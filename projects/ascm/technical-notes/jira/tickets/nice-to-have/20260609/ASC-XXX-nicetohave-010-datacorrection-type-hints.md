# ASC-XXX: Add Return Types and Parameter Type Hints to `DataCorrectionLogic`

**Epic:** Nice to Have / Tech Debt  
**Scope:** Small (10 signature changes)  
**Difficulty:** 1  
**Files:** `app/Libs/DataCorrectionLogic.php`

---

## Context

The `execute()` method has no return type. Nine private methods accept `$data` without a type hint even though they exclusively receive `CorrectionDataObject`. Adding types enables IDE "find usages", Larastan verification of property access, and prevents accidental wrong-type passing.

---

## Steps

### File: `app/Libs/DataCorrectionLogic.php`

Add a `use` import at the top if not already present:
```php
use App\Libs\CorrectionDataObject;
```

Then update the following method signatures:

#### 1. `execute()` — line ~69

**Before:** `public function execute()`  
**After:** `public function execute(): void`

#### 2. `correctBalanceTransitionWithOrderNumber` — line ~166

**Before:** `private function correctBalanceTransitionWithOrderNumber($data)`  
**After:** `private function correctBalanceTransitionWithOrderNumber(CorrectionDataObject $data): void`

#### 3. `createBalanceTransitionWithOrderNumberAmount` — line ~208

**Before:** `private function createBalanceTransitionWithOrderNumberAmount($data)`  
**After:** `private function createBalanceTransitionWithOrderNumberAmount(CorrectionDataObject $data): void`

#### 4. `correctDailyRateCalculation` — line ~249

**Before:** `private function correctDailyRateCalculation($data)`  
**After:** `private function correctDailyRateCalculation(CorrectionDataObject $data): void`

#### 5. `dailyRateUpdate` — line ~264

**Before:** `private function dailyRateUpdate($data)`  
**After:** `private function dailyRateUpdate(CorrectionDataObject $data): void`

#### 6. `dailyRateCancel` — line ~288

**Before:** `private function dailyRateCancel($data)`  
**After:** `private function dailyRateCancel(CorrectionDataObject $data): void`

#### 7. `createDailyRateCalculation` — line ~308

**Before:** `private function createDailyRateCalculation($data)`  
**After:** `private function createDailyRateCalculation(CorrectionDataObject $data): void`

#### 8. `updateDailyRateLogic` — line ~424

**Before:** `private function updateDailyRateLogic($paidPrice, $target, $data)`  
**After:** `private function updateDailyRateLogic(int $paidPrice, $target, CorrectionDataObject $data): void`

Note: `$target` can be `LogDailyRateCalculation` or `LogDailyRateCalculationZipan` — leave it untyped (or use a common interface if one exists in a future PR).

#### 9. `createBalanceTransitionWithOrderNumber` — line ~494

**Before:** `private function createBalanceTransitionWithOrderNumber($data)`  
**After:** `private function createBalanceTransitionWithOrderNumber(CorrectionDataObject $data): ?\App\Models\LogBalanceTransitionWithOrderNumber`

Note: This method returns `null` on error or a model instance on success.

#### 10. `recalculationOfBalanceTransitionWithOrderNumber` — line ~524

**Before:** `private function recalculationOfBalanceTransitionWithOrderNumber($data, $diff)`  
**After:** `private function recalculationOfBalanceTransitionWithOrderNumber(CorrectionDataObject $data, int $diff): void`

---

## Do NOT change

- `createErrorData($message, $data, $diff = null)` — this method receives both `CorrectionDataObject` and raw arrays from the CSV validation path. Leave its `$data` parameter untyped (or type it as `CorrectionDataObject|array` if on PHP 8.0+).

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/VerifyContaintsTest.php
vendor/bin/phpunit
```

All callers already pass `CorrectionDataObject` — adding the type hint just documents truth. If a `TypeError` fires at runtime, it indicates a pre-existing bug that was previously hidden.
