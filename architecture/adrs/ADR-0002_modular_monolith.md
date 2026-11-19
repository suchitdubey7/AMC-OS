---
id: ADR-0002
title: Start as a modular monolith with schema-per-domain ownership
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: all
related: STD-001 §2, DA-000 Ch 2
---

# ADR-0002 — Start as a modular monolith with schema-per-domain ownership

## Context
22 domain services are required (master prompt §5 L3). The brief warns against microservices for their own sake. Financial workflows need strong consistency inside a domain.

## Decision
One deployable Python/FastAPI application with one package per domain under `src/`. Each package owns exactly one PostgreSQL schema and connects with its own DB role that can write only that schema. Modules talk through public service interfaces and domain events; import rules are enforced by architecture tests. A module is extracted into its own service only when an ADR shows a need for independent scaling, a stronger security boundary, a different reliability or release cadence, a different runtime, or separate team ownership.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Microservices from day one | Distributed transactions, operational overhead, slower delivery, no proven need |
| Unstructured monolith | Boundaries erode; later extraction impossible |

## Consequences
Simple deployment and ACID inside the monolith; extraction is mechanical later. Requires discipline enforced by CI.

## Validation
`import-linter` contracts green; DB grant tests show each module role cannot write other schemas.
