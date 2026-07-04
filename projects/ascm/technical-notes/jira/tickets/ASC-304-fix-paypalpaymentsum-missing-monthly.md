# ASC-304: PaypalPaymentSum/PaypalPayment CSV — Missing Monthly Rate Calculation Data

## Status: In Progress
## Epic: TBA
## Branch from: ASC-master

## Context

Reported by Wu-san (2026-06-25). The accounting team escalated a discrepancy between `PaypalPaymentSum_202605(20260618).csv` and the combined `MonthlyRateCalculation` + `DailyRateCalculation` CSVs. The total PayPal `paid_price` (J7+J8 cells) does not match the sum of revenue from both calculation reports.

**Root cause:** The PaypalPaymentSum and PaypalPayment CSV generation functions only query `log_daily_rate_calculation` for the revenue ("uriage") breakdown. Since the ASC project separated monthly-plan charges into `log_monthly_rate_calculation`, those charges return `uriage = 0` in the PayPal CSVs — creating a mismatch against `trn_charge.paid_price` which correctly includes them.

**Investigation:** `[asc-kiro] Technical_Notes/Issue_Investigation/20260625_paypal_payment_sum_discrepancy/REPORT_00_PaypalPaymentSum_Investigation.md`

## Business Rule

The PayPal CSV files compare:
- **Column A:** `trn_charge.paid_price` — what was actually charged (from `trn_charge`)
- **Column B:** Sum of revenue breakdown over 6 months — what was recognized (from log tables)

Column B must equal Column A when all months are processed. Currently Column B is incomplete because it only reads the daily log.

**Expected:** Column B = sum from `log_daily_rate_calculation` + `log_monthly_rate_calculation` for the same charge.

## Solution

### What to change

Modify the uriage subquery in both functions to read from BOTH log tables using UNION ALL:

**File:** `app/Libs/CommonUtil.php`

#### 1. `createPaypalPaymentFile` (~L2204)

**Before:**
```php
$selectItem[] = '(select case when 1='. $isFuture .' then 0 else sum(paid_price) end as paid_price from log_daily_rate_calculation where target_ym = '. $startDate->format('Ym') .' and charge_id = trn_charge.id group by charge_id) AS uriage'.$i;
```

**After:**
```php
$selectItem[] = '(select case when 1='. $isFuture .' then 0 else sum(paid_price) end as paid_price from (select paid_price from log_daily_rate_calculation where target_ym = '. $startDate->format('Ym') .' and charge_id = trn_charge.id union all select paid_price from log_monthly_rate_calculation where target_ym = '. $startDate->format('Ym') .' and charge_id = trn_charge.id) combined group by 1 having 1=1) AS uriage'.$i;
```

#### 2. `createPaypalPaymentSumFile` (~L2271)

**Before:**
```php
$selectItem[] = '(select case when sum(paid_price) is null then 0 else sum(paid_price) end as paid_price from log_daily_rate_calculation where target_ym = '. $uriageStartDate->format('Ym') .' and charge_id = trn_charge.id group by charge_id) AS uriage'.$j;
```

**After:**
```php
$selectItem[] = '(select case when sum(paid_price) is null then 0 else sum(paid_price) end as paid_price from (select paid_price from log_daily_rate_calculation where target_ym = '. $uriageStartDate->format('Ym') .' and charge_id = trn_charge.id union all select paid_price from log_monthly_rate_calculation where target_ym = '. $uriageStartDate->format('Ym') .' and charge_id = trn_charge.id) combined group by 1 having 1=1) AS uriage'.$j;
```

### Why UNION ALL is safe

A charge exists in **one OR the other** log table, never both:
- Monthly-plan charges (product_id IN BizmatesMonthlyPlanEnum / ZipanMonthlyPlanEnum) → `log_monthly_rate_calculation` / `log_monthly_rate_calculation_zipan`
- All other charges → `log_daily_rate_calculation` / `log_daily_rate_calculation_zipan`

The daily calculation explicitly excludes monthly plans. The monthly calculation only processes monthly plans. No double-count risk.

### Zipan table names

Zipan uses `_zipan` suffixed tables on the `zipan` DB connection:
- `log_daily_rate_calculation_zipan` (existing in code)
- `log_monthly_rate_calculation_zipan` (to be added by this fix)

The fix pattern is identical to Bizmates — just with the `_zipan` suffix.

### Pre vs Final consideration

Confirmed: PayPal CSV generation runs ONLY during `SendJournalsDataCommand` (Final) and `DataCorrectionCommand`. It does NOT run during Pre commands. Therefore:
- Bizmates: uses `log_monthly_rate_calculation` (Final table) ✅
- Zipan: uses `log_monthly_rate_calculation_zipan` (Final table on zipan connection) ✅

No `_pre` table references needed.

## Affected Files

- `app/Libs/CommonUtil.php` — `createPaypalPaymentFile()` and `createPaypalPaymentSumFile()` (Bizmates)
- `app/Libs/ZipanUtil.php` — `createPaypalPaymentFile()` and `createPaypalPaymentSumFile()` (Zipan)

**Total: 4 locations** (same pattern as other CTE fixes: Bizmates + Zipan)

## Acceptance Criteria

1. For any B2C/B2B2C PayPal charge (`contract_type IN (0,2)`, `charge_type <> 1`):
   - If the charge is a monthly plan → its `paid_price` from `log_monthly_rate_calculation` appears in the uriage columns
   - If the charge is a daily-rate plan → its `paid_price` from `log_daily_rate_calculation` appears in the uriage columns (unchanged behavior)
2. The sum of all uriage columns for a fully-processed charge equals `trn_charge.paid_price`
3. The J7+J8 total in `PaypalPaymentSum` matches the sum of `paid_price` from `MonthlyRateCalculation` + `DailyRateCalculation` for the same filter conditions
4. No regression on existing PayPal CSV output for daily-rate charges

## Verification

1. Re-run `SendJournalsDataCommand` for May 2026 on DEV04
2. Compare new `PaypalPaymentSum_202605` CSV totals against `MonthlyRateCalculation_202605` + `DailyRateCalculation_202605`
3. Spot-check individual monthly-plan charges (e.g., FLP product_id 29) in `PaypalPayment_202605` — uriage columns should now show non-zero values
4. Confirm daily-rate charges are unchanged (compare specific charge_ids before/after)

## Risk Assessment

| Risk | Mitigation |
|---|---|
| UNION ALL adds query complexity to a correlated subquery | Each subquery is indexed by `charge_id + target_ym` — should be fast |
| Wrong table referenced (Pre vs Final) | Verify which command generates PayPal CSVs before implementing |
| Existing charges have both daily AND monthly log rows | Verified: not possible. Daily explicitly excludes monthly plans. |

## Notes

- This is the same class of issue that affected CalculationSummary (already fixed — both sources merged)
- The PayPal CSVs were designed before the ASC monthly commands existed and were never updated
- Severity is medium: affects accounting reconciliation, not revenue recognition itself
- KB: `Documentation/05_Engineering_Knowledge_Base.md` — Topic 21
