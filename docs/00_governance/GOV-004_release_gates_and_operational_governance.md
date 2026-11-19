---
id: GOV-004
title: Release Gates and Operational Governance
status: Draft
version: 0.1
owner: Head of Release & Operations (to be named)
approver: CTO + ARB
work_package: WP1
last_updated: 2026-11-19
---

# GOV-004 — Release Gates and Operational Governance

Every capability passes nine gates, G0 to G8, before it reaches production. Critical financial modules can never skip G5 (financial correctness).

## 1. Risk tiers

The tier decides how much evidence each gate needs.

| Tier | Modules / changes | Rule |
| --- | --- | --- |
| **T1 Critical financial** | NAV (FE-01), accounting (FE-02), valuation (FE-03), compliance (FE-04), settlement (FE-06), reconciliation (FE-07), commission (FE-09), investor unit balances, any tenant-isolation or security control | All gates; G5 parallel run mandatory; two approvers at G8 |
| **T2 Business-critical** | OMS, portfolio, risk (FE-05), revenue (FE-08), performance (FE-10), distribution MIS, integrations | All gates; G5 by expected-result test packs |
| **T3 Supporting** | Dashboards, AI assistants (read-only), admin screens, documentation | G0, G1 (lightweight), G3, G6, G8 |

## 2. Gates

| Gate | Name | Entry | Exit evidence | Approver |
| --- | --- | --- | --- | --- |
| G0 | Product requirement approval | BR/FR/US/AC drafted with IDs | PRD section Approved; acceptance criteria testable; traceability rows created | Product Manager + domain owner |
| G1 | Architecture approval | Design + ADRs drafted | ADRs Approved; domain boundaries, APIs, events defined | ARB |
| G2 | Data and security design approval | Tables, migrations, threat model drafted | Data dictionary entries, RLS design, threat model Approved | Data Architect + Security Architect |
| G3 | Development completion | Code complete on branch | Unit/integration/contract/DB/tenant-isolation tests pass; coverage targets met (95% for T1 engines); static analysis + security scans clean; peer review done | Engineering lead |
| G4 | Integration validation | Deployed to integration environment | End-to-end workflow tests pass; provider certification steps done where applicable | QA Architect |
| G5 | Financial correctness validation | T1/T2 only | Independent expected-result packs pass; property-based tests pass; **T1: parallel run against incumbent/reference with 100% match or every difference explained and signed off**; historical replay reproduces stored results | Financial Systems Architect + business owner (e.g., Head of Fund Accounting) |
| G6 | Operational readiness | Release candidate | Monitoring and alerts live; runbooks written and walked through; backup restore tested; rollback plan tested; capacity check | Operations head |
| G7 | UAT and business acceptance | Operational readiness passed | UAT scripts signed by named business users; known issues accepted in writing | Business owner |
| G8 | Production authorisation | All prior gates evidenced | Release record with change list, migration review, security review, rollback plan, approvals | CTO (T1: CTO + business owner) |

No gate can be passed by an AI agent (GOV-003).

## 3. Production release checklist (G8 record)

- [ ] Approved change list (CR / PR links)
- [ ] All tests green, with run links
- [ ] Database migration reviewed (forward + rollback, timing on production-size data, lock analysis)
- [ ] Security review complete (scans, threat-model delta)
- [ ] Monitoring and alert thresholds in place
- [ ] Backup taken and restore validated in the last 30 days
- [ ] Rollback plan tested
- [ ] Runbook updated
- [ ] Business acceptance (where required)
- [ ] Authorised release approval recorded

Release windows avoid the daily NAV window and market hours for T1/T2 changes **[DES]**; exact windows set per tenant in G6.

## 4. Operational governance

| Area | Standard |
| --- | --- |
| Change management | Standard (pre-approved, low risk), normal (CAB review), emergency (post-facto review within 2 business days) |
| Incident severity | Sev1: wrong or late NAV, wrong money movement, cross-tenant exposure, security breach. Sev2: core workflow down with workaround. Sev3: degraded. Sev4: cosmetic |
| Incident response | Sev1 page within 5 min; customer AMC notified per contract; regulatory reporting obligations of the AMC supported with evidence **[VAL — CSCRF incident-reporting timelines]** |
| Problem management | Root-cause analysis for every Sev1/Sev2 within 10 business days; actions tracked to closure |
| Runbooks | One per T1/T2 workflow (daily NAV, day close, recon, commission run, DR failover) under `docs/14_release_and_operations/` |
| DR drills | Quarterly per cell; results recorded |
| Access reviews | Quarterly privileged access review; break-glass usage reported to the tenant |
| Claims discipline | No claim of SEBI compliance, ISO 27001, SOC 2 or any certification without independent assessment and evidence |
