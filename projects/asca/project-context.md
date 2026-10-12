# ASCA — Project Context

> Load this at the start of each ASCA session.
> Also load `projects/ascm/project-context.md` for base ASC system context.
> If context gets compacted, re-read this file before continuing.

---

## Current State (as of 2026-10-12)

- **ASCM Refactor (DEVOPS-6415) + ZPR (DEVOPS-6596):** ✅ deployed to production together **2026-09-28**; **`main` merged into `feature/ASCA/ASCA-master` on 2026-10-01**.
- **ZPR daily-table cleanup + September FINAL:** ✅ all complete. Data cleanup executed 2026-09-30 (Yijun-san). 10/01 PRE verified. September FINAL (10/02) initially crashed — root cause was a Zipan product-type resolution issue in `ZipanUtil.php`; fixed by **DEVOPS-6274** (Harvey-san) + **DEVOPS-6284** (Yijun-san), deployed alongside 6415/6596. DevOps re-ran after deploy — both monthly and send-journal commands completed successfully. Investigation reports: `projects/ascm/technical-notes/investigation/20261002-sendjournals-othersales-product-type-null/`.
- **Foundation (Spec 01):** ✅ **Code complete** — ASCA-16 (ls-db, Cristoff) and ASCA-17 (accounting, Throy) both merged to `feature/ASCA/ASCA-master`. **G3 ([ASCA-18](https://bizmates.atlassian.net/browse/ASCA-18)) In Progress** — one fix outstanding: [ASCA-34](https://bizmates.atlassian.net/browse/ASCA-34) (Cristoff, `v_alloc_prorations_active` missing `run_type = Final` filter + view test) is **committed but NOT yet merged** to `feature/ASCA/ASCA-master`. **Next action:** verify/merge ASCA-34, then close G3.
- **Steering files (ASCA-10):** ✅ updated to REF-CIP-05 + REF-CAP-11. PR sent to `feature/ASCA/ASCA-master` (branch `feature/ASCA/ASCA-10-steering-files-update`), 2026-10-05.
- **DEV04 QA test-data prep:** [ASCA-30](https://bizmates.atlassian.net/browse/ASCA-30) → [ASCA-31](https://bizmates.atlassian.net/browse/ASCA-31) → [ASCA-32](https://bizmates.atlassian.net/browse/ASCA-32) → [ASCA-33](https://bizmates.atlassian.net/browse/ASCA-33). Delegated; parallel, not on critical path.
- **Spec 02 (CAP Integration) — G1 status:**
  - **02a, 02b, 02d:** ✅ **SIGNED OFF by Kuroda-san (2026-10-05)**.
  - **02c:** approved **pending Kuroda-san's 2nd review** of the latest edits (sent 2026-10-09; **awaiting reply**).
  - **02a in the code repo** (`accounting_related_system_for_freee/.kiro/specs/asca-spec-02a-cap-core-injection/`), valid single-line `.config.kiro` (`specId` + `workflowType: requirements-first` + `specType: feature`).
    - **requirements.md** — committed on branch `feature/ASCA/ASCA-38-spec-2a-requirements` (ASCA-38, pushed to origin). Promoted as-is from the signed-off version, not regenerated.
    - **design.md (G2)** — ✅ **generated + committed (2026-10-12)** on branch `feature/ASCA/ASCA-39-spec-2a-architecture` (ASCA-39, HEAD, not yet pushed). Grounded against the actual batch code + Spec 01 engine; validated against the authoritative technical design (§8/§9) — aligned with the current REF-CAP-12/13 decisions (the §8/§9 *code samples* are the superseded 2026-08 version).
    - ⚠️ **Design surfaced three 02a→Spec 01 dependencies** (02a is larger than the framework's original "thin call at the injection point" framing; all three follow from the per-bundle failure-isolation decision, REF-CAP-13 #2) — **open, need coordination/sign-off before the 02a tasks phase:**
      1. **`COMPLETED_WITH_ERRORS` run status + `RunLifecycleService::finalizeWithErrors()`** — Spec 01's `RunStatus` is CREATING/COMPLETED/FAILED only (all-or-nothing); the per-bundle model needs a "mostly succeeded, these pairs failed" state.
      2. **`log_alloc_bundle_outcomes` table + `LogAllocBundleOutcome` model** — one row per skipped (V-3) / failed (V-1) bundle. **This is the same table already tracked below as the 02c-driven Spec 01 CR** (`ASCA-PROPOSAL-20261008`); 02a now **also** depends on it, so the CR covers both 02a and 02c.
      3. **Reference-price `effective_from` → 2026-12-01** in the Spec 01 / ls-db CAP seeder — the current 2027-01-01 value leaves the first close (`target_ym = 2026-12`) with no resolvable price (silent V-4), so December CAP revenue would stay 100% on Coaching.
    - **Next action:** confirm the three Spec 01 extensions with PM/engineering, then generate 02a **tasks.md** (the user runs task generation manually). **Design 02a before 02b** (02b builds on 02a's injected path) — unchanged.
- **02d repurposed** from "inject allocation into DataCorrectionLogic" to **DECOMMISSION `DataCorrectionCommand`** (disable + deprecate) — command confirmed unused (Wu-san 08-28, Harvey-san 10-05). ADR + evidence note in `projects/asca/documentation/` (`ASCA-ADR-20261005-datacorrection-decommission.md`, `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md`).
- **02c schema change-request (pending):** 02c needs a new ls-db table **`log_alloc_bundle_outcomes`** (Option A, bundle-keyed, approved 2026-10-08) to source skipped/failed CSV rows. The money table (`log_alloc_prorations`) stays money-only. **Now also required by 02a** (surfaced in 02a design, 2026-10-12 — see the Spec 02 02a bullet above): the CR covers both 02a and 02c. Since 02a is signed off and its design is complete, this table is no longer gated solely on the 02c confirm — it can be raised as a small Spec 01 CR ticket (like ASCA-34) as part of confirming the 02a→Spec 01 extensions. Proposal: `projects/asca/documentation/ASCA-PROPOSAL-20261008-skipped-failed-bundle-recording.md`.
- **CIP-refund split home:** still **open** — extend 02b / new sub-spec / ASCI undecided. Identification resolved (REF-CIP-07: shareholder via `trn_receipt_locked_charge`, else fixed ratio); the home decision is on hold pending the scope decision.

### Immediate next actions
1. ✅ 02a **design.md** generated + committed (2026-10-12, ASCA-39). **Now:** confirm the three 02a→Spec 01 extensions (run status + `finalizeWithErrors()`, `log_alloc_bundle_outcomes` table, reference-price `effective_from` fix) with PM/engineering, then generate 02a **tasks.md** (run manually). Do NOT regenerate requirements.md — signed off.
2. Verify/merge **ASCA-34** into `feature/ASCA/ASCA-master`, then close Spec 01 **G3 (ASCA-18)**.
3. Raise the `log_alloc_bundle_outcomes` Spec 01 CR ticket — now needed by **both 02a (design-complete) and 02c**; no longer gated solely on the 02c confirm. Then promote 02c once Kuroda-san confirms.

### Key source docs (Spec 02)
- **REF-CAP-12** — G1 round 1 feedback
- **REF-CAP-13** — G1 round 2 feedback
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

Created in JIRA as **two epics, each with 6 stories** (ASCA-38–50), currently **unassigned**. Flat per-sub-spec gate sets matching the Spec 01 precedent.

| Key | Type | Parent | Summary |
|---|---|---|---|
| [ASCA-37](https://bizmates.atlassian.net/browse/ASCA-37) | Epic | — | [Spec 02a] — CAP Core Injection (6 stories) |
| [ASCA-44](https://bizmates.atlassian.net/browse/ASCA-44) | Epic | — | [Spec 02b] — Refund Allocation (6 stories) |

> Stories ASCA-38–50 sit under ASCA-37 / ASCA-44 (Requirements/G1, Architecture/G2, Coding ×N, Code Review/G3, QA, Dev test — the Spec 01 gate shape). 02c and 02d epics are **not yet created** — 02c pends Kuroda-san's 2nd review; 02d (decommission) is low priority.

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
