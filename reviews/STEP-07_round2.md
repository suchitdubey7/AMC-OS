## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step07-prd-investment-portfolio-oms` (base origin/main 104bde6) · **Step / WP:** GOV-006 Step 7 / WP2 (review round 2) · **Reviewed at:** 3b4c595208d4e67b7f4c804043c86b0cf40c041f

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
All 16 round-1 findings were fixed or accepted as before. The PRD-005 §4.3 state machine now matches the DDL-000 `trading.order_state_transition` table exactly (30 of 30 transitions, none extra and none missing). The new findings are Minors and Nits about consistency.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | LOOP_STATE.md:9 | The Step 8 next action still says "settle the side-exit states of the order state machine (PRD-005 C4)". After the round-1 fix, the side exits come from DDL-000, and C4 is now about something else: how an amended order version re-enters `PENDING_COMPLIANCE`. The note would send Step 8 to work on a question that is already closed. | Change it to "settle how an amended order version re-enters `PENDING_COMPLIANCE` (PRD-005 C4)". |
| 2 | Minor | docs/03_product_requirements/PRD-005_order_management.md:227 | C4 (amendment re-entry) is to be closed in "PRD-006 (Step 8) with D06 states". Amendment and versioning belong to D05 (CAP-D05-004, BRL-D05-004), not D06. AC-US-D05-008-1 also needs a transition that §4.3 and FR-D05-016 currently refuse, so this matters before the state machine is built. | Name the closing document as DA-001 (Step 15) or a PRD-005 revision. Keep PRD-006 only if D06 states are really involved. |
| 3 | Minor | PRD-005:188 vs :103 | The §9 "Broker reject" row says the "dealer may re-route as a new release". In the adopted DDL state machine, `REJECTED_BY_BROKER` has no outgoing transition, and `order_open_ix` treats it as closed. So re-routing cannot happen on the same order, and the PRD does not say what "a new release" is (a new order? a new version? which decision link and compliance run?). | Say that a re-route creates a new order or version that goes through compliance again, or add the question to C4. |
| 4 | Minor | PRD-005:77, :118 | FR-D05-016 says illegal transitions are "refused … by the database". The DDL-000 trigger `trading.tg_order_state` runs only on `BEFORE UPDATE OF state`. `trading.order.state` has no CHECK on the allowed values, and nothing on INSERT, so an order can be inserted directly in, for example, `FILLED`. The `PARTIALLY_FILLED → PARTIALLY_FILLED` self-transition is never checked and writes no `order_event`, because the trigger skips rows where the state is unchanged. The wording comes from PRD-000, but the PRD now relies on the DDL. | Add an open point for DA-001 / DDL (Steps 15–16): a state-domain CHECK, initial state `DRAFT` enforced on insert, and how further partial fills are recorded as order events (or say they are recorded only in D06 `execution`). |
| 5 | Nit | PRD-005:189 vs :111-112 | §9 "Late fill after cancel → exception queue" can now be read as conflicting with the new `CANCEL_REQUESTED → PARTIALLY_FILLED/FILLED` transitions. | Write "Fill after the order is `CANCELLED`"; a fill while `CANCEL_REQUESTED` follows §4.3. |
| 6 | Nit | commit 3b4c595 message | The trailer still reads `Co-Authored-By: Claude <noreply@anthropic.com>` (round-1 Nit 16; accepted in LOOP_STATE). | None needed unless the owner wants it. |

**Round-1 follow-up:** 1 Major fixed (exact match, see Checks run). The Minors were fixed as follows:
- 2: † marks and C7 added.
- 3: C6 added.
- 4: AC IDs aligned (§2 → AC-US-D03-002-2; US-D03-005 cites both).
- 5: merges and rewordings listed in the PRD-004 and PRD-005 §2 tables, checked against PRD-000 Module 03 and Module 04 point 7.
- 6: new acceptance criteria marked new [DES] and listed in §2.
- 7: FR-D04-002 marked (changed).
- 8: C5 now includes "zero lost fills" and the raw FIX archive; NFR-AUD-005 is split by source.
- 9: the DDL list is corrected (`order_version` and `intent_pct` exist in DDL-000) and the schema-write question is C9.
- 10: FR-D05-015 is now generic, with C8.
- 11: the debt-issuer credit row is IC-only, and FR-D03-012 sends the issuer limit to D08 (CAP-D08-002), consistent with PRD-000 Module 02 point 6 steps 1 and 5.
- 12: headroom is "as reported by D08".
- 13: the BA-004 line 51 text and the §5.1 D03/D04 rows are updated.

The Nits were handled as follows:
- 14: FR-D02-013 is now cited; it is the disclosures/factsheet feed in PRD-002:68.
- 15: fixed.
- 16: accepted as before.

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | PASS — "37 spec documents checked; 0 problem(s)." (exit 0, head 3b4c595) |
| `python3 -m pytest -q tests/governance` (claimed in commit) | Re-run: 14 passed. The claim holds. |
| State machine vs DDL-000 | A script parsed the PRD-005 Mermaid arrows (without `[*]→DRAFT`) and the DDL-000 lines 597-609 INSERT. Both have 30 transitions; DDL minus PRD = ∅ and PRD minus DDL = ∅. |
| Arithmetic re-computed | No new derived numbers. Counts in LOOP_STATE were checked: new FRs are 10 (FR-D03-011…020), 8 (FR-D04-012…019) and 5 (FR-D05-012…016). All correct. The 30-transition count was confirmed. |
| Sources | All sources are in the repo. No new external facts or regulatory figures were added in round 2. The carried "SEBI circular of 10 July 2026" stays [REG — VAL] (source not opened). No invented provider interface was found. |
| Scope vs GOV-006 step | Delivers PRD-003, PRD-004 and PRD-005, plus WF-031 and WF-032. The GOV-001 §7 register, the GOV-006 Step 7 cell, the PRD README and the BA-004 register and §5.1 are updated. Nothing outside the step's scope. |
| Front matter / IDs | All three PRDs are Draft, have full front matter, and each ID matches its file name. No duplicate IDs were introduced. |
| Instruction injection | None found in the diff or the commit messages. |

### Not checked
- CI status on GitHub: the branch has no PR number or push. Only local runs were checked.
- Regulatory sources carried from PRD-000 (SEBI circulars, AMFI lists) were not opened; they are not in the repo, and the PRDs keep them as [VAL].
- The DDL/DBT database tests were not run, because the change makes no database change. The DDL statements in finding 4 come from reading DDL-000 lines 592-697, not from running them.
- `scripts/merge_gate.py` (CR-0001) was not run; it is the owner's or the loop's gate step.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
