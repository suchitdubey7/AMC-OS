---
id: AIML-101
title: Agent Registry Specification — Proposal
status: Draft
version: 0.1
owner: Head of AI
approver: Project owner (interim ARB); AI Governance Committee once formed
work_package: WP6 (proposal; final owner GOV-006 Step 26, AIML-001)
last_updated: 2026-11-20
---

# AIML-101 — Agent Registry Specification (Proposal)

> **PROPOSAL** — part of the [EA-100](../04_enterprise_architecture/EA-100_ai_orchestration_architecture_proposal.md) set. PRD-000 Module 15 (point 12, FR-15-01) already places the agent registry in schema `ai`, and DDL-000 defines `ai.agent` as a **per-tenant** table. This document proposes a global definition plus per-tenant enablement — a departure recorded as EA-100 conflict C9 (decision OD-10). No DDL is added here.

## 1. Purpose

Every agent that can run in AMC OS has one registry record per version. An agent with no Approved record cannot run. Proposed shape (C9): records are global definitions (control plane, EA-103); **enablement** is per tenant (data plane), keeping DDL-000's per-tenant `ai.agent` row and its per-tenant service identity. DDL-000 risk tiers LOW/MEDIUM/HIGH would map to R0/R1, R1, R2 — to be settled in WP4.

## 2. Fields

| Field | Type | Required | Meaning / rule |
| --- | --- | --- | --- |
| `agent_id` | string, e.g. `AG-PM` | yes | Stable ID (AIML-100 §3) |
| `name` | string | yes | Display name |
| `domain` | D-code list | yes | Primary first (GOV-001 §3) |
| `description` | text | yes | What it does and does not do |
| `version` | semver | yes | Any change to prompt, model, tools or schema = new version |
| `supported_tasks` | list of task IDs | yes | Each task has its own I/O schema and risk class |
| `input_schema` | JSON Schema ref | yes | Validated before the run |
| `output_schema` | JSON Schema ref | yes | Validated after the run; failure = FH-02 (EA-105) |
| `allowed_tools` | list of `tool_id@version` | yes | Allow-list; anything else is denied |
| `permissions` | permission codes | yes | Upper bound; effective = user ∩ agent ∩ tenant ∩ tool (SEC-100) |
| `data_classification_max` | Public / Internal / Confidential / Restricted | yes | Highest class it may read |
| `risk_class_max` | R0 / R1 / R2 | yes | R3 not allowed for any agent |
| `human_approval` | rule ref | yes | Which outputs must go to a human queue |
| `model_version` | pinned provider + model + version | yes | Exactly one pinned model per agent version (PRD-000 §9.2). A fallback model is allowed only as its own agent version that has passed the same evaluation suite |
| `model_policy` | provider allow-list per data class | yes | OD-4 |
| `tenant_context` | rule | yes | Tenant comes from the user token only; which tenant settings and SoR modes the agent reads (master prompt §11) |
| `failure_strategy` | ref | yes | What the agent does on each EA-105 failure (master prompt §11) |
| `prompt_version` | ref | yes | Stored and hashed |
| `limits` | max steps, tokens, wall time, cost | yes | FH-13 |
| `timeout_retry` | timeout, max retries | yes | Generation retries ≤ 1 (EA-105 §2) |
| `evaluation_suite` | ref + pass thresholds | yes | Must pass before Approved |
| `audit_requirements` | level | yes | Minimum: full trace (AIML-103) |
| `owner` | role | yes | Business owner of the agent |
| `status` | Draft / Under Review / Approved / Suspended / Retired | yes | Only Approved runs |
| `approved_by`, `approved_at` | — | when Approved | Human approver(s); maker-checker |

## 3. Example record (illustrative only)

```yaml
agent_id: AG-NAV
name: NAV Operations Agent
domain: [D11, D10]
description: Explains NAV movements and triages NAV exceptions. Cannot approve or publish NAV.
version: 0.1.0
supported_tasks: [nav.explain_movement, nav.triage_exceptions]
input_schema: schemas/ai/nav_explain_input.v1.json      # to be written
output_schema: schemas/ai/nav_explain_output.v1.json    # to be written
allowed_tools: [nav.run.read@1, nav.components.read@1, valuation.price_exceptions.read@1]
permissions: [nav.read, valuation.read]
data_classification_max: Confidential
risk_class_max: R1
human_approval: none (read-only)
model_version: "<pinned when evaluated>"
tenant_context: token_only
failure_strategy: fail_closed_explain
limits: {max_steps: 8, max_wall_seconds: 60}
evaluation_suite: evals/AG-NAV/v1                       # to be written
audit_requirements: full_trace
owner: Head of Fund Operations
status: Draft
```

The schema and evaluation paths are placeholders for WP6 (Step 26); they do not exist yet.

## 4. Lifecycle

Draft → Under Review (evaluation results attached) → Approved (by AI governance, maker ≠ checker) → Suspended (kill switch) → Retired. A tenant admin may enable only Approved versions, and enabling is an R3 configuration change.
