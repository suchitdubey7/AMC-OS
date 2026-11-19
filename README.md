# AMC OS

Product specification and database architecture for **AMC OS**, a multi-tenant, API-first, AI-enabled operating system for Indian mutual fund Asset Management Companies.

## Contents

| Path | What it is |
| --- | --- |
| [`docs/PRD.md`](docs/PRD.md) | Product Requirements Document: 15 modules, 17 end-to-end workflows, user stories, role-permission matrix, NFRs, integrations, AI agents, roadmap, regulatory register |
| [`docs/Database-Architecture.md`](docs/Database-Architecture.md) | Database architecture: storage stack, 23 schema boundaries, 13 ER diagrams, table specs, multi-tenant isolation, transaction model, data engineering, high-volume design |
| [`db/amc_os_ddl.sql`](db/amc_os_ddl.sql) | Core PostgreSQL 16 DDL (schemas, tables, partitions, RLS, triggers, functions, materialized view) |
| [`db/amc_os_tests.sql`](db/amc_os_tests.sql) | 24 integrity and negative security checks (cross-tenant access, double entry, immutability, state machine, maker-checker, NAV) |

Diagrams are Mermaid and render directly on GitHub.

## Run the database and tests

Requires PostgreSQL 16+ with `pgcrypto` and `btree_gist` (both ship with standard PostgreSQL).

```bash
createdb amcos
psql -d amcos -v ON_ERROR_STOP=1 -f db/amc_os_ddl.sql
psql -d amcos -v ON_ERROR_STOP=1 -f db/amc_os_tests.sql   # prints PASS for each check
```

Run both as a superuser or migration owner. The tests switch to the `amc_app` role so row-level security applies.

## Status

Draft v0.9 (19 Nov 2026). Regulatory items are labelled **[REG]** confirmed, **[IND]** industry practice, **[DES]** design choice, or **[VAL]** needs legal/compliance validation. Thresholds, cut-off times and rates are not hard-coded; they belong in the versioned rule registry once validated. External provider interfaces (RTAs, exchanges, custodians, data vendors) must be confirmed with each provider.
