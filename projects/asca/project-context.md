# ASCA — Project Context

> Load this at the start of each ASCA session.
> Also load `projects/ascm/project-context.md` for base ASC system context.
> If context gets compacted, re-read this file before continuing.

---

## Current State (as of 2026-10-15 — git-verified: 02a (ASCA-40)/66/67 MERGED to ASCA-master; 02c G2 complete (promoted); 02d promoted (G1 approved); 02b coding + ASCA-68 ls-db view half still open)

> **⚠️ Lead on leave 2026-11-11 → 2026-11-23.** Target: ASCA CAP Integration (02a–02d) **dev-complete + through G3 before Nov 11**. ASCI runs during/after the absence (delegate TBD — Orlino sub-lead / Patrick-san backstop). A Lead delegate for any G2/G3 landing Nov 11–23 must be named before leave.

- **ASCM Refactor (DEVOPS-6415) + ZPR (DEVOPS-6596):** ✅ deployed to production together **2026-09-28**; **`main` merged into `feature/ASCA/ASCA-master` on 2026-10-01**.
- **ZPR daily-table cleanup + September FINAL:** ✅ all complete. Data cleanup executed 2026-09-30 (Yijun-san). 10/01 PRE verified. September FINAL (10/02) initially crashed — root cause was a Zipan product-type resolution issue in `ZipanUtil.php`; fixed by **DEVOPS-6274** (Harvey-san) + **DEVOPS-6284** (Yijun-san), deployed alongside 6415/6596. DevOps re-ran after deploy — both monthly and send-journal commands completed successfully. Investigation reports: `projects/ascm/technical-notes/investigation/20261002-sendjournals-othersales-product-type-null/`.
- **Foundation (Spec 01):** ✅ **Code complete.** ASCA-16 (ls-db) + ASCA-17 (accounting) merged to `feature/ASCA/ASCA-master`. The one G3 fix — [ASCA-34](https://bizmates.atlassian.net/browse/ASCA-34) (`v_alloc_prorations_active` `run_type = Final` filter + view test) — is **✅ merged + Done** (confirmed via JIRA, 2026-10-12). **G3 ([ASCA-18](https://bizmates.atlassian.net/browse/ASCA-18)) is still "In Progress" in JIRA but its blocking fix has landed** — Lead chose to leave the status as-is for now; the SHOULD-FIX-1/2 spot-checks (test adequacy, model/seeder pass) were not formally recorded as cleared. Admin close only — no code work remains.
- **Steering files (ASCA-10):** ✅ updated to REF-CIP-05 + REF-CAP-11. PR sent to `feature/ASCA/ASCA-master` (branch `feature/ASCA/ASCA-10-steering-files-update`), 2026-10-05.
- **DEV04 QA test-data prep:** [ASCA-30](https://bizmates.atlassian.net/browse/ASCA-30) → [ASCA-31](https://bizmates.atlassian.net/browse/ASCA-31) → [ASCA-32](https://bizmates.atlassian.net/browse/ASCA-32) → [ASCA-33](https://bizmates.atlassian.net/browse/ASCA-33). Delegated; parallel, not on critical path.
- **Spec 02 (CAP Integration) — G1 status:**
  - **02a, 02b, 02d:** ✅ **SIGNED OFF by Kuroda-san (2026-10-05)**.
  - **02c:** Round-2 edits sent 2026-10-09. **Round-3 feedback (REF-CAP-14, 2026-10-13) ✅ ingested + folded into the 02c requirements.** Three items resolved: (1) completed-with-errors must be an active Final in `v_alloc_prorations_active`/V-5/supersede (owned by the Spec 01 run-status extension, overlaps ASCA-34); (2) **CIP produces no outcome row and never appears in the CSV** — verified in `BundleDetectionService` (CAP `plan_id` filter runs before bundle formation, so the shared App 10022 can't drag CIP in); 02a Req 2.5 to be corrected; (3) exception-row columns 部署ID/プロダクトID/プロダクトタイプ/契約種類 filled from the daily-rate log row. Minor date fix (10-05→10-08) applied. Kuroda-san: "once 1–3 are in, 02c is good." **Awaiting his final sign-off**, then promote.
  - **02a in the code repo** (`accounting_related_system_for_freee/.kiro/specs/asca-spec-02a-cap-core-injection/`), valid single-line `.config.kiro` (`specId` + `workflowType: requirements-first` + `specType: feature`).
    - **requirements.md** — committed on branch `feature/ASCA/ASCA-38-spec-2a-requirements` (ASCA-38, pushed to origin). Promoted as-is from the signed-off version, not regenerated.
    - **design.md (G2)** — ✅ **generated + committed (2026-10-12)** on branch `feature/ASCA/ASCA-39-spec-2a-architecture` (ASCA-39, HEAD, not yet pushed). Grounded against the actual batch code + Spec 01 engine; validated against the authoritative technical design (§8/§9) — aligned with the current REF-CAP-12/13 decisions (the §8/§9 *code samples* are the superseded 2026-08 version).
    - ✅ **02a is requirements + design + tasks complete, and the Coding story (ASCA-40) is MERGED to ASCA-master** (git-verified 2026-10-15, PR #307: `AllocationInjector` + `RunStatus::COMPLETED_WITH_ERRORS` present).
    - ✅ **The three 02a→Spec 01 dependencies are APPROVED by Kuroda-san (2026-10-13), ticketed, and partially landed:**
      1. **`COMPLETED_WITH_ERRORS` run status + `RunLifecycleService::finalizeWithErrors()`** — plus (REF-CAP-14 #1) `v_alloc_prorations_active`/V-5/supersede must treat completed-with-errors as an active Final → **[ASCA-68](https://bizmates.atlassian.net/browse/ASCA-68)** (accounting enum/service + ls-db view; overlaps ASCA-34, same view). **Status (2026-10-14): a dev task, being handled by the devs** alongside 02a/02b coding — not yet merged. This is the implementation precondition for 02c (the view must treat completed-with-errors as active, or the CSV shows exception rows but no allocated rows for a completed-with-errors Final). Sub-task under ASCA-18.
      2. **`log_alloc_bundle_outcomes` table + model** → **[ASCA-66](https://bizmates.atlassian.net/browse/ASCA-66)** (ls-db migration + structure test). **✅ Status (2026-10-14): MERGED to `feature/ASCA/ASCA-master`.** Sub-task under ASCA-18, like ASCA-34.
      3. **Reference-price `effective_from` → 2026-12-01** → **[ASCA-67](https://bizmates.atlassian.net/browse/ASCA-67)**. **✅ Status (2026-10-14): MERGED to `feature/ASCA/ASCA-master`.** ⚠️ **Correction:** the seeder (`ReferencePriceSeeder.php`) is in the **accounting repo**, NOT ls-db (steering says ls-db — doc/code discrepancy flagged in the ticket). Sub-task under ASCA-18.
    - **Next action:** 02a (ASCA-40) + 02b (ASCA-47) are **in coding** (ASCA-66/67 merged unblocked them); ASCA-68 proceeds in parallel as a dev task. Lead generates 02c G2 (design + tasks) today.
- **02d repurposed** from "inject allocation into DataCorrectionLogic" to **DECOMMISSION `DataCorrectionCommand`** (disable + deprecate) — command confirmed unused (Wu-san 08-28, Harvey-san 10-05). ADR + evidence note in `projects/asca/documentation/` (`ASCA-ADR-20261005-datacorrection-decommission.md`, `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md`).
- **02c: ✅ SIGNED OFF (Kuroda-san 2026-10-13, REF-CAP-15) + PROMOTED** to the code repo (`accounting_related_system_for_freee/.kiro/specs/asca-spec-02c-allocation-detail-csv/` with a valid `.config.kiro`). Next phase is G2 (design + tasks) via the spec UI's "Continue to Design". His two follow-ups: (1) run-status/view ticket → already raised as **ASCA-68**; (2) 02a Req 2.5 CIP wording → fixed in both the dev-context and code-repo 02a copies (doc-only, no code/tasks impact; the design.md CIP clause also cleaned). Design-phase note folded in: a refund skip/fail emits an exception row for the **refund charge only** (Req 2.3/2.12).
- **Spec 01 change-request (`log_alloc_bundle_outcomes` + run-status/view + `effective_from`):** the money table (`log_alloc_prorations`) stays money-only. Required by **both 02a and 02c**. Approved by Kuroda-san 2026-10-13; raised as three sub-tasks under ASCA-18 (like ASCA-34): **ASCA-66** (table, ls-db) **✅ merged**, **ASCA-67** (`effective_from`, accounting) **✅ merged**, **ASCA-68** (run-status + view-active) **— dev task, in progress**. Proposal: `projects/asca/documentation/ASCA-PROPOSAL-20261008-skipped-failed-bundle-recording.md`.
- **CIP-refund split home:** still **open** — extend 02b / new sub-spec / ASCI undecided. Identification resolved (REF-CIP-07: shareholder via `trn_receipt_locked_charge`, else fixed ratio); the home decision is on hold pending the scope decision.

### Immediate next actions

> **Task flow (agreed):** ASCA-66 + ASCA-67 (✅ merged) → **02a Coding (ASCA-40, ✅ MERGED to ASCA-master — git-verified 2026-10-15, PR #307)** → **02b Coding (ASCA-47, in progress; now unblocked) + ASCA-68** → **02c coding** → **02d**. ⚠️ **ASCA-68 is only half done:** the accounting-side `scopeActiveFinal` already accepts COMPLETED_WITH_ERRORS (landed with 02a), but the **ls-db `v_alloc_prorations_active` view SQL still filters `status = 1` only** — the view half is NOT merged and must land before 02c coding.

**Status (2026-10-15, Lead — git-verified):**
- ✅ **02a (ASCA-40) MERGED** to ASCA-master (PR #307): `AllocationInjector` + `RunStatus::COMPLETED_WITH_ERRORS` present. ✅ **ASCA-66** (ls-db outcomes table, PR #976) + **ASCA-67** (effective_from, PR #302) MERGED.
- ✅ **02c G2 complete** — `requirements.md` (signed off, promoted) + `design.md` + `tasks.md` all in the code repo. Ready for dev hand-off (ASCA-54 coding), gated on ASCA-68 view half.
- ✅ **02d promoted** — `requirements.md` + `.config.kiro` in the code repo, G1 approved (Kuroda-san 2026-10-05). JIRA epic/stories (ASCA-59–65) descriptions aligned. Next: generate 02d design/tasks via the spec UI.
- 🔴 **ASCA-68 half-open (critical for 02c):** accounting `scopeActiveFinal` accepts COMPLETED_WITH_ERRORS ✅, but the **ls-db `v_alloc_prorations_active` view SQL still filters `status = 1` only** (git-verified: `view-table-migration.sql` lines 475/486). The view half must be merged before 02c coding, else a completed-with-errors Final shows exception rows but no allocated rows. 02c tasks.md flags this precondition.

**In flight (devs — they own the JIRA statuses):**
- **02b (ASCA-47) coding** — unblocked now that 02a is merged.
- **ASCA-68 ls-db view half** — still needed (the accounting half shipped with 02a).
Sessions per `docs/workspace-setup.md` (ingest context → open `tasks.md` → task execution).
4. **ASCA-68** (`COMPLETED_WITH_ERRORS` + `v_alloc_prorations_active`/V-5/supersede active-on-completed-with-errors; overlaps ASCA-34) — dev task, in progress, parallel with 02a/02b.

**Doc/admin (low effort):**
5. **02a CIP wording fix (doc-only)** — Req 2.2/2.5 + design.md CIP clause already corrected in the code-repo 02a. Fold into the ASCA-40 Coding PR (no code/tasks impact).
6. **ASCA-34 merged + Done.** Admin only: optionally close Spec 01 **G3 (ASCA-18)** (Lead left it open).

### Key source docs (Spec 02)
- **REF-CAP-12** — G1 round 1 feedback
- **REF-CAP-13** — G1 round 2 feedback
- **REF-CAP-14** — 02c round 3 feedback (2026-10-13): completed-with-errors active in view, CIP no outcome row, exception-row columns; approved the Spec 01 CR
- **REF-CIP-07** — CIP refund-type detection

---

## What ASCA Is

**ASCA (ASC for CAP)** implements revenue allocation for the Coaching and App Plan bundles within the existing accounting batch system. It splits coaching charge revenue between Coaching and App products so that Freee journals correctly reflect the revenue split.

**JIRA:** [ASCA Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) · [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog)

**Scope:** Bizmates-only (`mysql` connection). Builds the shared allocation framework that ASCI reuses.

---

## Key Info

| Item | Value |
|---|---|
| Project code | ASCA |
| Full name | ASC for CAP (Coaching and App Plan) |
| Upstream project | CAP (Keith's team) |
| Code repo | `accounting_related_system_for_freee`, `ls-database-migrations` |
| Lead | Noel Palo |
| Developer | Throy Embudo |
| SDM | Patrick-san |
| PM | Kuroda-san |
| Deadline | 2026/12/17 |
| First batch run | 2027/01/01 |
| Approach | Scenario D (injection) + Option 1 (Overwrite) |

---

## ASCM Refactor (DEVOPS-6415)

Preparatory maintenance work billed under DEVOPS, linked to ASCA via ASCA-7.

- **Epic:** [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415)
- **Link ticket:** [ASCA-7](https://bizmates.atlassian.net/browse/ASCA-7)
- **Effort:** 3–5 days (no blockers — can start immediately)
- **Commits go under:** Sub-tickets/stories of DEVOPS-6415

### Scope (DEVOPS-6415 only — refactoring existing code)

| Task | Why (feeds into ASCA) |
|---|---|
| Extract ArchiverService + MailerService from DailyRateCalcPre + SendJournals + DataCorrection | Refactor existing duplication — shared services reused by ASCA/ASCI |
| Fix DataCorrectionLogic drift: add BizmatesMonthlyPlanEnum skip | Fix latent bug — monthly plans shouldn't enter daily log via correction |
| Fix DataCorrectionLogic drift: add missing fields (tax_free, country_id, gross_amount) | Align with CommonUtil schema |
| Unit test extracted service + corrected DataCorrectionLogic | Verify no regression |
| Smoke test all 3 batches on DEV04 (baseline) | Establish "before" state |
| Document baseline CSV file list | Know what's in the zip today |

**NOT in DEVOPS-6415 (belongs in ASCA Spec 01):** DB migrations, models, enums, test data seeder, reference price seeder — these are new features, not maintenance.

---

## ZPR — Zipan Price Revision (DEVOPS-6596)

Zipan accounting change, billed under DEVOPS (like the ASCM refactor — no ASC project). Shipped **together with DEVOPS-6415** (stacked + co-tested on DEV04, released to prod 2026-09-28).

- **Epic:** [DEVOPS-6596](https://bizmates.atlassian.net/browse/DEVOPS-6596)
- **Developer:** Cristoff (Lead: Noel)
- **Hard deadline (met):** released before **Oct 1, 2026** — the Oct 1 PRE batch would otherwise mishandle the new plan's charges.

### Scope (accounting system only)

| Task | Why |
|---|---|
| Add the new Zipan 20-lesson plan (`product_id = 38`) to `ZipanMonthlyPlanEnum` (+ unit test) | Route the new plan through the existing monthly-rate pipeline, not the daily table |

- **No computation change** (Wu-san via Harvey-san) — Zipan-only, a one-line enum add. Upstream ZPR is already in production.
- **Post-release cleanup:** 8 stale `product_id=38` daily rows removed by Yijun-san (2026-09-30) before the 10/01 PRE; 10/01 PRE verified (Noel) that product 38 now lands in the monthly-rate table, not daily. Runbook: `projects/asca/technical-notes/investigation/20260928-zpr-daily-table-cleanup/REPORT-00-zpr-daily-table-cleanup.md`.

> **Relationship to ASCA:** independent of allocation — ZPR only adds a Zipan monthly-plan enum entry. It shares the DEV04 environment and the combined 6415+6596 release, which is why it is tracked here alongside the ASCM refactor.

---

## What ASCA Builds

1. **ASCM Prep:** Fix DataCorrectionLogic drift, extract ArchiverService + MailerService
2. **Shared Foundation:** DB migrations (`log_alloc_*` for batch tables, `mst_alloc_*` for reference prices — O-3 resolved), models, enums, run lifecycle, allocation engine
3. **CAP-specific:** Detection for plans 1016–1027, reference prices (App ¥3,980, Coaching ¥19,800/¥39,600), AllocationDetail CSV
4. **Injection:** Allocation call in `CommonUtil::createDailyRateCalculation()` + `DataCorrectionLogic`

---

## JIRA Tickets Created

**Convention:** spec stories are prefixed `[Spec NN] —` so the spec is identifiable from the title.

| Key | Type | Parent | Summary | Notes |
|---|---|---|---|---|
| [ASCA-9](https://bizmates.atlassian.net/browse/ASCA-9) | Epic | — | ASCA — Project Scaffolding | Non-spec epic. Holds steering + DEV04 env. |
| [ASCA-10](https://bizmates.atlassian.net/browse/ASCA-10) | Story | ASCA-9 | Steering files (adapted from ASCH) | Done. Branch-setup story dropped. |
| [ASCA-13](https://bizmates.atlassian.net/browse/ASCA-13) | Epic | — | [Spec 01] — Foundation | Created 2026-09-09. Engine + schema (2-way). |
| [ASCA-14](https://bizmates.atlassian.net/browse/ASCA-14) | Story | ASCA-13 | [Spec 01] — Requirements + Sign-off | PM (Kuroda-san) · G1 |
| [ASCA-15](https://bizmates.atlassian.net/browse/ASCA-15) | Story | ASCA-13 | [Spec 01] — Architecture (Design + Tasks) | Lead · G2 |
| [ASCA-16](https://bizmates.atlassian.net/browse/ASCA-16) | Story | ASCA-13 | [Spec 01] — Coding (ls-db migrations) | Dev (Throy) |
| [ASCA-17](https://bizmates.atlassian.net/browse/ASCA-17) | Story | ASCA-13 | [Spec 01] — Coding (accounting application) | Dev (Throy) |
| [ASCA-18](https://bizmates.atlassian.net/browse/ASCA-18) | Story | ASCA-13 | [Spec 01] — Code Review | Lead · G3 |
| [ASCA-34](https://bizmates.atlassian.net/browse/ASCA-34) | Sub-task | ASCA-18 | [G3 Fix] v_alloc_prorations_active — add run_type = Final filter + view test | Cristoff · **committed, NOT yet merged** to `feature/ASCA/ASCA-master` — verify/merge to close G3 |
| [ASCA-19](https://bizmates.atlassian.net/browse/ASCA-19) | Story | ASCA-13 | [Spec 01] — QA Testing | QA (Miko) |
| [ASCA-20](https://bizmates.atlassian.net/browse/ASCA-20) | Story | ASCA-13 | [Spec 01] — Dev/Manual Testing | Lead |

### DEV04 environment (under ASCA-9 Scaffolding)

| Key | Type | Parent | Summary | Status | Notes |
|---|---|---|---|---|---|
| [ASCA-11](https://bizmates.atlassian.net/browse/ASCA-11) | Task | ASCA-9 | Repository update for Dev04 | In Progress | Throy |
| [ASCA-12](https://bizmates.atlassian.net/browse/ASCA-12) | Task | ASCA-9 | Database update for Dev04 | Done | Throy |
| [ASCA-21](https://bizmates.atlassian.net/browse/ASCA-21) | Task | ASCA-9 | DEV04 — Reconfigure for Freee API Access | ✅ Done | Noel. Token regenerated with Soli-san. |
| [ASCA-22](https://bizmates.atlassian.net/browse/ASCA-22) | Task | ASCA-9 | DEV04 — Investigate Zipan DB connection issue | ✅ Done | Throy. Root cause: `Unknown database 'zipan'` on DEV04 (SendJournals). Fixed + validated 2026-09-11 → unblocks ZPR command execution + ASCA Foundation testing. |

> **Shared DEV04 env note:** ASCA-21/22 are ASCA infrastructure tasks under the Scaffolding epic. ZPR (DEVOPS-6596) hit them first during Cristoff's command execution. Both now resolved — ZPR DEV04 run and ASCA Foundation testing are unblocked.

> Also on the board (pre-existing, not created here): ASCA-1–6 (time-logging buckets), ASCA-7 (Pre-Phase/ASCM link, DEVOPS-6415), ASCA-8 (Metabase breakdown). All unassigned unless noted.

### Spec 02 (CAP Integration) epics + stories

All four Spec 02 epics now created, each with the standard 6-story set, currently **unassigned**. Flat per-sub-spec gate sets matching the Spec 01 precedent.

| Key | Type | Stories | Summary |
|---|---|---|---|
| [ASCA-37](https://bizmates.atlassian.net/browse/ASCA-37) | Epic | ASCA-38–43 | [Spec 02a] — CAP Core Injection |
| [ASCA-44](https://bizmates.atlassian.net/browse/ASCA-44) | Epic | ASCA-45–50 | [Spec 02b] — Refund Allocation |
| [ASCA-52](https://bizmates.atlassian.net/browse/ASCA-52) | Epic | ASCA-53–58 | [Spec 02c] — AllocationDetail CSV (created 2026-10-13) |
| [ASCA-59](https://bizmates.atlassian.net/browse/ASCA-59) | Epic | ASCA-60–65 | [Spec 02d] — DataCorrection Decommission (created 2026-10-13) |

> Each epic carries the standard 6 stories (Requirements/G1, Architecture/G2, Coding, Code Review/G3, Dev/Manual Testing, QA). The Coding stories are the dev pick-up points: **ASCA-40** (02a), **ASCA-47** (02b). 02c ✅ signed off (REF-CAP-15) + promoted — next is G2 (design/tasks); 02d is decommission scope, low priority.
>
> **Spec 01 change-request (three sub-tasks under ASCA-18, like ASCA-34):** [ASCA-66](https://bizmates.atlassian.net/browse/ASCA-66) `log_alloc_bundle_outcomes` table (ls-db) · [ASCA-67](https://bizmates.atlassian.net/browse/ASCA-67) reference-price `effective_from` → 2026-12-01 (accounting repo) · [ASCA-68](https://bizmates.atlassian.net/browse/ASCA-68) `COMPLETED_WITH_ERRORS` + `v_alloc_prorations_active` active-on-completed-with-errors (accounting + ls-db view, overlaps ASCA-34). All three block 02a/02b. Note: ASCA-51 is an unrelated ticket (not ASCA Spec 02).

---

## Related Projects

| Code | JIRA | Relationship |
|---|---|---|
| ASC (ASCM) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/boards/1186/backlog) | Base system — ASCA injects into its commands |
| ASCH | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/boards/1753/backlog) | Cancelled predecessor — research reused |
| ASCI | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog) | Sister project — reuses ASCA's foundation |
| CAP (upstream) | — | Creates the charges ASCA allocates |

---

## Key Documents

| Document | Location |
|---|---|
| Technical design (authoritative) | `projects/asca/documentation/asc-allocation-framework-technical-design.md` |
| **Master timeline (authoritative schedule)** | **`docs/asc-projects-master-timeline.md`** |
| Scenario D proposal (historical, archived) | `archive/projects/asca/documentation/asc-alloc-scenario-d-injection-timeline-20260811.md` |
| Table prefix ADR | `projects/asca/documentation/ASCA-ADR-20260817-table-prefix-decision.md` |
| Upstream CAP research | `research/CAP/` |
| Base system context (ASCM) | `projects/ascm/project-context.md` |
| ASCM knowledge base | `projects/ascm/knowledge-base/` |
| Plans & products reference | `domain-knowledge/plans-and-products.md` |
| Spec 02 sub-spec index + promotion checklist | `projects/asca/specs/README.md` |
| 02a requirements (promoted) | `accounting_related_system_for_freee/.kiro/specs/asca-spec-02a-cap-core-injection/requirements.md` |
| 02d decommission ADR + usage note | `projects/asca/documentation/ASCA-ADR-20261005-datacorrection-decommission.md`, `…/ASCA-NOTE-20261005-datacorrection-usage-confirmation.md` |
| 02c skipped/failed-bundle recording proposal | `projects/asca/documentation/ASCA-PROPOSAL-20261008-skipped-failed-bundle-recording.md` |
