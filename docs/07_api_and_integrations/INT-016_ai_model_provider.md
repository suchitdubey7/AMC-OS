---
id: INT-016
title: Provider Specification — AI model provider (through the AI gateway only)
status: Draft
version: 0.1
owner: Chief Enterprise Architect
approver: Project owner (interim ARB)
work_package: WP3 / Step 14
last_updated: 2026-11-22
---

# INT-016 — AI model provider

Outside system X14 of [EA-001](../04_enterprise_architecture/EA-001_system_context.md) §4. Follows [INT-001](INT-001_integration_architecture.md) and [ADR-0008](../../architecture/adrs/ADR-0008_ai_boundary.md). **The provider is not chosen (D-61); the AI platform design is AIML-001 (Step 26).** This specification fixes only the integration rules that any chosen provider must meet. The model provider is never a source of truth for any financial figure (master prompt §3.1). Builds on Draft documents EA-001, EA-003 §3.22, PRD-017 (owner decision D-3).

## 1. The 14 fields (master prompt §10)

| # | Field | Content | Label |
| --- | --- | --- | --- |
| 1 | Provider | Not chosen (D-61) | [DES] |
| 2 | Business purpose | Language model answers for the AI assistants of D17 (PRD-017): explanations, summaries, drafts — never authoritative figures, approvals or postings | [DES] |
| 3 | Approved interface | The chosen provider's API, reached only through the AI gateway (EA-003 §3.22); India-region private endpoint (D-61) — Confirm with the provider that such an endpoint exists **[VAL]** (EA-001 G3) | Confirm |
| 4 | Authentication | Per-cell service credentials held in the cell secrets manager; tenant context carried by the gateway, never by the model | [DES] |
| 5 | Data contract | Prompts built from tenant-filtered, classified and masked data (PRD-017); answers with source references. Schema in AIML-001 | [DES] |
| 6 | Ingestion schedule | Per request | [DES] |
| 7 | Error handling | Provider down or slow → assistant says it is unavailable; no business process waits on AI (EA-003 B10); kill switch (D-75) | [DES] |
| 8 | Retry logic | Class A1 with a short budget; no financial instructions ever go to the provider | [DES] |
| 9 | Idempotency | Not applicable to answers; every call logged with request ID for audit | [DES] |
| 10 | Reconciliation | Not applicable; quality checked by the evaluation suite (AIML-001) | [DES] |
| 11 | Monitoring | Latency, errors, cost per tenant, blocked prompts (data classification), kill-switch state | [DES] |
| 12 | Commercial dependency | Contract with zero data retention and no training on AMC data (D-61) **[VAL — contract terms]** | [VAL] |
| 13 | Certification requirements | Approval of each assistant or model release by business owner, CTO and ISO, validated by the Risk Manager (D-60, WF-043) | [DES] |
| 14 | Operational ownership | DEP-17 Data and analytics (AI models) with DEP-16 Information security; vendor runs the gateway | [DES] |

## 2. Outbound instructions

None. No AI output is sent to any outside party as an instruction (ADR-0008).

## Sources

| # | Source | Used for |
| --- | --- | --- |
| S1 | [ADR-0008](../../architecture/adrs/ADR-0008_ai_boundary.md); [PRD-017](../03_product_requirements/PRD-017_ai_and_decision_intelligence.md) | AI boundary |
| S2 | [LOOP_STATE.md](../../LOOP_STATE.md) D-60, D-61, D-75 | Decisions |
