# D16 Enterprise Data Platform — `master`, `analytics`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Golden reference data (`master`)

```mermaid
erDiagram
  ISSUER_GROUP ||--o{ ISSUER : "contains"
  ISSUER ||--o{ SECURITY : "issues"
  CURRENCY ||--o{ SECURITY : "denominated in"
  SECURITY ||--o{ SECURITY_SCHEDULE : "pays"
  SECURITY ||--o{ CREDIT_RATING : "rated"
  ISSUER ||--o{ CREDIT_RATING : "rated"
  BENCHMARK ||--o{ BENCHMARK_LEVEL : "levels"
  BENCHMARK ||--o{ BENCHMARK_CONSTITUENT : "made of"
  SECURITY ||--o{ BENCHMARK_CONSTITUENT : "in"
  IDENTIFIER_SCHEME ||--o{ EXTERNAL_IDENTIFIER : "types"
  SECURITY ||--o{ STEWARD_REQUEST : "changed by"
  CURRENCY {
    char currency_code PK
    text name
  }
  ISSUER_GROUP {
    uuid tenant_id PK
    uuid group_id PK
    text group_name
    bool is_sponsor_group
    daterange valid_period
  }
  ISSUER {
    uuid tenant_id PK
    uuid issuer_id PK
    uuid group_id FK
    text legal_name
    char lei
    text cin
    daterange valid_period
    timestamptz recorded_at
  }
  SECURITY {
    uuid tenant_id PK
    uuid security_id PK
    uuid issuer_id FK
    char currency_code FK
    text instrument_type
    char isin
    date maturity_date
    text approval_status
    daterange valid_period
  }
  SECURITY_SCHEDULE {
    uuid tenant_id PK
    uuid security_id PK
    text schedule_type PK
    date event_date PK
    numeric amount
  }
  CREDIT_RATING {
    uuid tenant_id PK
    uuid rating_id PK
    uuid security_id FK
    uuid issuer_id FK
    text agency
    text rating
    daterange valid_period
  }
  BENCHMARK {
    uuid tenant_id PK
    uuid benchmark_id PK
    text name
    daterange valid_period
  }
  BENCHMARK_LEVEL {
    uuid tenant_id PK
    uuid benchmark_id PK
    date level_date PK
    text level_type PK
    numeric level
  }
  BENCHMARK_CONSTITUENT {
    uuid tenant_id PK
    uuid benchmark_id PK
    date as_of_date PK
    uuid security_id PK
    numeric weight
  }
  COUNTERPARTY {
    uuid tenant_id PK
    uuid counterparty_id PK
    text legal_name
    char lei
    text counterparty_type
    text empanelment_status
    daterange valid_period
  }
  IDENTIFIER_SCHEME {
    uuid tenant_id PK
    text scheme_code PK
    text issuing_body
    text format_check
  }
  EXTERNAL_IDENTIFIER {
    uuid tenant_id PK
    uuid external_identifier_id PK
    text entity_type
    uuid entity_id
    text scheme_code FK
    text value
    daterange valid_period
  }
  SOURCE_PRECEDENCE_RULE {
    uuid tenant_id PK
    text entity_type PK
    text field_name PK
    int version_no PK
  }
  STEWARD_REQUEST {
    uuid tenant_id PK
    uuid request_id PK
    text entity_type
    uuid entity_id
    text state
  }
  MATCH_CANDIDATE {
    uuid tenant_id PK
    uuid candidate_id PK
    text entity_type
    uuid left_id
    uuid right_id
    text state
  }
```

## Data governance (`analytics`)

```mermaid
erDiagram
  DATASET ||--o{ CATALOGUE_ENTRY : "described by"
  DATASET ||--o{ DQ_RULE : "checked by"
  DQ_RULE ||--o{ DQ_RESULT : "produces"
  DQ_RESULT ||--o| DQ_EXCEPTION : "raises"
  DATASET ||--o{ DATASET_CERTIFICATION : "certified"
  DATASET ||--o{ ACCESS_REQUEST : "requested"
  PIPELINE_RUN ||--o{ LINEAGE_POINTER : "traced by"
  METRIC_DEFINITION {
    uuid tenant_id PK
    text metric_code PK
    int version_no PK
    bool certified
  }
  DATASET {
    uuid tenant_id PK
    text dataset_code PK
    int version_no PK
    text owner_module
    text classification
    text retention_class
    text licence_tag
  }
  CATALOGUE_ENTRY {
    uuid tenant_id PK
    uuid entry_id PK
    text dataset_code FK
  }
  DQ_RULE {
    uuid tenant_id PK
    text rule_code PK
    int version_no PK
    text dataset_code FK
    text severity
  }
  DQ_RESULT {
    uuid tenant_id PK
    date business_date PK
    uuid result_id PK
    text rule_code FK
    int version_no
    text outcome
  }
  DQ_EXCEPTION {
    uuid tenant_id PK
    uuid exception_id PK
    uuid result_id
    text owner_module
    text state
  }
  DATASET_CERTIFICATION {
    uuid tenant_id PK
    text dataset_code PK
    date business_date PK
    text state
  }
  ACCESS_REQUEST {
    uuid tenant_id PK
    uuid request_id PK
    text dataset_code FK
    uuid user_id
    text state
  }
  PIPELINE_RUN {
    uuid tenant_id PK
    uuid run_id PK
    text pipeline_code
    text status
  }
  LINEAGE_POINTER {
    uuid tenant_id PK
    uuid pointer_id PK
    uuid run_id FK
    text lineage_ref
  }
```

## Notes

- `CURRENCY` is the only table here without a tenant column (D-62, DA-001 M3). Golden-record tables are bi-temporal (DM-1): `valid_period` + `recorded_at` / `superseded_at` (shown on `ISSUER`; the same on the others).
- `EXTERNAL_IDENTIFIER` covers master entities only; Product, Distribution and Investor keep their own crosswalk tables of the same shape (DA-001 §3.4, DM-3). `COUNTERPARTY` is referenced by `execution.broker`, `settlement.ssi` and `risk.counterparty_exposure`.
- `DQ_RESULT` is partitioned yearly, so `DQ_EXCEPTION.result_id` is a plain ID column. `EXTERNAL_IDENTIFIER` points at its entity by `(entity_type, entity_id)`, which cannot be a foreign key, so no line is drawn. Which datasets a metric is computed from is part of the metric definition; a link table, if needed, is set in DBE-001.
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `master.load_run`, `analytics.mv_daily_aum`.
