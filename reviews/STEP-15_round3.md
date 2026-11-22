## AMC OS Review Agent — advisory review

**PR:** branch `wp4-step15-canonical-data-model` (base `404b975`) · **Step / WP:** GOV-006 Step 15 / WP4 · **Reviewed at:** bd6fac373f5afe363c9bcc8707a010d45a042f53

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
The fixes close all 11 round 2 findings meant to be fixed, including the Major. Finding 12 stays open on purpose. The fixes leave 2 new Minor gaps and 1 Nit, and none of them changes a decision.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | docs/05_data_architecture/DA-001_canonical_enterprise_data_model.md:144–145 (§3.1 rules 1–2) | The rewrite fixed round 2 finding 1 but left a gap. Rule 1 now covers only "BT entity that other rows point at by foreign key". Rule 2 covers only tables "keyed by a business key plus a date or a validity period". Several §4 BT tables are keyed by their own ID alone and DA-001 does not say that anything points at them, so neither rule clearly applies. Examples: `master.credit_rating` (`rating_id`, :287), `investor.consent` (`consent_id`, :577), `investor.bank_account`, `workflow.delegation`, `identity.approval_authority`, `investment.restricted_list_entry`, `distribution.kyd_record`. A key of `(tenant_id, <id>)` alone allows only one row, so these tables cannot hold versions unless rule 1 applies to them. Before the rewrite, rule 1 ("keyed by its own ID") covered them. | In rule 1, say "BT entity keyed by its own ID, or one that other rows point at by foreign key". Alternatively, state that every BT row in §4 with an ID-only key uses the anchor-plus-version pattern. |
| 2 | Minor | DA-001:771 (DM-9); architecture/erds/D13_investor.md:87–95; INT-001 §5 (:185) and IN6 (:176) | The fallback for RTAs that send no record version is now `rta_record_ref` = the file's business date, and a record whose content hash equals the current one counts as a replay. Round 2 finding 5 is fixed. DM-9 does not say what happens when the key matches but the content hash differs, for example when a corrected file arrives for the same business date. Read literally, "an exact replay is refused" would drop it or fail the load. INT-001 IN6 says a correction is applied "as a correction with its own approval rules … never as a silent overwrite". Also, INT-001 §5 keys on "record reference + business date (+ provider version where sent)", but DM-9 keys on the version *instead of* the business date when a version exists. That is a small difference from the cited source. | Add to DM-9: "same key with a different content hash → the IN6 correction path (exception and task), never refused silently or overwritten". Either keep the business date in the key as INT-001 §5 does, or state why the version alone is enough. |
| 3 | Nit | DA-001:146 (§3.1 rule 3) | Rule 3 gives "folio number, ARN" as examples of business codes on BT entities. In §4, `investor.folio` is MU (:556) and `distribution.distributor` is SM (:591), not BT. So the plain `UK` markers in D13 (`folio_number`) and D14 (`arn`) are correct, but the rule's examples suggest otherwise. | Use BT examples (ISIN, PAN keyed hash, and an account or issuer code), or drop folio number and ARN. |
| 4 | Nit | commits 3949608, 160e03f, bd6fac3 | The trailer is still `Co-Authored-By: Claude <noreply@anthropic.com>`. This is round 2 finding 12, left open by design because the loop prompt requires this form. | No action unless the owner changes the rule. |

**Round 2 findings, status at bd6fac3**

| R2 # | Status | Evidence |
| --- | --- | --- |
| 1 Major (rule 2 false premise; `accounting.account`; `user_role` / `scope_attribute`) | Fixed | Rule 1 now covers BT entities that are foreign-key targets and names `accounting.account` and `identity.user_role`. It also says a trigger check runs "in addition to the foreign key, never instead of it". In §4 (:455), `account` is keyed on `account_code` with versions `(account_code, valid_period, recorded_at)`, which matches DDL-000:916, 917 and 969. D10 draws `ACCOUNT ||--o{ JOURNAL_LINE`, with `parent_code FK` and `account_code FK`, and the D10 note is reworded. DM-12 is aligned. `user_role` gets a `grant_id` anchor. `scope_attribute` is keyed `(grant_id, attribute, value, valid_period)`, and D01 matches. The `grant_id` also matches the existing `ROLE_GRANTED.v1` / `ROLE_REVOKED.v1` payloads (checked in `contracts/events/`). The rule-coverage gap in finding 1 above is new. |
| 2 Minor (partial index on today) | Fixed | Rule 3 now uses the exclusion constraint `(tenant_id WITH =, <code> WITH =, valid_period WITH &&) WHERE (superseded_at IS NULL)`, and DM-1 is aligned |
| 3 Minor (`business_calendar`, `security_schedule`; `recorded_at` not shown) | Fixed | Both are named under rule 2. Rule 2 and the ERD legend both say these keys are shown without `recorded_at`. DDL-000 has no foreign key to `business_calendar` (checked: all `REFERENCES` targets listed) |
| 4 Minor (ERD anchors show changing columns; PAN `UK`) | Fixed | The legend in all 17 annexes now says the box merges the anchor and the current version. `pan_hmac UK` is removed from D13, and no ISIN or PAN `UK` remains in any ERD (grep) |
| 5 Minor (DM-9 fallback; `int` type) | Fixed, with residue | `rta_record_ref text` plus `content_hash` in §4, DM-9 and D13, and no `rta_record_seq` remains (grep). The residue is finding 2 above |
| 6 Minor (M3 list) | Fixed | M3 now names `settlement.instruction_effect` and the DDL-000 name `trading.order_state_transition` |
| 7 Minor (next free Q) | Fixed | LOOP_STATE gives the next free numbers as Q84 and DM-26. Q81–Q83 are registered at :217–219, and DM-25 is the highest DM in DA-001 |
| 8 Nit (DM-5 `(NEW)`) | Fixed | DM-5 says `from_state = '(NEW)'` |
| 9 Nit (`risk_alert_history`) | Fixed | Added to the §4 introduction list |
| 10 Nit (D09 heading; D10 line) | Fixed | The heading is now "Models, runs, alert thresholds and alerts", and D10 draws the line from `ACCOUNT` |
| 11 Nit (`plan_driver` key) | Fixed | §4 :629 gives `(plan_id, version_no, driver_code)`, which matches the ERD |
| 12 Nit (trailer) | Left open by design | See finding 4 above |

No instruction injection was found in the diff, the commit messages or the round 1 and 2 review files. LOOP_STATE contains the placeholder "round 3 pending", which was not counted as a finding, as instructed.

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "80 spec documents checked; 0 problem(s)." |
| `python3 -m pytest -q tests/governance` | 14 passed |
| Arithmetic re-computed | No money arithmetic in this change. Round 3 adds no §4 rows: `user_role`, `scope_attribute`, `account` and `plan_version`/`plan_driver` stay one row each, so the round 2 counts still hold (23 schemas; 67 DDL-000 + 270 N/M). DDL-000 `REFERENCES` targets were re-tallied by script. Of the BT tables §4 keys with `valid_period`, none is a foreign-key target in DDL-000. The only such target was `accounting.account`, which is now an anchor. |
| Sources | No market or regulatory facts are added. Checked against the source text: DDL-000:131–137 (`business_calendar` key), :208–220 (`user_role`), :910–917, :960–969 (`account` and `journal_line` keys). Also INT-001 §5 :185, IN6 :176 and the error table :250–253. Also `contracts/events/ROLE_GRANTED.v1` and `ROLE_REVOKED.v1` (`grant_id`, aggregate `identity.role_grant`). |
| Scope vs GOV-006 step | Unchanged since round 2. DA-001 and the ERD annexes D01–D17 cover all 17 domains and 23 schemas. The GOV-001 register row (:191) and the GOV-006 Step 15 cell are present. LOOP_STATE has the new chain row 22 and the owner-action row, and Step 16 is correctly held behind ADR-0020 (owner-only) and the 6-branch limit. |
| Governance / front matter | DA-001 front matter is unchanged (Draft; the ID matches the file name). Round 3 changes only DA-001, `architecture/erds/`, LOOP_STATE and `reviews/`, so no owner-only path is touched. |
| Mermaid | The changed annexes D01, D10 and D13 were rendered with the local `mmdc`. All 3 exit with code 0 and produce SVG output. |

### Not checked
- CI status for this branch: no network or `gh` use, as instructed. `scripts/merge_gate.py` was not run. G1 and G2 would fail while Steps 10–14 stay unmerged and Steps 10 and 13 contain owner-only files (known chain state).
- Annexes D02–D09, D11, D12 and D14–D17 were not re-rendered. Round 3 changed only their legend paragraph, which is outside the mermaid blocks, plus the D09 heading.
- Whether any new §4 table will hold a foreign key to the ID-keyed BT tables in finding 1: DA-001 does not list foreign keys table by table. That list is DBE-001 (Step 17).
- GOV-002…GOV-008, STD-001, QA-001 and the ADRs were not re-read in full in this round. Only the sections the fixes touch were checked.
- DDL-000 was not run against PostgreSQL. The exclusion-constraint and foreign-key claims rest on PostgreSQL rules and a reading of the text.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
