## AMC OS Review Agent — advisory review

**PR:** branch `step-01-vision-market` (base `main`) · **Step / WP:** GOV-006 Step 1 (WP2, Stage A items 2–3) · **Reviewed at:** `ee4731a29dc776e666de3c95be1f633a29f47f34`

**Verdict (advisory):** RECOMMEND CHANGES
A decision-driving market claim (KFin ≈32% / "two RTAs cover essentially all AUM") rests on a dead source and is contradicted by the one source opened; benchmark ratings and differentiator claims are largely unsourced yet presented as fact; the comparison silently omits 5 of 17 domains; and the PR alters out-of-scope items. No Blockers found.

### Findings
| # | Severity | File:line | Finding | Suggested fix |
| --- | --- | --- | --- | --- |
| 1 | Major | docs/01_product_strategy/PS-003_market_and_customer_analysis.md:31, :41, :91 | "KFin ≈ 32%" is unsourced in practice: [S6] (`tradebrains.in/?p=150222`) resolves to the Trade Brains homepage with no KFin/32% content. [S5] (opened, CAMS MD&A) supports "CAMS ≈ 68%" but states "The industry is dominated by three QRTAs" — so the implication at :41 "Two RTAs cover essentially all AUM → Building two RTA adapters (CAMS, KFin) covers the whole market", which drives INT-001 adapter priority, is not supported. | Cite a working source for KFin's share (e.g., KFin annual report), name the third QRTA and its MF relevance, or label :41 **[ASSUMPTION]** with confirmer (Product Manager). Fix S6 URL. |
| 2 | Major | docs/01_product_strategy/PS-004_benchmark_capability_comparison.md:32–47, :61–62 | Only ◐/○ ratings are labelled [ASSUMPTION] (:47); ● ratings are equally unsourced per cell. §4 asserts as fact that distribution/AMC-finance are "absent from benchmark positioning" (:62) and that "global platforms need" customisation (:61); PS-003:73 labels the same customisation claim **[ASSUMPTION]** — inconsistent labelling across documents for a claim supporting the differentiation decision. | Mark all unsourced cells [ASSUMPTION] or cite per cell; label §4 :61–62 [ASSUMPTION] with named confirmer. |
| 3 | Major | docs/01_product_strategy/PS-004_benchmark_capability_comparison.md:32–45 | Comparison covers D04–D06, D08–D11, D13–D17 but silently omits **D01, D02, D03, D07, D12**, contrary to GOV-001:85 and reviewer check §2.A. Settlement, fund operations and investment research are areas where benchmarks are likely strong, so the omission skews the "where AMC OS differs" conclusion. | Add rows for the missing domains or an explicit omission note with rationale. |
| 4 | Major | PS-002:8, PS-003:8, PS-004:8; GOV-001:149–151 | New docs tagged WP2, but GOV-005:14,:21 says WP2 starts only after WP1 documents are **Approved**, and GOV-001:137 states "Nothing is Approved yet". GOV-006:72 requires only the prior step merged. The governance documents conflict, and the commit does not state that it builds on Draft PS-001/GOV-006 as AGENTS.md:9 requires. | Owner decides which rule governs; update GOV-005; state Draft dependencies in the PR. |
| 5 | Major | PS-003:49–51 vs PS-001:72–74 | Segment table silently contradicts PS-001 §5.2: C2 first purchase differs, C1 drops risk; PS-003 ranks new AMCs first while PRD-000:59 ranks mid-size first. Reviewer check §2.E requires contradictions to be declared. | Align PS-001 §5.2 and PS-003 §3, or record that PS-003 supersedes PS-001 §5.2. |
| 6 | Minor | GOV-006:89, :18–23, :51 | Step 0 marked done while branch protection (part of Step 0) is pending; out of Step 1 scope. §1 still says WP1 unmerged and no CI; :51 still says "Stage A 1/10". | Mark "partly done"; refresh §1 and :51. |
| 7 | Minor | .github/workflows/ci.yml:6 | CI trigger change is outside Step 1 scope; with `pull_request` also present, PR branches now run CI twice. | Separate PR, or revert. |
| 8 | Minor | (branch name) | `step-01-vision-market` does not follow `wp<n>-<topic>` / `feat/<id>-<topic>` (AGENTS.md:26, GOV-003:52). | Rename or update convention. |
| 9 | Minor | PS-002:27–38 | No persona for D02 Product & Scheme Management (Head of Products) although mission begins "from scheme launch". | Add Head of Products row. |
| 10 | Minor | PS-002:53 | Attributes the customer mix to GOV-006 Q1; Q1 decided only "pilot → 3–5". | "(count: GOV-006 Q1; mix: [ASSUMPTION])". |
| 11 | Minor | PS-002:52–53 | 3-year target timeline not shown: go-live ≈ month 21–25 plus 9–18-month sales cycles makes 3–5 paying AMCs by month 36 tight. | Add short timeline or state the 3–5 includes the pilot. |
| 12 | Minor | PS-003:67,:73,:75; PS-004:26,:47,:64 | Several [ASSUMPTION]s lack a named confirmer; PS-003:75 unlabelled; PS-004:26 "mainly sell side" not in B7/B8. | Name confirmers; label or source. |
| 13 | Minor | PS-003:17,:32; PS-004:67–76 | [S7] press source not marked secondary; PS-004 marks none (B2 is trade press). | Mark press/aggregator sources secondary. |
| 14 | Minor | PS-004:23,:70; :25,:73; :74 | US$4.3 bn rests only on B2 (HTTP 403); B5 403; B6 URL 404. | Cite primary source for value; fix B6. |
| 15 | Minor | PS-002:38; PS-004:38,:41,:61; PS-003:52 | Unexplained jargon for business readers: CSCRF, IBOR/ABOR, ARN/EUIN, B30/T30, IDCW, SIF, QRTA, GIFT City funds. | Glossary line or link to BA-003. |
| 16 | Minor | GOV-005:20–21 | Status/outputs not updated (WP1 "In review", WP2 "Not started", PS-002–004 not listed). | Update GOV-005. |
| 17 | Minor | (commit message) | Completion report lacks AGENTS.md §5 items 4–7 and 12. | Provide all 12 items in PR description. |
| 18 | Nit | PS-001:79 | "roughly 40–100%": exact 20/51 = 39.2%, 50/51 = 98.0%. | Optionally "about 39–98%". |
| 19 | Nit | PS-002:19 vs PS-001:18 | Vision statement duplicated verbatim. | Single source in PS-002; PS-001 links. |

### Checks run
| Check | Result |
| --- | --- |
| scripts/check_docs.py | 24 spec documents checked; 0 problems (temporary worktree of the step branch). Front matter of PS-002–004 complete; no duplicate IDs; register updated. |
| Arithmetic re-computed | Decimal: SIP AUM 17,68,000 ÷ 83,38,858 = 21.20% ✓; 9,99,87,082 ≈ 10 crore ✓; top-10 81.7→76.3 ✓; AMC count 43→51 ✓; 20/51 = 39.2%, 50/51 = 98.0% (Nit 18). |
| Sources | Opened and matching: S1, S2, S3, S4, S5, S7, B1, B3, B4, B7, B8. Failed: S6 (homepage), B2 (403), B5 (403), B6 (404). No injection found. |
| Scope vs GOV-006 step | All three Step 1 items delivered; out-of-scope CI and Step 0 status changes; 5 domains missing from PS-004; D02 persona missing. |

### Not checked
GitHub CI and PR description (no PR existed); B2, B5, S6 content; accuracy of every ●/◐/○ rating; third QRTA's MF relevance; STD-001, QA-001, GOV-004 and most ADRs (no code/DB change in scope).

_This review is advisory. Only the project owner can merge (GOV-003, GOV-007)._
