---
id: ADR-0008
title: AI may read, explain and propose; it can never approve, post, publish or execute
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: D17 + all
related: master prompt §3.1, §11; GOV-003
---

# ADR-0008 — AI may read, explain and propose; it can never approve, post, publish or execute

## Context
Principle 3.1: LLMs must never be the source of truth for financial numbers and must never independently execute, approve, publish or modify financial records. AI failure must not interrupt financial processing.

## Decision
1. Agents run under service identities with no approve/override/post/publish/execute permissions (enforced in identity and by DB trigger on approvals — DBT-000 T5b).
2. Agents read numbers only through tools that call deterministic engine APIs; a grounding checker blocks answers containing numbers not present in tool outputs.
3. Agents create *proposals* that enter the target module's normal human approval workflow.
4. The AI gateway is isolated: no financial workflow waits on an AI call; if the gateway is down, financial processing continues.
5. Retrieval is tenant-filtered by the platform, not by prompt; sources keep document, version, effective date, page, URL, extraction time and approval status.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| AI auto-actions with post-hoc review | Violates principle 3.1 |

## Consequences
Lower automation ceiling; high trust and auditability.

## Validation
Permission tests; grounding tests; red-team suite (prompt injection, cross-tenant); chaos test with AI gateway down during NAV run.
