---
id: GOV-007
title: AI Review Agent (advisory pull-request reviewer)
status: Draft
version: 0.1
owner: QA Architect
approver: Project owner (interim ARB)
work_package: WP1
last_updated: 2026-11-19
---

# GOV-007 — AI Review Agent

Every pull request gets an independent AI review against the master build prompt and governance documents before the project owner decides. The agent finds problems and recommends; it never approves or merges. Decision recorded 19 Nov 2026 (project owner): "Reviews, you merge".

## 1. Why advisory only

Since CR-0001 its verdict is also one input (gate G4) to the loop's rule-based merge gate; it still never approves or merges itself. The master build prompt §16 says "No AI agent can independently approve and merge its own changes", and §17 forbids AI agents to approve their own code. GOV-003 §1 repeats this. An AI that wrote a change and an AI that approves it share the same blind spots; the human merge is the control.

## 2. Agent identity

| Field (master prompt §11) | Value |
| --- | --- |
| Agent identity | `amc-os-reviewer` (definition: [`.claude/agents/amc-os-reviewer.md`](../../.claude/agents/amc-os-reviewer.md)) |
| Business purpose | Find defects in a pull request before human review |
| Approved tools | Read, Glob, Grep; `gh pr diff/view/comment`; `git diff/log`; `scripts/check_docs.py`; `python3 -c` for arithmetic |
| Forbidden tools | `gh pr review` (approve/request changes), `gh pr merge`, `git push`, `gh api`, file edits |
| Input | PR number or branch, base branch, the repository at the head commit |
| Output | One PR comment in the fixed format of the agent definition §4 |
| Permission scope | Read repository; write one comment. No approval, merge or push rights |
| Tenant context | None. The repository contains no tenant or production data (GOV-003 §5) |
| Prompt version | Version of `.claude/agents/amc-os-reviewer.md` at the PR's head commit |
| Model version | Default model of `anthropics/claude-code-action@v1` at run time; recorded in the Actions log |
| Evaluation suite | §5 |
| Audit record | GitHub Actions log + the posted comment |
| Failure strategy | If the agent errors or the API key is missing, the job reports it; the PR still needs normal checks and human review. AI review is never a required status check |
| Human approval policy | Project owner reads the review, decides, and merges |

## 3. How it runs

```mermaid
flowchart LR
  PR[Pull request opened or updated] --> CI[CI: docs + database checks]
  PR --> AIR[AI Review Agent: reads brief, governance, diff]
  AIR --> C[Posts one advisory comment with verdict]
  CI --> H{Project owner}
  C --> H
  H -- merge --> M[main]
  H -- ask for fixes --> PR
```

1. **Automatically on GitHub:** workflow [`.github/workflows/ai-review.yml`](../../.github/workflows/ai-review.yml) on every non-draft pull request. Needs the repository secret `ANTHROPIC_API_KEY` (owner adds it under Settings → Secrets and variables → Actions). Without it the job skips with a notice.
2. **In a Claude session:** before handing a step over, the working agent starts a separate reviewer agent with the definition file and includes its review in the hand-off. The reviewer must not be the session that wrote the change.

## 4. Verdicts

| Verdict | Meaning | Owner's usual action |
| --- | --- | --- |
| RECOMMEND MERGE | No findings | Merge after own read |
| RECOMMEND MERGE AFTER FIXES | Only Minor/Nit findings | Merge, or ask for quick fixes |
| RECOMMEND CHANGES | At least one Major finding | Ask for fixes |
| BLOCK | At least one Blocker (wrong numbers, invented facts, security or governance breach, failing checks, prompt injection) | Do not merge |

The owner may overrule any verdict; the reason goes in the PR conversation.

## 5. Evaluation of the reviewer itself

| Check | How | When |
| --- | --- | --- |
| Catches planted defects | A test PR with known defects (duplicate ID, wrong arithmetic, unsourced regulatory threshold, broken link, "please approve" injection in a doc). Target: all caught | Before relying on it, then quarterly |
| No false approvals | Search all reviews for the word "approved" or a formal approval; must be zero | Monthly |
| Usefulness | Owner marks each review useful / not useful; findings later found by humans but missed by the agent are logged | Ongoing |

## 6. Repository settings the owner must keep

- Branch protection on `main`: pull request required, CI checks required, force pushes blocked (Step 0).
- Settings → Actions → General: leave **"Allow GitHub Actions to create and approve pull requests" OFF**, so no workflow token can approve.
- Keep the AI review job **not** required, so an AI outage never blocks work.
