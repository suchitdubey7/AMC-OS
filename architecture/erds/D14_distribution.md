# D14 Distribution Management — `distribution`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Distributors and mappings

```mermaid
erDiagram
  DISTRIBUTOR ||--o{ EUIN : "employs"
  DISTRIBUTOR ||--o{ KYD_RECORD : "verified by"
  DISTRIBUTOR ||--o{ HIERARCHY_LINK : "parent in"
  DISTRIBUTOR ||--|{ RM_MAPPING : "mapped"
  CHANNEL ||--o{ CHANNEL_ASSIGNMENT : "assigned"
  DISTRIBUTOR ||--o{ CHANNEL_ASSIGNMENT : "in"
  DISTRIBUTOR ||--o{ AGREEMENT : "signs"
  DISTRIBUTOR ||--o{ DUE_DILIGENCE_REVIEW : "reviewed"
  SEGMENT_RULE ||--o{ SEGMENT_MEMBER : "selects"
  DISTRIBUTOR {
    uuid tenant_id PK
    uuid distributor_id PK
    text arn UK
    text entity_type
    date arn_valid_to
    text empanelment_state
  }
  EUIN {
    uuid tenant_id PK
    uuid distributor_id PK
    text euin PK
    daterange valid_period PK
  }
  KYD_RECORD {
    uuid tenant_id PK
    uuid record_id PK
    uuid distributor_id FK
    daterange valid_period
    uuid load_run_id
  }
  HIERARCHY_LINK {
    uuid tenant_id PK
    uuid parent_id PK
    uuid child_id PK
    daterange valid_period PK
  }
  RM_MAPPING {
    uuid tenant_id PK
    uuid distributor_id PK
    daterange valid_period PK
    uuid rm_user_id
    uuid org_unit_id
  }
  CHANNEL {
    uuid tenant_id PK
    text channel_code PK
  }
  CHANNEL_ASSIGNMENT {
    uuid tenant_id PK
    uuid distributor_id PK
    daterange valid_period PK
    text channel_code FK
  }
  AGREEMENT {
    uuid tenant_id PK
    uuid distributor_id PK
    int version_no PK
    uuid document_id
  }
  DUE_DILIGENCE_REVIEW {
    uuid tenant_id PK
    uuid review_id PK
    uuid distributor_id FK
    text category
    date next_review
  }
  SEGMENT_RULE {
    uuid tenant_id PK
    uuid rule_id PK
    int version_no PK
  }
  SEGMENT_MEMBER {
    uuid tenant_id PK
    uuid rule_id PK
    uuid member_id PK
    date as_of_date PK
  }
```

## Commission and incentives

```mermaid
erDiagram
  COMMISSION_RUN |o--o| COMMISSION_RUN : "supersedes"
  COMMISSION_RUN ||--|{ COMMISSION_LINE : "contains"
  COMMISSION_LINE |o--o{ COMMISSION_LINE : "adjusted by"
  DISTRIBUTOR_REF ||--o{ COMMISSION_LINE : "earns"
  DISTRIBUTOR_REF ||--o{ CARRY_FORWARD_BALANCE : "carries"
  DISTRIBUTOR_REF ||--o{ RTA_BROKERAGE_LINE : "paid per RTA"
  COMMISSION_RUN ||--o{ BROKERAGE_COMPARISON : "compared"
  COMMISSION_RUN ||--o{ STATEMENT : "reported in"
  DISTRIBUTOR_REF ||--o{ DISPUTE : "raises"
  COMMISSION_RUN ||--o{ PAYMENT_FILE : "paid by"
  COMMISSION_RATE {
    uuid tenant_id PK
    text structure_code PK
    uuid plan_id PK
    text distributor_category PK
    daterange valid_period PK
    numeric trail_pct_pa
  }
  INCENTIVE_RULE {
    uuid tenant_id PK
    uuid rule_id PK
    int version_no PK
  }
  COMMISSION_RUN {
    uuid tenant_id PK
    uuid run_id PK
    date period_month
    text status
    uuid supersedes_run_id FK
    uuid prepared_by
    uuid approved_by
  }
  COMMISSION_LINE {
    uuid tenant_id PK
    uuid line_id PK
    uuid run_id FK
    uuid distributor_id FK
    uuid plan_id FK
    text line_type
    uuid adjusts_line_id FK
    numeric gross_commission
    numeric net_payable
  }
  CARRY_FORWARD_BALANCE {
    uuid tenant_id PK
    uuid distributor_id PK
    date period_month PK
    numeric amount
  }
  RTA_BROKERAGE_LINE {
    uuid tenant_id PK
    date period_month PK
    uuid line_id PK
    uuid distributor_id FK
    numeric amount
  }
  BROKERAGE_COMPARISON {
    uuid tenant_id PK
    uuid comparison_id PK
    uuid run_id FK
    numeric difference
  }
  STATEMENT {
    uuid tenant_id PK
    uuid statement_id PK
    uuid run_id FK
    uuid distributor_id FK
  }
  DISPUTE {
    uuid tenant_id PK
    uuid dispute_id PK
    uuid distributor_id FK
    text state
  }
  PAYMENT_FILE {
    uuid tenant_id PK
    uuid payment_file_id PK
    uuid run_id FK
    text delivery_state
  }
  DISTRIBUTOR_REF {
    uuid tenant_id PK
    uuid distributor_id PK
  }
```

## Notes

- `DISTRIBUTOR_REF` is the `DISTRIBUTOR` entity of the first diagram. Empanelment states follow FR-D14-017 (DM-14). `COMMISSION_LINE` has its own key, a line type and `adjusts_line_id`; `COMMISSION_RUN` has `supersedes_run_id` (DM-14).
- Staff incentive schemes and results, sales forecasts and opportunities are in DA-001 §4.20 and left out of the diagram for size. `plan_id` goes to `product.plan` (reference schema).
