---
id: INT-015
title: Provider Specification — AMC identity providers (sign-in, MFA, user changes)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-015 — AMC identity providers

Outside system X01 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). The design decision is in [ADR-0016](../../architecture/adrs/ADR-0016_identity_provider_and_sign_in.md) (Draft, owner-only): each AMC's own identity provider through OIDC or SAML, brokered per cell; Keycloak for an AMC without one (D-8). This specification adds the 14 integration fields. **Which identity provider each AMC uses, and whether it can push user changes, is Confirm with the AMC's identity team.** Builds on Draft documents EA-001, EA-002, ADR-0016, PRD-001, BA-004 WF-020 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | The AMC's own identity provider (for example a corporate directory service), or Keycloak run by AMC OS for that AMC (D-8) | [DES] |
| 2 | Business purpose | Prove who a person is (sign-in, MFA proof); tell AMC OS when people join, move or leave (WF-020). Roles and grants stay in AMC OS (FR-D01-006) | [DES] |
| 3 | Approved interface | OIDC or SAML sign-in (ADR-0016, D-8) — open standards **[IND]**. User changes: pushed by the identity provider where it supports a provisioning standard, otherwise read at sign-in — Confirm with each identity provider (BA-004 WF-020 hand-off) | [IND] / Confirm |
| 4 | Authentication | Signed tokens or assertions verified against the provider's published keys; client credentials per tenant | [DES] |
| 5 | Data contract | Canonical family: **sign-in and user changes** (subject, tenant, groups as hints only, MFA proof) (INT-001 §3). Groups never grant AMC OS roles by themselves; a role grant needs AMC OS approval (BA-005) | [DES] |
| 6 | Ingestion schedule | Sign-in: per request. User changes: as pushed, or daily comparison where only sign-in data is available **[ASSUMPTION]** | [ASSUMPTION] |
| 7 | Error handling | Token invalid or no MFA proof → sign-in refused (EA-001 §5 B0→B1); identity provider down → no new sign-ins for that tenant; existing sessions end at their normal expiry | [DES] |
| 8 | Retry logic | Key-set fetch and provisioning reads: class A1. No financial instructions | [DES] |
| 9 | Idempotency | User change: tenant + subject + change ID or timestamp | [DES] |
| 10 | Reconciliation | AMC OS users vs identity-provider users in the recertification (WF-020); leavers disabled in the provider but still active in AMC OS → alert | [DES] |
| 11 | Monitoring | Sign-in failures by reason; key-set fetch failures; certificate expiry; leaver gaps | [DES] |
| 12 | Commercial dependency | The AMC's own identity licence; none for Keycloak (open source) | [IND] |
| 13 | Certification requirements | Connection test per tenant at onboarding (WF-019) | [DES] |
| 14 | Operational ownership | DEP-15 Technology (connection); DEP-16 Information security (MFA and access policy) | [DES] |

## 2. Outbound instructions

None.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [ADR-0016](../../architecture/adrs/ADR-0016_identity_provider_and_sign_in.md) | Sign-in design |
| S2 | [EA-001](../04_enterprise_architecture/EA-001_system_context.md) X01, §5 | Trust boundary |
| S3 | [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-019, WF-020 | Onboarding, user lifecycle |
| S4 | [LOOP_STATE.md](../../LOOP_STATE.md) D-8 | Decision |
