---
id: DA-100
title: Data and Decision Intelligence — Proposal
status: Draft
version: 0.1
owner: Chief Data Officer
approver: Project owner (interim ARB)
work_package: WP3/WP4 (proposal)
last_updated: 2026-11-20
---

# DA-100 — Data and Decision Intelligence (Proposal)

> **PROPOSAL** — part of the [EA-100](../04_enterprise_architecture/EA-100_ai_orchestration_architecture_proposal.md) set. Builds on ADR-0007 (data stores, Draft) and DA-000.

**LLMs must never be the source of numerical truth.** Every number an agent shows comes from a deterministic engine or a certified metric, with its source and as-of time.

## 1. Data layers

| Layer | Content | Store | Who writes |
| --- | --- | --- | --- |
| Operational | Domain records (orders, positions, journals…) | PostgreSQL per domain schema | Owning domain only |
| Projections | Copies from external SoRs (EA-101 mode E) | PostgreSQL | Adapters |
| Analytical | Facts and dimensions for dashboards | ClickHouse (when justified, EA-106) | Data pipelines |
| Semantic / metrics | Certified metric definitions | Metric registry (§2) | Data platform with business approval |
| Documents and vectors | Files, embeddings with source metadata | Object store + pgvector | Document pipeline |

## 2. Metric registry

| Field | Rule |
| --- | --- |
| `metric_id` | e.g. `MET-AUM-CLOSING` (prefix MET-, GOV-001 §4) |
| `name`, `definition` | Plain-language definition |
| `formula` | Deterministic, in a versioned expression or code reference; no AI-generated formulas in production |
| `dimensions` | Allowed slices (scheme, plan, distributor, region, date) |
| `source` | Tables / engines it reads; SoR mode of each |
| `calculation_version` | Changes create a new version; old results keep their version |
| `effective_date` | From when the version applies |
| `owner` | Business owner |
| `approval` | Approved by owner + data governance (maker ≠ checker) |
| `certification_status` | Draft / Certified / Deprecated — agents may use **Certified** only |
| `regulatory_basis` | If defined by regulation, the reference (labelled [REG] only once confirmed with a source) |

## 3. Decision intelligence pattern

1. Deterministic layer produces numbers (engines, certified metrics).
2. Agents explain, compare and draft — citing metric ID, version and as-of.
3. Humans decide; decisions are recorded with the numbers shown at the time.

## 4. ML models (forecasts, anomaly scores)

Allowed as **advisory signals** (e.g. redemption forecasts, churn scores), labelled as estimates, never as booked or published figures. Model governance (validation, drift, owner) is required before use and is to be specified in WP6 (GOV-006 Step 26, AIML-002; gap 11).

## 5. Open items

Metric list per workspace (WP2 Step 2 onward); which metrics are regulatory definitions (e.g. AUM categories) **[VAL — Compliance to confirm]**.
