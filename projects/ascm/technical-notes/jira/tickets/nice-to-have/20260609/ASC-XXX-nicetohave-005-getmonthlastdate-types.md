# ASC-XXX: Add Type Hints to `getMonthLastDate`

**Epic:** Nice to Have / Tech Debt  
**Scope:** Micro (1 signature change per file)  
**Difficulty:** 1  
**Files:** `app/Libs/CommonUtil.php` (line 1218), `app/Libs/ZipanUtil.php` (line ~235)

---

## Context

`getMonthLastDate()` exists in both `CommonUtil` and `ZipanUtil`. Both always receive `Carbon` objects and return a `Carbon` object, but have no type declarations. Adding them enables IDE autocomplete and static analysis (Larastan) through the daily-rate calculation loop.

---

## Steps

### File 1: `app/Libs/CommonUtil.php` — line 1218

**Before:**
```php
    /**
     * 月末日取得
     *
     * @param $date：日付
     * @param $targetYm：月末日付
     *
     * @return object $monthLastDate：月末日
     */

    public static function getMonthLastDate($date, $endDate)
    {
        // 月末取得
        $monthLastDate = Carbon::create($date->year, $date->month, 1)->lastOfMonth();
        // 終了年月の場合、終了日付を設定
        if ($monthLastDate->format('Ym') === $endDate->format('Ym')) {
            $monthLastDate = $endDate;
        }
        return $monthLastDate;

    }
```

**After:**
```php
    /**
     * 月末日取得
     *
     * @param Carbon $date 日付
     * @param Carbon $endDate 月末日付
     *
     * @return Carbon 月末日
     */
    public static function getMonthLastDate(Carbon $date, Carbon $endDate): Carbon
    {
        // 月末取得
        $monthLastDate = Carbon::create($date->year, $date->month, 1)->lastOfMonth();
        // 終了年月の場合、終了日付を設定
        if ($monthLastDate->format('Ym') === $endDate->format('Ym')) {
            $monthLastDate = $endDate;
        }
        return $monthLastDate;
    }
```

### File 2: `app/Libs/ZipanUtil.php` — method `getMonthLastDate`

**Before:**
```php
    public static function getMonthLastDate($date, $endDate)
    {
        // 月末取得
        $monthLastDate = Carbon::create($date->year, $date->month, 1)->lastOfMonth();
        // 終了年月の場合、終了日付を設定
        if ($monthLastDate->format('Ym') == $endDate->format('Ym')) {
            $monthLastDate = $endDate;
        }
        return $monthLastDate;
    }
```

**After:**
```php
    public static function getMonthLastDate(Carbon $date, Carbon $endDate): Carbon
    {
        // 月末取得
        $monthLastDate = Carbon::create($date->year, $date->month, 1)->lastOfMonth();
        // 終了年月の場合、終了日付を設定
        if ($monthLastDate->format('Ym') == $endDate->format('Ym')) {
            $monthLastDate = $endDate;
        }
        return $monthLastDate;
    }
```

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/Libs/DailyRateCalculationPreLogicTest.php
vendor/bin/phpunit tests/Unit/Libs/ZipanUtilTest.php
```

All callers already pass `Carbon` instances — adding the type hint just documents what's already true. A type error at runtime would indicate a pre-existing bug that was previously hidden.
