# ASC-XXX: Remove Dead `$condition` Initialization Before Loops

**Epic:** Nice to Have / Tech Debt  
**Scope:** Micro (delete 1 line per file)  
**Difficulty:** 1  
**Files:** `app/Libs/CommonUtil.php` (line 432), `app/Libs/ZipanUtil.php` (line 68)

---

## Context

In both `createDailyRateCalculation` methods, `$condition` is assigned an empty array immediately before a `foreach` that unconditionally overwrites it on every iteration. The initialization is dead code that misleadingly suggests accumulation.

---

## Steps

### File 1: `app/Libs/CommonUtil.php` — line 432

**Before:**
```php
            // 日割計算登録
            $condition = array();
            foreach ($ContractDateLists as $key => $value) {
                $condition = array(
```

**After:**
```php
            // 日割計算登録
            foreach ($ContractDateLists as $key => $value) {
                $condition = array(
```

Delete the line `$condition = array();` (line 432).

### File 2: `app/Libs/ZipanUtil.php` — line 68

**Before:**
```php
            // 日割計算登録
            $condition = [];
            foreach ($contractDateLists as $key => $value) {
                $condition = array(
```

**After:**
```php
            // 日割計算登録
            foreach ($contractDateLists as $key => $value) {
                $condition = array(
```

Delete the line `$condition = [];` (line 68).

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/Libs/DailyRateCalculationPreLogicTest.php
```

The variable is unconditionally assigned inside the loop body before any read — removing the pre-assignment has zero behavioral effect.
