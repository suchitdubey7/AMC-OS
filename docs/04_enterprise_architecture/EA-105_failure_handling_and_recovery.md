---
id: EA-105
title: Failure Handling and Recovery for AI Orchestration — Proposal
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 (proposal)
last_updated: 2026-11-20
---

# EA-105 — Failure Handling and Recovery (Proposal)

> **PROPOSAL** — part of the [EA-100](EA-100_ai_orchestration_architecture_proposal.md) set.

Core rule: **AI failure must never stop or corrupt financial processing** (ADR-0008 decision 4). Financial workflows never wait on an AI call.

## 1. Failure catalogue

| # | Failure | Detection | Behaviour | Recovery |
| --- | --- | --- | --- | --- |
| F1 | Model provider down or slow | Timeout, error rate | Agent returns "assistant unavailable"; workspaces keep working without AI panels | Failover to secondary model if configured and approved for that data class; else wait |
| F2 | Model output malformed (fails schema) | Output schema validation | Retry once with same input; then fail closed | Logged; counted in agent quality metrics |
| F3 | Ungrounded number in answer | Grounding checker | Answer blocked; user sees "could not verify" | Logged as quality incident |
| F4 | Prompt injection detected | Input/retrieval scanners, tool-call anomaly | Tool call denied; session flagged | Security review (SEC-100) |
| F5 | Tool denied by policy | Policy engine | Agent explains what permission is missing; no workaround | User requests access through normal route |
| F6 | Tool timeout (read) | Timeout | Retry per tool registry policy (idempotent reads only) | Circuit breaker after N failures **[DES]** |
| F7 | Tool timeout (write, R2) | Timeout | Do not retry blindly; query by idempotency key | Same idempotency key guarantees one effect |
| F8 | Provider submission outcome unknown | No ACK / connection loss | UNKNOWN state (EA-102 §4) | Query provider; human decides |
| F9 | Adapter receives invalid data | Canonical schema validation | Record quarantined; nothing downstream consumes it | Data-quality exception queue |
| F10 | Event consumer fails | Retry exhaustion | Dead-letter queue | Replay after fix (idempotent consumers) |
| F11 | Workflow worker crash | Temporal | Workflow resumes from last completed activity | Automatic |
| F12 | Policy engine unavailable | Health check | **Fail closed** for R1–R3 (deny); R0 public content allowed | Restore; no bypass switch |
| F13 | Agent loops or exceeds budget | Step/token/time limits | Run stopped; partial result clearly labelled | Logged |
| F14 | Cross-tenant data appears in context | Tenant tag check on every retrieved item | Item dropped; run aborted; security incident | SEC-100 incident process |
| F15 | Control plane down | Health | Data planes continue; upgrades and config changes pause | EA-103 CP-6 |

## 2. Retry rules

- Reads and status queries: bounded exponential back-off with jitter.
- Writes inside AMC OS: retried only with the same idempotency key.
- Outbound financial instructions: **never auto-retried** (EA-102).
- AI generations: at most one automatic retry.

## 3. Degraded modes (shown to users)

| Mode | Trigger | What users see |
| --- | --- | --- |
| AI off | F1 / F12 / manual kill switch | Banner; AI panels hidden; all deterministic functions work |
| Read-only integration | Provider outage | Last-good data with "as of" timestamp |
| Manual dealing | Broker link down | Orders stay APPROVED; dealer uses broker's own channel per desk procedure; trades booked back with reference |

## 4. Kill switches

Per tenant and per agent, an authorised admin can disable an agent, a tool or all AI within one minute **[DES target]**. Disabling is R2 (fast, single approver); re-enabling is R3 (maker-checker).
