# D10 Fund Accounting — `accounting`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Chart of accounts, journals and sub-ledgers

```mermaid
erDiagram
  ACCOUNT ||--o{ ACCOUNT : "parent of"
  ACCOUNT ||--o{ SCHEME_ACCOUNT : "used by scheme"
  SCHEME_ACCOUNT ||--o{ JOURNAL_LINE : "posted to"
  POSTING_RULE ||--o{ POSTING_RULE_TEST : "tested by"
  POSTING_RULE ||--o{ JOURNAL_BATCH : "produced"
  JOURNAL_BATCH ||--|{ JOURNAL_LINE : "contains (balanced)"
  JOURNAL_BATCH |o--o| JOURNAL_BATCH : "reverses"
  ACCRUAL_RUN ||--o{ JOURNAL_BATCH : "posts"
  OPEN_ITEM ||--o{ JOURNAL_BATCH : "settled by"
  ACCOUNT {
    uuid tenant_id PK
    text account_code PK
    daterange valid_period PK
    text account_class
    char normal_balance
    text parent_code
    text statement_line
  }
  SCHEME_ACCOUNT {
    uuid tenant_id PK
    uuid scheme_id PK
    text account_code PK
    daterange valid_period PK
  }
  PERIOD {
    uuid tenant_id PK
    uuid scheme_id PK
    text period_type PK
    daterange period_range PK
    text status
    text reopen_reason
  }
  POSTING_RULE {
    uuid tenant_id PK
    text rule_code PK
    int version_no PK
    text source_type
    daterange valid_period
  }
  POSTING_RULE_TEST {
    uuid tenant_id PK
    uuid test_id PK
    text rule_code FK
    int version_no
  }
  JOURNAL_BATCH {
    uuid tenant_id PK
    uuid batch_id PK
    uuid scheme_id FK
    date accounting_date
    date effective_date
    text source_type
    uuid source_id
    text posting_rule_code
    int posting_rule_version
    uuid reverses_batch_id FK
    text idempotency_key UK
  }
  JOURNAL_LINE {
    uuid tenant_id PK
    date accounting_date PK
    uuid line_id PK
    uuid batch_id FK
    text account_code
    char dr_cr
    numeric amount
  }
  ACCRUAL_RUN {
    uuid tenant_id PK
    uuid accrual_run_id PK
    uuid scheme_id FK
    date accrual_date
    jsonb input_manifest
    text state
  }
  OPEN_ITEM {
    uuid tenant_id PK
    uuid open_item_id PK
    uuid scheme_id FK
    text item_type
    numeric open_amount
    date due_date
  }
  SUSPENSE_ITEM {
    uuid tenant_id PK
    uuid suspense_item_id PK
    uuid scheme_id FK
    numeric amount
    text state
  }
  MIRROR_LEDGER_LINE {
    uuid tenant_id PK
    date ledger_date PK
    uuid line_id PK
    uuid scheme_id FK
    uuid load_run_id
  }
  MIRROR_TRIAL_BALANCE {
    uuid tenant_id PK
    uuid scheme_id PK
    date tb_date PK
    text account_code PK
    numeric balance
    uuid load_run_id
  }
```

## Notes

- `ACCOUNT` is effective-dated; a line's account must be valid on the line's date and active for the scheme in `SCHEME_ACCOUNT` (DM-12). Because `ACCOUNT`'s key includes `valid_period`, the line-to-account link is checked by the posting trigger, not by a plain foreign key.
- `source_id` is an ID reference to the event's aggregate (trade, NAV run, investor flow …); `scheme_id` goes to `product.scheme`. Mirror tables are used only for schemes in custodian-mirror mode (D-16, D-40).
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `accounting.load_run`, `accounting.trial_balance`.
