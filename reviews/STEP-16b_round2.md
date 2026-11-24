## AMC OS Review Agent — advisory review

**PR:** branch `wp4-step16b-ddl-product-front-office` (base `wp4-step16ac-review-fixes`), round 2 · **Step / WP:** GOV-006 Step 16, part b (WP4) · **Reviewed at:** 077107c9dcef12f981a7c62deb4413c61778871f

**Verdict (advisory):** RECOMMEND CHANGES
The three round-1 Majors are fixed as written and every test passes. But the new compliance gate only checks that a result exists for the current order version, not what the result says. So an order whose pre-trade check is BLOCK or INDETERMINATE can still go straight to approval and skip the override process.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Major | database/ddl/DDL-002_…sql:1493-1502; DA-001 §11 row `trading."order"` (line 914) | The new DM-6 gate needs a `PRE_TRADE` row for `NEW.order_version` but ignores its `outcome`. I tested this in a scratch copy as `amc_app`. With a current-version result of `BLOCK`, the move `PENDING_COMPLIANCE → PENDING_APPROVAL` was accepted. The same happened with `INDETERMINATE`, and with `WARN` when there was no `trading.warn_acknowledgement`. This conflicts with PRD-008 BRL-D08-008 and AC-US-D08-008-1 (INDETERMINATE means BLOCK pre-trade, and the order is `COMPLIANCE_BLOCKED`). It also conflicts with PRD-005 §10 (a WARN needs an acknowledgement). In the database, a blocked order can reach a human approver without going through `OVERRIDE_REQUESTED → OVERRIDE_APPROVED`. The fix commit says it "closes the three control gaps", but this one stays open. This is new; round 1 asked only for a result to exist. | In the same trigger (same schema, so M4 allows it): `PENDING_COMPLIANCE → PENDING_APPROVAL` only with outcome `PASS`, or `WARN` plus a `warn_acknowledgement` for that version. `PENDING_COMPLIANCE → COMPLIANCE_BLOCKED` only with `BLOCK` or `INDETERMINATE`. `OVERRIDE_APPROVED → PENDING_APPROVAL` only with `BLOCK` or `INDETERMINATE` on the current version. Add DBT tests for each case. If the owner wants this left to the application, record it in DA-001 §11 and in Q81. |
| 2 | Minor | DDL-002_…sql:2109-2132; DA-001 §11 line 923 | Round-1 Major 2 is fixed as far as it went: unknown users, service identities and inactive users are now refused (T11f, T11g). But `callback_by` and `callback_at` are still values the maker types in. I tested it: the maker named an active colleague who did nothing, with `callback_at = now() + 10 days`, and the row was accepted. DA-001 §11 says "each version has a call-back by another active human user", which reads as enforced. In fact the database stores the maker's claim, and the checker (`approval_request_id`) is expected to confirm it. | Refuse `callback_at` in the future (`callback_at <= clock_timestamp()`). Either record the call-back as a separate act by the call-back user (`tg_set_actor`), or reword DA-001 §11 to say the maker records it and the checker confirms it. |
| 3 | Minor | DDL-002_…sql:2285-2311 | Round-1 Minor 8 is fixed only at INSERT. The valid-on-date trigger is `BEFORE INSERT` only. I tested it: a payment instruction was created against a valid account version. Then the account version was retracted (RETRACT closure; no current version left). The payment then moved `READY → SENT` without error. So a bank-account or SSI change that was retracted for fraud does not stop instructions already waiting to go out. | Re-run the check when `delivery_state` moves `READY → SENT` (for example `BEFORE UPDATE OF delivery_state`), on `settlement.payment_instruction` and `settlement.instruction`. Add a test with an END and a RETRACT. |
| 4 | Minor | DDL-002_…sql:1748, 1754-1760 | The comment says a leg of unknown outcome "cannot be cancelled until its outcome is known". But `UNKNOWN_OUTCOME → READY` is an ordinary `STATE_CHANGE`, and nothing ties it to a recorded status-query result. T10g itself does `UNKNOWN_OUTCOME → READY → CANCELLED` with no evidence. INT-001 §6 allows this move only when the "provider confirms not received", so for now only the application enforces that. | Require a `STATUS_QUERY` (or `DECISION`) attempt row showing "not received" before `UNKNOWN_OUTCOME / INVESTIGATION → READY`. Otherwise, soften the comment and DA-001 §11 to say the application enforces this. |
| 5 | Minor | database/tests/DBT-002_step16b_tests.sql | Round-1 Minor 6 is still partly open, as the commit says. Not tested: the cancel rule on `settlement.payment_instruction` (only `broker_order` T10f/T10g and `instruction` T11i are tested), the SSI valid-on-date path of `settlement.instruction`, an ended or retracted account (T11h covers only "no version at all"), and the earlier list (END / RETRACT on other BT tables, crosswalk, NFO, rebalance lines). Several `expect_fail` calls still pin only a SQLSTATE (for example lines 292, 384, 422, 494). T2e now tests UPDATE; the DELETE branch of `scheme_mandate_draft_only` is still untested. | Add the missing cases and pin the message prefixes (QA-001). |
| 6 | Nit | LOOP_STATE.md row 28 | Row 28 still says `REVIEW_PENDING` and does not record round 1 (RECOMMEND CHANGES; 3 Majors fixed, Minor 6 partly). Other rows record each round. | Record the round-1 result and what was fixed. |
| 7 | Nit | commit 077107c | The trailer is still `Co-Authored-By: Claude <noreply@anthropic.com>` (round-1 Nit 14, not addressed). | As in earlier steps. |

Round-1 fixes verified as correct:
- Major 1: the CHECK on all three instruction tables. T10f, T10g and T11i pass.
- Major 2: unknown, inactive and service users are refused (see Finding 2 for what remains).
- Major 3: the version gate. T8g and T8h pass; the existing order FK on `compliance_result_ref` stops a result being stored ahead for a future version.
- Minors 4 and 9: now documented in DA-001 §11.
- Minor 7: `NULLS NOT DISTINCT`.
- Minor 10: DEFAULT partition added.
- Nit 11: active-maker check added.
- Nit 12: `sent_at` can only be set once.
- Nit 13: header now says v0.4.

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "81 spec documents checked; 0 problem(s)." |
| pytest tests/governance | 28 passed |
| Database (/tmp/runall.sh, PostgreSQL 16 on /tmp) | All DDL files applied (rc=0). DBT-000 23 PASS, DBT-001 43 PASS, DBT-002 65 PASS, "All tests passed". This matches the commit's claim; 65 = 56 + 9 new tests (T8g, T8h, T10f, T10g, T11f–T11j). |
| Experiments (scratch copy `amcos_rev2`, run as `amc_app`, dropped afterwards) | Findings 1, 2 and 3 reproduced as described. A call-back by an unknown user was refused; the `maker_user_id` given at insert was overwritten by the acting user. |
| Arithmetic re-computed | No new derived figures in this round. The round-1 figures are unchanged and were not re-derived. |
| Sources | No market figures or vendor facts. Rule references checked against the repo: INT-001 §6 diagram (UNKNOWN_OUTCOME → READY "provider confirms not received"), EA-007 A2, PRD-007 BRL-D07-001, PRD-008 BRL-D08-008 / AC-US-D08-008-1, DA-001 DM-6. |
| Scope vs GOV-006 step | Unchanged from round 1: the 16b scope is delivered and the ADR-0020 items are correctly left out. This round changes only triggers, CHECKs, one partition, tests and doc rows. GOV-001 §7 (DBT-002 65 checks), DA-001 v0.4 §11, GOV-006 row 16 and LOOP_STATE are updated. |
| Governance / instruction injection | Nothing in the change, the commit messages or reviews/STEP-16b_round1.md tries to direct the reviewer. |

### Not checked
- **CI status:** not verified. `gh run list -b wp4-step16b-ddl-product-front-office` returns no runs, so the branch has not been pushed or run in CI.
- **reviews/STEP-16b_round1.md "unedited":** not verified. I have no copy of the original reviewer output to compare it with.
- **Concurrency:** the race between an amend and the compliance gate was reasoned about (both update the same order row, so the trigger sees the latest version) but not run in two sessions.
- **Performance** of the deferred position-consistency trigger and the exposure view: not assessed (same as round 1).

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
