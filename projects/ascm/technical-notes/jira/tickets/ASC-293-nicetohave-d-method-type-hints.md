# ASC-293: Add Type Hints to `getMonthLastDate` + `getSegment2Id`

## User Story

As a developer navigating the ASC codebase, I want utility method signatures to declare their parameter and return types so that IDE autocomplete works correctly and Larastan can verify usage without manual `@var` annotations.

## Current Situation

Two utility methods exist in both `CommonUtil` and `ZipanUtil` with no type declarations:

- `getMonthLastDate($date, $endDate)` — always receives `Carbon`, always returns `Carbon`
- `getSegment2Id($departmentId, $contractType)` — always receives `?int`, always returns `?int`

Without type hints, IDEs cannot autocomplete method calls on the return value, and Larastan cannot verify property access in the calling code.

## Proposed Solution

Add parameter and return type declarations to both methods in both files. No logic changes.

### Change 1: `getMonthLastDate` — add Carbon types

**Files:** `app/Libs/CommonUtil.php` (line 1218), `app/Libs/ZipanUtil.php` (line ~235)

**Before:**
```php
    public static function getMonthLastDate($date, $endDate)
```

**After:**
```php
    public static function getMonthLastDate(Carbon $date, Carbon $endDate): Carbon
```

Also update docblock in CommonUtil from `@return object` to `@return Carbon`.

### Change 2: `getSegment2Id` — add int|null types

**Files:** `app/Libs/CommonUtil.php` (line ~670), `app/Libs/ZipanUtil.php` (line ~245)

**Before:**
```php
    public static function getSegment2Id($departmentId, $contractType)
```

**After:**
```php
    public static function getSegment2Id(?int $departmentId, ?int $contractType): ?int
```

## Acceptance Criteria

- [ ] `CommonUtil::getMonthLastDate` has `Carbon $date, Carbon $endDate` parameters and `: Carbon` return type
- [ ] `ZipanUtil::getMonthLastDate` has `Carbon $date, Carbon $endDate` parameters and `: Carbon` return type
- [ ] `CommonUtil::getSegment2Id` has `?int` parameter types and `?int` return type
- [ ] `ZipanUtil::getSegment2Id` has `?int` parameter types and `?int` return type
- [ ] Full test suite passes (`vendor/bin/phpunit`)

## Technical Notes

- **Branch:** `feature/ASC/ASC-293`
- **Epic:** ASC-289
- **Estimated time:** 10 minutes
- **Risk:** Zero. All callers already pass the correct types. Adding type hints documents what's already true. A `TypeError` at runtime would indicate a pre-existing hidden bug.

## Verification

```bash
vendor/bin/phpunit tests/Unit/Libs/
vendor/bin/phpunit
```
