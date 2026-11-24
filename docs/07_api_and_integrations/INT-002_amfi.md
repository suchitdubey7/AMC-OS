---
id: INT-002
title: Provider Specification — AMFI (NAV publication, distributor registration data, industry data)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-002 — AMFI

Outside system X12 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows the rules of [INT-001](INT-001_integration_architecture.md). **No AMFI interface for AMCs is specified here**: the channel an AMC uses to submit NAV and the formats of AMFI's member data are not public in the sources found, so they are **Confirm with AMFI**. Builds on Draft documents EA-001, EA-003, EA-007, PRD-011, PRD-014, PRD-016 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | Association of Mutual Funds in India (AMFI), the industry body of SEBI-registered mutual funds | [IND] |
| 2 | Business purpose | (a) NAV made public on the AMFI website each business day; (b) check that a distributor's ARN and EUIN are valid (D14 commission and empanelment, WF-039); (c) industry lists and data (for example the half-yearly market-capitalisation list used for scheme categorisation, PRD-000 Ch 8 **[REG — VAL]**; monthly industry AUM and flows for Finance and Distribution analytics); (d) AMFI scheme codes for new schemes and plans (Product, WF-001 — a human set-up task; PRD-000 Ch 8 "scheme codes") — Confirm with AMFI | [DES] |
| 3 | Approved interface | **NAV out:** how an AMC (or the custodian or RTA on its behalf, D-44) submits NAV to AMFI — Confirm with AMFI. **NAV published (read back):** AMFI publishes text reports on its website: "Complete NAV Report" `NAVAll.txt`, open-ended, close-ended and interval-fund reports, and a NAV history download limited to 90 days per request (AMFI "NAV Download" page, seen 22 Nov 2026) **[IND]**. **ARN / EUIN data:** source and channel Confirm with AMFI (BA-004 WF-013 hand-off marks it [ASSUMPTION]). **Industry lists:** AMFI website publications — Confirm format per list | [IND] / Confirm |
| 4 | Authentication | Public website reports: none. Member submission and member data: Confirm with AMFI (expected to be an AMC member login; AMC OS never stores a person's password, INT-001 I12) | Confirm |
| 5 | Data contract | Canonical families (INT-001 §3): **NAV publication record** (scheme / plan code, NAV date, NAV, as published) owned by NAV; **distributor registration** (ARN, EUIN, validity dates, status) owned by Distribution; **industry list** (list name, period, security identifiers, category) owned by Security master. Field mapping from AMFI's layout is written only after the layout is confirmed | [DES] |
| 6 | Ingestion schedule | Published NAV read back each business evening after the tenant's NAV publication time and again next morning; ARN / EUIN validity before each commission run and daily for empanelled distributors **[ASSUMPTION]**; lists when AMFI publishes them. NAV disclosure time limits are set by SEBI: for most schemes 11 p.m. on the business day; later limits for some scheme types, for example schemes investing mainly overseas (SEBI circular SEBI/HO/IMD/IMD-I POD2/P/CIR/2023/48, 29 Mar 2023, effective 1 Jul 2023, read via the AMFI-hosted copy; the table in that copy did not extract cleanly, so the scheme categories and their thresholds are not quoted here) **[REG — VAL: Compliance to confirm the current limits and categories against the SEBI original and the Master Circular]**. The limits are tenant calendar settings, not code | [REG — VAL] / [ASSUMPTION] |
| 7 | Error handling | Published NAV missing or different from the approved NAV → NAV exception task (WF-007 / WF-017); ARN not found or expired → distributor flagged, commission held (PRD-014); malformed file → quarantine (INT-001 §8) | [DES] |
| 8 | Retry logic | Reads (published NAV, lists): class A1, retried with back-off. NAV submission: class A2 — never retried automatically (§2) | [DES] |
| 9 | Idempotency | Published NAV: tenant + scheme/plan code + NAV date; ARN: tenant + ARN + as-of date; NAV submission: EA-007 key + client reference (§2) | [DES] |
| 10 | Reconciliation | Published NAV vs approved NAV (`NAV_APPROVED`) for every plan, every day; ARN validity vs distributor master (PRD-000 Ch 8) | [DES] |
| 11 | Monitoring | NAV not visible in the AMFI report by the tenant's check time → alert to NAV team; count of plans published vs approved; ARN check failures | [DES] |
| 12 | Commercial dependency | AMFI membership of the AMC; no fee assumed for public reports; terms of use of the AMFI website for automated download **[VAL — owner question Q80]** | [VAL] |
| 13 | Certification requirements | Confirm with AMFI whether any test or registration is needed before an AMC submits NAV from a new system | Confirm |
| 14 | Operational ownership | NAV submission and published-NAV check: DEP-07 Fund accounting and NAV; ARN / EUIN: DEP-12 Sales and distribution; lists: DEP-17 Data and analytics; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2)

| Instruction | Owning module | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- |
| NAV submission to AMFI, only where the tenant setting says the AMC submits (D-44) | NAV | Confirm with AMFI | None known. The public NAV report shows what AMFI published and is read back (field 10) | NAV team compares the AMFI report with the approved NAV and, if it differs or is missing, contacts AMFI; a resend is released by a person |

## 3. Confirm with AMFI

1. Channel, format and timing for an AMC's NAV submission, and whether a custodian or RTA may submit on the AMC's behalf.
2. Whether a correction to a published NAV is a resubmission or a separate process (WF-017).
3. Source and format of ARN / EUIN validity data available to AMCs.
4. Terms of use for automated reading of the public NAV reports.
5. How an AMC obtains AMFI scheme codes for new schemes and plans.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | AMFI, "NAV Download", https://www.amfiindia.com/net-asset-value/nav-download (read 22 Nov 2026) | Report names, 90-day history limit |
| S2 | SEBI circular SEBI/HO/IMD/IMD-I POD2/P/CIR/2023/48, 29 Mar 2023, "Review of time limit for disclosure of NAV of Mutual fund schemes investing overseas", AMFI-hosted copy https://www.amfiindia.com/uploads/Reviewoftimelimitfordisclosureof_NAV_f5ebc65062.pdf (read 22 Nov 2026; table extraction garbled) | NAV disclosure time limits |
| S3 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 AMFI row | Purpose, data exchanged |
| S4 | [EA-001](../04_enterprise_architecture/EA-001_system_context.md) X12; [EA-007](../04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md) §10.1 | Context, publication step |
