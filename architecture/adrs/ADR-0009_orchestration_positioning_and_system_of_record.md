---
id: ADR-0009
title: AMC OS is an orchestration layer with a per-tenant system-of-record registry
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D01 + all
related: EA-100, EA-101; PS-001, PS-002; master prompt §2
---

# ADR-0009 — AMC OS is an orchestration layer with a per-tenant system-of-record registry

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
The owner asked (20 Nov 2026) to position AMC OS as "the AI-native orchestration layer for asset management companies" that integrates existing systems rather than replacing them. PS-001/PS-002, the master prompt §2 and PRD-000 Modules 08/09 (all Draft) position AMC OS as a full platform that replaces fragmented systems and acts as scheme ledger and NAV publisher. Both views have support: pilot AMCs already run RTA, accounting and NAV processes they cannot switch off quickly; but some AMCs want AMC OS to own domains where their current tools are weak.

## Decision
**Proposed:**
1. AMC OS is positioned as an orchestration layer first. It owns intent, orders, approvals, workflow, routing, compliance results and audit in every deployment.
2. For every other data object, a per-tenant, effective-dated system-of-record registry (EA-101) sets mode O (AMC OS owns), S (shadow) or E (external, read-only).
3. Defaults: execution → broker/exchange; settlement → custodian/bank; investor/folio → RTA; accounting → AMC's platform; NAV publication → AMC's NAV authority. AMC OS engines remain available for tenants that choose mode O.
4. The platform enforces the registry: write tools for objects not in mode O are denied.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Full replacement platform (current Draft position) | Slower adoption; forces AMCs to migrate core books of record at once |
| Pure orchestration, no own engines | Loses shadow-checking value and tenants without suitable systems |

## Consequences
Positive: lower adoption barrier; clear ownership per object. Negative: more projection and reconciliation work; DDL-000 must add SoR registry and projection tables (WP4). PS-001/PS-002 wording needs reconciliation if approved.

## Validation
Policy tests deny writes for mode E/S objects; reconciliation tests for shadow mode; owner decisions O-1 and O-2 recorded.

## Change log
| Date | Change |
| --- | --- |
| 2026-11-20 | Created as proposal (EA-100 set) |
