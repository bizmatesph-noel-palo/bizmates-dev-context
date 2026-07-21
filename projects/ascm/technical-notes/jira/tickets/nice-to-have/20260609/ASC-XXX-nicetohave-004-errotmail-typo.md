# ASC-XXX: Fix `errotMail` Config Key Typo (Additive Alias)

**Epic:** Nice to Have / Tech Debt  
**Scope:** Small (6 lines)  
**Difficulty:** 2  
**Files:** `config/const.php`

---

## Context

`config/const.php` defines two mail type keys with a typo: `applicationErrotMail` and `errotMail` (should be "Error", not "Errot"). Since renaming could break references in other parts of the system (DB-stored mail_type values, external templates), we add correctly-spelled aliases while keeping the originals marked as deprecated.

---

## Steps

### File: `config/const.php` — inside the `'mailType'` array (around line 288)

**Before:**
```php
    'mailType' => [
        // 日割計算結果（速報版）送信メール
        'dailyRateCalculationPreMail' => 1,
        // 日割計算結果送信メール
        'dailyRateCalculationMail' => 2,
        // 振替伝票送信結果メール
        'sendJournalsMail' => 3,
        // エラーメール
        'applicationErrotMail' => 8,
        // エラーメール
        'errotMail' => 9,
        // 修正バッチ
        'reCalculation' => 10
    ],
```

**After:**
```php
    'mailType' => [
        // 日割計算結果（速報版）送信メール
        'dailyRateCalculationPreMail' => 1,
        // 日割計算結果送信メール
        'dailyRateCalculationMail' => 2,
        // 振替伝票送信結果メール
        'sendJournalsMail' => 3,
        // アプリケーションエラーメール
        'applicationErrorMail' => 8,
        'applicationErrotMail' => 8, // @deprecated typo — kept for backward compat
        // システムエラーメール
        'errorMail' => 9,
        'errotMail' => 9, // @deprecated typo — kept for backward compat
        // 修正バッチ
        'reCalculation' => 10
    ],
```

---

## Notes

- Do **NOT** change any existing references in `CommonUtil.php` (`sendErrorMail` and `sendSystemErrorMail` still use the typo keys). Those can be updated in a follow-up PR once the team confirms no external systems reference these config keys by name.
- The numeric values (8, 9) are what actually gets stored/compared — the string keys are just for developer readability.
- Future new code should use `config('const.mailType.applicationErrorMail')` and `config('const.mailType.errorMail')`.

---

## Verification

```bash
php artisan tinker --execute="var_dump(config('const.mailType.applicationErrorMail') === 8);"
php artisan tinker --execute="var_dump(config('const.mailType.applicationErrotMail') === 8);"
```

Both should output `bool(true)`. Run full test suite to confirm nothing breaks:

```bash
vendor/bin/phpunit
```
