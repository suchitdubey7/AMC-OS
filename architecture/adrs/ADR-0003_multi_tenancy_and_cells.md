---
id: ADR-0003
title: Multi-tenancy: tenant context from identity, PostgreSQL RLS, composite tenant keys, cell-based deployment
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: D01 + all
related: DA-000 Ch 6, DDL-000 §16, DBT-000 T1
---

# ADR-0003 — Multi-tenancy: tenant context from identity, PostgreSQL RLS, composite tenant keys, cell-based deployment

## Context
Shared SaaS and dedicated AMC deployments must run one codebase (master prompt §6). Isolation must cover auth, services, DB, APIs, events, storage, caches, AI retrieval, logs, analytics, backups and support tools, and tenant context must come from authenticated identity.

## Decision
1. **Identity-derived context:** the API gateway takes `tenant_id` only from the signed token; any request parameter that disagrees is rejected.
2. **Database:** every tenant table has `tenant_id` as the leading primary-key column; every foreign key is composite `(tenant_id, id)`; RLS is enabled and forced on every tenant table and partition; context set per transaction with `SET LOCAL`; missing context returns no rows.
3. **Other layers:** per-tenant object-storage prefix/bucket and KMS key; cache keys prefixed by tenant; events carry tenant_id and consumers set context from it; vector retrieval filtered by session tenant; logs tagged; analytics tables partitioned by tenant.
4. **Cells:** an application cell = app instances + PostgreSQL cluster + analytics + storage + keys for a group of tenants (shared) or one tenant (dedicated). A separate control plane holds tenant registry, placement, release and configuration, and never stores customer financial data.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Database per tenant only | Costly at small scale; offered as dedicated tier instead |
| Schema per tenant | Migration fan-out; weak for 50 tenants × 23 schemas |
| App-level filtering only | One missed WHERE clause leaks data |

## Consequences
Defence in depth; small runtime cost of RLS; every new table must call `platform.apply_tenant_rls()`.

## Validation
DBT-000 T1a–T1g pass (already green on PostgreSQL 16.15); CI catalogue check (no tenant table without forced policy); API, cache, storage and AI leakage suites (WP4/WP6).
