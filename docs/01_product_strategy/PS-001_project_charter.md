---
id: PS-001
title: AMC OS Project Charter
status: Draft
version: 0.1
owner: Product Manager
approver: Project owner / sponsor
work_package: WP1
last_updated: 2026-11-19
---

# PS-001 — AMC OS Project Charter

AMC OS will be a single, multi-tenant operating platform that runs an Indian mutual fund AMC end to end, from scheme launch to daily NAV to distributor payouts, with deterministic financial engines and governed AI. This charter fixes the scope, objectives, customers, deployment models, boundaries and how success is measured.

## 1. Vision

> Every number an AMC reports — NAV, AUM, exposure, revenue, commission — comes from one auditable system, can be reproduced exactly for any past date, and can be explained in plain language on demand.

## 2. Problem

Indian AMCs run on many separate systems: an order management system, a fund-accounting system (often at the custodian), RTA portals for investor data, separate compliance and risk tools, and Excel for management reporting. Data is re-keyed and reconciled between them every day, limit breaches are found late, NAV checks are manual, and leadership MIS takes days. Detail: PRD-000 §1.3.

## 3. Scope

**In scope:** the 17 domains D01–D17 in [GOV-001 §3](../00_governance/GOV-001_document_control_and_identifiers.md#3-domain-identifiers), delivered as one product with:

- deterministic engines FE-01–FE-10 for every official number;
- multi-tenant SaaS and dedicated deployments from one codebase;
- adapters to Indian market infrastructure (AMFI, exchanges, RTAs, depositories, custodians, banks, brokers, KRA/CKYC, data vendors), built only to interfaces confirmed by each provider;
- governed AI assistants that read, explain and propose, never approve or post.

**Out of scope (product boundaries):**

| Not in AMC OS | Why / who does it |
| --- | --- |
| Acting as the Registrar & Transfer Agent of record | CAMS / KFin remain RTAs; AMC OS mirrors and services the investor book (mode A). An RTA-grade mode needs a separate regulatory decision **[VAL]** |
| Custody, broking, exchange, clearing, banking | Counterparties; AMC OS instructs and reconciles |
| KRA / CKYC registry | Queried and updated via approved channels |
| Algorithmic execution | Broker algorithms; AMC OS routes orders |
| The AMC company's own statutory books | Corporate ERP; AMC OS exports management P&L |
| AI that executes, approves, posts or publishes | Prohibited by principle 3.1 |

## 4. Objectives

| # | Objective (master prompt §2) | Measurable outcome (proposed) |
| --- | --- | --- |
| O1 | Complete AMC operating platform | All 17 domains live at a pilot AMC by month 24 of the roadmap |
| O2 | Replace fragmented systems | Pilot AMC retires ≥ 3 legacy systems or spreadsheets per domain go-live |
| O3 | Governed financial data foundation | 100% of CXO dashboard metrics come from the certified metric registry |
| O4 | Automate repetitive workflows | ≥ 95% auto-match on holdings, trade and cash reconciliations |
| O5 | Deterministic engines | 100% NAV match (or signed-off explanation) across a ≥ 3-month parallel run |
| O6 | AI research and decision support | Zero uncited numbers in AI answers; measurable analyst time saved |
| O7 | Indian infrastructure integration | Certified adapters for the pilot AMC's RTA, custodian, banks and brokers |
| O8 | Configurable workflows | No customer-specific code branches; all variation via governed configuration |
| O9 | SaaS and dedicated models | Both deployment models run the same release |
| O10 | Commercially scalable | See §6 |

All targets are proposals for sponsor approval.

## 5. Customers

### 5.1 Market facts (verified 19 Nov 2026)

- The number of AMCs in the industry grew from 43 in March 2022 to 51 by March 2026, and the top 10 AMCs held 76.3% of industry AUM in March 2026 (AMFI-Crisil Factbook 2026, as reported by 5paisa). **[fact — secondary source]**
- Industry AUM was ₹83,38,858 crore on 31 October 2026, with 28.78 crore folios (AMFI). **[fact — AMFI]**

### 5.2 Customer profiles

| Segment | Description | What they buy first | Deployment |
| --- | --- | --- | --- |
| C1 Large AMCs (top 10) | Very large AUM, heavy legacy, in-house IT | Individual modules: compliance, risk, data platform, AI | Dedicated |
| C2 Mid-size AMCs | Growing, mixed legacy, cost-sensitive | Front-to-back core (OMS + compliance + accounting/NAV oversight) | Shared SaaS or dedicated |
| C3 New and small AMCs | Recently licensed, including passive-only entrants **[VAL — current licensing routes]** | Full stack from day one | Shared SaaS |
| C4 Adjacent (later) | Specialised Investment Fund arms, PMS/AIF managers in AMC groups | Selected modules | Shared SaaS |

### 5.3 Important commercial finding — target scale

The brief sets an initial target of **20–50 AMC customers**. With about 51 AMCs in India, that equals roughly 40–100% of every AMC in the country. That is a full-market-share target, not an initial one.

Decision **(project owner, 19 Nov 2026 — GOV-006 Q1): adopted.**

1. Keep **50 tenants** as the *technical* design capacity (cells, isolation, performance).
2. Set the *commercial* target as 1 pilot AMC, then 3–5 paying AMCs, before scaling.
3. Plan growth beyond Indian mutual funds (SIF, PMS, AIF, GIFT City funds) for revenue scale. Each needs its own regulatory review.

## 6. Commercial objectives (proposed)

| Item | Proposal |
| --- | --- |
| Pricing basis | Platform fee per module + AUM-tiered fee; dedicated deployment priced on infrastructure + support |
| Land-and-expand | Enter via a high-pain module (compliance, risk, distribution analytics, data platform), expand to front-to-back |
| Unit economics | Gross margin target set after the first pilot, once hosting and support costs are measured |
| Pilot | One design-partner AMC from month 18–22, with a parallel run before go-live |

## 7. Deployment models

| Model | Summary | Detail |
| --- | --- | --- |
| A — Shared SaaS | Several AMCs share an application cell; isolation by authenticated tenant context, PostgreSQL RLS, composite tenant keys, per-tenant keys and storage | ADR-0003; WP3 EA-004/005 |
| B — Dedicated | One AMC gets its own cell: app, database, analytics, storage, keys, network, monitoring, backups | ADR-0003; WP3 EA-004 |
| Common | One codebase and release train; customisation only through governed configuration; control plane separate from the financial data plane | ADR-0002, ADR-0003 |

## 8. Success measures

| Area | Measure |
| --- | --- |
| Correctness | Zero unexplained differences in NAV, TB, unit balances and commission in parallel runs |
| Isolation | Zero cross-tenant data exposure; cross-tenant negative tests run on every build |
| Timeliness | NAV ready for approval within the AMC's internal deadline on ≥ 99.5% of business days (deadline set per customer) |
| Automation | Reconciliation auto-match ≥ 95%; MIS turnaround from days to same day |
| Audit | 100% of approvals, overrides and financial state changes in the hash-chained audit log |
| Delivery | Each work package and build increment passes its gates without waivers on T1 items |
| Commercial | Pilot signed; then 3–5 paying AMCs |

## 9. Roadmap baseline

The master prompt's 24-month programme (months 1–3 documentation … months 22–24 pilot and rollout) is adopted as the planning baseline. It is not a guaranteed deadline, and correctness is never traded for schedule. The v0.9 PRD's 30-month, 10-phase roadmap is retired in favour of this baseline in WP2.

## 10. Key risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Provider integrations (RTA, custodian, banks) are vendor-controlled | Delays; scope limits | Adapter pattern; early provider engagement; no invented APIs |
| Regulatory change during build | Rework | Rules as versioned data; regulatory control registry |
| Small addressable market (~51 AMCs) | Revenue ceiling | §5.3 recommendation; adjacent segments |
| Large incumbents' switching costs | Slow sales | Module-first entry; parallel-run evidence |
| Founder-stage team | Governance seats unfilled | Interim approver (GOV-002 §1); hire plan |
| AI data-residency and licence limits | AI features restricted | India-region endpoints; licence checks per vendor |

## 11. Governance and sponsorship

| Role | Person |
| --- | --- |
| Sponsor / project owner | Suchit Dubey |
| Interim approver for all documents | Project owner (until ARB staffed — GOV-002 §1) |
| ARB | To be staffed |

## 12. Open decisions for the sponsor

1. ~~Commercial target~~ — decided: design capacity 50 tenants; commercial 1 pilot → 3–5 AMCs (GOV-006 Q1).
2. Investor book — decided: mirror the RTA (GOV-006 Q2).
3. Confirm proposed objective targets in §4 and success measures in §8.
4. Confirm the 24-month roadmap baseline replaces the v0.9 30-month roadmap.
5. Name a design-partner AMC candidate for the pilot, if any.

## Sources

- [Equity flows shift beyond top 10 AMCs — 5paisa (citing AMFI-Crisil Factbook 2026)](https://www.5paisa.com/blog/equity-flows-shift-beyond-top-10-amcs-as-smaller-fund-houses-gain-ground)
- [Industry AAUM October 2026 — AMFI](https://www.amfiindia.com/articles/indian-mutual)
