---
id: INT-005
title: Provider Specification — BSE (market data, corporate actions, clearing obligations, StAR MF platform)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-005 — BSE

Outside systems X03 and X09 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4, for BSE. Follows [INT-001](INT-001_integration_architecture.md) and has the same shape as [INT-004](INT-004_nse.md) (NSE); only the differences are written out in full. Builds on Draft documents EA-001, EA-003, PRD-007, PRD-011, PRD-012, PRD-013 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | BSE and its group: its clearing corporation, BSE StAR MF (mutual-fund platform), index data where licensed | [IND] |
| 2 | Business purpose | Same as INT-004 field 2 (a)–(g), for BSE-listed prices, BSE corporate actions, BSE clearing obligations, StAR MF order and allotment data, NAV / iNAV out where BSE requires it from the AMC, and broker membership status | [DES] |
| 3 | Approved interface | **Market data:** UDiFF trade and bhavcopy files (BSE UDiFF page: standard file formats set under SEBI's Market Data Advisory Committee; legacy files discontinued from 8 Jul 2024, read 22 Nov 2026) **[IND]**; delivery channel under BSE's licence — Confirm with BSE. **StAR MF:** BSE publishes file and API structure documents for StAR MF (for example `APIFileStructure.pdf` on bsestarmf.in — title seen in search 22 Nov 2026, not opened) **[IND]**; these are aimed at members and distributors; AMC-side data — directly or through the RTA — Confirm with BSE and the RTA. **Clearing obligations:** through the custodian or the clearing corporation — Confirm **[ASSUMPTION]** | [IND] / Confirm |
| 4 | Authentication | As INT-004 — Confirm with BSE | Confirm |
| 5 | Data contract | As INT-004 field 5 | [DES] |
| 6 | Ingestion schedule | As INT-004 field 6, on the BSE trading calendar — Confirm times with BSE | Confirm |
| 7 | Error handling | As INT-004 field 7 | [DES] |
| 8 | Retry logic | As INT-004 field 8 | [DES] |
| 9 | Idempotency | As INT-004 field 9, with exchange = BSE | [DES] |
| 10 | Reconciliation | As INT-004 field 10; a security listed on both exchanges uses the price source named in the tenant's price-source hierarchy (PRD-011, D-46) | [DES] |
| 11 | Monitoring | As INT-004 field 11 | [DES] |
| 12 | Commercial dependency | BSE data licence per AMC (D-62); StAR MF onboarding of the AMC | [VAL] |
| 13 | Certification requirements | StAR MF onboarding tests — Confirm with BSE | Confirm |
| 14 | Operational ownership | As INT-004 field 14 | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2)

As INT-004 §2:

| Instruction | Owning module | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- |
| Scheme NAV and, for listed schemes, NAV / iNAV data to BSE — only where BSE requires it from the AMC | NAV | Confirm with BSE | Confirm with BSE | NAV team checks BSE's published value against the approved NAV and contacts BSE; resend released by a person with the same key |

## 3. Confirm with BSE

Points 1–6 of INT-004 §3, for BSE, its clearing corporation and StAR MF.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | BSE, "UDiFF", https://bseindia.com/static/members/udiff.aspx (read 22 Nov 2026) | UDiFF; discontinuation date |
| S2 | BSE StAR MF, "API File Structure", https://www.bsestarmf.in/APIFileStructure.pdf; BSE, "StAR Mutual Funds Platform", https://bseindia.com/static/Markets/MutualFunds/BSEStarMF.aspx (titles seen in search 22 Nov 2026; not opened) | Existence of platform documents |
| S3 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 BSE row | Purpose |
