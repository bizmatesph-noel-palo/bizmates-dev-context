---
inclusion: auto
---

# Conventions

> **Scope:** Placement, migration location, and branch/commit conventions for the **new allocation code** (`RevenueAllocation` namespace, `log_alloc_*` / `mst_alloc_*` tables). Detailed class/enum naming lives in `coding-standards.md` — this file covers where things go and how branches/commits are named.

## File Placement

Allocation code is grouped under a `RevenueAllocation` sub-namespace (not the project code). Only these locations are used — there are no factory/strategy/collector folders (ASCA has a single allocation path; see `backend-patterns.md`).

| Content | Location |
|---|---|
| Allocation service (orchestrator) | `app/Libs/RevenueAllocation/` (`RevenueAllocationService.php`) |
| Run-lifecycle service | `app/Libs/RevenueAllocation/` |
| Eloquent models | `app/Models/RevenueAllocation/` (`LogAlloc*`, `MstAlloc*`) |
| Enumerations | `app/Enums/RevenueAllocation/` |
| Config | `config/revenue_allocation.php` |
| Unit tests | `tests/Unit/RevenueAllocation/` |
| CSV generation (Spec 02) | `app/Libs/RevenueAllocation/` (added later — not Foundation) |
| Database migrations | External repo: `ls-database-migrations` (see below) |

Injection touch-points in **existing** files (not new files): `app/Libs/CommonUtil.php` and `app/Libs/DataCorrectionLogic.php` — Spec 02.

## Database Migrations

**CRITICAL:** Migrations do NOT live in this repo. They live in `ls-database-migrations`.

Allocation tables use the Bizmates connection (`bizmates_mysql` in migrations, `mysql` at runtime). Bizmates-only — no Zipan.

```php
Schema::connection('bizmates_mysql')->create('log_alloc_calculation_runs', function (Blueprint $table) {
    // ...
});
```

Table prefixes: `log_alloc_*` (batch-generated), `mst_alloc_*` (master), `v_alloc_*` (view). See `database-standards.md` and the ls-db migration spec.

## Naming

Full naming rules (models, enums, service, config, log prefix) are in `coding-standards.md`. Summary:

| Entity | Convention | Example |
|---|---|---|
| Batch-generated tables | `log_alloc_*`, snake_case | `log_alloc_prorations` |
| Master-data tables | `mst_alloc_*` | `mst_alloc_reference_prices` |
| Views | `v_alloc_*` | `v_alloc_prorations_active` |
| Models | match the table (`LogAlloc*` / `MstAlloc*`) | `LogAllocProration`, `MstAllocReferencePrice` |
| Service | `RevenueAllocationService` | — |
| Enums | `{Concept}Enum` / `RunType` / `RunStatus` / `BundleType` | `CoachingAndAppPlanEnum` |
| Config keys | `revenue_allocation.*` | `config('revenue_allocation.launch_date')` |
| Log tag | `[REVENUE_ALLOCATION]` (ASCM UPPER_SNAKE style) | `Log::info('[REVENUE_ALLOCATION] - STARTED')` |

ASCA adds **no** artisan command and **no** Logic class — so there are no `Asca…Command` / `Asca…Logic` names.

## Branch Naming

Per the ASCA/ASCI branch strategy (`asca-development-workflow.md`). PRs target the long-lived `feature/ASCA/ASCA-master`.

- Scaffolding (steering): `feature/ASCA/ASCA-{t}-scaffolding`
- Foundation (app): `feature/ASCA/ASCA-{t}-spec01-foundation`
- Foundation (ls-db): `feature/ASCA/ASCA-{t}-spec01-migrations`
- CAP Integration: `feature/ASCA/ASCA-{t}-spec02-cap-integration`
- CIP Integration: `feature/ASCI/ASCI-{t}-spec01-cip-integration`

`{t}` = the JIRA story number the branch's work is logged against. ASCI work uses the `feature/ASCI/` prefix but still PRs into `ASCA-master` (shared foundation).

## Commit Messages

- `[ASCA-XXX] Short description` for ASCA-ticketed work; `[ASCI-XXX]` for ASCI.
- Reference the spec task when implementing via the spec workflow.
- ASCM Prep refactor commits are logged under `[DEVOPS-6415]` (its sub-stories), not ASCA.
