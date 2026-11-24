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
  PERFORM pg_temp.ok('C2 every tenant table has forced RLS; every other table is on the M3 product-level list');
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
    DELETE FROM master.security_version WHERE security_id = '40000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'T8b FAIL: version deleted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE master.security SET isin = 'INE000B01099' WHERE security_id = '40000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'T8b FAIL: anchor changed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.ok('T8b versions are insert-only: no edit, no supersede without a correction, no delete; anchors never change');
END $$;

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
  PERFORM pg_temp.ok('T8c a split of the validity period leaves exactly the corrected set current');
END $$;

-- Two current versions that overlap are refused (the exclusion constraint is checked at COMMIT).
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    -- Bypass the supersede trigger's effect by inserting an OLDER-recorded row is impossible,
    -- so prove the constraint directly: two rows in one statement with the same recorded_at.
    INSERT INTO platform.tenant_entitlement (tenant_id, module_code, valid_period, recorded_at, access_mode, desired_state_ref)
    VALUES ('00000000-0000-0000-0000-00000000000a','NAV','[2026-01-01,)','2026-11-24 10:00+05:30','FULL','ds-1'),
           ('00000000-0000-0000-0000-00000000000a','NAV','[2026-06-01,)','2026-11-24 10:00+05:30','READ_ONLY','ds-1');
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'T8d FAIL: overlapping current versions accepted';
  EXCEPTION WHEN exclusion_violation THEN
    PERFORM pg_temp.ok('T8d two overlapping current versions of one key are refused');
  END;
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
  UPDATE master.load_run SET status = 'COMPLETED', finished_at = now(), rows_loaded = 1, rows_quarantined = 0
   WHERE load_run_id = 'b1000000-0000-0000-0000-000000000001';
  BEGIN
    UPDATE master.load_run SET rows_loaded = 99 WHERE load_run_id = 'b1000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T9b FAIL: finished load run edited';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T9b a load run is frozen once it is no longer RUNNING');
  END;
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
  PERFORM pg_temp.ok('T12a two different people grant a role, neither the receiver; nobody certifies their own access');
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
  PERFORM pg_temp.ok('T13a configuration follows DRAFT -> ... -> APPROVED, never applies before approval, and is frozen once approved');
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

RESET ROLE;
\echo 'All tests passed.'
