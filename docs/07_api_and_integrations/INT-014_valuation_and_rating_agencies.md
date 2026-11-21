---
id: INT-014
title: Provider Specification — Valuation agencies and credit rating agencies
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-014 — Valuation and rating agencies

Outside system X11 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). Not named in master prompt §10's list, but needed by EA-001 and PRD-011 (debt and money-market prices) and PRD-016 (ratings). **Every interface item is Confirm with <agency>.** Builds on Draft documents EA-001, EA-003, PRD-009, PRD-011, PRD-016 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | (a) Valuation agencies that provide security-level prices or yields for debt and money-market securities to mutual funds. AMFI-hosted documents titled "crisil agreement", "icra agreement" and "AMFI BP 42 dt. 19 Nov 2013" (seen in search 22 Nov 2026, not opened) suggest AMFI arrangements with CRISIL and ICRA **[ASSUMPTION — from document titles only; Confirm current agencies and the regulatory basis with AMFI and Compliance; REG — VAL]**. (b) SEBI-registered credit rating agencies, directly or through a data vendor (INT-003) | [ASSUMPTION] / [VAL] |
| 2 | Business purpose | (a) Prices and yields for debt and money-market holdings (Valuation, D11; WF-007, WF-035 fair-value exceptions); (b) ratings, outlooks and rating actions (Security master, D16; consumed by Risk D09 and Compliance D08 through `RATING_CHANGED`) | [DES] |
| 3 | Approved interface | Agency files or feeds — Confirm with <agency>. PRD-000 Ch 8 expects SFTP files for valuation agencies and vendor or agency feeds for ratings **[ASSUMPTION]** | Confirm |
| 4 | Authentication | Per agency (SFTP keys per PRD-000 Ch 8) — Confirm; per tenant | Confirm |
| 5 | Data contract | Canonical families: **price** (with yield and the agency's reference) and **rating** (INT-001 §3) | [DES] |
| 6 | Ingestion schedule | Prices each valuation day before the tenant's NAV cut-off; ratings daily — times Confirm with <agency> | Confirm |
| 7 | Error handling | Missing price for a held debt security → Valuation exception (WF-007); two agencies differ beyond the tenant's tolerance (D-46) → Valuation exception for a person to decide under the valuation policy (PRD-011); rating action on a held issuer → `RATING_CHANGED` → Risk and Compliance alerts | [DES] |
| 8 | Retry logic | Class A1 reads; no outbound instructions | [DES] |
| 9 | Idempotency | Price: tenant + agency + ISIN + valuation date; rating: tenant + agency + instrument or issuer + action date | [DES] |
| 10 | Reconciliation | Completeness vs held debt securities; two-agency comparison where the policy uses two (PRD-000 Ch 8); rating from agency vs vendor | [DES] |
| 11 | Monitoring | File late on a valuation day; securities without a price; large day-on-day moves above the tenant's threshold | [DES] |
| 12 | Commercial dependency | Licences or agreements per AMC (D-62); how AMFI's arrangements apply to each AMC **[VAL]** | [VAL] |
| 13 | Certification requirements | None known — Confirm with <agency> | Confirm |
| 14 | Operational ownership | Prices: DEP-07 Fund accounting and NAV (valuation); ratings: DEP-17 Data and analytics with DEP-11 Risk; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions

None.

## 3. Confirm with <agency> (and AMFI, Compliance)

1. Which agencies the AMC must or may use, and the current regulatory basis **[REG — VAL]**.
2. File layout, delivery time and corrections.
3. Licence terms for storing and showing prices and ratings.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | AMFI-hosted documents "31.1 crisil agreement", "31.2 icra agreement", "31. AMFI BP 42 dt. 19-Nov-2013" at amfiindia.com (titles seen in search 22 Nov 2026; not opened) | Agencies indicated |
| S2 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 valuation and rating rows; [PRD-011](../03_product_requirements/PRD-011_valuation_and_nav.md) | Purpose, checks |
| S3 | [LOOP_STATE.md](../../LOOP_STATE.md) D-46, D-62 | Tolerances, licences |
