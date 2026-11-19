## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step01b-review-fixes` (base `gov-07-review-agent`) · **Step / WP:** GOV-006 Step 1 fix round 2 (WP2: PS-002, PS-003, PS-004) · **Reviewed at:** `3fed1b714caff81f19ecd068f9daa1f1db98e77a`

**Verdict (advisory):** BLOCK
The documents are now in good shape: all 5 Majors and almost all Minors from round 1 are resolved and no new content finding is above Minor. The block is for one governance rule only. The head commit is a "WIP … draft" commit with no `Co-Authored-By` trailer (AGENTS.md §4) and no completion report (AGENTS.md §5). The fix is to rewrite the commit message.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Blocker | (commit `3fed1b7` message) | The commit message is only "WIP step 1 review fixes (round 2 draft)". (a) It has no `Co-Authored-By` trailer, which AGENTS.md §4 requires on every AI-agent commit. All earlier commits in the chain (05ed179, ee4731a, 7b3f1fd, 6da435a) have one. (b) It has no completion report under AGENTS.md §5 / GOV-003:53, so round-1 finding 17 is still open. No PR exists yet to hold the report. | Amend the commit, or squash it into a final commit, with a proper message, the 12-item completion report (or put the report in the PR description) and the required trailers. |
| 2 | Minor | .github/workflows/ci.yml:3–10 | Round-1 finding 7 is fixed, but not the way LOOP_STATE.md "Next action" says. LOOP_STATE says "run `push` only on `main`, plus `pull_request`". The change instead drops `pull_request`, keeps `push` on `'**'` and adds `workflow_dispatch`. The double run is gone and GOV-008 rule 7 is consistent with this. Two side effects: CI never tests the PR merge result against the base, and PRs from forks get no CI. LOOP_STATE does not record the deviation. | Record the chosen approach and why in LOOP_STATE (or GOV-008), or follow the instruction as written. |
| 3 | Minor | docs/00_governance/GOV-005_work_package_plan.md:14 | The amended sentence reads "starts only after … its documents are Approved (during the documentation phase, see the D-3 note below §1)". That suggests Approval is needed *during* the documentation phase, which is the opposite of D-3 and of line 28. | Reword, e.g. "…are Approved. Exception: during the documentation phase, steps may build on Draft documents (D-3, see below §1)." |
| 4 | Minor | docs/01_product_strategy/PS-002_product_vision.md:67–68 | The new timeline puts pilot go-live at "about 21–25". PS-001:48 (O1) says "All 17 domains live at a pilot AMC by month 24", and PS-001:113 says "months 22–24 pilot and rollout". A month-25 go-live breaks O1, and the clash is not declared. | Note the tension with O1 (or cap at 24), and add it to Q11. |
| 5 | Minor | docs/01_product_strategy/PS-004_benchmark_capability_comparison.md:100 | The [B9] URL (`/dbg-en/media/press-releases/…3711076`) returns HTTP 404. The same release is live at `/dbg-en/media/news-stories/press-releases/…3711076`. Its content was checked there: release date 18 Oct 2023, "completes takeover of SimCorp", 94% acceptance. | Fix the path. |
| 6 | Minor | PS-004:27, :43–44, :54, :96–97 | The cells cited "● [B5]" (Charles River D04, D05/D06) and "● [B6]" (D16), and the quote "an end-to-end data management and warehouse solution", rest on B5 and B6. Both return HTTP 403 to automated fetches, so they were not verified. B5 was already unreachable in round 1. | Keep as is if the owner accepts. Otherwise add a reachable State Street or Charles River page, or mark those cells \*. |
| 7 | Nit | docs/01_product_strategy/PS-003_market_and_customer_analysis.md:119 | S6 is labelled "(May 2026)". The transcript itself is dated 30 April 2026 (May is only the upload folder). | "(30 Apr 2026)". |
| 8 | Nit | PS-003:34 | The row is labelled "share of domestic mutual fund AAUM". The transcript says "domestic mutual fund … market share … from 30.3% to 32.5%" and does not say AAUM. :37 already warns that the bases may differ. | Write "domestic mutual fund market share (basis not stated)". |

Round-1 findings, status on head:
1 resolved (S6 replaced and verified; third QRTA marked [ASSUMPTION] with a confirmer and open question 4) · 2 resolved (every unsourced cell marked \*; §4 labelled with confirmers) · 3 resolved (all 17 domains; D05/D06 merge explained at :58) · 4 resolved by D-3 (GOV-005 updated, see new finding 3; "Builds on Draft" notes added to PS-002/003/004) · 5 resolved (PS-001 §5.2 superseded; differences declared in PS-003:52–55; Q10 raised) · 6 resolved · 7 resolved differently from the instruction (finding 2) · 8 resolved (GOV-008 §2; the branch name conforms) · 9 resolved · 10 resolved · 11 resolved (timeline added and Q11 raised; see finding 4) · 12 resolved (confirmers named; PS-003:75 now [VAL]; "mainly sell side" removed) · 13 resolved · 14 mostly resolved (EUR 3.9 bn now taken from the primary source B2 and verified; B6 changed to a URL that returns 403; B5 still 403; B9 404, see findings 5–6) · 15 resolved (glossaries in PS-002 §8, PS-003 §7, PS-004 §5) · 16 resolved · 17 **not resolved** (finding 1) · 18 resolved (39–98%) · 19 resolved.

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "26 spec documents checked; 0 problem(s)." (exit 0, on the head branch). Front matter of PS-002–004 complete with status Draft; versions bumped to 0.2; GOV-001 §7 register lists PS-002–004 and GOV-005–008; GOV-006 Step 1 status updated. |
| Arithmetic re-computed | Decimal: 68 + 32.5 = 100.5 ("about 100%" ✓); 20/51 = 39.22%, 50/51 = 98.04% ("about 39–98%" ✓); 17,68,000 / 83,38,858 = 21.20% ✓. The timeline was checked against PS-001 (finding 4). |
| Sources | Opened and matching: S5 (IIFL CAMS MD&A FY26: "about 68% market share", "dominated by three QRTAs"); S6 (KFin Q4 FY26 transcript: "from 30.3% to 32.5%"); B2 (DKK 735.0 per share, EUR 3.9 billion); B9 (content at the corrected path). Failed: B9 as cited (404), B5 (403), B6 (403). S1–S4, S7, B1, B3, B4, B7, B8 are unchanged from round 1 (verified then) and were not re-opened. No instruction injection found in the changed files. |
| Scope vs GOV-006 step | Step 1 deliverables complete for all 17 domains. The out-of-scope CI and governance edits (GOV-005, GOV-006, PS-001, LOOP_STATE, ci.yml) were directed by LOOP_STATE / round-1 findings and are declared. Q10 and Q11 were added under GOV-008 rule 6. |

### Not checked
- B5 and B6 content (HTTP 403 to automated fetch).
- Accuracy of the ●/◐/○ ratings marked \* (they are flagged as unverified [ASSUMPTION]s).
- The identity of the third QRTA.
- GitHub CI status for this commit (not read from GitHub; no PR exists).
- Database tests: no DB change in this diff.
- STD-001, QA-001, GOV-004 and the ADRs: not re-read, because no code, DB or architecture change is in scope.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
