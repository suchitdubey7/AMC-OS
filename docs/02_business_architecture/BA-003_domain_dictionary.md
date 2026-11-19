---
id: BA-003
title: Domain Dictionary (glossary with IDs)
status: Draft
version: 0.1
owner: Technical Documentation Lead
approver: Project owner (interim ARB)
work_package: WP2
step: 3
last_updated: 2026-11-20
---

# BA-003 — Domain Dictionary

One meaning per word. This dictionary fixes the business terms every AMC OS document, API, table, event and screen must use, so that "AUM", "unit balance" or "breach" mean the same thing everywhere (master prompt §22: "use consistent terminology"). It also gives each of the 17 business domains a short definition.

**Builds on Draft documents:** BA-001, BA-002, GOV-001, PS-001, PRD-000 v0.9 (glossary in "How to read this PRD", Chapters 2, 3 and 6) — allowed by owner decision D-3 ([GOV-008 §2](../00_governance/GOV-008_build_loop.md#2-rules), rule 3).

**How to use it**

- Each term has a stable ID `TERM-nnn`, proposed here **[DES]** (not yet in GOV-001 §4; owner question Q15 in [LOOP_STATE.md](../../LOOP_STATE.md)). IDs are never reused; new terms get the next free number. The list is in ID order: TERM-001 to TERM-088 were numbered roughly alphabetically, and later terms are added at the end.
- Definitions are plain-language working definitions for the product. Where a term has a legal definition in the SEBI (Mutual Funds) Regulations, 2026 or a SEBI circular, **the legal text prevails**; such terms are labelled **[REG-term]** = "regulatory term; legal definition to be cited clause by clause in REG-001 (Step 25)". This dictionary adds no regulatory numbers: limits, cut-off times and timelines are configuration **[VAL]**.
- Labels: **[IND]** industry usage · **[DES]** AMC OS design term · **[REG-term]** as above.
- Capability names are defined by [BA-001](BA-001_business_capability_map.md) (`CAP-` IDs) and departments by [BA-002](BA-002_amc_operating_model.md) (`DEP-` IDs); this dictionary defines the words they use and points to them.

## 1. The 17 business domains

Domain IDs are fixed by [GOV-001 §3](../00_governance/GOV-001_document_control_and_identifiers.md#3-domain-identifiers). The one-line definitions summarise BA-001 §3.

| ID | Domain | Definition | Accountable department(s) (BA-002 §4) |
| --- | --- | --- | --- |
| D01 | Platform Administration | Running AMC OS for a tenant: tenants, users, identity, access, configuration, audit, environments | DEP-15, DEP-16, DEP-01 |
| D02 | Product and Scheme Management | Designing, launching, documenting, changing and closing schemes, plans and options | DEP-13 |
| D03 | Investment Management | Research, recommendations, investment committee, investment decisions and investment policy | DEP-04, DEP-02 / DEP-03 |
| D04 | Portfolio Management | The holdings of each scheme: construction, rebalancing, exposure, benchmark comparison, attribution | DEP-02 / DEP-03, DEP-11 |
| D05 | Order Management System | Creating, checking, approving and routing orders, with their full history | DEP-02 / DEP-03, DEP-05, DEP-09 |
| D06 | Trading and Execution | Executing orders with brokers, allocating fills, confirming trades | DEP-05, DEP-06 |
| D07 | Settlement Management | Settling trades in cash and securities and handling failed settlements | DEP-06 |
| D08 | Compliance Management | Turning regulations and mandates into rules, checking them, and handling breaches | DEP-09 |
| D09 | Risk Management | Measuring and reporting market, credit, liquidity, concentration and counterparty risk | DEP-11 |
| D10 | Fund Accounting | Double-entry books of each scheme, from journals to period close | DEP-07 |
| D11 | Valuation and NAV | Prices, valuation, and calculating, approving and publishing NAV | DEP-07 |
| D12 | Fund Operations | Daily operations: calendars, reconciliations, corporate actions, exceptions, documents, workflows | DEP-06, DEP-15 |
| D13 | Investor Management and Servicing | Investors, folios and their transactions, mirrored from the RTA, plus service and complaints | DEP-08 |
| D14 | Distribution Management | Distributors, channels, sales, AUM by channel and commission | DEP-12 |
| D15 | Finance and Management Reporting | The AMC's own revenue, costs, budgets, profitability and management reports | DEP-14, DEP-01 |
| D16 | Enterprise Data Platform | Ingesting, governing and serving data: master data, quality, lineage, warehouse, metrics | DEP-17 |
| D17 | AI and Decision Intelligence | AI assistants and models that read, explain and propose — never approve, post or publish | DEP-15, DEP-17, business owners |

## 2. Terms

| ID | Term | Meaning | Domain(s) | Used in | Label |
| --- | --- | --- | --- | --- | --- |
| TERM-001 | Accrual | Income or expense earned or incurred but not yet received or paid, recorded in the books for the day it belongs to | D10, D11 | CAP-D10-005, CAP-D11-006, CAP-D11-007 | [IND] |
| TERM-002 | AMC (Asset Management Company) | The company appointed by the trustees to manage the schemes of a mutual fund. In AMC OS, one AMC is one tenant | All | BA-002 §1 | [REG-term] |
| TERM-003 | AMFI | Association of Mutual Funds in India, the industry body; registers distributors (ARN) and publishes NAVs and industry data | D11, D14 | BA-002 §6 | [IND] |
| TERM-004 | AMFI code | The scheme code AMFI assigns to each scheme plan and option | D02 | CAP-D02-001 | [IND] |
| TERM-005 | Approved universe | The list of securities a scheme may buy, approved through research and the investment committee | D03, D08 | CAP-D03-007, CAP-D03-009 | [IND] |
| TERM-006 | ARN | AMFI Registration Number, the registration of a mutual fund distributor | D14 | CAP-D14-002 | [IND] |
| TERM-007 | Audit event | An append-only record of who did what, when, from where, and to which record; never changed or deleted | D01 | CAP-D01-010 | [DES] |
| TERM-008 | AUM (assets under management) | Assets managed in a scheme (or in all schemes) on a date, normally reported on a net-assets basis (TERM-089) **[VAL]**. "Average AUM" (AAUM) is the average over a period. Always state which one and the date; the exact basis and formula for MIS are set once in the metric registry (CAP-D16-012) | D11, D14, D15, D16 | CAP-D14-008, CAP-D16-012 | [IND] |
| TERM-009 | Benchmark | The index a scheme's performance is compared with; the total-return variant (TRI) includes reinvested income | D02, D04 | CAP-D02-007, CAP-D04-008 | [REG-term] |
| TERM-010 | Break | A difference found by a reconciliation that has not yet been explained or resolved | D12 | CAP-D12-003 | [IND] |
| TERM-011 | Breach | A position or action found to be outside a regulatory, mandate or internal limit. Active breach = caused by the AMC's own action; passive breach = caused by market movement or flows **[IND]**; how each must be handled is **[VAL]** | D08 | CAP-D08-009 to CAP-D08-011 | [REG-term] |
| TERM-012 | Business date | The date a business event belongs to (for example the NAV date), as opposed to the time it was recorded | All | Master prompt §7 (business-effective dates) | [DES] |
| TERM-013 | Capability | Something the business must be able to do, independent of who does it or which system; levels L1–L3 with `CAP-` IDs | All | BA-001 §1 | [DES] |
| TERM-014 | Cell | One deployment unit of AMC OS that hosts one or more tenants | D01 | ADR-0003; EA-004 (Step 12) | [DES] |
| TERM-015 | Chart of accounts | The list of ledger accounts each scheme's books use | D10 | CAP-D10-001 | [IND] |
| TERM-016 | CKYC | Central KYC records registry (CERSAI). AMC OS connects to it through the RTA or directly; it never runs it | D13 | CAP-D13-003 | [REG-term] |
| TERM-017 | Compliance rule | An executable, versioned, effective-dated rule that checks a limit (`RULE-<code>@v<n>`), approved by a person | D08 | CAP-D08-001 to CAP-D08-005; GOV-001 §4 | [DES] |
| TERM-018 | Contract note | The broker's legal confirmation of a trade | D06 | CAP-D06-003 | [IND] |
| TERM-019 | Corporate action | An event by an issuer that changes holdings or income (for example dividend, bonus, split, rights, merger) | D12, D10 | CAP-D12-007, CAP-D10-008 | [IND] |
| TERM-020 | Custodian | The entity that holds a scheme's securities in safekeeping and settles them | D07, D12 | BA-002 §1, §6 | [REG-term] |
| TERM-021 | Cut-off time | The time of day that decides which day's NAV applies to an investor transaction; values are configuration | D02, D13 | CAP-D02-006 | [REG-term] |
| TERM-022 | Dealer | The person on the dealing desk who executes orders with brokers | D05, D06 | DEP-05 | [IND] |
| TERM-023 | Department | An organisational unit of the AMC (`DEP-nn`); configurable per tenant | D01 | BA-002 §3; CAP-D01-007 | [DES] |
| TERM-024 | Deterministic engine | Software that always returns the same result for the same inputs and versions; the only source of official numbers (`FE-nn`) | All | Master prompt §3.1; GOV-001 §5 | [DES] |
| TERM-025 | Distributor | An intermediary that sells schemes to investors: individual MFDs, banks, national distributors | D14 | CAP-D14-001 | [IND] |
| TERM-026 | Domain | One of the 17 business areas D01–D17; each owns its data schema and APIs | All | §1; GOV-001 §3 | [DES] |
| TERM-027 | Effective-dated | A record that carries the date range it applies to, so history can be reproduced exactly | All | PRD-000 C4 | [DES] |
| TERM-028 | EUIN | Employee Unique Identification Number of a distributor's employee or sub-broker who gives advice on a sale | D14 | CAP-D14-002 | [IND] |
| TERM-029 | Event | A versioned message that something happened in a domain (`<NAME>.v<n>`) | All | GOV-001 §4; EA-007 (Step 13) | [DES] |
| TERM-030 | Exception | A case a workflow cannot complete automatically and that a person must handle | D12 | CAP-D12-008 | [DES] |
| TERM-031 | Execution | The filling of an order (fully or partly) by a broker on an exchange or off-market | D06 | CAP-D06-002 | [IND] |
| TERM-032 | Exit load | A charge on redemption within a period set in the scheme documents; slabs are configuration | D02, D13 | CAP-D02-006 | [REG-term] |
| TERM-033 | Exposure | The amount of a scheme's assets in an issuer, group, sector, instrument type or other bucket. D04 shows it, D08 limits it, D09 measures its risk (BA-001 §4) | D04, D08, D09 | CAP-D04-007, CAP-D08-005, CAP-D09-006 | [IND] |
| TERM-034 | Fair valuation | Valuing a security by an approved method when a reliable market price is not available | D11 | CAP-D11-005 | [REG-term] |
| TERM-035 | Folio | An investor account number with an AMC, held at the RTA; one folio can hold units of several schemes | D13 | CAP-D13-002 | [IND] |
| TERM-036 | Fund manager | The person who manages a scheme's portfolio and makes its investment decisions | D03, D04, D05 | DEP-02, DEP-03 | [IND] |
| TERM-037 | Golden record | The single approved version of a master-data item (for example a security) used by every domain | D16 | CAP-D16-004 | [DES] |
| TERM-038 | Holding | The quantity of a security a scheme owns on a date | D04 | CAP-D04-002 | [IND] |
| TERM-039 | IDCW | Income Distribution cum Capital Withdrawal: the option under which a scheme pays out distributions (formerly called "dividend" option). Use "IDCW", not "dividend", for scheme payouts | D02, D13 | CAP-D02-003, CAP-D13-010 | [REG-term] |
| TERM-040 | Idempotent | Sending the same request twice has the same effect as sending it once | All | PRD-000 C7 | [DES] |
| TERM-041 | Investment Committee | The committee that approves investment policy, universe and major decisions | D03 | CAP-D03-005; BA-002 §2 | [IND] |
| TERM-042 | Investor | A person or entity holding units of a scheme (also "unitholder") | D13 | CAP-D13-001 | [IND] |
| TERM-043 | ISIN | International Securities Identification Number of a security or of a scheme plan and option | D02, D16 | CAP-D02-001 | [IND] |
| TERM-044 | Issuer | The company or government that issued a security | D03, D08, D16 | CAP-D08-004 | [IND] |
| TERM-045 | Journal | A balanced set of debit and credit postings recorded together | D10 | CAP-D10-002 | [IND] |
| TERM-046 | KIM | Key Information Memorandum, the short scheme document given with application forms | D02 | CAP-D02-004 | [REG-term] |
| TERM-047 | KRA | KYC Registration Agency, which holds investors' KYC records | D13 | CAP-D13-003 | [REG-term] |
| TERM-048 | KYC | Know Your Customer: identity and address verification of an investor | D13 | CAP-D13-003 | [REG-term] |
| TERM-049 | Ledger | The record of all postings per account; the general ledger is the full set for a scheme | D10 | CAP-D10-003, CAP-D10-004 | [IND] |
| TERM-050 | Maker-checker | One person prepares (maker), a different person approves (checker); the system blocks the same person doing both | All | PRD-000 C3, SOD-01; CAP-D12-011 | [DES] |
| TERM-051 | Mandate | The investment limits and permitted instruments of a scheme as set in its documents | D02, D08 | CAP-D02-006, CAP-D08-003 | [IND] |
| TERM-052 | Master data | Shared reference data (securities, issuers, counterparties, benchmarks, calendars) owned once and used everywhere | D16, D01 | CAP-D16-004, CAP-D01-009 | [DES] |
| TERM-053 | Metric registry | The single, versioned definition of each business metric (for example AUM, net sales, yield) | D16 | CAP-D16-012 | [DES] |
| TERM-054 | Mirror | A synced copy of another system's records kept for servicing, analytics and reconciliation; the other system stays the record keeper | D13 | GOV-006 Q2; BA-002 §5 | [DES] |
| TERM-055 | NAV per unit | Net assets (TERM-089) of a scheme plan and option divided by its units outstanding on a business date. "NAV" alone in AMC OS means NAV per unit; say "net assets" for the total. Calculated only by the NAV engine (FE-01); rounding per the FE-01 spec | D11 | CAP-D11-010 to CAP-D11-015 | [REG-term] |
| TERM-056 | NAV correction | Changing a NAV after publication because of an error; an exception workflow with its own approvals | D11 | PRD-000 W17 | [IND] |
| TERM-057 | Net flows (net sales) | Subscriptions minus redemptions (including switches) for a scheme, channel or period; definition held in the metric registry | D13, D14 | CAP-D14-009 | [IND] |
| TERM-058 | NFO | New Fund Offer: the first offer of a new scheme's units for subscription | D02 | CAP-D02-005 | [REG-term] |
| TERM-059 | Order | An instruction from a fund manager to buy or sell a security for one or more schemes | D05 | CAP-D05-001 | [IND] |
| TERM-060 | Override | A permitted, recorded decision to proceed despite a control result; needs the approvers set in BA-005 (for example PRD-000 SOD-04). AI never overrides | D05, D08 | CAP-D08-006 | [DES] |
| TERM-061 | Plan and option | Each scheme has plans (direct, regular) and options (growth, IDCW); each combination has its own NAV and ISIN | D02 | CAP-D02-003 | [REG-term] |
| TERM-062 | Platform operator | The AMC OS vendor's operations staff; no default access to tenant business data | D01 | PRD-000 SOD-09 | [DES] |
| TERM-063 | Posting | One debit or credit line in a journal | D10 | CAP-D10-002 | [IND] |
| TERM-064 | Post-trade compliance | Checking compliance rules on actual holdings after trades and market moves | D08 | CAP-D08-007 | [IND] |
| TERM-065 | Pre-trade compliance | Checking compliance rules on an order before it is released to the dealer | D08, D05 | CAP-D08-006, CAP-D05-010 | [IND] |
| TERM-066 | Price source | An approved provider or method for the price of a security, with a priority order | D11 | CAP-D11-003 | [DES] |
| TERM-067 | Reconciliation | Comparing two records of the same thing (for example AMC OS holdings against the custodian) and resolving breaks | D12 | CAP-D12-003 to CAP-D12-006 | [IND] |
| TERM-068 | Regulatory control | A control that implements a regulatory requirement, registered as `RC-nnnn` | D08 | GOV-001 §4; REG-001 (Step 25) | [DES] |
| TERM-069 | Riskometer | The product label showing a scheme's risk level, as prescribed by SEBI | D02 | CAP-D02-004 | [REG-term] |
| TERM-070 | RTA | Registrar and Transfer Agent (CAMS, KFin): keeps investor records and processes investor transactions for the AMC | D13 | BA-002 §1 | [REG-term] |
| TERM-071 | SAI | Statement of Additional Information: the common document with details that apply to all schemes of the mutual fund | D02 | CAP-D02-004 | [REG-term] |
| TERM-072 | Scheme | A mutual fund scheme registered with SEBI and managed by the AMC. Use "scheme", not "fund", in AMC OS documents and screens | D02 | CAP-D02-001 | [REG-term] |
| TERM-073 | Scheme category | The SEBI category a scheme belongs to (for example a large-cap equity scheme) | D02 | CAP-D02-002 | [REG-term] |
| TERM-074 | Segregation of duties (SoD) | Rules that stop one person holding conflicting roles or doing conflicting steps | D01 | PRD-000 Ch 6 SOD-01 to SOD-11; BA-005 | [DES] |
| TERM-075 | Settlement | Exchange of cash and securities that completes a trade | D07 | CAP-D07-003, CAP-D07-004 | [IND] |
| TERM-076 | SID | Scheme Information Document: the offer document of a scheme | D02 | CAP-D02-004 | [REG-term] |
| TERM-077 | SIP / STP / SWP | Systematic Investment Plan (regular purchases), Systematic Transfer Plan (regular switches between schemes), Systematic Withdrawal Plan (regular redemptions) | D13 | CAP-D13-007 to CAP-D13-009 | [IND] |
| TERM-078 | SSI | Standing Settlement Instructions: the account details used to settle with a counterparty | D07 | CAP-D07-002 | [IND] |
| TERM-079 | Switch | Moving units from one scheme or plan to another: a redemption and a purchase processed together | D13 | CAP-D13-006 | [IND] |
| TERM-080 | TER | Total Expense Ratio: the scheme expenses charged to the scheme, as a share of its assets, per plan; limits are regulatory parameters | D02, D10, D15 | CAP-D02-006 | [REG-term] |
| TERM-081 | Tenant | One AMC using AMC OS; its data is isolated from every other tenant, and tenant context always comes from the authenticated identity | D01 | CAP-D01-001; master prompt §3.4 | [DES] |
| TERM-082 | Trade | An executed order allocated to a scheme, with price, quantity, broker and settlement details | D06 | CAP-D06-004, CAP-D06-007 | [IND] |
| TERM-083 | Trial balance | The list of ledger balances used to check that debits equal credits before closing | D10 | CAP-D10-011 | [IND] |
| TERM-084 | Trustees | The board of trustees or trustee company that supervises the AMC on behalf of unitholders; an outside supervisory body with read-only views | — (external party) | BA-002 §1, §2 | [REG-term] |
| TERM-085 | Unit balance | Number of units held. Two grains: per investor and folio (D13, mirrored from the RTA) and units outstanding per scheme plan and option (D11). They must reconcile | D11, D13 | CAP-D11-009, CAP-D13-011 | [IND] |
| TERM-086 | Unitholder Protection Committee (UHPC) | The committee whose responsibilities SEBI has set to protect unitholders' interests | D08, D13 | BA-002 §2 | [REG-term] |
| TERM-087 | Valuation policy | The approved methods and price sources for valuing each type of security | D11 | CAP-D11-004 | [IND] |
| TERM-088 | Workflow | A documented sequence of steps across departments and systems (`WF-nnn`) | D12 | BA-004 (Step 4); CAP-D12-011 | [DES] |
| TERM-089 | Net assets | Value of a scheme's (or a plan and option's) assets minus its liabilities on a business date; the numerator of NAV per unit (TERM-055) | D10, D11 | CAP-D11-008, CAP-D11-010 | [REG-term] |
| TERM-090 | MIS | Management information: the AMC's internal management reports | D15, D16 | CAP-D15-009 | [IND] |
| TERM-091 | QRTA | Qualified RTA: SEBI's category for large RTAs, which face extra oversight (PS-003 §7) | D13 | BA-002 §6 | [REG-term] |
| TERM-092 | SIF | Specialised Investment Fund: a SEBI fund category run by eligible AMCs (PS-003 §7); a later segment (C4, PS-003 §3; PS-001 §5.3) | D02 | PS-003 | [REG-term] |
| TERM-093 | PMS / AIF | Portfolio Management Services / Alternative Investment Fund: other SEBI-regulated products; a later segment (C4, PS-003 §3; PS-001 §5.3) that needs its own regulatory review | — | PS-003 | [REG-term] |
| TERM-094 | GIFT City funds | Funds set up in India's international financial services centre (GIFT IFSC), regulated by IFSCA (PS-003 §7); a later segment (C4, PS-003 §3) | — | PS-003 | [REG-term] |
| TERM-095 | Mutual fund (trust) | The trust, set up by the sponsor, that holds the schemes' assets for unitholders; the AMC manages it and the trustees supervise it. Not the same as a scheme (TERM-072) | All | BA-002 §1 | [REG-term] |
| TERM-096 | Sponsor | The entity that establishes the mutual fund trust | — (external party) | BA-002 §1 | [REG-term] |

## 3. Words to avoid or use with care

| Avoid | Use instead | Why |
| --- | --- | --- |
| "Fund" for a single scheme | Scheme (TERM-072); Mutual fund (TERM-095) for the trust | "Fund" can mean the mutual fund trust, a scheme or the money; ambiguity causes reporting errors |
| "Dividend" for scheme payouts | IDCW (TERM-039) | Dividend is kept for corporate actions on securities the scheme holds (TERM-019) |
| "Customer" | Tenant (the AMC) or Investor | AMC OS has two kinds of "customer" |
| "Module" for an AMC OS business area | Domain (TERM-026) | PRD-000 v0.9 used 15 modules; the 17 domains replace them (GOV-001 §3) |
| "AUM" without a date and type | "AUM as at <date>" or "AAUM for <period>" (TERM-008) | Closing and average AUM differ |
| "NAV" for the total value of a scheme | Net assets (TERM-089) | NAV means NAV per unit (TERM-055) |
| "Approved" for AI output | "Proposed" or "recommended" | AI never approves (master prompt §3.1) |
| "Balance" alone | Ledger balance, cash balance or unit balance (TERM-049, TERM-085) | Different domains, different numbers |

## 4. Consistency points found

| # | Point | Where it is closed |
| --- | --- | --- |
| C1 | PRD-000 v0.9 has its own short glossary ("How to read this PRD"); the six terms there (tenant, maker-checker, deterministic engine, effective-dated, idempotent, modular monolith) are carried here except "modular monolith", which is an architecture term for EA-002 (Step 10) | PRD re-key (Steps 6–9) |
| C2 | Terms labelled [REG-term] have no clause reference yet | REG-001 (Step 25) adds the clause of the SEBI (Mutual Funds) Regulations, 2026 or circular for each |
| C3 | `TERM-` IDs are not in GOV-001 §4 | Owner (Q15) |
| C4 | PS-003 §7 defines SIP as "a fixed monthly investment"; TERM-077 says "regular purchases", because SIP frequencies other than monthly exist **[IND]** and are scheme configuration (CAP-D02-006). PS-003's eight terms are otherwise carried here (TERM-008, TERM-070, TERM-077, TERM-090 to TERM-094) | PS-003 next revision |
| C5 | Whether AUM is reported on a net-assets basis (TERM-008) is **[VAL]**; confirm against the AMFI and SEBI definitions | REG-001 (Step 25); metric registry (Step 15) |

## Sources

All sources are inside this repository; no new regulatory facts are introduced. Regulatory meanings are labelled [REG-term] and will be sourced clause by clause in REG-001.

| # | Source | Used for |
| --- | --- | --- |
| 1 | [MASTER_BUILD_PROMPT.md](../../MASTER_BUILD_PROMPT.md) §3, §4, §22 | Domains, principles, consistent terminology |
| 2 | [GOV-001](../00_governance/GOV-001_document_control_and_identifiers.md) §3–§5 | Domain, artefact and engine IDs |
| 3 | [BA-001](BA-001_business_capability_map.md), [BA-002](BA-002_amc_operating_model.md) | Capabilities, departments, ownership |
| 4 | [PRD-000 v0.9](../03_product_requirements/PRD-000_master_prd_v0.9.md) glossary, Ch 2, 3, 4, 6 | Existing terms, common rules C1–C8, SoD rules, workflows |
| 5 | [PS-003](../01_product_strategy/PS-003_market_and_customer_analysis.md) §7 | Market terms (MIS, QRTA, SIF, PMS / AIF, GIFT City funds, SIP) |
