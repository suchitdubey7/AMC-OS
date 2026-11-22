# D08 Compliance Management — `compliance`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Register, rules, checks and breaches

```mermaid
erDiagram
  REGULATION ||--o{ RULE : "implemented by"
  RULE ||--|{ RULE_VERSION : "versioned"
  RULE_VERSION ||--o{ RULE_PARAMETER : "parameterised"
  RULE ||--o{ RULE_TEST_CASE : "tested by"
  RULE_TEST_CASE ||--o{ RULE_TEST_RUN : "run as"
  RULE ||--o{ BACKTEST_RESULT : "back-tested"
  REGULATION ||--o{ IMPACT_ASSESSMENT : "assessed"
  RULE ||--o{ CHECK_RESULT : "produces"
  CHECK_RUN ||--|{ CHECK_RESULT : "groups"
  CHECK_RESULT ||--o| PRETRADE_OVERRIDE : "overridden by"
  RULE ||--o{ EXEMPTION : "exempted"
  RULE ||--o{ BREACH : "breached"
  BREACH ||--o{ CURE_PLAN : "cured by"
  REPORT_DEFINITION ||--o{ REPORT_RUN : "run as"
  REGULATION {
    uuid tenant_id PK
    uuid regulation_id PK
    text source
    text reference
    daterange valid_period
    text verification_status
  }
  RULE {
    uuid tenant_id PK
    uuid rule_id PK
    text rule_code UK
    text rule_class
    uuid regulation_id FK
  }
  RULE_VERSION {
    uuid tenant_id PK
    uuid rule_id PK
    int version_no PK
    jsonb definition
    daterange valid_period
    text status
    bool tests_passed
  }
  RULE_PARAMETER {
    uuid tenant_id PK
    uuid rule_id PK
    int version_no PK
    text param_name PK
    text scope_key PK
    numeric param_value
  }
  RULE_TEST_CASE {
    uuid tenant_id PK
    uuid test_case_id PK
    uuid rule_id FK
    int version_no
  }
  RULE_TEST_RUN {
    uuid tenant_id PK
    uuid test_run_id PK
    uuid test_case_id FK
    text outcome
  }
  BACKTEST_RESULT {
    uuid tenant_id PK
    uuid backtest_id PK
    uuid rule_id FK
    int version_no
  }
  IMPACT_ASSESSMENT {
    uuid tenant_id PK
    uuid assessment_id PK
    uuid regulation_id FK
    text state
  }
  CHECK_RUN {
    uuid tenant_id PK
    uuid check_run_id PK
    text check_kind
    uuid order_id
    uuid scheme_id FK
  }
  CHECK_RESULT {
    uuid tenant_id PK
    date checked_on PK
    uuid result_id PK
    uuid check_run_id FK
    uuid rule_id FK
    int version_no
    text check_kind
    text outcome
    numeric measured_value
    bytea input_hash
  }
  PRETRADE_OVERRIDE {
    uuid tenant_id PK
    uuid override_id PK
    uuid check_result_id
    uuid order_id
    text state
    uuid approval_request_id
  }
  EXEMPTION {
    uuid tenant_id PK
    uuid exemption_id PK
    uuid rule_id FK
    timestamptz expires_at
    text state
  }
  BREACH {
    uuid tenant_id PK
    uuid breach_id PK
    uuid rule_id FK
    uuid scheme_id FK
    text breach_type
    date cure_deadline
    text status
  }
  CURE_PLAN {
    uuid tenant_id PK
    uuid breach_id PK
    int version_no PK
    text plan
  }
  REPORT_DEFINITION {
    uuid tenant_id PK
    text report_code PK
    int version_no PK
  }
  REPORT_RUN {
    uuid tenant_id PK
    uuid report_run_id PK
    text report_code FK
    text state
    text filing_ack
  }
  EVIDENCE_PACK {
    uuid tenant_id PK
    uuid pack_id PK
    uuid document_id
  }
```

## Notes

- `rule_class` adds `HOUSE_LIMIT` (DM-11). `CHECK_RESULT` is partitioned yearly; `PRETRADE_OVERRIDE.check_result_id` is a plain ID column because the partitioned check-result key includes `checked_on`.
- `order_id` is an ID reference to `trading."order"`; `scheme_id` goes to `product.scheme` (reference schema).
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `compliance.breach_investigation`, `compliance.load_run`.
