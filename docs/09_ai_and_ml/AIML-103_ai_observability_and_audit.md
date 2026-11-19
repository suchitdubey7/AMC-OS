---
id: AIML-103
title: AI Observability and Audit — Proposal
status: Draft
version: 0.1
owner: Head of AI
approver: Project owner (interim ARB)
work_package: WP5 (proposal)
last_updated: 2026-11-20
---

# AIML-103 — AI Observability and Audit (Proposal)

> **PROPOSAL** — part of the [EA-100](../04_enterprise_architecture/EA-100_ai_orchestration_architecture_proposal.md) set.

## 1. What is recorded for every agent run

| Item | Stored where | Retention |
| --- | --- | --- |
| Run ID, correlation ID, tenant, user, agent ID@version, prompt version, model + version | `ai` schema (session/run tables, PRD-000 §9) | Per records policy **[REG — confirm SEBI record-keeping period]** |
| User input (masked per class) | `ai` schema | Same |
| Plan and delegation tree | `ai` schema | Same |
| Every tool call: tool@version, policy decision + reason, inputs/outputs (masked), latency, status | Tool-call log (insert-only) | Same |
| Retrieved documents: ID, version, page, effective date | `ai` schema | Same |
| Output, grounding-check result, citations | `ai` schema | Same |
| Proposals created (target module, record ID) | Target module + audit | Same |
| Tokens, cost, latency | Metrics store | 13 months **[ASSUMPTION]** |

All rows carry `tenant_id` and follow RLS. Policy decisions and proposals also go to the hash-chained audit log (DDL-000 `audit` schema).

## 2. Tracing

OpenTelemetry spans: user request → supervisor → agent → policy decision → tool → domain service → adapter → provider. Span attributes contain IDs and timings only; payloads stay in the data plane (EA-103 CP-3).

## 3. Quality monitoring

| Metric | Target source |
| --- | --- |
| Groundedness (numbers traced to tool outputs) | 100% enforced by checker; failures counted |
| Citation accuracy | PRD-000 §9.3 targets per agent |
| Schema-failure rate | Alert above threshold **[DES]** |
| Policy denials by reason | Security review weekly |
| Human acceptance rate of proposals | Business owner review |
| Injection detections | Security |

## 4. Cost control

Per-tenant monthly budget and per-agent limits in the registry (AIML-101). At 80% budget: alert; at 100%: non-essential agents pause (deterministic functions unaffected).

## 5. Audit questions the system must answer

1. Who asked what, which agent answered, using which model and prompt version?
2. Which data did it see, and was the user allowed to see it at that time?
3. Which tools did it call and what did the policy engine decide?
4. Which human acted on its proposal, and what changed?
