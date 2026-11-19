---
id: SEC-100
title: AI Security and Permission Model — Proposal
status: Draft
version: 0.1
owner: CISO
approver: Project owner (interim ARB)
work_package: WP6 (proposal; final owner GOV-006 Step 25, SEC-001)
last_updated: 2026-11-20
---

# SEC-100 — AI Security and Permission Model (Proposal)

> **PROPOSAL** — part of the [EA-100](../04_enterprise_architecture/EA-100_ai_orchestration_architecture_proposal.md) set. Decision records: ADR-0012 (policy engine and R0–R3), ADR-0008 (AI boundary).

## 1. Four authorisation dimensions

Every agent tool call is allowed only if **all four** allow it:

| Dimension | Question | Source |
| --- | --- | --- |
| User | May this human do or see this? | Roles + attributes (RBAC + ABAC): scheme, desk, region, data class, maker/checker role |
| Agent | Is this agent version allowed this tool and data class? | Agent registry (AIML-101) |
| Tenant | Has this tenant enabled this module, agent and tool, and is AMC OS SoR for any object written? | Tenant config + SoR registry (EA-101) |
| Tool | Does the tool's own policy (risk class, rate limit, approval rule) allow this call now? | Tool registry (AIML-102) |

Effective permission = **user ∩ agent ∩ tenant ∩ tool**. Delegation to a sub-agent never adds permissions.

A central policy engine (ADR-0012, ADR-0015) evaluates versioned policies; policy bundles are signed and distributed from the control plane (EA-103 CPR-2). The engine **fails closed**: if it is unavailable, every agent tool call is denied, including R0 (EA-105 FH-12).

## 2. Risk classes

| Class | Meaning | Who may do it | Controls |
| --- | --- | --- | --- |
| **R0** | Public information | Any authenticated user/agent | Logging |
| **R1** | Authorised read of tenant data | Users and agents with permission | Four-dimension check; masking; audit |
| **R2** | Controlled write: drafts and proposals inside AMC OS where AMC OS is SoR | Agents may create; a human must act on them | Policy check; idempotency; human queue; audit |
| **R3** | Critical financial or control action | **Humans only** with their own identity | Explicit human authorisation; maker ≠ checker; deterministic validation before effect; step-up MFA **[DES]**; audit |

R3 examples: submit/approve/release orders; post journals; approve or publish NAV; approve payments; change compliance rules or limits; change SoR modes, roles or agent enablement; close breaches; send regulatory filings.

## 3. Mandatory AI restrictions (enforced, not just written)

AI agents must never:

1. Approve their own actions, or any action.
2. Approve trades or execute unauthorised transactions.
3. Publish NAV.
4. Modify accounting records.
5. Override compliance results.
6. Change compliance rules, limits or permissions.
7. Rewrite or delete history (audit, ledgers, approvals).
8. Bypass maker-checker.

Enforcement layers: (a) no such tools exist (AIML-102 §3); (b) agent service identities lack the permissions; (c) in the database today, a trigger blocks AI service identities from recording approvals — this is the **only** restriction already tested (DBT-000 T5b); the other seven are **not yet tested**; (d) red-team and forbidden-action tests (§8) must cover all eight before any agent is enabled.

## 4. Tenant isolation for AI

- Tenant ID comes from the user token, never from the prompt or model output.
- Retrieval, vector search, caches, conversation memory and tool calls are all tenant-filtered by the platform (RLS + namespace), then re-checked on every retrieved item (EA-105 FH-14).
- No cross-tenant learning: no tenant data in prompts for another tenant, no shared fine-tuning **[DES]**.

## 5. Prompt-injection protection

| Threat | Control |
| --- | --- |
| Instructions hidden in documents, emails, web pages, vendor tool descriptions | Retrieved content is passed as *data*, marked as untrusted; it cannot change the tool allow-list or permissions |
| Model asked to call a dangerous tool | Dangerous tools do not exist; policy engine decides, not the model |
| Data exfiltration via tool arguments (e.g. URL with data) | Egress allow-lists; outbound tools take structured fields only; no free-form URLs |
| Vendor MCP tool description changes | Pinned at review; change → re-review (INT-100 §2) |
| Jailbreak to reveal other users' data | Four-dimension check on every call regardless of conversation |

## 6. Data protection

- **Classification:** Public, Internal, Confidential, Restricted (investor PII, KYC, bank details = Restricted).
- **Masking:** Restricted fields masked in prompts and logs unless the user has unmask permission and the task needs it.
- **Model provider egress:** only through the AI gateway; data class checked against the provider's approval; redaction applied; provider contract must forbid training on tenant data and set retention **[VAL]**.
- **Secrets:** in a secrets manager per cell; never in prompts, logs, code or repository; agents never see credentials.
- **Short-lived credentials:** per-call tokens for tools; lifetime in minutes, not days **[DES]**.
- **Allow-lists:** for tools per agent, for network egress per adapter, for external MCP servers.

## 7. Revocation

Disabling a user, role, agent, tool or tenant takes effect on the next call (tokens are per call; policy cache short). Running agent sessions are stopped. Kill switches: EA-105 §4. **Exception to maker-checker:** an emergency *disable* is an R3 human action that one authorised person may do alone, because it can only reduce what AI can do; *re-enabling* needs maker-checker.

## 8. Tests required before any agent is enabled

Prompt-injection suite; cross-tenant leakage suite; forbidden-action suite (every item in §3 attempted, all must be denied and alerted); masking tests; policy fail-closed test.
