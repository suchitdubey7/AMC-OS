## AMC OS Review Agent — advisory review

**PR:** local branch `gov-merge-gate-findings-section` vs `origin/main` (round 2) · **Step / WP:** none. This is an owner-requested governance fix (chat, 24 Nov 2026): merge gate G4 plus the LOOP_STATE update · **Reviewed at:** 20ac088624c67a815d13ec12011f294c6c56e30f

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
All 10 round-1 findings are fixed or answered, and the three ways round 1 found for a Major to slip through now fail closed. One narrower gap is left: a Blocker or Major placed before the first `### Findings` heading is still not counted. The verdict check catches it as long as the review follows its own verdict rule.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | scripts/merge_gate.py:102-109 | There is still one way through that the old whole-file scan blocked. Any Blocker or Major row before the first `^### Findings` line is ignored. That includes a round-1 status-table row that is **not** fixed (`\| 1 \| Major \| Not fixed. \|`), and a `## Findings` (level 2) table placed before a later `### Findings`. I checked both with a scratch copy of the logic: the old code counts 1, the new code counts 0. The gate's verdict check (RECOMMEND MERGE or RECOMMEND MERGE AFTER FIXES only) still stops this whenever the reviewer follows the GOV-007 rule "any Major → RECOMMEND CHANGES". So it gets through only when a review contradicts itself, which is the kind of unclear case the gate is meant to fail closed on. This is a design trade-off, not a regression in the normal layout. | Optional hardening: before the Findings heading, fail if a row is Blocker or Major and its last cell does not start with "Fixed". Or state the trade-off in the docstring and add a test showing that a status-table "Not fixed" Major passes only because the verdict check fails it. |
| 2 | Nit | tests/governance/test_merge_gate.py:186-203 | The layout `"### Findings (round 2)\n\| 2 \| Major \|…"` is meant to cover a table at end of file with no final newline. But the test appends `"\n### Checks run…"` after every layout, so that case is never actually tested. The logic does handle it (checked by hand in round 1). | Add one case that writes the layout as the final bytes of the file. |
| 3 | Nit | tests/governance/test_merge_gate.py:207 | `test_rows_in_checks_run_are_ignored` has a misleading name. Checks-run rows **are** scanned (the scope runs to the end of the file); they pass only because they do not start with a number. | Rename it to e.g. `test_checks_run_rows_do_not_count`. |
| 4 | Nit | commits 4c78eb8, 20ac088 | The trailer is `Co-Authored-By: Claude <noreply@anthropic.com>`, the same as round 1 finding 10. | Owner choice. |

### Round 1 findings: status
| R1 # | Status |
| --- | --- |
| 1 (two Findings sections, `###` sub-heading, fenced heading) | Fixed. The scope is now from the first `### Findings` to the end of the file. All three layouts are in the parametrised test and fail (checked). The remaining narrower gap is finding 1 above. |
| 2 (edge-case tests) | Fixed. Seven parametrised layouts: heading suffix, `####` sub-heading, bold severity, indented row, and the three from R1-1. The end-of-file case is not really tested (finding 2). |
| 3 (bold or indented severity) | Fixed. The row regex is now `^\s*\|\s*\d+\s*\|\s*[*_]*\s*(Blocker\|Major)\b`. Both cases are tested. |
| 4 (ADR-0015 reminder) | Fixed. LOOP_STATE.md:191. |
| 5 (Step 16 stacking) | Answered. LOOP_STATE now says stacking is intended, with the gate fix merged first. Step 16 is owner-merged anyway (`/database/`). |
| 6 (missing GATEFIX review file) | Fixed. `reviews/GATEFIX_round1.md` has been added, and row 24 says G4 does not apply. |
| 7 (which gate failed per step) | Fixed. Rows 17, 18 and 20 now name G2, G4 and G2. I checked this: under the old regex, STEP-10_round1 and STEP-13_round2 have 0 Blocker/Major rows, so G4 could not have failed them. Only STEP-11_round2 (3) was affected. |
| 8 (DA-001 §0 says ADR-0020 is "not yet drafted") | Fixed. The LOOP_STATE next action now has Step 16 correct DA-001 §0. |
| 9 (`owner\'s` backslashes) | Fixed. No occurrences are left. |
| 10 (commit trailer) | Unchanged, owner choice (finding 4). |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | PASS: "81 spec documents checked; 0 problem(s)." (branch head) |
| `python3 -m pytest -q tests/governance` | 25 passed in 5.74 s (branch head) |
| Old vs new G4 on every `reviews/*.md` | Only `STEP-11_round2.md` changes: old 3, new 0. Its verdict is RECOMMEND MERGE AFTER FIXES, so the new result is correct. `GATEFIX_round1.md` counts 1 under both, which is correct. |
| G4 edge cases (scratch script) | Old and new both catch: an open Major in a status table placed after Findings. Old catches, new misses: an open Major only in the status table before Findings; `## Findings` before `### Findings` (finding 1). Both miss (not a regression): blockquote rows `> \| 1 \| Major`, ID-prefixed rows `\| F1 \| Major`, and severity in the first column. The new `\b` after the severity also catches `Major (security)`, which the old pattern missed. |
| LOOP_STATE vs round-1 facts | Rows 17–24 and the Waiting-for-owner table match the round-1 verified merge history. ADR-0020 is still recorded as Draft. |
| Arithmetic re-computed | Not applicable (no financial figures). |
| Sources | Not applicable (no market, regulatory or vendor claims). |
| Scope vs GOV-006 step | Not a GOV-006 step. Covers the owner's two requests (G4 fix, LOOP_STATE update) plus the round-1 fixes. Nothing outside that scope. `scripts/` is owner-only (G2), so the owner merges. |

### Not checked
- CI status of this branch: not verified (local branch, not pushed).
- I did not run the full `scripts/merge_gate.py` end to end against this branch. G4 would not apply because there is no `STEP-*` review, and G2 fails by design on `scripts/`.
- I did not open the owner's chat instruction of 24 Nov 2026. I relied on the commit messages and the round-1 review for it.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
