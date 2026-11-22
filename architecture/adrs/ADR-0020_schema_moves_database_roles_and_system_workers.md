---
id: ADR-0020
title: Table moves between schemas, one database role per module, and named system-worker exceptions
status: Draft
date: 2026-11-22
deciders: ARB (interim: project owner)
domains: D01, D06, D07, D12, D16, all modules (database roles)
related: GOV-002 §2; ADR-0002; ADR-0003; ADR-0006; ADR-0017; EA-003 §7 (T1, T3, T15, B1, B2, B8); EA-004 §11; EA-005 §2, §2.1, §6, §9; EA-007 D1–D6, §9.4, §13; DA-001 §3.2, §8, M4, DM-4, DM-7, DM-8, DM-17, DM-18, DM-19, DM-20; DDL-000 §16–§17; STD-001 §4
---

# ADR-0020: Table moves between schemas, one database role per module, and named system-worker exceptions

> Drafted at the owner's request on 22 Nov 2026 (chat), on a `proposal/` branch outside the build-loop chain. It is a Draft proposal for the owner (interim ARB). Nothing here is decided until the owner accepts it. It builds on Draft documents that are not yet in `main` (EA-003, EA-005, EA-007, DA-001), as owner decision D-3 allows.

## Status
Draft

## Context

GOV-002 §2 needs an ADR before tables move between schemas ("Domain boundaries") and before any change to row-level security (RLS), keys or roles ("Tenant isolation", "Database design"). Steps 11 to 15 proposed several such changes and deferred them to "ADR-0020". DA-001 says Step 16 must not build them until this ADR is accepted. This ADR collects them in one place. The scope is the union of EA-003 §7, EA-005 §9, EA-007 §13 and DA-001 §8.

What DDL-000 v0.9 does today (checked in `database/ddl/DDL-000_core_schema_v0.9.sql`):

- **One write role for everything.** `amc_app` gets `SELECT, INSERT, UPDATE` on every table in all 23 schemas (§17 grants loop), with a few revokes: `UPDATE` on seven insert-only tables, and `INSERT, UPDATE` on `platform.tenant`. The rule that a module writes only its own schema (AGENTS.md §2.3, ADR-0002, EA-003 B1) is therefore not enforced by the database. ADR-0002's own validation expects "DB grant tests show each module role cannot write other schemas", and DDL-000 cannot pass that test.
- **A role that bypasses tenant isolation.** `amc_platform_admin` is created `BYPASSRLS`. DA-000 §6.4 uses it for break-glass support. One support session could then read every tenant in the cell, while the approval covers only one tenant (EA-005 §6).
- **One shared outbox and one shared idempotency table.** These are `platform.outbox_event` and `platform.idempotency_key`, written by every module (EA-003 T15).
- **One RLS policy for every role.** `platform.apply_tenant_rls()` creates `tenant_isolation` with no `TO` clause, so it applies to every role. It allows rows where `tenant_id = platform.current_tenant()`, which comes from a session setting that any session can set for itself.
- **No import path for the audit hash chain.** `audit.tg_hash_chain()` always recomputes `prev_hash` and `row_hash`. Migrated audit rows can't keep their original hashes (EA-005 §2.1).
- **Two foreign keys that cross module boundaries:** `trading."order"` → `investment.decision_record`, and `ai.agent` → `identity.app_user`. The Workflow separation-of-duties trigger also reads `identity.app_user` directly (DA-001 DM-20).

Some work has no user token, so the tenant can't come from an authenticated principal: the outbox relay, event handlers, the scheduler, file ingestion, the Reporting extract, the L4 signal bridge, the platform data tools and break-glass. STD-001 §4 says tenant context comes from the authenticated principal. EA-005 §2 names these workers as exceptions, and they need to be recorded here.

## Decision

Accept the following nine parts as one package. Step 16 builds them, and Step 17 (DBE-001) adds the column detail. Each part is labelled **[DES]** (design proposal) unless shown otherwise.

### 1. Tables that move between schemas (EA-003 T1, T3; DA-001 DM-7, DM-8)

| Item | From (DA-000 / DDL-000) | To | Note |
| --- | --- | --- | --- |
| Trade record (confirmation states, charges) | `settlement.trade` (trade and charge fields) | `execution.trade` | Execution owns the trade |
| Post-trade allocation results (allocated quantity, average price, deviation approval) | `trading.block_allocation` (allocation result fields) | `execution.allocation` | `trading.block_allocation` keeps only the intended split |
| Settlement record | `settlement.trade` | renamed `settlement.settlement`, one per trade | Holds `trade_id` as an ID reference, not a foreign key (see below) |
| Corporate actions, sources, entitlements, elections | `settlement` (DA-000 placement only; no DDL-000 table exists) | `operations.corporate_action`, `operations.corporate_action_source`, `operations.ca_entitlement`, `operations.election` | Nothing is physically moved; only the owner changes |

No production data exists yet, so the "move" is a change to DDL-000 before the first release. There is no data migration.

**Departure from master prompt §7 principle 3 ("Explicit foreign-key constraints").** Following DA-001 M4, this ADR uses ID references checked by events instead of foreign keys **between modules**: `settlement.settlement.trade_id`, plus the two keys in part 9. Foreign keys stay in place inside a module, and to the reference tables that B2 allows (`platform.tenant`, `master.*`, `product.*`). Reason: a foreign key across modules ties two schemas together, so one module can't move, be extracted or be restored without the other (ADR-0002). This departure is recorded here for the owner to accept.

### 2. One database role per module (EA-003 B1, T15; ADR-0002)

1. **Module roles.** Each of the 22 modules in EA-003 §2 gets one `NOLOGIN` role, named `amc_mod_<module>` (for example `amc_mod_execution`). It gets `SELECT, INSERT, UPDATE` only on its own schema or schemas (EA-003 §2; DA-001 §2). `DELETE` is granted only where the DA-001 time model allows it, for example the purge of expired idempotency keys or outbox archiving. Removing a tenant is done by the removal role in part 6, not by module roles.
2. **Cross-schema reads are narrowed (EA-003 B2).** A module role gets `SELECT` on another module's tables only for the reference tables DA-001 allows: `master.*` and `product.*`, plus `platform.tenant` limited to **the columns `tenant_id`, `tenant_code` and `status` only**. `legal_name`, `sebi_reg_no`, `kms_key_ref`, `data_region` and the rest of the row are readable only by the Tenant module role (`amc_mod_tenant`). Other modules get these through the Tenant module's interface, for their own tenant only. This keeps one tenant's registration details and key alias hidden from code running for another tenant in a shared cell (master prompt §3.4). `platform.tenant` has no RLS (DDL-000 leaves it out of `apply_tenant_rls()`), so the column grant is what protects it. All other cross-module reads go through the owning module's interface.
3. **Logins.** Each process role (EA-004 §2.1: `api`, `worker`) connects through **one connection pool per module**. Each pool logs in as a login role that is a member of that module's role only. This matches EA-004's "per-module connection pools" through PgBouncer. Code can't switch to another module's role inside a transaction, because its login isn't a member of any other module role. The alternative, one login for all modules with `SET LOCAL ROLE` per transaction, is described under Alternatives and isn't chosen. The connection budget (pool sizes × modules × instances) is set in DBE-002 (Step 19) **[VAL: measure in the performance test]**.
4. **Object owner.** All tables, policies and ordinary functions are owned by `amc_migration_owner`. The exceptions are the `SECURITY DEFINER` functions in parts 6, 7 and 8, which have their own owner roles. `amc_migration_owner` is not a superuser and has no `BYPASSRLS`. Because every tenant table has `FORCE ROW LEVEL SECURITY`, the owner is also subject to RLS ([IND — PostgreSQL docs](https://www.postgresql.org/docs/16/ddl-rowsecurity.html)). But as the owner it can still run `ALTER TABLE … NO FORCE ROW LEVEL SECURITY`, disable triggers or drop policies. Its credential is therefore as sensitive as `BYPASSRLS`. It is held only by the migration pipeline (CI/CD, from the secrets manager), never by the application or a person's day-to-day login. Each use is logged. The detail goes in SEC-001 (Step 25).
5. **Roles that are retired:** `amc_app` (replaced by the module roles) and `amc_platform_admin BYPASSRLS` (replaced by part 8). **No application, worker, tool or break-glass role has `BYPASSRLS`.** CI fails the DDL tests if any non-superuser role has it.
6. `amc_readonly`, `amc_auditor` and `amc_ai_agent` keep their current grants for now. They are members of the tenant-scoped group in part 3, so RLS keeps working for them exactly as today. Their read grants are reviewed against B2 in Step 16 and against SEC-001 in Step 25 (open point O2). This ADR doesn't widen them.

### 3. Which roles the tenant policy applies to (EA-005 §9 DDL-000 point 1; DA-001 DM-18)

1. A `NOLOGIN` group role, `amc_tenant_scoped`, is created. `platform.apply_tenant_rls()` creates the `tenant_isolation` policy **`TO amc_tenant_scoped`** instead of to every role. A policy given to a group role applies to its members. This was checked on PostgreSQL 16.15: a login that is a member of a member of the group saw only the rows of the tenant in its `app.tenant_id`.
2. These roles are members of `amc_tenant_scoped`: every module role, `amc_sys_signal_bridge`, `amc_sys_extract`, `amc_audit_writer`, `amc_audit_import`, `amc_tenant_removal`, `amc_readonly`, `amc_auditor` and `amc_ai_agent`. A role that writes tenant tables but is not a member would have every insert refused under `FORCE ROW LEVEL SECURITY`, because no permissive policy would apply to it. So DBT test 3 checks this list.
3. **`amc_breakglass` and `amc_migration_owner` are not members.** Break-glass gets its own policies (part 8). The migration owner sees no tenant rows.

### 4. Standard per-schema tables replace the shared outbox (EA-003 T15; EA-007 D1–D6; DA-001 §3.2, DM-4)

Each module schema (all except `audit`) gets five tables, written only by that module's role: `outbox_event`, `outbox_delivery`, `inbox_event`, `dead_letter_event` and `idempotency_key`. Their columns and keys are in DA-001 §3.2. `platform.outbox_event` and `platform.idempotency_key` are removed from DDL-000. All five tables keep forced RLS. Financial idempotency keys are never kept only in the cache (ADR-0017 Decision 3).

### 5. Named system-worker exceptions to STD-001 §4 (EA-005 §2; EA-007 D2, D3, §9.4)

STD-001 §4 stays the rule: tenant context comes from the authenticated principal. The following workers are the **only** exceptions. Each one sets the tenant context (`SET LOCAL`, or `set_config(…, true)` inside a function) within a transaction. It sets it from a **tenant-scoped record that was itself created inside that tenant by an authenticated action**:

| Worker | Where its tenant comes from | Database role | Limits |
| --- | --- | --- | --- |
| Outbox relay (one per producing module, EA-007 D2) | The tenant list (`platform.tenant` columns in part 2.2), then that tenant's own outbox rows | The producing module's role | Reads only its own outbox. Marks only its own delivery rows. Works one tenant per transaction |
| Event handler (EA-007 D3) | `tenant_id` in the event envelope, which the producer wrote inside its own tenant transaction | The consuming module's role | Records its inbox row in the same transaction as its effect (D4) |
| Scheduler | A tenant-scoped schedule entry (`platform` schedule table, DA-001 §4.1) created by an approved action | Tenant module role to read due entries; the job itself runs under the owning module's role | Starts one job for one tenant per entry |
| Temporal workflow activity | `tenant_id` fixed when the workflow was started by an authenticated caller. The workflow ID includes the tenant (EA-005 §2) | The owning module's role | A workflow can't change its tenant |
| File ingestion | The connection record the file came through (`operations.connection`, one tenant) | Operations, or the owning module's adapter role (EA-003 B9, T16) | A file is never matched to a tenant by its content |
| Reporting extract (D16 pipelines, EA-003 B2) | A tenant-scoped pipeline schedule entry, started like any scheduled job | `amc_sys_extract`: `SELECT` only, on the tables and views each pipeline lists; no write grant outside `analytics` pipeline-run rows, which go through the Reporting module | One tenant per transaction; read only; subject to `tenant_isolation` like any member of `amc_tenant_scoped`. Lake and mart design: DA-002 (Step 19) |
| L4 signal bridge (EA-007 §9.4) | The event's `tenant_id`, which must match the tenant prefix of the target workflow ID | `amc_sys_signal_bridge`, which writes no module data (see O1) | Refuses a tenant mismatch (EA-007 E5) |
| Break-glass tool | The approved grant (part 8) | Per-grant login | One tenant, read only, time-boxed |
| Platform data tools (part 6) | The approved, tenant-scoped migration, exit or removal record | See part 6 | One tenant per run |

**No worker loops over tenants to read business data.** The relay and the scheduler only read the tenant list and their own tenant-scoped work rows (EA-005 §2.1 rule). The Reporting extract is started per tenant by its schedule entry, and it doesn't loop either. The tenant context is always set for the transaction only, so it can't leak into the next use of a pooled connection.

### 6. Platform data tools (EA-005 §2.1; DA-001 DM-17)

1. **Seed and export** run each module's own function under **that module's** role. The tool only calls them in order, and no role writes another schema.
2. **Import (except audit)** runs each module's own import function under that module's role. Imported rows pass the same checks as new rows (for example balanced journals) and keep their original IDs, timestamps and versions.
3. **Audit import.** A separate `NOLOGIN` role, `amc_audit_import`, owns an insert-only import function.
   - The function first checks for an approved migration record for this tenant, with status `APPROVED` and not expired (the record EA-005 §2.1 requires, held in `platform`). It sets the tenant context from that record.
   - For rows inserted while `current_user` is `amc_audit_import`, the hash-chain trigger **checks** that each row's stored `prev_hash` and `row_hash` match the chain instead of recomputing them. For every other role it still recomputes them, so normal writes are unchanged.
   - The import must run **before any audit row exists for that tenant in the target cell**. The function refuses to start otherwise. The target tenant's SETUP seed, which writes audit rows, therefore runs after the audit import.
   - When it finishes, the function verifies the whole chain end to end, records `audit.import_run`, and moves the target cell's audit sequence past the highest imported `event_seq`.
   - For hashes to verify the same way in every cell, Step 16 fixes the text form of every hashed value regardless of session settings. In particular, `occurred_at` is hashed as UTC in ISO-8601 form, because DDL-000 today casts `timestamptz` to text, and that text depends on the session `TimeZone`.
4. **Removing a tenant** (option (a) of EA-005 §2.1, as chosen in DA-001 DM-17). A `NOLOGIN` role, `amc_tenant_removal`, owns one removal procedure. It removes **all** of one tenant's rows in every schema: ordinary rows and protected rows (posted journals, audit). It deletes in an order generated from the foreign keys in Step 16.
   - **Named exception to EA-003 B1.** This is the only role that deletes in schemas it doesn't own. Module roles don't get `DELETE` for this purpose.
   - The procedure sets the tenant context from the authorisation row. It runs only when an `APPROVED`, unexpired `platform.tenant_removal_authorisation` row exists for that tenant (two-sided: AMC and vendor), and the tenant's status is `OFFBOARDING` or `MIGRATED_OUT` (DM-16).
   - The immutability triggers on posted journals and audit rows allow `DELETE` only when `current_user` is `amc_tenant_removal` **and** the trigger itself finds that authorisation row for the row's tenant. The trigger doesn't rely on a session flag, because any session could set one.
   - The run is audited in the control plane (EA-006 CP-7) and ends with a deletion certificate.
   - Option (c), keeping the rows and crypto-shredding personal data, stays available where a contract or REG-001 needs the rows kept **[VAL]**.
5. **Restore extract** runs only on a scratch cluster with that cluster's own migration-owner role. Nothing is written to the live cell.
6. No login is a member of `amc_audit_import` or `amc_tenant_removal`. Their functions can be run only by the platform-tools login, through the grants in part 7, and each run handles one tenant.

### 7. Rules for every `SECURITY DEFINER` function in this ADR

PostgreSQL gives `EXECUTE` on a new function to `PUBLIC` by default ([IND — PostgreSQL docs, `CREATE FUNCTION`, "Writing SECURITY DEFINER Functions Safely"](https://www.postgresql.org/docs/16/sql-createfunction.html); also checked on PostgreSQL 16.15). Every definer function (audit write, audit import, tenant removal, break-glass provisioning, session ending) therefore has:

1. `REVOKE ALL ON FUNCTION … FROM PUBLIC`, then `GRANT EXECUTE` only to the roles named here. The audit write function is granted to the module roles. Import and removal are granted to the platform-tools login only. Provisioning is granted to the break-glass tool login only.
2. A fixed `SET search_path = pg_catalog, <its schema>` in the function definition.
3. Its own check of the approved record it depends on, as described in parts 6 and 8. Holding `EXECUTE` alone is never enough.

### 8. Audit writes (EA-003 T15, B8; DA-001 DM-19)

Modules don't get `INSERT` on `audit.audit_event`. They get `EXECUTE` on an insert-only definer function owned by `amc_audit_writer`. That role is part of the Tenant module, which owns `audit` (EA-003 §2, B8), and is kept separate from `amc_mod_tenant` so the Tenant module's own code can't insert audit rows directly either. The function keeps the per-tenant hash chain in one place and writes in the caller's tenant context. As DA-001 DM-19 says, audit payloads (`before_state`, `after_state`) must not hold tenant-key ciphertext or keyed-hash values, and personal-data fields are masked. This way a tenant move or key destruction never changes audit hashes or leaves a readable copy (EA-005 §9).

### 9. Break-glass without bypassing RLS (EA-005 §6; DA-001 DM-18)

1. **Where the grant lives.** The grant record is `identity.break_glass_grant` (Identity module), as in DA-001 §4.2. EA-005 §6 said "owned by the Tenant module". DA-001's placement is kept, because grants with scope and expiry are Identity data (EA-003 §2). EA-005 §6 gets this correction in its next revision.
2. **Provisioning a login.** When a tenant approves a request (WF-022), the break-glass tool calls a provisioning function owned by a `NOLOGIN` role, `amc_breakglass_admin`. That role has `CREATEROLE` and `ADMIN OPTION` on `amc_breakglass` only, and no table rights.
   - The function creates a **per-grant login** (`VALID UNTIL` the grant expiry) and grants it `amc_breakglass` only.
   - The login name is recorded in the grant row.
   - The credential is a random secret delivered to the approved support engineer through the secrets manager. It is never logged or stored in the database. The delivery method is set in SEC-001 (Step 25) **[VAL]**.
   - This was checked on PostgreSQL 16.15: such a role could create a login and grant it `amc_breakglass`, could drop it, and was **refused** when it tried to grant any other role.
3. **Ending access.** At expiry, or when the grant is revoked, the provisioning function drops the login. A second definer function ends that login's open sessions. It is owned by a role that holds `pg_signal_backend` and may end only sessions whose user is a member of `amc_breakglass`, so no other session can be ended through it. The grant lasts at most 4 hours (WF-022; PRD-001 FR-D01-023).
4. **Policies.** These don't use `app.tenant_id`, because any session can set it:
   - On `identity.break_glass_grant`, a `SELECT` policy `TO amc_breakglass` that shows only the row whose login name is `current_user`, while it is approved and unexpired. Without this policy, the break-glass login couldn't see its own grant (the table has forced RLS), and the next policy would return nothing.
   - On every table in scope, a **permissive** `SELECT` policy `TO amc_breakglass` that allows a row only if its `tenant_id` matches that grant.
   - A **restrictive** policy that enforces the grant's schema scope on top.
   - Restrictive policies only narrow what permissive policies allow. With only a restrictive policy, the login would see no rows at all ([IND — PostgreSQL docs, `CREATE POLICY`](https://www.postgresql.org/docs/16/sql-createpolicy.html)). This corrects DA-001 DM-18, which mentions only a restrictive policy.
5. **Views.** The tool offers predefined `security_invoker` read-only views, not free SQL. Because the views run with the caller's rights, the login also holds `SELECT` on the tables underneath. So the **database** enforces one tenant, read only and the scope. The **tool** enforces "views only". This trade-off is accepted because the alternative, views owned by a role that the break-glass policy applies to, would add yet another role with broad read rights.
6. The control plane sees only that a grant exists (incident, tenant, start, expiry), never the data seen (EA-006 §2).

### 10. Cross-schema keys and the Workflow read model (DA-001 DM-20)

1. The foreign keys `trading."order"` → `investment.decision_record` and `ai.agent` → `identity.app_user` become ID references checked by the owning module (see the departure note in part 1).
2. The Workflow separation-of-duties trigger reads its own read model, `workflow.actor_ref`, instead of `identity.app_user`. `workflow.actor_ref` is kept up to date from `USER_PROVISIONED` and `USER_DEPROVISIONED`. Three safeguards apply:
   - Identity makes `is_service_identity` unchangeable after the user is created (trigger plus a DBT test).
   - The trigger **fails closed**. It refuses the decision if there is no `actor_ref` row, the row is a service identity, or the status isn't `ACTIVE`.
   - `USER_DEPROVISIONED` is an access event that is never overtaken by later events (EA-007 D6). The approval API also checks the approver's current rights through the policy engine before the database trigger runs.

### Out of scope

The cell shapes (DEDICATED_DB dropped, Q69), placement rules P1–P7 and the new tenant key on each migration (EA-004 §11 row "ADR-0003 revision, or ADR-0020") are **not** in this ADR. They go to the ADR-0003 revision, which the owner writes, because they concern cell placement rather than database roles.

### Open points for the owner (not decided here)

- **O1. Where the L4 signal bridge keeps its inbox.** EA-007 §9.4 says the bridge "has an inbox like any consumer" and "writes no module data". Options:
  - (a) A `workflow.signal_inbox` table written through a Workflow module definer function that `amc_sys_signal_bridge` may execute.
  - (b) No database inbox. The bridge relies on Temporal's signal handling being idempotent, using the event ID as the de-duplication key.
  - (c) A schema of its own. The master prompt §7 list of 23 schemas has none for it, and a new schema needs its own ADR (GOV-002 §2).

  The default is (a), and Step 16 builds (a) unless the owner chooses otherwise.
- **O2.** Whether `amc_readonly` and `amc_auditor` keep read access to all schemas, or get B2-narrowed views (part 2.6). Decided with SEC-001 (Step 25).

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Keep one `amc_app` role and enforce module boundaries only in code (import rules) | Simplest; one connection pool | The database can't stop a bug or a compromised module from writing another schema. ADR-0002's validation can't pass | Fails AGENTS.md §2.3 at the database layer |
| One login for all modules and `SET LOCAL ROLE amc_mod_<module>` per transaction | Fewer connections | The login is a member of every module role, so any code can switch roles. The boundary becomes a coding rule again | Weaker guarantee; kept as a fallback only if the pool budget measured in Step 19 can't be met |
| Keep the shared `platform.outbox_event` with one central relay | One table, one relay | The central relay writes every module's delivery state. Every module writes `platform` | Breaks B1; replaced by per-schema tables (EA-003 T15) |
| Keep `BYPASSRLS` for break-glass, limited by tooling | Easy to build | One support session can read every tenant in the cell, while the approval covers one tenant | Fails master prompt §3.4 tenant isolation |
| Each module removes its own rows when a tenant leaves (one removal function per module) | No cross-schema delete exception | Needs `DELETE` on every module table for 22 roles, plus 22 trigger exceptions for protected rows | One named, audited removal role is a smaller and easier-to-test exception |
| Partition protected tables by tenant so removal is a partition drop (EA-005 §2.1 option (b)) | No trigger exception | Multiplies partitions in every shared cell | Rejected in DA-001 DM-17 |

## Consequences

- **Positive:**
  - The database enforces "a module writes only its own schema" and "no role bypasses tenant isolation".
  - ADR-0002's validation can pass.
  - Break-glass access is limited to one tenant by the database itself.
  - Audit chains survive a tenant move.
  - Other tenants' registration details are hidden in shared cells.
- **Negative:**
  - 22 module roles plus about ten system, tool and break-glass roles.
  - More connection pools.
  - Five extra tables per schema.
  - Grant and policy tests grow.
  - Every new table needs a grant line for its owning role, and CI must check that.
- **Follow-up work:**
  - Step 16 DDL: roles, grants, the `amc_tenant_scoped` group, policies, moved tables, per-schema tables, trigger changes, the fixed hash text form, and `apply_tenant_rls()` with a `TO` clause.
  - Step 16 DBT tests (see Validation).
  - STD-001 next revision lists the exceptions in part 5.
  - ADR-0003 revision for the RLS and break-glass changes (owner-only).
  - DA-000 §6.4 is superseded by part 9.
  - EA-005 §6 is corrected: the grant table is in Identity (part 9.1).
  - EA-003 B1 note: the tenant-removal exception (part 6.4).
  - DA-001 corrections:
    - DM-17: the removal procedure's owner is `amc_tenant_removal`, not the migration-owner role, and the procedure removes ordinary rows too.
    - DM-18: a permissive policy and a grant-table policy are needed.
  - EA-003 T1, T3 and T15, EA-005 §2.1 and §6, and DA-001 DM-4, DM-7, DM-8, DM-17, DM-18 and DM-20 get "decided in ADR-0020" once this is accepted.

## Validation

Moves to Validated when these DBT tests pass on PostgreSQL 16 in CI:

1. Each module role can't `INSERT`, `UPDATE` or `DELETE` in any other module's schema. This is the ADR-0002 validation.
2. No non-superuser role has `BYPASSRLS`.
3. Every tenant table has `FORCE ROW LEVEL SECURITY` and a `tenant_isolation` policy `TO amc_tenant_scoped`. Every role in the part 3.2 list is a member of that group, and `amc_breakglass` is not.
4. A break-glass login sees only its own grant row, and only its granted tenant and scope, even with `app.tenant_id` set to another tenant. After the grant expires it sees nothing. The provisioning role can't grant any role other than `amc_breakglass`.
5. The relay of module A can't read module B's outbox. Module roles can read only `tenant_id`, `tenant_code` and `status` of `platform.tenant`.
6. An event handler's effect and its inbox row commit or roll back together. A repeated delivery has no second effect.
7. Audit import:
   - keeps the original hashes;
   - refuses a row whose hash doesn't match the chain;
   - refuses to run without an approved migration record, or when the tenant already has audit rows;
   - leaves normal inserts recomputing hashes;
   - advances the audit sequence past the import.
8. Tenant removal deletes rows only for the authorised tenant. It fails without an approved authorisation, for another tenant, or when called by any other role.
9. No definer function in part 7 can be run by `PUBLIC` or by a role not named there.
10. The Workflow SoD trigger refuses a decision when the `actor_ref` row is missing, is a service identity or isn't `ACTIVE`. `is_service_identity` can't be changed.
11. A tenant context set for a transaction doesn't survive into the next transaction on the same pooled connection, tested through PgBouncer in transaction mode.
12. The audit hash of a row is the same when it is written with the session `TimeZone` set to UTC or to Asia/Kolkata.

## Sources

- PostgreSQL 16 documentation:
  - Row security policies: https://www.postgresql.org/docs/16/ddl-rowsecurity.html
  - `CREATE POLICY` (permissive and restrictive policies): https://www.postgresql.org/docs/16/sql-createpolicy.html
  - `CREATE FUNCTION` (default `EXECUTE` to `PUBLIC`; writing `SECURITY DEFINER` functions safely): https://www.postgresql.org/docs/16/sql-createfunction.html
  - `CREATE VIEW` (`security_invoker`): https://www.postgresql.org/docs/16/sql-createview.html
  - `SET` (`SET LOCAL`): https://www.postgresql.org/docs/16/sql-set.html
  - `CREATE ROLE` (`CREATEROLE`, `VALID UNTIL`): https://www.postgresql.org/docs/16/sql-createrole.html
- Local checks on PostgreSQL 16.15, 22 Nov 2026. These were scratch tests, not part of the repository's test suite. Each line gives the setup and the result.
  - A restrictive-only policy: 0 rows.
  - A permissive policy on the data table plus a `SELECT` policy on a forced-RLS grant table, both `TO amc_breakglass`: the break-glass login saw only the granted tenant's rows, even with `app.tenant_id` set to another tenant. It saw only its own grant row.
  - A policy `TO` a group role: it applied to members of members.
  - Definer function: `has_function_privilege` was true for an unrelated role before `REVOKE … FROM PUBLIC`, and false after.
  - A role with `CREATEROLE` and `ADMIN OPTION` on `amc_breakglass`: it could create and drop a login, and was refused when it tried to grant another role.

  The core of the break-glass check:

  ```sql
  CREATE POLICY bg_own_grant ON s.grant_t FOR SELECT TO breakglass
    USING (login = current_user AND expires > now());
  CREATE POLICY bg_permit ON s.t FOR SELECT TO breakglass
    USING (tenant_id IN (SELECT tenant_id FROM s.grant_t
                          WHERE login = current_user AND expires > now()));
  -- as bg_1 with app.tenant_id = '2': SELECT returns only tenant 1's row; grant_t shows 1 row
  ```

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-22 | Draft | Claude, for the project owner | Drafted at the owner's request on branch `proposal/adr-0020-schema-moves-db-roles`; review round 1 findings 1–17 addressed |
