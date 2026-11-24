-- =====================================================================
-- DDL-001  AMC OS - Step 16a DDL additions (status: Draft, WP4 / GOV-006 Step 16, part a)
-- Target: PostgreSQL 16+.  Applied after DDL-000 v0.9.  Tested on PostgreSQL 16.15.
-- Run as a superuser / migration owner:  psql -v ON_ERROR_STOP=1 -f <this file>
--
-- What this file builds (DA-001 v0.3, Draft):
--   00  shared building blocks (M6, M7, M9, M14 trigger functions; closure tables for BT-3/BT-4; provenance helper)
--   01  numeric widening of DDL-000 amount columns (DA-001 §3.7, DM-22)
--   02  platform  (DA-001 §4.1)  - cell, tenant changes (DM-16), configuration (DM-21) ...
--   03  identity  (DA-001 §4.2)  - grant anchors, scope attributes, requests, sessions ...
--   04  audit     (DA-001 §4.3)  - daily chain anchors, access log
--   05  master    (DA-001 §4.4)  - anchor/version split (DM-1), crosswalk (§3.4), provenance (§3.3)
--   06  row-level security and grants for every new table
--
-- What this file does NOT build, and why:
--   * Everything DA-001 marks (ADR-0020): per-schema outbox/inbox/dead-letter/idempotency tables
--     (DM-4), per-module database roles, table moves (DM-7, DM-8), tenant removal and audit import
--     (DM-17: platform.tenant_removal_authorisation, audit.import_run, audit_event changes),
--     break-glass (DM-18: identity.break_glass_grant), cross-schema key removal and the Workflow
--     read model (DM-20: unchangeable is_service_identity, workflow.actor_ref).
--     ADR-0020 is merged as Draft and not yet accepted by the owner.
--   * The other 18 schemas: Steps 16b-16e (see LOOP_STATE.md).
--
-- Data: this file reshapes DDL-000 tables (drops columns that move to version tables) without
-- copying rows.  It is for the empty reference database; it refuses to run if those tables hold
-- rows.  The data move for a real database is the Alembic migration of Step 18.
-- The whole file runs in one transaction: it applies completely or not at all.
--
-- Every decision here is [DES] unless labelled. No business rule, rate, threshold or cut-off is
-- set: where a value is a business rule it is data (a row), not code. State lists that no source
-- document fixes are marked [ASSUMPTION] and live in transition tables, so the owner can change
-- them by migration without touching code.
-- =====================================================================

BEGIN;

-- Refuse to run against tables that hold rows (finding: columns are dropped, not copied).
DO $$
DECLARE t text; n bigint;
BEGIN
  FOREACH t IN ARRAY ARRAY['identity.user_role','identity.role_permission','platform.business_calendar',
                           'master.issuer_group','master.issuer','master.security','master.credit_rating','master.benchmark']
  LOOP
    EXECUTE format('SELECT count(*) FROM %s', t) INTO n;
    IF n > 0 THEN
      RAISE EXCEPTION 'DDL-001 reshapes % but it holds % rows; use the Step 18 migration that moves the data', t, n;
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 00  Shared building blocks
-- ---------------------------------------------------------------------

-- Today's business date.  Fixed to India time (Asia/Kolkata), whatever the session TimeZone or the
-- server clock zone, so no session can move "today" back by setting a far-west TimeZone.
-- [DES] One zone for every tenant: AMC OS serves Indian AMCs; a per-tenant zone held in data can
-- replace it if that ever changes.
CREATE OR REPLACE FUNCTION platform.today_ist() RETURNS date
LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT (now() AT TIME ZONE 'Asia/Kolkata')::date
$$;

-- Helper used by the generic triggers below: "t.k1 IS NOT DISTINCT FROM ($1).k1 AND ..."
-- for a list of key columns passed as trigger arguments.
CREATE OR REPLACE FUNCTION platform.key_match_sql(p_keys text[], p_alias text DEFAULT 't')
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT string_agg(format('%I.%I IS NOT DISTINCT FROM ($1).%I', p_alias, k, k), ' AND ')
    FROM unnest(p_keys) AS k
$$;

-- How bi-temporal versions change (M7; DA-001 §11, rules BT-1..BT-5; owner decision D-76):
--   BT-1  A version states the truth for its own validity period.  Inserting it closes (supersedes)
--         every older current version of the same key whose period overlaps it.
--   BT-2  What an older version said OUTSIDE the new version's period (before its start and after
--         its end) is kept: each part is re-inserted as a current version with the old content
--         (a "continuation").  A version with an end date therefore does NOT end the key.
--   BT-3  Ending a key from a date (revoking a grant, removing a right, retiring a code) is a
--         separate END row in the table's closure table <table>_closure (D-76, option B).  It
--         records who ended the key (closed_by, from the identity context), from which date
--         (end_date), under which request (request_id) and why (reason).  It never restates or
--         re-signs the old content.  It closes every current version of the key whose period
--         reaches end_date or later - including versions that start later - and keeps only the
--         part before end_date as a continuation.
--         A new version and an END / RETRACT of the same key never interleave (platform.bt_lock_key:
--         a busy key is refused with 40001, retry), and a version is refused if another
--         transaction ended or retracted the key after this transaction began.  Both rules need
--         READ COMMITTED: versions and closure rows are refused under other isolation levels.  Not
--         caught: an END inserted before the writing transaction began that commits after it began
--         and before its write (no lock contention then); modules keep END transactions short.
--         closed_by must be an
--         active user of the tenant; request_id is checked on the identity grant closure tables and
--         is an ID reference (M4) elsewhere.
--   BT-4  Retracting one current version (no version at all for its period) is a RETRACT row in
--         the same closure table, with the same who / request / why.  The application can never
--         set superseded_at itself.  Rows are never edited otherwise and never deleted.
--   BT-5  recorded_at and superseded_at are the database clock.  One inserted version or one
--         closure row uses one instant: the rows it closes get superseded_at, and its
--         continuations get recorded_at, equal to its own recorded_at.  Several versions written
--         in one transaction each get their own (increasing) instant, so an "as known at T"
--         query for a T inside that transaction's few microseconds can see part of the change;
--         as-known-at queries use instants taken from committed data (DA-001 §11).
--   Continuations are recognised from data, not only from trigger depth: the row must be written
--   inside a trigger AND a row of the same table closed at exactly its recorded_at must have the
--   same content over a period that contains it (platform.bt_is_continuation).  Only continuations
--   skip today's signing and format checks.  No other trigger may insert into a version table or
--   set superseded_at (DA-001 §11).
--   The "no overlap among current versions" exclusion constraints are DEFERRABLE INITIALLY
--   DEFERRED and checked at COMMIT; a module must not SET CONSTRAINTS ... IMMEDIATE before it
--   inserts a version (the check would run before the old row is closed).

-- Is this row a continuation written by tg_bt_supersede / tg_bt_close?  (BT-5: from data.)
CREATE OR REPLACE FUNCTION platform.bt_is_continuation(p_table regclass, p_row jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE AS $$
DECLARE v_ok boolean;
BEGIN
  IF pg_trigger_depth() < 2 OR p_row ->> 'recorded_at' IS NULL OR NOT (p_row ? 'superseded_at') THEN
    RETURN false;
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM %s t
                   WHERE t.tenant_id = ($1 ->> ''tenant_id'')::uuid
                     AND t.superseded_at = ($1 ->> ''recorded_at'')::timestamptz %s
                     AND (to_jsonb(t) - ''valid_period'' - ''recorded_at'' - ''superseded_at'')
                       = ($1 - ''valid_period'' - ''recorded_at'' - ''superseded_at''))',
                 p_table,
                 CASE WHEN p_row ? 'valid_period'
                      THEN 'AND t.valid_period @> ($1 ->> ''valid_period'')::daterange' ELSE '' END)
    INTO v_ok USING p_row;
  RETURN v_ok;
END $$;

-- BT-5 system time.  BEFORE INSERT on a version table.
CREATE OR REPLACE FUNCTION platform.tg_bt_stamp() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN
    RETURN NEW;                                   -- continuation written by tg_bt_supersede / tg_bt_close
  END IF;
  IF NEW.superseded_at IS NOT NULL THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: a version cannot be inserted already superseded (%.%)',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  NEW.recorded_at := clock_timestamp();
  RETURN NEW;
END $$;

-- BT-1, BT-2.  AFTER INSERT on a version table.  Arguments: the key columns WITHOUT
-- valid_period / recorded_at.  Tables without a valid_period column (keyed by a date, e.g. a
-- calendar day) simply supersede the current row of the same key.
CREATE OR REPLACE FUNCTION platform.tg_bt_supersede() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_sql  text;
  v_old  jsonb;
  v_left daterange;
  v_new  daterange;
  v_part daterange;
  v_stale boolean;
BEGIN
  -- BT-3 concurrency rules rely on READ COMMITTED (each statement sees what committed before it);
  -- under REPEATABLE READ or SERIALIZABLE a closure committed meanwhile would stay invisible.
  IF current_setting('transaction_isolation') <> 'read committed' THEN
    RAISE EXCEPTION 'ISOLATION_NOT_SUPPORTED: versions of %.% are written only under READ COMMITTED', TG_TABLE_SCHEMA, TG_TABLE_NAME
      USING ERRCODE = '0A000';
  END IF;
  -- One writer per key at a time (with tg_bt_close): an END and a new version of the same key
  -- never interleave (BT-3).
  PERFORM platform.bt_lock_key(format('%I.%I', TG_TABLE_SCHEMA, TG_TABLE_NAME), TG_ARGV, to_jsonb(NEW));
  -- A version written while another transaction ended or retracted the same key is stale: that
  -- closure committed after this transaction began, so this transaction decided without seeing it.
  -- It is refused (retry), so a revocation is never undone by a version written at the same moment.
  IF to_regclass(format('%I.%I', TG_TABLE_SCHEMA, TG_TABLE_NAME || '_closure')) IS NOT NULL THEN
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I.%I c WHERE %s AND c.recorded_at >= transaction_timestamp()
                                     AND c.closing_xact <> pg_current_xact_id())',
                   TG_TABLE_SCHEMA, TG_TABLE_NAME || '_closure', platform.key_match_sql(TG_ARGV, 'c'))
      INTO v_stale USING NEW;
    IF v_stale THEN
      RAISE EXCEPTION 'KEY_CLOSED_MEANWHILE: %.% was ended or retracted by another transaction while this version was written; retry',
        TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '40001';
    END IF;
  END IF;
  v_sql := format('UPDATE %I.%I t SET superseded_at = ($1).recorded_at WHERE %s
                     AND t.superseded_at IS NULL AND t.recorded_at < ($1).recorded_at',
                  TG_TABLE_SCHEMA, TG_TABLE_NAME, platform.key_match_sql(TG_ARGV));
  IF NOT (to_jsonb(NEW) ? 'valid_period') THEN
    EXECUTE v_sql USING NEW;
    RETURN NULL;
  END IF;
  v_new := (to_jsonb(NEW) ->> 'valid_period')::daterange;
  FOR v_old IN EXECUTE v_sql || ' AND t.valid_period && ($1).valid_period RETURNING to_jsonb(t.*)' USING NEW
  LOOP
    -- BT-2: keep the parts of the old period before the new version starts and after it ends.
    FOREACH v_part IN ARRAY ARRAY[
        CASE WHEN lower_inf(v_new) THEN 'empty'::daterange
             ELSE (v_old ->> 'valid_period')::daterange * daterange(NULL, lower(v_new), '[)') END,
        CASE WHEN upper_inf(v_new) THEN 'empty'::daterange
             ELSE (v_old ->> 'valid_period')::daterange * daterange(upper(v_new), NULL, '[)') END]
    LOOP
      IF NOT isempty(v_part) THEN
        EXECUTE format('INSERT INTO %I.%I SELECT * FROM jsonb_populate_record(NULL::%I.%I, $1)',
                       TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_TABLE_SCHEMA, TG_TABLE_NAME)
          USING v_old || jsonb_build_object('valid_period', v_part::text, 'superseded_at', NULL,
                                            'recorded_at', to_jsonb(NEW) -> 'recorded_at');
      END IF;
    END LOOP;
  END LOOP;
  RETURN NULL;
END $$;

-- Transaction lock on one key of a version table (BT-3).  An END / RETRACT and a new version of
-- the same key never interleave: if another transaction is writing the key, this one is refused
-- with a serialization failure (40001) and retries, so it re-reads what that transaction did.
CREATE OR REPLACE FUNCTION platform.bt_lock_key(p_table text, p_keys text[], p_row jsonb) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtextextended(
           p_table || '|' || (SELECT string_agg(coalesce(p_row ->> k, ''), '|') FROM unnest(p_keys) AS k), 0)) THEN
    RAISE EXCEPTION 'KEY_BUSY: another transaction is changing this key of %; retry', p_table USING ERRCODE = '40001';
  END IF;
END $$;

-- BT-3, BT-4.  BEFORE INSERT on a closure table: the database sets the time and the actor (an
-- active user of the tenant).
CREATE OR REPLACE FUNCTION platform.tg_bt_closure_stamp() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.recorded_at  := clock_timestamp();
  NEW.closing_xact := pg_current_xact_id();
  NEW.closed_by    := platform.current_user_id();
  IF NEW.closed_by IS NULL OR NOT EXISTS (SELECT 1 FROM identity.app_user u
                                           WHERE u.tenant_id = NEW.tenant_id AND u.user_id = NEW.closed_by
                                             AND u.status = 'ACTIVE') THEN
    RAISE EXCEPTION 'NO_ACTOR: ending or retracting a version on %.% needs an active user of the tenant as the acting user (app.user_id)',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- BT-3, BT-4.  AFTER INSERT on a closure table.  Arguments: [0] the version table, [1..] its key
-- columns (the closure table has the same key columns).
CREATE OR REPLACE FUNCTION platform.tg_bt_close() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_table text := TG_ARGV[0];
  v_keys  text[] := TG_ARGV[1:TG_NARGS - 1];
  v_old   jsonb;
  v_left  daterange;
  n       int := 0;
BEGIN
  -- BT-3 concurrency rules rely on READ COMMITTED (each statement sees what committed before it);
  -- under REPEATABLE READ or SERIALIZABLE a closure committed meanwhile would stay invisible.
  IF current_setting('transaction_isolation') <> 'read committed' THEN
    RAISE EXCEPTION 'ISOLATION_NOT_SUPPORTED: versions of %.% are written only under READ COMMITTED', TG_TABLE_SCHEMA, TG_TABLE_NAME
      USING ERRCODE = '0A000';
  END IF;
  PERFORM platform.bt_lock_key(v_table, v_keys, to_jsonb(NEW));
  IF NEW.closure_kind = 'RETRACT' THEN
    EXECUTE format('UPDATE %s t SET superseded_at = ($1).recorded_at WHERE %s AND t.superseded_at IS NULL
                      AND t.recorded_at = ($1).target_recorded_at %s',
                   v_table, platform.key_match_sql(v_keys),
                   CASE WHEN NEW.target_valid_period IS NOT NULL
                        THEN 'AND t.valid_period = ($1).target_valid_period' ELSE '' END)
      USING NEW;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 1 THEN
      RAISE EXCEPTION 'NOTHING_TO_RETRACT: no single current version of % matches the retraction (% found)', v_table, n
        USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
  END IF;
  -- END: close every current version that reaches the end date or later; keep the part before it.
  FOR v_old IN EXECUTE format('UPDATE %s t SET superseded_at = ($1).recorded_at WHERE %s AND t.superseded_at IS NULL
                                 AND (upper_inf(t.valid_period) OR upper(t.valid_period) > ($1).end_date)
                               RETURNING to_jsonb(t.*)', v_table, platform.key_match_sql(v_keys)) USING NEW
  LOOP
    n := n + 1;
    v_left := (v_old ->> 'valid_period')::daterange * daterange(NULL, NEW.end_date, '[)');
    IF NOT isempty(v_left) THEN
      EXECUTE format('INSERT INTO %s SELECT * FROM jsonb_populate_record(NULL::%s, $1)', v_table, v_table)
        USING v_old || jsonb_build_object('valid_period', v_left::text, 'superseded_at', NULL,
                                          'recorded_at', to_jsonb(NEW.recorded_at));
    END IF;
  END LOOP;
  IF n = 0 THEN
    RAISE EXCEPTION 'NOTHING_TO_END: % has no current version on or after %', v_table, NEW.end_date
      USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END $$;

-- BT-4, BT-5 guard.  BEFORE UPDATE OR DELETE on a version table: only superseded_at may be set,
-- once, and only by tg_bt_supersede or tg_bt_close (trigger depth > 1), which set it to the
-- correcting row's or closure row's recorded_at.  A direct UPDATE is refused: a retraction is a
-- RETRACT row in the closure table, which records who, why and under which request (BT-4).
CREATE OR REPLACE FUNCTION platform.tg_bt_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: DELETE on %.% is not allowed; insert a correcting version or a closure row',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  IF OLD.superseded_at IS NOT NULL OR NEW.superseded_at IS NULL
     OR (to_jsonb(NEW) - 'superseded_at') IS DISTINCT FROM (to_jsonb(OLD) - 'superseded_at') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: only superseded_at may be set, once, on %.%',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  IF pg_trigger_depth() < 2 THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: %.% versions are closed only by a new version or a row in %_closure (BT-3, BT-4)',
      TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- M14 state machines as data.  BEFORE INSERT OR UPDATE.  Arguments:
--   [0] transition table (schema.table, columns from_state, to_state, cause)
--   [1] state column name
-- A new row must match a transition ('(NEW)' -> state, cause 'CREATE').  A state change must
-- match (old -> new, cause), where cause comes from SET LOCAL app.transition_cause
-- (default STATE_CHANGE).  States not named in the transition table are therefore refused on
-- insert and on update.  Self-moves are not transitions and pass unchanged (DM-5).
CREATE OR REPLACE FUNCTION platform.tg_state_machine() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_from  text;
  v_to    text := to_jsonb(NEW) ->> TG_ARGV[1];
  v_cause text;
  v_ok    boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_from := '(NEW)'; v_cause := 'CREATE';
  ELSE
    v_from := to_jsonb(OLD) ->> TG_ARGV[1];
    IF v_from IS NOT DISTINCT FROM v_to THEN RETURN NEW; END IF;
    v_cause := coalesce(NULLIF(current_setting('app.transition_cause', true), ''), 'STATE_CHANGE');
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM %s WHERE from_state = $1 AND to_state = $2 AND cause = $3)',
                 TG_ARGV[0]) INTO v_ok USING v_from, v_to, v_cause;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'ILLEGAL_TRANSITION: %.% % -> % (cause %)', TG_TABLE_SCHEMA, TG_TABLE_NAME,
      v_from, coalesce(v_to, 'NULL'), v_cause USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;

-- M14 history.  AFTER INSERT OR UPDATE.  Arguments:
--   [0] history table (schema.table), [1] state column, [2..] key columns of the entity.
-- The history table has: tenant_id, the key columns, from_state, to_state, cause, changed_at,
-- changed_by.  (The outbox row M14 also asks for is ADR-0020 / DM-4 and is not built here.)
CREATE OR REPLACE FUNCTION platform.tg_state_history() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_from  text;
  v_to    text := to_jsonb(NEW) ->> TG_ARGV[1];
  v_cause text;
  v_keys  text[] := TG_ARGV[2:TG_NARGS - 1];
  v_cols  text;
  v_vals  text;
  v_ok    boolean;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_from := '(NEW)'; v_cause := 'CREATE';
  ELSE
    v_from := to_jsonb(OLD) ->> TG_ARGV[1];
    IF v_from IS NOT DISTINCT FROM v_to THEN RETURN NULL; END IF;
    v_cause := coalesce(NULLIF(current_setting('app.transition_cause', true), ''), 'STATE_CHANGE');
    -- The cause is read again here; check it again, so a cause changed after the BEFORE trigger
    -- ran (same statement) cannot be written to the history.
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %s WHERE from_state = $1 AND to_state = $2 AND cause = $3)',
                   regexp_replace(TG_ARGV[0], '_history$', '_transition')) INTO v_ok USING v_from, v_to, v_cause;
    IF NOT v_ok THEN
      RAISE EXCEPTION 'ILLEGAL_TRANSITION: history for %.% % -> % (cause %) does not match a transition',
        TG_TABLE_SCHEMA, TG_TABLE_NAME, v_from, coalesce(v_to, 'NULL'), v_cause USING ERRCODE = '23514';
    END IF;
  END IF;
  SELECT string_agg(format('%I', k), ', '), string_agg(format('($1).%I', k), ', ')
    INTO v_cols, v_vals FROM unnest(v_keys) AS k;
  EXECUTE format('INSERT INTO %s (tenant_id, %s, from_state, to_state, cause, changed_by)
                  VALUES (($1).tenant_id, %s, $2, $3, $4, platform.current_user_id())',
                 TG_ARGV[0], v_cols, v_vals)
    USING NEW, v_from, v_to, v_cause;
  RETURN NULL;
END $$;

-- Load runs (DA-001 §3.3): a run may be updated only while RUNNING (to record counts and the
-- final status); afterwards it is frozen.  Never deleted.
CREATE OR REPLACE FUNCTION platform.tg_load_run_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' OR OLD.status <> 'RUNNING' THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: load run % is final', OLD.load_run_id USING ERRCODE = '42501';
  END IF;
  IF NEW.load_run_id <> OLD.load_run_id OR NEW.started_at <> OLD.started_at
     OR NEW.adapter_name <> OLD.adapter_name OR NEW.adapter_version <> OLD.adapter_version
     OR NEW.canonical_family <> OLD.canonical_family
     OR NEW.business_date IS DISTINCT FROM OLD.business_date
     OR NEW.inbound_file_id IS DISTINCT FROM OLD.inbound_file_id
     OR NEW.message_session_ref IS DISTINCT FROM OLD.message_session_ref THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: identity columns of load run % cannot change', OLD.load_run_id
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- Loaded rows (§3.3): a new row may cite only a load run that is still RUNNING (rows are loaded
-- during the run; a FAILED or COMPLETED run takes no more rows).  Continuations written by the
-- bi-temporal triggers (BT-5, recognised from data) keep the load run of the row they continue.
-- Argument: the owning schema's load_run table.
CREATE OR REPLACE FUNCTION platform.tg_load_run_open() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_status text;
BEGIN
  IF NEW.load_run_id IS NULL OR platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN RETURN NEW; END IF;
  -- FOR SHARE: the run cannot be completed while this row is uncommitted.  The completion step
  -- locks the run (SELECT ... FOR UPDATE) before it counts rows, so it waits for this row.
  EXECUTE format('SELECT status FROM %s WHERE tenant_id = $1 AND load_run_id = $2 FOR SHARE', TG_ARGV[0])
    INTO v_status USING NEW.tenant_id, NEW.load_run_id;
  IF v_status IS DISTINCT FROM 'RUNNING' THEN
    RAISE EXCEPTION 'LOAD_RUN_CLOSED: load run % is %, rows can be added only while it is RUNNING',
      NEW.load_run_id, coalesce(v_status, 'unknown') USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;

-- History rows of state machines are written only by platform.tg_state_history (which runs as a
-- trigger, so its insert is at trigger depth 2); a direct insert by any role is refused.
CREATE OR REPLACE FUNCTION platform.tg_history_via_trigger_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF pg_trigger_depth() < 2 THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: %.% is written only by the state-machine trigger',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- Migration helpers (session-local; they disappear when this script ends).
-- Adds the standard bi-temporal triggers to a version table, and its closure table
-- <table>_closure (BT-3 END rows, BT-4 RETRACT rows) with the same key columns.
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
      end_date            date,           -- END: the key has no version from this date on
      target_valid_period daterange,      -- RETRACT: the current version to retract
      target_recorded_at  timestamptz,
      recorded_at         timestamptz NOT NULL DEFAULT clock_timestamp(),  -- set by the database
      closing_xact        xid8 NOT NULL DEFAULT pg_current_xact_id(),       -- set by the database
      closed_by           uuid NOT NULL,                                    -- set by the database (app.user_id)
      request_id          uuid NOT NULL,  -- the approved request this follows (ID reference, M4, unless a table adds a FK)
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

-- Adds a product-level transition table, a tenant history table and both state triggers to a
-- state-machine entity.  p_keys are the entity's key columns after tenant_id, with their types.
CREATE FUNCTION pg_temp.make_state_machine(p_schema text, p_table text, p_state_col text,
                                           p_keys text[], p_key_types text[]) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
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
    )', p_schema, p_table || '_transition');
  EXECUTE format('COMMENT ON TABLE %I.%I IS %L', p_schema, p_table || '_transition',
    'Product-level list of allowed state moves (DA-001 M3, M14). No tenant column; read-only for application roles; changed only by migration.');
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
    )', p_schema, p_table || '_history', v_cols, v_keylist, v_keylist, p_schema, p_table, v_keylist);
  EXECUTE format('CREATE TRIGGER history_immutable BEFORE UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable()',
                 p_schema, p_table || '_history');
  EXECUTE format('CREATE TRIGGER history_via_trigger_only BEFORE INSERT ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_history_via_trigger_only()',
                 p_schema, p_table || '_history');
  EXECUTE format('CREATE TRIGGER state_machine BEFORE INSERT OR UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_state_machine(%L, %L)',
                 p_schema, p_table, p_schema || '.' || p_table || '_transition', p_state_col);
  SELECT string_agg(quote_literal(k), ', ') INTO v_args FROM unnest(p_keys) AS k;
  EXECUTE format('CREATE TRIGGER state_history AFTER INSERT OR UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION platform.tg_state_history(%L, %L, %s)',
                 p_schema, p_table, p_schema || '.' || p_table || '_history', p_state_col, v_args);
END $$;

-- Adds the M9 provenance columns to a table that holds copies of outside data, with a foreign
-- key to the owning schema's load_run.  A row is either typed in by a person
-- (source_system = 'AMC_OS_MANUAL', with an approval reference) or loaded (load run and the
-- provider's record reference are then required).
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

-- ---------------------------------------------------------------------
-- 01  Numeric widening (DA-001 §3.7, DM-22): amounts numeric(20,4) -> numeric(24,4).
--     Precision only; no scale changes, nothing narrows, so no stored value changes.
-- ---------------------------------------------------------------------
ALTER TABLE settlement.trade
  ALTER COLUMN brokerage     TYPE numeric(24,4),
  ALTER COLUMN stt           TYPE numeric(24,4),
  ALTER COLUMN stamp_duty    TYPE numeric(24,4),
  ALTER COLUMN gst           TYPE numeric(24,4),
  ALTER COLUMN other_charges TYPE numeric(24,4);
ALTER TABLE investor.investor_txn
  ALTER COLUMN stamp_duty TYPE numeric(24,4),
  ALTER COLUMN exit_load  TYPE numeric(24,4),
  ALTER COLUMN tds        TYPE numeric(24,4);
ALTER TABLE investor.sip_registration
  ALTER COLUMN amount TYPE numeric(24,4);
ALTER TABLE distribution.commission_line
  ALTER COLUMN gross_commission TYPE numeric(24,4),
  ALTER COLUMN gst              TYPE numeric(24,4),
  ALTER COLUMN tds              TYPE numeric(24,4),
  ALTER COLUMN clawback         TYPE numeric(24,4),
  ALTER COLUMN net_payable      TYPE numeric(24,4);

-- ---------------------------------------------------------------------
-- 02  platform  (Tenant module, D01; DA-001 §4.1)
-- ---------------------------------------------------------------------

-- This cell's own identity (EA-004 §1-§3). Product-level row, no tenant column (M3).
CREATE TABLE platform.cell (
  cell_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cell_code   text NOT NULL UNIQUE CHECK (cell_code ~ '^[A-Z0-9_-]{3,40}$'),
  cell_kind   text NOT NULL CHECK (cell_kind IN ('PRODUCTION','NON_PRODUCTION','VENDOR_TEST')),
  cell_shape  text NOT NULL CHECK (cell_shape IN ('SHARED','DEDICATED')),
  region      text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  row_version integer NOT NULL DEFAULT 1
);
COMMENT ON TABLE platform.cell IS 'One row per cell (DA-001 §4.1, DM-16). Written by the cell agent from signed desired state; read-only for application roles.';
CREATE TRIGGER cell_version BEFORE UPDATE ON platform.cell
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Tenant record changes (DM-16).  DEDICATED_DB dropped [ASSUMPTION - owner Q69 default];
-- MIGRATED_OUT added for the source copy of a tenant that moved to another cell (EA-004 §6).
ALTER TABLE platform.tenant DROP CONSTRAINT tenant_isolation_tier_check;
ALTER TABLE platform.tenant DROP CONSTRAINT tenant_status_check;
ALTER TABLE platform.tenant
  ADD CONSTRAINT tenant_isolation_tier_check CHECK (isolation_tier IN ('SHARED','DEDICATED_DEPLOYMENT')),
  ADD CONSTRAINT tenant_status_check
      CHECK (status IN ('ONBOARDING','ACTIVE','SUSPENDED','OFFBOARDING','MIGRATED_OUT','ARCHIVED')),
  ADD COLUMN hosting_account text NOT NULL DEFAULT 'VENDOR' CHECK (hosting_account IN ('VENDOR','AMC')),
  ADD COLUMN cell_id uuid REFERENCES platform.cell,
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
  ADD CONSTRAINT tenant_cell_required CHECK (status = 'ONBOARDING' OR cell_id IS NOT NULL);
CREATE TRIGGER tenant_version BEFORE UPDATE ON platform.tenant
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Every tenant status change, written by trigger in the same transaction (FR-D01-002).
CREATE TABLE platform.tenant_status_history (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  changed_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  from_status   text,
  to_status     text NOT NULL,
  confirmed_by  uuid,                 -- person in the cell who confirmed (EA-006 §1.3); ID reference
  desired_state_ref text,             -- signed desired-state step that caused it, if any
  PRIMARY KEY (tenant_id, changed_at)
);
CREATE TRIGGER tenant_status_history_immutable BEFORE UPDATE OR DELETE ON platform.tenant_status_history
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

CREATE OR REPLACE FUNCTION platform.tg_tenant_status_history() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO platform.tenant_status_history (tenant_id, from_status, to_status, confirmed_by, desired_state_ref)
    VALUES (NEW.tenant_id, CASE WHEN TG_OP = 'UPDATE' THEN OLD.status END, NEW.status,
            platform.current_user_id(), NULLIF(current_setting('app.desired_state_ref', true), ''));
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER tenant_status_history AFTER INSERT OR UPDATE ON platform.tenant
  FOR EACH ROW EXECUTE FUNCTION platform.tg_tenant_status_history();

-- Subscription as received from the control plane (D-14).  BT anchor + versions (§3.1 rule 1).
CREATE TABLE platform.subscription (
  tenant_id       uuid NOT NULL REFERENCES platform.tenant,
  subscription_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, subscription_id)
);
CREATE TABLE platform.subscription_version (
  tenant_id         uuid NOT NULL,
  subscription_id   uuid NOT NULL,
  valid_period      daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at     timestamptz,
  plan_code         text NOT NULL,
  desired_state_ref text NOT NULL,   -- the signed desired-state step this version came from
  desired_state_hash bytea NOT NULL,
  PRIMARY KEY (tenant_id, subscription_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, subscription_id) REFERENCES platform.subscription (tenant_id, subscription_id),
  EXCLUDE USING gist (tenant_id WITH =, subscription_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('platform.subscription_version', ARRAY['tenant_id','subscription_id']);

-- What the tenant may use per module, from when (D-14; D-26: a lapsed module becomes read-only).
-- Limit columns hold whatever the subscription says; no value is set here.
CREATE TABLE platform.tenant_entitlement (
  tenant_id         uuid NOT NULL REFERENCES platform.tenant,
  module_code       text NOT NULL CHECK (module_code ~ '^[A-Z_]{2,40}$'),
  valid_period      daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at     timestamptz,
  access_mode       text NOT NULL CHECK (access_mode IN ('FULL','READ_ONLY')),
  max_users         integer CHECK (max_users >= 0),
  max_schemes       integer CHECK (max_schemes >= 0),
  max_api_calls_per_day bigint CHECK (max_api_calls_per_day >= 0),
  max_storage_gb    numeric(24,6) CHECK (max_storage_gb >= 0),
  desired_state_ref text NOT NULL,
  PRIMARY KEY (tenant_id, module_code, valid_period, recorded_at),
  EXCLUDE USING gist (tenant_id WITH =, module_code WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('platform.tenant_entitlement', ARRAY['tenant_id','module_code']);

-- Usage counts per tenant, meter and day (D-26; counts only, EA-006 CP-4).
CREATE TABLE platform.usage_meter (
  tenant_id   uuid NOT NULL REFERENCES platform.tenant,
  meter_code  text NOT NULL CHECK (meter_code IN ('USERS','SCHEMES','API_CALLS','STORAGE_GB')),
  usage_date  date NOT NULL,
  module_code text NOT NULL DEFAULT 'ALL',
  quantity    numeric(24,6) NOT NULL CHECK (quantity >= 0),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, meter_code, usage_date, module_code)
);
CREATE TRIGGER usage_meter_immutable BEFORE UPDATE OR DELETE ON platform.usage_meter
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- Organisation units in one tree (CAP-D01-007).  BT anchor + versions.
CREATE TABLE platform.organisation_unit (
  tenant_id   uuid NOT NULL REFERENCES platform.tenant,
  org_unit_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, org_unit_id)
);
CREATE TABLE platform.organisation_unit_version (
  tenant_id      uuid NOT NULL,
  org_unit_id    uuid NOT NULL,
  valid_period   daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at    timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at  timestamptz,
  unit_code      text NOT NULL,
  unit_name      text NOT NULL,
  unit_type      text NOT NULL CHECK (unit_type IN ('LEGAL_ENTITY','DEPARTMENT','BRANCH','REGION','ZONE','COST_CENTRE')),
  parent_org_unit_id uuid,
  department_code text CHECK (department_code ~ '^DEP-[0-9]{2}$'),   -- BA-002 department, where it is one
  approval_request_id uuid NOT NULL,                                -- ID reference (M4, §3.6)
  PRIMARY KEY (tenant_id, org_unit_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, org_unit_id) REFERENCES platform.organisation_unit (tenant_id, org_unit_id),
  FOREIGN KEY (tenant_id, parent_org_unit_id) REFERENCES platform.organisation_unit (tenant_id, org_unit_id),
  CHECK (parent_org_unit_id IS DISTINCT FROM org_unit_id),
  EXCLUDE USING gist (tenant_id WITH =, org_unit_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED,
  EXCLUDE USING gist (tenant_id WITH =, unit_code WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('platform.organisation_unit_version', ARRAY['tenant_id','org_unit_id']);

-- The unit tree has no cycles (checked at commit over the current versions).
CREATE OR REPLACE FUNCTION platform.tg_org_unit_no_cycle() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_cycle boolean;
BEGIN
  -- Walk up the tree, keeping only links that are valid on some common date with the path so far.
  WITH RECURSIVE up(org_unit_id, period, depth) AS (
      SELECT v.parent_org_unit_id, v.valid_period, 1 FROM platform.organisation_unit_version v
       WHERE v.tenant_id = NEW.tenant_id AND v.org_unit_id = NEW.org_unit_id AND v.superseded_at IS NULL
         AND v.parent_org_unit_id IS NOT NULL AND v.valid_period && NEW.valid_period
    UNION ALL
      SELECT v.parent_org_unit_id, up.period * v.valid_period, up.depth + 1 FROM up
        JOIN platform.organisation_unit_version v
          ON v.tenant_id = NEW.tenant_id AND v.org_unit_id = up.org_unit_id AND v.superseded_at IS NULL
       WHERE v.parent_org_unit_id IS NOT NULL AND v.valid_period && up.period
         AND up.org_unit_id <> NEW.org_unit_id AND up.depth < 1000)
  SELECT EXISTS (SELECT 1 FROM up WHERE org_unit_id = NEW.org_unit_id) INTO v_cycle;
  IF v_cycle THEN
    RAISE EXCEPTION 'ORG_UNIT_CYCLE: unit % would be its own ancestor', NEW.org_unit_id USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER organisation_unit_no_cycle AFTER INSERT ON platform.organisation_unit_version
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION platform.tg_org_unit_no_cycle();

-- Who reports to whom (FR-D01-032).  Subjects and managers are users (identity) or units;
-- both are ID references (M4), checked by the Tenant module.
CREATE TABLE platform.reporting_line (
  tenant_id         uuid NOT NULL REFERENCES platform.tenant,
  reporting_line_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, reporting_line_id)
);
CREATE TABLE platform.reporting_line_version (
  tenant_id         uuid NOT NULL,
  reporting_line_id uuid NOT NULL,
  valid_period      daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at       timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at     timestamptz,
  subject_type      text NOT NULL CHECK (subject_type IN ('USER','ORG_UNIT')),
  subject_id        uuid NOT NULL,
  manager_type      text NOT NULL CHECK (manager_type IN ('USER','ORG_UNIT')),
  manager_id        uuid NOT NULL,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, reporting_line_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, reporting_line_id) REFERENCES platform.reporting_line (tenant_id, reporting_line_id),
  CHECK (NOT (subject_type = manager_type AND subject_id = manager_id)),
  EXCLUDE USING gist (tenant_id WITH =, reporting_line_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED,
  EXCLUDE USING gist (tenant_id WITH =, subject_type WITH =, subject_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED      -- one manager per subject per date [DES]
);
SELECT pg_temp.make_bitemporal('platform.reporting_line_version', ARRAY['tenant_id','reporting_line_id']);

-- Business calendar becomes bi-temporal (M7; §3.1 rule 2): recorded_at joins the key and one
-- current row per calendar day is kept by a partial unique index.
ALTER TABLE platform.business_calendar
  ADD COLUMN recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN superseded_at timestamptz,
  ADD COLUMN approval_request_id uuid;
ALTER TABLE platform.business_calendar DROP CONSTRAINT business_calendar_pkey;
ALTER TABLE platform.business_calendar ADD PRIMARY KEY (tenant_id, calendar_code, cal_date, recorded_at);
ALTER TABLE platform.business_calendar ADD CONSTRAINT business_calendar_one_current
  EXCLUDE USING gist (tenant_id WITH =, calendar_code WITH =, cal_date WITH =)
  WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED;
SELECT pg_temp.make_bitemporal('platform.business_calendar', ARRAY['tenant_id','calendar_code','cal_date']);

-- Configuration (EA-008 §3, §5, §8; DM-21).
-- Catalogue: product-level rows loaded with each release (M3).
CREATE TABLE platform.config_item (
  item_key          text NOT NULL CHECK (item_key ~ '^d[0-9]{2}\.[a-z0-9_]+\.[a-z0-9_]+$'),
  release           text NOT NULL,
  owning_module     text NOT NULL,
  owning_department text NOT NULL CHECK (owning_department ~ '^DEP-[0-9]{2}$'),
  value_type        text NOT NULL CHECK (value_type IN ('BOOLEAN','INTEGER','DECIMAL','TEXT','CODE','DATE','TIME','DURATION')),
  value_schema      jsonb NOT NULL,          -- allowed values / range / unit, validated before saving (M20)
  default_value     jsonb,                   -- NULL = no default (regulatory values never have one)
  required_before_use boolean NOT NULL,
  allowed_scopes    text[] NOT NULL CHECK (allowed_scopes <@ ARRAY['TENANT','SCHEME'] AND 'TENANT' = ANY (allowed_scopes)),
  is_regulatory     boolean NOT NULL,
  is_technical      boolean NOT NULL,
  is_sensitive      boolean NOT NULL DEFAULT false,
  introduced_in     text NOT NULL,
  deprecated_in     text,
  PRIMARY KEY (item_key, release),
  CHECK (NOT is_regulatory OR default_value IS NULL)     -- EA-008 §3: no regulatory defaults
);
COMMENT ON TABLE platform.config_item IS 'Configuration catalogue (EA-008 §3). Product-level, no tenant column (DA-001 M3); changed only by migration.';

CREATE TABLE platform.config_version (
  tenant_id          uuid NOT NULL REFERENCES platform.tenant,
  config_version_id  uuid NOT NULL DEFAULT gen_random_uuid(),
  release            text NOT NULL,              -- catalogue release the values were validated against
  status             text NOT NULL DEFAULT 'DRAFT',
  valid_period       daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  maker_user_id      uuid NOT NULL,
  approval_request_id uuid,
  approved_on        date,                       -- set by the database when the version is approved
  values_hash        text,                       -- hash of the values the validator checked
  supersedes_version_id uuid,
  withdrawal_request_id uuid,                    -- approved request to withdraw it (D-77), ID reference (M4)
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  row_version        integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, config_version_id),
  FOREIGN KEY (tenant_id, supersedes_version_id) REFERENCES platform.config_version (tenant_id, config_version_id),
  CHECK (status NOT IN ('APPROVED','EFFECTIVE','SUPERSEDED','WITHDRAWN') OR (approval_request_id IS NOT NULL AND approved_on IS NOT NULL)),
  CHECK (approved_on IS NULL OR lower(valid_period) >= approved_on),  -- EA-008 §5: never applies to the past
  CHECK (status IN ('DRAFT') OR values_hash IS NOT NULL),
  CHECK (status <> 'DRAFT' OR (approved_on IS NULL AND approval_request_id IS NULL)),
  CHECK ((status = 'WITHDRAWN') = (withdrawal_request_id IS NOT NULL)),
  -- Owner decision D-77 (24 Nov 2026): a version holds the tenant's complete configuration and
  -- applies from its start date until a later approved version starts, so its period is
  -- open-ended (no end dates).  The version in force on date D is the latest version in
  -- APPROVED, EFFECTIVE or SUPERSEDED whose start is on or before D (platform.config_version_in_force):
  -- SUPERSEDED means "no longer the newest" (EA-008 §4 rule 2) and still counts for past dates.
  -- WITHDRAWN (found wrong before its start date) never counts.  So no two versions in those three
  -- statuses may start on the same date.
  CHECK (upper_inf(valid_period)),
  EXCLUDE USING gist (tenant_id WITH =, (lower(valid_period)) WITH =)
    WHERE (status IN ('APPROVED','EFFECTIVE','SUPERSEDED')) DEFERRABLE INITIALLY DEFERRED
);
CREATE TRIGGER config_version_version BEFORE UPDATE ON platform.config_version
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- The hash of a version's values, in a fixed text form.  The validator computes it over the values
-- it checked and sends it with the move to VALIDATED; the move is refused if the values changed.
CREATE OR REPLACE FUNCTION platform.config_values_hash(p_tenant uuid, p_version uuid) RETURNS text
LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN (SELECT encode(digest(coalesce(string_agg(item_key || '|' || scope_type || '|' || scope_id || '|' || value::text, E'\n'
                                                   ORDER BY item_key, scope_type, scope_id), ''), 'sha256'), 'hex')
            FROM platform.config_value WHERE tenant_id = p_tenant AND config_version_id = p_version);
END $$;

-- The configuration version in force for a tenant on a business date (D-77).
CREATE OR REPLACE FUNCTION platform.config_version_in_force(p_tenant uuid, p_date date) RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT config_version_id FROM platform.config_version
   WHERE tenant_id = p_tenant AND status IN ('APPROVED','EFFECTIVE','SUPERSEDED')
     AND lower(valid_period) <= p_date
   ORDER BY lower(valid_period) DESC
   LIMIT 1
$$;

-- Moves that need database facts: DRAFT -> VALIDATED checks the values hash; -> APPROVED stamps
-- approved_on with today's business date (EA-008 §5: a version never applies to the past);
-- APPROVED -> EFFECTIVE only once the start date is reached (EA-008 §5); APPROVED -> WITHDRAWN only
-- before the start date; EFFECTIVE -> SUPERSEDED only when a later approved version has become
-- effective, i.e. its start date is reached (D-77; EA-008 §5 "a newer version becomes effective").
-- So a version used to supersede another is already in force and can never be withdrawn.
CREATE OR REPLACE FUNCTION platform.tg_config_version_moves() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'VALIDATED' AND OLD.status = 'DRAFT'
     AND NEW.values_hash IS DISTINCT FROM platform.config_values_hash(NEW.tenant_id, NEW.config_version_id) THEN
    RAISE EXCEPTION 'VALUES_CHANGED: values of configuration version % differ from what was validated', NEW.config_version_id
      USING ERRCODE = '40001';
  END IF;
  IF NEW.status = 'DRAFT' AND OLD.status <> 'DRAFT' THEN
    NEW.values_hash := NULL;                       -- rejected: validate again
  END IF;
  IF NEW.status = 'APPROVED' AND OLD.status <> 'APPROVED' THEN
    NEW.approved_on := platform.today_ist();
  ELSIF NEW.approved_on IS DISTINCT FROM OLD.approved_on AND OLD.status NOT IN ('APPROVED','EFFECTIVE','SUPERSEDED','WITHDRAWN') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: approved_on is set by the database at approval' USING ERRCODE = '42501';
  END IF;
  IF NEW.status = 'WITHDRAWN' AND OLD.status <> 'WITHDRAWN' AND lower(OLD.valid_period) <= platform.today_ist() THEN
    RAISE EXCEPTION 'VERSION_IN_FORCE: configuration version % has applied since %; correct it with a new version (EA-008 §5)',
      OLD.config_version_id, lower(OLD.valid_period) USING ERRCODE = '23514';
  END IF;
  IF NEW.status = 'EFFECTIVE' AND OLD.status <> 'EFFECTIVE' AND lower(OLD.valid_period) > platform.today_ist() THEN
    RAISE EXCEPTION 'NOT_YET_IN_FORCE: configuration version % starts on %', OLD.config_version_id, lower(OLD.valid_period)
      USING ERRCODE = '23514';
  END IF;
  IF NEW.status = 'SUPERSEDED' AND OLD.status <> 'SUPERSEDED'
     AND NOT EXISTS (SELECT 1 FROM platform.config_version v
                      WHERE v.tenant_id = OLD.tenant_id AND v.config_version_id <> OLD.config_version_id
                        AND v.status IN ('APPROVED','EFFECTIVE','SUPERSEDED')
                        AND lower(v.valid_period) > lower(OLD.valid_period)
                        AND lower(v.valid_period) <= platform.today_ist()
                        FOR SHARE) THEN
    RAISE EXCEPTION 'NO_LATER_VERSION: configuration version % can be superseded only by a later version that is already in force',
      OLD.config_version_id USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER config_version_moves BEFORE UPDATE ON platform.config_version
  FOR EACH ROW EXECUTE FUNCTION platform.tg_config_version_moves();
SELECT pg_temp.make_state_machine('platform', 'config_version', 'status',
  ARRAY['config_version_id'], ARRAY['uuid']);
-- EA-008 §5 lifecycle.
INSERT INTO platform.config_version_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  ('DRAFT','VALIDATED','STATE_CHANGE'),
  ('VALIDATED','TESTED','STATE_CHANGE'),
  ('TESTED','SUBMITTED','STATE_CHANGE'),
  ('SUBMITTED','APPROVED','STATE_CHANGE'),
  ('SUBMITTED','DRAFT','REJECT'),
  ('APPROVED','EFFECTIVE','STATE_CHANGE'),
  ('EFFECTIVE','SUPERSEDED','STATE_CHANGE'),     -- only when a later approved version is in force (D-77)
  ('APPROVED','WITHDRAWN','STATE_CHANGE');       -- D-77: found wrong before its start date; never counts

-- Content is frozen from SUBMITTED on (the checker approves exactly what was submitted); from
-- APPROVED on the approval fields are frozen too.  Only status (and its bookkeeping) moves;
-- WITHDRAWN is final.
CREATE OR REPLACE FUNCTION platform.tg_config_version_frozen() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: configuration versions are never deleted (FR-D01-034)' USING ERRCODE = '42501';
  END IF;
  IF OLD.status IN ('SUBMITTED','APPROVED','EFFECTIVE','SUPERSEDED','WITHDRAWN')
     AND (to_jsonb(NEW) - 'status' - 'approval_request_id' - 'approved_on' - 'withdrawal_request_id' - 'updated_at' - 'row_version')
         IS DISTINCT FROM
         (to_jsonb(OLD) - 'status' - 'approval_request_id' - 'approved_on' - 'withdrawal_request_id' - 'updated_at' - 'row_version') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: configuration version % is % and cannot be edited; create a new version',
      OLD.config_version_id, OLD.status USING ERRCODE = '42501';
  END IF;
  IF OLD.status IN ('APPROVED','EFFECTIVE','SUPERSEDED')
     AND (NEW.approval_request_id IS DISTINCT FROM OLD.approval_request_id OR NEW.approved_on IS DISTINCT FROM OLD.approved_on) THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: approval of configuration version % cannot change', OLD.config_version_id
      USING ERRCODE = '42501';
  END IF;
  -- The withdrawal reference is written only with the move APPROVED -> WITHDRAWN (D-77).
  IF NEW.withdrawal_request_id IS DISTINCT FROM OLD.withdrawal_request_id
     AND NOT (OLD.status = 'APPROVED' AND NEW.status = 'WITHDRAWN') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: withdrawal of configuration version % is recorded only when it is withdrawn',
      OLD.config_version_id USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER config_version_frozen BEFORE UPDATE OR DELETE ON platform.config_version
  FOR EACH ROW EXECUTE FUNCTION platform.tg_config_version_frozen();

CREATE TABLE platform.config_value (
  tenant_id         uuid NOT NULL,
  config_version_id uuid NOT NULL,
  item_key          text NOT NULL,
  scope_type        text NOT NULL CHECK (scope_type IN ('TENANT','SCHEME')),
  scope_id          uuid NOT NULL,           -- tenant ID or scheme ID (ID reference, M4)
  value             jsonb NOT NULL,          -- validated against config_item.value_schema (M20)
  PRIMARY KEY (tenant_id, config_version_id, item_key, scope_type, scope_id),
  FOREIGN KEY (tenant_id, config_version_id) REFERENCES platform.config_version (tenant_id, config_version_id),
  CHECK (scope_type <> 'TENANT' OR scope_id = tenant_id)
);
-- Values belong to their version: they can be added or changed only while it is DRAFT.
CREATE OR REPLACE FUNCTION platform.tg_config_value_draft_only() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_status text; v_row platform.config_value;
BEGIN
  v_row := CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  -- FOR SHARE: a concurrent status change waits until this value is committed or rolled back.
  SELECT status INTO v_status FROM platform.config_version
   WHERE tenant_id = v_row.tenant_id AND config_version_id = v_row.config_version_id
     FOR SHARE;
  IF v_status IS DISTINCT FROM 'DRAFT'
     OR (TG_OP = 'UPDATE' AND (OLD.tenant_id, OLD.config_version_id) IS DISTINCT FROM (NEW.tenant_id, NEW.config_version_id)) THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: values of configuration version % can change only while it is DRAFT',
      v_row.config_version_id USING ERRCODE = '42501';
  END IF;
  RETURN v_row;
END $$;
CREATE TRIGGER config_value_draft_only BEFORE INSERT OR UPDATE OR DELETE ON platform.config_value
  FOR EACH ROW EXECUTE FUNCTION platform.tg_config_value_draft_only();

CREATE TABLE platform.config_promotion (
  tenant_id          uuid NOT NULL,
  promotion_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  config_version_id  uuid NOT NULL,
  bundle_hash        bytea NOT NULL,
  source_environment text NOT NULL,
  target_environment text NOT NULL CHECK (target_environment <> source_environment),
  promoted_at        timestamptz NOT NULL DEFAULT now(),
  promoted_by        uuid NOT NULL,
  PRIMARY KEY (tenant_id, promotion_id),
  FOREIGN KEY (tenant_id, config_version_id) REFERENCES platform.config_version (tenant_id, config_version_id)
);
CREATE TRIGGER config_promotion_immutable BEFORE UPDATE OR DELETE ON platform.config_promotion
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- Product-level code lists shipped with releases (M3).
CREATE TABLE platform.code_list (
  list_code   text NOT NULL CHECK (list_code ~ '^[A-Z][A-Z0-9_]{1,40}$'),
  version_no  integer NOT NULL CHECK (version_no > 0),
  description text NOT NULL,
  release     text NOT NULL,
  PRIMARY KEY (list_code, version_no)
);
CREATE TABLE platform.code_value (
  list_code   text NOT NULL,
  version_no  integer NOT NULL,
  value       text NOT NULL,
  label       text NOT NULL,
  sort_order  integer,
  is_active   boolean NOT NULL DEFAULT true,
  PRIMARY KEY (list_code, version_no, value),
  FOREIGN KEY (list_code, version_no) REFERENCES platform.code_list (list_code, version_no)
);

-- Release-delivered feature flags and the tenant's state for each (PRD-001 §10).
CREATE TABLE platform.feature_flag (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  flag_key      text NOT NULL CHECK (flag_key ~ '^[a-z0-9_.]+$'),
  introduced_in text NOT NULL,
  is_enabled    boolean NOT NULL DEFAULT false,
  approval_request_id uuid,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, flag_key),
  CHECK (NOT is_enabled OR approval_request_id IS NOT NULL)
);
CREATE TRIGGER feature_flag_version BEFORE UPDATE ON platform.feature_flag
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Tenant-scoped schedule rows that start calendar-driven jobs (EA-005 §2).
CREATE TABLE platform.schedule_entry (
  tenant_id         uuid NOT NULL REFERENCES platform.tenant,
  schedule_entry_id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_code          text NOT NULL CHECK (job_code ~ '^[a-z0-9_.]+$'),
  owning_module     text NOT NULL,
  calendar_code     text NOT NULL,                -- business calendar it follows (T17)
  run_rule          jsonb NOT NULL,               -- when it runs, in calendar terms (M20)
  valid_period      daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status            text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','PAUSED','RETIRED')),
  approval_request_id uuid NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  row_version       integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, schedule_entry_id)
);
CREATE TRIGGER schedule_entry_version BEFORE UPDATE ON platform.schedule_entry
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Releases and migration steps applied in this cell (one row per release; M3).
CREATE TABLE platform.environment_release (
  release_id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cell_id        uuid NOT NULL REFERENCES platform.cell,
  release        text NOT NULL,
  migration_step text NOT NULL,
  artefact_digest bytea NOT NULL,       -- signed artefact (EA-006 CP-2)
  applied_at     timestamptz NOT NULL DEFAULT now(),
  outcome        text NOT NULL CHECK (outcome IN ('APPLIED','FAILED','ROLLED_BACK')),
  UNIQUE (cell_id, release, migration_step, applied_at)
);
CREATE TRIGGER environment_release_immutable BEFORE UPDATE OR DELETE ON platform.environment_release
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- Where operational notices go: role mailboxes and channels, never personal data (M22).
CREATE TABLE platform.notification_channel (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  channel_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  channel_type  text NOT NULL CHECK (channel_type IN ('EMAIL','WEBHOOK','CHAT')),
  purpose_code  text NOT NULL,
  address       text NOT NULL,
  status        text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, channel_id),
  UNIQUE (tenant_id, purpose_code, channel_type, address)
);
CREATE TRIGGER notification_channel_version BEFORE UPDATE ON platform.notification_channel
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- ---------------------------------------------------------------------
-- 03  identity  (Identity module, D01; DA-001 §4.2)
--     Not here (ADR-0020): break_glass_grant (DM-18); unchangeable is_service_identity (DM-20).
-- ---------------------------------------------------------------------

-- Provenance of users pushed from the AMC's identity provider (INT-015): one change at a time,
-- so no load run; the IdP connection, the IdP's change ID and time are kept instead (DA-001 §4.2).
ALTER TABLE identity.app_user
  ADD COLUMN provisioned_via    text NOT NULL DEFAULT 'MANUAL' CHECK (provisioned_via IN ('IDP_PUSH','MANUAL')),
  ADD COLUMN idp_connection_id  uuid,          -- ID reference to operations.connection (M4)
  ADD COLUMN source_change_ref  text,
  ADD COLUMN source_changed_at  timestamptz,
  ADD CONSTRAINT app_user_idp_provenance_ck CHECK (
        provisioned_via <> 'IDP_PUSH'
     OR (idp_connection_id IS NOT NULL AND source_change_ref IS NOT NULL AND source_changed_at IS NOT NULL));

-- Rights per role become effective-dated and bi-temporal (§3.1 rule 2).
ALTER TABLE identity.role_permission
  ADD COLUMN valid_period  daterange NOT NULL DEFAULT daterange(platform.today_ist(), NULL)
             CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  ADD COLUMN recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN superseded_at timestamptz,
  ADD COLUMN approval_request_id uuid;
ALTER TABLE identity.role_permission DROP CONSTRAINT role_permission_pkey;
ALTER TABLE identity.role_permission
  ADD PRIMARY KEY (tenant_id, role_code, permission_code, valid_period, recorded_at),
  ADD CONSTRAINT role_permission_no_overlap EXCLUDE USING gist
      (tenant_id WITH =, role_code WITH =, permission_code WITH =, valid_period WITH &&)
      WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED;
SELECT pg_temp.make_bitemporal('identity.role_permission', ARRAY['tenant_id','role_code','permission_code']);

-- Role grants become an anchor per grant (§3.1 rule 1) so scope attributes can point at it.
-- DDL-000 kept user, role, free-JSON scope, dates and the two people in one row; the anchor keeps
-- what never changes, and identity.user_role_version keeps the rest per validity period.
ALTER TABLE identity.user_role DROP CONSTRAINT user_role_pkey;
ALTER TABLE identity.user_role DROP CONSTRAINT user_role_check;     -- granted_by <> approved_by (moves to versions)
ALTER TABLE identity.user_role DROP CONSTRAINT user_role_check1;    -- granted_by <> user_id     (moves to versions)
ALTER TABLE identity.user_role DROP CONSTRAINT user_role_check2;    -- valid_to >= valid_from    (replaced by valid_period)
ALTER TABLE identity.user_role
  DROP COLUMN scope, DROP COLUMN valid_from, DROP COLUMN valid_to,
  DROP COLUMN granted_by, DROP COLUMN approved_by,
  ADD COLUMN grant_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
  ADD PRIMARY KEY (tenant_id, grant_id);
CREATE TRIGGER user_role_anchor_immutable BEFORE UPDATE OR DELETE ON identity.user_role
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

CREATE TABLE identity.user_role_version (
  tenant_id     uuid NOT NULL,
  grant_id      uuid NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  granted_by    uuid NOT NULL,
  approved_by   uuid NOT NULL,
  request_id    uuid,                       -- identity.role_grant_request that led to it
  PRIMARY KEY (tenant_id, grant_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, grant_id) REFERENCES identity.user_role (tenant_id, grant_id),
  CHECK (granted_by <> approved_by),        -- SOD-05
  EXCLUDE USING gist (tenant_id WITH =, grant_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('identity.user_role_version', ARRAY['tenant_id','grant_id']);

-- No self-grant, and both people must be active humans: neither the granter nor the approver may
-- be the user who receives the role, a service identity (AI never approves) or an inactive user.
-- A linked request must be approved.
CREATE OR REPLACE FUNCTION identity.tg_user_role_no_self_grant() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_user uuid; v_ok boolean; v_req text;
BEGIN
  IF platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN RETURN NEW; END IF;  -- already checked (BT-5)
  SELECT user_id INTO v_user FROM identity.user_role WHERE tenant_id = NEW.tenant_id AND grant_id = NEW.grant_id;
  IF v_user IN (NEW.granted_by, NEW.approved_by) THEN
    RAISE EXCEPTION 'SOD_VIOLATION: a user cannot grant or approve their own role' USING ERRCODE = '42501';
  END IF;
  SELECT count(*) = CASE WHEN NEW.granted_by = NEW.approved_by THEN 1 ELSE 2 END INTO v_ok FROM identity.app_user
   WHERE tenant_id = NEW.tenant_id AND user_id IN (NEW.granted_by, NEW.approved_by)
     AND status = 'ACTIVE' AND NOT is_service_identity;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'SOD_VIOLATION: granter and approver must be two active human users' USING ERRCODE = '42501';
  END IF;
  -- A version that names a request follows an APPROVED GRANT request for this grant (or this user
  -- and role), starting on the request's date (identity.check_grant_request, defined below).
  IF NEW.request_id IS NOT NULL THEN
    PERFORM identity.check_grant_request(NEW.tenant_id, NEW.grant_id, NEW.request_id, ARRAY['GRANT']);
    IF lower(NEW.valid_period) IS DISTINCT FROM (SELECT effective_from FROM identity.role_grant_request
                                                  WHERE tenant_id = NEW.tenant_id AND request_id = NEW.request_id)
       OR NOT upper_inf(NEW.valid_period) THEN
      RAISE EXCEPTION 'NOT_REQUESTED: the grant version must start on the request''s date and be open-ended' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER user_role_version_no_self_grant BEFORE INSERT ON identity.user_role_version
  FOR EACH ROW EXECUTE FUNCTION identity.tg_user_role_no_self_grant();

-- Named scope values a grant carries, replacing DDL-000's free JSON scope (PRD-001 §10).
-- Meaning (DA-001 §11, [ASSUMPTION - owner Q87]): the current rows of one attribute list the
-- values the grant is limited to on a date; an attribute with no current row does not limit the
-- grant (as DDL-000's empty scope '{}').  So adding a row narrows access and ending the last row
-- of an attribute widens it: both follow an approved request (FR-D01-017: scope is part of the
-- grant that is approved).
CREATE TABLE identity.scope_attribute (
  tenant_id     uuid NOT NULL,
  grant_id      uuid NOT NULL,
  attribute     text NOT NULL CHECK (attribute IN ('SCHEME','DESK','BRANCH','REGION')),
  value         text NOT NULL,              -- scheme ID, desk code, org unit ID ... (ID reference, M4)
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  request_id    uuid NOT NULL,              -- approved GRANT or CHANGE_SCOPE request for this grant
  PRIMARY KEY (tenant_id, grant_id, attribute, value, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, grant_id) REFERENCES identity.user_role (tenant_id, grant_id),
  EXCLUDE USING gist (tenant_id WITH =, grant_id WITH =, attribute WITH =, value WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('identity.scope_attribute', ARRAY['tenant_id','grant_id','attribute','value']);

-- Request to grant or revoke a role (WF-020).
CREATE TABLE identity.role_grant_request (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  request_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  request_type  text NOT NULL CHECK (request_type IN ('GRANT','REVOKE','CHANGE_SCOPE')),
  user_id       uuid NOT NULL,
  role_code     text NOT NULL,
  grant_id      uuid,                       -- the grant changed or revoked
  requested_by  uuid NOT NULL,              -- set by the database: the acting user (app.user_id)
  reason        text NOT NULL,
  -- The date the approved change takes effect [DES]: start of the grant version and of every added
  -- scope row (open-ended); end date of every removed scope row and of a revoked grant.
  effective_from date NOT NULL,
  -- Scope change asked for (M20) [DES]: {"add":[{"attribute":"SCHEME","value":"..."}],
  -- "remove":[{"attribute":...,"value":...}]}.  Scope rows are added / ended only as listed here.
  requested_scope jsonb CHECK (requested_scope IS NULL OR (jsonb_typeof(requested_scope) = 'object'
                    AND requested_scope - 'add' - 'remove' = '{}'::jsonb)),
  sod_result    text CHECK (sod_result IN ('PASS','CONFLICT')),
  status        text NOT NULL DEFAULT 'SUBMITTED',
  approval_request_id uuid,
  approved_by   uuid,                       -- set by the database at APPROVED: the acting user, an active human
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, request_id),
  FOREIGN KEY (tenant_id, user_id)   REFERENCES identity.app_user (tenant_id, user_id),
  FOREIGN KEY (tenant_id, role_code) REFERENCES identity.role (tenant_id, role_code),
  FOREIGN KEY (tenant_id, grant_id)  REFERENCES identity.user_role (tenant_id, grant_id),
  CHECK (requested_by <> user_id),
  CHECK (request_type = 'GRANT' OR grant_id IS NOT NULL),
  CHECK (status NOT IN ('APPROVED','APPLIED') OR approval_request_id IS NOT NULL),
  CHECK (status NOT IN ('APPROVED','APPLIED') OR sod_result = 'PASS'),      -- WF-020: SoD conflict is rejected
  CHECK (status NOT IN ('APPROVED','APPLIED') OR approved_by IS NOT NULL),
  CHECK (approved_by <> requested_by AND approved_by <> user_id),         -- maker <> checker; no self-approval
  FOREIGN KEY (tenant_id, approved_by) REFERENCES identity.app_user (tenant_id, user_id)
);
-- Maker and checker come from the identity context, never from typed-in values: requested_by is
-- the acting user at insert; approved_by is the acting user at the move to APPROVED, who must be an
-- active human other than the requester and the user (AI never approves).  From creation on, the
-- content of a request is frozen: only status, sod_result (while SUBMITTED), approval_request_id
-- and approved_by (with the move to APPROVED) change.  A changed request is a new request.
CREATE OR REPLACE FUNCTION identity.tg_role_grant_request_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_me uuid := platform.current_user_id();
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF v_me IS NULL THEN
      RAISE EXCEPTION 'NO_ACTOR: a role grant request needs the acting user (app.user_id)' USING ERRCODE = '42501';
    END IF;
    NEW.requested_by := v_me;
    IF NEW.approved_by IS NOT NULL OR NEW.approval_request_id IS NOT NULL THEN
      RAISE EXCEPTION 'IMMUTABLE_RECORD: a role grant request is born unapproved' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  IF (to_jsonb(NEW) - 'status' - 'sod_result' - 'approval_request_id' - 'approved_by' - 'updated_at' - 'row_version')
     IS DISTINCT FROM
     (to_jsonb(OLD) - 'status' - 'sod_result' - 'approval_request_id' - 'approved_by' - 'updated_at' - 'row_version') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: role grant request % cannot be edited; raise a new request', OLD.request_id
      USING ERRCODE = '42501';
  END IF;
  IF NEW.sod_result IS DISTINCT FROM OLD.sod_result AND OLD.status <> 'SUBMITTED' THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: the SoD result of role grant request % is fixed once it is decided', OLD.request_id
      USING ERRCODE = '42501';
  END IF;
  IF OLD.status = 'SUBMITTED' AND NEW.status = 'APPROVED' THEN
    NEW.approved_by := v_me;
    IF v_me IS NULL OR NOT EXISTS (SELECT 1 FROM identity.app_user WHERE tenant_id = NEW.tenant_id AND user_id = v_me
                                      AND status = 'ACTIVE' AND NOT is_service_identity) THEN
      RAISE EXCEPTION 'SOD_VIOLATION: role grant request % must be approved by an active human user', NEW.request_id
        USING ERRCODE = '42501';
    END IF;
  ELSIF NEW.approved_by IS DISTINCT FROM OLD.approved_by OR NEW.approval_request_id IS DISTINCT FROM OLD.approval_request_id THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: the approval of role grant request % is recorded only when it is approved',
      OLD.request_id USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER role_grant_request_guard BEFORE INSERT OR UPDATE ON identity.role_grant_request
  FOR EACH ROW EXECUTE FUNCTION identity.tg_role_grant_request_guard();
ALTER TABLE identity.user_role_version
  ADD FOREIGN KEY (tenant_id, request_id) REFERENCES identity.role_grant_request (tenant_id, request_id);
ALTER TABLE identity.scope_attribute
  ADD FOREIGN KEY (tenant_id, request_id) REFERENCES identity.role_grant_request (tenant_id, request_id);
ALTER TABLE identity.user_role_version_closure
  ADD FOREIGN KEY (tenant_id, request_id) REFERENCES identity.role_grant_request (tenant_id, request_id),
  ADD FOREIGN KEY (tenant_id, grant_id)   REFERENCES identity.user_role (tenant_id, grant_id);
ALTER TABLE identity.scope_attribute_closure
  ADD FOREIGN KEY (tenant_id, request_id) REFERENCES identity.role_grant_request (tenant_id, request_id),
  ADD FOREIGN KEY (tenant_id, grant_id)   REFERENCES identity.user_role (tenant_id, grant_id);

-- A grant's scope, and the end or retraction of a grant or a scope row, follow an approved request
-- for that grant (D-76; FR-D01-017), used once:
--   scope row added            GRANT or CHANGE_SCOPE request whose requested_scope.add lists it
--   scope row ended/retracted  CHANGE_SCOPE request whose requested_scope.remove lists it
--   grant ended/retracted      REVOKE request
-- The request must be APPROVED (not yet APPLIED); at commit the database moves it to APPLIED, so
-- it cannot be used again in a later transaction.  A GRANT request made before the grant existed
-- (grant_id empty) matches by user and role.
CREATE OR REPLACE FUNCTION identity.check_grant_request(p_tenant uuid, p_grant uuid, p_request uuid, p_types text[],
                                                        p_scope_op text DEFAULT NULL, p_attribute text DEFAULT NULL,
                                                        p_value text DEFAULT NULL)
RETURNS date LANGUAGE plpgsql STABLE AS $$
DECLARE r identity.role_grant_request; g identity.user_role;
BEGIN
  SELECT * INTO r FROM identity.role_grant_request WHERE tenant_id = p_tenant AND request_id = p_request;
  SELECT * INTO g FROM identity.user_role WHERE tenant_id = p_tenant AND grant_id = p_grant;
  IF r.status IS DISTINCT FROM 'APPROVED' THEN
    RAISE EXCEPTION 'REQUEST_NOT_APPROVED: role grant request % is % (it must be APPROVED and not yet applied)',
      p_request, coalesce(r.status, 'unknown') USING ERRCODE = '23514';
  END IF;
  IF NOT (r.request_type = ANY (p_types)) THEN
    RAISE EXCEPTION 'WRONG_REQUEST_TYPE: a % request cannot do this (allowed: %)', r.request_type, p_types
      USING ERRCODE = '23514';
  END IF;
  IF NOT (r.grant_id = p_grant
          OR (r.request_type = 'GRANT' AND r.grant_id IS NULL AND r.user_id = g.user_id AND r.role_code = g.role_code)) THEN
    RAISE EXCEPTION 'WRONG_GRANT: request % is not for grant %', p_request, p_grant USING ERRCODE = '23514';
  END IF;
  IF p_scope_op IS NOT NULL
     AND NOT coalesce(r.requested_scope -> p_scope_op @> jsonb_build_array(jsonb_build_object('attribute', p_attribute, 'value', p_value)), false) THEN
    RAISE EXCEPTION 'NOT_REQUESTED: request % does not ask to % scope % = %', p_request, p_scope_op, p_attribute, p_value
      USING ERRCODE = '23514';
  END IF;
  RETURN r.effective_from;
END $$;

-- An added scope row starts on the request's date and is open-ended.
CREATE OR REPLACE FUNCTION identity.tg_scope_attribute_request() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_from date;
BEGIN
  IF platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN RETURN NEW; END IF;  -- already checked (BT-5)
  v_from := identity.check_grant_request(NEW.tenant_id, NEW.grant_id, NEW.request_id, ARRAY['GRANT','CHANGE_SCOPE'],
                                         'add', NEW.attribute, NEW.value);
  IF lower(NEW.valid_period) <> v_from OR NOT upper_inf(NEW.valid_period) THEN
    RAISE EXCEPTION 'NOT_REQUESTED: scope row % = % must run from the request''s date % with no end', NEW.attribute, NEW.value, v_from
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER scope_attribute_request BEFORE INSERT ON identity.scope_attribute
  FOR EACH ROW EXECUTE FUNCTION identity.tg_scope_attribute_request();

-- An END uses the request's date as its end date; a RETRACT may remove only a version that starts on
-- or after the request's date (one that never applied before the approved change).
CREATE OR REPLACE FUNCTION identity.tg_grant_closure_request() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_from date;
BEGIN
  IF TG_TABLE_NAME = 'scope_attribute_closure' THEN
    v_from := identity.check_grant_request(NEW.tenant_id, NEW.grant_id, NEW.request_id, ARRAY['CHANGE_SCOPE'],
                                           'remove', to_jsonb(NEW) ->> 'attribute', to_jsonb(NEW) ->> 'value');
  ELSE
    v_from := identity.check_grant_request(NEW.tenant_id, NEW.grant_id, NEW.request_id, ARRAY['REVOKE']);
  END IF;
  IF (NEW.closure_kind = 'END' AND NEW.end_date <> v_from)
     OR (NEW.closure_kind = 'RETRACT' AND lower(NEW.target_valid_period) < v_from) THEN
    RAISE EXCEPTION 'NOT_REQUESTED: % on %.% does not match the request''s date %', NEW.closure_kind, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_from
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER user_role_version_closure_request BEFORE INSERT ON identity.user_role_version_closure
  FOR EACH ROW EXECUTE FUNCTION identity.tg_grant_closure_request();
CREATE TRIGGER scope_attribute_closure_request BEFORE INSERT ON identity.scope_attribute_closure
  FOR EACH ROW EXECUTE FUNCTION identity.tg_grant_closure_request();

-- At commit, a request used in this transaction must have been applied in full, and it then moves
-- APPROVED -> APPLIED (single use):
--   GRANT         a grant version naming the request, and every "add" entry as a scope row
--   CHANGE_SCOPE  every "add" entry as a scope row and every "remove" entry as a scope closure row
--   REVOKE        a grant closure row
CREATE OR REPLACE FUNCTION identity.tg_mark_request_applied() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE r identity.role_grant_request; e jsonb; v_missing text;
BEGIN
  IF TG_TABLE_NAME IN ('scope_attribute','user_role_version') AND platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN
    RETURN NULL;
  END IF;
  IF NEW.request_id IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO r FROM identity.role_grant_request
   WHERE tenant_id = NEW.tenant_id AND request_id = NEW.request_id FOR UPDATE;
  IF r.status <> 'APPROVED' THEN
    -- Already applied: by this transaction (an earlier row of it) is fine; by another one is not.
    IF current_setting('identity.applied_' || replace(r.request_id::text, '-', ''), true) = 'yes' THEN RETURN NULL; END IF;
    RAISE EXCEPTION 'REQUEST_NOT_APPROVED: role grant request % was applied by another transaction', r.request_id
      USING ERRCODE = '40001';
  END IF;
  IF r.request_type = 'GRANT' AND NOT EXISTS (SELECT 1 FROM identity.user_role_version v
                                              WHERE v.tenant_id = r.tenant_id AND v.request_id = r.request_id) THEN
    v_missing := 'the grant version';
  END IF;
  IF r.request_type = 'REVOKE' AND NOT EXISTS (SELECT 1 FROM identity.user_role_version_closure c
                                               WHERE c.tenant_id = r.tenant_id AND c.request_id = r.request_id) THEN
    v_missing := 'the revocation';
  END IF;
  FOR e IN SELECT * FROM jsonb_array_elements(coalesce(r.requested_scope -> 'add', '[]'::jsonb)) LOOP
    IF NOT EXISTS (SELECT 1 FROM identity.scope_attribute a
                    WHERE a.tenant_id = r.tenant_id AND a.request_id = r.request_id AND a.superseded_at IS NULL
                      AND a.attribute = e ->> 'attribute' AND a.value = e ->> 'value') THEN
      v_missing := coalesce(v_missing || ', ', '') || 'add ' || (e ->> 'attribute') || '=' || (e ->> 'value');
    END IF;
  END LOOP;
  FOR e IN SELECT * FROM jsonb_array_elements(coalesce(r.requested_scope -> 'remove', '[]'::jsonb)) LOOP
    IF NOT EXISTS (SELECT 1 FROM identity.scope_attribute_closure c
                    WHERE c.tenant_id = r.tenant_id AND c.request_id = r.request_id
                      AND c.attribute = e ->> 'attribute' AND c.value = e ->> 'value') THEN
      v_missing := coalesce(v_missing || ', ', '') || 'remove ' || (e ->> 'attribute') || '=' || (e ->> 'value');
    END IF;
  END LOOP;
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'REQUEST_PARTLY_APPLIED: role grant request % was not applied in full (missing: %)', r.request_id, v_missing
      USING ERRCODE = '23514';
  END IF;
  PERFORM set_config('app.transition_cause', 'STATE_CHANGE', true);
  UPDATE identity.role_grant_request SET status = 'APPLIED'
   WHERE tenant_id = r.tenant_id AND request_id = r.request_id;
  PERFORM set_config('identity.applied_' || replace(r.request_id::text, '-', ''), 'yes', true);
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER user_role_version_request_applied AFTER INSERT ON identity.user_role_version
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identity.tg_mark_request_applied();
CREATE CONSTRAINT TRIGGER scope_attribute_request_applied AFTER INSERT ON identity.scope_attribute
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identity.tg_mark_request_applied();
CREATE CONSTRAINT TRIGGER user_role_version_closure_request_applied AFTER INSERT ON identity.user_role_version_closure
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identity.tg_mark_request_applied();
CREATE CONSTRAINT TRIGGER scope_attribute_closure_request_applied AFTER INSERT ON identity.scope_attribute_closure
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION identity.tg_mark_request_applied();
CREATE TRIGGER role_grant_request_version BEFORE UPDATE ON identity.role_grant_request
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('identity', 'role_grant_request', 'status', ARRAY['request_id'], ARRAY['uuid']);
-- [ASSUMPTION] request states: no source document lists them; WF-020 names submit, SoD check,
-- approval, rejection and the grant itself.
INSERT INTO identity.role_grant_request_transition (from_state, to_state, cause) VALUES
  ('(NEW)','SUBMITTED','CREATE'),
  ('SUBMITTED','APPROVED','STATE_CHANGE'),
  ('SUBMITTED','REJECTED','STATE_CHANGE'),
  ('SUBMITTED','CANCELLED','STATE_CHANGE'),
  ('APPROVED','APPLIED','STATE_CHANGE');

-- Who may approve what, up to which limit, from when (BA-005 approval authorities).
-- No limit value is set here; limits are rows the AMC approves.
CREATE TABLE identity.approval_authority (
  tenant_id    uuid NOT NULL REFERENCES platform.tenant,
  authority_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, authority_id)
);
CREATE TABLE identity.approval_authority_version (
  tenant_id       uuid NOT NULL,
  authority_id    uuid NOT NULL,
  valid_period    daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at     timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at   timestamptz,
  permission_code text NOT NULL REFERENCES identity.permission,
  holder_type     text NOT NULL CHECK (holder_type IN ('ROLE','USER')),
  role_code       text,
  user_id         uuid,
  limit_amount    numeric(24,4) CHECK (limit_amount >= 0),     -- NULL = no amount limit applies
  limit_currency  char(3) REFERENCES master.currency,
  scope_attribute text CHECK (scope_attribute IN ('SCHEME','DESK','BRANCH','REGION')),
  scope_value     text,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, authority_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, authority_id) REFERENCES identity.approval_authority (tenant_id, authority_id),
  FOREIGN KEY (tenant_id, role_code) REFERENCES identity.role (tenant_id, role_code),
  FOREIGN KEY (tenant_id, user_id)   REFERENCES identity.app_user (tenant_id, user_id),
  CHECK ((holder_type = 'ROLE' AND role_code IS NOT NULL AND user_id IS NULL)
      OR (holder_type = 'USER' AND user_id IS NOT NULL AND role_code IS NULL)),
  CHECK ((limit_amount IS NULL) = (limit_currency IS NULL)),
  CHECK ((scope_attribute IS NULL) = (scope_value IS NULL)),
  EXCLUDE USING gist (tenant_id WITH =, authority_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.make_bitemporal('identity.approval_authority_version', ARRAY['tenant_id','authority_id']);

-- Sign-in sessions (no tokens stored).  Insert-only, except that the end may be recorded once.
CREATE TABLE identity.session (
  tenant_id       uuid NOT NULL,
  session_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL,
  idp_session_ref text NOT NULL,
  started_at      timestamptz NOT NULL DEFAULT now(),
  client_ip       inet,
  ended_at        timestamptz,
  end_reason      text CHECK (end_reason IN ('SIGN_OUT','TIMEOUT','REVOKED','IDP_LOGOUT')),
  PRIMARY KEY (tenant_id, session_id),
  FOREIGN KEY (tenant_id, user_id) REFERENCES identity.app_user (tenant_id, user_id),
  CHECK ((ended_at IS NULL) = (end_reason IS NULL)),
  CHECK (ended_at IS NULL OR ended_at >= started_at)
);
CREATE OR REPLACE FUNCTION identity.tg_session_end_once() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' OR OLD.ended_at IS NOT NULL
     OR (to_jsonb(NEW) - 'ended_at' - 'end_reason') IS DISTINCT FROM (to_jsonb(OLD) - 'ended_at' - 'end_reason') THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: a session may only be ended, once' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER session_end_once BEFORE UPDATE OR DELETE ON identity.session
  FOR EACH ROW EXECUTE FUNCTION identity.tg_session_end_once();

-- Service accounts per integration (FR-D01-010; EA-002 §4.1).  Credentials are a reference
-- to the secret store, never the secret.
CREATE TABLE identity.api_client (
  tenant_id        uuid NOT NULL,
  client_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  client_name      text NOT NULL,
  service_user_id  uuid NOT NULL,           -- the non-human identity (ROLE-27)
  owner_user_id    uuid NOT NULL,           -- named human owner
  credentials_ref  text NOT NULL,
  rotate_by        date,
  status           text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','RETIRED')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  row_version      integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, client_id),
  UNIQUE (tenant_id, client_name),
  FOREIGN KEY (tenant_id, service_user_id) REFERENCES identity.app_user (tenant_id, user_id),
  FOREIGN KEY (tenant_id, owner_user_id)   REFERENCES identity.app_user (tenant_id, user_id),
  CHECK (service_user_id <> owner_user_id)
);
CREATE TRIGGER api_client_version BEFORE UPDATE ON identity.api_client
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Recertification (FR-D01-009).  Items are per grant (DA-001 lists (campaign, user, role); with
-- grant anchors a user can hold one role under two grants, so the grant is the item key).
CREATE TABLE identity.recertification_campaign (
  tenant_id    uuid NOT NULL REFERENCES platform.tenant,
  campaign_id  uuid NOT NULL DEFAULT gen_random_uuid(),
  title        text NOT NULL,
  due_date     date NOT NULL,
  status       text NOT NULL DEFAULT 'OPEN',
  created_by   uuid NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  row_version  integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, campaign_id)
);
CREATE TRIGGER recertification_campaign_version BEFORE UPDATE ON identity.recertification_campaign
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('identity', 'recertification_campaign', 'status', ARRAY['campaign_id'], ARRAY['uuid']);
-- [ASSUMPTION] campaign states (WF-020: certify or revoke each grant; overdue escalates).
INSERT INTO identity.recertification_campaign_transition (from_state, to_state, cause) VALUES
  ('(NEW)','OPEN','CREATE'),
  ('OPEN','OVERDUE','STATE_CHANGE'),
  ('OPEN','CLOSED','STATE_CHANGE'),
  ('OVERDUE','CLOSED','STATE_CHANGE');

CREATE TABLE identity.recertification_item (
  tenant_id     uuid NOT NULL,
  campaign_id   uuid NOT NULL,
  grant_id      uuid NOT NULL,
  reviewer_user_id uuid NOT NULL,           -- role owner (department head)
  status        text NOT NULL DEFAULT 'PENDING',
  decided_at    timestamptz,
  decision_reason text,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, campaign_id, grant_id),
  FOREIGN KEY (tenant_id, campaign_id) REFERENCES identity.recertification_campaign (tenant_id, campaign_id),
  FOREIGN KEY (tenant_id, grant_id)    REFERENCES identity.user_role (tenant_id, grant_id),
  FOREIGN KEY (tenant_id, reviewer_user_id) REFERENCES identity.app_user (tenant_id, user_id),
  CHECK ((status = 'PENDING') = (decided_at IS NULL))
);
CREATE TRIGGER recertification_item_version BEFORE UPDATE ON identity.recertification_item
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
-- Nobody certifies their own access (FR-D01-009).
CREATE OR REPLACE FUNCTION identity.tg_recert_not_self() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM identity.user_role
              WHERE tenant_id = NEW.tenant_id AND grant_id = NEW.grant_id AND user_id = NEW.reviewer_user_id) THEN
    RAISE EXCEPTION 'SOD_VIOLATION: nobody certifies their own access' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER recertification_item_not_self BEFORE INSERT OR UPDATE ON identity.recertification_item
  FOR EACH ROW EXECUTE FUNCTION identity.tg_recert_not_self();
SELECT pg_temp.make_state_machine('identity', 'recertification_item', 'status',
  ARRAY['campaign_id','grant_id'], ARRAY['uuid','uuid']);
-- [ASSUMPTION] item states (WF-020: the role owner certifies or revokes each grant).
INSERT INTO identity.recertification_item_transition (from_state, to_state, cause) VALUES
  ('(NEW)','PENDING','CREATE'),
  ('PENDING','CERTIFIED','STATE_CHANGE'),
  ('PENDING','REVOKED','STATE_CHANGE');

-- ---------------------------------------------------------------------
-- 04  audit  (Tenant module, audit write function; DA-001 §4.3)
--     Not here (ADR-0020 / DM-17): audit_event import path, audit.import_run.
-- ---------------------------------------------------------------------

-- Daily chain head per tenant, also written to WORM object storage (PRD-001 §10).
CREATE TABLE audit.chain_anchor (
  tenant_id       uuid NOT NULL,
  anchor_date     date NOT NULL,
  last_event_seq  bigint NOT NULL,
  chain_head_hash bytea NOT NULL,
  worm_object_ref text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, anchor_date)
);
CREATE TRIGGER chain_anchor_immutable BEFORE UPDATE OR DELETE ON audit.chain_anchor
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- Reads of sensitive data: unmask, export, break-glass reads (NFR-AUD-013).  Monthly partitions.
CREATE TABLE audit.access_log (
  tenant_id      uuid NOT NULL,
  accessed_at    timestamptz NOT NULL DEFAULT now(),
  access_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_user_id  uuid,
  actor_type     text NOT NULL CHECK (actor_type IN ('USER','SERVICE','AI_AGENT','SYSTEM','PLATFORM_OPERATOR')),
  access_kind    text NOT NULL CHECK (access_kind IN ('UNMASK','EXPORT','BREAK_GLASS_READ','BULK_READ')),
  object_type    text NOT NULL,
  object_id      uuid,
  purpose_code   text NOT NULL,
  reason         text,
  correlation_id uuid,
  PRIMARY KEY (tenant_id, accessed_at, access_id)
) PARTITION BY RANGE (accessed_at);
CREATE TABLE audit.access_log_2026_11 PARTITION OF audit.access_log FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE audit.access_log_2026_12 PARTITION OF audit.access_log FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE audit.access_log_default PARTITION OF audit.access_log DEFAULT;
CREATE INDEX access_log_object_ix ON audit.access_log (tenant_id, object_type, object_id, accessed_at);
CREATE TRIGGER access_log_immutable BEFORE UPDATE OR DELETE ON audit.access_log
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- ---------------------------------------------------------------------
-- 05  master  (Security master module, D16; DA-001 §4.4)
--     DM-1: entities other rows point at become an anchor (what never changes) plus versions.
-- ---------------------------------------------------------------------

-- Provenance of reference-data loads (§3.3).  Created first: version tables point at it.
CREATE TABLE master.load_run (
  tenant_id        uuid NOT NULL REFERENCES platform.tenant,
  load_run_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  inbound_file_id  uuid,                  -- ID reference to operations.inbound_file (M4)
  message_session_ref text,               -- for message-based feeds instead of a file
  adapter_name     text NOT NULL,
  adapter_version  text NOT NULL,
  canonical_family text NOT NULL,         -- INT-001 §3
  business_date    date NOT NULL,
  started_at       timestamptz NOT NULL DEFAULT now(),
  finished_at      timestamptz,
  rows_loaded      integer CHECK (rows_loaded >= 0),
  rows_quarantined integer CHECK (rows_quarantined >= 0),
  status           text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','COMPLETED','FAILED')),
  PRIMARY KEY (tenant_id, load_run_id),
  CHECK (inbound_file_id IS NOT NULL OR message_session_ref IS NOT NULL),
  CHECK ((status = 'RUNNING') = (finished_at IS NULL))
);
CREATE TRIGGER load_run_guard BEFORE UPDATE OR DELETE ON master.load_run
  FOR EACH ROW EXECUTE FUNCTION platform.tg_load_run_guard();

-- Issuer groups -> anchor + versions.
ALTER TABLE master.issuer_group
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
CREATE TABLE master.issuer_group_version (
  tenant_id        uuid NOT NULL,
  group_id         uuid NOT NULL,
  valid_period     daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at    timestamptz,
  group_name       text NOT NULL,
  is_sponsor_group boolean NOT NULL DEFAULT false,
  PRIMARY KEY (tenant_id, group_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, group_id) REFERENCES master.issuer_group (tenant_id, group_id),
  EXCLUDE USING gist (tenant_id WITH =, group_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
ALTER TABLE master.issuer_group DROP COLUMN group_name, DROP COLUMN is_sponsor_group;

-- Issuers -> anchor + versions; LEI unique among current versions (§3.1 rule 3).
ALTER TABLE master.issuer
  DROP CONSTRAINT issuer_tenant_id_group_id_fkey,
  DROP COLUMN legal_name, DROP COLUMN lei, DROP COLUMN cin, DROP COLUMN group_id,
  DROP COLUMN sector_code, DROP COLUMN issuer_type, DROP COLUMN valid_from,
  DROP COLUMN updated_at, DROP COLUMN row_version,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
CREATE TABLE master.issuer_version (
  tenant_id     uuid NOT NULL,
  issuer_id     uuid NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  legal_name    text NOT NULL,
  lei           char(20) CHECK (lei ~ '^[A-Z0-9]{18}[0-9]{2}$'),
  cin           text,
  group_id      uuid,
  sector_code   text,
  issuer_type   text NOT NULL CHECK (issuer_type IN ('CORPORATE','BANK','NBFC','PSU','CENTRAL_GOVT','STATE_GOVT','MUNICIPAL','FUND','OTHER')),
  PRIMARY KEY (tenant_id, issuer_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, issuer_id) REFERENCES master.issuer (tenant_id, issuer_id),
  FOREIGN KEY (tenant_id, group_id)  REFERENCES master.issuer_group (tenant_id, group_id),
  EXCLUDE USING gist (tenant_id WITH =, issuer_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED,
  EXCLUDE USING gist (tenant_id WITH =, lei WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL AND lei IS NOT NULL) DEFERRABLE INITIALLY DEFERRED
);

-- Securities -> anchor + versions.  The anchor keeps what never changes: the ID, the ISIN
-- (a new ISIN is a new security; kept as a plain unique key, §3.1 rule 3, and also in the
-- crosswalk) and the instrument type.  Everything else is versioned.
DROP TRIGGER security_version ON master.security;
ALTER TABLE master.security
  DROP CONSTRAINT security_tenant_id_issuer_id_fkey,
  DROP CONSTRAINT security_check,                    -- debt needs a maturity date (moves to versions)
  DROP COLUMN short_name, DROP COLUMN issuer_id, DROP COLUMN currency_code,
  DROP COLUMN face_value, DROP COLUMN coupon_rate, DROP COLUMN maturity_date,
  DROP COLUMN day_count, DROP COLUMN lot_size, DROP COLUMN tick_size,
  DROP COLUMN market_cap_class, DROP COLUMN status, DROP COLUMN updated_at, DROP COLUMN row_version,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
CREATE TABLE master.security_version (
  tenant_id        uuid NOT NULL,
  security_id      uuid NOT NULL,
  valid_period     daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at      timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at    timestamptz,
  short_name       text NOT NULL,
  issuer_id        uuid,
  currency_code    char(3) NOT NULL DEFAULT 'INR' REFERENCES master.currency,
  face_value       numeric(20,6),
  coupon_rate      numeric(9,6),                    -- % p.a.
  maturity_date    date,
  day_count        text CHECK (day_count IN ('ACT/365','ACT/360','30/360','ACT/ACT')),
  lot_size         numeric(20,4) NOT NULL DEFAULT 1 CHECK (lot_size > 0),
  tick_size        numeric(12,6),
  market_cap_class text CHECK (market_cap_class IN ('LARGE','MID','SMALL')),
  status           text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','MATURED','DELISTED')),
  PRIMARY KEY (tenant_id, security_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  FOREIGN KEY (tenant_id, issuer_id)   REFERENCES master.issuer (tenant_id, issuer_id),
  EXCLUDE USING gist (tenant_id WITH =, security_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
-- DDL-000 rule kept: debt instruments need a maturity date.
CREATE OR REPLACE FUNCTION master.tg_security_version_check() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_type text;
BEGIN
  SELECT instrument_type INTO v_type FROM master.security
   WHERE tenant_id = NEW.tenant_id AND security_id = NEW.security_id;
  IF v_type IN ('BOND','NCD','CP','CD','TBILL','GSEC','SDL') AND NEW.maturity_date IS NULL THEN
    RAISE EXCEPTION 'MATURITY_REQUIRED: % security % needs a maturity date', v_type, NEW.security_id
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER security_version_check BEFORE INSERT ON master.security_version
  FOR EACH ROW EXECUTE FUNCTION master.tg_security_version_check();

-- Credit ratings -> anchor (who rates what, on which scale) + versions (the rating over time).
ALTER TABLE master.credit_rating
  DROP CONSTRAINT credit_rating_check,               -- subject check (security or issuer); re-added below by name
  DROP COLUMN rating, DROP COLUMN outlook, DROP COLUMN valid_from, DROP COLUMN valid_to, DROP COLUMN recorded_at,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
  ADD CONSTRAINT credit_rating_subject_ck CHECK (security_id IS NOT NULL OR issuer_id IS NOT NULL);
CREATE TABLE master.credit_rating_version (
  tenant_id     uuid NOT NULL,
  rating_id     uuid NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  rating        text NOT NULL,
  outlook       text,
  PRIMARY KEY (tenant_id, rating_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, rating_id) REFERENCES master.credit_rating (tenant_id, rating_id),
  EXCLUDE USING gist (tenant_id WITH =, rating_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);

-- Benchmarks -> anchor (ID and variant) + versions.
ALTER TABLE master.benchmark
  DROP COLUMN name, DROP COLUMN provider,
  ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();
CREATE TABLE master.benchmark_version (
  tenant_id     uuid NOT NULL,
  benchmark_id  uuid NOT NULL,
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  name          text NOT NULL,
  provider      text NOT NULL,
  PRIMARY KEY (tenant_id, benchmark_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, benchmark_id) REFERENCES master.benchmark (tenant_id, benchmark_id),
  EXCLUDE USING gist (tenant_id WITH =, benchmark_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);

-- Anchors never change and are never deleted.
CREATE TRIGGER issuer_group_anchor_immutable  BEFORE UPDATE OR DELETE ON master.issuer_group  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();
CREATE TRIGGER issuer_anchor_immutable        BEFORE UPDATE OR DELETE ON master.issuer        FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();
CREATE TRIGGER security_anchor_immutable      BEFORE UPDATE OR DELETE ON master.security      FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();
CREATE TRIGGER credit_rating_anchor_immutable BEFORE UPDATE OR DELETE ON master.credit_rating FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();
CREATE TRIGGER benchmark_anchor_immutable     BEFORE UPDATE OR DELETE ON master.benchmark     FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- Coupon, call, put and redemption schedules of debt securities (PRD-016 §10).  BT, keyed by
-- date (§3.1 rule 2): one current row per security, schedule type and date.
CREATE TABLE master.security_schedule (
  tenant_id     uuid NOT NULL,
  security_id   uuid NOT NULL,
  schedule_type text NOT NULL CHECK (schedule_type IN ('COUPON','CALL','PUT','REDEMPTION','AMORTISATION')),
  event_date    date NOT NULL,
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at timestamptz,
  record_date   date,
  coupon_rate   numeric(9,6),          -- % p.a.; rates keep DDL-000 scale until the FE spec sets one
  principal_pct numeric(12,8) CHECK (principal_pct >= 0 AND principal_pct <= 100),  -- % of face value repaid
  PRIMARY KEY (tenant_id, security_id, schedule_type, event_date, recorded_at),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id)
);
ALTER TABLE master.security_schedule ADD CONSTRAINT security_schedule_one_current
  EXCLUDE USING gist (tenant_id WITH =, security_id WITH =, schedule_type WITH =, event_date WITH =)
  WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED;

-- Daily index levels and constituents.  Insert-only; a vendor correction is a new version_no
-- (M12 correction path; DA-001's key plus version_no).
CREATE TABLE master.benchmark_level (
  tenant_id    uuid NOT NULL,
  benchmark_id uuid NOT NULL,
  level_date   date NOT NULL,
  level_type   text NOT NULL CHECK (level_type IN ('PRICE','TOTAL_RETURN')),
  version_no   integer NOT NULL DEFAULT 1 CHECK (version_no > 0),
  level_value  numeric(24,8) NOT NULL CHECK (level_value > 0),
  recorded_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, benchmark_id, level_date, level_type, version_no),
  FOREIGN KEY (tenant_id, benchmark_id) REFERENCES master.benchmark (tenant_id, benchmark_id)
);
CREATE TRIGGER benchmark_level_immutable BEFORE UPDATE OR DELETE ON master.benchmark_level
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

CREATE TABLE master.benchmark_constituent (
  tenant_id    uuid NOT NULL,
  benchmark_id uuid NOT NULL,
  as_of_date   date NOT NULL,
  security_id  uuid NOT NULL,
  version_no   integer NOT NULL DEFAULT 1 CHECK (version_no > 0),
  weight_pct   numeric(12,8) NOT NULL CHECK (weight_pct >= 0 AND weight_pct <= 100),
  recorded_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, benchmark_id, as_of_date, security_id, version_no),
  FOREIGN KEY (tenant_id, benchmark_id) REFERENCES master.benchmark (tenant_id, benchmark_id),
  FOREIGN KEY (tenant_id, security_id)  REFERENCES master.security (tenant_id, security_id)
);
CREATE TRIGGER benchmark_constituent_immutable BEFORE UPDATE OR DELETE ON master.benchmark_constituent
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- Counterparty golden record (EA-003 T5): custodians, banks, clearing corporations, brokers as
-- legal entities, debt and repo counterparties; non-broker empanelment status.
CREATE TABLE master.counterparty (
  tenant_id       uuid NOT NULL REFERENCES platform.tenant,
  counterparty_id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, counterparty_id)
);
CREATE TRIGGER counterparty_anchor_immutable BEFORE UPDATE OR DELETE ON master.counterparty
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();
CREATE TABLE master.counterparty_version (
  tenant_id          uuid NOT NULL,
  counterparty_id    uuid NOT NULL,
  valid_period       daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at        timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at      timestamptz,
  legal_name         text NOT NULL,
  lei                char(20) CHECK (lei ~ '^[A-Z0-9]{18}[0-9]{2}$'),
  counterparty_type  text NOT NULL CHECK (counterparty_type IN
                      ('CUSTODIAN','BANK','CLEARING_CORPORATION','DEPOSITORY','BROKER','DEBT_COUNTERPARTY','REPO_COUNTERPARTY','OTHER')),
  issuer_id          uuid,                  -- same legal entity as an issuer, where it is one
  empanelment_status text NOT NULL CHECK (empanelment_status IN ('NOT_REQUIRED','PENDING','EMPANELLED','SUSPENDED','TERMINATED')),
  PRIMARY KEY (tenant_id, counterparty_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, counterparty_id) REFERENCES master.counterparty (tenant_id, counterparty_id),
  FOREIGN KEY (tenant_id, issuer_id)       REFERENCES master.issuer (tenant_id, issuer_id),
  EXCLUDE USING gist (tenant_id WITH =, counterparty_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED,
  EXCLUDE USING gist (tenant_id WITH =, lei WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL AND lei IS NOT NULL) DEFERRABLE INITIALLY DEFERRED
);

-- Provenance (M9) on every master version table that holds copies of outside data.
SELECT pg_temp.add_provenance('master.issuer_group_version',  'master.load_run');
SELECT pg_temp.add_provenance('master.issuer_version',        'master.load_run');
SELECT pg_temp.add_provenance('master.security_version',      'master.load_run');
SELECT pg_temp.add_provenance('master.credit_rating_version', 'master.load_run');
SELECT pg_temp.add_provenance('master.benchmark_version',     'master.load_run');
SELECT pg_temp.add_provenance('master.counterparty_version',  'master.load_run');
SELECT pg_temp.add_provenance('master.security_schedule',     'master.load_run');
SELECT pg_temp.add_provenance('master.benchmark_level',       'master.load_run');
SELECT pg_temp.add_provenance('master.benchmark_constituent', 'master.load_run');

-- Bi-temporal triggers on master version tables.
SELECT pg_temp.make_bitemporal('master.issuer_group_version',  ARRAY['tenant_id','group_id']);
SELECT pg_temp.make_bitemporal('master.issuer_version',        ARRAY['tenant_id','issuer_id']);
SELECT pg_temp.make_bitemporal('master.security_version',      ARRAY['tenant_id','security_id']);
SELECT pg_temp.make_bitemporal('master.credit_rating_version', ARRAY['tenant_id','rating_id']);
SELECT pg_temp.make_bitemporal('master.benchmark_version',     ARRAY['tenant_id','benchmark_id']);
SELECT pg_temp.make_bitemporal('master.counterparty_version',  ARRAY['tenant_id','counterparty_id']);
SELECT pg_temp.make_bitemporal('master.security_schedule',     ARRAY['tenant_id','security_id','schedule_type','event_date']);

-- Outside code types (§3.4).  Tenant-scoped: licensed vendor code sets differ per AMC (D-62).
CREATE TABLE master.identifier_scheme (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  scheme_code   text NOT NULL CHECK (scheme_code ~ '^[A-Z][A-Z0-9_]{1,40}$'),
  description   text NOT NULL,
  issuing_body  text NOT NULL,
  format_regex  text,                          -- format check applied before a code is stored
  entity_types  text[] NOT NULL,               -- which master entities may carry it
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, scheme_code),
  CHECK (entity_types <@ ARRAY['SECURITY','ISSUER','ISSUER_GROUP','COUNTERPARTY','BENCHMARK'] AND cardinality(entity_types) > 0)
);
CREATE TRIGGER identifier_scheme_version BEFORE UPDATE ON master.identifier_scheme
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Crosswalk for master entities (§3.4).  Nothing points at it by foreign key, so it is one
-- bi-temporal table (§3.1 rule 2).  One outside code points to one entity on any date.
CREATE TABLE master.external_identifier (
  tenant_id              uuid NOT NULL,
  external_identifier_id uuid NOT NULL DEFAULT gen_random_uuid(),
  valid_period           daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  recorded_at            timestamptz NOT NULL DEFAULT clock_timestamp(),
  superseded_at          timestamptz,
  entity_type            text NOT NULL CHECK (entity_type IN ('SECURITY','ISSUER','ISSUER_GROUP','COUNTERPARTY','BENCHMARK')),
  entity_id              uuid NOT NULL,
  scheme_code            text NOT NULL,
  value                  text NOT NULL,
  PRIMARY KEY (tenant_id, external_identifier_id, valid_period, recorded_at),
  FOREIGN KEY (tenant_id, scheme_code) REFERENCES master.identifier_scheme (tenant_id, scheme_code),
  EXCLUDE USING gist (tenant_id WITH =, external_identifier_id WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED,
  EXCLUDE USING gist (tenant_id WITH =, scheme_code WITH =, value WITH =, valid_period WITH &&)
    WHERE (superseded_at IS NULL) DEFERRABLE INITIALLY DEFERRED
);
SELECT pg_temp.add_provenance('master.external_identifier', 'master.load_run');
SELECT pg_temp.make_bitemporal('master.external_identifier', ARRAY['tenant_id','external_identifier_id']);

-- The entity must exist in this schema, the scheme must allow the entity type, and the value
-- must pass the scheme's format check.
CREATE OR REPLACE FUNCTION master.tg_external_identifier_check() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_ok boolean; v_types text[]; v_regex text;
BEGIN
  IF platform.bt_is_continuation(TG_RELID, to_jsonb(NEW)) THEN RETURN NEW; END IF;  -- already checked (BT-5)
  v_ok := CASE NEW.entity_type
    WHEN 'SECURITY'     THEN EXISTS (SELECT 1 FROM master.security     WHERE tenant_id = NEW.tenant_id AND security_id     = NEW.entity_id)
    WHEN 'ISSUER'       THEN EXISTS (SELECT 1 FROM master.issuer       WHERE tenant_id = NEW.tenant_id AND issuer_id       = NEW.entity_id)
    WHEN 'ISSUER_GROUP' THEN EXISTS (SELECT 1 FROM master.issuer_group WHERE tenant_id = NEW.tenant_id AND group_id        = NEW.entity_id)
    WHEN 'COUNTERPARTY' THEN EXISTS (SELECT 1 FROM master.counterparty WHERE tenant_id = NEW.tenant_id AND counterparty_id = NEW.entity_id)
    WHEN 'BENCHMARK'    THEN EXISTS (SELECT 1 FROM master.benchmark    WHERE tenant_id = NEW.tenant_id AND benchmark_id    = NEW.entity_id)
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
CREATE TRIGGER external_identifier_check BEFORE INSERT ON master.external_identifier
  FOR EACH ROW EXECUTE FUNCTION master.tg_external_identifier_check();

-- Which provider wins for which field when sources disagree (PRD-016 §10).  Approved versions.
CREATE TABLE master.source_precedence_rule (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  entity_type   text NOT NULL CHECK (entity_type IN ('SECURITY','ISSUER','ISSUER_GROUP','COUNTERPARTY','BENCHMARK','CREDIT_RATING')),
  field_name    text NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  provider_order text[] NOT NULL CHECK (cardinality(provider_order) > 0),
  valid_period  daterange NOT NULL CHECK (NOT isempty(valid_period) AND lower(valid_period) IS NOT NULL),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  maker_user_id uuid NOT NULL,
  approval_request_id uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, entity_type, field_name, version_no),
  CHECK (status NOT IN ('APPROVED','SUPERSEDED') OR approval_request_id IS NOT NULL),
  EXCLUDE USING gist (tenant_id WITH =, entity_type WITH =, field_name WITH =, valid_period WITH &&) WHERE (status = 'APPROVED')
);

-- Approved rule versions (M11): content frozen once APPROVED; only APPROVED -> SUPERSEDED moves.
CREATE OR REPLACE FUNCTION platform.tg_vr_frozen() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status IN ('APPROVED','SUPERSEDED') THEN
      RAISE EXCEPTION 'IMMUTABLE_RECORD: approved version on %.% is never deleted', TG_TABLE_SCHEMA, TG_TABLE_NAME
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.status IN ('APPROVED','SUPERSEDED')
     AND ((to_jsonb(NEW) - 'status') IS DISTINCT FROM (to_jsonb(OLD) - 'status')
          OR NOT (OLD.status = 'APPROVED' AND NEW.status IN ('APPROVED','SUPERSEDED'))
          OR (OLD.status = 'SUPERSEDED' AND NEW.status <> 'SUPERSEDED')) THEN
    RAISE EXCEPTION 'IMMUTABLE_RECORD: approved version on %.% cannot be edited; create a new version',
      TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER source_precedence_rule_frozen BEFORE UPDATE OR DELETE ON master.source_precedence_rule
  FOR EACH ROW EXECUTE FUNCTION platform.tg_vr_frozen();
SELECT pg_temp.make_state_machine('master', 'source_precedence_rule', 'status',
  ARRAY['entity_type','field_name','version_no'], ARRAY['text','text','integer']);
-- The approved-version lifecycle of DA-001 §3.1 (code VR).
INSERT INTO master.source_precedence_rule_transition (from_state, to_state, cause) VALUES
  ('(NEW)','DRAFT','CREATE'),
  ('DRAFT','PENDING_APPROVAL','STATE_CHANGE'),
  ('PENDING_APPROVAL','APPROVED','STATE_CHANGE'),
  ('PENDING_APPROVAL','REJECTED','STATE_CHANGE'),
  ('PENDING_APPROVAL','DRAFT','REJECT'),
  ('APPROVED','SUPERSEDED','STATE_CHANGE');

-- Request to create or change a golden record (WF-041), with evidence.
CREATE TABLE master.steward_request (
  tenant_id       uuid NOT NULL REFERENCES platform.tenant,
  request_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  request_kind    text NOT NULL CHECK (request_kind IN ('CREATE','CHANGE','MERGE','RETIRE')),
  entity_type     text NOT NULL CHECK (entity_type IN ('SECURITY','ISSUER','ISSUER_GROUP','COUNTERPARTY','BENCHMARK','CREDIT_RATING')),
  entity_id       uuid,                       -- NULL for CREATE
  requested_by    uuid NOT NULL,
  requesting_module text NOT NULL,
  proposed_change jsonb NOT NULL,             -- before/after image of the change (M20)
  evidence_document_id uuid,                  -- ID reference to documents.document (M4)
  status          text NOT NULL DEFAULT 'SUBMITTED',
  approval_request_id uuid,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  row_version     integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, request_id),
  CHECK ((request_kind = 'CREATE') = (entity_id IS NULL)),
  CHECK (status NOT IN ('APPROVED','APPLIED') OR approval_request_id IS NOT NULL)
);
CREATE TRIGGER steward_request_version BEFORE UPDATE ON master.steward_request
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('master', 'steward_request', 'status', ARRAY['request_id'], ARRAY['uuid']);
-- [ASSUMPTION] states: PRD-016 WF-041 shows request -> steward queue -> decision; the exact
-- list is not fixed by any source document.
INSERT INTO master.steward_request_transition (from_state, to_state, cause) VALUES
  ('(NEW)','SUBMITTED','CREATE'),
  ('SUBMITTED','IN_REVIEW','STATE_CHANGE'),
  ('IN_REVIEW','APPROVED','STATE_CHANGE'),
  ('IN_REVIEW','REJECTED','STATE_CHANGE'),
  ('SUBMITTED','CANCELLED','STATE_CHANGE'),
  ('APPROVED','APPLIED','STATE_CHANGE');

-- Possible duplicates found by matching, for a steward to decide.  For investors, distributors
-- and users (owned by D13, D14, D01) only the finding is kept here and routed to the owner's
-- queue (EA-003 T9): the IDs are ID references (M4).
CREATE TABLE master.match_candidate (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  candidate_id  uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_type   text NOT NULL CHECK (entity_type IN
                 ('SECURITY','ISSUER','ISSUER_GROUP','COUNTERPARTY','BENCHMARK','INVESTOR','DISTRIBUTOR','USER')),
  entity_id_a   uuid NOT NULL,
  entity_id_b   uuid NOT NULL,
  match_score   numeric(9,6) CHECK (match_score >= 0 AND match_score <= 1),
  matcher_version text NOT NULL,
  owner_module  text NOT NULL,                -- module whose queue decides (T9)
  status        text NOT NULL DEFAULT 'OPEN',
  decided_by    uuid,
  decision_reason text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, candidate_id),
  CHECK (entity_id_a <> entity_id_b),
  CHECK ((status IN ('OPEN','ROUTED_TO_OWNER')) = (decided_by IS NULL))
);
CREATE UNIQUE INDEX match_candidate_open_ux ON master.match_candidate
  (tenant_id, entity_type, LEAST(entity_id_a, entity_id_b), GREATEST(entity_id_a, entity_id_b))
  WHERE status IN ('OPEN','ROUTED_TO_OWNER');
CREATE TRIGGER match_candidate_version BEFORE UPDATE ON master.match_candidate
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
SELECT pg_temp.make_state_machine('master', 'match_candidate', 'status', ARRAY['candidate_id'], ARRAY['uuid']);
-- [ASSUMPTION] states: a steward confirms or rejects; records of other modules are routed to
-- their owner, who decides there.
INSERT INTO master.match_candidate_transition (from_state, to_state, cause) VALUES
  ('(NEW)','OPEN','CREATE'),
  ('OPEN','CONFIRMED_DUPLICATE','STATE_CHANGE'),
  ('OPEN','NOT_DUPLICATE','STATE_CHANGE'),
  ('OPEN','ROUTED_TO_OWNER','STATE_CHANGE'),
  ('ROUTED_TO_OWNER','CONFIRMED_DUPLICATE','STATE_CHANGE'),
  ('ROUTED_TO_OWNER','NOT_DUPLICATE','STATE_CHANGE');

-- Standard columns on mutable rows (M21) where the table definitions above lack them.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['identity.api_client','platform.feature_flag','platform.notification_channel',
                           'master.identifier_scheme','master.match_candidate','identity.role_grant_request',
                           'platform.schedule_entry','master.steward_request','identity.recertification_item']
  LOOP
    EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now()', t);
    EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS created_by uuid DEFAULT platform.current_user_id()', t);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 06  Row-level security and grants for every new table
-- ---------------------------------------------------------------------
SELECT platform.apply_tenant_rls();

-- Grant only on tables that do not have grants yet (the tables created above), so the revokes
-- DDL-000 made on its own tables stay in force.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS s, c.relname AS t
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind IN ('r','p')
       AND n.nspname IN ('platform','identity','audit','master','product','workflow','investment','portfolio',
                         'trading','execution','settlement','compliance','risk','valuation','accounting','nav',
                         'operations','investor','distribution','finance','documents','analytics','ai')
       AND NOT has_table_privilege('amc_readonly', c.oid, 'SELECT')
  LOOP
    EXECUTE format('GRANT SELECT ON %I.%I TO amc_readonly, amc_auditor', r.s, r.t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON %I.%I TO amc_app', r.s, r.t);
  END LOOP;
END $$;

-- No role but the migration owner may create temporary objects: an application role with its own
-- temporary table and trigger could otherwise write at trigger depth 2 (BT-5, history tables).
DO $$ BEGIN EXECUTE format('REVOKE TEMPORARY ON DATABASE %I FROM PUBLIC', current_database()); END $$;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Product-level rows (M3) are read-only for application roles; they change only by migration.
REVOKE INSERT, UPDATE ON platform.cell, platform.config_item, platform.code_list, platform.code_value,
                         platform.environment_release,
                         platform.config_version_transition, identity.role_grant_request_transition,
                         identity.recertification_campaign_transition, identity.recertification_item_transition,
                         master.steward_request_transition, master.match_candidate_transition,
                         master.source_precedence_rule_transition,
                         identity.permission, master.currency,         -- DDL-000 product-level lists (M3)
                         trading.order_state_transition
  FROM amc_app;
-- Written only by the cell agent applying a signed desired-state step (DM-16), or by the
-- migration owner until the ADR-0020 roles exist: never by the application.
REVOKE INSERT, UPDATE ON platform.subscription, platform.subscription_version,
                         platform.tenant_entitlement, platform.usage_meter
  FROM amc_app;
-- Insert-only tables: no UPDATE for the application (the triggers refuse it as well).
REVOKE UPDATE ON platform.tenant_status_history, platform.usage_meter, platform.config_promotion,
                 platform.config_version_history, identity.role_grant_request_history,
                 identity.recertification_campaign_history, identity.recertification_item_history,
                 audit.chain_anchor, audit.access_log,
                 master.benchmark_level, master.benchmark_constituent,
                 master.steward_request_history, master.match_candidate_history,
                 master.source_precedence_rule_history,
                 audit.access_log_2026_11, audit.access_log_2026_12, audit.access_log_default
  FROM amc_app;
-- The tenant status history is written by the trigger on platform.tenant, never by the app.
REVOKE INSERT ON platform.tenant_status_history FROM amc_app;
-- Closure tables (BT-3, BT-4) are insert-only; those of tables the application may not write are
-- not writable by it either.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT n.nspname AS s, c.relname AS t FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind = 'r' AND c.relname LIKE '%\_closure'
              AND n.nspname IN ('platform','identity','audit','master')
  LOOP
    EXECUTE format('REVOKE UPDATE ON %I.%I FROM amc_app', r.s, r.t);
  END LOOP;
END $$;
REVOKE INSERT ON platform.subscription_version_closure, platform.tenant_entitlement_closure FROM amc_app;

COMMIT;

-- End of DDL-001.
