# ASC-XXX: Replace `exit` with Exception in `DataCorrectionLogic`

**Epic:** Nice to Have / Tech Debt  
**Scope:** Small (3 lines changed)  
**Difficulty:** 2  
**Files:** `app/Libs/DataCorrectionLogic.php` (lines 83-87)

---

## Context

When `updateAccessToken()` or file existence check fails, the code logs the error and calls `exit;`. Two problems:

1. `exit` kills the PHP process without Laravel shutdown hooks (same issue as the PreLogic class).
2. The log message says `'END DailyRateCalculationPreLogic'` — a **copy-paste bug** from the other class. It should reference `DataCorrectionLogic`.

Both are fixed by throwing an exception (the correct class name appears naturally in the stack trace).

---

## Steps

### File: `app/Libs/DataCorrectionLogic.php` — inside `execute()`, lines 76-87

**Before:**
```php
        try {
            $filePath = storage_path('app/csv/correction_' . $now . '.csv');
            if (!\File::exists($filePath)) {
                throw new \Exception('処理対象のファイルが存在しません。ファイル：' . $filePath);
            }
            // freee会計APIアクセストークン設定
            \App\Libs\CommonUtil::updateAccessToken();
        } catch (\Exception $e) {
            Log::error($e);
            Log::info('END DailyRateCalculationPreLogic');
            exit;
        }
```

**After:**
```php
        try {
            $filePath = storage_path('app/csv/correction_' . $now . '.csv');
            if (!\File::exists($filePath)) {
                throw new \Exception('処理対象のファイルが存在しません。ファイル：' . $filePath);
            }
            // freee会計APIアクセストークン設定
            \App\Libs\CommonUtil::updateAccessToken();
        } catch (\Exception $e) {
            Log::error($e);
            throw new \RuntimeException('DataCorrectionLogic initialization failed: ' . $e->getMessage(), 0, $e);
        }
```

---

## What This Fixes

1. **Copy-paste log bug:** The misleading `'END DailyRateCalculationPreLogic'` message is removed. The stack trace in the thrown exception identifies the correct class.
2. **Graceful shutdown:** Artisan properly reports FAILURE exit code to the scheduler.
3. **Testability:** The exception can be asserted in tests; `exit` cannot.

---

## Why This Is Safe

- Nothing runs after `exit` today — the exception stops execution at the same point.
- The calling `DataCorrectionCommand`'s `handle()` does not have a top-level catch that would swallow this. The exception propagates to artisan's default handler.
- The `finally` block at line ~169 (`Log::info('End DataCorrectionDataLogic')`) will now fire correctly.

---

## Verification

```bash
vendor/bin/phpunit
```

To manually test the failure path:
```bash
# Remove the expected CSV to trigger the file-not-found path
php artisan data:correction
echo $?  # expect: 1 (not 0)
```
