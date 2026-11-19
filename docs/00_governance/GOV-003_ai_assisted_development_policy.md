---
id: GOV-003
title: AI-Assisted Development Policy
status: Draft
version: 0.1
owner: CTO
approver: Architecture Review Board (ARB)
work_package: WP1
last_updated: 2026-11-19
---

# GOV-003 — AI-Assisted Development Policy

AI agents speed up the work; humans stay accountable for it. AI-written code, documents and migrations go through exactly the same review and tests as human work, and no AI agent can approve or merge its own change.

This policy covers AI used to **build** AMC OS. AI features **inside** the product (copilots, agents) are governed by the AI/ML specifications in `docs/09_ai_and_ml/` and by ADR-0008.

## 1. What AI agents may and may not do

| May | May not |
| --- | --- |
| Analyse approved requirements | Invent financial business rules (rates, thresholds, formulas, cut-offs) |
| Propose technical designs | Change approved architecture without a CR and ARB review |
| Generate boilerplate, migrations, tests, documentation | Access production secrets or production data |
| Review code and identify defects | Connect to or modify live production databases |
| Suggest performance improvements | Approve financial calculations |
| Draft ADRs and change requests | Approve or merge their own changes |
| Run tests in non-production environments | Skip, disable or weaken tests to make a build pass |
| | Deploy any release |
| | Set any document or ADR status to Approved |

## 2. Rules for financial logic

1. Every financial calculation an AI writes must cite the approved spec it implements (e.g., `# Implements FE-01 §5.3`). No citation → the change is rejected.
2. If the spec is missing or ambiguous, the agent stops, records the gap (GOV-001 `[ASSUMPTION]` / open question) and asks. It never fills the gap with a plausible guess.
3. Every financial function an AI writes ships with independent expected-result tests whose expected values come from the spec or a human-prepared worked example, not from running the new code.

## 3. Required checks for AI-generated changes

All must pass before human review is requested:

1. Specification validation — the PR links the requirement / spec IDs it implements.
2. Static analysis — type checking (mypy strict / `tsc --strict`), linting (ruff / eslint).
3. Unit tests.
4. Integration tests (including tenant-isolation tests for any data-access change).
5. Security scanning — dependency scan, secret scan, SAST.
6. Advisory AI review by the independent review agent (GOV-007), then human review by a qualified reviewer (financial code: a reviewer with fund accounting / NAV knowledge).
7. CI/CD pipeline green.

## 4. Working protocol in this repository

- AI agents work on a branch named `wp<n>-<topic>` or `feat/<id>-<topic>`, never on `main`.
- Each change is a pull request; the PR description follows the completion report in [AGENTS.md](../../AGENTS.md) (objective, files, decisions, DB/API/security impact, tests run and results, limitations, open decisions).
- Commits made by an AI agent carry a `Co-Authored-By` trailer naming the agent, so AI-generated changes are identifiable in history.
- Branch protection on `main`: at least one human approval, all checks green, no self-approval.
- Test results reported in a PR must be from tests actually run; "not run" is stated as such.

## 5. Data handling

- No production data, investor PII or customer documents in prompts, fixtures or test data. Use synthetic data generated from documented rules.
- No secrets in prompts or code; secrets come from the secrets manager at runtime.
- Licensed vendor data (e.g., FactSet) is used with AI tools only where the licence permits; confirm per vendor **[VAL]**.

## 6. Accountability

The human who approves and merges a PR owns its content, whoever wrote it. Recurring AI-introduced defect patterns are logged and fed back into agent instructions (AGENTS.md).
