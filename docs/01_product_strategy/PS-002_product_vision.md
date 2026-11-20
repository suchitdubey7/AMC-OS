---
id: PS-002
title: Product Vision
status: Draft
version: 0.2
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 1
last_updated: 2026-11-19
---

# PS-002 — Product Vision

AMC OS becomes the system an Indian AMC trusts for every number it reports, and the fastest way for a new or mid-size AMC to run like a large one.

**Builds on Draft documents:** PS-001 and GOV-006 — allowed by owner decision D-3 ([GOV-008 §2](../00_governance/GOV-008_build_loop.md#2-rules), rule 3). Terms such as RTA, IDCW, ARN/EUIN and CSCRF are explained in §8.

## 1. Vision statement

This is the single source of the vision statement; PS-001 §1 links here.

> Every number an AMC reports — NAV, AUM, exposure, revenue, commission — comes from one auditable system, can be reproduced exactly for any past date, and can be explained in plain language on demand.

## 2. Mission

Give Indian mutual fund AMCs one integrated, configurable operating platform, from scheme launch to daily NAV to distributor payout, so they spend their people's time on investing and serving investors instead of re-keying and reconciling data between systems.

## 3. Who it is for

| Persona | What they need from AMC OS | Domains |
| --- | --- | --- |
| CEO / MD | One trusted view of AUM, flows, market share, profitability; answers in plain language | D15, D16, D17 |
| CIO and fund managers | Live positions and cash, pre-trade limits in under a second, research and decisions in one place | D03, D04, D05, D08, D09 |
| Head of Products | Launch and change schemes, plans and options quickly; scheme documents versioned and traced to approvals | D02 |
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
- Three to five paying AMCs, mixing new entrants on the full stack and mid-size AMCs on selected modules (count: decision GOV-006 Q1; mix: [ASSUMPTION — confirm: project owner]).
- No unexplained financial difference and no cross-tenant incident since go-live.
- Leadership MIS that used to take days arrives the same day.

**Timeline check [ASSUMPTION — confirm: project owner (question Q11 in LOOP_STATE.md)].** Months count from the start of the roadmap (PS-001):

| Months | Milestone | Basis |
| --- | --- | --- |
| 1–3 | Documentation programme (Steps 0–28) | GOV-006 §3 |
| 18–22 | Pilot AMC starts, with a parallel run of at least 3 months | PS-001 §6 and O5 |
| about 21–25 | Pilot go-live after a clean parallel run | PS-001 §6 + 3 months. **Conflict declared:** PS-001 O1 (all 17 domains live at the pilot by month 24) and PS-001 §9 (pilot and rollout in months 22–24) need go-live by month 24; a pilot that starts after month 21 may not finish a 3-month parallel run by month 24. Raised in Q11 |
| 25–36 | Further AMCs sign and go live | 9–18-month sales cycles (PS-003 §4), started in parallel with the pilot |

Reaching 3–5 *paying* AMCs by month 36 is tight unless sales to the second and later AMCs start well before pilot go-live. Whether the 3–5 includes the pilot AMC is not yet decided; this document assumes it does.

## 6. What AMC OS is not

Not an RTA of record (decision GOV-006 Q2: mirror the RTA), not a custodian, broker, exchange, bank or KYC registry, not an algorithmic execution engine, not the AMC's corporate ERP, and never an AI that approves or posts money. Detail: PS-001 §3.

## 7. Related documents

[PS-001 charter](PS-001_project_charter.md) · [PS-003 market and customers](PS-003_market_and_customer_analysis.md) · [PS-004 benchmarks](PS-004_benchmark_capability_comparison.md)

## 8. Terms used

| Term | Meaning |
| --- | --- |
| AMC | Asset management company: the company that runs mutual fund schemes |
| NAV | Net asset value per unit of a scheme, published daily |
| RTA | Registrar and Transfer Agent (CAMS or KFin): keeps investor records |
| IDCW | Income Distribution cum Capital Withdrawal: the payout option of a scheme |
| ARN / EUIN | Distributor's AMFI Registration Number / ID of the distributor's employee who advised |
| TER | Total expense ratio charged to a scheme |
| MIS | Management information (internal reports) |
| CSCRF | SEBI's Cybersecurity and Cyber Resilience Framework for regulated entities |

More terms: [PS-003 §7](PS-003_market_and_customer_analysis.md#7-terms-used), [PS-004 §5](PS-004_benchmark_capability_comparison.md#5-terms-used). Full glossary: BA-003 (Step 3).
