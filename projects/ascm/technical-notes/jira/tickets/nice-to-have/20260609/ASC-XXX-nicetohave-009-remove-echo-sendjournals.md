# ASC-XXX: Remove Raw `echo` Statements from `SendJournalsDataLogic`

**Epic:** Nice to Have / Tech Debt  
**Scope:** Medium (~25 lines deleted)  
**Difficulty:** 2  
**Files:** `app/Libs/SendJournalsDataLogic.php`

---

## Context

`SendJournalsDataLogic::execute()` has ~25 `echo "..." . PHP_EOL` statements interspersed with `Log::info(...)` calls. Every `echo` duplicates a message already sent to `Log::info`. The `echo` calls:

- Bypass artisan's `--quiet` / verbosity flags
- Produce raw stdout during tests (pollutes test output)
- Don't follow the pattern used by other logic classes (`DailyRateCalculationPreLogic`, `MonthlyRateCalculationLogic`) which only use `Log::info`

---

## Steps

### File: `app/Libs/SendJournalsDataLogic.php`

Delete every line matching `echo ... PHP_EOL;` in the `execute()` method. The affected lines are:

| Line | Content to delete |
|------|-------------------|
| 53 | `echo "Send Journals - NO SEND FLAG IS SET. Will not send journals to Freee." . PHP_EOL;` |
| 57 | `echo "Send Journals - NO DAILY RATE CALCULATION FLAG IS SET. Will not generate daily rate calculation records." . PHP_EOL;` |
| 74 | `echo 'Send Journals - 処理対象年月：' . $targetYm . PHP_EOL;` |
| 79 | `echo 'Send Journals - 処理対象期間：' . $targetStartDate . '～' . $targetEndDate . PHP_EOL;` |
| 88 | `echo 'Send Journals - Freee請求書情報取得 - Start' . PHP_EOL;` |
| 91 | `echo 'Send Journals - Freee請求書情報取得 - End' . PHP_EOL;` |
| 95 | `echo 'Send Journals - Freee請求情報チェック - Start' . PHP_EOL;` |
| 98 | `echo 'Send Journals - Freee請求情報チェック - End' . PHP_EOL;` |
| 102 | `echo 'Send Journals - 日割情報作成 - Skipped' . PHP_EOL;` |
| 104 | `echo 'Send Journals - Zipan日割情報作成 - Skipped' . PHP_EOL;` |
| 108 | `echo 'Send Journals - 日割情報作成 - Start' . PHP_EOL;` |
| 111 | `echo 'Send Journals - 日割情報作成 - End' . PHP_EOL;` |
| 115 | `echo 'Send Journals - Zipan日割情報作成 - Start' . PHP_EOL;` |
| 118 | `echo 'Send Journals - Zipan日割情報作成 - End' . PHP_EOL;` |
| 123 | `echo 'Saving Current Records to DB' . PHP_EOL;` |
| 132 | `echo 'Send Journals - Freee連携処理 - Skipped' . PHP_EOL;` |
| 135 | `echo 'Send Journals - Freee連携処理 - Start' . PHP_EOL;` |
| 138 | `echo 'Send Journals - Freee連携処理 - End' . PHP_EOL;` |
| 143 | `echo 'Saving Current Records to DB' . PHP_EOL;` |
| 151 | `echo 'Send Journals - Create Balance Transition 残高推移作成 - Start' . PHP_EOL;` |
| 154 | `echo 'Send Journals - Create Balance Transition 残高推移作成 - End' . PHP_EOL;` |
| 158 | `echo 'Send Journals - Create Balance Transition with Order Number 残高推移作成 - Start' . PHP_EOL;` |
| 162 | `echo 'Send Journals - Create Balance Transition with Order Number 残高推移作成 - End' . PHP_EOL;` |
| 166 | `echo 'Saving Current Records to DB' . PHP_EOL;` |
| 175 | `echo 'Send Journals - メール添付ファイル作成 - Start' . PHP_EOL;` |
| 179 | `echo 'Send Journals - メール添付ファイル作成 - End' . PHP_EOL;` |
| 183 | `echo 'メール送信' . PHP_EOL;` |

**Approach:** Use find-and-replace to delete all lines containing `echo` followed by `. PHP_EOL;` in this file. Leave all `Log::info(...)` lines intact.

---

## Example (before/after for one block)

**Before:**
```php
        $targetYm = CommonUtil::getTargetYm();
        Log::info('Send Journals - 処理対象年月：' . $targetYm);
        echo 'Send Journals - 処理対象年月：' . $targetYm . PHP_EOL;

        // 処理対象開始／終了年月日取得
        [$targetStartDate, $targetEndDate] = CommonUtil::getTargetFromTo();
        Log::info('Send Journals - 処理対象期間：' . $targetStartDate . '～' . $targetEndDate);
        echo 'Send Journals - 処理対象期間：' . $targetStartDate . '～' . $targetEndDate . PHP_EOL;
```

**After:**
```php
        $targetYm = CommonUtil::getTargetYm();
        Log::info('Send Journals - 処理対象年月：' . $targetYm);

        // 処理対象開始／終了年月日取得
        [$targetStartDate, $targetEndDate] = CommonUtil::getTargetFromTo();
        Log::info('Send Journals - 処理対象期間：' . $targetStartDate . '～' . $targetEndDate);
```

---

## Why This Is Safe

- Every `echo` has an identical `Log::info` on the line above it — no information is lost.
- The scheduler and monitoring systems read exit codes and log files, not stdout.
- `DailyRateCalculationPreLogic` and `MonthlyRateCalculationLogic` already use log-only (no echo) and work correctly in production.

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/Libs/SendJournalsDataLogicTest.php
```

To confirm logs still appear:
```bash
make php-logs  # tail the Laravel log and run the command with --no-send
```
