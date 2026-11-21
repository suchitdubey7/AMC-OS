---
id: INT-004
title: Provider Specification — NSE (market data, corporate actions, clearing obligations, MF platform)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-004 — National Stock Exchange of India (NSE)

Outside systems X03 (exchange and clearing corporation) and X09 (MF transaction platform) of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4, for NSE. Follows [INT-001](INT-001_integration_architecture.md). BSE is the same shape in [INT-005](INT-005_bse.md). Builds on Draft documents EA-001, EA-003, PRD-007, PRD-011, PRD-012, PRD-013 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | National Stock Exchange of India and its group: its clearing corporation (NSE Clearing), its index business (NSE Indices), NSE's mutual-fund platform | [IND] |
| 2 | Business purpose | (a) End-of-day prices (bhavcopy) for equity and ETF valuation (Valuation, D11); (b) corporate-action announcements (Operations, WF-009); (c) index levels where licensed (Security master); (d) clearing obligations for exchange trades, usually received through the custodian (Settlement, WF-026); (e) MF platform: order and allotment data for transactions placed through the exchange platform (Investor, D13) and scheme set-up on the platform (Product, WF-001); PRD-000 Ch 8 also lists platform confirmations going **out** — by default these are sent by the AMC's RTA, which allots units (Q2), and AMC OS only receives and checks them **[ASSUMPTION — Confirm with NSE and the RTA]**; if the AMC itself must send them, §2 applies; (f) **out:** scheme NAV, and for listed schemes such as ETFs the NAV and indicative NAV (iNAV) the exchange disseminates, where the exchange requires them from the AMC (NAV, D11; EA-007 §10.1 channel "exchanges"; PRD-000 Ch 8 "ETF/iNAV") — what, when and how: Confirm with NSE **[VAL]**; note that PRD-011 §1 lists intraday iNAV for ETFs as out of D11 scope with open point C9 (no BA-001 capability), so the owner of iNAV is open — this specification only carries the channel; (g) membership status of brokers on the AMC's panel (Execution, WF-023; BA-004 marks the source **[ASSUMPTION]**) — Confirm with NSE whether and how an AMC can get it | [DES] |
| 3 | Approved interface | **Market data:** exchange data products under NSE's licence terms — Confirm with NSE. BSE's UDiFF page says SEBI's Market Data Advisory Committee asked all market infrastructure institutions to standardise their file formats as "Unified Distilled File Formats" (UDiFF), and that BSE's legacy trade and bhavcopy files were discontinued from 8 Jul 2024 (read 22 Nov 2026) **[IND — BSE source only]**. NSE's own adoption and date were not read in this run — Confirm with NSE; building the NSE adapter on UDiFF only is an **[ASSUMPTION]** until confirmed. **Clearing obligations:** through the custodian (INT-008) or NSE Clearing — Confirm with the custodian and NSE Clearing **[ASSUMPTION]**. **MF platform:** NSE publishes API documents for its MF platform aimed at members and distributors (for example "NSEMF API Details V1.9.7", and an "NSE MF Invest API FAQ" dated 29 Oct 2026 — titles seen in search, 22 Nov 2026, not opened) **[IND]**; whether an AMC receives platform data directly or through its RTA — Confirm with NSE and the RTA | [IND] / Confirm |
| 4 | Authentication | Data licence credentials; platform credentials per AMC — Confirm with NSE; credentials per tenant (INT-001 I7) | Confirm |
| 5 | Data contract | Canonical families: **price**, **corporate-action announcement**, **benchmark and index levels**, **clearing obligation**, **investor transaction** (platform), **scheme set-up** (INT-001 §3) | [DES] |
| 6 | Ingestion schedule | Bhavcopy once per trading day after close; corporate actions daily; index levels daily; platform data per platform cycle — exact times Confirm with NSE; due times are tenant settings on the exchange calendar (INT-001 IN1) | Confirm |
| 7 | Error handling | Missing price for a held security → Valuation exception (WF-007, price-source hierarchy PRD-011); corporate action not matched to a security → Operations queue; malformed file → quarantine | [DES] |
| 8 | Retry logic | Class A1 for all reads. Scheme set-up on the platform is a human task (EA-007 §10.2); no automatic outbound instruction | [DES] |
| 9 | Idempotency | Price: tenant + exchange + security + trade date; corporate action: tenant + exchange announcement reference; platform record: tenant + platform reference + date | [DES] |
| 10 | Reconciliation | Price completeness against held securities; corporate actions cross-checked with a second source (vendor or custodian, PRD-000 Ch 8); clearing obligations vs AMC trades (WF-026); platform transactions vs RTA feed (INT-006/007) | [DES] |
| 11 | Monitoring | Bhavcopy late on a trading day; securities with no price; unmatched corporate actions; platform records not found in the RTA feed | [DES] |
| 12 | Commercial dependency | NSE data licence per AMC (D-62) — including whether a separate NSE Indices licence is needed for index data **[VAL]**; platform onboarding of the AMC | [VAL] |
| 13 | Certification requirements | Platform onboarding tests for the AMC — Confirm with NSE; none known for public end-of-day files | Confirm |
| 14 | Operational ownership | Prices: DEP-07 Fund accounting and NAV; corporate actions and obligations: DEP-06 Fund operations and settlement; platform: DEP-08 Investor services with DEP-13 for scheme set-up; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2)

Trades reach the exchange through brokers (INT-009). Platform scheme set-up is a person's task. Direct sends are possible only for NAV publication and, if the RTA does not send them, MF-platform confirmations:

| Instruction | Owning module | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- |
| Scheme NAV and, for listed schemes (for example ETFs), NAV / iNAV data to NSE — only where NSE requires it from the AMC (field 2 f) | NAV | Confirm with NSE | Confirm with NSE; a published value may be readable back from NSE's public data **[ASSUMPTION]** | NAV team checks NSE's published value against the approved NAV and contacts NSE; resend released by a person with the same key |
| MF-platform confirmations (for example allotment confirmations) — **only if the AMC, not its RTA, must send them** (field 2 e) | Investor | Confirm with NSE / RTA | Confirm with NSE / RTA | Investor Services checks the platform's records with NSE or the RTA; resend released by a person with the same key |

If an iNAV value is calculated during the day, it is calculated by a deterministic engine (master prompt §3.1); whether AMC OS or an outside agent calculates it is **[VAL]**; the capability and its owner are open under PRD-011 C9 (next BA-001 revision), and any AMC OS calculation would be specified with FE-01 (Step 20).

## 3. Confirm with NSE

1. Licensed data products for the AMC and their delivery channel and times.
2. Whether index levels need an NSE Indices licence.
3. MF platform: what data the AMC can receive, and whether directly or through the RTA.
4. Clearing obligations: received from NSE Clearing or only through the custodian.
5. Whether the AMC must send NAV or ETF NAV / iNAV data to NSE, and the channel, timing and acknowledgement.
6. Whether an AMC can obtain broker membership status from NSE (WF-023).
7. NSE's adoption of UDiFF and its date.
8. Does the AMC, or only its RTA, send confirmations to the MF platform?

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | BSE, "UDiFF", https://bseindia.com/static/members/udiff.aspx (read 22 Nov 2026) | UDiFF standard; BSE legacy files discontinued from 8 Jul 2024 (BSE only; NSE not confirmed) |
| S2 | NSE, "NSEMF API Details V1.9.7", https://nseinvestuat.nseindia.com/nsemfdesk/resources/upload/apidetails/NSEMF_API_Details_V1.9.7.pdf and "NSE MF Invest API FAQ", https://nsearchives.nseindia.com//web/mediaattachment/2026-11/NSE_MF_INVEST_API_FAQ_291026_20261102144826.pdf (titles seen in search 22 Nov 2026; not opened) | Existence of platform API documents |
| S3 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 NSE row | Purpose, data exchanged, ETF/iNAV, platform confirmations |
| S5 | [PRD-011](../03_product_requirements/PRD-011_valuation_and_nav.md) §1, C9 | iNAV out of D11 scope, open point |
| S4 | [EA-007](../04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md) §10.1; [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-007, WF-023 hand-offs | NAV channels; broker membership status |
