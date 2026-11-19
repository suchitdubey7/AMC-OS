---
id: TRACE-003
title: Traceability — AI Orchestration Architecture Proposal
status: Draft
version: 0.2
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 (proposal)
last_updated: 2026-11-20
---

# TRACE-003 — Traceability for the AI Orchestration Proposal

Links each requested deliverable (owner request of 20 Nov 2026) to where it is answered, the GOV-006 step that will finally own it, its WP2 dependency and any open owner decision. TRACE-002 is reserved for WP7 (GOV-006). Everything here is **proposal** status. Every row also depends on the WP2 capability map (BA-001, Step 2); it is listed only where nothing more specific applies.

Work package ownership (GOV-005): EA and INT → WP3 (Steps 10–14); DA → WP4; SEC → WP6 (Step 25); AIML → WP6 (Step 26).

## 1. Deliverables

| # | Deliverable | Where | Final owner (GOV-006 step) | Depends on (WP2) | Open decisions | State |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Orchestration architecture | [EA-100](../04_enterprise_architecture/EA-100_ai_orchestration_architecture_proposal.md) §3–6 | WP3 Step 10 (EA-002) | BA-001 | OD-1, OD-3 | Proposal |
| 2 | Agent hierarchy | [AIML-100](../09_ai_and_ml/AIML-100_agent_hierarchy_and_supervisor.md) §1–3 | WP6 Step 26 (AIML-001) | BA-001, BA-005 | OD-9 | Proposal |
| 3 | Agent registry | [AIML-101](../09_ai_and_ml/AIML-101_agent_registry_specification.md) | WP6 Step 26 | BA-005 (roles for approval) | OD-10 | Proposal |
| 4 | Tool registry | [AIML-102](../09_ai_and_ml/AIML-102_tool_registry_specification.md) | WP6 Step 26 | BA-004, PRD-001…017 (operations to wrap) | — | Proposal |
| 5 | MCP and integrations | [INT-100](../07_api_and_integrations/INT-100_mcp_and_integration_architecture.md) | WP3 Step 14 (INT-001) | BA-004 (which flows need which provider) | OD-8 | Proposal |
| 6 | AI security | [SEC-100](../10_security_and_regulatory/SEC-100_ai_security_and_permission_model.md) | WP6 Step 25 (SEC-001/002) | BA-005 | OD-4 | Proposal |
| 7 | Human-in-the-loop | [SEC-101](../10_security_and_regulatory/SEC-101_human_in_the_loop_execution.md) | WP6 Step 25 | BA-004, BA-005 | — | Proposal |
| 8 | Transaction orchestration | [EA-102](../04_enterprise_architecture/EA-102_transaction_orchestration.md) | WP3 Step 13 (EA-007) | BA-004 dealing and settlement workflows | — | Proposal |
| 9 | System-of-record registry | [EA-101](../04_enterprise_architecture/EA-101_system_of_record_registry.md) | WP3 Step 11 (EA-003) | BA-001, BA-002 (operating model) | OD-1, OD-2 | Proposal |
| 10 | Hybrid deployment | [EA-103](../04_enterprise_architecture/EA-103_hybrid_deployment_control_and_data_plane.md) §1, 3–5 | WP3 Step 12 (EA-004/005) | BA-001 | Q5 | Proposal |
| 11 | Control / data plane | [EA-103](../04_enterprise_architecture/EA-103_hybrid_deployment_control_and_data_plane.md) §2 | WP3 Step 12 (EA-006) | BA-001 | — | Proposal |
| 12 | Domain-to-agent matrix | [AIML-100](../09_ai_and_ml/AIML-100_agent_hierarchy_and_supervisor.md) §4 | WP6 Step 26 | BA-001 | OD-9 | Proposal |
| 13 | Suites and workspaces | [EA-104](../04_enterprise_architecture/EA-104_product_suites_and_workspaces.md) | WP3 Step 10 (EA-002) | BA-005 | OD-11 | Proposal |
| 14 | Data and decision intelligence | [DA-100](../05_data_architecture/DA-100_data_and_decision_intelligence.md) | WP4 (DA-001) | BA-001, PRD-001…017 (metrics) | — | Proposal |
| 15 | Technology evaluation | [EA-106](../04_enterprise_architecture/EA-106_technology_evaluation.md) | WP3 Step 10 (ADRs) | BA-001 | Q5, Q6, OD-5, OD-6, OD-7 | Proposal |
| 16 | AI observability and audit | [AIML-103](../09_ai_and_ml/AIML-103_ai_observability_and_audit.md) | WP6 Step 26 | BA-005 (who reads audit) | — | Proposal |
| 17 | Failure handling | [EA-105](../04_enterprise_architecture/EA-105_failure_handling_and_recovery.md) | WP3 Steps 10 and 13 | BA-004 | — | Proposal |
| 18 | Diagrams and workflows | Mermaid in EA-100 (layers, two sequences), EA-102 (order state machine), EA-103 (planes), AIML-100 (hierarchy), INT-100 (adapters), SEC-101 (approval flow) | WP3 Step 10 | BA-004 | — | Proposal |
| 19 | ADRs | ADR-0009 – ADR-0015 (all Draft) | WP3 Step 10 | BA-001 | OD-1 … OD-11 | Proposal |
| 20 | Traceability | This document | WP7 (TRACE-002) | All WP2 outputs | — | Proposal |

## 2. ADRs to documents

| ADR | Topic | Documents |
| --- | --- | --- |
| ADR-0009 | Positioning and system of record (options; recommends C) | EA-100, EA-101 |
| ADR-0010 | Supervisor/specialist runtime (LangGraph) | AIML-100, AIML-101 |
| ADR-0011 | Tool registry and MCP gateway | AIML-102, INT-100 |
| ADR-0012 | Policy engine, four dimensions, R0–R3 | SEC-100, SEC-101 |
| ADR-0013 | Transaction lifecycles and UNKNOWN states | EA-102 |
| ADR-0014 | AI gateway and model abstraction | SEC-100, EA-105 |
| ADR-0015 | API gateway and policy engine products (open) | EA-106 |

## 3. Non-negotiable controls: where designed, and what is tested today

| Control | Designed in | Tested today? |
| --- | --- | --- |
| AI cannot approve (incl. its own actions or trades) | SEC-100 §3, SEC-101 §4 | **Yes** — DDL-000 approval trigger; DBT-000 T5b (AI service identity cannot record an approval) |
| AI cannot execute unauthorised transactions | SEC-100 §3, AIML-102 §3, EA-102 | **No** — SEC-100 §8 forbidden-action suite (to be written) |
| AI cannot publish NAV | SEC-100 §3, EA-101 | **No** — SEC-100 §8 |
| AI cannot modify accounting records | SEC-100 §3 | **No** — SEC-100 §8 (DDL-000 database grants exist but are not tested) |
| AI cannot override compliance | SEC-100 §3 | **No** — SEC-100 §8 |
| AI cannot change rules, limits or permissions | SEC-100 §3 | **No** — SEC-100 §8 |
| AI cannot rewrite history | SEC-100 §3 | Partly — DBT-000 tests insert-only/immutability for all users (e.g. T6 published NAV immutable); no AI-specific test |
| AI cannot bypass maker-checker | SEC-100 §3, SEC-101 | Partly — DBT-000 T5a (maker cannot approve own request); no AI end-to-end test |
| LLM never source of numerical truth | DA-100, AIML-100 §2 (grounding) | **No** — grounding tests in WP6 |
| Tenant isolation | SEC-100 §4, EA-103 | Database level yes (DBT-000 isolation tests); AI retrieval level no |
| No blind resubmission | EA-102 §4, ADR-0013 | **No** — WP4 state-machine tests |
| Control plane never stores customer financial data | EA-103 CPR-1, ADR-0003 | **No** |
| Vendor MCP / licence not assumed | INT-100 §4–5 | Sources cited in INT-100 §4 |
