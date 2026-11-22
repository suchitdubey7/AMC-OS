# D17 AI and Decision Intelligence — `ai`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Assistants, sessions and governance

```mermaid
erDiagram
  AGENT_DEFINITION_VERSION ||--o{ AGENT : "enabled as"
  PROMPT_VERSION ||--o{ AGENT_DEFINITION_VERSION : "used by"
  AGENT ||--o{ SESSION : "runs"
  SESSION ||--|{ MESSAGE : "contains"
  SESSION ||--o{ TOOL_CALL_LOG : "calls"
  TOOL ||--o{ TOOL_CALL_LOG : "called as"
  SESSION ||--o{ RETRIEVAL_LOG : "retrieves"
  CORPUS_DOCUMENT ||--o{ RETRIEVAL_LOG : "retrieved"
  AGENT ||--o{ PROPOSAL : "drafts"
  SESSION ||--o{ FEEDBACK : "rated"
  EVALUATION_SUITE ||--o{ EVALUATION_RESULT : "produces"
  MODEL_REGISTRY ||--o{ AGENT_DEFINITION_VERSION : "model of"
  AGENT ||--o{ USAGE_COUNTER : "counted"
  AGENT_DEFINITION_VERSION {
    uuid tenant_id PK
    text agent_code PK
    int version_no PK
    text model_ref
    text prompt_version
    text risk_tier
    bytea content_hash
  }
  AGENT {
    uuid tenant_id PK
    text agent_code PK
    int enabled_version
    uuid service_user_id
    text status
  }
  PROMPT_VERSION {
    uuid tenant_id PK
    text prompt_code PK
    int version_no PK
    bytea content_hash
  }
  TOOL {
    uuid tenant_id PK
    text tool_name PK
    int version_no PK
    text owning_module
    text tool_kind
  }
  SESSION {
    uuid tenant_id PK
    uuid session_id PK
    text agent_code FK
    uuid user_id
    timestamptz started_at
  }
  MESSAGE {
    uuid tenant_id PK
    uuid session_id PK
    int message_seq PK
    text role
    text content_masked
  }
  TOOL_CALL_LOG {
    uuid tenant_id PK
    timestamptz called_at PK
    uuid call_id PK
    uuid session_id
    text tool_name
    jsonb input_payload
    text outcome
  }
  RETRIEVAL_LOG {
    uuid tenant_id PK
    timestamptz retrieved_at PK
    uuid retrieval_id PK
    uuid session_id
    uuid corpus_document_id
  }
  PROPOSAL {
    uuid tenant_id PK
    uuid proposal_id PK
    text agent_code FK
    text target_module
    text target_workflow
    timestamptz expires_at
    text status
  }
  FEEDBACK {
    uuid tenant_id PK
    uuid feedback_id PK
    uuid session_id
    text rating
  }
  EVALUATION_SUITE {
    uuid tenant_id PK
    uuid suite_id PK
    int version_no PK
  }
  EVALUATION_RESULT {
    uuid tenant_id PK
    uuid result_id PK
    uuid suite_id FK
    int version_no
    text agent_code FK
  }
  MODEL_REGISTRY {
    uuid tenant_id PK
    text model_ref PK
    int version_no PK
    text validation_status
  }
  CORPUS_DOCUMENT {
    uuid tenant_id PK
    uuid corpus_document_id PK
    int version_no PK
    text source
    text licence_tag
  }
  KILL_SWITCH_EVENT {
    uuid tenant_id PK
    uuid event_id PK
    text scope
    bool engaged
  }
  USAGE_COUNTER {
    uuid tenant_id PK
    date usage_date PK
    text agent_code PK
    bigint calls
  }
```

## Notes

- Assistant definitions are released by the vendor and copied identically into each tenant (D-73, DM-15). `AGENT.service_user_id` is an ID reference to `identity.app_user` (DM-20). A proposal enters the normal approval of the owning module; it never approves itself (ADR-0008).
- `TOOL_CALL_LOG` and `RETRIEVAL_LOG` are partitioned monthly, so `session_id` there is a plain ID column. Embeddings are in the separate pgvector cluster (ADR-0007), not in this schema.
