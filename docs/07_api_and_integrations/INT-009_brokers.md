---
id: INT-009
title: Provider Specification — Brokers (orders, executions, contract notes)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-009 — Brokers

Outside system X02 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md). One specification for every empanelled broker (WF-023); each broker has its own adapter configuration and "Confirm with" answers. **FIX per broker is an [ASSUMPTION] (BA-004 WF-004); the FIX version and dialect are Confirm with <broker>.** Builds on Draft documents EA-001, EA-003, EA-007 §10.6, PRD-005, PRD-006, BA-004 WF-004, WF-023, WF-025 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | Each broker on the AMC's approved panel (SEBI-registered stock broker) | [IND] |
| 2 | Business purpose | **Out:** orders released by the Dealer, cancellations and amendments (Execution, WF-004). **In:** order acknowledgement and rejection, execution reports (fills), end-of-day trade confirmations, contract notes and bills (Execution, WF-025) | [DES] |
| 3 | Approved interface | Confirm with <broker>. PRD-000 Ch 8 assumes FIX 4.2 or 4.4 over a leased line or VPN for orders and executions, and files or PDFs for contract notes **[ASSUMPTION]**. Emailed contract notes follow INT-001 IN7 (human check in release 1, Q79) | Confirm |
| 4 | Authentication | FIX session credentials and mutual TLS, or the broker's own scheme — Confirm with <broker>; per tenant | Confirm |
| 5 | Data contract | Canonical family: **order to broker / execution / contract note** (INT-001 §3). Allocation to schemes stays in AMC OS (Execution), never at the broker unless the broker's contract note shows it | [DES] |
| 6 | Ingestion schedule | Orders and executions in real time during market hours; contract notes end of day or next morning per the broker — Confirm with <broker>; expected-file schedule per broker | Confirm |
| 7 | Error handling | Order rejected → back to the Dealer with the broker's reason; execution for an unknown order → Execution exception queue; fills vs contract note differences beyond the tenant's tolerance → `TRADE_EXCEPTION_RAISED` (WF-025); charges outside the trade-charges table (D-29) → exception | [DES] |
| 8 | Retry logic | New order, cancel, amend: class A2 (§2). Session reconnect: transport-level only; FIX session-level resend of the same sequence numbers where the broker supports it (INT-001 OUT2) **[IND — FIX session layer; per broker Confirm]** | [DES] |
| 9 | Idempotency | Outbound: EA-007 key + client order ID sent to the broker (FIX ClOrdID where FIX is used **[IND]**); inbound execution: tenant + broker + broker's execution ID; contract note: tenant + broker + contract note number | [DES] |
| 10 | Reconciliation | Fills vs contract notes (quantity, price, charges; PRD-000 Ch 8); contract notes vs allocations; broker trades vs custodian settlement (INT-008) | [DES] |
| 11 | Monitoring | Session down in market hours; orders without ack (unknown submission); executions not matched; contract notes late | [DES] |
| 12 | Commercial dependency | Broker empanelment (WF-023); network connectivity to each broker (leased line or VPN) if FIX is used **[ASSUMPTION]** | [ASSUMPTION] |
| 13 | Certification requirements | FIX certification per broker (PRD-000 Ch 8) where FIX is used — Confirm with <broker> | Confirm |
| 14 | Operational ownership | DEP-05 Dealing desk (orders, executions); DEP-06 Fund operations (contract notes, charges); connection: DEP-15 Technology | [DES] |

## 2. Outbound instructions (EA-007 §9.3 class A2; §10.6)

| Instruction | Owning module | Ack time limit | Status query | Manual check |
| --- | --- | --- | --- | --- |
| New order | Execution | Confirm with <broker> **[ASSUMPTION — per broker]** | The FIX standard defines an Order Status Request message (MsgType H) in FIX 4.2 and 4.4 **[IND — third-party FIX dictionary pages seen in search; not checked against the FIX Trading Community text]**; whether each broker supports it: Confirm with <broker> | Dealer calls the broker's desk and records the answer on the order (`UNKNOWN_SUBMISSION`, EA-007 §10.6) |
| Cancel / amend | Execution | As above | As above | As above (`UNKNOWN_CANCEL`) |

## 3. Confirm with <broker>

1. FIX version, dialect and session set-up (or the broker's alternative).
2. Order acknowledgement time and support for order status requests.
3. Contract note delivery (file, PDF, email) and timing.
4. Certification steps and test environment.

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [PRD-000](../03_product_requirements/PRD-000_master_prd_v0.9.md) Ch 8 Brokers row; [PRD-006](../03_product_requirements/PRD-006_trading_and_execution.md) | Data exchanged, FIX assumption |
| S2 | [EA-007](../04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md) §10.6 | Broker leg workflow |
| S3 | OnixS FIX dictionary, "FIX 4.4: Order Status Request <H> message", https://www.onixs.biz/fix-dictionary/4.4/msgtype_h_72.html and FIX 4.2 equivalent https://onixs.biz/fix-dictionary/4.2/msgtype_h_72.html (search results seen 22 Nov 2026; secondary) | Order Status Request in FIX |
| S4 | [LOOP_STATE.md](../../LOOP_STATE.md) D-29 | Trade-charges table |
