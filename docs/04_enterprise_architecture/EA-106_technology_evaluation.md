---
id: EA-106
title: Technology Evaluation for AI Orchestration — Proposal
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 (proposal; input to GOV-006 Step 10 ADRs)
last_updated: 2026-11-20
---

# EA-106 — Technology Evaluation (Proposal)

> **PROPOSAL** — part of the [EA-100](EA-100_ai_orchestration_architecture_proposal.md) set. These are evaluations, **not approved selections**. Where an existing Draft ADR already covers a technology, this document refers to it and does not re-decide it.

Scoring: **Fit** = how well it meets AMC OS needs; **Risk** = adoption/operational risk. Both H/M/L. Licence facts must be re-checked at ADR approval **[VAL]**.

| Area | Candidate | Existing ADR | Fit | Risk | Main reasons | Alternatives | Proposed ADR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Backend | FastAPI (Python) | ADR-0004 | H | L | Typed APIs, OpenAPI generation, Python data/AI ecosystem | Django, Java/Spring | — (covered) |
| Frontend | React + TypeScript | none | H | L | Large ecosystem, typed contracts from OpenAPI | Angular, Vue | Step 10 |
| Transactional DB | PostgreSQL 16+ | ADR-0004, 0007 | H | L | RLS, NUMERIC, tested in DBT-000 | — | — |
| Analytics DB | ClickHouse | ADR-0007 | H | M | Fast aggregates for dashboards; needs ops skill | PostgreSQL only at pilot scale | — |
| Workflows | Temporal | ADR-0006 | H | M | Durable, auditable workflows; fits EA-102 | Camunda, custom state tables | — |
| Events | Kafka | ADR-0006 | M | M | Needed at multi-cell scale; heavy for pilot | Outbox + PostgreSQL queue first | — (OD-7) |
| Agent runtime | LangGraph | none | H | M | Explicit graph/state, checkpoints, human-interrupt nodes, model-agnostic | Custom orchestrator, other frameworks | **ADR-0010** |
| MCP | Official MCP SDKs (Python, TypeScript) | none | H | M | Open protocol; official Python and TypeScript SDKs with OAuth-based authorization support; new specification revision dated 2026-07-28 ([MCP blog, SDK tag](https://blog.modelcontextprotocol.io/tags/sdk/); [Python SDK authorization docs](https://py.sdk.modelcontextprotocol.io/authorization/)) | Plain REST tools only | **ADR-0011** |
| Dataframes | Polars | ADR-0007 | H | L | Fast, deterministic; not for money rounding (Decimal in engines) | pandas | — |
| Vectors | pgvector | ADR-0007 | H | L | PostgreSQL extension on a separate PostgreSQL cluster (ADR-0007); RLS applies to embeddings | Dedicated vector DB | — |
| API gateway | Kong (or equivalent) | none | M | M | Rate limits, auth plugins; licence edition matters | Envoy-based, cloud gateway | **ADR-0015** |
| Policy engine | OPA (or equivalent) | none | H | M | Policy as code, versioned bundles, decision logs | Cedar, in-app rules | **ADR-0012 / 0015** |
| Object store | S3-compatible | ADR-0007 | H | L | Documents, files, object lock for evidence | — | — |
| Identity | OIDC; Keycloak as one option | none | M | M | Standards-based; Keycloak self-hosted vs managed IdP | Cloud IdP, customer IdP federation | Step 10 (Q6) |
| Containers | Docker images | none | H | L | Standard | — | Step 10 |
| Infrastructure as code | Terraform (or OpenTofu) | none | H | M | Repeatable cells; licence change history to consider | Pulumi, cloud-native | Step 10 |
| Observability | OpenTelemetry + Prometheus + Grafana | none | H | L | Vendor-neutral traces across agent → tool → service | Commercial APM | Step 10 / AIML-103 |

## Unresolved

- Kafka timing (OD-7); gateway and policy engine products (OD-5, OD-6); IdP (Q6); cloud (Q5); model providers (OD-4).
- Smallest-viable set for the pilot vs full design (master prompt "cost efficiency"): this evaluation *suggests* re-examining when Kafka and ClickHouse are introduced. Kafka timing is already open under ADR-0006 ("where justified"). ClickHouse is part of ADR-0007; changing its timing would need a new ADR in Step 10 (EA-100 C13). Nothing is re-decided here.
