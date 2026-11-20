---
id: PRD-006
title: Trading and Execution (D06) — Product Requirements
status: Draft
version: 0.1
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 8
last_updated: 2026-11-20
---

# PRD-006 — Trading and Execution (D06)

This document states what AMC OS must do between the moment an approved order is released to the dealing desk and the moment a confirmed trade is handed to settlement: talk to brokers, capture fills, allocate block fills fairly to schemes, match broker contract notes, reconcile orders, fills and contract notes, and handle trade exceptions. It also covers the broker panel. It re-keys the execution part of PRD-000 v0.9 Module 04 (FR-04-09…11) and the trade part of Module 05 (FR-05-01…03, FR-05-07 and the broker part of FR-05-11) to the GOV-001 identifiers (`FR-04-nn` / `FR-05-nn` → `FR-D06-nnn`, `BR-04-n` / `BR-05-n` → `BRL-D06-nnn`, `US-STL-01` and Module 04/05 stories → `US-D06-nnn`). This closes PRD-005 open point C5.

**Builds on Draft documents:** [PRD-000 v0.9](PRD-000_master_prd_v0.9.md) Modules 04, 05 and 10 (FR-10-02 only as a reference), Chapter 4 (W4, W6b), Chapter 5, Chapter 6, Chapter 9; [BA-001](../02_business_architecture/BA-001_business_capability_map.md) D06, §4, §5; [BA-002](../02_business_architecture/BA-002_amc_operating_model.md) §4; [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-004, WF-018, WF-023, WF-024, WF-025; [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md); [PRD-005](PRD-005_order_management.md); [DA-000](../05_data_architecture/DA-000_data_and_database_architecture_v0.9.md); DDL-000 v0.9 — allowed by owner decision D-3 ([GOV-008](../00_governance/GOV-008_build_loop.md) §2 rule 3). No document used here is Approved. Owner decision D-18 (no SoD waivers except SOD-03 and small-team mode) is applied.

**What this document is not:** order creation, approval, compliance calls and release (D05, [PRD-005](PRD-005_order_management.md)); rule evaluation (D08, FE-04); settlement instructions, SSIs, payments and fails (D07, PRD-007); the reconciliation engine itself (D12, CAP-D12-003, FE-07) and broker statements and brokerage bills (D12, CAP-D12-005); counterparty golden records (D16, CAP-D16-004); algorithmic execution (PS-001 §3); AI that sends, executes or allocates (ADR-0008). **Rule for engineers (PRD-000):** no regulatory number, tax rate, tolerance or limit is hard-coded; each is a versioned parameter or configuration.

## 1. Scope

| In scope (CAP) | Out of scope |
| --- | --- |
| CAP-D06-001 Broker management · CAP-D06-002 Execution management · CAP-D06-003 Trade confirmation · CAP-D06-004 Trade allocation · CAP-D06-005 Execution reconciliation · CAP-D06-006 Broker communication · CAP-D06-007 Trade lifecycle · CAP-D06-008 Trade exception handling | Orders up to release (D05); settlement instructions, SSIs, cash and fails (D07); reconciliation engine and broker bills (D12); counterparty golden record (D16); exchange or clearing membership (AMC OS is not a broker, BA-001 §6); algorithmic execution; AI that executes (ADR-0008) |

## 2. Re-keying from PRD-000

| PRD-000 v0.9 | Here | Note |
| --- | --- | --- |
| FR-04-09, FR-04-10, FR-04-11 | FR-D06-001, FR-D06-002, FR-D06-003 | Left by PRD-005 §2 for this document (PRD-005 C5) |
| FR-05-01, FR-05-02, FR-05-03 | FR-D06-004, FR-D06-005, FR-D06-006 | BA-001 places trade capture and confirmation in D06 (CAP-D06-007, CAP-D06-003) |
| FR-05-07 | FR-D06-007 | Trade-by-trade execution reconciliation; broker statements and bills stay D12 (BA-001 §4) |
| FR-05-11 **(split)** | FR-D06-008 (broker part) | D06 keeps only the broker part: brokers' empanelment status and limits (CAP-D06-001). SSIs go to D07 (PRD-007, CAP-D07-004 (.2)). Empanelment status and limits of non-broker counterparties (custodians, banks, clearing corporations, debt and repo counterparties): **[DES]** proposal — the counterparty record and its empanelment status sit with the counterparty master (D16 CAP-D16-004; owner of `master` open, BA-001 §5 C2); counterparty exposure limits are measured by D09 (CAP-D09-005) and enforced as D08 rules (CAP-D08-005). Confirmed in EA-003 (Step 11). (open point C15) |
| FR-05-04 … FR-05-06, FR-05-08, FR-05-09 | — | D07 (PRD-007) |
| FR-05-10 | — | Corporate actions are D12 (CAP-D12-007), re-keyed in PRD-012 (Step 9) |
| FR-10-02 (broker connectivity) | — | **Referenced only**; Module 10 is re-keyed in PRD-012 (Step 9). FR-D06-013 and FR-D06-014 state the D06 need |
| BR-04-3 (after the fill), BR-04-5 | BRL-D06-001, BRL-D06-002 | PRD-005 keeps BRL-D05-003 and BRL-D05-005 for the D05 side (intent recorded, storage required); here is how D06 applies and stores them |
| BR-05-4 | BRL-D06-003 | Charges check; rates are **[REG; VAL]** |
| BR-05-1, BR-05-2, BR-05-3 | — | D07 (SSI, settlement on custodian confirmation) and D12 (corporate-action entitlements) |
| US-OMS-02 and the Module 04 point 7 Dealer story — fair-allocation part after the fill | US-D06-001 | PRD-005 US-D05-002 keeps the intent part |
| US-STL-01 (Ch 5) and the Module 05 point 7 Operations story ("every trade automatically matched with the broker's contract note") | US-D06-002 | **Merged:** same need |
| Module 04 point 18 allocation criterion (500/300/200) | AC-US-D06-001-1 | Left by PRD-005 §2 |
| Module 05 point 18 `CHARGE_MISMATCH` criterion | AC-US-D06-002-2 | |
| Module 05 point 7 FM and Auditor stories; Module 05 point 18 failed-settlement criterion | — | D07 (PRD-007) |
| Module 04 point 14 (FIX session drop, duplicate fill, late fill), point 15 (raw FIX archive), point 17 ("zero lost fills") | §9, FR-D06-015, NFR-AUD-006 | Left by PRD-005 (C5) |
| — | FR-D06-009 … FR-D06-021, BRL-D06-004 … BRL-D06-008, US-D06-003 … US-D06-008 | **New** **[DES]** |

## 3. Business requirements

| ID | Business requirement | Capabilities |
| --- | --- | --- |
| BR-D06-001 | Orders reach only empanelled, active brokers within approved limits, and every message to and from a broker can be produced later exactly as sent or received | CAP-D06-001, -006 |
| BR-D06-002 | Every fill is captured once and only once, and block fills are allocated to schemes fairly and by the intent fixed before execution | CAP-D06-002, -004 |
| BR-D06-003 | Every trade is matched to the broker's contract note, and orders, fills and contract notes agree trade by trade on the trade date, before the trade goes to settlement | CAP-D06-003, -005, -007 |
| BR-D06-004 | Trade errors are found early, worked in one queue and corrected only by reversal and re-entry with maker-checker, never by editing history | CAP-D06-008 |

## 4. Functional requirements

Every requirement also obeys PRD-000 common rules C1–C8. Labels from PRD-000 are carried unchanged. Priority: **M** must (release-blocking), **S** should — as PRD-000 Chapter 3.

### 4.1 Re-keyed from PRD-000 Modules 04 and 05

| ID (was) | Pri | Capability | Requirement |
| --- | --- | --- | --- |
| FR-D06-001 (FR-04-09) | M | CAP-D06-002 (.1), (.2) | **Execution capture:** fills with price, quantity, time, exchange and broker trade/execution ID; partial executions accumulate against the order or block. Each fill is stored once: the service detects a duplicate by broker and broker execution ID, whatever its `executed_at` (idempotent). DDL-000 `execution.fill` does not yet enforce this on its own (open point C16) |
| FR-D06-002 (FR-04-10) | M | CAP-D06-004 (.1), (.2) | **Post-trade allocation:** allocate block fills to schemes pro-rata to the intent recorded in D05 (FR-D05-007), or by a documented rule; one average price per scheme; deviations need Head of Dealing **and** Compliance Officer approval (`execution.allocation.approve_deviation`). **[REG — fair allocation among schemes; VAL exact clause]** |
| FR-D06-003 (FR-04-11) | M | CAP-D06-003 (.1) | **Trade confirmation:** match the broker contract note to the allocations; send the status to settlement (D07) and to the order (D05) |
| FR-D06-004 (FR-05-01) | M | CAP-D06-007 (.1) | **Trade capture:** trades from executed and allocated orders; also externally booked trades (primary market, IPO allotments, inter-scheme transfers, repo / TREPS) by controlled entry with maker-checker and evidence (WF-024, `execution.trade.approve_external`) |
| FR-D06-005 (FR-05-02) | M | CAP-D06-007 (.2) | **Execution records:** link every trade to its fill(s), block and order; an externally booked trade links to its evidence instead |
| FR-D06-006 (FR-05-03) | M | CAP-D06-003 (.1), (.2), (.3) | **Contract-note matching (affirmation):** match the contract note (trade ID, quantity, price, brokerage, stamp duty, STT, GST, exchange charges) to the AMC trade under tolerance rules (tenant configuration **[ASSUMPTION]**); a mismatch creates a break of a typed reason (for example `QUANTITY_MISMATCH`, `PRICE_MISMATCH`, `CHARGE_MISMATCH`) and the trade is not auto-affirmed |
| FR-D06-007 (FR-05-07) | M | CAP-D06-005 (.1) | **Execution reconciliation:** each trade date, orders vs fills vs contract notes, trade by trade, run on the reconciliation engine (FE-07, CAP-D12-003) with D06's own reconciliation set; unmatched items become breaks (WF-025) |
| FR-D06-008 (FR-05-11, broker part) **(split)** | M | CAP-D06-001 (.1) | **Broker records:** empanelment status (WF-023 states), segments and instruments the broker may be used for, broker limits (% of turnover per broker, PRD-005 FR-D05-007), and links to the counterparty golden record (CAP-D16-004) and the broker's SSIs (D07). Changes are maker-checker versions with effective dates |

### 4.2 New requirements **[DES]**

| ID | Pri | Capability | Requirement |
| --- | --- | --- | --- |
| FR-D06-009 | M | CAP-D06-001 (.2) | **Brokerage rate schedule:** brokerage rates per broker, segment and instrument kept as versions with effective dates, entered by maker-checker; the version used for each trade's expected brokerage is stored with the trade |
| FR-D06-010 | S | CAP-D06-001 (.3) | **Broker evaluation:** periodic evaluation of each broker on execution quality (FR-D06-012), service and errors (breaks caused, late contract notes); the result feeds the review in WF-023. Criteria and frequency are AMC policy **[ASSUMPTION]** — confirm: Head of Dealing of the pilot AMC |
| FR-D06-011 | M | CAP-D06-001 (.1) | **Broker status enforced:** only a broker in status `ACTIVE` (WF-023) can receive a new order or block; a broker set to `SUSPENDED` or `REMOVED` is refused at routing, and open orders at that broker are shown to the Head of Dealing |
| FR-D06-012 | S | CAP-D06-002 (.3) | **Execution-quality review:** compare each fill price with a reference price for the same period (the reference measure and price source are AMC policy **[ASSUMPTION]**); show per order, per dealer and per broker; no threshold is set by this document |
| FR-D06-013 | M | CAP-D06-006 (.1) | **Broker order and fill messages:** send released orders, blocks, amendments and cancels to the broker, and receive acknowledgements, rejects and execution reports. The protocol and message format are agreed with each broker (PRD-000 FR-10-02 assumes FIX **[ASSUMPTION]**) — confirm with each broker in INT-001 (Step 14). After a lost connection, messages are recovered by sequence so that no fill is lost or doubled |
| FR-D06-014 | M | CAP-D06-006 (.2) | **Contract-note intake:** receive contract notes as files or as emailed PDF documents (PRD-000 FR-10-02) — formats confirmed with each broker; parsing is deterministic; a note that cannot be read completely goes to the break queue, never to an auto-match |
| FR-D06-015 | M | CAP-D06-006 | **Raw message archive:** every message to and from a broker, and every contract note as received, is stored raw, unchanged and linked to the fill, order or trade it concerns (BRL-D06-002) |
| FR-D06-016 | M | CAP-D06-004 (.2) | **Allocation fairness check:** after allocation the system compares each scheme's allocated quantity and price with the intent; any difference beyond the allocation rule (for example rounding to lot size, open point C6) is a deviation that blocks hand-off until approved under FR-D06-002 |
| FR-D06-017 | M | CAP-D06-008 (.1) | **Trade break queue:** one queue for D06 breaks (contract-note mismatch, reconciliation breaks, unreadable contract notes, late fills after cancel) with reason, owner, ageing and link to the item; breaks also appear in the operations exception queue (CAP-D12-008) |
| FR-D06-018 | M | CAP-D06-008 (.2) | **Trade cancel or correct:** a trade is cancelled or corrected only by a reversal and a new trade, with maker-checker (`execution.trade.correct`, Head of Dealing as checker); a correction after allocation re-runs post-trade compliance (D08, through D05 FR-D05-009) and leads to a reversal and a new entry in accounting (WF-025) |
| FR-D06-019 | M | CAP-D06-007 (.3) | **Hand-off to settlement:** a trade goes to D07 only when it is matched to its contract note within tolerance (WF-025), or, for an externally booked type with no contract note, when the checker has confirmed it against its evidence (WF-024) |
| FR-D06-020 | M | CAP-D06-002, CAP-D06-004, CAP-D06-003 | **Status to the order:** fills, broker acknowledgements, rejects (with the broker's reason), cancel confirmations, allocation results and confirmation status are published as events that move the order state in D05 (PRD-005 FR-D05-014, §4.3); D06 never writes D05 records (AGENTS.md §2.3) |
| FR-D06-021 | M | CAP-D06-002 | **Broker reject and re-route (D06 side):** on a broker reject D06 records the reject and the broker's reason and reports it; D06 never re-sends a rejected order to the same or another broker on its own. A re-route is sent only when D05 releases a new order or order version (PRD-005 §9, open point C4 there) |

### 4.3 Trade and execution states

PRD-000 gives no state machine for executions or trades before settlement, and DDL-000 has none (`execution.fill` is insert-only; `settlement.trade.status` starts at `PENDING_INSTRUCTION`, the D07 state machine). The following is proposed **[DES]** for DA-001 (Step 15) to confirm (open point C10):

```mermaid
stateDiagram-v2
  [*] --> CAPTURED: fills allocated (WF-004) or external trade entered (WF-024)
  CAPTURED --> ALLOCATION_DEVIATION: fairness check fails (FR-D06-016)
  ALLOCATION_DEVIATION --> CAPTURED: deviation approved
  CAPTURED --> CHECKER_PENDING: external trade
  CHECKER_PENDING --> CONFIRMED: checker approves; no contract note for the type
  CHECKER_PENDING --> AWAITING_CONTRACT_NOTE: checker approves; type has a contract note (changed from WF-024)
  CAPTURED --> AWAITING_CONTRACT_NOTE
  AWAITING_CONTRACT_NOTE --> CONFIRMED: matched within tolerance
  AWAITING_CONTRACT_NOTE --> BREAK: mismatch or unreadable note
  BREAK --> AWAITING_CONTRACT_NOTE: broker sends corrected note
  BREAK --> REVERSED: AMC trade corrected (maker-checker)
  CONFIRMED --> REVERSED: later correction (maker-checker)
  CONFIRMED --> [*]: handed to D07 (WF-018)
  REVERSED --> [*]
```

The transition `CHECKER_PENDING → AWAITING_CONTRACT_NOTE` is **(changed from WF-024)**: WF-024 marks such a trade `CONFIRMED` before matching (open point C17). A reversed trade is replaced by a new trade that starts at `CAPTURED` (BRL-D06-004). Fills themselves have no state: a broker bust or correction is a new adjustment fill linked to the original (DA-000 Ch 1 principle 3; Ch 7, execution row) **[DES]**.

## 5. Business rules

| ID (was) | Rule | Label |
| --- | --- | --- |
| BRL-D06-001 (BR-04-3, after the fill) | Block fills are allocated by the pre-trade intent recorded in D05 unless an approved deviation exists (Head of Dealing and Compliance Officer) | **[DES]** (PRD-000 unlabelled); fair allocation **[REG — VAL exact clause]** (FR-04-10) |
| BRL-D06-002 (BR-04-5) | Every message to or from a broker is stored raw for at least the retention period; raw messages are never changed or deleted before then | **[VAL period]** |
| BRL-D06-003 (BR-05-4) | Expected charges (STT, stamp duty, GST, exchange charges) are calculated from a versioned rate table and compared with the broker's values within tolerance; this document states no rate | **[REG — tax rates; VAL]** |
| BRL-D06-004 | Fills and confirmed trades are never edited: a broker bust or correction is an adjustment fill; an AMC correction is a reversal and a new trade | **[DES]** (DA-000 Ch 1 principle 3) |
| BRL-D06-005 | All schemes in one block allocation receive the same average price of the block's fills | **[DES]** (from PRD-000 Module 04 point 18) |
| BRL-D06-006 | Only a broker in status `ACTIVE`, within its approved limits, may receive an order | **[DES]** |
| BRL-D06-007 | A trade goes to settlement only when confirmed (FR-D06-019) | **[DES]** |
| BRL-D06-008 | Broker limits, brokerage rate schedules, matching tolerances and the allocation rounding rule are tenant configuration changed only through maker-checker (WF-021 for configuration) | **[DES]**; values **[ASSUMPTION — confirm: Head of Dealing and DEP-06 of the pilot AMC]** |

## 6. Workflows

| Workflow | D06 role | Requirements |
| --- | --- | --- |
| [WF-004](../02_business_architecture/BA-004_end_to_end_workflows.md) Order creation and execution | Execution part: send to broker, capture fills, allocate | FR-D06-001, -002, -013, -015, -016, -020, -021 |
| WF-023 Broker empanelment and review | Accountable (DEP-05) | FR-D06-008…011 |
| WF-024 Externally booked trade capture | Accountable (DEP-05) | FR-D06-004, -005, -019 |
| WF-025 Trade confirmation, execution reconciliation and trade exceptions | Accountable for D06 parts (DEP-06 confirmation and reconciliation; DEP-05 exceptions) | FR-D06-003, -006, -007, -014, -017, -018, -019 |
| WF-018 Trade settlement | Hands confirmed trades to D07 | FR-D06-019 |
| WF-015 Reconciliation | Uses the engine for its own reconciliation set | FR-D06-007 |

No new workflow is needed for D06: BA-004 §5.1 lists no D06 gap.

## 7. Permissions by capability

From BA-005 §3 (D06 column) and §4, narrowed to each capability (BA-005 §7 C2). Checker ≠ maker (SOD-01). CEO, COO, CIO, CFO, Fund Manager (own schemes), Compliance Officer, Risk Manager, Fund Accountant and Auditor read (BA-005 §3).

| Capability | Maker | Checker(s) |
| --- | --- | --- |
| CAP-D06-001 Broker management | Dealer — Head of Dealing proposes (WF-023) | Body named in the AMC's broker policy **[ASSUMPTION]** (`execution.broker.approve`, SOD-14); limits and rate schedules: a second person per maker-checker **[DES]** |
| CAP-D06-002 Execution management | System (fills); Dealer (blocks at the desk) | — |
| CAP-D06-003 Trade confirmation | System; Operations Analyst (confirmation) | — (force-match follows WF-015: Operations Manager) |
| CAP-D06-004 Trade allocation | System allocates; Dealer requests a deviation | Head of Dealing **and** Compliance Officer (`execution.allocation.approve_deviation`) |
| CAP-D06-005 Execution reconciliation | System; Operations Analyst works breaks | — |
| CAP-D06-006 Broker communication | System | — |
| CAP-D06-007 Trade lifecycle; external trades | Dealer or Operations Analyst | A second Dealer, or the Operations Manager (`execution.trade.approve_external`) |
| CAP-D06-008 Trade exception handling; cancel or correct | Dealer or Operations Analyst | Head of Dealing (`execution.trade.correct`) |

All makers and checkers above match the BA-005 §3 D06 cells (Dealer "R C U S (route, block, allocate, external trades)", Operations Analyst "R C U S (confirmation, breaks, external trades)"); no right is added. The Fund Manager has read only on D06 (BA-005 §3), so the FM who originated an order cannot act on its execution (SOD-03).

## 8. User stories and acceptance criteria

Priority: **C** critical (release-blocking), **O** optional — as PRD-000 Chapter 5.

| ID | Story | Pri | Acceptance criteria (Given / When / Then) |
| --- | --- | --- | --- |
| US-D06-001 (was US-OMS-02 / Module 04 point 7, fill part) | As a Dealer, I want block fills allocated to schemes fairly by the intent | C | **AC-US-D06-001-1** (was Module 04 point 18) Given a block of 3 scheme orders with intent 50/30/20 and a fill of 1,000 shares, when allocation runs, then schemes receive 500/300/200 at the same average price. |
| US-D06-002 (was US-STL-01 and Module 05 point 7 Operations story) | As an Operations Analyst, I want contract notes matched automatically, so that I work only on exceptions | C | **AC-US-D06-002-1** (was US-STL-01) Given 1,000 trades with correct notes, when matching runs, then ≥ 99% auto-affirm. **AC-US-D06-002-2** (was Module 05 point 18) Given a contract note where brokerage differs from expected by more than tolerance, when matching runs, then a break with type `CHARGE_MISMATCH` is created and the trade is not auto-affirmed. |
| US-D06-003 | As a Dealer, I want each fill recorded exactly once | C | **AC-US-D06-003-1** Given a fill already stored, when the broker sends the same execution report again (same broker and execution ID), then no second fill is created and the duplicate is logged. |
| US-D06-004 | As a Compliance Officer, I want allocation deviations approved by two people | C | **AC-US-D06-004-1** Given an allocation that differs from the intent beyond the allocation rule, when only the Head of Dealing approves, then the trades stay in `ALLOCATION_DEVIATION` until a Compliance Officer also approves. |
| US-D06-005 | As Head of Dealing, I want suspended brokers blocked | C | **AC-US-D06-005-1** Given a broker in status `SUSPENDED`, when a dealer tries to route an order to it, then routing is refused and logged. |
| US-D06-006 | As an Auditor, I want the original broker message behind every fill | C | **AC-US-D06-006-1** Given any stored fill, when the auditor opens it, then the raw broker message it came from is shown unchanged. |
| US-D06-007 | As an Operations Manager, I want external trades checked before settlement | C | **AC-US-D06-007-1** Given an IPO allotment entered with evidence, when it is not yet approved by a checker who is not the maker, then it is not sent to settlement. |
| US-D06-008 | As an Auditor, I want trade corrections to keep history | C | **AC-US-D06-008-1** Given a confirmed trade, when it is corrected, then the original stays unchanged, a reversal and a new trade are created, and the correction shows maker and Head of Dealing approval. |

Definition of done: as PRD-000 Chapter 5. The 99% target in AC-US-D06-002-1 is PRD-000's figure, kept as proposed until pilot discovery.

## 9. Exceptions

| Exception | Handling | Source |
| --- | --- | --- |
| Broker reject | Recorded with reason; order moves to `REJECTED_BY_BROKER` in D05; no automatic re-send (FR-D06-021) | PRD-000 Module 04 point 14; WF-004 |
| Connection drop with a broker | Reconnect and recover missed messages by sequence; order state in D05 unchanged until D06 reports | PRD-000 Module 04 point 14 |
| Duplicate fill | Ignored by broker and broker execution ID, whatever its `executed_at` (idempotent, checked by the service), and logged | PRD-000 Module 04 point 14; open point C16 |
| Late fill after the order is `CANCELLED` | Stored, flagged and put in the break queue and the exception queue (CAP-D12-008); not allocated until resolved | PRD-000 Module 04 point 14 |
| Broker bust or correction of a fill | Adjustment fill linked to the original; allocation and confirmation re-run | DA-000 Ch 7 (execution row) |
| Contract note mismatch or unreadable | Break; not auto-affirmed (FR-D06-006, -014) | PRD-000 Module 05 point 18; WF-025 |
| Contract note not received in time | Break by ageing; the time limit is tenant configuration **[ASSUMPTION]** | WF-025 **[DES]** |
| Allocation deviation | Held until both approvals (FR-D06-002, -016) | WF-004 |

## 10. Data and interfaces

**Owned schema:** `execution` (GOV-001 §3; DA-000: broker sessions, raw FIX messages, executions). No database change is made in this step.

| Exists in DDL-000 | Not yet in DDL-000 (for DA-001 / DDL, Steps 15–16) **[DES]** |
| --- | --- |
| `execution.fill` (insert-only, monthly partitions, `UNIQUE (tenant_id, executed_at, broker_code, broker_exec_id)` — this does **not** stop a repeated report with a different `executed_at` or in another partition being stored twice, so duplicate detection is not yet in place in the database (C16); `raw_message_ref` pointer to the raw archive). Related, owned elsewhere: `trading.block_allocation` (D05 schema, holds `allocated_quantity` and `average_price`), `settlement.trade` (D07 schema, holds charges and the settlement status) | Raw broker message archive; broker record, limits and brokerage rate schedule versions; broker evaluations; allocation results owned by D06; contract notes and match results; trade record with the §4.3 states; trade break queue; external-trade evidence links; charges rate table |

**Allocation results and trade records (PRD-005 C9; BA-001 §5 C3)** **[DES proposal]:** D06 owns post-trade allocation results and the trade record in `execution`; D05 records only the order state it learns from D06 events; D07 receives confirmed trades by event and keeps its own settlement record. Today DDL-000 puts allocation results in `trading.block_allocation` and the trade with charges in `settlement.trade`, which would need D06 to write other domains' schemas (AGENTS.md §2.3). Confirmation is left to EA-003 (Step 11) and DA-001 (Step 15) (open points C3, C4).

**Interfaces (indicative, not contracts):** PRD-000 Module 04 point 11 names `/allocations`, `/executions` and the event `trading.execution.received`; Module 05 point 11 names `/trades`. These move to D06. Brokers connect only to D06 (FR-D06-013, -014), with protocol and format confirmed with each broker in INT-001 (Step 14). D06 sends confirmed trades to D07 (`trading.trade.confirmed` in BA-004) and status events to D05. Names become `API-D06-nnn` in Step 24 and events `<NAME>.v<n>` in EA-007 (Step 13) (BA-004 §5.2 C4).

## 11. Non-functional requirements

NFR numbering continues after PRD-005.

| ID | Requirement | Type / source |
| --- | --- | --- |
| NFR-AUD-006 | Zero lost fills: every execution report received is either stored as a fill or logged as a duplicate, and gaps in broker message sequence are detected and recovered; raw broker message archive linked to fills, orders and trades (PRD-000 Module 04 points 15 and 17) | PRD-000 Module 04 points 15, 17; **[DES]** wording |
| NFR-RET-003 | Raw broker messages and contract notes are kept, unchanged, for the retention period set in REG-001 | **[VAL period]** (BRL-D06-002) |

PRD-000 gives no latency or volume figure for execution capture, matching or reconciliation; none is invented here (open point C12). Platform NFRs in PRD-001 §11 apply.

## 12. AI in this domain

Within PRD-000 C8 and ADR-0008 (read and propose only):

- **Dealing assistant** (CAP-D17-004): gives dealers order and execution context (broker status, fills so far, execution-quality history). It never sends, amends, cancels or allocates.
- **Reconciliation assistant** (CAP-D17-008): suggests matches and likely break causes with a confidence; the Operations Analyst accepts, and a force-match still needs maker-checker (WF-015).
- Contract-note parsing (FR-D06-014) is deterministic; any AI-read value would be a suggestion that a person confirms, never an auto-match **[DES]**.

## 13. Open points

| # | Point | Where closed |
| --- | --- | --- |
| C1 | Regulatory basis of fair allocation among schemes (FR-D06-002, BRL-D06-001) **[VAL]** | REG-001 (Step 25) |
| C2 | Retention period for raw broker messages and contract notes (BRL-D06-002, NFR-RET-003) **[VAL]** | REG-001 (Step 25) |
| C3 | DA-000 and DDL-000 keep trades and charges in `settlement.trade` (D07 schema) while BA-001 gives trade lifecycle and confirmation to D06 (BA-001 §5 C3, BA-004 §5.2 C2) | EA-003 (Step 11), DA-001 (Step 15) |
| C4 | Where allocation results live and who writes them (PRD-005 C9): §10 proposes D06 in `execution`, with D05 updated by events | EA-003 (Step 11), DA-001 (Step 15) |
| C5 | Re-route after `REJECTED_BY_BROKER`: D06 side settled here (FR-D06-021); whether D05 creates a new order or a new order version stays PRD-005 C4 | PRD-005 revision or DA-001 |
| C6 | Allocation rounding rule when pro-rata quantities are not whole lots or shares (who gets the remainder) **[ASSUMPTION]** | Owner question Q22 in [LOOP_STATE.md](../../LOOP_STATE.md); pilot discovery (Head of Dealing, Compliance) |
| C7 | Who owns the statutory charges rate table (BRL-D06-003) — D06, D10 or reference data in D16 — who updates it when rates change, and the matching tolerances **[ASSUMPTION]** | Owner question Q23 in [LOOP_STATE.md](../../LOOP_STATE.md); EA-003 (Step 11); values: pilot discovery |
| C8 | Broker evaluation criteria and review frequency, broker limits and brokerage schedules (FR-D06-008…010) **[ASSUMPTION]** | Pilot discovery (Head of Dealing) |
| C9 | Order, fill and contract-note protocols and formats per broker (FR-D06-013, -014) | INT-001 (Step 14) — confirm with each broker |
| C10 | Trade states (§4.3) are proposed; not in PRD-000 or DDL-000 | DA-001 / DDL (Steps 15–16) |
| C11 | Broker records rely on the counterparty golden record, whose owning domain is not yet set (BA-001 §5 C2) | EA-003 (Step 11) |
| C12 | No performance figure exists for fill capture, matching or reconciliation; the 99% auto-affirm target (AC-US-D06-002-1) is PRD-000's figure | Pilot discovery; next PRD-006 revision |
| C13 | Reference price and measure for execution-quality review (FR-D06-012) **[ASSUMPTION]** | Pilot discovery |
| C14 | Which externally booked trade types have a broker contract note (BA-004 WF-024) **[ASSUMPTION]** | Pilot discovery (DEP-06) |
| C15 | FR-05-11 split: Empanelment status and limits of non-broker counterparties (custodians, banks, clearing corporations, debt and repo counterparties): **[DES]** proposal — the counterparty record and its empanelment status sit with the counterparty master (D16 CAP-D16-004; owner of `master` open, BA-001 §5 C2); counterparty exposure limits are measured by D09 (CAP-D09-005) and enforced as D08 rules (CAP-D08-005). Confirmed in EA-003 (Step 11). | EA-003 (Step 11); PRD-007 states the same proposal |
| C16 | Duplicate fills: DDL-000 `execution.fill` is unique on `(tenant_id, executed_at, broker_code, broker_exec_id)`, so the same report with a different `executed_at` (or in another monthly partition) would be stored twice. A dedup key independent of `executed_at` is needed (for example a separate dedup key table); until then the service check of FR-D06-001 is the only control | DA-001 / DDL (Steps 15–16) |
| C17 | **(changed from WF-024)** §4.3 sends an external trade whose type has a contract note from `CHECKER_PENDING` to `AWAITING_CONTRACT_NOTE`, so it is `CONFIRMED` only after matching; BA-004 WF-024 marks it `CONFIRMED` before matching in WF-025 | Next BA-004 revision |

## Sources

All sources are inside this repository; no external facts are introduced.

| # | Source | Used for |
| --- | --- | --- |
| R1 | [PRD-000 v0.9](PRD-000_master_prd_v0.9.md) Module 04 (FR-04-09…11, BR-04-3, BR-04-5, points 11, 14, 15, 17, 18), Module 05 (FR-05-01…03, -07, -11, BR-05-4, points 7, 11, 18), Module 10 FR-10-02, Ch 5 (US-STL-01), Ch 9 | Re-keyed requirements, rules, stories, criteria, labels |
| R2 | [BA-001](../02_business_architecture/BA-001_business_capability_map.md) D06, §4, §5 C2, C3 | Capabilities and boundaries |
| R3 | [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-004, WF-015, WF-018, WF-023, WF-024, WF-025, §5.2 | Workflows |
| R4 | [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md) §3, §4, §5 | Rights, approvers, SoD |
| R5 | [PRD-005](PRD-005_order_management.md) §2, §4.3, §9, §13 | D05 boundary; open points C4, C5, C9 |
| R6 | [DA-000](../05_data_architecture/DA-000_data_and_database_architecture_v0.9.md) Ch 1 principle 3, Ch 2, Ch 7; DDL-000 v0.9 (`execution.fill`, `trading.block_allocation`, `settlement.trade`) | Schema ownership, existing tables |
| R7 | [LOOP_STATE.md](../../LOOP_STATE.md) owner decisions D-3, D-18 | Building on Drafts; SoD waivers |
