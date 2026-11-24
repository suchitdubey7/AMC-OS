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

-- =====================================================================
-- Fixtures for tenant A (as the application role)
-- =====================================================================
SET ROLE amc_app;
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
SET LOCAL app.user_id   = '10000000-0000-0000-0000-000000000002';
INSERT INTO identity.app_user (user_id, tenant_id, external_subject, email, display_name) VALUES
 ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-00000000000a','sub-ta','ta@alpha.in','Tenant Admin A');
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
     WHERE security_id = '40000000-0000-0000-0000-000000000002' AND superseded_at IS NULL;
    RAISE EXCEPTION 'T8b FAIL: current version superseded without a correction';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE master.security SET isin = 'INE000B01099' WHERE security_id = '40000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'T8b FAIL: anchor changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T8b versions are insert-only: no edit, no supersede without a correction; anchors never change');
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
    UPDATE master.security_version SET superseded_at = now()
     WHERE security_id = '40000000-0000-0000-0000-000000000002' AND superseded_at IS NULL;
    RAISE EXCEPTION 'T8b2 FAIL: superseded without a correction';
  EXCEPTION WHEN insufficient_privilege THEN GET STACKED DIAGNOSTICS e = MESSAGE_TEXT;
    IF e NOT LIKE 'SUPERSEDE_WITHOUT_CORRECTION%' THEN RAISE EXCEPTION 'T8b2 FAIL: wrong refusal: %', e; END IF;
  END;
  PERFORM pg_temp.ok('T8b2 the bi-temporal guard trigger itself refuses delete and supersede-without-correction');
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
-- (A new block: the correction relies on the default deferred check, which SET CONSTRAINTS
-- ALL IMMEDIATE above switched off for the rest of that transaction.)
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
  INSERT INTO identity.role (tenant_id, role_code, description)
  VALUES ('00000000-0000-0000-0000-00000000000a','FUND_ACCOUNTANT','Fund accountant');
  BEGIN
    INSERT INTO identity.role_grant_request (tenant_id, request_type, user_id, role_code, requested_by, reason, status, sod_result, approval_request_id)
    VALUES ('00000000-0000-0000-0000-00000000000a','GRANT','10000000-0000-0000-0000-000000000001','FUND_ACCOUNTANT',
            '10000000-0000-0000-0000-000000000002','x','APPROVED','PASS','f0000000-0000-0000-0000-000000000006');
    RAISE EXCEPTION 'T11a FAIL: a request was born APPROVED';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO identity.role_grant_request (tenant_id, request_type, user_id, role_code, requested_by, reason, status)
    VALUES ('00000000-0000-0000-0000-00000000000a','GRANT','10000000-0000-0000-0000-000000000001','FUND_ACCOUNTANT',
            '10000000-0000-0000-0000-000000000002','x','MADE_UP_STATE');
    RAISE EXCEPTION 'T11a FAIL: a state not in the transition table was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM pg_temp.ok('T11a a row is born only in its first state; states not in the transition table are refused');
END $$;

DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO identity.role_grant_request (tenant_id, request_id, request_type, user_id, role_code, requested_by, reason)
  VALUES ('00000000-0000-0000-0000-00000000000a','c1000000-0000-0000-0000-000000000001','GRANT','10000000-0000-0000-0000-000000000001',
          'FUND_ACCOUNTANT','10000000-0000-0000-0000-000000000002','joiner');
  BEGIN
    UPDATE identity.role_grant_request SET status = 'APPLIED', sod_result = 'PASS', approval_request_id = 'f0000000-0000-0000-0000-000000000006'
     WHERE request_id = 'c1000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T11b FAIL: SUBMITTED -> APPLIED skipped approval';
  EXCEPTION WHEN check_violation THEN NULL;
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
          '10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003');
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

-- =====================================================================
-- T13  Configuration versions (EA-008 §5, M11)
-- =====================================================================
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.config_version (tenant_id, config_version_id, release, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001','REL-TEST','[2026-12-01,)',
          '10000000-0000-0000-0000-000000000001');
  INSERT INTO platform.config_value (tenant_id, config_version_id, item_key, scope_type, scope_id, value)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000001','d11.price.tolerance_day_move','TENANT',
          '00000000-0000-0000-0000-00000000000a','5'::jsonb);
  UPDATE platform.config_version SET status = 'VALIDATED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  UPDATE platform.config_version SET status = 'TESTED'    WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  UPDATE platform.config_version SET status = 'SUBMITTED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  BEGIN
    UPDATE platform.config_version SET release = 'REL-OTHER' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: submitted version edited';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000007',
           approved_on = '2026-12-15'
     WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: version approved to apply before its approval date';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000007',
         approved_on = '2026-11-24'
   WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
  BEGIN
    UPDATE platform.config_value SET value = '7'::jsonb WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: value of an approved version changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE platform.config_version SET valid_period = '[2026-12-02,)' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T13a FAIL: approved version edited';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T13a configuration follows DRAFT -> ... -> APPROVED, never applies before approval, and is frozen from SUBMITTED on');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO platform.config_version (tenant_id, config_version_id, release, valid_period, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','c4000000-0000-0000-0000-000000000002','REL-TEST','[2026-12-01,)',
          '10000000-0000-0000-0000-000000000001');
  UPDATE platform.config_version SET status = 'VALIDATED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
  UPDATE platform.config_version SET status = 'TESTED'    WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
  UPDATE platform.config_version SET status = 'SUBMITTED' WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
  BEGIN
    UPDATE platform.config_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000008',
           approved_on = '2026-11-24'
     WHERE config_version_id = 'c4000000-0000-0000-0000-000000000002';
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T13b FAIL: two approved configuration versions start on the same date';
  EXCEPTION WHEN exclusion_violation THEN
    PERFORM pg_temp.ok('T13b two approved configuration versions cannot start on the same date');
  END;
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
