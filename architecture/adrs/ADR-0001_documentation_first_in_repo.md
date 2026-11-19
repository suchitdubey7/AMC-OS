---
id: ADR-0001
title: Documentation-first programme in this repository, in work packages
status: Draft
date: 2026-11-19
deciders: ARB (interim: project owner)
domains: all
related: GOV-001, GOV-005
---

# ADR-0001 — Documentation-first programme in this repository, in work packages

## Context
The master build prompt requires a complete approved specification before application coding, stored as Markdown in fixed repository folders, built in reviewable work packages. Earlier v0.9 drafts were produced as large single documents.

## Decision
1. All specifications live in this repository as Markdown, in the folders of master prompt §14, with IDs per GOV-001.
2. Work proceeds in seven work packages (GOV-005); each ends in a pull request reviewed by a human approver.
3. No production code in `src/` until WP7 baseline approval; v0.9 drafts are inputs, not baselines.
4. Mermaid is used for diagrams so they diff and render on GitHub.

## Alternatives considered
| Option | Why not chosen |
| --- | --- |
| Wiki / Google Docs | Not versioned with code; weak traceability |
| One master document | Unreviewable; brief forbids it |

## Consequences
Slower start; strong traceability; documents and code change in the same PRs later.

## Validation
WP1–WP7 merged with approvals recorded; CI link-checker and ID-uniqueness checker green.
