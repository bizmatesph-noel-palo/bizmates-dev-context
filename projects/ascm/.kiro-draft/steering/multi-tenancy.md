---
inclusion: auto
---

# Multi-Tenancy

## Tenants

| Tenant | DB Connection | Monthly Plan Product IDs |
|---|---|---|
| Bizmates | `mysql` | 16, 17, 18, 19, 20, 21, 22, 23, 27, 28, 29 (BizmatesMonthlyPlanEnum) |
| Zipan | `zipan` | 16, 17, 18 (ZipanMonthlyPlanEnum) |

Both tenants run through the same code path with different DB connections. Every fix must be applied to BOTH tenants.

## Table-to-Connection Mapping (⚠️ CRITICAL)

The Zipan daily tables use a `_zipan` suffix. The Zipan monthly tables do **NOT**. This is a known inconsistency.

**RULE:** Always verify table names from the model's `protected $table` property. NEVER pattern-match from daily table naming.

| Table | Bizmates (`mysql`) | Zipan (`zipan`) | Notes |
|---|---|---|---|
| Daily rate (Final) | `log_daily_rate_calculation` | `log_daily_rate_calculation_zipan` | ⚠️ Has `_zipan` suffix |
| Daily rate (Pre) | `log_daily_rate_calculation_pre` | `log_daily_rate_calculation_pre_zipan` | ⚠️ Has `_zipan` suffix |
| Monthly rate (Final) | `log_monthly_rate_calculation` | `log_monthly_rate_calculation` | ⚠️ NO suffix — same name, different DB |
| Monthly rate (Pre) | `log_monthly_rate_calculation_pre` | `log_monthly_rate_calculation_pre` | ⚠️ NO suffix — same name, different DB |
| Summary (Final) | `log_sum_calculation` | `log_sum_calculation_zipan` | Has `_zipan` suffix |
| Summary (Pre) | `log_sum_calculation_pre` | `log_sum_calculation_pre_zipan` | Has `_zipan` suffix |
| Summary history | `log_sum_calculation_history` | `log_sum_calculation_history_zipan` | Has `_zipan` suffix |
| Charges | `trn_charge` | `trn_charge` | Same name, different DB |
| Student product | `trn_student_product` | `trn_student_product` | Same name, different DB |
| Tickets | `trn_ticket` | `trn_ticket` | Same name, different DB |

## Models to Verify

- `app/Models/Zipan/LogMonthlyRateCalculationZipan.php` → `$table = 'log_monthly_rate_calculation'`
- `app/Models/Zipan/LogDailyRateCalculationZipan.php` → `$table = 'log_daily_rate_calculation_zipan'`

## 4-Location Rule

Any fix that touches the monthly CTE must be applied in **4 locations**:
1. `MonthlyRateCalculationLogic.php` — Bizmates section
2. `MonthlyRateCalculationLogic.php` — Zipan section
3. `MonthlyRateCalculationPreLogic.php` — Bizmates section
4. `MonthlyRateCalculationPreLogic.php` — Zipan section
