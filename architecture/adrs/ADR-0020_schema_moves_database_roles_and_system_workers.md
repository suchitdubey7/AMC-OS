---
id: ADR-0020
title: Table moves between schemas, one database role per module, and named system-worker exceptions
status: Draft
date: 2026-11-22
deciders: ARB (interim: project owner)
domains: D01, D06, D07, D12, all modules (database roles)
related: GOV-002 §2; ADR-0002; ADR-0003; ADR-0006; ADR-0017; EA-003 §7 (T1, T3, T15, B1, B2); EA-005 §2, §2.1, §6, §9; EA-007 D1–D6, §9.4, §13; DA-001 §3.2, §8, DM-4, DM-7, DM-8, DM-17, DM-18, DM-20; DDL-000 §16–§17; STD-001 §4
---

# ADR-0020: Table moves between schemas, one database role per module, and named system-worker exceptions

> Drafted at the owner's request on 22 Nov 2026 (chat), on a `proposal/` branch outside the build-loop chain. It is a Draft proposal for the owner (interim ARB). Nothing here is decided until the owner accepts it. It builds on Draft documents that are not yet in `main` (EA-003, EA-005, EA-007, DA-001), as owner decision D-3 allows.

## Status
Draft

## Context

GOV-002 §2 needs an ADR before tables move between schemas ("Domain boundaries") and before any change to row-level security (RLS), keys or roles ("Tenant isolation", "Database design"). Steps 11 to 15 proposed several such changes and deferred them to "ADR-0020". DA-001 says Step 16 must not build them until this ADR is accepted. This ADR collects them in one place. The scope is the union of EA-003 §7, EA-005 §9, EA-007 §13 and DA-001 §8.

What DDL-000 v0.9 does today (checked in `database/ddl/DDL-000_core_schema_v0.9.sql`):

- **One write role for everything.** `amc_app` gets `SELECT, INSERT, UPDATE` on every table in all 23 schemas (§17 grants loop). The rule that a module writes only its own schema (AGENTS.md §2.3, ADR-0002, EA-003 B1) is therefore not enforced by the database. ADR-0002's own validation expects "DB grant tests show each module role cannot write other schemas", and DDL-000 cannot pass that test.
- **A role that bypasses tenant isolation.** `amc_platform_admin` is created `BYPASSRLS`. DA-000 §6.4 uses it for break-glass support. One support session could then read every tenant in the cell, while the approval covers only one tenant (EA-005 §6).
- **One shared outbox and one shared idempotency table.** These are `platform.outbox_event` and `platform.idempotency_key`, written by every module (EA-003 T15).
- **One RLS policy for every role.** `platform.apply_tenant_rls()` creates `tenant_isolation` with no `TO` clause, so it applies to every role. It allows rows where `tenant_id = platform.current_tenant()`, which comes from a session setting that any session can set for itself.
- **No import path for the audit hash chain.** `audit.tg_hash_chain()` always recomputes `prev_hash` and `row_hash`. Migrated audit rows can't keep their original hashes (EA-005 §2.1).
- **Two foreign keys that cross module boundaries:** `trading."order"` → `investment.decision_record`, and `ai.agent` → `identity.app_user`. The Workflow separation-of-duties trigger also reads `identity.app_user` directly (DA-001 DM-20).

Some work has no user token, so the tenant can't come from an authenticated principal: the outbox relay, event handlers, the scheduler, file ingestion, the L4 signal bridge, the platform data tools and break-glass. STD-001 §4 says tenant context comes from the authenticated principal. EA-005 §2 names these workers as exceptions, and they need to be recorded here.

## Decision

Accept the following eight parts as one package. Step 16 builds them, and Step 17 (DBE-001) adds the column detail. Each part is labelled **[DES]** (design proposal) unless shown otherwise.

### 1. Tables that move between schemas (EA-003 T1, T3; DA-001 DM-7, DM-8)

| Item | From (DA-000 / DDL-000) | To | Note |
| --- | --- | --- | --- |
| Trade record (confirmation states, charges) | `settlement.trade` (trade and charge fields) | `execution.trade` | Execution owns the trade |
| Post-trade allocation results (allocated quantity, average price, deviation approval) | `trading.block_allocation` (allocation result fields) | `execution.allocation` | `trading.block_allocation` keeps only the intended split |
| Settlement record | `settlement.trade` | renamed `settlement.settlement`, one per trade | Holds `trade_id` as an ID reference checked by events, not a foreign key (DA-001 M4) |
| Corporate actions, sources, entitlements, elections | `settlement` (DA-000 placement only; no DDL-000 table exists) | `operations.corporate_action`, `operations.corporate_action_source`, `operations.ca_entitlement`, `operations.election` | Nothing is physically moved; only the owner changes |

No production data exists yet, so the "move" is a change to DDL-000 before the first release. There is no data migration.

### 2. One database role per module (EA-003 B1, T15; ADR-0002)

1. **Module roles.** Each module gets one `NOLOGIN` role, named `amc_mod_<module>` (for example `amc_mod_execution`). It gets `SELECT, INSERT, UPDATE` only on its own schema or schemas (EA-003 §2; DA-001 §2). `DELETE` is granted only where the DA-001 time model allows it (for example the purge of expired idempotency keys, or outbox archiving). The Tenant module role writes `platform`. The audit role is described in point 6.
2. **Cross-schema reads are narrowed (EA-003 B2).** A module role gets `SELECT` on another module's tables only for the reference tables DA-001 allows: `platform.tenant`, `master.*` and `product.*`. All other reads go through the owning module's interface. D16 data pipelines (Reporting) use their own extract role, which can read but not write.
3. **Logins.** Each process role (EA-004 §2.1: `api`, `worker`) connects through **one connection pool per module**, each logging in as a login role that is a member of that module's role only. This matches EA-004's "per-module connection pools" through PgBouncer. Code can't switch to another module's role inside a transaction, because its login isn't a member of any other module role. The alternative, one login for all modules with `SET LOCAL ROLE` per transaction, is described under Alternatives and isn't chosen. The connection budget (pool sizes × modules × instances) is set in DBE-002 (Step 19) **[VAL: measure in the performance test]**.
4. **Object owner.** All tables, functions and policies are owned by a `amc_migration_owner` role. It is not a superuser and has no `BYPASSRLS`. It is used only by the migration tool. Because every tenant table has `FORCE ROW LEVEL SECURITY`, the owner is also subject to RLS (PostgreSQL docs, `ALTER TABLE … FORCE ROW LEVEL SECURITY`).
5. **Roles that are retired:** `amc_app` (replaced by the module roles) and `amc_platform_admin BYPASSRLS` (replaced by the break-glass design in point 7). **No application, worker, tool or break-glass role has `BYPASSRLS`.** CI fails the DDL tests if any non-superuser role has it.
6. `amc_readonly`, `amc_auditor` and `amc_ai_agent` are kept for now. Their read grants are reviewed against B2 in Step 16 and against SEC-001 in Step 25. This ADR doesn't widen them.

### 3. Standard per-schema tables replace the shared outbox (EA-003 T15; EA-007 D1–D6; DA-001 §3.2, DM-4)

Each module schema (all except `audit`) gets five tables, written only by that module's role: `outbox_event`, `outbox_delivery`, `inbox_event`, `dead_letter_event` and `idempotency_key`. Their columns and keys are in DA-001 §3.2. `platform.outbox_event` and `platform.idempotency_key` are removed from DDL-000. All five tables keep forced RLS. Financial idempotency keys are never kept only in the cache (ADR-0017 Decision 3).

### 4. Named system-worker exceptions to STD-001 §4 (EA-005 §2; EA-007 D2, D3, §9.4)

STD-001 §4 stays the rule: tenant context comes from the authenticated principal. The following workers are the **only** exceptions. Each one sets the tenant context (`SET LOCAL`, inside a transaction) from a **tenant-scoped record that was itself created inside that tenant by an authenticated action**:

| Worker | Where its tenant comes from | Database role | Limits |
| --- | --- | --- | --- |
| Outbox relay (one per producing module, EA-007 D2) | The tenant list in `platform.tenant`, then that tenant's own outbox rows | The producing module's role | Reads only its own outbox. Marks only its own delivery rows. Works one tenant per transaction |
| Event handler (EA-007 D3) | `tenant_id` in the event envelope, which the producer wrote inside its own tenant transaction | The consuming module's role | Records its inbox row in the same transaction as its effect (D4) |
| Scheduler | A tenant-scoped schedule entry (`platform` schedule table, DA-001 §4.1) created by an approved action | Tenant module role to read due entries; the job itself runs under the owning module's role | Starts one job for one tenant per entry |
| Temporal workflow activity | `tenant_id` fixed when the workflow was started by an authenticated caller. The workflow ID includes the tenant (EA-005 §2) | The owning module's role | A workflow can't change its tenant |
| File ingestion | The connection record the file came through (`operations.connection`, one tenant) | Operations, or the owning module's adapter role (EA-003 B9, T16) | A file is never matched to a tenant by its content |
| L4 signal bridge (EA-007 §9.4) | The event's `tenant_id`, which must match the tenant prefix of the target workflow ID | Its own role, `amc_sys_signal_bridge`, which writes no module data | Refuses a tenant mismatch (EA-007 E5) |
| Break-glass tool | The approved grant (point 7) | Per-grant login | One tenant, read only, time-boxed |
| Platform data tools (point 5) | The approved, tenant-scoped migration, exit or removal record | See point 5 | One tenant per run |

To read the tenant list, worker login roles get column-level `SELECT (tenant_id, status)` on `platform.tenant`, not the whole row. **No worker loops over tenants to read business data.** The relay and the scheduler only read the tenant list and their own tenant-scoped work rows (EA-005 §2.1 rule). The tenant context is always set with `SET LOCAL` inside the transaction, so it can't leak into the next use of a pooled connection.

### 5. Platform data tools (EA-005 §2.1; DA-001 DM-17)

1. **Seed, export and import** run each module's own function under **that module's** role. The tool only calls them in order, and no role writes another schema. Imported rows pass the same checks as new rows (for example balanced journals) and keep their original IDs, timestamps and versions.
2. **Audit import.** A separate `NOLOGIN` role, `amc_audit_import`, owns an insert-only `SECURITY DEFINER` import function. For rows inserted while `current_user` is `amc_audit_import`, the hash-chain trigger **checks** that each row's stored `prev_hash` and `row_hash` match the chain instead of recomputing them. For every other role it still recomputes them, so normal writes are unchanged. After the import, the function verifies the whole chain end to end, records `audit.import_run`, and moves the target cell's audit sequence past the highest imported `event_seq`.
3. **Removing one tenant's protected rows** (option (a) of EA-005 §2.1, as chosen in DA-001 DM-17). A `NOLOGIN` role, `amc_tenant_removal`, owns a `SECURITY DEFINER` removal procedure. The immutability triggers on posted journals and audit rows allow `DELETE` only when **both** are true:
   - `current_user` is `amc_tenant_removal`;
   - the trigger itself finds an `APPROVED`, unexpired `platform.tenant_removal_authorisation` row for the row's tenant, and that tenant's status is `OFFBOARDING` or `MIGRATED_OUT`.

   The trigger doesn't rely on a session flag, because any session could set one. The run is audited in the control plane (EA-006 CP-7) and ends with a deletion certificate. Option (c), keeping the rows and crypto-shredding personal data, stays available where a contract or REG-001 needs the rows kept **[VAL]**.
4. **Restore extract** runs only on a scratch cluster with that cluster's own migration-owner role. Nothing is written to the live cell.
5. No login is a member of `amc_audit_import` or `amc_tenant_removal`. Their functions can be run only by the platform-tools login, and only from an approved run record. Each run handles one tenant.

### 6. Audit writes (EA-003 T15, B8)

Modules don't get `INSERT` on `audit.audit_event`. They get `EXECUTE` on an insert-only `SECURITY DEFINER` write function owned by `amc_audit_writer`, which keeps the per-tenant hash chain in one place. Audit payloads (`before_state`, `after_state`) must not hold tenant-key ciphertext or keyed-hash values. Personal data in audit diffs is referenced, not copied. This way a tenant move or key destruction never changes audit hashes (EA-005 §9).

### 7. Break-glass without bypassing RLS (EA-005 §6; DA-001 DM-18)

1. `platform.apply_tenant_rls()` creates the `tenant_isolation` policy **`TO` the module, worker and tool roles only**, not to every role (the `PUBLIC` default).
2. When a tenant approves a break-glass request (WF-022), a **per-grant login** is created as a member of a `NOLOGIN` group role, `amc_breakglass`. It has read-only grants on predefined `security_invoker` views of the schemas in the grant's scope. Free SQL isn't offered. The login is dropped and its sessions are ended when the grant expires (at most 4 hours, WF-022).
3. `amc_breakglass` gets a **permissive** policy that allows a row only if its `tenant_id` matches an approved, unexpired `identity.break_glass_grant` row for `current_user`. A **restrictive** policy enforces the schema scope on top. The policies don't use `app.tenant_id`, because any session can set that.
4. **Correction to DA-001 DM-18 [VAL, tested].** DM-18 describes only a restrictive policy for the break-glass login. In PostgreSQL, restrictive policies only narrow what permissive policies allow. With no permissive policy, the login sees no rows at all. A permissive policy is therefore needed as well (point 3). This was checked on PostgreSQL 16 on 22 Nov 2026. With only a restrictive policy the login saw 0 rows. With the added permissive policy it saw only the granted tenant's rows, even after setting `app.tenant_id` to another tenant. This matches the PostgreSQL documentation for `CREATE POLICY`.
5. The control plane sees only that a grant exists (incident, tenant, start, expiry), never the data seen (EA-006 §2).

### 8. Cross-schema keys and the Workflow read model (DA-001 DM-20)

1. The foreign keys `trading."order"` → `investment.decision_record` and `ai.agent` → `identity.app_user` become ID references checked by the owning module.
2. The Workflow separation-of-duties trigger reads its own read model, `workflow.actor_ref`, instead of `identity.app_user`. `workflow.actor_ref` is kept up to date from `USER_PROVISIONED` and `USER_DEPROVISIONED`. Three safeguards apply:
   - Identity makes `is_service_identity` unchangeable after the user is created (trigger plus a DBT test).
   - The trigger **fails closed**. It refuses the decision if there is no `actor_ref` row, the row is a service identity, or the status isn't `ACTIVE`.
   - `USER_DEPROVISIONED` is an access event that is never overtaken by later events (EA-007 D6). The approval API also checks the approver's current rights through the policy engine before the database trigger runs.

### Open points for the owner (not decided here)

- **O1. Where the L4 signal bridge keeps its inbox.** EA-007 §9.4 says the bridge "has an inbox like any consumer" and "writes no module data". Master prompt §7 fixes the 23 schemas, so there's no schema of its own for it. Options:
  - (a) A `workflow.signal_inbox` table written through a Workflow module function that the bridge role may execute.
  - (b) No database inbox. The bridge relies on Temporal's signal handling being idempotent, using the event ID as the signal's de-duplication key.

  This is left for Step 16, and the default is (a). It's raised as a question for the owner.
- **O2.** Whether `amc_readonly` and `amc_auditor` keep read access to all schemas, or get B2-narrowed views (point 2.6). Decided with SEC-001 (Step 25).

## Alternatives considered

| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Keep one `amc_app` role and enforce module boundaries only in code (import rules) | Simplest; one connection pool | The database can't stop a bug or a compromised module from writing another schema. ADR-0002's validation can't pass | Fails AGENTS.md §2.3 at the database layer |
| One login for all modules and `SET LOCAL ROLE amc_mod_<module>` per transaction | Fewer connections | The login is a member of every module role, so any code can switch roles. The boundary becomes a coding rule again | Weaker guarantee; kept as a fallback only if the pool budget measured in Step 19 can't be met |
| Keep the shared `platform.outbox_event` with one central relay | One table, one relay | The central relay writes every module's delivery state. Every module writes `platform` | Breaks B1; replaced by per-schema tables (EA-003 T15) |
| Keep `BYPASSRLS` for break-glass, limited by tooling | Easy to build | One support session can read every tenant in the cell, while the approval covers one tenant | Fails master prompt §3.4 tenant isolation |
| Partition protected tables by tenant so removal is a partition drop (EA-005 §2.1 option (b)) | No trigger exception | Multiplies partitions in every shared cell | Rejected in DA-001 DM-17 |

## Consequences

- **Positive:**
  - The database enforces "a module writes only its own schema" and "no role bypasses tenant isolation".
  - ADR-0002's validation can pass.
  - Break-glass access is limited to one tenant by the database itself.
  - Audit chains survive a tenant move.
- **Negative:**
  - About 23 module roles plus worker, tool and break-glass roles.
  - More connection pools.
  - Five extra tables per schema.
  - Grant and policy tests grow.
  - Every new table needs a grant line for its owning role, and CI must check that.
- **Follow-up work:**
  - Step 16 DDL (roles, grants, policies, moved tables, per-schema tables, trigger changes, `apply_tenant_rls()` with a `TO` list).
  - Step 16 DBT tests (see Validation).
  - STD-001 next revision lists the exceptions in point 4.
  - ADR-0003 revision for the RLS and break-glass changes (owner-only).
  - DA-000 §6.4 is superseded by point 7.
  - EA-003 T1, T3 and T15, EA-005 §2.1 and §6, and DA-001 DM-4, DM-7, DM-8, DM-17, DM-18 and DM-20 get "decided in ADR-0020" once this is accepted.
  - DA-001 DM-18 is corrected as in point 7.4.

## Validation

Moves to Validated when these DBT tests pass on PostgreSQL 16 in CI:

1. Each module role can't `INSERT`, `UPDATE` or `DELETE` in any other module's schema. This is the ADR-0002 validation.
2. No non-superuser role has `BYPASSRLS`.
3. Every tenant table has `FORCE ROW LEVEL SECURITY` and a `tenant_isolation` policy `TO` the expected roles.
4. A break-glass login sees only its granted tenant and scope, even with `app.tenant_id` set to another tenant. After the grant expires it sees nothing.
5. The relay of module A can't read module B's outbox.
6. An event handler's effect and its inbox row commit or roll back together. A repeated delivery has no second effect.
7. Audit import keeps the original hashes and refuses a row whose hash doesn't match the chain. Normal inserts still recompute hashes. The audit sequence is advanced past the import.
8. Tenant removal deletes protected rows only for the authorised tenant. It fails without an approved authorisation, for another tenant, or when called by any other role.
9. The Workflow SoD trigger refuses a decision when the `actor_ref` row is missing, is a service identity or isn't `ACTIVE`. `is_service_identity` can't be changed.
10. A tenant context set with `SET LOCAL` doesn't survive into the next transaction on the same pooled connection.

## Sources

- PostgreSQL 16 documentation, `CREATE POLICY` (permissive and restrictive policies), `ALTER TABLE … FORCE ROW LEVEL SECURITY`, `CREATE VIEW … security_invoker`, `SET LOCAL`: https://www.postgresql.org/docs/16/sql-createpolicy.html, https://www.postgresql.org/docs/16/ddl-rowsecurity.html, https://www.postgresql.org/docs/16/sql-createview.html, https://www.postgresql.org/docs/16/sql-set.html
- Local test, 22 Nov 2026, PostgreSQL 16: a restrictive-only policy returns 0 rows; adding a permissive grant-table policy returns only the granted tenant's rows, regardless of `app.tenant_id`.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-22 | Draft | Claude, for the project owner | Drafted at the owner's request on branch `proposal/adr-0020-schema-moves-db-roles` |
