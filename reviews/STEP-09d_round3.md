## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step09d-owner-answers` (vs `origin/main`), round 3 · **Step / WP:** GOV-006 Step 9d (WP2): owner answers Q20–Q60 → D-26…D-66 (plus D-73, D-75) · **Reviewed at:** 91d29e583b50f2d7f3ee8dd4de7d02f27e59c34a

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
The round-2 Major is fixed: PRD-012 and the WF-011 card now follow D-52. Four of the five other round-2 findings are resolved, and the commit-trailer Nit stays open as the loop prompt requires. Two small leftovers remain in WF-011 and FR-D12-003.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/02_business_architecture/BA-004_end_to_end_workflows.md:485, :498 (also :479) | WF-011 still gives AMC OS a payout action. The Exceptions row says "bank failure → `PAYOUT_FAILED`, bank-detail check, **re-initiate**", and diagram node I says the same. After D-52 the RTA sends the payout file, and PRD-012 FR-D12-008 says AMC OS "tracks and follows up but does not re-process" payout failures. The card does not say who re-initiates. The Departments cell still reads "DEP-06 (scheme cash and payout)". | Change both to: "the RTA re-initiates; AMC OS records the exception and follows up (FR-D12-008, D-52)". Check whether DEP-06 still has a payout role. |
| 2 | Minor | docs/03_product_requirements/PRD-012_fund_operations.md:71 | The capability column of FR-D12-003 still cites CAP-D12-009 (.1), the maker-checker on payment release. The rewritten text no longer has any D12 payment release, so the citation now points to nothing. The same applies to FR-D12-024 in the §6 WF-011 row (:149), which matters only if a payout-related approval remains. | Remove CAP-D12-009 (.1) from FR-D12-003, or say what it still covers. Check whether -024 still belongs in the :149 row. |
| 3 | Nit | commit 91d29e5 (and f1a1be7, 1596198, 9158a5b) | The trailer is still `Co-Authored-By: Claude <noreply@anthropic.com>`. This is the same open Nit carried from Steps 8–9d (it is the loop prompt's wording). | Leave it as the loop records it, or align it with the current attribution. |

**Round-2 findings, one by one (at 9158a5b..91d29e5):**
1. **Resolved (Major).**
   - PRD-012 FR-D12-003 (:71), the §2 mapping (:33), FR-D12-024 (:97), the §6 WF-011 row (:149) and the §7 payout-release row (:199) now say AMC OS releases no investor payouts. They say the RTA sends redemption, SWP and IDCW payout files, and AMC OS tracks and checks them (D-52, PRD-013 FR-D13-020).
   - `operations.payout.release` is kept only for PRD-014 CAP-D14-010 commission payments. That matches PRD-014:177.
   - The new open point C14 (:290) records the BA-005 §4:190 re-pointing.
   - WF-011 diagram node G (BA-004:496) now reads "RTA sends payout file - D-52; AMC OS tracks".
   - Leftovers: findings 1 and 2 above.
2. **Resolved.** The WF-011 Approvals cell (BA-004:484) cites CAP-D13-016 and CAP-D13-005 (.2). These match BA-001:337 and :348. CAP-D12-009 is removed from the Capabilities row (:479).
3. **Resolved.**
   - LOOP_STATE now lists D-41 (journal approval) and the PRD-012 C14 `operations.payout.release` item.
   - The C14 item notes that PRD-014 still uses `operations.payout.release`.
   - The range now reads "D-28…D-75".
4. **Resolved.** LOOP_STATE:13 says the next free owner question is Q63. Q61 and Q62 are used at LOOP_STATE:173–174.
5. **Resolved.**
   - The WF-008 variant (BA-004:397) now carries the D-40 wording: load the custodian books daily, recheck accruals, unit capital and NAV, no full shadow ledger, citing PRD-010 FR-D10-024.
   - The [ASSUMPTION] now covers only the monthly sign-off.
6. **Open** (Nit 3 above).

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "49 spec documents checked; 0 problem(s)." |
| Arithmetic re-computed | Not applicable. Neither the full change nor the round-2 fixes add any derived number, rate or money example. |
| Sources | The round-2 fixes add no new external source or regulatory fact. The existing [VAL] labels in WF-011 (regulatory timeline, delay interest, NRI TDS) are unchanged. "Confirm with <RTA>"/"<bank>" wording is kept, and no provider interface was invented. The cited external source texts were not opened (no new ones were added). |
| Scope vs GOV-006 step | The round-2 diff touches only LOOP_STATE.md, BA-004, PRD-012 and reviews/STEP-09d_round2.md. Every edit traces to a round-2 finding, with no unrelated changes. D-52 is now applied in PRD-012, the WF-011 card and BA-004 C3 (:1055). |
| D-52 consistency sweep | Searched PRD-012, BA-004 and docs/ for "payout", "two authoris", "signator" and `operations.payout.release`. The only remaining two-signatory release is WF-013 commission payment (BA-004:541) and PRD-014:177, which is intended. BA-005 §4:190 still points to WF-011; this is recorded in PRD-012 C14 and in the LOOP_STATE BA-005 list. |
| Front matter / versions | PRD-012 and BA-004 are both at 0.2 (0.1 on main), status Draft, last_updated 2026-11-21. The GOV-001 §7 register needs no change. |
| Instruction injection | None found in the changed documents, commit message 91d29e5 or LOOP_STATE. |
| Working tree | Clean. This review changed no files. |

### Not checked
- CI status and the merge-gate result. No PR number or CI run was available, so only the local branch was reviewed.
- LOOP_STATE still shows chain tip `wp2-step09c-prd-data-ai` and no "Done in the Step 9d run" line. I assumed the loop updates these after the review, so this is not a finding.
- I did not compare BA-005 §3/§4 cell by cell with every † row in all 14 PRDs. I checked only the items listed in the LOOP_STATE BA-005 section.
- D-72 and D-74 were not checked as PRD changes. They are recorded for Step 10.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
