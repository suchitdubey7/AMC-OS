-- =====================================================================
-- DDL-002  AMC OS - Step 16b DDL additions (status: Draft, WP4 / GOV-006 Step 16, part b)
-- Target: PostgreSQL 16+.  Applied after DDL-000 v0.9 and DDL-001.  Tested on PostgreSQL 16.15.
-- Run as a superuser / migration owner:  psql -v ON_ERROR_STOP=1 -f <this file>
--
-- What this file builds (DA-001 v0.4, Draft):
--   00  helpers: copies of DDL-001's session-local helpers (make_bitemporal, make_state_machine,
--       add_provenance), a helper for approved versions (make_vr) and four small generic triggers
--   01  product     (DA-001 §4.5)
--   02  investment  (DA-001 §4.6)
--   03  portfolio   (DA-001 §4.7)
--   04  trading     (DA-001 §4.8)  - the parts that do not depend on ADR-0020
--   05  execution   (DA-001 §4.9)  - the parts that do not depend on ADR-0020
--   06  settlement  (DA-001 §4.10) - the parts that do not depend on ADR-0020
--   07  row-level security and grants for every new table
--
-- What this file does NOT build, and why (ADR-0020 is merged as Draft, not yet accepted):
--   * execution.trade and execution.allocation (DM-7); trading.block_allocation keeps its
--     DDL-000 result columns until then.
--   * the rename settlement.trade -> settlement.settlement keyed by trade_id (DM-7).  The
--     settlement state machine (DM-10) is built on settlement.trade now; its transition and
--     history tables already carry the target names settlement.settlement_transition and
--     settlement.settlement_history, so the later rename touches only the table itself.
--   * per-schema outbox / inbox / dead-letter / idempotency tables (DM-4).
--   * removal of the cross-schema key trading."order" -> investment.decision_record (DM-20).
--   The other 12 schemas follow in Steps 16c-16e (see LOOP_STATE.md).
--
-- Bi-temporal tables follow rules BT-1..BT-5 of DDL-001 §00 (DA-001 §11) through the shared
-- functions platform.tg_bt_stamp, tg_bt_supersede, tg_bt_guard, tg_bt_closure_stamp, tg_bt_close.
-- No trigger in this file inserts into a version table or sets superseded_at.
--
-- Data: this file reshapes DDL-000 tables (renames columns, drops columns that move) without
-- copying rows.  It is for the empty reference database and refuses to run if those tables hold
-- rows.  The data move for a real database is the Alembic migration of Step 18.
-- The whole file runs in one transaction: it applies completely or not at all.
--
-- Every decision here is [DES] unless labelled.  No business rule, rate, threshold or cut-off is
-- set as code: values are rows.  State lists that no source document fixes are [ASSUMPTION] and
-- live in transition tables, so the owner can change them by migration without touching code.
-- =====================================================================

BEGIN;

DO $$
DECLARE t text; n bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY['product.scheme','product.scheme_version','product.fee_schedule','product.exit_load_slab',
                           'investment.universe_member','investment.restricted_list_entry','investment.decision_record',
                           'portfolio.snapshot','portfolio.snapshot_position','trading.order','trading.block_allocation',
                           'execution.fill','settlement.trade','settlement.instruction']
  LOOP
    EXECUTE format('SELECT count(*) FROM %s', t) INTO n;
    IF n > 0 THEN
      RAISE EXCEPTION 'DDL-002 reshapes % but it holds % rows; use the Step 18 migration that moves the data', t, n;
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 00  Helpers
-- ---------------------------------------------------------------------

-- The acting user (app.user_id) is the author of a row; a typed-in value is ignored, and it never
-- changes afterwards.  Argument: the column name.  BEFORE INSERT OR UPDATE.
CREATE OR REPLACE FUNCTION platform.tg_set_actor() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v := (to_jsonb(OLD) ->> TG_ARGV[0])::uuid;
  ELSE
    v := platform.current_user_id();
    IF v IS NULL OR NOT EXISTS (SELECT 1 FROM identity.app_user u
                                 WHERE u.tenant_id = NEW.tenant_id AND u.user_id = v AND u.status = 'ACTIVE') THEN
      RAISE EXCEPTION 'NO_ACTOR: %.% rows need an active user of the tenant as the acting user (app.user_id)',
        TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
    END IF;
  END IF;
  NEW := jsonb_populate_record(NEW, jsonb_build_object(TG_ARGV[0], v));
  RETURN NEW;
END $$;

-- Rows of some tables are written only by a trigger of another table (for example the order's
-- version history, the fill de-duplication key).  A direct insert by any role is refused.
CREATE OR REPLACE FUNCTION platform.tg_written_by_trigger_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF pg_trigger_depth() < 2 THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: %.% is written only by the trigger of its owning table',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- Child rows that may change only while their parent is in one of the listed states (lines of a
-- draft version, positions of a draft snapshot, votes of a meeting in session).  The parent row
-- is read FOR SHARE, so it cannot change state while the child row is uncommitted.
-- Arguments: [0] parent table, [1] parent state column, [2] allowed states (comma-separated),
-- [3..] key columns shared by child and parent (starting with tenant_id).
CREATE OR REPLACE FUNCTION platform.tg_parent_state_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_keys  text[] := TG_ARGV[3:TG_NARGS - 1];
  v_state text;
  v_row   record;
BEGIN
  FOR v_row IN SELECT * FROM (SELECT NEW AS r WHERE TG_OP <> 'DELETE' UNION ALL SELECT OLD WHERE TG_OP <> 'INSERT') x
  LOOP
    EXECUTE format('SELECT t.%I FROM %s t WHERE %s FOR SHARE', TG_ARGV[1], TG_ARGV[0], platform.key_match_sql(v_keys))
      INTO v_state USING v_row.r;
    IF v_state IS NULL OR NOT (v_state = ANY (string_to_array(TG_ARGV[2], ','))) THEN
      RAISE EXCEPTION 'PARENT_FROZEN: %.% rows change only while % is in %, it is %',
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_ARGV[0], TG_ARGV[2], coalesce(v_state, 'missing') USING ERRCODE = '23514';
    END IF;
  END LOOP;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

-- Session-local migration helpers (copies of DDL-001's; they disappear when this script ends).
CREATE FUNCTION pg_temp.make_bitemporal(p_table regclass, p_keys text[]) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_args   text;
  v_cols   text;
  v_schema text;
  v_name   text;
  v_period boolean;
BEGIN
  SELECT string_agg(quote_literal(k), ', ') INTO v_args FROM unnest(p_keys) AS k;
  EXECUTE format('CREATE TRIGGER bt_stamp BEFORE INSERT ON %s FOR EACH ROW EXECUTE FUNCTION platform.tg_bt_stamp()', p_table);
  EXECUTE format('CREATE TRIGGER bt_supersede AFTER INSERT ON %s FOR EACH ROW EXECUTE FUNCTION platform.tg_bt_supersede(%s)', p_table, v_args);
  EXECUTE format('CREATE TRIGGER bt_guard BEFORE UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION platform.tg_bt_guard(%s)', p_table, v_args);

  SELECT n.nspname, c.relname INTO v_schema, v_name
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.oid = p_table;
  SELECT string_agg(format('%I %s NOT NULL', a.attname, format_type(a.atttypid, a.atttypmod)), ', ' ORDER BY k.ord)
    INTO v_cols
    FROM unnest(p_keys) WITH ORDINALITY AS k(name, ord)
    JOIN pg_attribute a ON a.attrelid = p_table AND a.attname = k.name AND NOT a.attisdropped;
  v_period := EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = p_table AND attname = 'valid_period' AND NOT attisdropped);
  EXECUTE format('CREATE TABLE %I.%I (
      %s,
      closure_id          uuid NOT NULL DEFAULT gen_random_uuid(),
      closure_kind        text NOT NULL CHECK (closure_kind IN (''END'',''RETRACT'')),
      end_date            date,
      target_valid_period daterange,
      target_recorded_at  timestamptz,
      recorded_at         timestamptz NOT NULL DEFAULT clock_timestamp(),
      closing_xact        xid8 NOT NULL DEFAULT pg_current_xact_id(),
      closed_by           uuid NOT NULL,
      request_id          uuid NOT NULL,
      reason              text NOT NULL CHECK (length(btrim(reason)) > 0),
      PRIMARY KEY (tenant_id, closure_id),
      CHECK ((closure_kind = ''END'') = (end_date IS NOT NULL)),
      CHECK ((closure_kind = ''RETRACT'') = (target_recorded_at IS NOT NULL)),
      CHECK (%s)
    )', v_schema, v_name || '_closure', v_cols,
    CASE WHEN v_period
         THEN '(closure_kind = ''RETRACT'') = (target_valid_period IS NOT NULL)'
         ELSE 'closure_kind = ''RETRACT'' AND target_valid_period IS NULL' END);
  EXECUTE format('CREATE INDEX ON %I.%I (%s, recorded_at)', v_schema, v_name || '_closure',
                 (SELECT string_agg(format('%I', k), ', ') FROM unnest(p_keys) AS k));
  EXECUTE format('COMMENT ON TABLE %I.%I IS %L', v_schema, v_name || '_closure',
    format('Ends (END) or retracts (RETRACT) versions of %s.%s, with who, when, why and under which request (DA-001 §11, BT-3, BT-4, D-76). Insert-only.', v_schema, v_name));
  EXECUTE format('CREATE TRIGGER bt_closure_stamp BEFORE INSERT ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_bt_closure_stamp()',
                 v_schema, v_name || '_closure');
  EXECUTE format('CREATE TRIGGER bt_close AFTER INSERT ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_bt_close(%L, %s)',
                 v_schema, v_name || '_closure', format('%I.%I', v_schema, v_name), v_args);
  EXECUTE format('CREATE TRIGGER bt_closure_immutable BEFORE UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable()',
                 v_schema, v_name || '_closure');
END $$;

-- As DDL-001's make_state_machine, with two additions: p_name names the transition and history
-- tables (default: the table's own name) and the trigger names carry the state column, so one
-- table can have two state machines (delivery state and business status of an instruction, §3.5).
CREATE FUNCTION pg_temp.make_state_machine(p_schema text, p_table text, p_state_col text,
                                           p_keys text[], p_key_types text[], p_name text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_name text := coalesce(p_name, p_table);
  v_cols text := '';
  v_keylist text;
  v_args text;
  i int;
BEGIN
  EXECUTE format('CREATE TABLE %I.%I (
      from_state text NOT NULL,
      to_state   text NOT NULL CHECK (to_state <> ''(NEW)''),
      cause      text NOT NULL CHECK (cause ~ ''^[A-Z_]+$''),
      PRIMARY KEY (from_state, to_state, cause),
      CHECK (from_state <> to_state),
      CHECK ((from_state = ''(NEW)'') = (cause = ''CREATE''))
    )', p_schema, v_name || '_transition');
  EXECUTE format('COMMENT ON TABLE %I.%I IS %L', p_schema, v_name || '_transition',
    format('Product-level list of allowed moves of %s.%s.%s (DA-001 M3, M14). No tenant column; read-only for application roles; changed only by migration.',
           p_schema, p_table, p_state_col));
  FOR i IN 1 .. array_length(p_keys, 1) LOOP
    v_cols := v_cols || format('%I %s NOT NULL, ', p_keys[i], p_key_types[i]);
  END LOOP;
  SELECT string_agg(format('%I', k), ', ') INTO v_keylist FROM unnest(p_keys) AS k;
  EXECUTE format('CREATE TABLE %I.%I (
      tenant_id   uuid NOT NULL,
      %s
      changed_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
      from_state  text NOT NULL,
      to_state    text NOT NULL,
      cause       text NOT NULL,
      changed_by  uuid,
      PRIMARY KEY (tenant_id, %s, changed_at),
      FOREIGN KEY (tenant_id, %s) REFERENCES %I.%I (tenant_id, %s)
    )', p_schema, v_name || '_history', v_cols, v_keylist, v_keylist, p_schema, p_table, v_keylist);
  EXECUTE format('CREATE TRIGGER history_immutable BEFORE UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable()',
                 p_schema, v_name || '_history');
  EXECUTE format('CREATE TRIGGER history_via_trigger_only BEFORE INSERT ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_history_via_trigger_only()',
                 p_schema, v_name || '_history');
  EXECUTE format('CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_state_machine(%L, %L)',
                 'state_machine_' || p_state_col, p_schema, p_table, p_schema || '.' || v_name || '_transition', p_state_col);
  SELECT string_agg(quote_literal(k), ', ') INTO v_args FROM unnest(p_keys) AS k;
  EXECUTE format('CREATE TRIGGER %I AFTER INSERT OR UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_state_history(%L, %L, %s)',
                 'state_history_' || p_state_col, p_schema, p_table, p_schema || '.' || v_name || '_history', p_state_col, v_args);
END $$;

CREATE FUNCTION pg_temp.add_provenance(p_table regclass, p_load_run regclass) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('ALTER TABLE %s
      ADD COLUMN load_run_id         uuid,
      ADD COLUMN source_system       text NOT NULL DEFAULT ''AMC_OS_MANUAL'',
      ADD COLUMN source_record_ref   text,
      ADD COLUMN source_as_of        timestamptz,
      ADD COLUMN licence_tag         text,
      ADD COLUMN data_classification text NOT NULL DEFAULT ''INTERNAL''
                 CHECK (data_classification IN (''PUBLIC'',''INTERNAL'',''CONFIDENTIAL'',''RESTRICTED_PII'')),
      ADD COLUMN approval_request_id uuid,
      ADD CONSTRAINT provenance_ck CHECK (
            (source_system = ''AMC_OS_MANUAL'' AND load_run_id IS NULL AND approval_request_id IS NOT NULL)
         OR (source_system <> ''AMC_OS_MANUAL'' AND load_run_id IS NOT NULL AND source_record_ref IS NOT NULL)),
      ADD CONSTRAINT provenance_load_run_fk FOREIGN KEY (tenant_id, load_run_id) REFERENCES %s (tenant_id, load_run_id)',
    p_table, p_load_run);
  EXECUTE format('CREATE TRIGGER load_run_open BEFORE INSERT ON %s FOR EACH ROW EXECUTE FUNCTION platform.tg_load_run_open(%L)',
    p_table, p_load_run::text);
END $$;

-- Approved versions (M11, code VR in DA-001 §3.1): the version row is frozen once APPROVED
-- (platform.tg_vr_frozen), its status follows the VR lifecycle as a state machine, and the maker is
-- the acting user.  The table must have: status, the maker column, approval_request_id.
CREATE FUNCTION pg_temp.make_vr(p_schema text, p_table text, p_keys text[], p_key_types text[],
                                p_maker_col text DEFAULT 'maker_user_id') RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('CREATE TRIGGER vr_frozen BEFORE UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_vr_frozen()',
                 p_schema, p_table);
  EXECUTE format('CREATE TRIGGER vr_maker BEFORE INSERT OR UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor(%L)',
                 p_schema, p_table, p_maker_col);
  PERFORM pg_temp.make_state_machine(p_schema, p_table, 'status', p_keys, p_key_types);
  -- The approved-version lifecycle of DA-001 §3.1 (code VR), as DDL-001 uses it for
  -- master.source_precedence_rule.
  EXECUTE format('INSERT INTO %I.%I (from_state, to_state, cause) VALUES
      (''(NEW)'',''DRAFT'',''CREATE''),
      (''DRAFT'',''PENDING_APPROVAL'',''STATE_CHANGE''),
      (''PENDING_APPROVAL'',''APPROVED'',''STATE_CHANGE''),
      (''PENDING_APPROVAL'',''REJECTED'',''STATE_CHANGE''),
      (''PENDING_APPROVAL'',''DRAFT'',''REJECT''),
      (''APPROVED'',''SUPERSEDED'',''STATE_CHANGE'')', p_schema, p_table || '_transition');
END $$;

-- Load runs (DA-001 §3.3) for each module schema that loads outside data in this part.
CREATE FUNCTION pg_temp.make_load_run(p_schema text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('CREATE TABLE %I.load_run (
      tenant_id        uuid NOT NULL REFERENCES platform.tenant,
      load_run_id      uuid NOT NULL DEFAULT gen_random_uuid(),
      inbound_file_id  uuid,                  -- ID reference to operations.inbound_file (M4)
      message_session_ref text,
      adapter_name     text NOT NULL,
      adapter_version  text NOT NULL,
      canonical_family text NOT NULL,         -- INT-001 §3
      business_date    date NOT NULL,
      started_at       timestamptz NOT NULL DEFAULT now(),
      finished_at      timestamptz,
      rows_loaded      integer CHECK (rows_loaded >= 0),
      rows_quarantined integer CHECK (rows_quarantined >= 0),
      status           text NOT NULL DEFAULT ''RUNNING'' CHECK (status IN (''RUNNING'',''COMPLETED'',''FAILED'')),
      PRIMARY KEY (tenant_id, load_run_id),
      CHECK (inbound_file_id IS NOT NULL OR message_session_ref IS NOT NULL),
      CHECK ((status = ''RUNNING'') = (finished_at IS NULL))
    )', p_schema);
  EXECUTE format('CREATE TRIGGER load_run_guard BEFORE UPDATE OR DELETE ON %I.load_run
                  FOR EACH ROW EXECUTE FUNCTION platform.tg_load_run_guard()', p_schema);
END $$;

-- Insert-only tables (M12): no update, no delete.
CREATE FUNCTION pg_temp.make_insert_only(p_table regclass) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('CREATE TRIGGER insert_only BEFORE UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable()', p_table);
END $$;

-- ---------------------------------------------------------------------
-- 01  product  (Product module, D02; DA-001 §4.5)
-- ---------------------------------------------------------------------

-- Scheme lifecycle as a state machine (M14).  States: FR-D02-009; moves: FR-D02-009 sequence and
-- the PRD-002 §6 lifecycle diagram.  The DDL-000 CHECK on lifecycle_state stays (same 14 states).
SELECT pg_temp.make_state_machine('product', 'scheme', 'lifecycle_state', ARRAY['scheme_id'], ARRAY['uuid']);
INSERT INTO product.scheme_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  -- FR-D02-009 launch sequence
  ('DRAFT','IN_REVIEW','STATE_CHANGE'),
  ('IN_REVIEW','FILED_WITH_SEBI','STATE_CHANGE'),
  ('FILED_WITH_SEBI','SEBI_OBSERVATIONS','STATE_CHANGE'),
  ('SEBI_OBSERVATIONS','APPROVED_FOR_LAUNCH','STATE_CHANGE'),
  ('APPROVED_FOR_LAUNCH','NFO_OPEN','STATE_CHANGE'),
  ('NFO_OPEN','NFO_CLOSED','STATE_CHANGE'),
  ('NFO_CLOSED','ALLOTTED','STATE_CHANGE'),
  ('NFO_CLOSED','CANCELLED','STATE_CHANGE'),      -- NFO minimum not met (FR-D02-009, WF-001)
  ('ALLOTTED','ACTIVE','STATE_CHANGE'),
  -- PRD-002 §6 lifecycle diagram
  ('ACTIVE','SUSPENDED_SUBSCRIPTIONS','STATE_CHANGE'),
  ('SUSPENDED_SUBSCRIPTIONS','ACTIVE','STATE_CHANGE'),
  ('ACTIVE','MERGING','STATE_CHANGE'),
  ('SUSPENDED_SUBSCRIPTIONS','MERGING','STATE_CHANGE'),
  ('MERGING','WOUND_UP','STATE_CHANGE'),
  ('ACTIVE','WOUND_UP','STATE_CHANGE'),
  ('ACTIVE','MATURED','STATE_CHANGE'),
  ('SUSPENDED_SUBSCRIPTIONS','WOUND_UP','STATE_CHANGE'),
  ('SUSPENDED_SUBSCRIPTIONS','MATURED','STATE_CHANGE'),
  ('MERGING','ACTIVE','ABANDON_MERGER'),
  ('MERGING','SUSPENDED_SUBSCRIPTIONS','ABANDON_MERGER');
-- Moves FR-D02-009 does not list (a scheme dropped before filing, a filing answered without
-- observations, a return to DRAFT from review) are not allowed: owner question Q90.

-- PRD-002 §6: an abandoned merger goes back to the state the scheme held before the merger.
CREATE OR REPLACE FUNCTION product.tg_scheme_merger_back() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_before text;
BEGIN
  IF OLD.lifecycle_state = 'MERGING' AND NEW.lifecycle_state IN ('ACTIVE','SUSPENDED_SUBSCRIPTIONS') THEN
    SELECT h.from_state INTO v_before FROM product.scheme_history h
     WHERE h.tenant_id = NEW.tenant_id AND h.scheme_id = NEW.scheme_id AND h.to_state = 'MERGING'
     ORDER BY h.changed_at DESC LIMIT 1;
    IF v_before IS DISTINCT FROM NEW.lifecycle_state THEN
      RAISE EXCEPTION 'ILLEGAL_TRANSITION: an abandoned merger returns scheme % to %, not %',
        NEW.scheme_id, coalesce(v_before, 'unknown'), NEW.lifecycle_state USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER scheme_merger_back BEFORE UPDATE OF lifecycle_state ON product.scheme
  FOR EACH ROW EXECUTE FUNCTION product.tg_scheme_merger_back();
ALTER TABLE product.scheme ADD COLUMN created_by uuid DEFAULT platform.current_user_id();

-- SEBI scheme categories and their versions (PRD-002 §10).  Category values are data loaded by the
-- tenant from the SEBI categorisation circular in force [REG — values are data, not code].
CREATE TABLE product.category (
  tenant_id      uuid NOT NULL REFERENCES platform.tenant,
  category_code  text NOT NULL CHECK (category_code ~ '^[A-Z][A-Z0-9_]{1,60}$'),
  version_no     integer NOT NULL CHECK (version_no > 0),
  name           text NOT NULL,
  category_group text NOT NULL,                   -- e.g. equity, debt, hybrid (data, from the circular)
  description    text,
  valid_period   daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status         text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id  uuid NOT NULL,
  approval_request_id uuid,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, category_code, version_no),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  EXCLUDE USING gist (tenant_id WITH =, category_code WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);
SELECT pg_temp.make_vr('product', 'category', ARRAY['category_code','version_no'], ARRAY['text','integer']);

-- Scheme versions (VR): effective -> valid_period (M6); the category is the exact approved category
-- version (M13), replacing DDL-000's free-text sebi_category / sebi_subcategory.
ALTER TABLE product.scheme_version RENAME COLUMN effective TO valid_period;
ALTER TABLE product.scheme_version RENAME COLUMN created_by TO maker_user_id;
ALTER TABLE product.scheme_version
  DROP COLUMN sebi_category, DROP COLUMN sebi_subcategory,
  ADD COLUMN category_code text NOT NULL,
  ADD COLUMN category_version_no integer NOT NULL,
  ADD CONSTRAINT scheme_version_category_fk FOREIGN KEY (tenant_id, category_code, category_version_no)
      REFERENCES product.category (tenant_id, category_code, version_no),
  ADD CONSTRAINT scheme_version_period_ck CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  ADD CONSTRAINT scheme_version_approval_ck CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL);
SELECT pg_temp.make_vr('product', 'scheme_version', ARRAY['scheme_id','version_no'], ARRAY['uuid','integer']);

-- A scheme version may cite only an APPROVED category version.
CREATE OR REPLACE FUNCTION product.tg_scheme_version_category() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM product.category c
                  WHERE c.tenant_id = NEW.tenant_id AND c.category_code = NEW.category_code
                    AND c.version_no = NEW.category_version_no AND c.status IN ('APPROVED','SUPERSEDED')) THEN
    RAISE EXCEPTION 'CATEGORY_NOT_APPROVED: category % version % is not approved', NEW.category_code, NEW.category_version_no
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER scheme_version_category BEFORE INSERT OR UPDATE OF category_code, category_version_no ON product.scheme_version
  FOR EACH ROW EXECUTE FUNCTION product.tg_scheme_version_category();

-- Mandate lines of a scheme version: asset-allocation ranges and permitted instruments
-- (PRD-002 §10).  Part of the version: they change only while the version is DRAFT.
CREATE TABLE product.scheme_mandate (
  tenant_id     uuid NOT NULL,
  scheme_id     uuid NOT NULL,
  version_no    integer NOT NULL,
  line_no       integer NOT NULL CHECK (line_no > 0),
  line_kind     text NOT NULL CHECK (line_kind IN ('ASSET_ALLOCATION','PERMITTED_INSTRUMENT','EXCLUDED_INSTRUMENT')),
  asset_class   text NOT NULL,
  min_pct       numeric(9,6) CHECK (min_pct >= 0 AND min_pct <= 100),
  max_pct       numeric(9,6) CHECK (max_pct >= 0 AND max_pct <= 100),
  note          text,
  PRIMARY KEY (tenant_id, scheme_id, version_no, line_no),
  FOREIGN KEY (tenant_id, scheme_id, version_no) REFERENCES product.scheme_version (tenant_id, scheme_id, version_no),
  CHECK ((line_kind = 'ASSET_ALLOCATION') = (min_pct IS NOT NULL AND max_pct IS NOT NULL)),
  CHECK (min_pct IS NULL OR min_pct <= max_pct)
);
CREATE TRIGGER scheme_mandate_draft_only BEFORE INSERT OR UPDATE OR DELETE ON product.scheme_mandate
  FOR EACH ROW EXECUTE FUNCTION platform.tg_parent_state_guard('product.scheme_version', 'status', 'DRAFT',
                                                               'tenant_id', 'scheme_id', 'version_no');

-- Benchmark(s) per scheme, effective-dated (BT, §3.1 rule 2; T18: the benchmark data is Security
-- master's, the mapping is here).  Role values [ASSUMPTION — owner Q90].
CREATE TABLE product.benchmark_mapping (
  tenant_id      uuid NOT NULL,
  scheme_id      uuid NOT NULL,
  benchmark_role text NOT NULL CHECK (benchmark_role IN ('PRIMARY','SECONDARY','ADDITIONAL')),
  valid_period   daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at  timestamptz,
  benchmark_id   uuid NOT NULL,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, scheme_id, benchmark_role, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, scheme_id)    REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, benchmark_id) REFERENCES master.benchmark (tenant_id, benchmark_id),
  EXCLUDE USING gist (tenant_id WITH =, scheme_id WITH =, benchmark_role WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('product.benchmark_mapping', ARRAY['tenant_id','scheme_id','benchmark_role']);

-- Fee schedules -> bi-temporal (M7, §3.1 rule 2).
ALTER TABLE product.fee_schedule RENAME COLUMN effective TO valid_period;
ALTER TABLE product.fee_schedule
  DROP CONSTRAINT fee_schedule_pkey,
  DROP CONSTRAINT fee_schedule_tenant_id_plan_id_fee_type_effective_excl,
  ADD COLUMN recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN superseded_at timestamptz,
  ADD CONSTRAINT fee_schedule_period_ck CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  ADD PRIMARY KEY (tenant_id, plan_id, fee_type, valid_period, recorded_at),
  ADD CONSTRAINT fee_schedule_current_excl EXCLUDE USING gist
      (tenant_id WITH =, plan_id WITH =, fee_type WITH =, valid_period WITH &&)
      WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED;
SELECT pg_temp.make_bitemporal('product.fee_schedule', ARRAY['tenant_id','plan_id','fee_type']);

-- Exit-load slabs -> bi-temporal.  Versions are per slab (plan, lower bound of days held); in
-- addition no two current slabs of one plan may cover the same holding day on the same date, so a
-- new slab set must END the old slabs it does not replace (BT-3).  approval_request_id added (M21).
ALTER TABLE product.exit_load_slab RENAME COLUMN effective TO valid_period;
ALTER TABLE product.exit_load_slab
  DROP CONSTRAINT exit_load_slab_pkey,
  ADD COLUMN recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN superseded_at timestamptz,
  ADD COLUMN approval_request_id uuid NOT NULL,
  ADD CONSTRAINT exit_load_slab_period_ck CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  ADD PRIMARY KEY (tenant_id, plan_id, min_days_held, valid_period, recorded_at),
  ADD CONSTRAINT exit_load_slab_current_excl EXCLUDE USING gist
      (tenant_id WITH =, plan_id WITH =, min_days_held WITH =, valid_period WITH &&)
      WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED,
  ADD CONSTRAINT exit_load_slab_no_overlap_excl EXCLUDE USING gist
      (tenant_id WITH =, plan_id WITH =, int4range(min_days_held, max_days_held, '[)') WITH &&, valid_period WITH &&)
      WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED;
SELECT pg_temp.make_bitemporal('product.exit_load_slab', ARRAY['tenant_id','plan_id','min_days_held']);

-- New fund offer and the collections mirror (PRD-002 §10, WF-001).  States [ASSUMPTION — Q90].
CREATE TABLE product.nfo (
  tenant_id      uuid NOT NULL,
  nfo_id         uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id      uuid NOT NULL,
  open_date      date NOT NULL,
  close_date     date NOT NULL,
  allotment_date date,
  minimum_subscription_amount numeric(24,4) CHECK (minimum_subscription_amount >= 0),  -- from the SID [VAL]
  collected_amount numeric(24,4) CHECK (collected_amount >= 0),     -- mirror of RTA collections
  collected_as_of  timestamptz,
  state          text NOT NULL DEFAULT 'PLANNED',
  approval_request_id uuid,
  created_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid DEFAULT platform.current_user_id(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  row_version    integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, nfo_id),
  UNIQUE (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  CHECK (close_date >= open_date),
  CHECK (allotment_date IS NULL OR allotment_date >= close_date),
  CHECK ((collected_amount IS NULL) = (collected_as_of IS NULL)),
  CHECK (state = 'PLANNED' OR approval_request_id IS NOT NULL),
  CHECK (state <> 'ALLOTTED' OR allotment_date IS NOT NULL)
);
CREATE TRIGGER nfo_version BEFORE UPDATE ON product.nfo FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('product', 'nfo', 'state', ARRAY['nfo_id'], ARRAY['uuid']);
INSERT INTO product.nfo_transition (from_state, to_state, cause) VALUES
  ('(NEW)','PLANNED','CREATE'),
  ('PLANNED','OPEN','STATE_CHANGE'),
  ('PLANNED','CANCELLED','STATE_CHANGE'),
  ('OPEN','CLOSED','STATE_CHANGE'),
  ('CLOSED','ALLOTTED','STATE_CHANGE'),
  ('CLOSED','CANCELLED','STATE_CHANGE');

-- Lifecycle events with effective dates (PRD-002 §10, §6).  Insert-only (M12); a correction is a
-- new event that names the one it corrects.
CREATE TABLE product.scheme_event (
  tenant_id        uuid NOT NULL,
  scheme_event_id  uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id        uuid NOT NULL,
  plan_id          uuid,                          -- set when the event concerns one plan only
  event_type       text NOT NULL CHECK (event_type IN
                     ('SUSPENSION','RESUMPTION','MERGER','MERGER_ABANDONED','WINDING_UP','MATURITY')),
  effective_date   date NOT NULL,
  target_scheme_id uuid,                          -- the scheme merged into (MERGER only)
  reason           text NOT NULL CHECK (length(btrim(reason)) > 0),
  approval_request_id uuid NOT NULL,
  corrects_event_id uuid,
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  recorded_by      uuid NOT NULL,
  PRIMARY KEY (tenant_id, scheme_event_id),
  FOREIGN KEY (tenant_id, scheme_id)         REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, plan_id)           REFERENCES product.plan (tenant_id, plan_id),
  FOREIGN KEY (tenant_id, target_scheme_id)  REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, corrects_event_id) REFERENCES product.scheme_event (tenant_id, scheme_event_id),
  CHECK ((event_type = 'MERGER') = (target_scheme_id IS NOT NULL)),
  CHECK (target_scheme_id IS NULL OR target_scheme_id <> scheme_id)
);
SELECT pg_temp.make_insert_only('product.scheme_event');
CREATE TRIGGER scheme_event_actor BEFORE INSERT ON product.scheme_event
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('recorded_by');

-- Scheme change request with fundamental-attribute flags (PRD-002 §10, WF-030).
-- States [ASSUMPTION — Q90].
CREATE TABLE product.scheme_change_request (
  tenant_id         uuid NOT NULL,
  change_request_id uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id         uuid NOT NULL,
  proposed_version_no integer,                    -- the DRAFT scheme_version that carries the change
  is_fundamental    boolean NOT NULL,
  changed_fields    text[] NOT NULL CHECK (cardinality(changed_fields) > 0),
  effective_date    date NOT NULL,
  reason            text NOT NULL CHECK (length(btrim(reason)) > 0),
  state             text NOT NULL DEFAULT 'DRAFT',
  approval_request_id uuid,
  requested_by      uuid NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  row_version       integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, change_request_id),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, scheme_id, proposed_version_no) REFERENCES product.scheme_version (tenant_id, scheme_id, version_no),
  CHECK (state NOT IN ('APPROVED','EFFECTIVE') OR approval_request_id IS NOT NULL),
  CHECK (state IN ('DRAFT','CANCELLED','REJECTED') OR proposed_version_no IS NOT NULL)
);
CREATE TRIGGER scheme_change_request_version BEFORE UPDATE ON product.scheme_change_request
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER scheme_change_request_actor BEFORE INSERT OR UPDATE ON product.scheme_change_request
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('requested_by');
SELECT pg_temp.make_state_machine('product', 'scheme_change_request', 'state', ARRAY['change_request_id'], ARRAY['uuid']);
INSERT INTO product.scheme_change_request_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  ('DRAFT','SUBMITTED','STATE_CHANGE'),
  ('DRAFT','CANCELLED','STATE_CHANGE'),
  ('SUBMITTED','APPROVED','STATE_CHANGE'),
  ('SUBMITTED','REJECTED','STATE_CHANGE'),
  ('SUBMITTED','DRAFT','REJECT'),
  ('APPROVED','EFFECTIVE','STATE_CHANGE');

-- Which documents.document version is the scheme's SID, KIM or SAI from when (BT, rule 2).
-- document_id is an ID reference (M4); the content stays in Documents (BA-001 §4).
CREATE TABLE product.scheme_document_link (
  tenant_id      uuid NOT NULL,
  scheme_id      uuid NOT NULL,
  document_type  text NOT NULL CHECK (document_type IN ('SID','KIM','SAI')),
  valid_period   daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at  timestamptz,
  document_id    uuid NOT NULL,
  document_version_no integer NOT NULL CHECK (document_version_no > 0),
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, scheme_id, document_type, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  EXCLUDE USING gist (tenant_id WITH =, scheme_id WITH =, document_type WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('product.scheme_document_link', ARRAY['tenant_id','scheme_id','document_type']);

-- Crosswalk for schemes and plans (§3.4): AMFI scheme code, RTA scheme and plan codes, ISIN per
-- plan option.  Same shape as master.external_identifier; the code types are master.identifier_scheme
-- rows, which may now name SCHEME and PLAN.
SELECT pg_temp.make_load_run('product');
ALTER TABLE master.identifier_scheme DROP CONSTRAINT identifier_scheme_entity_types_check,
  ADD CONSTRAINT identifier_scheme_entity_types_check CHECK (
    entity_types <@ ARRAY['SECURITY','ISSUER','ISSUER_GROUP','COUNTERPARTY','BENCHMARK','SCHEME','PLAN']
    AND cardinality(entity_types) > 0);
CREATE TABLE product.external_identifier (
  tenant_id              uuid NOT NULL,
  external_identifier_id uuid NOT NULL DEFAULT gen_random_uuid(),
  valid_period           daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at            timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at          timestamptz,
  entity_type            text NOT NULL CHECK (entity_type IN ('SCHEME','PLAN')),
  entity_id              uuid NOT NULL,
  scheme_code            text NOT NULL,         -- code type (master.identifier_scheme)
  value                  text NOT NULL,
  PRIMARY KEY (tenant_id, external_identifier_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, scheme_code) REFERENCES master.identifier_scheme (tenant_id, scheme_code),
  EXCLUDE USING gist (tenant_id WITH =, external_identifier_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED,
  EXCLUDE USING gist (tenant_id WITH =, scheme_code WITH =, value WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.add_provenance('product.external_identifier', 'product.load_run');
SELECT pg_temp.make_bitemporal('product.external_identifier', ARRAY['tenant_id','external_identifier_id']);
CREATE OR REPLACE FUNCTION product.tg_external_identifier_check() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_ok boolean; v_types text[]; v_regex text;
BEGIN
  IF platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN RETURN NEW; END IF;  -- already checked (BT-5)
  v_ok := CASE NEW.entity_type
    WHEN 'SCHEME' THEN EXISTS (SELECT 1 FROM product.scheme WHERE tenant_id = NEW.tenant_id AND scheme_id = NEW.entity_id)
    WHEN 'PLAN'   THEN EXISTS (SELECT 1 FROM product.plan   WHERE tenant_id = NEW.tenant_id AND plan_id   = NEW.entity_id)
  END;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'UNKNOWN_ENTITY: % % does not exist', NEW.entity_type, NEW.entity_id USING ERRCODE = '23503';
  END IF;
  SELECT entity_types, format_regex INTO v_types, v_regex FROM master.identifier_scheme
   WHERE tenant_id = NEW.tenant_id AND scheme_code = NEW.scheme_code;
  IF NOT (NEW.entity_type = ANY (v_types)) THEN
    RAISE EXCEPTION 'SCHEME_NOT_ALLOWED: % codes cannot identify a %', NEW.scheme_code, NEW.entity_type USING ERRCODE = '23514';
  END IF;
  IF v_regex IS NOT NULL AND NEW.value !~ v_regex THEN
    RAISE EXCEPTION 'BAD_IDENTIFIER_FORMAT: % value % fails the scheme format', NEW.scheme_code, NEW.value USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER external_identifier_check BEFORE INSERT ON product.external_identifier
  FOR EACH ROW EXECUTE FUNCTION product.tg_external_identifier_check();

-- ---------------------------------------------------------------------
-- 02  investment  (Investment module, D03; DA-001 §4.6)
-- ---------------------------------------------------------------------

-- Universe -> bi-temporal (M7, §3.1 rule 2).  An APPROVED member needs its approval reference.
ALTER TABLE investment.universe_member RENAME COLUMN effective TO valid_period;
ALTER TABLE investment.universe_member
  DROP CONSTRAINT universe_member_pkey,
  DROP CONSTRAINT universe_member_tenant_id_scheme_id_security_id_effective_excl,
  ADD COLUMN recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN superseded_at timestamptz,
  ADD CONSTRAINT universe_member_period_ck CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  ADD CONSTRAINT universe_member_approval_ck CHECK (status <> 'APPROVED' OR approval_request_id IS NOT NULL),
  ADD PRIMARY KEY (tenant_id, scheme_id, security_id, valid_period, recorded_at),
  ADD CONSTRAINT universe_member_current_excl EXCLUDE USING gist
      (tenant_id WITH =, scheme_id WITH =, security_id WITH =, valid_period WITH &&)
      WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED;
SELECT pg_temp.make_bitemporal('investment.universe_member', ARRAY['tenant_id','scheme_id','security_id']);

-- Restricted list -> anchor + versions (§3.1 rule 1: keyed by its own ID).  The anchor keeps what
-- never changes (the ID and what is restricted).  DDL-000's tstzrange "effective" becomes a daterange
-- valid_period (M6); the moment a restriction became known during a day is its recorded_at (BT-5),
-- so a pre-trade check "as known at" a time sees a restriction from the minute it was entered.
DROP INDEX investment.restricted_active_ix;
ALTER TABLE investment.restricted_list_entry
  DROP COLUMN restriction, DROP COLUMN reason_code, DROP COLUMN effective, DROP COLUMN approval_request_id,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
CREATE TRIGGER restricted_list_entry_anchor_immutable BEFORE UPDATE OR DELETE ON investment.restricted_list_entry
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();
CREATE TABLE investment.restricted_list_entry_version (
  tenant_id     uuid NOT NULL,
  entry_id      uuid NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  restriction   text NOT NULL CHECK (restriction IN ('BLOCK','WARN')),
  reason_code   text NOT NULL,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, entry_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, entry_id) REFERENCES investment.restricted_list_entry (tenant_id, entry_id),
  EXCLUDE USING gist (tenant_id WITH =, entry_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('investment.restricted_list_entry_version', ARRAY['tenant_id','entry_id']);

-- Decisions are insert-only facts (M12; DA-001 §4.6 code IO).
SELECT pg_temp.make_insert_only('investment.decision_record');

-- Research notes: anchor (author, subject) and approved versions (content in Documents).
CREATE TABLE investment.research_note (
  tenant_id      uuid NOT NULL REFERENCES platform.tenant,
  note_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  issuer_id      uuid,
  security_id    uuid,
  author_user_id uuid NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, note_id),
  FOREIGN KEY (tenant_id, issuer_id)   REFERENCES master.issuer (tenant_id, issuer_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  CHECK (issuer_id IS NOT NULL OR security_id IS NOT NULL)
);
SELECT pg_temp.make_insert_only('investment.research_note');
CREATE TRIGGER research_note_actor BEFORE INSERT ON investment.research_note
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('author_user_id');
CREATE TABLE investment.research_note_version (
  tenant_id     uuid NOT NULL,
  note_id       uuid NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  title         text NOT NULL,
  summary       text,
  document_id   uuid NOT NULL,                 -- ID reference to documents.document (M4)
  document_version_no integer NOT NULL CHECK (document_version_no > 0),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, note_id, version_no),
  FOREIGN KEY (tenant_id, note_id) REFERENCES investment.research_note (tenant_id, note_id),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL)
);
SELECT pg_temp.make_vr('investment', 'research_note_version', ARRAY['note_id','version_no'], ARRAY['uuid','integer']);

-- Buy / sell / hold recommendation with versions and thesis (PRD-003 §10).
CREATE TABLE investment.recommendation (
  tenant_id         uuid NOT NULL REFERENCES platform.tenant,
  recommendation_id uuid NOT NULL,
  version_no        integer NOT NULL CHECK (version_no > 0),
  security_id       uuid NOT NULL,
  call              text NOT NULL CHECK (call IN ('BUY','SELL','HOLD')),
  thesis            text NOT NULL CHECK (length(btrim(thesis)) > 0),
  target_price      numeric(24,8) CHECK (target_price > 0),
  note_id           uuid,
  valid_period      daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status            text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id     uuid NOT NULL,
  approval_request_id uuid,
  created_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, recommendation_id, version_no),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  FOREIGN KEY (tenant_id, note_id)     REFERENCES investment.research_note (tenant_id, note_id),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  EXCLUDE USING gist (tenant_id WITH =, recommendation_id WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);
SELECT pg_temp.make_vr('investment', 'recommendation', ARRAY['recommendation_id','version_no'], ARRAY['uuid','integer']);

-- Which analyst covers which issuer (BT, rule 2).  analyst_user_id is an ID reference (M4).
-- Role values [ASSUMPTION — Q90].
CREATE TABLE investment.coverage (
  tenant_id       uuid NOT NULL,
  analyst_user_id uuid NOT NULL,
  issuer_id       uuid NOT NULL,
  valid_period    daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at     timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at   timestamptz,
  coverage_role   text NOT NULL CHECK (coverage_role IN ('PRIMARY','SECONDARY')),
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, analyst_user_id, issuer_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, issuer_id) REFERENCES master.issuer (tenant_id, issuer_id),
  EXCLUDE USING gist (tenant_id WITH =, analyst_user_id WITH =, issuer_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('investment.coverage', ARRAY['tenant_id','analyst_user_id','issuer_id']);

-- Investment committee meetings, agenda items and votes (PRD-003 §10; NFR-AUD-003).
-- Meeting states [ASSUMPTION — Q90].
CREATE TABLE investment.ic_meeting (
  tenant_id      uuid NOT NULL REFERENCES platform.tenant,
  meeting_id     uuid NOT NULL DEFAULT gen_random_uuid(),
  committee_code text NOT NULL,
  meeting_date   date NOT NULL,
  chair_user_id  uuid NOT NULL,                 -- ID reference (M4)
  minutes_document_id uuid,                     -- ID reference to documents.document (M4)
  state          text NOT NULL DEFAULT 'SCHEDULED',
  created_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid DEFAULT platform.current_user_id(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  row_version    integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, meeting_id),
  CHECK (state <> 'MINUTES_APPROVED' OR minutes_document_id IS NOT NULL)
);
CREATE TRIGGER ic_meeting_version BEFORE UPDATE ON investment.ic_meeting FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('investment', 'ic_meeting', 'state', ARRAY['meeting_id'], ARRAY['uuid']);
INSERT INTO investment.ic_meeting_transition (from_state, to_state, cause) VALUES
  ('(NEW)','SCHEDULED','CREATE'),
  ('SCHEDULED','IN_SESSION','STATE_CHANGE'),
  ('SCHEDULED','CANCELLED','STATE_CHANGE'),
  ('IN_SESSION','CONCLUDED','STATE_CHANGE'),
  ('CONCLUDED','MINUTES_APPROVED','STATE_CHANGE');

CREATE TABLE investment.ic_agenda_item (
  tenant_id     uuid NOT NULL,
  meeting_id    uuid NOT NULL,
  item_no       integer NOT NULL CHECK (item_no > 0),
  subject       text NOT NULL,
  linked_object_type text,                      -- e.g. 'investment.credit_approval'
  linked_object_id   uuid,                      -- ID reference (M4)
  outcome       text CHECK (outcome IN ('APPROVED','REJECTED','DEFERRED')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by    uuid DEFAULT platform.current_user_id(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, meeting_id, item_no),
  FOREIGN KEY (tenant_id, meeting_id) REFERENCES investment.ic_meeting (tenant_id, meeting_id),
  CHECK ((linked_object_type IS NULL) = (linked_object_id IS NULL))
);
CREATE TRIGGER ic_agenda_item_version BEFORE UPDATE ON investment.ic_agenda_item FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER ic_agenda_item_open_meeting BEFORE INSERT OR UPDATE OR DELETE ON investment.ic_agenda_item
  FOR EACH ROW EXECUTE FUNCTION platform.tg_parent_state_guard('investment.ic_meeting', 'state', 'SCHEDULED,IN_SESSION',
                                                               'tenant_id', 'meeting_id');

-- A member's own vote and conflict declaration; cast only while the meeting is in session; the
-- voter is the acting user (a typed-in member is ignored).  Insert-only.
CREATE TABLE investment.ic_vote (
  tenant_id      uuid NOT NULL,
  meeting_id     uuid NOT NULL,
  item_no        integer NOT NULL,
  member_user_id uuid NOT NULL,
  vote           text NOT NULL CHECK (vote IN ('FOR','AGAINST','ABSTAIN','RECUSED')),
  conflict_declared boolean NOT NULL,
  conflict_note  text,
  voted_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, meeting_id, item_no, member_user_id),
  FOREIGN KEY (tenant_id, meeting_id, item_no) REFERENCES investment.ic_agenda_item (tenant_id, meeting_id, item_no),
  CHECK (NOT conflict_declared OR length(btrim(conflict_note)) > 0)
);
SELECT pg_temp.make_insert_only('investment.ic_vote');
CREATE TRIGGER ic_vote_actor BEFORE INSERT ON investment.ic_vote
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('member_user_id');
CREATE TRIGGER ic_vote_in_session BEFORE INSERT ON investment.ic_vote
  FOR EACH ROW EXECUTE FUNCTION platform.tg_parent_state_guard('investment.ic_meeting', 'state', 'IN_SESSION',
                                                               'tenant_id', 'meeting_id');

-- Approved credit limit per issuer with review date (VR).
CREATE TABLE investment.credit_approval (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  issuer_id     uuid NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  limit_amount  numeric(24,4) NOT NULL CHECK (limit_amount >= 0),
  currency_code char(3) NOT NULL DEFAULT 'INR' REFERENCES master.currency,
  review_date   date NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, issuer_id, version_no),
  FOREIGN KEY (tenant_id, issuer_id) REFERENCES master.issuer (tenant_id, issuer_id),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  CHECK (review_date >= lower(valid_period)),
  EXCLUDE USING gist (tenant_id WITH =, issuer_id WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);
SELECT pg_temp.make_vr('investment', 'credit_approval', ARRAY['issuer_id','version_no'], ARRAY['uuid','integer']);

-- House view, scheme strategy and investment policy versions (VR; WF-031).
CREATE TABLE investment.house_view (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  view_id       uuid NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  title         text NOT NULL,
  asset_class   text NOT NULL,
  stance        text NOT NULL,
  document_id   uuid,                           -- ID reference (M4)
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, view_id, version_no),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  EXCLUDE USING gist (tenant_id WITH =, view_id WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);
SELECT pg_temp.make_vr('investment', 'house_view', ARRAY['view_id','version_no'], ARRAY['uuid','integer']);

CREATE TABLE investment.scheme_strategy (
  tenant_id     uuid NOT NULL,
  scheme_id     uuid NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  strategy_text text NOT NULL,
  document_id   uuid,                           -- ID reference (M4)
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, scheme_id, version_no),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  EXCLUDE USING gist (tenant_id WITH =, scheme_id WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);
SELECT pg_temp.make_vr('investment', 'scheme_strategy', ARRAY['scheme_id','version_no'], ARRAY['uuid','integer']);

CREATE TABLE investment.investment_policy (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  policy_id     uuid NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  title         text NOT NULL,
  document_id   uuid NOT NULL,                  -- ID reference (M4)
  document_version_no integer NOT NULL CHECK (document_version_no > 0),
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, policy_id, version_no),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  EXCLUDE USING gist (tenant_id WITH =, policy_id WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);
SELECT pg_temp.make_vr('investment', 'investment_policy', ARRAY['policy_id','version_no'], ARRAY['uuid','integer']);

-- Request to set a house limit, passed to Compliance as a rule change (WF-034, DM-11).
-- compliance_rule_id is an ID reference to compliance.rule (M4).  States [ASSUMPTION — Q90].
CREATE TABLE investment.internal_limit_request (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  request_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid,                           -- NULL = applies to every scheme
  limit_description text NOT NULL CHECK (length(btrim(limit_description)) > 0),
  proposed_rule jsonb NOT NULL,                 -- rule definition in the rule engine's shape (M20, FE-04)
  rationale     text NOT NULL CHECK (length(btrim(rationale)) > 0),
  compliance_rule_id uuid,
  state         text NOT NULL DEFAULT 'DRAFT',
  requested_by  uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, request_id),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  CHECK (state NOT IN ('SENT_TO_COMPLIANCE','IN_FORCE') OR approval_request_id IS NOT NULL),
  CHECK (state <> 'IN_FORCE' OR compliance_rule_id IS NOT NULL)
);
CREATE TRIGGER internal_limit_request_version BEFORE UPDATE ON investment.internal_limit_request
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER internal_limit_request_actor BEFORE INSERT OR UPDATE ON investment.internal_limit_request
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('requested_by');
SELECT pg_temp.make_state_machine('investment', 'internal_limit_request', 'state', ARRAY['request_id'], ARRAY['uuid']);
INSERT INTO investment.internal_limit_request_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  ('DRAFT','SUBMITTED','STATE_CHANGE'),
  ('DRAFT','WITHDRAWN','STATE_CHANGE'),
  ('SUBMITTED','SENT_TO_COMPLIANCE','STATE_CHANGE'),
  ('SUBMITTED','REJECTED','STATE_CHANGE'),
  ('SENT_TO_COMPLIANCE','IN_FORCE','STATE_CHANGE'),
  ('SENT_TO_COMPLIANCE','REJECTED','STATE_CHANGE');

-- ---------------------------------------------------------------------
-- 03  portfolio  (Portfolio module, D04; DA-001 §4.7)
-- ---------------------------------------------------------------------

-- Portfolios and sub-portfolios per scheme.  A sub-portfolio belongs to the same scheme as its
-- parent (composite key with scheme_id).
CREATE TABLE portfolio.portfolio (
  tenant_id      uuid NOT NULL,
  portfolio_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id      uuid NOT NULL,
  parent_portfolio_id uuid,
  portfolio_code text NOT NULL,
  name           text NOT NULL,
  status         text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','CLOSED')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid DEFAULT platform.current_user_id(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  row_version    integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, portfolio_id),
  UNIQUE (tenant_id, scheme_id, portfolio_id),
  UNIQUE (tenant_id, scheme_id, portfolio_code),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, scheme_id, parent_portfolio_id) REFERENCES portfolio.portfolio (tenant_id, scheme_id, portfolio_id),
  CHECK (parent_portfolio_id IS NULL OR parent_portfolio_id <> portfolio_id)
);
CREATE UNIQUE INDEX portfolio_one_root_ux ON portfolio.portfolio (tenant_id, scheme_id) WHERE parent_portfolio_id IS NULL;
CREATE TRIGGER portfolio_version BEFORE UPDATE ON portfolio.portfolio FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE OR REPLACE FUNCTION portfolio.tg_portfolio_fixed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.scheme_id <> OLD.scheme_id OR NEW.parent_portfolio_id IS DISTINCT FROM OLD.parent_portfolio_id THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: a portfolio''s scheme and parent never change' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER portfolio_fixed BEFORE UPDATE ON portfolio.portfolio FOR EACH ROW EXECUTE FUNCTION portfolio.tg_portfolio_fixed();

-- Current position per portfolio and security (MU), kept equal to the sum of its open lots, and
-- each lot kept equal to the sum of its position events (checked at COMMIT, below).
CREATE TABLE portfolio.position (
  tenant_id     uuid NOT NULL,
  position_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  portfolio_id  uuid NOT NULL,
  security_id   uuid NOT NULL,
  quantity      numeric(24,6) NOT NULL DEFAULT 0,
  cost_amount   numeric(24,4) NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, position_id),
  UNIQUE (tenant_id, portfolio_id, security_id),
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES portfolio.portfolio (tenant_id, portfolio_id),
  FOREIGN KEY (tenant_id, security_id)  REFERENCES master.security (tenant_id, security_id)
);
CREATE TRIGGER position_version BEFORE UPDATE ON portfolio.position FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

CREATE TABLE portfolio.position_lot (
  tenant_id     uuid NOT NULL,
  lot_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  portfolio_id  uuid NOT NULL,
  security_id   uuid NOT NULL,
  quantity      numeric(24,6) NOT NULL,
  cost_amount   numeric(24,4) NOT NULL,
  acquired_on   date NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, lot_id),
  FOREIGN KEY (tenant_id, portfolio_id, security_id) REFERENCES portfolio.position (tenant_id, portfolio_id, security_id)
);
CREATE INDEX position_lot_position_ix ON portfolio.position_lot (tenant_id, portfolio_id, security_id);
CREATE TRIGGER position_lot_version BEFORE UPDATE ON portfolio.position_lot FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE OR REPLACE FUNCTION portfolio.tg_lot_fixed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: lots are never deleted; a closed lot keeps quantity 0' USING ERRCODE = '42501';
  END IF;
  IF NEW.portfolio_id <> OLD.portfolio_id OR NEW.security_id <> OLD.security_id OR NEW.acquired_on <> OLD.acquired_on THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: a lot''s portfolio, security and acquisition date never change' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER position_lot_fixed BEFORE UPDATE OR DELETE ON portfolio.position_lot FOR EACH ROW EXECUTE FUNCTION portfolio.tg_lot_fixed();

-- Every change to a lot, linked to its source (trade, corporate action, transfer; NFR-AUD-004).
-- Insert-only, monthly partitions (DA-001 §6.1).  Source types [ASSUMPTION — Q90].
CREATE TABLE portfolio.position_event (
  tenant_id         uuid NOT NULL,
  event_date        date NOT NULL,
  position_event_id uuid NOT NULL DEFAULT gen_random_uuid(),
  lot_id            uuid NOT NULL,
  source_type       text NOT NULL CHECK (source_type IN ('TRADE','CORPORATE_ACTION','TRANSFER','OPENING_BALANCE','CORRECTION')),
  source_id         uuid NOT NULL,              -- ID reference to the causing record (M4)
  quantity_change   numeric(24,6) NOT NULL,
  cost_change       numeric(24,4) NOT NULL,
  recorded_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  recorded_by       uuid DEFAULT platform.current_user_id(),
  PRIMARY KEY (tenant_id, event_date, position_event_id),
  FOREIGN KEY (tenant_id, lot_id) REFERENCES portfolio.position_lot (tenant_id, lot_id),
  CHECK (quantity_change <> 0 OR cost_change <> 0)
) PARTITION BY RANGE (event_date);
CREATE TABLE portfolio.position_event_2026_11 PARTITION OF portfolio.position_event FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE portfolio.position_event_2026_12 PARTITION OF portfolio.position_event FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE portfolio.position_event_default PARTITION OF portfolio.position_event DEFAULT;
CREATE INDEX position_event_lot_ix ON portfolio.position_event (tenant_id, lot_id);
SELECT pg_temp.make_insert_only('portfolio.position_event');

-- At COMMIT: each touched lot equals the sum of its events, and each touched position equals the
-- sum of its lots (quantity and cost).  Lots and positions therefore change only together with the
-- events that explain them (DA-001 §4.7: "each change has a position event").
CREATE OR REPLACE FUNCTION portfolio.tg_position_consistent() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_q numeric; v_c numeric; v_lq numeric; v_lc numeric; v_pf uuid; v_sec uuid;
BEGIN
  IF TG_TABLE_NAME LIKE 'position_event%' THEN
    SELECT portfolio_id, security_id INTO v_pf, v_sec FROM portfolio.position_lot WHERE tenant_id = NEW.tenant_id AND lot_id = NEW.lot_id;
  ELSE
    v_pf := NEW.portfolio_id; v_sec := NEW.security_id;
  END IF;
  -- lots of this position vs their events
  FOR v_lq, v_lc, v_q, v_c IN
    SELECT l.quantity, l.cost_amount, coalesce(sum(e.quantity_change), 0), coalesce(sum(e.cost_change), 0)
      FROM portfolio.position_lot l
      LEFT JOIN portfolio.position_event e ON e.tenant_id = l.tenant_id AND e.lot_id = l.lot_id
     WHERE l.tenant_id = NEW.tenant_id AND l.portfolio_id = v_pf AND l.security_id = v_sec
     GROUP BY l.lot_id, l.quantity, l.cost_amount
  LOOP
    IF v_lq <> v_q OR v_lc <> v_c THEN
      RAISE EXCEPTION 'POSITION_OUT_OF_STEP: a lot of portfolio % security % holds % / % but its events sum to % / %',
        v_pf, v_sec, v_lq, v_lc, v_q, v_c USING ERRCODE = '23514';
    END IF;
  END LOOP;
  SELECT coalesce(sum(quantity), 0), coalesce(sum(cost_amount), 0) INTO v_q, v_c FROM portfolio.position_lot
   WHERE tenant_id = NEW.tenant_id AND portfolio_id = v_pf AND security_id = v_sec;
  SELECT quantity, cost_amount INTO v_lq, v_lc FROM portfolio.position
   WHERE tenant_id = NEW.tenant_id AND portfolio_id = v_pf AND security_id = v_sec;
  IF v_lq IS DISTINCT FROM v_q OR v_lc IS DISTINCT FROM v_c THEN
    RAISE EXCEPTION 'POSITION_OUT_OF_STEP: position of portfolio % security % holds % / % but its lots sum to % / %',
      v_pf, v_sec, v_lq, v_lc, v_q, v_c USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER position_consistent AFTER INSERT OR UPDATE ON portfolio.position
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION portfolio.tg_position_consistent();
CREATE CONSTRAINT TRIGGER position_lot_consistent AFTER INSERT OR UPDATE ON portfolio.position_lot
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION portfolio.tg_position_consistent();
CREATE CONSTRAINT TRIGGER position_event_consistent AFTER INSERT ON portfolio.position_event
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION portfolio.tg_position_consistent();

-- Snapshots as a state machine (M14).  A FROZEN snapshot is unchangeable ("immutable once frozen",
-- DDL-000): it needs its content hash and freezing time; afterwards only FROZEN -> SUPERSEDED.
-- Its positions change only while it is DRAFT.
SELECT pg_temp.make_state_machine('portfolio', 'snapshot', 'status', ARRAY['snapshot_id'], ARRAY['uuid']);
INSERT INTO portfolio.snapshot_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  ('DRAFT','FROZEN','STATE_CHANGE'),
  ('FROZEN','SUPERSEDED','STATE_CHANGE');
ALTER TABLE portfolio.snapshot
  ADD CONSTRAINT snapshot_frozen_ck CHECK (status = 'DRAFT' OR (content_hash IS NOT NULL AND frozen_at IS NOT NULL));
CREATE OR REPLACE FUNCTION portfolio.tg_snapshot_frozen() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'DRAFT' THEN
      RAISE EXCEPTION 'IMMUTABLE_RECORD: snapshot % is %, it is never deleted', OLD.snapshot_id, OLD.status USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.status <> 'DRAFT' AND (to_jsonb(NEW) - 'status') IS DISTINCT FROM (to_jsonb(OLD) - 'status') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: snapshot % is %, its content cannot change', OLD.snapshot_id, OLD.status USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER snapshot_frozen BEFORE UPDATE OR DELETE ON portfolio.snapshot FOR EACH ROW EXECUTE FUNCTION portfolio.tg_snapshot_frozen();
ALTER TABLE portfolio.snapshot_position
  ADD CONSTRAINT snapshot_position_snapshot_fk FOREIGN KEY (tenant_id, snapshot_id) REFERENCES portfolio.snapshot (tenant_id, snapshot_id),
  ADD CONSTRAINT snapshot_position_security_fk FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id);
CREATE TRIGGER snapshot_position_draft_only BEFORE INSERT OR UPDATE OR DELETE ON portfolio.snapshot_position
  FOR EACH ROW EXECUTE FUNCTION platform.tg_parent_state_guard('portfolio.snapshot', 'status', 'DRAFT', 'tenant_id', 'snapshot_id');

-- Expected cash in and out per scheme and date (PRD-004 §10).  Amount is signed: + in, - out.
-- Flow types [ASSUMPTION — Q90].
CREATE TABLE portfolio.cash_ladder_entry (
  tenant_id     uuid NOT NULL,
  entry_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid NOT NULL,
  value_date    date NOT NULL,
  flow_type     text NOT NULL CHECK (flow_type IN ('SUBSCRIPTION','REDEMPTION','TRADE_SETTLEMENT','INCOME','EXPENSE','DISTRIBUTION','OTHER')),
  amount        numeric(24,4) NOT NULL CHECK (amount <> 0),
  currency_code char(3) NOT NULL DEFAULT 'INR' REFERENCES master.currency,
  source_type   text,
  source_id     uuid,                           -- ID reference (M4)
  status        text NOT NULL DEFAULT 'EXPECTED' CHECK (status IN ('EXPECTED','CONFIRMED','CANCELLED')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by    uuid DEFAULT platform.current_user_id(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, entry_id),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  CHECK ((source_type IS NULL) = (source_id IS NULL))
);
CREATE INDEX cash_ladder_scheme_date_ix ON portfolio.cash_ladder_entry (tenant_id, scheme_id, value_date) WHERE status <> 'CANCELLED';
CREATE TRIGGER cash_ladder_entry_version BEFORE UPDATE ON portfolio.cash_ladder_entry FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Model portfolios (VR) and their target lines (part of the version).
CREATE TABLE portfolio.model_portfolio (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  model_id      uuid NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  name          text NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, model_id, version_no),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  EXCLUDE USING gist (tenant_id WITH =, model_id WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);
SELECT pg_temp.make_vr('portfolio', 'model_portfolio', ARRAY['model_id','version_no'], ARRAY['uuid','integer']);
CREATE TABLE portfolio.model_portfolio_line (
  tenant_id     uuid NOT NULL,
  model_id      uuid NOT NULL,
  version_no    integer NOT NULL,
  security_id   uuid NOT NULL,
  target_weight_pct numeric(12,8) NOT NULL CHECK (target_weight_pct >= 0 AND target_weight_pct <= 100),
  PRIMARY KEY (tenant_id, model_id, version_no, security_id),
  FOREIGN KEY (tenant_id, model_id, version_no) REFERENCES portfolio.model_portfolio (tenant_id, model_id, version_no),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id)
);
CREATE TRIGGER model_portfolio_line_draft_only BEFORE INSERT OR UPDATE OR DELETE ON portfolio.model_portfolio_line
  FOR EACH ROW EXECUTE FUNCTION platform.tg_parent_state_guard('portfolio.model_portfolio', 'status', 'DRAFT',
                                                               'tenant_id', 'model_id', 'version_no');

-- Proposed orders from a rebalance, before they become OMS orders (PRD-004 §10).
-- States [ASSUMPTION — Q90].  Lines change only while the proposal is DRAFT.
CREATE TABLE portfolio.rebalance_proposal (
  tenant_id     uuid NOT NULL,
  proposal_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  portfolio_id  uuid NOT NULL,
  model_id      uuid NOT NULL,
  model_version_no integer NOT NULL,
  snapshot_id   uuid,
  state         text NOT NULL DEFAULT 'DRAFT',
  proposed_by   uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, proposal_id),
  FOREIGN KEY (tenant_id, portfolio_id) REFERENCES portfolio.portfolio (tenant_id, portfolio_id),
  FOREIGN KEY (tenant_id, model_id, model_version_no) REFERENCES portfolio.model_portfolio (tenant_id, model_id, version_no),
  FOREIGN KEY (tenant_id, snapshot_id) REFERENCES portfolio.snapshot (tenant_id, snapshot_id),
  CHECK (state NOT IN ('ACCEPTED','CONVERTED') OR approval_request_id IS NOT NULL)
);
CREATE TRIGGER rebalance_proposal_version BEFORE UPDATE ON portfolio.rebalance_proposal FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER rebalance_proposal_actor BEFORE INSERT OR UPDATE ON portfolio.rebalance_proposal
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('proposed_by');
SELECT pg_temp.make_state_machine('portfolio', 'rebalance_proposal', 'state', ARRAY['proposal_id'], ARRAY['uuid']);
INSERT INTO portfolio.rebalance_proposal_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  ('DRAFT','SUBMITTED','STATE_CHANGE'),
  ('DRAFT','WITHDRAWN','STATE_CHANGE'),
  ('SUBMITTED','ACCEPTED','STATE_CHANGE'),
  ('SUBMITTED','REJECTED','STATE_CHANGE'),
  ('ACCEPTED','CONVERTED','STATE_CHANGE');
CREATE TABLE portfolio.rebalance_proposal_line (
  tenant_id     uuid NOT NULL,
  proposal_id   uuid NOT NULL,
  line_no       integer NOT NULL CHECK (line_no > 0),
  security_id   uuid NOT NULL,
  side          text NOT NULL CHECK (side IN ('BUY','SELL')),
  quantity      numeric(24,6) CHECK (quantity > 0),
  amount        numeric(24,4) CHECK (amount > 0),
  order_id      uuid,                           -- ID reference to trading."order" once raised (M4)
  PRIMARY KEY (tenant_id, proposal_id, line_no),
  FOREIGN KEY (tenant_id, proposal_id) REFERENCES portfolio.rebalance_proposal (tenant_id, proposal_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  CHECK ((quantity IS NOT NULL) <> (amount IS NOT NULL))
);
CREATE TRIGGER rebalance_proposal_line_draft_only BEFORE INSERT OR DELETE ON portfolio.rebalance_proposal_line
  FOR EACH ROW EXECUTE FUNCTION platform.tg_parent_state_guard('portfolio.rebalance_proposal', 'state', 'DRAFT',
                                                               'tenant_id', 'proposal_id');
-- Updates: any column while the proposal is DRAFT; once ACCEPTED only the link to the raised order
-- may be filled in (once); never in other states.
CREATE OR REPLACE FUNCTION portfolio.tg_rebalance_line_update() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_state text;
BEGIN
  SELECT state INTO v_state FROM portfolio.rebalance_proposal
   WHERE tenant_id = OLD.tenant_id AND proposal_id = OLD.proposal_id FOR SHARE;
  IF v_state = 'DRAFT' AND NEW.proposal_id = OLD.proposal_id AND NEW.line_no = OLD.line_no THEN
    RETURN NEW;
  END IF;
  IF v_state = 'ACCEPTED' AND OLD.order_id IS NULL AND NEW.order_id IS NOT NULL
     AND (to_jsonb(NEW) - 'order_id') = (to_jsonb(OLD) - 'order_id') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'PARENT_FROZEN: rebalance proposal % is %; this line change is not allowed', OLD.proposal_id, v_state
    USING ERRCODE = '23514';
END $$;
CREATE TRIGGER rebalance_proposal_line_update BEFORE UPDATE ON portfolio.rebalance_proposal_line
  FOR EACH ROW EXECUTE FUNCTION portfolio.tg_rebalance_line_update();

-- Performance runs and results (FE-10; M13: every result names the run, its input manifest and
-- engine version).  Run states [ASSUMPTION — Q90].  The manifest and engine version are fixed once
-- the run starts; results are added only while the run is RUNNING.
CREATE TABLE portfolio.performance_run (
  tenant_id      uuid NOT NULL REFERENCES platform.tenant,
  performance_run_id uuid NOT NULL DEFAULT gen_random_uuid(),
  period         daterange NOT NULL CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period)),
  input_manifest jsonb NOT NULL,                -- M13, M20
  engine_version text NOT NULL CHECK (engine_version ~ '^FE-10@'),
  state          text NOT NULL DEFAULT 'REQUESTED',
  requested_by   uuid NOT NULL,
  started_at     timestamptz,
  finished_at    timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  row_version    integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, performance_run_id),
  CHECK (state = 'REQUESTED' OR started_at IS NOT NULL),
  CHECK (state NOT IN ('COMPLETED','FAILED','SUPERSEDED') OR finished_at IS NOT NULL)
);
CREATE TRIGGER performance_run_version BEFORE UPDATE ON portfolio.performance_run FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER performance_run_actor BEFORE INSERT OR UPDATE ON portfolio.performance_run
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('requested_by');
CREATE OR REPLACE FUNCTION portfolio.tg_performance_run_fixed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.state <> 'REQUESTED' AND (NEW.input_manifest IS DISTINCT FROM OLD.input_manifest
       OR NEW.engine_version <> OLD.engine_version OR NEW.period <> OLD.period
       OR NEW.started_at IS DISTINCT FROM OLD.started_at) THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: performance run % has started; its inputs cannot change', OLD.performance_run_id
      USING ERRCODE = '42501';
  END IF;
  IF OLD.state IN ('COMPLETED','FAILED','SUPERSEDED') AND NEW.finished_at IS DISTINCT FROM OLD.finished_at THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: performance run % has finished', OLD.performance_run_id USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER performance_run_fixed BEFORE UPDATE ON portfolio.performance_run FOR EACH ROW EXECUTE FUNCTION portfolio.tg_performance_run_fixed();
SELECT pg_temp.make_state_machine('portfolio', 'performance_run', 'state', ARRAY['performance_run_id'], ARRAY['uuid']);
INSERT INTO portfolio.performance_run_transition (from_state, to_state, cause) VALUES
  ('(NEW)','REQUESTED','CREATE'),
  ('REQUESTED','RUNNING','STATE_CHANGE'),
  ('RUNNING','COMPLETED','STATE_CHANGE'),
  ('RUNNING','FAILED','STATE_CHANGE'),
  ('COMPLETED','SUPERSEDED','STATE_CHANGE');

-- Return kinds and the scale of returns are set by the FE-10 specification (Step 21); numeric(20,10)
-- is a placeholder of the "ratio" kind recorded for DBE-001 (DA-001 §3.7 last paragraph).
CREATE TABLE portfolio.performance_result (
  tenant_id      uuid NOT NULL,
  result_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  performance_run_id uuid NOT NULL,
  scheme_id      uuid NOT NULL,
  plan_id        uuid,
  period         daterange NOT NULL CHECK (NOT isempty(period) AND NOT lower_inf(period) AND NOT upper_inf(period)),
  return_kind    text NOT NULL,
  return_value   numeric(20,10) NOT NULL,
  benchmark_id   uuid,
  benchmark_return numeric(20,10),
  engine_version text NOT NULL CHECK (engine_version ~ '^FE-10@'),
  recorded_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, result_id),
  UNIQUE NULLS NOT DISTINCT (tenant_id, performance_run_id, scheme_id, plan_id, period, return_kind),
  FOREIGN KEY (tenant_id, performance_run_id) REFERENCES portfolio.performance_run (tenant_id, performance_run_id),
  FOREIGN KEY (tenant_id, scheme_id)    REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, plan_id)      REFERENCES product.plan (tenant_id, plan_id),
  FOREIGN KEY (tenant_id, benchmark_id) REFERENCES master.benchmark (tenant_id, benchmark_id),
  CHECK ((benchmark_id IS NULL) = (benchmark_return IS NULL))
);
SELECT pg_temp.make_insert_only('portfolio.performance_result');
CREATE TRIGGER performance_result_while_running BEFORE INSERT ON portfolio.performance_result
  FOR EACH ROW EXECUTE FUNCTION platform.tg_parent_state_guard('portfolio.performance_run', 'state', 'RUNNING',
                                                               'tenant_id', 'performance_run_id');
CREATE OR REPLACE FUNCTION portfolio.tg_performance_result_engine() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM portfolio.performance_run r WHERE r.tenant_id = NEW.tenant_id
                   AND r.performance_run_id = NEW.performance_run_id AND r.engine_version = NEW.engine_version
                   AND r.period @> NEW.period) THEN
    RAISE EXCEPTION 'RUN_MISMATCH: a result must carry its run''s engine version and lie inside its period'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER performance_result_engine BEFORE INSERT ON portfolio.performance_result
  FOR EACH ROW EXECUTE FUNCTION portfolio.tg_performance_result_engine();

CREATE TABLE portfolio.attribution_result (
  tenant_id     uuid NOT NULL,
  result_id     uuid NOT NULL,
  factor_code   text NOT NULL,
  contribution  numeric(20,10) NOT NULL,
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, result_id, factor_code),
  FOREIGN KEY (tenant_id, result_id) REFERENCES portfolio.performance_result (tenant_id, result_id)
);
SELECT pg_temp.make_insert_only('portfolio.attribution_result');
CREATE OR REPLACE FUNCTION portfolio.tg_attribution_while_running() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM portfolio.performance_result p
                   JOIN portfolio.performance_run r ON r.tenant_id = p.tenant_id AND r.performance_run_id = p.performance_run_id
                  WHERE p.tenant_id = NEW.tenant_id AND p.result_id = NEW.result_id AND r.state = 'RUNNING') THEN
    RAISE EXCEPTION 'PARENT_FROZEN: attribution rows are added only while their performance run is RUNNING'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER attribution_result_while_running BEFORE INSERT ON portfolio.attribution_result
  FOR EACH ROW EXECUTE FUNCTION portfolio.tg_attribution_while_running();

-- Exposure by issuer, group and sector (DER), from the latest FROZEN snapshot of each scheme and the
-- security and issuer versions current on the snapshot date as known now.  security_invoker: the
-- reader's own row-level security applies.  Ratings are added with the FE-07 / FE-08 specifications.
CREATE VIEW portfolio.exposure_view WITH (security_invoker = true) AS
SELECT s.tenant_id, s.scheme_id, s.as_of_date, s.snapshot_id,
       sv.issuer_id, iv.group_id, iv.sector_code, sv.market_cap_class,
       sum(p.market_value) AS market_value,
       sum(p.pct_net_assets) AS pct_net_assets
  FROM portfolio.snapshot s
  JOIN portfolio.snapshot_position p ON p.tenant_id = s.tenant_id AND p.snapshot_id = s.snapshot_id AND p.as_of_date = s.as_of_date
  LEFT JOIN master.security_version sv ON sv.tenant_id = p.tenant_id AND sv.security_id = p.security_id
        AND sv.superseded_at IS NULL AND sv.valid_period @> s.as_of_date
  LEFT JOIN master.issuer_version iv ON iv.tenant_id = sv.tenant_id AND iv.issuer_id = sv.issuer_id
        AND iv.superseded_at IS NULL AND iv.valid_period @> s.as_of_date
 WHERE s.status = 'FROZEN'
   AND s.as_of_date = (SELECT max(s2.as_of_date) FROM portfolio.snapshot s2
                        WHERE s2.tenant_id = s.tenant_id AND s2.scheme_id = s.scheme_id AND s2.status = 'FROZEN')
 GROUP BY s.tenant_id, s.scheme_id, s.as_of_date, s.snapshot_id, sv.issuer_id, iv.group_id, iv.sector_code, sv.market_cap_class;

-- ---------------------------------------------------------------------
-- 04  trading  (OMS module, D05; DA-001 §4.8)
-- ---------------------------------------------------------------------

-- DM-5: the transition table gets a cause and an initial-state row; the self-move
-- PARTIALLY_FILLED -> PARTIALLY_FILLED is removed (a further fill only raises filled_quantity).
-- DM-6 [ASSUMPTION — owner Q81]: AMEND from COMPLIANCE_BLOCKED and PENDING_APPROVAL back to
-- PENDING_COMPLIANCE; REROUTE from REJECTED_BY_BROKER to PENDING_COMPLIANCE.  The name stays
-- trading.order_state_transition (DA-001 §4.8).
DELETE FROM trading.order_state_transition WHERE from_state = to_state;
ALTER TABLE trading.order_state_transition
  ADD COLUMN cause text NOT NULL DEFAULT 'STATE_CHANGE' CHECK (cause ~ '^[A-Z_]+$'),
  DROP CONSTRAINT order_state_transition_pkey,
  ADD PRIMARY KEY (from_state, to_state, cause),
  ADD CONSTRAINT order_state_transition_new_ck CHECK (to_state <> '(NEW)' AND from_state <> to_state
                                                       AND (from_state = '(NEW)') = (cause = 'CREATE'));
ALTER TABLE trading.order_state_transition ALTER COLUMN cause DROP DEFAULT;
INSERT INTO trading.order_state_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  ('COMPLIANCE_BLOCKED','PENDING_COMPLIANCE','AMEND'),
  ('PENDING_APPROVAL','PENDING_COMPLIANCE','AMEND'),
  ('REJECTED_BY_BROKER','PENDING_COMPLIANCE','REROUTE');
COMMENT ON TABLE trading.order_state_transition IS
  'Product-level list of allowed order moves with cause (DA-001 M3, M14, DM-5, DM-6). No tenant column; read-only for application roles.';

-- Each version of the order's terms (DM-6, BRL-D05-004).  Written only by the order's own trigger.
CREATE TABLE trading.order_version (
  tenant_id     uuid NOT NULL,
  order_id      uuid NOT NULL,
  order_version integer NOT NULL CHECK (order_version > 0),
  order_type    text NOT NULL,
  quantity      numeric(24,6),
  amount        numeric(24,4),
  limit_price   numeric(24,8),
  time_in_force text NOT NULL,
  cause         text NOT NULL CHECK (cause IN ('CREATE','DRAFT_EDIT','AMEND','REROUTE')),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  recorded_by   uuid,
  PRIMARY KEY (tenant_id, order_id, order_version),
  FOREIGN KEY (tenant_id, order_id) REFERENCES trading.order (tenant_id, order_id)
);
SELECT pg_temp.make_insert_only('trading.order_version');
CREATE TRIGGER order_version_via_trigger BEFORE INSERT ON trading.order_version
  FOR EACH ROW EXECUTE FUNCTION platform.tg_written_by_trigger_only();
ALTER TABLE trading.order_event ADD COLUMN cause text;

-- The order's state machine, now with causes (replaces DDL-000's trading.tg_order_state):
--   * a new order starts in DRAFT at version 1 ((NEW) -> DRAFT, cause CREATE);
--   * a state move must match (from, to, cause), cause from app.transition_cause (default STATE_CHANGE);
--   * the scheme, security, side, decision, author, trade date and idempotency key never change;
--   * the terms (type, quantity, amount, limit price, time in force) change only with a new version
--     (order_version + 1), and a new version needs either a DRAFT order (no state move: it has not
--     been checked yet) or a move with cause AMEND or REROUTE (DM-6), which sends it back to
--     PENDING_COMPLIANCE so the old version's compliance result never covers the new one;
--   * an amend while PENDING_COMPLIANCE (no check result yet) is a new version with cause AMEND and
--     no state move [ASSUMPTION — owner Q81, DM-6 lists PENDING_COMPLIANCE among amendable states];
--   * filled_quantity never goes down (DM-5).
CREATE OR REPLACE FUNCTION trading.tg_order_state() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_cause   text := coalesce(NULLIF(current_setting('app.transition_cause', true), ''), 'STATE_CHANGE');
  v_terms   boolean;
  v_new_ver boolean;
  v_outcome text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NOT EXISTS (SELECT 1 FROM trading.order_state_transition
                    WHERE from_state = '(NEW)' AND to_state = NEW.state AND cause = 'CREATE') OR NEW.order_version <> 1 THEN
      RAISE EXCEPTION 'ILLEGAL_ORDER_TRANSITION: an order starts in DRAFT at version 1 (got % / %)', NEW.state, NEW.order_version
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.scheme_id <> OLD.scheme_id OR NEW.security_id <> OLD.security_id OR NEW.side <> OLD.side
     OR NEW.decision_id <> OLD.decision_id OR NEW.created_by <> OLD.created_by OR NEW.trade_date <> OLD.trade_date
     OR NEW.idempotency_key <> OLD.idempotency_key OR NEW.created_at <> OLD.created_at THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: an order''s scheme, security, side, decision, author, trade date and key never change'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.filled_quantity < OLD.filled_quantity THEN
    RAISE EXCEPTION 'ILLEGAL_ORDER_CHANGE: filled quantity cannot go down' USING ERRCODE = '23514';
  END IF;
  v_terms := (NEW.order_type, NEW.quantity, NEW.amount, NEW.limit_price, NEW.time_in_force)
             IS DISTINCT FROM (OLD.order_type, OLD.quantity, OLD.amount, OLD.limit_price, OLD.time_in_force);
  IF NEW.order_version <> OLD.order_version AND NEW.order_version <> OLD.order_version + 1 THEN
    RAISE EXCEPTION 'ILLEGAL_ORDER_CHANGE: order_version moves by one' USING ERRCODE = '23514';
  END IF;
  v_new_ver := NEW.order_version = OLD.order_version + 1;
  IF v_terms AND NOT v_new_ver THEN
    RAISE EXCEPTION 'ILLEGAL_ORDER_CHANGE: changed terms need a new order version (DM-6)' USING ERRCODE = '23514';
  END IF;
  IF v_cause IN ('AMEND','REROUTE') AND NOT v_new_ver THEN
    RAISE EXCEPTION 'ILLEGAL_ORDER_CHANGE: % needs a new order version (DM-6)', v_cause USING ERRCODE = '23514';
  END IF;
  IF NEW.state IS NOT DISTINCT FROM OLD.state THEN
    IF v_new_ver AND NOT (OLD.state = 'DRAFT' OR (OLD.state = 'PENDING_COMPLIANCE' AND v_cause = 'AMEND')) THEN
      RAISE EXCEPTION 'ILLEGAL_ORDER_CHANGE: a new version of a % order needs a move with cause AMEND or REROUTE', OLD.state
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM trading.order_state_transition
                  WHERE from_state = OLD.state AND to_state = NEW.state AND cause = v_cause) THEN
    RAISE EXCEPTION 'ILLEGAL_ORDER_TRANSITION: % -> % (cause %)', OLD.state, NEW.state, v_cause USING ERRCODE = '23514';
  END IF;
  IF v_new_ver AND v_cause NOT IN ('AMEND','REROUTE') THEN
    RAISE EXCEPTION 'ILLEGAL_ORDER_CHANGE: a new version with a state move needs cause AMEND or REROUTE' USING ERRCODE = '23514';
  END IF;
  -- DM-6: leaving the compliance check (PENDING_COMPLIANCE -> PENDING_APPROVAL / COMPLIANCE_BLOCKED,
  -- OVERRIDE_APPROVED -> PENDING_APPROVAL) needs a pre-trade result for the CURRENT version, so the
  -- result of an older version never covers a newer one (also when an amend raced a running check),
  -- and the move must fit the outcome (PRD-008 BRL-D08-008: INDETERMINATE counts as BLOCK pre-trade;
  -- PRD-005 §10: a WARN needs a person's acknowledgement):
  --   PENDING_COMPLIANCE -> PENDING_APPROVAL  : PASS, or WARN with a warn_acknowledgement
  --   PENDING_COMPLIANCE -> COMPLIANCE_BLOCKED: BLOCK or INDETERMINATE
  --   OVERRIDE_APPROVED  -> PENDING_APPROVAL  : BLOCK or INDETERMINATE (the override covers it)
  IF OLD.state IN ('PENDING_COMPLIANCE','OVERRIDE_APPROVED') AND NEW.state IN ('PENDING_APPROVAL','COMPLIANCE_BLOCKED') THEN
    SELECT r.outcome INTO v_outcome FROM trading.compliance_result_ref r
     WHERE r.tenant_id = NEW.tenant_id AND r.order_id = NEW.order_id
       AND r.order_version = NEW.order_version AND r.check_kind = 'PRE_TRADE';
    IF v_outcome IS NULL THEN
      RAISE EXCEPTION 'NO_COMPLIANCE_RESULT: order % version % has no pre-trade result', NEW.order_id, NEW.order_version
        USING ERRCODE = '23514';
    END IF;
    IF NOT (CASE
         WHEN OLD.state = 'PENDING_COMPLIANCE' AND NEW.state = 'PENDING_APPROVAL' THEN
              v_outcome = 'PASS'
              OR (v_outcome = 'WARN' AND EXISTS (SELECT 1 FROM trading.warn_acknowledgement a
                                                  WHERE a.tenant_id = NEW.tenant_id AND a.order_id = NEW.order_id
                                                    AND a.order_version = NEW.order_version AND a.check_kind = 'PRE_TRADE'))
         ELSE v_outcome IN ('BLOCK','INDETERMINATE') END) THEN
      RAISE EXCEPTION 'COMPLIANCE_OUTCOME: order % version % has pre-trade outcome %; % -> % is not allowed',
        NEW.order_id, NEW.order_version, v_outcome, OLD.state, NEW.state USING ERRCODE = '23514';
    END IF;
  END IF;
  -- Every state change is recorded as an order event (same transaction), now with its cause.
  INSERT INTO trading.order_event (tenant_id, order_id, order_version, from_state, to_state, actor_user_id, cause)
  VALUES (NEW.tenant_id, NEW.order_id, NEW.order_version, OLD.state, NEW.state, platform.current_user_id(), v_cause);
  RETURN NEW;
END $$;
DROP TRIGGER order_state_machine ON trading.order;
CREATE TRIGGER order_state_machine BEFORE INSERT OR UPDATE ON trading.order
  FOR EACH ROW EXECUTE FUNCTION trading.tg_order_state();

CREATE OR REPLACE FUNCTION trading.tg_order_version_row() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.order_version = OLD.order_version THEN RETURN NULL; END IF;
  INSERT INTO trading.order_version (tenant_id, order_id, order_version, order_type, quantity, amount, limit_price,
                                     time_in_force, cause, recorded_by)
  VALUES (NEW.tenant_id, NEW.order_id, NEW.order_version, NEW.order_type, NEW.quantity, NEW.amount, NEW.limit_price,
          NEW.time_in_force,
          CASE WHEN TG_OP = 'INSERT' THEN 'CREATE'
               WHEN OLD.state = 'DRAFT' AND NEW.state = 'DRAFT' THEN 'DRAFT_EDIT'
               ELSE coalesce(NULLIF(current_setting('app.transition_cause', true), ''), 'STATE_CHANGE') END,
          platform.current_user_id());
  RETURN NULL;
END $$;
CREATE TRIGGER order_version_row AFTER INSERT OR UPDATE ON trading.order
  FOR EACH ROW EXECUTE FUNCTION trading.tg_order_version_row();

-- Blocks of orders sent together (PRD-005 §10).  States [ASSUMPTION — Q90].
CREATE TABLE trading.block (
  tenant_id     uuid NOT NULL,
  block_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  security_id   uuid NOT NULL,
  side          text NOT NULL CHECK (side IN ('BUY','SELL')),
  trade_date    date NOT NULL,
  state         text NOT NULL DEFAULT 'OPEN',
  created_at    timestamptz NOT NULL DEFAULT now(),
  created_by    uuid DEFAULT platform.current_user_id(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, block_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id)
);
CREATE TRIGGER block_version BEFORE UPDATE ON trading.block FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('trading', 'block', 'state', ARRAY['block_id'], ARRAY['uuid']);
INSERT INTO trading.block_transition (from_state, to_state, cause) VALUES
  ('(NEW)','OPEN','CREATE'),
  ('OPEN','ROUTED','STATE_CHANGE'),
  ('OPEN','CANCELLED','STATE_CHANGE'),
  ('ROUTED','PARTIALLY_FILLED','STATE_CHANGE'),
  ('ROUTED','FILLED','STATE_CHANGE'),
  ('ROUTED','CANCELLED','STATE_CHANGE'),
  ('PARTIALLY_FILLED','FILLED','STATE_CHANGE'),
  ('PARTIALLY_FILLED','CANCELLED','STATE_CHANGE'),
  ('FILLED','ALLOCATED','STATE_CHANGE');
-- The intended split points at its block (DDL-000 had no key on block_id).  Its result columns
-- move to execution.allocation with ADR-0020 (DM-7) and stay here until then.
ALTER TABLE trading.block_allocation
  ADD CONSTRAINT block_allocation_block_fk FOREIGN KEY (tenant_id, block_id) REFERENCES trading.block (tenant_id, block_id);

-- Reference to Compliance's check result for each order version (ID reference, M4).
-- Outcome values as compliance.check_result (DDL-000).  Insert-only.
CREATE TABLE trading.compliance_result_ref (
  tenant_id       uuid NOT NULL,
  order_id        uuid NOT NULL,
  order_version   integer NOT NULL,
  check_kind      text NOT NULL CHECK (check_kind IN ('PRE_TRADE','POST_TRADE','WHAT_IF')),
  check_result_id uuid NOT NULL,
  checked_on      date NOT NULL,                -- partition key of compliance.check_result
  outcome         text NOT NULL CHECK (outcome IN ('PASS','WARN','BLOCK','INDETERMINATE')),
  recorded_at     timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, order_id, order_version, check_kind),
  FOREIGN KEY (tenant_id, order_id, order_version) REFERENCES trading.order_version (tenant_id, order_id, order_version)
);
SELECT pg_temp.make_insert_only('trading.compliance_result_ref');

-- A person's acknowledgement of a WARN result of the same order version (PRD-005 §10).
CREATE TABLE trading.warn_acknowledgement (
  tenant_id     uuid NOT NULL,
  ack_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL,
  order_version integer NOT NULL,
  check_kind    text NOT NULL,
  user_id       uuid NOT NULL,
  reason        text NOT NULL CHECK (length(btrim(reason)) > 0),
  acknowledged_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, ack_id),
  FOREIGN KEY (tenant_id, order_id, order_version, check_kind)
    REFERENCES trading.compliance_result_ref (tenant_id, order_id, order_version, check_kind)
);
SELECT pg_temp.make_insert_only('trading.warn_acknowledgement');
CREATE TRIGGER warn_acknowledgement_actor BEFORE INSERT ON trading.warn_acknowledgement
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('user_id');
CREATE OR REPLACE FUNCTION trading.tg_warn_ack_check() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM trading.compliance_result_ref r
                  WHERE r.tenant_id = NEW.tenant_id AND r.order_id = NEW.order_id AND r.order_version = NEW.order_version
                    AND r.check_kind = NEW.check_kind AND r.outcome = 'WARN') THEN
    RAISE EXCEPTION 'NOT_A_WARNING: order % version % has no WARN result to acknowledge', NEW.order_id, NEW.order_version
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER warn_acknowledgement_check BEFORE INSERT ON trading.warn_acknowledgement
  FOR EACH ROW EXECUTE FUNCTION trading.tg_warn_ack_check();

-- Quotes received in a request for quote (PRD-005 §10).  broker_id is an ID reference to
-- execution.broker (M4).  Insert-only.
CREATE TABLE trading.rfq_quote (
  tenant_id     uuid NOT NULL,
  quote_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL,
  order_version integer NOT NULL,
  broker_id     uuid NOT NULL,
  price         numeric(24,8) NOT NULL CHECK (price > 0),
  quantity      numeric(24,6) NOT NULL CHECK (quantity > 0),
  yield_pct     numeric(12,8),
  quoted_at     timestamptz NOT NULL,
  valid_until   timestamptz,
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  recorded_by   uuid DEFAULT platform.current_user_id(),
  PRIMARY KEY (tenant_id, quote_id),
  FOREIGN KEY (tenant_id, order_id, order_version) REFERENCES trading.order_version (tenant_id, order_id, order_version),
  CHECK (valid_until IS NULL OR valid_until > quoted_at)
);
SELECT pg_temp.make_insert_only('trading.rfq_quote');

-- ---------------------------------------------------------------------
-- 05  execution  (Execution module, D06; DA-001 §4.9) - without execution.trade and
--     execution.allocation (DM-7, ADR-0020)
-- ---------------------------------------------------------------------
SELECT pg_temp.make_load_run('execution');

-- Broker-specific data keyed to the counterparty record (T5): anchor + versions.
-- Empanelment states [ASSUMPTION — Q90].
CREATE TABLE execution.broker (
  tenant_id       uuid NOT NULL REFERENCES platform.tenant,
  broker_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  counterparty_id uuid NOT NULL,
  broker_code     text NOT NULL,                -- never changes; a new code is a new broker record
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, broker_id),
  UNIQUE (tenant_id, broker_code),
  FOREIGN KEY (tenant_id, counterparty_id) REFERENCES master.counterparty (tenant_id, counterparty_id)
);
SELECT pg_temp.make_insert_only('execution.broker');
CREATE TABLE execution.broker_version (
  tenant_id     uuid NOT NULL,
  broker_id     uuid NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  empanelment_status text NOT NULL CHECK (empanelment_status IN ('APPLIED','EMPANELLED','SUSPENDED','TERMINATED')),
  segments      text[] NOT NULL DEFAULT '{}',   -- market segments the broker is used for
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, broker_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, broker_id) REFERENCES execution.broker (tenant_id, broker_id),
  EXCLUDE USING gist (tenant_id WITH =, broker_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('execution.broker_version', ARRAY['tenant_id','broker_id']);

-- Broker limits and brokerage rates (BT, rule 2; D-29).  Limit types and rate values are data.
CREATE TABLE execution.broker_limit (
  tenant_id     uuid NOT NULL,
  broker_id     uuid NOT NULL,
  limit_type    text NOT NULL CHECK (limit_type ~ '^[A-Z][A-Z0-9_]{1,40}$'),
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  limit_amount  numeric(24,4) NOT NULL CHECK (limit_amount >= 0),
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, broker_id, limit_type, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, broker_id) REFERENCES execution.broker (tenant_id, broker_id),
  EXCLUDE USING gist (tenant_id WITH =, broker_id WITH =, limit_type WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('execution.broker_limit', ARRAY['tenant_id','broker_id','limit_type']);

-- rate_pct: a rate kind; its scale is confirmed by the FE-06 specification (DA-001 §3.7).
CREATE TABLE execution.brokerage_rate (
  tenant_id        uuid NOT NULL,
  broker_id        uuid NOT NULL,
  instrument_class text NOT NULL,
  valid_period     daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at    timestamptz,
  rate_pct         numeric(12,8) NOT NULL CHECK (rate_pct >= 0),
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, broker_id, instrument_class, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, broker_id) REFERENCES execution.broker (tenant_id, broker_id),
  EXCLUDE USING gist (tenant_id WITH =, broker_id WITH =, instrument_class WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('execution.brokerage_rate', ARRAY['tenant_id','broker_id','instrument_class']);

-- STT, stamp duty, GST and exchange-fee rates (D-29, T6: maker Operations, checker Compliance,
-- through the approval reference).  Rates are data [REG / VAL per tenant]; none is set here.
CREATE TABLE execution.trade_charge_rate (
  tenant_id        uuid NOT NULL REFERENCES platform.tenant,
  charge_type      text NOT NULL CHECK (charge_type IN ('STT','STAMP_DUTY','GST','EXCHANGE_FEE')),
  instrument_class text NOT NULL,
  side             text NOT NULL CHECK (side IN ('BUY','SELL','BOTH')),
  valid_period     daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at    timestamptz,
  rate_pct         numeric(12,8) NOT NULL CHECK (rate_pct >= 0),
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, charge_type, instrument_class, side, valid_period, recorded_at),
  EXCLUDE USING gist (tenant_id WITH =, charge_type WITH =, instrument_class WITH =, side WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('execution.trade_charge_rate', ARRAY['tenant_id','charge_type','instrument_class','side']);

-- Periodic broker evaluations (PRD-006 §10).  Insert-only.
CREATE TABLE execution.broker_evaluation (
  tenant_id     uuid NOT NULL,
  evaluation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  broker_id     uuid NOT NULL,
  period_start  date NOT NULL,
  period_end    date NOT NULL,
  outcome       text NOT NULL,
  document_id   uuid,                           -- ID reference (M4)
  evaluated_by  uuid NOT NULL,
  approval_request_id uuid NOT NULL,
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, evaluation_id),
  FOREIGN KEY (tenant_id, broker_id) REFERENCES execution.broker (tenant_id, broker_id),
  CHECK (period_end >= period_start)
);
SELECT pg_temp.make_insert_only('execution.broker_evaluation');
CREATE TRIGGER broker_evaluation_actor BEFORE INSERT ON execution.broker_evaluation
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('evaluated_by');

-- Outbound-instruction pattern (DA-001 §3.5, INT-001 §6): two separate state machines on one row.
-- delivery_state: did the provider get it? (INT-001 §6 diagram, [DES]).  Shared by every
-- instruction table in this file.
CREATE FUNCTION pg_temp.add_delivery_transitions(p_table text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('INSERT INTO %s (from_state, to_state, cause) VALUES
      (''(NEW)'',''READY'',''CREATE''),
      (''READY'',''SENT'',''STATE_CHANGE''),
      (''SENT'',''ACKNOWLEDGED'',''STATE_CHANGE''),
      (''SENT'',''UNKNOWN_OUTCOME'',''STATE_CHANGE''),
      (''UNKNOWN_OUTCOME'',''ACKNOWLEDGED'',''STATE_CHANGE''),
      (''UNKNOWN_OUTCOME'',''READY'',''STATE_CHANGE''),
      (''UNKNOWN_OUTCOME'',''INVESTIGATION'',''STATE_CHANGE''),
      (''INVESTIGATION'',''ACKNOWLEDGED'',''STATE_CHANGE''),
      (''INVESTIGATION'',''READY'',''STATE_CHANGE'')', p_table);
END $$;

-- The broker leg of an order (EA-007 §10.6).  order_id and block_id are ID references to trading
-- (M4).  Business status [ASSUMPTION — Q90].  A business status other than PENDING needs the
-- delivery to be acknowledged, except CANCELLED of a leg that is READY (never sent, or confirmed
-- not received).  Delivery has no move back from ACKNOWLEDGED, and the CHECK refuses any move out of
-- READY once the leg is CANCELLED, so a cancelled leg is never sent and a leg of unknown outcome
-- cannot be cancelled while it is UNKNOWN_OUTCOME or INVESTIGATION.  The move back to READY
-- ("provider confirms not received", INT-001 §6) is a person's decision recorded as an attempt row;
-- the database does not check that evidence: the Execution / Settlement module does (OUT4).  Same rule on the
-- settlement instruction and payment instruction tables.
CREATE TABLE execution.broker_order (
  tenant_id        uuid NOT NULL,
  broker_order_id  uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id         uuid,
  order_version    integer,
  block_id         uuid,
  broker_id        uuid NOT NULL,
  side             text NOT NULL CHECK (side IN ('BUY','SELL')),
  quantity         numeric(24,6) NOT NULL CHECK (quantity > 0),
  limit_price      numeric(24,8) CHECK (limit_price > 0),
  connection_id    uuid NOT NULL,               -- ID reference to operations.connection (M4)
  idempotency_key  text NOT NULL,               -- workflow ID + activity + step (INT-001 §5)
  client_reference text NOT NULL,               -- sent to the broker (FIX ClOrdID)
  ack_deadline     timestamptz,                 -- from the connection setting (OUT3) [ASSUMPTION — Confirm with <broker>]
  delivery_state   text NOT NULL DEFAULT 'READY',
  business_status  text NOT NULL DEFAULT 'PENDING',
  approval_request_id uuid,
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       uuid DEFAULT platform.current_user_id(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  row_version      integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, broker_order_id),
  UNIQUE (tenant_id, idempotency_key),
  UNIQUE (tenant_id, broker_id, client_reference),
  FOREIGN KEY (tenant_id, broker_id) REFERENCES execution.broker (tenant_id, broker_id),
  CHECK ((order_id IS NULL) <> (block_id IS NULL)),
  CHECK ((order_id IS NULL) = (order_version IS NULL)),
  CHECK (business_status = 'PENDING' OR delivery_state = 'ACKNOWLEDGED'
         OR (business_status = 'CANCELLED' AND delivery_state = 'READY'))
);
CREATE TRIGGER broker_order_version BEFORE UPDATE ON execution.broker_order FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('execution', 'broker_order', 'delivery_state', ARRAY['broker_order_id'], ARRAY['uuid'], 'broker_order_delivery');
SELECT pg_temp.add_delivery_transitions('execution.broker_order_delivery_transition');
SELECT pg_temp.make_state_machine('execution', 'broker_order', 'business_status', ARRAY['broker_order_id'], ARRAY['uuid'], 'broker_order_business');
INSERT INTO execution.broker_order_business_transition (from_state, to_state, cause) VALUES
  ('(NEW)','PENDING','CREATE'),
  ('PENDING','ACCEPTED','STATE_CHANGE'),
  ('PENDING','REJECTED','STATE_CHANGE'),
  ('PENDING','CANCELLED','STATE_CHANGE'),
  ('ACCEPTED','PARTIALLY_FILLED','STATE_CHANGE'),
  ('ACCEPTED','FILLED','STATE_CHANGE'),
  ('ACCEPTED','CANCELLED','STATE_CHANGE'),
  ('ACCEPTED','EXPIRED','STATE_CHANGE'),
  ('PARTIALLY_FILLED','FILLED','STATE_CHANGE'),
  ('PARTIALLY_FILLED','CANCELLED','STATE_CHANGE'),
  ('PARTIALLY_FILLED','EXPIRED','STATE_CHANGE');
-- Keys and terms of an instruction never change once it exists (a resend uses the same key, OUT2).
CREATE OR REPLACE FUNCTION platform.tg_instruction_keys_fixed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (to_jsonb(NEW) - ARRAY['delivery_state','business_status','updated_at','row_version','status_reason','sent_at'])
     IS DISTINCT FROM
     (to_jsonb(OLD) - ARRAY['delivery_state','business_status','updated_at','row_version','status_reason','sent_at']) THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: only the delivery state and business status of %.% change; keys and terms are fixed',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  IF (to_jsonb(OLD) ->> 'sent_at') IS NOT NULL AND (to_jsonb(NEW) ->> 'sent_at') IS DISTINCT FROM (to_jsonb(OLD) ->> 'sent_at') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: sent_at of %.% is set once', TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER broker_order_keys_fixed BEFORE UPDATE ON execution.broker_order
  FOR EACH ROW EXECUTE FUNCTION platform.tg_instruction_keys_fixed();

-- Every send, ack, status query, decision and permitted resend (INT-001 OUT6; NFR-AUD-019).
CREATE FUNCTION pg_temp.make_attempt_table(p_schema text, p_parent text, p_parent_key text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('CREATE TABLE %I.%I (
      tenant_id     uuid NOT NULL,
      attempt_id    uuid NOT NULL DEFAULT gen_random_uuid(),
      %I            uuid NOT NULL,
      action        text NOT NULL CHECK (action IN (''SEND'',''ACK'',''STATUS_QUERY'',''DECISION'',''RESEND'')),
      outcome       text NOT NULL,
      idempotency_key  text NOT NULL,
      client_reference text NOT NULL,
      detail        text,
      actor_user_id uuid DEFAULT platform.current_user_id(),
      attempted_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
      PRIMARY KEY (tenant_id, attempt_id),
      FOREIGN KEY (tenant_id, %I) REFERENCES %I.%I (tenant_id, %I)
    )', p_schema, p_parent || '_attempt', p_parent_key, p_parent_key, p_schema, p_parent, p_parent_key);
  EXECUTE format('CREATE INDEX ON %I.%I (tenant_id, %I, attempted_at)', p_schema, p_parent || '_attempt', p_parent_key);
  EXECUTE format('CREATE TRIGGER insert_only BEFORE UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable()',
                 p_schema, p_parent || '_attempt');
  -- A DECISION or RESEND is a person's act (OUT2, OUT4): it needs an acting user.
  EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT attempt_person_ck CHECK (action NOT IN (''DECISION'',''RESEND'') OR actor_user_id IS NOT NULL)',
                 p_schema, p_parent || '_attempt');
END $$;
SELECT pg_temp.make_attempt_table('execution', 'broker_order', 'broker_order_id');

-- Raw FIX and broker messages, unchanged (PRD-006 §10; NFR-RET-003).  Monthly partitions.
CREATE FUNCTION pg_temp.make_raw_message(p_schema text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format('CREATE TABLE %I.raw_message (
      tenant_id      uuid NOT NULL,
      received_at    timestamptz NOT NULL,
      message_id     uuid NOT NULL DEFAULT gen_random_uuid(),
      connection_id  uuid NOT NULL,             -- ID reference to operations.connection (M4)
      session_ref    text,
      direction      text NOT NULL CHECK (direction IN (''IN'',''OUT'')),
      message_type   text NOT NULL,
      provider_message_id text,
      body_ref       text NOT NULL,             -- object-store reference of the unchanged message
      body_sha256    bytea NOT NULL CHECK (length(body_sha256) = 32),
      recorded_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
      PRIMARY KEY (tenant_id, received_at, message_id)
    ) PARTITION BY RANGE (received_at)', p_schema);
  EXECUTE format('CREATE TABLE %I.raw_message_2026_11 PARTITION OF %I.raw_message FOR VALUES FROM (''2026-11-01'') TO (''2026-12-01'')', p_schema, p_schema);
  EXECUTE format('CREATE TABLE %I.raw_message_2026_12 PARTITION OF %I.raw_message FOR VALUES FROM (''2026-12-01'') TO (''2027-01-01'')', p_schema, p_schema);
  EXECUTE format('CREATE TABLE %I.raw_message_default PARTITION OF %I.raw_message DEFAULT', p_schema, p_schema);
  EXECUTE format('CREATE INDEX ON %I.raw_message (tenant_id, connection_id, received_at)', p_schema);
  EXECUTE format('CREATE TRIGGER insert_only BEFORE UPDATE OR DELETE ON %I.raw_message FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable()', p_schema);
END $$;
SELECT pg_temp.make_raw_message('execution');

-- Fills (DM-9): link to the broker leg, and a de-duplication key that holds across partitions.
-- The key row is written by the fill's own trigger in the same transaction; a repeat of the same
-- broker execution ID is refused (a broker correction or bust has its own execution ID).
ALTER TABLE execution.fill
  ADD COLUMN broker_order_id uuid,
  ADD CONSTRAINT fill_broker_order_fk FOREIGN KEY (tenant_id, broker_order_id) REFERENCES execution.broker_order (tenant_id, broker_order_id);
CREATE TABLE execution.fill_dedup_key (
  tenant_id      uuid NOT NULL,
  broker_code    text NOT NULL,
  broker_exec_id text NOT NULL,
  executed_at    timestamptz NOT NULL,
  fill_id        uuid NOT NULL,
  recorded_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, broker_code, broker_exec_id),
  UNIQUE (tenant_id, executed_at, fill_id),
  FOREIGN KEY (tenant_id, executed_at, fill_id) REFERENCES execution.fill (tenant_id, executed_at, fill_id)
    DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_insert_only('execution.fill_dedup_key');
CREATE TRIGGER fill_dedup_key_via_trigger BEFORE INSERT ON execution.fill_dedup_key
  FOR EACH ROW EXECUTE FUNCTION platform.tg_written_by_trigger_only();
CREATE OR REPLACE FUNCTION execution.tg_fill_dedup() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    INSERT INTO execution.fill_dedup_key (tenant_id, broker_code, broker_exec_id, executed_at, fill_id)
    VALUES (NEW.tenant_id, NEW.broker_code, NEW.broker_exec_id, NEW.executed_at, NEW.fill_id);
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'DUPLICATE_FILL: broker % execution % is already stored', NEW.broker_code, NEW.broker_exec_id
      USING ERRCODE = '23505';
  END;
  RETURN NULL;
END $$;
CREATE TRIGGER fill_dedup AFTER INSERT ON execution.fill FOR EACH ROW EXECUTE FUNCTION execution.tg_fill_dedup();

-- Contract notes received (document link and parsed fields; T2).  Loaded rows carry provenance.
-- A corrected note from the broker is a new revision.  Insert-only.
CREATE TABLE execution.contract_note (
  tenant_id        uuid NOT NULL,
  contract_note_id uuid NOT NULL DEFAULT gen_random_uuid(),
  broker_id        uuid NOT NULL,
  contract_note_no text NOT NULL,
  revision_no      integer NOT NULL DEFAULT 1 CHECK (revision_no > 0),
  trade_date       date NOT NULL,
  document_id      uuid NOT NULL,               -- ID reference to documents.document (M4)
  gross_amount     numeric(24,4),
  total_charges    numeric(24,4) CHECK (total_charges >= 0),
  net_amount       numeric(24,4),
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, contract_note_id),
  UNIQUE (tenant_id, broker_id, contract_note_no, trade_date, revision_no),
  FOREIGN KEY (tenant_id, broker_id) REFERENCES execution.broker (tenant_id, broker_id)
);
SELECT pg_temp.add_provenance('execution.contract_note', 'execution.load_run');
SELECT pg_temp.make_insert_only('execution.contract_note');

-- Result of matching a contract note with trades and expected charges (T2).  trade_id is an ID
-- reference: the trade record is execution.trade after ADR-0020 (today settlement.trade).
-- Outcomes [ASSUMPTION — Q90]; tolerance values belong to FE-06.  Insert-only.
CREATE TABLE execution.contract_note_match (
  tenant_id        uuid NOT NULL,
  match_id         uuid NOT NULL DEFAULT gen_random_uuid(),
  contract_note_id uuid NOT NULL,
  trade_id         uuid NOT NULL,
  outcome          text NOT NULL CHECK (outcome IN ('MATCHED','WITHIN_TOLERANCE','MISMATCH','UNREADABLE')),
  difference_amount numeric(24,4),
  matcher_version  text NOT NULL,
  matched_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, match_id),
  FOREIGN KEY (tenant_id, contract_note_id) REFERENCES execution.contract_note (tenant_id, contract_note_id)
);
SELECT pg_temp.make_insert_only('execution.contract_note_match');

-- Trade exceptions and breaks queue (event TRADE_EXCEPTION_RAISED).  States [ASSUMPTION — Q90].
CREATE TABLE execution.trade_exception (
  tenant_id        uuid NOT NULL,
  break_id         uuid NOT NULL DEFAULT gen_random_uuid(),
  trade_id         uuid,                        -- ID reference (see contract_note_match)
  contract_note_id uuid,
  exception_type   text NOT NULL,
  description      text NOT NULL,
  owner_user_id    uuid,                        -- ID reference (M4)
  state            text NOT NULL DEFAULT 'OPEN',
  resolution       text,
  raised_at        timestamptz NOT NULL DEFAULT clock_timestamp(),
  resolved_at      timestamptz,
  created_by       uuid DEFAULT platform.current_user_id(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  row_version      integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, break_id),
  FOREIGN KEY (tenant_id, contract_note_id) REFERENCES execution.contract_note (tenant_id, contract_note_id),
  CHECK (trade_id IS NOT NULL OR contract_note_id IS NOT NULL),
  CHECK ((state = 'RESOLVED') = (resolved_at IS NOT NULL AND resolution IS NOT NULL))
);
CREATE INDEX trade_exception_open_ix ON execution.trade_exception (tenant_id, state) WHERE state <> 'RESOLVED';
CREATE TRIGGER trade_exception_version BEFORE UPDATE ON execution.trade_exception FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('execution', 'trade_exception', 'state', ARRAY['break_id'], ARRAY['uuid']);
INSERT INTO execution.trade_exception_transition (from_state, to_state, cause) VALUES
  ('(NEW)','OPEN','CREATE'),
  ('OPEN','IN_PROGRESS','STATE_CHANGE'),
  ('OPEN','RESOLVED','STATE_CHANGE'),
  ('IN_PROGRESS','RESOLVED','STATE_CHANGE');

-- Links to evidence for trades done outside the OMS (WF-024).  Insert-only.
CREATE TABLE execution.external_trade_evidence (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  evidence_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  trade_id      uuid NOT NULL,                  -- ID reference (see contract_note_match)
  evidence_kind text NOT NULL,
  document_id   uuid NOT NULL,                  -- ID reference to documents.document (M4)
  captured_by   uuid NOT NULL,
  captured_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, evidence_id)
);
SELECT pg_temp.make_insert_only('execution.external_trade_evidence');
CREATE TRIGGER external_trade_evidence_actor BEFORE INSERT ON execution.external_trade_evidence
  FOR EACH ROW EXECUTE FUNCTION platform.tg_set_actor('captured_by');

-- ---------------------------------------------------------------------
-- 06  settlement  (Settlement module, D07; DA-001 §4.10) - settlement.trade keeps its name until
--     ADR-0020 (DM-7)
-- ---------------------------------------------------------------------
SELECT pg_temp.make_load_run('settlement');

-- DM-10: the settlement record's own state machine.  The 11 DDL-000 states are kept; the moves are
-- the PRD-007 §4.3 diagram (its [DES] moves included).  Moves straight from INSTRUCTED or
-- ACKNOWLEDGED to FAILED are left out: Confirm with <custodian> (PRD-007 C4).
SELECT pg_temp.make_state_machine('settlement', 'trade', 'status', ARRAY['trade_id'], ARRAY['uuid'], 'settlement');
INSERT INTO settlement.settlement_transition (from_state, to_state, cause) VALUES
  ('(NEW)','PENDING_INSTRUCTION','CREATE'),
  ('PENDING_INSTRUCTION','INSTRUCTED','STATE_CHANGE'),
  ('PENDING_INSTRUCTION','CANCELLED','STATE_CHANGE'),
  ('INSTRUCTED','ACKNOWLEDGED','STATE_CHANGE'),
  ('INSTRUCTED','PENDING_INSTRUCTION','STATE_CHANGE'),
  ('ACKNOWLEDGED','MATCHED','STATE_CHANGE'),
  ('MATCHED','SETTLED','STATE_CHANGE'),
  ('MATCHED','PARTIALLY_SETTLED','STATE_CHANGE'),
  ('MATCHED','FAILED','STATE_CHANGE'),
  ('PARTIALLY_SETTLED','SETTLED','STATE_CHANGE'),
  ('PARTIALLY_SETTLED','FAILED','STATE_CHANGE'),
  ('FAILED','RE_INSTRUCTED','STATE_CHANGE'),
  ('FAILED','BOUGHT_IN','STATE_CHANGE'),
  ('FAILED','CLOSED_OUT','STATE_CHANGE'),
  ('FAILED','CANCELLED','STATE_CHANGE'),
  ('RE_INSTRUCTED','ACKNOWLEDGED','STATE_CHANGE');

-- Settlement cycle and cut-off configuration per market and instrument (BT, rule 2).  Values are
-- data [VAL per market]; none is set here.
CREATE TABLE settlement.settlement_cycle (
  tenant_id        uuid NOT NULL REFERENCES platform.tenant,
  market           text NOT NULL,
  instrument_class text NOT NULL,
  valid_period     daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at    timestamptz,
  cycle            text NOT NULL CHECK (cycle ~ '^T\+[0-9]{1,2}$'),
  cut_off_time     time,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, market, instrument_class, valid_period, recorded_at),
  EXCLUDE USING gist (tenant_id WITH =, market WITH =, instrument_class WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('settlement.settlement_cycle', ARRAY['tenant_id','market','instrument_class']);

-- Scheme bank and demat accounts (T4): anchor + versions, each version with its call-back record
-- (WF-028: details are confirmed by a call-back before use, by someone other than the maker).
CREATE TABLE settlement.scheme_bank_account (
  tenant_id     uuid NOT NULL,
  account_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid NOT NULL,
  account_type  text NOT NULL CHECK (account_type IN ('BANK','DEMAT')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, account_id),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id)
);
SELECT pg_temp.make_insert_only('settlement.scheme_bank_account');
CREATE TABLE settlement.scheme_bank_account_version (
  tenant_id         uuid NOT NULL,
  account_id        uuid NOT NULL,
  valid_period      daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at     timestamptz,
  provider_counterparty_id uuid NOT NULL,       -- the bank, custodian or depository participant
  account_number    text NOT NULL,              -- CONFIDENTIAL (not personal data, M22)
  branch_code       text,                       -- IFSC for a bank account, DP ID for a demat account
  account_purpose   text NOT NULL,
  maker_user_id     uuid NOT NULL,
  callback_by       uuid NOT NULL,
  callback_at       timestamptz NOT NULL,
  callback_evidence_document_id uuid,           -- ID reference (M4)
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, account_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, account_id) REFERENCES settlement.scheme_bank_account (tenant_id, account_id),
  FOREIGN KEY (tenant_id, provider_counterparty_id) REFERENCES master.counterparty (tenant_id, counterparty_id),
  CHECK (callback_by <> maker_user_id),
  EXCLUDE USING gist (tenant_id WITH =, account_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('settlement.scheme_bank_account_version', ARRAY['tenant_id','account_id']);

-- Standing settlement instructions per counterparty (T4, WF-028): anchor + versions with call-back.
CREATE TABLE settlement.ssi (
  tenant_id       uuid NOT NULL,
  ssi_id          uuid NOT NULL DEFAULT gen_random_uuid(),
  counterparty_id uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, ssi_id),
  FOREIGN KEY (tenant_id, counterparty_id) REFERENCES master.counterparty (tenant_id, counterparty_id)
);
SELECT pg_temp.make_insert_only('settlement.ssi');
CREATE TABLE settlement.ssi_version (
  tenant_id        uuid NOT NULL,
  ssi_id           uuid NOT NULL,
  valid_period     daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at    timestamptz,
  market           text NOT NULL,
  instrument_class text NOT NULL,
  settlement_details text NOT NULL,             -- depository / account / agent details as received (CONFIDENTIAL)
  maker_user_id    uuid NOT NULL,
  callback_by      uuid NOT NULL,
  callback_at      timestamptz NOT NULL,
  callback_evidence_document_id uuid,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, ssi_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, ssi_id) REFERENCES settlement.ssi (tenant_id, ssi_id),
  CHECK (callback_by <> maker_user_id),
  EXCLUDE USING gist (tenant_id WITH =, ssi_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('settlement.ssi_version', ARRAY['tenant_id','ssi_id']);
-- The maker of a new version (not a continuation) is the acting user, an active user of the
-- tenant; the call-back was made by another active human user of the tenant (not a service
-- identity; PRD-007 BRL-D07-001, WF-028).
CREATE OR REPLACE FUNCTION settlement.tg_version_maker() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN RETURN NEW; END IF;
  NEW.maker_user_id := platform.current_user_id();
  IF NEW.maker_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM identity.app_user u WHERE u.tenant_id = NEW.tenant_id
                                                 AND u.user_id = NEW.maker_user_id AND u.status = 'ACTIVE') THEN
    RAISE EXCEPTION 'NO_ACTOR: %.% needs an active user of the tenant as the acting user (app.user_id)',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM identity.app_user u WHERE u.tenant_id = NEW.tenant_id AND u.user_id = NEW.callback_by
                    AND u.status = 'ACTIVE' AND NOT u.is_service_identity) THEN
    RAISE EXCEPTION 'BAD_CALLBACK: the call-back on %.% must be made by an active human user of the tenant',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '23514';
  END IF;
  IF NEW.callback_at > clock_timestamp() THEN
    RAISE EXCEPTION 'BAD_CALLBACK: the call-back on %.% cannot be dated in the future', TG_TABLE_SCHEMA, TG_TABLE_NAME
      USING ERRCODE = '23514';
  END IF;
  IF NEW.callback_by = NEW.maker_user_id THEN
    RAISE EXCEPTION 'BAD_CALLBACK: the call-back on %.% must be made by someone other than the maker',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER ssi_version_maker BEFORE INSERT ON settlement.ssi_version
  FOR EACH ROW EXECUTE FUNCTION settlement.tg_version_maker();
CREATE TRIGGER scheme_bank_account_version_maker BEFORE INSERT ON settlement.scheme_bank_account_version
  FOR EACH ROW EXECUTE FUNCTION settlement.tg_version_maker();

-- DM-10: instructions get the common delivery_state (§3.5) and a separate business status.
-- CREATED -> READY, ACK -> ACKNOWLEDGED (delivery); NACK -> business REJECTED.  instruction_ref
-- becomes client_reference (still unique per custodian).  READY means approved (INT-001 §6), so
-- every instruction carries its approval reference (D-31: a second approver).
ALTER TABLE settlement.instruction DROP COLUMN status;
ALTER TABLE settlement.instruction RENAME COLUMN instruction_ref TO client_reference;
ALTER TABLE settlement.instruction
  ADD COLUMN ssi_id           uuid,
  ADD COLUMN connection_id    uuid NOT NULL,     -- ID reference to operations.connection (M4)
  ADD COLUMN idempotency_key  text NOT NULL,
  ADD COLUMN ack_deadline     timestamptz,       -- connection setting (OUT3) [ASSUMPTION — Confirm with <custodian>]
  ADD COLUMN delivery_state   text NOT NULL DEFAULT 'READY',
  ADD COLUMN business_status  text NOT NULL DEFAULT 'PENDING',
  ADD COLUMN approval_request_id uuid NOT NULL,
  ADD COLUMN created_at       timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN created_by       uuid DEFAULT platform.current_user_id(),
  ADD COLUMN updated_at       timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN row_version      integer NOT NULL DEFAULT 1,
  ADD CONSTRAINT instruction_ssi_fk FOREIGN KEY (tenant_id, ssi_id) REFERENCES settlement.ssi (tenant_id, ssi_id),
  ADD CONSTRAINT instruction_idempotency_uk UNIQUE (tenant_id, idempotency_key),
  ADD CONSTRAINT instruction_business_ck CHECK (business_status = 'PENDING' OR delivery_state = 'ACKNOWLEDGED'
         OR (business_status = 'CANCELLED' AND delivery_state = 'READY'));
CREATE TRIGGER instruction_version BEFORE UPDATE ON settlement.instruction FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER instruction_keys_fixed BEFORE UPDATE ON settlement.instruction
  FOR EACH ROW EXECUTE FUNCTION platform.tg_instruction_keys_fixed();
SELECT pg_temp.make_state_machine('settlement', 'instruction', 'delivery_state', ARRAY['instruction_id'], ARRAY['uuid'], 'instruction_delivery');
SELECT pg_temp.add_delivery_transitions('settlement.instruction_delivery_transition');
-- Business status: DM-10 values; PENDING = nothing reported yet [DES]; moves [ASSUMPTION — FE-06, Step 22].
SELECT pg_temp.make_state_machine('settlement', 'instruction', 'business_status', ARRAY['instruction_id'], ARRAY['uuid'], 'instruction_business');
INSERT INTO settlement.instruction_business_transition (from_state, to_state, cause) VALUES
  ('(NEW)','PENDING','CREATE'),
  ('PENDING','MATCHED','STATE_CHANGE'),
  ('PENDING','REJECTED','STATE_CHANGE'),
  ('PENDING','CANCELLED','STATE_CHANGE'),
  ('MATCHED','SETTLED','STATE_CHANGE'),
  ('MATCHED','FAILED','STATE_CHANGE'),
  ('MATCHED','CANCELLED','STATE_CHANGE');

-- Which settlement move each instruction status causes (DM-10).  Product-level list (M3): no
-- tenant column, read-only for the application.  Rows are DM-10's examples; FE-06 (Step 22)
-- confirms the full list.  The Settlement module applies the move through the settlement state
-- machine, which refuses a move that is not allowed from the record's current state.
CREATE TABLE settlement.instruction_effect (
  status_kind      text NOT NULL CHECK (status_kind IN ('DELIVERY','BUSINESS')),
  status_value     text NOT NULL,
  settlement_to_state text NOT NULL,
  PRIMARY KEY (status_kind, status_value)
);
COMMENT ON TABLE settlement.instruction_effect IS
  'Product-level map from instruction delivery / business status to the settlement move it causes (DA-001 DM-10, M3). Read-only for application roles.';
INSERT INTO settlement.instruction_effect (status_kind, status_value, settlement_to_state) VALUES
  ('DELIVERY','SENT','INSTRUCTED'),
  ('DELIVERY','ACKNOWLEDGED','ACKNOWLEDGED'),
  ('BUSINESS','MATCHED','MATCHED'),
  ('BUSINESS','SETTLED','SETTLED'),
  ('BUSINESS','FAILED','FAILED');
-- Every effect points at a settlement state that exists and a status that exists.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM settlement.instruction_effect e
              WHERE NOT EXISTS (SELECT 1 FROM settlement.settlement_transition t WHERE t.to_state = e.settlement_to_state)
                 OR (e.status_kind = 'DELIVERY' AND NOT EXISTS (SELECT 1 FROM settlement.instruction_delivery_transition d WHERE d.to_state = e.status_value))
                 OR (e.status_kind = 'BUSINESS' AND NOT EXISTS (SELECT 1 FROM settlement.instruction_business_transition b WHERE b.to_state = e.status_value))) THEN
    RAISE EXCEPTION 'settlement.instruction_effect names a state that no transition table has';
  END IF;
END $$;
SELECT pg_temp.make_attempt_table('settlement', 'instruction', 'instruction_id');

-- Gross and net obligations per clearing cycle (PRD-007 §10), as loaded from the clearing
-- corporation or computed.  A changed obligation is a new row that supersedes the old (M12).
CREATE TABLE settlement.obligation (
  tenant_id       uuid NOT NULL,
  obligation_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id       uuid NOT NULL,
  market          text NOT NULL,
  clearing_cycle  text NOT NULL,
  settlement_date date NOT NULL,
  obligation_kind text NOT NULL CHECK (obligation_kind IN ('GROSS','NET')),
  security_id     uuid,                         -- NULL for a funds obligation
  quantity        numeric(24,6),
  direction       text NOT NULL CHECK (direction IN ('PAY','RECEIVE')),
  gross_amount    numeric(24,4),
  net_amount      numeric(24,4),
  supersedes_obligation_id uuid,
  recorded_at     timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, obligation_id),
  FOREIGN KEY (tenant_id, scheme_id)   REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  FOREIGN KEY (tenant_id, supersedes_obligation_id) REFERENCES settlement.obligation (tenant_id, obligation_id),
  CHECK ((security_id IS NULL) = (quantity IS NULL)),
  CHECK (gross_amount IS NOT NULL OR net_amount IS NOT NULL OR quantity IS NOT NULL)
);
CREATE UNIQUE INDEX obligation_superseded_once_ux ON settlement.obligation (tenant_id, supersedes_obligation_id)
  WHERE supersedes_obligation_id IS NOT NULL;
SELECT pg_temp.add_provenance('settlement.obligation', 'settlement.load_run');
SELECT pg_temp.make_insert_only('settlement.obligation');

-- Funding payments routed through AMC OS (PRD-007 §10; INT-001 §6), with the A2 states.
-- Business status [ASSUMPTION — Q90].
CREATE TABLE settlement.payment_instruction (
  tenant_id        uuid NOT NULL,
  payment_instruction_id uuid NOT NULL DEFAULT gen_random_uuid(),
  obligation_id    uuid,
  account_id       uuid NOT NULL,               -- paying scheme account
  amount           numeric(24,4) NOT NULL CHECK (amount > 0),
  currency_code    char(3) NOT NULL DEFAULT 'INR' REFERENCES master.currency,
  value_date       date NOT NULL,
  beneficiary_ssi_id uuid,
  connection_id    uuid NOT NULL,               -- ID reference to operations.connection (M4)
  idempotency_key  text NOT NULL,
  client_reference text NOT NULL,
  ack_deadline     timestamptz,                 -- [ASSUMPTION — Confirm with <bank>]
  delivery_state   text NOT NULL DEFAULT 'READY',
  business_status  text NOT NULL DEFAULT 'PENDING',
  status_reason    text,
  sent_at          timestamptz,
  approval_request_id uuid NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       uuid DEFAULT platform.current_user_id(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  row_version      integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, payment_instruction_id),
  UNIQUE (tenant_id, idempotency_key),
  UNIQUE (tenant_id, connection_id, client_reference),
  FOREIGN KEY (tenant_id, obligation_id)      REFERENCES settlement.obligation (tenant_id, obligation_id),
  FOREIGN KEY (tenant_id, account_id)         REFERENCES settlement.scheme_bank_account (tenant_id, account_id),
  FOREIGN KEY (tenant_id, beneficiary_ssi_id) REFERENCES settlement.ssi (tenant_id, ssi_id),
  CHECK (business_status = 'PENDING' OR delivery_state = 'ACKNOWLEDGED'
         OR (business_status = 'CANCELLED' AND delivery_state = 'READY'))
);
CREATE TRIGGER payment_instruction_version BEFORE UPDATE ON settlement.payment_instruction FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER payment_instruction_keys_fixed BEFORE UPDATE ON settlement.payment_instruction
  FOR EACH ROW EXECUTE FUNCTION platform.tg_instruction_keys_fixed();
SELECT pg_temp.make_state_machine('settlement', 'payment_instruction', 'delivery_state', ARRAY['payment_instruction_id'], ARRAY['uuid'], 'payment_instruction_delivery');
SELECT pg_temp.add_delivery_transitions('settlement.payment_instruction_delivery_transition');
SELECT pg_temp.make_state_machine('settlement', 'payment_instruction', 'business_status', ARRAY['payment_instruction_id'], ARRAY['uuid'], 'payment_instruction_business');
INSERT INTO settlement.payment_instruction_business_transition (from_state, to_state, cause) VALUES
  ('(NEW)','PENDING','CREATE'),
  ('PENDING','EXECUTED','STATE_CHANGE'),
  ('PENDING','REJECTED','STATE_CHANGE'),
  ('PENDING','CANCELLED','STATE_CHANGE'),
  ('EXECUTED','RETURNED','STATE_CHANGE');
SELECT pg_temp.make_attempt_table('settlement', 'payment_instruction', 'payment_instruction_id');

-- DA-001 §3.1 rule 1: a foreign key to an anchor is not enough; the paying account and the
-- beneficiary SSI must have a current version valid on the value date, and an instruction's SSI one
-- valid on the trade's settlement date.
CREATE OR REPLACE FUNCTION settlement.tg_valid_on_date() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_date date;
BEGIN
  IF TG_TABLE_NAME = 'payment_instruction' THEN
    v_date := NEW.value_date;
    IF NOT EXISTS (SELECT 1 FROM settlement.scheme_bank_account_version v WHERE v.tenant_id = NEW.tenant_id
                      AND v.account_id = NEW.account_id AND v.superseded_at IS NULL AND v.valid_period @> v_date) THEN
      RAISE EXCEPTION 'NOT_VALID_ON_DATE: account % has no current version on %', NEW.account_id, v_date USING ERRCODE = '23514';
    END IF;
    IF NEW.beneficiary_ssi_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM settlement.ssi_version v WHERE v.tenant_id = NEW.tenant_id
                      AND v.ssi_id = NEW.beneficiary_ssi_id AND v.superseded_at IS NULL AND v.valid_period @> v_date) THEN
      RAISE EXCEPTION 'NOT_VALID_ON_DATE: SSI % has no current version on %', NEW.beneficiary_ssi_id, v_date USING ERRCODE = '23514';
    END IF;
  ELSIF NEW.ssi_id IS NOT NULL THEN
    SELECT settlement_date INTO v_date FROM settlement.trade WHERE tenant_id = NEW.tenant_id AND trade_id = NEW.trade_id;
    IF NOT EXISTS (SELECT 1 FROM settlement.ssi_version v WHERE v.tenant_id = NEW.tenant_id
                      AND v.ssi_id = NEW.ssi_id AND v.superseded_at IS NULL AND v.valid_period @> v_date) THEN
      RAISE EXCEPTION 'NOT_VALID_ON_DATE: SSI % has no current version on %', NEW.ssi_id, v_date USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
-- Checked when the instruction is created and again each time it is sent (READY -> SENT), so an
-- account or SSI version ended or retracted in between stops instructions still waiting to go out.
CREATE TRIGGER payment_instruction_valid_on_date BEFORE INSERT ON settlement.payment_instruction
  FOR EACH ROW EXECUTE FUNCTION settlement.tg_valid_on_date();
CREATE TRIGGER payment_instruction_valid_on_send BEFORE UPDATE OF delivery_state ON settlement.payment_instruction
  FOR EACH ROW WHEN (OLD.delivery_state = 'READY' AND NEW.delivery_state = 'SENT')
  EXECUTE FUNCTION settlement.tg_valid_on_date();
CREATE TRIGGER instruction_valid_on_date BEFORE INSERT ON settlement.instruction
  FOR EACH ROW EXECUTE FUNCTION settlement.tg_valid_on_date();
CREATE TRIGGER instruction_valid_on_send BEFORE UPDATE OF delivery_state ON settlement.instruction
  FOR EACH ROW WHEN (OLD.delivery_state = 'READY' AND NEW.delivery_state = 'SENT')
  EXECUTE FUNCTION settlement.tg_valid_on_date();

-- Failed settlement: reason, owner, ageing (from failed_on), penalty, close-out (PRD-007 §10, WF-027).
-- States [ASSUMPTION — Q90]; the outcome is required when the fail is closed.
CREATE TABLE settlement.fail (
  tenant_id      uuid NOT NULL,
  fail_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  trade_id       uuid NOT NULL,
  reason_code    text NOT NULL,
  failed_on      date NOT NULL,
  owner_user_id  uuid,                          -- ID reference (M4)
  penalty_amount numeric(24,4) CHECK (penalty_amount >= 0),
  state          text NOT NULL DEFAULT 'OPEN',
  close_outcome  text CHECK (close_outcome IN ('SETTLED_LATE','BOUGHT_IN','CLOSED_OUT','CANCELLED')),
  closed_on      date,
  created_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid DEFAULT platform.current_user_id(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  row_version    integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, fail_id),
  FOREIGN KEY (tenant_id, trade_id) REFERENCES settlement.trade (tenant_id, trade_id),
  CHECK ((state = 'CLOSED') = (close_outcome IS NOT NULL AND closed_on IS NOT NULL)),
  CHECK (closed_on IS NULL OR closed_on >= failed_on)
);
CREATE UNIQUE INDEX fail_one_open_ux ON settlement.fail (tenant_id, trade_id) WHERE state <> 'CLOSED';
CREATE TRIGGER fail_version BEFORE UPDATE ON settlement.fail FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('settlement', 'fail', 'state', ARRAY['fail_id'], ARRAY['uuid']);
INSERT INTO settlement.fail_transition (from_state, to_state, cause) VALUES
  ('(NEW)','OPEN','CREATE'),
  ('OPEN','IN_PROGRESS','STATE_CHANGE'),
  ('OPEN','CLOSED','STATE_CHANGE'),
  ('IN_PROGRESS','CLOSED','STATE_CHANGE');

-- Custodian, depository and bank holdings and cash statements as loaded (reconciled by
-- Operations).  Insert-only, yearly partitions; every row carries provenance (M9).
CREATE TABLE settlement.holding_statement (
  tenant_id      uuid NOT NULL,
  statement_date date NOT NULL,
  statement_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  account_id     uuid NOT NULL,
  statement_kind text NOT NULL CHECK (statement_kind IN ('CUSTODY_HOLDING','DEPOSITORY_HOLDING','BANK_CASH')),
  security_id    uuid,
  quantity       numeric(24,6),
  amount         numeric(24,4),
  recorded_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (tenant_id, statement_date, statement_id),
  FOREIGN KEY (tenant_id, account_id)  REFERENCES settlement.scheme_bank_account (tenant_id, account_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  CHECK (CASE WHEN statement_kind = 'BANK_CASH' THEN security_id IS NULL AND quantity IS NULL AND amount IS NOT NULL
              ELSE security_id IS NOT NULL AND quantity IS NOT NULL END)
) PARTITION BY RANGE (statement_date);
CREATE TABLE settlement.holding_statement_2026 PARTITION OF settlement.holding_statement FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE settlement.holding_statement_2027 PARTITION OF settlement.holding_statement FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE settlement.holding_statement_default PARTITION OF settlement.holding_statement DEFAULT;
SELECT pg_temp.add_provenance('settlement.holding_statement', 'settlement.load_run');
ALTER TABLE settlement.holding_statement ADD CONSTRAINT holding_statement_loaded_ck CHECK (source_system <> 'AMC_OS_MANUAL');
SELECT pg_temp.make_insert_only('settlement.holding_statement');

SELECT pg_temp.make_raw_message('settlement');

-- Standard columns on mutable rows (M21) where this part's DDL-000 tables lack them.
ALTER TABLE trading.block_allocation
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN created_by uuid DEFAULT platform.current_user_id();

-- ---------------------------------------------------------------------
-- 07  Row-level security and grants for every new table
-- ---------------------------------------------------------------------
SELECT platform.apply_tenant_rls();

-- Grant only on tables that do not have grants yet (the tables created above), so the revokes
-- DDL-000 and DDL-001 made stay in force.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS s, c.relname AS t
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind IN ('r','p','v')
       AND n.nspname IN ('product','investment','portfolio','trading','execution','settlement')
       AND NOT has_table_privilege('amc_readonly', c.oid, 'SELECT')
  LOOP
    EXECUTE format('GRANT SELECT ON %I.%I TO amc_readonly, amc_auditor', r.s, r.t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON %I.%I TO amc_app', r.s, r.t);
  END LOOP;
END $$;
-- Views are read-only.
REVOKE INSERT, UPDATE ON portfolio.exposure_view FROM amc_app;

-- Product-level rows (M3): transition tables and the instruction-effect map are read-only for
-- application roles; they change only by migration.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT n.nspname AS s, c.relname AS t FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind = 'r' AND (c.relname LIKE '%\_transition' OR c.relname = 'instruction_effect')
              AND n.nspname IN ('product','investment','portfolio','trading','execution','settlement')
  LOOP
    EXECUTE format('REVOKE INSERT, UPDATE ON %I.%I FROM amc_app', r.s, r.t);
  END LOOP;
END $$;

-- Insert-only tables (history, closure, attempt, raw-message, IO facts): no UPDATE for the
-- application (the triggers refuse it as well).  Partitions included.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT n.nspname AS s, c.relname AS t FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind IN ('r','p')
              AND n.nspname IN ('product','investment','portfolio','trading','execution','settlement')
              AND (c.relname LIKE '%\_history' OR c.relname LIKE '%\_closure' OR c.relname LIKE '%\_attempt'
                   OR c.relname LIKE 'raw\_message%' OR c.relname LIKE 'position\_event%' OR c.relname LIKE 'holding\_statement%'
                   OR (n.nspname, c.relname) IN (('product','scheme_event'), ('investment','decision_record'),
                       ('investment','research_note'), ('investment','ic_vote'), ('portfolio','performance_result'),
                       ('portfolio','attribution_result'), ('trading','order_version'), ('trading','compliance_result_ref'),
                       ('trading','warn_acknowledgement'), ('trading','rfq_quote'), ('execution','broker'),
                       ('execution','broker_evaluation'), ('execution','fill_dedup_key'), ('execution','contract_note'),
                       ('execution','contract_note_match'), ('execution','external_trade_evidence'),
                       ('settlement','scheme_bank_account'), ('settlement','ssi'), ('settlement','obligation')))
  LOOP
    EXECUTE format('REVOKE UPDATE ON %I.%I FROM amc_app', r.s, r.t);
  END LOOP;
END $$;
-- History rows and the fill de-duplication key / order versions are written only by triggers
-- (the triggers refuse a direct insert); the application role keeps INSERT because triggers run
-- with the caller's rights (no SECURITY DEFINER before ADR-0020's roles exist).

COMMIT;

-- End of DDL-002.
