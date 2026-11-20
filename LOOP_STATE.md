# LOOP_STATE — build loop status (GOV-008)

**Status:** RUNNING
**Updated:** 2026-11-20 09:40 IST
**Chain tip:** `wp2-step05-roles-permissions`

## Next action

**Step 6** on a new branch `wp2-step06-prd-platform-product` from the chain tip: PRD-001 Platform Administration (new; D01) and PRD-002 Product and Scheme Management (D02), GOV-006 §3. Re-key PRD-000 FR-01-nn to `FR-D02-nnn`; write new `FR-D01-nnn` from BA-001 D01 capabilities and BA-004 WF-019…WF-022; use BA-005 roles and SoD; close BA-005 §7 C7 (US-PLT-01 maker) in PRD-001.

After that: Steps 7, 8, … in GOV-006 order. The repository is still public until the owner switches it (D-6).

Done in the Step 5 run (20 Nov 2026, started early on owner request in chat): BA-005 roles, permissions and SoD; 2 review rounds. Defaults used until the owner answers Q17–Q19 are in the questions table.

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
| 7 | `wp2-step04-workflows` | Step 4: BA-004 end-to-end workflows WF-001…WF-028 (17 re-keyed, W6b → WF-018, 10 new for D01/D06/D07); D-12 pilot timing in PS-001/PS-002 | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits — 13 fixed, 1 left) | pass | yes (20 Nov 08:55, build loop, CR-0001 gate PASS) |
| 8 | `wp2-step05-roles-permissions` | Step 5: BA-005 roles (27), re-keyed permission matrix (17 domains), approval authorities, SOD-01…SOD-16 | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 5 Minor, 2 Nits — all fixed; round 1 had 4 Major, all fixed) | see gate | see gate |

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

## Waiting for owner (cannot be auto-merged)

| Branch | Why |
| --- | --- |
| — | Nothing waiting before Step 4: Steps 1–3, CR-0001 and the Q5–Q16 answers were merged by the owner on 20 Nov 2026 |

## Questions for owner (open)

| # | Question | Raised by | Default used meanwhile |
| --- | --- | --- | --- |
| Q17 | Make `ROLE-nn` (role IDs, BA-005 §2) an official ID in GOV-001 §4, like CAP-, DEP- and TERM-? | Step 5 (BA-005 §7 C1) | Used in BA-005 as a proposal **[DES]** |
| Q18 | Can any segregation-of-duties rule be waived, by whom and for how long? And how should very small AMCs (e.g. a two-person accounting team) be handled without weakening maker ≠ checker? | Step 5 (BA-005 §5.1, §7 C3) | No waiver except SOD-03 (tenant may switch it off by a Compliance-checked configuration change) |
| Q19 | Every AMC would need at least three people with no business role (two Tenant Administrators and one Technology Administrator; SOD-05 + SOD-16). For small new AMCs, may a Tenant Administrator also hold a business role, with a compensating control such as Information Security Officer review of every grant? | Step 5 review round 2 (BA-005 §7 C3) | No: three admin-only people needed |
