# D05 Order Management System — `trading`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Orders, versions and blocks

```mermaid
erDiagram
  ORDER ||--|{ ORDER_VERSION : "versioned as"
  ORDER ||--|{ ORDER_EVENT : "state history"
  ORDER_STATE_TRANSITION ||--o{ ORDER : "constrains"
  BLOCK ||--|{ BLOCK_ALLOCATION : "contains"
  ORDER ||--o{ BLOCK_ALLOCATION : "member of"
  ORDER_VERSION ||--o{ COMPLIANCE_RESULT_REF : "checked by"
  ORDER ||--o{ WARN_ACKNOWLEDGEMENT : "acknowledged"
  ORDER ||--o{ RFQ_QUOTE : "quoted"
  ORDER {
    uuid tenant_id PK
    uuid order_id PK
    int current_version
    uuid scheme_id FK
    uuid security_id FK
    text side
    numeric filled_quantity
    text state
    uuid decision_id
    text idempotency_key UK
  }
  ORDER_VERSION {
    uuid tenant_id PK
    uuid order_id PK
    int order_version PK
    numeric quantity
    numeric amount
    numeric limit_price
    text order_type
    text cause
  }
  ORDER_EVENT {
    uuid tenant_id PK
    uuid event_id PK
    uuid order_id FK
    int order_version
    text from_state
    text to_state
    timestamptz occurred_at
  }
  ORDER_STATE_TRANSITION {
    text from_state PK
    text to_state PK
    text cause PK
  }
  BLOCK {
    uuid tenant_id PK
    uuid block_id PK
    uuid security_id FK
    text state
  }
  BLOCK_ALLOCATION {
    uuid tenant_id PK
    uuid allocation_id PK
    uuid block_id FK
    uuid order_id FK
    numeric intent_pct
  }
  COMPLIANCE_RESULT_REF {
    uuid tenant_id PK
    uuid order_id PK
    int order_version PK
    text check_kind PK
    uuid check_result_id
    text outcome
  }
  WARN_ACKNOWLEDGEMENT {
    uuid tenant_id PK
    uuid ack_id PK
    uuid order_id FK
    int order_version
    uuid user_id
  }
  RFQ_QUOTE {
    uuid tenant_id PK
    uuid quote_id PK
    uuid order_id FK
    uuid broker_id
    numeric price
  }
```

## Notes

- `ORDER` is `trading."order"`. `decision_id` (to `investment.decision_record`), `check_result_id` (to `compliance.check_result`) and `broker_id` (to `execution.broker`) are ID references (DA-001 M4, DM-20). Scheme and security keys go to the reference schemas.
- `ORDER_STATE_TRANSITION` has no tenant column (product definition list, DA-001 M3); `cause` is `STATE_CHANGE`, `AMEND` or `REROUTE` (DM-5, DM-6).
- Allocation **results** are in `execution.allocation` (DM-7, ADR-0020).
