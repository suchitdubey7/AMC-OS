---
id: INT-003
title: Provider Specification — FactSet and other market and reference data vendors
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-003 — FactSet and other data vendors

Outside system X10 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). FactSet is named in the master prompt; other vendors an AMC licenses use the same specification with their own "Confirm with" list. **Which FactSet products an AMC licenses, and therefore which interface applies, is Confirm with FactSet and the AMC.** Builds on Draft documents EA-001, EA-003, PRD-003, PRD-004, PRD-009, PRD-016 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | FactSet Research Systems (and any other data vendor the AMC licenses) | [IND] |
| 2 | Business purpose | Security and issuer reference data, fundamentals, estimates, index constituents and levels, ownership data, and (where licensed) prices — inputs to research (D03), portfolio analytics (D04), risk (D09), the security master and benchmarks (D16). Never a source of truth for NAV prices unless the tenant's price-source hierarchy names it (PRD-011, D-46) | [DES] |
| 3 | Approved interface | Confirm with FactSet per licensed product. FactSet publishes APIs and a "Standard DataFeed" product with official SDK packages (for example `fds.sdk.StandardDatafeed` on PyPI, seen 22 Nov 2026) **[IND]**. FactSet announced a production MCP server on 16 Dec 2025 (as recorded in proposal INT-100 §4, input only) **[IND — not opened in this run]**; MCP is not used in release 1 unless the owner decides (INT-001 I13, D-72) | [IND] / Confirm |
| 4 | Authentication | Per FactSet product (API key or OAuth per PRD-000 Ch 8) — Confirm with FactSet; credentials per tenant (INT-001 I7) | Confirm |
| 5 | Data contract | Canonical families: **security and issuer reference**, **benchmark and index levels**, **rating** (where the vendor carries ratings), **price** (where licensed) — INT-001 §3. Every record carries the licence tag (INT-001 I11) | [DES] |
| 6 | Ingestion schedule | Daily delta for reference data, on demand for research look-ups; times per licensed product — Confirm with FactSet. Expected-file schedule per tenant (INT-001 IN1) | Confirm |
| 7 | Error handling | Unknown security → WF-041 golden-record queue, never created silently; conflicts with exchange or depository data → Data Steward queue (PRD-000 Ch 8); malformed delivery → quarantine | [DES] |
| 8 | Retry logic | Class A1 reads, retried with back-off; no outbound instructions | [DES] |
| 9 | Idempotency | Tenant + vendor + vendor record identifier + as-of date (+ vendor version where sent) | [DES] |
| 10 | Reconciliation | Reference data cross-checked with the exchange master (INT-004/005) and ISINs with the depository (INT-011); index levels with the index provider where both are licensed; differences go to the Data Steward | [DES] |
| 11 | Monitoring | Delivery late, records rejected, steward queue size, licence-tag missing (must be zero) | [DES] |
| 12 | Commercial dependency | One licence per AMC (D-62); licence scope limits storage, display, redistribution and AI use — each AMC's contract to be checked **[VAL]**; an individual's or another firm's licence is never used | [VAL] |
| 13 | Certification requirements | None known; FactSet onboarding and entitlement set-up per AMC — Confirm with FactSet | Confirm |
| 14 | Operational ownership | DEP-17 Data and analytics (Data Steward ROLE-23); connection: DEP-15 Technology; licence: the AMC (owner question Q77) | [DES] |

## 2. Outbound instructions

None. Data vendors only send data to AMC OS.

## 3. Confirm with FactSet (and each other vendor)

1. Products licensed by the AMC and the delivery method for each (API, data feed, files).
2. Rights to store, show to users, use in AI assistants and in derived outputs (I11).
3. Delivery times and correction (restatement) handling.
4. Whether the licensed product covers Indian securities' identifiers (ISIN, exchange codes) needed by the security master.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | PyPI, `fds.sdk.StandardDatafeed`, https://pypi.org/project/fds.sdk.StandardDatafeed (search result seen 22 Nov 2026, page not opened) | Existence of the Standard DataFeed SDK |
| S2 | Proposal branch `proposal/ai-orchestration-architecture`, INT-100 §4, citing FactSet release "FactSet Meets Demand for AI-Ready Data, First to Announce MCP Sans Intermediary", 16 Dec 2025 (input only; not re-opened) | MCP server note |
| S3 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 FactSet row; [PRD-016](../03_product_requirements/PRD-016_enterprise_data_platform.md) | Purpose, steward queue |
| S4 | [LOOP_STATE.md](../../LOOP_STATE.md) D-62, D-72 | Licence per AMC; no MCP in release 1 |
