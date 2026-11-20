---
id: PRD-001
title: Platform Administration (D01) — Product Requirements
status: Draft
version: 0.2
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 6
last_updated: 2026-11-20
---

# PRD-001 — Platform Administration (D01)

This document states what AMC OS must do to run the platform for each AMC: set up and close tenants, let the right people in (and keep everyone else out), hold the AMC's organisation, subscription and configuration, keep a tamper-evident audit trail, and run environments and releases. PRD-000 v0.9 had no module for this domain (GOV-001 §3 gap); everything here is newly written from the capabilities in [BA-001](../02_business_architecture/BA-001_business_capability_map.md) (CAP-D01-001…011), the workflows WF-019…WF-022 in [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md), the roles and segregation-of-duties (SoD) rules in [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md), and the common rules C1–C8, Chapter 5 (US-PLT-01…03), Chapter 6 and Chapter 7 of [PRD-000 v0.9](PRD-000_master_prd_v0.9.md).

**Builds on Draft documents:** PRD-000, BA-001, BA-002, BA-003, BA-004, BA-005, GOV-001, ADR-0003 — allowed by owner decision D-3 ([GOV-008](../00_governance/GOV-008_build_loop.md) §2 rule 3). No document used here is Approved. Owner decisions D-7 (AWS Mumbai, Hyderabad for disaster recovery), D-8 (each AMC's own identity provider, Keycloak otherwise), D-11 (new AMCs first), D-14 (D01 "subscription" = the AMC's subscription to AMC OS) and D-17…D-25 (role IDs, no SoD waivers, small-team mode) are applied ([LOOP_STATE.md](../../LOOP_STATE.md)).

**What this document is not:** the identity design (token claims, policy engine — EA-002, Step 10), the configuration-over-customisation design (EA-003, Step 11), cell and control-plane design (EA-004…EA-006, Step 12), table definitions (DA-001 / DDL, Steps 15–16), API contracts (Step 24) or the security architecture and threat model (SEC-001/002, Step 25). It adds **no new regulatory fact**; labels carried from PRD-000 keep their **[VAL]** qualifiers.

## 1. Scope

| In scope (CAP) | Out of scope |
| --- | --- |
| CAP-D01-001 Tenant management · CAP-D01-002 User management · CAP-D01-003 Identity · CAP-D01-004 Role-based access · CAP-D01-005 Permission management · CAP-D01-006 Subscription management · CAP-D01-007 Organization hierarchy · CAP-D01-008 Configuration management · CAP-D01-009 System administration · CAP-D01-010 Audit management · CAP-D01-011 Environment administration | Running the AMC's own identity provider (AMC OS connects to it, D-8); billing and invoicing of the subscription (the vendor's finance system; AMC OS only records entitlements and usage) **[ASSUMPTION — confirm: project owner]**; HR records (DEP-19, BA-002 §3); the generic approval mechanism (CAP-D12-011, PRD-012) and document storage (CAP-D12-010) — D01 uses them |

## 2. Identifiers used

| Kind | Format (GOV-001 §4) | Range in this document |
| --- | --- | --- |
| Business requirement | `BR-D01-nnn` | BR-D01-001…007 (BR-D01-001 keeps the TRACE-001 seed wording) |
| Functional requirement | `FR-D01-nnn` | FR-D01-001…048 (all new — PRD-000 had no D01 module) |
| Business rule | `BRL-D01-nnn` | BRL-D01-001…010 |
| User story / acceptance criterion | `US-D01-nnn` / `AC-US-D01-nnn-n` | US-D01-001…012; US-PLT-01…03 re-keyed to US-D01-001…003 |
| Non-functional requirement | `NFR-<AREA>-nnn` | See §11. NFR IDs are global; PRD-001 takes the first numbers in each area it uses, and later PRDs continue from the next free number |

Priority: **M** must (release-blocking), **S** should — as PRD-000 Chapter 3. User stories use **C** critical (release-blocking) and **O** optional — as PRD-000 Chapter 5.

## 3. Business requirements

| ID | Business requirement | Capabilities |
| --- | --- | --- |
| BR-D01-001 | No AMC can see another AMC's data | CAP-D01-001, -003, -005 |
| BR-D01-002 | Every person and system gets only the access its job needs, approved by someone else, and loses it promptly when the job changes | CAP-D01-002, -004, -005 |
| BR-D01-003 | Every change, approval, export, sign-in and refused action can be proven later and cannot be altered without detection | CAP-D01-010 |
| BR-D01-004 | Each AMC can tailor AMC OS through governed, versioned configuration, never through customer-specific code (master prompt §3.6) | CAP-D01-008 |
| BR-D01-005 | The vendor can onboard, run, upgrade, support and offboard many AMCs without default access to their business data | CAP-D01-001, -005, -011 |
| BR-D01-006 | Each AMC's subscription (plan, modules, usage) is recorded and decides what it can use (D-14) | CAP-D01-006 |
| BR-D01-007 | AMC OS holds the AMC's legal entities, departments, branches and reporting lines, so that scopes, approvals and reports follow the real organisation | CAP-D01-007, CAP-D01-009 |

## 4. Functional requirements

Every requirement also obeys PRD-000 common rules C1–C8 (tenancy, audit, maker-checker, effective dating, decimal money, APIs, idempotency, AI boundary).

### 4.1 Tenant management (CAP-D01-001) — BR-D01-001, BR-D01-005

- **FR-D01-001 (M) Tenant register.** Each tenant has: legal name of the AMC and of the mutual fund trust, regulator registration references (format **[VAL]** — confirm: Compliance), isolation tier (shared or dedicated cell, ADR-0003), cell, hosting region (AWS Mumbai with Hyderabad for disaster recovery, D-7), subscription (§4.6) and status. Status follows WF-019: `DRAFT → PROVISIONING → SETUP → ACTIVE → SUSPENDED → OFFBOARDED`.
- **FR-D01-002 (M) Two-sided activation.** A tenant becomes `ACTIVE` only when the Platform Operator (ROLE-20) and the AMC's Tenant Administrator (ROLE-19) have both confirmed; the operator can never be the only confirmer (SOD-15).
- **FR-D01-003 (M) Tenant settings and feature flags.** Tenant-level settings and feature flags are configuration items (§4.8): versioned, effective-dated, maker-checker.
- **FR-D01-004 (M) Offboarding and data export.** On exit the tenant becomes `SUSPENDED` (read-only), a complete export of the tenant's data is delivered in documented, non-proprietary formats with a manifest and checksums **[DES]**, and the AMC confirms receipt. Deletion or retention afterwards follows the contract and record-retention law. Export format, the time the AMC has to take its data and how long records are kept after exit are **[ASSUMPTION]** — confirm: project owner (Q21) and REG-001 for retention **[VAL]**.
- **FR-D01-005 (M) Tenant isolation.** Every tenant record carries `tenant_id`, every tenant table has forced row-level security and composite `(tenant_id, id)` keys (AGENTS.md non-negotiable 4; DDL-000). A request for another tenant's object returns "not found" and raises a cross-tenant alert (US-D01-003). Isolation also covers events, object storage, caches, AI retrieval, logs, analytics and backups (master prompt §3.4); the design is EA-005 (Step 12).

### 4.2 User management (CAP-D01-002) — BR-D01-002

- **FR-D01-006 (M) Joiner.** A user created or synced from the AMC's identity provider (D-8) starts with **no role**. Roles come only through an approved grant (FR-D01-016).
- **FR-D01-007 (M) Mover.** When a user's department, job or reporting line changes, roles that do not fit the new job are flagged for removal and the role owner decides (WF-020).
- **FR-D01-008 (M) Leaver.** A leaver's sessions are revoked and all roles removed. How quickly AMC OS learns of a leaver depends on the identity provider (pushed change or next sign-in) — confirm with each provider (EA-002). The maximum time from leaver event to revocation is a target to be set **[ASSUMPTION — confirm: DEP-16 of the pilot AMC]**.
- **FR-D01-009 (M) Recertification.** Each role grant is recertified by the role owner at a tenant-set frequency **[ASSUMPTION — confirm: DEP-16 of the pilot AMC]**; nobody certifies their own access (SOD-13); overdue recertifications escalate to DEP-16; whether access is then removed automatically is a tenant setting (WF-020).
- **FR-D01-010 (M) Service accounts and API clients.** Non-human identities (ROLE-27) have a named human owner, only the API operations their integration needs, credentials that can be rotated without downtime **[DES]**, and are reviewed in every recertification. They never hold approve (A) or override (O) rights.

### 4.3 Identity (CAP-D01-003) — BR-D01-001, BR-D01-002

- **FR-D01-011 (M) Single sign-on.** People sign in through the AMC's identity provider over OIDC or SAML; Keycloak is offered to an AMC without one (D-8).
- **FR-D01-012 (M) Multi-factor authentication.** Every human sign-in must carry proof of MFA from the identity provider; a sign-in without it is refused (US-D01-002, from US-PLT-02).
- **FR-D01-013 (M) Sessions.** Idle and absolute session time-outs are tenant settings with platform minimums **[ASSUMPTION — values set in EA-002 / SEC-001]**; a user and the Information Security Officer can see active sessions; sessions can be revoked.
- **FR-D01-014 (M) Tenant context from identity only.** The tenant is taken from the authenticated identity, never from a browser-supplied value, path, header or body (master prompt §3.4). A request that names a different tenant is refused and audited.

### 4.4 Role-based access (CAP-D01-004) — BR-D01-002

- **FR-D01-015 (M) Role catalogue.** Each tenant starts with the BA-005 §2 default roles ROLE-01…ROLE-27 and the BA-005 §3 default rights. A tenant may add or rename roles and change rights through configuration (§4.8), but cannot remove or weaken an SoD rule (BRL-D01-004).
- **FR-D01-016 (M) Role grants (maker-checker).** The **Technology Administrator** (ROLE-17) requests a grant (maker); the **Tenant Administrator** (ROLE-19) approves it (checker). A grant of the Tenant Administrator role is approved by another Tenant Administrator and reported to the Information Security Officer (SOD-05, SOD-16). In small-team mode (FR-D01-019) an Information Security Officer also approves every access grant before it takes effect (owner decisions D-22, D-24; a Compliance Officer for a grant to the only ISO, D-23). This follows PRD-000 Chapter 6 and BA-005 and **closes BA-005 §7 C7**: PRD-000 US-PLT-01 had the Tenant Administrator creating users with roles; it is re-keyed as US-D01-001 with the maker-checker split.
- **FR-D01-017 (M) Scope and approval authority.** A grant carries scope attributes (schemes, desks, regions, distributors) and, where needed, an approval authority (BA-005 §4, for example "Head of Fund Accounting"). Both are effective-dated and part of the grant that is approved.
- **FR-D01-018 (M) SoD enforcement.** The conflicting role pairs of BA-005 §5 are refused at request time with the rule shown, and re-checked at the moment of every action. A nightly toxic-combination scan reports any conflict to Compliance (SOD-11).
- **FR-D01-019 (M) SoD waivers and small-team mode.** No SoD rule can be waived (owner decision D-18), except: (1) SOD-03, which a tenant may switch off only through a configuration change checked by a Compliance Officer; and (2) small-team mode of SOD-16 (D-19…D-25, BA-005 §5): only for a small AMC (test set in pilot discovery **[VAL]**, D-20), switched on only with approval of both an Information Security Officer and a Compliance Officer (D-21); switching it on is a configuration change (WF-021); a Tenant Administrator may then also hold a business role (never ROLE-17 or ROLE-22 **[DES]**); every access grant (role, scope change, approval authority) is approved by an Information Security Officer who is not the grantee **[DES]** before it takes effect, and a rejection blocks it (D-22, D-24; a Compliance Officer reviews grants to the only ISO, D-23); the mode is switched off when a grace period ends once the AMC is no longer small, and Tenant Administrators then give up business roles (D-25). Both exceptions and every small-team-mode grant appear in the SOD-11 report.

### 4.5 Permission management (CAP-D01-005) — BR-D01-001, BR-D01-002, BR-D01-005

- **FR-D01-020 (M) One permission per API operation.** Permissions are named `domain.object.action` (PRD-000 Chapter 6); anything not granted is denied. The final list is written with the OpenAPI contracts (Step 24).
- **FR-D01-021 (M) Scope rules on the server.** Scope (ABAC) is evaluated by the service on every request, never by the user interface (master prompt §3.5).
- **FR-D01-022 (M) Masking.** Investor personal data is masked by role; an Investor Service Executive may unmask one record with a recorded reason (BA-005 §3).
- **FR-D01-023 (M) Break-glass access.** Platform-operator access to tenant business data follows WF-022: tenant approval by a Tenant Administrator, stated scope, time-boxed to at most 4 hours, every action logged, automatic expiry, report to the tenant (SOD-09 **[DES; CSCRF alignment VAL]**, SOD-15).
- **FR-D01-024 (M) AI agent identities.** ROLE-26 can hold read tools and proposal/draft tools only (ADR-0008); a call by an AI agent identity to any approve, override, post, publish or execute operation returns HTTP 403 and raises a security alert (SOD-10).
- **FR-D01-025 (M) Export controls.** Every export is watermarked with user and time; personal-data exports need a reason and approval; a bulk export above a tenant threshold raises an alert (PRD-000 Chapter 6; threshold **[ASSUMPTION — confirm: DEP-16 of the pilot AMC]**).

### 4.6 Subscription management (CAP-D01-006) — BR-D01-006 (D-14)

- **FR-D01-026 (M) Plan and module entitlements.** Each tenant has a subscription plan and a list of entitled modules (domains or features), effective-dated. Entitlements decide which domains, APIs and screens are switched on for the tenant.
- **FR-D01-027 (S) Usage metering.** AMC OS counts agreed usage measures per tenant per period and shows them to the Tenant Administrator. Which measures are counted (for example named users, schemes, API calls, storage) is a commercial decision **[ASSUMPTION — confirm: project owner, Q20]**. Metering counts only; it never reads business content.
- **FR-D01-028 (S) Plan changes and renewals.** Upgrades, downgrades and renewals take effect on a stated date. A downgrade or lapse never deletes data; whether a lapsed module becomes read-only or hidden is **[ASSUMPTION — confirm: project owner, Q20]**.

### 4.7 Organization hierarchy (CAP-D01-007) — BR-D01-007

- **FR-D01-029 (M) Legal entities.** Sponsor, mutual fund trust, AMC and trustee company or board of trustees (BA-002 §1), with effective dates.
- **FR-D01-030 (M) Departments and cost centres.** Departments start from the BA-002 reference model (DEP-01…DEP-19) as an editable template (WF-019); cost centres are attached to departments and used by D15.
- **FR-D01-031 (S) Branches, regions and zones.** Used by D14 to map distributors and RMs (CAP-D14-005).
- **FR-D01-032 (M) Reporting lines.** Effective-dated reporting lines; used to route recertifications (FR-D01-009) and to find a user's department head.

### 4.8 Configuration management (CAP-D01-008) — BR-D01-004

- **FR-D01-033 (M) Configuration catalogue.** Every setting a tenant may change is listed with: key, data type, allowed values, default, owning department, and whether it is a **regulatory parameter** (cut-off, timeline, limit). A setting not in the catalogue cannot be changed by a tenant.
- **FR-D01-034 (M) Versioned, approved changes.** A change creates a new version with an effective date; it is checked by someone from the owning department, plus a Compliance Officer for a regulatory parameter (WF-021, SOD-12). History is never edited; a mistake is fixed by a new version.
- **FR-D01-035 (M) Promotion between environments.** A configuration version is tested in a non-production environment and promoted to production unchanged (same version identifier) (WF-021).
- **FR-D01-036 (M) Difference view.** Any two versions of a setting can be compared, with maker, checker and effective dates.
- **FR-D01-037 (M) No customer-specific code.** A need that the catalogue cannot meet becomes a product change request for all tenants, never a code fork for one tenant (master prompt §3.6) **[DES]**. Compliance rules are **not** changed through configuration; they follow the rule lifecycle of CAP-D08-001 (SOD-08).

### 4.9 System administration (CAP-D01-009) — BR-D01-007

- **FR-D01-038 (M) Business calendar master.** One source of holidays per calendar (exchanges, clearing, banks, RTA, settlement), changed under maker-checker (DA-000 `platform.business_calendar`). D07 and D12 use it (BA-001 §4).
- **FR-D01-039 (M) Scheduled jobs.** A register of scheduled jobs and batch windows with owner, schedule, dependencies, last run and status; a missed or failed job raises an exception to its owner.
- **FR-D01-040 (S) Notification channels.** Set-up of the channels AMC OS uses to notify users (in-app and e-mail at minimum; others **[ASSUMPTION — confirm: pilot discovery]**).
- **FR-D01-041 (M) Reference code lists.** Shared code lists (for example reason codes, country codes) are versioned and effective-dated.

### 4.10 Audit management (CAP-D01-010) — BR-D01-003

- **FR-D01-042 (M) Audit events.** Every create, update, state change, approval, export, sign-in and refused action writes an append-only audit event with actor, tenant, time, before and after values, reason and request identifier (PRD-000 C2 **[REG — record keeping under MF Regulations 2026; DES for format]**).
- **FR-D01-043 (M) Tamper evidence.** Audit events are hash-chained per tenant per day (PRD-000 Chapter 7, Auditability).
- **FR-D01-044 (M) Audit search and export.** Auditors (ROLE-18) and the Information Security Officer (ROLE-22) can search and export the audit log; exports are themselves audited.
- **FR-D01-045 (M) Access logs and retention.** Sign-in and access logs, including refused requests, are kept for the periods the law requires (PRD-000 Chapter 7, Data retention **[REG — VAL exact periods per record type]**).

### 4.11 Environment administration (CAP-D01-011) — BR-D01-005

- **FR-D01-046 (M) Environment register.** Each tenant's environments (development, test, UAT, production) are recorded with their release version and cell.
- **FR-D01-047 (M) Release version per tenant.** The tenant can see its current release and scheduled upgrades; release compatibility and cell upgrades are designed in EA-004 (Step 12) and INF-001 (Step 26).
- **FR-D01-048 (M) Maintenance windows and non-production data.** Maintenance windows are announced to tenants in advance (notice period **[ASSUMPTION — confirm: project owner]**). Production investor personal data is never copied unmasked into non-production environments (GOV-003 §5 principle; DPDP obligations **[REG — VAL]**, PRD-000 Chapter 7, Privacy).

## 5. Business rules

| ID | Rule | Source / label |
| --- | --- | --- |
| BRL-D01-001 | Tenant context comes only from the authenticated identity | Master prompt §3.4 **[DES]** |
| BRL-D01-002 | Deny by default: a user or service account with no approved grant can do nothing | **[DES]** |
| BRL-D01-003 | Nobody approves a role grant, scope change or approval authority for themselves | SOD-16 |
| BRL-D01-004 | A tenant may change roles and rights by configuration but may not remove or weaken an SoD rule; only SOD-03 may be switched off, and SOD-16 relaxed only in small-team mode (FR-D01-019) | BA-005 §5.1; owner decisions D-18, D-19 |
| BRL-D01-005 | The Technology Administrator and the Tenant Administrator hold no business role and no other role; in small-team mode a Tenant Administrator may also hold a business role (FR-D01-019) | SOD-05, SOD-16; owner decisions D-19…D-25 |
| BRL-D01-006 | A platform operator has no default access to tenant business data and is never the checker of a tenant action | SOD-09, SOD-15 |
| BRL-D01-007 | A configuration version applies only from its effective date after approval; past versions are never edited | PRD-000 C4 **[DES]** |
| BRL-D01-008 | Audit events are never updated or deleted | PRD-000 C2, Chapter 7 |
| BRL-D01-009 | An AI agent identity can never hold an approval authority or an approve, override, post, publish or execute permission | SOD-10; master prompt §3.1 |
| BRL-D01-010 | A subscription downgrade, lapse or offboarding never deletes data before the export is confirmed (or the contract time limit passes) and the legal retention period is respected | **[ASSUMPTION — confirm: project owner, Q20, Q21]**; retention **[VAL]** |

## 6. Workflows

| Workflow | What D01 adds here |
| --- | --- |
| [WF-019](../02_business_architecture/BA-004_end_to_end_workflows.md) Tenant onboarding and offboarding | FR-D01-001…005, FR-D01-026, FR-D01-029…030, FR-D01-046 |
| WF-020 User access lifecycle | FR-D01-006…010, FR-D01-016…019 |
| WF-021 Configuration change and promotion | FR-D01-033…037 |
| WF-022 Break-glass support access | FR-D01-023 |
| WF-026 Settlement obligations and funding (calendar master only) | FR-D01-038 |

No new workflow is needed for D01: BA-004 §5.1 lists no D01 gap.

## 7. Permissions by capability

BA-005 §3 gives D01 rights for the whole domain to the CTO (R A(tech config)), the Technology Administrator (C U S, A by Tenant Administrator), the Auditor (R audit log), the Tenant Administrator, the Information Security Officer and the Platform Operator (BA-005 new-role rights); every other role has "—", apart from the CEO and Compliance Officer read access to market-abuse access logs listed below the BA-005 §3 matrix. This table splits those rights by capability (BA-005 §7 C2). "Maker" may create or submit; "Checker" approves (≠ maker, SOD-01). Cells marked **†** give a right that BA-005 §3 does not give; each is listed with its reason below the table and must be carried into the BA-005 D01 column (open point C9). Everyone not listed has no access.

| Capability | Maker | Checker | Read |
| --- | --- | --- | --- |
| CAP-D01-001 Tenant management | Platform Operator (create, provision, offboard) | Tenant Administrator (activation, offboarding confirmation; SOD-15) | CTO, Information Security Officer; Auditor through the audit log |
| CAP-D01-002 User management | Technology Administrator; role owners (recertification)† | Tenant Administrator (user changes); recertification has no checker and is reported to DEP-16 (BA-005 §4 `platform.access.recertify`) | Information Security Officer; Auditor through the audit log |
| CAP-D01-003 Identity | Technology Administrator (connection set-up) | Tenant Administrator; Information Security Officer for MFA and session policy | CTO; Auditor through the audit log |
| CAP-D01-004 Role-based access | Technology Administrator | Tenant Administrator (another Tenant Administrator for a Tenant Administrator grant); in small-team mode also an Information Security Officer before the grant takes effect, blocking (a Compliance Officer for a grant to the only ISO) — D-22…D-24 | Information Security Officer; Compliance Officer receives the SOD-11 report†; Auditor through the audit log |
| CAP-D01-005 Permission management | Technology Administrator; Platform Operator (break-glass request only) | Tenant Administrator; Information Security Officer (access policy) | Auditor through the audit log |
| CAP-D01-006 Subscription management | Platform Operator (plan, entitlements) | Tenant Administrator confirms plan changes | CTO; CFO† |
| CAP-D01-007 Organization hierarchy | Technology Administrator | Tenant Administrator | CTO; all business roles read their own organisation unit and reporting line† |
| CAP-D01-008 Configuration management | Technology Administrator, or the setting's business owner† | Checker from the owning department†; plus Compliance Officer for a regulatory parameter† (SOD-12); CTO for technical settings ("A(tech config)"); switching small-team mode on: Information Security Officer **and** Compliance Officer (D-21) | Owning department†; Auditor through the audit log |
| CAP-D01-009 System administration | Technology Administrator | Tenant Administrator | CTO; all business roles read business calendars† |
| CAP-D01-010 Audit management | System only (no human maker) | — | Auditor (R E), Information Security Officer (R E), CEO and Compliance Officer for market-abuse access logs (BA-005 §3) |
| CAP-D01-011 Environment administration | Platform Operator | Tenant Administrator confirms production upgrade dates **[ASSUMPTION — confirm: pilot discovery]** | CTO, Technology Administrator |

**Rights added beyond BA-005 §3 (†), with reasons [DES]:**

| Cell | Reason |
| --- | --- |
| Role owners as makers of recertification decisions (CAP-D01-002) | BA-004 WF-020 and BA-005 `platform.access.recertify` already name the role owner (department head); BA-005 §3 has no D01 cell for it |
| Compliance Officer receives the SoD report (CAP-D01-004) | SOD-11 sends the nightly toxic-combination report to Compliance |
| CFO reads subscription (CAP-D01-006) | WF-019 names DEP-14 for subscription cost |
| Business roles read own organisation unit and reporting line (CAP-D01-007) | Scopes, approval routing and recertification depend on them (FR-D01-017, FR-D01-032); read only, own record **[ASSUMPTION — confirm: DEP-16 of the pilot AMC]** |
| Setting owner as maker; owning department checker and reader; Compliance Officer checker (CAP-D01-008) | BA-004 WF-021, BA-005 `platform.config.approve` and SOD-12 already give these; BA-005 §3 D01 column does not show them |
| Business roles read business calendars (CAP-D01-009) | Calendars decide business dates in every domain (BA-001 §4: one holiday source for D07, D12) |

## 8. User stories and acceptance criteria

| ID | Story | Pri | Acceptance criteria (Given / When / Then) |
| --- | --- | --- | --- |
| US-D01-001 (was US-PLT-01) | As a Technology Administrator, I want to request roles for a user, approved by a Tenant Administrator, so that each person sees only what their job needs | C | **AC-US-D01-001-1** Given a user granted only the Dealer role, when they open a NAV approval screen or call `nav.run.approve`, then HTTP 403 is returned and the refusal is audited. **AC-US-D01-001-2** Given a role request made by a Technology Administrator, when the same person tries to approve it, then it is refused with `SOD_VIOLATION`. |
| US-D01-002 (was US-PLT-02) | As an Information Security Officer, I want MFA for every user, so that stolen passwords are not enough | C | **AC-US-D01-002-1** Given a sign-in through SSO without an MFA claim, when it is attempted, then access is denied and audited. |
| US-D01-003 (was US-PLT-03) | As any user, I want my session limited to my AMC, so that I never see another AMC's data | C | **AC-US-D01-003-1** Given a user of tenant A, when any API is called with an object ID of tenant B, then "not found" (404) is returned and a cross-tenant alert is logged. |
| US-D01-004 | As an Information Security Officer, I want leavers' access removed, so that former staff cannot act | C | **AC-US-D01-004-1** Given a leaver event from the identity provider, when AMC OS processes it, then all sessions are revoked, all roles removed, and both are audited. |
| US-D01-005 | As a Compliance Officer, I want conflicting roles refused at grant time | C | **AC-US-D01-005-1** Given a user holding the Head of Fund Accounting authority, when a Dealer role is requested for them, then the request is refused showing SOD-02. |
| US-D01-006 | As a Tenant Administrator, I want my own role grants approved by someone else | C | **AC-US-D01-006-1** Given a request to grant the Tenant Administrator role, when the only approver offered is the person receiving it, then approval is refused (SOD-16) and another Tenant Administrator is required. |
| US-D01-007 | As a Head of Fund Accounting, I want configuration changes to apply only from their effective date | C | **AC-US-D01-007-1** Given an approved new version of a setting effective from date D, when a process runs for a business date before D, then it uses the previous version; on or after D it uses the new one. |
| US-D01-008 | As a Compliance Officer, I want regulatory parameters to need my approval | C | **AC-US-D01-008-1** Given a change to a setting marked regulatory parameter, when only the owning department's checker has approved, then the change is not effective until a Compliance Officer also approves. |
| US-D01-009 | As a Tenant Administrator, I want break-glass access to end on its own | C | **AC-US-D01-009-1** Given break-glass access approved for 2 hours, when 2 hours pass, then the access ends without any action, and the tenant receives a report of every action taken. |
| US-D01-010 | As an Information Security Officer, I want AI agents unable to approve anything | C | **AC-US-D01-010-1** Given an AI agent identity, when it calls any approve, override, post, publish or execute operation, then HTTP 403 is returned and a security alert is raised. |
| US-D01-011 | As an Auditor, I want proof that the audit log was not altered | C | **AC-US-D01-011-1** Given a day's audit events for a tenant, when one stored event is changed outside the application, then the hash-chain check for that day fails and an alert is raised. |
| US-D01-012 | As a Tenant Administrator, I want only my entitled modules switched on | O | **AC-US-D01-012-1** Given a tenant not entitled to D14, when any user calls a D14 API, then it is refused with `NOT_ENTITLED` and no data is returned. |
| US-D01-013 | As an Information Security Officer of a small AMC, I want every access grant to wait for my approval in small-team mode | M | **AC-US-D01-013-1** Given small-team mode is off, when a Tenant Administrator approves only the switch-on request, then the mode stays off until an Information Security Officer **and** a Compliance Officer have both approved. **AC-US-D01-013-2** Given small-team mode is on, when a role is granted, then it is not effective until an Information Security Officer who is not the grantee approves it; if the ISO rejects, the grant never takes effect. **AC-US-D01-013-3** Given the AMC has one ISO, when access is granted to that ISO, then a Compliance Officer is the required approver. **AC-US-D01-013-4** Given small-team mode is on, when a Tenant Administrator is offered ROLE-17 or ROLE-22, then the grant is refused with SOD-05 / SOD-16 shown. |

Definition of done for every story: as PRD-000 Chapter 5 (unit and integration tests, API documentation, audit events verified, row-level-security negative test, performance test for any stated target, accessibility check).

## 9. Exceptions

| Exception | Handling |
| --- | --- |
| Identity-provider connection test fails during onboarding | Tenant stays in `SETUP` (WF-019) |
| No capacity in the chosen cell | New cell or other cell, decided in EA-004 (Step 12) |
| AMC does not confirm its export | Tenant stays `SUSPENDED` until the contract time limit **[ASSUMPTION — confirm: project owner, Q21]** |
| Role request conflicts with an SoD rule | Refused with the rule shown (FR-D01-018) |
| Small-team mode: Information Security Officer rejects a grant | Grant never takes effect; rejection in the SOD-11 report (FR-D01-019, D-24) |
| Small-team mode: the AMC is no longer small and the grace period ends | Mode switched off; Tenant Administrators give up business roles (FR-D01-019, D-25); grace period and who detects the change set in pilot discovery **[VAL]** |
| Recertification overdue | Escalation to DEP-16; optional automatic removal (tenant setting) |
| Configuration change fails catalogue validation or UAT test | Back to the maker (WF-021) |
| Tenant refuses break-glass | Incident handled without data access (WF-022) |
| Audit hash-chain check fails | Security incident to DEP-16 and the platform operator; no automatic repair **[DES]** |
| Scheduled job missed or failed | Exception to the job owner (FR-D01-039); generic exception queue CAP-D12-008 |

## 10. Data and interfaces

**Owned schemas:** `platform`, `identity`, `audit` (GOV-001 §3). No database change is made in this step.

| Need | Exists in DDL-000 | Not yet in DDL-000 (for DA-001 / DDL, Steps 15–16) **[DES]** |
| --- | --- | --- |
| Tenants, calendars, outbox, idempotency | `platform.tenant`, `platform.business_calendar`, `platform.outbox_event`, `platform.idempotency_key` | Subscription plan, entitlement and usage meter; tenant settings and feature flags (DA-000 lists them for `platform`); environment and release register; scheduled-job register; notification channels; reference code lists; organisation (legal entity, department, cost centre, branch, reporting line) — `platform.cell` is already planned in GOV-006 Step 16 |
| Users, roles, permissions | `identity.app_user`, `identity.role`, `identity.permission`, `identity.role_permission`, `identity.user_role` | Scope attributes, approval authorities, sessions and API clients (DA-000 lists them for `identity`), role-grant requests, recertification campaigns, break-glass grants |
| Audit | `audit.audit_event` (partitioned) | Hash-chain anchors and access logs (DA-000 lists them for `audit`); configuration catalogue and versions (schema to be decided in EA-003, Step 11) |

**Interfaces (indicative, not contracts):** the AMC's identity provider over OIDC or SAML (D-8; details per provider in EA-002). APIs for tenants, users, role grants, configuration, calendars, audit search and entitlements; final paths and `API-D01-nnn` IDs come with the OpenAPI contracts (Step 24). Events such as tenant activated, role granted, role revoked, configuration version approved and break-glass granted are named in the GOV-001 `<NAME>.v<n>` form in the event catalogue (EA-007, Step 13).

## 11. Non-functional requirements

Targets marked "Proposed" are carried from PRD-000 Chapter 7 as engineering commitments to be confirmed with customers; nothing new is invented here.

| ID | Requirement | Type / source |
| --- | --- | --- |
| NFR-SEC-001 | Tenant isolation enforced across authentication, authorisation, services, databases, APIs, events, object storage, caches, AI retrieval, logs, analytics, backups and support tools; row-level security forced on every tenant table and negative-tested (TRACE-001 seed) | Mandatory — master prompt §3.4 **[DES]** |
| NFR-SEC-002 | MFA and SSO (SAML/OIDC) for every human user; RBAC + ABAC | PRD-000 Ch 7, CSCRF-driven **[REG]**, specifics Proposed |
| NFR-SEC-003 | TLS 1.3 in transit, AES-256 at rest, tenant-specific keys in a key-management service, field-level encryption of investor personal data, secrets in a vault | PRD-000 Ch 7, CSCRF-driven **[REG]**, specifics Proposed |
| NFR-AUD-001 | Append-only audit log, hash-chained per tenant per day, available to the tenant | PRD-000 Ch 7 — Mandatory **[DES; REG record-keeping]** |
| NFR-RET-001 | Audit and access logs kept for the periods required by SEBI MF Regulations, CSCRF and PMLA | PRD-000 Ch 7 **[REG — VAL exact periods per record type]** |
| NFR-AVAIL-001 | Sign-in and authorisation are available whenever any core trading-day service is (99.95% during 08:00–23:00 IST business days, 99.9% otherwise) | Proposed — PRD-000 Ch 7 availability targets applied to identity **[DES]** |
| NFR-DR-001 | RPO ≤ 5 min, RTO ≤ 2 h; primary AWS Mumbai, disaster recovery AWS Hyderabad (D-7); data residency in India | Proposed RPO/RTO (PRD-000 Ch 7); localisation and DR drills **[REG — CSCRF / SEBI cloud framework; VAL]** |
| NFR-SCAL-001 | From 1 to 50+ tenants on the same code base (design capacity 50, GOV-006 Q1) | Proposed — PRD-000 Ch 7 |
| NFR-PRIV-001 | DPDP Act 2023 obligations (notice, consent, purpose limitation, rights, breach notification) supported by masking, export controls and non-production data rules | PRD-000 Ch 7 **[REG — VAL DPDP Rules timeline]** |
| NFR-OBS-001 | Per-tenant service-level dashboards and alerts for cross-tenant attempts, refused AI-agent actions, failed hash-chain checks and missed jobs | Proposed — PRD-000 Ch 7 Observability **[DES]** |

## 12. AI in this domain

No D01 AI feature is proposed. AI agents act through ROLE-26 identities governed here (FR-D01-024, BRL-D01-009); the agents themselves are D17 (PRD-017, AIML-001).

## 13. Open points

| # | Point | Where closed |
| --- | --- | --- |
| C1 | BA-005 §7 C7 (US-PLT-01 maker) — **closed here** by FR-D01-016 and US-D01-001 | — |
| C2 | Small new AMCs may not have three people with no business role (BRL-D01-005) | Closed by owner decisions D-19…D-25 (small-team mode); the "small" test and grace period are set in pilot discovery |
| C3 | Which usage measures are metered; what a lapsed module looks like | Owner Q20 |
| C4 | Offboarding: export format, time to take data, retention after exit | Owner Q21; REG-001 (Step 25) |
| C5 | Session time-outs, leaver revocation time, maintenance notice, bulk-export threshold have no values | EA-002 (Step 10), SEC-001 (Step 25), pilot discovery |
| C6 | Configuration catalogue schema (`platform` or a separate `config` schema) is not decided | EA-003 (Step 11) |
| C7 | TRACE-001 seed row "BR-D12-001 … FR-D01-0xx (SOD rules)" can now point to FR-D01-018 | TRACE-002 (Step 27) |
| C8 | NFR IDs are allocated per PRD (§2); no central NFR register yet | TRACE-002 (Step 27) |
| C9 | The † rights of §7 are not yet in the BA-005 §3 D01 column | Next BA-005 revision |

## Sources

All sources are inside this repository; no external facts are introduced.

| # | Source | Used for |
| --- | --- | --- |
| R1 | [PRD-000 v0.9](PRD-000_master_prd_v0.9.md) Ch 3 (C1–C8), Ch 5 (US-PLT-01…03), Ch 6 (roles, SOD-01…11, export controls), Ch 7 (NFRs) | Requirements, labels, targets |
| R2 | [BA-001](../02_business_architecture/BA-001_business_capability_map.md) §3 D01, §4 | Capabilities, shared owners |
| R3 | [BA-002](../02_business_architecture/BA-002_amc_operating_model.md) §1, §3 | Legal entities, departments |
| R4 | [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-019…WF-022, §5.1 | Workflows |
| R5 | [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md) §2–§5, §7 | Roles, rights, approval authorities, SoD, C7 |
| R6 | [GOV-001](../00_governance/GOV-001_document_control_and_identifiers.md) §3–§4; [TRACE-001](../00_governance/TRACE-001_traceability_matrix.md) §2 | IDs, seed rows |
| R7 | [DA-000 v0.9](../05_data_architecture/DA-000_data_and_database_architecture_v0.9.md) Ch 2, §4 register; `database/ddl/DDL-000_core_schema_v0.9.sql` | Schemas and existing tables |
| R8 | [ADR-0003](../../architecture/adrs/ADR-0003_multi_tenancy_and_cells.md), [ADR-0008](../../architecture/adrs/ADR-0008_ai_boundary.md) | Isolation tiers, AI proposals |
| R9 | [LOOP_STATE.md](../../LOOP_STATE.md) owner decisions D-7, D-8, D-11, D-14, D-17…D-25 | Hosting, identity, segment, subscription meaning, role IDs, SoD waivers, small-team mode |
