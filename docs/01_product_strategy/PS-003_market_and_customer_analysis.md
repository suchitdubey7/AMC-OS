---
id: PS-003
title: Market and Customer Analysis
status: Draft
version: 0.1
owner: Product Manager
approver: Project owner (interim ARB)
work_package: WP2
step: 1
last_updated: 2026-11-19
---

# PS-003 — Market and Customer Analysis

The Indian mutual fund market is large and growing but has only about 51 AMCs, so AMC OS is a few-big-customers business. The best first customers are new and mid-size AMCs, whose share of industry assets is rising and who need a full stack quickly.

All figures were checked on 19 Nov 2026; sources are listed at the end. Secondary sources are marked.

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
| RTA market share by AAUM | CAMS ≈ 68%; KFin ≈ 32% | FY26 | CAMS annual-report MD&A via IIFL [S5]; Trade Brains [S6] (secondary) |
| New licences | Count around 40 for a decade, rose to 50 with 8 licences in 2 years; recent entrants include JioBlackRock, The Wealth Company, Choice | Aug 2025 | Business Standard [S7] |

## 2. What the facts mean for AMC OS

| Fact | Implication | Where it lands |
| --- | --- | --- |
| Only ~51 AMCs | Few customers, high value each; a long sales cycle per deal; the product must earn trust through evidence (parallel runs) | PS-001 §5.3 (decided: pilot → 3–5) |
| Top-10 share falling (81.7% → 76.3%) and AMC count rising | Mid-size and new AMCs are growing; they are the natural first customers | Segment priority §3 |
| New entrants keep arriving | Each needs a full operating stack from day one; no legacy to replace | Beachhead segment C3 |
| Two RTAs cover essentially all AUM | Building two RTA adapters (CAMS, KFin) covers the whole market | INT-001 priority (Step 14) |
| ~10 crore SIP accounts contributing monthly | Investor-transaction volumes are very high even in mirror mode; partitioning and bulk loading are mandatory | DA-000 Ch 9; Step 19 |
| SIP is 21% of AUM | SIP analytics (book, continuity, cancellations) are a core MIS need | PRD-013, PRD-014 |

## 3. Customer segments and priority

| Priority | Segment | Profile | Likely first purchase | Deployment |
| --- | --- | --- | --- | --- |
| 1 | C3 New and recently licensed AMCs | Building operations from scratch; small teams; need speed | Full stack: platform, product, OMS, compliance, distribution MIS, NAV oversight | Shared SaaS |
| 2 | C2 Mid-size AMCs (outside top 10) | Growing share; mixed legacy; cost-sensitive | Compliance + risk, or distribution analytics + MIS, then front-to-back | Shared SaaS or dedicated |
| 3 | C1 Large AMCs (top 10) | Heavy legacy and in-house IT; strict vendor due diligence | Individual modules: data platform, compliance engine, AI copilots | Dedicated |
| Later | C4 Adjacent: SIF arms, PMS/AIF managers, GIFT City funds | Related operations; separate rules | Selected modules | Shared SaaS |

**Gap [ASSUMPTION]:** an AMC-by-AMC list by AUM band was not compiled in this step. It should be built from AMFI's AUM-by-fund-house data before sales planning (owner: Product Manager).

## 4. Buyers and buying process

| Role | Part in the decision |
| --- | --- |
| CEO / MD | Sponsor; approves budget |
| CTO / CISO | Technical and security due diligence; data residency; vendor risk |
| COO | Operational fit; parallel-run sign-off |
| CCO | Regulatory and outsourcing approval **[VAL — SEBI requirements on technology outsourcing and third-party risk for AMCs]** |
| CFO | Commercials |
| Board / Trustees | Material outsourcing approval where required **[VAL]** |

Sales cycles for core financial systems are long; plan 9–18 months from first meeting to pilot contract **[ASSUMPTION — validate with industry contacts]**.

## 5. Competitive landscape (by type)

| Type | Examples | Strength | Weakness for Indian AMCs | AMC OS position |
| --- | --- | --- | --- | --- |
| Global front-to-back platforms | SimCorp, State Street Alpha / Charles River, BlackRock Aladdin, Murex | Depth, scale, reputation | Built for global institutions; India-specific flows (RTA, AMFI, SEBI formats) need customisation; high cost **[ASSUMPTION]** | India-native, priced for mid-size and new AMCs; see PS-004 |
| RTAs | CAMS, KFin | Own the investor book; serve nearly all AMCs | Not investment, compliance or accounting platforms | Integrate, not compete (mirror mode) |
| Custodian fund-accounting services | Custodian banks | Outsourced accounting and NAV | AMC has limited real-time visibility | NAV oversight and shadow accounting first |
| Indian AMC software vendors and in-house builds | **Not yet researched** | — | — | Research in WP2 before sales planning (owner: Product Manager) |

## 6. Open questions

1. Build the AMC list by AUM band and name the top 10 pilot candidates (C3 and C2).
2. Research Indian vendors and in-house systems competing in OMS, compliance and fund accounting.
3. Validate pricing assumptions with 3–5 industry conversations.

## Sources

- [S1] [AMFI — Industry AAUM, October 2026](https://www.amfiindia.com/articles/indian-mutual)
- [S2] [5paisa — Equity flows shift beyond top 10 AMCs (citing AMFI-Crisil Factbook 2026)](https://www.5paisa.com/blog/equity-flows-shift-beyond-top-10-amcs-as-smaller-fund-houses-gain-ground)
- [S3] [FinTech BizNews — AMFI monthly data, October 2026](https://fintechbiznews.com/finserv-mf-amcs/mf-sector-aum-up-just-9)
- [S4] [Equitybulls — Highlights of AMFI monthly data, October 2026](https://www.equitybulls.com/news/379006/highlights-amfi-mutual-fund-industry-monthly-data-october-2026)
- [S5] [IIFL — CAMS management discussion](https://www.indiainfoline.com/company/computer-age-management-services-ltd-share-price/management-discussions/47716)
- [S6] [Trade Brains — CAMS and KFin market share](https://tradebrains.in/?p=150222)
- [S7] [Business Standard — MF roster swells to 50](https://www.business-standard.com/amp/markets/mutual-fund/mf-roster-swells-to-50-8-licences-issued-in-2-years-8-more-await-sebi-nod-125081201814_1.html)
