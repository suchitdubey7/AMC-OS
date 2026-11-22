# D01 Platform Administration — `platform`, `identity`, `audit`

Annex of [DA-001](../../docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md) (canonical enterprise data model), Step 15. Status: **Draft** — same status and approver as DA-001; these annexes carry no ID of their own. Only key columns and a few main columns are shown; the full column list of every table is the data dictionary DBE-001 (Step 17).

**How to read:** every tenant table's key starts with `tenant_id` (shown first, `PK`). `||--o{` = one to zero-or-many, `||--|{` = one to one-or-many, `||--o|` = one to zero-or-one, `|o--o|` = optional link to a row of the same kind. A bi-temporal entity that other rows point at (for example a security or an investor) is drawn once, as its anchor; its `_version` table (DA-001 §3.1) is implied. Boxes named `MASTER_…`, `PRODUCT_…` stand for tables in the reference schemas `master` and `product` (foreign keys allowed, DA-001 M4); a link to any other schema is an ID reference and is not drawn as a line.

## Tenant, cell, organisation and configuration (`platform`)

```mermaid
erDiagram
  CELL ||--o{ TENANT : "hosts"
  TENANT ||--o{ TENANT_STATUS_HISTORY : "changes"
  TENANT ||--o{ SUBSCRIPTION : "has"
  TENANT ||--o{ TENANT_ENTITLEMENT : "may use"
  TENANT ||--o{ ORGANISATION_UNIT : "organised as"
  ORGANISATION_UNIT ||--o{ ORGANISATION_UNIT : "parent of"
  ORGANISATION_UNIT ||--o{ REPORTING_LINE : "has"
  TENANT ||--o{ BUSINESS_CALENDAR : "uses"
  CONFIG_ITEM ||--o{ CONFIG_VALUE : "set by"
  CONFIG_VERSION ||--|{ CONFIG_VALUE : "contains"
  CONFIG_VERSION ||--o{ CONFIG_PROMOTION : "promoted in"
  TENANT ||--o{ SCHEDULE_ENTRY : "schedules"
  TENANT ||--o{ TENANT_REMOVAL_AUTHORISATION : "authorises"
  TENANT {
    uuid tenant_id PK
    text tenant_code UK
    text isolation_tier
    text hosting_account
    uuid cell_id FK
    text status
    text kms_key_ref
  }
  CELL {
    uuid cell_id PK
    text kind
    text shape
    text region
  }
  TENANT_STATUS_HISTORY {
    uuid tenant_id PK
    timestamptz changed_at PK
    text from_status
    text to_status
    uuid confirmed_by
  }
  SUBSCRIPTION {
    uuid tenant_id PK
    uuid subscription_id PK
    text plan_code
    daterange valid_period
  }
  TENANT_ENTITLEMENT {
    uuid tenant_id PK
    text module_code PK
    daterange valid_period PK
    numeric limit_value
  }
  ORGANISATION_UNIT {
    uuid tenant_id PK
    uuid org_unit_id PK
    uuid parent_org_unit_id FK
    text unit_type
    daterange valid_period
  }
  REPORTING_LINE {
    uuid tenant_id PK
    uuid reporting_line_id PK
    uuid org_unit_id FK
    uuid manager_user_id
    daterange valid_period
  }
  BUSINESS_CALENDAR {
    uuid tenant_id PK
    text calendar_code PK
    date calendar_date PK
    bool is_business_day
    timestamptz recorded_at
  }
  CONFIG_ITEM {
    text item_key PK
    text release PK
    text value_type
    bool required
  }
  CONFIG_VERSION {
    uuid tenant_id PK
    uuid config_version_id PK
    text state
    date effective_from
    uuid approval_request_id
  }
  CONFIG_VALUE {
    uuid tenant_id PK
    uuid config_version_id PK
    text item_key PK
    text scope_type PK
    uuid scope_id PK
    text value
  }
  CONFIG_PROMOTION {
    uuid tenant_id PK
    uuid promotion_id PK
    uuid config_version_id FK
    bytea bundle_hash
  }
  SCHEDULE_ENTRY {
    uuid tenant_id PK
    uuid schedule_entry_id PK
    text job_code
    text calendar_rule
    uuid approval_request_id
  }
  TENANT_REMOVAL_AUTHORISATION {
    uuid tenant_id PK
    uuid authorisation_id PK
    text purpose
    text state
    timestamptz expires_at
  }
```

## Users, roles and grants (`identity`)

```mermaid
erDiagram
  ROLE ||--o{ ROLE_PERMISSION : "grants"
  PERMISSION ||--o{ ROLE_PERMISSION : "granted by"
  APP_USER ||--o{ USER_ROLE : "holds"
  ROLE ||--o{ USER_ROLE : "assigned via"
  USER_ROLE ||--o{ SCOPE_ATTRIBUTE : "limited by"
  APP_USER ||--o{ ROLE_GRANT_REQUEST : "subject of"
  ROLE ||--o{ APPROVAL_AUTHORITY : "may approve"
  APP_USER ||--o{ SESSION : "signs in"
  APP_USER ||--o| API_CLIENT : "service account"
  RECERTIFICATION_CAMPAIGN ||--|{ RECERTIFICATION_ITEM : "reviews"
  APP_USER {
    uuid tenant_id PK
    uuid user_id PK
    text external_subject UK
    bool is_service_identity
    text status
  }
  ROLE {
    uuid tenant_id PK
    text role_code PK
  }
  PERMISSION {
    text permission_code PK
    bool is_approval
    bool ai_forbidden
  }
  ROLE_PERMISSION {
    uuid tenant_id PK
    text role_code PK
    text permission_code PK
    daterange valid_period PK
  }
  USER_ROLE {
    uuid tenant_id PK
    uuid user_id PK
    text role_code PK
    daterange valid_period PK
    uuid granted_by
    uuid approved_by
  }
  SCOPE_ATTRIBUTE {
    uuid tenant_id PK
    uuid user_id PK
    text role_code PK
    daterange valid_period PK
    text attribute PK
    text value PK
  }
  ROLE_GRANT_REQUEST {
    uuid tenant_id PK
    uuid request_id PK
    uuid user_id FK
    text role_code FK
    text state
  }
  APPROVAL_AUTHORITY {
    uuid tenant_id PK
    uuid authority_id PK
    text role_code FK
    text action
    numeric limit_amount
    daterange valid_period
  }
  SESSION {
    uuid tenant_id PK
    uuid session_id PK
    uuid user_id FK
    timestamptz started_at
  }
  API_CLIENT {
    uuid tenant_id PK
    uuid client_id PK
    uuid user_id FK
    text integration_code
  }
  RECERTIFICATION_CAMPAIGN {
    uuid tenant_id PK
    uuid campaign_id PK
    text state
  }
  RECERTIFICATION_ITEM {
    uuid tenant_id PK
    uuid campaign_id PK
    uuid user_id PK
    text role_code PK
    text decision
  }
  BREAK_GLASS_GRANT {
    uuid tenant_id PK
    uuid grant_id PK
    text scope
    timestamptz expires_at
    text state
  }
```

## Audit (`audit`)

```mermaid
erDiagram
  AUDIT_EVENT |o--o| AUDIT_EVENT : "prev_hash links"
  CHAIN_ANCHOR ||--o{ AUDIT_EVENT : "anchors day of"
  IMPORT_RUN ||--o{ AUDIT_EVENT : "imported"
  AUDIT_EVENT {
    uuid tenant_id PK
    timestamptz occurred_at PK
    bigint event_seq PK
    text actor_type
    text action
    text object_type
    uuid object_id
    bytea prev_hash
    bytea row_hash
  }
  CHAIN_ANCHOR {
    uuid tenant_id PK
    date anchor_date PK
    bytea head_hash
    text worm_object_ref
  }
  ACCESS_LOG {
    uuid tenant_id PK
    timestamptz accessed_at PK
    uuid access_id PK
    uuid user_id
    text object_type
    text reason
  }
  IMPORT_RUN {
    uuid tenant_id PK
    uuid import_run_id PK
    bigint first_seq
    bigint last_seq
    text chain_check
  }
```

## Notes

- `identity.permission`, `platform.config_item` and `platform.cell` have no tenant column (DA-001 M3). `CONFIG_VALUE` points at `CONFIG_ITEM` by `item_key` and the release of its version (column detail in DBE-001).
- `identity.user_role.approved_by` and `granted_by` point at `identity.app_user` (SOD-05). Cross-schema user references from other modules (for example `created_by`) are ID references (DA-001 M4).
- Not drawn here, to keep the diagram readable (listed in DA-001 §4): `platform.usage_meter`, `platform.code_list`, `platform.code_value`, `platform.feature_flag`, `platform.environment_release`, `platform.notification_channel`.
