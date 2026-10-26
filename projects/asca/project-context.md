# ASCA — Project Context

> Load this at the start of each ASCA session.
> Also load `projects/ascm/project-context.md` for base ASC system context.
> If context gets compacted, re-read this file before continuing.

---

## Current State (as of 2026-10-23 — DEV04 verified; 02c removal handed off; ASCI-01 at G1)

**ASCA CAP integration is dev-complete + DEV04-verified; the 02c removal is now merged too.** As of 2026-10-26: **ASCA-78 (02c AllocationDetail CSV removal) is DONE** (Throy, weekend — full allocation unit suite green, 126 tests / 43,662 assertions). **ASCA-79 (CEIL steering note) merged.** A fresh **DEV04 Oct–Nov command run ([ASCA-80](https://bizmates.atlassian.net/browse/ASCA-80)) is in progress** (Throy) to re-verify batch output on the post-removal code. ASCI-01 requirements **G1 feedback has been received from Kuroda-san** (shared at DSM) — now being ingested. What advanced earlier was **DEV04 deployment + command execution + QA allocation verification**:

- ✅ **ASCA-master deployed to DEV04** (both repos: `accounting_related_system_for_freee` + `ls-database-migrations`).
- ✅ **ASCA-24 (DEV04 Command Execution 20261020) — Done.** October (202610) + November (202611) batch commands executed on DEV04.
- ✅ **ASCA-71 ([QA] App price verification) — Done / PASS.** Glenn-san's retest (2026-10-21) confirms the CAP App allocation is correct in the DailyRateCalculation CSV: e.g. student 568/567/1032 App = ¥2,921 (15-min), 1014 App = ¥2,994 (30-min), all balancing to N. The earlier "all App rows ¥0" defect is **resolved**. Remaining 15 zero-App rows are valid V-3 skips / refund pairs / out-of-scope / missing-mapping — not failures.
- **freee-400 on real-send = DEV ENVIRONMENT issue, NOT a code bug.** Root cause: DEV04 had no mailer configured, so the send/email step couldn't complete. Does not affect the project; the allocation path itself is verified. (The ASCA-24 comment's Stripe-master-ID theory was a red herring.)
- **Stripe errors are out of ASCA scope.** Any Stripe-related failure (STRP-4 journal lines, Stripe master IDs) belongs to the responsible team — ignore for ASCA.

**The DEV04-verification gate from REF-CAP-17 is SATISFIED.** → The 02c removal CR is **unblocked** (no dependency on ASCA-8/Metabase — the system never reads from Metabase). Hard deadline for the removal: before the CAP beta release **2026-12-01**.

> Code baseline (unchanged, git-verified on `feature/ASCA/ASCA-master` @ PR #313): Spec 01 CR (ASCA-66/67/68) ✅; 02a (ASCA-40, PR #307) ✅; 02b (ASCA-47, PR #311) ✅; 02c AllocationDetail CSV (ASCA-48, PR #312) ✅; 02d DataCorrection decommission (ASCA-61, PR #313) ✅.

> **⚠️ Lead on leave 2026-11-11 → 2026-11-23.** ASCA CAP Integration is dev-complete + DEV04-verified (only the 02c removal ASCA-78 + admin closes remain). ASCI runs during/after the absence — **Throy-san to oversee ASCI during the leave** (to be confirmed formally as the last pre-leave item). Team is Noel/Throy/Cristoff/Glenn, no sub-lead.

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
      1. **`COMPLETED_WITH_ERRORS` run status + `RunLifecycleService::finalizeWithErrors()`** — plus (REF-CAP-14 #1) `v_alloc_prorations_active`/V-5/supersede must treat completed-with-errors as an active Final → **[ASCA-68](https://bizmates.atlassian.net/browse/ASCA-68)** (accounting enum/service + ls-db view `status IN (2,4)`; overlaps ASCA-34, same view). **✅ Status (2026-10-15): MERGED to `feature/ASCA/ASCA-master`.** This was 02c's view precondition — the view must treat completed-with-errors as active, or the CSV would show exception rows but no allocated rows for a completed-with-errors Final. **Now cleared → 02c coding (ASCA-55) is unblocked.** Sub-task under ASCA-18.
      2. **`log_alloc_bundle_outcomes` table + model** → **[ASCA-66](https://bizmates.atlassian.net/browse/ASCA-66)** (ls-db migration + structure test). **✅ Status (2026-10-14): MERGED to `feature/ASCA/ASCA-master`.** Sub-task under ASCA-18, like ASCA-34.
      3. **Reference-price `effective_from` → 2026-12-01** → **[ASCA-67](https://bizmates.atlassian.net/browse/ASCA-67)**. **✅ Status (2026-10-14): MERGED to `feature/ASCA/ASCA-master`.** ⚠️ **Correction:** the seeder (`ReferencePriceSeeder.php`) is in the **accounting repo**, NOT ls-db (steering says ls-db — doc/code discrepancy flagged in the ticket). Sub-task under ASCA-18.
    - **Next action:** 02a (ASCA-40) + 02b (ASCA-47) coding **MERGED** (PRs #307, #311); 02c (ASCA-55 Coding) **in progress — Throy** (req+design+tasks merged, ASCA-68 precondition cleared); 02d (ASCA-59/61) **coding just picked up — Cristoff** (decommission scope).
- **02d (epic ASCA-59): ✅ CODING MERGED (ASCA-61, PR #313).** DECOMMISSION of `DataCorrectionCommand` — `handle()` is now a guarded no-op that logs a deprecation warning, prints a decommissioned notice pointing to the DevOps direct-SQL process (DEVOPS-6706), and returns success without invoking `DataCorrectionLogic`; both classes carry `@deprecated` docblocks + unit tests. G1 approved (Kuroda-san 2026-10-05). ADR + evidence note in `projects/asca/documentation/` (`ASCA-ADR-20261005-datacorrection-decommission.md`, `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md`).
- **02c (epic ASCA-52): ✅ CODING MERGED (ASCA-48, PR #312).** `RevenueAllocationCsvService` + `allocationDetailFile` entry in `config/const.php` present on ASCA-master. G2 (requirements+design+tasks) merged; ASCA-54 Architecture done. (Coding story is **ASCA-48**, not ASCA-55 as earlier notes assumed.) Follow-up notes retained: run-status/view (ASCA-68 ✅ merged); 02a Req 2.5 CIP wording fixed (doc-only); refund skip/fail emits an exception row for the refund charge only (Req 2.3/2.12).
- **Spec 01 change-request (`log_alloc_bundle_outcomes` + run-status/view + `effective_from`):** the money table (`log_alloc_prorations`) stays money-only. Required by **both 02a and 02c**. Approved by Kuroda-san 2026-10-13; three sub-tasks under ASCA-18 (like ASCA-34), **all ✅ MERGED (git-verified 2026-10-15):** **ASCA-66** (table, ls-db, PR #976), **ASCA-67** (`effective_from`, accounting, PR #302), **ASCA-68** (run-status + ls-db view `status IN (2,4)`, PR #985). Proposal: `projects/asca/documentation/ASCA-PROPOSAL-20261008-skipped-failed-bundle-recording.md`.
- **CIP-refund split home:** ✅ **decided — inside ASCI-01** (not extending ASCA 02b, not a new ASCA sub-spec). Lead decision; to be ratified by Kuroda-san at ASCI-01 G1. Identification resolved (REF-CIP-07: shareholder via `trn_receipt_locked_charge`, else fixed ratio). CIP refund is therefore an ASCI concern, not an ASCA one.

### Immediate next actions

> **Task flow (agreed):** ASCA-66 + ASCA-67 + ASCA-68 (✅ all merged) → **02a Coding (ASCA-40, ✅ MERGED, PR #307)** → **02b Coding (ASCA-47, ✅ MERGED, PR #311)** → **02c Coding (ASCA-55, in progress — Throy) + 02d Coding (ASCA-59/61, picked up — Cristoff)**. ✅ **ASCA-68 fully merged** (ls-db view PR #985): `v_alloc_prorations_active` now filters `status IN (2,4)` (Completed OR Completed-with-errors) + `run_type = 2`. **No open blockers remain.**

**Status (2026-10-23, Lead):**
- ✅ **ALL Spec 01 + Spec 02 coding MERGED** (unchanged): 02a (ASCA-40, PR #307), 02b (ASCA-47, PR #311), 02c (ASCA-48, PR #312), 02d (ASCA-61, PR #313); Spec 01 CR ASCA-66/67/68.
- ✅ **DEV04 deploy + command execution (ASCA-24) + QA allocation verification (ASCA-71) all Done.** CAP allocation verified correct in the DailyRateCalculation CSV (Glenn-san, 2026-10-21).
- ✅ Test state (post-ASCA-78 weekend run, 2026-10-25/26): `tests/Unit/RevenueAllocation` **126/126 green (43,662 assertions)** — the AllocationDetail tests are gone with the CSV; no regressions.
- freee-400 = dev-env mailer config (not a code bug); Stripe errors out of ASCA scope.
- ✅ **02c removal (ASCA-78) — DONE** (Throy, weekend of 2026-10-25/26). Surgical removal per the grounded trace; full `tests/Unit/RevenueAllocation` suite green (126 tests / 43,662 assertions). The allocated value remains the `paid_price` in the daily-rate table (02a overwrite untouched), so the existing DailyRateCalculation CSV still carries it.
- ✅ **CEIL steering note (ASCA-79) — merged** (Lead).
- ✅ **DEV04 re-run ([ASCA-80](https://bizmates.atlassian.net/browse/ASCA-80)) — done** (Throy, reported at the 2026-10-26 DSM): redeployed to DEV04 + re-ran the batch commands to **regenerate the reports for QA after the 02c-removal changes**. Month wording reconciled — the batch processes the *previous* month, so "September and October **data**" produces the "October–November **report**"; same run, data-month vs report-month wording. (Tidy the JIRA status to Done if not already.)
- ✅ **ASCI-01 G1 feedback received from Kuroda-san** (shared at DSM) — now ours to ingest/process. (Was "submitted 2026-10-23"; feedback has since come back.)
- 🔵 **DB-safety fix (ASCA-70 follow-on):** two sub-tickets drafted + grounded + dev-Kiro prompts ready (accounting under ASCA-17, ls-db under ASCA-16) — **awaiting Lead review → create in JIRA.** Drafts: `technical-notes/jira/tickets/ASCA-17-SUB-TBA-...` and `ASCA-16-SUB-TBA-...`.

**Next actions (as of 2026-10-26):**
1. **Ingest Kuroda-san's ASCI-01 G1 feedback** → fold in, then promote requirements to the code repo `.kiro/specs/` + create the ASCI epic/stories. (Capture the feedback as a verbatim REF first.)
2. **Create the two DB-safety fix sub-tickets** (ASCA-17 accounting / ASCA-16 ls-db) after Lead review of the drafts.
3. **Confirm ASCA-80** DEV04 Oct–Nov run results when Throy posts them.
4. **NEW ASCH (2027) requirements — review (committed in the Friday Slack update):** Kuroda-san/Patrick-san provided **new requirements for an ASCH project targeted at 2027**. ⚠️ This is a **NEW** ASCH — NOT the 2026 cancelled predecessor; it reuses the name only. **Not yet reviewed.** Task: read the new requirements, then determine whether they overlap with / reuse the old cancelled ASCH research or are entirely new scope, and prepare feedback for Kuroda-san. (New project — likely its own context/tracking later; for now it's a Lead review task.)
5. **ASCI leave-coverage** — **Throy-san oversees ASCI during the Lead's leave (2026-11-11 → 11-23).** Confirm formally before leave.
6. **Deferred cleanup (tech debt):** filename/namespace review per Laravel standards — see `technical-notes/ASCA-NOTE-20261016-filename-namespace-cleanup.md`.

**Doc/admin (low effort, optional):**
- **02a CIP wording fix (doc-only)** — Req 2.2/2.5 + design.md CIP clause already corrected in the code-repo 02a. Fold into the ASCA-40 Coding PR (no code/tasks impact).

> **⚠️ Lead on leave 2026-11-11 → 2026-11-23.** ASCA CAP Integration is dev-complete + DEV04-verified and the 02c removal is merged, so ASCA is well-positioned against the leave (only the DB-safety fix + admin closes remain). **ASCI is the watch item** — G1 feedback received and being processed; if design/build runs into the leave window, **Throy-san oversees ASCI**.

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
| Developer | Throy Embudo, Cristoff Danganan |
| QA | Glenn Flamiano |
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
3. **CAP-specific:** Detection for plans 1016–1027, reference prices tax-excl (App ¥3,618, Coaching ¥18,000/¥36,000), AllocationDetail CSV
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
| [ASCA-19](https://bizmates.atlassian.net/browse/ASCA-19) | Story | ASCA-13 | [Spec 01] — QA Testing | QA (Glenn) |
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
