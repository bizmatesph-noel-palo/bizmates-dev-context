# Low-Priority Technical Improvements (June 2026)

**Created:** 2026-06-09  
**Target window:** Wed 06/10 – Thu 06/11  
**Constraints:** No CTE changes, no CSV format changes, no paid_price logic changes.

---

### Item 1: Add `declare(strict_types=1)` to Enum files

- **Target File(s):** `app/Enums/BizmatesMonthlyPlanEnum.php`, `app/Enums/ZipanMonthlyPlanEnum.php`
- **Scope:** Micro (2 lines — one per file)
- **Difficulty:** 1
- **Description:** `ServiceNameEnum.php` already has `declare(strict_types=1)` but the two monthly plan enums do not. Add the declaration after `<?php` in both files for consistency.
- **Benefit:** Enforces strict type coercion at the file level. Prevents silent int/string casting bugs if these enums are ever called with a loosely-typed argument. Matches the pattern already established in `ServiceNameEnum`.
- **Risk:** Zero. PHP enums with `int` backing already reject non-int values at the boundary. The declaration only tightens calling code *inside* that file, and neither file has any method body beyond the trait delegation.

---

### Item 2: Add `values(): array` helper to `HasEnumHelperTrait`

- **Target File(s):** `app/Traits/HasEnumHelperTrait.php`, `app/Contracts/MonthlyPlanEnumInterface.php`
- **Scope:** Small (8-10 lines)
- **Difficulty:** 1
- **Description:** Every call site currently does `BizmatesMonthlyPlanEnum::toArray()` which returns `['CASE_NAME' => 16, ...]`. But all consumers actually need just the *values* (product IDs) — they feed them into `whereNotIn()` or `in_array()`. Add a `values(): array` method that returns `array_column(self::cases(), 'value')` and expose it on the interface.
- **Benefit:** Eliminates repeated `array_values(::toArray())` patterns and makes intent clearer at call sites (`::values()` vs `::toArray()`). Future devs won't accidentally use the keyed version in a `whereIn`.
- **Risk:** Additive-only. Existing `toArray()` stays unchanged. No callers break. The trait is used by exactly 2 enums.

---

### Item 3: Remove dead `$condition = array()` / `$condition = []` initialization before loops

- **Target File(s):** `app/Libs/CommonUtil.php` (line ~246), `app/Libs/ZipanUtil.php` (line ~73)
- **Scope:** Micro (delete 1 line per file)
- **Difficulty:** 1
- **Description:** In both `createDailyRateCalculation` methods, `$condition` is initialized *before* the inner `foreach` but then immediately overwritten on the first iteration. The initialization is dead code.
- **Benefit:** Removes misleading code that suggests `$condition` accumulates across iterations (it doesn't — each iteration creates a fresh array).
- **Risk:** None. The variable is unconditionally reassigned on every loop iteration before any read.

---

### Item 4: Fix typo in config key `'errotMail'` → add alias constant

- **Target File(s):** `config/const.php` (2 keys), `app/Libs/CommonUtil.php` (2 references)
- **Scope:** Small (6 lines)
- **Difficulty:** 2
- **Description:** `config/const.php` defines `'applicationErrotMail' => 8` and `'errotMail' => 9` (should be "Error"). Since external systems (email templates, DB `mail_type` column) may reference the numeric IDs by these config keys, a rename could break things. Instead: add correctly-spelled aliases alongside the originals and mark the typos with a `// @deprecated` comment. New code should use the correct spelling.
  ```php
  'applicationErrorMail' => 8, // correct alias
  'applicationErrotMail' => 8, // @deprecated typo — kept for backward compat
  'errorMail' => 9,            // correct alias
  'errotMail' => 9,            // @deprecated typo — kept for backward compat
  ```
- **Benefit:** New code gets readable keys. Static analysis and grep find the correct spelling. Zero runtime risk.
- **Risk:** None — additive. Original keys stay, existing references still resolve. We add but don't remove.

---

### Item 5: Add `getMonthLastDate` return type + parameter types to `CommonUtil`

- **Target File(s):** `app/Libs/CommonUtil.php` — `getMonthLastDate()` method
- **Scope:** Micro (1-line signature change)
- **Difficulty:** 1
- **Description:** The method `getMonthLastDate($date, $endDate)` has no parameter or return type hints. It always receives Carbon instances and returns a Carbon instance. Add the type declaration:
  ```php
  public static function getMonthLastDate(Carbon $date, Carbon $endDate): Carbon
  ```
  ZipanUtil has the same method with the same issue — apply there too.
- **Benefit:** IDE autocomplete and static analysis (Larastan) can trace through the daily-rate loop without guessing types. Catches accidental string-passing at compile time.
- **Risk:** Zero. Both callers already pass Carbon objects — this just documents what's already true.

---

### Item 6: Add `getSegment2Id` return type declarations

- **Target File(s):** `app/Libs/CommonUtil.php`, `app/Libs/ZipanUtil.php`
- **Scope:** Micro (1 line change per file)
- **Difficulty:** 1
- **Description:** Both `getSegment2Id($departmentId, $contractType)` methods have no return type. They always return `int|null` (either `3` or the passed `$contractType`). Add explicit return type and parameter types:
  ```php
  public static function getSegment2Id(?int $departmentId, ?int $contractType): int|null
  ```
- **Benefit:** Documents the contract. Prevents accidental string injection. Aligns with PHP 8.3 best practices.
- **Risk:** Zero. Callers already pass int|null values. The function already returns int or null.

---

### Item 7: Replace `exit` with proper exception throw in `DailyRateCalculationPreLogic`

- **Target File(s):** `app/Libs/DailyRateCalculationPreLogic.php` (line ~43)
- **Scope:** Small (3-5 lines)
- **Difficulty:** 2
- **Description:** When `updateAccessToken()` fails, the code calls `exit;` which kills the PHP process immediately — no cleanup, no Laravel shutdown hooks, no transaction rollback. Replace with:
  ```php
  throw new \RuntimeException('Failed to update access token: ' . $e->getMessage());
  ```
  The calling command's `handle()` method will catch this and return `self::FAILURE`, which lets Laravel shut down gracefully.
- **Benefit:** Prevents orphaned DB connections / locks. Allows artisan's exit-code mechanism to report failure properly (scheduler, cron monitoring). Makes the failure testable.
- **Risk:** Low. The `exit` already stopped execution — a thrown exception stops execution too, but through the framework's proper shutdown path. No downstream logic is affected because nothing ran after `exit` anyway. Verify the calling command doesn't swallow the exception silently (it doesn't — the existing pattern in other commands lets exceptions propagate to artisan).

---

---

### Item 8: Replace `exit` with exception throw in `DataCorrectionLogic`

- **Target File(s):** `app/Libs/DataCorrectionLogic.php` (line ~87)
- **Scope:** Small (3-5 lines)
- **Difficulty:** 2
- **Description:** Same issue as Item 7 but in a different file. When `updateAccessToken()` fails, the code logs then calls `exit;`. Additionally, the log message says `'END DailyRateCalculationPreLogic'` — a copy-paste error from the Pre logic class. Fix both:
  ```php
  // Before:
  Log::info('END DailyRateCalculationPreLogic');
  exit;

  // After:
  throw new \RuntimeException('Failed to update access token: ' . $e->getMessage());
  ```
  The calling command's artisan handler will catch this, and the correct class name will appear in the stack trace naturally.
- **Benefit:** Fixes a misleading log message (wrong class name) and enables proper Laravel shutdown (same rationale as Item 7). Two bugs fixed in one micro-change.
- **Risk:** Zero behavioral change. Nothing executes after the `exit` today — the exception just routes the termination through Laravel's proper shutdown path. The DataCorrectionCommand's `handle()` does not catch `RuntimeException`, so artisan returns `FAILURE` and the scheduler sees it.

---

### Item 9: Replace `echo` statements with `$this->info()` / `$this->line()` in `SendJournalsDataLogic`

- **Target File(s):** `app/Libs/SendJournalsDataLogic.php` (~20 occurrences of `echo ... PHP_EOL`)
- **Scope:** Medium (20-30 lines changed — simple find/replace)
- **Difficulty:** 2
- **Description:** `SendJournalsDataLogic::execute()` mixes `Log::info(...)` with raw `echo` calls for console progress. The `echo` calls bypass artisan's output layer, so they: (a) don't appear in `--quiet` mode, (b) don't respect output verbosity flags, (c) produce raw output when called from tests. Replace each `echo "..." . PHP_EOL` with an injected output interface or remove them entirely (the Log calls already capture the same info).
  
  Simplest approach: remove the `echo` lines entirely — the Log::info calls remain and are the canonical record. If console visibility is wanted, it can be wired through the command layer later (consistent with how all other logic classes work in this project).
- **Benefit:** Cleaner separation between logic and presentation. Prevents duplicate output in production batch logs. Makes the class testable without capturing stdout. Matches the pattern in `DailyRateCalculationPreLogic` and `MonthlyRateCalculationLogic` which do not echo.
- **Risk:** Low. The `echo` statements are purely informational progress messages (not control flow). All the same information is already captured in `Log::info`. No external system consumes stdout from artisan batch commands — the scheduler and monitoring read exit codes and log files.

---

### Item 10: Add `execute(): void` return type and type-hint `$data` parameter in `DataCorrectionLogic`

- **Target File(s):** `app/Libs/DataCorrectionLogic.php`
- **Scope:** Small (5-8 lines — signature changes only)
- **Difficulty:** 1
- **Description:** The `execute()` method has no return type, and several private methods accept `$data` without a type hint even though they always receive `CorrectionDataObject`. Add:
  ```php
  public function execute(): void
  ```
  And for the private methods (`correctBalanceTransitionWithOrderNumber`, `correctDailyRateCalculation`, `dailyRateUpdate`, `dailyRateCancel`, `createDailyRateCalculation`, `updateDailyRateLogic`, `createBalanceTransitionWithOrderNumber`, `createBalanceTransitionWithOrderNumberAmount`, `recalculationOfBalanceTransitionWithOrderNumber`), add the type declaration:
  ```php
  private function correctBalanceTransitionWithOrderNumber(CorrectionDataObject $data): void
  ```
  The `createErrorData` method already shows `$data` can also receive an array (from `verifyContaints` error path), so leave that one typed as `$data` or use a union. All other private methods exclusively receive `CorrectionDataObject`.
- **Benefit:** IDE navigation ("find usages") works correctly. Larastan can verify property access on `$data->containts`, `$data->order_number` etc. without `@var` annotations. Prevents accidentally passing wrong type.
- **Risk:** Zero. All callers already pass the correct types — this just documents truth. Private methods cannot be called externally.

---

## Summary Scoreboard

| # | Title | Scope | Difficulty | Files touched |
|---|-------|-------|-----------|---------------|
| 1 | strict_types on Enum files | Micro | 1 | 2 |
| 2 | `values()` helper on trait | Small | 1 | 2 |
| 3 | Remove dead `$condition` init | Micro | 1 | 2 |
| 4 | Fix `errotMail` typo (additive alias) | Small | 2 | 2 |
| 5 | Type hints on `getMonthLastDate` | Micro | 1 | 2 |
| 6 | Type hints on `getSegment2Id` | Micro | 1 | 2 |
| 7 | Replace `exit` with exception (PreLogic) | Small | 2 | 1 |
| 8 | Replace `exit` with exception + fix log msg (DataCorrection) | Small | 2 | 1 |
| 9 | Remove raw `echo` from SendJournalsDataLogic | Medium | 2 | 1 |
| 10 | Add return types + `CorrectionDataObject` type hints | Small | 1 | 1 |

**Total estimated effort:** ~3-4 hours across both days, with generous code-review time.
