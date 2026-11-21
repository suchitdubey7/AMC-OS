---
id: INT-008
title: Provider Specification — Custodians (settlement, holdings, cash, corporate actions, custodian books and NAV)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-008 — Custodians

Outside system X05 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). One specification for every custodian; each custodian an AMC uses gets its own adapter and its own "Confirm with" answers. **Which custodian the pilot AMC uses is not known (owner question Q76); every interface item is Confirm with <custodian>.** Builds on Draft documents EA-001, EA-003, EA-007 §10.3, PRD-007, PRD-010, PRD-011, PRD-012 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | The SEBI-registered custodian appointed for the AMC's schemes | [IND] |
| 2 | Business purpose | **Out:** settlement instructions and cancellations (Settlement, WF-018, WF-027). **In:** instruction acknowledgement and status (matched, settled, failed and reason), holdings and cash statements (Settlement load; reconciliation WF-015), corporate-action notices and entitlements (Operations, WF-009), clearing obligations where the custodian passes them on (WF-026). **Outsourced fund accounting (D-16, D-40, D-44):** custodian ledger, trial balance, accruals, unit capital and NAV, loaded and checked (Accounting, NAV) | [DES] |
| 3 | Approved interface | Confirm with <custodian>. PRD-000 Ch 8 lists the options to ask about: SWIFT ISO 15022 or ISO 20022 messages, or the custodian's own API or SFTP files **[ASSUMPTION — options only]**. Whether release 1 supports SWIFT at all is owner question Q78; default: the custodian's own file or API channel | Confirm |
| 4 | Authentication | Per channel — SWIFT PKI, mutual TLS or SFTP keys per PRD-000 Ch 8 — Confirm with <custodian>; per tenant | Confirm |
| 5 | Data contract | Canonical families: **settlement instruction and status**, **holdings and cash statement**, **corporate-action announcement and entitlement**, **clearing obligation**, **custodian books and NAV** (INT-001 §3) | [DES] |
| 6 | Ingestion schedule | Status: intraday as the custodian sends; statements: end of day; corporate actions: daily; custodian books and NAV: per the custodian's NAV timetable (D-44) — Confirm with <custodian> | Confirm |
| 7 | Error handling | Status for an unknown instruction → Settlement exception queue; failed settlement → `SETTLEMENT_FAILED`, WF-027; statement control-total mismatch → quarantine; custodian NAV outside the tenant's tolerance (D-46) → NAV exception, never auto-accepted (D-44 requires acceptance after checks) | [DES] |
| 8 | Retry logic | Instructions and cancellations: class A2, never retried automatically (§2). Status queries and statement fetches: class A1 | [DES] |
| 9 | Idempotency | Instruction: EA-007 key + client reference (the AMC OS instruction reference sent to the custodian); status: tenant + custodian reference + status time; statement: tenant + account + statement date + statement number where sent | [DES] |
| 10 | Reconciliation | Daily holdings and cash vs AMC OS books (WF-015, FE-07); instruction status vs trades (every instruction ends settled, failed or cancelled); custodian NAV and key items (accruals, unit capital) vs AMC OS checks (D-40) | [DES] |
| 11 | Monitoring | Instructions without ack in the time limit (unknown outcome); unsettled past settlement date; statements late; holdings breaks; custodian NAV late | [DES] |
| 12 | Commercial dependency | AMC's custody agreement; SWIFT membership or a service bureau if SWIFT is used (Q78) | [VAL] |
| 13 | Certification requirements | Custodian onboarding and test cycle (PRD-000 Ch 8); parallel run of at least one month (INT-001 §11 C6) | [DES] / Confirm |
| 14 | Operational ownership | DEP-06 Fund operations and settlement; custodian books and NAV: DEP-07 Fund accounting and NAV; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2)

| Instruction | Owning module | Approval before send | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- | --- |
| Settlement instruction | Settlement | Second approver, every instruction (D-31) | Confirm with <custodian> | Confirm with <custodian> whether a status request is supported on the chosen channel | Operations Analyst checks the custodian's portal or desk; resend only by a person with the same key |
| Cancellation of an instruction | Settlement | Maker-checker (PRD-007) | Confirm | Confirm | As above |
| Re-instruction after a fail (EA-007 §10.3 step 4a) | Settlement | As settlement instruction | Confirm | Confirm | As above |

## 3. Confirm with <custodian>

1. Channel (SWIFT, API or files) and message or file versions.
2. Acknowledgement and status messages, and whether status can be queried for one instruction.
3. Statement timing and control totals.
4. For outsourced accounting: which books, trial balance and NAV items are delivered, when, and in what layout.
5. Whether clearing obligations come from the custodian or the clearing corporation.
6. Test environment and certification steps.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 Custodians row | Data exchanged, channel options |
| S2 | [PRD-007](../03_product_requirements/PRD-007_settlement_management.md); [PRD-010](../03_product_requirements/PRD-010_fund_accounting.md); [PRD-011](../03_product_requirements/PRD-011_valuation_and_nav.md) | Settlement, mirror accounting, custodian NAV |
| S3 | [EA-007](../04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md) §9.3, §10.3 | Unknown outcome, failed settlement |
| S4 | [LOOP_STATE.md](../../LOOP_STATE.md) D-16, D-31, D-40, D-44, D-46 | Decisions applied |
