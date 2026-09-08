---
inclusion: auto
---

# Repository Map

ASCA spans two code repos plus a dev-context workspace. Know which repo owns which artifact before writing.

## Repositories

| Repository | Role for ASCA | Read/Write |
|---|---|---|
| `accounting_related_system_for_freee` | **Primary.** All ASCA PHP lives here — allocation service, models, enums, config, injection into the existing batch. | Read + Write |
| `ls-database-migrations` | Schema source of truth. The `log_alloc_*` / `mst_alloc_*` / `v_alloc_*` migrations + structure tests + reference-price seeder go here. | Write (migrations/seeders) |
| `MBTI_backend` | Student portal — where CAP/CIP plans and products originate upstream. Reference only; ASCA does not read it at runtime (it reads `trn_charge` in the Bizmates DB). | Read-only reference |
| `bizmates.jp` | Admin portal (FuelPHP) — upstream charge writer (enrollment, refunds, charge batch). Reference only. | Read-only reference |
| `bizmates-dev-context` | Dev-context workspace — specs, design docs, reports, and these steering drafts. **Not code.** | Read + Write (artifacts) |

## Boundary Rules

| Action | Where it happens |
|---|---|
| Allocation service, models, enums, config, injection call | `accounting_related_system_for_freee` |
| DB migrations (`log_alloc_*`, `mst_alloc_*`, `v_alloc_*`) + structure tests | `ls-database-migrations` |
| Reference-price seeder (`mst_alloc_reference_prices`) | `ls-database-migrations` (`database/seeders/Bizmates/`) |
| Requirements / design / tasks / reports | `bizmates-dev-context/projects/asca/` |
| Reference CAP/CIP plan & product definitions | `MBTI_backend` (read-only) |
| Reference charge creation / refund flow | `bizmates.jp` (read-only) |

> Cross-repo dependency: ls-db migrations must be **merged and run** before the accounting-repo models can be integration-tested. Model code can be written in parallel. (See `asca-development-workflow.md` → Multi-Repo Coordination.)

## Key Files / Locations in Other Repos

### accounting_related_system_for_freee (primary — where ASCA is built)

- `app/Libs/CommonUtil.php` → `createDailyRateCalculation()` — **injection point** (`allocate()` between write-N and build-sum)
- `app/Libs/DataCorrectionLogic.php` → `createDailyRateCalculation()` — **second injection point** (`allocateForCharge()`)
- `app/Enums/BizmatesMonthlyPlanEnum.php` — pattern to match for the new plan enums
- `app/Traits/HasEnumHelperTrait.php` — reused by the new enums (`exists()`, `toArray()`)
- New code lands under `RevenueAllocation/` sub-namespaces (see `coding-standards.md` → File Organization)

### ls-database-migrations (schema)

- `database/migrations/` — `log_alloc_*` / `mst_alloc_*` tables use `Schema::connection('bizmates_mysql')`
- `database/migrations/sql/` — raw-SQL pair for the `v_alloc_prorations_active` view (Laravel schema builder can't express it cleanly); driven by `db:migrate-view-table` / `db:rollback-view-table`
- `database/seeders/Bizmates/` — reference-price seeder
- `tests/Unit/Database/` — auto-generated table-structure tests (regenerate after schema changes)

### MBTI_backend (upstream plan/product origin — reference only)

- CAP plans **1016–1027**, CIP plans **1028–1032** are defined upstream here.
- Products: Coaching 10005/10015, Coaching Intensive 10025, App 10022.
- ASCA does not query MBTI_backend directly — these values arrive via `trn_charge` (Bizmates DB). Look here only to confirm upstream plan/product definitions.

### bizmates.jp (upstream charge writer — reference only)

- FuelPHP monolith that writes `trn_charge` (enrollment, B2B/B2E, refunds, charge batch). Look here only to trace how a charge was created.
