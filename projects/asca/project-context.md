# ASCA — Project Context

> Load this at the start of each ASCA session.
> Also load `projects/ascm/project-context.md` for base ASC system context.
> If context gets compacted, re-read this file before continuing.

---

## Current State (as of 2026-09-30)

- **ASCM Refactor (DEVOPS-6415) + ZPR (DEVOPS-6596):** ✅ deployed to production together **2026-09-28**.
- **ZPR daily-table cleanup:** ✅ executed by Yijun-san (DevOps) **2026-09-30** — 8 stale `product_id=38` rows removed from the Zipan daily tables (delete-only), before the 10/01 PRE. Upcoming: Noel's 10/01 PRE-figure verification (by 10/02 15:00 JST), then the September FINAL (10/02 18:00 JST). Runbook: `projects/asca/technical-notes/investigation/20260928-zpr-daily-table-cleanup/REPORT-00-zpr-daily-table-cleanup.md`.
- **Foundation (Spec 01):** 🔄 in execution in both repos (Throy accounting, Cristoff ls-db); awaiting PRs → G3.
- **DEV04 QA test-data prep:** QA requested CAP/CIP upstream code on DEV04 for ASCA test data. 4 tasks under ASCA-9 — [ASCA-30](https://bizmates.atlassian.net/browse/ASCA-30) (DB reimport) → [ASCA-31](https://bizmates.atlassian.net/browse/ASCA-31) (repos main/master) → [ASCA-32](https://bizmates.atlassian.net/browse/ASCA-32) (CAP `feature/CAP/CAP-base`) → [ASCA-33](https://bizmates.atlassian.net/browse/ASCA-33) (CIP TBA). Delegated; parallel with Spec 02 G1.
- **Spec 02 (CAP Integration):** at G1 (submitted 2026-09-28). **3 sub-specs — 02a Core Injection · 02b Refund · 02c AllocationDetail CSV.** Former **02d (DataCorrection) dropped at G1** (Kuroda-san, REF-CAP-12 §0 — DataCorrection fix batch outdated; draft archived). G1 returned 4 items to resolve: 02b CAP refund→bundle pairing (**blocker**), 02a failure-state + re-run/V-7, 02c linking columns. **CIP refunds ARE split** by a fixed per-type rule (REF-CIP-06) but the home (02b / new sub-spec / ASCI) is **on hold** pending Kuroda-san's refund-type-identification answer.

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
