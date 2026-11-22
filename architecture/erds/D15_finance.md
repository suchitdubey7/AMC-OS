# D15 Finance and Management Reporting — `finance`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Expenses, allocation, plans and reporting

```mermaid
erDiagram
  ALLOCATION_KEY ||--o{ ALLOCATION_RUN : "used by"
  ALLOCATION_RUN ||--|{ ALLOCATION_RESULT : "produces"
  BUDGET_VERSION ||--|{ BUDGET_LINE : "contains"
  PLAN_VERSION ||--o{ PLAN_DRIVER : "driven by"
  MANAGEMENT_PERIOD ||--o{ AUM_BRIDGE_RESULT : "includes"
  MANAGEMENT_PERIOD ||--o{ BOARD_PACK : "reported in"
  MANAGEMENT_PERIOD ||--o{ REVENUE_RESULT : "includes"
  ERP_EXPORT {
    uuid tenant_id PK
    uuid export_id PK
    date period_month
    numeric control_total
    text state
  }
  EXPENSE_ACTUAL {
    uuid tenant_id PK
    date period_month PK
    uuid expense_id PK
    text account_code
    uuid org_unit_id
    numeric amount
    uuid load_run_id
  }
  SCHEME_EXPENSE_BORNE {
    uuid tenant_id PK
    date period_month PK
    uuid scheme_id PK
    text expense_code PK
    numeric amount
  }
  ALLOCATION_KEY {
    uuid tenant_id PK
    text key_code PK
    int version_no PK
  }
  ALLOCATION_RUN {
    uuid tenant_id PK
    uuid run_id PK
    text key_code FK
    int version_no
    date period_month
    text state
  }
  ALLOCATION_RESULT {
    uuid tenant_id PK
    uuid run_id PK
    uuid result_id PK
    uuid scheme_id FK
    numeric amount
  }
  REVENUE_RESULT {
    uuid tenant_id PK
    date period_month PK
    uuid scheme_id PK
    uuid plan_id PK
    uuid run_id PK
    numeric amount
    text engine_version
  }
  BUDGET_VERSION {
    uuid tenant_id PK
    uuid budget_id PK
    int version_no PK
    text state
  }
  BUDGET_LINE {
    uuid tenant_id PK
    uuid budget_id PK
    int version_no PK
    int line_no PK
    numeric amount
  }
  PLAN_VERSION {
    uuid tenant_id PK
    uuid plan_id PK
    int version_no PK
    text scenario
  }
  PLAN_DRIVER {
    uuid tenant_id PK
    uuid plan_id PK
    int version_no PK
    text driver_code PK
    numeric value
  }
  FORECAST_VERSION {
    uuid tenant_id PK
    uuid forecast_id PK
    int version_no PK
    numeric accuracy
  }
  MANAGEMENT_PERIOD {
    uuid tenant_id PK
    date period_month PK
    int version_no PK
    text state
  }
  AUM_BRIDGE_RESULT {
    uuid tenant_id PK
    date period_month PK
    uuid scheme_id PK
    uuid run_id PK
  }
  BOARD_PACK {
    uuid tenant_id PK
    uuid pack_id PK
    int version_no PK
    uuid document_id
  }
```

## Notes

- `PLAN_VERSION.plan_id` is a finance plan, not a scheme plan (`product.plan`); DBE-001 will name it `finance_plan_id` to avoid the clash.
- `REVENUE_RESULT.engine_version` is `FE-08@<version>`. Employee-level data is masked or aggregated (PRD-015 NFR-PRIV-003).
