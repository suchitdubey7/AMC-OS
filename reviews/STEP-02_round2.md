## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step02-capability-map` (base `gov-cr0001-merge-protocol` b531bc5) · **Step / WP:** GOV-006 §3 Step 2 / WP2 (BA-001), review round 2 · **Reviewed at:** 04c2c602a22aaa83faf03725c0b06cc1d7c9cf1b

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
All 10 round-1 findings are fixed and the counts, IDs and labels check out again. The only new problems are two small traceability errors in the D08 rows and one small wording mismatch in LOOP_STATE.md.

### Round-1 findings: are they fixed?
| R1 # | Status | Evidence |
| --- | --- | --- |
| 1 (Major) | Fixed | BA-001:204. The "(.2) is new [DES]" text is gone. The Notes column now says "FR-04-10 carries [REG] / [VAL] (fair allocation among schemes)", which matches PRD-000:394. |
| 2 (Major) | Fixed | BA-001:417. CAP-D17-001 now has (.5) for agent evaluation and release gates, and cites FR-15-07 and Ch 9 §9.4. Both exist (PRD-000:933, :1488). |
| 3 (Minor) | Fixed | BA-001:19 was reworded. The PRD-000 requirement it cites now holds the label, and the Notes column repeats the label only where it changes what the capability must do. |
| 4 (Minor) | Fixed | BA-001:221. CAP-D07-006 now cites FR-10-06. A script check finds no FR in PRD-000 left unmapped (FR-01-11 and FR-01-12 are explained at line 139). |
| 5 (Minor) | Fixed | Q12, Q13 and Q14 are now in the "Questions for owner" list in LOOP_STATE.md. |
| 6 (Minor) | Fixed | BA-001:443 now reads "FR-05-07 (trade level) and FR-10-02 (brokerage bills)". |
| 7 (Minor) | Fixed | BA-001:293 now notes the partial input from the Module 09 and Module 02 exceptions. |
| 8 (Minor) | Fixed in the diff | The `.pyc` file is no longer in the change. The root cause is still there: `__pycache__` is tracked and the repo has no `.gitignore`. The commit message says this needs the owner. |
| 9 (Minor) | Fixed | BA-001:19 now says where responsibilities and systems go, and C7 / Q14 (BA-001:465) records the systems gap. |
| 10 (Nit) | Fixed | IDs are now 3 digits (`CAP-Dxx-nnn`). A script finds no 2-digit IDs left. |

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/02_business_architecture/BA-001_business_capability_map.md:241 | CAP-D08-011 "Corrective actions" (corrective action plan and owner, deadline tracking) cites FR-06-11. FR-06-11 is "Exception workflows: temporary exemptions with expiry; overrides with reasons" (PRD-000:517). Corrective actions and the "cure deadline (rebalancing timelines from rules)" are in FR-06-10 (PRD-000:516). As a result, the FR-06-11 content (temporary exemptions with expiry, overrides with reasons) does not appear as a level-3 item anywhere in BA-001. The word "exemption" does not occur in the file, so the traceability chain in §7 would lose it. | Cite FR-06-10 for CAP-D08-011. Add an L3 item for "temporary exemptions with expiry; overrides with reasons" that cites FR-06-11, for example as CAP-D08-011 (.3) or under CAP-D08-009. |
| 2 | Minor | BA-001:240 | CAP-D08-010 says "(.2) detail new" for "active vs passive classification". The requirement it cites, FR-06-10, already asks for exactly this ("active vs passive breach classification", PRD-000:516). So the row understates its v0.9 source. | Remove "(.2) detail new", or say exactly which detail is new. |
| 3 | Nit | LOOP_STATE.md "Next action" vs Q14 row | "Next action" says Step 3 should "consider BA-001 §5 C7 … if the owner agrees". The Q14 row says the working assumption is "Step 3 includes a short systems column". These say slightly different things. | Make both say the same: either the working assumption applies, or it waits for the owner. |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | Run on 04c2c60: "28 spec documents checked; 0 problem(s)." |
| pytest tests/governance | Run: 14 passed. Running it rewrote the tracked `.pyc` file; I restored it with `git checkout`, and the working tree is clean afterwards. |
| scripts/merge_gate.py (`--ci unknown`) | G1, G2, G3 and G5 pass. G2 confirms the GOV-001 and GOV-006 edits are table-row-only. G4 fails only because the latest review file (round 1) says RECOMMEND CHANGES; that is expected until this round-2 review is saved. G6: CI status unknown (see below). |
| Arithmetic re-computed | A Python script compared BA-001 with MASTER_BUILD_PROMPT.md, Domains 1–17. All 209 L2 names match the brief, in order, and the ID sequences have no gaps. Each domain's L2 / with-source / new counts match the §2 overview rows. Totals 209 = 183 + 26 are correct. Every CAP- ID cited in the text exists (no broken references). There are no money figures in the change. |
| Sources | All internal. All 185 FR/BR IDs cited exist in PRD-000 v0.9, and every FR in PRD-000 is cited. FR titles were compared row by row with the capabilities that cite them; they agree except findings 1 and 2. Labels quoted in Notes were checked against PRD-000 and are accurate: FR-01-02, BR-01-4, FR-01-10, FR-02-10, FR-04-10, FR-05-04, FR-05-06, FR-05-09, FR-07-03, FR-07-11, FR-11-16, FR-12-10. No external facts are introduced. |
| Scope vs GOV-006 step | Delivers Step 2: L1–L3 for all 17 domains, with no domain dropped. Nothing from Step 3 or later is delivered; later steps are only pointed to. Front matter is complete, status is Draft, and the ID matches the file name. The GOV-001 §7 register row and the GOV-006 Step 2 status cell are updated. Building on Draft documents is disclosed (BA-001:17) and allowed by D-3. Both commit messages follow the AGENTS.md §5 format. |
| Architecture (GOV-002 §4) | No binding decisions. The shared-capability owners (§4) and the `master` schema owner (C2) are labelled [DES] and sent to EA-003 for confirmation. One owner per capability, no cross-domain writes, and the D17 AI boundary is "read, explain and propose only". No ADR is touched or contradicted. |
| LOOP_STATE chain row 4 "CI pass" claim | Checked: GitHub CI run 44586007267 on b531bc5 has conclusion `success`. |
| Instruction injection | None found in the changed files, the round-1 review file or the commit messages. |

### Not checked
- CI for this branch: `wp2-step02-capability-map` is not on `origin`, so GitHub CI for 04c2c60 could not be read.
- Whether reviews/STEP-02_round1.md is "unedited" reviewer output, as the commit message says: I have no original copy to compare it with. Its content is consistent with a round-1 review of e84b1f4.
- Whether each L3 breakdown is complete from an Indian AMC domain expert's point of view, beyond the PRD-000 cross-check. The L3 items are [DES] proposals and need review by the owner or an expert.
- GOV-002…GOV-005, GOV-007, STD-001, QA-001 and the ADRs were not re-read line by line this round. The change is documentation only, with no code, database or migrations, so check F and the code part of check D did not apply.
- Mermaid diagram rendering was not checked visually.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
