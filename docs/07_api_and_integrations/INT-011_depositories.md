---
id: INT-011
title: Provider Specification — Depositories NSDL and CDSL (ISINs, demat unit holdings, statements)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-011 — Depositories (NSDL, CDSL)

Outside system X04 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). Covers National Securities Depository Ltd (NSDL) and Central Depository Services (India) Ltd (CDSL). Much of what an AMC exchanges with the depositories goes through the RTA or the custodian (PRD-000 Ch 8: "Through RTA and depository interfaces"); **which route applies, and every interface item, is Confirm with the depository, the RTA and the custodian.** Builds on Draft documents EA-001, EA-003, PRD-002, PRD-007, PRD-013 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | NSDL and CDSL, SEBI-registered depositories | [IND] |
| 2 | Business purpose | (a) ISIN creation for new schemes and plans (Product, WF-001 — a human task); (b) units held in demat form, for reconciliation with RTA units (Investor, Operations); (c) the scheme's own demat securities holdings, usually reported through the custodian (Settlement, INT-008) | [DES] |
| 3 | Approved interface | Confirm with NSDL / CDSL, the RTA and the custodian. No direct depository interface for an AMC is assumed | Confirm |
| 4 | Authentication | Confirm | Confirm |
| 5 | Data contract | Canonical families: **security and issuer reference** (ISIN), **holdings and cash statement** (demat units), **scheme set-up** (ISIN request) (INT-001 §3) | [DES] |
| 6 | Ingestion schedule | Demat unit holdings: daily or monthly as offered (PRD-000 Ch 8 says event / daily / monthly) — Confirm | Confirm |
| 7 | Error handling | ISIN not received by the NFO task's due date → escalation (EA-007 §10.2); demat vs RTA unit break → reconciliation exception | [DES] |
| 8 | Retry logic | Reads: class A1. ISIN request: human task, not automated | [DES] |
| 9 | Idempotency | Holdings: tenant + depository + ISIN + as-of date; ISIN request: task ID | [DES] |
| 10 | Reconciliation | Demat units vs RTA units per plan (PRD-000 Ch 8) via WF-015 | [DES] |
| 11 | Monitoring | Holdings file late; unit breaks; ISIN tasks overdue | [DES] |
| 12 | Commercial dependency | Depository onboarding of the AMC as issuer (PRD-000 Ch 8) — Confirm | [VAL] |
| 13 | Certification requirements | Confirm with NSDL / CDSL | Confirm |
| 14 | Operational ownership | ISINs: DEP-13 Products; unit reconciliation: DEP-08 Investor services with DEP-06; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions

None automated. The ISIN request is a person's task (EA-007 §10.2 step 5).

## 3. Confirm with NSDL / CDSL (and the RTA, custodian)

1. Whether the AMC receives demat unit holdings directly or through the RTA.
2. ISIN application process and the AMC's role.
3. Any data an AMC may receive about consolidated account statements.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 NSDL / CDSL row | Purpose, routes |
| S2 | [EA-007](../04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md) §10.2 | NFO set-up tasks |
