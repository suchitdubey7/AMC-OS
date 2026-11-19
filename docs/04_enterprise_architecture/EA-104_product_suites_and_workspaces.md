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
| SU-1 | Investment Management | D03 Investment Mgmt, D04 Portfolio Mgmt, D05 OMS, D06 Trading and Execution | CIO, Investment Research, Portfolio Mgmt, Trading |
| SU-2 | Risk and Compliance | D08 Compliance, D09 Risk | Compliance, Risk |
| SU-3 | Fund Operations | D07 Settlement, D10 Fund Accounting, D11 Valuation and NAV, D12 Fund Operations | NAV Ops, Fund Accounting, Reconciliation |
| SU-4 | Investor Services | D13 Investor Management and Servicing | Investor Servicing |
| SU-5 | Distribution and Growth | D14 Distribution | Distribution Intelligence |
| SU-6 | Finance and Leadership | D15 Finance and Management Reporting | CFO/Finance, CEO Intelligence |
| SU-7 | Data and AI Platform | D16 Enterprise Data Platform, D17 AI and Decision Intelligence | Supervisor, utility agents |
| SU-8 | Platform Administration | D01 Platform Administration, D02 Product and Scheme | Integration Health, Workflow Assistant (D02 has no specialist agent — EA-100 OD-9) |

Domain codes follow GOV-001 §3; the exact D-code titles there take precedence over the short names above.

## 2. Twelve workspaces

Every workspace follows the same rules: data comes from deterministic APIs; AI panels show sources and confidence; actions above R1 open the normal approval workflow; nothing in the UI calculates money.

| # | Workspace | Primary users | Key views | AI assistance (propose only) | Human actions (examples) |
| --- | --- | --- | --- | --- | --- |
| WS-01 | CEO Command Centre | CEO, MD's office | AUM, flows, market share, profitability, risk and compliance headline, open escalations | Narrative briefs, variance explanation, board-pack drafts | Approve board pack (human) |
| WS-02 | CIO Investment Desk | CIO | Fund performance, attribution, exposure, risk limits, research pipeline | Cross-fund summaries, idea comparison | Approve house views |
| WS-03 | Fund Manager Workspace | Fund managers | Positions, cash, model vs actual, what-if, pre-trade compliance | Rebalance drafts, research Q&A | Submit orders |
| WS-04 | Dealer Workspace | Dealers | Order blotter, broker routing, fills, UNKNOWN queue | Broker/venue notes, exception summaries | Release, cancel, resolve UNKNOWN |
| WS-05 | Compliance Control Room | Compliance officers | Pre/post-trade results, breaches, regulatory calendar, filings | Circular summaries, rule-change proposals | Approve rule versions, close breaches |
| WS-06 | Risk Command Centre | Risk team | Liquidity, concentration, VaR/stress (engine outputs), limits | Driver explanations | Approve limit changes |
| WS-07 | NAV and Accounting Desk | Fund accountants, NAV ops | NAV runs, price exceptions, accruals, journal review, shadow NAV breaks | Break explanations, checklist status | Approve NAV / journals (maker-checker) |
| WS-08 | Investor Operations Desk | Investor service | Investor 360, requests, complaints, RTA exceptions | Reply drafts, complaint classification | Send replies, resolve cases |
| WS-09 | Distribution Growth Centre | Sales, distribution | Flows by distributor/region, SIP book, campaigns, commission | Opportunity lists, meeting briefs | Plan campaigns |
| WS-10 | CFO Workspace | CFO, finance | AMC P&L, TER utilisation, expenses, budgets | Variance commentary | Approve budgets |
| WS-11 | Enterprise AI Assistant | All users | Chat across permitted domains with citations | Supervisor routes to agents | — |
| WS-12 | Platform Administration | Tenant admins, ops | Users, roles, SoR registry, agent/tool enablement, integrations health, audit search | Configuration checks | R3 configuration changes |

### 2.1 Conflict with master prompt §5 L1 (C10, owner decision OD-11)

The owner's list (above) merges fund accounting and NAV into WS-07 and adds a stand-alone AI assistant (WS-11). Master prompt §5 L1 asks for separate experiences for **Fund accounting** and **NAV operations**, and lists no stand-alone AI experience.

| Option | Workspaces | Effect |
| --- | --- | --- |
| A — owner's list | As above (12) | Matches the 20 Nov brief |
| B — master prompt | Split WS-07 into "Fund Accounting Desk" and "NAV Operations Desk"; the AI assistant becomes a panel inside every workspace instead of WS-11 | Matches master prompt §5 L1 |

Until OD-11 is decided, designs should keep fund-accounting and NAV views as separable modules so either option works.

## 3. Configuration per tenant

Workspaces, widgets, enabled agents and tools are tenant configuration, not code. A workspace view appears only if the tenant has the module and the user has the permission.

## 4. Open items

- Roles and permission matrix per workspace (BA-005).
- Whether WS-01 and WS-02 are separate products for pricing (commercial, Step 1 follow-up).
