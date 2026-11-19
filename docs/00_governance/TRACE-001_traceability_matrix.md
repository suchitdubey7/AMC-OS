---
id: TRACE-001
title: Traceability Matrix — Structure and Seed
status: Draft
version: 0.1
owner: QA Architect
approver: ARB
work_package: WP1
last_updated: 2026-11-19
---

# TRACE-001 — Traceability Matrix

Every critical requirement must be traceable along one chain (master prompt §14, Stage E):

**Business Requirement → Functional Requirement → Workflow → API → Database Entity → Financial Rule → Test Case → Release.**

This file fixes the structure. WP7 (TRACE-002) fills it for all critical requirements. From the first build increment onward the matrix is generated from IDs in code and docs, and CI fails if a T1 requirement has no test case.

## 1. Columns

| Column | ID format (GOV-001) | Mandatory for |
| --- | --- | --- |
| Business requirement | BR-Dxx-nnn | All |
| Functional requirement | FR-Dxx-nnn | All |
| Workflow | WF-nnn | All with a process |
| API operation | API-Dxx-nnn | All exposed capabilities |
| Database entity | schema.table | All persisted data |
| Financial rule / engine section | FE-nn §x / RULE-…@vn / RC-nnnn | T1, T2 |
| Test case | TC-area-nnn | All (T1: at least one expected-result and one negative test) |
| Release | REL-yyyy.n | When shipped |
| Status | Draft / Approved / Implemented / Validated | All |

## 2. Seed rows

These rows show the format with elements that already exist in the v0.9 drafts. IDs marked * are provisional until WP2 re-keys the PRD.

| BR | FR | WF | API | DB entity | Rule / engine | Test case | Release | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BR-D11-001* Publish exactly one authoritative NAV per plan per day | FR-D11-010* (v0.9 FR-09-10/11) | WF-007 Daily NAV | API-D11-003* `POST /v1/nav-runs/{id}/approve` | `nav.nav_run`, `nav.nav_result` | FE-01 (WP5) | DBT-000 T6a–T6d | — | Draft |
| BR-D10-001* Books must always balance | FR-D10-003* (v0.9 FR-08-03) | WF-008 Accounting closure | API-D10-002* `POST /v1/journal-batches` | `accounting.journal_batch`, `accounting.journal_line` | FE-02 (WP5) | DBT-000 T2a–T2c, T3a | — | Draft |
| BR-D01-001* No AMC can see another AMC's data | NFR-SEC-001* | all | all | every tenant table (RLS) | ADR-0003 | DBT-000 T1a–T1g | — | Draft |
| BR-D05-001* Every order follows the approved lifecycle | FR-D05-013* (v0.9 FR-04-13) | WF-004 Order creation and execution | API-D05-001* `POST /v1/orders` | `trading.order`, `trading.order_event`, `trading.order_state_transition` | — | DBT-000 T4a–T4c | — | Draft |
| BR-D12-001* Every approval needs a different human | FR-D01-0xx* (SOD rules) | all MC workflows | API-D12-0xx* approvals | `workflow.approval_request`, `workflow.approval_decision` | — | DBT-000 T5a–T5c | — | Draft |
| BR-D14-001* Commission must be reproducible to the paisa | FR-D14-010* (v0.9 FR-12-10) | WF-013 Distributor commission | API-D14-0xx* | `distribution.commission_line` | FE-09 (WP5) | DBT-000 T7 | — | Draft |
