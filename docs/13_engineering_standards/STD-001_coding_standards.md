---
id: STD-001
title: Engineering and Coding Standards
status: Draft
version: 0.1
owner: Backend Engineering Lead / Frontend Engineering Lead
approver: ARB
work_package: WP1
last_updated: 2026-11-19
---

# STD-001 — Engineering and Coding Standards

These rules apply to all code in this repository, whoever or whatever writes it. CI enforces the ones marked **(CI)**.

## 1. General

1. Type hints everywhere; `mypy --strict` for Python, `tsc --strict` for TypeScript. **(CI)**
2. Structured JSON logging with `tenant_id`, `user_id`, `correlation_id`, `module`; never log secrets, PAN, bank account numbers or full names. **(CI: log-PII lint)**
3. Explicit exception handling. No bare `except:`; no swallowed exceptions; domain errors are typed (`DomainError` subclasses with stable error codes). **(CI: ruff rules)**
4. Separation of concerns: API layer (FastAPI routers) → application services → domain model → repositories. Routers contain no business logic.
5. Dependency injection for repositories, clocks, ID generators and external clients, so engines can be tested with fixed inputs.
6. No hardcoded secrets, URLs, tenant IDs or customer assumptions. **(CI: secret scan)**
7. Validate every external input with Pydantic models at the boundary (APIs, files, events).
8. No hidden financial calculations: every money calculation lives in a named engine function that cites its spec section.
9. No production database change outside a reviewed Alembic migration.

## 2. Module boundaries (modular monolith)

- `src/<domain>/` packages map 1:1 to domains and own one database schema each (ADR-0002).
- A module may import another module only through that module's public `api.py` (service interface) or its published events. Architecture tests (`import-linter`) fail the build on violations or cycles. **(CI)**
- Each module connects with its own database role that can write only its own schema.

## 3. Money and numbers (ADR-0005)

| Rule | Detail |
| --- | --- |
| Type | Python `decimal.Decimal`; PostgreSQL `NUMERIC(p,s)`; API JSON as **strings** (`"1520.50"`); TypeScript never converts amounts to `number` |
| Context | A module-level `decimal.Context` per engine with precision ≥ 34 digits and `ROUND_HALF_UP` unless the engine spec states otherwise |
| Rounding | Only at steps the engine spec names (e.g., final NAV per unit, final units allotted); intermediate values keep full precision |
| Floats | `float` is banned in financial code paths **(CI: lint rule + test scanning for `float(` in `src/**/engines/`)** |
| Currency | Amounts carry currency; no implicit INR assumption outside INR-only fields |
| Dates | `date` for business dates; `datetime` with timezone (UTC stored, IST displayed) for events |

## 4. Persistence

- SQLAlchemy 2.x Core/ORM with explicit transactions; one unit of work per command.
- Every transaction sets tenant context with `SET LOCAL app.tenant_id` from the authenticated principal (never from request parameters) (ADR-0003).
- Writes that publish events use the transactional outbox (ADR-0006).
- Optimistic locking via `row_version` on mutable aggregates.
- Every write API accepts an `Idempotency-Key`.

## 5. APIs

- REST, OpenAPI 3.1 contracts in `contracts/openapi/` written **before** implementation; versioned under `/v1`.
- Errors follow RFC 9457 problem details with stable `code`.
- Pagination by cursor; no offset pagination on large tables.
- Full API standard: API-001 (WP6).

## 6. Frontend

- React + TypeScript, shared design system, accessibility WCAG 2.1 AA.
- The UI never computes financial values; it displays server-computed, server-formatted values.
- Role workspaces gate features by server-issued permissions; hiding a button is not authorisation.

## 7. Code review

- Every change via pull request with at least one human approval; T1 code (GOV-004) needs a reviewer with domain knowledge.
- AI-generated code is reviewed exactly like human code; no self-approval (GOV-003).
- Review checklist: spec citation, tests, tenant context, decimal usage, error handling, logging, migration safety, docs updated.

## 8. Service documentation

Every module folder `src/<domain>/` contains a README with: purpose, architecture, dependencies, API contracts, data model (tables owned), configuration, security controls, tests, operational runbook link.
