---
id: INT-010
title: Provider Specification — Banks (statements, payment status, payment files where the AMC chooses)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-010 — Banks

Outside system X06 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). One specification for every bank where the schemes or the AMC hold accounts. **Every interface item is Confirm with <bank>.** Owner decisions narrow what AMC OS sends: investor payouts are sent by the RTA (D-52) and scheme expenses are paid outside AMC OS (D-51), so the only payment files AMC OS may send are those the AMC chooses to route through it (for example distributor commission, EA-007 §10.5; EA-001 gap G2). Builds on Draft documents EA-001, EA-003, PRD-007, PRD-012, PRD-014, PRD-015 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | Each bank holding scheme collection, payout or operating accounts, or the AMC's own accounts | [IND] |
| 2 | Business purpose | **In:** account statements (intraday and end of day), payment status (Settlement for scheme cash; Operations reconciliation WF-015; Finance for AMC accounts). **Out (only where the AMC chooses):** settlement payment instructions for scheme funding (Settlement, WF-026, FR-D07-010) and payment files such as distributor commission (Distribution, WF-013) — never investor payouts (D-52) or scheme expenses (D-51) | [DES] |
| 3 | Approved interface | Confirm with <bank>. PRD-000 Ch 8 lists the options to ask about: host-to-host SFTP or bank API; statements as SWIFT MT940 or ISO 20022 camt.053 **[ASSUMPTION — options only]**; SWIFT in release 1 is owner question Q78 | Confirm |
| 4 | Authentication | Digital signatures and dual authorisation on payment files (PRD-000 Ch 8); channel credentials — Confirm with <bank>; per tenant | Confirm |
| 5 | Data contract | Canonical families: **holdings and cash statement** (cash part), **payment file and payment status** (INT-001 §3) | [DES] |
| 6 | Ingestion schedule | Intraday and end-of-day statements — Confirm with <bank>; payment status as the bank sends | Confirm |
| 7 | Error handling | Statement balance does not roll forward from the previous one → quarantine; payment rejected → task to Finance or Distribution with the bank's reason; unmatched credits → reconciliation exception | [DES] |
| 8 | Retry logic | Payment files: class A2 (§2). Statement and status fetches: class A1 | [DES] |
| 9 | Idempotency | Payment file: EA-007 key + file reference sent to the bank; each payment line: tenant + payment ID; statement: tenant + account + statement date + sequence | [DES] |
| 10 | Reconciliation | Bank vs ledger cash (WF-015, FE-07); payment status vs payment records; RTA payout files vs bank debits (D-52 tracking) | [DES] |
| 11 | Monitoring | Statements late; payment file without ack; rejected payments; unreconciled cash by age | [DES] |
| 12 | Commercial dependency | Banking agreements per account; host-to-host set-up by the bank | [VAL] |
| 13 | Certification requirements | Bank integration testing and payment-file certification (PRD-000 Ch 8) — Confirm with <bank> | Confirm |
| 14 | Operational ownership | Scheme accounts: DEP-06 Fund operations and settlement; commission payments: DEP-12 with DEP-14 Finance; AMC accounts: DEP-14 Finance; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2)

| Instruction | Owning module | Approval before send | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- | --- |
| Settlement payment instruction for scheme funding (pay-in, WF-026), where the AMC routes it through AMC OS | Settlement | Funding check passed (FR-D07-009, BRL-D07-005); release by the bank-mandate signatories, maker-checker (FR-D07-010; BA-004 WF-026 — number of authorisers is the AMC's bank mandate **[ASSUMPTION]**) | Confirm with <bank> | Confirm with <bank> | Operations Analyst checks the bank portal or desk; payment not confirmed → WF-027 if it causes a fail; resend only by a person with the same key |
| Commission payment file (where the AMC routes it through AMC OS) | Distribution | Finance approval (D-56); release by two bank-mandate signatories (EA-007 §10.5 step 6) | Confirm with <bank> | Confirm with <bank> | Finance checks the bank portal; resend only by a person with the same key |

## 3. Confirm with <bank>

1. Statement channel, format and times.
2. Payment-file format, signing and acknowledgement; whether payment status can be queried.
3. Certification steps.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 Banks row | Options, auth |
| S4 | [PRD-007](../03_product_requirements/PRD-007_settlement_management.md) FR-D07-009, FR-D07-010, BRL-D07-005; [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-026 | Settlement payments and their approval |
| S2 | [EA-007](../04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md) §10.5 | Commission payment release |
| S3 | [LOOP_STATE.md](../../LOOP_STATE.md) D-51, D-52, D-56 | What AMC OS does and does not pay |
