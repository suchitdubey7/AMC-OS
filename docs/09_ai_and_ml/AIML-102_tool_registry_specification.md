---
id: AIML-102
title: Tool Registry Specification — Proposal
status: Draft
version: 0.2
owner: Head of AI
approver: Project owner (interim ARB)
work_package: WP6 (proposal; final owner GOV-006 Step 26, AIML-001)
last_updated: 2026-11-20
---

# AIML-102 — Tool Registry Specification (Proposal)

> **PROPOSAL** — part of the [EA-100](../04_enterprise_architecture/EA-100_ai_orchestration_architecture_proposal.md) set. Decision record: ADR-0011 (Draft).

A *tool* is the only way an agent can touch data or systems. Every tool wraps a documented deterministic API (internal) or an adapter (external). Agents never get raw database access or vendor credentials.

## 1. Four categories

| Category | Examples | Who builds | Notes |
| --- | --- | --- | --- |
| TLC1 Internal business tools | `oms.order.draft`, `nav.run.read`, `compliance.whatif.run` | Owning domain team | Call domain APIs; writes only where AMC OS is SoR (EA-101) |
| TLC2 Internal data / analytics tools | `metrics.get`, `analytics.query_certified` | Data platform | Return only certified metrics (DA-100) |
| TLC3 External vendor tools | Market data, regulatory sources, RTA reports | Integration team (adapters) | Behind canonical contracts (INT-100) |
| TLC4 Approved MCP tools | Tools from a vendor MCP server that passed review | Integration team | Proxied through the AMC OS MCP gateway; never called directly by agents |

## 2. Fields

| Field | Required | Rule |
| --- | --- | --- |
| `tool_id` (e.g. `oms.order.draft`) | yes | `<domain>.<object>.<verb>` |
| `name`, `description` | yes | Description is what the model sees; reviewed for injection-safe wording |
| `owning_domain` | yes | D-code; single owner |
| `category` | yes | TLC1–TLC4 |
| `input_schema`, `output_schema` | yes | JSON Schema; strict (no extra properties) |
| `version` | yes | semver; breaking change = major |
| `tenant_scope` | yes | `tenant` (always, for customer data) or `global` (public reference only) |
| `required_permissions` | yes | Permission codes checked by policy engine |
| `access` | yes | read / write |
| `writes_object_type` | if write | Checked against SoR registry (EA-101) |
| `risk_class` | yes | R0 / R1 / R2 (**no R3 tools exist**) |
| `approval_rule` | yes | For R2: which human queue receives the result |
| `data_classification` | yes | Highest class returned |
| `rate_limit` | yes | Per tenant, per user, per agent |
| `timeout`, `retry_policy` | yes | Writes: retry only with same idempotency key |
| `idempotency` | if write | Key format and scope |
| `credential_ref` | if external | Pointer to secrets manager entry per tenant; never the secret |
| `audit_level` | yes | Inputs/outputs logged (masked per class) |
| `contract_ref` | yes | OpenAPI operation, event or adapter spec |
| `licence_constraints` | if TLC3/TLC4 | Redistribution, display, AI-use terms (INT-100 §5) |
| `status` | yes | Draft / Approved / Suspended / Retired |

## 3. Risk class examples

| Tool | Risk | Why |
| --- | --- | --- |
| `regulatory.circulars.search` (public SEBI pages) | R0 | Public data |
| `portfolio.positions.read` | R1 | Authorised read |
| `oms.order.draft` | R2 | Creates a DRAFT only; human submits |
| `recon.match.propose` | R2 | Proposed match; analyst accepts |
| `investor.reply.draft` | R2 | Draft; human sends |
| Submit / approve / release order, post journal, publish NAV, change rule | **not a tool** | R3 human-only actions (SEC-101) |

## 4. Routing

The agent asks for a tool by ID → policy engine checks (user, agent, tenant, tool) → gateway issues a short-lived token for that one call → call executes → output validated against schema → result returned with provenance (source system, as-of, record IDs).
