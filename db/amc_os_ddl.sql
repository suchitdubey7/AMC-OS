-- =====================================================================
-- AMC OS  -  Core PostgreSQL DDL  (Deliverable Two, Chapter 5)
-- Target: PostgreSQL 16+.  Tested on PostgreSQL 16.15.
-- Run as a superuser / migration owner, in one transaction per section.
--
-- Conventions
--   * UUID keys (gen_random_uuid()).
--   * Every tenant table: tenant_id is the leading key column; RLS forced.
--   * Tenant-aware FKs: child (tenant_id, parent_id) -> parent (tenant_id, id)
--     so a row can never point at another AMC's row.
--   * NUMERIC for all money/units/prices.  No float types anywhere.
--   * DATE for business dates, TIMESTAMPTZ for event times.
--   * row_version for optimistic locking on mutable rows.
--   * Financial facts are insert-only (immutability triggers).
--
-- Migration order (each section depends only on earlier ones):
--   00 extensions, roles, schemas      08 compliance
--   01 platform + helper functions     09 valuation
--   02 identity                        10 accounting
--   03 audit                           11 nav
--   04 master                          12 operations
--   05 product                         13 investor
--   06 workflow                        14 distribution
--   07 investment, portfolio,          15 documents, analytics, ai
--      trading, execution, settlement  16 RLS policies (all tenant tables)
--                                      17 grants, materialized views
-- =====================================================================

-- ---------------------------------------------------------------------
-- 00  Extensions, roles, schemas
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;     -- digest() for audit hash chain
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- exclusion constraints on date ranges

DO $$
BEGIN
  -- Application roles. NOLOGIN group roles; real logins are granted membership.
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'amc_app')      THEN CREATE ROLE amc_app NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'amc_readonly') THEN CREATE ROLE amc_readonly NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'amc_auditor')  THEN CREATE ROLE amc_auditor NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'amc_ai_agent') THEN CREATE ROLE amc_ai_agent NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'amc_platform_admin') THEN CREATE ROLE amc_platform_admin NOLOGIN BYPASSRLS; END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS platform;
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS master;
CREATE SCHEMA IF NOT EXISTS product;
CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS investment;
CREATE SCHEMA IF NOT EXISTS portfolio;
CREATE SCHEMA IF NOT EXISTS trading;
CREATE SCHEMA IF NOT EXISTS execution;
CREATE SCHEMA IF NOT EXISTS settlement;
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE SCHEMA IF NOT EXISTS risk;
CREATE SCHEMA IF NOT EXISTS valuation;
CREATE SCHEMA IF NOT EXISTS accounting;
CREATE SCHEMA IF NOT EXISTS nav;
CREATE SCHEMA IF NOT EXISTS operations;
CREATE SCHEMA IF NOT EXISTS investor;
CREATE SCHEMA IF NOT EXISTS distribution;
CREATE SCHEMA IF NOT EXISTS finance;
CREATE SCHEMA IF NOT EXISTS documents;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS ai;

-- ---------------------------------------------------------------------
-- 01  Platform + shared helper functions
-- ---------------------------------------------------------------------
CREATE TABLE platform.tenant (
  tenant_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_code      text NOT NULL UNIQUE CHECK (tenant_code ~ '^[A-Z0-9_]{3,20}$'),
  legal_name       text NOT NULL,
  sebi_reg_no      text,                                   -- AMC registration number
  isolation_tier   text NOT NULL DEFAULT 'SHARED'
                   CHECK (isolation_tier IN ('SHARED','DEDICATED_DB','DEDICATED_DEPLOYMENT')),
  status           text NOT NULL DEFAULT 'ONBOARDING'
                   CHECK (status IN ('ONBOARDING','ACTIVE','SUSPENDED','OFFBOARDING','ARCHIVED')),
  kms_key_ref      text NOT NULL,                          -- tenant-specific KMS key alias
  data_region      text NOT NULL DEFAULT 'ap-south-1',
  created_at       timestamptz NOT NULL DEFAULT now(),
  row_version      integer NOT NULL DEFAULT 1
);
COMMENT ON TABLE platform.tenant IS 'One row per AMC. The only table without RLS; visible to platform admin only.';

-- Tenant context. The app sets it per transaction:  SET LOCAL app.tenant_id = '<uuid>';
-- If unset, returns NULL and every RLS policy evaluates false (fail closed).
CREATE OR REPLACE FUNCTION platform.current_tenant() RETURNS uuid
LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT NULLIF(current_setting('app.tenant_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION platform.current_user_id() RETURNS uuid
LANGUAGE sql STABLE PARALLEL SAFE AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

-- Generic: bump row_version on UPDATE (optimistic locking).
CREATE OR REPLACE FUNCTION platform.tg_bump_version() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.row_version <> OLD.row_version THEN
    RAISE EXCEPTION 'STALE_ROW_VERSION: expected %, got %', OLD.row_version, NEW.row_version
      USING ERRCODE = '40001';
  END IF;
  NEW.row_version := OLD.row_version + 1;
  NEW.updated_at  := now();
  RETURN NEW;
END $$;

-- Generic: forbid UPDATE/DELETE on insert-only financial tables.
CREATE OR REPLACE FUNCTION platform.tg_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'IMMUTABLE_RECORD: % on %.% is not allowed; post a reversal instead',
    TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME USING ERRCODE = '42501';
END $$;

-- Generic: tenant_id may never change after insert.
CREATE OR REPLACE FUNCTION platform.tg_tenant_fixed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
    RAISE EXCEPTION 'TENANT_CHANGE_FORBIDDEN' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

CREATE TABLE platform.business_calendar (
  tenant_id      uuid NOT NULL REFERENCES platform.tenant,
  calendar_code  text NOT NULL,                 -- e.g. NSE_EQ, NCL_SETTLEMENT, RBI_BANK
  cal_date       date NOT NULL,
  is_business_day boolean NOT NULL,
  description    text,
  PRIMARY KEY (tenant_id, calendar_code, cal_date)
);

-- Transactional outbox: written in the same transaction as the business row.
CREATE TABLE platform.outbox_event (
  tenant_id      uuid NOT NULL,
  event_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  aggregate_type text NOT NULL,               -- e.g. 'trading.order'
  aggregate_id   uuid NOT NULL,
  event_type     text NOT NULL,               -- e.g. 'oms.order.released'
  payload        jsonb NOT NULL,              -- versioned event schema (external contract)
  schema_version integer NOT NULL DEFAULT 1,
  occurred_at    timestamptz NOT NULL DEFAULT now(),
  published_at   timestamptz,
  PRIMARY KEY (tenant_id, event_id)
);
CREATE INDEX outbox_unpublished_ix ON platform.outbox_event (occurred_at) WHERE published_at IS NULL;

CREATE TABLE platform.idempotency_key (
  tenant_id     uuid NOT NULL,
  idem_key      text NOT NULL,
  request_hash  bytea NOT NULL,
  response_code integer,
  response_body jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  expires_at    timestamptz NOT NULL DEFAULT now() + interval '7 days',
  PRIMARY KEY (tenant_id, idem_key)
);

-- ---------------------------------------------------------------------
-- 02  Identity
-- ---------------------------------------------------------------------
CREATE TABLE identity.app_user (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  user_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  external_subject text NOT NULL,              -- IdP subject (SSO)
  email         text NOT NULL,
  display_name  text NOT NULL,
  employee_code text,
  status        text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('INVITED','ACTIVE','LOCKED','DISABLED')),
  is_service_identity boolean NOT NULL DEFAULT false,   -- true for AI agents / jobs
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, user_id),
  UNIQUE (tenant_id, external_subject),
  UNIQUE (tenant_id, email)
);

CREATE TABLE identity.permission (
  permission_code text PRIMARY KEY CHECK (permission_code ~ '^[a-z_]+\.[a-z_]+\.[a-z_]+$'),
  description     text NOT NULL,
  is_approval     boolean NOT NULL DEFAULT false,   -- approve/override/post/publish/execute class
  ai_forbidden    boolean NOT NULL DEFAULT false    -- never grantable to service identities of AI agents
);

CREATE TABLE identity.role (
  tenant_id   uuid NOT NULL REFERENCES platform.tenant,
  role_code   text NOT NULL,                        -- e.g. FUND_MANAGER
  description text NOT NULL,
  PRIMARY KEY (tenant_id, role_code)
);

CREATE TABLE identity.role_permission (
  tenant_id       uuid NOT NULL,
  role_code       text NOT NULL,
  permission_code text NOT NULL REFERENCES identity.permission,
  PRIMARY KEY (tenant_id, role_code, permission_code),
  FOREIGN KEY (tenant_id, role_code) REFERENCES identity.role (tenant_id, role_code)
);

CREATE TABLE identity.user_role (
  tenant_id   uuid NOT NULL,
  user_id     uuid NOT NULL,
  role_code   text NOT NULL,
  scope       jsonb NOT NULL DEFAULT '{}'::jsonb,   -- ABAC limits, e.g. {"scheme_ids":[...]} (controlled config)
  valid_from  date NOT NULL DEFAULT current_date,
  valid_to    date,
  granted_by  uuid NOT NULL,
  approved_by uuid NOT NULL,
  PRIMARY KEY (tenant_id, user_id, role_code, valid_from),
  FOREIGN KEY (tenant_id, user_id)   REFERENCES identity.app_user (tenant_id, user_id),
  FOREIGN KEY (tenant_id, role_code) REFERENCES identity.role (tenant_id, role_code),
  CHECK (granted_by <> approved_by),                                     -- SOD-05
  CHECK (granted_by <> user_id),                                         -- no self-grant
  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

-- ---------------------------------------------------------------------
-- 03  Audit (append-only, hash-chained, monthly partitions)
-- ---------------------------------------------------------------------
CREATE SEQUENCE audit.audit_seq;

CREATE TABLE audit.audit_event (
  tenant_id     uuid NOT NULL,
  event_seq     bigint NOT NULL DEFAULT nextval('audit.audit_seq'),
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  actor_user_id uuid,
  actor_type    text NOT NULL CHECK (actor_type IN ('USER','SERVICE','AI_AGENT','SYSTEM','PLATFORM_OPERATOR')),
  action        text NOT NULL,          -- e.g. 'nav.run.approve'
  object_type   text NOT NULL,
  object_id     uuid,
  reason        text,
  before_state  jsonb,
  after_state   jsonb,
  client_ip     inet,
  correlation_id uuid,
  prev_hash     bytea,
  row_hash      bytea,
  PRIMARY KEY (tenant_id, occurred_at, event_seq)
) PARTITION BY RANGE (occurred_at);

CREATE TABLE audit.audit_event_2026_11 PARTITION OF audit.audit_event
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE audit.audit_event_2026_12 PARTITION OF audit.audit_event
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE audit.audit_event_default PARTITION OF audit.audit_event DEFAULT;

CREATE INDEX audit_object_ix ON audit.audit_event (tenant_id, object_type, object_id, occurred_at);

-- Hash chain per tenant: row_hash = sha256(prev_hash || canonical row text).
-- Serialised per tenant with an advisory xact lock so the chain has no forks.
CREATE OR REPLACE FUNCTION audit.tg_hash_chain() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_prev bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.tenant_id::text, 0));
  SELECT row_hash INTO v_prev
    FROM audit.audit_event
   WHERE tenant_id = NEW.tenant_id
   ORDER BY event_seq DESC LIMIT 1;
  NEW.prev_hash := v_prev;
  NEW.row_hash  := digest(
      coalesce(encode(v_prev,'hex'),'') || '|' || NEW.tenant_id || '|' || NEW.event_seq || '|' ||
      NEW.occurred_at || '|' || coalesce(NEW.actor_user_id::text,'') || '|' || NEW.action || '|' ||
      NEW.object_type || '|' || coalesce(NEW.object_id::text,'') || '|' ||
      coalesce(NEW.before_state::text,'') || '|' || coalesce(NEW.after_state::text,''),
      'sha256');
  RETURN NEW;
END $$;

CREATE TRIGGER audit_hash_chain BEFORE INSERT ON audit.audit_event
  FOR EACH ROW EXECUTE FUNCTION audit.tg_hash_chain();
CREATE TRIGGER audit_immutable BEFORE UPDATE OR DELETE ON audit.audit_event
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- ---------------------------------------------------------------------
-- 04  Master data (tenant-scoped golden records; vendor licences are per AMC)
-- ---------------------------------------------------------------------
CREATE TABLE master.currency (
  currency_code char(3) PRIMARY KEY,
  minor_units   smallint NOT NULL CHECK (minor_units BETWEEN 0 AND 4)
);

CREATE TABLE master.issuer_group (
  tenant_id   uuid NOT NULL REFERENCES platform.tenant,
  group_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  group_name  text NOT NULL,
  is_sponsor_group boolean NOT NULL DEFAULT false,      -- related-party limits
  PRIMARY KEY (tenant_id, group_id)
);

CREATE TABLE master.issuer (
  tenant_id    uuid NOT NULL REFERENCES platform.tenant,
  issuer_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  legal_name   text NOT NULL,
  lei          char(20),
  cin          text,
  group_id     uuid,
  sector_code  text,
  issuer_type  text NOT NULL CHECK (issuer_type IN ('CORPORATE','BANK','NBFC','PSU','CENTRAL_GOVT','STATE_GOVT','MUNICIPAL','FUND','OTHER')),
  valid_from   date NOT NULL DEFAULT current_date,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  row_version  integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, issuer_id),
  FOREIGN KEY (tenant_id, group_id) REFERENCES master.issuer_group (tenant_id, group_id)
);

CREATE TABLE master.security (
  tenant_id        uuid NOT NULL REFERENCES platform.tenant,
  security_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  isin             char(12) NOT NULL CHECK (isin ~ '^[A-Z]{2}[A-Z0-9]{9}[0-9]$'),
  short_name       text NOT NULL,
  instrument_type  text NOT NULL CHECK (instrument_type IN
                    ('EQUITY','PREFERENCE','BOND','NCD','CP','CD','TBILL','GSEC','SDL',
                     'REIT','INVIT','ETF','MF_UNIT','FUTURE','OPTION','TREPS','REPO','DEPOSIT','GOLD','SILVER','OTHER')),
  issuer_id        uuid,
  currency_code    char(3) NOT NULL DEFAULT 'INR' REFERENCES master.currency,
  face_value       numeric(20,6),
  coupon_rate      numeric(9,6),                   -- % p.a.
  maturity_date    date,
  day_count        text CHECK (day_count IN ('ACT/365','ACT/360','30/360','ACT/ACT')),
  lot_size         numeric(20,4) NOT NULL DEFAULT 1 CHECK (lot_size > 0),
  tick_size        numeric(12,6),
  market_cap_class text CHECK (market_cap_class IN ('LARGE','MID','SMALL')),   -- from AMFI list
  status           text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','MATURED','DELISTED')),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  row_version      integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, security_id),
  UNIQUE (tenant_id, isin),
  FOREIGN KEY (tenant_id, issuer_id) REFERENCES master.issuer (tenant_id, issuer_id),
  CHECK (instrument_type NOT IN ('BOND','NCD','CP','CD','TBILL','GSEC','SDL') OR maturity_date IS NOT NULL)
);
CREATE TRIGGER security_version BEFORE UPDATE ON master.security
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

CREATE TABLE master.credit_rating (
  tenant_id    uuid NOT NULL,
  rating_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  security_id  uuid,
  issuer_id    uuid,
  agency       text NOT NULL,
  rating       text NOT NULL,
  outlook      text,
  rating_scale text NOT NULL CHECK (rating_scale IN ('LONG_TERM','SHORT_TERM')),
  valid_from   date NOT NULL,
  valid_to     date,
  recorded_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, rating_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  FOREIGN KEY (tenant_id, issuer_id)   REFERENCES master.issuer (tenant_id, issuer_id),
  CHECK (security_id IS NOT NULL OR issuer_id IS NOT NULL)
);

CREATE TABLE master.benchmark (
  tenant_id     uuid NOT NULL REFERENCES platform.tenant,
  benchmark_id  uuid NOT NULL DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  variant       text NOT NULL CHECK (variant IN ('PRI','TRI')),
  provider      text NOT NULL,
  PRIMARY KEY (tenant_id, benchmark_id)
);

-- ---------------------------------------------------------------------
-- 05  Product & scheme
-- ---------------------------------------------------------------------
CREATE TABLE product.scheme (
  tenant_id       uuid NOT NULL REFERENCES platform.tenant,
  scheme_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_code     text NOT NULL,                 -- internal code
  amfi_scheme_code text,
  legal_name      text NOT NULL,
  structure       text NOT NULL CHECK (structure IN ('OPEN_ENDED','CLOSE_ENDED','INTERVAL')),
  lifecycle_state text NOT NULL DEFAULT 'DRAFT' CHECK (lifecycle_state IN
                   ('DRAFT','IN_REVIEW','FILED_WITH_SEBI','SEBI_OBSERVATIONS','APPROVED_FOR_LAUNCH',
                    'NFO_OPEN','NFO_CLOSED','ALLOTTED','ACTIVE','SUSPENDED_SUBSCRIPTIONS',
                    'MERGING','WOUND_UP','MATURED','CANCELLED')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  row_version     integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, scheme_id),
  UNIQUE (tenant_id, scheme_code)
);
CREATE TRIGGER scheme_version BEFORE UPDATE ON product.scheme
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Effective-dated scheme attributes. Exactly one version per date (exclusion constraint).
CREATE TABLE product.scheme_version (
  tenant_id        uuid NOT NULL,
  scheme_id        uuid NOT NULL,
  version_no       integer NOT NULL CHECK (version_no > 0),
  effective        daterange NOT NULL,
  sebi_category    text NOT NULL,
  sebi_subcategory text,
  primary_benchmark_id uuid NOT NULL,
  custodian_name   text NOT NULL,
  rta_name         text NOT NULL CHECK (rta_name IN ('CAMS','KFINTECH','OTHER')),
  is_fundamental_change boolean NOT NULL DEFAULT false,
  status           text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED','SUPERSEDED','REJECTED')),
  approval_request_id uuid,
  created_by       uuid NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, scheme_id, version_no),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, primary_benchmark_id) REFERENCES master.benchmark (tenant_id, benchmark_id),
  EXCLUDE USING gist (tenant_id WITH =, scheme_id WITH =, effective WITH &&) WHERE (status = 'APPROVED')
);

CREATE TABLE product.plan (
  tenant_id     uuid NOT NULL,
  plan_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid NOT NULL,
  plan_type     text NOT NULL CHECK (plan_type IN ('DIRECT','REGULAR')),
  option_type   text NOT NULL CHECK (option_type IN ('GROWTH','IDCW_PAYOUT','IDCW_REINVEST','IDCW_TRANSFER')),
  isin          char(12) NOT NULL,
  nav_decimals  smallint NOT NULL DEFAULT 4 CHECK (nav_decimals BETWEEN 2 AND 6),     -- VAL with RTA
  unit_decimals smallint NOT NULL DEFAULT 3 CHECK (unit_decimals BETWEEN 2 AND 6),    -- VAL with RTA
  face_value    numeric(12,4) NOT NULL DEFAULT 10,
  PRIMARY KEY (tenant_id, plan_id),
  UNIQUE (tenant_id, isin),
  UNIQUE (tenant_id, scheme_id, plan_type, option_type),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id)
);

CREATE TABLE product.fee_schedule (
  tenant_id     uuid NOT NULL,
  plan_id       uuid NOT NULL,
  fee_type      text NOT NULL CHECK (fee_type IN ('MANAGEMENT_FEE','TER_TOTAL','OTHER_EXPENSES')),
  rate_pct_pa   numeric(9,6) NOT NULL CHECK (rate_pct_pa >= 0 AND rate_pct_pa < 10),
  effective     daterange NOT NULL,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, plan_id, fee_type, effective),
  FOREIGN KEY (tenant_id, plan_id) REFERENCES product.plan (tenant_id, plan_id),
  EXCLUDE USING gist (tenant_id WITH =, plan_id WITH =, fee_type WITH =, effective WITH &&)
);

CREATE TABLE product.exit_load_slab (
  tenant_id     uuid NOT NULL,
  plan_id       uuid NOT NULL,
  effective     daterange NOT NULL,
  min_days_held integer NOT NULL CHECK (min_days_held >= 0),
  max_days_held integer,                              -- NULL = open-ended upper bound
  load_pct      numeric(7,4) NOT NULL CHECK (load_pct >= 0 AND load_pct <= 10),
  PRIMARY KEY (tenant_id, plan_id, effective, min_days_held),
  FOREIGN KEY (tenant_id, plan_id) REFERENCES product.plan (tenant_id, plan_id),
  CHECK (max_days_held IS NULL OR max_days_held > min_days_held)
);

-- ---------------------------------------------------------------------
-- 06  Workflow  (generic maker-checker)
-- ---------------------------------------------------------------------
CREATE TABLE workflow.approval_request (
  tenant_id      uuid NOT NULL REFERENCES platform.tenant,
  request_id     uuid NOT NULL DEFAULT gen_random_uuid(),
  object_type    text NOT NULL,                  -- e.g. 'nav.run'
  object_id      uuid NOT NULL,
  object_version integer NOT NULL DEFAULT 1,
  action         text NOT NULL,                  -- permission code required to approve
  required_approvals smallint NOT NULL DEFAULT 1 CHECK (required_approvals BETWEEN 1 AND 3),
  status         text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED','WITHDRAWN','EXPIRED')),
  maker_user_id  uuid NOT NULL,
  reason         text NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  decided_at     timestamptz,
  PRIMARY KEY (tenant_id, request_id)
);

CREATE TABLE workflow.approval_decision (
  tenant_id     uuid NOT NULL,
  request_id    uuid NOT NULL,
  approver_user_id uuid NOT NULL,
  decision      text NOT NULL CHECK (decision IN ('APPROVE','REJECT')),
  comment       text,
  decided_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, request_id, approver_user_id),
  FOREIGN KEY (tenant_id, request_id) REFERENCES workflow.approval_request (tenant_id, request_id)
);

-- SOD-01: maker can never be checker. Also: AI service identities cannot decide.
CREATE OR REPLACE FUNCTION workflow.tg_check_sod() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_maker uuid; v_is_service boolean;
BEGIN
  SELECT maker_user_id INTO v_maker FROM workflow.approval_request
   WHERE tenant_id = NEW.tenant_id AND request_id = NEW.request_id;
  IF v_maker = NEW.approver_user_id THEN
    RAISE EXCEPTION 'SOD_VIOLATION: maker cannot approve own request' USING ERRCODE = '42501';
  END IF;
  SELECT is_service_identity INTO v_is_service FROM identity.app_user
   WHERE tenant_id = NEW.tenant_id AND user_id = NEW.approver_user_id;
  IF coalesce(v_is_service, true) THEN
    RAISE EXCEPTION 'SOD_VIOLATION: service or unknown identity cannot approve' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER approval_sod BEFORE INSERT ON workflow.approval_decision
  FOR EACH ROW EXECUTE FUNCTION workflow.tg_check_sod();
CREATE TRIGGER approval_decision_immutable BEFORE UPDATE OR DELETE ON workflow.approval_decision
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- ---------------------------------------------------------------------
-- 07a Investment
-- ---------------------------------------------------------------------
CREATE TABLE investment.restricted_list_entry (
  tenant_id     uuid NOT NULL,
  entry_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  security_id   uuid,
  issuer_id     uuid,
  restriction   text NOT NULL CHECK (restriction IN ('BLOCK','WARN')),
  reason_code   text NOT NULL,
  effective     tstzrange NOT NULL,                 -- intraday precision
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, entry_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  FOREIGN KEY (tenant_id, issuer_id)   REFERENCES master.issuer (tenant_id, issuer_id),
  CHECK (security_id IS NOT NULL OR issuer_id IS NOT NULL)
);
CREATE INDEX restricted_active_ix ON investment.restricted_list_entry USING gist (tenant_id, effective);

CREATE TABLE investment.universe_member (
  tenant_id    uuid NOT NULL,
  scheme_id    uuid NOT NULL,
  security_id  uuid NOT NULL,
  status       text NOT NULL CHECK (status IN ('PROPOSED','APPROVED','WATCHLIST','SUSPENDED','REMOVED')),
  effective    daterange NOT NULL,
  approval_request_id uuid,
  PRIMARY KEY (tenant_id, scheme_id, security_id, effective),
  FOREIGN KEY (tenant_id, scheme_id)   REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  EXCLUDE USING gist (tenant_id WITH =, scheme_id WITH =, security_id WITH =, effective WITH &&)
);

CREATE TABLE investment.decision_record (
  tenant_id     uuid NOT NULL,
  decision_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid NOT NULL,
  author_user_id uuid NOT NULL,
  rationale     text NOT NULL CHECK (length(rationale) >= 20),
  decided_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, decision_id),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id)
);

-- ---------------------------------------------------------------------
-- 07b Portfolio (EOD snapshots; immutable once frozen)
-- ---------------------------------------------------------------------
CREATE TABLE portfolio.snapshot (
  tenant_id     uuid NOT NULL,
  snapshot_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid NOT NULL,
  as_of_date    date NOT NULL,
  snapshot_version integer NOT NULL DEFAULT 1,
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','FROZEN','SUPERSEDED')),
  nav_run_id    uuid,
  content_hash  bytea,
  frozen_at     timestamptz,
  PRIMARY KEY (tenant_id, snapshot_id),
  UNIQUE (tenant_id, scheme_id, as_of_date, snapshot_version),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id)
);
CREATE UNIQUE INDEX snapshot_one_frozen_ux ON portfolio.snapshot (tenant_id, scheme_id, as_of_date)
  WHERE status = 'FROZEN';

CREATE TABLE portfolio.snapshot_position (
  tenant_id      uuid NOT NULL,
  as_of_date     date NOT NULL,
  snapshot_id    uuid NOT NULL,
  security_id    uuid NOT NULL,
  quantity       numeric(24,6) NOT NULL,
  settled_quantity numeric(24,6) NOT NULL,
  book_cost      numeric(24,4) NOT NULL,
  price          numeric(24,8) NOT NULL CHECK (price >= 0),
  accrued_interest numeric(24,4) NOT NULL DEFAULT 0,
  market_value   numeric(24,4) NOT NULL,
  pct_net_assets numeric(12,8),
  PRIMARY KEY (tenant_id, as_of_date, snapshot_id, security_id)
) PARTITION BY RANGE (as_of_date);
CREATE TABLE portfolio.snapshot_position_2026 PARTITION OF portfolio.snapshot_position
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE portfolio.snapshot_position_2027 PARTITION OF portfolio.snapshot_position
  FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

-- ---------------------------------------------------------------------
-- 07c Trading (OMS) with enforced state machine
-- ---------------------------------------------------------------------
CREATE TABLE trading.order_state_transition (
  from_state text NOT NULL,
  to_state   text NOT NULL,
  PRIMARY KEY (from_state, to_state)
);
INSERT INTO trading.order_state_transition VALUES
 ('DRAFT','PENDING_COMPLIANCE'),('DRAFT','CANCELLED'),
 ('PENDING_COMPLIANCE','COMPLIANCE_BLOCKED'),('PENDING_COMPLIANCE','PENDING_APPROVAL'),
 ('COMPLIANCE_BLOCKED','OVERRIDE_REQUESTED'),('COMPLIANCE_BLOCKED','CANCELLED'),
 ('OVERRIDE_REQUESTED','OVERRIDE_APPROVED'),('OVERRIDE_REQUESTED','REJECTED'),
 ('OVERRIDE_APPROVED','PENDING_APPROVAL'),
 ('PENDING_APPROVAL','APPROVED'),('PENDING_APPROVAL','REJECTED'),
 ('APPROVED','RELEASED_TO_DESK'),('APPROVED','CANCELLED'),
 ('RELEASED_TO_DESK','ROUTED'),('RELEASED_TO_DESK','CANCEL_REQUESTED'),
 ('ROUTED','PARTIALLY_FILLED'),('ROUTED','FILLED'),('ROUTED','REJECTED_BY_BROKER'),('ROUTED','CANCEL_REQUESTED'),('ROUTED','EXPIRED'),
 ('PARTIALLY_FILLED','PARTIALLY_FILLED'),('PARTIALLY_FILLED','FILLED'),('PARTIALLY_FILLED','CANCEL_REQUESTED'),('PARTIALLY_FILLED','EXPIRED'),
 ('CANCEL_REQUESTED','CANCELLED'),('CANCEL_REQUESTED','PARTIALLY_FILLED'),('CANCEL_REQUESTED','FILLED'),
 ('FILLED','ALLOCATED'),('ALLOCATED','CONFIRMED'),('CONFIRMED','CLOSED');

CREATE TABLE trading.order (
  tenant_id     uuid NOT NULL,
  order_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  order_version integer NOT NULL DEFAULT 1,       -- bumps on amend; compliance result is per version
  scheme_id     uuid NOT NULL,
  security_id   uuid NOT NULL,
  side          text NOT NULL CHECK (side IN ('BUY','SELL')),
  order_type    text NOT NULL CHECK (order_type IN ('MARKET','LIMIT','STOP_LIMIT','VWAP','TWAP','NEGOTIATED','PRIMARY')),
  quantity      numeric(24,6) CHECK (quantity > 0),
  amount        numeric(24,4) CHECK (amount > 0),
  limit_price   numeric(24,8) CHECK (limit_price > 0),
  time_in_force text NOT NULL DEFAULT 'DAY' CHECK (time_in_force IN ('DAY','IOC','GTD')),
  filled_quantity numeric(24,6) NOT NULL DEFAULT 0 CHECK (filled_quantity >= 0),
  state         text NOT NULL DEFAULT 'DRAFT',
  decision_id   uuid NOT NULL,
  created_by    uuid NOT NULL,
  trade_date    date NOT NULL,
  idempotency_key text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, order_id),
  UNIQUE (tenant_id, idempotency_key),
  FOREIGN KEY (tenant_id, scheme_id)   REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  FOREIGN KEY (tenant_id, decision_id) REFERENCES investment.decision_record (tenant_id, decision_id),
  CHECK ((quantity IS NOT NULL) <> (amount IS NOT NULL)),               -- exactly one of qty / amount
  CHECK (order_type NOT IN ('LIMIT','STOP_LIMIT') OR limit_price IS NOT NULL),
  CHECK (quantity IS NULL OR filled_quantity <= quantity)
);
CREATE INDEX order_open_ix ON trading.order (tenant_id, scheme_id, state)
  WHERE state NOT IN ('CLOSED','CANCELLED','REJECTED','EXPIRED','REJECTED_BY_BROKER');
CREATE INDEX order_trade_date_ix ON trading.order (tenant_id, trade_date);

CREATE OR REPLACE FUNCTION trading.tg_order_state() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.state IS DISTINCT FROM OLD.state AND NOT EXISTS (
       SELECT 1 FROM trading.order_state_transition
        WHERE from_state = OLD.state AND to_state = NEW.state) THEN
    RAISE EXCEPTION 'ILLEGAL_ORDER_TRANSITION: % -> %', OLD.state, NEW.state USING ERRCODE = '23514';
  END IF;
  -- Every state change is recorded as an order event (same transaction).
  IF NEW.state IS DISTINCT FROM OLD.state THEN
    INSERT INTO trading.order_event (tenant_id, order_id, order_version, from_state, to_state, actor_user_id)
    VALUES (NEW.tenant_id, NEW.order_id, NEW.order_version, OLD.state, NEW.state, platform.current_user_id());
  END IF;
  RETURN NEW;
END $$;

CREATE TABLE trading.order_event (
  tenant_id     uuid NOT NULL,
  event_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id      uuid NOT NULL,
  order_version integer NOT NULL,
  from_state    text,
  to_state      text NOT NULL,
  actor_user_id uuid,
  detail        jsonb,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, event_id),
  FOREIGN KEY (tenant_id, order_id) REFERENCES trading.order (tenant_id, order_id)
);
CREATE INDEX order_event_order_ix ON trading.order_event (tenant_id, order_id, occurred_at);
CREATE TRIGGER order_event_immutable BEFORE UPDATE OR DELETE ON trading.order_event
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

CREATE TRIGGER order_state_machine BEFORE UPDATE OF state ON trading.order
  FOR EACH ROW EXECUTE FUNCTION trading.tg_order_state();
CREATE TRIGGER order_version BEFORE UPDATE ON trading.order
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();
CREATE TRIGGER order_tenant_fixed BEFORE UPDATE ON trading.order
  FOR EACH ROW EXECUTE FUNCTION platform.tg_tenant_fixed();

CREATE TABLE trading.block_allocation (
  tenant_id     uuid NOT NULL,
  allocation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  block_id      uuid NOT NULL,
  order_id      uuid NOT NULL,
  intent_pct    numeric(9,6) NOT NULL CHECK (intent_pct > 0 AND intent_pct <= 100),
  allocated_quantity numeric(24,6),
  average_price numeric(24,8),
  deviation_approval_id uuid,
  PRIMARY KEY (tenant_id, allocation_id),
  UNIQUE (tenant_id, block_id, order_id),
  FOREIGN KEY (tenant_id, order_id) REFERENCES trading.order (tenant_id, order_id)
);

-- ---------------------------------------------------------------------
-- 07d Execution (fills; monthly partitions; insert-only)
-- ---------------------------------------------------------------------
CREATE TABLE execution.fill (
  tenant_id      uuid NOT NULL,
  executed_at    timestamptz NOT NULL,
  fill_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  broker_exec_id text NOT NULL,                  -- FIX ExecID: idempotency for duplicates
  broker_code    text NOT NULL,
  order_id       uuid NOT NULL,
  block_id       uuid,
  exchange       text,
  quantity       numeric(24,6) NOT NULL CHECK (quantity > 0),
  price          numeric(24,8) NOT NULL CHECK (price > 0),
  raw_message_ref text,                          -- pointer to raw FIX archive
  PRIMARY KEY (tenant_id, executed_at, fill_id),
  UNIQUE (tenant_id, executed_at, broker_code, broker_exec_id)
) PARTITION BY RANGE (executed_at);
CREATE TABLE execution.fill_2026_11 PARTITION OF execution.fill FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE execution.fill_2026_12 PARTITION OF execution.fill FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE execution.fill_default PARTITION OF execution.fill DEFAULT;
CREATE INDEX fill_order_ix ON execution.fill (tenant_id, order_id);
CREATE TRIGGER fill_immutable BEFORE UPDATE OR DELETE ON execution.fill
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- ---------------------------------------------------------------------
-- 07e Settlement
-- ---------------------------------------------------------------------
CREATE TABLE settlement.trade (
  tenant_id      uuid NOT NULL,
  trade_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id       uuid,                           -- NULL for externally booked trades (IPO, ITT)
  scheme_id      uuid NOT NULL,
  security_id    uuid NOT NULL,
  side           text NOT NULL CHECK (side IN ('BUY','SELL')),
  trade_date     date NOT NULL,
  settlement_date date NOT NULL,
  quantity       numeric(24,6) NOT NULL CHECK (quantity > 0),
  price          numeric(24,8) NOT NULL CHECK (price > 0),
  gross_amount   numeric(24,4) NOT NULL,
  brokerage      numeric(20,4) NOT NULL DEFAULT 0 CHECK (brokerage >= 0),
  stt            numeric(20,4) NOT NULL DEFAULT 0 CHECK (stt >= 0),
  stamp_duty     numeric(20,4) NOT NULL DEFAULT 0 CHECK (stamp_duty >= 0),
  gst            numeric(20,4) NOT NULL DEFAULT 0 CHECK (gst >= 0),
  other_charges  numeric(20,4) NOT NULL DEFAULT 0 CHECK (other_charges >= 0),
  net_amount     numeric(24,4) NOT NULL,
  accrued_interest numeric(24,4) NOT NULL DEFAULT 0,
  counterparty_code text NOT NULL,
  status         text NOT NULL DEFAULT 'PENDING_INSTRUCTION' CHECK (status IN
                  ('PENDING_INSTRUCTION','INSTRUCTED','ACKNOWLEDGED','MATCHED','SETTLED',
                   'PARTIALLY_SETTLED','FAILED','RE_INSTRUCTED','BOUGHT_IN','CLOSED_OUT','CANCELLED')),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  row_version    integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, trade_id),
  FOREIGN KEY (tenant_id, scheme_id)   REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, security_id) REFERENCES master.security (tenant_id, security_id),
  CHECK (settlement_date >= trade_date),
  CHECK (gross_amount = round(quantity * price, 4)),
  CHECK (net_amount = CASE side
          WHEN 'BUY'  THEN gross_amount + brokerage + stt + stamp_duty + gst + other_charges
          ELSE              gross_amount - brokerage - stt - stamp_duty - gst - other_charges END)
);
CREATE INDEX trade_settle_ix ON settlement.trade (tenant_id, settlement_date, status);
CREATE TRIGGER trade_version BEFORE UPDATE ON settlement.trade
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

CREATE TABLE settlement.instruction (
  tenant_id      uuid NOT NULL,
  instruction_id uuid NOT NULL DEFAULT gen_random_uuid(),
  trade_id       uuid NOT NULL,
  custodian_code text NOT NULL,
  message_type   text NOT NULL,                  -- e.g. MT540..MT543 / sese.023
  instruction_ref text NOT NULL,
  sent_at        timestamptz,
  status         text NOT NULL DEFAULT 'CREATED' CHECK (status IN ('CREATED','SENT','ACK','NACK','MATCHED','SETTLED','FAILED','CANCELLED')),
  status_reason  text,
  PRIMARY KEY (tenant_id, instruction_id),
  UNIQUE (tenant_id, custodian_code, instruction_ref),
  FOREIGN KEY (tenant_id, trade_id) REFERENCES settlement.trade (tenant_id, trade_id)
);

-- ---------------------------------------------------------------------
-- 08  Compliance (rules as versioned data)
-- ---------------------------------------------------------------------
CREATE TABLE compliance.regulation (
  tenant_id       uuid NOT NULL,          -- shared corpus is copied per tenant for tenant-specific status
  regulation_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  source          text NOT NULL,          -- SEBI, AMFI, RBI, MeitY, INTERNAL_POLICY
  document_title  text NOT NULL,
  reference       text NOT NULL,
  published_on    date,
  effective_on    date,
  domain          text NOT NULL,
  system_control  text,
  responsible_dept text NOT NULL,
  validation_requirement text,
  verification_status text NOT NULL CHECK (verification_status IN
                  ('UNVERIFIED','DOCUMENT_VERIFIED','CLAUSES_MAPPED','LEGAL_VALIDATED','SUPERSEDED')),
  classification  text NOT NULL CHECK (classification IN ('REG','IND','DES','VAL')),
  source_url      text,
  PRIMARY KEY (tenant_id, regulation_id)
);

CREATE TABLE compliance.rule (
  tenant_id     uuid NOT NULL,
  rule_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  rule_code     text NOT NULL,                       -- e.g. SINGLE_ISSUER_EQUITY
  regulation_id uuid NOT NULL,
  rule_class    text NOT NULL CHECK (rule_class IN ('REGULATORY','MANDATE','INTERNAL_RISK')),
  PRIMARY KEY (tenant_id, rule_id),
  UNIQUE (tenant_id, rule_code),
  FOREIGN KEY (tenant_id, regulation_id) REFERENCES compliance.regulation (tenant_id, regulation_id)
);

CREATE TABLE compliance.rule_version (
  tenant_id     uuid NOT NULL,
  rule_id       uuid NOT NULL,
  version_no    integer NOT NULL CHECK (version_no > 0),
  definition    jsonb NOT NULL,          -- typed rule DSL (validated by JSON schema in the service)
  severity      text NOT NULL CHECK (severity IN ('BLOCK','WARN','INFO')),
  timing        text NOT NULL CHECK (timing IN ('PRE','POST','BOTH')),
  effective     daterange NOT NULL,
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','TESTED','APPROVED','RETIRED','REJECTED')),
  tests_passed  boolean NOT NULL DEFAULT false,
  author_user_id uuid NOT NULL,
  approval_request_id uuid,
  PRIMARY KEY (tenant_id, rule_id, version_no),
  FOREIGN KEY (tenant_id, rule_id) REFERENCES compliance.rule (tenant_id, rule_id),
  CHECK (status <> 'APPROVED' OR (tests_passed AND approval_request_id IS NOT NULL)),
  EXCLUDE USING gist (tenant_id WITH =, rule_id WITH =, effective WITH &&) WHERE (status = 'APPROVED')
);

CREATE TABLE compliance.rule_parameter (
  tenant_id     uuid NOT NULL,
  rule_id       uuid NOT NULL,
  version_no    integer NOT NULL,
  param_name    text NOT NULL,                     -- e.g. 'max_pct_net_assets'
  scope_key     text NOT NULL DEFAULT '*',         -- '*' or category/scheme code
  param_value   numeric(20,8) NOT NULL,
  PRIMARY KEY (tenant_id, rule_id, version_no, param_name, scope_key),
  FOREIGN KEY (tenant_id, rule_id, version_no) REFERENCES compliance.rule_version (tenant_id, rule_id, version_no)
);

CREATE TABLE compliance.check_result (
  tenant_id     uuid NOT NULL,
  checked_on    date NOT NULL,
  result_id     uuid NOT NULL DEFAULT gen_random_uuid(),
  check_kind    text NOT NULL CHECK (check_kind IN ('PRE_TRADE','POST_TRADE','WHAT_IF')),
  scheme_id     uuid NOT NULL,
  order_id      uuid,
  order_version integer,
  rule_id       uuid NOT NULL,
  rule_version  integer NOT NULL,
  outcome       text NOT NULL CHECK (outcome IN ('PASS','WARN','BLOCK','INDETERMINATE')),
  measured_value numeric(24,8),
  threshold_value numeric(24,8),
  input_hash    bytea NOT NULL,
  evaluated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, checked_on, result_id)
) PARTITION BY RANGE (checked_on);
CREATE TABLE compliance.check_result_2026 PARTITION OF compliance.check_result FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE compliance.check_result_2027 PARTITION OF compliance.check_result FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE INDEX check_result_order_ix ON compliance.check_result (tenant_id, order_id, order_version) WHERE order_id IS NOT NULL;
CREATE TRIGGER check_result_immutable BEFORE UPDATE OR DELETE ON compliance.check_result
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

CREATE TABLE compliance.breach (
  tenant_id     uuid NOT NULL,
  breach_id     uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid NOT NULL,
  rule_id       uuid NOT NULL,
  rule_version  integer NOT NULL,
  breach_type   text NOT NULL CHECK (breach_type IN ('ACTIVE','PASSIVE')),
  detected_on   date NOT NULL,
  cure_deadline date,
  status        text NOT NULL DEFAULT 'OPEN' CHECK (status IN
                 ('OPEN','ACKNOWLEDGED','PLAN_SUBMITTED','PLAN_APPROVED','CURED','ESCALATED','REGULARISED','RESOLVED')),
  owner_user_id uuid,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, breach_id),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, rule_id, rule_version) REFERENCES compliance.rule_version (tenant_id, rule_id, version_no)
);

-- ---------------------------------------------------------------------
-- 09  Valuation
-- ---------------------------------------------------------------------
CREATE TABLE valuation.price (
  tenant_id     uuid NOT NULL,
  price_date    date NOT NULL,
  security_id   uuid NOT NULL,
  price_source  text NOT NULL,                -- NSE, BSE, VALUATION_AGENCY_1, OVERRIDE ...
  price_type    text NOT NULL CHECK (price_type IN ('CLOSE','YIELD_BASED','FAIR_VALUE','NAV','OVERRIDE')),
  price         numeric(24,8) NOT NULL CHECK (price >= 0),
  yield_pct     numeric(12,8),
  is_validated  boolean NOT NULL DEFAULT false,
  validation_flags text[] NOT NULL DEFAULT '{}',
  loaded_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, price_date, security_id, price_source)
) PARTITION BY RANGE (price_date);
CREATE TABLE valuation.price_2026 PARTITION OF valuation.price FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE valuation.price_2027 PARTITION OF valuation.price FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TRIGGER price_immutable BEFORE DELETE ON valuation.price
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- ---------------------------------------------------------------------
-- 10  Accounting (double entry, insert-only, balanced batches)
-- ---------------------------------------------------------------------
CREATE TABLE accounting.account (
  tenant_id     uuid NOT NULL,
  account_code  text NOT NULL,
  account_name  text NOT NULL,
  account_class text NOT NULL CHECK (account_class IN ('ASSET','LIABILITY','UNIT_CAPITAL','RESERVE','INCOME','EXPENSE')),
  normal_balance char(1) NOT NULL CHECK (normal_balance IN ('D','C')),
  is_postable   boolean NOT NULL DEFAULT true,
  parent_code   text,
  PRIMARY KEY (tenant_id, account_code),
  FOREIGN KEY (tenant_id, parent_code) REFERENCES accounting.account (tenant_id, account_code)
);

CREATE TABLE accounting.period (
  tenant_id     uuid NOT NULL,
  scheme_id     uuid NOT NULL,
  period_type   text NOT NULL CHECK (period_type IN ('DAY','MONTH','HALF_YEAR','YEAR')),
  period_range  daterange NOT NULL,
  status        text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','SOFT_CLOSED','CLOSED','REOPENED')),
  closed_by     uuid,
  closed_at     timestamptz,
  PRIMARY KEY (tenant_id, scheme_id, period_type, period_range),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id)
);

CREATE TABLE accounting.journal_batch (
  tenant_id       uuid NOT NULL,
  batch_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id       uuid NOT NULL,
  accounting_date date NOT NULL,
  source_type     text NOT NULL,              -- 'settlement.trade', 'accrual.run', 'manual', 'reversal' ...
  source_id       uuid,
  posting_rule_version text,
  is_manual       boolean NOT NULL DEFAULT false,
  reverses_batch_id uuid,
  approval_request_id uuid,
  posted_by       uuid NOT NULL,
  posted_at       timestamptz NOT NULL DEFAULT now(),
  idempotency_key text NOT NULL,
  PRIMARY KEY (tenant_id, batch_id),
  UNIQUE (tenant_id, idempotency_key),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, reverses_batch_id) REFERENCES accounting.journal_batch (tenant_id, batch_id),
  CHECK (NOT is_manual OR approval_request_id IS NOT NULL)                 -- manual journals always MC
);

CREATE TABLE accounting.journal_line (
  tenant_id       uuid NOT NULL,
  accounting_date date NOT NULL,
  line_id         uuid NOT NULL DEFAULT gen_random_uuid(),
  batch_id        uuid NOT NULL,
  scheme_id       uuid NOT NULL,
  plan_id         uuid,
  account_code    text NOT NULL,
  dr_cr           char(1) NOT NULL CHECK (dr_cr IN ('D','C')),
  amount          numeric(24,4) NOT NULL CHECK (amount > 0),
  currency_code   char(3) NOT NULL DEFAULT 'INR',
  security_id     uuid,
  counterparty_code text,
  narration       text,
  PRIMARY KEY (tenant_id, accounting_date, line_id),
  FOREIGN KEY (tenant_id, batch_id)     REFERENCES accounting.journal_batch (tenant_id, batch_id),
  FOREIGN KEY (tenant_id, account_code) REFERENCES accounting.account (tenant_id, account_code)
) PARTITION BY RANGE (accounting_date);
CREATE TABLE accounting.journal_line_2026_11 PARTITION OF accounting.journal_line FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE accounting.journal_line_2026_12 PARTITION OF accounting.journal_line FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE accounting.journal_line_default PARTITION OF accounting.journal_line DEFAULT;
CREATE INDEX journal_line_batch_ix ON accounting.journal_line (tenant_id, batch_id);
CREATE INDEX journal_line_tb_ix ON accounting.journal_line (tenant_id, scheme_id, account_code, accounting_date) INCLUDE (dr_cr, amount);

CREATE TRIGGER journal_batch_immutable BEFORE UPDATE OR DELETE ON accounting.journal_batch
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();
CREATE TRIGGER journal_line_immutable BEFORE UPDATE OR DELETE ON accounting.journal_line
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

-- Batch must balance per scheme & currency, and must not post into a CLOSED period.
-- Deferred constraint trigger: checked once at COMMIT, after all lines are inserted.
CREATE OR REPLACE FUNCTION accounting.tg_check_batch() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_diff numeric; v_closed boolean; v_scheme uuid; v_date date;
BEGIN
  SELECT sum(CASE dr_cr WHEN 'D' THEN amount ELSE -amount END)
    INTO v_diff
    FROM accounting.journal_line
   WHERE tenant_id = NEW.tenant_id AND batch_id = NEW.batch_id;
  IF coalesce(v_diff, 0) <> 0 THEN
    RAISE EXCEPTION 'UNBALANCED_BATCH: batch % differs by %', NEW.batch_id, v_diff USING ERRCODE = '23514';
  END IF;
  IF EXISTS (SELECT 1 FROM accounting.journal_line
              WHERE tenant_id = NEW.tenant_id AND batch_id = NEW.batch_id
                AND (scheme_id <> NEW.scheme_id OR accounting_date <> NEW.accounting_date)) THEN
    RAISE EXCEPTION 'BATCH_LINE_MISMATCH: all lines must share batch scheme and date' USING ERRCODE = '23514';
  END IF;
  SELECT EXISTS (SELECT 1 FROM accounting.period p
                  WHERE p.tenant_id = NEW.tenant_id AND p.scheme_id = NEW.scheme_id
                    AND p.status = 'CLOSED' AND p.period_range @> NEW.accounting_date)
    INTO v_closed;
  IF v_closed THEN
    RAISE EXCEPTION 'PERIOD_CLOSED: % for scheme %', NEW.accounting_date, NEW.scheme_id USING ERRCODE = '23514';
  END IF;
  RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER journal_batch_balanced
  AFTER INSERT ON accounting.journal_batch
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION accounting.tg_check_batch();

-- Trial balance as a function (any scheme, any date) - deterministic.
CREATE OR REPLACE FUNCTION accounting.trial_balance(p_scheme uuid, p_as_of date)
RETURNS TABLE (account_code text, debit numeric, credit numeric, net numeric)
LANGUAGE sql STABLE AS $$
  SELECT jl.account_code,
         sum(amount) FILTER (WHERE dr_cr = 'D'),
         sum(amount) FILTER (WHERE dr_cr = 'C'),
         sum(CASE dr_cr WHEN 'D' THEN amount ELSE -amount END)
    FROM accounting.journal_line jl
   WHERE jl.tenant_id = platform.current_tenant()
     AND jl.scheme_id = p_scheme
     AND jl.accounting_date <= p_as_of
   GROUP BY jl.account_code
   ORDER BY jl.account_code
$$;

-- ---------------------------------------------------------------------
-- 11  NAV
-- ---------------------------------------------------------------------
CREATE TABLE nav.nav_run (
  tenant_id     uuid NOT NULL,
  nav_run_id    uuid NOT NULL DEFAULT gen_random_uuid(),
  scheme_id     uuid NOT NULL,
  nav_date      date NOT NULL,
  run_no        integer NOT NULL DEFAULT 1,
  run_kind      text NOT NULL DEFAULT 'REGULAR' CHECK (run_kind IN ('REGULAR','CORRECTION','RECONSTRUCTION')),
  corrects_run_id uuid,
  state         text NOT NULL DEFAULT 'INITIATED' CHECK (state IN
                 ('INITIATED','DATA_COLLECTED','CALCULATED','VALIDATION_FAILED','VALIDATED',
                  'PENDING_APPROVAL','APPROVED','PUBLISHING','PUBLISHED','SUPERSEDED','CANCELLED')),
  prepared_by   uuid NOT NULL,
  approved_by   uuid,
  approved_at   timestamptz,
  input_manifest jsonb,               -- versions/hashes of TB, prices, snapshot, units, rules
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, nav_run_id),
  UNIQUE (tenant_id, scheme_id, nav_date, run_no),
  FOREIGN KEY (tenant_id, scheme_id) REFERENCES product.scheme (tenant_id, scheme_id),
  FOREIGN KEY (tenant_id, corrects_run_id) REFERENCES nav.nav_run (tenant_id, nav_run_id),
  CHECK (approved_by IS NULL OR approved_by <> prepared_by),            -- SOD-02
  CHECK (state NOT IN ('APPROVED','PUBLISHING','PUBLISHED') OR approved_by IS NOT NULL),
  CHECK (run_kind <> 'CORRECTION' OR corrects_run_id IS NOT NULL)
);
-- Only one live (approved/published) run per scheme per date.
CREATE UNIQUE INDEX nav_run_one_live_ux ON nav.nav_run (tenant_id, scheme_id, nav_date)
  WHERE state IN ('APPROVED','PUBLISHING','PUBLISHED');
CREATE TRIGGER nav_run_version BEFORE UPDATE ON nav.nav_run
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

-- Published runs may only move to SUPERSEDED; nothing else may change.
CREATE OR REPLACE FUNCTION nav.tg_nav_run_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.state = 'PUBLISHED' AND NOT (NEW.state = 'SUPERSEDED'
       AND NEW.approved_by = OLD.approved_by AND NEW.input_manifest = OLD.input_manifest) THEN
    RAISE EXCEPTION 'PUBLISHED_NAV_IMMUTABLE' USING ERRCODE = '42501';
  END IF;
  IF OLD.state IN ('SUPERSEDED','CANCELLED') THEN
    RAISE EXCEPTION 'TERMINAL_NAV_STATE: %', OLD.state USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER nav_run_guard BEFORE UPDATE ON nav.nav_run
  FOR EACH ROW EXECUTE FUNCTION nav.tg_nav_run_guard();

CREATE TABLE nav.nav_result (
  tenant_id       uuid NOT NULL,
  nav_run_id      uuid NOT NULL,
  plan_id         uuid NOT NULL,
  nav_date        date NOT NULL,
  total_assets    numeric(26,4) NOT NULL CHECK (total_assets >= 0),
  total_liabilities numeric(26,4) NOT NULL CHECK (total_liabilities >= 0),
  net_assets      numeric(26,4) GENERATED ALWAYS AS (total_assets - total_liabilities) STORED,
  units_outstanding numeric(26,6) NOT NULL CHECK (units_outstanding > 0),
  nav_unrounded   numeric(30,12) NOT NULL,
  nav_per_unit    numeric(20,6) NOT NULL CHECK (nav_per_unit > 0),
  PRIMARY KEY (tenant_id, nav_run_id, plan_id),
  FOREIGN KEY (tenant_id, nav_run_id) REFERENCES nav.nav_run (tenant_id, nav_run_id),
  FOREIGN KEY (tenant_id, plan_id) REFERENCES product.plan (tenant_id, plan_id),
  CHECK (nav_unrounded = round((total_assets - total_liabilities) / units_outstanding, 12)),
  CHECK (nav_per_unit = round(nav_unrounded, 6) OR nav_per_unit = round(nav_unrounded, 4) OR nav_per_unit = round(nav_unrounded, 2))  -- rounding only at the final step
);
CREATE INDEX nav_result_plan_date_ix ON nav.nav_result (tenant_id, plan_id, nav_date);
CREATE TRIGGER nav_result_immutable BEFORE UPDATE OR DELETE ON nav.nav_result
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

CREATE TABLE nav.nav_validation (
  tenant_id     uuid NOT NULL,
  nav_run_id    uuid NOT NULL,
  check_code    text NOT NULL,      -- TB_BALANCED, DOD_VS_BENCHMARK, PRICES_VALIDATED, UNITS_RECONCILED ...
  outcome       text NOT NULL CHECK (outcome IN ('PASS','FAIL','WAIVED')),
  detail        jsonb,
  waiver_approval_id uuid,
  checked_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, nav_run_id, check_code),
  FOREIGN KEY (tenant_id, nav_run_id) REFERENCES nav.nav_run (tenant_id, nav_run_id),
  CHECK (outcome <> 'WAIVED' OR waiver_approval_id IS NOT NULL)
);

CREATE TABLE nav.nav_publication (
  tenant_id     uuid NOT NULL,
  nav_run_id    uuid NOT NULL,
  channel       text NOT NULL CHECK (channel IN ('RTA','AMFI','WEBSITE','EXCHANGE','DISTRIBUTOR_FEED')),
  status        text NOT NULL CHECK (status IN ('PENDING','SENT','ACKNOWLEDGED','FAILED')),
  attempt_no    integer NOT NULL DEFAULT 1,
  ack_reference text,
  sent_at       timestamptz,
  PRIMARY KEY (tenant_id, nav_run_id, channel, attempt_no),
  FOREIGN KEY (tenant_id, nav_run_id) REFERENCES nav.nav_run (tenant_id, nav_run_id)
);

-- ---------------------------------------------------------------------
-- 12  Operations (reconciliation)
-- ---------------------------------------------------------------------
CREATE TABLE operations.inbound_file (
  tenant_id     uuid NOT NULL,
  file_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  sender        text NOT NULL,
  file_type     text NOT NULL,
  business_date date NOT NULL,
  object_key    text NOT NULL,             -- raw file in object storage (never altered)
  sha256        bytea NOT NULL,
  received_at   timestamptz NOT NULL DEFAULT now(),
  parse_status  text NOT NULL DEFAULT 'RECEIVED' CHECK (parse_status IN ('RECEIVED','PARSED','QUARANTINED','DUPLICATE')),
  PRIMARY KEY (tenant_id, file_id),
  UNIQUE (tenant_id, sender, business_date, sha256)              -- duplicate detection
);

CREATE TABLE operations.recon_run (
  tenant_id     uuid NOT NULL,
  recon_run_id  uuid NOT NULL DEFAULT gen_random_uuid(),
  recon_type    text NOT NULL CHECK (recon_type IN ('HOLDINGS','CASH','TRADES','UNITS','NAV','FEES','COMMISSION')),
  scheme_id     uuid,
  business_date date NOT NULL,
  definition_version integer NOT NULL,
  matched_count integer NOT NULL DEFAULT 0,
  break_count   integer NOT NULL DEFAULT 0,
  status        text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','COMPLETE','FAILED')),
  started_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, recon_run_id)
);

CREATE TABLE operations.recon_break (
  tenant_id     uuid NOT NULL,
  break_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  recon_run_id  uuid NOT NULL,
  break_type    text NOT NULL,             -- QTY_MISMATCH, MISSING_IN_CUSTODIAN, CHARGE_MISMATCH ...
  business_key  text NOT NULL,
  our_value     numeric(26,6),
  their_value   numeric(26,6),
  difference    numeric(26,6) GENERATED ALWAYS AS (our_value - their_value) STORED,
  status        text NOT NULL DEFAULT 'OPEN' CHECK (status IN
                 ('OPEN','ASSIGNED','INVESTIGATING','PROPOSED_RESOLUTION','RESOLVED','WRITTEN_OFF','AUTO_CLEARED')),
  owner_user_id uuid,
  resolution_approval_id uuid,
  opened_at     timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz,
  PRIMARY KEY (tenant_id, break_id),
  FOREIGN KEY (tenant_id, recon_run_id) REFERENCES operations.recon_run (tenant_id, recon_run_id),
  CHECK (status <> 'WRITTEN_OFF' OR resolution_approval_id IS NOT NULL)
);
CREATE INDEX recon_break_open_ix ON operations.recon_break (tenant_id, status, opened_at)
  WHERE status NOT IN ('RESOLVED','WRITTEN_OFF','AUTO_CLEARED');

-- ---------------------------------------------------------------------
-- 13  Investor (PII encrypted at application layer; heavy partitioning)
-- ---------------------------------------------------------------------
CREATE TABLE investor.investor (
  tenant_id     uuid NOT NULL,
  investor_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  investor_type text NOT NULL CHECK (investor_type IN ('INDIVIDUAL','HUF','COMPANY','TRUST','PARTNERSHIP','FPI','OTHER')),
  pan_ciphertext bytea NOT NULL,           -- AES-256-GCM with tenant key (envelope encryption in app/KMS)
  pan_hmac      bytea NOT NULL,            -- HMAC-SHA256(tenant secret, PAN) for exact-match lookup
  pan_last4     char(4) NOT NULL,          -- display mask only
  name_ciphertext bytea NOT NULL,
  tax_status    text NOT NULL,
  residency     text NOT NULL CHECK (residency IN ('RESIDENT','NRI','FOREIGN')),
  kyc_status    text NOT NULL CHECK (kyc_status IN ('VALIDATED','REGISTERED','ON_HOLD','REJECTED','PENDING')),
  kyc_source    text,
  ckyc_number_ciphertext bytea,
  fatca_reportable boolean,
  dpdp_consent_ref uuid,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  row_version   integer NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, investor_id),
  UNIQUE (tenant_id, pan_hmac)
);
CREATE TRIGGER investor_version BEFORE UPDATE ON investor.investor
  FOR EACH ROW EXECUTE FUNCTION platform.tg_bump_version();

CREATE TABLE investor.folio (
  tenant_id     uuid NOT NULL,
  folio_id      uuid NOT NULL DEFAULT gen_random_uuid(),
  folio_number  text NOT NULL,             -- RTA folio number
  primary_investor_id uuid NOT NULL,
  holding_mode  text NOT NULL CHECK (holding_mode IN ('SINGLE','JOINT','ANYONE_OR_SURVIVOR')),
  status        text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','FROZEN','CLOSED')),
  PRIMARY KEY (tenant_id, folio_id),
  UNIQUE (tenant_id, folio_number),
  FOREIGN KEY (tenant_id, primary_investor_id) REFERENCES investor.investor (tenant_id, investor_id)
);

CREATE TABLE investor.investor_txn (
  tenant_id     uuid NOT NULL,
  txn_date      date NOT NULL,             -- NAV-applicable date (partition key)
  txn_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  rta_txn_ref   text NOT NULL,
  folio_id      uuid NOT NULL,
  plan_id       uuid NOT NULL,
  txn_type      text NOT NULL CHECK (txn_type IN
                 ('PURCHASE','ADDITIONAL_PURCHASE','REDEMPTION','SWITCH_IN','SWITCH_OUT','SIP','STP_IN','STP_OUT',
                  'SWP','IDCW_PAYOUT','IDCW_REINVEST','NFO_ALLOTMENT','TRANSMISSION','REVERSAL')),
  channel       text,
  arn           text,
  euin          text,
  received_at   timestamptz NOT NULL,      -- time stamp that drives applicable NAV
  gross_amount  numeric(24,4),
  stamp_duty    numeric(20,4) NOT NULL DEFAULT 0,
  exit_load     numeric(20,4) NOT NULL DEFAULT 0,
  tds           numeric(20,4) NOT NULL DEFAULT 0,
  net_amount    numeric(24,4),
  applicable_nav numeric(20,6),
  units         numeric(24,6),             -- positive in, negative out
  state         text NOT NULL CHECK (state IN
                 ('RECEIVED','VALIDATED','REJECTED','FUNDS_PENDING','FUNDS_REALISED','NAV_APPLIED','PROCESSED',
                  'PAYOUT_INITIATED','PAID','PAYOUT_FAILED','REPROCESSED','REVERSED')),
  reverses_txn_id uuid,
  linked_txn_id uuid,                      -- switch pairs
  loaded_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, txn_date, txn_id),
  UNIQUE (tenant_id, txn_date, rta_txn_ref),
  CHECK (state NOT IN ('PROCESSED','PAYOUT_INITIATED','PAID') OR (applicable_nav IS NOT NULL AND units IS NOT NULL))
) PARTITION BY RANGE (txn_date);
CREATE TABLE investor.investor_txn_2026_11 PARTITION OF investor.investor_txn FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE investor.investor_txn_2026_12 PARTITION OF investor.investor_txn FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE investor.investor_txn_default PARTITION OF investor.investor_txn DEFAULT;
CREATE INDEX investor_txn_folio_ix ON investor.investor_txn (tenant_id, folio_id, txn_date);
CREATE INDEX investor_txn_arn_ix   ON investor.investor_txn (tenant_id, arn, txn_date) WHERE arn IS NOT NULL;

CREATE TABLE investor.sip_registration (
  tenant_id     uuid NOT NULL,
  sip_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  folio_id      uuid NOT NULL,
  plan_id       uuid NOT NULL,
  amount        numeric(20,4) NOT NULL CHECK (amount > 0),
  frequency     text NOT NULL CHECK (frequency IN ('DAILY','WEEKLY','FORTNIGHTLY','MONTHLY','QUARTERLY')),
  start_date    date NOT NULL,
  end_date      date,
  mandate_ref   text NOT NULL,
  consecutive_failures smallint NOT NULL DEFAULT 0,
  status        text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','PAUSED','CANCELLED','COMPLETED')),
  arn           text,
  PRIMARY KEY (tenant_id, sip_id),
  FOREIGN KEY (tenant_id, folio_id) REFERENCES investor.folio (tenant_id, folio_id),
  FOREIGN KEY (tenant_id, plan_id)  REFERENCES product.plan (tenant_id, plan_id),
  CHECK (end_date IS NULL OR end_date > start_date)
);

-- ---------------------------------------------------------------------
-- 14  Distribution
-- ---------------------------------------------------------------------
CREATE TABLE distribution.distributor (
  tenant_id     uuid NOT NULL,
  distributor_id uuid NOT NULL DEFAULT gen_random_uuid(),
  arn           text NOT NULL CHECK (arn ~ '^ARN-[0-9]+$'),
  name          text NOT NULL,
  entity_type   text NOT NULL CHECK (entity_type IN ('INDIVIDUAL','CORPORATE','BANK','NATIONAL_DISTRIBUTOR','ONLINE_PLATFORM','RIA')),
  arn_valid_to  date,
  empanelment_status text NOT NULL DEFAULT 'ACTIVE' CHECK (empanelment_status IN ('PENDING','ACTIVE','SUSPENDED','TERMINATED')),
  PRIMARY KEY (tenant_id, distributor_id),
  UNIQUE (tenant_id, arn)
);

-- RM / branch mapping, effective-dated, no overlaps per distributor.
CREATE TABLE distribution.rm_mapping (
  tenant_id     uuid NOT NULL,
  distributor_id uuid NOT NULL,
  rm_user_id    uuid NOT NULL,
  branch_code   text NOT NULL,
  region_code   text NOT NULL,
  zone_code     text NOT NULL,
  effective     daterange NOT NULL,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, distributor_id, effective),
  FOREIGN KEY (tenant_id, distributor_id) REFERENCES distribution.distributor (tenant_id, distributor_id),
  EXCLUDE USING gist (tenant_id WITH =, distributor_id WITH =, effective WITH &&)
);

CREATE TABLE distribution.commission_rate (
  tenant_id     uuid NOT NULL,
  structure_code text NOT NULL,
  plan_id       uuid NOT NULL,
  distributor_category text NOT NULL DEFAULT '*',
  trail_pct_pa  numeric(9,6) NOT NULL CHECK (trail_pct_pa >= 0 AND trail_pct_pa < 5),
  effective     daterange NOT NULL,
  approval_request_id uuid NOT NULL,
  PRIMARY KEY (tenant_id, structure_code, plan_id, distributor_category, effective),
  FOREIGN KEY (tenant_id, plan_id) REFERENCES product.plan (tenant_id, plan_id),
  EXCLUDE USING gist (tenant_id WITH =, plan_id WITH =, distributor_category WITH =, effective WITH &&)
);

CREATE TABLE distribution.commission_run (
  tenant_id     uuid NOT NULL,
  run_id        uuid NOT NULL DEFAULT gen_random_uuid(),
  period_month  date NOT NULL CHECK (extract(day FROM period_month) = 1),
  status        text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','CALCULATED','APPROVED','PAID','SUPERSEDED')),
  prepared_by   uuid NOT NULL,
  approved_by   uuid,
  PRIMARY KEY (tenant_id, run_id),
  CHECK (approved_by IS NULL OR approved_by <> prepared_by)
);
CREATE UNIQUE INDEX commission_run_live_ux ON distribution.commission_run (tenant_id, period_month)
  WHERE status IN ('APPROVED','PAID');

CREATE TABLE distribution.commission_line (
  tenant_id     uuid NOT NULL,
  run_id        uuid NOT NULL,
  distributor_id uuid NOT NULL,
  plan_id       uuid NOT NULL,
  aum_days      numeric(30,4) NOT NULL,   -- sum of daily AUM over eligible days
  day_basis     smallint NOT NULL DEFAULT 365 CHECK (day_basis IN (365,366)),
  trail_pct_pa  numeric(9,6) NOT NULL,
  gross_commission numeric(20,4) NOT NULL,
  gst           numeric(20,4) NOT NULL DEFAULT 0,
  tds           numeric(20,4) NOT NULL DEFAULT 0,
  clawback      numeric(20,4) NOT NULL DEFAULT 0,
  net_payable   numeric(20,4) NOT NULL,
  PRIMARY KEY (tenant_id, run_id, distributor_id, plan_id),
  FOREIGN KEY (tenant_id, run_id) REFERENCES distribution.commission_run (tenant_id, run_id),
  FOREIGN KEY (tenant_id, distributor_id) REFERENCES distribution.distributor (tenant_id, distributor_id),
  CHECK (gross_commission = round(aum_days * trail_pct_pa / 100 / day_basis, 4)),
  CHECK (net_payable = gross_commission + gst - tds - clawback)
);

-- ---------------------------------------------------------------------
-- 15  Documents, analytics, AI
-- ---------------------------------------------------------------------
CREATE TABLE documents.document (
  tenant_id     uuid NOT NULL,
  document_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  doc_type      text NOT NULL,             -- SID, KIM, SAI, RESEARCH_NOTE, CONTRACT_NOTE, EVIDENCE_PACK ...
  version_no    integer NOT NULL DEFAULT 1,
  object_key    text NOT NULL,             -- s3://amcos-<tenant_code>/... (tenant prefix enforced by app + bucket policy)
  sha256        bytea NOT NULL,
  classification text NOT NULL CHECK (classification IN ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED_PII')),
  retention_class text NOT NULL,
  linked_object_type text,
  linked_object_id uuid,
  uploaded_by   uuid NOT NULL,
  uploaded_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, document_id, version_no)
);

CREATE TABLE analytics.metric_definition (
  tenant_id     uuid NOT NULL,
  metric_code   text NOT NULL,             -- aaum, net_sales, net_yield ...
  version_no    integer NOT NULL,
  plain_definition text NOT NULL,
  formula_sql   text NOT NULL,
  grain         text NOT NULL,
  owner_user_id uuid NOT NULL,
  effective     daterange NOT NULL,
  certified     boolean NOT NULL DEFAULT false,
  PRIMARY KEY (tenant_id, metric_code, version_no),
  EXCLUDE USING gist (tenant_id WITH =, metric_code WITH =, effective WITH &&) WHERE (certified)
);

CREATE TABLE ai.agent (
  tenant_id     uuid NOT NULL,
  agent_code    text NOT NULL,             -- RESEARCH_AGENT, CIO_COPILOT ...
  service_user_id uuid NOT NULL,           -- identity.app_user with is_service_identity = true
  model_ref     text NOT NULL,
  prompt_version text NOT NULL,
  allowed_tools text[] NOT NULL,
  risk_tier     text NOT NULL CHECK (risk_tier IN ('LOW','MEDIUM','HIGH')),
  status        text NOT NULL CHECK (status IN ('DRAFT','APPROVED','ACTIVE','SUSPENDED','RETIRED')),
  PRIMARY KEY (tenant_id, agent_code),
  FOREIGN KEY (tenant_id, service_user_id) REFERENCES identity.app_user (tenant_id, user_id)
);

CREATE TABLE ai.tool_call_log (
  tenant_id     uuid NOT NULL,
  called_at     timestamptz NOT NULL DEFAULT now(),
  call_id       uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id    uuid NOT NULL,
  agent_code    text NOT NULL,
  on_behalf_of_user_id uuid NOT NULL,
  tool_name     text NOT NULL,
  input_payload jsonb NOT NULL,
  output_hash   bytea,
  outcome       text NOT NULL CHECK (outcome IN ('OK','DENIED','ERROR')),
  PRIMARY KEY (tenant_id, called_at, call_id)
) PARTITION BY RANGE (called_at);
CREATE TABLE ai.tool_call_log_default PARTITION OF ai.tool_call_log DEFAULT;
CREATE TRIGGER tool_call_immutable BEFORE UPDATE OR DELETE ON ai.tool_call_log
  FOR EACH ROW EXECUTE FUNCTION platform.tg_immutable();

CREATE TABLE ai.proposal (
  tenant_id     uuid NOT NULL,
  proposal_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  agent_code    text NOT NULL,
  proposal_type text NOT NULL,             -- DRAFT_ORDER, RULE_CHANGE, REGISTER_ENTRY, REPLY, MATCH ...
  target_module text NOT NULL,
  payload       jsonb NOT NULL,
  status        text NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','ACCEPTED','REJECTED','EXPIRED')),
  decided_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, proposal_id),
  FOREIGN KEY (tenant_id, agent_code) REFERENCES ai.agent (tenant_id, agent_code)
);

-- ---------------------------------------------------------------------
-- 16  Row-level security on EVERY tenant table, partitions included (fail closed)
--     Note: a query that targets a partition directly does NOT use the parent's
--     policy, so every leaf partition gets the same policy too.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION platform.apply_tenant_rls() RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE r record; n integer := 0;
BEGIN
  FOR r IN
    SELECT ns.nspname AS s, k.relname AS t
      FROM pg_class k JOIN pg_namespace ns ON ns.oid = k.relnamespace
     WHERE k.relkind IN ('r','p')
       AND ns.nspname NOT IN ('pg_catalog','information_schema','pg_toast')
       AND NOT (ns.nspname = 'platform' AND k.relname = 'tenant')
       AND EXISTS (SELECT 1 FROM pg_attribute a
                    WHERE a.attrelid = k.oid AND a.attname = 'tenant_id' AND NOT a.attisdropped)
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.s, r.t);
    EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', r.s, r.t);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I.%I', r.s, r.t);
    EXECUTE format('CREATE POLICY tenant_isolation ON %I.%I USING (tenant_id = platform.current_tenant()) WITH CHECK (tenant_id = platform.current_tenant())', r.s, r.t);
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;
COMMENT ON FUNCTION platform.apply_tenant_rls IS
  'Idempotent. Re-run after every migration that adds a table or partition; CI fails if any tenant table lacks the policy.';

SELECT platform.apply_tenant_rls();

-- ---------------------------------------------------------------------
-- 17  Grants (least privilege) and materialized views
-- ---------------------------------------------------------------------
DO $$
DECLARE s text;
BEGIN
  FOREACH s IN ARRAY ARRAY['platform','identity','audit','master','product','workflow','investment','portfolio',
                           'trading','execution','settlement','compliance','risk','valuation','accounting','nav',
                           'operations','investor','distribution','finance','documents','analytics','ai']
  LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO amc_app, amc_readonly, amc_auditor', s);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO amc_readonly, amc_auditor', s);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA %I TO amc_app', s);
    EXECUTE format('GRANT USAGE ON ALL SEQUENCES IN SCHEMA %I TO amc_app', s);
  END LOOP;
END $$;
-- The app can never delete financial records or touch the tenant registry.
REVOKE UPDATE ON audit.audit_event, accounting.journal_batch, accounting.journal_line,
                 execution.fill, nav.nav_result, compliance.check_result, ai.tool_call_log FROM amc_app;
REVOKE INSERT, UPDATE ON platform.tenant FROM amc_app;

-- AI agent role: read-only on the few views the tool gateway exposes; nothing else.
GRANT USAGE ON SCHEMA analytics, ai TO amc_ai_agent;
GRANT INSERT ON ai.tool_call_log, ai.proposal TO amc_ai_agent;

-- Daily AUM by scheme/plan from approved NAV results (refreshed after each NAV publish).
CREATE MATERIALIZED VIEW analytics.mv_daily_aum AS
SELECT r.tenant_id, p.scheme_id, r.plan_id, r.nav_date,
       r.net_assets AS aum, r.units_outstanding, r.nav_per_unit
  FROM nav.nav_result r
  JOIN nav.nav_run n ON n.tenant_id = r.tenant_id AND n.nav_run_id = r.nav_run_id
  JOIN product.plan p ON p.tenant_id = r.tenant_id AND p.plan_id = r.plan_id
 WHERE n.state = 'PUBLISHED'
WITH NO DATA;
CREATE UNIQUE INDEX mv_daily_aum_ux ON analytics.mv_daily_aum (tenant_id, plan_id, nav_date);
-- Materialized views do not support RLS: expose only through a security-barrier view.
CREATE VIEW analytics.v_daily_aum WITH (security_barrier = true) AS
  SELECT * FROM analytics.mv_daily_aum WHERE tenant_id = platform.current_tenant();
REVOKE ALL ON analytics.mv_daily_aum FROM amc_app, amc_readonly, amc_auditor;
GRANT SELECT ON analytics.v_daily_aum TO amc_app, amc_readonly, amc_auditor, amc_ai_agent;

-- End of core DDL.
