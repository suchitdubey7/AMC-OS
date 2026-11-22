## AMC OS Review Agent — advisory review

**PR:** branch `proposal/adr-0020-schema-moves-db-roles` (vs `origin/wp4-step15-canonical-data-model`), round 3 · **Step / WP:** none of its own. This is an owner-requested Draft ADR-0020 that collects the items EA-003 §7, EA-005 §9, EA-007 §13 and DA-001 §8 deferred to it (WP4, before Step 16). · **Reviewed at:** 4f39ef15fe87bf4a7c02f7b87a5cf7ca6b1e3f77

**Verdict (advisory):** RECOMMEND MERGE AFTER FIXES
All 8 round 2 findings are fixed, and I confirmed the Blocker fix (`pg_temp` last) on PostgreSQL 16.15. The new findings are three Minors and two Nits. They are wording and ordering details that Step 16 should not have to guess.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Minor | ADR-0020:100, :216, :24; DDL-000:902-903, :1473-1474 | **New (from the round 2 finding 2 fix).** Part 6.4 lists `valuation.price` as an insert-only table and says "`UPDATE` stays refused for every role". Validation test 8 repeats this for "each insert-only table listed in part 6.4". But DDL-000's `price_immutable` trigger is `BEFORE DELETE` only. `amc_app`'s `UPDATE` on `valuation.price` is not revoked either. So prices can be updated today, and test 8 would fail for that table. Line 24 also speaks of "seven insert-only tables" (the `UPDATE` revokes), while part 6.4 lists ten. | Say "`UPDATE` behaviour is unchanged" (refused where DDL-000 refuses it today), or decide here whether `valuation.price` becomes fully insert-only. Then make line 24 and test 8 match. |
| 2 | Minor | ADR-0020:131 (part 9.3) | **New (from the round 2 finding 4 fix).** The text says the provisioning function drops the login, and a second function then ends "sessions whose user is a member of `amc_breakglass`". I tested this on PG 16.15. After `DROP ROLE`, the open session keeps running. In `pg_stat_activity` its `usename` becomes NULL, and `pg_has_role(usesysid, 'rv_bg', 'member')` returns false. The session-ending function therefore cannot find that session once the login has been dropped. The data risk is low. In the same test, the leftover session got "permission denied" on its next query, and the expiry check in the policy also blocks it. But the cleanup step as written does not do what it says. | Set the order explicitly: `ALTER ROLE … NOLOGIN`, end that login's sessions, then `DROP ROLE`. Add this to Validation test 4: no session of the dropped login remains. |
| 3 | Minor | ADR-0020:97, :100 | **New (from the round 1 finding 6 wording).** The procedure "removes **all** of one tenant's rows in every schema". The trigger, however, needs the tenant's approved `platform.tenant_removal_authorisation` row for every protected row it deletes. Also, DA-000 §6 ends offboarding with tenant status `ARCHIVED`, so the `platform.tenant` row is kept. As worded, the scope could include deleting the authorisation row before the protected rows (which would make every later delete fail) and deleting the registry row. | Say that the `platform.tenant` row (set to `ARCHIVED` by the Tenant module) and the authorisation row are kept, or are removed last in a separate, named step. |
| 4 | Nit | ADR-0020:129 | "PostgreSQL stores a pre-computed verifier as given." I confirmed this on PG 16.15 with a valid verifier. A malformed `SCRAM-SHA-256$…` string, however, was hashed and stored as if it were a plain password, with no error. | Have the provisioning function check that the input is a well-formed SCRAM verifier and reject anything else. |
| 5 | Nit | ADR-0020:182 | "22 module roles plus about ten system, tool and break-glass roles". The ADR names 12 non-module roles: `amc_tenant_scoped`, two `amc_sys_*`, three audit/removal owners, three break-glass roles, two tool logins and `amc_migration_owner`. It also implies per-module pool logins (part 2.3, one per process role per module, up to 44), which the count leaves out. | Give the exact count and mention the pool logins. |

**Round 2 findings:**
- **1 (Blocker): fixed.** Part 7.2 now requires `SET search_path = pg_catalog, <schema>, pg_temp` and names written with their schema, and test 9 has the temporary-table case. I re-ran the attack on PG 16.15 with `pg_temp` last: the insert went into the real table and the caller's temporary table stayed empty.
- **2 (Major): fixed.** All 10 tables guarded by `tg_immutable()` are listed and match DDL-000 :280, 504, 675, 721, 862, 902, 977, 979, 1099, 1410. The exception sits in the shared trigger and checks the authorisation row, not a session flag. Test 8 and the DM-17 follow-up were updated. Finding 1 above is a side effect of this fix.
- **3 (Minor): fixed.** The text now says "ten parts". Every part cross-reference (2.2, 2.6, 3.2, 5, 6, 6.4, 7, 7.1, 9, 9.1, 9.4, 10) points to the right section.
- **4 (Minor): fixed.** `amc_login_platform_tools` and `amc_login_breakglass_tool` are named, `amc_breakglass_session_admin` owns the session-ending function, and the execute grant is stated. The two logins are excluded from module roles, `amc_tenant_scoped` and owner roles.
- **5 (Minor): fixed.** Both functions take the tenant ID as a parameter, set the context, and only then check the record.
- **6 (Minor): fixed.** The D16 exception is in part 2.2, the extract worker has "no write grant at all", and `amc_sys_extract` is in test 1.
- **7 (Minor): fixed.** Only a verifier is passed to the database, and the secret is generated outside it. Verified on PG 16.15 that a valid verifier is stored exactly as given.
- **8 (Nit): fixed.** The test snippet is now marked as simplified, with the status condition named.

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | "81 spec documents checked; 0 problem(s)." `pytest tests/governance`: 14 passed (re-run locally). Front matter is correct (status Draft, ID matches the file name). The GOV-001 §7 register row is present. All three commits carry a Co-Authored-By trailer. Working tree is clean. |
| Arithmetic re-computed | No financial figures. Counts: "ten parts" is correct. 10 DELETE-guarded tables match DDL-000. 7 `UPDATE` revokes in DDL-000 (:1473-1474), which conflicts with the "insert-only" wording (finding 1). 12 named non-module roles vs "about ten" (finding 5). |
| Sources | DDL-000 re-checked: `tg_immutable()` (:114-119); `price_immutable` is `BEFORE DELETE` only (:902); grants and revokes (:1462-1476); tenant status CHECK (:80, no `MIGRATED_OUT` yet, which matches the ADR's reference to DM-16); DA-001 DM-16 and DM-17 (:778-779); DA-000 §6 offboarding ends `ARCHIVED` (:622). PG 16.15 scratch tests (database `rv_adr20_r3` and `rv_*` roles, all dropped afterwards; confirmed none remain): `pg_temp`-last fix works; a dropped login's open session loses membership in `pg_stat_activity` (finding 2); valid SCRAM verifier stored as given, malformed one hashed as a password (finding 4). PostgreSQL documentation URLs: source not opened. The claims match the behaviour I observed. |
| Scope vs GOV-006 step | Unchanged from round 2. The union of EA-003 §7, EA-005 §2/§2.1/§6/§9, EA-007 §13 and DA-001 §8 is covered. EA-004 §11 is sent explicitly to the ADR-0003 revision. O1 and O2 are left open on purpose. No domain is dropped. There is no GOV-006 step of its own (owner-requested proposal). |

### Not checked
- I did not test a full mock of the trigger exception (`current_user` = removal role plus an RLS-protected authorisation lookup inside `tg_immutable()`). Round 2 confirmed `current_user` behaviour inside non-definer triggers.
- PgBouncer transaction mode (test 11) and PG 16 `CREATEROLE` side effects on `amc_breakglass` itself were not tested.
- No CI status is available for this local branch.
- Whether `proposal/` branches outside the GOV-008 chain are allowed was not checked. The ADR says the owner requested it.
- I found no instruction-injection content in the change, including the two committed review files.

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
