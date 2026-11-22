# D12 Fund Operations — `operations`, `workflow`, `documents`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Connections, files and reconciliation (`operations`)

```mermaid
erDiagram
  CONNECTION ||--o{ INBOUND_FILE : "delivers"
  CONNECTION ||--o{ OUTBOUND_FILE : "sends"
  CONNECTION ||--o{ EXPECTED_FILE : "scheduled on"
  EXPECTED_FILE ||--o{ EXPECTED_FILE_STATUS : "tracked daily"
  INBOUND_FILE |o--o{ EXPECTED_FILE_STATUS : "fulfils"
  RECON_DEFINITION ||--o{ RECON_RUN : "run as"
  RECON_RUN ||--o{ RECON_MATCH : "matches"
  RECON_RUN ||--o{ RECON_BREAK : "breaks"
  RECON_BREAK ||--o{ BREAK_ACTION : "worked by"
  CORPORATE_ACTION ||--|{ CORPORATE_ACTION_SOURCE : "announced by"
  CORPORATE_ACTION ||--o{ ENTITLEMENT : "entitles"
  ENTITLEMENT ||--o{ ELECTION : "elected"
  CONNECTION {
    uuid tenant_id PK
    uuid connection_id PK
    text provider
    text channel
    text owning_module
    text credential_ref
    interval ack_time_limit
    daterange valid_period
  }
  INBOUND_FILE {
    uuid tenant_id PK
    uuid file_id PK
    uuid connection_id FK
    bytea sha256
    text raw_object_ref
    text parse_status
  }
  OUTBOUND_FILE {
    uuid tenant_id PK
    uuid outbound_file_id PK
    uuid connection_id FK
    bytea sha256
    text instruction_ref
  }
  EXPECTED_FILE {
    uuid tenant_id PK
    uuid expected_file_id PK
    uuid connection_id FK
    text file_kind
    time due_by
    daterange valid_period
  }
  EXPECTED_FILE_STATUS {
    uuid tenant_id PK
    date business_date PK
    uuid expected_file_id PK
    uuid file_id FK
    text status
  }
  RECON_DEFINITION {
    uuid tenant_id PK
    uuid definition_id PK
    int version_no PK
    text recon_type
  }
  RECON_RUN {
    uuid tenant_id PK
    uuid recon_run_id PK
    uuid definition_id FK
    int version_no
    date business_date
    text status
  }
  RECON_MATCH {
    uuid tenant_id PK
    uuid recon_run_id PK
    uuid match_id PK
    text left_ref
    text right_ref
  }
  RECON_BREAK {
    uuid tenant_id PK
    uuid break_id PK
    uuid recon_run_id FK
    numeric difference
    text state
  }
  BREAK_ACTION {
    uuid tenant_id PK
    uuid action_id PK
    uuid break_id FK
    text action
  }
  EXCEPTION {
    uuid tenant_id PK
    uuid exception_id PK
    text source_module
    text state
  }
  CORPORATE_ACTION {
    uuid tenant_id PK
    uuid corporate_action_id PK
    uuid security_id FK
    text action_type
    date ex_date
    text state
  }
  CORPORATE_ACTION_SOURCE {
    uuid tenant_id PK
    uuid corporate_action_id PK
    uuid source_id PK
    uuid load_run_id
  }
  ENTITLEMENT {
    uuid tenant_id PK
    uuid entitlement_id PK
    uuid corporate_action_id FK
    uuid scheme_id FK
    numeric quantity
    text state
  }
  ELECTION {
    uuid tenant_id PK
    uuid election_id PK
    uuid entitlement_id FK
    text option
    text state
  }
```

## Day plan, cut-offs and checklists (`operations`)

```mermaid
erDiagram
  CHECKLIST_DEFINITION ||--o{ DAY_CLOSE : "used in"
  DAY_PLAN ||--o| DAY_CLOSE : "closed by"
  DAY_PLAN {
    uuid tenant_id PK
    date business_date PK
    text state
  }
  CUTOFF {
    uuid tenant_id PK
    text cutoff_code PK
    daterange valid_period PK
    time cutoff_time
    text calendar_code
  }
  CHECKLIST_DEFINITION {
    uuid tenant_id PK
    uuid checklist_id PK
    int version_no PK
  }
  DAY_CLOSE {
    uuid tenant_id PK
    date business_date PK
    uuid checklist_id FK
    int version_no
    text state
  }
```

## Approvals and tasks (`workflow`) and documents (`documents`)

```mermaid
erDiagram
  APPROVAL_CHAIN ||--o{ APPROVAL_REQUEST : "governs"
  APPROVAL_REQUEST ||--o{ APPROVAL_DECISION : "decided by"
  ACTOR_REF ||--o{ APPROVAL_DECISION : "checked against"
  RETENTION_CLASS ||--o{ DOCUMENT : "kept for"
  DOCUMENT ||--o{ LEGAL_HOLD : "held by"
  DOCUMENT ||--o| DISPOSAL_RECORD : "disposed"
  APPROVAL_CHAIN {
    uuid tenant_id PK
    text chain_code PK
    int version_no PK
    smallint required_approvals
  }
  APPROVAL_REQUEST {
    uuid tenant_id PK
    uuid request_id PK
    text object_type
    uuid object_id
    int object_version
    text action
    text status
    uuid maker_user_id
  }
  APPROVAL_DECISION {
    uuid tenant_id PK
    uuid request_id PK
    uuid approver_user_id PK
    text decision
    timestamptz decided_at
  }
  ACTOR_REF {
    uuid tenant_id PK
    uuid user_id PK
    bool is_service_identity
    text status
  }
  TASK {
    uuid tenant_id PK
    uuid task_id PK
    text task_type
    uuid assignee_user_id
    text state
    timestamptz due_at
  }
  DELEGATION {
    uuid tenant_id PK
    uuid delegation_id PK
    uuid from_user_id
    uuid to_user_id
    daterange valid_period
  }
  DOCUMENT {
    uuid tenant_id PK
    uuid document_id PK
    int version_no PK
    text object_key
    bytea sha256
    text classification
    text retention_class FK
  }
  RETENTION_CLASS {
    uuid tenant_id PK
    text class_code PK
    int version_no PK
    text period_ref
  }
  LEGAL_HOLD {
    uuid tenant_id PK
    uuid hold_id PK
    uuid document_id FK
    text state
  }
  DISPOSAL_RECORD {
    uuid tenant_id PK
    uuid disposal_id PK
    uuid document_id FK
    timestamptz disposed_at
  }
```

## Notes

- `CORPORATE_ACTION`, `ENTITLEMENT`, `ELECTION` are owned by Operations (EA-003 T3, DM-8) — **(ADR-0020)**.
- `OUTBOUND_FILE.instruction_ref` points by ID at the owning module's instruction (DA-001 §3.5). `ACTOR_REF` is Workflow's read model of Identity (DM-20).
- Retention periods are **[VAL]** for REG-001 (Step 25); `RETENTION_CLASS.period_ref` points to the REG-001 entry.
