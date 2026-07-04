# ASC-XXX: Replace `exit` with Exception in `DailyRateCalculationPreLogic`

**Epic:** Nice to Have / Tech Debt  
**Scope:** Small (3 lines changed)  
**Difficulty:** 2  
**Files:** `app/Libs/DailyRateCalculationPreLogic.php` (line ~43)

---

## Context

When `updateAccessToken()` fails, the code logs the error and calls `exit;`. This kills the PHP process immediately — no Laravel shutdown hooks fire, no transaction cleanup runs, and artisan cannot report a proper exit code to the scheduler/cron.

---

## Steps

### File: `app/Libs/DailyRateCalculationPreLogic.php` — inside `execute()`, lines 35-44

**Before:**
```php
        try {
            // freee会計APIアクセストークン設定
            CommonUtil::updateAccessToken();
        } catch (\Exception $e) {
            Log::error($e);
            Log::error('Failed to update access token.');
            Log::info('END DailyRateCalculationPreLogic');
            exit;
        }
```

**After:**
```php
        try {
            // freee会計APIアクセストークン設定
            CommonUtil::updateAccessToken();
        } catch (\Exception $e) {
            Log::error($e);
            Log::error('Failed to update access token.');
            throw new \RuntimeException('Failed to update access token: ' . $e->getMessage(), 0, $e);
        }
```

---

## Why This Is Safe

1. Nothing runs after `exit` today — throwing an exception also halts execution of this method.
2. The calling command (`DailyRateCalculationPreCommand`) uses `$logic->execute()` inside a simple `handle()` method. An uncaught `RuntimeException` propagates to artisan, which:
   - Logs the exception via Laravel's exception handler
   - Returns exit code 1 (FAILURE) to the process
   - Fires normal shutdown hooks (closing DB connections, flushing logs)
3. The `finally` block at line ~100 (`Log::info('END DailyRateCalculationPreLogic')`) will now fire correctly on exception, ensuring the log always shows the END marker.

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/Libs/DailyRateCalculationPreLogicTest.php
```

If you want to verify the exception path specifically, temporarily disable the network in your Docker container and run:
```bash
php artisan daily-rate-calculation:pre 2026-05-01
# Should see exit code 1 (not 0) and proper error in laravel.log
echo $?  # expect: 1
```
