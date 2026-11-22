# D09 Risk Management — `risk`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Models, runs, limits and alerts

```mermaid
erDiagram
  RISK_MODEL ||--|{ RISK_MODEL_VERSION : "versioned"
  RISK_MODEL ||--o{ MODEL_VALIDATION : "validated in"
  RISK_MODEL_VERSION ||--o{ RISK_RUN : "used by"
  RISK_RUN ||--|{ METRIC_RESULT : "produces"
  SCENARIO ||--o{ STRESS_RESULT : "applied in"
  RISK_RUN ||--o{ STRESS_RESULT : "contains"
  RISK_RUN ||--o{ ATTRIBUTION_RESULT : "explained by"
  ALERT_THRESHOLD ||--o{ RISK_ALERT : "crossed as"
  RISK_RUN ||--o{ RISK_ALERT : "raises"
  RISK_ALERT ||--|{ RISK_ALERT_HISTORY : "history"
  RISK_MODEL {
    uuid tenant_id PK
    uuid model_id PK
    text model_code UK
    text metric_family
  }
  RISK_MODEL_VERSION {
    uuid tenant_id PK
    uuid model_id PK
    int version_no PK
    text validation_status
  }
  MODEL_VALIDATION {
    uuid tenant_id PK
    uuid validation_id PK
    uuid model_id FK
    int version_no
    uuid validated_by
  }
  SCENARIO {
    uuid tenant_id PK
    uuid scenario_id PK
    int version_no PK
    jsonb shocks
  }
  RISK_RUN {
    uuid tenant_id PK
    uuid risk_run_id PK
    uuid scheme_id FK
    date as_of_date
    jsonb input_manifest
    text state
  }
  METRIC_RESULT {
    uuid tenant_id PK
    uuid risk_run_id PK
    text metric_code PK
    text scope_key PK
    numeric value
  }
  STRESS_RESULT {
    uuid tenant_id PK
    uuid risk_run_id PK
    uuid scenario_id PK
    int version_no PK
    numeric pnl_impact
  }
  ATTRIBUTION_RESULT {
    uuid tenant_id PK
    uuid risk_run_id PK
    text factor_code PK
    numeric contribution
  }
  ALERT_THRESHOLD {
    uuid tenant_id PK
    uuid threshold_id PK
    int version_no PK
    text metric_code
    numeric threshold
  }
  RISK_ALERT {
    uuid tenant_id PK
    uuid alert_id PK
    uuid risk_run_id FK
    uuid threshold_id FK
    text state
    uuid owner_user_id
  }
  RISK_ALERT_HISTORY {
    uuid tenant_id PK
    uuid alert_id PK
    timestamptz changed_at PK
    text to_state
  }
  REPORT_PACK {
    uuid tenant_id PK
    uuid pack_id PK
    date as_of_date
    text state
  }
  COUNTERPARTY_EXPOSURE {
    uuid tenant_id PK
    date as_of_date PK
    uuid counterparty_id PK
    numeric exposure
  }
```

## Notes

- Risk **limits** are Compliance rules of class `INTERNAL_RISK` (owner decision D-33); Risk keeps only alert thresholds and alerts. Long time series of risk measures are in the analytical store (ADR-0007, DA-001 §6.2); `METRIC_RESULT` keeps the summary.
- `RISK_RUN.input_manifest` lists the snapshot, price set, model and scenario versions used (DA-001 M13). `counterparty_id` goes to `master.counterparty`.
