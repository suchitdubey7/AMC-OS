---
id: ADR-0010
title: One agent runtime with a supervisor, specialist and utility agents as logical roles
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D17
related: AIML-100, AIML-101; ADR-0008
---

# ADR-0010 — One agent runtime with a supervisor, specialist and utility agents as logical roles

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
The owner's architecture names a supervisor, 13 specialist and 7 utility agents. Running each as a separate service would multiply cost and operations for 20–50 tenants. PRD-000 Ch 9 lists 11 agents.

## Decision
**Proposed:**
1. Agents are logical roles defined in the agent registry; one stateless runtime (per cell) executes them.
2. The supervisor classifies, plans, delegates, merges and enforces grounding; specialists may call utility agents; delegation depth ≤ 2.
3. LangGraph is the proposed runtime framework (explicit state graph, checkpoints, human-interrupt points, model-agnostic), wrapped behind an internal interface so it can be replaced.
4. All agent permissions follow ADR-0008 and SEC-100.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| One microservice per agent | High cost and ops load; no isolation benefit since tools are the boundary |
| Custom orchestrator | More code to own; LangGraph covers checkpoints and interrupts |
| Single general agent | Weak separation of permissions and evaluation |

## Consequences
Positive: cheap to add agents; uniform audit. Negative: dependency on LangGraph's release pace; mitigated by internal interface.

## Validation
Prototype in WP5 with two agents; evaluation suites; load test per cell.

## Change log
| Date | Change |
| --- | --- |
| 2026-11-20 | Created as proposal (EA-100 set) |
