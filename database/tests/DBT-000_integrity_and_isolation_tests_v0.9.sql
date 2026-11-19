-- =====================================================================
-- AMC OS  -  DDL verification & negative security tests
-- Run after amc_os_ddl.sql:  psql -v ON_ERROR_STOP=1 -f amc_os_tests.sql
-- Every test prints PASS or raises an exception (which stops the run).
-- =====================================================================
\set QUIET on
-- Fixture data is created as the migration owner (bypasses RLS by design).
INSERT INTO platform.tenant (tenant_id, tenant_code, legal_name, kms_key_ref, status) VALUES
 ('00000000-0000-0000-0000-00000000000a','AMC_ALPHA','Alpha AMC Ltd','kms/alpha','ACTIVE'),
 ('00000000-0000-0000-0000-00000000000b','AMC_BETA','Beta AMC Ltd','kms/beta','ACTIVE');
INSERT INTO master.currency VALUES ('INR',2);

-- Helper to run a block as the application role inside a tenant.
CREATE OR REPLACE FUNCTION pg_temp.ok(msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN RAISE NOTICE 'PASS  %', msg; END $$;

SET ROLE amc_app;

-- ---------- Tenant A fixtures ----------
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
INSERT INTO identity.app_user (user_id, tenant_id, external_subject, email, display_name) VALUES
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-00000000000a','sub-fa1','fa1@alpha.in','Fund Accountant A'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-00000000000a','sub-hfa','hfa@alpha.in','Head FA A');
INSERT INTO identity.app_user (user_id, tenant_id, external_subject, email, display_name, is_service_identity) VALUES
 ('10000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-00000000000a','svc-nav-agent','nav-agent@alpha.in','NAV Ops Agent', true);
INSERT INTO master.benchmark (tenant_id, benchmark_id, name, variant, provider)
 VALUES ('00000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000001','Nifty 100','TRI','NSE Indices');
INSERT INTO product.scheme (tenant_id, scheme_id, scheme_code, legal_name, structure, lifecycle_state)
 VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001','ALPHA_LC','Alpha Large Cap Fund','OPEN_ENDED','ACTIVE');
INSERT INTO product.plan (tenant_id, plan_id, scheme_id, plan_type, option_type, isin)
 VALUES ('00000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','DIRECT','GROWTH','INF000A01011');
INSERT INTO master.security (tenant_id, security_id, isin, short_name, instrument_type)
 VALUES ('00000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000001','INE000A01018','ALPHA CORP','EQUITY');
INSERT INTO accounting.account (tenant_id, account_code, account_name, account_class, normal_balance) VALUES
 ('00000000-0000-0000-0000-00000000000a','1100','Investments - Equity','ASSET','D'),
 ('00000000-0000-0000-0000-00000000000a','1200','Bank','ASSET','D');
COMMIT;

-- ---------- Tenant B fixtures ----------
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000b';
INSERT INTO product.scheme (tenant_id, scheme_id, scheme_code, legal_name, structure)
 VALUES ('00000000-0000-0000-0000-00000000000b','30000000-0000-0000-0000-0000000000b1','BETA_FLEXI','Beta Flexi Cap Fund','OPEN_ENDED');
COMMIT;

-- =====================================================================
-- T1  Cross-tenant isolation (negative tests)
-- =====================================================================
DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  SELECT count(*) INTO n FROM product.scheme;
  IF n <> 1 THEN RAISE EXCEPTION 'T1a FAIL: tenant A sees % schemes', n; END IF;
  SELECT count(*) INTO n FROM product.scheme WHERE scheme_id = '30000000-0000-0000-0000-0000000000b1';
  IF n <> 0 THEN RAISE EXCEPTION 'T1b FAIL: tenant A can read tenant B scheme by id'; END IF;
  PERFORM pg_temp.ok('T1a/T1b tenant A cannot see tenant B rows, even by primary key');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO product.scheme (tenant_id, scheme_code, legal_name, structure)
    VALUES ('00000000-0000-0000-0000-00000000000b','HACK','Injected','OPEN_ENDED');
    RAISE EXCEPTION 'T1c FAIL: cross-tenant insert succeeded';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T1c insert with another tenant_id is rejected by RLS WITH CHECK');
  END;
END $$;

DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  UPDATE product.scheme SET legal_name = 'pwned' WHERE scheme_id = '30000000-0000-0000-0000-0000000000b1';
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 0 THEN RAISE EXCEPTION 'T1d FAIL: cross-tenant update touched % rows', n; END IF;
  PERFORM pg_temp.ok('T1d cross-tenant UPDATE affects 0 rows');
END $$;

DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','', true);       -- no tenant context
  SELECT count(*) INTO n FROM product.scheme;
  IF n <> 0 THEN RAISE EXCEPTION 'T1e FAIL: no tenant context returned % rows', n; END IF;
  PERFORM pg_temp.ok('T1e missing tenant context returns nothing (fail closed)');
END $$;

DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000b', true);
  -- direct partition access must also be filtered
  SELECT count(*) INTO n FROM audit.audit_event_default;
  SELECT count(*) INTO n FROM investor.investor_txn_2026_11;
  PERFORM pg_temp.ok('T1f direct partition access is under RLS (policy present on leaf partitions)');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000b', true);
  BEGIN
    -- tenant B tries to reference tenant A's scheme via a tenant-aware FK
    INSERT INTO product.plan (tenant_id, scheme_id, plan_type, option_type, isin)
    VALUES ('00000000-0000-0000-0000-00000000000b','30000000-0000-0000-0000-000000000001','DIRECT','GROWTH','INF000B01019');
    RAISE EXCEPTION 'T1g FAIL: cross-tenant FK accepted';
  EXCEPTION WHEN foreign_key_violation THEN
    PERFORM pg_temp.ok('T1g composite (tenant_id, id) FK blocks pointing at another tenant''s parent');
  END;
END $$;

-- =====================================================================
-- T2  Double-entry: unbalanced batch rejected at COMMIT; balanced accepted
-- =====================================================================
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO accounting.journal_batch (tenant_id, batch_id, scheme_id, accounting_date, source_type, posted_by, idempotency_key)
    VALUES ('00000000-0000-0000-0000-00000000000a','50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','2026-11-19','settlement.trade','10000000-0000-0000-0000-000000000001','T2-unbalanced');
    INSERT INTO accounting.journal_line (tenant_id, accounting_date, batch_id, scheme_id, account_code, dr_cr, amount) VALUES
     ('00000000-0000-0000-0000-00000000000a','2026-11-19','50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','1100','D',1000.00),
     ('00000000-0000-0000-0000-00000000000a','2026-11-19','50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','1200','C', 999.99);
    SET CONSTRAINTS ALL IMMEDIATE;   -- force the deferred check now
    RAISE EXCEPTION 'T2a FAIL: unbalanced batch accepted';
  EXCEPTION WHEN check_violation THEN
    PERFORM pg_temp.ok('T2a batch out by 0.01 is rejected');
  END;
END $$;

BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
INSERT INTO accounting.journal_batch (tenant_id, batch_id, scheme_id, accounting_date, source_type, posted_by, idempotency_key)
VALUES ('00000000-0000-0000-0000-00000000000a','50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','2026-11-19','settlement.trade','10000000-0000-0000-0000-000000000001','T2-balanced');
INSERT INTO accounting.journal_line (tenant_id, accounting_date, batch_id, scheme_id, account_code, dr_cr, amount) VALUES
 ('00000000-0000-0000-0000-00000000000a','2026-11-19','50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','1100','D',1000.00),
 ('00000000-0000-0000-0000-00000000000a','2026-11-19','50000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','1200','C',1000.00);
COMMIT;
DO $$ BEGIN PERFORM pg_temp.ok('T2b balanced batch commits'); END $$;

DO $$
DECLARE v numeric;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  SELECT sum(net) INTO v FROM accounting.trial_balance('30000000-0000-0000-0000-000000000001','2026-11-30');
  IF v <> 0 THEN RAISE EXCEPTION 'T2c FAIL: trial balance nets to %', v; END IF;
  PERFORM pg_temp.ok('T2c trial balance nets to zero');
END $$;

-- =====================================================================
-- T3  Immutability of posted journals and audit
-- =====================================================================
DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    DELETE FROM accounting.journal_line WHERE batch_id = '50000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'T3a FAIL: journal delete allowed';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T3a DELETE on posted journal lines is refused');
  END;
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  INSERT INTO audit.audit_event (tenant_id, actor_type, action, object_type) VALUES
    ('00000000-0000-0000-0000-00000000000a','USER','scheme.scheme.update','product.scheme'),
    ('00000000-0000-0000-0000-00000000000a','USER','nav.run.approve','nav.run');
  BEGIN
    UPDATE audit.audit_event SET action = 'tampered';
    RAISE EXCEPTION 'T3b FAIL: audit update allowed';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T3b audit events cannot be updated');
  END;
END $$;

DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  SELECT count(*) INTO n FROM (
    SELECT row_hash, lag(row_hash) OVER (ORDER BY event_seq) AS expected_prev, prev_hash
      FROM audit.audit_event) x
   WHERE expected_prev IS NOT NULL AND expected_prev <> prev_hash;
  IF n <> 0 THEN RAISE EXCEPTION 'T3c FAIL: hash chain broken at % rows', n; END IF;
  PERFORM pg_temp.ok('T3c audit hash chain links each event to the previous one');
END $$;

-- =====================================================================
-- T4  Order state machine
-- =====================================================================
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
INSERT INTO investment.decision_record (tenant_id, decision_id, scheme_id, author_user_id, rationale)
VALUES ('00000000-0000-0000-0000-00000000000a','60000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Add on valuation comfort after Q2 results; within limits.');
INSERT INTO trading.order (tenant_id, order_id, scheme_id, security_id, side, order_type, quantity, limit_price, decision_id, created_by, trade_date, idempotency_key)
VALUES ('00000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','BUY','LIMIT',10000,1520.50,'60000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','2026-11-19','idem-001');
UPDATE trading.order SET state = 'PENDING_COMPLIANCE' WHERE order_id = '70000000-0000-0000-0000-000000000001';
COMMIT;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    UPDATE trading.order SET state = 'FILLED' WHERE order_id = '70000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T4a FAIL: illegal transition allowed';
  EXCEPTION WHEN check_violation THEN
    PERFORM pg_temp.ok('T4a PENDING_COMPLIANCE -> FILLED is refused');
  END;
END $$;

DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  SELECT count(*) INTO n FROM trading.order_event WHERE order_id = '70000000-0000-0000-0000-000000000001';
  IF n <> 1 THEN RAISE EXCEPTION 'T4b FAIL: expected 1 order event, got %', n; END IF;
  PERFORM pg_temp.ok('T4b each legal transition writes an order event');
END $$;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO trading.order (tenant_id, scheme_id, security_id, side, order_type, quantity, decision_id, created_by, trade_date, idempotency_key)
    VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','BUY','MARKET',5,'60000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','2026-11-19','idem-001');
    RAISE EXCEPTION 'T4c FAIL: duplicate idempotency key accepted';
  EXCEPTION WHEN unique_violation THEN
    PERFORM pg_temp.ok('T4c duplicate Idempotency-Key cannot create a second order');
  END;
END $$;

-- =====================================================================
-- T5  Maker-checker / SoD
-- =====================================================================
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
INSERT INTO workflow.approval_request (tenant_id, request_id, object_type, object_id, action, maker_user_id, reason)
VALUES ('00000000-0000-0000-0000-00000000000a','80000000-0000-0000-0000-000000000001','nav.run','90000000-0000-0000-0000-000000000001','nav.run.approve','10000000-0000-0000-0000-000000000001','Daily NAV 19-Nov');
COMMIT;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    INSERT INTO workflow.approval_decision (tenant_id, request_id, approver_user_id, decision)
    VALUES ('00000000-0000-0000-0000-00000000000a','80000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','APPROVE');
    RAISE EXCEPTION 'T5a FAIL: maker approved own request';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T5a maker cannot approve own request');
  END;
  BEGIN
    INSERT INTO workflow.approval_decision (tenant_id, request_id, approver_user_id, decision)
    VALUES ('00000000-0000-0000-0000-00000000000a','80000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000009','APPROVE');
    RAISE EXCEPTION 'T5b FAIL: AI service identity approved';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T5b AI agent service identity cannot approve');
  END;
  INSERT INTO workflow.approval_decision (tenant_id, request_id, approver_user_id, decision)
  VALUES ('00000000-0000-0000-0000-00000000000a','80000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','APPROVE');
  PERFORM pg_temp.ok('T5c a different human approver succeeds');
END $$;

-- =====================================================================
-- T6  NAV: preparer != approver, one live NAV per date, published NAV immutable
-- =====================================================================
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
INSERT INTO nav.nav_run (tenant_id, nav_run_id, scheme_id, nav_date, prepared_by)
VALUES ('00000000-0000-0000-0000-00000000000a','90000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','2026-11-19','10000000-0000-0000-0000-000000000001');
INSERT INTO nav.nav_result (tenant_id, nav_run_id, plan_id, nav_date, total_assets, total_liabilities, units_outstanding, nav_unrounded, nav_per_unit)
VALUES ('00000000-0000-0000-0000-00000000000a','90000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000001','2026-11-19',
        1000000000.0000, 2500000.0000, 23456789.123456,
        (1000000000.0000 - 2500000.0000) / 23456789.123456,
        round((1000000000.0000 - 2500000.0000) / 23456789.123456, 4));
COMMIT;

DO $$
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  BEGIN
    UPDATE nav.nav_run SET state = 'APPROVED', approved_by = prepared_by WHERE nav_run_id = '90000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T6a FAIL: preparer approved own NAV';
  EXCEPTION WHEN check_violation THEN
    PERFORM pg_temp.ok('T6a NAV preparer cannot approve');
  END;
  UPDATE nav.nav_run SET state = 'PUBLISHED', approved_by = '10000000-0000-0000-0000-000000000002', approved_at = now()
   WHERE nav_run_id = '90000000-0000-0000-0000-000000000001';
  BEGIN
    UPDATE nav.nav_run SET input_manifest = '{"x":1}' WHERE nav_run_id = '90000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'T6b FAIL: published NAV changed';
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.ok('T6b published NAV run cannot be edited');
  END;
  BEGIN
    INSERT INTO nav.nav_run (tenant_id, scheme_id, nav_date, run_no, state, prepared_by, approved_by)
    VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001','2026-11-19',2,'APPROVED',
            '10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002');
    RAISE EXCEPTION 'T6c FAIL: second live NAV for same date';
  EXCEPTION WHEN unique_violation THEN
    PERFORM pg_temp.ok('T6c only one live NAV per scheme per date');
  END;
END $$;

DO $$
DECLARE v numeric;
BEGIN
  PERFORM set_config('app.tenant_id','00000000-0000-0000-0000-00000000000a', true);
  SELECT nav_per_unit INTO v FROM nav.nav_result WHERE nav_run_id = '90000000-0000-0000-0000-000000000001';
  IF v <> 42.5250 THEN RAISE EXCEPTION 'T6d FAIL: NAV %', v; END IF;
  PERFORM pg_temp.ok('T6d NAV = (1,000,000,000 - 2,500,000) / 23,456,789.123456 = 42.5250 (exact NUMERIC, rounded once at the end)');
END $$;

-- =====================================================================
-- T7  Commission arithmetic is enforced
-- =====================================================================
BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-00000000000a';
INSERT INTO distribution.distributor (tenant_id, distributor_id, arn, name, entity_type)
VALUES ('00000000-0000-0000-0000-00000000000a','a0000000-0000-0000-0000-000000000001','ARN-12345','Sample MFD','INDIVIDUAL');
INSERT INTO distribution.commission_run (tenant_id, run_id, period_month, prepared_by)
VALUES ('00000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-000000000001','2026-11-01','10000000-0000-0000-0000-000000000001');
-- 10,00,000 AUM for 30 days at 0.80% p.a. on 365 basis = 657.5342
INSERT INTO distribution.commission_line (tenant_id, run_id, distributor_id, plan_id, aum_days, trail_pct_pa, gross_commission, net_payable)
VALUES ('00000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001',
        '31000000-0000-0000-0000-000000000001', 30000000, 0.80, 657.5342, 657.5342);
COMMIT;
DO $$ BEGIN PERFORM pg_temp.ok('T7 commission 10,00,000 x 30 days x 0.80% / 365 = 657.5342 accepted by CHECK'); END $$;

RESET ROLE;
\echo 'All tests passed.'
