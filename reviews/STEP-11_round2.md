## AMC OS Review Agent — advisory review

**PR:** branch `wp3-step11-service-catalogue` (base `wp3-step10-system-context`), review round 2 · **Step / WP:** GOV-006 Step 11 / WP3 · **Reviewed at:** 5318af685ce212d0d89c0a6f9131e28639096126

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
All three round 1 Majors are fixed. Of the 16 Minor and Nit findings, 14 are fixed, finding 5 is only partly fixed and finding 19 is left to the owner. I found no new Blocker or Major. Five new Minor findings and two new Nits remain.

### Round 1 findings: status
| R1 # | Severity | Status at 5318af6 |
| --- | --- | --- |
| 1 | Major | **Fixed.** T15 (EA-003:511) now gives each module its own relay under its own role, writing only its own outbox. Row-level security stays forced, and the relay sets tenant context per batch from `platform.tenant`. DDL-000:1441 excludes `platform.tenant` from `apply_tenant_rls()`, so the relay can read it. B4 is updated. One wording leftover is new finding 2. |
| 2 | Major | **Fixed.** Reporting moved to tier 4 and now calls Workflow and Documents. The card, the §4.1 table and the diagram agree. Only Finance (tier 10) calls Reporting, so the change adds no upward edge. |
| 3 | Major | **Fixed.** The §7 row and G8 now require ADR-0020 before Steps 15–16. The row covers T1, T3, T15 and B2. ADR-0020 is unused on every local and remote branch. ADR-0009…0015 are on the proposal branch and ADR-0016…0019 on Step 10. |
| 4 | Minor | Fixed. Valuation policy and source order are now separate rows. EA-008:149 matches PRD-011 FR-D11-014 and BRL-D11-007 word for word. |
| 5 | Minor | **Partly fixed.** EA-008:150 now marks the right with †, adds the owning-department checker and says definitions are authored through the Operations API. EA-003 still says "each owning module defines", which is new finding 1. |
| 6 | Minor | Fixed. The mode change now needs a migration plan. Entitlements moved to a "Not tenant settings" row that cites D-14 and D-26 correctly. |
| 7 | Minor | Fixed. Compliance now consumes `NAV_APPROVED`, Risk consumes `CORPORATE_ACTION_EFFECTIVE`, and the Accounting card consumes `SETTLEMENT_STATUS_CHANGED`, matching the §4.3 diagram. |
| 8 | Minor | Fixed. B9 is marked *new*, and the EA-002 §5.1 row is in §7. |
| 9 | Minor | Fixed. §7 now has rows for BA-004 WF-021, PRD-001, BA-001 CAP-D01-008, GOV-005 and ADR-0017. Cache time-to-live values are deferred to DBE-002 (EA-003 G9, EA-008 G6). |
| 10 | Minor | Fixed. The Workflow card notes the change as *new*, and §7 has rows for BA-001 and DA-000. |
| 11 | Minor | Fixed. §3 and §4.1 now give one convention for calls to Tenant and Identity, and all cards follow it. |
| 12 | Minor | Fixed. Tenant feature flags are now K1 settings (FR-D01-003, CAP-D01-001 (.3)), and vendor release toggles are kept separate. |
| 13 | Minor | Fixed. WF-022 is added (EA-003 §3.2 and §4.2). Q66–Q68 are in LOOP_STATE:181–183. |
| 14–18 | Nit | Fixed. Q2 now cites GOV-006 §4, the gateway rule cites EA-001 X14 and CAP-D17-001, the FE-10 request is dropped, the DA-000 paraphrase is reworded and the EA-101 scope is corrected. |
| 19 | Nit | Open, owner's choice. Commit 5318af6 still has the trailer `Co-Authored-By: Claude <noreply@anthropic.com>`. |

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | EA-003:322, :507, :508 vs EA-008:150 | This is round 1 finding 5, still open on the EA-003 side. The Operations card says "each owning module defines its own reconciliation sets". T11 says "Settlement and Accounting each define their own match rule sets". T12 says "reconciliation sets that the Investor module defines". EA-008:150 now says the definitions are stored in `operations` and written by people of the owning department through the Operations API, "not by the owning module calling Operations". Investor and Settlement (tiers 6–7) cannot call Operations (tier 8), so the EA-003 wording still reads as a call against the tier order. | Reword the three EA-003 places to match EA-008. Example: "the owning department defines its sets through the Operations API; they are stored in `operations`". |
| 2 | Minor | EA-003:135 vs :511 | The Tenant card still says Tenant "holds … the per-schema outbox relay (B4)". T15 and B4 now say each module runs its own relay under its own role and only the code is shared. Read literally, the card describes the central relay that round 1 finding 1 removed. | Change the card to "provides the shared relay code; each module runs its own relay (B4, T15)". |
| 3 | Minor | EA-003:511 (T15) | The relay sets tenant context from the tenant list it reads in `platform.tenant`, "exactly as a request does". A request does not work that way: STD-001 §4 (line 48) and AGENTS.md §2.4 say tenant context comes "from the authenticated principal". This is a system-worker exception. It is a reasonable one, and EA-002:230 already has a similar rule for event consumers. But it is not named as an exception, and it is not in the ADR-0020 scope in §7 (line 532). | Remove "exactly as a request does". Name this as a system-worker exception to STD-001 §4, citing the EA-002:230 precedent. Add it to the ADR-0020 scope row. |
| 4 | Minor | EA-003:297 (Valuation adapters), T16 :512; §7 | T16 gives price adapters to Valuation (X03, X11, X10). PRD-011 FR-D11-001 (PRD-011:63) still says prices come in "through D16 adapters". This is the same kind of stale cross-reference as round 1 finding 9, and PRD-011 is not in the §7 PRD row. | Add PRD-011 FR-D11-001 to §7 ("price adapters sit in the Valuation module, B9 and T16"). |
| 5 | Minor | EA-008:156 | The † footnote sends readers to LOOP_STATE "BA-005 changes waiting". That list (LOOP_STATE:149–163) covers only D-28…D-75 items. It contains neither `operations.recon_definition.approve` (a PRD-012 §7 † right, PRD-012:207) nor the Head of Sales role (PRD-014 BRL-D14-005). The pointer therefore leads to a list without these items, and they could be missed when BA-005 is next revised. | Point the footnote to PRD-012 §7 and PRD-014. Alternatively, when LOOP_STATE is next updated, add these two items to its "BA-005 changes waiting" list. |
| 6 | Nit | EA-008:32, :48 | The section heading and the diagram describe "four kinds … and one kind that is never allowed". The table now also has a "Not tenant settings" row, placed between K2 and K3, which neither the heading nor the diagram shows. | Move the row below "Never allowed", or mention it in the heading or the diagram. |
| 7 | Nit | LOOP_STATE.md:181 (Q66) | "per-scheme accounting mode, NAV mode and NAV submitter" can be read as saying the NAV submitter is per scheme. D-44 says it is "set per tenant", and EA-003 §6 point 2 gives no scope for it. | Reword as "per-scheme accounting mode and NAV mode, and the per-tenant NAV submitter". |
| 8 | Nit | commit 5318af6 | Round 1 finding 19 repeated: the trailer is `Co-Authored-By: Claude`. | Owner choice. |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | Run on the head working tree (clean, at 5318af6): "57 spec documents checked; 0 problem(s)". Exit code 0. |
| Arithmetic re-computed | This change has no money arithmetic. Counts are unchanged from round 1: 22 modules in the §2 table and the 17 domains covered. Q66–Q68 follow on from Q65 with no gaps. G1–G9 in EA-003 §8 and G1–G6 in EA-008 §11 run in order. |
| Tier table vs §3 "Calls" rows | I re-ran the round 1 parser (scratchpad `chk.py`) on the head EA-003. All 22 cards and all 22 tier rows were parsed. Every "Calls" row equals its §4.1 row. The only reported mismatch is Tenant, a parser false positive: the Tenant card's explanation mentions Workflow, but the card itself says "None (tier 0)". There are no upward or same-tier calls, so the table is acyclic. Reporting at tier 4 calls Workflow (3) and Documents (2); it does not call Security master (also tier 4). Every consumed event has a publisher; the newly consumed `NAV_APPROVED`, `CORPORATE_ACTION_EFFECTIVE` and `SETTLEMENT_STATUS_CHANGED` are all published. The §4.1 diagram edge "Reporting 4 → Workflow" matches the table. |
| Sources | All sources are internal and were opened in the repo: PRD-001 (FR-D01-003, §4.6 FR-D01-026…028), BA-001 (CAP-D01-001 (.3), CAP-D01-006), PRD-011 (FR-D11-014, BRL-D11-007, FR-D11-001), PRD-012 (FR-D12-016, §7 line 196, line 207), PRD-014 (BRL-D14-005), PRD-005 (FR-D05-012), PRD-016 (C10), LOOP_STATE (D-14, D-16, D-26, D-44), DA-000 Ch 2 line 56, DDL-000 (`current_tenant`, `apply_tenant_rls`), STD-001 §4, EA-002:230, GOV-002 §2 line 39, GOV-006 (Steps 12, 19, 26). Every claim checked matches the wording quoted, except the items in findings 3–5. There are no external sources, and no regulatory fact or provider interface is invented. |
| Scope vs GOV-006 step | Step 11 asks for "EA-003 domain boundaries & service catalogue; configuration-over-customisation design" (master prompt §3.6, §5). Both are delivered, with all 17 domains covered. Splitting the configuration design into EA-008 is now recorded for GOV-005 WP3 in EA-003 §7. Nothing outside the scope was added. |
| Governance | EA-003 and EA-008 have full front matter, status Draft, and IDs that match their file names. The GOV-001 §7 register has two table rows added (lines 183–184). The GOV-006 Step 11 cell is updated (table row only). Both changes fall under the merge_gate.py G2 exemptions; LOOP_STATE.md and reviews/** are also exempt. The EA README lists both documents, and its "Next" line is correct. LOOP_STATE Q66–Q68 each have a source and a default. As the caller said, the chain table and next action are not yet updated, which is expected. No instruction-injection text was found in the diff, the round 1 review file or the commit messages. |
| Cross-references | ADR-0020 is free on every branch. DBE-002 is Step 19, EA-006 is Step 12 and the runbooks are Step 26, all as cited. `platform` is "only schema with non-tenant rows" (DA-000:56), as EA-008:171 now states. |

### Not checked
- CI status: not verified. The head branch is local only (it is not on `origin`), and I did not query GitHub.
- Database tests (DBT-000): not run. No DDL or migration changed.
- `scripts/merge_gate.py`: not run. Merging is outside this review. Whether the gate passes on the G2 exemptions was judged by reading the script's docstring and CODEOWNERS only.
- Owner-only decisions (ADR-0020 content, the ADR-0002 G1 reading, the GOV-001 §5 FE-03 change, and Q66–Q68): these are for the owner and were not assessed beyond checking that the documents state them correctly.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._

Files reviewed:
- /home/claude/amc-os/docs/04_enterprise_architecture/EA-003_domain_boundaries_and_service_catalogue.md
- /home/claude/amc-os/docs/04_enterprise_architecture/EA-008_configuration_over_customisation.md
- /home/claude/amc-os/LOOP_STATE.md
- /home/claude/amc-os/docs/00_governance/GOV-001_document_control_and_identifiers.md
- /home/claude/amc-os/docs/00_governance/GOV-006_gap_analysis_and_delivery_plan.md
- /home/claude/amc-os/docs/04_enterprise_architecture/README.md

Checker script reused: /tmp/claude-0/-home-claude-amc-os/53210007-c75b-5fa2-8b05-aba2fd510524/scratchpad/chk.py

The repository was not modified.
