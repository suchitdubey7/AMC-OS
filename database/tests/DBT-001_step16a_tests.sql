-- =====================================================================
-- DBT-001  AMC OS - Step 16a database tests (status: Draft, WP4 / GOV-006 Step 16, part a)
-- Run after every file in database/ddl and after DBT-000 (it reuses DBT-000's tenants):
--   psql -v ON_ERROR_STOP=1 -f DBT-001_step16a_tests.sql
-- Every test prints PASS or raises an exception (which stops the run).
-- Rule numbers (M2, M4, M5, M7, M9, M14 ...) are DA-001 §1 modelling rules.
-- =====================================================================
\set QUIET on
CREATE OR REPLACE FUNCTION pg_temp.ok(msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN RAISE NOTICE 'PASS  %', msg; END $$;

-- =====================================================================
-- C  Catalogue checks (run as migration owner)
-- =====================================================================
DO $$
DECLARE n int; v text;
BEGIN
  -- M5: no float or money type anywhere in the 23 schemas.
  SELECT count(*), string_agg(table_schema || '.' || table_name || '.' || column_name, ', ') INTO n, v
    FROM information_schema.columns
   WHERE table_schema NOT IN ('pg_catalog','information_schema')
     AND data_type IN ('real','double precision','money');
  IF n <> 0 THEN RAISE EXCEPTION 'C1 FAIL: float/money columns: %', v; END IF;
  -- M5 / DM-22: the DDL-000 numeric(20,4) amount columns are widened to numeric(24,4).
  -- (lot_size numeric(20,4) is a quantity term DA-001 §3.7 keeps; it is not in this list.)
  SELECT count(*), string_agg(c.t || '.' || c.col || '=' || coalesce(ic.numeric_precision::text, '?') || ',' || coalesce(ic.numeric_scale::text, '?'), ', ')
    INTO n, v
    FROM (VALUES ('settlement.trade','brokerage'), ('settlement.trade','stt'), ('settlement.trade','stamp_duty'),
                 ('settlement.trade','gst'), ('settlement.trade','other_charges'),
                 ('investor.investor_txn','stamp_duty'), ('investor.investor_txn','exit_load'), ('investor.investor_txn','tds'),
                 ('investor.sip_registration','amount'),
                 ('distribution.commission_line','gross_commission'), ('distribution.commission_line','gst'),
                 ('distribution.commission_line','tds'), ('distribution.commission_line','clawback'),
                 ('distribution.commission_line','net_payable')) AS c(t, col)
    LEFT JOIN information_schema.columns ic
      ON ic.table_schema || '.' || ic.table_name = c.t AND ic.column_name = c.col
   WHERE ic.numeric_precision IS DISTINCT FROM 24 OR ic.numeric_scale IS DISTINCT FROM 4;
  IF n <> 0 THEN RAISE EXCEPTION 'C1 FAIL: amount columns not numeric(24,4): %', v; END IF;
  PERFORM pg_temp.ok('C1 no float or money columns; the 14 DM-22 amount columns are numeric(24,4)');
END $$;

DO $$
DECLARE n int; v text;
BEGIN
  -- M2: every tenant table (and partition) has forced RLS and the tenant policy.
  SELECT count(*), string_agg(s.nspname || '.' || k.relname, ', ') INTO n, v
    FROM pg_class k JOIN pg_namespace s ON s.oid = k.relnamespace
   WHERE k.relkind IN ('r','p') AND s.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
     AND NOT (s.nspname = 'platform' AND k.relname = 'tenant')
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = k.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped)
     AND (NOT k.relforcerowsecurity
          OR NOT EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = k.oid AND p.polname = 'tenant_isolation'));
  IF n <> 0 THEN RAISE EXCEPTION 'C2 FAIL: tenant tables without forced RLS policy: %', v; END IF;
  -- M3: a table without tenant_id must be on the product-level list.
  SELECT count(*), string_agg(s.nspname || '.' || k.relname, ', ') INTO n, v
    FROM pg_class k JOIN pg_namespace s ON s.oid = k.relnamespace
   WHERE k.relkind IN ('r','p') AND s.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
     AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = k.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped)
     AND NOT (s.nspname || '.' || k.relname IN ('platform.tenant','platform.cell','platform.config_item',
                 'platform.code_list','platform.code_value','platform.environment_release',
                 'master.currency','identity.permission','trading.order_state_transition')
              OR k.relname LIKE '%\_transition');
  IF n <> 0 THEN RAISE EXCEPTION 'C2 FAIL: tables without tenant_id outside the M3 list: %', v; END IF;
  -- M3: product-level lists are read-only for the application role.
  SELECT count(*), string_agg(s.nspname || '.' || k.relname, ', ') INTO n, v
    FROM pg_class k JOIN pg_namespace s ON s.oid = k.relnamespace
   WHERE k.relkind IN ('r','p') AND s.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
     AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = k.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped)
     AND (has_table_privilege('amc_app', k.oid, 'INSERT') OR has_table_privilege('amc_app', k.oid, 'UPDATE')
          OR has_table_privilege('amc_app', k.oid, 'DELETE'));
  IF n <> 0 THEN RAISE EXCEPTION 'C2 FAIL: product-level tables writable by amc_app: %', v; END IF;
  PERFORM pg_temp.ok('C2 every tenant table has forced RLS; every other table is on the M3 list and read-only for the application');
END $$;

DO $$
DECLARE n int; v text;
BEGIN
  -- M4: cross-schema foreign keys only to platform.tenant, platform.cell, master.*, product.*.
  -- The two DDL-000 exceptions are DM-20 (ADR-0020, not yet accepted) and stay listed here.
  SELECT count(*), string_agg(conname || ' ' || src.nspname || '.' || sc.relname || ' -> ' || tgt.nspname || '.' || tc.relname, '; ') INTO n, v
    FROM pg_constraint c
    JOIN pg_class sc ON sc.oid = c.conrelid JOIN pg_namespace src ON src.oid = sc.relnamespace
    JOIN pg_class tc ON tc.oid = c.confrelid JOIN pg_namespace tgt ON tgt.oid = tc.relnamespace
   WHERE c.contype = 'f' AND src.nspname <> tgt.nspname
     AND NOT (tgt.nspname = 'platform' AND tc.relname IN ('tenant','cell'))
     AND tgt.nspname NOT IN ('master','product')
     AND NOT (src.nspname = 'trading' AND tgt.nspname = 'investment' AND tc.relname = 'decision_record')
     AND NOT (src.nspname = 'ai' AND tgt.nspname = 'identity' AND tc.relname = 'app_user');
  IF n <> 0 THEN RAISE EXCEPTION 'C3 FAIL: cross-schema foreign keys breaking M4: %', v; END IF;
  -- M2: a foreign key between two tenant tables starts with tenant_id on both sides.
  SELECT count(*), string_agg(conname, ', ') INTO n, v
    FROM pg_constraint c
   WHERE c.contype = 'f'
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.conrelid  AND a.attname = 'tenant_id' AND NOT a.attisdropped)
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.confrelid AND a.attname = 'tenant_id' AND NOT a.attisdropped)
     AND NOT EXISTS (SELECT 1 FROM pg_class t JOIN pg_namespace s ON s.oid = t.relnamespace
                      WHERE t.oid = c.confrelid AND s.nspname = 'platform' AND t.relname = 'tenant')
     AND ((SELECT attname FROM pg_attribute WHERE attrelid = c.conrelid  AND attnum = c.conkey[1])  <> 'tenant_id'
       OR (SELECT attname FROM pg_attribute WHERE attrelid = c.confrelid AND attnum = c.confkey[1]) <> 'tenant_id');
  IF n <> 0 THEN RAISE EXCEPTION 'C3 FAIL: tenant foreign keys not led by tenant_id: %', v; END IF;
  PERFORM pg_temp.ok('C3 cross-schema FKs only to reference tables (2 DDL-000 exceptions wait for ADR-0020); tenant FKs are composite');
END $$;

DO $$
DECLARE n int; v text;
BEGIN
  -- BT-5 and the history-table rule rely on application roles having no temporary objects and no
  -- CREATE on any schema (they could otherwise run their own triggers).
  SELECT count(*), string_agg(r, ', ') INTO n, v
    FROM unnest(ARRAY['amc_app','amc_readonly','amc_auditor','amc_ai_agent']) AS r
   WHERE has_database_privilege(r, current_database(), 'TEMPORARY')
      OR EXISTS (SELECT 1 FROM pg_namespace ns WHERE ns.nspname NOT LIKE 'pg\_%' AND ns.nspname <> 'information_schema'
                   AND has_schema_privilege(r, ns.oid, 'CREATE'));
  IF n <> 0 THEN RAISE EXCEPTION 'C4 FAIL: roles with TEMPORARY or CREATE: %', v; END IF;
  PERFORM pg_temp.ok('C4 application roles cannot create temporary objects or objects in any schema');
END $$;

-- =====================================================================
-- Fixtures for tenant A (as the application role)
-- =====================================================================
SET ROLE amc_app;
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
SET LOCAL app.user_id   = '10000000-0000-0000-0000-000000000002';
INSERT INTO identity.app_user (user_id, tenant_id, external_subject, email, display_name) VALUES
 ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-00000000000a','sub-ta','ta@alpha.in','Tenant Admin A'),
 ('10000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-00000000000a','sub-co','co@alpha.in','Compliance Officer A');
INSERT INTO master.identifier_scheme (tenant_id, scheme_code, description, issuing_body, format_regex, entity_types) VALUES
 ('00000000-0000-0000-0000-00000000000a','ISIN','International Securities Identification Number','NSDL / CDSL (India)',
  '^[A-Z]{2}[A-Z0-9]{9}[0-9]$', ARRAY['SECURITY']),
 ('00000000-0000-0000-0000-00000000000a','NSE_SYMBOL','NSE trading symbol','NSE', NULL, ARRAY['SECURITY']);
INSERT INTO master.load_run (tenant_id, load_run_id, inbound_file_id, adapter_name, adapter_version, canonical_family, business_date)
VALUES ('00000000-0000-0000-0000-00000000000a','b1000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001',
        'test_adapter','1.0.0','SECURITY_MASTER','2026-11-20');
INSERT INTO master.security (tenant_id, security_id, isin, instrument_type)
VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000002','INE000B01016','EQUITY');
COMMIT;

-- =====================================================================
-- T8  Bi-temporal versions (M7, DM-1)
-- =====================================================================
DO $$
DECLARE v_before timestamptz; v_name text; n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.security_version (tenant_id, security_id, valid_period, short_name, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000002','[2026-01-01,)','BETA CORP',
          'f0000000-0000-0000-0000-000000000002');
  v_before := clock_timestamp();
  -- Correction learned later: the name was wrong for the whole period.
  INSERT INTO master.security_version (tenant_id, security_id, valid_period, short_name, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000002','[2026-01-01,)','BETA CORPORATION',
          'f0000000-0000-0000-0000-000000000003');
  SET CONSTRAINTS ALL IMMEDIATE;
  -- What did we believe at v_before about 2026-06-30?
  SELECT short_name INTO v_name FROM master.security_version
   WHERE security_id = '40000000-0000-0000-0000-000000000002' AND valid_period @> date '2026-06-30'
     AND recorded_at <= v_before AND (superseded_at IS NULL OR superseded_at > v_before);
  IF v_name IS DISTINCT FROM 'BETA CORP' THEN RAISE EXCEPTION 'T8a FAIL: old belief is %', v_name; END IF;
  SELECT short_name INTO v_name FROM master.security_version
   WHERE security_id = '40000000-0000-0000-0000-000000000002' AND valid_period @> date '2026-06-30' AND superseded_at IS NULL;
  IF v_name IS DISTINCT FROM 'BETA CORPORATION' THEN RAISE EXCEPTION 'T8a FAIL: current belief is %', v_name; END IF;
  SELECT count(*) INTO n FROM master.security_version WHERE security_id = '40000000-0000-0000-0000-000000000002';
  IF n <> 2 THEN RAISE EXCEPTION 'T8a FAIL: % versions kept', n; END IF;
  PERFORM pg_temp.ok('T8a "as known on X about Y" returns the old belief after a correction; both versions kept');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    UPDATE master.security_version SET short_name = 'EDITED'
     WHERE security_id = '40000000-0000-0000-0000-000000000002' AND superseded_at IS NULL;
    RAISE EXCEPTION 'T8b FAIL: a version was edited in place';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE master.security_version SET superseded_at = now()
     WHERE security_id = '40000000-0000-0000-0000-000000000002' AND superseded_at IS NOT NULL;
    RAISE EXCEPTION 'T8b FAIL: superseded_at set twice';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE master.security SET isin = 'INE000B01099' WHERE security_id = '40000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'T8b FAIL: anchor changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T8b versions are insert-only: no edit, superseded_at set only once; anchors never change');
END $$;

-- The same guards hold for a role that has every grant (the migration owner): the triggers, not
-- missing grants, refuse the change.
RESET ROLE;
DO $$
DECLARE e text;
BEGIN
  BEGIN
    DELETE FROM master.security_version WHERE security_id = '40000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'T8b2 FAIL: version deleted';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'IMMUTABLE_RECORD%' THEN RAISE EXCEPTION 'T8b2 FAIL: wrong refusal: %', e; END IF;
  END;
  BEGIN
    UPDATE master.security_version SET short_name = 'EDITED'
     WHERE security_id = '40000000-0000-0000-0000-000000000002' AND superseded_at IS NULL;
    RAISE EXCEPTION 'T8b2 FAIL: version edited';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'IMMUTABLE_RECORD%' THEN RAISE EXCEPTION 'T8b2 FAIL: wrong refusal: %', e; END IF;
  END;
  PERFORM pg_temp.ok('T8b2 the bi-temporal guard trigger itself refuses delete and edit (not only missing grants)');
END $$;
SET ROLE amc_app;

-- A back-dated change for part of the period: the module inserts the full corrected set.
DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.security_version (tenant_id, security_id, valid_period, short_name, approval_request_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000002','[2026-01-01,2026-07-01)','BETA CORPORATION',
    'f0000000-0000-0000-0000-000000000004'),
   ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000002','[2026-07-01,)','BETA CORPORATION LTD',
    'f0000000-0000-0000-0000-000000000004');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM master.security_version
   WHERE security_id = '40000000-0000-0000-0000-000000000002' AND superseded_at IS NULL;
  IF n <> 2 THEN RAISE EXCEPTION 'T8c FAIL: % current versions', n; END IF;
  SELECT count(*) INTO n FROM master.security_version
   WHERE security_id = '40000000-0000-0000-0000-000000000002' AND superseded_at IS NULL
     AND ((valid_period = '[2026-01-01,2026-07-01)' AND short_name = 'BETA CORPORATION')
       OR (valid_period = '[2026-07-01,)' AND short_name = 'BETA CORPORATION LTD'));
  IF n <> 2 THEN RAISE EXCEPTION 'T8c FAIL: current versions do not carry the corrected content'; END IF;
  PERFORM pg_temp.ok('T8c a split of the validity period (two rows, one statement) leaves exactly the corrected set current');
END $$;

-- System time is the database's: a forged recorded_at is overwritten, a row cannot be born superseded.
DO $$
DECLARE n int; e text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.benchmark_version (tenant_id, benchmark_id, valid_period, recorded_at, name, provider, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000001','[2026-01-01,)','2099-01-01',
          'Nifty 100 TRI','NSE Indices','f0000000-0000-0000-0000-000000000010');
  SELECT count(*) INTO n FROM master.benchmark_version WHERE recorded_at > now() + interval '1 day';
  IF n <> 0 THEN RAISE EXCEPTION 'T8d FAIL: a forged future recorded_at was kept'; END IF;
  BEGIN
    INSERT INTO master.benchmark_version (tenant_id, benchmark_id, valid_period, recorded_at, superseded_at, name, provider, approval_request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000001','[2025-01-01,2026-01-01)','2026-02-01','2026-03-01',
            'Forged','X','f0000000-0000-0000-0000-000000000010');
    RAISE EXCEPTION 'T8d FAIL: a row was inserted already superseded';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'IMMUTABLE_RECORD%' THEN RAISE EXCEPTION 'T8d FAIL: wrong refusal: %', e; END IF;
  END;
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM master.benchmark_version WHERE benchmark_id = '20000000-0000-0000-0000-000000000001' AND superseded_at IS NULL;
  IF n <> 1 THEN RAISE EXCEPTION 'T8d FAIL: % current benchmark versions', n; END IF;
  PERFORM pg_temp.ok('T8d recorded_at is always the database clock; a row cannot be born superseded; later corrections still work');
END $$;

-- A forward-dated change keeps the earlier dates current (no silent gap).
DO $$
DECLARE v text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.benchmark_version (tenant_id, benchmark_id, valid_period, name, provider, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000001','[2027-01-01,)',
          'Nifty 100 TRI (renamed)','NSE Indices','f0000000-0000-0000-0000-000000000011');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT name INTO v FROM master.benchmark_version
   WHERE benchmark_id = '20000000-0000-0000-0000-000000000001' AND superseded_at IS NULL AND valid_period @> date '2026-06-30';
  IF v IS DISTINCT FROM 'Nifty 100 TRI' THEN RAISE EXCEPTION 'T8e FAIL: 2026 value is %', coalesce(v, 'missing'); END IF;
  SELECT name INTO v FROM master.benchmark_version
   WHERE benchmark_id = '20000000-0000-0000-0000-000000000001' AND superseded_at IS NULL AND valid_period @> date '2027-06-30';
  IF v IS DISTINCT FROM 'Nifty 100 TRI (renamed)' THEN RAISE EXCEPTION 'T8e FAIL: 2027 value is %', coalesce(v, 'missing'); END IF;
  PERFORM pg_temp.ok('T8e a forward-dated version leaves the earlier dates current with the old content');
END $$;

-- Date-keyed bi-temporal tables (calendar, debt schedule) accept corrections.
DO $$
DECLARE n int; v boolean;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.business_calendar (tenant_id, calendar_code, cal_date, is_business_day, description)
  VALUES ('00000000-0000-0000-0000-00000000000a','NSE_EQ','2026-12-25',true,'loaded');
  INSERT INTO platform.business_calendar (tenant_id, calendar_code, cal_date, is_business_day, description, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','NSE_EQ','2026-12-25',false,'holiday (corrected)','f0000000-0000-0000-0000-000000000012');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*), bool_and(NOT is_business_day) INTO n, v FROM platform.business_calendar
   WHERE calendar_code = 'NSE_EQ' AND cal_date = '2026-12-25' AND superseded_at IS NULL;
  IF n <> 1 OR NOT v THEN RAISE EXCEPTION 'T8f FAIL: calendar correction (% current)', n; END IF;
END $$;
-- (Each DO block is its own transaction; the schedule correction is kept separate so it runs
-- with the default deferred check.)
DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.security (tenant_id, security_id, isin, instrument_type)
  VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000003','INE000C07011','NCD');
  INSERT INTO master.security_schedule (tenant_id, security_id, schedule_type, event_date, coupon_rate, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000003','COUPON','2027-03-31',8.250000,'f0000000-0000-0000-0000-000000000012');
  INSERT INTO master.security_schedule (tenant_id, security_id, schedule_type, event_date, coupon_rate, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000003','COUPON','2027-03-31',8.300000,'f0000000-0000-0000-0000-000000000013');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM master.security_schedule
   WHERE security_id = '40000000-0000-0000-0000-000000000003' AND superseded_at IS NULL AND coupon_rate = 8.300000;
  IF n <> 1 THEN RAISE EXCEPTION 'T8f FAIL: schedule correction'; END IF;
  PERFORM pg_temp.ok('T8f date-keyed tables (calendar, debt schedule) take corrections; one current row per key');
END $$;

-- BT-2: a version with an end date corrects only its own period; the old content stays current
-- after it (ending a key is an END row, BT-3).
DO $$
DECLARE v text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.benchmark_version (tenant_id, benchmark_id, valid_period, name, provider, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000001','[2026-03-01,2026-04-01)',
          'Nifty 100 TRI (March name)','NSE Indices','f0000000-0000-0000-0000-000000000017');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT name INTO v FROM master.benchmark_version
   WHERE benchmark_id = '20000000-0000-0000-0000-000000000001' AND superseded_at IS NULL AND valid_period @> date '2026-03-15';
  IF v IS DISTINCT FROM 'Nifty 100 TRI (March name)' THEN RAISE EXCEPTION 'T8e2 FAIL: March value is %', coalesce(v, 'missing'); END IF;
  SELECT name INTO v FROM master.benchmark_version
   WHERE benchmark_id = '20000000-0000-0000-0000-000000000001' AND superseded_at IS NULL AND valid_period @> date '2026-06-30';
  IF v IS DISTINCT FROM 'Nifty 100 TRI' THEN RAISE EXCEPTION 'T8e2 FAIL: June value is %', coalesce(v, 'missing'); END IF;
  SELECT name INTO v FROM master.benchmark_version
   WHERE benchmark_id = '20000000-0000-0000-0000-000000000001' AND superseded_at IS NULL AND valid_period @> date '2027-06-30';
  IF v IS DISTINCT FROM 'Nifty 100 TRI (renamed)' THEN RAISE EXCEPTION 'T8e2 FAIL: 2027 value is %', coalesce(v, 'missing'); END IF;
  PERFORM pg_temp.ok('T8e2 a version with an end date changes only its own period; earlier and later content stays current');
END $$;

-- BT-3 (D-76): ending a grant is a separate END row that follows an approved REVOKE request, on the
-- request's date.  It closes every current version from that date on, including a version that
-- starts later, and keeps the signed content before that date unchanged.  The application can
-- never set superseded_at itself.  Requests: maker and checker come from the identity context; the
-- content of a request never changes after it is raised.
DO $$
DECLARE n int; e text; v_close timestamptz; v_by uuid; v_appr uuid;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO identity.role (tenant_id, role_code, description) VALUES ('00000000-0000-0000-0000-00000000000a','DEALER','Dealer');
  INSERT INTO identity.user_role (tenant_id, grant_id, user_id, role_code)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000001','DEALER');
  INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by) VALUES
   ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','[2026-11-01,)',
    '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003');
  -- A forward-dated version already recorded (the round-3 Blocker case).
  INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by) VALUES
   ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','[2027-01-01,)',
    '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003');
  -- Requests for this grant, raised by ...02 (requested_by is set by the database from app.user_id).
  INSERT INTO identity.role_grant_request (tenant_id, request_id, request_type, user_id, role_code, grant_id, requested_by, reason, effective_from, requested_scope) VALUES
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000a1','REVOKE','10000000-0000-0000-0000-000000000001','DEALER',
    'c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000004','leaver','2026-12-01',NULL),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000a5','REVOKE','10000000-0000-0000-0000-000000000001','DEALER',
    'c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','second revoke, kept unused for T8h','2026-12-01',NULL),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000a2','CHANGE_SCOPE','10000000-0000-0000-0000-000000000001','DEALER',
    'c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','desk EQ','2026-11-01',
    '{"add":[{"attribute":"DESK","value":"EQ"}]}'),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000a6','CHANGE_SCOPE','10000000-0000-0000-0000-000000000001','DEALER',
    'c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','desk EQ typed in error','2026-11-01',
    '{"remove":[{"attribute":"DESK","value":"EQ"}]}'),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000a7','CHANGE_SCOPE','10000000-0000-0000-0000-000000000001','DEALER',
    'c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','desks FX and MM','2026-11-01',
    '{"add":[{"attribute":"DESK","value":"FX"},{"attribute":"DESK","value":"MM"}]}'),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000a3','GRANT','10000000-0000-0000-0000-000000000001','DEALER',
    'c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','joiner','2026-11-01',NULL),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000a4','REVOKE','10000000-0000-0000-0000-000000000001','DEALER',
    'c2000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','not yet approved','2026-12-01',NULL);
  SELECT count(*) INTO n FROM identity.role_grant_request
   WHERE request_id::text LIKE 'c1000000-0000-0000-0000-0000000000a%' AND requested_by = '10000000-0000-0000-0000-000000000002';
  IF n <> 7 THEN RAISE EXCEPTION 'T8g FAIL: requested_by not taken from the acting user (% of 7)', n; END IF;
  -- The checker is the acting user at approval: the requester cannot approve, nor a service identity.
  BEGIN
    UPDATE identity.role_grant_request SET status = 'APPROVED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000018',
           approved_by = '10000000-0000-0000-0000-000000000004'
     WHERE request_id = 'c1000000-0000-0000-0000-0000000000a1';
    RAISE EXCEPTION 'T8g FAIL: the requester approved their own request (typing another approver)';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000009', true);
  BEGIN
    UPDATE identity.role_grant_request SET status = 'APPROVED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000018'
     WHERE request_id = 'c1000000-0000-0000-0000-0000000000a1';
    RAISE EXCEPTION 'T8g FAIL: a service identity approved a request';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000004', true);
  UPDATE identity.role_grant_request SET status = 'APPROVED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000018'
   WHERE request_id IN ('c1000000-0000-0000-0000-0000000000a1','c1000000-0000-0000-0000-0000000000a2','c1000000-0000-0000-0000-0000000000a3',
                        'c1000000-0000-0000-0000-0000000000a5','c1000000-0000-0000-0000-0000000000a6','c1000000-0000-0000-0000-0000000000a7');
  SELECT count(*) INTO n FROM identity.role_grant_request
   WHERE status = 'APPROVED' AND approved_by = '10000000-0000-0000-0000-000000000004' AND request_id::text LIKE 'c1000000-0000-0000-0000-0000000000a%';
  IF n <> 6 THEN RAISE EXCEPTION 'T8g FAIL: approved_by not taken from the acting user (% of 6)', n; END IF;
  -- An approved request cannot be rewritten (round-2 Major 1).
  BEGIN
    UPDATE identity.role_grant_request SET requested_scope = '{"remove":[{"attribute":"DESK","value":"EQ"}]}'
     WHERE request_id = 'c1000000-0000-0000-0000-0000000000a2';
    RAISE EXCEPTION 'T8g FAIL: an approved request was edited';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE identity.role_grant_request SET request_type = 'REVOKE' WHERE request_id = 'c1000000-0000-0000-0000-0000000000a2';
    RAISE EXCEPTION 'T8g FAIL: an approved request changed type';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Refused: an END under a request that is not approved, of the wrong type, on another date, with no reason.
  BEGIN
    INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','END','2026-12-01','c1000000-0000-0000-0000-0000000000a4','leaver');
    RAISE EXCEPTION 'T8g FAIL: grant ended under a request that is not approved';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'REQUEST_NOT_APPROVED%' THEN RAISE EXCEPTION 'T8g FAIL: wrong refusal: %', e; END IF;
  END;
  BEGIN
    INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','END','2026-11-01','c1000000-0000-0000-0000-0000000000a3','leaver');
    RAISE EXCEPTION 'T8g FAIL: grant ended under a GRANT request';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'WRONG_REQUEST_TYPE%' THEN RAISE EXCEPTION 'T8g FAIL: wrong refusal: %', e; END IF;
  END;
  BEGIN
    INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','END','2020-01-01','c1000000-0000-0000-0000-0000000000a1','leaver');
    RAISE EXCEPTION 'T8g FAIL: grant ended on a date the request does not give';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'NOT_REQUESTED%' THEN RAISE EXCEPTION 'T8g FAIL: wrong refusal: %', e; END IF;
  END;
  BEGIN
    INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','END','2026-12-01','c1000000-0000-0000-0000-0000000000a1',' ');
    RAISE EXCEPTION 'T8g FAIL: grant ended with no reason';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- The application cannot close a version itself.
  BEGIN
    UPDATE identity.user_role_version SET superseded_at = now()
     WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1' AND superseded_at IS NULL;
    RAISE EXCEPTION 'T8g FAIL: the application set superseded_at directly';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Revoke from 1 Dec 2026 under the approved REVOKE request; the acting user ...04 is recorded,
  -- whatever closed_by the application sends.
  INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason, closed_by)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','END','2026-12-01',
          'c1000000-0000-0000-0000-0000000000a1','leaver','10000000-0000-0000-0000-000000000009');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1' AND superseded_at IS NULL
     AND (valid_period @> date '2026-12-15' OR valid_period @> date '2027-06-30');
  IF n <> 0 THEN RAISE EXCEPTION 'T8g FAIL: the grant is still current after its end date (% versions)', n; END IF;
  SELECT count(*), max(approved_by::text)::uuid INTO n, v_appr FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1' AND superseded_at IS NULL AND valid_period = '[2026-11-01,2026-12-01)';
  IF n <> 1 OR v_appr <> '10000000-0000-0000-0000-000000000003' THEN
    RAISE EXCEPTION 'T8g FAIL: November is not kept with its original approver (%, %)', n, v_appr;
  END IF;
  SELECT recorded_at, closed_by INTO v_close, v_by FROM identity.user_role_version_closure
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1';
  IF v_by <> '10000000-0000-0000-0000-000000000004' THEN RAISE EXCEPTION 'T8g FAIL: closed_by is % (not the acting user)', v_by; END IF;
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1' AND superseded_at = v_close;
  IF n <> 2 THEN RAISE EXCEPTION 'T8g FAIL: % versions closed at the END row''s instant (expected 2)', n; END IF;
  BEGIN
    UPDATE identity.user_role_version_closure SET reason = 'edited' WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1';
    RAISE EXCEPTION 'T8g FAIL: closure row edited';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T8g an END row (approved REVOKE request, its date, acting user recorded) revokes a grant, also a forward-dated version; requests are frozen and their maker / checker come from the identity context');
END $$;

-- Scope rows follow an approved request that lists them and run from its date; a REVOKE request
-- cannot touch scope; no active acting user, no closure.
DO $$
DECLARE n int; e text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  BEGIN
    INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','SCHEME','any-scheme','[2026-11-01,)');
    RAISE EXCEPTION 'T8h FAIL: scope row added with no request';
  EXCEPTION WHEN not_null_violation OR check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','SCHEME','any-scheme','[2026-11-01,)',
            'c1000000-0000-0000-0000-0000000000a4');
    RAISE EXCEPTION 'T8h FAIL: scope row added under a request that is not approved';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','SCHEME','any-scheme','[2026-11-01,)',
            'c1000000-0000-0000-0000-0000000000a2');
    RAISE EXCEPTION 'T8h FAIL: scope row added that the request does not list';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'NOT_REQUESTED%' THEN RAISE EXCEPTION 'T8h FAIL: wrong refusal: %', e; END IF;
  END;
  BEGIN
    INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','[2026-11-01,2026-11-02)',
            'c1000000-0000-0000-0000-0000000000a2');
    RAISE EXCEPTION 'T8h FAIL: scope row shorter than requested';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'NOT_REQUESTED%' THEN RAISE EXCEPTION 'T8h FAIL: wrong refusal: %', e; END IF;
  END;
  BEGIN
    INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','SCHEME','any-scheme','[2026-11-01,)',
            'c1000000-0000-0000-0000-0000000000a5');
    RAISE EXCEPTION 'T8h FAIL: scope row added under a REVOKE request';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'WRONG_REQUEST_TYPE%' THEN RAISE EXCEPTION 'T8h FAIL: wrong refusal: %', e; END IF;
  END;
  INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','[2026-11-01,)',
          'c1000000-0000-0000-0000-0000000000a2');
  BEGIN
    UPDATE identity.scope_attribute SET superseded_at = now()
     WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1' AND value = 'EQ' AND superseded_at IS NULL;
    RAISE EXCEPTION 'T8h FAIL: scope row retracted without a closure row';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Without an active acting user, nothing can be ended or retracted.
  PERFORM set_config('app.user_id','', true);
  BEGIN
    INSERT INTO master.external_identifier_closure (tenant_id, external_identifier_id, closure_kind, end_date, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c7000000-0000-0000-0000-000000000001','END','2027-01-01','f0000000-0000-0000-0000-000000000016','x');
    RAISE EXCEPTION 'T8h FAIL: a version was ended with no acting user';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id','99999999-0000-0000-0000-000000000099', true);
  BEGIN
    INSERT INTO master.external_identifier_closure (tenant_id, external_identifier_id, closure_kind, end_date, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c7000000-0000-0000-0000-000000000001','END','2027-01-01','f0000000-0000-0000-0000-000000000016','x');
    RAISE EXCEPTION 'T8h FAIL: a version was ended by an unknown user';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T8h scope rows need an approved GRANT/CHANGE_SCOPE request that lists them, from its date with no end; REVOKE cannot add scope; no active actor, no closure');
END $$;

-- A request is used once (APPLIED at commit); a REVOKE request cannot end scope; a retraction is a
-- RETRACT row under a CHANGE_SCOPE request that lists the removal; a request applied only in part
-- is refused at commit.
DO $$
DECLARE n int; e text; v text; v_rec timestamptz; v_by uuid;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  SELECT status INTO v FROM identity.role_grant_request WHERE request_id = 'c1000000-0000-0000-0000-0000000000a2';
  IF v <> 'APPLIED' THEN RAISE EXCEPTION 'T8h2 FAIL: used request is %', v; END IF;
  BEGIN
    INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','[2026-11-01,)',
            'c1000000-0000-0000-0000-0000000000a2');
    RAISE EXCEPTION 'T8h2 FAIL: an APPLIED request was used again';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'REQUEST_NOT_APPROVED%' THEN RAISE EXCEPTION 'T8h2 FAIL: wrong refusal: %', e; END IF;
  END;
  SELECT recorded_at INTO v_rec FROM identity.scope_attribute
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1' AND value = 'EQ' AND superseded_at IS NULL;
  BEGIN
    INSERT INTO identity.scope_attribute_closure (tenant_id, grant_id, attribute, value, closure_kind, end_date, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','END','2026-12-01',
            'c1000000-0000-0000-0000-0000000000a5','x');
    RAISE EXCEPTION 'T8h2 FAIL: a REVOKE request ended a scope row';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'WRONG_REQUEST_TYPE%' THEN RAISE EXCEPTION 'T8h2 FAIL: wrong refusal: %', e; END IF;
  END;
  BEGIN
    INSERT INTO identity.scope_attribute_closure (tenant_id, grant_id, attribute, value, closure_kind, target_valid_period, target_recorded_at, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','RETRACT','[2026-11-01,)', v_rec,
            'c1000000-0000-0000-0000-0000000000a7','typed in error');
    RAISE EXCEPTION 'T8h2 FAIL: a scope row was retracted under a request that does not list the removal';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- A RETRACT alone does not carry out a "remove": the request is refused at commit (round-3 Major 3).
  BEGIN
    INSERT INTO identity.scope_attribute_closure (tenant_id, grant_id, attribute, value, closure_kind, target_valid_period, target_recorded_at, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','RETRACT','[2026-11-01,)', v_rec,
            'c1000000-0000-0000-0000-0000000000a6','typed in error');
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T8h2 FAIL: a "remove" was applied as a RETRACT only';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'REQUEST_PARTLY_APPLIED%' THEN RAISE EXCEPTION 'T8h2 FAIL: wrong refusal: %', e; END IF;
  END;
  SET CONSTRAINTS ALL DEFERRED;
  INSERT INTO identity.scope_attribute_closure (tenant_id, grant_id, attribute, value, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','END','2026-11-01',
          'c1000000-0000-0000-0000-0000000000a6','typed in error');
  SELECT count(*) INTO n FROM identity.scope_attribute
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1' AND value = 'EQ' AND superseded_at IS NULL;
  SELECT closed_by INTO v_by FROM identity.scope_attribute_closure WHERE grant_id = 'c2000000-0000-0000-0000-0000000000a1';
  IF n <> 0 OR v_by <> '10000000-0000-0000-0000-000000000002' THEN RAISE EXCEPTION 'T8h2 FAIL: retraction (% current, by %)', n, v_by; END IF;
  BEGIN
    INSERT INTO identity.scope_attribute_closure (tenant_id, grant_id, attribute, value, closure_kind, target_valid_period, target_recorded_at, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','EQ','RETRACT','[2026-11-01,)', v_rec,
            'c1000000-0000-0000-0000-0000000000a6','again');
    RAISE EXCEPTION 'T8h2 FAIL: a closed row was retracted twice';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- a7 asks for desks FX and MM; applying only FX is refused when the deferred check runs.
  BEGIN
    INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','DESK','FX','[2026-11-01,)',
            'c1000000-0000-0000-0000-0000000000a7');
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T8h2 FAIL: a request applied in part was accepted';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'REQUEST_PARTLY_APPLIED%' THEN RAISE EXCEPTION 'T8h2 FAIL: wrong refusal: %', e; END IF;
  END;
  SET CONSTRAINTS ALL DEFERRED;
  PERFORM pg_temp.ok('T8h2 requests are used once and in full; REVOKE cannot end scope; a "remove" is an END row on the request''s date (a RETRACT alone is refused at commit), recording who and why');
END $$;

-- T8m (round-3 Blockers 1-2, Major 3, Minor 4 of reviews/STEP-16ab_round3.md).  A grant and a scope
-- row made through requests can later be ended from a date after their start, and corrected by a new
-- version: the database's own continuation rows keep the old request_id but are not a new use of it.
-- Each step below is its own transaction, so the commit check runs at each COMMIT.
-- Setup: GRANT request for user ...03 / DEALER with scope SCHEME=S1, from 1 Jan 2027.
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO identity.user_role (tenant_id, grant_id, user_id, role_code)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000c1','10000000-0000-0000-0000-000000000003','DEALER');
  INSERT INTO identity.role_grant_request (tenant_id, request_id, request_type, user_id, role_code, grant_id, reason, effective_from, requested_scope) VALUES
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000c1','GRANT','10000000-0000-0000-0000-000000000003','DEALER',
    'c2000000-0000-0000-0000-0000000000c1','joiner','2027-01-01','{"add":[{"attribute":"SCHEME","value":"S1"}]}'),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000c2','CHANGE_SCOPE','10000000-0000-0000-0000-000000000003','DEALER',
    'c2000000-0000-0000-0000-0000000000c1','scheme S1 no longer covered','2027-03-01','{"remove":[{"attribute":"SCHEME","value":"S1"}]}'),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000c3','REVOKE','10000000-0000-0000-0000-000000000003','DEALER',
    'c2000000-0000-0000-0000-0000000000c1','leaver','2027-08-01',NULL),
   ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000c4','REVOKE','10000000-0000-0000-0000-000000000003','DEALER',
    'c2000000-0000-0000-0000-0000000000c1','retract-only attempt','2027-06-01',NULL);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000004', true);
  UPDATE identity.role_grant_request SET status = 'APPROVED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000040'
   WHERE request_id IN ('c1000000-0000-0000-0000-0000000000c1','c1000000-0000-0000-0000-0000000000c2',
                        'c1000000-0000-0000-0000-0000000000c3','c1000000-0000-0000-0000-0000000000c4');
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by, request_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000c1','[2027-01-01,)',
    '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004','c1000000-0000-0000-0000-0000000000c1');
  INSERT INTO identity.scope_attribute (tenant_id, grant_id, attribute, value, valid_period, request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000c1','SCHEME','S1','[2027-01-01,)',
          'c1000000-0000-0000-0000-0000000000c1');
END $$;

DO $$
DECLARE n int; e text; v text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  SELECT status INTO v FROM identity.role_grant_request WHERE request_id = 'c1000000-0000-0000-0000-0000000000c1';
  IF v <> 'APPLIED' THEN RAISE EXCEPTION 'T8m FAIL: GRANT request is % after commit', v; END IF;
  -- Blocker 1(c): a plain signed correcting version from 1 Jun 2027 (no request) over the request-made version.
  INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by) VALUES
   ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000c1','[2027-06-01,)',
    '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000c1' AND superseded_at IS NULL
     AND valid_period = '[2027-01-01,2027-06-01)' AND request_id = 'c1000000-0000-0000-0000-0000000000c1';
  IF n <> 1 THEN RAISE EXCEPTION 'T8m FAIL: continuation of the request-made version not kept (%)', n; END IF;
  SELECT count(*) INTO n FROM identity.request_use WHERE request_id = 'c1000000-0000-0000-0000-0000000000c1' AND xact_id = pg_current_xact_id();
  IF n <> 0 THEN RAISE EXCEPTION 'T8m FAIL: a continuation was recorded as a new use of its request'; END IF;
  -- Minor 4: nothing the session sets can mark a request as used or applied.
  BEGIN
    INSERT INTO identity.request_use (tenant_id, request_id, xact_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000c3', pg_current_xact_id());
    RAISE EXCEPTION 'T8m FAIL: the application recorded a request use itself';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Major 3(b): APPROVED -> APPLIED is never a plain UPDATE.
  BEGIN
    UPDATE identity.role_grant_request SET status = 'APPLIED' WHERE request_id = 'c1000000-0000-0000-0000-0000000000c3';
    RAISE EXCEPTION 'T8m FAIL: a request was set to APPLIED by a plain UPDATE';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'IMMUTABLE_RECORD%' THEN RAISE EXCEPTION 'T8m FAIL: wrong refusal: %', e; END IF;
  END;
  SET CONSTRAINTS ALL DEFERRED;
END $$;

-- Blocker 1(b): remove SCHEME=S1 from 1 Mar 2027 (after the row's start) under CHANGE_SCOPE c2.
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);   -- not the grant owner (owner question Q89)
  INSERT INTO identity.scope_attribute_closure (tenant_id, grant_id, attribute, value, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000c1','SCHEME','S1','END','2027-03-01',
          'c1000000-0000-0000-0000-0000000000c2','scheme S1 no longer covered');
END $$;

-- Major 3(a): a REVOKE carried out as a RETRACT only (of the later version) is refused at commit.
DO $$
DECLARE e text; v_rec timestamptz;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  SELECT recorded_at INTO v_rec FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000c1' AND superseded_at IS NULL AND valid_period = '[2027-06-01,)';
  BEGIN
    INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, target_valid_period, target_recorded_at, request_id, reason)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000c1','RETRACT','[2027-06-01,)', v_rec,
            'c1000000-0000-0000-0000-0000000000c4','retract instead of end');
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T8m FAIL: a REVOKE was applied as a RETRACT only';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'REQUEST_PARTLY_APPLIED%' THEN RAISE EXCEPTION 'T8m FAIL: wrong refusal: %', e; END IF;
  END;
  SET CONSTRAINTS ALL DEFERRED;
END $$;

-- Blocker 1(a): revoke the request-made grant from 1 Aug 2027 (after its start) under REVOKE c3.
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000c1','END','2027-08-01',
          'c1000000-0000-0000-0000-0000000000c3','leaver');
END $$;

DO $$
DECLARE n int; e text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  SELECT count(*) INTO n FROM identity.role_grant_request
   WHERE request_id IN ('c1000000-0000-0000-0000-0000000000c2','c1000000-0000-0000-0000-0000000000c3') AND status = 'APPLIED';
  IF n <> 2 THEN RAISE EXCEPTION 'T8m FAIL: % of 2 later requests APPLIED', n; END IF;
  SELECT count(*) INTO n FROM identity.role_grant_request WHERE request_id = 'c1000000-0000-0000-0000-0000000000c4' AND status = 'APPROVED';
  IF n <> 1 THEN RAISE EXCEPTION 'T8m FAIL: the refused retract-only REVOKE did not stay APPROVED'; END IF;
  SELECT count(*) INTO n FROM identity.scope_attribute
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000c1' AND superseded_at IS NULL;
  IF n <> 1 OR NOT EXISTS (SELECT 1 FROM identity.scope_attribute WHERE grant_id = 'c2000000-0000-0000-0000-0000000000c1'
                             AND superseded_at IS NULL AND valid_period = '[2027-01-01,2027-03-01)') THEN
    RAISE EXCEPTION 'T8m FAIL: SCHEME=S1 is not limited to Jan-Feb 2027';
  END IF;
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000c1' AND superseded_at IS NULL AND upper(valid_period) > date '2027-08-01';
  SELECT n + count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000c1' AND superseded_at IS NULL AND upper_inf(valid_period);
  IF n <> 0 THEN RAISE EXCEPTION 'T8m FAIL: the grant is still current after 1 Aug 2027'; END IF;
  -- Blocker 2: a request that names someone else's grant is refused at insert.
  BEGIN
    INSERT INTO identity.role_grant_request (tenant_id, request_type, user_id, role_code, grant_id, reason, effective_from, requested_scope)
    VALUES ('00000000-0000-0000-0000-00000000000a','CHANGE_SCOPE','10000000-0000-0000-0000-000000000001','FUND_ACCOUNTANT',
            'c2000000-0000-0000-0000-0000000000c1','mislabelled','2027-02-01','{"remove":[{"attribute":"SCHEME","value":"S1"}]}');
    RAISE EXCEPTION 'T8m FAIL: a request naming another user''s grant was accepted';
  EXCEPTION WHEN check_violation OR foreign_key_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'WRONG_GRANT%' THEN RAISE EXCEPTION 'T8m FAIL: wrong refusal: %', e; END IF;
  END;
  -- ... so the grant owner (...03) can never be the checker of a change to their own grant.
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000003', true);
  BEGIN
    INSERT INTO identity.role_grant_request (tenant_id, request_type, user_id, role_code, grant_id, reason, effective_from)
    VALUES ('00000000-0000-0000-0000-00000000000a','REVOKE','10000000-0000-0000-0000-000000000003','DEALER',
            'c2000000-0000-0000-0000-0000000000c1','self','2027-09-01');
    RAISE EXCEPTION 'T8m FAIL: the grant owner raised a request on their own grant';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.ok('T8m request-made grants and scope rows can be ended after their start and corrected (continuations are not new uses); a request must name its grant''s own user and role; APPLIED only by the commit check after an END on the request''s date');
END $$;

-- Retire a code from a date and give it to another entity; remove a right from a role from a date,
-- including a later version of that right.
RESET ROLE;
INSERT INTO identity.permission (permission_code, description) VALUES ('oms.order.release','Release orders');
SET ROLE amc_app;
DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO master.external_identifier (tenant_id, external_identifier_id, valid_period, entity_type, entity_id, scheme_code, value, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c7000000-0000-0000-0000-000000000001','[2026-01-01,)','SECURITY',
          '40000000-0000-0000-0000-000000000001','NSE_SYMBOL','ALPHAX','f0000000-0000-0000-0000-000000000016');
  INSERT INTO master.external_identifier_closure (tenant_id, external_identifier_id, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c7000000-0000-0000-0000-000000000001','END','2027-01-01','f0000000-0000-0000-0000-000000000016','symbol retired');
  INSERT INTO master.external_identifier (tenant_id, valid_period, entity_type, entity_id, scheme_code, value, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','[2027-01-01,)','SECURITY','40000000-0000-0000-0000-000000000002','NSE_SYMBOL','ALPHAX',
          'f0000000-0000-0000-0000-000000000016');
  INSERT INTO identity.role_permission (tenant_id, role_code, permission_code, valid_period, approval_request_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','DEALER','oms.order.release','[2026-11-01,)','f0000000-0000-0000-0000-000000000019');
  INSERT INTO identity.role_permission (tenant_id, role_code, permission_code, valid_period, approval_request_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','DEALER','oms.order.release','[2027-01-01,)','f0000000-0000-0000-0000-000000000019');
  INSERT INTO identity.role_permission_closure (tenant_id, role_code, permission_code, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','DEALER','oms.order.release','END','2026-12-01','f0000000-0000-0000-0000-000000000020','right removed');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM identity.role_permission
   WHERE role_code = 'DEALER' AND superseded_at IS NULL AND (valid_period @> date '2026-12-15' OR valid_period @> date '2027-06-30');
  IF n <> 0 THEN RAISE EXCEPTION 'T8i FAIL: right still on the role after its end date'; END IF;
  SELECT count(*) INTO n FROM identity.role_permission
   WHERE role_code = 'DEALER' AND superseded_at IS NULL AND valid_period = '[2026-11-01,2026-12-01)';
  IF n <> 1 THEN RAISE EXCEPTION 'T8i FAIL: right lost before its end date'; END IF;
  PERFORM pg_temp.ok('T8i a retired code can be given to another entity; a right is removed from a date, also its later version');
END $$;

-- BT-5: a continuation is not re-checked against today's signing rules (the approver has left);
-- revoking such a grant works and keeps the old approver on the kept period; a row that only
-- looks like a continuation (same content, forged recorded_at) is checked like any new version.
RESET ROLE;
INSERT INTO identity.user_role (tenant_id, grant_id, user_id, role_code)
VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000b1','10000000-0000-0000-0000-000000000001','DEALER');
INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000b1','[2026-11-01,)',
        '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003');
UPDATE identity.app_user SET status = 'DISABLED' WHERE user_id = '10000000-0000-0000-0000-000000000003';
SET ROLE amc_app;
DO $$
DECLARE n int; v_rec timestamptz; v_sup timestamptz; v_close timestamptz; e text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000004', true);
  -- c2...b1 was approved by ...03, now DISABLED.  A forward-dated change signed by two active humans:
  INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000b1','[2027-01-01,)',
          '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000b1' AND superseded_at IS NULL;
  IF n <> 2 THEN RAISE EXCEPTION 'T8j FAIL: % current versions after a forward-dated change', n; END IF;
  -- One instant per correction: the closed row's superseded_at = the new and continued rows' recorded_at.
  SELECT recorded_at INTO v_rec FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000b1' AND valid_period = '[2027-01-01,)';
  SELECT max(superseded_at) INTO v_sup FROM identity.user_role_version WHERE grant_id = 'c2000000-0000-0000-0000-0000000000b1';
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000b1' AND superseded_at IS NULL AND recorded_at = v_rec;
  IF v_sup <> v_rec OR n <> 2 THEN RAISE EXCEPTION 'T8j FAIL: correction not recorded at one instant'; END IF;
  -- A new version still needs active approvers.
  BEGIN
    INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000b1','[2028-01-01,)',
            '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003');
    RAISE EXCEPTION 'T8j FAIL: a disabled user approved a new version';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- Revoke from 1 Dec 2026 although the original approver is disabled (round-3 Major 2).
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO identity.role_grant_request (tenant_id, request_id, request_type, user_id, role_code, grant_id, requested_by, reason, effective_from)
  VALUES ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000b1','REVOKE','10000000-0000-0000-0000-000000000001','DEALER',
          'c2000000-0000-0000-0000-0000000000b1','10000000-0000-0000-0000-000000000002','role no longer needed','2026-12-01');
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000004', true);
  UPDATE identity.role_grant_request SET status = 'APPROVED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000021'
   WHERE request_id = 'c1000000-0000-0000-0000-0000000000b1';
  INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000b1','END','2026-12-01',
          'c1000000-0000-0000-0000-0000000000b1','role no longer needed');
  SET CONSTRAINTS ALL IMMEDIATE;
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000b1' AND superseded_at IS NULL;
  IF n <> 1 THEN RAISE EXCEPTION 'T8j FAIL: % current versions after the revocation (expected 1)', n; END IF;
  SELECT count(*) INTO n FROM identity.user_role_version
   WHERE grant_id = 'c2000000-0000-0000-0000-0000000000b1' AND superseded_at IS NULL
     AND valid_period = '[2026-11-01,2026-12-01)' AND approved_by = '10000000-0000-0000-0000-000000000003';
  IF n <> 1 THEN RAISE EXCEPTION 'T8j FAIL: November no longer shows its original approver'; END IF;
  -- A forged "continuation": same content as a closed row, recorded_at set to its closing instant.
  SELECT recorded_at INTO v_close FROM identity.user_role_version_closure WHERE grant_id = 'c2000000-0000-0000-0000-0000000000b1';
  BEGIN
    INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, recorded_at, granted_by, approved_by)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000b1','[2026-12-01,2027-01-01)', v_close,
            '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003');
    RAISE EXCEPTION 'T8j FAIL: a forged continuation brought the revoked grant back';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'SOD_VIOLATION%' THEN RAISE EXCEPTION 'T8j FAIL: wrong refusal: %', e; END IF;
  END;
  PERFORM pg_temp.ok('T8j continuations keep old signatures (recognised from data); a grant whose approver left can be revoked; a forged continuation is checked like a new version');
END $$;

-- Grant versions that name a request follow an APPROVED GRANT request for that grant, from its date.
DO $$
DECLARE e text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000b1','[2027-03-01,)',
            '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004','c1000000-0000-0000-0000-0000000000b1');
    RAISE EXCEPTION 'T8k FAIL: a grant version cited a REVOKE request';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by, request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000a1','[2027-03-01,)',
            '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004','c1000000-0000-0000-0000-0000000000a3');
    RAISE EXCEPTION 'T8k FAIL: a grant version started on another date than its GRANT request';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'NOT_REQUESTED%' THEN RAISE EXCEPTION 'T8k FAIL: wrong refusal: %', e; END IF;
  END;
  -- Versions are written only under READ COMMITTED (the concurrency rules of BT-3 rely on it).
  PERFORM pg_temp.ok('T8k a grant version names only a matching GRANT request and starts on its date');
END $$;
BEGIN ISOLATION LEVEL REPEATABLE READ;
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.benchmark_version (tenant_id, benchmark_id, valid_period, name, provider, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000001','[2028-01-01,)','X','Y','f0000000-0000-0000-0000-000000000029');
  RAISE EXCEPTION 'T8l FAIL: a version was written under REPEATABLE READ';
EXCEPTION WHEN feature_not_supported THEN
  PERFORM pg_temp.ok('T8l versions and closure rows are refused outside READ COMMITTED');
END $$;
ROLLBACK;

-- Two sessions (dblink): a version and an END of the same key never interleave, and a version
-- written by a transaction that began before an END committed is refused.
RESET ROLE;
CREATE EXTENSION IF NOT EXISTS dblink;
DO $$
DECLARE v_conn text; e text; v_ok boolean := false;
BEGIN
  v_conn := format('host=%s port=%s dbname=%s user=postgres',
                   split_part(current_setting('unix_socket_directories'), ',', 1), current_setting('port'), current_database());
  BEGIN
    PERFORM dblink_connect('t16', v_conn);
    v_ok := true;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SKIP  T16 two-session checks: no second connection (%)', SQLERRM;
  END;
  IF v_ok THEN
    PERFORM dblink_exec('t16', $q$SET ROLE amc_app$q$);
    PERFORM dblink_exec('t16', $q$SET app.tenant_id = '00000000-0000-0000-0000-00000000000a'$q$);
  END IF;
END $$;
-- The test needs the grant and an approved REVOKE request; set up as the migration owner.
INSERT INTO identity.user_role (tenant_id, grant_id, user_id, role_code)
VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000e1','10000000-0000-0000-0000-000000000001','DEALER');
INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000e1','[2026-11-01,)',
        '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004');
SET ROLE amc_app;
DO $$
DECLARE e text;
BEGIN
  IF NOT ('t16' = ANY (coalesce(dblink_get_connections(), '{}'))) THEN RETURN; END IF;
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', false);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', false);
  INSERT INTO identity.role_grant_request (tenant_id, request_id, request_type, user_id, role_code, grant_id, requested_by, reason, effective_from)
  VALUES ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-0000000000e1','REVOKE','10000000-0000-0000-0000-000000000001','DEALER',
          'c2000000-0000-0000-0000-0000000000e1','10000000-0000-0000-0000-000000000002','leaver','2026-12-01');
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000004', false);
  UPDATE identity.role_grant_request SET status = 'APPROVED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000030'
   WHERE request_id = 'c1000000-0000-0000-0000-0000000000e1';
  COMMIT;
  -- (a) This session ends the grant from 1 Dec and keeps its transaction open.
  INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000e1','END','2026-12-01',
          'c1000000-0000-0000-0000-0000000000e1','leaver');
  -- (b) Session 2 writes a forward-dated version meanwhile: the key is busy.
  PERFORM dblink_exec('t16', 'BEGIN');
  BEGIN
    PERFORM dblink_exec('t16', $q$INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
      VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000e1','[2027-02-01,)',
              '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004')$q$);
    RAISE EXCEPTION 'T16 FAIL: a version was written while the key was being ended';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e LIKE 'T16 FAIL%' OR e NOT LIKE '%KEY_BUSY%' THEN RAISE EXCEPTION 'T16 FAIL: wrong outcome: %', e; END IF;
  END;
  PERFORM dblink_exec('t16', 'ROLLBACK');
  ROLLBACK;                                      -- undo this END; the next one is made after session 2 begins
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', false);
  PERFORM dblink_exec('t16', 'BEGIN');
  PERFORM dblink_exec('t16', $q$SET LOCAL app.noop = '1'$q$);
  PERFORM pg_sleep(0.01);
  INSERT INTO identity.user_role_version_closure (tenant_id, grant_id, closure_kind, end_date, request_id, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000e1','END','2026-12-01',
          'c1000000-0000-0000-0000-0000000000e1','leaver');
  COMMIT;                                        -- the END is made and committed after session 2's transaction began
  -- (c) Session 2's version is now stale: refused.
  BEGIN
    PERFORM dblink_exec('t16', $q$INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
      VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-0000000000e1','[2027-02-01,)',
              '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004')$q$);
    RAISE EXCEPTION 'T16 FAIL: a stale version undid the revocation';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e LIKE 'T16 FAIL%' OR e NOT LIKE '%KEY_CLOSED_MEANWHILE%' THEN RAISE EXCEPTION 'T16 FAIL: wrong outcome: %', e; END IF;
  END;
  PERFORM dblink_exec('t16', 'ROLLBACK');
  PERFORM dblink_disconnect('t16');
  IF EXISTS (SELECT 1 FROM identity.user_role_version WHERE grant_id = 'c2000000-0000-0000-0000-0000000000e1'
              AND superseded_at IS NULL AND valid_period @> date '2027-06-30') THEN
    RAISE EXCEPTION 'T16 FAIL: the revoked grant is current again';
  END IF;
  PERFORM set_config('app.user_id','', false);
  PERFORM pg_temp.ok('T16 two sessions: a version cannot be written while its key is being ended, nor after an END that committed during its transaction');
END $$;

-- =====================================================================
-- T9  Provenance (M9, §3.3)
-- =====================================================================
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO master.security_version (tenant_id, security_id, valid_period, short_name, source_system, source_record_ref)
    VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000001','[2027-01-01,)','X','NSE','rec-1');
    RAISE EXCEPTION 'T9a FAIL: loaded row without a load run accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO master.security_version (tenant_id, security_id, valid_period, short_name)
    VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000001','[2027-01-01,)','X');
    RAISE EXCEPTION 'T9a FAIL: manual row without an approval reference accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO master.security_version (tenant_id, security_id, valid_period, short_name, load_run_id,
                                       source_system, source_record_ref, source_as_of, licence_tag)
  VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000001','[2027-01-01,)','ALPHA CORP',
          'b1000000-0000-0000-0000-000000000001','NSE','rec-1','2026-11-20 18:00+05:30','NSE-EOD');
  PERFORM pg_temp.ok('T9a a loaded row needs a load run and record reference; a typed row needs an approval reference');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    UPDATE master.load_run SET business_date = '2026-11-21' WHERE load_run_id = 'b1000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T9b FAIL: business date of a running load changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE master.load_run SET status = 'COMPLETED', finished_at = now(), rows_loaded = 1, rows_quarantined = 0
   WHERE load_run_id = 'b1000000-0000-0000-0000-000000000001';
  BEGIN
    UPDATE master.load_run SET rows_loaded = 99 WHERE load_run_id = 'b1000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T9b FAIL: finished load run edited';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO master.benchmark_level (tenant_id, benchmark_id, level_date, level_type, level_value, load_run_id, source_system, source_record_ref)
    VALUES ('00000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000001','2026-11-20','TOTAL_RETURN',34567.12345678,
            'b1000000-0000-0000-0000-000000000001','NSE_INDICES','lvl-1');
    RAISE EXCEPTION 'T9b FAIL: row added to a completed load run';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.ok('T9b a load run''s identity and business date never change; it is frozen when finished and takes no more rows');
END $$;

-- =====================================================================
-- T10  Identifier crosswalk (M10, §3.4)
-- =====================================================================
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.external_identifier (tenant_id, valid_period, entity_type, entity_id, scheme_code, value, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','[2026-01-01,)','SECURITY','40000000-0000-0000-0000-000000000001','NSE_SYMBOL','ALPHA',
          'f0000000-0000-0000-0000-000000000005');
  BEGIN
    INSERT INTO master.external_identifier (tenant_id, valid_period, entity_type, entity_id, scheme_code, value, approval_request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','[2026-06-01,)','SECURITY','40000000-0000-0000-0000-000000000002','NSE_SYMBOL','ALPHA',
            'f0000000-0000-0000-0000-000000000005');
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T10a FAIL: one code mapped to two securities on the same date';
  EXCEPTION WHEN exclusion_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO master.external_identifier (tenant_id, valid_period, entity_type, entity_id, scheme_code, value, approval_request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','[2026-01-01,)','SECURITY','40000000-0000-0000-0000-0000000000ff','NSE_SYMBOL','GHOST',
            'f0000000-0000-0000-0000-000000000005');
    RAISE EXCEPTION 'T10a FAIL: code for an unknown security accepted';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO master.external_identifier (tenant_id, valid_period, entity_type, entity_id, scheme_code, value, approval_request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','[2026-01-01,)','SECURITY','40000000-0000-0000-0000-000000000002','ISIN','NOT-AN-ISIN',
            'f0000000-0000-0000-0000-000000000005');
    RAISE EXCEPTION 'T10a FAIL: badly formed ISIN accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.ok('T10a one outside code points to one entity per date; unknown entities and bad formats are refused');
END $$;

-- =====================================================================
-- T11  State machines as data (M14, DM-5)
-- =====================================================================
DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO identity.role (tenant_id, role_code, description)
  VALUES ('00000000-0000-0000-0000-00000000000a','FUND_ACCOUNTANT','Fund accountant');
  BEGIN
    INSERT INTO identity.role_grant_request (tenant_id, request_type, user_id, role_code, requested_by, reason, effective_from, status, sod_result)
    VALUES ('00000000-0000-0000-0000-00000000000a','GRANT','10000000-0000-0000-0000-000000000001','FUND_ACCOUNTANT',
            '10000000-0000-0000-0000-000000000002','x','2026-12-01','APPROVED','PASS');
    RAISE EXCEPTION 'T11a FAIL: a request was born APPROVED';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity.role_grant_request (tenant_id, request_type, user_id, role_code, requested_by, reason, effective_from, status)
    VALUES ('00000000-0000-0000-0000-00000000000a','GRANT','10000000-0000-0000-0000-000000000001','FUND_ACCOUNTANT',
            '10000000-0000-0000-0000-000000000002','x','2026-12-01','MADE_UP_STATE');
    RAISE EXCEPTION 'T11a FAIL: a state not in the transition table was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.ok('T11a a row is born only in its first state; states not in the transition table are refused');
END $$;

DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000002', true);
  INSERT INTO identity.role_grant_request (tenant_id, request_id, request_type, user_id, role_code, requested_by, reason, effective_from)
  VALUES ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-000000000001','GRANT','10000000-0000-0000-0000-000000000001',
          'FUND_ACCOUNTANT','10000000-0000-0000-0000-000000000002','joiner','2026-12-01');
  PERFORM set_config('app.user_id','10000000-0000-0000-0000-000000000004', true);
  BEGIN
    UPDATE identity.role_grant_request SET status = 'APPLIED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000006'
     WHERE request_id = 'c1000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T11b FAIL: SUBMITTED -> APPLIED skipped approval';
  EXCEPTION WHEN check_violation OR insufficient_privilege THEN NULL;
  END;
  UPDATE identity.role_grant_request SET status = 'APPROVED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000006'
   WHERE request_id = 'c1000000-0000-0000-0000-000000000001';
  SELECT count(*) INTO n FROM identity.role_grant_request_history WHERE request_id = 'c1000000-0000-0000-0000-000000000001';
  IF n <> 2 THEN RAISE EXCEPTION 'T11b FAIL: % history rows (expected 2)', n; END IF;
  BEGIN
    UPDATE identity.role_grant_request_history SET to_state = 'X' WHERE request_id = 'c1000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T11b FAIL: history edited';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T11b illegal moves are refused; each move writes one insert-only history row');
END $$;

DO $$
BEGIN
  BEGIN
    INSERT INTO identity.role_grant_request_transition VALUES ('SUBMITTED','APPLIED','STATE_CHANGE');
    RAISE EXCEPTION 'T11c FAIL: the application changed a transition table';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T11c transition tables are read-only for the application (M3)');
  END;
END $$;

DO $$
DECLARE e text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO identity.role_grant_request_history (tenant_id, request_id, from_state, to_state, cause, changed_by)
    VALUES ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-000000000001','APPROVED','APPLIED','FORGED',
            '10000000-0000-0000-0000-000000000003');
    RAISE EXCEPTION 'T11d FAIL: forged history row accepted';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'IMMUTABLE_RECORD%' THEN RAISE EXCEPTION 'T11d FAIL: wrong refusal: %', e; END IF;
  END;
  PERFORM pg_temp.ok('T11d history rows are written only by the state-machine trigger');
END $$;

-- Approved versions (M11) with their lifecycle (source precedence rules).
DO $$
DECLARE e text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO master.source_precedence_rule (tenant_id, entity_type, field_name, version_no, provider_order, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','SECURITY','short_name',1,ARRAY['NSE','BSE'],'[2026-12-01,)','10000000-0000-0000-0000-000000000001');
  UPDATE master.source_precedence_rule SET status = 'PENDING_APPROVAL' WHERE field_name = 'short_name';
  UPDATE master.source_precedence_rule SET status = 'REJECTED' WHERE field_name = 'short_name';
  BEGIN
    UPDATE master.source_precedence_rule SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000014'
     WHERE field_name = 'short_name';
    RAISE EXCEPTION 'T11e FAIL: REJECTED -> APPROVED accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO master.source_precedence_rule (tenant_id, entity_type, field_name, version_no, provider_order, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','SECURITY','short_name',2,ARRAY['NSE','BSE'],'[2026-12-01,)','10000000-0000-0000-0000-000000000001');
  UPDATE master.source_precedence_rule SET status = 'PENDING_APPROVAL' WHERE field_name = 'short_name' AND version_no = 2;
  UPDATE master.source_precedence_rule SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000014'
   WHERE field_name = 'short_name' AND version_no = 2;
  BEGIN
    UPDATE master.source_precedence_rule SET provider_order = ARRAY['BSE'] WHERE field_name = 'short_name' AND version_no = 2;
    RAISE EXCEPTION 'T11e FAIL: approved version edited';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'IMMUTABLE_RECORD%' THEN RAISE EXCEPTION 'T11e FAIL: wrong refusal: %', e; END IF;
  END;
  PERFORM pg_temp.ok('T11e approved versions follow DRAFT -> PENDING_APPROVAL -> APPROVED -> SUPERSEDED and are frozen once approved');
END $$;

-- =====================================================================
-- T12  Role grants (SOD-05, no self-grant, no self-certification)
-- =====================================================================
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO identity.user_role (tenant_id, grant_id, user_id, role_code)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','FUND_ACCOUNTANT');
  BEGIN
    INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-000000000001','[2026-11-01,)',
            '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'T12a FAIL: granter approved own grant';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-000000000001','[2026-11-01,)',
            '10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'T12a FAIL: user granted own role';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
  VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-000000000001','[2026-11-01,)',
          '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004');
  INSERT INTO identity.recertification_campaign (tenant_id, campaign_id, title, due_date, created_by)
  VALUES ('00000000-0000-0000-0000-00000000000a','c3000000-0000-0000-0000-000000000001','Q4 review','2026-12-31','10000000-0000-0000-0000-000000000002');
  BEGIN
    INSERT INTO identity.recertification_item (tenant_id, campaign_id, grant_id, reviewer_user_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','c3000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001');
    RAISE EXCEPTION 'T12a FAIL: user certifies own access';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO identity.user_role_version (tenant_id, grant_id, valid_period, granted_by, approved_by)
    VALUES ('00000000-0000-0000-0000-00000000000a','c2000000-0000-0000-0000-000000000001','[2027-01-01,)',
            '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000009');
    RAISE EXCEPTION 'T12a FAIL: an AI service identity approved a role grant';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T12a two active humans grant a role, neither the receiver nor a service identity; nobody certifies their own access');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO identity.session (tenant_id, session_id, user_id, idp_session_ref)
  VALUES ('00000000-0000-0000-0000-00000000000a','c5000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','idp-s-1');
  UPDATE identity.session SET ended_at = now(), end_reason = 'SIGN_OUT' WHERE session_id = 'c5000000-0000-0000-0000-000000000001';
  BEGIN
    UPDATE identity.session SET end_reason = 'TIMEOUT' WHERE session_id = 'c5000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T12b FAIL: ended session changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE identity.session SET user_id = '10000000-0000-0000-0000-000000000002' WHERE session_id = 'c5000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T12b FAIL: session owner changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T12b a session may only be ended, once');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.organisation_unit (tenant_id, org_unit_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000001'),
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000002');
  INSERT INTO platform.organisation_unit_version (tenant_id, org_unit_id, valid_period, unit_code, unit_name, unit_type, parent_org_unit_id, approval_request_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000001','[2026-01-01,)','U1','Unit 1','DEPARTMENT','c6000000-0000-0000-0000-000000000002','f0000000-0000-0000-0000-000000000015'),
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000002','[2026-01-01,)','U2','Unit 2','DEPARTMENT','c6000000-0000-0000-0000-000000000001','f0000000-0000-0000-0000-000000000015');
  BEGIN
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T12c FAIL: a cycle in the unit tree was accepted';
  EXCEPTION WHEN check_violation THEN
    PERFORM pg_temp.ok('T12c the organisation-unit tree cannot contain a cycle');
  END;
  RAISE EXCEPTION 'rollback this block' USING ERRCODE = 'P0099';
EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.organisation_unit (tenant_id, org_unit_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000011'),
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000012');
  -- U12 under U11 in 2026; U11 under U12 from 2027: a restructure, not a cycle.
  INSERT INTO platform.organisation_unit_version (tenant_id, org_unit_id, valid_period, unit_code, unit_name, unit_type, parent_org_unit_id, approval_request_id) VALUES
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000012','[2026-01-01,2027-01-01)','U12','Unit 12','DEPARTMENT','c6000000-0000-0000-0000-000000000011','f0000000-0000-0000-0000-000000000015'),
   ('00000000-0000-0000-0000-00000000000a','c6000000-0000-0000-0000-000000000011','[2027-01-01,)','U11','Unit 11','DEPARTMENT','c6000000-0000-0000-0000-000000000012','f0000000-0000-0000-0000-000000000015');
  SET CONSTRAINTS ALL IMMEDIATE;
  PERFORM pg_temp.ok('T12d a restructure across dates is not mistaken for a cycle');
END $$;

-- =====================================================================
-- T13  Configuration versions (EA-008 §5, M11).  Dates are relative to today, so the test does
--      not depend on the day it runs; "today" is the India business date (platform.today_ist).
-- =====================================================================
DO $$
DECLARE v_start date := platform.today_ist() + 7; v_hash text; v_on date;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.config_version (tenant_id, config_version_id, release, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001','REL-TEST', daterange(v_start, NULL),
          '10000000-0000-0000-0000-000000000001');
  INSERT INTO platform.config_value (tenant_id, config_version_id, item_key, scope_type, scope_id, value)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001','d11.price.tolerance_day_move','TENANT',
          '00000000-0000-0000-0000-00000000000a','5'::jsonb);
  -- The validator hashes what it checked; a value added afterwards makes the move fail.
  v_hash := platform.config_values_hash('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001');
  INSERT INTO platform.config_value (tenant_id, config_version_id, item_key, scope_type, scope_id, value)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001','d11.price.stale_days','TENANT',
          '00000000-0000-0000-0000-00000000000a','999'::jsonb);
  BEGIN
    UPDATE platform.config_version SET status = 'VALIDATED', values_hash = v_hash
     WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: a version was validated with a value the validator never saw';
  EXCEPTION WHEN serialization_failure THEN NULL;
  END;
  v_hash := platform.config_values_hash('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001');
  UPDATE platform.config_version SET status = 'VALIDATED', values_hash = v_hash WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  BEGIN
    INSERT INTO platform.config_value (tenant_id, config_version_id, item_key, scope_type, scope_id, value)
    VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001','d11.price.other','TENANT',
            '00000000-0000-0000-0000-00000000000a','1'::jsonb);
    RAISE EXCEPTION 'T13a FAIL: value added after validation';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE platform.config_version SET status = 'TESTED'    WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  UPDATE platform.config_version SET status = 'SUBMITTED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  BEGIN
    UPDATE platform.config_version SET release = 'REL-OTHER' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: submitted version edited';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- approved_on is the database date, whatever the application sends.
  UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000007',
         approved_on = DATE '2000-01-01'
   WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  SELECT approved_on INTO v_on FROM platform.config_version WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  IF v_on <> platform.today_ist() THEN RAISE EXCEPTION 'T13a FAIL: approved_on is %', v_on; END IF;
  BEGIN
    UPDATE platform.config_version SET approved_on = DATE '2000-01-01' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: approval date changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE platform.config_value SET value = '7'::jsonb WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: value of an approved version changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T13a configuration: values fixed at validation (hash), frozen from SUBMITTED, approval date set by the database');
END $$;

-- A version that would apply before its approval date is refused (the database sets approved_on).
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.config_version (tenant_id, config_version_id, release, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000003','REL-TEST', daterange(platform.today_ist() - 30, NULL),
          '10000000-0000-0000-0000-000000000001');
  UPDATE platform.config_version SET status = 'VALIDATED',
         values_hash = platform.config_values_hash('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000003')
   WHERE config_version_id = 'c4000000-0000-0000-0000-000000000003';
  UPDATE platform.config_version SET status = 'TESTED'    WHERE config_version_id = 'c4000000-0000-0000-0000-000000000003';
  UPDATE platform.config_version SET status = 'SUBMITTED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000003';
  BEGIN
    UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000008',
           approved_on = platform.today_ist() - 60
     WHERE config_version_id = 'c4000000-0000-0000-0000-000000000003';
    RAISE EXCEPTION 'T13b FAIL: a back-dated version was approved';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.ok('T13b a configuration version can never apply to dates before its approval');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.config_version (tenant_id, config_version_id, release, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000002','REL-TEST', daterange(platform.today_ist() + 7, NULL),
          '10000000-0000-0000-0000-000000000001');
  UPDATE platform.config_version SET status = 'VALIDATED',
         values_hash = platform.config_values_hash('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000002')
   WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
  UPDATE platform.config_version SET status = 'TESTED'    WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
  UPDATE platform.config_version SET status = 'SUBMITTED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
  BEGIN
    UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000008'
     WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T13c FAIL: two approved configuration versions start on the same date';
  EXCEPTION WHEN exclusion_violation THEN
    PERFORM pg_temp.ok('T13c two approved configuration versions cannot start on the same date');
  END;
END $$;

-- D-77: the version in force on a date is the latest APPROVED / EFFECTIVE / SUPERSEDED version that
-- started on or before it; superseded versions still answer for past dates; WITHDRAWN never counts
-- and is allowed only before the start date; EFFECTIVE only from the start date; EFFECTIVE ->
-- SUPERSEDED only when a later version is in force.
RESET ROLE;
CREATE FUNCTION pg_temp.cfg_to_submitted(p_id uuid, p_start date) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO platform.config_version (tenant_id, config_version_id, release, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a', p_id, 'REL-TEST', daterange(p_start, NULL), '10000000-0000-0000-0000-000000000001');
  UPDATE platform.config_version SET status = 'VALIDATED',
         values_hash = platform.config_values_hash('00000000-0000-0000-0000-00000000000a', p_id)
   WHERE config_version_id = p_id;
  UPDATE platform.config_version SET status = 'TESTED'    WHERE config_version_id = p_id;
  UPDATE platform.config_version SET status = 'SUBMITTED' WHERE config_version_id = p_id;
END $f$;
-- History for tenant B, as it would stand after earlier days (versions approved 10 and 3 days ago
-- and now in force).  Loaded by the migration owner with triggers off, because the test cannot
-- wait for real days to pass; constraints still apply.
SET session_replication_role = replica;
INSERT INTO platform.config_version (tenant_id, config_version_id, release, status, valid_period, maker_user_id,
                                     approval_request_id, approved_on, values_hash) VALUES
 ('00000000-0000-0000-0000-00000000000b','c4000000-0000-0000-0000-0000000000b1','REL-TEST','EFFECTIVE',
  daterange(platform.today_ist() - 10, NULL),'10000000-0000-0000-0000-0000000000b1','f0000000-0000-0000-0000-000000000026',
  platform.today_ist() - 10,'h'),
 ('00000000-0000-0000-0000-00000000000b','c4000000-0000-0000-0000-0000000000b2','REL-TEST','EFFECTIVE',
  daterange(platform.today_ist() - 3, NULL),'10000000-0000-0000-0000-0000000000b1','f0000000-0000-0000-0000-000000000027',
  platform.today_ist() - 3,'h');
SET session_replication_role = origin;
SET ROLE amc_app;
DO $$
DECLARE d date := platform.today_ist(); e text; v uuid;
BEGIN
  -- Tenant B: the older version is superseded by the newer one, which is in force.
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000b', true);
  UPDATE platform.config_version SET status = 'SUPERSEDED' WHERE config_version_id = 'c4000000-0000-0000-0000-0000000000b1';
  BEGIN
    UPDATE platform.config_version SET status = 'SUPERSEDED' WHERE config_version_id = 'c4000000-0000-0000-0000-0000000000b2';
    RAISE EXCEPTION 'T13d FAIL: the newest version was superseded with no later version';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'NO_LATER_VERSION%' THEN RAISE EXCEPTION 'T13d FAIL: wrong refusal: %', e; END IF;
  END;
  -- A re-run for a past date finds the superseded version.
  v := platform.config_version_in_force('00000000-0000-0000-0000-00000000000b', d - 5);
  IF v IS DISTINCT FROM 'c4000000-0000-0000-0000-0000000000b1' THEN RAISE EXCEPTION 'T13d FAIL: in force on d-5: %', v; END IF;
  v := platform.config_version_in_force('00000000-0000-0000-0000-00000000000b', d);
  IF v IS DISTINCT FROM 'c4000000-0000-0000-0000-0000000000b2' THEN RAISE EXCEPTION 'T13d FAIL: in force today: %', v; END IF;
  v := platform.config_version_in_force('00000000-0000-0000-0000-00000000000b', d - 11);
  IF v IS NOT NULL THEN RAISE EXCEPTION 'T13d FAIL: a version is in force before any started: %', v; END IF;

  -- Tenant A: c4..01 (start d+7) is APPROVED from T13a.  c4..11 starts today, c4..12 in 14 days.
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  PERFORM pg_temp.cfg_to_submitted('c4000000-0000-0000-0000-000000000011', d);
  PERFORM pg_temp.cfg_to_submitted('c4000000-0000-0000-0000-000000000012', d + 14);
  UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000022'
   WHERE config_version_id IN ('c4000000-0000-0000-0000-000000000011','c4000000-0000-0000-0000-000000000012');
  -- A version in force today cannot be withdrawn.
  BEGIN
    UPDATE platform.config_version SET status = 'WITHDRAWN', withdrawal_request_id = 'f0000000-0000-0000-0000-000000000023'
     WHERE config_version_id = 'c4000000-0000-0000-0000-000000000011';
    RAISE EXCEPTION 'T13d FAIL: a version in force today was withdrawn';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'VERSION_IN_FORCE%' THEN RAISE EXCEPTION 'T13d FAIL: wrong refusal: %', e; END IF;
  END;
  UPDATE platform.config_version SET status = 'EFFECTIVE' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000011';
  -- A version cannot be marked EFFECTIVE before its start date ...
  BEGIN
    UPDATE platform.config_version SET status = 'EFFECTIVE' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13d FAIL: a future version was marked EFFECTIVE';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'NOT_YET_IN_FORCE%' THEN RAISE EXCEPTION 'T13d FAIL: wrong refusal: %', e; END IF;
  END;
  -- ... and nothing is superseded by versions that have not started yet.
  BEGIN
    UPDATE platform.config_version SET status = 'SUPERSEDED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000011';
    RAISE EXCEPTION 'T13d FAIL: superseded by a version not yet in force';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  v := platform.config_version_in_force('00000000-0000-0000-0000-00000000000a', d + 8);
  IF v IS DISTINCT FROM 'c4000000-0000-0000-0000-000000000001' THEN RAISE EXCEPTION 'T13d FAIL: in force on d+8: %', v; END IF;
  v := platform.config_version_in_force('00000000-0000-0000-0000-00000000000a', d + 20);
  IF v IS DISTINCT FROM 'c4000000-0000-0000-0000-000000000012' THEN RAISE EXCEPTION 'T13d FAIL: in force on d+20: %', v; END IF;
  -- Withdrawal needs its request; before the start date it works and the version never counts.
  BEGIN
    UPDATE platform.config_version SET status = 'WITHDRAWN' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000012';
    RAISE EXCEPTION 'T13d FAIL: withdrawn with no request';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE platform.config_version SET status = 'WITHDRAWN', withdrawal_request_id = 'f0000000-0000-0000-0000-000000000023'
   WHERE config_version_id = 'c4000000-0000-0000-0000-000000000012';
  v := platform.config_version_in_force('00000000-0000-0000-0000-00000000000a', d + 20);
  IF v IS DISTINCT FROM 'c4000000-0000-0000-0000-000000000001' THEN RAISE EXCEPTION 'T13d FAIL: withdrawn version still counts (%)', v; END IF;
  BEGIN
    UPDATE platform.config_version SET status = 'APPROVED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000012';
    RAISE EXCEPTION 'T13d FAIL: a withdrawn version came back';
  EXCEPTION WHEN check_violation OR insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T13d D-77: superseded versions answer for past dates; EFFECTIVE only from the start date; supersede only by a version in force; withdrawal only before the start date and never counts');
END $$;

-- A superseded version still blocks another version with the same start date (D-77).  Checked on
-- the constraint itself: a SUPERSEDED version starts in the past, and no version can be approved for
-- a past date, so the clash cannot be produced through the lifecycle in one test run (T13c shows the
-- constraint acting on APPROVED versions).
RESET ROLE;
DO $$
DECLARE v text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO v FROM pg_constraint
   WHERE conrelid = 'platform.config_version'::regclass AND contype = 'x';
  IF v NOT LIKE '%lower(valid_period) WITH =%' OR v NOT LIKE '%''APPROVED''%' OR v NOT LIKE '%''EFFECTIVE''%'
     OR v NOT LIKE '%''SUPERSEDED''%' OR v LIKE '%''WITHDRAWN''%' THEN
    RAISE EXCEPTION 'T13e FAIL: same-start rule is %', v;
  END IF;
  PERFORM pg_temp.ok('T13e no two APPROVED / EFFECTIVE / SUPERSEDED versions may start on the same date; WITHDRAWN does not count');
END $$;
SET ROLE amc_app;

-- "Today" cannot be moved back by the session time zone (round-3 Major 4).
DO $$
DECLARE d date; v_on date;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  d := platform.today_ist();
  PERFORM set_config('TimeZone','Etc/GMT+12', true);
  IF platform.today_ist() <> d THEN RAISE EXCEPTION 'T13f FAIL: today moved with the session time zone'; END IF;
  PERFORM pg_temp.cfg_to_submitted('c4000000-0000-0000-0000-000000000014', d - 1);
  BEGIN
    UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000025'
     WHERE config_version_id = 'c4000000-0000-0000-0000-000000000014';
    RAISE EXCEPTION 'T13f FAIL: a far-west session approved a version for yesterday';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.cfg_to_submitted('c4000000-0000-0000-0000-000000000015', d + 3);
  UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000025'
   WHERE config_version_id = 'c4000000-0000-0000-0000-000000000015';
  SELECT approved_on INTO v_on FROM platform.config_version WHERE config_version_id = 'c4000000-0000-0000-0000-000000000015';
  IF v_on <> d THEN RAISE EXCEPTION 'T13f FAIL: approved_on % under a far-west time zone (India date %)', v_on, d; END IF;
  PERFORM pg_temp.ok('T13f approved_on is the India business date whatever the session TimeZone');
END $$;

-- M14: the history cannot carry a cause that is not the checked move's (round-3 Minor 6).
DO $$
DECLARE e text; x text;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.config_version (tenant_id, config_version_id, release, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000016','REL-TEST',
          daterange(platform.today_ist() + 40, NULL),'10000000-0000-0000-0000-000000000001');
  BEGIN
    WITH u AS (UPDATE platform.config_version SET status = 'VALIDATED',
                      values_hash = platform.config_values_hash('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000016')
                WHERE config_version_id = 'c4000000-0000-0000-0000-000000000016' RETURNING 1)
    SELECT set_config('app.transition_cause','FORGED_CAUSE', true) INTO x FROM u;
    RAISE EXCEPTION 'T11f FAIL: history written with a forged cause';
  EXCEPTION WHEN check_violation THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'ILLEGAL_TRANSITION%' THEN RAISE EXCEPTION 'T11f FAIL: wrong refusal: %', e; END IF;
  END;
  PERFORM set_config('app.transition_cause','', true);
  PERFORM pg_temp.ok('T11f a cause changed after the move was checked cannot reach the history');
END $$;

-- =====================================================================
-- T14  Tenant record (DM-16) and isolation of the new tables
-- =====================================================================
RESET ROLE;
DO $$
DECLARE n int;
BEGIN
  BEGIN
    INSERT INTO platform.tenant (tenant_code, legal_name, kms_key_ref, status) VALUES ('AMC_GAMMA','Gamma','kms/g','ACTIVE');
    RAISE EXCEPTION 'T14a FAIL: active tenant without a cell';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO platform.tenant (tenant_code, legal_name, kms_key_ref, isolation_tier) VALUES ('AMC_DELTA','Delta','kms/d','DEDICATED_DB');
    RAISE EXCEPTION 'T14a FAIL: DEDICATED_DB tier accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE platform.tenant SET status = 'SUSPENDED' WHERE tenant_code = 'AMC_BETA';
  SELECT count(*) INTO n FROM platform.tenant_status_history
   WHERE tenant_id = '00000000-0000-0000-0000-00000000000b' AND from_status = 'ACTIVE' AND to_status = 'SUSPENDED';
  IF n <> 1 THEN RAISE EXCEPTION 'T14a FAIL: status change not in history'; END IF;
  UPDATE platform.tenant SET status = 'ACTIVE' WHERE tenant_code = 'AMC_BETA';
  PERFORM pg_temp.ok('T14a an active tenant needs a cell; DEDICATED_DB is gone; every status change is in the history');
END $$;

SET ROLE amc_app;
DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000b', true);
  SELECT count(*) INTO n FROM master.security_version;
  IF n <> 0 THEN RAISE EXCEPTION 'T14b FAIL: tenant B sees % of tenant A''s security versions', n; END IF;
  SELECT count(*) INTO n FROM master.external_identifier;
  IF n <> 0 THEN RAISE EXCEPTION 'T14b FAIL: tenant B sees tenant A''s crosswalk'; END IF;
  SELECT count(*) INTO n FROM identity.role_grant_request_history;
  IF n <> 0 THEN RAISE EXCEPTION 'T14b FAIL: tenant B sees tenant A''s request history'; END IF;
  BEGIN
    INSERT INTO master.security_version (tenant_id, security_id, valid_period, short_name, approval_request_id)
    VALUES ('00000000-0000-0000-0000-00000000000b','40000000-0000-0000-0000-000000000001','[2028-01-01,)','HIJACK',
            'f0000000-0000-0000-0000-000000000009');
    RAISE EXCEPTION 'T14b FAIL: tenant B wrote a version of tenant A''s security';
  EXCEPTION WHEN foreign_key_violation OR insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO audit.access_log (tenant_id, accessed_at, actor_type, access_kind, object_type, purpose_code)
  VALUES ('00000000-0000-0000-0000-00000000000a','2026-11-24 10:00+05:30','USER','UNMASK','investor.investor','SERVICE_REQUEST');
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000b', true);
  SELECT count(*) INTO n FROM audit.access_log_2026_11;
  IF n <> 0 THEN RAISE EXCEPTION 'T14b FAIL: tenant B reads tenant A access log through the partition'; END IF;
  PERFORM pg_temp.ok('T14b new tables and partitions are tenant-isolated (reads, writes, cross-tenant foreign keys)');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO platform.tenant_entitlement (tenant_id, module_code, valid_period, access_mode, max_users, desired_state_ref)
    VALUES ('00000000-0000-0000-0000-00000000000a','RISK','[2026-01-01,)','FULL',100000,'self');
    RAISE EXCEPTION 'T15 FAIL: the application gave itself an entitlement';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO platform.usage_meter (tenant_id, meter_code, usage_date, quantity)
    VALUES ('00000000-0000-0000-0000-00000000000a','USERS','2026-11-24',1);
    RAISE EXCEPTION 'T15 FAIL: the application wrote its own usage count';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE identity.permission SET ai_forbidden = false;
    RAISE EXCEPTION 'T15 FAIL: the application changed the permission list';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T15 subscriptions, entitlements, usage counts and product-level lists are not writable by the application');
END $$;

RESET ROLE;
\echo 'All tests passed.'
