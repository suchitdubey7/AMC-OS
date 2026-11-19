---
id: TRACE-003
title: Traceability — AI Orchestration Architecture Proposal
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 (proposal)
last_updated: 2026-11-20
---

# TRACE-003 — Traceability for the AI Orchestration Proposal

Links each requested deliverable (owner request of 20 Nov 2026) to where it is answered, the GOV-006 step that will finally own it, and its WP2 dependency. TRACE-002 is reserved for WP7 (GOV-006). Everything here is **proposal** status.

## 1. Deliverables

| # | Deliverable | Where | Final owner step (GOV-006) | Depends on (WP2) | State |
| --- | --- | --- | --- | --- | --- |
| 1 | Orchestration architecture | [EA-100](../04_enterprise_architecture/EA-100_ai_orchestration_architecture_proposal.md) §3–6 | 10 | BA-001 | Proposal |
| 2 | Agent hierarchy | [AIML-100](../09_ai_and_ml/AIML-100_agent_hierarchy_and_supervisor.md) §1–3 | WP5 | BA-001, BA-005 | Proposal |
| 3 | Agent registry | [AIML-101](../09_ai_and_ml/AIML-101_agent_registry_specification.md) | WP5 | — | Proposal |
| 4 | Tool registry | [AIML-102](../09_ai_and_ml/AIML-102_tool_registry_specification.md) | WP5 | API contracts (WP3) | Proposal |
| 5 | MCP and integrations | [INT-100](../07_api_and_integrations/INT-100_mcp_and_integration_architecture.md) | 14 | Provider confirmations | Proposal |
| 6 | AI security | [SEC-100](../10_security_and_regulatory/SEC-100_ai_security_and_permission_model.md) | Security steps | BA-005 | Proposal |
| 7 | Human-in-the-loop | [SEC-101](../10_security_and_regulatory/SEC-101_human_in_the_loop_execution.md) | Security steps | BA-004, BA-005 | Proposal |
| 8 | Transaction orchestration | [EA-102](../04_enterprise_architecture/EA-102_transaction_orchestration.md) | 13 | BA-004 dealing workflow | Proposal |
| 9 | System-of-record registry | [EA-101](../04_enterprise_architecture/EA-101_system_of_record_registry.md) | 11 | O-1, O-2 | Proposal |
| 10 | Hybrid deployment | [EA-103](../04_enterprise_architecture/EA-103_hybrid_deployment_control_and_data_plane.md) §1, 3–5 | 12 | Q5 | Proposal |
| 11 | Control / data plane | [EA-103](../04_enterprise_architecture/EA-103_hybrid_deployment_control_and_data_plane.md) §2 | 12 | — | Proposal |
| 12 | Domain-to-agent matrix | [AIML-100](../09_ai_and_ml/AIML-100_agent_hierarchy_and_supervisor.md) §4 | WP5 | BA-001 | Proposal |
| 13 | Suites and workspaces | [EA-104](../04_enterprise_architecture/EA-104_product_suites_and_workspaces.md) | 10 | BA-005 | Proposal |
| 14 | Data and decision intelligence | [DA-100](../05_data_architecture/DA-100_data_and_decision_intelligence.md) | WP4 | — | Proposal |
| 15 | Technology evaluation | [EA-106](../04_enterprise_architecture/EA-106_technology_evaluation.md) | 10 | Q5, Q6 | Proposal |
| 16 | AI observability and audit | [AIML-103](../09_ai_and_ml/AIML-103_ai_observability_and_audit.md) | WP5 | — | Proposal |
| 17 | Failure handling | [EA-105](../04_enterprise_architecture/EA-105_failure_handling_and_recovery.md) | 10/13 | — | Proposal |
| 18 | Diagrams and workflows | Mermaid in EA-100 (layers, two sequences), EA-102 (order state machine), EA-103 (planes), AIML-100 (hierarchy), INT-100 (adapters), SEC-101 (approval flow) | 10 | — | Proposal |
| 19 | ADRs | ADR-0009 – ADR-0015 (all Draft) | 10 | O-1…O-9 | Proposal |
| 20 | Traceability | This document | 10 | — | Proposal |

## 2. ADRs to documents

| ADR | Topic | Documents |
| --- | --- | --- |
| ADR-0009 | Positioning and system of record | EA-100, EA-101 |
| ADR-0010 | Supervisor/specialist runtime (LangGraph) | AIML-100, AIML-101 |
| ADR-0011 | Tool registry and MCP gateway | AIML-102, INT-100 |
| ADR-0012 | Policy engine, four dimensions, R0–R3 | SEC-100, SEC-101 |
| ADR-0013 | Transaction lifecycles and UNKNOWN states | EA-102 |
| ADR-0014 | AI gateway and model abstraction | SEC-100, EA-105 |
| ADR-0015 | API gateway and policy engine products (open) | EA-106 |

## 3. Non-negotiable controls to where enforced

| Control | Documents | Existing evidence |
| --- | --- | --- |
| AI never approves, executes, posts, publishes, overrides, changes rules, rewrites history, bypasses maker-checker | SEC-100 §3, SEC-101, AIML-102 §3 | ADR-0008; DDL-000 approval trigger; DBT-000 T5b |
| LLM never source of numerical truth | DA-100, AIML-100 §2 (grounding) | ADR-0008 decision 2 |
| Tenant isolation | SEC-100 §4, EA-103 | DDL-000 RLS; DBT-000 isolation tests |
| No blind resubmission | EA-102 §4, ADR-0013 | — (to be tested in WP4) |
| Control plane has no unrestricted financial data access | EA-103 §2 | — |
| Vendor MCP / licence not assumed | INT-100 §4–5 | FactSet press releases (verified 20 Nov 2026) |
