---
id: ADR-0019
title: API gateway and policy engine — evaluation, shortlist and proof-of-concept plan
status: Draft
date: 2026-11-21
deciders: ARB (interim: project owner)
domains: D01 + all
related: EA-002 §4.2; ADR-0003; ADR-0016; ADR-0018; owner decisions D-7, D-8, D-71; proposal ADR-0015 (branch proposal/ai-orchestration-architecture, input only)
---

# ADR-0019 — API gateway and policy engine: evaluation, shortlist and proof-of-concept plan

> Written by the build loop (GOV-006 Step 10) because owner decision D-71 asks Step 10 to evaluate the API gateway and policy-engine products now that cloud (D-7) and sign-in (D-8) are decided. It takes over the open question of the unmerged proposal ADR-0015; if the owner merges the proposal branch, ADR-0015 should be marked Superseded by this ADR. **No product is selected here**: the ADR proposes a shortlist and a leading candidate for each, to be confirmed by a proof of concept.

## Status
Draft

## Context
- Master prompt §5 L2: API gateway, rate limiting, request validation, tenant context, RBAC and ABAC where necessary, audit logging.
- EA-002 §4: tenant comes from the token (ADR-0016); permissions come from AMC OS grants plus attributes (scheme, desk, department, data sensitivity); every allow/deny decision must be logged; AI assistants pass the same checks (ADR-0008).
- Kubernetes is not yet decided (master prompt §13 "when justified"; INF-001, Step 26). Hosting is AWS India (ADR-0018).

Facts checked on 21 Nov 2026 (H = page opened; T = search-result title only):

| Product | Fact | Source |
| --- | --- | --- |
| Kong Gateway | Community reports that free/open-source mode ended with version 3.10.0 (March 2025) and that open-source images were no longer published from 3.10.0; no official Kong statement seen | H: [Kong Nation thread](https://discuss.konghq.com/t/is-opensource-support-for-kong-ceased/13529), [GitHub discussion 14405](https://github.com/Kong/kong/discussions/14405) — community, secondary |
| Envoy Gateway | Envoy-based gateway for the Kubernetes Gateway API; release 1.9 in 2026; general availability since 2024 | T: [v1.9 announcement](https://gateway.envoyproxy.io/news/releases/v1.9/), [CNCF "a year of GA", 11 Jun 2025](https://www.cncf.io/blog/2025/06/11/a-year-of-envoy-gateway-ga-building-growing-and-innovating-together/) |
| Open Policy Agent (OPA) | 20 Aug 2025: OPA's creators and many Styra staff joined Apple; "OPA remains a CNCF graduated open source project and there are no changes to the project governance or licensing" | H: [OPA blog](https://openpolicyagent.org/blog/note-from-teemu-tim-and-torin-to-the-open-policy-agent-community-2dbbfe494371) |
| Cedar | Open-source policy language from AWS (2023); joined the CNCF as a sandbox project (reported Jan 2026); AWS offers it as a managed service (Amazon Verified Permissions) | T: [AWS open-source blog](https://aws.amazon.com/blogs/opensource/cedar-joins-cncf-as-a-sandbox-project), [InfoQ, Jan 2026](https://www.infoq.com/news/2026/01/cedar-joins-cncf-sandbox), [AWS docs](https://docs.aws.amazon.com/verifiedpermissions/latest/userguide/terminology-differences-avp-cedar.html) |

Licence terms of every candidate must be re-read at approval **[VAL]**.

## Evaluation criteria
1. Validates ADR-0016 tokens (OIDC/JWT) and passes tenant and user context on; never accepts a tenant from the request.
2. Per-tenant rate limits and quotas.
3. Request validation against OpenAPI.
4. Runs the same way in shared and dedicated cells, and in both AWS India regions (ADR-0018 Decision 4).
5. Open licence with a clear governance home; low risk of a sudden licence change.
6. Decision log export for every allow/deny (policy engine).
7. Policies written as versioned, testable code, reviewed like code; ABAC on scheme, desk, department, sensitivity.
8. Added latency small enough for NFR-PERF-010 (pre-trade p95 < 300 ms) and NFR-PERF-006.
9. Smallest operating footprint (master prompt §13).

## Decision (proposed)
1. **Policy engine — leading candidate: OPA**, run as a library or sidecar next to the application so a decision needs no network hop to a shared service; policies in Rego, versioned in the repository, with unit tests and decision logs shipped to the audit store. **Alternative kept: Cedar** (in-process library), if the proof of concept shows simpler ABAC policies or better analysis tooling. A managed policy service is not chosen as default, because it adds a network call per decision and ties authorisation to one cloud.
2. **API gateway — no leading product until the Kubernetes decision.** If Kubernetes is adopted (INF-001), **Envoy Gateway** is the leading candidate. If not, the shortlist is the cloud provider's managed gateway or a load balancer plus validation in the FastAPI application. **Kong is not recommended** while the status of its open-source edition is unclear (community reports above).
3. **Separation of duties between them:** the gateway checks *who* (token) and *how much* (rate limits) and validates shape; the policy engine, called by the domain module, decides *may this user do this action on this object* (it needs object attributes the gateway does not have).
4. Until the proof of concept ends, documents refer to "API gateway" and "policy engine" generically.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Kong Gateway | Mature plugin set | Open-source status unclear since 3.10 (community reports); enterprise licence cost | Licence risk (criterion 5) |
| Permission checks hand-written in each module | No new component | Rules scattered; no single decision log; hard to review ABAC | Fails criteria 6 and 7 |
| Managed policy service (Amazon Verified Permissions) | No servers | Network call per decision; cloud tie-in for dedicated cells | Criteria 4, 8 |
| Decide all products now | Removes uncertainty | Gateway depends on the open Kubernetes decision | Premature for the gateway |

## Consequences
- Positive: one place for authorisation rules and one decision log; gateway choice stays open until the platform decision it depends on.
- Negative: policy language skills needed (Rego or Cedar); policy tests become part of CI.
- Follow-up: proof of concept in the platform-foundation increment; INF-001 (Step 26) Kubernetes decision; SEC-001 (Step 25) maps policies to BA-005 rights and SoD rules.

## Validation
Proof of concept: 20 representative BA-005 rights incl. SoD rules (e.g. maker ≠ checker) written in OPA and in Cedar; measure p95 decision latency; cross-tenant negative tests; ROLE-26 cannot get an approve decision; decision logs reach the audit store; gateway candidate passes criteria 1–4 in both regions.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-21 | Draft | Claude (build loop) for project owner | Created in GOV-006 Step 10 (owner decision D-71) |
