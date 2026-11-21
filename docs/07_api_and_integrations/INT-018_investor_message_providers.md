---
id: INT-018
title: Provider Specification — Investor-message providers (email, SMS and similar; the AMC's own provider or the RTA)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-018 — Investor-message providers

Outside system X16 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). AMC OS prepares investor messages, checks consent and tracks delivery; the RTA or the AMC's own provider sends them (D-55). **Whether the AMC's provider connects to AMC OS at all varies per AMC (EA-001 G2); every interface item is Confirm with the provider.** Builds on Draft documents EA-001, EA-003 §3.18, PRD-013 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | The AMC's email or SMS provider, or the RTA acting as sender (INT-006/007) | [DES] |
| 2 | Business purpose | **Out:** message requests (template, recipient reference, consent check result). **In:** delivery status (Investor, D13) | [DES] |
| 3 | Approved interface | Confirm with the provider (or the RTA) | Confirm |
| 4 | Authentication | Per provider — Confirm; per tenant | Confirm |
| 5 | Data contract | Canonical family: **investor message request and delivery status** (INT-001 §3). Personal data limited to what the message needs; classified (PRD-016) | [DES] |
| 6 | Ingestion schedule | Status as the provider sends | Confirm |
| 7 | Error handling | Bounced or failed → recorded on the investor record; repeated failures → `INVESTOR_DATA_FLAGGED` for correction through the RTA (D-53) | [DES] |
| 8 | Retry logic | Not a financial instruction (not class A2). A message request is sent once with an idempotency key; a resend is a new request decided by the module's rules, so the investor never gets duplicates from a technical retry | [DES] |
| 9 | Idempotency | Tenant + message ID | [DES] |
| 10 | Reconciliation | Messages requested vs delivery statuses received | [DES] |
| 11 | Monitoring | Requests without status; failure rate by template | [DES] |
| 12 | Commercial dependency | The AMC's provider contract. Commercial SMS in India is subject to TRAI rules on sender and template registration (proposal INT-100 §6 note) **[VAL — Compliance to confirm]** | [VAL] |
| 13 | Certification requirements | Template and sender registration with the provider where required **[VAL]** | [VAL] |
| 14 | Operational ownership | DEP-08 Investor services; consent policy: DEP-09 Compliance with the DPO (D-54); connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions

None of class A2. Message requests follow field 8.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-013](../03_product_requirements/PRD-013_investor_management.md) | Messages, consent |
| S2 | [EA-001](../04_enterprise_architecture/EA-001_system_context.md) X16, G2 | Context |
| S3 | [LOOP_STATE.md](../../LOOP_STATE.md) D-53, D-54, D-55 | Decisions |
