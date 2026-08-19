# ASCA — Project Context

> Load this at the start of each ASCA session.
> Also load `projects/ascm/project-context.md` for base ASC system context.
> If context gets compacted, re-read this file before continuing.

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

## ASCM Prep Phase (DEVOPS-6415)

Preparatory maintenance work billed under DEVOPS, linked to ASCA via ASCA-7.

- **Epic:** [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415)
- **Link ticket:** [ASCA-7](https://bizmates.atlassian.net/browse/ASCA-7)
- **Effort:** 5–7 days (no blockers — can start immediately)
- **Commits go under:** Sub-tickets/stories of DEVOPS-6415

### Scope

| Task | Why (feeds into ASCA) |
|---|---|
| Extract BatchReportDeliveryService from DailyRateCalcPre + SendJournals | Enables conditional CSV inclusion for AllocationDetail |
| Fix DataCorrectionLogic drift: add BizmatesMonthlyPlanEnum skip | Fix latent bug — monthly plans shouldn't enter daily log via correction |
| Fix DataCorrectionLogic drift: add missing fields (tax_free, country_id, gross_amount) | Align with CommonUtil schema |
| Unit test extracted service + corrected DataCorrectionLogic | Verify no regression |
| Smoke test all 3 batches on DEV04 (baseline) | Establish "before" state |
| Document baseline CSV file list | Know what's in the zip today |
| Create test data seeder for CAP/CIP charges | Mock upstream data for ASCA development |

---

## What ASCA Builds

1. **ASCM Prep:** Fix DataCorrectionLogic drift, extract BatchReportDeliveryService
2. **Shared Foundation:** DB migrations (`log_alloc_*` or `asc_alloc_*` — O-3 pending), models, enums, run lifecycle, allocation engine
3. **CAP-specific:** Detection for plans 1016–1027, reference prices (App ¥3,980, Coaching ¥19,800/¥39,600), AllocationDetail CSV
4. **Injection:** Allocation call in `CommonUtil::createDailyRateCalculation()` + `DataCorrectionLogic`

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
| Scenario D timeline + Gantt | `projects/asca/documentation/asc-alloc-scenario-d-injection-timeline-20260811.md` |
| Table prefix decision | `projects/asca/documentation/table-prefix-decision.md` |
| Master timeline (all ASC projects) | `docs/asc-projects-master-timeline.md` |
| Upstream CAP research | `research/CAP/` |
| Base system context (ASCM) | `projects/ascm/project-context.md` |
| ASCM knowledge base | `projects/ascm/knowledge-base/` |
| Plans & products reference | `domain-knowledge/plans-and-products.md` |
