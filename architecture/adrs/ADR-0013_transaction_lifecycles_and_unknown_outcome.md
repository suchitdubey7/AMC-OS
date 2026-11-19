---
id: ADR-0013
title: Separate order, execution, confirmation and settlement lifecycles with explicit UNKNOWN states
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D05, D06, D07
related: EA-102; EA-101; DDL-000 trading.order_state_transition
---

# ADR-0013 — Separate order, execution, confirmation and settlement lifecycles with explicit UNKNOWN states

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
Network failures can leave AMC OS unsure whether a broker, bank or custodian received an instruction. Blind resubmission can cause duplicate trades or payments. DDL-000 has one order state machine.

## Decision
**Proposed:**
1. Four separate records and lifecycles: order (AMC OS SoR), execution (broker/exchange), confirmation (broker/custodian), settlement (custodian/bank).
2. Explicit `UNKNOWN_SUBMISSION` and `UNKNOWN_CANCEL` states; from them only a provider status query is allowed; never blind resubmission.
3. Outbound release activities are never retried automatically; humans decide after query.
4. Every outbound instruction carries an idempotency key and client reference.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Single status field | Mixes facts owned by different systems |
| Automatic retry on timeout | Duplicate trades/payments risk |

## Consequences
Positive: no duplicate instructions; clear accountability. Negative: more states; providers without status queries need manual procedures.

## Validation
State-machine tests in DDL (WP4); integration tests with simulated timeouts; per-provider confirmation of status-query support.

## Change log
| Date | Change |
| --- | --- |
| 2026-11-20 | Created as proposal (EA-100 set) |
