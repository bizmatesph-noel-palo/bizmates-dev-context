# ASC-307 — Fix Monthly Pre Delete Scope: Use target_ym Instead of created_at

**Type:** Bug
**Priority:** High
**Reported by:** Wu-san (Sizhe Wu)
**Assignee:** TBA
**Investigation:** `[bizmates-dev-context] projects/ascm/technical-notes/investigation/20260701-pre-delete-scope/REPORT_00_Pre_Delete_Scope_Investigation.md`
**Related:** [ASC-220](https://bizmates.atlassian.net/browse/ASC-220)

---

## Summary

The Monthly Pre command deletes records from prior months when running for the current month. April and May Pre data was wiped during the July 1st execution because the delete uses `created_at >= targetFirstDate` (timestamp) instead of `target_ym = targetYm` (business key).

Note: `ClearCalculationLogsCommand` uses the same `created_at >=` pattern but is intentionally unchanged — it's a manual cleanup tool where operators deliberately clear all data from a run date forward before re-execution. Only the Monthly Pre inline delete (which auto-runs monthly) needs fixing.

---

## Current Behavior (Defect)

- Running Pre for June (exeDate = 2026-07-01) deletes ALL records with `created_at >= 2026-06-01`
- April (202604) and May (202605) records created on June 2nd (deployment day) are caught by this scope
- Result: prior months' Pre data is lost — cannot be used for reconciliation

---

## Expected Behavior (Correct)

- Running Pre for June should ONLY delete records with `target_ym = 202606`
- Records for April (202604) and May (202605) should remain untouched regardless of when they were created
- Re-running the same month is idempotent — only that month's data is cleared and re-inserted

---

## Root Cause

The delete logic uses `created_at` (when the record was written) instead of `target_ym` (which business period it belongs to). This works when records are always created within their own month, but fails when records are created outside their logical period (catch-up runs, late deployments).

The pattern was inherited from `DailyRateCalculationPreLogic` when the Monthly Pre was created. ASC-220 identified this issue; the implementation created `ClearCalculationLogsCommand` as a dedicated cleanup tool, but the inline delete in `MonthlyRateCalculationPreLogic` was not updated — an oversight during a high-volume sprint.

---

## Fix Approach

Change the delete scope from timestamp-based to business-key-based.

### Affected Locations

- [ ] `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` (~L158-175)

### Change

**Before:**
```php
$targetFirstDate = Carbon::parse($startDateFilter)->startOfMonth()->format('Y-m-d H:i:s');

$deletedBizmates = DB::connection(self::$BIZMATES_DATABASE)
    ->table(self::$TABLE_NAME)
    ->where('created_at', '>=', $targetFirstDate)
    ->delete();

$deletedZipan = DB::connection(self::$ZIPAN_DATABASE)
    ->table(self::$TABLE_NAME)
    ->where('created_at', '>=', $targetFirstDate)
    ->delete();
```

**After:**
```php
// FIX ASC-307: Delete by business key (target_ym) instead of timestamp (created_at).
$deletedBizmates = DB::connection(self::$BIZMATES_DATABASE)
    ->table(self::$TABLE_NAME)
    ->where('target_ym', '=', $targetYm)
    ->delete();

$deletedZipan = DB::connection(self::$ZIPAN_DATABASE)
    ->table(self::$TABLE_NAME)
    ->where('target_ym', '=', $targetYm)
    ->delete();
```

Remove `$targetFirstDate` variable (no longer needed).

---

## Acceptance Criteria

- [ ] Running Pre for June only deletes `target_ym = 202606` records
- [ ] Records with `target_ym = 202604` and `202605` are NOT deleted
- [ ] Re-running Pre for the same month clears and re-inserts correctly (idempotent)
- [ ] Log output: `[PRE DELETE] Bizmates: X record(s) deleted | target_ym=YYYYMM`
- [ ] Both Bizmates and Zipan connections use the same fixed scope

---

## Verification Steps

1. Confirm prior months have data in `log_monthly_rate_calculation_pre`
2. Run Pre command for current month
3. Check that only current month's records were deleted (query `target_ym` for prior months)
4. Check logs for correct delete count
5. Smoke test: command completes without error

---

## Risk Assessment

| Risk | Mitigation |
|---|---|
| `target_ym` column not indexed | Pre table is small — performance impact negligible |
| Different behavior from Daily Pre | Acknowledged — Daily Pre is out of scope (separate ticket if needed) |

---

## Test Case

Manual verification — not a calculation output change, so no structured TC needed.

---

## References

- KB: `[bizmates-dev-context] projects/ascm/knowledge-base/15-unsafe-delete-scope.md`
- Design Context: `[bizmates-dev-context] projects/ascm/knowledge-base/00-design-context.md` — Section 6

---

## Notes

- `ClearCalculationLogsCommand` NOT changed — its `created_at >=` is intentional for manual cleanup (full rebuild before re-execution)
- Daily Pre has the same `created_at >=` pattern — same risk exists but hasn't surfaced because Daily does a full rebuild (re-creates all data after deleting). Monthly Pre only inserts the current month, so prior months wiped by the broad scope are permanently lost.
- Both commands use the same unsafe idea. The fix is scoped to Monthly Pre only (what was reported). Daily is acknowledged as tech debt — separate ticket if needed.
- Final Monthly command (`MonthlyRateCalculationLogic`) does NOT delete — no change needed there
- The `target_ym` approach ensures idempotency: if Pre runs twice for the same month (operator error, retry), the second run safely clears and re-inserts without duplicates. Removing the delete entirely would cause duplicate rows on re-run (INSERT has no upsert or conflict handling).
