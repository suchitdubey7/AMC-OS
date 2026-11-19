---
id: EA-104
title: Product Suites and Role Workspaces — Proposal
status: Draft
version: 0.1
owner: Chief Product Architect
approver: Project owner (interim ARB)
work_package: WP3 (proposal; depends on WP2 roles BA-005)
last_updated: 2026-11-20
---

# EA-104 — Product Suites and Role Workspaces (Proposal)

> **PROPOSAL** — part of the [EA-100](EA-100_ai_orchestration_architecture_proposal.md) set. Workspace contents depend on roles (BA-005) and workflows (BA-004), not yet written.

## 1. Eight product suites

| # | Suite | Domains covered (GOV-001 D01–D17) | Main agents |
| --- | --- | --- | --- |
| S1 | Investment Management | D03 Investment Mgmt, D04 Portfolio Mgmt, D05 OMS, D06 Trading and Execution | CIO, Investment Research, Portfolio Mgmt, Trading |
| S2 | Risk and Compliance | D08 Compliance, D09 Risk | Compliance, Risk |
| S3 | Fund Operations | D07 Settlement, D10 Fund Accounting, D11 Valuation and NAV, D12 Fund Operations | NAV Ops, Fund Accounting, Reconciliation |
| S4 | Investor Services | D13 Investor Management and Servicing | Investor Servicing |
| S5 | Distribution and Growth | D14 Distribution | Distribution Intelligence |
| S6 | Finance and Leadership | D15 Finance and Management Reporting | CFO/Finance, CEO Intelligence |
| S7 | Data and AI Platform | D16 Enterprise Data Platform, D17 AI and Decision Intelligence | Supervisor, utility agents |
| S8 | Platform Administration | D01 Platform Administration, D02 Product and Scheme | Integration Health, Workflow Assistant (D02 has no specialist agent — EA-100 O-9) |

Domain codes follow GOV-001 §3; the exact D-code titles there take precedence over the short names above.

## 2. Twelve workspaces

Every workspace follows the same rules: data comes from deterministic APIs; AI panels show sources and confidence; actions above R1 open the normal approval workflow; nothing in the UI calculates money.

| # | Workspace | Primary users | Key views | AI assistance (propose only) | Human actions (examples) |
| --- | --- | --- | --- | --- | --- |
| W1 | CEO Command Centre | CEO, MD's office | AUM, flows, market share, profitability, risk and compliance headline, open escalations | Narrative briefs, variance explanation, board-pack drafts | Approve board pack (human) |
| W2 | CIO Investment Desk | CIO | Fund performance, attribution, exposure, risk limits, research pipeline | Cross-fund summaries, idea comparison | Approve house views |
| W3 | Fund Manager Workspace | Fund managers | Positions, cash, model vs actual, what-if, pre-trade compliance | Rebalance drafts, research Q&A | Submit orders |
| W4 | Dealer Workspace | Dealers | Order blotter, broker routing, fills, UNKNOWN queue | Broker/venue notes, exception summaries | Release, cancel, resolve UNKNOWN |
| W5 | Compliance Control Room | Compliance officers | Pre/post-trade results, breaches, regulatory calendar, filings | Circular summaries, rule-change proposals | Approve rule versions, close breaches |
| W6 | Risk Command Centre | Risk team | Liquidity, concentration, VaR/stress (engine outputs), limits | Driver explanations | Approve limit changes |
| W7 | NAV and Accounting Desk | Fund accountants, NAV ops | NAV runs, price exceptions, accruals, journal review, shadow NAV breaks | Break explanations, checklist status | Approve NAV / journals (maker-checker) |
| W8 | Investor Operations Desk | Investor service | Investor 360, requests, complaints, RTA exceptions | Reply drafts, complaint classification | Send replies, resolve cases |
| W9 | Distribution Growth Centre | Sales, distribution | Flows by distributor/region, SIP book, campaigns, commission | Opportunity lists, meeting briefs | Plan campaigns |
| W10 | CFO Workspace | CFO, finance | AMC P&L, TER utilisation, expenses, budgets | Variance commentary | Approve budgets |
| W11 | Enterprise AI Assistant | All users | Chat across permitted domains with citations | Supervisor routes to agents | — |
| W12 | Platform Administration | Tenant admins, ops | Users, roles, SoR registry, agent/tool enablement, integrations health, audit search | Configuration checks | R3 configuration changes |

## 3. Configuration per tenant

Workspaces, widgets, enabled agents and tools are tenant configuration, not code. A workspace view appears only if the tenant has the module and the user has the permission.

## 4. Open items

- Roles and permission matrix per workspace (BA-005).
- Whether W1 and W2 are separate products for pricing (commercial, Step 1 follow-up).
