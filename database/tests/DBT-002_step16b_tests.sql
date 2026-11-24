-- =====================================================================
-- DBT-002  AMC OS - Step 16b database tests (status: Draft, WP4 / GOV-006 Step 16, part b)
-- Run after every file in database/ddl and after DBT-000 and DBT-001 (it reuses their tenants,
-- users, scheme, plan, securities and benchmark):
--   psql -v ON_ERROR_STOP=1 -f DBT-002_step16b_tests.sql
-- Every test prints PASS or raises an exception (which stops the run).
-- Rule numbers (M5, M6, M7, M12, M14 ...) are DA-001 §1 modelling rules; BT-n are DDL-001 §00.
-- =====================================================================
\set QUIET on
CREATE OR REPLACE FUNCTION pg_temp.ok(msg text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN RAISE NOTICE 'PASS  %', msg; END $$;

-- Acting tenant A and user (transaction-local, as the application sets them).
CREATE OR REPLACE FUNCTION pg_temp.as_a(p_user text DEFAULT '10000000-0000-0000-0000-000000000002') RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('app.tenant_id', '00000000-0000-0000-0000-00000000000a', true);
  PERFORM set_config('app.user_id', p_user, true);
END $$;

-- Runs p_sql (and then every deferred check); PASS only if it fails with SQLSTATE p_state and,
-- when given, a message starting with p_msg.  The statement's effects are rolled back.
CREATE OR REPLACE FUNCTION pg_temp.expect_fail(p_label text, p_sql text, p_state text, p_msg text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'NO_ERROR';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'NO_ERROR' THEN
      RAISE EXCEPTION '% FAIL: statement was accepted', p_label;
    END IF;
    IF SQLSTATE <> p_state OR (p_msg IS NOT NULL AND SQLERRM NOT LIKE p_msg || '%') THEN
      RAISE EXCEPTION '% FAIL: expected % %, got % %', p_label, p_state, coalesce(p_msg, ''), SQLSTATE, SQLERRM;
    END IF;
  END;
  SET CONSTRAINTS ALL DEFERRED;
  PERFORM pg_temp.ok(p_label);
END $$;

-- =====================================================================
-- C  Catalogue checks (run as migration owner)
-- =====================================================================
DO $$
DECLARE n int; v text;
BEGIN
  -- M7 / BT: every version table in this part's schemas has the three bi-temporal triggers and a
  -- closure table whose rows the application cannot update.
  SELECT count(*), string_agg(s.nspname || '.' || k.relname, ', ') INTO n, v
    FROM pg_class k JOIN pg_namespace s ON s.oid = k.relnamespace
   WHERE k.relkind = 'r' AND s.nspname IN ('product','investment','portfolio','trading','execution','settlement')
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = k.oid AND a.attname = 'superseded_at' AND NOT a.attisdropped)
     AND ((SELECT count(*) FROM pg_trigger t WHERE t.tgrelid = k.oid AND t.tgname IN ('bt_stamp','bt_supersede','bt_guard')) <> 3
          OR to_regclass(format('%I.%I', s.nspname, k.relname || '_closure')) IS NULL
          OR has_table_privilege('amc_app', format('%I.%I', s.nspname, k.relname || '_closure'), 'UPDATE'));
  IF n <> 0 THEN RAISE EXCEPTION 'C1 FAIL: version tables without the BT triggers or a closed closure table: %', v; END IF;
  SELECT count(*) INTO n
    FROM pg_class k JOIN pg_namespace s ON s.oid = k.relnamespace
   WHERE k.relkind = 'r' AND s.nspname IN ('product','investment','portfolio','trading','execution','settlement')
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = k.oid AND a.attname = 'superseded_at' AND NOT a.attisdropped);
  IF n <> 15 THEN RAISE EXCEPTION 'C1 FAIL: expected 15 version tables in part b, found %', n; END IF;
  PERFORM pg_temp.ok('C1 all 15 version tables of part b have the BT triggers and an insert-only closure table');
END $$;

DO $$
DECLARE n int; v text;
BEGIN
  -- M14: every transition table has exactly one way to be born per state machine ((NEW) rows,
  -- cause CREATE) and is read-only for the application.
  SELECT count(*), string_agg(s.nspname || '.' || k.relname, ', ') INTO n, v
    FROM pg_class k JOIN pg_namespace s ON s.oid = k.relnamespace
   WHERE k.relkind = 'r' AND s.nspname IN ('product','investment','portfolio','trading','execution','settlement')
     AND (k.relname LIKE '%\_transition' OR k.relname = 'instruction_effect')
     AND (has_table_privilege('amc_app', k.oid, 'INSERT') OR has_table_privilege('amc_app', k.oid, 'UPDATE'));
  IF n <> 0 THEN RAISE EXCEPTION 'C2 FAIL: product-level tables writable by amc_app: %', v; END IF;
  FOR v IN SELECT format('%I.%I', s.nspname, k.relname) FROM pg_class k JOIN pg_namespace s ON s.oid = k.relnamespace
            WHERE k.relkind = 'r' AND s.nspname IN ('product','investment','portfolio','trading','execution','settlement')
              AND k.relname LIKE '%\_transition'
  LOOP
    EXECUTE format('SELECT count(*) FROM %s WHERE from_state = ''(NEW)'' AND cause = ''CREATE''', v) INTO n;
    IF n <> 1 THEN RAISE EXCEPTION 'C2 FAIL: % has % initial-state rows, expected 1', v, n; END IF;
  END LOOP;
  -- DM-5: no self-move left in the order transitions.
  SELECT count(*) INTO n FROM trading.order_state_transition WHERE from_state = to_state;
  IF n <> 0 THEN RAISE EXCEPTION 'C2 FAIL: order transitions still have % self-moves', n; END IF;
  PERFORM pg_temp.ok('C2 transition tables: one initial state each, no self-moves, read-only for the application');
END $$;

DO $$
DECLARE n int; v text;
BEGIN
  -- M6: no column called "effective" left in part b's schemas (renamed to valid_period).
  SELECT count(*), string_agg(table_schema || '.' || table_name, ', ') INTO n, v
    FROM information_schema.columns
   WHERE table_schema IN ('product','investment','portfolio','trading','execution','settlement')
     AND column_name = 'effective';
  IF n <> 0 THEN RAISE EXCEPTION 'C3 FAIL: effective columns left: %', v; END IF;
  -- M5: amount columns (scale 4) and quantity columns (scale 6) are at least numeric(24, n).
  SELECT count(*), string_agg(table_schema || '.' || table_name || '.' || column_name || '=' || numeric_precision || ',' || numeric_scale, ', ')
    INTO n, v
    FROM information_schema.columns
   WHERE table_schema IN ('product','investment','portfolio','trading','execution','settlement')
     AND data_type = 'numeric'
     AND (column_name ~ '(amount|quantity|charges|cost_change|brokerage|stt|stamp_duty|gst)')
     AND (numeric_scale NOT IN (4, 6) OR numeric_precision < 24);
  IF n <> 0 THEN RAISE EXCEPTION 'C3 FAIL: amount / quantity columns below the M5 minimum: %', v; END IF;
  PERFORM pg_temp.ok('C3 no "effective" columns left (M6); amounts and quantities meet the M5 minimum');
END $$;

-- =====================================================================
-- Fixtures for tenant A (as the application role)
-- =====================================================================
SET ROLE amc_app;
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO master.issuer (tenant_id, issuer_id) VALUES
 ('00000000-0000-0000-0000-00000000000a','41000000-0000-0000-0000-000000000001');
INSERT INTO master.issuer_version (tenant_id, issuer_id, valid_period, legal_name, issuer_type, approval_request_id) VALUES
 ('00000000-0000-0000-0000-00000000000a','41000000-0000-0000-0000-000000000001','[2026-01-01,)','Alpha Corp Ltd','CORPORATE',
  'f0000000-0000-0000-0000-000000000001');
INSERT INTO master.counterparty (tenant_id, counterparty_id) VALUES
 ('00000000-0000-0000-0000-00000000000a','42000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-00000000000a','42000000-0000-0000-0000-000000000002');
INSERT INTO master.counterparty_version (tenant_id, counterparty_id, valid_period, legal_name, counterparty_type, empanelment_status, approval_request_id) VALUES
 ('00000000-0000-0000-0000-00000000000a','42000000-0000-0000-0000-000000000001','[2026-01-01,)','Broker One Ltd','BROKER','EMPANELLED','f0000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-00000000000a','42000000-0000-0000-0000-000000000002','[2026-01-01,)','Bank One Ltd','BANK','NOT_REQUIRED','f0000000-0000-0000-0000-000000000001');
INSERT INTO product.category (tenant_id, category_code, version_no, name, category_group, valid_period) VALUES
 ('00000000-0000-0000-0000-00000000000a','LARGE_CAP',1,'Large Cap Fund','EQUITY','[2026-01-01,)');
UPDATE product.category SET status = 'PENDING_APPROVAL' WHERE category_code = 'LARGE_CAP';
UPDATE product.category SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000002' WHERE category_code = 'LARGE_CAP';
INSERT INTO execution.broker (tenant_id, broker_id, counterparty_id, broker_code) VALUES
 ('00000000-0000-0000-0000-00000000000a','43000000-0000-0000-0000-000000000001','42000000-0000-0000-0000-000000000001','BRK1');
INSERT INTO execution.broker_version (tenant_id, broker_id, valid_period, empanelment_status, approval_request_id) VALUES
 ('00000000-0000-0000-0000-00000000000a','43000000-0000-0000-0000-000000000001','[2026-01-01,)','EMPANELLED','f0000000-0000-0000-0000-000000000003');
INSERT INTO settlement.trade (tenant_id, trade_id, scheme_id, security_id, side, trade_date, settlement_date, quantity, price,
                              gross_amount, brokerage, net_amount, counterparty_code)
VALUES ('00000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',
        '40000000-0000-0000-0000-000000000001','BUY','2026-11-20','2026-11-21',100,1520.50,152050.0000,15.2050,152065.2050,'BRK1');
INSERT INTO portfolio.portfolio (tenant_id, portfolio_id, scheme_id, portfolio_code, name) VALUES
 ('00000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','MAIN','Main book');
COMMIT;

-- =====================================================================
-- T1  Scheme lifecycle (M14; FR-D02-009, PRD-002 §6)
-- =====================================================================
DO $$
DECLARE n int; s text;
BEGIN
  PERFORM pg_temp.as_a();
  INSERT INTO product.scheme (tenant_id, scheme_id, scheme_code, legal_name, structure)
  VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000002','ALPHA_MID','Alpha Mid Cap Fund','OPEN_ENDED');
  PERFORM pg_temp.expect_fail('T1a a scheme cannot be born ACTIVE',
    $q$INSERT INTO product.scheme (tenant_id, scheme_code, legal_name, structure, lifecycle_state)
       VALUES ('00000000-0000-0000-0000-00000000000a','X','X','OPEN_ENDED','ACTIVE')$q$, '23514', 'ILLEGAL_TRANSITION');
  PERFORM pg_temp.expect_fail('T1b DRAFT -> ACTIVE is refused',
    $q$UPDATE product.scheme SET lifecycle_state = 'ACTIVE' WHERE scheme_id = '30000000-0000-0000-0000-000000000002'$q$, '23514', 'ILLEGAL_TRANSITION');
  FOREACH s IN ARRAY ARRAY['IN_REVIEW','FILED_WITH_SEBI','SEBI_OBSERVATIONS','APPROVED_FOR_LAUNCH','NFO_OPEN','NFO_CLOSED','ALLOTTED','ACTIVE','MERGING']
  LOOP
    UPDATE product.scheme SET lifecycle_state = s WHERE scheme_id = '30000000-0000-0000-0000-000000000002';
  END LOOP;
  PERFORM set_config('app.transition_cause', 'ABANDON_MERGER', true);
  PERFORM pg_temp.expect_fail('T1c an abandoned merger cannot return to a state the scheme did not hold before it',
    $q$UPDATE product.scheme SET lifecycle_state = 'SUSPENDED_SUBSCRIPTIONS' WHERE scheme_id = '30000000-0000-0000-0000-000000000002'$q$,
    '23514', 'ILLEGAL_TRANSITION: an abandoned merger');
  UPDATE product.scheme SET lifecycle_state = 'ACTIVE' WHERE scheme_id = '30000000-0000-0000-0000-000000000002';
  SELECT count(*) INTO n FROM product.scheme_history WHERE scheme_id = '30000000-0000-0000-0000-000000000002';
  IF n <> 11 THEN RAISE EXCEPTION 'T1d FAIL: expected 11 history rows (birth + 10 moves), got %', n; END IF;
  PERFORM pg_temp.ok('T1d launch sequence and abandoned merger write one history row per move, with cause');
END $$;

-- =====================================================================
-- T2  Approved versions (M11, VR): category, scheme version, mandate lines
-- =====================================================================
DO $$
DECLARE v uuid;
BEGIN
  PERFORM pg_temp.as_a();
  INSERT INTO product.category (tenant_id, category_code, version_no, name, category_group, valid_period)
  VALUES ('00000000-0000-0000-0000-00000000000a','MID_CAP',1,'Mid Cap Fund','EQUITY','[2026-01-01,)');
  PERFORM pg_temp.expect_fail('T2a a scheme version may not cite a category version that is not approved',
    $q$INSERT INTO product.scheme_version (tenant_id, scheme_id, version_no, valid_period, primary_benchmark_id, custodian_name, rta_name,
                                           category_code, category_version_no)
       VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001',1,'[2026-12-01,)',
               '20000000-0000-0000-0000-000000000001','Custodian A','CAMS','MID_CAP',1)$q$, '23514', 'CATEGORY_NOT_APPROVED');
  -- The maker is the acting user, whatever is typed in.
  INSERT INTO product.scheme_version (tenant_id, scheme_id, version_no, valid_period, primary_benchmark_id, custodian_name, rta_name,
                                      category_code, category_version_no, maker_user_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001',1,'[2026-12-01,)',
          '20000000-0000-0000-0000-000000000001','Custodian A','CAMS','LARGE_CAP',1,'10000000-0000-0000-0000-000000000004');
  SELECT maker_user_id INTO v FROM product.scheme_version WHERE scheme_id = '30000000-0000-0000-0000-000000000001' AND version_no = 1;
  IF v <> '10000000-0000-0000-0000-000000000002' THEN RAISE EXCEPTION 'T2b FAIL: maker is %, not the acting user', v; END IF;
  PERFORM pg_temp.ok('T2b the maker of a version is the acting user, not a typed-in value');
  INSERT INTO product.scheme_mandate (tenant_id, scheme_id, version_no, line_no, line_kind, asset_class, min_pct, max_pct)
  VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001',1,1,'ASSET_ALLOCATION','LARGE_CAP_EQUITY',80,100);
  UPDATE product.scheme_version SET status = 'PENDING_APPROVAL' WHERE scheme_id = '30000000-0000-0000-0000-000000000001' AND version_no = 1;
  UPDATE product.scheme_version SET status = 'APPROVED', approval_request_id = 'f0000000-0000-0000-0000-000000000004'
   WHERE scheme_id = '30000000-0000-0000-0000-000000000001' AND version_no = 1;
  PERFORM pg_temp.expect_fail('T2c an approved scheme version cannot be edited',
    $q$UPDATE product.scheme_version SET custodian_name = 'Other' WHERE scheme_id = '30000000-0000-0000-0000-000000000001' AND version_no = 1$q$,
    '42501', 'IMMUTABLE_RECORD');
  PERFORM pg_temp.expect_fail('T2d mandate lines of an approved version cannot be added',
    $q$INSERT INTO product.scheme_mandate (tenant_id, scheme_id, version_no, line_no, line_kind, asset_class)
       VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001',1,2,'PERMITTED_INSTRUMENT','DERIVATIVES')$q$,
    '23514', 'PARENT_FROZEN');
  PERFORM pg_temp.expect_fail('T2e mandate lines of an approved version cannot be changed (draft-only guard)',
    $q$UPDATE product.scheme_mandate SET max_pct = 90 WHERE scheme_id = '30000000-0000-0000-0000-000000000001'$q$, '23514', 'PARENT_FROZEN');
  PERFORM pg_temp.expect_fail('T2f a version cannot be born APPROVED (VR lifecycle starts in DRAFT)',
    $q$INSERT INTO product.category (tenant_id, category_code, version_no, name, category_group, valid_period, status, approval_request_id)
       VALUES ('00000000-0000-0000-0000-00000000000a','LARGE_CAP',2,'Large Cap','EQUITY','[2026-06-01,)','APPROVED','f0000000-0000-0000-0000-000000000002')$q$,
    '23514', 'ILLEGAL_TRANSITION');
END $$;

-- =====================================================================
-- T3  Bi-temporal fee schedule (M7, BT-1..BT-4) and exit-load slabs
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO product.fee_schedule (tenant_id, plan_id, fee_type, rate_pct_pa, valid_period, approval_request_id)
VALUES ('00000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-000000000001','TER_TOTAL',1.050000,'[2026-01-01,)','f0000000-0000-0000-0000-000000000005');
COMMIT;
BEGIN;
SELECT pg_temp.as_a();
-- Correction from 1 July: the old version keeps January-June as a continuation (BT-2).
INSERT INTO product.fee_schedule (tenant_id, plan_id, fee_type, rate_pct_pa, valid_period, approval_request_id)
VALUES ('00000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-000000000001','TER_TOTAL',0.950000,'[2026-07-01,)','f0000000-0000-0000-0000-000000000006');
COMMIT;
DO $$
DECLARE n int; r numeric;
BEGIN
  PERFORM pg_temp.as_a();
  SELECT count(*) INTO n FROM product.fee_schedule WHERE plan_id = '31000000-0000-0000-0000-000000000001' AND superseded_at IS NULL;
  IF n <> 2 THEN RAISE EXCEPTION 'T3a FAIL: expected 2 current versions, got %', n; END IF;
  SELECT rate_pct_pa INTO r FROM product.fee_schedule WHERE plan_id = '31000000-0000-0000-0000-000000000001'
     AND superseded_at IS NULL AND valid_period @> date '2026-03-31';
  IF r <> 1.050000 THEN RAISE EXCEPTION 'T3a FAIL: March rate is %, expected 1.05', r; END IF;
  -- As known before the correction, July had the old rate (M7).
  SELECT f.rate_pct_pa INTO r FROM product.fee_schedule f
   WHERE f.plan_id = '31000000-0000-0000-0000-000000000001' AND f.valid_period @> date '2026-07-15'
     AND f.recorded_at <= (SELECT min(recorded_at) FROM product.fee_schedule WHERE plan_id = '31000000-0000-0000-0000-000000000001')
     AND (f.superseded_at IS NULL OR f.superseded_at > (SELECT min(recorded_at) FROM product.fee_schedule WHERE plan_id = '31000000-0000-0000-0000-000000000001'));
  IF r <> 1.050000 THEN RAISE EXCEPTION 'T3a FAIL: as known before the correction, July rate is %', r; END IF;
  PERFORM pg_temp.ok('T3a a correction keeps the earlier months (BT-2) and the old belief stays queryable (M7)');
  PERFORM pg_temp.expect_fail('T3b superseded_at cannot be set by the application',
    $q$UPDATE product.fee_schedule SET superseded_at = now() WHERE plan_id = '31000000-0000-0000-0000-000000000001' AND superseded_at IS NULL$q$,
    '42501', 'IMMUTABLE_RECORD');
END $$;
BEGIN;
SELECT pg_temp.as_a();
-- END the fee from 1 Jan 2027 (BT-3): the open version keeps July-December.
INSERT INTO product.fee_schedule_closure (tenant_id, plan_id, fee_type, closure_kind, end_date, request_id, reason)
VALUES ('00000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-000000000001','TER_TOTAL','END','2027-01-01',
        'f0000000-0000-0000-0000-000000000007','Plan closes');
COMMIT;
DO $$
DECLARE p daterange; who uuid;
BEGIN
  PERFORM pg_temp.as_a();
  SELECT valid_period INTO p FROM product.fee_schedule WHERE plan_id = '31000000-0000-0000-0000-000000000001'
     AND superseded_at IS NULL AND valid_period @> date '2026-12-31';
  IF p <> daterange('2026-07-01','2027-01-01') THEN RAISE EXCEPTION 'T3c FAIL: after END the period is %', p; END IF;
  SELECT closed_by INTO who FROM product.fee_schedule_closure WHERE plan_id = '31000000-0000-0000-0000-000000000001';
  IF who <> '10000000-0000-0000-0000-000000000002' THEN RAISE EXCEPTION 'T3c FAIL: closed_by is %', who; END IF;
  PERFORM pg_temp.ok('T3c an END row closes the key from its date and records who ended it (BT-3)');
  PERFORM pg_temp.expect_fail('T3d two current exit-load slabs of one plan cannot cover the same holding day',
    $q$INSERT INTO product.exit_load_slab (tenant_id, plan_id, valid_period, min_days_held, max_days_held, load_pct, approval_request_id) VALUES
        ('00000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-000000000001','[2026-01-01,)',0,365,1.0,'f0000000-0000-0000-0000-000000000008'),
        ('00000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-000000000001','[2026-01-01,)',180,NULL,0.5,'f0000000-0000-0000-0000-000000000008')$q$,
    '23P01');
END $$;

-- =====================================================================
-- T4  Restricted list as anchor + versions; universe (BT)
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO investment.restricted_list_entry (tenant_id, entry_id, security_id)
VALUES ('00000000-0000-0000-0000-00000000000a','46000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002');
INSERT INTO investment.restricted_list_entry_version (tenant_id, entry_id, valid_period, restriction, reason_code, approval_request_id)
VALUES ('00000000-0000-0000-0000-00000000000a','46000000-0000-0000-0000-000000000001','[2026-11-01,)','BLOCK','UPSI','f0000000-0000-0000-0000-000000000009');
INSERT INTO investment.universe_member (tenant_id, scheme_id, security_id, status, valid_period, approval_request_id)
VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','APPROVED','[2026-01-01,)','f0000000-0000-0000-0000-00000000000a');
COMMIT;
DO $$
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T4a the restricted-list anchor never changes',
    $q$UPDATE investment.restricted_list_entry SET security_id = '40000000-0000-0000-0000-000000000001'$q$, '42501', 'IMMUTABLE_RECORD');
  PERFORM pg_temp.expect_fail('T4b an APPROVED universe member needs its approval reference',
    $q$INSERT INTO investment.universe_member (tenant_id, scheme_id, security_id, status, valid_period)
       VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002','APPROVED','[2026-01-01,)')$q$,
    '23514');
  PERFORM pg_temp.expect_fail('T4c decision records are insert-only (M12)',
    $q$UPDATE investment.decision_record SET rationale = 'changed after the fact, which is not allowed'$q$, '42501');
END $$;

-- =====================================================================
-- T5  Investment committee: agenda and votes
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO investment.ic_meeting (tenant_id, meeting_id, committee_code, meeting_date, chair_user_id)
VALUES ('00000000-0000-0000-0000-00000000000a','47000000-0000-0000-0000-000000000001','IC','2026-11-25','10000000-0000-0000-0000-000000000004');
INSERT INTO investment.ic_agenda_item (tenant_id, meeting_id, item_no, subject)
VALUES ('00000000-0000-0000-0000-00000000000a','47000000-0000-0000-0000-000000000001',1,'Alpha Corp credit limit');
COMMIT;
DO $$
DECLARE v uuid;
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T5a no vote before the meeting is in session',
    $q$INSERT INTO investment.ic_vote (tenant_id, meeting_id, item_no, member_user_id, vote, conflict_declared)
       VALUES ('00000000-0000-0000-0000-00000000000a','47000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000002','FOR',false)$q$,
    '23514', 'PARENT_FROZEN');
  UPDATE investment.ic_meeting SET state = 'IN_SESSION' WHERE meeting_id = '47000000-0000-0000-0000-000000000001';
  INSERT INTO investment.ic_vote (tenant_id, meeting_id, item_no, member_user_id, vote, conflict_declared)
  VALUES ('00000000-0000-0000-0000-00000000000a','47000000-0000-0000-0000-000000000001',1,'10000000-0000-0000-0000-000000000004','FOR',false);
  SELECT member_user_id INTO v FROM investment.ic_vote WHERE meeting_id = '47000000-0000-0000-0000-000000000001';
  IF v <> '10000000-0000-0000-0000-000000000002' THEN RAISE EXCEPTION 'T5b FAIL: vote recorded for %, not the acting user', v; END IF;
  PERFORM pg_temp.ok('T5b a vote is always the acting member''s own');
  PERFORM pg_temp.expect_fail('T5c a vote cannot be changed',
    $q$UPDATE investment.ic_vote SET vote = 'AGAINST'$q$, '42501');
  UPDATE investment.ic_meeting SET state = 'CONCLUDED' WHERE meeting_id = '47000000-0000-0000-0000-000000000001';
  PERFORM pg_temp.expect_fail('T5d agenda items of a concluded meeting cannot change',
    $q$UPDATE investment.ic_agenda_item SET outcome = 'REJECTED' WHERE meeting_id = '47000000-0000-0000-0000-000000000001'$q$,
    '23514', 'PARENT_FROZEN');
END $$;

-- =====================================================================
-- T6  Positions, lots and position events stay in step (checked at COMMIT)
-- =====================================================================
DO $$
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T6a a lot without position events is refused',
    $q$INSERT INTO portfolio.position (tenant_id, portfolio_id, security_id, quantity, cost_amount)
         VALUES ('00000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',100,152065.2050);
       INSERT INTO portfolio.position_lot (tenant_id, portfolio_id, security_id, quantity, cost_amount, acquired_on)
         VALUES ('00000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',100,152065.2050,'2026-11-20')$q$,
    '23514', 'POSITION_OUT_OF_STEP');
END $$;
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO portfolio.position (tenant_id, portfolio_id, security_id, quantity, cost_amount)
VALUES ('00000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',100,152065.2050);
INSERT INTO portfolio.position_lot (tenant_id, lot_id, portfolio_id, security_id, quantity, cost_amount, acquired_on)
VALUES ('00000000-0000-0000-0000-00000000000a','48000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',100,152065.2050,'2026-11-20');
INSERT INTO portfolio.position_event (tenant_id, event_date, lot_id, source_type, source_id, quantity_change, cost_change)
VALUES ('00000000-0000-0000-0000-00000000000a','2026-11-20','48000000-0000-0000-0000-000000000001','TRADE','44000000-0000-0000-0000-000000000001',100,152065.2050);
COMMIT;
DO $$
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.ok('T6b a position, its lot and the event that explains it commit together');
  PERFORM pg_temp.expect_fail('T6c a lot cannot change without an event',
    $q$UPDATE portfolio.position_lot SET quantity = 60 WHERE lot_id = '48000000-0000-0000-0000-000000000001';
       UPDATE portfolio.position SET quantity = 60 WHERE portfolio_id = '45000000-0000-0000-0000-000000000001'$q$,
    '23514', 'POSITION_OUT_OF_STEP');
  PERFORM pg_temp.expect_fail('T6d a position cannot differ from its lots',
    $q$INSERT INTO portfolio.position_event (tenant_id, event_date, lot_id, source_type, source_id, quantity_change, cost_change)
         VALUES ('00000000-0000-0000-0000-00000000000a','2026-12-02','48000000-0000-0000-0000-000000000001','TRADE','44000000-0000-0000-0000-000000000009',-40,-60826.0820);
       UPDATE portfolio.position_lot SET quantity = 60, cost_amount = 91239.1230 WHERE lot_id = '48000000-0000-0000-0000-000000000001'$q$,
    '23514', 'POSITION_OUT_OF_STEP');
  PERFORM pg_temp.expect_fail('T6e position events are insert-only (M12)',
    $q$UPDATE portfolio.position_event SET quantity_change = 1$q$, '42501');
END $$;

-- =====================================================================
-- T7  Snapshot freeze
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO portfolio.snapshot (tenant_id, snapshot_id, scheme_id, as_of_date)
VALUES ('00000000-0000-0000-0000-00000000000a','49000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','2026-11-20');
INSERT INTO portfolio.snapshot_position (tenant_id, as_of_date, snapshot_id, security_id, quantity, settled_quantity, book_cost, price, market_value, pct_net_assets)
VALUES ('00000000-0000-0000-0000-00000000000a','2026-11-20','49000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',
        100,0,152065.2050,1530.00000000,153000.0000,1.00000000);
COMMIT;
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T7a a snapshot cannot be frozen without its content hash',
    $q$UPDATE portfolio.snapshot SET status = 'FROZEN' WHERE snapshot_id = '49000000-0000-0000-0000-000000000001'$q$, '23514');
  UPDATE portfolio.snapshot SET status = 'FROZEN', content_hash = '\x01', frozen_at = now()
   WHERE snapshot_id = '49000000-0000-0000-0000-000000000001';
  PERFORM pg_temp.expect_fail('T7b positions of a frozen snapshot cannot change',
    $q$UPDATE portfolio.snapshot_position SET quantity = 1 WHERE snapshot_id = '49000000-0000-0000-0000-000000000001'$q$,
    '23514', 'PARENT_FROZEN');
  PERFORM pg_temp.expect_fail('T7c a frozen snapshot''s content cannot change',
    $q$UPDATE portfolio.snapshot SET nav_run_id = gen_random_uuid() WHERE snapshot_id = '49000000-0000-0000-0000-000000000001'$q$,
    '42501', 'IMMUTABLE_RECORD');
  SELECT count(*) INTO n FROM portfolio.exposure_view WHERE scheme_id = '30000000-0000-0000-0000-000000000001';
  IF n <> 1 THEN RAISE EXCEPTION 'T7d FAIL: exposure view shows % rows', n; END IF;
  PERFORM pg_temp.ok('T7d the exposure view reads the latest frozen snapshot');
END $$;

-- =====================================================================
-- T8  Orders: versions, amend, re-route (DM-5, DM-6)
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO trading.order (tenant_id, order_id, scheme_id, security_id, side, order_type, quantity, limit_price, decision_id, created_by, trade_date, idempotency_key)
VALUES ('00000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',
        '40000000-0000-0000-0000-000000000001','BUY','LIMIT',500,1500.00,'60000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000002','2026-11-24','idem-t8');
-- A DRAFT order may be edited with a new version and no state move.
UPDATE trading.order SET quantity = 600, order_version = 2 WHERE order_id = '70000000-0000-0000-0000-000000000002';
UPDATE trading.order SET state = 'PENDING_COMPLIANCE' WHERE order_id = '70000000-0000-0000-0000-000000000002';
INSERT INTO trading.compliance_result_ref (tenant_id, order_id, order_version, check_kind, check_result_id, checked_on, outcome)
VALUES ('00000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000002',2,'PRE_TRADE',gen_random_uuid(),'2026-11-24','PASS');
UPDATE trading.order SET state = 'PENDING_APPROVAL' WHERE order_id = '70000000-0000-0000-0000-000000000002';
COMMIT;
DO $$
DECLARE n int; c text;
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T8a changed terms need a new version',
    $q$UPDATE trading.order SET limit_price = 1490 WHERE order_id = '70000000-0000-0000-0000-000000000002'$q$, '23514', 'ILLEGAL_ORDER_CHANGE');
  PERFORM pg_temp.expect_fail('T8b a new version of an order under approval needs cause AMEND',
    $q$UPDATE trading.order SET limit_price = 1490, order_version = 3, state = 'PENDING_COMPLIANCE' WHERE order_id = '70000000-0000-0000-0000-000000000002'$q$,
    '23514');
  PERFORM set_config('app.transition_cause', 'AMEND', true);
  UPDATE trading.order SET limit_price = 1490, order_version = 3, state = 'PENDING_COMPLIANCE'
   WHERE order_id = '70000000-0000-0000-0000-000000000002';
  SELECT count(*) INTO n FROM trading.order_version WHERE order_id = '70000000-0000-0000-0000-000000000002';
  SELECT cause INTO c FROM trading.order_version WHERE order_id = '70000000-0000-0000-0000-000000000002' AND order_version = 3;
  IF n <> 3 OR c <> 'AMEND' THEN RAISE EXCEPTION 'T8c FAIL: % versions, last cause %', n, c; END IF;
  SELECT cause INTO c FROM trading.order_event WHERE order_id = '70000000-0000-0000-0000-000000000002' AND order_version = 3;
  IF c <> 'AMEND' THEN RAISE EXCEPTION 'T8c FAIL: order event cause %', c; END IF;
  PERFORM pg_temp.ok('T8c an amend makes version 3 (CREATE, DRAFT_EDIT, AMEND) and goes back to PENDING_COMPLIANCE');
  PERFORM set_config('app.transition_cause', '', true);
  PERFORM pg_temp.expect_fail('T8d the order''s scheme, security and side never change',
    $q$UPDATE trading.order SET side = 'SELL' WHERE order_id = '70000000-0000-0000-0000-000000000002'$q$, '42501', 'IMMUTABLE_RECORD');
  PERFORM pg_temp.expect_fail('T8e order versions are written only by the order''s trigger',
    $q$INSERT INTO trading.order_version (tenant_id, order_id, order_version, order_type, time_in_force, cause)
       VALUES ('00000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000002',9,'LIMIT','DAY','AMEND')$q$,
    '42501', 'IMMUTABLE_RECORD');
  PERFORM pg_temp.expect_fail('T8f a WARN acknowledgement needs a WARN result for that order version',
    $q$INSERT INTO trading.compliance_result_ref (tenant_id, order_id, order_version, check_kind, check_result_id, checked_on, outcome)
         VALUES ('00000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000002',3,'PRE_TRADE',gen_random_uuid(),'2026-11-24','PASS');
       INSERT INTO trading.warn_acknowledgement (tenant_id, order_id, order_version, check_kind, user_id, reason)
         VALUES ('00000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000002',3,'PRE_TRADE','10000000-0000-0000-0000-000000000002','seen')$q$,
    '23514', 'NOT_A_WARNING');
  -- Version 3 has no result yet: the order cannot leave PENDING_COMPLIANCE on version 2's result.
  PERFORM pg_temp.expect_fail('T8g leaving PENDING_COMPLIANCE needs a pre-trade result for the current version (DM-6)',
    $q$UPDATE trading.order SET state = 'PENDING_APPROVAL' WHERE order_id = '70000000-0000-0000-0000-000000000002'$q$,
    '23514', 'NO_COMPLIANCE_RESULT');
  -- An amend while PENDING_COMPLIANCE (no state move) leaves a version-3 result behind as well.
  PERFORM set_config('app.transition_cause', 'AMEND', true);
  INSERT INTO trading.compliance_result_ref (tenant_id, order_id, order_version, check_kind, check_result_id, checked_on, outcome)
  VALUES ('00000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000002',3,'PRE_TRADE',gen_random_uuid(),'2026-11-24','PASS');
  UPDATE trading.order SET quantity = 50000, order_version = 4 WHERE order_id = '70000000-0000-0000-0000-000000000002';
  PERFORM set_config('app.transition_cause', '', true);
  PERFORM pg_temp.expect_fail('T8h after an amend in PENDING_COMPLIANCE the old version''s result does not let the order through',
    $q$UPDATE trading.order SET state = 'PENDING_APPROVAL' WHERE order_id = '70000000-0000-0000-0000-000000000002'$q$,
    '23514', 'NO_COMPLIANCE_RESULT');
END $$;

-- =====================================================================
-- T9  Fills: de-duplication across partitions (DM-9)
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO execution.fill (tenant_id, executed_at, broker_exec_id, broker_code, order_id, quantity, price)
VALUES ('00000000-0000-0000-0000-00000000000a','2026-11-30 10:00+05:30','EX-1','BRK1','70000000-0000-0000-0000-000000000002',100,1489.5);
COMMIT;
DO $$
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T9a the same broker execution ID is refused in another month''s partition',
    $q$INSERT INTO execution.fill (tenant_id, executed_at, broker_exec_id, broker_code, order_id, quantity, price)
       VALUES ('00000000-0000-0000-0000-00000000000a','2026-12-01 10:00+05:30','EX-1','BRK1','70000000-0000-0000-0000-000000000002',100,1489.5)$q$,
    '23505', 'DUPLICATE_FILL');
  PERFORM pg_temp.expect_fail('T9b de-duplication keys are written only by the fill trigger',
    $q$INSERT INTO execution.fill_dedup_key (tenant_id, broker_code, broker_exec_id, executed_at, fill_id)
       VALUES ('00000000-0000-0000-0000-00000000000a','BRK1','EX-2',now(),gen_random_uuid())$q$, '42501', 'IMMUTABLE_RECORD');
END $$;

-- =====================================================================
-- T10  Outbound instructions: delivery state and business status (§3.5, INT-001 §6)
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO execution.broker_order (tenant_id, broker_order_id, order_id, order_version, broker_id, side, quantity, connection_id,
                                    idempotency_key, client_reference, approval_request_id)
VALUES ('00000000-0000-0000-0000-00000000000a','4a000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000002',3,
        '43000000-0000-0000-0000-000000000001','BUY',600,'4b000000-0000-0000-0000-000000000001','wf-1:send:1','CL-1','f0000000-0000-0000-0000-00000000000b');
COMMIT;
DO $$
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T10a a business status needs an acknowledged delivery',
    $q$UPDATE execution.broker_order SET business_status = 'ACCEPTED' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001'$q$, '23514');
  PERFORM pg_temp.expect_fail('T10b READY -> ACKNOWLEDGED skips SENT and is refused',
    $q$UPDATE execution.broker_order SET delivery_state = 'ACKNOWLEDGED' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001'$q$,
    '23514', 'ILLEGAL_TRANSITION');
  UPDATE execution.broker_order SET delivery_state = 'SENT' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001';
  UPDATE execution.broker_order SET delivery_state = 'UNKNOWN_OUTCOME' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001';
  UPDATE execution.broker_order SET delivery_state = 'READY' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001';
  PERFORM pg_temp.ok('T10c SENT -> UNKNOWN_OUTCOME -> READY (provider confirms not received) is allowed');
  PERFORM pg_temp.expect_fail('T10d the client reference never changes (a resend uses the same key)',
    $q$UPDATE execution.broker_order SET client_reference = 'CL-2' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001'$q$,
    '42501', 'IMMUTABLE_RECORD');
  UPDATE execution.broker_order SET delivery_state = 'SENT' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001';
  UPDATE execution.broker_order SET delivery_state = 'UNKNOWN_OUTCOME' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001';
  PERFORM pg_temp.expect_fail('T10f a leg of unknown outcome cannot be cancelled',
    $q$UPDATE execution.broker_order SET business_status = 'CANCELLED' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001'$q$,
    '23514', 'new row for relation "broker_order" violates check constraint');
  UPDATE execution.broker_order SET delivery_state = 'READY' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001';
  UPDATE execution.broker_order SET business_status = 'CANCELLED' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001';
  PERFORM pg_temp.expect_fail('T10g a cancelled leg can never be sent',
    $q$UPDATE execution.broker_order SET delivery_state = 'SENT' WHERE broker_order_id = '4a000000-0000-0000-0000-000000000001'$q$,
    '23514', 'new row for relation "broker_order" violates check constraint');
  PERFORM pg_temp.expect_fail('T10e attempts are insert-only',
    $q$INSERT INTO execution.broker_order_attempt (tenant_id, broker_order_id, action, outcome, idempotency_key, client_reference)
         VALUES ('00000000-0000-0000-0000-00000000000a','4a000000-0000-0000-0000-000000000001','SEND','SENT','wf-1:send:1','CL-1');
       UPDATE execution.broker_order_attempt SET outcome = 'X'$q$, '42501');
END $$;

-- =====================================================================
-- T11  Settlement record state machine (DM-10, PRD-007 §4.3), SSI call-back, effect map
-- =====================================================================
DO $$
DECLARE n int;
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T11a PENDING_INSTRUCTION -> SETTLED is refused',
    $q$UPDATE settlement.trade SET status = 'SETTLED' WHERE trade_id = '44000000-0000-0000-0000-000000000001'$q$, '23514', 'ILLEGAL_TRANSITION');
  UPDATE settlement.trade SET status = 'INSTRUCTED' WHERE trade_id = '44000000-0000-0000-0000-000000000001';
  UPDATE settlement.trade SET status = 'ACKNOWLEDGED' WHERE trade_id = '44000000-0000-0000-0000-000000000001';
  SELECT count(*) INTO n FROM settlement.settlement_history WHERE trade_id = '44000000-0000-0000-0000-000000000001';
  IF n <> 3 THEN RAISE EXCEPTION 'T11b FAIL: % history rows', n; END IF;
  PERFORM pg_temp.ok('T11b settlement moves follow PRD-007 §4.3 and are recorded in settlement.settlement_history');
  PERFORM pg_temp.expect_fail('T11c the instruction-effect map is read-only for the application',
    $q$INSERT INTO settlement.instruction_effect VALUES ('BUSINESS','REJECTED','FAILED')$q$, '42501');
  PERFORM pg_temp.expect_fail('T11d an SSI version must be called back by someone other than its maker',
    $q$INSERT INTO settlement.ssi (tenant_id, ssi_id, counterparty_id)
         VALUES ('00000000-0000-0000-0000-00000000000a','4c000000-0000-0000-0000-000000000001','42000000-0000-0000-0000-000000000001');
       INSERT INTO settlement.ssi_version (tenant_id, ssi_id, valid_period, market, instrument_class, settlement_details,
                                           callback_by, callback_at, approval_request_id)
         VALUES ('00000000-0000-0000-0000-00000000000a','4c000000-0000-0000-0000-000000000001','[2026-11-01,)','NSE','EQUITY','CM pool a/c',
                 '10000000-0000-0000-0000-000000000002',now(),'f0000000-0000-0000-0000-00000000000c')$q$, '23514', 'BAD_CALLBACK');
  PERFORM pg_temp.expect_fail('T11f a call-back must name an active human user of the tenant',
    $q$INSERT INTO settlement.ssi (tenant_id, ssi_id, counterparty_id)
         VALUES ('00000000-0000-0000-0000-00000000000a','4c000000-0000-0000-0000-000000000002','42000000-0000-0000-0000-000000000001');
       INSERT INTO settlement.ssi_version (tenant_id, ssi_id, valid_period, market, instrument_class, settlement_details,
                                           callback_by, callback_at, approval_request_id)
         VALUES ('00000000-0000-0000-0000-00000000000a','4c000000-0000-0000-0000-000000000002','[2026-11-01,)','NSE','EQUITY','CM pool a/c',
                 gen_random_uuid(),now(),'f0000000-0000-0000-0000-00000000000c')$q$, '23514', 'BAD_CALLBACK');
  PERFORM pg_temp.expect_fail('T11g a call-back by a service identity is refused',
    $q$INSERT INTO settlement.ssi (tenant_id, ssi_id, counterparty_id)
         VALUES ('00000000-0000-0000-0000-00000000000a','4c000000-0000-0000-0000-000000000003','42000000-0000-0000-0000-000000000001');
       INSERT INTO settlement.ssi_version (tenant_id, ssi_id, valid_period, market, instrument_class, settlement_details,
                                           callback_by, callback_at, approval_request_id)
         VALUES ('00000000-0000-0000-0000-00000000000a','4c000000-0000-0000-0000-000000000003','[2026-11-01,)','NSE','EQUITY','CM pool a/c',
                 '10000000-0000-0000-0000-000000000009',now(),'f0000000-0000-0000-0000-00000000000c')$q$, '23514', 'BAD_CALLBACK');
  PERFORM pg_temp.expect_fail('T11e a holding statement is loaded data, never typed in',
    $q$INSERT INTO settlement.scheme_bank_account (tenant_id, account_id, scheme_id, account_type)
         VALUES ('00000000-0000-0000-0000-00000000000a','4d000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','BANK');
       INSERT INTO settlement.holding_statement (tenant_id, statement_date, account_id, statement_kind, amount, approval_request_id)
         VALUES ('00000000-0000-0000-0000-00000000000a','2026-11-20','4d000000-0000-0000-0000-000000000001','BANK_CASH',1000,gen_random_uuid())$q$,
    '23514');
END $$;

DO $$
BEGIN
  PERFORM pg_temp.as_a();
  INSERT INTO settlement.scheme_bank_account (tenant_id, account_id, scheme_id, account_type)
  VALUES ('00000000-0000-0000-0000-00000000000a','4d000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','BANK');
  PERFORM pg_temp.expect_fail('T11h a payment cannot use an account with no version valid on its value date',
    $q$INSERT INTO settlement.payment_instruction (tenant_id, account_id, amount, value_date, connection_id, idempotency_key,
                                                   client_reference, approval_request_id)
       VALUES ('00000000-0000-0000-0000-00000000000a','4d000000-0000-0000-0000-000000000002',1000,'2026-11-25',gen_random_uuid(),
               'wf-p:send:1','PAY-1',gen_random_uuid())$q$, '23514', 'NOT_VALID_ON_DATE');
  INSERT INTO settlement.instruction (tenant_id, instruction_id, trade_id, custodian_code, message_type, client_reference,
                                      connection_id, idempotency_key, approval_request_id)
  VALUES ('00000000-0000-0000-0000-00000000000a','4f000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-000000000001',
          'CUST1','MT541','SI-1',gen_random_uuid(),'wf-s:send:1','f0000000-0000-0000-0000-00000000000d');
  UPDATE settlement.instruction SET business_status = 'CANCELLED' WHERE instruction_id = '4f000000-0000-0000-0000-000000000001';
  PERFORM pg_temp.expect_fail('T11i a cancelled settlement instruction can never be sent',
    $q$UPDATE settlement.instruction SET delivery_state = 'SENT' WHERE instruction_id = '4f000000-0000-0000-0000-000000000001'$q$,
    '23514', 'new row for relation "instruction" violates check constraint');
  PERFORM pg_temp.expect_fail('T11j a settlement instruction needs its approval reference (D-31)',
    $q$INSERT INTO settlement.instruction (tenant_id, trade_id, custodian_code, message_type, client_reference, connection_id, idempotency_key)
       VALUES ('00000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-000000000001','CUST1','MT541','SI-2',gen_random_uuid(),'wf-s:send:2')$q$,
    '23502');
END $$;

-- =====================================================================
-- T12  Performance results only inside their running run (M13)
-- =====================================================================
BEGIN;
SELECT pg_temp.as_a();
INSERT INTO portfolio.performance_run (tenant_id, performance_run_id, period, input_manifest, engine_version)
VALUES ('00000000-0000-0000-0000-00000000000a','4e000000-0000-0000-0000-000000000001','[2026-10-01,2026-11-01)','{"snapshot":"x"}','FE-10@0.1.0');
COMMIT;
DO $$
BEGIN
  PERFORM pg_temp.as_a();
  PERFORM pg_temp.expect_fail('T12a no result before the run is RUNNING',
    $q$INSERT INTO portfolio.performance_result (tenant_id, performance_run_id, scheme_id, period, return_kind, return_value, engine_version)
       VALUES ('00000000-0000-0000-0000-00000000000a','4e000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',
               '[2026-10-01,2026-11-01)','ABSOLUTE',0.0123456789,'FE-10@0.1.0')$q$, '23514', 'PARENT_FROZEN');
  UPDATE portfolio.performance_run SET state = 'RUNNING', started_at = now() WHERE performance_run_id = '4e000000-0000-0000-0000-000000000001';
  PERFORM pg_temp.expect_fail('T12b a result must carry its run''s engine version',
    $q$INSERT INTO portfolio.performance_result (tenant_id, performance_run_id, scheme_id, period, return_kind, return_value, engine_version)
       VALUES ('00000000-0000-0000-0000-00000000000a','4e000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',
               '[2026-10-01,2026-11-01)','ABSOLUTE',0.0123456789,'FE-10@0.2.0')$q$, '23514', 'RUN_MISMATCH');
  PERFORM pg_temp.expect_fail('T12c a started run''s input manifest cannot change',
    $q$UPDATE portfolio.performance_run SET input_manifest = '{}' WHERE performance_run_id = '4e000000-0000-0000-0000-000000000001'$q$,
    '42501', 'IMMUTABLE_RECORD');
END $$;

-- =====================================================================
-- T13  Cross-tenant isolation on new tables (M2)
-- =====================================================================
DO $$
DECLARE n int;
BEGIN
  PERFORM set_config('app.tenant_id', '00000000-0000-0000-0000-00000000000b', true);
  SELECT (SELECT count(*) FROM product.category) + (SELECT count(*) FROM execution.broker)
       + (SELECT count(*) FROM trading.order_version) + (SELECT count(*) FROM portfolio.position_event)
       + (SELECT count(*) FROM settlement.settlement_history) + (SELECT count(*) FROM portfolio.exposure_view) INTO n;
  IF n <> 0 THEN RAISE EXCEPTION 'T13a FAIL: tenant B sees % rows of tenant A', n; END IF;
  PERFORM pg_temp.ok('T13a tenant B sees none of tenant A''s rows in the new tables and the exposure view');
  PERFORM pg_temp.expect_fail('T13b tenant B cannot write a row for tenant A',
    $q$INSERT INTO portfolio.cash_ladder_entry (tenant_id, scheme_id, value_date, flow_type, amount)
       VALUES ('00000000-0000-0000-0000-00000000000a','30000000-0000-0000-0000-000000000001','2026-11-25','INCOME',10)$q$, '42501');
END $$;

RESET ROLE;
-- End of DBT-002.
