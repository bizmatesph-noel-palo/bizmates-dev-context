# ASC-XXX: Remove Lookahead & Simplify Lesson Counting Bounds

## Status: Waiting (Kuroda-san reviewing — no JIRA ticket yet)
## Epic: TBA
## Branch from: ASC-master (after ASC-301 is merged)

## Context

During code review of ASC-301, Kuroda-san identified that:
1. The lookahead can be removed entirely (Option B) since the guarded scenario never exists
2. The `lessons_taken` CASE expression has two equivalent branches (dead logic from ASC-287)
3. The EvaluationFilter fetches 2 extra days of data that is never used

**Investigation:** `[asc-kiro] Technical_Notes/Issue_Investigation/20260623_check_lookahead_condition/REPORT_01_Kuroda_Questions_Analysis.md`

## Changes

### Change 1: Remove Lookahead (replaces ASC-301 `rn = total_rows` gate)

Remove the entire OR block from `is_ticket_expiry_month` in the Grouped CTE:

```sql
-- REMOVE:
OR (
    om.rn = om.total_rows
    AND om.end_date > LAST_DAY(om.month_start)
    AND om.end_date <= DATE_ADD(LAST_DAY(om.month_start), INTERVAL 2 DAY)
    AND NOT EXISTS (
        SELECT 1 FROM StudentProduct sp3
        WHERE sp3.student_id = om.student_id
            AND sp3.product_id = om.product_id
            AND (sp3.order_no <=> om.order_no)
            AND sp3.start_date > om.end_date
    )
)
```

**4 locations:**
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Bizmates Grouped CTE
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Zipan Grouped CTE
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Bizmates Grouped CTE
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Zipan Grouped CTE

### Change 2a: Simplify `lessons_taken` Upper Bound

**Before:**
```sql
AND ef.lesson_datetime < CASE
    WHEN tm.month_start = DATE_FORMAT(DATE({startDate}), '%Y-%m-01')
    THEN DATE_ADD(LAST_DAY(DATE({startDate})), INTERVAL 1 DAY)
    ELSE DATE_ADD(tm.month_start, INTERVAL 1 MONTH)
END
```

**After:**
```sql
AND ef.lesson_datetime < DATE_ADD(tm.month_start, INTERVAL 1 MONTH)
```

**4 locations:**
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Bizmates MonthlyUsage
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Zipan MonthlyUsage
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Bizmates MonthlyUsage
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Zipan MonthlyUsage

### Change 2b: Reduce EvaluationFilter Window

**Before:**
```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({startDate}), INTERVAL 3 MONTH)
                      AND DATE_ADD(LAST_DAY(DATE({startDate})), INTERVAL 2 DAY)
```

**After (tightest safe bound — confirmed with Kuroda-san 2026-06-26):**
```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({startDate}), INTERVAL 3 MONTH)
                      AND LAST_DAY(DATE({startDate}))
```

**Why no offset is needed:**
- Counting logic: `lesson_datetime < DATE_ADD(month_start, INTERVAL 1 MONTH)` = first of next month at midnight
- Any countable lesson has `lesson_date ≤ LAST_DAY` (datetime before midnight on 1st → date is still last day)
- No downstream CTE stage references EvaluationFilter rows beyond the counting bound

**4 locations:**
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Bizmates EvaluationFilter
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Zipan EvaluationFilter
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Bizmates EvaluationFilter
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Zipan EvaluationFilter

## Acceptance Criteria

1. All existing test cases (TC001–TC035) pass — no output changes
2. TC035 (ASC-301): April shows remaining=15, May shows expired=15 (same as current ASC-301 fix)
3. TC013 (B2B REST): February shows remaining, March shows expired (unchanged — `is_last_charge_in_order` handles it)
4. No performance regression on batch execution time

## Verification

1. Run test case simulation (all 35 TCs) against DEV04 output
2. Compare CSV output before/after for a full month (April or May 2026)
3. Verify no new charges appear or disappear from the output
4. Check batch execution time hasn't degraded

## Risk Assessment

| Change | Risk | Rationale |
|---|---|---|
| Remove lookahead | Low | Scenario never existed in production. Next-month row always handles expiry. |
| Simplify CASE | None | Both branches produce identical results for any month. Pure cleanup. |
| Reduce EvaluationFilter | Very low | Extra rows were fetched but never counted. No output change. Slight performance improvement. |

## Dependencies

- ASC-301 must be deployed first (or this ticket replaces it entirely — the lookahead removal is a superset of the `rn = total_rows` gate)
- If this ticket is approved, ASC-301's `rn = total_rows` gate becomes unnecessary — the entire block is removed instead of gated

## Notes

- Total code changes: ~12 locations (4 per change × 3 changes)
- All changes are in the same 2 files (Logic + PreLogic)
- Changes are independent — can be applied as separate commits for easier review
- Comment blocks referencing ASC-287/ASC-261 CASE logic should be updated or removed
