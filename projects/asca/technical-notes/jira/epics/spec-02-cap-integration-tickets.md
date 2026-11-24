# ASCA Spec 02 — CAP Integration — JIRA Ticket Draft

## Document Info

| | |
|---|---|
| **Document type** | JIRA Ticket Draft |
| **Date** | 2026-09-28 (Created) · 2026-10-13 (Updated — Round-3 02c feedback, real JIRA keys, 02d repurposed to decommission) · 2026-10-13 (02c signed off + promoted (REF-CAP-15); Spec 01 CR raised as ASCA-66/67/68) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Partially created — **02a/02b epics + stories exist in JIRA (ASCA-37–50); 02c/02d epics NOT yet created** (drafted below) |
| **Audience** | Dev team (Noel, Throy), Patrick-san (SDM), Kuroda-san (PM) |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) |
| **Related** | `projects/asca/documentation/asca-development-workflow.md` (JIRA structure); `projects/asca/specs/` (requirements drafts); `docs/asc-projects-master-timeline.md` (schedule) |

---

## Purpose

Track the JIRA tickets for ASCA Spec 02 (CAP Integration), split into 4 sub-specs. Per the dev workflow (**1 Epic = 1 Spec**), each sub-spec gets **its own epic** with the standard 6-story set.

**All four Spec 02 epics + their stories now exist in JIRA.** 02a (ASCA-37) and 02b (ASCA-44) were created earlier; **02c (ASCA-52) and 02d (ASCA-59) were created on 2026-10-13** from this doc. The **Spec 01 change-request** has also been raised — **ASCA-66 / ASCA-67 / ASCA-68** under ASCA-18 (`log_alloc_bundle_outcomes` + `effective_from` + run-status/view). **02c is signed off (REF-CAP-15, 2026-10-13) and promoted to the code repo.**

## Current status (as of 2026-10-13)

| Sub-spec | Epic | Stories | G1 (Kuroda-san) | Where it stands |
|---|---|---|---|---|
| **02a** CAP Core Injection | **ASCA-37** ✅ created | ASCA-38–43 ✅ created | ✅ **signed off** (2026-10-05) | Requirements promoted to code repo (ASCA-38 branch). **design.md generated + committed 2026-10-12** (ASCA-39, not yet pushed). Design surfaced 3 Spec 01 extensions — **Kuroda-san approved the change-request 2026-10-13**; tasks.md next (run manually). |
| **02b** Refund Allocation | **ASCA-44** ✅ created | ASCA-45–50 ✅ created | ✅ **signed off** (2026-10-05) | req+design+tasks complete; **coding in progress (ASCA-47, Cristoff)**. CIP-refund home still open (REF-CIP-07 identification resolved; home TBD). |
| **02c** AllocationDetail CSV | **ASCA-52** ✅ created 2026-10-13 | ASCA-53–58 ✅ created | ✅ **signed off 2026-10-13** (REF-CAP-15) | Epic + stories created. Requirements signed off + **promoted to code repo**. Next: G2 (design/tasks). |
| **02d** DataCorrection **Decommission** | **ASCA-59** ✅ created 2026-10-13 | ASCA-60–65 ✅ created | ✅ **confirmed repurposed** (Kuroda-san 2026-10-05) | **Repurposed from injection → decommission `DataCorrectionCommand`.** Low priority. Epic + stories created. |

> **All Spec 02 stories (ASCA-37–65) are currently "To Do" / Unassigned** in JIRA (02a/02b confirmed 2026-10-13; 02c/02d created 2026-10-13). Assignees in the tables below are the intended owners, not yet set in JIRA.

## Conventions (from the dev workflow)

- **1 Epic = 1 sub-spec.** Story titles prefixed `[Spec 02x] —` so the sub-spec is identifiable from the title.
- **Standard story set (6):** Requirements + Sign-off (G1) · Architecture/Design+Tasks (G2) · Coding · Code Review (G3) · Dev/Manual Testing · QA Testing.
- **Repo:** all Spec 02 work is in `accounting_related_system_for_freee` (single repo — unlike Spec 01 which spanned two). **Exception:** the `log_alloc_bundle_outcomes` table + `effective_from` seeder fix are a **Spec 01 change-request in `ls-database-migrations`** (see below).
- **Author/gate order:** 02a → 02b → 02c → 02d.
- **Branch per sub-spec:** `feature/ASCA/ASCA-{story}-spec02{a,b,c,d}-...` targeting `feature/ASCA/ASCA-master`.
- **Next free key:** **ASCA-51** (ASCA-50 is the highest Spec 02 key in use as of 2026-10-13).

## Cross-cutting dependencies (note on every epic)

1. **Spec 01 Foundation merged** — provides the engine (`allocate` / `allocateForCharge`), `log_alloc_*` / `mst_alloc_*` tables, enums, run lifecycle, reference-price seeder. Spec 02 only *calls* the engine. ✅ merged to `feature/ASCA/ASCA-master`.
2. **DEVOPS 6415 + 6596 in the ASCA base** — 02c rides the extracted `ArchiverService`/`MailerService`. ✅ Released to prod 2026-09-28 and **merged `main` → `feature/ASCA/ASCA-master` on 2026-10-01**.
3. **02a is the prerequisite** for 02b / 02c. (02d no longer depends on 02a — it decommissions a command rather than injecting allocation.)
4. **Spec 01 change-request (`log_alloc_bundle_outcomes` + run-status extension + `effective_from`)** — needed by **both 02a and 02c**. **Approved by Kuroda-san 2026-10-13.** Raised as a small additive change-request in `ls-database-migrations` (ls-db migration + model + structure test) plus the accounting-repo `RunStatus` enum + view/V-5 changes. See the dedicated section below.

---

## Epic 1 — [Spec 02a] — CAP Core Injection — ✅ ASCA-37 (created)

**Epic:** [ASCA-37](https://bizmates.atlassian.net/browse/ASCA-37) · **Requirements draft:** `projects/asca/specs/asca-spec-02a-cap-core-injection/requirements.md` (promoted to code repo)
**Scope:** Inject `RevenueAllocationService::allocate()` into `CommonUtil::createDailyRateCalculation()` (Option 1 overwrite N→P, step [b] between existing [a]/[c]), CAP detection (plans 1016–1027), per-pair atomic write + failure isolation (completed-with-errors). Covers Pre + Final. The prerequisite spine.

| Key | Story | Assignee | Gate | Status |
|---|---|---|---|---|
| [ASCA-38](https://bizmates.atlassian.net/browse/ASCA-38) | [Spec 02a] — Requirements + Sign-off | PM (Kuroda-san) | G1 | ✅ signed off 2026-10-05 |
| [ASCA-39](https://bizmates.atlassian.net/browse/ASCA-39) | [Spec 02a] — Architecture (Design + Tasks) | Lead (Noel) | G2 | design.md committed 2026-10-12; tasks.md next |
| [ASCA-40](https://bizmates.atlassian.net/browse/ASCA-40) | [Spec 02a] — Coding | Dev (Throy) | — | To Do |
| [ASCA-41](https://bizmates.atlassian.net/browse/ASCA-41) | [Spec 02a] — Code Review | Lead (Noel) | G3 | To Do |
| [ASCA-42](https://bizmates.atlassian.net/browse/ASCA-42) | [Spec 02a] — Dev/Manual Testing | Lead (Noel) | — | To Do |
| [ASCA-43](https://bizmates.atlassian.net/browse/ASCA-43) | [Spec 02a] — QA Testing | QA (Glenn) | — | To Do |

**Notes:** G1 signed off. The **design surfaced three Spec 01 extensions** (per-bundle failure isolation, REF-CAP-13 #2): (1) `COMPLETED_WITH_ERRORS` run status + `finalizeWithErrors()`, (2) `log_alloc_bundle_outcomes` table, (3) reference-price `effective_from` → 2026-12-01. **Kuroda-san approved the change-request on 2026-10-13** — see the Spec 01 CR section. Round-3 (REF-CAP-14 #1) adds that the view/V-5/supersede must treat completed-with-errors as an active Final; this lands in the same run-status extension and must be stated in 02a (Req 4) and 02c. **Also from Round-3 (REF-CAP-14 #2):** CIP must write **no** outcome row and never appear in the CSV — adjust 02a Req 2.5 (confirm whether the engine filters CIP before bundling). Open item O-A (App Freee-mapping rows) to verify before go-live — data, not code.

---

## Epic 2 — [Spec 02b] — Refund Allocation — ✅ ASCA-44 (created)

**Epic:** [ASCA-44](https://bizmates.atlassian.net/browse/ASCA-44) · **Requirements draft:** `projects/asca/specs/asca-spec-02b-refund-allocation/requirements.md`
**Scope:** Negative-N via REF-CAP-09 — same pipeline, true floor toward −∞, execution-month lump, cooling-off (90%)/tax-exemption/shareholder cashback, refund→bundle pairing (Req 9 — `log_refund_history` linkage), atomic Coaching+App write. CAP-only (CIP uses no engine).

| Key | Story | Assignee | Gate | Status |
|---|---|---|---|---|
| [ASCA-45](https://bizmates.atlassian.net/browse/ASCA-45) | [Spec 02b] — Requirements + Sign-off | PM (Kuroda-san) | G1 | ✅ signed off 2026-10-05 |
| [ASCA-46](https://bizmates.atlassian.net/browse/ASCA-46) | [Spec 02b] — Architecture (Design + Tasks) | Lead (Noel) | G2 | To Do |
| [ASCA-47](https://bizmates.atlassian.net/browse/ASCA-47) | [Spec 02b] — Coding | Dev (Throy) | — | To Do |
| [ASCA-48](https://bizmates.atlassian.net/browse/ASCA-48) | [Spec 02b] — Code Review | Lead (Noel) | G3 | To Do |
| [ASCA-49](https://bizmates.atlassian.net/browse/ASCA-49) | [Spec 02b] — Dev/Manual Testing | Lead (Noel) | — | To Do |
| [ASCA-50](https://bizmates.atlassian.net/browse/ASCA-50) | [Spec 02b] — QA Testing | QA (Glenn) | — | To Do |

**Notes:** G1 signed off (Round-2 edits applied — cooling-off = 90% refund, overlap-produces-no-refund removed, numeric acceptance cases added). Risk-carrying sub-spec. **CIP-refund home still open:** REF-CIP-07 resolved identification (shareholder via `trn_receipt_locked_charge`, else fixed ratio `App = FLOOR(refund × 3,980 / 75,900)`), but whether CIP-refund handling lives here (currently CAP-only), in a new sub-spec, or in ASCI is **on hold** pending the Lead/PM scope decision. Known dependency to record: `trn_receipt_locked_charge` was built to hide charges from receipts — detection breaks if other flows start writing to it.

---

## Epic 3 — [Spec 02c] — AllocationDetail CSV — ✅ ASCA-52 (created 2026-10-13)

> **Created 2026-10-13.** Epic + 6 stories created in dependency order. ✅ **G1 signed off 2026-10-13 (REF-CAP-15) + requirements promoted to the code repo.** Next phase: G2 (design + tasks) via the spec UI. All stories "To Do" / Unassigned (assignees below are intended owners, not yet set in JIRA).

**Epic:** [ASCA-52](https://bizmates.atlassian.net/browse/ASCA-52) · **Requirements draft:** `projects/asca/specs/asca-spec-02c-allocation-detail-csv/requirements.md`
**Scope:** `allocationDetailFile` config in `config/const.php` + `RevenueAllocationCsvService::createAllocationDetailFile($targetYm, $preFlg)`; add one file to `$fileNameList` via the extracted `ArchiverService`/`MailerService`, guarded per-run-type by `hasCompletedRun()`. 18-column breakdown reading **two sources, same run** — allocated rows from `log_alloc_prorations`/`v_alloc_prorations_active`, skipped/failed rows from `log_alloc_bundle_outcomes`. No new email/mail template/command. Reporting only.

| Key | Story | Assignee | Gate |
|---|---|---|---|
| [ASCA-53](https://bizmates.atlassian.net/browse/ASCA-53) | [Spec 02c] — Requirements + Sign-off | PM (Kuroda-san) | G1 |
| [ASCA-54](https://bizmates.atlassian.net/browse/ASCA-54) | [Spec 02c] — Architecture (Design + Tasks) | Lead (Noel) | G2 |
| [ASCA-55](https://bizmates.atlassian.net/browse/ASCA-55) | [Spec 02c] — Coding | Dev (Throy) | — |
| [ASCA-56](https://bizmates.atlassian.net/browse/ASCA-56) | [Spec 02c] — Code Review | Lead (Noel) | G3 |
| [ASCA-57](https://bizmates.atlassian.net/browse/ASCA-57) | [Spec 02c] — Dev/Manual Testing | Lead (Noel) | — |
| [ASCA-58](https://bizmates.atlassian.net/browse/ASCA-58) | [Spec 02c] — QA Testing | QA (Glenn) | — |

> **Note on keys:** the earlier draft proposed ASCA-51–57, but **ASCA-51 was already taken** by an unrelated ticket ("Script creation for Student Attendance for Testing"), so JIRA assigned the epic ASCA-52 and stories ASCA-53–58.

**Dependencies:** 02a merged (the CSV reads the rows a completed run produced, incl. the per-bundle skip/fail rows 02a writes); DEVOPS-6415 (ArchiverService/MailerService) ✅ in base; **`log_alloc_bundle_outcomes` table (Spec 01 CR — approved 2026-10-13)** must land before coding.

**Round-3 feedback to fold in before sign-off (REF-CAP-14, 2026-10-13):**
1. **Completed-with-errors must be "active" in the Spec 01 view** — `v_alloc_prorations_active` + V-5 active-Final rule + supersede step currently only accept `status = Completed`; they must treat completed-with-errors as active, else the CSV shows exception rows but no allocated rows (and a re-run could surface an older run's rows). Lands in the Spec 01 run-status extension; stated in 02a/02c. ASCA-34 touches the same view (handle together).
2. **CIP writes no outcome row and never appears in the CSV** — adjust 02a Req 2.5; confirm whether the engine filters CIP before bundle formation.
3. **Req 2.12 exception-row columns** — fill プロダクトタイプ / プロダクトID / 部署ID / 契約種類 from the same daily-rate log row already read for 元金額.
4. Minor: fix the "approved 2026-10-05" → **2026-10-08** in the 02c staging note + Dependencies.

---

## Epic 4 — [Spec 02d] — DataCorrection **Decommission** — ✅ ASCA-59 (created 2026-10-13)

> **Created 2026-10-13.** Epic + 6 stories created in dependency order. **Repurposed from injection → decommission.** Confirmed by Kuroda-san 2026-10-05: `DataCorrectionCommand` is unused in operation (Wu-san 08-28; corrections go through Redmine → DevOps manual SQL with post-allocation amounts). 02d is **no longer an allocation injection** — it **disables + deprecates the command** (fail fast with a deprecated message). Low priority. ADR + usage note: `projects/asca/documentation/ASCA-ADR-20261005-datacorrection-decommission.md`, `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md`.

**Epic:** [ASCA-59](https://bizmates.atlassian.net/browse/ASCA-59) · **Requirements draft:** `projects/asca/specs/asca-spec-02d-datacorrection-integration/requirements.md` (folder name retained; scope repurposed)
**Scope:** Disable + deprecate `DataCorrectionCommand` — the command fails fast with a deprecated message rather than running. **No** `allocateForCharge()` injection. Smallest sub-spec; low priority.

| Key | Story | Assignee | Gate |
|---|---|---|---|
| [ASCA-60](https://bizmates.atlassian.net/browse/ASCA-60) | [Spec 02d] — Requirements + Sign-off | PM (Kuroda-san) | G1 |
| [ASCA-61](https://bizmates.atlassian.net/browse/ASCA-61) | [Spec 02d] — Architecture (Design + Tasks) | Lead (Noel) | G2 |
| [ASCA-62](https://bizmates.atlassian.net/browse/ASCA-62) | [Spec 02d] — Coding | Dev (Throy) | — |
| [ASCA-63](https://bizmates.atlassian.net/browse/ASCA-63) | [Spec 02d] — Code Review | Lead (Noel) | G3 |
| [ASCA-64](https://bizmates.atlassian.net/browse/ASCA-64) | [Spec 02d] — Dev/Manual Testing | Lead (Noel) | — |
| [ASCA-65](https://bizmates.atlassian.net/browse/ASCA-65) | [Spec 02d] — QA Testing | QA (Glenn) | — |

**Notes:** Created with the full 6-story set to match the 02a/02b/02c shape. Low priority — schedule after 02a/02b/02c. No dependency on 02a. G1 scope already confirmed (repurposed scope agreed by Kuroda-san 2026-10-05) — the Requirements story (ASCA-60) is largely a formality. If the Lead prefers to collapse the testing/review stories for such a small change, close the unused ones rather than leaving them open.

---

## Spec 01 change-request — `log_alloc_bundle_outcomes` + run-status extension + `effective_from` (✅ approved + ticketed 2026-10-13)

**Not a Spec 02 epic** — a small additive change-request against the **merged** Spec 01 Foundation (same motion as ASCA-34). Needed by **both 02a and 02c**. **Approved by Kuroda-san 2026-10-13; raised as ASCA-66 / ASCA-67 / ASCA-68 under ASCA-18.**

Three parts, raised as **three sub-tasks under ASCA-18** (same motion as ASCA-34), all created 2026-10-13:
1. **[ASCA-66](https://bizmates.atlassian.net/browse/ASCA-66) — `log_alloc_bundle_outcomes` table** (ls-db) — new migration + structure test, `bizmates_mysql`, bundle-keyed (Option A). One row per skipped (V-3) / failed (pair-level) bundle with its reason. Money table `log_alloc_prorations` stays money-only. Schema: `ASCA-PROPOSAL-20261008-skipped-failed-bundle-recording.md` §7.
2. **[ASCA-68](https://bizmates.atlassian.net/browse/ASCA-68) — Run-status extension** — add `COMPLETED_WITH_ERRORS` to `RunStatus` + `RunLifecycleService::finalizeWithErrors()` (accounting), **plus (REF-CAP-14 #1)** `v_alloc_prorations_active` / V-5 active-Final rule / supersede step treating completed-with-errors as an active Final (ls-db view). Overlaps **ASCA-34** (same view) — handle together.
3. **[ASCA-67](https://bizmates.atlassian.net/browse/ASCA-67) — Reference-price `effective_from` → 2026-12-01** — ⚠️ in the **accounting repo** `ReferencePriceSeeder.php` (NOT ls-db — steering says ls-db; doc/code discrepancy flagged in the ticket), so the first close (`target_ym = 2026-12`) resolves a price instead of leaving December CAP revenue 100% on Coaching.

> **All three created 2026-10-13 as sub-tasks under ASCA-18.** All three block 02a/02b completion.

---

## Creation checklist

- [x] **02c:** epic + 6 stories created 2026-10-13 — ASCA-52 (epic), ASCA-53–58 (stories). ✅ **G1 signed off 2026-10-13 (REF-CAP-15) + promoted to the code repo.**
- [x] **02d:** epic + 6 stories created 2026-10-13 — ASCA-59 (epic), ASCA-60–65 (stories). Scope = decommission.
- [x] Each epic linked to its stories via the `parent` field (matches the ASCA-37/44 pattern).
- [x] **Spec 01 CR:** raised as ASCA-66 (`log_alloc_bundle_outcomes`, ls-db) + ASCA-67 (`effective_from`, accounting) + ASCA-68 (run-status + view-active, accounting + ls-db view) under ASCA-18. All three block 02a/02b.
- [ ] Set assignees on the created stories (currently all Unassigned).
- [ ] Record the created keys into the master timeline (`docs/asc-projects-master-timeline.md`).
- [ ] Consider whether 02d's 6-story set should be trimmed for such a small change (close unused stories rather than leave them open).

> Follow-up JIRA writes (assignees, the Spec 01 CR) still need explicit Lead confirmation per the toolkit workflow.
