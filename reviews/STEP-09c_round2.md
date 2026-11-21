## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step09c-prd-data-ai` (not pushed, no PR) · **Step / WP:** GOV-006 Step 9c / WP2 (build loop, GOV-008) · **Reviewed at:** ac211d5b8e7ebdc4fa9648d2782cfdf50f8ded7d

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
The round 1 Major and all 9 Minors and 3 of the 4 Nits are fixed. The fourth Nit, the commit trailer, is left by design. The fixes cause no new problem. Round 2 found only two Minors and one Nit: both are small mismatches between what a document claims and what it does.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/03_product_requirements/PRD-000_master_prd_v0.9.md:7 | The re-keying note is now much more accurate (it fixes round 1 #2), but its list of what is "not yet re-keyed" leaves out the **Chapter 3 common rules C1–C8** (PRD-000:166-175). These are still kept only in PRD-000, and every per-domain PRD cites them from there ("Every requirement also obeys PRD-000 common rules C1–C8": PRD-016:55, PRD-017:55 and earlier PRDs). The note also does not say where Chapters 1 and 2 went. Readers who follow "read those for these parts" could miss that C1–C8 still apply only through PRD-000. | Add "the Chapter 3 common rules C1–C8 (cited by every PRD-0nn)" to the "still the source" list. Name where Chapter 2 is re-keyed (BA-001 / BA-002), or list Chapters 1–2 as source. |
| 2 | Minor | docs/03_product_requirements/PRD-016_enterprise_data_platform.md:78 (FR-D16-013) | This is the same kind of problem as round 1 #3, which was fixed only for FR-D16-012. FR-D16-013 (was FR-D03-002) adds a rule that is not in the source FR-D03-002 (PRD-003:57): "A change to the issuer group or the sponsor-group flag … needs a Compliance Officer as checker (§7 †)". It is not marked **(changed)**, against the PRD's own rule (PRD-016:55). | Mark FR-D16-013 **(changed)** and state that the Compliance Officer checker for issuer-group and sponsor-group-flag changes was added (WF-041, §7 †). |
| 3 | Nit | docs/03_product_requirements/PRD-017_ai_and_decision_intelligence.md:37, :41 | The §2 table classes BRL-D17-007 and BRL-D17-010 as "Kept" from Ch 9 §9.1 (row 37) and also as "New [DES]" in the range "BRL-D17-005 … 012" (row 41). BRL-D17-010 itself cites "PRD-000 §9.1 hard rule 5". The mapping is otherwise correct: hard rule 1 maps to BRL-D17-003, rule 2 to FR-D17-005, rule 3 to BRL-D17-001, rule 4 to BRL-D17-004 and rule 5 to BRL-D17-010. | Write "BRL-D17-005, -006, -008, -009, -011, -012" in the "New" row, or add "(except as above)" as was done for the FR range. |
| 4 | Nit | commit ac211d5 (and 0c20e7e) | The trailer is `Co-Authored-By: Claude <noreply@anthropic.com>`. This is the same open Nit as in earlier steps, left by design because the loop prompt requires it. | None needed unless the owner wants it changed. |

**Round 1 findings, status after this round:**
| R1 # | Status |
| --- | --- |
| 1 Major (US-DAT-01, US-AI-01 not re-keyed) | **Fixed.** US-D16-013 (PRD-016:234) and US-D17-013 (PRD-017:225) match the PRD-000:1351-1352 story text, priority (C / O) and acceptance criterion word for word. US-AI-02 is also re-keyed as US-D17-014 (PRD-017:226, exact wording), with a cross-reference to PRD-008 US-D08-007 and PRD-010 US-D10-011 (both checked; both cite US-AI-02). `git grep` confirms that all 34 Chapter 5 stories (US-PLT-01 … US-AI-02) now appear in at least one per-domain document. |
| 2 Minor (PRD-000 note overclaims) | **Fixed in part.** The note now says 9 of 11 agents and lists the two agents, Ch 7 leftovers, Ch 8, Ch 10 and Appendix A as still sourced in PRD-000. Remaining gap: finding #1 above. |
| 3 Minor (FR-D16-012 not marked changed) | **Fixed** (PRD-016:77). The listed additions (lot and tick size, issuer link, effective dating) are correct against FR-D03-001 (PRD-003:56). The same issue remains on FR-D16-013 (finding #2 above). |
| 4 Minor (BA-001 §5 C4, PRD-003 C3 not updated) | **Fixed.** BA-001:462 and PRD-003:221 are updated (table rows only). |
| 5 Minor (FR-D17-021 label) | **Fixed** (PRD-017:86): [REG] for the circular's existence; whether it still applies, its content and its frequency are [VAL]. This matches the §5 note. |
| 6 Minor (CTO †; ISO in model release) | **Fixed** (PRD-017:199-200, :205). §7 now matches WF-043 (PRD-017:170). |
| 7 Minor (`ai.proposal` columns) | **Fixed** (PRD-017:250). |
| 8 Minor (D05 golden-record rule) | **Fixed** as open point C10 (PRD-016:292). |
| 9 Minor (Q53–Q60 missing from LOOP_STATE) | **Fixed.** Q53–Q60 are added with defaults. Each default matches the PRD text: Q53 matches WF-042 approvals, Q54 matches WF-043 checkers, and Q56 matches PRD-016 C4. |
| 10 Minor (OpenLineage attributed to ADR-0007) | **Fixed** (PRD-016:258). |
| 11 Nit (hard-rule mapping; §9.4 "Kept") | **Fixed** (PRD-017:37, :40). Small leftover: finding #3 above. |
| 12 Nit (intro "each agent") | **Fixed** (PRD-017:15). |
| 13 Nit ("within one minute" unlabelled) | **Fixed** (PRD-017:218, [DES]). |
| 14 Nit (trailer) | Left by design (finding #4). |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | Run on the branch head (ac211d5): "49 spec documents checked; 0 problem(s)." |
| Arithmetic re-computed | The change contains no money arithmetic. Counts checked: PRD-000 Ch 5 has 34 stories, all re-keyed. Ch 9 §9.3 has 11 agents, 9 placed. US-D16-001…013, US-D17-001…014 and FR-D17-001…027 are contiguous. The LOOP_STATE "next free numbers" are correct: the highest IDs in docs/ are NFR-PERF-027, NFR-AUD-017, NFR-RET-007, NFR-SEC-005, NFR-SCAL-004, NFR-PRIV-004, NFR-AVAIL-002, NFR-OBS-002 and WF-043, so the next are -028, -018, -008, -006, -005, -005, -003, -003 and WF-044. Q60 is the highest question used, so Q61 is next. Round 1 counts in LOOP_STATE row 15 (1 Major, 9 Minor, 4 Nits) match reviews/STEP-09c_round1.md. |
| Sources | The external source lists did not change in the fix commit, so the round 1 checks still apply (S1 to S3 were opened 21 Nov 2026 in round 1; I did not re-open them this round). The new FR-D17-021 wording matches the §5 note and S1's "listing page only" scope. |
| Scope vs GOV-006 step | Delivers PRD-016 and PRD-017. The D03 → D16 takeover is done (PRD-003 C3 closed). The `master` schema is proposed (Q59). The brief's Dealing and Risk assistants are added (BA-001 §5 C4, brief part closed). All Ch 5 stories are now re-keyed. "Mark PRD-000 Superseded" is replaced, with a stated reason, by a note plus Q60. This is correct under GOV-001 §1 and merge gate G3, and GOV-006 row 9 records it. BA-004 coverage still lists all 17 domains. The new coverage entries (D01, D03, D06, D08, D14, D15, D16, D17) match the capabilities on the WF-041/042/043 cards. |
| Governance / IDs | Both new PRDs have full front matter, status Draft and an ID matching the file name. The GOV-001 §7 register, GOV-006 row 9, BA-001 C4, BA-004 and PRD-003 C3 edits are table rows or text only. No status was changed and no ID was reused. |
| Architecture (GOV-002 §4) | No change from round 1. AI produces no financial number, ML signals are advisory only, D16 writes only its own schemas, tenant context comes from identity, maker-checker is kept, and financial processing does not depend on AI. No contradiction with ADR-0007 or ADR-0008. |
| Instruction injection | None found in the diff, the review file or the commit messages. |

### Not checked
- CI: the branch has not been pushed (no `origin` ref), so there is no CI run.
- `scripts/merge_gate.py`: I tried to run it read-only for information, but the permission classifier denied the call. Gate results G1–G6 were not verified by me.
- External sources S1 to S3 were not re-opened this round, because they did not change since round 1. The SEBI 2019/63 circular body and the MeitY DPDP Rules text were never opened (the PRDs mark the dependent points [VAL]).
- Database tests (DDL-000 / DBT-000) were not run: this step makes no database change.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
