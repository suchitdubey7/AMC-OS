# LOOP_STATE — build loop status (GOV-008)

**Status:** RUNNING
**Updated:** 2026-11-20 00:35 IST
**Chain tip:** `wp2-step02-capability-map`

## Next action

**Step 3** on a new branch `wp2-step03-operating-model` from the chain tip: BA-002 AMC operating model & department hierarchy; BA-003 domain dictionary (glossary with IDs), GOV-006 §3. Use the BA-001 capability IDs; consider BA-001 §5 C7 (systems each capability replaces) if the owner agrees.

After that: Steps 4, 5, … in GOV-006 order.

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
| 5 | `wp2-step02-capability-map` | Step 2: BA-001 business capability map (17 domains, 209 L2 capabilities, L3 breakdown) | see reviews/STEP-02_round*.md | pending | no |

## Owner decisions used by the loop

| # | Decision | Date |
| --- | --- | --- |
| D-1 | Reviewer is advisory; owner merges (GOV-007) | 2026-11-19 |
| D-2 | Loop: stack steps; scheduled one step per run; 3 fix rounds; log gaps and continue (GOV-008) | 2026-11-19 |
| D-3 | Steps may build on Draft documents; GOV-005 "start after Approved" applies to production build only (resolves review STEP-01 finding 4) | 2026-11-19 |
| D-4 | Loop may merge only through `scripts/merge_gate.py` (CR-0001, GOV-008 §5) | 2026-11-19 |
| D-5 | Paid external expert review before any T1 document is Approved | 2026-11-19 |
| D-6 | Repository to become private (owner action) | 2026-11-19 |

## Waiting for owner (cannot be auto-merged)

| Branch | Why |
| --- | --- |
| `wp2-step01b-review-fixes` | Gate G2: changes `.github/workflows/ci.yml` and GOV-005/GOV-006 text (owner-only) |
| `gov-cr0001-merge-protocol` | Gate G2: governance, AGENTS.md, scripts, workflows (owner-only) |

## Questions for owner (open)

| # | Question | Raised by | Default used meanwhile |
| --- | --- | --- | --- |
| Q5 | Cloud and region | GOV-006 | Cloud-neutral; AWS India as reference |
| Q6 | Identity provider | GOV-006 | Customer IdP via OIDC; Keycloak for shared SaaS |
| Q8 | Add `ANTHROPIC_API_KEY` repo secret so the AI review also runs on GitHub? | GOV-007 | Review runs inside each loop session only |
| Q9 | Has branch protection on `main` been switched on? | Step 0 | Treated as pending |
| Q10 | First target segment: new AMCs (C3) before mid-size AMCs (C2)? PRD-000 put both first | Step 1 fixes (PS-003 §3) | C3 first, C2 second |
| Q11 | Does the "3–5 paying AMCs" target include the pilot AMC? Is month 36 the right horizon? And: pilot start at month 18–22 (PS-001 §6) plus a 3-month parallel run can end after month 24, which clashes with O1 and the roadmap (go-live by month 24). Which wins? | Step 1 fixes (PS-002 §5) | Includes the pilot; month 36; conflict left open |
| Q12 | Add the capability ID `CAP-Dxx-nnn` (and `.m` for level 3) to the GOV-001 §4 identifier table? | Step 2 (BA-001 §1) | Used in BA-001 as a proposal |
| Q13 | D01 "Subscription management": does it mean the AMC's subscription to AMC OS (plans, entitlements, metering), not investor subscriptions? | Step 2 (BA-001 CAP-D01-006) | Yes, the AMC's subscription to AMC OS |
| Q14 | Brief §22 Deliverable 2 asks for the "systems" in the operating model. Add "which current systems each capability replaces" to BA-002 (Step 3)? | Step 2 (BA-001 §5 C7) | Step 3 includes a short systems column |
