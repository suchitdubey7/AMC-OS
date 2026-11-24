---
id: ADR-0018
title: Cloud and regions — AWS Mumbai (ap-south-1) primary, AWS Hyderabad (ap-south-2) disaster recovery; portable building blocks
status: Draft
date: 2026-11-21
deciders: ARB (interim: project owner)
domains: D01 + all
related: EA-001 §8; EA-002; ADR-0003; ADR-0007; PRD-001 NFR-DR-001, NFR-AVAIL-001; owner decisions D-7, D-61
---

# ADR-0018 — Cloud and regions: AWS Mumbai primary, AWS Hyderabad disaster recovery

> Written by the build loop (GOV-006 Step 10). The **cloud and region choice** is owner decision D-7 (20 Nov 2026). The rules for using it below are a proposal for the owner.

## Status
Draft

## Context
- D-7: AWS Mumbai (ap-south-1) is the primary region and AWS Hyderabad (ap-south-2) the disaster-recovery region.
- PRD-001 NFR-DR-001 (proposed): RPO ≤ 5 min, RTO ≤ 2 h, data residency in India; NFR-AVAIL-001: 99.95 % during 08:00–23:00 IST business days.
- Facts checked on 21 Nov 2026: AWS opened Asia Pacific (Hyderabad), API name `ap-south-2`, on 21 Nov 2022 with three Availability Zones; the same post says the Mumbai region launched in 2016 and added a third Availability Zone in May 2019 ([AWS News Blog](https://aws.amazon.com/blogs/aws/now-open-the-30th-aws-region-asia-pacific-hyderabad-region-in-india)). Both regions are in India, so a primary–DR pair keeps data in the country.
- Regulation (not yet read in full — **[VAL]**): SEBI's "Framework for Adoption of Cloud Services by SEBI Regulated Entities" (circular SEBI/HO/ITD/ITD_VAPT/P/CIR/2023/033, 6 Mar 2023, [circular page](https://www.sebi.gov.in/legal/circulars/mar-2023/framework-for-adoption-of-cloud-services-by-sebi-regulated-entities-res-_68740.html); body not opened in this run) and SEBI's Cybersecurity and Cyber Resilience Framework (CSCRF, 20 Aug 2024 per a [secondary source](https://www.barandbench.com/law-firms/view-point/cybersecurity-cyber-resilience-framework-sebi-digital-safety)). PRD-001 NFR-DR-001 already labels data localisation and DR drills as **[REG — CSCRF / SEBI cloud framework; VAL]**. Whether the AMC (as the regulated entity) needs the cloud provider to hold any specific Indian government empanelment, and what the AMC must contractually require from AMC OS as its technology provider, must be confirmed by Compliance **[VAL — confirm: Compliance / legal counsel; SEC-001 and REG-001, Step 25]**.

## Decision
1. **Regions.** All tenant data, backups, logs and AI processing stay in India. Primary: ap-south-1, spread over at least two (target three) Availability Zones. Disaster recovery: ap-south-2, with continuous database replication and replicated object storage and backups, sized to meet NFR-DR-001 once that target is confirmed.
2. **Accounts.** Shared cells run in AMC OS vendor accounts; a dedicated cell runs in its own account, which may be the AMC's own account if the AMC asks **[DES]** (master prompt §6 Model B). The control plane runs in a separate account and never stores financial data (ADR-0003 §4).
3. **Portable building blocks.** Prefer managed services that have open, portable equivalents: PostgreSQL, S3-compatible storage, a Redis-protocol cache (ADR-0017), Kubernetes-compatible containers if Kubernetes is adopted, OpenTelemetry. Avoid proprietary services on the financial path unless an ADR records the exit route. Reason: dedicated customers may require another hosting set-up, and an exit plan is expected for outsourced technology **[ASSUMPTION — confirm: Compliance]**.
4. **Service availability check.** Before any managed service is used, confirm it exists in **both** ap-south-1 and ap-south-2; a service missing in Hyderabad needs a documented DR alternative **[VAL — confirm with AWS per service]**.
5. **AI processing.** Model calls use India-region private endpoints with zero data retention and no training on AMC data (D-61). If the chosen provider has no such endpoint in ap-south-1 / ap-south-2, the assistant is not offered; it never falls back to another country **[DES]**.
6. **Encryption keys.** Per-tenant keys in the cloud key service of the tenant's cell, replicated to the DR region (ADR-0003 §3). Customer-managed keys for dedicated cells **[DES]**; key-management design in SEC-001 (Step 25).

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| --- | --- | --- | --- |
| Cloud-neutral documents only, no provider named (GOV-006 Q5 default before D-7) | No lock-in in documents | Cannot size, cost or check services | Owner decided D-7 |
| Another hyperscaler with two Indian regions | Similar | Not chosen by the owner | D-7 |
| Single region with multi-AZ only | Simpler, cheaper | No regional disaster recovery; NFR-DR-001 asks for a DR region | Fails NFR-DR-001 |
| Active-active across Mumbai and Hyderabad | Faster recovery | Complex for strongly consistent financial writes; not needed for the proposed RTO of 2 h | Over-engineered for release 1 |

## Consequences
- Positive: data stays in India; DR region in the same country; managed services reduce operating load.
- Negative: dependence on one provider; every managed service must be checked in two regions; costs of cross-region replication.
- Follow-up: EA-004 (Step 12) cell layout per region; INF-001 (Step 26) Terraform and DR runbook; SEC-001 / REG-001 (Step 25) read the SEBI cloud framework and CSCRF texts and close the [VAL] items above.

## Validation
DR drill: fail a test cell over from ap-south-1 to ap-south-2 and measure RPO and RTO against NFR-DR-001; service-availability checklist complete for both regions; compliance confirmation of the [VAL] items recorded.

## Change log
| Date | Status | By | Note |
| --- | --- | --- | --- |
| 2026-11-21 | Draft | Claude (build loop) for project owner | Created in GOV-006 Step 10 from owner decision D-7 |
