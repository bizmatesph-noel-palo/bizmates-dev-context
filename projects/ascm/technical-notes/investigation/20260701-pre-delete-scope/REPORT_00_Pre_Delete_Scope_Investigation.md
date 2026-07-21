# Pre Delete Scope — Prior Months Wiped (20260701)

**Reported by:** Wu-san (Sizhe Wu)
**JIRA Ticket:** [ASC-307](https://bizmates.atlassian.net/browse/ASC-307) (related: [ASC-220](https://bizmates.atlassian.net/browse/ASC-220))
**Investigated by:** Noel
**Date:** 2026-07-01
**Environment:** Production
**Batch run analyzed:** July 2026 Pre execution (exeDate = 2026-07-01, processes June 2026)

---

## Summary

After today's Pre command execution, all `log_monthly_rate_calculation_pre` records with `target_ym = 202604` and `target_ym = 202605` were deleted. These records were created on June 2nd (the day ASC was deployed to production) and were caught by the delete scope which removes everything with `created_at >= 2026-06-01`.

**Root cause (confirmed via code trace):** The `MonthlyRateCalculationPreLogic` delete uses `created_at >= $targetFirstDate` (timestamp-based) instead of `target_ym = $targetYm` (business-key-based). When processing June 2026, it computes `targetFirstDate = 2026-06-01 00:00:00` and deletes ALL records created on or after that date — regardless of which month they belong to.

**Impact:** April and May Pre data lost. Final data (`log_monthly_rate_calculation`) is unaffected — only the Pre (`_pre`) table was wiped.

---

## Code Trace

### MonthlyRateCalculationPreLogic.php (~L158-175)

```php
$targetYm = date('Ym', strtotime($startDateFilter));
$targetFirstDate = Carbon::parse($startDateFilter)->startOfMonth()->format('Y-m-d H:i:s');

// Delete old data
$deletedBizmates = DB::connection(self::$BIZMATES_DATABASE)
    ->table(self::$TABLE_NAME)
    ->where('created_at', '>=', $targetFirstDate)
    ->delete();

$deletedZipan = DB::connection(self::$ZIPAN_DATABASE)
    ->table(self::$TABLE_NAME)
    ->where('created_at', '>=', $targetFirstDate)
    ->delete();
```

For today's execution:
- `startDateFilter = 2026-06-01` (exeDate 2026-07-01 → processes previous month)
- `targetFirstDate = 2026-06-01 00:00:00`
- Delete scope: `created_at >= '2026-06-01 00:00:00'`
- April/May records: `created_at = 2026-06-02` (deployment day)
- `2026-06-02 >= 2026-06-01` → **TRUE** → deleted ❌

---

## Why This Pattern Exists

The Monthly Pre delete logic was patterned after the `DailyRateCalculationPreLogic`, which uses the same approach:

```php
// DailyRateCalculationPreLogic.php (~L214)
DB::connection('mysql')
    ->table($table)
    ->where('created_at', '>=', $targetStartDate)
    ->delete();
```

The Daily command deletes from 10 tables (6 Bizmates + 4 Zipan) using the same `created_at >= targetStartDate` scope. The Monthly Pre inherited this pattern when it was created.

### The Consistent Pattern

The `created_at >=` delete scope is the consistent pattern across the entire codebase:

| Location | Delete approach | Tables affected |
|---|---|---|
| `DailyRateCalculationPreLogic` | `created_at >= targetStartDate` | 6 Bizmates + 4 Zipan tables |
| `MonthlyRateCalculationPreLogic` | `created_at >= targetFirstDate` | `log_monthly_rate_calculation_pre` (both connections) |
| `ClearCalculationLogsCommand` | `created_at >= $date` | All log tables (manual command) |
| `MonthlyRateCalculationLogic` (Final) | No delete | — |

This pattern works without issue when:
- The system runs monthly on schedule (records for month N are always created in month N)
- No catch-up runs or late deployments occur

It fails when records are created AFTER their logical period — as happened here: April/May records were created on June 2nd because that's when the system was first deployed to production.

---

## What Went Wrong

[ASC-220](https://bizmates.atlassian.net/browse/ASC-220) identified the unsafe delete scope pattern. During implementation, a `ClearCalculationLogsCommand` was created as a dedicated cleanup tool — intended to give operators explicit control over when and what to clear.

However, the **inline delete in `MonthlyRateCalculationPreLogic` was never updated or removed**. It continued using the original `created_at >= targetFirstDate` scope. With the volume of work happening concurrently during the project timeline, this was simply overlooked — not intentional.

The result: the Monthly Pre command still auto-deletes on every run using the unsafe timestamp-based scope, while a separate cleanup command exists alongside it. The fix is straightforward — change the scope to `target_ym` (business key) so only the target month is affected.

---

## Why the Daily Command Wasn't Affected

The Daily Pre (`DailyRateCalculationPreLogic`) uses the same `created_at >= targetStartDate` pattern and carries the same theoretical risk. It hasn't surfaced as a problem because of how the two commands differ:

| Aspect | Monthly Pre | Daily Pre |
|---|---|---|
| Deletes from | 1 table (`log_monthly_rate_calculation_pre`) | ~10 tables (daily, summary, balance, etc.) |
| Re-creates | Only the CURRENT month's monthly data | Everything — full rebuild of all tables |
| If prior months are wiped | **Gone permanently** — not re-created | Re-populated by the same run (full rebuild) |

The Daily command is a full rebuild — delete everything, recreate everything. Even with the broad scope, the end state is correct because it repopulates all data in the same execution. The Monthly Pre is a targeted insert — it only writes the current month. If the delete wipes prior months, they're gone and not re-created.

**Both commands use the same unsafe idea.** The Daily command hasn't failed because its full-rebuild approach masks the over-deletion. But the risk exists — if a scenario arose where the Daily rebuild couldn't regenerate data it deleted (e.g., a table that depends on external state no longer available), the same issue would surface.

**This fix is scoped to Monthly Pre only** (what was reported and confirmed broken). The Daily command's identical pattern is acknowledged as tech debt — a separate ticket if/when it causes a problem or if the team decides to address it proactively.

---

## Scope Assessment

| Aspect | Assessment |
|---|---|
| Is this an ASC scope issue? | **Yes** — the delete logic is in ASC code |
| Severity | Medium — Pre data is draft (accounting team uses Final for official numbers) |
| Data loss? | Pre data for April/May lost. Recoverable by re-running those months. |
| Final data affected? | **No** — `MonthlyRateCalculationLogic` (Final) does not delete |
| Which tenants? | Both Bizmates and Zipan |

---

## Expected Fix

Change the inline delete scope in `MonthlyRateCalculationPreLogic` from timestamp-based to business-key-based. Only the Monthly Pre command is affected — `ClearCalculationLogsCommand` is intentionally left unchanged (it's a manual cleanup tool where `created_at >=` is the correct behavior — operators run it deliberately to clear all data from a specific run date forward before re-execution).

Detailed solution: `[bizmates-dev-context] projects/ascm/technical-notes/jira/tickets/ASC-307-fix-delete-scope-pre-and-cleanup.md`

---

## Recovery

To restore April/May Pre data:

```bash
# Clear any partial data first
php artisan command:ClearCalculationLogsCommand 202604
php artisan command:ClearCalculationLogsCommand 202605

# Re-run Pre for April (exeDate = 2026-05-01 → processes April)
php artisan command:MonthlyRateCalculationPreCommand 2026-05-01

# Re-run Pre for May (exeDate = 2026-06-01 → processes May)
php artisan command:MonthlyRateCalculationPreCommand 2026-06-01
```

Note: This should only be done if the accounting team needs the Pre data for April/May. Since Final data is unaffected, this may not be urgent.

---

## Cross-Reference

- KB article: `[bizmates-dev-context] projects/ascm/knowledge-base/15-unsafe-delete-scope.md`
- Design context: `[bizmates-dev-context] projects/ascm/knowledge-base/00-design-context.md` — Section 6 (No Batch Orchestration)
- Related JIRA: [ASC-220](https://bizmates.atlassian.net/browse/ASC-220) (original fix request)
- Code: `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` lines ~158-175
- Same pattern: `[ASC] app/Libs/DailyRateCalculationPreLogic.php` lines ~192-238
- Cleanup command: `[ASC] app/Console/Commands/ClearCalculationLogsCommand.php` line ~122
