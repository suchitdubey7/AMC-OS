---
id: EA-102
title: Transaction Orchestration — Proposal
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 (proposal; depends on WP2 and FE specs)
last_updated: 2026-11-20
---

# EA-102 — Transaction Orchestration (Proposal)

> **PROPOSAL** — part of the [EA-100](EA-100_ai_orchestration_architecture_proposal.md) set. Not approved. This document **keeps every state and transition in DDL-000 `trading.order_state_transition`** and adds only the unknown-outcome states (§2.1). No state is removed.

## 1. Principles

1. AI may **prepare** a transaction (draft). Only humans **submit, approve and release** it (SEC-101).
2. Deterministic validation runs before every state change that leaves AMC OS.
3. Every outbound instruction has an **idempotency key** and a **client reference** that the provider echoes back.
4. If AMC OS does not know whether a provider received an instruction, the state is **UNKNOWN**. From UNKNOWN the only allowed action is **query the provider**. Blind resubmission is forbidden.
5. Order, execution, confirmation and settlement are separate records with separate lifecycles and separate systems of record (EA-101).

## 2. Order lifecycle (AMC OS is SoR)

DDL-000 states are kept unchanged. **New** states are marked ★.

```mermaid
stateDiagram-v2
  [*] --> DRAFT: human or agent creates
  DRAFT --> PENDING_COMPLIANCE: human submits
  DRAFT --> CANCELLED
  PENDING_COMPLIANCE --> COMPLIANCE_BLOCKED: hard breach
  PENDING_COMPLIANCE --> PENDING_APPROVAL: pass / warnings acknowledged
  COMPLIANCE_BLOCKED --> OVERRIDE_REQUESTED: human requests override
  COMPLIANCE_BLOCKED --> CANCELLED
  OVERRIDE_REQUESTED --> OVERRIDE_APPROVED: compliance approves (human)
  OVERRIDE_REQUESTED --> REJECTED
  OVERRIDE_APPROVED --> PENDING_APPROVAL
  PENDING_APPROVAL --> APPROVED: checker (not maker, not AI)
  PENDING_APPROVAL --> REJECTED
  APPROVED --> RELEASED_TO_DESK: human
  APPROVED --> CANCELLED
  RELEASED_TO_DESK --> ROUTED: dealer routes; provider ACK received
  RELEASED_TO_DESK --> UNKNOWN_SUBMISSION: ★ no ACK / timeout
  RELEASED_TO_DESK --> CANCEL_REQUESTED
  UNKNOWN_SUBMISSION --> ROUTED: ★ status query finds order
  UNKNOWN_SUBMISSION --> RELEASED_TO_DESK: ★ query confirms not received; human may route again with same idempotency key
  UNKNOWN_SUBMISSION --> MANUAL_INVESTIGATION: ★ query fails or ambiguous
  ROUTED --> PARTIALLY_FILLED
  ROUTED --> FILLED
  ROUTED --> REJECTED_BY_BROKER
  ROUTED --> CANCEL_REQUESTED
  ROUTED --> EXPIRED
  PARTIALLY_FILLED --> PARTIALLY_FILLED
  PARTIALLY_FILLED --> FILLED
  PARTIALLY_FILLED --> CANCEL_REQUESTED
  PARTIALLY_FILLED --> EXPIRED
  CANCEL_REQUESTED --> CANCELLED
  CANCEL_REQUESTED --> PARTIALLY_FILLED
  CANCEL_REQUESTED --> FILLED
  CANCEL_REQUESTED --> UNKNOWN_CANCEL: ★ no response
  UNKNOWN_CANCEL --> CANCELLED: ★ query confirms
  UNKNOWN_CANCEL --> PARTIALLY_FILLED: ★ query shows partial fill
  UNKNOWN_CANCEL --> FILLED: ★ query shows filled
  UNKNOWN_CANCEL --> MANUAL_INVESTIGATION: ★ query fails or ambiguous
  MANUAL_INVESTIGATION --> ROUTED: ★ human confirms with provider
  MANUAL_INVESTIGATION --> RELEASED_TO_DESK: ★ human confirms not received
  MANUAL_INVESTIGATION --> PARTIALLY_FILLED: ★ human confirms
  MANUAL_INVESTIGATION --> FILLED: ★ human confirms
  MANUAL_INVESTIGATION --> CANCELLED: ★ human confirms
  FILLED --> ALLOCATED
  ALLOCATED --> CONFIRMED
  CONFIRMED --> CLOSED
  CANCELLED --> [*]
  REJECTED --> [*]
  REJECTED_BY_BROKER --> [*]
  EXPIRED --> [*]
  CLOSED --> [*]
```

### 2.1 Change to DDL-000 (proposed for WP4)

| Change | Rows to add to `trading.order_state_transition` |
| --- | --- |
| Unknown submission | RELEASED_TO_DESK→UNKNOWN_SUBMISSION; UNKNOWN_SUBMISSION→ROUTED / RELEASED_TO_DESK / MANUAL_INVESTIGATION |
| Unknown cancel | CANCEL_REQUESTED→UNKNOWN_CANCEL; UNKNOWN_CANCEL→CANCELLED / PARTIALLY_FILLED / FILLED / MANUAL_INVESTIGATION |
| Manual investigation exits (human only) | MANUAL_INVESTIGATION→ROUTED / RELEASED_TO_DESK / PARTIALLY_FILLED / FILLED / CANCELLED |

Note: DDL-000 keeps ALLOCATED and CONFIRMED on the order. This proposal keeps them for the order's own allocation step, and tracks the broker/custodian confirmation separately (§3). WP4 decides whether the order-level CONFIRMED stays or is derived from §3.

## 3. Execution, confirmation and settlement lifecycles (external SoR; AMC OS tracks)

| Lifecycle | States tracked by AMC OS | Source of truth | Driven by |
| --- | --- | --- | --- |
| Execution | RECEIVED_FILL · CORRECTED · BUSTED | Broker / exchange | FIX execution reports or broker files **[VAL per broker]** |
| Confirmation | AWAITING_CONFIRM · CONFIRMED · MISMATCH · AFFIRMED | Broker / custodian | Contract notes, custodian affirmation |
| Settlement | INSTRUCTED · PENDING · SETTLED · FAILED · PARTIALLY_SETTLED | Custodian / bank / clearing | Custodian status files or APIs **[VAL per custodian]** |

A fill never changes the order's approval history. A busted or corrected fill creates a new execution record; the old one is kept (insert-only).

## 4. Unknown-outcome procedure (all providers)

1. Mark the instruction `UNKNOWN_*`; freeze any automatic retry.
2. Run the provider's **status query** (order book, status API or file, as the provider supports) using the client reference.
3. Found → adopt the provider's state. Confirmed not received → back to the previous safe state (for orders: RELEASED_TO_DESK); a human may retry with the **same** idempotency key. Ambiguous → `MANUAL_INVESTIGATION` with an alert to the dealer desk and operations; only a human can move it out, after confirming with the provider.
4. Every step is audited with correlation ID.
5. If the provider offers no status query, the integration spec must say so and name the manual procedure; such a provider cannot be used for automated release **[VAL]**.

## 5. Same pattern for non-trade instructions

| Instruction | Provider | Unknown-outcome query |
| --- | --- | --- |
| Payment / fund transfer | Bank | Bank status enquiry by client reference **[VAL per bank]** |
| Settlement instruction | Custodian | Custodian instruction status **[VAL]** |
| Investor transaction push (if ever allowed) | RTA | RTA status report **[VAL]** |
| NAV file submission | AMFI (human-submitted) | Human checks submission status with AMFI **[VAL — confirm submission route with the pilot AMC's NAV team]** |

## 6. Workflow implementation (proposed)

Each lifecycle runs as a durable Temporal workflow (ADR-0006); activities that call providers are idempotent and record request and response; retries apply only to *safe* calls (reads, status queries). Routing activities are **not retried automatically**; failure moves to UNKNOWN_SUBMISSION.

## 7. Open items

- Which brokers support FIX vs file vs API for Indian AMC dealing desks — to be confirmed per pilot AMC (INT-100 §6).
- Whether partial-fill allocation is done in AMC OS or at the broker (WP2 dealing workflow).
