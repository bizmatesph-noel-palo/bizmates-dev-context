---
inclusion: auto
---

# Coding Standards

> **Scope:** These standards apply to **new revenue allocation code** (the `RevenueAllocation` namespace and `log_alloc_*` / `mst_alloc_*` tables). Existing code (CommonUtil, the Logic classes, ZipanUtil) is NOT refactored to match — allocation only touches it at the documented injection points.

## PHP Standards

- **PSR-12** coding style
- **`declare(strict_types=1)`** in all new/modified files
- **Type hints** on all method parameters and return types
- **Docblocks** on classes and complex methods

## Principles

| Principle | How it applies |
|---|---|
| **KISS** | SQL conditions should be readable. Document INTERVAL choices with inline comments. Don't build abstractions (interfaces, factories) for a single implementation — add them only when a second implementation actually appears. |
| **DRY** | Existing ASC has 4-location duplication (Pre × Final × Bizmates × Zipan). The allocation framework is Bizmates-only and uses a single `RevenueAllocationService` with a `$preFlg` parameter — one implementation, two modes, no duplication. |
| **Single Responsibility (S)** | Each class has one reason to change. `CommonUtil.php` is already too large (2,000+ lines) — do NOT add allocation logic there beyond the ~8-line injection call. New concerns get new classes (e.g., `ArchiverService` for zip, `MailerService` for email — split, not combined). |
| **Open/Closed (O)** | CAP and CIP differ only by plan detection + reference prices. Add CIP by config/enum, not by modifying the allocation engine. |
| **Liskov Substitution (L)** | If a strategy/interface is introduced later (e.g., a per-project detection strategy), every implementation must be safely interchangeable without special-casing at the call site. Until a second implementation exists, KISS wins — don't introduce the abstraction preemptively. |
| **Interface Segregation (I)** | Keep service interfaces small and consumer-specific. `RevenueAllocationService` exposes only what callers need (`allocate()`, `allocateForCharge()`) — don't bundle unrelated methods into one fat service. `ArchiverService` and `MailerService` are split for this reason. |
| **Dependency Inversion (D)** | Logic classes resolve services via the container (`app(RevenueAllocationService::class)`) or constructor injection. Don't hard-instantiate collaborators that might need swapping in tests. |
| **Composition over Inheritance** | Prefer injected collaborators and enums over base classes. No abstract Logic base classes. |

## SQL in PHP Strings

Calculation queries are raw SQL inside PHP strings. Rules:

1. **Never use `"` (double quotes) inside SQL comments** — breaks the PHP string
2. **Document every INTERVAL / date-boundary choice** with an inline comment
3. **Reference the fix ticket** in comments when adding conditions:
   ```sql
   -- FIX ASCA-XXX: Explanation of why this condition exists
   AND some_condition = 1
   ```
4. **Use `<=>` for NULL-safe comparisons** (not `=` which fails for NULL)

## Error Handling

The allocation call is wrapped so a failure never breaks the existing batch:

```php
// At the injection point (CommonUtil / DataCorrectionLogic):
try {
    app(RevenueAllocationService::class)->allocate($targetYm, $preFlg);
} catch (\Throwable $e) {
    Log::error('[ASC_ALLOC] Allocation failed: ' . $e->getMessage());
    Log::error($e->getTraceAsString());
    // Fallback: log table still has N — today's behavior, nothing lost
}
```

Inside the service, use the run-lifecycle model so the run row persists even on failure:

```php
$run = $this->runLifecycle->createRun($targetYm, $runType);  // own commit — always persists
try {
    // ... allocation work ...
    $this->runLifecycle->finalizeRun($run->id, $count);
} catch (\Throwable $e) {
    $this->runLifecycle->markFailed($run->id, $e->getMessage());  // own commit
    throw $e;  // re-thrown to the outer try/catch above
}
```

Never use `exit()`. Always log before re-throwing.

## Logging

- Prefix all allocation logs with `[ASC_ALLOC]`
- Start/end markers: `[ASC_ALLOC] Allocation started` / `Allocation completed`
- Include structured context: `['target_ym' => $targetYm, 'pre' => $preFlg, 'records' => $count]`

## File Organization

New allocation code follows this structure (per technical design §11):

```
app/
├── Libs/
│   └── RevenueAllocation/
│       └── RevenueAllocationService.php # Main orchestrator (allocate, allocateForCharge)
├── Models/
│   └── RevenueAllocation/               # models named after their table
│       ├── LogAllocCalculationRun.php        → log_alloc_calculation_runs
│       ├── LogAllocSourceDocument.php        → log_alloc_source_documents
│       ├── LogAllocBundle.php                → log_alloc_bundles
│       ├── LogAllocBundleCharge.php          → log_alloc_bundle_charges
│       ├── LogAllocGroup.php                 → log_alloc_groups
│       ├── LogAllocProration.php             → log_alloc_prorations
│       ├── MstAllocReferencePrice.php        → mst_alloc_reference_prices
│       ├── LogAllocSumCalculation.php        → log_alloc_sum_calculation
│       ├── LogAllocSumCalculationHistory.php → log_alloc_sum_calculation_history
│       └── LogAllocDelivery.php              → log_alloc_deliveries
├── Enums/
│   └── RevenueAllocation/
│       ├── CoachingAndAppPlanEnum.php  # CAP plan_ids 1016–1027
│       ├── CoachingIntensivePlanEnum.php # CIP plan_ids 1028–1032
│       ├── BundleType.php              # int-backed: CAP=1, CIP=2 (label() → 'cap'/'cip'). Renamed+retyped from ProjectCode/VARCHAR (O-9 — confirmed by Kuroda-san 2026-09-02)
│       ├── RunType.php                 # Preview, Final
│       └── RunStatus.php               # Creating, Completed, Failed
└── Traits/
    └── HasEnumHelperTrait.php          # Already exists — reused by new enums

config/
└── revenue_allocation.php              # Launch dates, feature flags

tests/Unit/RevenueAllocation/
├── RevenueAllocationServiceTest.php
├── CoachingAndAppPlanEnumTest.php
└── AllocationFormulaTest.php
```

Migrations live in the **`ls-database-migrations`** repo, NOT here. See `database-standards.md`.

**Full field-level schema** (columns, types, keys, descriptions for all 10 tables + view) is the authoritative reference for models and migrations: `projects/asca/documentation/asc-alloc-db-schema.md` (in the dev-context workspace).

## Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| Service | `RevenueAllocationService` (in `Libs/RevenueAllocation/`) | `RevenueAllocationService` |
| Models | Match the table name — `log_alloc_*` → `LogAlloc*`, `mst_alloc_*` → `MstAlloc*` (in `Models/RevenueAllocation/`) | `LogAllocProration`, `MstAllocReferencePrice` |
| Enums | `{Concept}Enum` for plan sets (matches existing `BizmatesMonthlyPlanEnum`); `RunType` / `RunStatus` for state; `BundleType` for the cap/cip discriminator (O-9 — confirmed by Kuroda-san 2026-09-02) | `CoachingAndAppPlanEnum`, `RunType`, `BundleType` |
| Batch-generated tables | `log_alloc_*` prefix, snake_case | `log_alloc_calculation_runs` |
| Master-data tables | `mst_alloc_*` prefix | `mst_alloc_reference_prices` |
| Views | `v_alloc_*` prefix | `v_alloc_prorations_active` |
| Migration files | `create_{table_name}_table.php` (uses the actual table name) | `create_log_alloc_calculation_runs_table.php` |
| Config keys | `revenue_allocation.*` namespace | `config('revenue_allocation.launch_date')` |
| Log prefix | `[ASC_ALLOC]` | `Log::info('[ASC_ALLOC] Allocation started')` |

### Namespace vs table naming (two axes)

- **PHP namespace** = the feature: `App\Models\RevenueAllocation\`, `App\Libs\RevenueAllocation\`, `App\Enums\RevenueAllocation\`. Descriptive domain name (not the project code `ASC`), consistent with the ADR principle that structure reflects what the code IS, not who built it.
- **Model class names** = the table: `LogAllocProration` → `log_alloc_prorations`, `MstAllocReferencePrice` → `mst_alloc_reference_prices`. Follows the existing convention (`log_daily_rate_calculation` → `LogDailyRateCalculation`), so a model name predictably maps to its table.

Feature grouping comes from the folder/namespace (`RevenueAllocation`), not from the class-name prefix. Set `$table` explicitly on every model:

```php
declare(strict_types=1);

namespace App\Models\RevenueAllocation;

use Illuminate\Database\Eloquent\Model;

class MstAllocReferencePrice extends Model
{
    protected $connection = 'mysql';
    protected $table = 'mst_alloc_reference_prices';  // matches the class name
    protected $guarded = ['id'];
}
```

Always rely on `$table` to know the real table name — never infer it from the model name (consistent with the multi-tenancy steering's table-naming warning).

## Enums

Backed enums (int) with the shared `HasEnumHelperTrait` (provides `exists()` and `toArray()`). Match the pattern of the existing `BizmatesMonthlyPlanEnum`:

```php
declare(strict_types=1);

namespace App\Enums\RevenueAllocation;

use App\Traits\HasEnumHelperTrait;

enum CoachingAndAppPlanEnum: int
{
    use HasEnumHelperTrait;

    case SOLO_C15_APP = 1016;
    case SOLO_C30_APP = 1017;
    // ... 1018–1027
}
```

Detection uses `CoachingAndAppPlanEnum::exists($planId)` — no date filter (these are new plans with no historical data).

**All allocation enums are int-backed** — they map to `TINYINT` columns for schema consistency (matching the existing accounting-system convention where status/type columns are int). Human-readable strings for CSV/Metabase output come from a `label()` method, never from the stored value.

```php
declare(strict_types=1);

namespace App\Enums\RevenueAllocation;

// Maps to the `bundle_type` TINYINT column — renamed+retyped from ProjectCode/VARCHAR (O-9 — confirmed by Kuroda-san 2026-09-02)
enum BundleType: int
{
    case CAP = 1;
    case CIP = 2;

    public function label(): string
    {
        return match ($this) {
            self::CAP => 'cap',
            self::CIP => 'cip',
        };
    }
}
```

- **Stored value** = int (`1`/`2`) in the `bundle_type` TINYINT column
- **Display value** = `->label()` (`'cap'`/`'cip'`) for CSV, logs, Metabase
- Use `1`-based values (not `0`) so `0` unambiguously means "unset" — matches the `STATUS_ACTIVE = 1` convention
- `RunType`, `RunStatus`, `product_role`, `channel` follow the same int-backed pattern (see `asc-alloc-db-schema.md`)

## Money Types

- Reference prices (L) and paid amounts (N, P): integer yen (matches existing `paid_price` column)
- `floor()` for the App split; remainder absorbed by Coaching (`P_coaching = N − P_app`) so `P_coaching + P_app = N` always holds

## Idempotency & Re-Run Safety (from technical design §9)

Allocation MUST be safe to re-run. Two rules enforce this:

1. **N = Σ(paid_price) across the bundle** (coaching + app), never the coaching row alone. This makes N invariant across runs:
   - 1st run: N = 22,550 + 0 = 22,550 → P_coaching=18,776, P_app=3,774
   - 2nd run: N = 18,776 + 3,774 = 22,550 → same result ✅

2. **Snapshot skip:** `snapshotSourceData()` must skip when a proration/source-document row already exists for `(charge_id, target_ym)`. Otherwise a re-run records already-allocated values as the "original N" — corrupting the audit trail even though the numbers stay correct.

## Two Injection Points (from technical design §8)

| Injection site | Method | Scope |
|---|---|---|
| `CommonUtil::createDailyRateCalculation()` | `allocate($targetYm, $preFlg)` | Full month — all CAP/CIP bundles. Covers Pre + Final batches. |
| `DataCorrectionLogic::createDailyRateCalculation()` | `allocateForCharge($chargeId, $targetYm)` | Single charge — only the bundle containing the corrected charge. Correction path only. |

Both calls are wrapped in try/catch (see Error Handling above). `allocateForCharge()` is NOT the full-month rebuild — it scopes to one bundle so a correction doesn't wipe/rebuild the whole month.

## Testing

- Unit test the allocation formula, idempotency (ΣN invariant on re-run), and bundle detection
- Property-based tests for invariants (ΣP = ΣN at bundle level) — min 100 iterations
- Test file naming: `{Subject}Test.php` (example-based), `{Subject}PropertyTest.php` (property-based)
