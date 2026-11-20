---
id: PRD-005
title: Order Management System (D05) — Product Requirements
status: Draft
version: 0.1
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 7
last_updated: 2026-11-20
---

# PRD-005 — Order Management System (D05)

This document states what AMC OS must do to take an investment decision to a validated, compliance-checked, approved order and release it to the dealing desk, with a complete audit trail. It re-keys the **order part** of PRD-000 v0.9 Module 04 to the GOV-001 identifiers (`FR-04-nn` → `FR-D05-nnn`, `BR-04-n` → `BRL-D05-nnn`, `US-OMS-0n` → `US-D05-nnn`). The execution part of Module 04 (fill capture, block allocation, trade confirmation, raw broker messages) belongs to D06 Trading and Execution (GOV-001 §3, BA-001 D06) and is re-keyed in PRD-006 (Step 8).

**Builds on Draft documents:** [PRD-000 v0.9](PRD-000_master_prd_v0.9.md) Module 04, Chapter 4 (W4, W5), Chapter 5, Chapter 6, Chapter 7; [BA-001](../02_business_architecture/BA-001_business_capability_map.md) D05, D06, §4; [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-004, WF-005, WF-006, WF-024; [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md); [PRD-003](PRD-003_investment_management.md), [PRD-004](PRD-004_portfolio_management.md); `database/ddl/DDL-000_core_schema_v0.9.sql` (order state machine) — allowed by owner decision D-3 ([GOV-008](../00_governance/GOV-008_build_loop.md) §2 rule 3). No document used here is Approved.

**What this document is not:** compliance rule evaluation (D08, FE-04 — D05 calls the check and acts on the result, never holds rule logic, BA-001 §4), execution and allocation (D06, PRD-006), broker message formats (INT-001, Step 14 — FIX per broker is an **[ASSUMPTION]**, BA-004 WF-004), table definitions (Steps 15–16) or API contracts (Step 24). It adds **no new regulatory fact**.

## 1. Scope

| In scope (CAP) | Out of scope |
| --- | --- |
| CAP-D05-001 Order creation · CAP-D05-002 Order validation · CAP-D05-003 Order approval · CAP-D05-004 Order amendments · CAP-D05-005 Order cancellation · CAP-D05-006 Order routing · CAP-D05-007 Order status · CAP-D05-008 Order history · CAP-D05-009 Maker-checker · CAP-D05-010 Pre-trade compliance · CAP-D05-011 Post-trade compliance · CAP-D05-012 Order audit | Fill capture, block-fill allocation, allocation deviations, trade confirmation, broker messages and raw message archive (D06: CAP-D06-002, -004, -003, -006); externally booked trades (D06, WF-024); rule evaluation (D08) |

## 2. Identifiers and re-keying

| PRD-000 v0.9 Module 04 | Here | Note |
| --- | --- | --- |
| FR-04-01 … FR-04-08 | FR-D05-001 … FR-D05-008 | Same order; capability added; wording shortened. Changes of meaning are marked **(changed)** |
| FR-04-09 Execution capture, FR-04-10 Post-trade allocation, FR-04-11 Trade confirmation | → PRD-006 (D06), Step 8 | CAP-D06-002, CAP-D06-004, CAP-D06-003 |
| FR-04-12, FR-04-13, FR-04-14 | FR-D05-009, FR-D05-010, FR-D05-011 | |
| BR-04-1 … BR-04-4 | BRL-D05-001 … BRL-D05-004 | BR-04-3 is split: intent before execution here; allocation by intent in PRD-006 |
| BR-04-5 (raw broker messages kept) | → PRD-006 (CAP-D06-006) | |
| Module 04 point 17 "zero lost fills"; Ch 7 Throughput "50,000 fills/min platform" | → PRD-006 (CAP-D06-002) | Fill-side NFRs |
| US-OMS-01 … US-OMS-04 (Ch 5) | US-D05-001 … US-D05-004 | US-OMS-02's allocation criterion (Module 04 AC 50/30/20) moves to PRD-006 |
| Module 04 point 18 second criterion | AC-US-D05-005-1 | |
| — | FR-D05-012 … FR-D05-019, BRL-D05-005 … 008, US-D05-006 … 010 | **New** **[DES]** |

Priority: **M** must, **S** should; user stories **C** critical, **O** optional (PRD-000 Ch 3 and Ch 5).

## 3. Business requirements

| ID | Business requirement | Capabilities |
| --- | --- | --- |
| BR-D05-001 | No order reaches a broker unless it is valid, compliant (or properly overridden) and approved for its current version (TRACE-001 seed BR-D05-001: every order follows the approved lifecycle) | CAP-D05-002, -003, -007, -010 |
| BR-D05-002 | Every order can be traced from the investment decision to its execution, with every version, check and approval kept | CAP-D05-001, -008, -012 |
| BR-D05-003 | Orders from several schemes in the same security are treated fairly: allocation intent is fixed before execution | CAP-D05-006 |
| BR-D05-004 | The person who originates an order and the person who approves or executes it are different | CAP-D05-009 |

## 4. Functional requirements

Every requirement also obeys PRD-000 common rules C1–C8 (in particular C7: every order write accepts an `Idempotency-Key`).

### 4.1 Re-keyed from PRD-000 Module 04 (order part)

| ID (was) | Pri | Capability | Requirement |
| --- | --- | --- | --- |
| FR-D05-001 (FR-04-01) | M | CAP-D05-001 | **Order creation:** from a rebalance proposal (D04), from a model, manually, or by bulk upload. Fields: scheme, security, side (buy/sell; for derivatives buy/sell open/close), quantity or amount, order type, limit price, time-in-force, broker preference, decision record ID (mandatory, FR-D03-010), reason |
| FR-D05-002 (FR-04-02) | M | CAP-D05-001 (.2) | **Order types:** market, limit, stop-loss limit (where the broker supports it), VWAP / TWAP instruction (broker algorithm that spreads the order to match the volume- or time-weighted average price), negotiated (debt RFQ — request for quotes — or OTC, over the counter), primary market (IPO / bond issue application) **[IND]** |
| FR-D05-003 (FR-04-03) | M | CAP-D05-004, CAP-D05-005 | **Modification and cancellation:** amend quantity or price before full execution; cancel the unexecuted remainder; every change re-runs compliance |
| FR-D05-004 (FR-04-04) | M | CAP-D05-002 | **Validation:** lot size, tick size, price band, security status, settlement-holiday check (calendar master, FR-D01-038), sufficient holdings for sells (no short selling in cash equity), available projected cash for buys (D04 cash ladder). *Added here* **[DES]**: the security is in the scheme's approved universe and not on the restricted list (PRD-003 FR-D03-003, FR-D03-004), checked at creation and again at release |
| FR-D05-005 (FR-04-05) | M | CAP-D05-010 | **Pre-trade compliance:** synchronous call to D08 (WF-005); result PASS / WARN / BLOCK per rule; WARN needs acknowledgement text; BLOCK needs the override workflow |
| FR-D05-006 (FR-04-06) | M | CAP-D05-003 (.1) | **Approval hierarchy:** configurable matrix by order size (% of scheme net assets, notional), instrument (for example unlisted debt, derivatives) and soft-limit warnings; auto-approval within the fund manager's authority. Threshold values are tenant configuration **[ASSUMPTION — confirm: CIO of the pilot AMC]** |
| FR-D05-007 (FR-04-07) **(changed)** | M | CAP-D05-006 (.1), (.2) | **Block orders and broker selection:** combine same-security orders from several schemes into one block; record the pre-trade allocation intent; select the broker from the empanelled list (CAP-D06-001), within broker limits (% of turnover per broker) and the best-execution policy. *Changed:* PRD-000 FR-04-07 is titled "block orders and broker allocation"; allocating fills after execution is D06 (CAP-D06-004) |
| FR-D05-008 (FR-04-08) **(changed)** | M | CAP-D05-006 (.3) | **Release to execution:** release the order or block to D06 for routing to the broker; for debt, quotes from RFQ platforms or by phone entered by the dealer (at least N quotes per policy **[IND; VAL any regulatory minimum]**). *Changed:* PRD-000 said "FIX to broker OMS"; the broker message protocol is per broker **[ASSUMPTION]** and owned by D06 (CAP-D06-006) |
| FR-D05-009 (FR-04-12) | M | CAP-D05-011 | **Post-trade checks:** after allocation (D06), D08 runs full compliance on actual post-trade positions, including inter-scheme transfer checks; the result is shown on the order |
| FR-D05-010 (FR-04-13) | M | CAP-D05-007, CAP-D05-008, CAP-D05-012 | **Order lifecycle and audit trail:** every state transition is stored as an order event with actor, time and payload (as `trading.order_event` in DDL-000) |
| FR-D05-011 (FR-04-14) | M | CAP-D05-012 (.2) | **Dealing-room controls:** recorded-line reference captured for phone orders; link to the dealer's personal-trading pre-clearance **[REG — VAL]** |

### 4.2 Order state machine

From PRD-000 Module 04 and DDL-000 `trading.order_state_transition`, copied unchanged here; the gaps this PRD finds in it are open point C3:

`DRAFT → PENDING_COMPLIANCE → (COMPLIANCE_BLOCKED → OVERRIDE_REQUESTED → OVERRIDE_APPROVED | REJECTED) → PENDING_APPROVAL → APPROVED → RELEASED_TO_DESK → ROUTED → PARTIALLY_FILLED → FILLED → ALLOCATED → CONFIRMED → CLOSED`; side exits `CANCEL_REQUESTED → CANCELLED`, `EXPIRED`, `REJECTED_BY_BROKER`. Transitions not in the table are refused by the database trigger and the service. `ROUTED` and later states are set from D06 events (CAP-D05-007 (.2)).

### 4.3 New requirements **[DES]**

| ID | Pri | Capability | Requirement |
| --- | --- | --- | --- |
| FR-D05-012 | M | CAP-D05-003 (.2) | **Approval queue:** approvers see pending orders with the compliance result, decision record, size vs threshold and age; an order not approved within a configured time is escalated **[ASSUMPTION — confirm: CIO of the pilot AMC]** |
| FR-D05-013 | M | CAP-D05-004 (.1), (.2) | **Order versions:** an amendment creates a new order version; the new version passes validation, compliance and (if the threshold is crossed) approval again before it can be released (BRL-D05-004). After release, an amendment is sent to D06 as a cancel-and-replace or amend request, as the broker supports |
| FR-D05-014 | M | CAP-D05-005 (.2) | **Cancel confirmation:** a cancel request on a routed order stays `CANCEL_REQUESTED` until D06 reports the broker's confirmation; fills arriving meanwhile still count (DDL-000 allows `CANCEL_REQUESTED → PARTIALLY_FILLED / FILLED`) |
| FR-D05-015 | M | CAP-D05-007 (.2) | **Fill status:** fill quantity, average price and remaining quantity from D06 are shown on the order and on the block in real time |
| FR-D05-016 | M | CAP-D05-009 (.2) | **Emergency override for an out-of-universe security:** an order on a security not in the scheme's approved universe fails validation unless an emergency override approved by both the CIO and a Compliance Officer exists for that scheme and security (BRL-D03-001). The override is a separate approval request (CAP-D12-011) raised before the order is created or resubmitted; it is not the D08 compliance-override path (`OVERRIDE_REQUESTED`, SOD-04). A restricted-list BLOCK can never be overridden this way |
| FR-D05-017 | M | CAP-D05-010 (.1) | **What is checked:** the pre-trade check covers the order version together with the scheme's start-of-day holdings, today's executions and other pending orders (WF-005); a check with incomplete data returns `INDETERMINATE`, treated as BLOCK |
| FR-D05-018 | M | CAP-D05-006 (.2) | **Fixed allocation intent:** the allocation intent of a block (scheme and quantity or proportion) is recorded before release and cannot be changed after the first fill except through the D06 deviation approval (Head of Dealing and Compliance) |
| FR-D05-019 | S | CAP-D05-001 (.1) | **Bulk upload:** a file of orders is validated row by row; each valid row becomes a separate `DRAFT` order with the same decision record or its own; invalid rows are returned with reasons and nothing is created for them |

## 5. Business rules

| ID (was) | Rule | Label |
| --- | --- | --- |
| BRL-D05-001 (BR-04-1) | No order reaches a broker without a PASS (or acknowledged WARN) or an approved override from compliance for its current version. "Or acknowledged WARN" is added to BR-04-1 here, following FR-04-05 and W4 | **[DES]** (PRD-000 unlabelled) |
| BRL-D05-002 (BR-04-2) | The fund manager who originates an order cannot be the dealer on the same order (configurable; default on — SOD-03) | **[IND]** |
| BRL-D05-003 (BR-04-3, first part) | The allocation of a block is decided before execution (intent); allocating fills by that intent after execution is a PRD-006 rule | **[DES]**; fair allocation **[REG — VAL exact clause]** (PRD-000 FR-04-10) |
| BRL-D05-004 (BR-04-4) | An amended order is a new order version; the compliance result of v1 does not cover v2 | **[DES]** |
| BRL-D05-005 | An order cannot be created without a decision record (DDL-000 `trading.order.decision_id` is NOT NULL) | PRD-000 FR-02-10 **[REG — VAL clause]** |
| BRL-D05-006 | A compliance override needs two distinct approvers, from Compliance and Investment (CCO + CIO or delegates), and a reason | SOD-04 |
| BRL-D05-007 | The approver of an order is not its maker (SOD-01); an AI agent identity may draft orders but never submit, approve or release them (SOD-10) | SOD-01, SOD-10 |
| BRL-D05-008 | A late fill on a cancelled order is never dropped; it goes to the exception queue (CAP-D12-008) | PRD-000 Module 04 point 14 **[DES]** |

## 6. Workflows

| Workflow | D05 role | Requirements |
| --- | --- | --- |
| [WF-004](../02_business_architecture/BA-004_end_to_end_workflows.md) Order creation and execution | Order part (create → approve → release); D06 executes; DEP-02 / DEP-03 own creation, amendment, cancellation | FR-D05-001…008, FR-D05-010, FR-D05-012…019 |
| WF-005 Pre-trade compliance | Calls D08 and acts on the result | FR-D05-005, FR-D05-016, FR-D05-017, BRL-D05-006 |
| WF-006 Post-trade compliance | Shows the result on the order | FR-D05-009 |
| WF-003 Portfolio construction | Receives `DRAFT` orders from accepted proposals | FR-D05-001, BRL-D04-004 |
| WF-024 Externally booked trade capture | Pre-trade check on types that need one (CAP-D05-010) | FR-D05-005 |

No new workflow is needed: BA-004 §5.1 lists no D05 gap.

## 7. Permissions by capability

From BA-005 §3 (D05 column) and §4, split by capability. Roles with "R" in D05 (CEO, COO, CIO, CFO, Fund Manager, Dealer, Compliance Officer, Risk Manager, Fund Accountant, Operations Analyst, Auditor) read; the Fund Manager only for own schemes.

| Capability | Maker | Checker(s) |
| --- | --- | --- |
| CAP-D05-001 Order creation | Fund Manager (own; "R C U S own"); AI agent identity drafts only (SOD-10) | — |
| CAP-D05-002 Order validation | System | — |
| CAP-D05-003 Order approval | — | CIO above the threshold ("A J"); auto-approval within FM authority (`trading.order.approve`) |
| CAP-D05-004 Order amendments | Fund Manager (own) | As for a new order version |
| CAP-D05-005 Order cancellation | Fund Manager (own); Dealer for the unexecuted remainder of a released order ("R U") | — |
| CAP-D05-006 Order routing | Dealer (block, broker selection, intent — "R U (route, block, allocate)") | Head of Dealing when a debt order has fewer quotes than the policy minimum (US-D05-004)† |
| CAP-D05-007 Order status | System (from D06) | — |
| CAP-D05-008 Order history | System | — |
| CAP-D05-009 Maker-checker | — | CIO **and** Compliance Officer for an out-of-universe override (FR-D05-016) |
| CAP-D05-010 Pre-trade compliance | System; Fund Manager requests an override | CCO **and** CIO (or delegates) (`compliance.pretrade.override`, SOD-04) |
| CAP-D05-011 Post-trade compliance | System | — |
| CAP-D05-012 Order audit | System; Dealer records the recorded-line reference | — |

**Right added beyond BA-005 §3 (†) [DES]:** the Head of Dealing (approval authority on ROLE-08, BA-005 §4) as checker for releasing a debt order with too few quotes — PRD-000 US-OMS-04 requires it, but BA-005 §4 lists the Head of Dealing only for WF-004 allocation deviations, WF-023 and WF-025. To be carried into BA-005 (open point C7).

## 8. User stories and acceptance criteria

| ID | Story | Pri | Acceptance criteria (Given / When / Then) |
| --- | --- | --- | --- |
| US-D05-001 (was US-OMS-01) | As a Fund Manager, I want pre-trade results before submission | C | **AC-US-D05-001-1** Given an order, when it is created, then the compliance results return in < 500 ms p95. |
| US-D05-002 (was US-OMS-02) | As a Dealer, I want block orders with fair allocation | C | **AC-US-D05-002-1** Given a block of three scheme orders, when the dealer tries to release it without an allocation intent for every scheme, then release is refused. (The allocation-by-intent criterion of PRD-000 Module 04 moves to PRD-006.) |
| US-D05-003 (was US-OMS-03) | As Compliance, I want overrides with two approvers | C | **AC-US-D05-003-1** Given a BLOCK, when one approver approves, then the order stays blocked until the second approves. |
| US-D05-004 (was US-OMS-04) | As a Dealer, I want debt RFQ quote capture | O | **AC-US-D05-004-1** Given a debt order, when fewer than the policy minimum quotes are captured, then release needs Head of Dealing approval. |
| US-D05-005 (Module 04 point 18) | As Compliance, I want the order lifecycle enforced | C | **AC-US-D05-005-1** Given an order in `FILLED`, when a user tries to set it to `DRAFT`, then the transition is rejected and logged. |
| US-D05-006 | As a Compliance Officer, I want amended orders re-checked | C | **AC-US-D05-006-1** Given an order v1 with a PASS, when the quantity is amended, then v2 is in `PENDING_COMPLIANCE` and cannot be released until its own result is PASS, acknowledged WARN or overridden. |
| US-D05-007 | As a Compliance Officer, I want the FM never to execute own orders | C | **AC-US-D05-007-1** Given a user holding both Fund Manager and Dealer for the same scheme because SOD-03 was off when the roles were granted, and SOD-03 since switched on, when that user tries to route an order they originated, then it is refused with `SOD_VIOLATION` (defence in depth; the grant-time refusal is PRD-001 FR-D01-018). |
| US-D05-008 | As a CIO, I want every order linked to a decision | C | **AC-US-D05-008-1** Given an order request with no decision record, when it is sent, then it is refused at creation with `DECISION_RECORD_REQUIRED` and no order is stored. |
| US-D05-009 | As a Fund Manager, I want sells refused when the scheme does not hold enough | C | **AC-US-D05-009-1** Given a scheme holding 1,000 shares with a pending sell of 600, when a new sell of 500 is created in cash equity, then it fails validation (600 + 500 = 1,100 > 1,000). |
| US-D05-010 | As a CTO, I want duplicate submissions to have no effect | C | **AC-US-D05-010-1** Given an order created with an `Idempotency-Key`, when the same request is sent again with the same key, then no second order is created and the first order is returned. |

## 9. Exceptions

| Exception | Handling | Source |
| --- | --- | --- |
| Compliance BLOCK | Override workflow (SOD-04) or cancel | PRD-000 FR-04-05, WF-005 |
| Compliance data incomplete | `INDETERMINATE` = BLOCK | BA-004 WF-005 |
| Broker reject (`REJECTED_BY_BROKER`) | Dealer re-routes as a new release, or cancels | PRD-000 point 14 |
| Late fill after cancel | Exception queue (BRL-D05-008) | PRD-000 point 14 |
| Price outside band | Validation failure (FR-D05-004) | PRD-000 point 14 |
| Approval not given in time | Escalation (FR-D05-012) | new |
| Broker connection loss, sequence-gap recovery, duplicate fills | Handled in D06 (PRD-006) | PRD-000 point 14 |

## 10. Data and interfaces

**Owned schema:** `trading` (GOV-001 §3). No database change is made in this step.

| Exists in DDL-000 | Not yet in DDL-000, or to check (for DA-001 / DDL, Steps 15–16) **[DES]** |
| --- | --- |
| `trading.order`, `trading.order_event`, `trading.order_state_transition`, `trading.block_allocation` | Order versions with their compliance-result reference; approval-matrix configuration; override requests; bulk-upload batches; RFQ quotes (or in D06 — decide in EA-003); recorded-line references. **Check:** the DDL-000 state-machine and column gaps listed in open point C3 |

**Interfaces (indicative, not contracts):** PRD-000 Module 04 point 11 names `oms-svc` endpoints `/orders`, `/orders/{id}/amend`, `/orders/{id}/cancel`, `/blocks`, `/allocations`, `/executions` and a synchronous call to `compliance-svc /pretrade/check`; `/allocations` and `/executions` move to D06. Final paths and `API-D05-nnn` IDs: Step 24 (TRACE-001 seed `API-D05-001 POST /v1/orders`); events `oms.order.*`: EA-007 (Step 13).

## 11. Non-functional requirements

| ID | Requirement | Type / source |
| --- | --- | --- |
| NFR-PERF-007 | Order create to compliance result p95 < 500 ms | Proposed — PRD-000 Module 04 point 17, Ch 7 Performance |
| NFR-PERF-008 | 2,000 orders per minute per tenant at peak | Proposed — PRD-000 Module 04 point 17, Ch 7 Throughput |
| NFR-AUD-005 | Order event store; compliance result snapshot per order version; override evidence | PRD-000 Module 04 point 15 **[DES]** |

Availability of core trading-day services (PRD-001 NFR-AVAIL-001) applies to the OMS.

## 12. AI in this domain

Within PRD-000 C8 and ADR-0008 (read and propose only):

- **CIO copilot** (CAP-D17-003 (.2)) explains why an order was blocked (PRD-000 Module 04 point 16).
- **Dealing assistant** (CAP-D17-004) gives dealers order and execution context.
- Drafting orders is not given to any assistant yet (open point C8). Whatever drafts them, an AI agent identity never submits, approves or releases an order (BRL-D05-007).

## 13. Open points

| # | Point | Where closed |
| --- | --- | --- |
| C1 | Fair-allocation clause and dealing-room controls **[VAL]**; any regulatory minimum number of debt quotes **[VAL]** | REG-001 (Step 25) |
| C2 | Approval thresholds, escalation times, RFQ quote minimum — tenant configuration with no values **[ASSUMPTION]** | Pilot discovery |
| C3 | DDL-000 `trading` gaps against this PRD: (a) no transition back to `PENDING_COMPLIANCE`, and `order_version` sits on the order row, so no amendment is possible before or after release (FR-D05-013, AC-US-D05-006-1) — either add the transitions or make each version its own row; (b) no cancel from `PENDING_COMPLIANCE`, `PENDING_APPROVAL` or `OVERRIDE_*`; (c) no way out of `REJECTED_BY_BROKER` for a re-release; (d) no allocation path for partial fills of an order that ends `CANCELLED` or `EXPIRED`; (e) `PENDING_APPROVAL → APPROVED` must also cover auto-approval; (f) `side` allows only BUY / SELL, while derivatives need buy / sell open / close; (g) no state or table for the emergency out-of-universe override (FR-D05-016) | DDL (Step 16) |
| C4 | Whether RFQ quotes live in `trading` or `execution` | EA-003 (Step 11) |
| C5 | Whether a WARN acknowledgement needs a second person for some rules | PRD-008 (Step 8) |
| C6 | TRACE-001 seed row gives `FR-D05-013*` (provisional) for v0.9 FR-04-13; the re-key here makes it FR-D05-010 | TRACE-002 (Step 27) |
| C7 | The † right of §7 (Head of Dealing for too few debt quotes) is not yet in BA-005 | Next BA-005 revision |
| C8 | Drafting orders: PRD-000 gives it to a "Portfolio Agent", which is not in the brief's D17 list; no D17 assistant drafts orders yet | AIML-001 (Step 26) |

## Sources

All sources are inside this repository; no external facts are introduced.

| # | Source | Used for |
| --- | --- | --- |
| R1 | [PRD-000 v0.9](PRD-000_master_prd_v0.9.md) Module 04, Ch 4 W4–W5, Ch 5 (US-OMS-01…04), Ch 6 (SOD-03, SOD-04), Ch 7 | Re-keyed requirements, state machine, rules, stories, targets |
| R2 | [BA-001](../02_business_architecture/BA-001_business_capability_map.md) D05, D06, §4 | Capabilities; D05 / D06 boundary; compliance ownership |
| R3 | [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-003…WF-006, WF-024 | Workflows |
| R4 | [BA-005](../02_business_architecture/BA-005_roles_and_permissions.md) §3, §4, §5 | Rights, approvers, SoD |
| R5 | [TRACE-001](../00_governance/TRACE-001_traceability_matrix.md) §2 | Seed rows BR-D05-001, API-D05-001 |
| R6 | `database/ddl/DDL-000_core_schema_v0.9.sql` | `trading` tables and state transitions |
