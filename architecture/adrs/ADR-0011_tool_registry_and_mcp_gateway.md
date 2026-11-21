---
id: ADR-0011
title: All agent access goes through a tool registry; MCP via a gateway
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D17, D16, D06, D07, D13
related: AIML-102, INT-100
---

# ADR-0011 — All agent access goes through a tool registry; MCP via a gateway

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
Agents need governed access to internal services and external vendors. FactSet offers a production MCP server (announced 16 Dec 2025) and a Portfolio Analytics MCP (announced 26 Jun 2026) — press-release links in INT-100 §4; other providers' MCP support is unverified. MCP specification revisions are frequent.

## Decision
**Proposed:**
1. Agents can only call tools registered in the tool registry (categories TLC1–TLC4) with strict JSON schemas, risk class and owner.
2. Vendor MCP servers are consumed through an MCP client gateway; vendor tools are reviewed, pinned and registered as TLC4 before use.
3. AMC OS may expose an MCP server of its own Approved R0/R1 tools to tenant-approved AI clients (optional, owner decision OD-8).
4. Use the official MCP SDKs; pin the supported specification version per release.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Agents connect directly to vendors | Fewer components | No central policy, audit or licence control | Breaks SEC-100 |
| REST-only tools, no MCP | One protocol to support | Cannot use vendor MCP offerings such as FactSet's | MCP behind a gateway costs little extra |

## Consequences
Positive: one control point. Negative: gateway is critical path for AI (not for financial processing).

## Validation
Contract tests per tool; red-team tests on vendor tool descriptions; spec-version compatibility tests.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-20 | Draft | Claude (AI author) for project owner | Created as proposal (EA-100 set) |
