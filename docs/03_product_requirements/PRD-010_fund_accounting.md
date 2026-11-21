---
id: PRD-010
title: Fund Accounting (D10) — Product Requirements
status: Draft
version: 0.2
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 9
last_updated: 2026-11-21
---

# PRD-010 — Fund Accounting (D10)

This document states what AMC OS must do to keep a complete, balanced, never-edited set of books for every scheme, so that the NAV, the scheme financial statements and every audit come from the same ledger. It re-keys PRD-000 v0.9 Module 08 to the GOV-001 identifiers (`FR-08-nn` → `FR-D10-nnn`, `BR-08-n` → `BRL-D10-nnn`, Module 08 and Chapter 5 stories → `US-D10-nnn`) and adds requirements for the BA-001 capabilities that had no v0.9 source: receivables (CAP-D10-009) and payables (CAP-D10-010), each with a sub-ledger and ageing. It also states how D10 works under owner decision **D-16**: AMC OS **replaces** fund accounting where the AMC does it in-house, and **mirrors and validates** it where it is outsourced to the custodian (FR-D10-024).

**Builds on Draft documents:** [PRD-000 v0.9](PRD-000_master_prd_v0.9.md) Module 08, Chapter 4 (W8), Chapter 5 (US-ACC-01, US-ACC-02), Chapter 6, Chapter 9; [BA-001](../02_business_architecture/BA-001_business_capability_map.md) D10, §4, §5; [BA-002](../02_business_architecture/BA-002_amc_operating_model.md) §3–§5 (DEP-07, systems stance); [BA-003](../02_business_architecture/BA-003_domain_dictionary.md); [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-007, WF-008, WF-009, WF-018, §5; [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md) §3–§5; [PRD-002](PRD-002_product_and_scheme_management.md) (TER schedule), [PRD-004](PRD-004_portfolio_management.md) (snapshots, cost shown in D04), [PRD-007](PRD-007_settlement_management.md) (settlement events, net settlement) — allowed by owner decision D-3 ([GOV-008](../00_governance/GOV-008_build_loop.md) §2 rule 3). No document used here is Approved. PRD-011 (Valuation and NAV) and PRD-012 (Fund Operations) are written in the same step (Step 9). Owner decisions D-40…D-43 (answers Q34–Q37, 21 Nov 2026) are applied ([LOOP_STATE.md](../../LOOP_STATE.md)).

**What this document is not:** the posting templates, rounding and test values of the accounting engine (FE-02, Step 21); prices and valuation methods (D11, FE-03); NAV calculation, approval and correction (D11, FE-01, PRD-011); corporate-action **event** processing and entitlements (D12 CAP-D12-007, PRD-012) — D10 only books the accounting entries (CAP-D10-008); the reconciliation engine and its break workflow (D12, FE-07 — D10 defines its reconciliation sets); investor-level unit records (D13, mirrored from the RTA); the AMC company's own statutory books, which stay in its corporate ERP (PRD-000 §1, BA-001 D15 boundary). **Rule for engineers (PRD-000):** no rate, cap, day-count, threshold or cut-off is hard-coded; each is a versioned, effective-dated parameter (PRD-001 FR-D01-033). Every official accounting number comes from FE-02, never from AI (master prompt §3.1).

## 1. Scope

| In scope (CAP) | Out of scope |
| --- | --- |
| CAP-D10-001 Chart of accounts · CAP-D10-002 Journal management · CAP-D10-003 Double-entry ledger · CAP-D10-004 General ledger · CAP-D10-005 Accruals · CAP-D10-006 Income recognition · CAP-D10-007 Expense recognition · CAP-D10-008 Corporate actions (accounting entries) · CAP-D10-009 Receivables · CAP-D10-010 Payables · CAP-D10-011 Trial balance · CAP-D10-012 Accounting reconciliation · CAP-D10-013 Period closing | Prices, valuation and NAV (D11); corporate-action events and entitlements (D12); reconciliation engine (D12, FE-07); TER caps (D08 rule registry; D02 holds the scheme's chosen TER); unit allotment (RTA; D13 mirror); AMC company books and management P&L (corporate ERP; D15); payments to banks (D07, D12); AI that creates or approves journals (ADR-0008) |

## 2. Re-keying from PRD-000 Module 08

| PRD-000 v0.9 | Here | Note |
| --- | --- | --- |
| FR-08-01 … FR-08-13 | FR-D10-001 … FR-D10-013 | Same order; capability references added. Wording kept except: FR-D10-001 (regulatory label narrowed, schedule number dropped — §5 note); FR-D10-006 (TER rates from D02, cap checked by D08); FR-D10-008 (boundary with D12 stated); FR-D10-012 (unit capital vs the D13 RTA mirror); FR-D10-013 (runs on FE-07) — all **[DES]** |
| BR-08-1 … BR-08-4 | BRL-D10-001 … BRL-D10-004 | Labels added where PRD-000 had none |
| Module 08 point 7 stories; Ch 5 US-ACC-01, US-ACC-02 | US-D10-001 (Module 08 story 1 **merged** with US-ACC-01), US-D10-002 (story 2 **merged** with US-ACC-02) | Acceptance criteria of US-ACC-01 and US-ACC-02 kept |
| Module 08 point 18 acceptance criteria | AC-US-D10-003-1 (unbalanced batch), AC-US-D10-004-1 (update of a posted line) | On new stories US-D10-003 and US-D10-004 |
| Module 08 point 13 approvals | BRL-D10-006 (manual vs automated), FR-D10-028 (close, reopen) | Reopen approvers: CFO and Head of Fund Accounting (owner decision D-42; C3 closed) |
| Module 08 points 12, 14, 15, 16, 17 | BRL-D10-005, §9, NFR-AUD-010, §12, NFR-PERF-014, NFR-PERF-015 | |
| Ch 4 W8 | BA-004 WF-008 (already re-keyed in Step 4); used in §6 | |
| — | FR-D10-014 … FR-D10-028, BRL-D10-005 … 013, US-D10-005 … 011 | **New** **[DES]** |

## 3. Business requirements

| ID | Business requirement | Capabilities |
| --- | --- | --- |
| BR-D10-001 | Each scheme has one complete double-entry ledger, from which the NAV, the trial balance and the financial statements are all taken | CAP-D10-001 … -004, -011 |
| BR-D10-002 | Every business event that changes a scheme's assets, liabilities, unit capital, income or expenses is booked once, automatically where possible, and can be traced back to its source | CAP-D10-002, -003, -006, -008 |
| BR-D10-003 | Income and expenses are booked for the day they belong to, so each day's NAV is fair to investors entering and leaving | CAP-D10-005, -006, -007 |
| BR-D10-004 | The AMC knows, every day, what each scheme is owed and what it owes, and how old each item is | CAP-D10-009, -010 |
| BR-D10-005 | Books are proven correct (reconciled, reviewed and closed) and are never changed after the fact — only corrected by visible entries | CAP-D10-012, -013 |
| BR-D10-006 | Where the custodian keeps the books, the AMC still sees and independently checks them every day (D-16) | CAP-D10-011, -012 |

## 4. Functional requirements

Every requirement also obeys PRD-000 common rules C1–C8. Labels from PRD-000 are carried unchanged unless the change is stated. Priority: **M** must (release-blocking), **S** should — as PRD-000 Chapter 3.

### 4.1 Re-keyed from PRD-000 Module 08

| ID (was) | Pri | Capability | Requirement |
| --- | --- | --- | --- |
| FR-D10-001 (FR-08-01) **(changed)** | M | CAP-D10-001 (.1) | **Chart of accounts:** standard mutual-fund template (assets: investments by class, receivables, cash and bank, accrued income; liabilities: payables for purchases, redemptions payable, accrued expenses, distribution payable; unit capital, reserves, unrealised appreciation reserve, equalisation; income; expenses), used by each scheme and mapped to the SEBI scheme financial-statement format **[REG — format prescribed by SEBI (§5 note, [S3], [S5], [S6]); VAL schedule and format version under the 2026 Regulations]**. *Changed:* PRD-000 said "Eleventh Schedule-type"; the schedule number is dropped until REG-001 maps the 2026 text |
| FR-D10-002 (FR-08-02) | M | CAP-D10-004 (.1) | **General ledger:** per scheme, per plan where required (plan-level unit capital and expenses), multi-dimensional (scheme, plan, security, counterparty) |
| FR-D10-003 (FR-08-03) | M | CAP-D10-002 (.1), CAP-D10-003 (.1) | **Journal batches and entries:** batch → entries → lines; each line debit or credit, positive amount, account, dimensions; a batch balances to zero per scheme (BRL-D10-001) |
| FR-D10-004 (FR-08-04) | M | CAP-D10-013 (.1), (.2), (.3) | **Accounting periods:** daily (NAV day), monthly, half-yearly, yearly; states `OPEN → SOFT_CLOSED → CLOSED → (REOPENED)` |
| FR-D10-005 (FR-08-05) | M | CAP-D10-003 (.3) | **Trade accounting:** trade-date accounting for investments; cost including charges per policy; realised gain or loss on sale (average cost or as per policy). Whether charges are capitalised or expensed follows the scheme accounting policy **[VAL]** (DA-000 §7.2) |
| FR-D10-006 (FR-08-06) **(changed)** | M | CAP-D10-007 (.1), CAP-D10-005 (.1) | **Expense accrual:** daily accrual of TER components (management fee, other expenses, GST) by plan; brokerage and transaction-cost rules **[REG — 2026 expense framework ([S3]); VAL]**. *Changed:* rates come only from the effective-dated TER schedule in D02 (CAP-D02-006, PRD-002 US-D02-007); the cap is a D08 rule (PRD-002 BRL-D02-005), not logic in D10; PRD-000 "capped by rule engine" is kept as: an accrual that would exceed the cap raises a D08 check result and an exception, it is not silently trimmed |
| FR-D10-007 (FR-08-07) | M | CAP-D10-006 (.1), (.2), CAP-D10-005 (.1) | **Income accrual:** coupon accrual by day count; dividend income on ex-date; discount amortisation for money-market instruments; interest on deposits and TREPS. Day-count conventions per instrument are versioned parameters **[VAL]** (FE-02) |
| FR-D10-008 (FR-08-08) **(changed)** | M | CAP-D10-008 (.1) | **Corporate-action accounting:** entries for bonus, split, rights, merger, demerger, buyback, redemption, call / put. *Changed:* D10 books only from an approved entitlement event from D12 (CAP-D12-007, WF-009); it never builds the golden record or computes entitlements (BA-001 §4) |
| FR-D10-009 (FR-08-09) | M | CAP-D10-003 (.4) | **Valuation adjustments:** daily mark-to-market into unrealised appreciation / depreciation accounts, from approved valuations (D11, FE-03) |
| FR-D10-010 (FR-08-10) | M | CAP-D10-002 (.3) | **Reversal entries:** corrections by reversal plus a new entry only; the reversal links to the original; reason code |
| FR-D10-011 (FR-08-11) | M | CAP-D10-011 (.1) | **Trial balance:** any scheme, any date, any plan; must balance |
| FR-D10-012 (FR-08-12) **(changed)** | M | CAP-D10-003 (.5) | **Capital-stock accounting:** subscriptions, redemptions and switches at the applicable NAV; equalisation; IDCW distribution. *Changed:* units come from the RTA through the D13 mirror (owner decision Q2); D10 books them and does not allot units |
| FR-D10-013 (FR-08-13) **(changed)** | M | CAP-D10-012 (.1), (.2) | **Accounting reconciliation:** ledger vs portfolio holdings, cash vs bank, unit capital vs RTA units (D13 mirror), receivables and payables vs settlement. *Changed:* runs on the D12 engine (FE-07); D10 owns these reconciliation sets and works their breaks (BA-001 §4) |

### 4.2 New requirements **[DES]**

| ID | Pri | Capability | Requirement |
| --- | --- | --- | --- |
| FR-D10-014 | M | CAP-D10-009 (.1) | **Receivables sub-ledger:** one open item per amount owed to the scheme — sale proceeds, coupon and interest due, dividends receivable, corporate-action cash due, subscription money due, other — each with counterparty, due date, source event, scheme and plan. The receivables control accounts in the ledger equal the sum of open items at every daily close (BRL-D10-009) |
| FR-D10-015 | M | CAP-D10-009 (.2) | **Receivables ageing:** open items grouped by days past due date into buckets set by tenant configuration; an overdue item opens an exception in the D12 queue (CAP-D12-008) with an owner from DEP-07. Age bands and escalation times are tenant settings; AMC OS ships no values **[DES]** (owner decision D-43). A write-off is a maker-checker manual journal (FR-D10-019) (D-43) |
| FR-D10-016 | M | CAP-D10-010 (.1) | **Payables sub-ledger:** one open item per amount the scheme owes — payables for purchases, redemptions payable (from the D13 mirror), IDCW payable, accrued expenses payable (for example management fee, trustee, custodian, registrar, audit fees), taxes, other — with the same fields and control-account rule as FR-D10-014 |
| FR-D10-017 | M | CAP-D10-010 (.2) | **Payables ageing:** as FR-D10-015. Redemption and IDCW payables also show the time left to the payout deadline; the deadline is a regulatory parameter **[VAL]** and a late item is reported to D13 and D08, not decided by D10 |
| FR-D10-018 | M | CAP-D10-002 (.2) | **Posting rules:** each event type maps to a debit / credit template; templates are versioned, effective-dated configuration changed through WF-021 with maker-checker and must pass their test cases before activation (BRL-D10-004); each posted line records the rule version |
| FR-D10-019 | M | CAP-D10-002 (.1) | **Manual journals:** for items no rule covers; reason, attachment and maker-checker always (BRL-D10-006). The Senior Fund Accountant approves (maker ≠ checker); above an amount set by each tenant (no value shipped **[DES]**) the Head of Fund Accounting also approves (owner decision D-41) |
| FR-D10-020 | M | CAP-D10-004 (.1), CAP-D10-005, CAP-D10-007 | **Plan-level books:** plan-specific items (for example TER of a Direct or Regular plan) post to that plan; items common to the scheme are shared between plans by a method recorded with each run **[IND]**; the method itself is **[VAL]** (FE-02) |
| FR-D10-021 | M | CAP-D10-005 (.1), (.2) | **Daily accrual run:** for each scheme and business date, before the NAV run (WF-007); idempotent (a rerun for the same date and inputs posts nothing new); stores rate versions (D02), the asset base used and the engine version; an accrual is reversed or settled when the cash is paid or received; differences are trued up by a new batch, never by editing (DA-000 §7) |
| FR-D10-022 | M | CAP-D10-001 (.2) | **Account changes:** new, renamed or remapped accounts take effect from a date, through maker-checker; an account that has postings is never deleted, only closed to new postings; the mapping to financial-statement lines is versioned |
| FR-D10-023 | S | CAP-D10-013 (.2), CAP-D10-011 | **Financial-statement data:** at each closed month, half-year and year, produce scheme-level data in the SEBI / Ind AS format version in force **[REG — Ind AS for schemes [S5], [S6]; VAL format version]**, for the auditors and the AMC's reporting tool; AMC OS does not sign or file statements |
| FR-D10-024 | M | CAP-D10-011 (.1), CAP-D10-012 (.2) | **Outsourced fund accounting (D-16):** a setting per scheme says whether D10 is the **book of record** (in-house) or **mirror and validate** (custodian keeps the books). In mirror mode AMC OS loads the custodian's trial balance and ledger daily, recomputes the items it can check independently (at least accruals and capital stock), and reconciles both through FE-07; differences are breaks. Mirror figures are labelled as the custodian's and never posted as the AMC's own books (BRL-D10-011). Owner decision D-40: AMC OS loads the custodian's books daily and rechecks key items (accruals, unit capital, NAV); it keeps no full shadow ledger; file formats: "Confirm with <custodian>" (INT-001, Step 14) |
| FR-D10-025 | M | CAP-D10-011, CAP-D10-013 (.1) | **Events to other domains:** the day's ledger, once complete for NAV (trial balance balanced, accruals and trades for the day posted — not the soft close, which follows NAV publication in WF-008), goes to D11 (PRD-000 §2.5 dependency 6, `accounting.day.closed`; the event name and its exact meaning are settled in EA-007, Step 13); accrual results to D11 and D15; book cost to D04. D10 never writes another domain's tables (AGENTS.md §2.3); event names become `<NAME>.v<n>` in EA-007 (Step 13) |
| FR-D10-026 | M | CAP-D10-002, CAP-D10-011 | **Drill-down:** trial balance line → ledger → journal → source event → source document, within one scheme and tenant (US-D10-002) |
| FR-D10-027 | M | CAP-D10-013 (.2) | **Monthly close checklist:** all days soft-closed; accrual true-ups posted; bank, custodian and RTA-unit reconciliations complete or breaks waived by the approver; suspense accounts cleared (BRL-D10-007); sub-ledgers equal control accounts; trial balance reviewed with variance comments (WF-008) |
| FR-D10-028 | M | CAP-D10-013 (.3) | **Period lock and reopen:** a CLOSED period takes no posting (BRL-D10-002); reopen needs a reason and approval by both the CFO and the Head of Fund Accounting (§7, owner decision D-42); every posting during a reopen is tagged with the reopen ID; re-close follows FR-D10-027 |

## 5. Business rules

| ID (was) | Rule | Label |
| --- | --- | --- |
| BRL-D10-001 (BR-08-1) | Every batch balances (sum of debits = sum of credits) per scheme and currency; enforced by a deferred database constraint trigger | **[DES]** (PRD-000 unlabelled); built in DDL-000 |
| BRL-D10-002 (BR-08-2) | No posting into a CLOSED period; corrections post into the current open period with a back-dated effective date only through the NAV-correction workflow (WF-017) | **[DES]** |
| BRL-D10-003 (BR-08-3) | Journals are immutable once posted | **[DES]**; built in DDL-000 |
| BRL-D10-004 (BR-08-4) | Posting rules (event type → debit / credit template) are versioned configuration with maker-checker | **[DES]** |
| BRL-D10-005 | Only the posting engine (FE-02) inserts journal lines; no update or delete of posted lines by anyone (PRD-000 Module 08 point 12) | **[DES]** |
| BRL-D10-006 | A rule-generated, balanced batch is approved automatically; a manual journal always needs maker-checker, maker ≠ checker (PRD-000 Module 08 point 13; SOD-01) | **[DES]** |
| BRL-D10-007 | An event with no posting rule goes to a suspense account with an alert, never silently (point 14); suspense must be cleared before the monthly close | **[DES]** |
| BRL-D10-008 | Accruals are computed and posted once, in D10; the NAV includes them and never recomputes them (BA-001 §4) | **[DES]** |
| BRL-D10-009 | At each daily close, each receivable and payable control account equals the sum of its open sub-ledger items; a difference is a reconciliation break (FR-D10-013) | **[DES]** |
| BRL-D10-010 | Fee and expense rates come only from D02 effective-dated configuration; caps live in D08 rules; D10 holds no rate or cap | **[DES]** |
| BRL-D10-011 | In mirror mode the custodian's books are the books of record; AMC OS figures are validation figures and are labelled so | **[DES]** (D-16); contract detail **[ASSUMPTION]** (BA-004 WF-008 variant) |
| BRL-D10-012 | Net settlement of funds does not change scheme-wise accounting: D10 keeps gross scheme-level records (PRD-007 FR-D07-005 (f)) | **[REG]** via PRD-007 source S3 |
| BRL-D10-013 | AI never creates, approves or posts a journal (PRD-000 Module 08 point 16; SOD-10) | **[DES]** |

**Regulatory note (books, formats, Ind AS, expenses).** The SEBI (Mutual Funds) Regulations, 2026 were notified on 14 Jan 2026 and apply from 1 Apr 2026 [S1], [S2] **[REG]**. Under the 1996 Regulations they replace, Regulation 50 required proper books of account, the Eighth Schedule held the investment valuation norms, the Ninth Schedule the accounting policies and standards, and the Eleventh and Twelfth Schedules the annual report and half-yearly results formats [S4] **[REG — titles only]**. In the 2026 Regulations the annual report follows the Ninth Schedule (Regulation 70(1)), and the expense framework is restructured into a base expense ratio with brokerage, transaction costs and levies charged separately (Regulation 67) [S3] **[REG — secondary source]**. SEBI required scheme financial statements under Ind AS from 1 Apr 2023, with prescribed formats [S5], [S6] **[REG — secondary sources]**. AMFI explains that expenses are charged as a percentage of daily net assets and the daily NAV is disclosed after deducting them [S7] **[IND]**. Which schedule now holds the accounting policies, how the Ind AS formats carry into the 2026 Regulations, and the treatment of unrealised gains, equalisation and distributable surplus are **[VAL]** (REG-001, Step 25). No numeric rate or threshold from these sources is used here.

## 6. Workflows

### 6.1 Existing workflows that touch D10

| Workflow | D10 role | Requirements |
| --- | --- | --- |
| [WF-008](../02_business_architecture/BA-004_end_to_end_workflows.md) Accounting closure (owner workflow, DEP-07) | Daily soft close after NAV publication; monthly checklist, Head FA approval, reopen; mirror-mode variant (D-16) | FR-D10-004, -024, -027, -028 |
| WF-007 Daily NAV | Accrual run and trial balance are NAV inputs; TB balanced is a validation gate | FR-D10-011, -021, -025 |
| WF-009 Corporate actions | D12 processes the event; D10 books ex-date and pay-date entries | FR-D10-008, -014 |
| WF-001 Scheme launch (NFO) | Opening unit capital; chart of accounts set up for the new scheme | FR-D10-001, -012 |
| WF-010 Investor purchase; WF-011 Investor redemption | Capital stock from the D13 mirror; redemption payable | FR-D10-012, -016, -017 |
| WF-015 Reconciliation | D10 reconciliation sets run on FE-07; breaks worked by DEP-07 | FR-D10-013, BRL-D10-009 |
| WF-017 NAV correction | Reversal and new entries for the corrected dates (BRL-D10-002) | FR-D10-010 |
| WF-018 Trade settlement; WF-025 Trade confirmation; WF-027 Failed settlement | Trade-date entries; settlement moves payable / receivable to cash; fails keep the item open and ageing | FR-D10-005, -014 … -017 |
| WF-021 Configuration change | Posting rules, account changes, ageing buckets, mirror / book-of-record mode | FR-D10-015, -018, -022, -024 |

No new workflow card is added. Manual journals use the generic maker-checker of CAP-D12-011; if a separate card is wanted it needs a WF number (C7).

## 7. Permissions by capability

From BA-005 §3 (D10 column) and §4, narrowed to each capability (BA-005 §7 C2). Checker ≠ maker (SOD-01). The Fund Accountant holds "R C S (A senior)" in D10; the Senior Fund Accountant and Head of Fund Accounting are approval authorities held with ROLE-11 (BA-005 §4). CEO, CIO, Compliance Officer, Risk Manager, Operations Analyst and Fund Manager (own schemes) read; the CFO has "R A(period)", the COO "R A(reopen with CFO)", the Auditor "R E". Research Analyst, Dealer, Product Manager, Distributor Manager, RM and Investor Service Executive have no D10 right (BA-005 §3: —).

| Capability | Maker | Checker(s) |
| --- | --- | --- |
| CAP-D10-002 (.2) posting rules; CAP-D10-001 account changes | Fund Accountant | Senior Fund Accountant, through WF-021 (SOD-12)† |
| CAP-D10-002 (.1) manual journals; (.3) reversals | Fund Accountant | Senior Fund Accountant (BRL-D10-006); above a tenant-set amount also the Head of Fund Accounting (D-41) |
| CAP-D10-003, -005 … -008 rule-generated postings | System (FE-02) | — (auto-approved if rule-generated and balanced) |
| CAP-D10-009, -010 sub-ledger items and ageing | System; Fund Accountant comments and assigns | — (write-off or provision is a maker-checker manual journal, D-43) |
| CAP-D10-011 trial balance; CAP-D10-012 reconciliation sets | System; Fund Accountant works breaks | Force-match by the D12 rule (Operations Manager, SOD-01) |
| CAP-D10-013 daily soft close | System after NAV publication | — |
| CAP-D10-013 monthly close | Fund Accountant | Head of Fund Accounting (`accounting.period.close`) |
| CAP-D10-013 reopen | Fund Accountant | CFO **and** Head of Fund Accounting (BA-005 §4; owner decision D-42). The COO "A(reopen with CFO)" in BA-005 §3 is not used; BA-005 §3 to be aligned at its next revision |

**Rights added beyond BA-005 (†):** BA-005 §4 has no row for posting-rule approval; this PRD names the Senior Fund Accountant as checker **[DES]** (open point C5).

## 8. User stories and acceptance criteria

Priority: **C** critical (release-blocking), **O** optional — as PRD-000 Chapter 5.

| ID | Story | Pri | Acceptance criteria (Given / When / Then) |
| --- | --- | --- | --- |
| US-D10-001 (was Module 08 point 7; US-ACC-01) | As a Fund Accountant, I want trades to post automatically from settlement events, so that I only handle exceptions | C | **AC-US-D10-001-1** (from US-ACC-01) Given a settled trade event, when it is consumed, then a balanced journal posts within 1 minute with the posting-rule version. |
| US-D10-002 (was Module 08 point 7; US-ACC-02) | As an Auditor, I want to drill from a trial-balance line to the source trade, so that I can verify it | C | **AC-US-D10-002-1** (from US-ACC-02) Given any trial-balance line, when drilled, then the source event and document are reachable in ≤ 3 clicks. |
| US-D10-003 | As the Head of Fund Accounting, I want unbalanced entries refused | C | **AC-US-D10-003-1** (was Module 08 point 18) Given a batch whose debits exceed credits by ₹0.01, when posting is attempted, then the whole batch is rejected. |
| US-D10-004 | As an Auditor, I want posted entries never changed | C | **AC-US-D10-004-1** (was Module 08 point 18) Given a posted journal, when an UPDATE is attempted at database level, then it fails with a permission or trigger error. |
| US-D10-005 | As a Fund Accountant, I want overdue receivables flagged | C | **AC-US-D10-005-1** Given a coupon receivable past its due date by more than the configured bucket limit, when the daily close runs, then the item is in that ageing bucket and an exception with an owner is open in the D12 queue. |
| US-D10-006 | As the Head of Fund Accounting, I want sub-ledgers to agree with the ledger | C | **AC-US-D10-006-1** Given open payables items for a scheme, when the daily close runs, then the payables control accounts equal their sum, or a reconciliation break is raised. |
| US-D10-007 | As the CFO, I want closed months locked | C | **AC-US-D10-007-1** Given a CLOSED month, when any batch dated in it is posted, then it is refused; **AC-US-D10-007-2** given a reopen approved by the required approvers with a reason, when entries are posted, then each carries the reopen ID. |
| US-D10-008 | As a Fund Accountant, I want unknown events never lost | C | **AC-US-D10-008-1** Given an event type with no active posting rule, when it arrives, then it posts to suspense, an alert is raised, and the monthly close checklist stays open until suspense is cleared. |
| US-D10-009 | As the COO of an AMC that outsources fund accounting, I want the custodian's books checked daily | C | **AC-US-D10-009-1** Given a scheme in mirror mode, when the custodian's trial balance for D is loaded, then AMC OS's recomputed accruals and unit capital for D are reconciled with it and every difference is a break. |
| US-D10-010 | As a Fund Accountant, I want accruals at the right rate each day | C | **AC-US-D10-010-1** Given a TER change effective from date D (PRD-002 AC-US-D02-007-1), when the accrual runs for D−1 and D, then each uses the rate version in force that day and records it. |
| US-D10-011 | As Compliance, I want AI kept out of the books | C | **AC-US-D10-011-1** Given an AI agent identity, when it calls any journal post or approve endpoint, then 403 is returned and a security alert is raised (PRD-000 US-AI-02). |

Definition of done: as PRD-000 Chapter 5.

## 9. Exceptions

| Exception | Handling | Source |
| --- | --- | --- |
| Unbalanced batch | Whole batch rejected | PRD-000 Module 08 point 14 |
| Unmapped event type | Suspense account and alert, never silent (BRL-D10-007) | Point 14 |
| Posting into a CLOSED period | Refused; correction through WF-017 (BRL-D10-002) | **[DES]** |
| Duplicate event | Ignored by idempotency key; no second batch | **[DES]** (DDL-000 `idempotency_key`) |
| Accrual would pass the TER cap | D08 check result and exception; no silent trimming (FR-D10-006) | **[DES]** |
| Sub-ledger ≠ control account | Reconciliation break (BRL-D10-009) | **[DES]** |
| Overdue receivable or payable | Ageing exception to owner (FR-D10-015, -017) | **[DES]** |
| Custodian file missing or late (mirror mode) | Scheme flagged "not validated" for D; alert to DEP-07; NAV gate per PRD-011 | **[DES]** |
| Unexplained trial-balance variance at month end | Back to true-ups (WF-008) | BA-004 WF-008 |

## 10. Data and interfaces

**Owned schema:** `accounting` (GOV-001 §3). Reads scheme and TER configuration (D02), approved valuations (D11), settlement events (D07), entitlement events (D12), investor transactions from the RTA mirror (D13) through APIs or events. No database change is made in this step.

| Exists in DDL-000 | Not yet in DDL-000 (for DA-001 / DDL, Steps 15–16) **[DES]** |
| --- | --- |
| `accounting.account` (tenant-level COA, class, normal balance, parent); `accounting.period` (per scheme, DAY / MONTH / HALF_YEAR / YEAR, `OPEN / SOFT_CLOSED / CLOSED / REOPENED`); `accounting.journal_batch` (source, posting-rule version as text, manual flag with approval request, reversal link, idempotency key); `accounting.journal_line` (partitioned by date, plan, security, counterparty dimensions, `numeric(24,4)`); immutability triggers; deferred balance and closed-period check; `accounting.trial_balance()` function | Posting-rule table with versions and test cases; accrual runs with inputs and versions; receivables and payables open items and ageing; effective dating and statement-line mapping on accounts (C4); reopen reason and approvals on periods; separate effective date for back-dated corrections (BRL-D10-002; C4); mirror-mode custodian ledger and TB loads; suspense tracking; per-scheme mode setting |

**Interfaces (indicative, not contracts):** PRD-000 Module 08 point 11 names `accounting-svc` endpoints `/coa`, `/journal-batches`, `/journals`, `/periods`, `/trial-balance?scheme&asOf`, `/accrual-runs`, `/reversals`; this PRD adds receivables, payables and ageing. Names become `API-D10-nnn` in Step 24 and events `<NAME>.v<n>` in EA-007 (Step 13). Outside parties: custodian (ledger and TB in mirror mode), banks (statements, through D12) — "Confirm with <custodian> / <bank>" (INT-001, Step 14).

## 11. Non-functional requirements

| ID | Requirement | Type / source |
| --- | --- | --- |
| NFR-PERF-014 | 1 million journal lines per day for a large tenant | Proposed — PRD-000 Module 08 point 17 |
| NFR-PERF-015 | Trial balance for any scheme and date in < 3 s | Proposed — PRD-000 Module 08 point 17 |
| NFR-AUD-010 | Line-level lineage to the source event; posting-rule version on each line; every manual journal, reopen and suspense clearance with maker, checker and reason | PRD-000 Module 08 point 15; **[DES]** |
| NFR-RET-004 | Books of account (journals, ledgers, trial balances, period sign-offs) kept for the period required for scheme books **[VAL period]**; never deleted inside it | **[REG — books of account [S4]; VAL period and 2026 clause]** |

Platform NFRs in PRD-001 §11 apply.

## 12. AI in this domain

Within PRD-000 C8 and ADR-0008 (read and propose only). The **NAV operations assistant** (CAP-D17-007) may explain unusual expense or income movements; the **CFO copilot** (CAP-D17-011) may summarise a scheme's income and expenses; the **reconciliation assistant** (CAP-D17-008) may suggest matches for accounting breaks, which a person accepts. Every number they state must come from FE-02 results through tools (PRD-000 §9.1 hard rule 2). An AI may draft a manual-journal *proposal* for a Fund Accountant to submit; it never creates, approves or posts a journal (BRL-D10-013, SOD-10). Anomaly flags on accruals (CAP-D17-015) are advisory only.

## 13. Open points

| # | Point | Where closed |
| --- | --- | --- |
| C1 | Accounting-policy schedule, statement formats and Ind AS carry-over under the 2026 Regulations; unrealised gains, equalisation and distributable surplus; retention period for books **[VAL]** | REG-001 (Step 25); FE-02 (Step 21) |
| C2 | Day counts, plan apportionment method, capitalise-or-expense of charges **[VAL]** | FE-02 (Step 21) |
| C3 | Reopen approvers — closed by owner decision D-42 (CFO and Head of Fund Accounting); BA-005 §3 still shows the COO "A(reopen with CFO)" | Next BA-005 revision (align §3) |
| C4 | DDL-000 keeps one chart of accounts per tenant, while PRD-000 says "cloned per scheme"; accounts have no effective dating; there is no separate effective date for back-dated corrections, and the closed-period check blocks only CLOSED | DA-001 / DDL (Steps 15–16) |
| C5 | Posting-rule and account-change checker (†) is not in BA-005 §4 | Next BA-005 revision |
| C6 | Mirror mode: how much AMC OS recomputes — closed by owner decision D-40 (daily load, recheck accruals, unit capital and NAV; no full shadow ledger); how often each mode occurs (BA-002 §8 C5) stays open | Pilot discovery |
| C7 | Manual journals have no WF card; the approval rule is closed by owner decision D-41 (Senior Fund Accountant; Head of Fund Accounting above a tenant-set amount) | Next BA-004 revision if a card is wanted |
| C8 | Ageing buckets, escalation and write-off / provision authority — closed by owner decision D-43 (tenant-set bands; write-off by maker-checker manual journal) | Values per tenant at onboarding |

## Sources

Repository sources: [PRD-000 v0.9](PRD-000_master_prd_v0.9.md) Module 08, Ch 4 W8, Ch 5, Ch 6, Ch 9 (re-keyed requirements, rules, stories, labels); [BA-001](../02_business_architecture/BA-001_business_capability_map.md) D10, §4 (capabilities, shared ownership); [BA-002](../02_business_architecture/BA-002_amc_operating_model.md) §3–§5 (DEP-07, systems stance); [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-007, WF-008, WF-009, WF-018; [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md) §3–§5; [DA-000](../05_data_architecture/DA-000_data_and_database_architecture_v0.9.md) ER-8, §7; [DDL-000](../../database/ddl/DDL-000_core_schema_v0.9.sql) section 10; [LOOP_STATE.md](../../LOOP_STATE.md) owner decisions D-3, D-16, D-40…D-43.

External sources (opened through web search on 21 Nov 2026; regulatory detail still **[VAL]**). The SEBI PDF of the 2026 Regulations could not be opened in this step and is to be read clause by clause in REG-001.

| # | Source | Used for |
| --- | --- | --- |
| S1 | [SEBI — Mutual Funds Regulations, 2026 (page)](https://www.sebi.gov.in/legal/regulations/apr-2026/securities-and-exchange-board-of-india-mutual-funds-regulations-2026_100744.html) — primary; title and date only | Name of the current rulebook |
| S2 | [Taxmann — SEBI notifies Mutual Funds Regulations, 2026](https://www.taxmann.com/post/blog/sebi-notifies-mutual-funds-regulations-2026) — secondary | Notified 14 Jan 2026; effective 1 Apr 2026 |
| S3 | [ELP — SEBI revamps and replaces its 30-year-old regulations for mutual funds (Mar 2026)](https://elplaw.in/wp-content/uploads/2026/03/SEBI-Revamps-and-Replaces-Its-30-Year-Old-Regulations-for-Mutual-Funds-2.pdf) — law-firm summary, secondary | Annual report in the Ninth Schedule (Reg 70(1)); base expense ratio (Reg 67); TER disclosure (Reg 70(4)) |
| S4 | [SEBI (Mutual Funds) Regulations, 1996 — text on SEBI site](https://www.sebi.gov.in/sebi_data/attachdocs/jan-2026/1768571780322.pdf) — primary, read for regulation and schedule titles only | Reg 50 books of account; Eighth, Ninth, Eleventh, Twelfth Schedule titles |
| S5 | [SCC Online — SEBI guidelines on accounting with respect to Ind AS (7 Feb 2022)](https://www.scconline.com/blog/post/2022/02/07/sebi-issues-guidelines-on-accounting-with-respect-to-indian-accounting-standards-ind-as/) — secondary | Scheme financial statements under Ind AS from 1 Apr 2023 |
| S6 | [KPMG First Notes — SEBI mutual funds Ind AS (Mar 2022)](https://assets.kpmg.com/content/dam/kpmg/in/pdf/2022/03/firstnotes-sebi-mutual-funds-ind-as-regulatory-updates.pdf) — secondary | Circular of 4 Feb 2022; prescribed formats; first Ind AS statements for the year ending 31 Mar 2024 |
| S7 | [AMFI — What is total expense ratio?](https://amfiindia.com/investor-corner/knowledge-center/Expense-Ratio.html) — industry body | Expenses charged as a share of daily net assets; daily NAV after expenses |
