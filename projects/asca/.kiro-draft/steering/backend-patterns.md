---
inclusion: auto
---

# Backend Patterns

> **Scope:** Patterns for the **new allocation code** (`RevenueAllocation` namespace). ASCA does NOT add a command or a Logic class — it injects a service into the existing batch. The older ASCH "Command → Logic → O-then-P proration → journal factory" model does **not** apply here.

## This is NOT Standard Laravel

| Standard Laravel | This Project |
|---|---|
| HTTP Controllers handle requests | Artisan Commands are the entry points (existing) |
| Eloquent ORM for all queries | Raw SQL / query-builder for calculations; Eloquent for the new alloc tables |
| Service → Repository pattern | Existing: Command → Logic. Allocation: a Service injected into existing Logic/Util |
| API responses | CSV files + Freee API calls |

## How ASCA Plugs In (no new command)

Allocation is a **service injected into existing code at two points** — it does not run standalone.

```php
// Existing CommonUtil::createDailyRateCalculation() — full-month
try {
    app(RevenueAllocationService::class)->allocate($targetYm, $preFlg);
} catch (\Throwable $e) {
    Log::error('[ASC_ALLOC] Allocation failed: ' . $e->getMessage());
    // Fallback: log table keeps N — today's behavior, nothing lost
}

// Existing DataCorrectionLogic::createDailyRateCalculation() — single charge
try {
    app(RevenueAllocationService::class)->allocateForCharge($chargeId, $targetYm);
} catch (\Throwable $e) {
    Log::error('[ASC_ALLOC] Allocation failed in DataCorrection: ' . $e->getMessage());
}
```

There is no `AllocationCommand` and no `AllocationLogic`. The orchestrator is `RevenueAllocationService`.

## Service — the Orchestrator

`RevenueAllocationService` (in `App\Libs\RevenueAllocation`) runs the pipeline for one target month:

```
createRun → detectBundles → snapshotSourceData → computeAllocations → overwriteLogTable → persistAllocationDetail → finalizeRun
```

- **Single-stage split** — there is no O-value / proration-method stage. For each bundle: `P_app = floor(N × L_app / (L_coaching + L_app))`, `P_coaching = N − P_app`. (Formula detail: `coding-standards.md`, technical design §4.)
- Inject always-used collaborators (e.g. the run-lifecycle service) via the constructor. Resolve conditional ones with `app()->make()`.

```php
class RevenueAllocationService
{
    public function __construct(private RunLifecycleService $runLifecycle) {}

    public function allocate(string $targetYm, bool $preFlg): void { /* pipeline */ }
    public function allocateForCharge(int $chargeId, string $targetYm): void { /* scoped */ }
}
```

## Run Lifecycle

The run row persists even on failure, so failures are auditable. Each lifecycle write commits independently.

```php
$run = $this->runLifecycle->createRun($targetYm, $runType);  // own commit
try {
    // detect → snapshot → compute → overwrite → persist
    $this->runLifecycle->finalizeRun($run->id, $count);
} catch (\Throwable $e) {
    $this->runLifecycle->markFailed($run->id, $e->getMessage());  // own commit
    throw $e;  // re-thrown to the injection-point try/catch
}
```

`RunType` is int-backed: `Preview` (writes `_pre` tables) / `Final`. There is **no Revision** run type, and allocation never sends to Freee (the overwritten App row rides the existing sum → journal path). See `coding-standards.md`.

## Transaction Pattern

Scope transactions to the Bizmates connection; roll back on failure; log then re-throw.

```php
try {
    DB::connection('mysql')->beginTransaction();
    // detect / overwrite / persist
    DB::connection('mysql')->commit();
} catch (\Throwable $e) {
    DB::connection('mysql')->rollBack();
    Log::error('[ASC_ALLOC] ' . $e->getMessage());
    throw $e;
}
```

Note: the run-lifecycle writes (`createRun` / `markFailed`) commit on their **own** so the run row survives a rolled-back calculation.

## Query Patterns

- **Detection & overwrite** use the query builder against the daily-rate log joined to `trn_charge` (the log has no `plan_id`). Not string CTEs.

```php
// detect
DB::table($table . ' as log')
    ->join('trn_charge as c', 'log.charge_id', '=', 'c.id')
    ->where('log.target_ym', $targetYm)
    ->whereIn('c.plan_id', CoachingAndAppPlanEnum::toArray())
    ->whereIn('c.product_id', [10005, 10015, 10025, 10022])
    ->get()
    ->groupBy(fn ($r) => $r->student_id . '|' . ($r->order_no ?? 'null'));

// overwrite (N → P in place)
DB::table($table)->where('id', $coachingLogId)->update(['paid_price' => $pCoaching]);
DB::table($table)->where('id', $appLogId)->update(['paid_price' => $pApp]);
```

- **Alloc tables** (`log_alloc_*`, `mst_alloc_*`) use Eloquent models (see `coding-standards.md` → File Organization).

## Enums & DTOs

- **Enums:** int-backed, per `coding-standards.md`. `BundleType` (1=CAP/2=CIP, `label()` for display), `RunType`, `RunStatus`; plan-detection enums use `HasEnumHelperTrait`. Prefer enum-selected behavior over abstract base classes (composition over inheritance) — but only introduce a strategy/interface when a second implementation actually exists (KISS). ASCA has one allocation path, so no strategy pattern.
- **DTOs:** use a small readonly DTO (e.g. an `AllocationResult` carrying `coachingLogId`, `appLogId`, `pCoaching`, `pApp`, `originalN`) when data crosses method boundaries; a plain array is fine for a single `create()`.

## What NOT to Use

| Pattern | Why not |
|---|---|
| New artisan command / Logic class | Allocation injects into existing commands — it is not a standalone batch. |
| Repository | Eloquent on the alloc tables + query-builder for detection is enough. No ORM abstraction layer. |
| Proration-method / journal-entry strategy | No O→P proration and no self-sent journals in ASCA. Single-stage overwrite; App rides the existing Freee path. |
| Action / Observer / Decorator | Batch service, single path — no HTTP actions, no events, no behavioral wrapping. |
| Abstract base classes | Prefer injected collaborators + enums. Only add an interface when a second implementation appears (CIP reuses the same engine via config, not a subclass). |
