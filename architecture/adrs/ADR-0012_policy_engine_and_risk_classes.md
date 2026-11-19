---
id: ADR-0012
title: Central policy engine with four-dimension authorisation and R0–R3 risk classes
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D01, D17 + all (D01–D17)
related: SEC-100, SEC-101; ADR-0008
---

# ADR-0012 — Central policy engine with four-dimension authorisation and R0–R3 risk classes

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
Agent actions must be allowed only when the user, the agent, the tenant and the tool all permit them. Scattered permission checks in code are hard to audit.

## Decision
**Proposed:**
1. A central policy engine evaluates every tool call and every R2/R3 action on four dimensions (user, agent, tenant, tool) using RBAC + ABAC.
2. Risk classes: R0 public; R1 authorised read; R2 controlled write (drafts/proposals) with policy and human queue; R3 critical action by humans only with maker-checker and deterministic validation.
3. No R3 tool exists for agents. The engine fails closed.
4. Policies are versioned, signed bundles; decisions are logged.
5. Product choice (OPA or equivalent) is left to ADR-0015.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Permission checks inside each service only | No new component | Inconsistent; hard to prove to auditors | Control evidence matters more than one fewer service |
| Agents get the user's full permissions | Simple | Breaks ADR-0008; an injected prompt could act as the user | Unsafe |

## Consequences
Positive: provable control. Negative: policy authoring skill needed; latency budget per call.

## Validation
Policy unit tests; forbidden-action suite (SEC-100 §8); fail-closed test.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-20 | Draft | Claude (AI author) for project owner | Created as proposal (EA-100 set) |
