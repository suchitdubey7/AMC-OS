---
id: PS-003
title: Market and Customer Analysis
status: Draft
version: 0.2
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 1
last_updated: 2026-11-19
---

# PS-003 — Market and Customer Analysis

The Indian mutual fund market is large and growing but has only about 51 AMCs, so AMC OS is a few-big-customers business. The best first customers are new and mid-size AMCs, whose share of industry assets is rising and who need a full stack quickly.

All figures were checked on 19 Nov 2026; sources are listed at the end. Secondary sources (press and aggregators reporting someone else's data) are marked "secondary".

**Builds on Draft documents:** PS-001 (charter) and GOV-006 (plan). This is allowed in the documentation phase by owner decision D-3 ([GOV-008 §2](../00_governance/GOV-008_build_loop.md#2-rules), rule 3).

## 1. Market facts

| Measure | Value | Date | Source |
| --- | --- | --- | --- |
| Industry AUM | ₹83,38,858 crore | 31 Oct 2026 | AMFI [S1] |
| Industry average AUM | ₹85,17,505 crore | Oct 2026 | AMFI [S1] |
| Investor folios | 28.78 crore | 31 Oct 2026 | AMFI [S1] |
| Number of AMCs | 43 → 51 | Mar 2022 → Mar 2026 | AMFI-Crisil Factbook via 5paisa [S2] (secondary) |
| Top-10 AMC share of AUM | 81.7% → 76.3% | Dec 2021 → Mar 2026 | AMFI-Crisil Factbook via 5paisa [S2] (secondary) |
| Monthly SIP contribution | ₹32,160 crore | Oct 2026 | AMFI data via FinTech BizNews [S3] (secondary) |
| Contributing SIP accounts | 9,99,87,082 | Oct 2026 | AMFI data via FinTech BizNews [S3] (secondary) |
| SIP AUM | ₹17.68 lakh crore, 21.2% of industry AUM | Oct 2026 | AMFI data via Equitybulls [S4] (secondary) |
| CAMS share of mutual fund AAUM | about 68% | FY 2025-26 | CAMS management discussion and analysis, via IIFL [S5] (secondary host of a company filing) |
| KFin share of the domestic mutual fund market (basis not stated) | 32.5% (up from 30.3% in FY22) | FY 2025-26 | KFintech Q4 FY26 earnings call transcript [S6] |
| New licences | Count around 40 for a decade, rose to 50 with 8 licences in 2 years; recent entrants include JioBlackRock, The Wealth Company, Choice | Aug 2025 | Business Standard [S7] (press, secondary) |

The CAMS and KFin shares come from each company's own disclosure, so their bases may differ slightly; together they add up to about 100% of the mutual fund market.

## 2. What the facts mean for AMC OS

| Fact | Implication | Where it lands |
| --- | --- | --- |
| Only ~51 AMCs | Few customers, high value each; a long sales cycle per deal; the product must earn trust through evidence (parallel runs) | PS-001 §5.3 (decided: pilot → 3–5) |
| Top-10 share falling (81.7% → 76.3%) and AMC count rising | Mid-size and new AMCs are growing; they are the natural first customers | Segment priority §3 |
| New entrants keep arriving | Each needs a full operating stack from day one; no legacy to replace | Beachhead segment C3 |
| CAMS (≈68%) and KFin (32.5%) together service about 100% of the mutual fund market [S5][S6] | Two RTA adapters (CAMS, KFin) should cover practically every AMC. CAMS's own report says the wider RTA industry "is dominated by three QRTAs" [S5]; the third one was not identified in this step and is **[ASSUMPTION]** not a material mutual fund RTA (confirm: Product Manager, from SEBI's QRTA list and AMFI's RTA list) | INT-001 priority (Step 14) |
| ~10 crore SIP accounts contributing monthly | Investor-transaction volumes are very high even in mirror mode; partitioning and bulk loading are mandatory | DA-000 Ch 9; Step 19 |
| SIP is 21% of AUM | SIP analytics (book, continuity, cancellations) are a core MIS need | PRD-013, PRD-014 |

## 3. Customer segments and priority

This table is the single source for customer segments. It **supersedes PS-001 §5.2** (which now links here) and refines PRD-000 §1.4 (an input, re-keyed in Steps 6–9). Differences declared:

- PRD-000 §1.4 treats mid-size and new AMCs together as "primary"; this table puts new AMCs (C3) first.
- C2's first purchase follows the land-and-expand model in PS-001 §6 (enter with one high-pain module, then expand), not "front-to-back core" as PS-001 §5.2 v0.1 said.

| Priority | Segment | Profile | Likely first purchase | Deployment |
| --- | --- | --- | --- | --- |
| 1 | C3 New and recently licensed AMCs | Building operations from scratch, including passive-only entrants **[VAL — current licensing routes; confirm: Compliance advisor]**; small teams; need speed | Full stack: platform, product, OMS, compliance, distribution MIS, NAV oversight | Shared SaaS |
| 2 | C2 Mid-size AMCs (outside top 10) | Growing share; mixed legacy; cost-sensitive | One high-pain module first (compliance + risk, or distribution analytics + MIS), then front-to-back core (OMS + compliance + accounting/NAV oversight) | Shared SaaS or dedicated |
| 3 | C1 Large AMCs (top 10) | Heavy legacy and in-house IT; strict vendor due diligence | Individual modules: data platform, compliance engine, risk, AI copilots | Dedicated |
| Later | C4 Adjacent: SIF arms, PMS/AIF managers, GIFT City funds | Related operations; separate rules | Selected modules | Shared SaaS |

**[ASSUMPTION — confirm: project owner (question Q10 in LOOP_STATE.md)]** C3 before C2 as the beachhead. Reason: new AMCs have no legacy to replace and need a full stack quickly. Risk: few new licences per year (§1).

**Gap [ASSUMPTION]:** an AMC-by-AMC list by AUM band was not compiled in this step. It should be built from AMFI's AUM-by-fund-house data before sales planning (owner: Product Manager).

## 4. Buyers and buying process

| Role | Part in the decision |
| --- | --- |
| CEO / MD | Sponsor; approves budget |
| CTO / CISO | Technical and security due diligence; data residency; vendor risk |
| COO | Operational fit; parallel-run sign-off |
| CCO | Regulatory and outsourcing approval **[VAL — SEBI requirements on technology outsourcing and third-party risk for AMCs; confirm: Compliance advisor]** |
| CFO | Commercials |
| Board / Trustees | Material outsourcing approval where required **[VAL — confirm: Compliance advisor]** |

Sales cycles for core financial systems are long; plan 9–18 months from first meeting to pilot contract **[ASSUMPTION — confirm: Product Manager, through 3–5 industry conversations]**.

## 5. Competitive landscape (by type)

| Type | Examples | Strength | Weakness for Indian AMCs | AMC OS position |
| --- | --- | --- | --- | --- |
| Global front-to-back platforms | SimCorp, State Street Alpha / Charles River, BlackRock Aladdin, Murex | Depth, scale, reputation | Built for global institutions; India-specific flows (RTA, AMFI, SEBI formats) need customisation; high cost **[ASSUMPTION — confirm: Chief Enterprise Architect, against vendor material and Indian AMC references]** | India-native, priced for mid-size and new AMCs; see PS-004 |
| RTAs | CAMS, KFin | Service about 100% of the mutual fund market between them (§1) | Not investment, compliance or accounting platforms | Integrate, not compete (mirror mode) |
| Custodian fund-accounting services | Custodian banks | Outsourced accounting and NAV | AMC has limited real-time visibility of the books **[ASSUMPTION — confirm: Product Manager, with AMC operations heads]** | NAV oversight and shadow accounting first |
| Indian AMC software vendors and in-house builds | **Not yet researched** | — | — | Research in WP2 before sales planning (owner: Product Manager) |

## 6. Open questions

1. Build the AMC list by AUM band and name the top 10 pilot candidates (C3 and C2).
2. Research Indian vendors and in-house systems competing in OMS, compliance and fund accounting.
3. Validate pricing assumptions with 3–5 industry conversations.
4. Identify the third QRTA named in [S5] and confirm it does not service mutual funds materially.

## 7. Terms used

| Term | Meaning |
| --- | --- |
| AUM / AAUM | Assets under management / average AUM over a period |
| RTA | Registrar and Transfer Agent: keeps the investor (unitholder) records for the AMC |
| QRTA | Qualified RTA: SEBI's category for large RTAs, which face extra oversight |
| SIP | Systematic Investment Plan: a fixed monthly investment |
| MIS | Management information (internal reports) |
| SIF | Specialised Investment Fund: a SEBI fund category run by eligible AMCs |
| PMS / AIF | Portfolio Management Services / Alternative Investment Fund |
| GIFT City funds | Funds set up in India's international financial services centre (GIFT IFSC), regulated by IFSCA |

The full glossary with IDs comes in BA-003 (Step 3).

## Sources

- [S1] [AMFI — Industry AAUM, October 2026](https://www.amfiindia.com/articles/indian-mutual)
- [S2] [5paisa — Equity flows shift beyond top 10 AMCs (citing AMFI-Crisil Factbook 2026)](https://www.5paisa.com/blog/equity-flows-shift-beyond-top-10-amcs-as-smaller-fund-houses-gain-ground) — secondary
- [S3] [FinTech BizNews — AMFI monthly data, October 2026](https://fintechbiznews.com/finserv-mf-amcs/mf-sector-aum-up-just-9) — secondary
- [S4] [Equitybulls — Highlights of AMFI monthly data, October 2026](https://www.equitybulls.com/news/379006/highlights-amfi-mutual-fund-industry-monthly-data-october-2026) — secondary
- [S5] [IIFL — CAMS management discussion and analysis, FY 2025-26](https://www.indiainfoline.com/company/computer-age-management-services-ltd-share-price/management-discussions/47716) — secondary host of a company filing
- [S6] [KFintech — Q4 FY26 earnings call transcript (30 Apr 2026)](https://investor.kfintech.com/wp-content/uploads/2026/05/KFintech-Earnings-Concall-Transcript-Q4FY26.pdf)
- [S7] [Business Standard — MF roster swells to 50](https://www.business-standard.com/amp/markets/mutual-fund/mf-roster-swells-to-50-8-licences-issued-in-2-years-8-more-await-sebi-nod-125081201814_1.html) — press, secondary
