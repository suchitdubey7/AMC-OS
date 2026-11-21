---
id: INT-017
title: Provider Specification — AMC corporate ERP (management figures and cost data)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-017 — AMC corporate ERP

Outside system X15 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). The ERP keeps the AMC company's statutory books; AMC OS does management reporting, budgets and plans (D-58) and records scheme expenses paid outside (D-51). **Which ERP the AMC uses and what it can export or import is Confirm with the AMC's ERP provider.** Builds on Draft documents EA-001, EA-003 §3.20, PRD-015 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | The AMC's corporate ERP | [DES] |
| 2 | Business purpose | **In:** actual costs and company general-ledger balances for management reporting, cost allocation and expense checks (Finance, D15; WF-040). **Out:** management figures, revenue (FE-08) and allocations for the ERP where the AMC wants them (PRD-015) | [DES] |
| 3 | Approved interface | Confirm with the AMC's ERP provider. Default for release 1: file export and import **[DES]** | Confirm |
| 4 | Authentication | Per ERP — Confirm; per tenant | Confirm |
| 5 | Data contract | Canonical family: **management figures** (account, cost centre, period, amount as decimal, currency) (INT-001 §3); the account mapping between ERP and AMC OS is a tenant setting maintained by Finance | [DES] |
| 6 | Ingestion schedule | Monthly at management close (WF-040), optionally weekly — tenant setting | [DES] |
| 7 | Error handling | Unmapped account → quarantine the line, task to Finance; period already closed in AMC OS → load refused, restatement path (PRD-015) | [DES] |
| 8 | Retry logic | Class A1. Journal files to the ERP are not class A2 (they do not move money); they are released by Finance and acknowledged by the ERP team | [DES] |
| 9 | Idempotency | Tenant + ERP + period + file checksum; line: tenant + ERP document number | [DES] |
| 10 | Reconciliation | ERP trial-balance totals vs loaded totals per period; revenue in AMC OS vs ERP revenue accounts | [DES] |
| 11 | Monitoring | Monthly file late against the close calendar; unmapped accounts | [DES] |
| 12 | Commercial dependency | The AMC's ERP licence | [IND] |
| 13 | Certification requirements | None; parallel run of the first close | [DES] |
| 14 | Operational ownership | DEP-14 Finance; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions

None of class A2 (no money or securities move).

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-015](../03_product_requirements/PRD-015_finance_and_management_reporting.md) | Purpose |
| S2 | [EA-001](../04_enterprise_architecture/EA-001_system_context.md) X15; [LOOP_STATE.md](../../LOOP_STATE.md) D-51, D-58 | Context and decisions |
