---
id: INT-006
title: Provider Specification — CAMS as Registrar and Transfer Agent (RTA)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-006 — CAMS (RTA)

Outside system X07 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4, for an AMC whose RTA is Computer Age Management Services (CAMS). Follows [INT-001](INT-001_integration_architecture.md). The RTA is the record keeper of the investor register; AMC OS keeps a checked mirror (owner decision Q2, D-53). [INT-007](INT-007_kfin_technologies.md) (KFin Technologies) has the same shape. **All RTA interfaces are under the AMC's agreement with the RTA and are not public: every interface item is Confirm with CAMS.** CAMS's KYC registration agency business is covered in [INT-012](INT-012_kra_and_ckyc.md). Builds on Draft documents EA-001, EA-003, EA-007, PRD-002, PRD-011, PRD-013, PRD-014 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | Computer Age Management Services Ltd (CAMS), SEBI-registered RTA, acting for the AMC under contract | [IND] |
| 2 | Business purpose | **In:** investor and folio master, provisional and final transaction feeds, SIP and mandate data, units outstanding per plan, AUM, brokerage computation, payout and message status, complaints received by the RTA (Investor D13, Distribution D14, Operations reconciliation). **Out:** approved NAV and IDCW rates (NAV, Product), scheme master and set-up (Product, WF-001), correction requests for investor data (Investor; corrections are made only by the RTA, D-53), message requests where the RTA sends investor messages (D-55). Payout files are prepared and sent by the RTA, AMC OS only tracks and checks them (D-52). **MF Central** (the service platform run jointly by the RTAs, PRD-013): transactions and service requests received there reach AMC OS in this RTA's feed by default **[ASSUMPTION — Confirm with the RTA]** | [DES] |
| 3 | Approved interface | Feeds and APIs per the AMC–CAMS agreement (PRD-000 Ch 8) — **Confirm with CAMS** for each feed: transport (file or API), layout, version, push or pull | Confirm |
| 4 | Authentication | Per agreement (PRD-000 Ch 8 lists SFTP keys, API credentials and IP allow-listing as expected) — Confirm with CAMS; per tenant, fixed outbound addresses per cell (INT-001 S4) | Confirm |
| 5 | Data contract | Canonical families: **investor, folio and transaction**; **KYC status** (as carried by the RTA); **distributor registration and brokerage**; **NAV publication record** (out); **scheme set-up** (out); **complaint**; **investor message request and delivery status** (INT-001 §3). Investor personal data is classified and never appears in events (NFR-SEC-007) | [DES] |
| 6 | Ingestion schedule | Intraday provisional feeds, end-of-day final feeds, monthly AUM and brokerage (PRD-000 Ch 8) — times Confirm with CAMS; NAV and IDCW out after NAV approval each business day (EA-007 §10.1) | Confirm |
| 7 | Error handling | Unknown scheme or plan code → quarantine; transaction for an unknown folio → held, task to Investor Services; investor-data mismatch → `INVESTOR_DATA_FLAGGED`, correction request to the RTA (D-53); provisional vs final differences reported, never overwritten silently | [DES] |
| 8 | Retry logic | Inbound feeds: class A1. NAV / IDCW file to the RTA: class A2 (§2). Scheme set-up: human task. Correction requests: class A1 with idempotency key (not a financial instruction; the RTA decides) | [DES] |
| 9 | Idempotency | Transaction: tenant + RTA + RTA transaction reference (+ version for provisional vs final); folio: tenant + folio number + as-of date; NAV out: EA-007 key + client reference | [DES] |
| 10 | Reconciliation | Units outstanding per plan vs AMC unit capital in Accounting; transaction count and amount control totals; brokerage vs the AMC OS commission engine (FE-09, D-56); demat units vs depository (INT-011) — via WF-015 | [DES] |
| 11 | Monitoring | Final feed late; provisional-to-final differences; units-outstanding break; NAV file unacknowledged; open correction requests by age | [DES] |
| 12 | Commercial dependency | AMC's RTA agreement with CAMS; each RTA's formats differ, so one adapter per RTA (PRD-000 Ch 8) | [IND] |
| 13 | Certification requirements | Test cycle with CAMS before go-live and parallel run (INT-001 §11 C6) — Confirm with CAMS | Confirm |
| 14 | Operational ownership | DEP-08 Investor services (RTA oversight); NAV file: DEP-07 Fund accounting and NAV; scheme set-up: DEP-13 Products; brokerage: DEP-12 Sales and distribution; connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2)

| Instruction | Owning module | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- |
| NAV and IDCW rate file to CAMS | NAV | Confirm with CAMS | Confirm with CAMS | NAV team confirms with the CAMS operations desk; resend released by a person with the same key |

## 3. Confirm with CAMS

1. List of feeds available to the AMC, with transport, layout version and delivery times.
2. Whether NAV upload is acknowledged and whether its status can be queried.
3. How corrections and reversals appear in the transaction feed.
4. How complaints and message delivery status are shared.
5. Test environment and certification steps.
6. Does any MF Central data reach the AMC other than through the RTA feed?

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 RTA row | Data exchanged, auth expected |
| S2 | [PRD-013](../03_product_requirements/PRD-013_investor_management.md); [EA-001](../04_enterprise_architecture/EA-001_system_context.md) X07 | Mirror stance |
| S3 | [LOOP_STATE.md](../../LOOP_STATE.md) Q2, D-52, D-53, D-55, D-56 | Record keeper, payouts, corrections, messages, commission |
