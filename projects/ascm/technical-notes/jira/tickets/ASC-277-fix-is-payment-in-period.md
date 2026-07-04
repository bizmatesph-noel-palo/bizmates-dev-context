# ASC-XXX: is_payment_in_period flag excludes charges paid after midnight on last day of month

## Summary

The `is_payment_in_period` flag in the Monthly Rate Calculation CTE uses `DATE()` comparison against a `datetime` column, causing charges paid after 00:00:00 on the last day of the month to be incorrectly marked as `is_payment_in_period = 0`.

## Why This Is Important

`is_payment_in_period` determines the `pre_sales` value:

```sql
CASE WHEN is_payment_in_period = 1 THEN lesson_volume ELSE 0 END AS pre_sales
```

`pre_sales` represents **前受金 (deferred revenue)** — the lesson volume that was pre-paid in the current month. This feeds into the balance transition calculations which track how much revenue is recognized vs. deferred each month. If `pre_sales` is understated:

- The **CalculationSummary** sent to Freee may not correctly reflect the deferred revenue portion for the period
- The **balance transition report** (前受金・売掛金残高推移表) could show incorrect monthly balance figures
- Revenue timing between months could be misallocated in the accounting system

In short: it's a revenue recognition accuracy issue. The financial reports may not match the actual payment timing for charges processed on the last day of the month.

## Root Cause

```sql
-- Current (incorrect for last day):
WHEN t.paid_at BETWEEN DATE('2026-05-01') AND DATE('2026-05-31') THEN 1 ELSE 0

-- MySQL evaluates DATE('2026-05-31') as '2026-05-31 00:00:00'
-- So paid_at = '2026-05-31 10:00:00' → BETWEEN fails → is_payment_in_period = 0
```

## Impact (DEV04 data)

| Month | Affected Charges |
|-------|:---:|
| January 2026 | 7 |
| February 2026 | 30 |
| March 2026 | 10 |
| April 2026 | 21 |
| **Total** | **68** |

These charges have `pre_sales = 0` when they should have `pre_sales = lesson_volume` (8, 10, or 15 depending on plan).

## Proposed Fix

Replace `DATE()` comparison with an inclusive range that covers the entire last day:

```sql
-- Option A: Use < next day (recommended — avoids edge cases with 23:59:59)
WHEN t.paid_at >= DATE({$startDate}) AND t.paid_at < DATE_ADD(DATE({$endDate}), INTERVAL 1 DAY) THEN 1 ELSE 0

-- Option B: Explicit end of day
WHEN t.paid_at BETWEEN DATE({$startDate}) AND CONCAT(DATE({$endDate}), ' 23:59:59') THEN 1 ELSE 0
```

## Affected Files

- `app/Libs/MonthlyRateCalculationLogic.php` — Bizmates `ChargeData` CTE (line ~217)
- `app/Libs/MonthlyRateCalculationLogic.php` — Zipan `ChargeData` CTE (line ~785)
- `app/Libs/MonthlyRateCalculationPreLogic.php` — Same locations in the Pre version

## Acceptance Criteria

1. Charges with `paid_at` on the last day of the month (any time) get `is_payment_in_period = 1`
2. `pre_sales` correctly reflects `lesson_volume` for these charges
3. No change to `paid_price`, ticket counts, or any other column
4. Existing test cases (TC014-TC030) continue to pass

## Priority

Low — pre-existing condition since the CTE was written. No reported discrepancy from the business team. Fix is trivial (1 line in 4 places) but should be validated independently.

## Reported By

Wu-san (code review observation)
