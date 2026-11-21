---
id: INT-012
title: Provider Specification — KYC Registration Agencies (KRAs) and Central KYC (CKYC)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-012 — KRAs and CKYC

Outside system X08 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). AMC OS mirrors the investor register kept by the RTA (owner decision Q2), and in mirror mode KYC checks are normally done by the RTA on the AMC's behalf (PRD-000 Ch 8; BA-004 WF-010 "KRA through the RTA"). **AMC OS never acts as a KYC registry. Whether the AMC needs any direct KRA or CKYC connection at all is Confirm with the AMC and its RTA; default: none, KYC status arrives in the RTA feed.** Builds on Draft documents EA-001, EA-003, PRD-013 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | SEBI-registered KYC Registration Agencies. PRD-000 Ch 8 lists CVL, NDML, CAMS KRA, KFin KRA and DotEx **[IND — from PRD-000; current list to be confirmed against SEBI's register]**. Central KYC Records Registry operated by CERSAI **[IND]** | [IND] |
| 2 | Business purpose | Know the KYC status of each investor in the mirror, to flag servicing issues and support compliance reporting (Investor, D13). No KYC record is created or changed by AMC OS | [DES] |
| 3 | Approved interface | **Default:** KYC status carried in the RTA feed (INT-006/007). **Direct (only if the AMC asks):** per KRA and per CERSAI specification — Confirm with each KRA and with CERSAI. Vendor material mentions a newer CKYC registry version ("CKYCRR 2.0") **[secondary — vendor web pages seen in search 22 Nov 2026; Confirm with CERSAI]** | Confirm |
| 4 | Authentication | Per KRA / per CERSAI (PRD-000 Ch 8: digital signature for CKYC) — Confirm | Confirm |
| 5 | Data contract | Canonical family: **KYC status** (investor reference, status, agency, as-of date) — part of the investor record; no KYC documents are stored by AMC OS unless the AMC's RTA arrangement requires it **[VAL — DPO]** | [DES] |
| 6 | Ingestion schedule | With the RTA feed (default) | [DES] |
| 7 | Error handling | Status missing or "on hold" for an investor with new transactions → `INVESTOR_DATA_FLAGGED`, task to Investor Services; correction only through the RTA (D-53) | [DES] |
| 8 | Retry logic | Class A1 reads only; no uploads in the default design | [DES] |
| 9 | Idempotency | Tenant + investor reference + agency + as-of date | [DES] |
| 10 | Reconciliation | KYC status vs investor master (PRD-000 Ch 8) | [DES] |
| 11 | Monitoring | Count of investors with non-valid KYC status and new activity | [DES] |
| 12 | Commercial dependency | Through the RTA agreement (default); direct access needs registration with each KRA and with CERSAI as a reporting entity, often via the RTA (PRD-000 Ch 8) **[REG — VAL: Compliance to confirm the AMC's obligations under SEBI KYC rules]** | [REG — VAL] |
| 13 | Certification requirements | Only for a direct connection — Confirm | Confirm |
| 14 | Operational ownership | DEP-08 Investor services; DEP-09 Compliance for KYC policy; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions

None in the default design. If an AMC later uploads KYC records directly, that upload is a class A2 instruction and this specification must be revised first.

## 3. Confirm with the AMC, the RTA, each KRA and CERSAI

1. Whether the RTA feed carries KYC status for every investor, and from which agency.
2. Whether the AMC needs any direct KRA or CKYC access in addition.
3. Personal-data handling of KYC fields (DPDP; DPO, D-54) **[VAL]**.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 KRA and CKYC rows | Agencies, routes |
| S2 | [BA-004](../02_business_architecture/BA-004_end_to_end_workflows.md) WF-010 hand-offs | KRA through the RTA |
| S3 | Digio, "CKYC", https://www.digio.in/ckyc (search result seen 22 Nov 2026; secondary, not opened) | CKYCRR 2.0 mention |
