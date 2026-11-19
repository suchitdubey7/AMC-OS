# AMC OS

An enterprise operating system for Indian mutual fund Asset Management Companies: multi-tenant, API-first, deterministic financial engines, governed AI.

**Phase:** documentation programme (no production code yet). Work Package 1 — charter and engineering governance — is in review.

## Start here

| If you want to… | Read |
| --- | --- |
| Understand the full brief | [MASTER_BUILD_PROMPT.md](MASTER_BUILD_PROMPT.md) |
| Work in this repo (people or AI agents) | [AGENTS.md](AGENTS.md) |
| See scope, customers and success measures | [PS-001 Project charter](docs/01_product_strategy/PS-001_project_charter.md) |
| See the plan and what is approved | [GOV-005 Work packages](docs/00_governance/GOV-005_work_package_plan.md), [GOV-001 Document register](docs/00_governance/GOV-001_document_control_and_identifiers.md#7-document-register-as-of-19-nov-2026) |
| Understand IDs and the 17 domains | [GOV-001](docs/00_governance/GOV-001_document_control_and_identifiers.md) |
| See key architecture decisions | [architecture/adrs/](architecture/adrs/) |

## Work package status

| WP | Deliverable | Status |
| --- | --- | --- |
| WP1 | Project charter + engineering governance | In review |
| WP2 | Business capability map + master PRD (17 domains) | Not started — v0.9 PRD exists as input |
| WP3 | Enterprise system architecture | Not started |
| WP4 | Data and database architecture | Not started — v0.9 doc, DDL and tests exist as input |
| WP5 | Financial engine specifications | Not started |
| WP6 | API, security, AI, infrastructure specifications | Not started |
| WP7 | Traceability and baseline approval | Not started |

## Repository layout

```
docs/            specifications, numbered 00_governance … 14_release_and_operations
architecture/    ADRs, diagrams, domain models, ERDs, deployment models
contracts/       OpenAPI, event and data schemas
database/        reference DDL, migrations, seeds, database tests
src/             application code by domain (empty until WP7 approval)
frontend/ infrastructure/ integrations/ tests/ scripts/ deployment/
```

## Existing v0.9 inputs

- [PRD-000 Master PRD v0.9](docs/03_product_requirements/PRD-000_master_prd_v0.9.md)
- [DA-000 Data & database architecture v0.9](docs/05_data_architecture/DA-000_data_and_database_architecture_v0.9.md)
- [DDL-000 Core PostgreSQL schema](database/ddl/DDL-000_core_schema_v0.9.sql) and [DBT-000 tests](database/tests/DBT-000_integrity_and_isolation_tests_v0.9.sql) — 24 checks pass on PostgreSQL 16.15

These are drafts, not approved baselines.
