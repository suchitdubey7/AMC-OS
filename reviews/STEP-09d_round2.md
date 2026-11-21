## AMC OS Review Agent — advisory review

**PR:** branch `wp2-step09d-owner-answers` (vs `origin/main`), round 2 · **Step / WP:** GOV-006 Step 9d (WP2): owner answers Q20–Q60 → D-26…D-66 (plus D-73, D-75) · **Reviewed at:** 9158a5bf89ebf2217359ba3054f21b226215fc98

**Verdict (advisory):** RECOMMEND CHANGES
All 13 round-1 findings are now fixed or recorded, but one owner decision (D-52, "the RTA sends the payout file") is still contradicted in PRD-012 and in the WF-011 diagram, which this PR edits.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Major | docs/03_product_requirements/PRD-012_fund_operations.md:71, :97, :149, :199; docs/02_business_architecture/BA-004_end_to_end_workflows.md:496 | D-52 is not applied everywhere. PRD-012 FR-D12-003 still has AMC OS sending "payment files host-to-host with maker-checker and dual authorisation for D12 payouts (**redemption payouts**, `operations.payout.release`, **WF-011**)". The §6 row for WF-011 still says "payout release", and the §7 row "D12 payout release" still needs two bank-mandate signatories. The WF-011 diagram, node G, still says "Payout file to bank - two authorisers". These contradict D-52, PRD-013 FR-D13-020/C1, and the WF-011 Approvals and Source cells that were rewritten in this PR (BA-004:484, :487). So the WF-011 card now disagrees with itself. Round 1 did not catch this. | In PRD-012, remove redemption, SWP and IDCW payouts from FR-D12-003, the §6 WF-011 row and the §7 payout-release row. Say instead that the RTA sends these files and AMC OS tracks and checks them (D-52, PRD-013 FR-D13-020). Keep `operations.payout.release` only for payouts AMC OS really releases, if there are any. If there are none, record that. In the WF-011 diagram, change node G to "RTA sends payout file (D-52); AMC OS tracks". |
| 2 | Minor | BA-004:484 (also the :479 Capabilities row) | The new Approvals cell cites CAP-D12-009 for "AMC OS tracks and checks the payout". In BA-001:321, CAP-D12-009 is "Operational approvals (.1) maker-checker on … payment release". Payout tracking is CAP-D13-016 / CAP-D13-005 (.2), as in PRD-013 FR-D13-020. | Cite CAP-D13-016 and CAP-D13-005 (.2). Check whether CAP-D12-009 still belongs in the WF-011 Capabilities row. |
| 3 | Minor | LOOP_STATE.md:154–162 | The new BA-005 tracking list (round-1 finding 11) is missing two items. (a) D-41: the Senior Fund Accountant approves manual journals, and above a tenant-set amount the Head of Fund Accounting also approves (PRD-010 FR-D10-019, §7). BA-005 §4 has no journal permission. (b) BA-005 §4:190 `operations.payout.release` is still tied to WF-011, which D-52 makes obsolete (see finding 1). Also, the lead sentence says "D-28…D-59", but the list includes D-60 and D-75. | Add (a) and (b). Change the range to "D-28…D-75" or drop it. |
| 4 | Minor | LOOP_STATE.md:13 | "Next free numbers: … owner question Q61" is now stale: this PR uses Q61 and Q62 (LOOP_STATE:171–172). The next run could reuse an ID, which GOV-001 forbids. | Change it to "owner question Q63". |
| 5 | Minor | BA-004:397 | The WF-008 outsourced-accounting variant still describes the mirror only generally and carries an [ASSUMPTION]. It does not reflect D-40 (load the custodian books daily; recheck accruals, unit capital and NAV; no full shadow ledger), which PRD-010 FR-D10-024 and C6 now apply. The [ASSUMPTION] itself covers the monthly sign-off, which D-40 does not answer, so keeping it is acceptable. | Add the D-40 wording to the variant. Keep the [ASSUMPTION] only for the monthly sign-off. |
| 6 | Nit | commits f1a1be7, 1596198, 9158a5b | The trailer is still `Co-Authored-By: Claude <noreply@anthropic.com>`. This is the same open Nit carried from Steps 8–9d round 1 (it is the loop prompt's wording). | Leave it as the loop records it, or align it with the current attribution. |

**Round-1 findings, one by one (at 34cf5ab..9158a5b):**
1. **Resolved.** BA-004:690, WF-018 Approvals now says every instruction needs a second approver (D-31, FR-D07-017, BRL-D07-007).
2. **Resolved for the cited lines.** BA-004:362 now uses D-44. :481, :484 and :487 now use D-52, but the diagram at :496 was missed (finding 1 above). :725 and :729 now use D-27, with [VAL] kept only for legal retention.
3. **Resolved.** PRD-011:108 BRL-D11-009 now says "[DES]; values set by each AMC (owner decision D-46)".
4. **Resolved.** The GOV-006 Step 9 cell is 🔄. The Deliverables cell now says "PRD-000 re-keying note — stays Draft until a replacement is Approved (D-66)".
5. **Recorded** as owner question Q62 in LOOP_STATE, with the default "note lists remaining parts".
6. **Resolved.** BRL-D01-010 is split into downgrade/lapse (D-26) and offboarding (D-27). The export right in FR-D01-028 is now [DES].
7. **Resolved.** PRD-007:69 marks "before the cost is booked" [DES]; PRD-007:162 marks "Operations Analyst records the facts" [DES]; PRD-009:165 marks the proposer and approver [DES], with only "path is a tenant setting" cited to D-37; PRD-012:198 says "Fund Accounting (D-50)", with the Head of Fund Accounting [DES].
8. **Resolved.** `settlement.fail.record_cause` is in §7 and C6. The US-D07-003 goal is reworded for D-31.
9. **Resolved.** D-54 is removed from the PRD-017 header. FR-D17-023 now says only AI requests counted as API calls are metered; token and spend limits are internal controls [DES].
10. **Recorded** as owner question Q61. The default reading (a) is marked [ASSUMPTION … Q61] in the same words at PRD-013:227, PRD-013:299 and PRD-016:90.
11. **Resolved, with gaps.** The tracking list was added to LOOP_STATE (finding 3 above).
12. **Resolved.** PRD-006 §7: the new rows are now sub-items of CAP-D06-003 and CAP-D06-004, in capability order.
13. **Open** (Nit 6 above).

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "49 spec documents checked; 0 problem(s)." |
| Arithmetic re-computed | Not applicable: neither the full change nor the round-2 fixes add derived numbers, rates or money examples. |
| Sources | No new external source or regulatory fact. The [VAL] labels on D-30, D-57 and D-64 are unchanged from round 1. The new [ASSUMPTION] labels (Q61) and [DES] labels are correct by type. The cited external source texts were not opened (no new ones were added). |
| Scope vs GOV-006 step | D-26…D-66 are applied in the PRDs named in LOOP_STATE:9/:11, and D-73/D-75 in PRD-017. Each D-number in LOOP_STATE:96–145 matches the PRD text checked. Remaining gap: D-52 in PRD-012 and the WF-011 diagram (finding 1). The GOV-006 row change is limited to the Step 9 table cells. |
| Round-1 fixes diff (34cf5ab..9158a5b) | 12 files changed plus reviews/STEP-09d_round1.md. All edits trace to round-1 findings. No unrelated changes. |
| Front matter / versions | 16 spec documents bumped (15 × 0.1→0.2, PRD-001 0.2→0.3). Status stays Draft. PRD-000 has no front matter, as on main. The GOV-001 §7 register needs no change. |
| Instruction injection | None found in the changed documents, commit messages or LOOP_STATE. |
| Working tree | Clean. No files were changed by this review. |

### Not checked
- CI status and the merge-gate result: no PR number or CI run was available, so only the local branch was reviewed.
- BA-005 §3/§4 was not compared cell by cell against every † row in all 14 PRDs. Only the D-41, D-42, D-52 and D-32 rows were checked.
- Whether any AMC OS-released payout other than investor payouts remains in D12 (this decides whether `operations.payout.release` is still needed) could not be settled from the documents alone.
- D-72 and D-74 were not checked as PRD changes. They are recorded for Step 10.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
