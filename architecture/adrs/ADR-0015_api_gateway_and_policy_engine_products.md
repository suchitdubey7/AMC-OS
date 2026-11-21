---
id: ADR-0015
title: Product choice for API gateway and policy engine (open)
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D01
related: EA-106; ADR-0012
---

# ADR-0015 — Product choice for API gateway and policy engine (open)

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
ADR-0012 proposes a central policy engine; EA-100 L2 needs an API gateway. Candidates: Kong or an Envoy-based gateway or a cloud gateway; OPA or Cedar or in-app rules. Licence editions and the cloud choice (Q5) affect the decision.

## Decision
**Open — no product selected.** Evaluation criteria: OIDC support, per-tenant rate limits, plugin model, licence terms, operational footprint, decision-log export, latency. Leading candidates for evaluation: Kong (gateway) and OPA (policy). To be decided after Q5 (cloud) and Q6 (IdP).

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Decide the products now | Removes uncertainty early | Depends on unanswered cloud (Q5) and IdP (Q6) questions | Premature |

## Consequences
Until decided, designs refer to 'API gateway' and 'policy engine' generically.

## Validation
Proof of concept against criteria in GOV-006 Step 10.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-20 | Draft | Claude (AI author) for project owner | Created as proposal (EA-100 set) |
