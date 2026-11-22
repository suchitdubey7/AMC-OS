# D11 Valuation and NAV — `valuation`, `nav`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Prices and valuation (`valuation`)

```mermaid
erDiagram
  MASTER_SECURITY ||--o{ PRICE : "priced"
  PRICE_SET ||--o{ VALUATION_RUN : "input to"
  SOURCE_HIERARCHY ||--o{ VALUATION_RUN : "applied in"
  VALUATION_POLICY ||--o{ VALUATION_RUN : "governs"
  MASTER_SECURITY ||--o{ PRICE_OVERRIDE : "overridden"
  MASTER_SECURITY ||--o{ FAIR_VALUE_CASE : "fair-valued"
  VALUATION_RUN ||--|{ VALUATION_RESULT : "produces"
  PRICE {
    uuid tenant_id PK
    date price_date PK
    uuid security_id PK
    text price_source PK
    text price_type
    numeric price
    bool is_validated
    uuid load_run_id
  }
  PRICE_SET {
    uuid tenant_id PK
    uuid price_set_id PK
    date price_date
    text state
  }
  SOURCE_HIERARCHY {
    uuid tenant_id PK
    uuid hierarchy_id PK
    int version_no PK
    text instrument_class
  }
  PRICE_OVERRIDE {
    uuid tenant_id PK
    uuid override_id PK
    uuid security_id FK
    date price_date
    numeric price
    text state
  }
  VALUATION_POLICY {
    uuid tenant_id PK
    uuid policy_id PK
    int version_no PK
    daterange valid_period
  }
  FAIR_VALUE_CASE {
    uuid tenant_id PK
    uuid case_id PK
    uuid security_id FK
    text state
    uuid decision_approval_id
  }
  DEVIATION_REPORT {
    uuid tenant_id PK
    uuid report_id PK
    date report_date
  }
  VALUATION_RUN {
    uuid tenant_id PK
    uuid run_id PK
    uuid scheme_id FK
    date valuation_date
    jsonb input_manifest
    text state
  }
  VALUATION_RESULT {
    uuid tenant_id PK
    date valuation_date PK
    uuid run_id PK
    uuid security_id PK
    numeric market_value
    text price_source_used
    smallint fallback_level
  }
  MASTER_SECURITY {
    uuid tenant_id PK
    uuid security_id PK
  }
```

## NAV (`nav`)

```mermaid
erDiagram
  NAV_RUN |o--o| NAV_RUN : "corrects"
  NAV_RUN ||--|{ NAV_COMPONENT : "built from"
  NAV_RUN ||--|{ NAV_RESULT : "per plan"
  PRODUCT_PLAN ||--o{ NAV_RESULT : "has NAV"
  NAV_RUN ||--|{ NAV_VALIDATION : "gated by"
  NAV_RUN ||--o{ NAV_MOVEMENT : "explained by"
  NAV_RUN ||--o{ NAV_PUBLICATION : "published to"
  PUBLICATION_DEADLINE ||--o{ NAV_PUBLICATION : "due by"
  NAV_PUBLICATION ||--|{ NAV_PUBLICATION_ATTEMPT : "sent via"
  PRODUCT_PLAN ||--o{ CUSTODIAN_NAV : "mirrored"
  NAV_RUN {
    uuid tenant_id PK
    uuid nav_run_id PK
    uuid scheme_id FK
    date nav_date
    int run_no
    text run_kind
    text state
    uuid corrects_run_id FK
    jsonb input_manifest
  }
  NAV_COMPONENT {
    uuid tenant_id PK
    uuid nav_run_id PK
    text component_code PK
    uuid plan_id PK
    numeric amount
    bytea input_hash
  }
  NAV_RESULT {
    uuid tenant_id PK
    uuid nav_run_id PK
    uuid plan_id PK
    numeric net_assets
    numeric units_outstanding
    numeric nav_unrounded
    numeric nav_per_unit
  }
  NAV_VALIDATION {
    uuid tenant_id PK
    uuid nav_run_id PK
    text check_code PK
    text outcome
    uuid waiver_approval_id
  }
  NAV_MOVEMENT {
    uuid tenant_id PK
    uuid nav_run_id PK
    uuid plan_id PK
    text driver_code PK
    numeric contribution
  }
  NAV_PUBLICATION {
    uuid tenant_id PK
    uuid nav_run_id PK
    text channel PK
    text delivery_state
    text ack_reference
  }
  NAV_PUBLICATION_ATTEMPT {
    uuid tenant_id PK
    uuid nav_run_id PK
    text channel PK
    int attempt_no PK
    text action
  }
  CUSTODIAN_NAV {
    uuid tenant_id PK
    date nav_date PK
    uuid scheme_id PK
    uuid plan_id PK
    uuid load_run_id PK
    numeric nav_per_unit
  }
  SHADOW_NAV {
    uuid tenant_id PK
    date nav_date PK
    uuid plan_id PK
    uuid shadow_run_id PK
    numeric nav_per_unit
  }
  PUBLICATION_DEADLINE {
    uuid tenant_id PK
    text channel PK
    daterange valid_period PK
    time deadline
  }
  PRODUCT_PLAN {
    uuid tenant_id PK
    uuid plan_id PK
  }
```

## Notes

- Valuation and NAV are two modules (EA-003 §2): NAV reads valuation results through the Valuation interface, so there is no foreign key from `nav` to `valuation` (DA-001 M4).
- `nav_unrounded` is `numeric(30,12)`; the published NAV is rounded per plan configuration (ADR-0005, FE-01). `NAV_PUBLICATION` uses the outbound-instruction pattern (DA-001 §3.5).
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `valuation.load_run`, `nav.load_run`.
