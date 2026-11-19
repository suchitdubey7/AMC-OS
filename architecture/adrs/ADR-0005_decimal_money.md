---
id: ADR-0005
title: Money and quantities use exact decimal arithmetic with declared rounding points
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: D10, D11, D13, D14, D15
related: STD-001 §3, FE-01…FE-10
---

# ADR-0005 — Money and quantities use exact decimal arithmetic with declared rounding points

## Context
Principle 3.2 forbids binary floating point for money and requires defined precision and rounding.

## Decision
PostgreSQL `NUMERIC(p,s)`, Python `Decimal` with a declared context per engine, JSON amounts as strings, TypeScript never converts amounts to `number`. Rounding happens only at steps named in each engine spec. Default storage scales: amounts 4 dp, units 6 dp, prices 8 dp, NAV unrounded 12 dp and published NAV per plan configuration **[VAL with RTA]**.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Integer paise | Breaks for units, prices and rates with more decimals |
| Float with rounding | Forbidden; non-reproducible |

## Consequences
Exact, reproducible results; slightly slower arithmetic; JSON clients must handle string amounts.

## Validation
Lint bans `float` in engine code; property tests; DBT-000 T6d (NAV exact to 4 dp) and T7 (commission) already green.
