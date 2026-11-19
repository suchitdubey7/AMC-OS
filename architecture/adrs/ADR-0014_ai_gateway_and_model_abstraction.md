---
id: ADR-0014
title: AI gateway with model abstraction, data-class routing and egress control
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D17
related: SEC-100 §6; ADR-0008 decision 4; INT-100
---

# ADR-0014 — AI gateway with model abstraction, data-class routing and egress control

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
Model providers change quickly, and tenants may restrict where data goes. Agents must not depend on one provider, and no financial workflow may wait on AI.

## Decision
**Proposed:**
1. All model calls pass through an AI gateway in each cell: provider abstraction, per-data-class routing, redaction, budgets, logging.
2. Providers and models are allow-listed per tenant and data class; contracts must exclude training on tenant data **[VAL]**.
3. The gateway is isolated from financial processing; its failure degrades AI only (EA-105).
4. Provider choice and data residency are owner decision O-4.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Call providers directly from agents | No central redaction, budget or audit |
| Self-host only | Capability and cost trade-off; may be allowed per tenant later |

## Consequences
Positive: provider independence. Negative: another component to run.

## Validation
Redaction tests; failover tests; chaos test with gateway down during NAV run (as ADR-0008).

## Change log
| Date | Change |
| --- | --- |
| 2026-11-20 | Created as proposal (EA-100 set) |
