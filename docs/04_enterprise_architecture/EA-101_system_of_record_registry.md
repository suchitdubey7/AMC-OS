---
id: EA-101
title: System-of-Record Registry — Proposal
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 (proposal; depends on WP2)
last_updated: 2026-11-20
---

# EA-101 — System-of-Record Registry (Proposal)

> **PROPOSAL** — part of the [EA-100](EA-100_ai_orchestration_architecture_proposal.md) set. Not approved. Depends on WP2 capability map (BA-001).

A *system of record* (SoR) is the one system whose copy of a piece of data is the legal and operational truth. Every other copy is a projection that must say where it came from and when it was taken. AMC OS records, per tenant, which system is the SoR for each data object, and the platform enforces it: a module may only **write** an object when AMC OS is that object's SoR for the tenant.

## 1. Three modes per object, per tenant

| Mode | Meaning | AMC OS behaviour |
| --- | --- | --- |
| **O — Owner** | AMC OS is the SoR | Deterministic engine writes; maker-checker; publishes events |
| **S — Shadow** | External system is SoR; AMC OS computes its own version to check it | Writes only to `shadow_*` records; never published; breaks raised to reconciliation |
| **E — External** | External system is SoR; AMC OS only reads | Stores a timestamped projection with source, extraction time and version; read-only |

The mode is set per tenant by an authorised administrator through an R3 change (SEC-101) and is effective-dated. Changing an object from E to O is a migration project, not a toggle.

## 2. Default registry (proposed)

| Data object | Default SoR | Default AMC OS mode | Lifecycle owned by AMC OS | Notes |
| --- | --- | --- | --- | --- |
| Investment intent, proposals, research notes | AMC OS | O | Draft → approved → archived | |
| Orders (intent to trade) | AMC OS (OMS) | O | Order lifecycle (EA-102 §2) | |
| Approvals, maker-checker records | AMC OS | O | Requested → approved/rejected | Insert-only |
| Workflow state, routing, tasks | AMC OS | O | Workflow lifecycle | Temporal history |
| Audit trail | AMC OS | O | Append-only, hash-chained | |
| Pre-/post-trade compliance results | AMC OS | O | Per rule version | Rules versioned as data |
| Execution (fills) | Broker / exchange | E | Execution lifecycle tracked as received | AMC OS records what the broker reports; never invents fills |
| Trade confirmation / allocation affirmation | Broker / custodian | E | Confirmation lifecycle | |
| Settlement (cash and securities) | Bank / custodian / clearing | E | Settlement lifecycle | |
| Holdings at custodian | Custodian | E | — | Reconciled against IBOR |
| Investment book of record (IBOR) | AMC OS | O | Derived from orders + fills + corporate actions | Reconciled daily |
| Investor / folio master, unit holdings | RTA (CAMS / KFintech) | E | — | Mirror mode chosen by owner (GOV-006 Q2) |
| Investor transactions (purchase, redemption, switch, SIP) | RTA | E | — | AMC OS stores copies for analytics and servicing |
| KYC status | KRA / CKYC | E | — | |
| Scheme ledger (accounting) | AMC's accounting platform | **E or S** (O only where AMC chooses) | — | Conflict C2 in EA-100; owner decision O-2 |
| NAV (official) | AMC's NAV authority / fund accountant | **E or S** (O only where AMC chooses) | — | AMC OS never publishes NAV unless mode O **and** human approval |
| NAV published to AMFI | AMC (via its authorised process) | E | — | AMC OS may prepare the file; humans submit |
| Market prices and reference data | Data vendors / exchanges / AMFI | E | — | Licence terms apply (INT-100 §5) |
| Distributor master, commissions | AMC OS **or** existing system | O or E | — | Per tenant |
| AMC corporate finance (P&L, budget) | AMC's ERP | E | — | |

## 3. Enforcement

1. Registry table `platform.system_of_record(tenant_id, object_type, mode, external_system, effective_from, approved_by)` — **proposed**, to be added in WP4 (DBE-*). Not added to DDL-000 by this proposal.
2. Every write tool in the tool registry (AIML-102) declares the `object_type` it writes. The policy engine denies the call when the tenant's mode for that object is not O.
3. Projections (mode E) carry `source_system`, `source_record_id`, `as_of`, `extracted_at`, `extraction_run_id`.
4. Shadow results (mode S) can raise reconciliation breaks but can never feed an external filing, investor statement or published figure.

## 4. Separate lifecycles for trade objects

AMC OS keeps four distinct records and never merges them into one status field: **order**, **execution**, **confirmation**, **settlement**. Details and state machines: [EA-102](EA-102_transaction_orchestration.md).

## 5. Open items

- O-2: default mode for accounting and NAV (EA-100 §7).
- The existing DDL-000 assumes mode O for accounting and NAV. If the owner picks E/S as default, WP4 must add projection and shadow tables; the current tables remain valid for tenants in mode O.
