---
inclusion: fileMatch
fileMatchPattern: "**/CommonUtil.php,**/ZipanUtil.php"
---

# CSV Generation Reference

## Which Functions Generate Which Files

### CommonUtil.php (Bizmates)

| Function | CSV File | Data Source |
|---|---|---|
| `createPaypalPaymentFile()` | `Bizmates_PaypalPayment_YYYYMM` | `trn_charge` + `log_daily` + `log_monthly` (COALESCE) |
| `createPaypalPaymentSumFile()` | `PaypalPaymentSum_YYYYMM` (Bizmates section) | Same as above, aggregated by month |
| `createDailyRateCalculationFile()` | `DailyRateCalculation_YYYYMM` | `log_daily_rate_calculation` |
| `createMonthlyRateCalculationFile()` | `MonthlyRateCalculation_YYYYMM` | `log_monthly_rate_calculation` |
| `createCalculationSummaryFile()` | `CalculationSummary_YYYYMM` | Both daily + monthly (merged) |

### ZipanUtil.php (Zipan)

| Function | CSV File | Data Source |
|---|---|---|
| `createPaypalPaymentFile()` | `Zipan_PaypalPayment_YYYYMM` | `trn_charge` + `log_daily_zipan` + `log_monthly` (COALESCE) |
| `createPaypalPaymentSumFile()` | `PaypalPaymentSum_YYYYMM` (Zipan section — APPENDS) | Same, aggregated |
| `createDailyRateCalculationFile()` | Zipan daily CSV | `log_daily_rate_calculation_zipan` |
| `createMonthlyRateCalculationFile()` | Zipan monthly CSV | `log_monthly_rate_calculation` |

## PayPal CSV Uriage Pattern (ASC-304)

The PayPal files compare `trn_charge.paid_price` against revenue recognized across 6 months.

Revenue is fetched via:
```sql
COALESCE((SELECT SUM(paid_price) FROM log_daily_rate_calculation WHERE ...), 0)
+ COALESCE((SELECT SUM(paid_price) FROM log_monthly_rate_calculation WHERE ...), 0)
```

A charge exists in one OR the other log table, never both. COALESCE handles NULL → 0.

## PayPal CSV Filter Conditions

All PayPal files use the same base filter:
- `paid = 1` (payment completed)
- `status = 1` (active)
- `charge_type <> 1` (excludes ticket purchases)
- `contract_type IN (0, 2)` (B2C + B2B2C — B2B excluded)

## Important: PaypalPaymentSum Is One File

`CommonUtil::createPaypalPaymentSumFile()` CREATES the file (Bizmates section).
`ZipanUtil::createPaypalPaymentSumFile()` APPENDS to the same file (Zipan section via `appendCsv()`).

## Called By

| Command | Calls |
|---|---|
| `SendJournalsDataCommand` | All CSV generation functions (Final) |
| `DataCorrectionCommand` | All CSV generation functions (manual correction) |
| `DailyRateCalculationPreCommand` | Pre CSV generation only |
