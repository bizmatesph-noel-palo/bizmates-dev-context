# ASC-XXX: Add Type Hints to `getSegment2Id`

**Epic:** Nice to Have / Tech Debt  
**Scope:** Micro (1 signature change per file)  
**Difficulty:** 1  
**Files:** `app/Libs/CommonUtil.php` (line ~670), `app/Libs/ZipanUtil.php` (line ~245)

---

## Context

`getSegment2Id()` exists in both `CommonUtil` and `ZipanUtil`. It accepts a department ID and contract type (both nullable ints) and returns either `3` or the passed contract type (int|null). No type hints exist on either version.

---

## Steps

### File 1: `app/Libs/CommonUtil.php`

**Before:**
```php
    /**
     * セグメント２ID取得
     *
     * @param $departmentId：部署ID
     * @param $contractType：コントラクトタイプ
     * @return $return：セグメント２ID（コントラクトタイプ）
     */
    public static function getSegment2Id($departmentId, $contractType)
    {
        // PartnerのDepartmentId
        $PartnerDepartmentIdList = config('const.PartnerDepartmentId');

        $return = null;
        if (in_array($departmentId, $PartnerDepartmentIdList)) {
            $return = 3;
        } else {
            $return = $contractType;
        }
        return $return;
    }
```

**After:**
```php
    /**
     * セグメント２ID取得
     *
     * @param int|null $departmentId 部署ID
     * @param int|null $contractType コントラクトタイプ
     * @return int|null セグメント２ID（コントラクトタイプ）
     */
    public static function getSegment2Id(?int $departmentId, ?int $contractType): ?int
    {
        // PartnerのDepartmentId
        $PartnerDepartmentIdList = config('const.PartnerDepartmentId');

        if (in_array($departmentId, $PartnerDepartmentIdList)) {
            return 3;
        }

        return $contractType;
    }
```

### File 2: `app/Libs/ZipanUtil.php`

**Before:**
```php
    public static function getSegment2Id($departmentId, $contractType)
    {
        // PartnerのDepartmentId
        $PartnerDepartmentIdList = config('zipan_const.PartnerDepartmentId');

        $return = null;
        if (in_array($departmentId, $PartnerDepartmentIdList)) {
            $return = 3;
        } else {
            $return = $contractType;
        }
        return $return;
    }
```

**After:**
```php
    public static function getSegment2Id(?int $departmentId, ?int $contractType): ?int
    {
        // PartnerのDepartmentId
        $PartnerDepartmentIdList = config('zipan_const.PartnerDepartmentId');

        if (in_array($departmentId, $PartnerDepartmentIdList)) {
            return 3;
        }

        return $contractType;
    }
```

---

## Notes

The refactored version also removes the unnecessary intermediate `$return` variable — the early return pattern is clearer and shorter. This is optional; if the team prefers to keep the structure identical, just add the type hints to the original signature without changing the body.

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/Libs/SendJournalsDataLogicTest.php
vendor/bin/phpunit tests/Unit/Libs/ZipanUtilTest.php
```

All callers pass `int|null` — this just documents the existing contract.
