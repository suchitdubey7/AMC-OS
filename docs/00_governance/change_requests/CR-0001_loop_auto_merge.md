---
id: CR-0001
title: Build loop may merge low-risk document steps under a strict, rule-based gate
status: Draft
version: 0.1
owner: Project owner
approver: Project owner (interim ARB)
work_package: WP1
last_updated: 2026-11-19
---

# CR-0001 — Build loop strict auto-merge

The project owner decided on 19 Nov 2026 (23:35 IST, in chat) that the build loop may merge its own steps, but only under the strict conditions below. Everything else still needs the owner. This deliberately departs from master build prompt §16 ("No AI agent can independently approve and merge its own changes"), so it is recorded here with its reasons, limits and how to undo it.

## 1. Documents changed

| Document | Change |
| --- | --- |
| GOV-003 §1, §4 | AI may merge only through the CR-0001 gate; never approve |
| GOV-007 §1 | Reviewer stays advisory, but its verdict is now one input to the merge gate |
| GOV-008 §2 rule 8, new §5 | Merge protocol |
| `.github/CODEOWNERS` (new) | Lists owner-only paths; the gate reads it |
| `scripts/merge_gate.py` (new) + `tests/governance/test_merge_gate.py` | Rule-based gate and its tests |

## 2. The rule

The loop may merge a branch into `main` **only if every gate passes** (`scripts/merge_gate.py`, fails closed):

| Gate | Rule |
| --- | --- |
| G1 | The branch sits directly on `main` (merges happen strictly in chain order) |
| G2 | No changed file is owner-only in CODEOWNERS: no governance rules, AGENTS.md, master prompt, workflows, scripts, ADRs, financial-engine specs, security/regulatory specs, database, contracts, code or infrastructure. Exceptions: new rows in the GOV-001 register and GOV-006 status cells, `reviews/`, `LOOP_STATE.md` |
| G3 | Every changed document is still `Draft` |
| G4 | The latest independent review round has verdict RECOMMEND MERGE or RECOMMEND MERGE AFTER FIXES and lists no Blocker or Major |
| G5 | `scripts/check_docs.py` passes on the branch |
| G6 | GitHub CI is not failed or pending (unknown is accepted only because G5 re-runs the same checks; see §4) |

Anything that fails a gate stays as a branch for the owner. Later branches in the chain wait behind it.

## 3. What does not change

- Merging is not approving. Every merged document stays `Draft`; only the owner changes a status to Approved.
- No production code before WP7 approval.
- **Owner decision D-5:** before any T1 document (financial engines, compliance rules, NAV/accounting, security, tenant isolation) becomes Approved, a qualified external reviewer (paid) must review it and the review is recorded. Until then such documents stay Draft.
- The loop never pushes anything other than a gate-passing merge to `main`, and never force-pushes `main`.

## 4. Known limitations (honest list)

1. **Self-produced review.** The review file comes from a separate reviewer agent in the same run. A misbehaving run could in principle write a fake review. Mitigations: G2 keeps every high-risk path out of auto-merge; every merge commit carries the gate report; the owner can revert any merge. Stronger option: add the `ANTHROPIC_API_KEY` secret so a second, GitHub-side review also runs on every branch.
2. **Private repository (owner decision D-6).** Once private, the loop cannot read GitHub CI results without a token, so G6 sees "unknown" and relies on G5. GitHub emails the owner when a CI run fails.
3. **No branch protection on a free private repo.** GitHub Free does not enforce branch protection or rulesets on private repositories, so the gate script (not GitHub) is the control. A paid plan (GitHub Pro) would let the owner add GitHub-side protection with the loop as a listed bypass.

## 5. How to undo

Set `Status: PAUSED` in LOOP_STATE.md or tell the assistant "stop auto-merge". Removing this CR returns the loop to "owner merges" (GOV-008 §2 rule 8 original text).

## 6. Evidence

- Gate tests: 12 cases including injection text in a review (all pass, 19 Nov 2026).
- Reviewer self-test: `reviews/SELFTEST_2026-11-19.md`.
