## AMC OS Review Agent — advisory review

**PR:** local branch `wp2-step07-prd-investment-portfolio-oms` (not pushed), round 2 · **Step / WP:** GOV-006 Step 7 / WP2 · **Reviewed at:** 228722859f422fb1f24197100f448ea117d28d61 (base origin/main 104bde6)

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
16 of the 17 round-1 findings are fixed, including the Major. Finding 13 is the verdict placeholder, which is left open on purpose. I checked each fix against BA-001, PRD-000, DDL-000 and BA-005. The fixes introduced one new Minor and one Nit.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/03_product_requirements/PRD-005_order_management_system.md:86 (FR-D05-016); :198 (C3 (a)) | The fix for round-1 finding 12 is new text, and it has two gaps. (a) It does not say how long the out-of-universe override lasts. "Exists for that scheme and security" reads as a standing permission. A standing override would let any number of later orders buy a security that is not in the approved universe, which skips the universe approval in WF-002 / WF-031 (CIO or Investment Committee). (b) It says the override is raised "before the order is created or resubmitted". But C3 (a) says DDL-000 has no way back to `PENDING_COMPLIANCE`, and BRL-D05-005 / AC-US-D05-008-1 refuse a failed request without storing it. So "resubmitted" has no defined meaning. | State the override's scope: one order, or a set quantity or time window, with an expiry. Say that once the override exists, a new order request is made (no resubmission). Optionally state that a restricted-list BLOCK cannot be overridden by any path, including SOD-04. |
| 2 | Nit | PRD-005:63 (FR-D05-004); PRD-003:61 (FR-D03-004) | The validation added to D05 covers "not on the restricted list" as pass or fail. FR-D03-004 also says the grey / watch list warns. DDL-000 `investment.restricted_list_entry.restriction` allows `WARN` as well as `BLOCK`. The PRDs do not say how D05 shows a `WARN` entry: as a warning on the order, or with an acknowledgement as for compliance WARNs. | Add one clause to FR-D05-004 on how `WARN` entries are handled. |
| 3 | Nit | LOOP_STATE.md:49 | The placeholder `STEP7_VERDICT` is still there (round-1 finding 13; expected, it is filled after this round). | Fill it in after this round. |

**Round-1 findings: what happened to each**
- **Finding 1 (Major), fixed.** PRD-003 §12 now has the CIO copilot as CAP-D17-003, and old C5 is gone. PRD-005 §12 gives blocked-order explanations to CAP-D17-003 (.2) and the Dealing assistant to CAP-D17-004 (.1). Order drafting is new open point C8. All of this matches BA-001:419–420, MASTER_BUILD_PROMPT.md:495–496 and PRD-000:428.
- **Finding 2, fixed.** Internal limits now cite CAP-D08-002 in FR-D03-016 and in WF-031.
- **Finding 3, fixed.** I checked each item of C3 (a)–(g) against DDL-000 lines 597–617, and each one is accurate.
- **Finding 4, fixed.** BRL-D05-005 now matches `decision_id NOT NULL`, and AC-US-D03-005-1 is rewritten with a pointer to PRD-005.
- **Finding 5, fixed.** FR-D04-009 and US-D04-005 are back to S / O, with PRD-004 C7 and owner question Q22 in LOOP_STATE. Both match PRD-000:329 and :1327.
- **Finding 6, fixed.** The Head of Dealing is marked † with a reason and carried as C7. The claim about BA-005 matches BA-005:155.
- **Finding 7, fixed.** The story mapping now shows 001–005 as re-keyed and 006–008 as new.
- **Finding 8, fixed.** FR-D04-007 is tagged (changed) and says how the optimiser gets its limit constraints.
- **Finding 9, fixed.** I rebuilt the BA-004 §5.1 coverage table by script from every card's Capabilities row (BA-004 plus PRD-002, -003 and -004). All 17 domain rows match. The rows also now include WF-029 and WF-030 (Step 6 cards), which is correct.
- **Finding 10, fixed.** The fill targets are handed to PRD-006 in PRD-005 §2 and in the LOOP_STATE Step 8 list.
- **Finding 11, fixed.** The SoD criterion now tests defence in depth, which is consistent with PRD-001 FR-D01-018 ("re-checked at the moment of every action").
- **Finding 12, fixed.** It now says where each check runs and which approvals the override uses; that new text raised finding 1 above.
- **Findings 14–17, fixed.** The WARN note, the active-weight condition, the "5 s from approval" rule and the glosses for business readers are all added.

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | Run on HEAD 2287228: "37 spec documents checked; 0 problem(s)." (exit 0) |
| pytest tests/governance | Run: 14 passed. Matches the commit message's claim. |
| Arithmetic re-computed | Recomputed with `decimal.Decimal`: US-D05-009 600 + 500 = 1,100 > 1,000, correct. ID counts match LOOP_STATE: PRD-003 18 FR / 8 BRL / 8 US / 5 BR; PRD-004 19 / 7 / 11 / 4; PRD-005 19 / 8 / 10 / 4. No NFR ID is defined twice across PRD-001…005. No other derived numbers changed. |
| Sources | No external sources. New claims checked against repository text: PRD-000:298, :327, :329, :389, :414, :428, :430, :1327, :1408, :1477–1478; BA-001:155, :190, :202, :231–232, :323, :418–420, :462; BA-004:155, :1046; BA-005:55, :155, :206, :226; DDL-000:458–470, :510–524, :592–636. All match. No new [REG] facts or provider interfaces. |
| Scope vs GOV-006 step | Matches Step 7 (PRD-003, PRD-004, PRD-005). The GOV-001 §7 register, the GOV-006 Step 7 cell ("in review"), the BA-004 register (WF-031, WF-032) and the README are updated. Front matter is complete, status is Draft, and IDs match file names. |
| BA-004 §5.1 coverage | Rebuilt by script from all workflow cards; no differences from the table. |
| Instruction injection | None found in the diff or the commit messages. |

### Not checked
- CI status: the branch is not pushed, so there is no CI run.
- LOOP_STATE chain row 10 (`wp2-step05b-owner-answers`) changed from "see push" to "pass" and "merged 104bde6". The merge commit exists on origin/main. I could not verify the CI result.
- DDL-000 and DBT-000 were not run on PostgreSQL. No database file changed; the DDL was only read.
- `scripts/merge_gate.py` was not run, as instructed.
- PRD-000 Appendix A (source of the 10 Jul 2026 intraday-borrowing circular) was not opened. The claim is carried unchanged with [REG — VAL conditions].
- The commit trailer (`Co-Authored-By: Claude <noreply@anthropic.com>`) was not judged; earlier rounds left it open as a Nit.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
