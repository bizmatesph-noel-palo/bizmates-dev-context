# ASCA-XXX — Deploy ASCA-master to DEV04 (accounting + ls-db)

**Type:** Task
**Epic:** ASCA-9 — ASCA Project Scaffolding
**Priority:** High
**Assignee:** Dev (Throy / Cristoff)
**Investigation:** `technical-notes/investigation/20261016-asca-master-readiness-review/REPORT-00-asca-master-readiness-review.md`

---

## Summary

Deploy the feature-complete `feature/ASCA/ASCA-master` branch to the **DEV04** environment in **both** repos — `accounting_related_system_for_freee` (allocation engine + injection + CSV + 02d decommission) and `ls-database-migrations` (`log_alloc_*` / `mst_alloc_*` / `v_alloc_prorations_active` schema). This unblocks G3 code review, QA, and a controlled Pre test-run of the allocation batch on DEV04. **No production deployment.**

---

## Context

As of 2026-10-19, ALL ASCA coding is merged to `feature/ASCA/ASCA-master` (git-verified):

| Piece | Repo | PR |
|---|---|---|
| Spec 01 Foundation | accounting + ls-db | ASCA-16 / ASCA-17 |
| Spec 01 CR (outcomes table, effective_from, run-status/view) | accounting + ls-db | ASCA-66 / 67 / 68 |
| 02a CAP Core Injection | accounting | ASCA-40, #307 |
| 02b Refund Allocation | accounting | ASCA-47, #311 |
| 02c AllocationDetail CSV | accounting | ASCA-48, #312 |
| 02d DataCorrection Decommission | accounting | ASCA-61, #313 |

The readiness review (2026-10-16) found no confirmed code bugs and both allocation suites green (Unit 125/125, Feature 34/34). The branch is ready for a DEV04 deploy so QA/G3 and a Pre smoke-run can proceed. The allocation tables only exist on DEV04 once the ls-db migrations run there, so **both repos must be deployed and in sync** — the accounting runtime reads tables the ls-db migrations create.

---

## Implementation

### Approach

Deploy `feature/ASCA/ASCA-master` from both repos to DEV04 using the standard DEV04 release path, then run the ls-db migrations (and the view-table SQL) against the DEV04 Bizmates DB before smoke-checking the accounting app.

### Affected Locations / Steps

**ls-database-migrations (schema — run FIRST):**
- [ ] Deploy `feature/ASCA/ASCA-master` to DEV04.
- [ ] Run `php artisan migrate` for the Bizmates connection (creates the 12 `log_alloc_*` + `mst_alloc_reference_prices` tables and FKs).
- [ ] Run the view migration for `v_alloc_prorations_active` (`php artisan db:migrate-view-table` — the raw-SQL pair; confirm it filters `status IN (2,4)` + `run_type = 2`).
- [ ] Confirm the structure tests / table presence on DEV04.

**accounting_related_system_for_freee (runtime — run AFTER schema):**
- [ ] Deploy `feature/ASCA/ASCA-master` to DEV04.
- [ ] Confirm `config/revenue_allocation.php` and the `AppServiceProvider` bindings load (no boot error).
- [ ] Confirm `app/Libs/RevenueAllocation/` + `RevenueAllocationCsvService` + the `allocationDetailFile` entry in `config/const.php` are present.

### N-Location / cross-repo check

- [ ] Both repos deployed from the SAME `ASCA-master` state (schema and runtime in sync).
- [ ] Bizmates connection only — no Zipan allocation tables (Bizmates-only feature).
- [ ] DEV04 only — NOT production.

---

## Acceptance Criteria

- [ ] `ASCA-master` is deployed to DEV04 in both `accounting_related_system_for_freee` and `ls-database-migrations`.
- [ ] All `log_alloc_*` / `mst_alloc_reference_prices` tables and the `v_alloc_prorations_active` view exist on the DEV04 Bizmates DB.
- [ ] The accounting app boots on DEV04 with no error from the allocation bindings/config.
- [ ] A dry `php artisan command:DailyRateCalculationPreCommand {exeDate}` run completes without a fatal error (allocation may log `No CAP bundles (no-op)` until test data is seeded — that is an acceptable deploy-smoke result).
- [ ] No change to the Zipan path or any production environment.

---

## Verification

Smoke per `.kiro/steering/batch-execution-flow.md`:

```bash
# in the accounting DEV04 container
php artisan command:DailyRateCalculationPreCommand {exeDate}
tail -80 storage/logs/laravel.log | grep -E "REVENUE_ALLOCATION|ERROR|FAILED|COMPLETED"
```

- PASS: `[REVENUE_ALLOCATION] inject allocate - END` with no `EXECUTION FAILED!`.
- Expected pre-seeding: `[REVENUE_ALLOCATION] inject allocate - NO CAP BUNDLES (no-op)` — acceptable for a bare deploy smoke; the data-seeded Pre test-run is a separate follow-up.

Also confirm the run row in `log_alloc_calculation_runs` is created for the smoke invocation.

---

## Dependencies

- Requires `feature/ASCA/ASCA-master` at PR #313 or later (all Spec 02 merged) — satisfied 2026-10-19.
- ls-db migrations must run on DEV04 BEFORE the accounting app is smoke-tested (runtime reads those tables).
- Downstream (separate tickets, NOT this one): the data-seeded Pre test-run (CAP master-data seeder in ls-db `CapCoachingAppPlansSeeder` → `ReferencePriceSeeder` in accounting → `Dev04CapTestDataSeeder`), and the Freee App `product_type=100` mapping data check (O-A) before any Final run.

---

## Cross-Reference

- Readiness review: `technical-notes/investigation/20261016-asca-master-readiness-review/REPORT-00-asca-master-readiness-review.md`
- Batch/smoke procedure: `accounting_related_system_for_freee/.kiro/steering/batch-execution-flow.md`
- Repo map: `accounting_related_system_for_freee/.kiro/steering/repository-map.md`
- Epic: ASCA-9 (Scaffolding)
