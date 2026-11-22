# D13 Investor Management and Servicing — `investor`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn as one box that **merges its anchor and the columns of its current version**; in the database the anchor holds only the key and the changing columns sit in the implied `_version` table (DA-001 §3.1 rule 1). Business-code unique keys on such entities (PAN keyed hash, ISIN) are exclusion constraints on the version table (rule 3), so they are not marked `UK` in the box. Keys of other bi-temporal tables also include `recorded_at` (rule 2), not shown. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Investors, folios and transactions

```mermaid
erDiagram
  INVESTOR ||--o{ FOLIO : "primary holder of"
  FOLIO ||--o{ FOLIO_HOLDER : "joint holders"
  INVESTOR ||--o{ FOLIO_HOLDER : "holds"
  FOLIO ||--o{ NOMINEE : "nominates"
  FOLIO ||--o{ BANK_ACCOUNT : "pays via"
  BANK_ACCOUNT ||--o{ MANDATE : "authorises"
  FOLIO ||--o{ INVESTOR_TXN : "transacts"
  PRODUCT_PLAN ||--o{ INVESTOR_TXN : "in"
  INVESTOR_TXN ||--|| TXN_DEDUP_KEY : "unique by"
  TXN_DEDUP_KEY }o--|| TXN_CURRENT : "latest is"
  INVESTOR_TXN ||--o{ DATA_FLAG : "flagged"
  PRODUCT_PLAN ||--o{ FLOW_BATCH : "flows"
  INVESTOR_TXN ||--o{ TXN_CHECK_RESULT : "checked"
  INVESTOR_TXN ||--o| PAYOUT : "paid by"
  FOLIO ||--o{ UNIT_LOT : "holds units"
  FOLIO ||--o{ SIP_REGISTRATION : "registers"
  MANDATE ||--o{ SIP_REGISTRATION : "funds"
  CODE_MAP ||--o{ INVESTOR_TXN : "maps codes of"
  INVESTOR {
    uuid tenant_id PK
    uuid investor_id PK
    bytea pan_ciphertext
    bytea pan_hmac
    char pan_last4
    text kyc_status
    uuid load_run_id
  }
  FOLIO {
    uuid tenant_id PK
    uuid folio_id PK
    text folio_number UK
    uuid primary_investor_id FK
    text holding_mode
    text status
  }
  FOLIO_HOLDER {
    uuid tenant_id PK
    uuid folio_id PK
    smallint holder_seq PK
    daterange valid_period PK
    uuid investor_id FK
  }
  NOMINEE {
    uuid tenant_id PK
    uuid folio_id PK
    smallint nominee_seq PK
    daterange valid_period PK
    numeric share_pct
  }
  BANK_ACCOUNT {
    uuid tenant_id PK
    uuid bank_account_id PK
    uuid folio_id FK
    bytea account_ciphertext
    daterange valid_period
  }
  MANDATE {
    uuid tenant_id PK
    uuid mandate_id PK
    uuid bank_account_id FK
    text state
  }
  INVESTOR_TXN {
    uuid tenant_id PK
    date txn_date PK
    uuid txn_id PK
    uuid folio_id FK
    uuid plan_id FK
    text txn_type
    text rta_txn_ref
    uuid supersedes_txn_id
    text rta_status
    text check_status
    numeric net_amount
    numeric units
  }
  TXN_DEDUP_KEY {
    uuid tenant_id PK
    text rta_code PK
    text rta_txn_ref PK
    text feed_kind PK
    text rta_record_ref PK
    bytea content_hash
    date txn_date
    uuid txn_id
  }
  TXN_CURRENT {
    uuid tenant_id PK
    text rta_code PK
    text rta_txn_ref PK
    date txn_date
    uuid txn_id
  }
  DATA_FLAG {
    uuid tenant_id PK
    uuid flag_id PK
    text object_type
    uuid object_id
    text state
  }
  FLOW_BATCH {
    uuid tenant_id PK
    uuid flow_batch_id PK
    uuid plan_id FK
    date flow_date
    text feed_kind
    text state
  }
  TXN_CHECK_RESULT {
    uuid tenant_id PK
    date txn_date PK
    uuid txn_id PK
    text check_code PK
    text outcome
  }
  UNIT_LOT {
    uuid tenant_id PK
    uuid lot_id PK
    uuid folio_id FK
    uuid plan_id FK
    numeric units_remaining
  }
  PAYOUT {
    uuid tenant_id PK
    uuid payout_id PK
    uuid txn_id
    date due_date
    text state
  }
  SIP_REGISTRATION {
    uuid tenant_id PK
    uuid sip_id PK
    uuid folio_id FK
    uuid mandate_id FK
    numeric amount
    text status
  }
  CODE_MAP {
    uuid tenant_id PK
    text rta_code PK
    text code_kind PK
    text source_code PK
    int version_no PK
    text canonical_value
  }
  PRODUCT_PLAN {
    uuid tenant_id PK
    uuid plan_id PK
  }
```

## Servicing, privacy and other registrations

```mermaid
erDiagram
  FOLIO_REF ||--o{ STP_REGISTRATION : "registers"
  FOLIO_REF ||--o{ SWP_REGISTRATION : "registers"
  FOLIO_REF ||--o{ IDCW_EXPECTED : "expects"
  FOLIO_REF ||--o{ SERVICE_REQUEST : "raises"
  INVESTOR_REF ||--o{ COMPLAINT : "files"
  INVESTOR_REF ||--o{ COMMUNICATION : "receives"
  PURPOSE ||--o{ CONSENT : "consented for"
  INVESTOR_REF ||--o{ CONSENT : "gives"
  INVESTOR_REF ||--o{ RIGHTS_REQUEST : "makes"
  STP_REGISTRATION {
    uuid tenant_id PK
    uuid stp_id PK
    uuid folio_id FK
    text status
  }
  SWP_REGISTRATION {
    uuid tenant_id PK
    uuid swp_id PK
    uuid folio_id FK
    text status
  }
  IDCW_EXPECTED {
    uuid tenant_id PK
    uuid declaration_id PK
    uuid folio_id PK
    uuid plan_id PK
    numeric expected_amount
  }
  SERVICE_REQUEST {
    uuid tenant_id PK
    uuid request_id PK
    uuid folio_id FK
    text state
  }
  COMPLAINT {
    uuid tenant_id PK
    uuid complaint_id PK
    uuid investor_id FK
    text external_ref
    text state
  }
  COMMUNICATION {
    uuid tenant_id PK
    uuid communication_id PK
    uuid investor_id FK
    text channel
    text state
  }
  PURPOSE {
    uuid tenant_id PK
    text purpose_code PK
    int version_no PK
  }
  CONSENT {
    uuid tenant_id PK
    uuid consent_id PK
    uuid investor_id FK
    text purpose_code FK
    daterange valid_period
  }
  RIGHTS_REQUEST {
    uuid tenant_id PK
    uuid rights_request_id PK
    uuid investor_id FK
    date due_date
    text state
  }
  FOLIO_REF {
    uuid tenant_id PK
    uuid folio_id PK
  }
  INVESTOR_REF {
    uuid tenant_id PK
    uuid investor_id PK
  }
```

## Notes

- `FOLIO_REF` and `INVESTOR_REF` are the `FOLIO` and `INVESTOR` entities of the first diagram, repeated so the second diagram stays readable.
- Release 1 mirrors the RTA (Q2, D-53): every loaded row carries `load_run_id` and provenance (DA-001 M9). `rta_status`, `check_status` and `PAYOUT` replace the DDL-000 single `state` (DM-13). `TXN_DEDUP_KEY` refuses exact replays across monthly partitions while newer RTA versions are stored as new rows linked by `supersedes_txn_id`; `TXN_CURRENT` points at the latest (DM-9). `DATA_FLAG.object_id` may point at an investor, folio or transaction (shown on the transaction only).
- Personal data columns are encrypted with tenant data keys and searched by keyed hash (DA-001 M22). `PAYOUT.txn_id` is a plain ID column because the partitioned transaction key includes `txn_date`.
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `investor.unit_balance`, `investor.platform_file`, `investor.platform_file_attempt`, `investor.external_identifier`, `investor.load_run`.
