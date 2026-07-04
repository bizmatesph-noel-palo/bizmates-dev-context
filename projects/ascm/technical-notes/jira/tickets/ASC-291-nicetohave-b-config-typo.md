# ASC-291: Fix `errotMail` Config Key Typo

## User Story

As a developer searching for mail-related config keys, I want the config keys to be spelled correctly so that grep and IDE search return expected results without requiring knowledge of the historical typo.

## Current Situation

`config/const.php` defines two mail type keys with a typo:
- `'applicationErrotMail' => 8` (should be "Error")
- `'errotMail' => 9` (should be "Error")

These are only referenced in two places in `app/Libs/CommonUtil.php`. The integer values (8, 9) are what actually get passed to `sendMail()` to look up the mail template from the DB — the string key name is purely for developer readability and has no runtime effect beyond config lookup.

## Proposed Solution

Rename the keys directly and update the 2 references. This is safe because:
1. The string keys are only accessed via `config('const.mailType.xxx')` in PHP code
2. Only 2 call sites exist (both in `CommonUtil.php`)
3. The DB stores the integer value (8/9), not the string key
4. No external system references these config key names

### Change 1: `config/const.php` — `mailType` array (around line 288)

**Before:**
```php
        // エラーメール
        'applicationErrotMail' => 8,
        // エラーメール
        'errotMail' => 9,
```

**After:**
```php
        // アプリケーションエラーメール
        'applicationErrorMail' => 8,
        // システムエラーメール
        'errorMail' => 9,
```

### Change 2: `app/Libs/CommonUtil.php` — `sendErrorMail()` method (line ~101)

**Before:**
```php
        static::sendMail(config('const.mailType.applicationErrotMail'), array(), $contents);
```

**After:**
```php
        static::sendMail(config('const.mailType.applicationErrorMail'), array(), $contents);
```

### Change 3: `app/Libs/CommonUtil.php` — `sendSystemErrorMail()` method (line ~115)

**Before:**
```php
        static::sendMail(config('const.mailType.errotMail'), array(), $contents);
```

**After:**
```php
        static::sendMail(config('const.mailType.errorMail'), array(), $contents);
```

## Acceptance Criteria

- [ ] `config('const.mailType.applicationErrorMail')` returns `8`
- [ ] `config('const.mailType.errorMail')` returns `9`
- [ ] Old typo keys (`applicationErrotMail`, `errotMail`) no longer exist in the codebase
- [ ] `CommonUtil::sendErrorMail()` references the corrected key
- [ ] `CommonUtil::sendSystemErrorMail()` references the corrected key
- [ ] Email sending still works (integer values 8/9 unchanged — mail template lookup unaffected)
- [ ] Full test suite passes (`vendor/bin/phpunit`)

## Technical Notes

- **Branch:** `feature/ASC/ASC-291`
- **Epic:** ASC-289
- **Estimated time:** 5 minutes
- **Risk:** None. The config key is a string label for developer use. The runtime value (integer 8 or 9) is unchanged. The DB `mst_mail_template` table is keyed by the integer `mail_type`, not the config string. Only 2 call sites exist and both are updated.

## Verification

```bash
grep -r "errotMail" app/ config/  # should return 0 results
vendor/bin/phpunit
```
