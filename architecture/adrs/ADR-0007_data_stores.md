---
id: ADR-0007
title: Data stores: PostgreSQL, ClickHouse, S3-compatible storage, pgvector, Polars
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: D16 + all
related: DA-000 Ch 1, 8, 9
---

# ADR-0007 — Data stores: PostgreSQL, ClickHouse, S3-compatible storage, pgvector, Polars

## Context
Master prompt §5 L6 forbids forcing all workloads into one database.

## Decision
PostgreSQL = system of record for transactions. ClickHouse = analytics and long history. S3-compatible storage = documents, raw inbound files (immutable), evidence, archives (Iceberg/Parquet). pgvector on a separate PostgreSQL cluster = governed retrieval to start. Python + Polars = data processing; Airflow or Dagster chosen by ADR with DA-002 (GOV-006 Step 19, WP4), because the choice depends on the ingestion design (EA-002 §8). *(Timing changed 21 Nov 2026 on the project owner's instruction; was "in WP3".)*

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Single PostgreSQL for everything | Analytical scans compete with OLTP; storage bloat |
| Cloud warehouse instead of ClickHouse | Kept as an option for dedicated customers who require it |

## Consequences
Clear separation; extra pipelines to maintain; lineage required across stores.

## Validation
Data platform increment: lineage from raw file to dashboard cell demonstrated.
