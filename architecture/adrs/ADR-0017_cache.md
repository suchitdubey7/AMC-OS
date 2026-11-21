---
id: ADR-0017
title: Cache — a Redis-protocol cache running Valkey (managed), never a source of truth
status: Draft
date: 2026-11-21
deciders: ARB (interim: project owner)
domains: all
related: EA-002 §5.4, §7; DA-000 Ch 1, §6.6; ADR-0003; ADR-0007; master prompt §13
---

# ADR-0017 — Cache: a Redis-protocol cache running Valkey (managed), never a source of truth

> Written by the build loop (GOV-006 Step 10). Draft proposal for the owner.

## Status
Draft

## Context
- Master prompt §13 names Redis as the default cache; §3.4 requires tenant isolation in caches; §13 asks for the smallest reliable set and an ADR per technology.
- DA-000 Ch 1 plans a Redis cache for session data, the security-master hot set, the restricted list, rate limits, short-lived idempotency keys and job locks, with `t:{tenant_id}:` key prefixes (§6.6).
- Needs from the PRDs: restricted-list change effective in every OMS session within 5 s (NFR-PERF-003); security lookup p95 < 50 ms (NFR-PERF-002); pre-trade check p95 < 300 ms (NFR-PERF-010).
- Licence facts checked on 21 Nov 2026: Redis added the OSI-approved AGPLv3 as an additional licence option starting with Redis 8 (1 May 2025) ([Redis blog](https://redis.io/blog/agplv3/)); after Redis Inc. changed its licence in 2024 the community continued the code as **Valkey** under the Linux Foundation with the BSD 3-clause licence, and AWS added Valkey to its managed ElastiCache and MemoryDB services ([AWS open-source blog, 4 Apr 2024](https://aws.amazon.com/blogs/opensource/why-aws-supports-valkey)). Both speak the same protocol, so application client code does not depend on the choice.

## Decision
1. **Product.** Use a Redis-protocol cache running **Valkey**, as the cloud provider's managed service in shared cells (ADR-0018) and as a managed or self-run Valkey in dedicated cells. Application code uses a standard Redis-protocol client and no product-only features, so Redis 8 (AGPLv3 or commercial) stays a drop-in alternative. Availability of the managed Valkey service in AWS Hyderabad (disaster-recovery region) to be confirmed **[VAL — confirm with AWS]**.
2. **Never a source of truth.** Everything in the cache can be rebuilt from PostgreSQL or the owning module. Losing the cache may slow AMC OS; it must never change a financial result.
3. **What may be cached:** sign-in session and token-check results; permission-grant lookups (short life, invalidated on grant change); security-master and scheme hot sets; restricted list (pushed on change to meet NFR-PERF-003); per-tenant rate-limit counters; fast duplicate checks in front of PostgreSQL. **Changed from DA-000 Ch 1:** idempotency keys and locks for financial work are recorded in PostgreSQL (unique keys, advisory locks) or Temporal; the cache holds at most a copy. Reason: a cache entry can be evicted or lost on failover, and a lost idempotency key could let a payment or order be processed twice.
4. **What may not be cached:** investor personal data in clear text; secrets; anything an engine uses as input for an official number unless read through the owning module with its version.
5. **Isolation.** Every key starts with `t:{tenant_id}:`; the shared client library refuses unprefixed keys and keys whose tenant differs from the request context (DA-000 §6.6; negative test 8 in §6.10). TLS in transit and encryption at rest on. Dedicated cells get their own cache cluster.
6. **Expiry.** Every key has a time-to-live; values set per use in EA-003 / DBE-002.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Redis 8 (AGPLv3 or commercial) | Original project; newest features | AGPL terms need legal review for a SaaS product **[VAL]**; commercial licence costs | Kept as a protocol-compatible alternative |
| No cache (PostgreSQL only) | Smallest set | Harder to meet NFR-PERF-003 push and per-tenant rate limits without extra tables and polling | Cache is cheap when managed and never authoritative |
| In-process memory only | No extra component | Not shared across application instances; restricted-list change would not reach every session | Fails NFR-PERF-003 with more than one instance |

## Consequences
- Positive: meets the latency needs; open licence; managed service reduces operations.
- Negative: one more component per cell; cache invalidation for grants and restricted list must be tested.
- Follow-up: cache client library with the tenant-prefix guard (platform foundation increment); DA-000 Ch 1 idempotency row to be updated in DA-001 (Step 15).

## Validation
DA-000 §6.10 negative test 8 (cache); chaos test — flush the cache during an order run and a NAV run: no duplicate or wrong financial effect; NFR-PERF-003 measured with several application instances.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-21 | Draft | Claude (build loop) for project owner | Created in GOV-006 Step 10 |
