# D06 Trading and Execution — `execution`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn as one box that **merges its anchor and the columns of its current version**; in the database the anchor holds only the key and the changing columns sit in the implied `_version` table (DA-001 §3.1 rule 1). Business-code unique keys on such entities (PAN keyed hash, ISIN) are exclusion constraints on the version table (rule 3), so they are not marked `UK` in the box. Keys of other bi-temporal tables also include `recorded_at` (rule 2), not shown. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Broker orders, fills, trades and contract notes

```mermaid
erDiagram
  MASTER_COUNTERPARTY ||--o| BROKER : "acts as"
  BROKER ||--o{ BROKER_LIMIT : "limited by"
  BROKER ||--o{ BROKERAGE_RATE : "charges"
  BROKER ||--o{ BROKER_EVALUATION : "evaluated in"
  BROKER ||--o{ BROKER_ORDER : "receives"
  BROKER_ORDER ||--|{ BROKER_ORDER_ATTEMPT : "sent via"
  BROKER_ORDER ||--o{ FILL : "executed by"
  FILL ||--|| FILL_DEDUP_KEY : "unique by"
  TRADE ||--|{ ALLOCATION : "allocated to orders"
  BROKER ||--o{ CONTRACT_NOTE : "sends"
  CONTRACT_NOTE ||--o{ CONTRACT_NOTE_MATCH : "matched in"
  TRADE ||--o{ CONTRACT_NOTE_MATCH : "confirmed by"
  TRADE ||--o{ TRADE_EXCEPTION : "breaks"
  BROKER {
    uuid tenant_id PK
    uuid broker_id PK
    uuid counterparty_id FK
    text broker_code UK
    text empanelment_status
    daterange valid_period
  }
  BROKER_LIMIT {
    uuid tenant_id PK
    uuid broker_id PK
    text limit_type PK
    daterange valid_period PK
    numeric limit_amount
  }
  BROKERAGE_RATE {
    uuid tenant_id PK
    uuid broker_id PK
    text instrument_class PK
    daterange valid_period PK
    numeric rate
  }
  BROKER_EVALUATION {
    uuid tenant_id PK
    uuid evaluation_id PK
    uuid broker_id FK
    date period_end
  }
  BROKER_ORDER {
    uuid tenant_id PK
    uuid broker_order_id PK
    uuid order_id
    uuid broker_id FK
    text delivery_state
    text client_reference UK
    text idempotency_key UK
  }
  BROKER_ORDER_ATTEMPT {
    uuid tenant_id PK
    uuid attempt_id PK
    uuid broker_order_id FK
    text action
    timestamptz at
  }
  RAW_MESSAGE {
    uuid tenant_id PK
    timestamptz received_at PK
    uuid message_id PK
    text session
    text body_ref
  }
  FILL {
    uuid tenant_id PK
    timestamptz executed_at PK
    uuid fill_id PK
    uuid broker_order_id FK
    text broker_exec_id
    numeric quantity
    numeric price
  }
  FILL_DEDUP_KEY {
    uuid tenant_id PK
    text broker_code PK
    text broker_exec_id PK
    uuid fill_id
  }
  TRADE {
    uuid tenant_id PK
    uuid trade_id PK
    uuid security_id FK
    date trade_date
    date settlement_date
    numeric gross_amount
    numeric charges
    numeric net_amount
    text status
  }
  ALLOCATION {
    uuid tenant_id PK
    uuid allocation_id PK
    uuid trade_id FK
    uuid order_id
    numeric allocated_quantity
    numeric average_price
    uuid deviation_approval_id
  }
  CONTRACT_NOTE {
    uuid tenant_id PK
    uuid contract_note_id PK
    uuid broker_id FK
    date trade_date
    uuid document_id
  }
  CONTRACT_NOTE_MATCH {
    uuid tenant_id PK
    uuid match_id PK
    uuid contract_note_id FK
    uuid trade_id FK
    text outcome
  }
  TRADE_EXCEPTION {
    uuid tenant_id PK
    uuid break_id PK
    uuid trade_id FK
    text state
  }
  TRADE_CHARGE_RATE {
    uuid tenant_id PK
    text charge_type PK
    text instrument_class PK
    daterange valid_period PK
    numeric rate
  }
  MASTER_COUNTERPARTY {
    uuid tenant_id PK
    uuid counterparty_id PK
  }
```

## Notes

- `TRADE` and `ALLOCATION` move here from `settlement.trade` and `trading.block_allocation` (DM-7) — **(ADR-0020)**. Fills link to trades through the allocation run; the exact fill-to-trade grouping is set in the Execution / FE-06 specification (EA-007 G10).
- `order_id` columns are ID references to `trading."order"`; `document_id` to `documents.document`.
- `BROKER_ORDER` uses the outbound-instruction pattern (DA-001 §3.5) with the unknown-outcome states of EA-007 §10.6.
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `execution.external_trade_evidence`, `execution.load_run`.
