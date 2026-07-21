# ASC-292: Replace `exit` with Exception Throw in Logic Classes

## User Story

As a developer maintaining the ASC batch system, I want failed batch commands to return proper exit codes and trigger Laravel's shutdown hooks so that failures are detectable by the scheduler and DB connections are cleaned up correctly.

## Current Situation

Two logic classes call `exit;` when `updateAccessToken()` fails:

1. **`app/Libs/DailyRateCalculationPreLogic.php`** (line ~43) — logs error, calls `exit`
2. **`app/Libs/DataCorrectionLogic.php`** (line ~87) — logs error, logs a **wrong class name** (`'END DailyRateCalculationPreLogic'` — copy-paste bug), calls `exit`

Calling `exit` kills the PHP process immediately:
- No Laravel shutdown hooks fire
- No transaction rollback
- Artisan reports exit code 0 (success) to the scheduler
- `finally` blocks don't execute

## Proposed Solution

Replace `exit` with `throw new \RuntimeException(...)` in both files.

### Change 1: `app/Libs/DailyRateCalculationPreLogic.php` — lines 38–44

**Before:**
```php
        } catch (\Exception $e) {
            Log::error($e);
            Log::error('Failed to update access token.');
            Log::info('END DailyRateCalculationPreLogic');
            exit;
        }
```

**After:**
```php
        } catch (\Exception $e) {
            Log::error($e);
            Log::error('Failed to update access token.');
            throw new \RuntimeException('Failed to update access token: ' . $e->getMessage(), 0, $e);
        }
```

### Change 2: `app/Libs/DataCorrectionLogic.php` — lines 83–87

**Before:**
```php
        } catch (\Exception $e) {
            Log::error($e);
            Log::info('END DailyRateCalculationPreLogic');
            exit;
        }
```

**After:**
```php
        } catch (\Exception $e) {
            Log::error($e);
            Log::info('END DataCorrectionLogic');
            throw new \RuntimeException('DataCorrectionLogic initialization failed: ' . $e->getMessage(), 0, $e);
        }
```

## Acceptance Criteria

- [ ] `DailyRateCalculationPreLogic` throws `RuntimeException` instead of calling `exit`
- [ ] `DataCorrectionLogic` throws `RuntimeException` instead of calling `exit`
- [ ] The copy-paste log message is corrected from `'END DailyRateCalculationPreLogic'` to `'END DataCorrectionLogic'`
- [ ] Failed commands return exit code 1 (not 0) when access token update fails
- [ ] `finally` blocks execute correctly on failure
- [ ] Full test suite passes (`vendor/bin/phpunit`)

## Technical Notes

- **Branch:** `feature/ASC/ASC-292`
- **Epic:** ASC-289
- **Estimated time:** 15 minutes
- **Risk:** Low. Nothing runs after `exit` today — the exception stops execution at the same point but routes through Laravel's proper shutdown path. The calling commands do not have top-level catches that would swallow `RuntimeException`.

## Verification

```bash
vendor/bin/phpunit
```
