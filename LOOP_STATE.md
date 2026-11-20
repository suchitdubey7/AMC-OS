# LOOP_STATE — build loop status (GOV-008)

**Status:** RUNNING
**Updated:** 2026-11-20 13:08 IST
**Chain tip:** `wp2-step07-prd-investment-portfolio-oms`

## Next action

**Step 8** on a new branch `wp2-step08-prd-execution-settlement-compliance-risk` from the chain tip: PRD-006 Trading and Execution (D06), PRD-007 Settlement Management (D07), PRD-008 Compliance Management (D08) and PRD-009 Risk Management (D09), GOV-006 §3. Re-key PRD-000 Module 04 execution part (FR-04-09, -10, -11, BR-04-3 second part, BR-04-5 — handed over by PRD-005 §2), Module 05 (split D06 / D07), Module 06 and Module 07; use BA-004 WF-023…WF-028 and WF-018; give D09 its daily risk run workflow (BA-004 §5.1, §5.2 C6) and D08 its rule-change lifecycle; continue NFR numbering (next free: NFR-PERF-009, NFR-AUD-006, NFR-RET-003, NFR-SEC-004; NFR-PERF-003 is skipped) and the WF register (next free: WF-033). Step 8 is large; if needed, the run may split it into 8a (PRD-006, PRD-007) and 8b (PRD-008, PRD-009) and record the split here.

After that: Step 9 in GOV-006 order. The repository is still public until the owner switches it (D-6).

Done in the Step 7 run (20 Nov 2026, started on owner request in chat "Go for next run"): PRD-003 Investment Management (18 FRs; WF-031), PRD-004 Portfolio Management (19 FRs; WF-032), PRD-005 Order Management System (19 FRs, order part of Module 04).

Findings left open from Step 7: see the Step 7 row of the chain table and `reviews/STEP-07_round*.md`.

Done in the Step 5 run (20 Nov 2026, started early on owner request in chat): BA-005 roles, permissions and SoD; 2 review rounds. Owner answered Q17–Q19 and six follow-ups in chat the same morning (D-17 to D-25), applied on branch `wp2-step05b-owner-answers`, which also updates PRD-001 to match.

Done in the Step 6 run (20 Nov 2026, scheduled, in parallel): PRD-001 Platform Administration (48 FRs, new) and PRD-002 Product and Scheme Management (FR-01-nn re-keyed + 12 new FRs, WF-029, WF-030); closes BA-005 §7 C7. It ran before the owner's answers D-17…D-25 reached main; PRD-001 was brought in line on `wp2-step05b-owner-answers`.

Findings left open from Step 6: see the Step 6 row of the chain table and the review files `reviews/STEP-06_round*.md`. Round 1 Nit 16 (commit trailer `Co-Authored-By: Claude`, as the loop prompt requires) is left as in earlier steps.

Findings left open from Step 5: none (all round 1 and round 2 findings fixed).

Findings left open from Step 4: STEP-04 round 1 Nit 14 — commit trailer is `Co-Authored-By: Claude` as the loop prompt requires (same as STEP-01 Nit 2). BA-004 §5.2 C8 (QA-001 still says WF-001…WF-017) and C9 (BA-003 TERM-078 SSI wording) wait for the next revision of those documents.

Finding left open from Step 3: STEP-03 round 1 Nit 14 — GOV-001 `last_updated` and the register heading "as of 19 Nov 2026" were not changed, because only table rows of GOV-001 may change on a loop branch (merge gate G2); owner may update the dates.

Findings left open from Step 1 (no fix needed unless the owner wants it): STEP-01 round 3 Nit 2 — commit trailer follows the loop prompt (`Co-Authored-By: Claude`) rather than the older model-named format. STEP-01 round 3 finding 1 (was round 2 finding 6) — State Street pages B5 and B6 block automated fetches for the reviewer (HTTP 403); the writer opened both on 19 Nov 2026 and the cited wording matched.

## Loop notes

- **CI trigger (review STEP-01 finding 7):** `ci.yml` runs on `push` to every branch (plus manual `workflow_dispatch`), not on `pull_request`. Reason: the loop pushes branches without opening pull requests and reads the push run to decide whether the chain tip is green (GOV-008 rule 7 and stop conditions); a `pull_request` trigger on top would run the same checks twice. This replaces the earlier plan ("push only on `main`, plus `pull_request`"), which would have left loop branches with no CI. Trade-off: CI does not test the merge result against `main`; acceptable while branches are merged in order.

## Chain (merge in this order)

| # | Branch | Content | Review verdict | CI | Merged |
| --- | --- | --- | --- | --- | --- |
| 1 | `step-01-vision-market` | Step 1: PS-002, PS-003, PS-004 | RECOMMEND CHANGES (0 Blocker, 5 Major, 12 Minor, 2 Nit) | pass | yes (23:28, on owner instruction) |
| 2 | `gov-07-review-agent` | GOV-007 reviewer, GOV-008 loop, this file | not yet reviewed | pass | yes (23:28, on owner instruction) |
| 3 | `wp2-step01b-review-fixes` | Step 1 review fixes (PS-001–004, GOV-005, GOV-006, CI trigger) | Round 3: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 1 Minor accepted, 3 Nits — 2 fixed) | pending | yes (20 Nov 07:15, on owner instruction) |
| 4 | `gov-cr0001-merge-protocol` | CR-0001 merge gate, CODEOWNERS, secret scanning, reviewer self-test (7/7) | owner work, self-tested | pass | yes (20 Nov 07:15, on owner instruction) |
| 5 | `wp2-step02-capability-map` | Step 2: BA-001 business capability map (17 domains, 209 L2 capabilities, L3 breakdown) | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 2 Minor, 1 Nit — all fixed) | pass | yes (20 Nov 07:15, on owner instruction) |
| 6 | `wp2-step03-operating-model` | Step 3: BA-002 operating model and department hierarchy (19 departments, owner of all 209 capabilities, systems stance per domain); BA-003 domain dictionary (96 terms) | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits — 13 fixed, 1 left) | pass | yes (20 Nov 07:15, on owner instruction) |
| 7 | `wp2-step04-workflows` | Step 4: BA-004 end-to-end workflows WF-001…WF-028 (17 re-keyed, W6b → WF-018, 10 new for D01/D06/D07); D-12 pilot timing in PS-001/PS-002 | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits — 13 fixed, 1 left) | pass | yes (20 Nov 08:39 IST, build loop, CR-0001 gate PASS) |
| 8 | `wp2-step05-roles-permissions` | Step 5: BA-005 roles (27), re-keyed permission matrix (17 domains), approval authorities, SOD-01…SOD-16 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 2 Nits — all fixed; round 1 had 4 Major, all fixed) | pass | yes (20 Nov 10:57 IST, build loop, CR-0001 gate PASS) |
| 9 | `wp2-step06-prd-platform-product` | Step 6: PRD-001 Platform Administration (D01), PRD-002 Product and Scheme Management (D02); WF-029, WF-030 added to BA-004 register | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 6 Minor, 3 Nits — 8 fixed, Nit 9 (commit trailer) left; round 1 had 2 Major, both fixed) | pass | yes (20 Nov 12:43 IST, build loop, CR-0001 gate PASS) |
| 10 | `wp2-step05b-owner-answers` | Owner answers Q17–Q19 and follow-ups (D-17 to D-25) applied to BA-005, PRD-001, BA-004 WF-020 and GOV-001 §4 | Round 5: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 5 Nits — all fixed except Nit 9 (version bumps, accepted Draft practice) and Nit 10 (trailer)) | pass | yes (20 Nov, by the owner's instruction in chat, merge 104bde6) |
| 11 | `wp2-step07-prd-investment-portfolio-oms` | Step 7: PRD-003 Investment (D03), PRD-004 Portfolio (D04), PRD-005 OMS (D05); WF-031, WF-032 added to BA-004 register | STEP7_VERDICT | see gate | see gate |

## Owner decisions used by the loop

| # | Decision | Date |
| --- | --- | --- |
| D-1 | Reviewer is advisory; owner merges (GOV-007) | 2026-11-19 |
| D-2 | Loop: stack steps; scheduled one step per run; 3 fix rounds; log gaps and continue (GOV-008) | 2026-11-19 |
| D-3 | Steps may build on Draft documents; GOV-005 "start after Approved" applies to production build only (resolves review STEP-01 finding 4) | 2026-11-19 |
| D-4 | Loop may merge only through `scripts/merge_gate.py` (CR-0001, GOV-008 §5) | 2026-11-19 |
| D-5 | Paid external expert review before any T1 document is Approved | 2026-11-19 |
| D-6 | Repository to become private (owner action) | 2026-11-19 |
| D-7 (Q5) | Cloud: AWS Mumbai (ap-south-1) primary, Hyderabad (ap-south-2) for disaster recovery | 2026-11-20 |
| D-8 (Q6) | Sign-in: each AMC's own identity provider via OIDC/SAML; Keycloak for AMCs without one | 2026-11-20 |
| D-9 (Q8) | No `ANTHROPIC_API_KEY` repo secret for now; reviews run inside loop sessions | 2026-11-20 |
| D-10 (Q9) | Branch protection on `main` is not on; merge gate + CODEOWNERS remain the control | 2026-11-20 |
| D-11 (Q10) | First target segment: new AMCs (C3) first, mid-size AMCs (C2) second | 2026-11-20 |
| D-12 (Q11) | Go-live by month 24 wins: pilot starts earlier (about month 15–18) so the parallel run ends by month 24. "3–5 paying AMCs by month 36" includes the pilot AMC | 2026-11-20 |
| D-13 (Q12, Q15) | `CAP-Dxx-nnn(.m)`, `DEP-nn` and `TERM-nnn` are official IDs (added to GOV-001 §4) | 2026-11-20 |
| D-14 (Q13) | D01 "Subscription management" = the AMC's subscription to AMC OS (plans, entitlements, metering) | 2026-11-20 |
| D-15 (Q14) | Systems stance stays per domain (replace / connect / mirror, BA-002 §5); per-capability detail during pilot discovery | 2026-11-20 |
| D-16 (Q16) | Fund accounting and NAV: AMC OS replaces them where the AMC does them in-house; mirrors and validates where outsourced to the custodian (also answers architecture proposal OD-2 direction) | 2026-11-20 |
| D-17 (Q17) | `ROLE-nn` is an official ID (added to GOV-001 §4) | 2026-11-20 |
| D-18 (Q18) | No segregation-of-duties rule can be waived, except SOD-03 (tenant-configurable, per PRD-000) and the SOD-16 small-team mode (D-19) | 2026-11-20 |
| D-19 (Q19) | Small AMCs (small-team mode): a Tenant Administrator may also hold a business role; every access grant is reviewed by the Information Security Officer and shown in the SOD-11 nightly report (BA-005 SOD-16) | 2026-11-20 |
| D-20 | What counts as a "small" AMC for small-team mode: decided in pilot discovery | 2026-11-20 |
| D-21 | Small-team mode is switched on only with approval of both the Information Security Officer and a Compliance Officer | 2026-11-20 |
| D-22 | In small-team mode the Information Security Officer reviews each access grant before it takes effect | 2026-11-20 |
| D-23 | Small-team mode: a grant to the AMC's only Information Security Officer is reviewed by a Compliance Officer | 2026-11-20 |
| D-24 | Small-team mode: the ISO pre-effect review is blocking (a rejection stops the grant) | 2026-11-20 |
| D-25 | Small-team mode: when an AMC is no longer small, the mode is switched off when a grace period ends (length set in pilot discovery), and Tenant Administrators then give up their business roles | 2026-11-20 |

## Waiting for owner (cannot be auto-merged)

| Branch | Why |
| --- | --- |
| — | Nothing waiting: `wp2-step05b-owner-answers` was merged by the owner (104bde6). Note kept for the owner: `scripts/merge_gate.py` accepts table-row-only changes anywhere in GOV-001, which is looser than CR-0001 G2 (review STEP-05b round 2, finding 1); fixing the script is an owner-only change |

## Questions for owner (open)

| # | Question | Raised by | Default used meanwhile |
| --- | --- | --- | --- |
| Q20 | Subscription to AMC OS: which usage measures should be metered (for example named users, schemes, API calls, storage), and when a subscription lapses or is downgraded, should the module become read-only or hidden? | Step 6 (PRD-001 FR-D01-027, FR-D01-028) | Metering of counts only, list to be decided; data never deleted; lapsed module read-only |
| Q21 | When an AMC leaves: in what format do we hand over its data, how long does it have to take it, and how long do we keep records afterwards? | Step 6 (PRD-001 FR-D01-004) | Open, documented formats with checksums; time limit and retention as in the contract and law (REG-001) |
