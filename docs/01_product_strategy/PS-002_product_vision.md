---
id: PS-002
title: Product Vision
status: Draft
version: 0.1
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 1
last_updated: 2026-11-19
---

# PS-002 — Product Vision

AMC OS becomes the system an Indian AMC trusts for every number it reports, and the fastest way for a new or mid-size AMC to run like a large one.

## 1. Vision statement

> Every number an AMC reports — NAV, AUM, exposure, revenue, commission — comes from one auditable system, can be reproduced exactly for any past date, and can be explained in plain language on demand.

## 2. Mission

Give Indian mutual fund AMCs one integrated, configurable operating platform, from scheme launch to daily NAV to distributor payout, so they spend their people's time on investing and serving investors instead of re-keying and reconciling data between systems.

## 3. Who it is for

| Persona | What they need from AMC OS | Domains |
| --- | --- | --- |
| CEO / MD | One trusted view of AUM, flows, market share, profitability; answers in plain language | D15, D16, D17 |
| CIO and fund managers | Live positions and cash, pre-trade limits in under a second, research and decisions in one place | D03, D04, D05, D08, D09 |
| Dealers | One blotter, fair block allocation, broker connectivity | D05, D06 |
| COO and operations | NAV ready on time, reconciliations that mostly match themselves, one exception queue | D07, D10, D11, D12 |
| Chief Compliance Officer | Rules versioned and traced to their circular; evidence produced automatically | D08 |
| Chief Risk Officer | Daily reproducible risk and liquidity numbers, stress tests | D09 |
| CFO | Revenue, TER, yield and profitability by scheme and channel from the ledger, not spreadsheets | D10, D15 |
| Head of Sales / distribution | Daily scorecards, distributor AUM and flows, correct commissions | D14 |
| Investor services | Full investor history and open requests on one screen | D13 |
| CTO / CISO | Secure, multi-tenant, API-first, auditable, CSCRF-aligned | D01, all |

## 4. Product principles (what we will not compromise)

1. **Correct before clever.** Deterministic engines; exact decimals; every result reproducible.
2. **One data model.** Holdings, trades, ledger and NAV share identifiers, so the same fact is never keyed twice.
3. **Rules are data.** Regulation and AMC policy live as versioned, tested, approved configuration, not code.
4. **Humans decide.** AI reads, explains and proposes; people approve.
5. **Isolated by design.** One AMC can never see another's data, at any layer.
6. **Open by API.** Everything the UI does is available by documented API.
7. **Configure, don't fork.** One codebase for every customer.

## 5. What success looks like in three years [ASSUMPTION — targets for sponsor approval]

- One pilot AMC runs daily NAV, compliance and distribution MIS on AMC OS after a clean parallel run.
- Three to five paying AMCs, mixing new entrants on the full stack and mid-size AMCs on selected modules (decision GOV-006 Q1).
- No unexplained financial difference and no cross-tenant incident since go-live.
- Leadership MIS that used to take days arrives the same day.

## 6. What AMC OS is not

Not an RTA of record (decision GOV-006 Q2: mirror the RTA), not a custodian, broker, exchange, bank or KYC registry, not an algorithmic execution engine, not the AMC's corporate ERP, and never an AI that approves or posts money. Detail: PS-001 §3.

## 7. Related documents

[PS-001 charter](PS-001_project_charter.md) · [PS-003 market and customers](PS-003_market_and_customer_analysis.md) · [PS-004 benchmarks](PS-004_benchmark_capability_comparison.md)
