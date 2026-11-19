---
id: ADR-0006
title: Events via transactional outbox and Kafka; long-running business workflows on Temporal
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: all
related: master prompt §5 L4, WF-001…WF-017
---

# ADR-0006 — Events via transactional outbox and Kafka; long-running business workflows on Temporal

## Context
Domains must react to each other without cross-domain writes; some business processes run for hours or days (NAV day, NFO, commission month, breach cure) and must survive restarts.

## Decision
1. Each module writes business rows and an outbox row in one transaction; a relay publishes to Kafka with schema-registry-validated payloads; consumers are idempotent by event ID; failures go to dead-letter topics with alerting.
2. Event names follow the catalogue (`NAV_APPROVED.v1` etc.) stored in `contracts/events/`; breaking changes create a new version.
3. Temporal runs durable workflows that span modules and human approvals (daily NAV, NFO, settlement fails, breach resolution, commission run). Workflows call module APIs; they never write module tables directly.
4. Kafka is introduced only where asynchronous fan-out is needed; in-process events suffice inside the monolith until then.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Direct dual writes (DB + broker) | Inconsistency on failure |
| Cron + status columns for long processes | Fragile retries, poor visibility |

## Consequences
Two extra platform components (Kafka, Temporal) to operate; strong reliability and auditability of processes.

## Validation
Chaos tests: kill relay/consumer/workflow worker mid-process; no lost or duplicated financial effect.
