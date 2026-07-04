# ASC-287: 2-Day Lookahead Causes Double-Attribution of Cross-Boundary Lessons (Bug C)

## Type: Bug Fix
## Priority: Medium
## Parent: ASC-283 (Investigation)
## Branch from: ASC-master (with ASC-276/277 merged)
## Depends on: ASC-285 (apply NULL order_no fix first for combined verification)
## Affected Files:
- `app/Libs/MonthlyRateCalculationLogic.php` (Bizmates + Zipan queries)
- `app/Libs/MonthlyRateCalculationPreLogic.php` (Bizmates + Zipan queries)

---

## Summary

When a lesson falls on the 1st or 2nd of a month (e.g., May 1) and the charge spans across months (e.g., April–May), the April batch counts the lesson via its 2-day lookahead AND the May batch also counts it in its own window. This causes:
- `number_of_lessons_taken` to exceed `lesson_volume` (e.g., 16 > 15)
- Over-recognition of paid_price across the two months

## Root Cause

The per-month lesson counting in the MonthlyUsage CTE uses a 2-day lookahead for the target month (added in ASC-261):

```sql
AND ef.lesson_datetime < CASE
    WHEN tm.month_start = DATE_FORMAT(DATE({$startDate}), '%Y-%m-01')
    THEN DATE_ADD(LAST_DAY(DATE({$startDate})), INTERVAL 2 DAY)   -- target month: +2 days
    ELSE DATE_ADD(tm.month_start, INTERVAL 1 MONTH)               -- other months: strict
END
```

**April batch** (target = April): upper bound = `LAST_DAY(April) + 2 = 2026-05-02`
→ A lesson on `2026-05-01 10:30` is `< 2026-05-02` → counted in April

**May batch** (target = May): lower bound = `month_start = 2026-05-01`
→ Same lesson is `>= 2026-05-01` → counted in May

The same lesson is attributed to both months because the boundaries overlap.

## Business Decision (Confirmed)

**Lessons should be attributed to the calendar month they occurred.** A lesson on May 1 belongs to May, not April.

(Confirmed by Kuroda-san, See this Slack Thread https://bizmatesinc.slack.com/archives/C0A1E2D7AF7/p1780897957805479?thread_ts=1780896841.284179&cid=C0A1E2D7AF7)

## Fix Instructions

### The Change

In the `MonthlyUsage` CTE's lesson counting CASE expression, change the target-month upper bound from `INTERVAL 2 DAY` to `INTERVAL 1 DAY`:

**Before:**
```sql
WHEN tm.month_start = DATE_FORMAT(DATE({$startDate}), '%Y-%m-01')
THEN DATE_ADD(LAST_DAY(DATE({$startDate})), INTERVAL 2 DAY)
```

**After:**
```sql
WHEN tm.month_start = DATE_FORMAT(DATE({$startDate}), '%Y-%m-01')
THEN DATE_ADD(LAST_DAY(DATE({$startDate})), INTERVAL 1 DAY)
```

This makes the upper bound = first day of next month (exclusive). A lesson on May 1 is `NOT < May 1` → not counted in April.

### Do NOT change the EvaluationFilter window

The `EvaluationFilter` CTE's WHERE clause also uses `INTERVAL 2 DAY`:

```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({$startDate}), INTERVAL 3 MONTH)
                      AND DATE_ADD(LAST_DAY(DATE({$startDate})), INTERVAL 2 DAY)
```

This must remain `INTERVAL 2 DAY`. It ensures evaluation rows are fetched into the working set. Only the per-month *counting* boundary needs tightening.

### Locations

**`MonthlyRateCalculationLogic.php`:**

1. **Bizmates MonthlyUsage** — look for the comment `FIX ASC-157/ASC-261` inside the COALESCE/SUM:
   ```sql
   THEN DATE_ADD(LAST_DAY(DATE({$startDate})), INTERVAL 2 DAY)
   ```
   Change `INTERVAL 2 DAY` → `INTERVAL 1 DAY`

2. **Zipan MonthlyUsage** — same pattern, same change.

**`MonthlyRateCalculationPreLogic.php`:**

3. **Bizmates MonthlyUsage** — same change.
4. **Zipan MonthlyUsage** — same change.

### Total: 4 replacements (one per query per file)

**How to identify the correct line:** Search for `INTERVAL 2 DAY` in the file. There are several occurrences. Only change the ones inside `MonthlyUsage`'s COALESCE/SUM/CASE block (with the `FIX ASC-157/ASC-261` comment above them). Do NOT change:
- EvaluationFilter's `INTERVAL 2 DAY`
- Grouped CTE's `INTERVAL 2 DAY` (used for max_ticket_end check)
- Any other `INTERVAL 2 DAY` reference

## Verification

1. Run the April batch against Bizmates
2. Check charge_id 3028086 (student 67915, 15-lesson plan):
   - **Before fix:** April `taken=15` (includes May 1 lesson), May `taken=1`, sum=16
   - **After fix:** April `taken=14`, May `taken=1`, sum=15 ✓
3. Confirm April shows `remaining=1` (to be carried over)
4. Confirm May shows `carried_over=1, taken=1`
5. Verify that lessons on the last day of April (e.g., `2026-04-30 23:30`) are still counted in April (they should be — `< 2026-05-01` is satisfied)
6. Run existing test suite (TC014-TC030)

## Note on Interaction with ASC-285

Charge 3028147 is affected by BOTH this bug and ASC-285 (NULL order_no). Apply ASC-285 first, then this fix. After both fixes:
- April: `taken=6, remaining=9, expired=0, paid_price=5644`
- May: `carried_over=9, taken=5, expired=4, paid_price=8464`
- Sum: 6+5=11 lessons, paid=5644+8464=14108 ≈ charge paid_price 14107 ✓

## Reference

See investigation report: `Technical_Notes/Issue_Investigation/20260608_data_adjustments/Notes_Data_Adjustment_Issue_20260608.md` — Bug C section.
