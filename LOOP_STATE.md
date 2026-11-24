# LOOP_STATE — build loop status (GOV-008)

**Status:** RUNNING
**Updated:** 2026-11-22 00:45 IST
**Chain tip:** `wp3-step13-events-workflows`

## Next action

**Step 14** (Stage B) on a new branch `wp3-step14-integrations` from the chain tip: INT-001 integration architecture and one specification per outside provider with all 14 fields of master prompt §10 (confirmed facts only; "Confirm with <provider>" otherwise). Inputs: EA-001 X01–X16, EA-003 B9 and T16 (adapters in the owning module), EA-007 §9.3 class A2 (acknowledgement time limit, status query and manual check per provider) and G5, PRD-000 Ch 8, BA-004 hand-offs. Note: `contracts/` (Step 13) is owner-only, so Step 13 waits for the owner to merge (gate G2), as do Steps 10–12 behind Step 10. Next free numbers: NFR-PERF-029, NFR-AUD-019, NFR-RET-008, NFR-SEC-008, NFR-SCAL-007, NFR-PRIV-005, NFR-AVAIL-005, NFR-OBS-005, NFR-DR-004, WF-044, ADR-0022 (ADR-0020 is reserved for the schema-move, database-role and system-worker ADR named in EA-003 §7, EA-005 §9 and EA-007 §13; ADR-0021 for the control plane, EA-006 §8), owner question Q76 (NFR-PERF-009 is unused, never reused).

Done in the Step 13 run (22 Nov 2026, scheduled): EA-007 event architecture and process workflows — event rules E1–E14, envelope, in-process outbox delivery per module with consumer inbox and dead-letter store (D1–D10), versioning V1–V6, catalogue of all 103 EA-003 events (3 renamed) as v1 JSON Schemas in `contracts/events/` with `catalogue.yaml`, contract tests `tests/contracts/` (not yet in CI — owner-only `.github/`), 21 business workflows on Temporal with owning module (closes EA-003 G6), workflow ID and duplicate-start rules, Pinned vs Auto-Upgrade versioning (confirms EA-004 §8.2 rule 5), unknown-outcome rule for outbound financial instructions, step designs for daily NAV, NFO, settlement fail, breach resolution, commission run and the broker leg of an order; NFR-PERF-028, NFR-AVAIL-004, NFR-OBS-004, NFR-AUD-018, NFR-SEC-007; owner questions Q73–Q75. Findings left open from Step 13: STEP-13 round 2 Nit 10 (commit trailer `Co-Authored-By: Claude`, as the loop prompt requires).

Done in the Step 12 run (21 Nov 2026, scheduled): EA-004 deployment and cells — two cell shapes (DEDICATED_DB dropped, Q69), what a cell contains, process roles of the one application, production and non-production cells kept apart, capacity limits and starting values ([ASSUMPTION] 10 tenants per shared cell, 70 % headroom), per-tenant resource limits, placement rules P1–P7, tenant migration between cells, module extraction triggers (closes EA-003 G7), release rings and compatibility rules, regional failover with a hold on unacknowledged outgoing financial messages, per-tenant restore as an investigation copy; NFR-SCAL-005, -006, NFR-DR-002, -003. EA-005 multi-tenant — tenant context for every kind of work (requests, workflows, events, relays, schedules, files, break-glass), platform data tools that touch every schema, isolation table per layer incl. audit, key hierarchy, break-glass without RLS bypass (per-grant login), lifecycle actions, isolation tests 12–21. EA-006 control plane / data plane — what may and may not be in the control plane, rules CP-1…CP-8 (pull model, signed artefacts, release signing outside the control plane), authoritative copy per tenant-record field, configuration promotion with a production checker (closes EA-008 G5), telemetry allow-list; NFR-AVAIL-003, NFR-SEC-006, NFR-OBS-003. SEBI cloud framework and CSCRF read only through secondary summaries (Taxmann, KPMG), labelled [REG — secondary; VAL]. New owner questions Q69–Q72. Review: round 1 RECOMMEND CHANGES (5 Major — migration destroyed the live tenant key, platform tools crossing schemas unnamed, production config approved only in UAT, break-glass role could set another tenant's context, CI test coverage overstated — all fixed, with 10 Minor and 4 Nits fixed except the trailer Nit); round 2 RECOMMEND MERGE AFTER FIXES (6 Minor, 2 Nits — all fixed). Left open: commit trailer Nit (`Co-Authored-By: Claude`, as the loop prompt requires); removal of a tenant's immutable rows and audit-chain import are open points for DA-001 with ADR-0020 (EA-005 G6).

Done in the Step 11 run (21 Nov 2026, scheduled): EA-003 domain boundaries and service catalogue — 22 modules with responsibilities, indicative APIs, candidate events, calls and adapters; boundary rules B1–B11; acyclic call tiers 0–11; ownership decisions T1–T19 closing PRD-005 C6/C9, PRD-006 C3/C4/C7/C11/C15, PRD-007 C3/C9, PRD-008 C4, PRD-012 C2/C3, PRD-013 C8, PRD-014 C5, PRD-016 C2/C10 (placement), PRD-001 C6, BA-001 §5 C3, BA-004 §5.2 C2; system-of-record decision for EA-001 G4 (Q66). EA-008 configuration over customisation (settings catalogue, scopes, WF-021 lifecycle, domain rule sets, storage in `platform`). New owner questions Q66–Q68. ADR-0020 (owner-only) is needed before Steps 15–16 for the table moves and per-module database roles. Review: round 1 RECOMMEND CHANGES (3 Major — central outbox relay wrote other schemas, Reporting could not reach Workflow, no ADR recorded for schema moves — all fixed, with 10 Minor, 6 Nits); round 2 RECOMMEND MERGE AFTER FIXES (5 Minor, 3 Nits — all fixed except the trailer Nit).

Done in the Step 10 run (21 Nov 2026, scheduled): EA-001 system context (people, 16 outside systems X01–X16, trust boundaries, systems of record); EA-002 seven-layer architecture with the 12 workspaces of D-74 (WS-01…WS-12), request path, identity design, tenant isolation per layer, smallest technology set for release 1; ADR-0016 sign-in (Keycloak broker per cell, D-8), ADR-0017 cache (Valkey, never a source of truth; financial idempotency keys in PostgreSQL), ADR-0018 cloud and regions (D-7), ADR-0019 gateway and policy-engine evaluation (D-71; OPA leading, gateway open until the Kubernetes decision, Kong not recommended). Review round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 12 Minor, 2 Nits) — all fixed except Nit 14 (trailer). Left open: SEBI cloud framework and CSCRF texts not opened (marked [VAL], for Step 25).

Done in the Step 9d run (21 Nov 2026, scheduled): owner answers Q20–Q60 (D-26…D-66) applied to PRD-001, PRD-003, PRD-006…PRD-017, BA-001 and BA-004 (WF-007, WF-008, WF-011, WF-018, WF-019 cards); D-73 and D-75 applied in PRD-017; PRD-000 note updated (stays Draft, D-66); matching [ASSUMPTION]s and open points closed; [VAL] kept for D-30, D-57, D-64. Rights the decisions add to BA-005 are listed under "BA-005 changes waiting" below. New owner questions Q61 (DPO reading of D-54) and Q62 (PRD-000 "fully re-keyed"). Review: round 1 RECOMMEND CHANGES (2 Major — BA-004 cards not updated — fixed, with 9 Minor, 1 Nit); round 2 RECOMMEND CHANGES (1 Major — D-52 payout files still released by AMC OS in PRD-012 / WF-011 — fixed, with 4 Minor); round 3 RECOMMEND MERGE AFTER FIXES (2 Minor fixed). Left open: commit trailer Nit (`Co-Authored-By: Claude`, as the loop prompt requires).

Done in the Step 9c run (21 Nov 2026, scheduled): PRD-016 Enterprise Data Platform (Module 14 re-keyed; takes over FR-D03-001/-002 as FR-D16-012/-013 and closes PRD-003 C3; `master` schema proposed for D16 (Q59); data catalogue, identifier crosswalk, counterparty and benchmark golden records; WF-041 master data change, WF-042 metric definition change and certification), PRD-017 AI and Decision Intelligence (Module 15 and Ch 9 re-keyed; 9 of 11 PRD-000 agents placed; new Dealing assistant and Risk assistant (closes the brief part of BA-001 §5 C4); anomaly detection, forecasting, kill switch, AI inventory; WF-043 AI assistant and model release). PRD-000: re-keying note added at the top; status not changed (GOV-001 §1 allows Superseded only after an Approved replacement) — owner question Q60. Step 9 is complete with 9c. Review: round 1 RECOMMEND CHANGES (1 Major — two Ch 5 stories not re-keyed — fixed with 9 Minor and 3 Nits); round 2 RECOMMEND MERGE AFTER FIXES (2 Minor, 1 Nit fixed). Findings left open from Step 9c: STEP-09c round 2 Nit 4 (commit trailer `Co-Authored-By: Claude`, as the loop prompt requires); the SEBI 2019 AI/ML circular body and the DPDP Rules commencement schedule were not opened (marked [VAL]).

Done in the Step 9b run (21 Nov 2026, scheduled): PRD-014 Distribution Management (Module 12 re-keyed; channel management, sales incentives, segmentation, sales forecasting; regulatory incentive lines; WF-039 distributor empanelment and registration monitoring; WF-013 run-state additions), PRD-015 Finance and Management Reporting (Module 13 re-keyed; expense management, multi-year planning, management period close and restatement; WF-040 monthly management reporting close — closes BA-004 §5.2 C6 and BA-002 P13 gap). Review round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits); all fixed except Nit 14 (commit trailer `Co-Authored-By: Claude`, as the loop prompt requires) and Minor 9 in part (the primary SEBI circulars of 27 Nov 2025 and 7 Jan 2026 were not opened; the 1 Mar 2026 start date rests on one press source, labelled [VAL]).

Done in the Step 9a run (21 Nov 2026, scheduled): PRD-010 Fund Accounting (Module 08 re-keyed; receivables and payables sub-ledgers; book-of-record vs mirror mode per D-16), PRD-011 Valuation and NAV (Module 09 re-keyed; price-source management, fair valuation, NAV reconciliation, NAV mode per scheme; WF-035), PRD-012 Fund Operations (Module 10 re-keyed with the Module 05 FR-05-10 / BR-05-3 and FR-10-02/-03/-06/-08 carry-overs; operational calendars; WF-036), PRD-013 Investor Management (Module 11 re-keyed as mirror-and-check per Q2; switch/STP/SWP, IDCW, service requests and complaints; WF-037, WF-038). Closes BA-001 §5 C5 and BA-004 §5.2 C3 (except Q46). Findings left open from Step 9a: STEP-09a round 1 Nit 13 (commit trailer `Co-Authored-By: Claude`, as the loop prompt requires); all 10 Minor and other Nits fixed.

Done in the Step 8 run (20 Nov 2026, scheduled): PRD-006 Trading and Execution (FR-04-09…11 and D06 parts of Module 05 re-keyed + new FRs), PRD-007 Settlement (D07 parts of Module 05 re-keyed + new FRs; net settlement per SEBI circular of 5 Nov 2026), PRD-008 Compliance (Module 06 re-keyed; WF-034 rule change lifecycle with legal review), PRD-009 Risk (Module 07 re-keyed; WF-033 daily risk run and alerts). PRD-005 open points C4, C5, C6, C9 updated.

After that: Steps 9, 10, … in GOV-006 order. The repository is still public until the owner switches it (D-6).

Done in the Step 5 run (20 Nov 2026, started early on owner request in chat): BA-005 roles, permissions and SoD; 2 review rounds. Owner answered Q17–Q19 and six follow-ups in chat the same morning (D-17 to D-25), applied on branch `wp2-step05b-owner-answers`, which also updates PRD-001 to match.

Findings left open from Step 8: STEP-08 round 2 Nit 7 (commit trailer `Co-Authored-By: Claude`, as the loop prompt requires).

Done in the Step 7 run (20 Nov 2026, on owner request in chat): PRD-003 Investment Management (FR-02-nn re-keyed + 10 new FRs, WF-031 investment policy review), PRD-004 Portfolio Management (FR-03-nn re-keyed + 8 new FRs, WF-032 performance measurement and attribution), PRD-005 Order Management (FR-04-01…08, 12…14 re-keyed + 5 new FRs; FR-04-09…11 left for PRD-006).

Done in the Step 6 run (20 Nov 2026, scheduled, in parallel): PRD-001 Platform Administration (48 FRs, new) and PRD-002 Product and Scheme Management (FR-01-nn re-keyed + 12 new FRs, WF-029, WF-030); closes BA-005 §7 C7. It ran before the owner's answers D-17…D-25 reached main; PRD-001 was brought in line on `wp2-step05b-owner-answers`.

Findings left open from Step 6: see the Step 6 row of the chain table and the review files `reviews/STEP-06_round*.md`. Round 1 Nit 16 (commit trailer `Co-Authored-By: Claude`, as the loop prompt requires) is left as in earlier steps.

Findings left open from Step 5: none (all round 1 and round 2 findings fixed).

Findings left open from Step 4: STEP-04 round 1 Nit 14 — commit trailer is `Co-Authored-By: Claude` as the loop prompt requires (same as STEP-01 Nit 2). BA-004 §5.2 C8 (QA-001 still says WF-001…WF-017) and C9 (BA-003 TERM-078 SSI wording) wait for the next revision of those documents.

Finding left open from Step 3: STEP-03 round 1 Nit 14 — GOV-001 `last_updated` and the register heading "as of 19 Nov 2026" were not changed, because only table rows of GOV-001 may change on a loop branch (merge gate G2); owner may update the dates.

Findings left open from Step 1 (no fix needed unless the owner wants it): STEP-01 round 3 Nit 2 — commit trailer follows the loop prompt (`Co-Authored-By: Claude`) rather than the older model-named format. STEP-01 round 3 finding 1 (was round 2 finding 6) — State Street pages B5 and B6 block automated fetches for the reviewer (HTTP 403); the writer opened both on 19 Nov 2026 and the cited wording matched.

## Loop notes

- **CI trigger (review STEP-01 finding 7):** `ci.yml` runs on `push` to every branch (plus manual `workflow_dispatch`), not on `pull_request`. Reason: the loop pushes branches without opening pull requests and reads the push run to decide whether the chain tip is green (GOV-008 rule 7 and stop conditions); a `pull_request` trigger on top would run the same checks twice. This replaces the earlier plan ("push only on `main`, plus `pull_request`"), which would have left loop branches with no CI. Trade-off: CI does not test the merge result against `main`; acceptable while branches are merged in order.

## Chain (merge in this order)

| # | Branch | Content | Review verdict | CI | Merged |
| --- | --- | --- | --- | --- | --- |
| 1 | `step-01-vision-market` | Step 1: PS-002, PS-003, PS-004 | RECOMMEND CHANGES (0 Blocker, 5 Major, 12 Minor, 2 Nit) | pass | yes (23:28, on owner instruction) |
| 2 | `gov-07-review-agent` | GOV-007 reviewer, GOV-008 loop, this file | not yet reviewed | pass | yes (23:28, on owner instruction) |
| 3 | `wp2-step01b-review-fixes` | Step 1 review fixes (PS-001–004, GOV-005, GOV-006, CI trigger) | Round 3: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 1 Minor accepted, 3 Nits — 2 fixed) | pending | yes (20 Nov 07:15, on owner instruction) |
| 4 | `gov-cr0001-merge-protocol` | CR-0001 merge gate, CODEOWNERS, secret scanning, reviewer self-test (7/7) | owner work, self-tested | pass | yes (20 Nov 07:15, on owner instruction) |
| 5 | `wp2-step02-capability-map` | Step 2: BA-001 business capability map (17 domains, 209 L2 capabilities, L3 breakdown) | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 2 Minor, 1 Nit — all fixed) | pass | yes (20 Nov 07:15, on owner instruction) |
| 6 | `wp2-step03-operating-model` | Step 3: BA-002 operating model and department hierarchy (19 departments, owner of all 209 capabilities, systems stance per domain); BA-003 domain dictionary (96 terms) | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits — 13 fixed, 1 left) | pass | yes (20 Nov 07:15, on owner instruction) |
| 7 | `wp2-step04-workflows` | Step 4: BA-004 end-to-end workflows WF-001…WF-028 (17 re-keyed, W6b → WF-018, 10 new for D01/D06/D07); D-12 pilot timing in PS-001/PS-002 | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits — 13 fixed, 1 left) | pass | yes (20 Nov 08:39 IST, build loop, CR-0001 gate PASS) |
| 8 | `wp2-step05-roles-permissions` | Step 5: BA-005 roles (27), re-keyed permission matrix (17 domains), approval authorities, SOD-01…SOD-16 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 2 Nits — all fixed; round 1 had 4 Major, all fixed) | pass | yes (20 Nov 10:57 IST, build loop, CR-0001 gate PASS) |
| 9 | `wp2-step06-prd-platform-product` | Step 6: PRD-001 Platform Administration (D01), PRD-002 Product and Scheme Management (D02); WF-029, WF-030 added to BA-004 register | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 6 Minor, 3 Nits — 8 fixed, Nit 9 (commit trailer) left; round 1 had 2 Major, both fixed) | pass | yes (20 Nov 12:43 IST, build loop, CR-0001 gate PASS) |
| 10 | `wp2-step05b-owner-answers` | Owner answers Q17–Q19 and follow-ups (D-17 to D-25) applied to BA-005, PRD-001, BA-004 WF-020 and GOV-001 §4 | Round 5: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 5 Nits — all fixed except Nit 9 (version bumps, accepted Draft practice) and Nit 10 (trailer)) | pass | yes (20 Nov 2026, merged on the owner's instruction in chat — GOV-001 §4 row, outside the CR-0001 G2 exception) |
| 11 | `wp2-step07-prd-investment-portfolio-oms` | Step 7: PRD-003 (D03), PRD-004 (D04), PRD-005 (D05); WF-031, WF-032 added to BA-004 register | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 4 Minor, 2 Nits — all fixed except Nit 6 (trailer); round 1 had 1 Major, fixed) | pass | yes (20 Nov 13:13 IST, build loop, CR-0001 gate PASS) |
| 12 | `wp2-step08-prd-trading-settlement-compliance-risk` | Step 8: PRD-006 (D06), PRD-007 (D07), PRD-008 (D08, WF-034), PRD-009 (D09, WF-033); owner questions Q22–Q33 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 2 Nits — all fixed except Nit 7 (trailer); round 1 had 5 Major, all fixed) | pass | yes (20 Nov 2026, build loop, CR-0001 gate PASS) |
| 13 | `wp2-step09a-prd-accounting-nav-ops-investor` | Step 9a: PRD-010 (D10), PRD-011 (D11, WF-035), PRD-012 (D12, WF-036), PRD-013 (D13, WF-037, WF-038); owner questions Q34–Q49 | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 10 Minor, 3 Nits — all fixed except Nit 13 (trailer)) | pass | yes (21 Nov 2026, build loop, CR-0001 gate PASS) |
| 14 | `wp2-step09b-prd-distribution-finance` | Step 9b: PRD-014 (D14, WF-039), PRD-015 (D15, WF-040); owner questions Q50–Q52 | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits — all fixed except Nit 14 (trailer); Minor 9 partly (primary circulars not opened)) | pass | yes (21 Nov 2026, build loop, CR-0001 gate PASS) |
| 15 | `wp2-step09c-prd-data-ai` | Step 9c: PRD-016 (D16, WF-041, WF-042), PRD-017 (D17, WF-043); PRD-000 re-keying note; owner questions Q53–Q60 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 2 Minor, 2 Nits — all fixed except Nit 4 (trailer); round 1 had 1 Major, fixed) | pass | yes (21 Nov 2026, build loop, CR-0001 gate PASS) |
| 16 | `wp2-step09d-owner-answers` | Step 9d: owner answers D-26…D-66 applied to PRD-001, PRD-003, PRD-006…PRD-017, BA-001, BA-004; PRD-000 note; owner questions Q61, Q62 | Round 3: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 2 Minor, 1 Nit — all fixed except Nit 3 (trailer); rounds 1–2 had 3 Major, all fixed) | pass | yes (21 Nov 2026, build loop, CR-0001 gate PASS) |
| 17 | `wp3-step10-system-context` | Step 10: EA-001, EA-002 (12 workspaces); ADR-0016…ADR-0019; owner questions Q63–Q65 | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 12 Minor, 2 Nits — all fixed except Nit 14 (trailer)) | pass | no — gate G2 failed: owner-only ADRs (see "Waiting for owner") |
| 18 | `wp3-step11-service-catalogue` | Step 11: EA-003 service catalogue (22 modules, tiers, T1–T19), EA-008 configuration over customisation; owner questions Q66–Q68 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 3 Nits — all fixed except Nit 8 (trailer); round 1 had 3 Major, all fixed) | pass | no — waits behind Step 10 (gate G1) |
| 19 | `wp3-step12-deployment-cells` | Step 12: EA-004 deployment and cells, EA-005 multi-tenant, EA-006 control plane / data plane; NFR-SCAL-005/-006, NFR-DR-002/-003, NFR-AVAIL-003, NFR-SEC-006, NFR-OBS-003; owner questions Q69–Q72 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 6 Minor, 2 Nits — all fixed; round 1 had 5 Major, all fixed, and 10 Minor, 4 Nits fixed except the trailer Nit) | pass | no — waits behind Step 10 (gate G1) |
| 20 | `wp3-step13-events-workflows` | Step 13: EA-007 event architecture and process workflows; `contracts/events/` v1 catalogue (103 events); contract tests; owner questions Q73–Q75 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 5 Nits — all fixed except Nit 10 (trailer); round 1 had 1 Major, 13 Minor, 6 Nits, all fixed except the trailer Nit) | pass | no — `contracts/` is owner-only (gate G2); also waits behind Step 10 (gate G1) |

## Owner decisions used by the loop

| # | Decision | Date |
| --- | --- | --- |
| D-1 | Reviewer is advisory; owner merges (GOV-007) | 2026-11-19 |
| D-2 | Loop: stack steps; scheduled one step per run; 3 fix rounds; log gaps and continue (GOV-008) | 2026-11-19 |
| D-3 | Steps may build on Draft documents; GOV-005 "start after Approved" applies to production build only (resolves review STEP-01 finding 4) | 2026-11-19 |
| D-4 | Loop may merge only through `scripts/merge_gate.py` (CR-0001, GOV-008 §5) | 2026-11-19 |
| D-5 | Paid external expert review before any T1 document is Approved | 2026-11-19 |
| D-6 | Repository to become private (owner action) | 2026-11-19 |
| D-7 (Q5) | Cloud: AWS Mumbai (ap-south-1) primary, Hyderabad (ap-south-2) for disaster recovery | 2026-11-20 |
| D-8 (Q6) | Sign-in: each AMC's own identity provider via OIDC/SAML; Keycloak for AMCs without one | 2026-11-20 |
| D-9 (Q8) | No `ANTHROPIC_API_KEY` repo secret for now; reviews run inside loop sessions | 2026-11-20 |
| D-10 (Q9) | Branch protection on `main` is not on; merge gate + CODEOWNERS remain the control | 2026-11-20 |
| D-11 (Q10) | First target segment: new AMCs (C3) first, mid-size AMCs (C2) second | 2026-11-20 |
| D-12 (Q11) | Go-live by month 24 wins: pilot starts earlier (about month 15–18) so the parallel run ends by month 24. "3–5 paying AMCs by month 36" includes the pilot AMC | 2026-11-20 |
| D-13 (Q12, Q15) | `CAP-Dxx-nnn(.m)`, `DEP-nn` and `TERM-nnn` are official IDs (added to GOV-001 §4) | 2026-11-20 |
| D-14 (Q13) | D01 "Subscription management" = the AMC's subscription to AMC OS (plans, entitlements, metering) | 2026-11-20 |
| D-15 (Q14) | Systems stance stays per domain (replace / connect / mirror, BA-002 §5); per-capability detail during pilot discovery | 2026-11-20 |
| D-16 (Q16) | Fund accounting and NAV: AMC OS replaces them where the AMC does them in-house; mirrors and validates where outsourced to the custodian (also answers architecture proposal OD-2 direction) | 2026-11-20 |
| D-17 (Q17) | `ROLE-nn` is an official ID (added to GOV-001 §4) | 2026-11-20 |
| D-18 (Q18) | No segregation-of-duties rule can be waived, except SOD-03 (tenant-configurable, per PRD-000) and the SOD-16 small-team mode (D-19) | 2026-11-20 |
| D-19 (Q19) | Small AMCs (small-team mode): a Tenant Administrator may also hold a business role; every access grant is reviewed by the Information Security Officer and shown in the SOD-11 nightly report (BA-005 SOD-16) | 2026-11-20 |
| D-20 | What counts as a "small" AMC for small-team mode: decided in pilot discovery | 2026-11-20 |
| D-21 | Small-team mode is switched on only with approval of both the Information Security Officer and a Compliance Officer | 2026-11-20 |
| D-22 | In small-team mode the Information Security Officer reviews each access grant before it takes effect | 2026-11-20 |
| D-23 | Small-team mode: a grant to the AMC's only Information Security Officer is reviewed by a Compliance Officer | 2026-11-20 |
| D-24 | Small-team mode: the ISO pre-effect review is blocking (a rejection stops the grant) | 2026-11-20 |
| D-25 | Small-team mode: when an AMC is no longer small, the mode is switched off when a grace period ends (length set in pilot discovery), and Tenant Administrators then give up their business roles | 2026-11-20 |
| D-26 (Q20) | Lapsed or downgraded module becomes read-only; data never deleted; metering counts users, schemes, API calls and storage | 2026-11-21 |
| D-27 (Q21) | Exit: documented open export formats with checksums; collection period and retention per contract and law | 2026-11-21 |
| D-28 (Q22) | Leftover shares from uneven block splits: rule set by the Head of Dealing per tenant, recorded and audited | 2026-11-21 |
| D-29 (Q23) | Keep a versioned trade-charges table (STT, stamp duty, GST, exchange fees); Operations updates it, Compliance checks (maker-checker) | 2026-11-21 |
| D-30 (Q24) | Settlement-failure penalty: AMC pays if caused by the AMC, otherwise the scheme; Compliance records the cause [VAL — Compliance to confirm against SEBI rules] | 2026-11-21 |
| D-31 (Q25) | Every settlement instruction needs a second approver (no amount threshold) | 2026-11-21 |
| D-32 (Q26) | Compliance rules: a Compliance Officer drafts, only the CCO approves | 2026-11-21 |
| D-33 (Q27) | Internal risk limits: Risk team writes, CRO approves, inside the rule engine | 2026-11-21 |
| D-34 (Q28) | Limit exemptions: granted by the CCO; maximum length is a tenant setting | 2026-11-21 |
| D-35 (Q29) | Legal reading of new SEBI rules: the AMC chooses its Legal Officer or outside counsel | 2026-11-21 |
| D-36 (Q30) | Risk models: validated by anyone who did not build them (inside or outside the AMC) | 2026-11-21 |
| D-37 (Q31) | Unactioned risk alerts: escalation path set per tenant (suggested default CEO, then Risk Committee) | 2026-11-21 |
| D-38 (Q32) | Risk-limit change: CRO approves in AMC OS with the Risk Committee minute reference attached | 2026-11-21 |
| D-39 (Q33) | Operational / enterprise risk register: later release, not release 1 | 2026-11-21 |
| D-40 (Q34) | Custodian-run accounting: load custodian books daily and recheck key items (accruals, unit capital, NAV); no full shadow ledger | 2026-11-21 |
| D-41 (Q35) | Manual journals: Senior Fund Accountant approves (maker ≠ checker); above a tenant-set amount the Head of Fund Accounting also approves | 2026-11-21 |
| D-42 (Q36) | Reopening a closed month: CFO and Head of Fund Accounting | 2026-11-21 |
| D-43 (Q37) | Ageing of receivables/payables: age bands are tenant settings; write-off by maker-checker manual journal | 2026-11-21 |
| D-44 (Q38) | Custodian-calculated NAV: the AMC accepts it in AMC OS after checks; who submits to AMFI is set per tenant | 2026-11-21 |
| D-45 (Q39) | Fair value: always a recorded Valuation Committee decision; no delegate | 2026-11-21 |
| D-46 (Q40) | Price and NAV tolerances, materiality and alerts: set by each AMC; AMC OS ships no values | 2026-11-21 |
| D-47 (Q41) | Swing pricing: not in release 1 (a swung NAV is blocked) | 2026-11-21 |
| D-48 (Q42) | Operations day close: no override while a critical item is open | 2026-11-21 |
| D-49 (Q43) | Voluntary corporate actions: Fund Manager decides; missed deadline escalates to CIO; nothing elected automatically | 2026-11-21 |
| D-50 (Q44) | Reconciliation-break write-off: Operations Manager (maker-checker); above a tenant-set amount Fund Accounting also approves | 2026-11-21 |
| D-51 (Q45) | Scheme expense payments: paid outside AMC OS for now; AMC OS records and checks them | 2026-11-21 |
| D-52 (Q46) | Payout files (redemption, SWP, IDCW): sent by the RTA; AMC OS tracks and checks | 2026-11-21 |
| D-53 (Q47) | Wrong investor details: fixed only through the RTA; flagged in AMC OS until corrected | 2026-11-21 |
| D-54 (Q48) | Grievance Officer and DPO: named person per AMC; DPO proposed with the Compliance Officer | 2026-11-21 |
| D-55 (Q49) | Investor messages: AMC OS prepares, consent-checks and tracks; the RTA or the AMC's provider sends | 2026-11-21 |
| D-56 (Q50) | Distributor commission paid = AMC OS calculation, checked against the RTA figure, approved by Finance | 2026-11-21 |
| D-57 (Q51) | Commission in the books, by type: trail commission is a scheme expense inside TER; amounts paid outside TER (e.g. SIP upfront) are an AMC company cost [VAL — Compliance to confirm current SEBI rules] | 2026-11-21 |
| D-58 (Q52) | Budgets and multi-year plans are made in AMC OS | 2026-11-21 |
| D-59 (Q53) | Metric definitions: Data Steward drafts, business owner approves (maker ≠ checker); Compliance also signs off regulatory metrics; no new council | 2026-11-21 |
| D-60 (Q54) | New AI assistant or model: approved by its business owner, CTO and Information Security Officer; Risk Manager validates; no new committee | 2026-11-21 |
| D-61 (Q55 / OD-4) | AI processing of AMC data: India-region private endpoints only, zero data retention, no training on AMC data; provider chosen later | 2026-11-21 |
| D-62 (Q56) | Reference data: one copy per AMC (licences are per AMC); only currencies shared | 2026-11-21 |
| D-63 (Q57 / OD-9) | Portfolio Agent and Product Intelligence Agent: later release, not release 1; Product Intelligence will be the D02 (Product and Scheme) agent | 2026-11-21 |
| D-64 (Q58) | SEBI AI/ML reporting: AMC OS prepares the data from its AI inventory; Compliance files [VAL — content and frequency to be confirmed] | 2026-11-21 |
| D-65 (Q59) | D16 owns the `master` schema (securities, issuers, ratings, benchmarks); GOV-001 §3 updated | 2026-11-21 |
| D-66 (Q60) | PRD-000 stays Draft with a 'fully re-keyed' note on top; marked Superseded only once a replacement is Approved | 2026-11-21 |
| D-67 (OD-1) | Positioning: connect to the AMC's existing systems first; AMC OS runs its own engines area by area where the AMC chooses (ADR-0009 option C) | 2026-11-21 |
| D-68 (OD-2) | Default system of record for accounting/NAV: AMC OS where done in-house, external with checks where outsourced (same as D-16) | 2026-11-21 |
| D-69 (OD-3) | '20–50 AMCs' is design capacity; commercial target stays 3–5 paying AMCs by month 36 | 2026-11-21 |
| D-70 (OD-7) | Kafka later, when volumes need it; start with database-backed (outbox) messaging, designed so Kafka can be added | 2026-11-21 |
| D-71 (OD-5 / OD-6) | API gateway and policy-engine products: Step 10 evaluates them now that cloud (D-7) and sign-in (D-8) are decided | 2026-11-21 |
| D-72 (OD-8) | No external AI tools reading AMC OS through MCP in release 1 | 2026-11-21 |
| D-73 (OD-10) | AI assistants: one shared, versioned definition list plus a per-AMC switch-on (needs WP4 database change) | 2026-11-21 |
| D-74 (OD-11) | Fund Accounting and NAV Operations are two separate workspaces (master prompt §5 L1); the AI assistant is built into every workspace | 2026-11-21 |
| D-75 (OD-12) | Emergency switch-off of AI (agent, tool or all AI for an AMC) by one authorised person; switching back on needs two people | 2026-11-21 |

## BA-005 changes waiting for its next revision (review STEP-09d round 1, finding 11)

The owner decisions D-28…D-75 add or narrow rights that BA-005 does not yet have. The PRDs mark them with † and defer them to the next BA-005 revision. Pick all of them up together:

- BA-005 §4 `compliance.rule.approve` says "another Compliance Officer"; D-32 says only the CCO approves (PRD-008 §7, C2).
- PRD-006 §7: trade-charges table (Operations Analyst maker, Compliance Officer checker, D-29); allocation remainder rule set by the Head of Dealing (D-28).
- PRD-007 C6: `settlement.instruction.approve`, `settlement.instruction.cancel`, `settlement.fail.write_off`, `settlement.fail.record_cause` (D-30, D-31).
- PRD-008 §7, C3, C9: Risk team writes and CRO approves internal limits (D-33); CCO grants exemptions (D-34); Legal Officer or outside counsel per AMC (D-35).
- PRD-009 §7: model validation by anyone independent (D-36); escalation path (D-37); CRO limit change with Risk Committee minute (D-38).
- PRD-010 FR-D10-019, §7: manual journals approved by the Senior Fund Accountant, and above a tenant-set amount also by the Head of Fund Accounting (D-41); BA-005 §4 has no journal permission.
- PRD-012 C14: BA-005 §4 `operations.payout.release` should no longer point to WF-011 after D-52 (the RTA sends investor payout files); PRD-014 still uses it for commission payments.
- PRD-010 C3: reopening a closed month by CFO and Head of Fund Accounting (D-42); BA-005 §3 still gives the COO a reopen role.
- PRD-011 §7, PRD-012 §7: Head of Fund Accounting accepts custodian NAV (D-44); break write-off above a tenant amount (D-50).
- PRD-013 C3, PRD-016 §7: Grievance Officer and Data Protection Officer roles (D-54, Q61).
- From Step 11 (EA-008 §6.2): the Head of Sales role (PRD-014 BRL-D14-005) and the right `operations.recon_definition.approve` (PRD-012 §7).
- PRD-014: Finance approval of commission paid (D-56). PRD-016, PRD-017 C6: metric definition sign-offs (D-59); AI release approvals (D-60) and emergency switch-off (D-75).

## Waiting for owner (cannot be auto-merged)

| Branch | Why |
| --- | --- |
| `wp3-step10-system-context` | Merge gate 21 Nov 12:47 IST, 16:52 IST (Step 11 run), 20:55 IST (Step 12 run) and 22 Nov 00:58 IST (Step 13 run): **FAIL on G2 only** (G1, G3–G6 pass; CI success). Adds ADR-0016…ADR-0019 in `architecture/adrs/` (owner-only in CODEOWNERS, gate G2). The branch also carries the wording fixes to ADR-0002 (one or more schemas), ADR-0006 (outbox first, Kafka later, D-70) and ADR-0007 (orchestrator choice in Step 19), made at the owner's request in chat on 21 Nov 2026; the loop is not permitted to merge owner-only files, so the owner merges this branch. If you merge the proposal branch later, mark its ADR-0015 Superseded by ADR-0019 |
| `wp3-step11-service-catalogue` | Stacked on Step 10, so it cannot pass gate G1 until the owner merges Step 10. It has no owner-only files of its own (GOV-001 register rows, GOV-006 status cell, `reviews/`, LOOP_STATE only), so the loop can merge it after Step 10 is in `main` |
| `wp3-step12-deployment-cells` | Stacked on Step 11, so it waits behind Step 10 (gate G1). No owner-only files of its own (GOV-001 register rows, GOV-006 status cell, EA README, `reviews/`, LOOP_STATE only). It names two ADRs the owner should have drafted (ADR-0020 scope extended, ADR-0021 control plane) |
| `wp3-step13-events-workflows` | Adds `contracts/events/` (owner-only in CODEOWNERS, gate G2) and stacks on Step 12, so the owner merges it. Also asks the owner to add a CI job for `tests/contracts` (`.github/` is owner-only) |
| — | Note for the owner: `scripts/merge_gate.py` accepts table-row-only changes anywhere in GOV-001, which is looser than CR-0001 G2 (review STEP-05b round 2, finding 1); fixing the script is an owner-only change |

## Questions for owner (open)

| # | Question | Raised by | Default used meanwhile |
| --- | --- | --- | --- |
| Q61 | Owner decision D-54 says "DPO proposed with the Compliance Officer". Does this mean (a) the Compliance Officer is suggested as the DPO, or (b) the AMC names a separate DPO, chosen together with the Compliance Officer? It matters for segregation of duties on access to personal data (PRD-016 CAP-D16-009) | Step 9d review (STEP-09d round 1, finding 10) | (a) — the Compliance Officer is suggested as DPO, marked [ASSUMPTION] in PRD-013 and PRD-016 |
| Q62 | Owner decision D-66 says PRD-000 gets a "fully re-keyed" note. In fact some parts of PRD-000 are not yet re-keyed (common rules C1–C8, two Ch 9 agents, some Ch 7 rows, Ch 8, Ch 10, Appendix A); they move in later steps (architecture, integrations, regulatory registry). Is it fine that the note lists these remaining parts instead of saying "fully re-keyed"? | Step 9d review (STEP-09d round 1, finding 5) | Yes — the note lists what is still left in PRD-000 |
| Q63 | Should the workspace labels WS-01…WS-12 (EA-002 §3) become official IDs, with a row `WS-nn` in GOV-001 §4? | Step 10 | Working labels only, not official |
| Q64 | Product and scheme management (D02) has no workspace in master prompt §5 L1. Keep scheme set-up inside the System administrators workspace (WS-12) with Product Managers seeing only that module, or add a 13th "Product" workspace? | Step 10 (EA-002 §3.2) | Inside WS-12 |
| Q65 | ClickHouse is in ADR-0007. Should the pilot start with it from day one, or start with PostgreSQL only for analytics and add ClickHouse when volumes need it (like Kafka, D-70)? | Step 10 (EA-002 §8) | Open — no default; DA-001 (Step 15) will propose |
| Q66 | System-of-record register (EA-003 §6): accept the smaller design — fixed record holders, plus per-scheme accounting mode and NAV mode and the per-tenant NAV submitter as named settings, with a generated read-only view — instead of the proposal's generic per-object register checked by the policy engine? | Step 11 (EA-001 G4) | Smaller design (EA-003 §6) |
| Q67 | Emergency universe override (FR-D05-012): may a new security get a fast-track golden-record approval so the emergency order can go ahead, and if so who approves it? | Step 11 (EA-003 T10; PRD-016 C10) | No fast track — the order waits for WF-041 |
| Q68 | May an AMC add its own tags or extra fields to records (for reporting only, never used by calculations or rules)? | Step 11 (EA-008 §10) | No tenant-defined fields |
| Q69 | Drop the DEDICATED_DB tier (a shared application with the AMC's own database)? An AMC that wants its own database would get a full dedicated cell instead (EA-004 §1) | Step 12 | Dropped — two shapes only: shared cell and dedicated cell |
| Q70 | How far may a dedicated cell lag behind the shared cells' release? | Step 12 (EA-004 §8.1) | At most one release behind |
| Q71 | Should the pilot AMC start alone in its own shared-shape cell (others join later), rather than in a dedicated cell or with other AMCs? | Step 12 (EA-004 §5) | Yes — alone in a shared-shape cell |
| Q72 | Offer a dedicated cell inside the AMC's own AWS account in release 1? | Step 12 (EA-004 §1) | Designed, but offered only after release 1 |
| Q73 | Temporal (the workflow engine): one namespace per cell, with the tenant in every workflow ID, or a separate namespace per AMC? | Step 13 (EA-007 W5) | One per cell |
| Q74 | Should AMC OS send events to the AMC's own systems (webhooks or event streams) in release 1? | Step 13 (EA-007 E12) | No — events stay inside AMC OS in release 1 |
| Q75 | Keep delivered events 35 days in the database for replay before archiving them (with up to 10 retries over about 2 hours before an event is set aside for a person)? | Step 13 (EA-007 D5, D8) | Yes, as starting values |
