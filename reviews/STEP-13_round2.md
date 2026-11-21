## AMC OS Review Agent — advisory review

**PR:** branch `wp3-step13-events-workflows` (base `origin/wp3-step12-deployment-cells`; local only, no PR number) · **Step / WP:** GOV-006 Step 13 / WP3 · **Reviewed at:** 5058ac7bf303b6baf126aaff518340c8230d2d5f

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
Round 1 findings 1 to 19 are fixed, including the Major one (W1 duplicate starts) and all checks pass. What remains is Minor and Nit only. Most of it is in the new duplicate-start rule (W1a) and in the new signal-bridge routing: workflow types left out, no recovery path for failed runs, a retention "default" that does not hold for a self-hosted setup, and no rule for a signal whose target workflow does not exist.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/04_enterprise_architecture/EA-007_event_architecture_and_process_workflows.md:355 (W1a) | W1a says "every start sets the reuse policy explicitly". But it gives no policy for 4 of the 24 workflow types in §9.1: `CorporateAction` (WF-009), `NavCorrection` (WF-017), `SchemeChange` (WF-029) and `SchemeEnd` (WF-030). I checked this with a script against the §9.1 table. NAV correction is a financial process. | Give each of the four types a reuse policy (or say it uses signal-with-start). Add a check that every workflow type in §9.1 appears in W1a. |
| 2 | Minor | EA-007:355 (W1a), 446 | Temporal's page S13 (opened during this review) says **Reject Duplicate** refuses a new run "regardless of the Closed status". That includes Failed, Timed Out and Terminated runs. So a `NavDay`/`SchemeNav`, `TradeSettlement`, `SettlementDay`, `BrokerOrder` or `BreakGlass` run that fails or is terminated (for example at the §9.5 history limit, or by an operator) cannot be restarted under the same ID for the whole retention period. No recovery path is designed, and §10.1 allows only reruns inside the workflow or WF-017. The same page says **Allow Duplicate Failed Only** "guarantee[s] that the Completed Workflow Execution will not be re-executed", and W1a already makes the module's unique record the lasting guard. | Use Allow Duplicate Failed Only for these types, with the module record as the guard. Or design the recovery (for example a restart ID suffix allowed only by the owning module). Add to T-E10: a terminated `SchemeNav` can be restarted the same day. |
| 3 | Minor | EA-007:355 (W1a), 360 (W6), 591 (S13) | Both rules treat 30 days as "Temporal's default" retention. The Temporal Server page (https://docs.temporal.io/temporal-service/temporal-server, opened during this review) says retention is set when the namespace is registered. The CLI default is 3 days, and the Register Namespace API returns an error if no value is given. The "30 days" on the S13 page is only an example. In a self-hosted cell there is no 30-day default. | Make the namespace retention an explicit [DES]/[ASSUMPTION] setting chosen by this design (for example 30 days), cite the Temporal Server page, and keep the SEC-001/REG-001 confirmation. |
| 4 | Minor | EA-007:385–391 (§9.4) | The new bridge routing signals a specific child or parent workflow. It does not say what happens if that workflow does not exist yet or has already closed. Two examples: `ACCOUNTING_DAY_CLOSED` arrives before the parent has started the `SchemeNav` child; `RECONCILIATION_COMPLETED` arrives after the NAV day ended. A failed signal is a handler error. Under D5/D6 it is retried, then dead-lettered, and because these are FINANCIAL events the aggregate is parked for the bridge. That raises false alerts. The table also does not say which payload field gives the NAV date (`price_date`, `business_date`, `accounting_date`). | Add a rule: if the target is not found or is closed, the bridge records the event in its inbox as handled with no action (the timer re-check in §10.1 covers readiness). Name the date field for each event. |
| 5 | Minor | EA-007:139, 556 | The new tests T-E9 and T-E10 are not reflected in the §3 "Tests" row ("T-E1…T-E8") or in the §13 QA-001 effect row ("Tests T-E1…T-E8"). | Change both to T-E1…T-E10. |
| 6 | Nit | EA-007:18, 189, 593 | D-14 is cited (`TENANT_ENTITLEMENT_CHANGED`, line 189). It is missing from the "Owner decisions used" list and from S12. | Add D-14. |
| 7 | Nit | EA-007:572–575, 590–593, 574 | The gaps are ordered G7, G9, G10, G8, and the sources S10, S13, S11, S12. G10 says "Steps 22". | Put both lists in number order; write "Step 22". |
| 8 | Nit | contracts/events/AI_KILL_SWITCH_CHANGED.v1.schema.json:45 | `scope_ref_id` is optional even when `switch_scope` is `ASSISTANT` or `TOOL`. A switch for "an assistant" that does not say which one is accepted. | Add an if/then that requires `scope_ref_id` unless the scope is `ALL_AI`. |
| 9 | Nit | contracts/events/README.md | The README does not mention the new `figure_source` metadata (E7) or the `changes:` list in `catalogue.yaml`. | Add one line each. |
| 10 | Nit | commits 31fc888, 5058ac7 trailer | `Co-Authored-By: Claude <noreply@anthropic.com>`. This is the known open trailer Nit (round 1 #20), still open. | As in earlier steps. |

Round 1 follow-up:
- **Fixed:** #1 (W1a, S13, T-E10; new issues in findings 1–3), #2 (E7 `figure_source` and test), #3 (tolerant reader, D5, T-E9), #4 (bridge routing; new issue in finding 4), #5 (NFO waits by timer and readiness call), #6 (G9; I checked that it maps all 15 remaining workflows to GOV-006 Steps 20–25 and 27), #7 (EA-003 row; I checked §3.1, §3.14, §3.17, §3.20, §3.22 and §4.3), #8 (PRD-016 narrowing recorded), #9 (`uniqueItems` and an if/then requiring 2 users for ON, with a test), #10 (ACCESS events parked), #11 (per-tenant data key, consistent with EA-005 §5), #12 (hard imports, E7 test), #13 (LOOP_STATE: Q73–Q75; next free numbers PERF-029, AUD-019, SEC-008, AVAIL-005, OBS-005, Q76 are consistent), #14 (E12 citation), #15–#19 (Nits).
- **Open:** #20 (trailer).

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | Re-run: 61 spec documents checked; 0 problems |
| pytest tests/governance tests/contracts | Re-run: 330 passed, 0 skipped. This matches the commit's claim. |
| Arithmetic re-computed | Recounted with Python. 103 catalogue events = 103 payload schema files = 103 rows in §8, with the same set of names. 21 kind-P workflows in §9.1. W1a covers 20 of the 24 workflow types (finding 1). `figure_source` is declared on every schema with money or decimal figures. ENGINE events require `engine_version`. ENGINE_RUN_REF events require a `*_run_id`, and the referenced run events (NAV_CALCULATED, COMMISSION_RUN_CALCULATED) require `engine_version`. `changes: []` is present. There are no money figures to recompute. |
| Sources | Opened during review: S13 (https://docs.temporal.io/workflow-execution/workflowid-runid) matches the policy names in W1a (Allow Duplicate default, Allow Duplicate Failed Only, Reject Duplicate, Use Existing, retention limit). Its wording on Reject Duplicate is the basis of finding 2. The Temporal Server retention page contradicts "30 days default" (finding 3). Same sources as round 1 for S8–S10, not re-opened. No regulatory fact is stated; deadlines are marked [VAL]. |
| Scope vs GOV-006 step | Delivered: EA-007, the full `contracts/events/` v1 catalogue (103 events), and workflow designs for the five ADR-0006 processes plus the broker leg. The other 15 kind-P designs are recorded as gap G9 with their delivering steps. D01–D17 all covered. GOV-001 register, GOV-006 step 13 status and EA README updated. |
| Governance / IDs | EA-007 front matter is complete; status Draft; ID matches the file name. No document or ADR is set to Approved. No ADR is edited. |
| Instruction injection | None found in the diff, the commit messages or the saved round 1 review. |

### Not checked
- CI status: the branch is local only and has no PR or CI run, so the test claims were checked only by re-running them locally.
- Database: there is no DDL in this change. The proposed outbox, inbox and dead-letter tables were not checked against DDL-000 (they are inputs to DA-001).
- Every payload field list against the PRD FRs: deferred to DA-001 and the FE specs (EA-007 G8).
- Whether the "Use Existing" conflict policy can be combined with signal-with-start in every Temporal SDK: not verified per SDK.
- Temporal sources S8–S10 were not re-opened in this round; they were checked in round 1.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
