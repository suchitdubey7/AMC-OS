---
id: ADR-0004
title: Backend stack: Python, FastAPI, Pydantic, SQLAlchemy, Alembic, PostgreSQL
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: all
related: master prompt §13, STD-001
---

# ADR-0004 — Backend stack: Python, FastAPI, Pydantic, SQLAlchemy, Alembic, PostgreSQL

## Context
The master prompt sets a default baseline stack and asks for the smallest reliable set, recorded in ADRs. The team's strongest skills are Python and SQL.

## Decision
Python 3.12+, FastAPI, Pydantic v2, SQLAlchemy 2.x, Alembic for migrations, PostgreSQL 16+. DDL-000 is kept as the reference schema; WP4 produces Alembic migrations that must reproduce it exactly (verified by schema diff in CI) and DDL-000 then becomes generated documentation.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Java/Kotlin + Spring | Strong in finance but slower for this team; no requirement forces it |
| Hand-written SQL migrations only | Weaker tooling for review and rollback |

## Consequences
Fast delivery; Python numeric performance acceptable with Decimal for OLTP-scale engines; heavy analytics move to ClickHouse/Polars.

## Validation
Platform foundation increment builds, migrates and passes DBT suites under Alembic.
