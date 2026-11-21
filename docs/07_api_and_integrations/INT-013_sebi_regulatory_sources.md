---
id: INT-013
title: Provider Specification — SEBI and other regulatory information sources (circulars, filings, SCORES complaints)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-013 — Regulatory information sources (SEBI)

Outside system X13 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4 and the master prompt §10 item "Relevant regulatory information sources". Follows [INT-001](INT-001_integration_architecture.md). **No SEBI API is assumed** (PRD-000 Ch 8). Circulars are read from SEBI's public website; filings are made by people on SEBI's portals (INT-001 I12); complaints are handled on SEBI's SCORES system. A new circular never changes a rule in AMC OS by itself: a person records it, and rule versions change only through WF-034 with the CCO's approval (D-32). Builds on Draft documents EA-001, EA-003, PRD-008, PRD-013, BA-004 WF-016, WF-034 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | Securities and Exchange Board of India (SEBI): public website (circulars, master circulars, regulations), intermediary portals for filings, SCORES complaint system. Other public sources the Compliance team adds (for example AMFI circulars, INT-002) use the same pattern | [REG] |
| 2 | Business purpose | (a) Watch for new circulars and regulations and put each in front of Compliance for triage (WF-034; PRD-000 Ch 8: triaged within 1 business day **[DES]**); (b) prepare reports that people file (WF-016); (c) receive investor complaints raised on SCORES and record responses (Investor, PRD-013) | [DES] |
| 3 | Approved interface | **Circulars:** SEBI public website pages (read; automated fetch only within the site's terms, owner question Q80 **[VAL]**). **Filings:** SEBI portals, by a person — channel per report Confirm with SEBI / Compliance (REG-001, Step 25). **Complaints:** SCORES — SEBI launched "SCORES 2.0" on 1 Apr 2024 (SEBI press release PR No. 37/2024, title and date seen 22 Nov 2026; body not opened) **[REG]**; whether SCORES offers any data interface to entities: Confirm with SEBI; default: complaints are downloaded or keyed by a person | [REG] / Confirm |
| 4 | Authentication | Website: none. Portals and SCORES: the AMC's own credentials held by named people; AMC OS never stores them (INT-001 I12) | [DES] |
| 5 | Data contract | Canonical families: **regulatory circular and filing record** (Compliance), **complaint** (Investor) (INT-001 §3). Each circular record keeps source URL, title, number, date, the raw copy and the extraction time (master prompt §11 RAG metadata) | [DES] |
| 6 | Ingestion schedule | Circular watch daily (PRD-000 Ch 8); complaints daily; filings per the tenant's regulatory calendar | [DES] |
| 7 | Error handling | Website unreachable → alert after the retry budget; Compliance checks manually that day | [DES] |
| 8 | Retry logic | Class A1 for reads. Filings are human steps (not class A2 automation) | [DES] |
| 9 | Idempotency | Circular: tenant + circular number (or URL) + date; complaint: tenant + SCORES complaint number | [DES] |
| 10 | Reconciliation | Complaint count and status in AMC OS vs SCORES (PRD-000 Ch 8); every filing on the calendar has a recorded acknowledgement | [DES] |
| 11 | Monitoring | Watch not run; circulars not triaged within the tenant's limit; complaints past their response deadline (deadline values are [VAL] in PRD-013) | [DES] |
| 12 | Commercial dependency | None (public sources); AMC's portal registrations | [IND] |
| 13 | Certification requirements | None known | [ASSUMPTION] |
| 14 | Operational ownership | DEP-09 Compliance (circulars, filings); DEP-08 Investor services (SCORES complaints); DEP-10 Legal for legal reading (D-35) | [DES] |

## 2. Outbound instructions

None automated. Filings and complaint responses are entered on SEBI's systems by named people; AMC OS records what was filed or answered and the acknowledgement.

## 3. Confirm with SEBI (through Compliance)

1. Whether SCORES 2.0 offers any data interface for regulated entities.
2. Portal and format for each regulatory report the AMC files (REG-001, Step 25).
3. Terms of use for automated reading of the SEBI website.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | SEBI press release PR No. 37/2024, "SCORES 2.0 New Technology to strengthen SEBI Complaint Redressal System for Investors", 1 Apr 2024, https://www.sebi.gov.in/media-and-notifications/press-releases/apr-2024/scores-2-0-new-technology-to-strengthen-sebi-complaint-redressal-system-for-investors_82618.html (title and date read 22 Nov 2026; body PDF not opened) | SCORES 2.0 |
| S2 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 SEBI rows | No API assumed; daily watch; triage |
| S3 | [PRD-008](../03_product_requirements/PRD-008_compliance_management.md) WF-034; [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-016 | Rule change and reporting |
| S4 | [LOOP_STATE.md](../../LOOP_STATE.md) D-32, D-35 | CCO approval, legal reading |
