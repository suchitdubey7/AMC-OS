---
id: ADR-0016
title: Sign-in through each AMC's own identity provider, brokered by Keycloak per cell; Keycloak as identity provider for AMCs without one
status: Draft
date: 2026-11-21
deciders: ARB (interim: project owner)
domains: D01 + all
related: EA-001, EA-002 §4; PRD-001 FR-D01-006…-012; ADR-0003; owner decision D-8
---

# ADR-0016 — Sign-in through each AMC's own identity provider, brokered by Keycloak per cell

> Written by the build loop (GOV-006 Step 10). Draft. The **direction** (each AMC's own IdP via OIDC/SAML; Keycloak for AMCs without one) is owner decision D-8 (20 Nov 2026). The **broker design** below is a proposal for the owner.

## Status
Draft

## Context
- Master prompt §5 L2 requires OAuth2, OIDC, SSO, MFA, RBAC, ABAC where needed, tenant context and audit; §3.4 requires tenant context from authenticated identity only.
- D-8: people sign in through their AMC's own identity provider (IdP) over OIDC or SAML; Keycloak for AMCs without one. PRD-001 FR-D01-011 (SSO), FR-D01-012 (MFA proof required), FR-D01-006 (users start with no role), FR-D01-008 (leavers; EA-002 to say how), NFR-AVAIL-001 (sign-in as available as trading-day services).
- A shared cell will serve several AMCs, each with a different IdP product and protocol **[ASSUMPTION — confirm in pilot discovery which IdPs AMCs use]**.
- Keycloak facts checked on 21 Nov 2026: current release line 26.8 (26.8.0 released 1 Oct 2026; latest patch 26.8.2 of 5 Nov 2026; only the latest release line gets security fixes) ([Keycloak 26.8.0 release note](https://www.keycloak.org/2026/10/keycloak-2680-released); [endoflife.date](https://endoflife.date/keycloak)). The 26.8 release note lists a supported SCIM API for user provisioning and "token exchange delegation for AI agents and automation" — the latter marked **preview** in that release note, so not yet relied on. Keycloak joined the CNCF as an incubating project in April 2023 ([CNCF blog title](https://cncf.io/blog/2023/04/11/keycloak-joins-cncf-as-an-incubating-project), page not opened) and added an "Organizations" feature for many organisations in one installation in version 26 ([CNCF blog title](https://cncf.io/blog/2024/11/13/scalable-authentication-across-organizations-with-keycloak-26), page not opened). Licence (Apache 2.0) not re-checked in this run **[VAL — confirm at approval]**.

## Decision
1. **Broker per cell.** Each cell runs one Keycloak deployment as an *identity broker*. Each tenant's IdP (OIDC or SAML) is configured in the broker; AMC OS services accept only tokens issued by their cell's broker. Result: one token format, one signing key set per cell, protocol differences handled in one place.
2. **Keycloak as IdP when needed.** For an AMC without its own IdP, the same Keycloak holds that AMC's users and enforces MFA itself (D-8).
3. **Tenant claim from the connection.** The broker writes `tenant_id` into the token from the IdP connection (or Keycloak organisation / realm) the user signed in through. Users and AMC administrators cannot edit it. The gateway sets tenant context from this claim only (ADR-0003 §1).
4. **MFA proof required.** The broker refuses to issue a token unless the upstream IdP reports a multi-factor sign-in (OIDC `acr`/`amr`, SAML authentication context — mapping per provider). Keycloak-held users must enrol MFA.
5. **Roles stay in AMC OS.** The IdP and broker say *who*; AMC OS `identity` grants say *what* (FR-D01-006, -016). Group claims from an IdP may be shown as hints to the Tenant Administrator, never applied automatically.
6. **Leavers.** Use, in order of preference: SCIM provisioning push, back-channel logout, then short access-token life (proposed 5 minutes **[ASSUMPTION — confirm: Information Security Officer of the pilot AMC]**) with a check at refresh. Supported methods are recorded per tenant connection (confirm with each provider).
7. **Non-human identities.** AI assistants (ROLE-26) get tokens by standard OAuth token exchange from the calling user's token, narrowed to their tools (Keycloak's 26.8 delegation feature is preview; if standard exchange is not enough, fallback: the assistant's own service identity (ADR-0008 decision 1) plus the user context passed and checked by the policy engine); service accounts (ROLE-27) use client credentials per tenant and integration.
8. **Tenant layout inside Keycloak** — realm per tenant or organisation per tenant in a shared realm — is settled in the proof of concept (Validation). Dedicated cells use one realm.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| AMC OS validates every AMC IdP's tokens directly (no broker) | One fewer component | Many token formats and key sets inside the API layer; SAML needs a separate path; tenant claim taken from varied IdP formats | Spreads security-critical parsing across services |
| Managed cloud identity service (e.g. the cloud provider's own) as broker | No servers to run | Ties identity to one cloud; dedicated AMC deployments and exit become harder (ADR-0018 portability aim); feature fit for SAML brokering not evaluated | Keycloak already named by D-8 and master prompt §13 |
| A different open-source broker | Possibly lighter | Not named in master prompt §13 or D-8; no evaluation done | Keycloak is the named option |

## Consequences
- Positive: one token type; tenant claim controlled by AMC OS; MFA enforced centrally; works for both deployment models.
- Negative: Keycloak becomes a critical component per cell — it must meet NFR-AVAIL-001 (run highly available in the primary region and be restorable in the disaster-recovery region, ADR-0018); keeping it on the latest release line is an operating duty.
- Follow-up: SEC-001 (Step 25) covers token lifetimes, key rotation and session policy; WP4 adds the tenant-connection table; FR-D01-008 gets its target from the pilot AMC.

## Validation
Proof of concept in the platform-foundation increment: (a) OIDC and SAML upstream IdPs, one each; (b) a token without MFA proof is refused; (c) a user of tenant A cannot obtain a token with tenant B by any attribute change; (d) leaver push revokes sessions; (e) realm-per-tenant vs organisation-per-tenant measured for 50 tenants (design capacity, D-69); (f) token exchange for an assistant token cannot carry approve rights — tested with standard token exchange, and with the fallback of Decision 7 if needed.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-21 | Draft | Claude (build loop) for project owner | Created in GOV-006 Step 10 |
