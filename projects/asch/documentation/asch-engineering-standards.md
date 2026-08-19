# ASCH Engineering Standards

**Last updated:** 2026-08-05  
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
    protected $signature = 'command:AschProrationCommand {exeDate?} {--run-type=final} {--force}';

    public function handle(): int
    {
        $exeDate = $this->argument('exeDate') ?: now()->format('Y/m/d');
        CommonUtil::setSystemDate($exeDate);
        [$startDate, $endDate] = CommonUtil::getTargetFromTo();

        $runType = RunType::fromLabel($this->option('run-type'));
        $force = (bool) $this->option('force');

        $logic = app()->make(AschProrationLogic::class);
        $logic->execute($startDate, $endDate, $runType, $force);

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

ASCH's calculation is a clear sequential pipeline. Each step takes the output of the previous. Uses a **3-transaction model** where run management and calculation work are independent commits.

```php
class AschProrationLogic
{
    public function execute(string $startDate, string $endDate, RunType $runType, bool $force = false): void
    {
        Log::info('[ASCH_PRORATION] - STARTED');

        $targetYm = date('Ym', strtotime($startDate));

        // Phase A — Create run (own commit, persists even on failure)
        if ($force) {
            $this->runLifecycleService->abortStaleRun($targetYm, $runType);
        }
        $run = $this->runLifecycleService->createRun($targetYm, $runType);

        try {
            // Phase B — Calculation work (own transaction, rollback-safe)
            DB::connection('mysql')->beginTransaction();

            $enrollments = $this->enrollmentService->identifyEligibleStudents($targetYm);
            $groups = $this->buildProrationGroups($enrollments, $targetYm);
            $this->validateGroups($groups); // ΣO = ΣM invariant
            $prorations = $this->allocateAndProrate($groups);
            $adjustments = $this->computeAdjustments($prorations, $runType);
            $this->aggregate($adjustments, $run);

            $run->update(['validation_status' => 1]);

            DB::connection('mysql')->commit();

            // Phase C — Finalize (own commit)
            $this->runLifecycleService->finalizeRun($run->id);

            if ($runType->sendsToFreee()) {
                $this->sendToFreee($run);
            }

            Log::info('DATA CREATION COMPLETED SUCCESSFULLY!');
        } catch (\Throwable $e) {
            DB::connection('mysql')->rollBack();
            // Phase C — Mark failed (own commit, independent of rollback)
            $this->runLifecycleService->markFailed($run->id, $e->getMessage());
            Log::error('EXECUTION FAILED!');
            throw $e;
        } finally {
            Log::info('[ASCH_PRORATION] - END');
        }
    }
}
```

**Key property:** A rollback in Phase B never rolls back Phase A or C. The run row always persists for audit/debugging.

Implemented as discrete methods — not a Laravel Pipeline object (overhead not justified for a single execution path).

### 2.6 Enums — Typed Value Sets with Behavior

PHP 8.1 backed enums replace magic strings/integers. Enums are the primary mechanism for composition over inheritance. **All domain enums are int-backed** (matching DB column types), with a `label()` method for string representation in CSV output, logs, and CLI.

```php
enum RunType: int
{
    case Preview = 0;
    case Final = 1;
    case Revision = 2;

    public function label(): string
    {
        return match ($this) {
            self::Preview => 'preview',
            self::Final => 'final',
            self::Revision => 'revision',
        };
    }

    public static function fromLabel(string $label): self
    {
        return match ($label) {
            'preview' => self::Preview,
            'final' => self::Final,
            'revision' => self::Revision,
            default => throw new \ValueError("Invalid run type: {$label}"),
        };
    }

    public function readsPreTables(): bool
    {
        return $this === self::Preview;
    }

    public function sendsToFreee(): bool
    {
        return $this === self::Final;
    }
}

enum ComponentType: int
{
    case Lesson = 1;
    case Coaching = 2;
    case App = 3;

    public function label(): string
    {
        return match ($this) {
            self::Lesson => 'lesson',
            self::Coaching => 'coaching',
            self::App => 'app',
        };
    }
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

**Important:** `ComponentType::Lesson->value` returns `1` (int), not `'lesson'`. Anywhere downstream (CSV output, logs, Freee mapping) that needs the string form must call `->label()` explicitly, never `->value`.

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
        public int $groupSeq,
        public int $paidTotal,          // ΣM (int yen)
        public float $denominatorTotal, // Σbasis (decimal 14,4)
        /** @var ProrationComponentDTO[] */
        public array $components,
    ) {}
}

final readonly class ProrationComponentDTO
{
    public function __construct(
        public int $productId,
        public int $componentType,     // 1=lesson, 2=coaching, 3=app
        public int $salesPrice,        // L (list price in yen)
        public int $paidPrice,         // M (paid amount in yen, negative for refunds)
        public int $prorationBasis,    // 0=list_price, 1=paid_price
        public float $baseAmount,      // O (decimal 14,4)
    ) {}
}

final readonly class AdjustmentResultDTO
{
    public function __construct(
        public int $enrollmentId,
        public int $chargeId,
        public string $targetYm,
        public float $accountingAmount,  // P
        public float $grossAmountAsc,    // N
        public float $adjustmentAmount,  // P - N
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

### 2.9 CSV Generation + Unified Email Delivery (REF-ASCH-07, 2026-08-05)

ASCH produces its own CSVs via a **dedicated, independent step**. Email delivery is a **separate downstream orchestrator** that collects CSVs from all projects (ASCH/CAP/CIP) into a single email.

**Design principle:** CSV generation and email delivery are separate concerns. This allows CAP and CIP to plug into the same email without reworking ASCH's generation path.

**How it works:**
1. ASCH batch generates CSVs from `asch_monthly_prorations` and `asch_sum_calculation` → returns file paths
2. Email orchestrator collects available CSVs for the target month across all projects
3. Sends a **single unified email** with per-project status table in the body
4. If one project failed, email still sends with available CSVs (failure isolation)

```php
// Step 11: CSV generation (per-project, failure-isolated)
class AschCsvGenerator
{
    public function generate(string $targetYm, int $runId): array
    {
        $files = [];
        $files[] = $this->createComponentDetailFile($targetYm, $runId);
        $files[] = $this->createCalculationSummaryFile($targetYm, $runId);
        return $files; // file paths — does NOT send email
    }
}

// Step 12: Email delivery (separate downstream orchestrator)
class AllocationEmailOrchestrator
{
    public function deliver(string $targetYm): void
    {
        $attachments = [];
        $projectStatuses = [];

        foreach ($this->getRegisteredProjects() as $project) {
            $status = $project->getRunStatus($targetYm);
            $projectStatuses[] = $status;

            if ($status->succeeded) {
                $attachments = array_merge($attachments, $project->getCsvFiles($targetYm));
            }
        }

        $zipFile = self::zipFiles($attachments, $targetYm);
        CommonUtil::sendMail(
            config('const.mailType.allocationProrationMail'),
            [$zipFile],
            self::buildMailContents($projectStatuses)
        );
    }
}
```

**Failure isolation constraints:**
- CSV generation failure in CAP must not prevent ASCH CSVs from being included
- Email body states per-project status (succeeded / failed / not executed)
- Freee journal sending remains completely independent per project

**Phasing:**
- Phase 1 (ASCH release): only ASCH CSVs in email, CAP/CIP show "not executed"
- Phase 2/3: CAP/CIP CSVs added as they release — no rework to ASCH

> **Note:** RESEARCH-04 (Zipan-precedent integration approach) is partially superseded by REF-ASCH-07. The research remains valid as historical context showing how the existing pipeline works.

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

Run management uses the 3-transaction model — run row persists even on failure:

```php
// Phase A: createRun() — own commit, never rolled back
$run = $this->runLifecycleService->createRun($targetYm, $runType);

try {
    // Phase B: calculation work — rollback-safe
    DB::connection('mysql')->beginTransaction();
    // ... pipeline steps ...
    $run->update(['validation_status' => 1]);
    DB::connection('mysql')->commit();

    // Phase C: finalize — own commit
    $this->runLifecycleService->finalizeRun($run->id);
    Log::info('DATA CREATION COMPLETED SUCCESSFULLY!');
} catch (\Throwable $e) {
    DB::connection('mysql')->rollBack();
    // Phase C: mark failed — own commit, independent of rollback
    $this->runLifecycleService->markFailed($run->id, $e->getMessage());
    Log::error('EXECUTION FAILED!');
    Log::error($e->getMessage());
    Log::error($e->getTraceAsString());
    throw $e; // Never swallow, never use exit()
} finally {
    Log::info('[ASCH_PRORATION] - END');
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
- Column naming: `sales_price` (L), `paid_price` (M), `base_amount` (O), `gross_amount_asc` (N), `accounting_amount` (P), `adjustment_amount` (P−N)
- Rounding: `floor()` per row, remainder absorbed by largest-O row in the group

ASCH does NOT:
- Modify existing ASC commands or logic
- Write to existing `log_*` tables
- Inherit from existing Logic classes
- Share transaction boundaries with existing commands
- Send T2 or T3 journals (adjustment-only approach eliminates the need)
