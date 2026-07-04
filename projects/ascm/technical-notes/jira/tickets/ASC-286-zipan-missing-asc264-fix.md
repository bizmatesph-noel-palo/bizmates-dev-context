# ASC-286: Zipan FilteredUsage Missing ASC-264 Start-Month Preservation (Bug A)

## Type: Bug Fix
## Priority: Medium
## Parent: ASC-283 (Investigation)
## Related: ASC-284 (symptom report for Zipan charge 12555)
## Branch from: ASC-master (with ASC-276/277 merged)
## Affected Files:
- `app/Libs/MonthlyRateCalculationLogic.php` (Zipan query)
- `app/Libs/MonthlyRateCalculationPreLogic.php` (Zipan query)

---

## Summary

Zipan monthly charges that start mid-month (e.g., April 10) with zero lessons taken in the start month are missing from `log_monthly_rate_calculation` for that month. They only appear in the following month.

This is because the Zipan `FilteredUsage` CTE is missing the ASC-264 fix that was already applied to Bizmates.

This ticket provides the fix for the symptom reported in ASC-284.

## Root Cause

The Bizmates `FilteredUsage` has this OR condition that preserves charges in their start month:

```sql
-- FIX ASC-264: Always show charges that started in the current month
OR DATE_FORMAT(mu.start_date, '%Y-%m-01') = mu.month_start
```

The Zipan `FilteredUsage` does NOT have this condition. When a charge starts mid-month with zero lessons and a different-order successor exists, FilteredUsage expels the row.

## Affected Data

Zipan charges: 11590, 11745, 12555, 12631 (and any similar pattern).

## Fix Instructions

### Step 1: Locate the Zipan FilteredUsage in `MonthlyRateCalculationLogic.php`

Find the Zipan `FilteredUsage` CTE. The current OR block looks like:

```sql
FilteredUsage AS (
    SELECT mu.*
    FROM MonthlyUsage mu
    WHERE
        (is_available_refund = 0
            OR (month_start <= DATE_FORMAT(charge_end_date, '%Y-%m-01')
                OR lessons_taken > 0))
        AND (
            NOT EXISTS (
                SELECT 1 FROM StudentProduct sp2
                WHERE sp2.student_id = mu.student_id
                    AND sp2.product_id = mu.product_id
                    AND (sp2.order_no != mu.order_no
                        OR (sp2.order_no IS NOT NULL AND mu.order_no IS NULL)
                        OR (sp2.order_no IS NULL AND mu.order_no IS NOT NULL))
                    AND sp2.start_date > mu.end_date
            )
            OR DATE_FORMAT(mu.end_date, '%Y-%m-01') = mu.month_start
            OR mu.lessons_taken > 0
        )
```

### Step 2: Add the ASC-264 condition

Add this line after `OR mu.lessons_taken > 0`:

```sql
            OR mu.lessons_taken > 0
            -- FIX ASC-264 (Zipan): Always show charges that started in the current month
            -- even if zero lessons taken and a different-order successor exists.
            OR DATE_FORMAT(mu.start_date, '%Y-%m-01') = mu.month_start
```

The closing `)` for the AND block should come after the new line.

### Step 3: Repeat for `MonthlyRateCalculationPreLogic.php`

The same Zipan `FilteredUsage` CTE exists in the Pre file. Apply the identical change.

## Verification

1. Run the April batch (`startDate = 2026-04-01`, `endDate = 2026-04-30`) against Zipan
2. Confirm that charges starting mid-April (e.g., charge_id 11590, start 2026-04-10) now appear in `target_ym = 202604`
3. Expected output for charge 11590 in April: `total=10, carried_over=0, taken=0, expired=0, remaining=10, paid_price=0`
4. Confirm existing May output is unchanged
5. Run existing test suite — no regression expected

## Reference

See investigation report: `Technical_Notes/Issue_Investigation/20260608_data_adjustments/Notes_Data_Adjustment_Issue_20260608.md` — Bug A section.
