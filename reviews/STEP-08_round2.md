## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step08-prd-trading-settlement-compliance-risk` (diff vs `main` 5666600), round 2 · **Step / WP:** GOV-006 Step 8 / WP2 · **Reviewed at:** 2100d7c3ddf56d152ce24ebce5c69a4c35770488

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
All 5 Majors and 9 Minors from round 1 are fixed, and round 1 Nit 15 is fixed too. Nit 16 (the commit trailer) is left, as accepted in earlier steps. This round found only Minor and Nit problems.

### Round 1 findings: status
| R1 # | Status |
| --- | --- |
| 1 (FR-05-11 non-broker counterparties) | Fixed. The same [DES] proposal is in PRD-006 §2 and C15 and in PRD-007 §2 and C9. See new finding 5 for the capability it cites. |
| 2 (duplicate-fill DDL wording) | Fixed. PRD-006:66, :183, :196 now quote DDL-000:715 correctly, and the gap is open point C16 for DA-001/DDL. |
| 3 (net settlement vs SEBI circular) | Fixed. I checked FR-D07-005, FR-D07-008, C1 and S3 against the cached circular text. Every paragraph cited (3, 4, 5, 6, 7.1–7.3, 8.2–8.3, 9.1, 10.1–10.3, 10.4, 11.2, 13.2, 14) says what the PRD claims. AC-US-D07-006-1 now uses different securities, and AC-US-D07-006-2 reproduces the Annexure. |
| 4 (owner questions not logged) | Fixed. Q22–Q33 are now in the LOOP_STATE.md Q-list, and each open point points to the right Q number (I checked all 12). The commit message no longer makes the false claim. |
| 5 (no legal review) | Fixed. FR-D08-017 and the WF-034 card, flowchart (node LR) and §7 now include legal review, with open point C9 and Q29. See new finding 4 for a gap in where it sits. |
| 6 (FR-D08-004 label) | Fixed in the requirement row. See new finding 2 for §2 and §4. |
| 7 (PRD-009 re-keying notes) | Fixed. §2 says "Wording extended [DES]" and lists the additions, and the new-ID range is US-D09-004…009. |
| 8 (30-minute criterion) | Fixed. AC-US-D09-001-1 now has the 30-minute condition and says that showing stale is not a pass. |
| 9 (NFR-PERF-007 skipped) | Fixed. PRD-007 now uses NFR-PERF-007 and -008, and -009 is recorded as never to be used. See new finding 1. |
| 10 (secondary sources) | Fixed. PRD-007 S2 and S4 and PRD-008 R7, R8 and R10 are labelled secondary, and S1 says "text not read". |
| 11 (CRO vs Risk officer) | Fixed. PRD-008 now says "Risk officer (CRO)" everywhere. |
| 12 (BA-004 §5.1 rows) | Fixed. The D04, D11, D12, D16 and D17 rows are updated. |
| 13 (WF-024 change) | Fixed. It is marked "(changed from WF-024)" and recorded as open point C17. |
| 14 (approval status field) | Fixed (FR-D08-001). |
| 15 (BA-004 C8) | Fixed. |
| 16 (commit trailer) | Left, as accepted in earlier steps. |

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/03_product_requirements/PRD-007_settlement_management.md:44 | The re-keying row for "Module 05 point 17 NFRs" reads "NFR-PERF-007, NFR-PERF-007". The second ID should be NFR-PERF-008 (§11, :212–213). | Change it to "NFR-PERF-007, NFR-PERF-008". |
| 2 | Minor | PRD-008:31, :52; PRD-009:52 | PRD-008 §2 says only FR-06-01 and FR-06-12 are **(changed)**, but FR-D08-004 (:61) is now also marked changed. In both PRDs, §4 still says "Labels from PRD-000 are carried unchanged" with no exception. That is untrue for FR-D08-004 and for FR-D09-009, which gains an added **[IND]**. PRD-006 and PRD-007 already use the wording "unless the change is stated". | Add FR-06-04 to the PRD-008 §2 note. In PRD-008 and PRD-009 §4, use PRD-007's wording: "carried unchanged unless the change is stated". |
| 3 | Minor | PRD-007:71 (FR-D07-005) | The circular conditions are carried over well, but para 7.4 is left out. It says netting must not affect scheme-wise accounting, NAV computation, asset allocation, investment limits or unit-holder interest. This condition affects D10, D11 and D08, which consume D07's events. BRL-D07-006 covers traceability only. | Add (f) to FR-D07-005: netting does not change scheme-wise accounting, NAV, asset allocation or limit checks (para 7.4) **[REG]**. Optionally also cite para 8.1 (residual funded by the scheme) and para 9.2 (STT and stamp duty stay on delivery basis). |
| 4 | Minor | PRD-008:180–182 (WF-034 flowchart), :171, :204 | 1) Legal review sits only on the "rule change needed = yes" branch. The decision that a new circular needs **no** rule change is also an interpretation, and it skips legal review. 2) §7 (:204) says a "no change" closure is checked by a second Compliance Officer, but the card and the flowchart (node E) do not show that check. 3) In the flowchart, every trigger passes through node LR, including house-limit, mandate and risk-limit requests. The card limits the review to regulations and circulars. | Move the legal review before decision D for regulatory triggers, or route the "no change" path through it as well. Show the second-Compliance-Officer check on node E. Label node LR "regulatory triggers only". |
| 5 | Minor | PRD-006:34, :236 (C15); PRD-007:38, :234 (C9) vs BA-001:235 | The non-broker counterparty proposal says counterparty exposure limits are "enforced as D08 rules (CAP-D08-005)". In BA-001, CAP-D08-005 Exposure limits covers only sector, rating, liquidity and derivative limits, and no D08 capability names counterparty limits. The proposal therefore cites a capability that does not cover it. | Say that no D08 capability covers counterparty limits yet, and add this to C15/C9 for the next BA-001 revision (for example a CAP-D08-005 (.5)). Or cite the closest capability and record the gap. |
| 6 | Nit | LOOP_STATE.md:36–48 | **Chain tip** is set to the Step 8 branch, but the chain table has no row 12 for it. In Step 7 that row was added in the final fix round, so this may be intended. | Add the Step 8 row (verdict, CI, merged) when the final round's result is recorded. |
| 7 | Nit | Commit 2100d7c trailer | `Co-Authored-By: Claude` rather than a trailer naming the model. This was accepted in earlier steps. | Leave it, as before. |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | Run by me at 2100d7c: "41 spec documents checked; 0 problem(s)". `pytest -q tests/governance`: 14 passed (run by me). These match the commit's claim. |
| scripts/merge_gate.py (dry run) | Not run: the permission system refused the command in this session. |
| Arithmetic re-computed | Python `Decimal`. AC-US-D07-006-2 (Annexure): gross pay-in 2,000 and pay-out 4,000; A and C outright; net A−C gives pay-out 1,000; plus B gross (pay-in 1,000, pay-out 2,000); total pay-in 1,000 and pay-out 3,000 ✓ (matches PRD and circular). AC-US-D07-006-1: 10 − 7 = 3 ✓ (now different securities, so valid). Allocation 1,000 × 50/30/20 % = 500/300/200 ✓. 99 % of 1,000 = 990 ✓. 100 × 50 = 5,000 ✓. |
| Sources | **Opened:** SEBI circular HO/24/13/(1)2026-IMD-POD-2/I/25242/2026 from the cached text (untrusted scratch copy). Its number, date (5 Nov 2026), title, start date (1 Apr 2027, para 14) and all paragraphs cited in PRD-007 match. **Not opened this round:** the S3 PDF URL itself, PRD-007 S1, S2 and S4, PRD-008 R7–R10, PRD-009 S1–S6 (round 1 opened R7, R8, PRD-009 S3 and S5). Their labels (primary/secondary, "text not read") are now stated correctly. |
| Scope vs GOV-006 step | Unchanged from round 1: all four PRDs are present and cover D06–D09. The FR-05-11 gap is now closed by a recorded [DES] proposal. WF-033 and WF-034 are registered. The GOV-001 register, GOV-006 Step 8 status ("in review"), BA-004 §2, §5.1 and §5.2, PRD-005 C4, C5, C6 and C9, and LOOP_STATE (Q22–Q33, next free IDs, Step 9 carry-over) are updated. Nothing found outside the step's scope. |
| IDs and numbering | No duplicate NFR IDs across docs/: NFR-PERF-007/008 are in PRD-007, 010/011 in PRD-008, 012/013 in PRD-009, and 009 appears only as "not used". NFR-AUD-006…009 and NFR-RET-003 are each in one PRD. Q22–Q33 are new and in sequence. Front matter is unchanged and correct (Draft, IDs match file names). |
| Architecture (GOV-002 §4) | No cross-domain writes proposed. Net settlement keeps the gross record and traceability (BRL-D07-006). AI is draft-only (ADR-0008, SOD-10). No hard-coded thresholds. No DB or code changes. |
| Instruction injection | None in the changed files, the commit messages or the cached circular text. |

### Not checked
- CI: the branch is not on `origin` (`git ls-remote` shows no step08 ref), so there is no CI result.
- `scripts/merge_gate.py` dry run: the permission system blocked the command in this session, so gates G1–G6 were not re-checked this round.
- Whether the cached circular text is a faithful copy of the SEBI PDF at the S3 URL: I did not fetch the PDF again, and I treated the cache as untrusted data.
- Whether `reviews/STEP-08_round1.md` is byte-identical to the round 1 reviewer output: I have no independent copy, but its content matches the round 1 findings that were fixed.
- Clause-level content of the 2026 MF Regulations, the 20 Mar 2026 Master Circular, the T+0 circulars and the AMFI stress-testing guidelines: not opened. The PRDs keep these **[VAL]** or "text not read".

Files referenced: /home/claude/amc-os/docs/03_product_requirements/PRD-006_trading_and_execution.md, /home/claude/amc-os/docs/03_product_requirements/PRD-007_settlement_management.md, /home/claude/amc-os/docs/03_product_requirements/PRD-008_compliance_management.md, /home/claude/amc-os/docs/03_product_requirements/PRD-009_risk_management.md, /home/claude/amc-os/docs/02_business_architecture/BA-001_business_capability_map.md (line 235), /home/claude/amc-os/LOOP_STATE.md, /home/claude/amc-os/reviews/STEP-08_round1.md, /home/claude/amc-os/database/ddl/DDL-000_core_schema_v0.9.sql (line 715). Cached circular (scratch, untrusted): /tmp/claude-0/-home-claude-amc-os/cb4bfca9-f4d6-56e4-97c6-fcde3c5d6d2c/scratchpad/dl/s3full.txt

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
