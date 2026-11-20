# LOOP_STATE — build loop status (GOV-008)

**Status:** RUNNING
**Updated:** 2026-11-19 23:50 IST
**Chain tip:** `wp2-step01b-review-fixes`

## Next action

**Step 2** on a new branch `wp2-step02-capability-map` from the chain tip: BA-001 business capability map (all 17 domains, level 1–3 capabilities), GOV-006 §3.

After that: Steps 3, 4, … in GOV-006 order.

Findings left open from Step 1 (no fix needed unless the owner wants it): STEP-01 round 3 Nit 2 — commit trailer follows the loop prompt (`Co-Authored-By: Claude`) rather than the older model-named format. STEP-01 round 3 finding 1 (was round 2 finding 6) — State Street pages B5 and B6 block automated fetches for the reviewer (HTTP 403); the writer opened both on 19 Nov 2026 and the cited wording matched.

## Loop notes

- **CI trigger (review STEP-01 finding 7):** `ci.yml` runs on `push` to every branch (plus manual `workflow_dispatch`), not on `pull_request`. Reason: the loop pushes branches without opening pull requests and reads the push run to decide whether the chain tip is green (GOV-008 rule 7 and stop conditions); a `pull_request` trigger on top would run the same checks twice. This replaces the earlier plan ("push only on `main`, plus `pull_request`"), which would have left loop branches with no CI. Trade-off: CI does not test the merge result against `main`; acceptable while branches are merged in order.

## Chain (merge in this order)

| # | Branch | Content | Review verdict | CI | Merged |
| --- | --- | --- | --- | --- | --- |
| 1 | `step-01-vision-market` | Step 1: PS-002, PS-003, PS-004 | RECOMMEND CHANGES (0 Blocker, 5 Major, 12 Minor, 2 Nit) | pass | no |
| 2 | `gov-07-review-agent` | GOV-007 reviewer, GOV-008 loop, this file | not yet reviewed | pass | no |
| 3 | `wp2-step01b-review-fixes` | Step 1 review fixes (PS-001–004, GOV-005, GOV-006, CI trigger) | Round 3: RECOMMEND MERGE AFTER FIXES (0 Blocker, 0 Major, 1 Minor accepted, 3 Nits — 2 fixed) | pending | no |

## Owner decisions used by the loop

| # | Decision | Date |
| --- | --- | --- |
| D-1 | Reviewer is advisory; owner merges (GOV-007) | 2026-11-19 |
| D-2 | Loop: stack steps; scheduled one step per run; 3 fix rounds; log gaps and continue (GOV-008) | 2026-11-19 |
| D-3 | Steps may build on Draft documents; GOV-005 "start after Approved" applies to production build only (resolves review STEP-01 finding 4) | 2026-11-19 |

## Questions for owner (open)

| # | Question | Raised by | Default used meanwhile |
| --- | --- | --- | --- |
| Q5 | Cloud and region | GOV-006 | Cloud-neutral; AWS India as reference |
| Q6 | Identity provider | GOV-006 | Customer IdP via OIDC; Keycloak for shared SaaS |
| Q8 | Add `ANTHROPIC_API_KEY` repo secret so the AI review also runs on GitHub? | GOV-007 | Review runs inside each loop session only |
| Q9 | Has branch protection on `main` been switched on? | Step 0 | Treated as pending |
| Q10 | First target segment: new AMCs (C3) before mid-size AMCs (C2)? PRD-000 put both first | Step 1 fixes (PS-003 §3) | C3 first, C2 second |
| Q11 | Does the "3–5 paying AMCs" target include the pilot AMC? Is month 36 the right horizon? And: pilot start at month 18–22 (PS-001 §6) plus a 3-month parallel run can end after month 24, which clashes with O1 and the roadmap (go-live by month 24). Which wins? | Step 1 fixes (PS-002 §5) | Includes the pilot; month 36; conflict left open |
