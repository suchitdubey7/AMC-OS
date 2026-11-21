---
id: INT-007
title: Provider Specification — KFin Technologies as Registrar and Transfer Agent (RTA)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-007 — KFin Technologies (RTA)

Outside system X07 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4, for an AMC whose RTA is KFin Technologies. Follows [INT-001](INT-001_integration_architecture.md) and has the same shape as [INT-006](INT-006_cams.md) (CAMS). The two RTAs' formats differ, so each has its own adapter (PRD-000 Ch 8); nothing learned from one RTA's layout is assumed for the other. **All interface items are Confirm with KFin Technologies.** KFin's KYC registration agency business is in [INT-012](INT-012_kra_and_ckyc.md). Builds on the same Draft documents as INT-006 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | KFin Technologies Ltd, SEBI-registered RTA, acting for the AMC under contract | [IND] |
| 2 | Business purpose | Same as INT-006 field 2 (in: investor, folio, transactions, SIP, units outstanding, AUM, brokerage, payout and message status, complaints; out: NAV and IDCW, scheme set-up, correction requests, message requests). Payouts sent by the RTA (D-52); corrections only through the RTA (D-53) | [DES] |
| 3 | Approved interface | Per the AMC–KFin agreement — **Confirm with KFin Technologies** for each feed | Confirm |
| 4 | Authentication | Per agreement — Confirm with KFin Technologies; per tenant (INT-001 I7, S4) | Confirm |
| 5 | Data contract | As INT-006 field 5 (same canonical families; separate adapter) | [DES] |
| 6 | Ingestion schedule | Provisional intraday, final end-of-day, monthly (PRD-000 Ch 8) — times Confirm with KFin Technologies | Confirm |
| 7 | Error handling | As INT-006 field 7 | [DES] |
| 8 | Retry logic | As INT-006 field 8 | [DES] |
| 9 | Idempotency | As INT-006 field 9, with RTA = KFin | [DES] |
| 10 | Reconciliation | As INT-006 field 10 | [DES] |
| 11 | Monitoring | As INT-006 field 11 | [DES] |
| 12 | Commercial dependency | AMC's RTA agreement with KFin Technologies | [IND] |
| 13 | Certification requirements | Test cycle with KFin before go-live and parallel run — Confirm with KFin Technologies | Confirm |
| 14 | Operational ownership | As INT-006 field 14 | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2)

| Instruction | Owning module | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- |
| NAV and IDCW rate file to KFin | NAV | Confirm with KFin Technologies | Confirm with KFin Technologies | NAV team confirms with the KFin operations desk; resend released by a person with the same key |

## 3. Confirm with KFin Technologies

The same five points as INT-006 §3.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 RTA row | Data exchanged; one adapter per RTA |
| S2 | [LOOP_STATE.md](../../LOOP_STATE.md) Q2, D-52, D-53, D-55 | Mirror, payouts, corrections, messages |
