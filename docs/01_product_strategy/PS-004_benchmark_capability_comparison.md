---
id: PS-004
title: Benchmark Capability Comparison (SimCorp, Aladdin, Charles River, Murex)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP2
step: 1
last_updated: 2026-11-19
---

# PS-004 — Benchmark Capability Comparison

All four benchmarks sell the same core idea: one platform and one data foundation from portfolio management to accounting. AMC OS adopts that idea and differs by being built for Indian mutual fund workflows, priced for mid-size and new AMCs, and governing AI by design.

**IP guardrail [DES]:** these platforms are capability reference points only (master prompt §2). No proprietary interface, screen, data model, code or documentation is copied or reverse-engineered. Statements below come from public vendor material and press; nothing here comes from any licensed or confidential source.

## 1. What each benchmark is (public facts)

| Platform | Owner | Public positioning | Source |
| --- | --- | --- | --- |
| SimCorp (Dimension / SimCorp One) | Deutsche Börse Group; takeover completed in 2023 (about US$4.3 bn) | Front-to-back investment management platform for the global buy side; includes Axioma risk and portfolio optimisation since 2024 | [B1], [B2], [B3] |
| BlackRock Aladdin | BlackRock | Investment and risk platform; Aladdin Studio gives programmatic access to run analytics and automate portfolio oversight workflows | [B4] |
| Charles River IMS / State Street Alpha | State Street (acquired Charles River Development in 2018) | Charles River IMS is the front- and middle-office system at the heart of State Street Alpha, described by State Street as a front-to-back platform | [B5], [B6] |
| Murex MX.3 | Murex | Front-to-back-to-risk capital markets platform, mainly sell side; MX.3 for Investment Management covers portfolio management, trading, compliance and risk, performance and accounting on a cross-asset book of record | [B7], [B8] |

## 2. Capability comparison

Ratings describe *publicly stated scope*, not quality. ● core public positioning · ◐ available or partial · ○ not a focus. AMC OS column is the *target* scope, not built capability.

| Capability (AMC OS domain) | SimCorp | Aladdin | Charles River / Alpha | Murex MX.3 | AMC OS target |
| --- | --- | --- | --- | --- | --- |
| Portfolio management (D04) | ● | ● | ● | ● | ● |
| OMS / trading (D05, D06) | ● | ● | ● | ● | ● |
| Pre/post-trade compliance (D08) | ● | ● | ● | ● | ● with Indian rule packs as versioned data |
| Risk analytics (D09) | ● (Axioma) | ● | ◐ | ● | ◐ → ● (deterministic, reproducible) |
| Fund accounting / IBOR-ABOR (D10) | ● | ◐ | ◐ (State Street back office services) | ● | ● scheme-level double entry |
| NAV for Indian MF plans/options (D11) | ◐ | ○ | ◐ | ○ | ● India-specific (plans, options, IDCW, RTA units) |
| Indian investor servicing via RTA (D13) | ○ | ○ | ○ | ○ | ● mirror of CAMS/KFin |
| Distributor management & commission (D14) | ○ | ○ | ○ | ○ | ● ARN/EUIN, trail, B30, scorecards |
| AMC finance & yield MIS (D15) | ○ | ○ | ○ | ○ | ● TER, yield, profitability |
| Data platform (D16) | ● | ● | ● (Alpha Data Platform) | ◐ | ● |
| Open APIs | ● | ● (Aladdin Studio) | ● | ● | ● API-first |
| Governed AI that cannot approve or post (D17) | ◐ | ◐ | ◐ | ○ | ● by design (ADR-0008) |

Public material was not reviewed in enough depth to rate every cell confidently; ◐ and ○ ratings for the benchmarks are **[ASSUMPTION]** and should be checked before any external use.

## 3. What AMC OS takes as reference

1. **One book of record** across front, middle and back office (all four).
2. **Data platform as a product** with catalogue and governance (Alpha Data Platform, Aladdin).
3. **Programmatic access** to analytics and workflows (Aladdin Studio, Murex APIs).
4. **Integrated risk and optimisation** next to portfolio management (SimCorp with Axioma).
5. **Deployment choice**: on-premises, cloud, SaaS (Murex) → our shared and dedicated cells.

## 4. Where AMC OS differs

| Differentiator | Why it matters to Indian AMCs |
| --- | --- |
| India-native workflows: RTA mirror, AMFI, SEBI formats, IDCW, ARN/EUIN, T30/B30 | Removes the customisation global platforms need for Indian MF operations |
| Distribution and AMC-finance domains built in | Sales and profitability analytics are core to Indian AMCs and absent from benchmark positioning |
| Regulation as versioned, tested, traceable data | SEBI rules change often; evidence for inspections comes out of the system |
| Priced and packaged for new and mid-size AMCs **[ASSUMPTION]** | The growing segments (PS-003 §2) |
| Governed AI by design | Copilots cannot move money or approve anything; every number is cited |

## Sources

- [B1] [Deutsche Börse — final tender result for SimCorp takeover (Sep 2023)](https://www.deutsche-boerse.com/dbg-en/media/news-stories/press-releases/Deutsche-B-rse-announces-final-tender-result-for-takeover-of-SimCorp-3685174)
- [B2] [The TRADE — SimCorp valued at US$4.3 bn](https://thetradenews.com/deutsche-borse-confirms-final-tender-result-for-simcorp-acquisition)
- [B3] [Deutsche Börse — SimCorp Alternatives (Sep 2025), SimCorp includes Axioma](https://deutsche-boerse.com/dbg-en/media/news-stories/press-releases/SimCorp-to-transform-private-market-investing-with-SimCorp-Alternatives-4654920)
- [B4] [BlackRock — Aladdin Studio for Aladdin Risk](https://www.blackrock.com/aladdin/discover/resources/aladdin-studio-for-aladdin-risk-management)
- [B5] [State Street — Forging connections with State Street Alpha (Charles River acquired 2018)](https://stakeholderreport.statestreet.com/Y2019/Details/2019/forging-connections-with-state-street-alpha/default.aspx)
- [B6] [State Street — Alpha Data Platform](https://www.statestreet.com/microsite/alpha/data-platform-services/)
- [B7] [Murex — MX.3 for Investment Management](https://www.murex.com/en/investment-management)
- [B8] [Murex — Smart technology for capital markets](https://murex.com/en/solutions/smart-technology-capital-markets)
