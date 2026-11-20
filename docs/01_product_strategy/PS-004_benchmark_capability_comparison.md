---
id: PS-004
title: Benchmark Capability Comparison (SimCorp, Aladdin, Charles River, Murex)
status: Draft
version: 0.2
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP2
step: 1
last_updated: 2026-11-19
---

# PS-004 — Benchmark Capability Comparison

All four benchmarks sell the same core idea: one platform and one data foundation from portfolio management to accounting. AMC OS adopts that idea and aims to differ by being built for Indian mutual fund workflows, priced for mid-size and new AMCs, and governing AI by design.

**IP guardrail [DES]:** these platforms are capability reference points only (master prompt §2). No proprietary interface, screen, data model, code or documentation is copied or reverse-engineered. Statements below come from public vendor material and press; nothing here comes from any licensed or confidential source.

**Builds on Draft documents:** PS-001, PS-003, GOV-001 §3 (domain list), ADR-0008 — allowed by owner decision D-3 ([GOV-008 §2](../00_governance/GOV-008_build_loop.md#2-rules), rule 3).

## 1. What each benchmark is (public facts)

| Platform | Owner | Public positioning | Source |
| --- | --- | --- | --- |
| SimCorp (Dimension / SimCorp One) | Deutsche Börse Group; offer valued SimCorp's whole share capital at EUR 3.9 bn; takeover completed in 2023 | Front-to-back investment management platform for the global buy side; includes Axioma risk and portfolio optimisation since 2024 | [B1], [B2], [B3], [B9] |
| BlackRock Aladdin | BlackRock | Investment and risk platform; Aladdin Studio gives programmatic access to run analytics and automate portfolio oversight workflows | [B4] |
| Charles River IMS / State Street Alpha | State Street (acquired Charles River Development in 2018) | Charles River IMS is a front-office system; State Street describes Alpha as a front-to-back investment servicing platform; Alpha Data Platform is "an end-to-end data management and warehouse solution" | [B5], [B6] |
| Murex MX.3 | Murex | Front-to-back-to-risk capital markets platform; MX.3 for Investment Management covers portfolio management, trading, compliance and risk, performance and accounting on a cross-asset book of record | [B7], [B8] |

## 2. Capability comparison (all 17 domains)

Ratings describe *publicly stated scope*, not quality. ● core public positioning · ◐ available or partial · ○ not a focus.

- A rating with a source tag (e.g., "● [B7]") is supported by that source.
- A rating marked **\*** is **[ASSUMPTION]** — not checked against vendor material. Confirm: Chief Enterprise Architect, before any external use.
- The AMC OS column is the *target* scope, not built capability.

| Capability (AMC OS domain) | SimCorp | Aladdin | Charles River / Alpha | Murex MX.3 | AMC OS target |
| --- | --- | --- | --- | --- | --- |
| Platform administration: multi-tenant SaaS, subscriptions, org hierarchy (D01) | ◐\* | ◐\* | ◐\* | ◐\* | ● shared and dedicated cells, one codebase |
| Product and scheme management for Indian MF schemes (D02) | ○\* | ○\* | ○\* | ○\* | ● scheme, plan and option master; regulatory document versions |
| Investment management: research, investment committee, policy (D03) | ◐\* | ◐\* | ◐\* | ○\* | ● research and decisions linked to orders |
| Portfolio management (D04) | ●\* | ● [B4] | ● [B5] | ● [B7] | ● |
| OMS / trading and execution (D05, D06) | ●\* | ●\* | ● [B5] | ● [B7] | ● |
| Settlement for Indian markets (D07) | ◐\* | ◐\* | ◐\* | ◐\* | ● exchange, custodian and broker obligations, India settlement calendar |
| Pre/post-trade compliance (D08) | ●\* | ●\* | ●\* | ● [B7] | ● with Indian rule packs as versioned data |
| Risk analytics (D09) | ● [B3] (Axioma) | ● [B4] | ◐\* | ● [B7] | ◐ → ● (deterministic, reproducible) |
| Fund accounting / IBOR and ABOR (D10) | ●\* | ◐\* | ◐\* (State Street back-office services) | ● [B7] | ● scheme-level double entry |
| NAV for Indian MF plans and options (D11) | ◐\* | ○\* | ◐\* | ○\* | ● India-specific (plans, options, IDCW, RTA units) |
| Fund operations: workflows, reconciliations, operational calendars (D12) | ◐\* | ◐\* | ◐\* | ◐\* | ● one exception queue, rule-based matching |
| Indian investor servicing via RTA (D13) | ○\* | ○\* | ○\* | ○\* | ● mirror of CAMS/KFin |
| Distributor management and commission (D14) | ○\* | ○\* | ○\* | ○\* | ● ARN/EUIN, trail, B30, scorecards |
| AMC finance and yield MIS (D15) | ○\* | ○\* | ○\* | ○\* | ● TER, yield, profitability |
| Data platform (D16) | ●\* | ●\* | ● [B6] (Alpha Data Platform) | ◐\* | ● |
| Open APIs | ●\* | ● [B4] (Aladdin Studio) | ●\* | ●\* | ● API-first |
| Governed AI that cannot approve or post (D17) | ◐\* | ◐\* | ◐\* | ○\* | ● by design (ADR-0008) |

No domain is left out. D05 and D06 share one row because the benchmarks present order management and execution as one capability.

## 3. What AMC OS takes as reference

1. **One book of record** across front, middle and back office (positioning of all four, §1).
2. **Data platform as a product** with catalogue and governance (Alpha Data Platform [B6]).
3. **Programmatic access** to analytics and workflows (Aladdin Studio [B4]).
4. **Integrated risk and optimisation** next to portfolio management (SimCorp with Axioma [B3]).
5. **Deployment choice:** shared and dedicated cells (ADR-0003). Murex deployment options were not checked in this step.

## 4. Where AMC OS aims to differ

| Differentiator | Why it matters to Indian AMCs |
| --- | --- |
| India-native workflows: RTA mirror, AMFI, SEBI formats, IDCW, ARN/EUIN, T30/B30 | Removes customisation that global platforms are likely to need for Indian MF operations **[ASSUMPTION — confirm: Chief Enterprise Architect, with vendor material and Indian AMC references]** |
| Distribution and AMC-finance domains built in | Sales and profitability analytics are core to Indian AMCs; they were not found in the public material reviewed (B1–B9) **[ASSUMPTION — absence in public material is not proof the capability is missing; confirm: Chief Enterprise Architect]** |
| Regulation as versioned, tested, traceable data | SEBI rules change often; evidence for inspections comes out of the system **[DES]** |
| Priced and packaged for new and mid-size AMCs **[ASSUMPTION — confirm: Product Manager, with pricing conversations (PS-003 §6)]** | The growing segments (PS-003 §2) |
| Governed AI by design | Copilots cannot move money or approve anything; every number is cited **[DES, ADR-0008]** |

## 5. Terms used

| Term | Meaning |
| --- | --- |
| OMS | Order management system |
| IBOR / ABOR | Investment book of record (live positions for the front office) / accounting book of record (the official books) |
| IDCW | Income Distribution cum Capital Withdrawal: the payout option of an Indian MF scheme (formerly "dividend") |
| ARN / EUIN | AMFI Registration Number of a distributor / Employee Unique Identification Number of the distributor's employee who advised the sale |
| T30 / B30 | Top 30 / beyond top 30 cities: Indian MF categories used for distributor incentives |
| TER | Total expense ratio charged to a scheme |
| RTA | Registrar and Transfer Agent (see PS-003 §7) |

## Sources

- [B1] [Deutsche Börse — final tender result for SimCorp takeover (Sep 2023)](https://www.deutsche-boerse.com/dbg-en/media/news-stories/press-releases/Deutsche-B-rse-announces-final-tender-result-for-takeover-of-SimCorp-3685174)
- [B2] [Deutsche Börse — recommended all-cash takeover offer for SimCorp (Apr 2023): DKK 735 per share, whole share capital valued at EUR 3.9 bn](https://deutsche-boerse.com/dbg-en/media/news-stories/press-releases/DEUTSCHE-B-RSE-AG-ANNOUNCES-RECOMMENDED-ALL-CASH-TAKEOVER-OFFER-FOR-SIMCORP-A-S-INTENDS-TO-COMBINE-QONTIGO-AND-ISS-AND-CREATE-NEW-INVESTMENT-MANAGEMENT-SOLUTIONS-SEGMENT-3516210)
- [B3] [Deutsche Börse — SimCorp Alternatives (Sep 2025), SimCorp includes Axioma](https://deutsche-boerse.com/dbg-en/media/news-stories/press-releases/SimCorp-to-transform-private-market-investing-with-SimCorp-Alternatives-4654920)
- [B4] [BlackRock — Aladdin Studio for Aladdin Risk](https://www.blackrock.com/aladdin/discover/resources/aladdin-studio-for-aladdin-risk-management)
- [B5] [State Street — Forging connections with State Street Alpha (Charles River acquired 2018)](https://stakeholderreport.statestreet.com/Y2019/Details/2019/forging-connections-with-state-street-alpha/default.aspx)
- [B6] [State Street — launch of the cloud-native Alpha Data Platform (15 Dec 2020)](https://newsroom.statestreet.com/press-releases/press-release-details/2020/State-Street-Launches-Cloud-Native-Alpha-Data-Platform-for-Institutional-and-Wealth-Managers-12-15-2020/default.aspx)
- [B7] [Murex — MX.3 for Investment Management](https://www.murex.com/en/investment-management)
- [B8] [Murex — Smart technology for capital markets](https://murex.com/en/solutions/smart-technology-capital-markets)
- [B9] [Deutsche Börse — Q3 2023 results: takeover of SimCorp completed (18 Oct 2023)](https://deutsche-boerse.com/dbg-en/media/news-stories/press-releases/Q3-2023-Deutsche-B-rse-Group-reports-further-growth-and-completes-takeover-of-SimCorp-3711076)
