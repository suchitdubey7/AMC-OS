---
id: ADR-0009
title: Positioning of AMC OS and system-of-record ownership (options A/B/C)
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D01 + all (D01–D17)
related: EA-100, EA-101; PS-001, PS-002; master prompt §2
---

# ADR-0009 — Positioning of AMC OS and system-of-record ownership (options A/B/C)

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
The owner asked (20 Nov 2026) to position AMC OS as "the AI-native orchestration layer for asset management companies" that integrates existing systems rather than replacing them. PS-001/PS-002, the master prompt §2 and PRD-000 Modules 08/09 (all Draft) position AMC OS as a full platform that replaces fragmented systems and acts as scheme ledger and NAV publisher. Both views have support. AMCs typically already run RTA, accounting and NAV processes that they cannot switch off quickly **[ASSUMPTION — confirm in pilot AMC interviews (PS-003 follow-up); no pilot AMC is signed yet]**; some AMCs may want AMC OS to own domains where their current tools are weak **[ASSUMPTION — same]**.

## Decision
**Open — owner decision OD-1.** Three options are on the table: A (replace), B (orchestrate only), C (orchestrate first, own engines per tenant and per domain). This proposal **recommends C**:
1. AMC OS owns intent, orders, approvals, workflow, routing, compliance results and audit in every deployment.
2. For every other data object, a per-tenant, effective-dated system-of-record registry (EA-101) sets mode O (AMC OS owns), S (shadow) or E (external, read-only).
3. Defaults: execution → broker/exchange; settlement → custodian/bank; investor/folio → RTA; accounting → AMC's platform; NAV publication → AMC's NAV authority (default for accounting and NAV is decision OD-2). AMC OS engines remain available for tenants that choose mode O.
4. The platform enforces the registry: write tools for objects not in mode O are denied.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| A — Full replacement platform (current Draft position in PS-001/PS-002) | One product owns every book of record; simplest data model | Forces AMCs to migrate core books of record at once; slow sales cycle **[ASSUMPTION — confirm in pilot interviews]** | Not recommended as the default; still available per domain under C |
| B — Pure orchestration, no own engines | Fastest adoption; smallest scope | No shadow checking; nothing for AMCs whose current tools are weak | Gives up the deterministic-engine value already designed (DDL-000) |

## Consequences
Positive: lower adoption barrier; clear ownership per object. Negative: more projection and reconciliation work; DDL-000 must add SoR registry and projection tables (WP4). PS-001/PS-002 wording needs reconciliation if approved.

## Validation
Policy tests deny writes for mode E/S objects; reconciliation tests for shadow mode; owner decisions OD-1 and OD-2 recorded.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-20 | Draft | Claude (AI author) for project owner | Created as proposal (EA-100 set) |
