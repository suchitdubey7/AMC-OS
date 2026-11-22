# D02 Product and Scheme Management — `product`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Scheme, plan and terms

```mermaid
erDiagram
  SCHEME ||--|{ SCHEME_VERSION : "versioned as"
  SCHEME ||--|{ PLAN : "offers"
  CATEGORY ||--o{ SCHEME_VERSION : "classifies"
  SCHEME_VERSION ||--o{ SCHEME_MANDATE : "allows"
  SCHEME ||--o{ BENCHMARK_MAPPING : "benchmarked by"
  MASTER_BENCHMARK ||--o{ BENCHMARK_MAPPING : "used in"
  PLAN ||--o{ FEE_SCHEDULE : "charges"
  PLAN ||--o{ EXIT_LOAD_SLAB : "applies"
  SCHEME ||--o| NFO : "launched by"
  SCHEME ||--o{ SCHEME_EVENT : "has"
  SCHEME ||--o{ SCHEME_CHANGE_REQUEST : "changed by"
  SCHEME ||--o{ SCHEME_DOCUMENT_LINK : "documented by"
  PLAN ||--o{ EXTERNAL_IDENTIFIER : "known outside as"
  SCHEME {
    uuid tenant_id PK
    uuid scheme_id PK
    text scheme_code UK
    text structure
    text lifecycle_state
  }
  SCHEME_VERSION {
    uuid tenant_id PK
    uuid scheme_id PK
    int version_no PK
    text category_code FK
    daterange valid_period
    text status
  }
  PLAN {
    uuid tenant_id PK
    uuid plan_id PK
    uuid scheme_id FK
    text plan_type
    text option_type
    smallint nav_decimals
  }
  CATEGORY {
    uuid tenant_id PK
    text category_code PK
    int version_no PK
    text name
  }
  SCHEME_MANDATE {
    uuid tenant_id PK
    uuid scheme_id PK
    int version_no PK
    int line_no PK
    text asset_class
    numeric min_pct
    numeric max_pct
  }
  BENCHMARK_MAPPING {
    uuid tenant_id PK
    uuid scheme_id PK
    text benchmark_role PK
    daterange valid_period PK
    uuid benchmark_id FK
  }
  FEE_SCHEDULE {
    uuid tenant_id PK
    uuid plan_id PK
    text fee_type PK
    daterange valid_period PK
    numeric rate_pct_pa
  }
  EXIT_LOAD_SLAB {
    uuid tenant_id PK
    uuid plan_id PK
    daterange valid_period PK
    int min_days_held PK
    numeric load_pct
  }
  NFO {
    uuid tenant_id PK
    uuid nfo_id PK
    uuid scheme_id FK
    date open_date
    date close_date
    text state
  }
  SCHEME_EVENT {
    uuid tenant_id PK
    uuid scheme_event_id PK
    uuid scheme_id FK
    text event_type
    date effective_date
  }
  SCHEME_CHANGE_REQUEST {
    uuid tenant_id PK
    uuid change_request_id PK
    uuid scheme_id FK
    bool fundamental
    text state
  }
  SCHEME_DOCUMENT_LINK {
    uuid tenant_id PK
    uuid scheme_id PK
    text document_type PK
    daterange valid_period PK
    uuid document_id
  }
  EXTERNAL_IDENTIFIER {
    uuid tenant_id PK
    uuid external_identifier_id PK
    text entity_type
    uuid entity_id
    text scheme_code
    text value
    daterange valid_period
  }
  MASTER_BENCHMARK {
    uuid tenant_id PK
    uuid benchmark_id PK
  }
```

## Notes

- `MASTER_BENCHMARK` is `master.benchmark` (Security master); a foreign key is allowed because `master.*` is a reference schema (DA-001 M4).
- `SCHEME_DOCUMENT_LINK.document_id` is an ID reference to `documents.document`.
