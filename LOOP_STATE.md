# LOOP_STATE — build loop status (GOV-008)

**Status:** RUNNING
**Updated:** 2026-11-20 04:39 IST
**Chain tip:** `wp2-step03-operating-model`

## Next action

**Owner answers 20 Nov 2026 (D-7 to D-16):** apply them when the related documents are next touched. In particular, D-12 changes the pilot timing in PS-001 §6 and PS-002 §5 — make that edit as a small fix (Step 1 follow-up) before or alongside Step 4. The repository is still public until the owner switches it (D-6).

**Step 4** on a new branch `wp2-step04-workflows` from the chain tip: BA-004 end-to-end workflows WF-001…WF-0nn (re-key PRD-000 W1–W17, add new workflows for D01, D06 and D07), GOV-006 §3. Each workflow lists the `CAP-` IDs it uses (BA-001) and the `DEP-` departments involved (BA-002), and names the external system at each hand-off (BA-002 §5).

After that: Steps 5, 6, … in GOV-006 order.

Housekeeping: `.gitignore` added and `__pycache__` untracked by the owner on 20 Nov 2026 (STEP-02 round 1 finding 8 closed).

Finding left open from Step 3: STEP-03 round 1 Nit 14 — GOV-001 `last_updated` and the register heading "as of 19 Nov 2026" were not changed, because only table rows of GOV-001 may change on a loop branch (merge gate G2); owner may update the dates.

Findings left open from Step 1 (no fix needed unless the owner wants it): STEP-01 round 3 Nit 2 — commit trailer follows the loop prompt (`Co-Authored-By: Claude`) rather than the older model-named format. STEP-01 round 3 finding 1 (was round 2 finding 6) — State Street pages B5 and B6 block automated fetches for the reviewer (HTTP 403); the writer opened both on 19 Nov 2026 and the cited wording matched.

## Loop notes

- **CI trigger (review STEP-01 finding 7):** `ci.yml` runs on `push` to every branch (plus manual `workflow_dispatch`), not on `pull_request`. Reason: the loop pushes branches without opening pull requests and reads the push run to decide whether the chain tip is green (GOV-008 rule 7 and stop conditions); a `pull_request` trigger on top would run the same checks twice. This replaces the earlier plan ("push only on `main`, plus `pull_request`"), which would have left loop branches with no CI. Trade-off: CI does not test the merge result against `main`; acceptable while branches are merged in order.

## Chain (merge in this order)

| # | Branch | Content | Review verdict | CI | Merged |
| --- | --- | --- | --- | --- | --- |
| 1 | `step-01-vision-market` | Step 1: PS-002, PS-003, PS-004 | RECOMMEND CHANGES (0 Blocker, 5 Major, 12 Minor, 2 Nit) | pass | yes (23:28, on owner instruction) |
| 2 | `gov-07-review-agent` | GOV-007 reviewer, GOV-008 loop, this file | not yet reviewed | pass | yes (23:28, on owner instruction) |
| 3 | `wp2-step01b-review-fixes` | Step 1 review fixes (PS-001–004, GOV-005, GOV-006, CI trigger) | Round 3: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 1 Minor accepted, 3 Nits — 2 fixed) | pending | no |
| 4 | `gov-cr0001-merge-protocol` | CR-0001 merge gate, CODEOWNERS, secret scanning, reviewer self-test (7/7) | owner work, self-tested | pass | no — owner-only files |
| 5 | `wp2-step02-capability-map` | Step 2: BA-001 business capability map (17 domains, 209 L2 capabilities, L3 breakdown) | Round 2: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 2 Minor, 1 Nit — all fixed) | pass | no |
| 6 | `wp2-step03-operating-model` | Step 3: BA-002 operating model and department hierarchy (19 departments, owner of all 209 capabilities, systems stance per domain); BA-003 domain dictionary (96 terms) | Round 1: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 9 Minor, 5 Nits — 13 fixed, 1 left) | pass | no |

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
| `wp2-step01b-review-fixes` | Gate re-run 2026-11-20 (Step 3 run): same result — G1, G3, G4, G6 (CI unknown) pass; **G2 fail** (owner-only `.github/workflows/ci.yml`, GOV-005, GOV-006); G5 run from the tip reports a checkout mismatch only. Earlier gate run 2026-11-20 (Step 2 run): G1, G3, G4, G6 pass; **G2 fail** — owner-only: `.github/workflows/ci.yml`, GOV-005, GOV-006 (text, not just table cells). G5 could not run with this branch checked out because `scripts/merge_gate.py` arrives only in the later branch; run from the tip it reports a checkout mismatch, not a docs failure. Owner merge needed |
| `gov-cr0001-merge-protocol` | Gate G2: governance, AGENTS.md, scripts, workflows (owner-only) |
| `wp2-step02-capability-map` | Waits behind the two branches above (G1). Own gates G2–G4 expected to pass: changes only BA-001, README, GOV-001 register row, GOV-006 status cell, reviews/, LOOP_STATE.md; round 2 review RECOMMEND MERGE AFTER FIXES; CI success |
| `wp2-step03-operating-model` | Waits behind the three branches above (G1). Own gates expected to pass: changes only BA-002, BA-003, README, GOV-001 register rows, GOV-006 status cell, reviews/, LOOP_STATE.md |

## Questions for owner (open)

| # | Question | Raised by | Default used meanwhile |
| --- | --- | --- | --- |
| — | None open (Q5–Q16 answered 20 Nov 2026, see D-7 to D-16) | — | — |
