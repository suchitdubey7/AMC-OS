---
id: ADR-0011
title: All agent access goes through a tool registry; MCP via a gateway
status: Draft
date: 2026-11-20
deciders: ARB (interim: project owner)
domains: D17, D16, integrations
related: AIML-102, INT-100
---

# ADR-0011 — All agent access goes through a tool registry; MCP via a gateway

> **PROPOSED ADR.** Written ahead of GOV-006 Steps 10–14 at the owner's request (EA-100). Depends on WP2. Not approved; may be changed or rejected when WP3 runs.

## Status
Draft (proposal)

## Context
Agents need governed access to internal services and external vendors. FactSet offers a production MCP server (announced 16 Dec 2025); other providers' MCP support is unverified. MCP specification revisions are frequent.

## Decision
**Proposed:**
1. Agents can only call tools registered in the tool registry (categories T1–T4) with strict JSON schemas, risk class and owner.
2. Vendor MCP servers are consumed through an MCP client gateway; vendor tools are reviewed, pinned and registered as T4 before use.
3. AMC OS may expose an MCP server of its own Approved R0/R1 tools to tenant-approved AI clients (optional, owner decision O-8).
4. Use the official MCP SDKs; pin the supported specification version per release.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Direct agent-to-vendor connections | No central policy, audit or licence control |
| REST-only tools, no MCP | Loses vendor MCP offerings; MCP adds little cost behind a gateway |

## Consequences
Positive: one control point. Negative: gateway is critical path for AI (not for financial processing).

## Validation
Contract tests per tool; red-team tests on vendor tool descriptions; spec-version compatibility tests.

## Change log
| Date | Change |
| --- | --- |
| 2026-11-20 | Created as proposal (EA-100 set) |
