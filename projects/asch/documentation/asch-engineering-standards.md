# ASCH Engineering Standards

**Last updated:** 2026-07-10  
**Audience:** Developers working on the ASCH (ASC Honki Set) subsystem  
**Scope:** Design patterns, coding principles, and standards specific to ASCH within `accounting_related_system_for_freee`

---

## 1. Coding Principles

### SOLID (Applied to Batch Systems)

| Principle | Application in ASCH |
|---|---|
| **Single Responsibility** | Each class has one reason to change. Logic class = orchestration. Service = domain concern. DTO = data transport. No god classes. |
| **Open/Closed** | New calculation patterns (2–9) are addable without modifying the core pipeline. Strategy injection, not if/else chains. |
| **Liskov Substitution** | Any `ProrationStrategy` implementation can replace another without breaking the pipeline. DTOs are `final` — no substitution risk. |
| **Interface Segregation** | Services expose only methods their consumers need. Don't build a single service with 15 methods. |
| **Dependency Inversion** | Logic classes depend on interfaces/contracts. Concrete implementations injected via constructor or container. |

### DRY, KISS, Composition over Inheritance

| Principle | Application in ASCH |
|---|---|
| **DRY** | Single logic class with mode parameter (run_id model). No Pre/Final code duplication. Shared services across pipeline steps. |
| **KISS** | SQL is readable with documented INTERVAL choices. No over-abstraction — if a simple method works, don't build a class. |
| **Composition over Inheritance** | Enums select strategies. DTOs carry data. Services are injected collaborators. No abstract base classes with template methods. |

---

## 2. Design Patterns

### 2.1 Command → Logic (Entry Point)

Thin artisan command delegates to a Logic class. The command only handles argument parsing and date setup.

```php
class AschProrationCommand extends Command
{
    protected $signature = 'command:AschProrationCommand {exeDate?}';

    public function handle(): int
    {
        $exeDate = $this->argument('exeDate') ?: now()->format('Y/m/d');
        CommonUtil::setSystemDate($exeDate);
        [$startDate, $endDate] = CommonUtil::getTargetFromTo();

        $logic = app()->make(AschProrationLogic::class);
        $logic->execute($startDate, $endDate, RunType::Final);

        return Command::SUCCESS;
    }
}
```

### 2.2 Service — Domain Logic Encapsulation

Services contain focused, reusable domain logic. The Logic class orchestrates; services do the work.

```php
class AschBundleEnrollmentService
{
    public function identifyEligibleStudents(string $targetYm): Collection { ... }
    public function buildComponents(AschBundleEnrollment $enrollment): Collection { ... }
}

class AschNValueReaderService
{
    public function readForCharge(int $chargeId, string $targetYm, RunType $runType): float
    {
        $table = $runType->readsPreTables()
            ? 'log_daily_rate_calculation_pre'
            : 'log_daily_rate_calculation';

        return DB::table($table)
            ->where('charge_id', $chargeId)
            ->where('target_ym', $targetYm)
            ->value('paid_price') ?? 0;
    }
}
```

**When to extract a Service:**
- Logic is reusable across commands or pipeline steps
- Testable in isolation (mockable dependency)
- Encapsulates a single domain concern

**Injection:** Constructor injection into the Logic class:

```php
class AschProrationLogic
{
    public function __construct(
        private AschBundleEnrollmentService $enrollmentService,
        private AschNValueReaderService $nValueReader,
        private AschJournalEntryFactory $journalFactory,
    ) {}
}
```

### 2.3 Strategy — Variant Calculation Logic

Daily and monthly plans calculate P differently. Strategy encapsulates the variant without polluting the pipeline with conditionals.

```php
interface ProrationStrategy
{
    public function calculate(float $oValue, array $periodData): float;
}

class DailyProrationStrategy implements ProrationStrategy
{
    public function calculate(float $oValue, array $periodData): float
    {
        return $oValue * ($periodData['j_days'] / $periodData['i_days']);
    }
}

class MonthlyProrationStrategy implements ProrationStrategy
{
    public function calculate(float $oValue, array $periodData): float
    {
        return $oValue * ($periodData['j_tickets'] / $periodData['i_tickets']);
    }
}
```

Strategy is resolved via enum (see §2.6 Enums).

### 2.4 Factory — Complex Object Construction

Journal entry construction involves config lookups, mapping tables, and conditional logic. A factory encapsulates this complexity.

```php
class AschJournalEntryFactory
{
    public function createFromAdjustment(AschSumCalculation $row): array
    {
        $freeeProductType = MstCodeChange::getChangeCodeToFreeeCode(
            config('code.masterDataType.productType'),
            $row->product_type
        );
        $rules = MstRuleForJournals::getMstRuleForJournals(
            $this->resolveSegment2Id($row),
            $freeeProductType
        );

        return [
            'entry_side' => $row->adjustment_amount > 0 ? 'debit' : 'credit',
            'tax_code' => $rules->tax_code,
            'account_item_id' => $rules->account_item_id,
            'amount' => abs(round($row->adjustment_amount)),
            'partner_id' => $row->partner_id,
            'item_id' => $rules->product_type,
            'section_id' => $rules->department_id,
            'segment_1_tag_id' => $rules->segment1_id,
            'segment_2_tag_id' => $rules->segment2_id,
            'description' => "asch_run:{$row->run_id},order_no:{$row->order_no}",
        ];
    }
}
```

### 2.5 Pipeline — Sequential Calculation Flow

ASCH's calculation is a clear sequential pipeline. Each step takes the output of the previous.

```php
class AschProrationLogic
{
    public function execute(string $startDate, string $endDate, RunType $runType): void
    {
        Log::info('[ASCH_PRORATION] - STARTED');

        $targetYm = date('Ym', strtotime($startDate));
        $run = $this->createRun($targetYm, $runType);

        try {
            DB::connection('mysql')->beginTransaction();

            $enrollments = $this->enrollmentService->identifyEligibleStudents($targetYm);
            $groups = $this->buildProrationGroups($enrollments, $targetYm);
            $this->validateGroups($groups); // ΣO = ΣM invariant
            $prorations = $this->allocateAndProrate($groups);
            $adjustments = $this->computeAdjustments($prorations, $runType);
            $this->aggregate($adjustments, $run);

            if ($runType->sendsToFreee()) {
                $this->sendToFreee($run);
            }

            DB::connection('mysql')->commit();
            Log::info('DATA CREATION COMPLETED SUCCESSFULLY!');
        } catch (\Throwable $e) {
            DB::connection('mysql')->rollBack();
            Log::error('EXECUTION FAILED!');
            throw $e;
        }

        Log::info('[ASCH_PRORATION] - END');
    }
}
```

Implemented as discrete methods — not a Laravel Pipeline object (overhead not justified for a single execution path).

### 2.6 Enums — Typed Value Sets with Behavior

PHP 8.1 backed enums replace magic strings/integers. Enums are the primary mechanism for composition over inheritance.

```php
enum RunType: string
{
    case Preview = 'preview';
    case Final = 'final';
    case Revision = 'revision';

    public function readsPreTables(): bool
    {
        return $this === self::Preview;
    }

    public function sendsToFreee(): bool
    {
        return $this === self::Final;
    }
}

enum ComponentType: string
{
    case Lesson = 'lesson';
    case Coaching = 'coaching';
    case App = 'app';
}

enum ProrationMethod: string
{
    case Daily = 'daily';
    case Monthly = 'monthly';

    public function strategy(): ProrationStrategy
    {
        return match ($this) {
            self::Daily => new DailyProrationStrategy(),
            self::Monthly => new MonthlyProrationStrategy(),
        };
    }
}
```

**Composition over inheritance via enums:**

```php
// ❌ Don't: class hierarchy
abstract class BaseCalculator { ... }
class DailyCalculator extends BaseCalculator { ... }
class MonthlyCalculator extends BaseCalculator { ... }

// ✅ Do: enum selects strategy, DTO carries data
$method = ProrationMethod::from($component->prorationMethod);
$pValue = $method->strategy()->calculate($oValue, $periodData);
```

### 2.7 DTOs — Typed Data Containers

DTOs carry data between pipeline steps. They replace associative arrays with named, typed properties.

```php
final readonly class ProrationGroupDTO
{
    public function __construct(
        public int $enrollmentId,
        public string $targetYm,
        public float $paidTotal,        // ΣM
        public float $denominatorTotal, // Σbasis
        /** @var ProrationComponentDTO[] */
        public array $components,
    ) {}
}

final readonly class ProrationComponentDTO
{
    public function __construct(
        public int $productId,
        public int $productType,
        public float $listPrice,       // L
        public float $paidAmount,      // M
        public float $prorationBasis,  // M or L depending on discount type
        public float $allocatedAmount, // O
    ) {}
}

final readonly class AdjustmentResultDTO
{
    public function __construct(
        public int $enrollmentId,
        public int $chargeId,
        public string $targetYm,
        public float $pValue,
        public float $nValue,
        public float $adjustment, // P - N
    ) {}
}
```

**When to use:**
- Data crosses method/service boundaries with 3+ fields
- Same data shape used in multiple pipeline steps
- Need IDE autocomplete and static analysis support

**Naming:** `{Domain}{Purpose}DTO` — `ProrationGroupDTO`, `AdjustmentResultDTO`, `JournalEntryDTO`

### 2.8 Collector — Aggregation

Collecting individual proration rows into summary-level rows for Freee submission.

```php
class AschSumCalculationCollector
{
    public function collect(Collection $prorations): Collection
    {
        return $prorations
            ->groupBy(fn ($row) => implode('|', [
                $row->productType,
                $row->contractType,
                $row->partnerId,
            ]))
            ->map(fn ($group) => new SumCalculationDTO(
                productType: $group->first()->productType,
                contractType: $group->first()->contractType,
                partnerId: $group->first()->partnerId,
                adjustmentAmount: $group->sum('adjustment'),
            ));
    }
}
```

### 2.9 CSV/Zip/Email Integration — Zipan Precedent Pattern

ASCH CSVs are included in the **same zip file and email** as existing ASC reports. The integration follows the proven Zipan pattern (already in production):

**How it works:**
1. ASCH provides a static `AschCsvUtil::addAschData(&$fileNameList)` method
2. This is called in `SendJournalsDataLogic::createSendMailAttacheFile()` after the Zipan call
3. A guard (`hasAschDataForMonth()`) returns early for months without Honki Set data — zero impact
4. ASCH creates its own separate CSV files (does NOT append to existing CSVs like Zipan does)

```php
// SendJournalsDataLogic::createSendMailAttacheFile() — 1 line added
ZipanUtil::addZipanData($targetYm, $targetStartDate, $targetEndDate, $fileNameList);
AschCsvUtil::addAschData($targetYm, $fileNameList);  // ← ASCH hook (same pattern as Zipan)
```

**Why NOT a facade/builder refactor:**
- The Zipan precedent is proven in production and requires only 1 line per pipeline
- A builder refactor is optional cleanup (Phase 2, later) — not a prerequisite for ASCH
- `$fileNameList` is a simple array with no hidden behavior; no abstraction needed yet

**Safety:** Months without Honki Set campaigns produce byte-for-byte identical output to pre-ASCH behavior. See `RESEARCH-04-CSV-Zip-Email-Integration.md` for full safety analysis.

**Files touched:** 2 existing files (1 line each) + new `AschCsvUtil.php` + config additions.

---

## 3. Patterns NOT Used (and Why)

| Pattern | Why not for ASCH |
|---|---|
| Repository | No ORM abstraction needed — raw SQL for calculations, direct Eloquent for CRUD. Adding repositories is indirection without benefit in a batch system. |
| Facade | No HTTP surface, no complex service resolution needs. Use direct injection. |
| Decorator | No behavioral extension needs. ASCH is a single-path batch with no optional middleware layers. |
| Action pattern | Actions are for HTTP request → response cycles (MBTI_backend pattern). ASCH is a batch system with commands. |
| Observer | No event-driven behavior needed. Batch runs sequentially with explicit control flow. |
| Abstract base classes | Use composition (services + enums + DTOs) instead of inheritance hierarchies. |

---

## 4. Coding Standards

### PHP

- **PSR-12** coding style
- **`declare(strict_types=1)`** in all new files
- **Type hints** on all parameters and return types
- **`final readonly`** on DTOs (immutable, non-extendable)
- **`final`** on service classes unless there's an explicit extensibility need
- **Backed enums** for all constrained value sets

### Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| Commands | `Asch{Purpose}Command` | `AschProrationCommand` |
| Logic classes | `Asch{Purpose}Logic` | `AschProrationLogic` |
| Services | `Asch{Domain}Service` | `AschBundleEnrollmentService` |
| DTOs | `{Domain}{Purpose}DTO` | `ProrationGroupDTO` |
| Enums | `{Concept}` (no suffix) | `RunType`, `ComponentType` |
| Factories | `Asch{Product}Factory` | `AschJournalEntryFactory` |
| Strategies | `{Variant}ProrationStrategy` | `DailyProrationStrategy` |
| Collectors | `Asch{Target}Collector` | `AschSumCalculationCollector` |
| Models | `Asch{TableName}` | `AschCalculationRun` |
| Tables | `asch_` prefix, snake_case | `asch_monthly_prorations` |
| Config keys | `asch.*` namespace | `config('asch.app_price')` |
| Log prefix | `[ASCH]` or `[ASCH_{COMMAND}]` | `[ASCH_PRORATION] - STARTED` |

### File Organization

```
app/
├── Console/Commands/Asch/       # Artisan commands (thin)
├── Libs/Asch/                   # Logic classes (pipeline orchestration)
├── Services/Asch/               # Domain services (focused logic)
├── Models/Asch/                 # Eloquent models
├── DTOs/Asch/                   # Data transfer objects
├── Enums/Asch/                  # PHP 8.1 backed enums
├── Factories/Asch/              # Object construction (journals, etc.)
├── Strategies/Asch/             # Proration calculation variants
├── Resources/Asch/              # Row mapping (raw → typed array)
└── Collectors/Asch/             # Aggregation logic
```

### SQL in PHP Strings

- Never use `"` (double quotes) inside SQL comments — breaks the PHP string
- Document every INTERVAL choice with inline comment
- Reference the fix ticket in comments: `-- FIX ASCH-XXX: ...`
- Use `<=>` for NULL-safe comparisons
- Use `DB::getPdo()->quote()` for date parameters in raw SQL

### Error Handling

```php
try {
    DB::connection('mysql')->beginTransaction();
    // ... pipeline steps ...
    DB::connection('mysql')->commit();
    Log::info('DATA CREATION COMPLETED SUCCESSFULLY!');
} catch (\Throwable $e) {
    DB::connection('mysql')->rollBack();
    Log::error('EXECUTION FAILED!');
    Log::error($e->getMessage());
    Log::error($e->getTraceAsString());
    throw $e; // Never swallow, never use exit()
}
```

### Validation Invariants

Assert invariants after each pipeline step, not just at the end:

```php
private function validateGroups(Collection $groups): void
{
    foreach ($groups as $group) {
        $sumO = collect($group->components)->sum('allocatedAmount');
        if (abs($sumO - $group->paidTotal) > 0.01) {
            throw new \RuntimeException(
                "ΣO ({$sumO}) ≠ ΣM ({$group->paidTotal}) for enrollment {$group->enrollmentId}"
            );
        }
    }
}
```

---

## 5. Testing Approach

- **Unit tests** for services, strategies, factories, collectors (isolated with mocks)
- **Integration tests** for the full pipeline (Logic class with real DB)
- **Property-based tests** for proration formula invariants (ΣO = ΣM, ΣP = O over lifetime)
- **Test file naming:** `{Subject}Test.php` (example-based), `{Subject}PropertyTest.php` (property-based)

---

## 6. Relationship to Existing ASCM Code

ASCH is a **new subsystem** that:
- Lives alongside existing ASC code (not replacing it)
- Reads from existing ASC output tables (read-only)
- Has its own `asch_*` tables, services, and commands
- Shares config infrastructure (`config/code.php`, `mst_rule_for_journals`, `mst_code_change`)
- Sends **T1 revenue journals only** (no T2 advance payment, no T3 wash) — simpler than `SendJournalsDataLogic`
- Uses `decimal(14,4)` for O values, `decimal(12,2)` for N/P/adjustment, `int` for M/L

ASCH does NOT:
- Modify existing ASC commands or logic
- Write to existing `log_*` tables
- Inherit from existing Logic classes
- Share transaction boundaries with existing commands
- Send T2 or T3 journals (adjustment-only approach eliminates the need)
