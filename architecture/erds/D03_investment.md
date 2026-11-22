# D03 Investment Management — `investment`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Research, decisions and controls

```mermaid
erDiagram
  PRODUCT_SCHEME ||--o{ UNIVERSE_MEMBER : "may hold"
  MASTER_SECURITY ||--o{ UNIVERSE_MEMBER : "approved in"
  MASTER_SECURITY ||--o{ RESTRICTED_LIST_ENTRY : "restricted by"
  MASTER_SECURITY ||--o{ RECOMMENDATION : "subject of"
  PRODUCT_SCHEME ||--o{ DECISION_RECORD : "decided for"
  PRODUCT_SCHEME ||--o{ SCHEME_STRATEGY : "follows"
  RESEARCH_NOTE ||--|{ RESEARCH_NOTE_VERSION : "versioned as"
  IC_MEETING ||--|{ IC_AGENDA_ITEM : "discusses"
  IC_AGENDA_ITEM ||--o{ IC_VOTE : "voted by"
  UNIVERSE_MEMBER {
    uuid tenant_id PK
    uuid scheme_id PK
    uuid security_id PK
    daterange valid_period PK
    text status
  }
  RESTRICTED_LIST_ENTRY {
    uuid tenant_id PK
    uuid entry_id PK
    uuid security_id FK
    daterange valid_period
    text reason
  }
  DECISION_RECORD {
    uuid tenant_id PK
    uuid decision_id PK
    uuid scheme_id FK
    text rationale
    timestamptz decided_at
  }
  RESEARCH_NOTE {
    uuid tenant_id PK
    uuid note_id PK
    uuid issuer_id FK
    uuid author_user_id
  }
  RESEARCH_NOTE_VERSION {
    uuid tenant_id PK
    uuid note_id PK
    int version_no PK
    uuid document_id
  }
  RECOMMENDATION {
    uuid tenant_id PK
    uuid recommendation_id PK
    int version_no PK
    uuid security_id FK
    text call
    text thesis
  }
  COVERAGE {
    uuid tenant_id PK
    uuid analyst_user_id PK
    uuid issuer_id PK
    daterange valid_period PK
  }
  IC_MEETING {
    uuid tenant_id PK
    uuid meeting_id PK
    date meeting_date
    text state
  }
  IC_AGENDA_ITEM {
    uuid tenant_id PK
    uuid meeting_id PK
    int item_no PK
    text subject
  }
  IC_VOTE {
    uuid tenant_id PK
    uuid meeting_id PK
    int item_no PK
    uuid member_user_id PK
    text vote
    bool conflict_declared
  }
  CREDIT_APPROVAL {
    uuid tenant_id PK
    uuid issuer_id PK
    int version_no PK
    numeric limit_amount
    date review_date
  }
  HOUSE_VIEW {
    uuid tenant_id PK
    uuid view_id PK
    int version_no PK
  }
  SCHEME_STRATEGY {
    uuid tenant_id PK
    uuid scheme_id PK
    int version_no PK
  }
  INVESTMENT_POLICY {
    uuid tenant_id PK
    uuid policy_id PK
    int version_no PK
    daterange valid_period
  }
  INTERNAL_LIMIT_REQUEST {
    uuid tenant_id PK
    uuid request_id PK
    text state
    uuid compliance_rule_id
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

- `MASTER_SECURITY` = `master.security`, `PRODUCT_SCHEME` = `product.scheme` (reference schemas; foreign keys allowed). Issuer links go to `master.issuer` the same way.
- `INTERNAL_LIMIT_REQUEST.compliance_rule_id` is an ID reference to `compliance.rule` (DA-001 M4).
