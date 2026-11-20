## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step01b-review-fixes` (base `gov-07-review-agent`) · **Step / WP:** GOV-006 Step 1 fix round 3 (WP2: PS-002, PS-003, PS-004 + governance edits) · **Reviewed at:** `30fa43270a6e836b67efa9805afcaddb19a47ba4`

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
The round-2 Blocker is fixed: the commit now carries the 12-item completion report and a `Co-Authored-By` trailer. Round-2 findings 2–5, 7 and 8 are fixed too. What is left is one carried-over Minor (B5 and B6 still cannot be fetched, which the owner may accept) and three Nits.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/01_product_strategy/PS-004_benchmark_capability_comparison.md:27, :43–44, :54, :96–97 | Carried over from round-2 finding 6. B5 and B6 still return HTTP 403 to an automated fetch (checked again in this round), so the reviewer still cannot verify the "● [B5]" and "● [B6]" cells or the quote "an end-to-end data management and warehouse solution". LOOP_STATE.md and the commit report say the writer opened both pages on 19 Nov 2026. That claim was not verified. | The owner can accept this as recorded in LOOP_STATE. Otherwise add a State Street or Charles River page that loads, or mark those cells \*. |
| 2 | Nit | (commit `30fa432` message, trailer) | The trailer reads `Co-Authored-By: Claude <noreply@anthropic.com>`. That meets AGENTS.md §4. Every earlier commit in the chain (05ed179, ee4731a, 7b3f1fd, 6da435a) names the model (`Claude Opus 5.5`) and adds a `Claude-Session:` line, and this one does neither. | Use the same trailer format as the other commits when you amend. |
| 3 | Nit | docs/01_product_strategy/PS-002_product_vision.md:68 | "A pilot that starts after month 21 cannot finish a 3-month parallel run by then" is too strong. A pilot that starts at the beginning of month 22 finishes its 3 months at the end of month 24. LOOP_STATE Q11 uses the softer and correct wording "can end after month 24". The "about 21–25" range (18+3 = 21, 22+3 = 25) is fine. | Write "may not finish … by month 24", to match Q11. |
| 4 | Nit | (commit `30fa432` message, item 3) | "B6 and new B9 working URLs": B9 now works (200 OK, content matches), but B6 still returns 403 to the reviewer. Item 10 of the same report already says this, so the two items do not agree. | Write "B9 URL corrected; B6 replaced (403 to automated fetch, see item 10)". |

Status on head of the round-2 findings:
- **1 (Blocker):** resolved. The commit message is now the AGENTS.md §5 report, with a trailer. The forward reference to round 3 is expected and was not treated as a finding.
- **2:** resolved. The CI trigger choice and its reason are recorded in LOOP_STATE "Loop notes" and in a comment in ci.yml.
- **3:** resolved. GOV-005:14 now states the D-3 exception clearly.
- **4:** resolved. The month-24 conflict is declared at PS-002:68 and raised in Q11. The PS-001 §9 reference is correct.
- **5:** resolved. The B9 path is corrected and returns 200. The page shows release date Oct 18, 2023, "completes takeover of SimCorp" and 94% acceptance.
- **6:** open, accepted in LOOP_STATE (finding 1 above).
- **7:** resolved. S6 is now dated 30 Apr 2026, which matches the transcript.
- **8:** resolved. The row now reads "(basis not stated)".

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "26 spec documents checked; 0 problem(s)." (exit 0, on the head branch). PS-001, PS-002, PS-003, PS-004, GOV-005 and GOV-006 are at v0.2 with status Draft. The GOV-001 §7 register lists PS-002–004 and GOV-005–008 as Draft. GOV-006 Step 0 and Step 1 statuses are updated. |
| Arithmetic re-computed | Decimal: 68 + 32.5 = 100.5 ("about 100%" ✓). 20/51 = 39.22% and 50/51 = 98.04% ("about 39–98%" ✓). 17,68,000 / 83,38,858 = 21.20% ✓. Timeline: 18+3 = 21 and 22+3 = 25 ✓ (see finding 3 on the wording). |
| Sources | Opened and matching: B9 at the corrected URL (200); S6 PDF (200), where the transcript is dated "April 30, 2026" and says "domestic mutual fund … market share … from 30.3% to 32.5%". B5 and B6 return 403 and were not verified. S1–S5, S7, B1–B4, B7 and B8 did not change in this round and were not opened again (they were verified in earlier rounds). No instruction injection in the changed files or the commit message. |
| Scope vs GOV-006 step | Step 1 deliverables cover all 17 domains (PS-004 §2; D05 and D06 merged, with the reason given). The governance edits (GOV-005, GOV-006, PS-001, LOOP_STATE, ci.yml) were directed by the review findings or LOOP_STATE, and the commit report declares them. Q10 and Q11 are recorded under GOV-008 rule 6. The branch name `wp2-step01b-review-fixes` and the next-step name `wp2-step02-capability-map` follow GOV-008 §2 rule 2. The Draft dependencies are declared under D-3 / GOV-008 rule 3. |
| Cross-references | PS-001 §5.2 now links to PS-003 §3, and no other document refers to the removed PS-001 §5.2 table. PS-001 §1 links to PS-002 §1. The PS-002 references to PS-001 §6, O1, O5 and §9 point to the right sections. GOV-006 §1 matches `main`, which contains WP1 (e5667a7) and Step 0 CI (05ed179). |

### Not checked
- B5 and B6 content: both return HTTP 403 to automated fetches.
- GitHub CI status for any branch. LOOP_STATE says `gov-07-review-agent` CI is "pass", but that was not read from GitHub, and no PR exists.
- The ci.yml push-only trigger with fork pull requests (they would get no CI). This does not matter while the loop pushes branches to the same repository.
- The accuracy of the benchmark ratings marked \* (they are declared [ASSUMPTION]s) and the identity of the third QRTA.
- Database tests: this diff makes no database change.
- STD-001, QA-001, GOV-004 and the ADRs were not re-read, because nothing in this change touches code, the database or the architecture.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
