# D04 Portfolio Management — `portfolio`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Positions, snapshots and results

```mermaid
erDiagram
  PRODUCT_SCHEME ||--o{ PORTFOLIO : "managed as"
  PORTFOLIO ||--o{ PORTFOLIO : "parent of"
  PORTFOLIO ||--o{ POSITION_LOT : "holds"
  PORTFOLIO ||--o{ POSITION : "positions"
  POSITION ||--|{ POSITION_LOT : "made of"
  MASTER_SECURITY ||--o{ POSITION_LOT : "held as"
  POSITION_LOT ||--|{ POSITION_EVENT : "changed by"
  PRODUCT_SCHEME ||--o{ SNAPSHOT : "EOD book"
  SNAPSHOT ||--|{ SNAPSHOT_POSITION : "holds"
  PRODUCT_SCHEME ||--o{ CASH_LADDER_ENTRY : "expects"
  MODEL_PORTFOLIO ||--o{ REBALANCE_PROPOSAL : "drives"
  PORTFOLIO ||--o{ REBALANCE_PROPOSAL : "rebalanced by"
  PERFORMANCE_RUN ||--|{ PERFORMANCE_RESULT : "produces"
  PERFORMANCE_RESULT ||--o{ ATTRIBUTION_RESULT : "explained by"
  PORTFOLIO {
    uuid tenant_id PK
    uuid portfolio_id PK
    uuid scheme_id FK
    uuid parent_portfolio_id FK
  }
  POSITION_LOT {
    uuid tenant_id PK
    uuid lot_id PK
    uuid portfolio_id FK
    uuid security_id FK
    numeric quantity
    numeric cost_amount
    date acquired_on
  }
  POSITION {
    uuid tenant_id PK
    uuid position_id PK
    uuid portfolio_id FK
    uuid security_id FK
    numeric quantity
  }
  POSITION_EVENT {
    uuid tenant_id PK
    date event_date PK
    uuid position_event_id PK
    uuid lot_id FK
    text source_type
    uuid source_id
    numeric quantity_change
  }
  SNAPSHOT {
    uuid tenant_id PK
    uuid snapshot_id PK
    uuid scheme_id FK
    date as_of_date
    int snapshot_version
    text status
    bytea content_hash
  }
  SNAPSHOT_POSITION {
    uuid tenant_id PK
    date as_of_date PK
    uuid snapshot_id PK
    uuid security_id PK
    numeric quantity
    numeric market_value
  }
  CASH_LADDER_ENTRY {
    uuid tenant_id PK
    uuid entry_id PK
    uuid scheme_id FK
    date value_date
    numeric amount
  }
  MODEL_PORTFOLIO {
    uuid tenant_id PK
    uuid model_id PK
    int version_no PK
    daterange valid_period
  }
  REBALANCE_PROPOSAL {
    uuid tenant_id PK
    uuid proposal_id PK
    uuid portfolio_id FK
    uuid model_id FK
    text state
  }
  PERFORMANCE_RUN {
    uuid tenant_id PK
    uuid performance_run_id PK
    jsonb input_manifest
    text state
  }
  PERFORMANCE_RESULT {
    uuid tenant_id PK
    uuid result_id PK
    uuid performance_run_id FK
    uuid scheme_id FK
    uuid plan_id FK
    daterange period
    numeric return_value
    text engine_version
  }
  ATTRIBUTION_RESULT {
    uuid tenant_id PK
    uuid result_id PK
    text factor_code PK
    numeric contribution
  }
  MASTER_SECURITY {
    uuid tenant_id PK
    uuid security_id PK
  }
  PRODUCT_SCHEME {
    uuid tenant_id PK
    uuid scheme_id PK
  }
```

## Notes

- `POSITION_EVENT.source_id` is an ID reference to the trade, corporate action or transfer that caused it (NFR-AUD-004); `PERFORMANCE_RESULT.engine_version` is `FE-10@<version>`.
- `NAV_RUN` freezes the snapshot by event (`NAV_APPROVED`), not by foreign key.
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `portfolio.exposure_view`.
