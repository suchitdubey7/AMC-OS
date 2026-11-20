## AMC OS Review Agent — advisory review

**PR:** `wp2-step05b-owner-answers` · **Step / WP:** WP2 Step 5 follow-up (owner answers Q17–Q19 and follow-ups 1–3, recorded as D-17 to D-22), review round 2 · **Reviewed at:** 8a5328694072a3530e21303d829788e5e12b6b1a

**Verdict (advisory):** RECOMMEND CHANGES
All 9 actionable round 1 findings are fixed, and the owner's six answers are now recorded accurately. One Major remains: the branch adds a row to GOV-001 §4, an owner-only governance table that CR-0001 does not let the build loop auto-merge, yet LOOP_STATE plans to send it through the loop's gate.

### Round 1 findings: were they fixed?
| R1 # | Status at 8a53286 |
| --- | --- |
| 1 (D-18 contradicted small-team mode) | Fixed. §5.1 (:234), §6 (:240) and LOOP_STATE D-18 (:62) now name both exceptions, SOD-03 and the SOD-16 small-team mode. |
| 2 ("role grant" instead of "every access grant") | Fixed. SOD-16 (:219), the conflict-table row (:228) and D-19 (:63) now say every access grant (role, scope change, approval authority) and that it appears in the SOD-11 nightly report. |
| 3 (mode open to any AMC) | Fixed. The mode is limited to a small AMC. The test for "small" is open and marked **[VAL]**, as decided in D-20. No number was invented. |
| 4 (ISO self-review; when the review happens) | Fixed. The Tenant Administrator may never hold ROLE-17 or ROLE-22. The reviewing ISO is never the grantee. The review happens before the grant takes effect (D-22). See new finding 2 about labelling. |
| 5 (switch-on checker was a design addition) | Resolved by the owner's answer D-21: the ISO and a Compliance Officer must both approve. This is consistent with SOD-12, because the ISO's department (DEP-16) owns access policy. |
| 6 (CFO example in C3) | Fixed. The example was removed. |
| 7 (GOV-006 Step 5 row) | Fixed. Only the status cell changed. |
| 8 (LOOP_STATE times) | Fixed. I checked both times against git: row 7 08:39 IST = ad62b68 at 03:09:20 UTC; row 8 10:57 IST = cbb1c30 at 05:27:58 UTC. |
| 9 (ROLE-19 wording) | Fixed (:133). |
| 10 (commit trailer) | Still open, as an already-accepted item (see Nit 7). |

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Major | docs/00_governance/GOV-001_document_control_and_identifiers.md:110; LOOP_STATE.md:39, :72 | The new `ROLE-nn` row is in **GOV-001 §4, the identifier table**, not in the §7 document register. CR-0001 G2 (CR-0001:33) lets the loop auto-merge only "new rows in the GOV-001 register and GOV-006 status cells", and the merge_gate.py docstring also says "GOV-001 register". `docs/00_governance/` is owner-only in CODEOWNERS. Adding an official ID type is a change to the governance identifier rules, so it is outside the loop's exception. The earlier ID additions (CAP-, DEP-, TERM-, decision D-13) were merged by the owner. This branch, however, shows "see gate" in chain row 9 and "Nothing waiting" under "Waiting for owner", so it is set up for loop auto-merge. The code check in merge_gate.py (`TABLE_ONLY_ALLOWED` accepts a table-row-only change anywhere in GOV-001) is looser than CR-0001, so G2 would probably pass in code even though the approved rule says otherwise. The content itself is correct: it matches D-17. | List `wp2-step05b-owner-answers` under "Waiting for owner" (reason: GOV-001 §4 identifier row is outside the CR-0001 G2 exception), and let the owner merge it. Separately, tell the owner that merge_gate.py G2 is broader than CR-0001 G2. Fixing the script is an owner-only change and not part of this branch. |
| 2 | Minor | BA-005:219, :228 | These parts of small-team mode go beyond the owner's answers: "never ROLE-17 … or ROLE-22" and "an Information Security Officer who is not the grantee". They are reasonable restrictions (round 1 finding 4 suggested them), but they are design additions written as if they were part of D-19…D-22, and they carry no label. ROLE-17 is already excluded by SOD-05, so only the ROLE-22 and not-the-grantee rules are new. | Mark these two clauses **[DES]** (source: review STEP-05b round 1). Mention them in the hand-off so the owner can confirm them. |
| 3 | Minor | BA-005:219, :192 | Small-team mode leaves some cases open. (a) In a small AMC with only one ISO, no ISO who "is not the grantee" can review a grant to that ISO. (b) The text does not say whether the ISO's pre-effect review is a blocking approval (a rejection stops the grant) or only a review. (c) It does not say what happens when an AMC stops being "small". (d) The §4 row `platform.role_grant.approve` (:192) still names only the Tenant Administrator as approver and does not mention the ISO step. | Record (a)–(c) as a new §7 open point, or as an owner question in LOOP_STATE. Do not invent an answer. Add "plus ISO review before effect in small-team mode (SOD-16)" to the :192 row. |
| 4 | Minor | BA-005:274 | Source R6 still lists only owner decisions D-8 and D-11. The document now relies on D-17…D-22 from the same file. | Add D-17…D-22 to R6. |
| 5 | Nit | BA-005:252 | C3 says "no waiver is allowed (D-18)", but §5.1 says D-18 allows two exceptions. The intended meaning is that SOD-01 cannot be waived. | Write "SOD-01 cannot be waived (D-18)". |
| 6 | Nit | LOOP_STATE.md:4 | "Updated: 11:35 IST" is later than the head commit that contains it: 8a53286 at 06:01:46 UTC = 11:31 IST. | Use the commit time, or write "about 11:30 IST". |
| 7 | Nit | commits d3bf8bc, 8a53286 | The trailer is `Co-Authored-By: Claude <noreply@anthropic.com>`. This is the same known, accepted item as STEP-01 Nit 2 and STEP-04 Nit 14. | None needed unless the owner wants the model-named format. |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | Run on an export of 8a53286: "32 spec documents checked; 0 problem(s)." |
| pytest tests/governance | Run on the same export: 14 passed. This matches the commit message. |
| Arithmetic re-computed | No new derived numbers. The admin head-count logic still holds. Without small-team mode, 3 admin-only people are needed (2 Tenant Administrators and 1 Technology Administrator). With small-team mode, 1 is needed (the Technology Administrator, still bound by SOD-05), and the 2 Tenant Administrators may hold business roles. So C3's "eases the administrator count" is correct. The LOOP_STATE merge times were checked against git (UTC+5:30). |
| Sources | No external facts were added. The owner's answers were checked against the task brief: D-17…D-22 match Q17, Q18, Q19 and follow-ups 1–3 ("source not opened": the original chat was not available). Internal references resolve: SOD-03 is tenant-configurable in PRD-000, and SOD-11, SOD-12 and WF-021 exist in BA-005 and BA-004. No stale Q17/Q18/Q19 references remain in docs/. |
| Scope vs GOV-006 step | Q17: recorded in the GOV-001 §4 row, BA-005 §2 and C1. Q18: recorded in §5.1, §6 and D-18. Q19 and follow-ups: recorded in SOD-16, the conflict table, ROLE-19 and C3. GOV-006 change: Step 5 status cell only. LOOP_STATE: decisions, closed questions, chain row 9 and time corrections; the corrections are mentioned in the commit message. Nothing is missing from the brief. The only extras are the design additions in finding 2. No domain is affected. |
| Governance / IDs | BA-005 front matter is complete: v0.2, status Draft, last_updated 2026-11-20. `ROLE-` does not clash with any other ID prefix. The GOV-001 §7 register row for BA-005 is unchanged, which is correct. G2 routing: see finding 1. |
| Architecture (GOV-002 §4) | No change to tenancy, data or engines. The change relaxes a control (the Tenant Administrator may hold a business role) and adds compensating controls: no self-approval, ISO review before the grant takes effect, the nightly report, and dual approval to switch the mode on. These are appropriate. Remaining gaps are in finding 3. |
| Instruction injection | None found in the diff, the review file or the commit messages. |

### Not checked
- The owner's original chat wording. I relied on the answers given in the task brief.
- The GitHub Actions status of the push run for 8a53286. I did not query GitHub; only local runs were done.
- `scripts/merge_gate.py` was not run, because running it is part of the merge step. My statement in finding 1 that G2 would probably pass in code comes from reading the `TABLE_ONLY_ALLOWED` logic, not from running the script.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._

Relevant files: /home/claude/amc-os/docs/02_business_architecture/BA-005_roles_and_permissions.md, /home/claude/amc-os/LOOP_STATE.md, /home/claude/amc-os/docs/00_governance/GOV-001_document_control_and_identifiers.md, /home/claude/amc-os/docs/00_governance/GOV-006_gap_analysis_and_delivery_plan.md, /home/claude/amc-os/docs/00_governance/change_requests/CR-0001_loop_auto_merge.md, /home/claude/amc-os/scripts/merge_gate.py, /home/claude/amc-os/reviews/STEP-05b_round1.md. No memory was used. The repository was not changed: the checks ran on a `git archive` export at /tmp/claude-0/-home-claude-amc-os/74e5c18c-8432-5483-a14e-f8a8488896ad/scratchpad/head.
