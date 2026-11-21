## AMC OS Review Agent — advisory review

**PR:** `wp2-step05-roles-permissions` (local branch, not pushed) · **Step / WP:** GOV-006 Step 5 / WP2 (BA-005) · **Reviewed at:** d228aface0f7e043e186ee255069117951e5eba0 (base origin/main ad62b68)

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
All 14 round 1 findings (4 Major, 7 Minor, 3 Nit) are fixed. The matrix still matches PRD-000 for every cell without a †. The new problems are all Minor or Nit: small inconsistencies, plus one design consequence the owner should be asked about directly.

### Round 1 findings: were they fixed?
| R1 # | Status | Evidence |
| --- | --- | --- |
| 1 (Major) self-approval of grants | Fixed | New SOD-16 (BA-005:218). It also appears in ROLE-19 (:132), `platform.role_grant.approve` (:191) and the conflict table (:227). |
| 2 (Major) SOD-05 range | Fixed | Conflict table now lists ROLE-01…16, 18, 19, 21…25 and gives the reason for the extension (:226). |
| 3 (Major) AI agent vs ADR-0008 | Fixed | ROLE-26 may now create proposals and drafts and is never allowed A/O/post/publish/execute (:139). Checked against ADR-0008 decision 3 and the PRD-000 §9.3 tool list (`propose_orders`, `propose_match`, `propose_register_entry`, `propose_rule_change`, `draft_reply`). |
| 4 (Major) D06 copied from OMS | Fixed | Fund Manager D06 is now "R own", CIO "R", Compliance Officer "R". All are marked † with reasons (:96, :99, :102, :119-121). |
| 5 Q17/Q18 missing | Fixed | Both are in the LOOP_STATE "Questions for owner" list (LOOP_STATE.md:68-69). |
| 6 "same order" claim | Fixed | The order claim now covers only ROLE-01…18 (:44). |
| 7 D16 † missing | Fixed | Added († count 23 = 18 D16 cells + 5 D06 cells). |
| 8 BA-001 §7 deviation | Fixed | Stated in C2 (:250). BA-001:475 confirmed. |
| 9 bank-mandate [ASSUMPTION] | Fixed (but see new finding 1) | :162, :177 |
| 10 payout prefix / WF-027 CAP | Fixed | `operations.payout.release` (:189). WF-027 now lists CAP-D07-008 and CAP-D12-009, which matches BA-004:957/961. |
| 11 market-abuse logs | Fixed (but see new finding 2) | New paragraph (:142) and C6 (:254). Wording checked against BA-002:65. |
| 12-14 Nits | Fixed | :98, :170, :136 |

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/02_business_architecture/BA-005_roles_and_permissions.md:162, :177, :189, :190, :209 | The bank-mandate signatory row says the number of signers per payment is **[ASSUMPTION]** and lists WF-011 and WF-013 among its uses. But `operations.payout.release` (WF-011) says "Two authorisers", the commission row says "payment by two signatories", and SOD-07 says two. PRD-000 BR-10-3 (line 725) gives "two authorisers from the bank-mandate list" with an **[IND]** label. So the document says both "the number is open" and "the number is two". | State the default once: "at least two (PRD-000 BR-10-3 **[IND]**); the AMC's bank mandate may require more **[ASSUMPTION]**". Use that wording in :162, :177 and :189. |
| 2 | Minor | BA-005:142 vs :94, :90 | The market-abuse paragraph gives the CEO, and the Compliance Officer with CCO authority, read access to dealing-desk access logs held in the audit log (D01). The matrix still shows CEO D01 "—" and has no † cell for this right. Rule 3 says the matrix shows every change. A reader of the matrix alone misses this right. | Add a † cell (for example CEO D01 "R (dealing-desk access log)†") with a row in the change table, or say in rule 3 that the right is granted outside the matrix. |
| 3 | Minor | BA-005:132, :207, :218, :251; LOOP_STATE.md:69 | SOD-05 and SOD-16 together mean every tenant needs at least three people with no business role: two Tenant Administrators and one Technology Administrator. This new **[DES]** choice weighs heavily on the first target segment, small new AMCs (D-11). C3 mentions the two-Tenant-Administrator need, but owner question Q18 only asks about waivers and the small-accounting-team case. Under AGENTS.md §3 step 4, the owner should approve a material control-design choice. | Extend Q18, or add Q19, to ask about the minimum number of administrators: may a Tenant Administrator hold a business role in a small AMC, and with what compensating control (for example ISO review of every grant)? |
| 4 | Minor | BA-005:132, §7 | PRD-000 US-PLT-01 (line 1318) says "As a Tenant Admin, I want to create users with roles". BA-005 gives ROLE-19 only "R A J" in D01 and makes the Technology Administrator the maker (which matches the PRD-000 matrix and SOD-05). This conflict inside PRD-000 is settled here without being recorded. | Add a C7 to §7: "US-PLT-01 maker role differs from Chapter 6 / SOD-05; BA-005 follows Chapter 6; fix in PRD-001 (Step 6)". |
| 5 | Minor | LOOP_STATE.md:4, :5, :9, :35 | The branch edits LOOP_STATE but leaves it stale. `Updated` is still 08:50. The chain tip is still `wp2-step04-workflows`. "Next action" still says to start Step 5. The Step 4 row still shows "see gate" although Step 4 is merged (ad62b68, and the GOV-006 Step 4 cell says merged). There is no Step 5 chain row. GOV-006 and LOOP_STATE now disagree. | Update the header, the next action and the chain table (Step 4 merged; Step 5 row with the review verdict) in the loop's state update before hand-off. |
| 6 | Nit | BA-005:137 | ROLE-24 Finance Officer has "D07: A J" with no R. A checker of SSI and bank-detail changes must be able to read them. | "D07: R A J". |
| 7 | Nit | BA-005:251, :226 | C3 has two bracketed asides in a row ("(SOD-16 alone needs…) (for example…)"). The conflict table says "Any other role" but the list rightly leaves out ROLE-20, 26 and 27. | Merge the asides. Write "Any other tenant role held by a person (…)". |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "32 spec documents checked; 0 problem(s)." (exit 0) |
| Arithmetic re-computed | No money figures. A fresh script (/tmp/claude-0/-home-claude-amc-os/74e5c18c-8432-5483-a14e-f8a8488896ad/scratchpad/r2/rekey2.py) parsed the PRD-000 Ch 6 matrix and the BA-005 §3 matrix at d228afa. Result: 18/18 roles in the same order; 0 mismatches on cells without a †; 23 † cells (18 D16 + 5 D06), each listed in the change table. Counts checked: 27 roles, 17 domain columns, SOD-01…SOD-16. Every department DEP-01…DEP-18 appears at least once in the role catalogue. |
| Sources | All sources are internal. Checked: PRD-000 §2.3 (line 122), Ch 6 (1355-1393), §9.1/§9.3 (1450-1486), BR-10-3 (725), US-PLT-01 (1318); ADR-0008 decision 3; BA-001 §7 (475) and the CAP IDs used in §4 (CAP-D01-001/002/005/008, D06-001, D07-003/008, D08-001, D10-013, D11-002, D12-009 all exist); BA-002 §2 (65); BA-004 WF-011/013/020/021/026/027/028 approval rows. Permission prefixes all match owning schemas in GOV-001 §3. No new external or regulatory facts are added. The [REG] market-abuse statement keeps its "secondary source" label. |
| Scope vs GOV-006 step | Delivered: re-keyed role catalogue and matrix; SOD-01…SOD-11 carried over; new SOD-12…SOD-16; roles for DEP-10/16/17 (BA-002 §8 C1); Finance Officer checker; answers to the BA-004 open points (§6: WF-020 SoD exception, named heads, WF-021 and WF-023 approvers); capability grouping deviation stated (C2). GOV-001 register row, GOV-006 Step 4/5 cells, README and Q17/Q18 are correct (only table rows changed in GOV-001 and GOV-006). No domain is dropped: D01…D17 all have a column. |
| Front matter / IDs | BA-005 has full front matter, status Draft, and an ID that matches the file name. No ID is reused. ROLE-nn is pending owner question Q17. |
| Instruction injection | None found in the diff, the saved round 1 review or the commit messages. |
| Commit trailers | Both commits carry `Co-Authored-By: Claude <noreply@anthropic.com>`. This follows the loop prompt (already accepted in earlier steps as STEP-01/STEP-04 Nit). |

### Not checked
- CI status: the branch is not on origin (`git branch -r --contains d228afa` returns nothing), so there is no CI run to read.
- `scripts/merge_gate.py` was not run, because it can merge and the reviewer must not merge.
- The scripts that BA-005 §8 says generated the matrix and checked coverage are not in the repository. I re-checked the matrix and department coverage independently (see above).
- I could not confirm that reviews/STEP-05_round1.md was saved unedited, because there is no independent copy to compare against. Its content matches the round 1 findings that the fix commit addresses.
- External regulatory sources behind BA-002 §2 (SEBI circular of 5 Aug 2024, secondary) were not opened. BA-005 only repeats that statement.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
