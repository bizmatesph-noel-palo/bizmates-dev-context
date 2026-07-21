# Epic: Move Refund Logic Into Monthly Rate Calculation Commands

## Current Situation

Refund records for monthly plans are currently handled **only at CSV generation time** — they are never stored in the `log_monthly_rate_calculation` or `log_monthly_rate_calculation_pre` tables. Instead, when generating the MonthlyRateCalculation CSV file, the system runs additional queries against `trn_charge`, `trn_prorated_refund_charge`, and `log_refund_history` to detect and emit refund rows on-the-fly.

This means:
- Refund data is NOT in the monthly log tables
- The CalculationSummary (which aggregates from the log tables) does not include monthly refund amounts
- Refund data is not available for Freee journal processing from the monthly pipeline
- The refund detection logic is duplicated across 4 model files and 2 utility files (CommonUtil + ZipanUtil)

## Business Driver

Business team confirmed that monthly rate calculation should include the same kinds of records as daily rate calculation. Specifically, refund records need to be inserted into `log_monthly_rate_calculation` and `log_monthly_rate_calculation_pre` so that they are:
1. Included in the CalculationSummary tables
2. Eventually sent to Freee as part of the standard journal flow

## Proposed Solution

Move the refund detection logic from CSV generation time into the Monthly Rate Calculation commands (`MonthlyRateCalculationCommand` and `MonthlyRateCalculationPreCommand`). After the main CTE query produces normal charge rows, a separate refund query runs against `trn_charge` for monthly-plan charges with negative `paid_price` in the target month. Both result sets are merged and saved to the log table together.

This makes the CSV generation a simple read from the log table — no additional refund queries needed at report time.

## Changes / Affected Files

**Add refund query + merge logic:**
- `app/Libs/MonthlyRateCalculationLogic.php`
- `app/Libs/MonthlyRateCalculationPreLogic.php`

**Remove refund logic from CSV generation:**
- `app/Libs/CommonUtil.php` (remove refund section from `createMonthlyRateCalculationFile`)
- `app/Libs/ZipanUtil.php` (remove refund section from `createMonthlyRateCalculationFile`)

**Simplify model queries (remove complex refund joins):**
- `app/Models/LogMonthlyRateCalculation.php`
- `app/Models/LogMonthlyRateCalculationPre.php`
- `app/Models/Zipan/LogMonthlyRateCalculationZipan.php`
- `app/Models/Zipan/LogMonthlyRateCalculationPreZipan.php`

## Scope Exclusions

- No BatchContext or TenantConfig introduction in this phase
- No merging of Pre/Final logic classes
- No DTO/Resource changes (refund rows inserted as arrays directly)

## Validation

- All existing test cases (TC014-TC030) must continue to pass
- Refund rows must appear in the MonthlyRateCalculation CSV with correct charge_id and negative paid_price
- CalculationSummary must now include monthly refund amounts
- No duplicate refund rows

---

# Ticket: ASC-XXX — Move refund logic from CSV generation into Monthly Rate Calculation commands

## Summary

Move the refund query and emission logic from `createMonthlyRateCalculationFile` (CSV generation) into `MonthlyRateCalculationLogic::execute()` and `MonthlyRateCalculationPreLogic::execute()`, so refund rows are stored in the log tables alongside normal charge rows.

## Acceptance Criteria

1. After running the Monthly Rate Calculation command, `log_monthly_rate_calculation` contains both normal charge rows AND refund rows for the target month
2. Refund rows have: `paid_price` = negative amount, `charge_id` = refund's own ID, ticket columns = 0, `target_ym` = month the refund was executed
3. After running the Monthly Rate Calculation Pre command, `log_monthly_rate_calculation_pre` contains the same (refund rows stored alongside normal rows)
4. `createMonthlyRateCalculationFile` in CommonUtil and ZipanUtil becomes a simple SELECT from the log table — no refund joins, no standalone refund query, no dedup logic
5. The 4 model `getLogMonthlyRateCalculation` methods become simple SELECT queries without the leftJoinSub/groupBy refund detection
6. CalculationSummary correctly includes the negative refund amounts (verified by checking the `getPaidPriceSumList` union query picks them up)
7. All existing test cases (TC014-TC030) continue to pass with identical CSV output
8. Both Bizmates and Zipan tenants are handled

## Implementation Steps

1. In `MonthlyRateCalculationLogic::execute()`, after the CTE query returns normal rows, add a refund query:
   - Query `trn_charge` for records where `paid_price < 0`, `product_id` in monthly plan IDs, `paid_at` in target month, `status = 1`, `paid = 1`
   - Format results to match the log table schema (ticket columns = 0)
   - Merge with normal rows before the INSERT

2. Apply the same change to `MonthlyRateCalculationPreLogic::execute()`

3. Remove from `CommonUtil::createMonthlyRateCalculationFile`:
   - The log-based refund detection section (ASC-244/ASC-236 path)
   - The ASC-269 late refund standalone query
   - The `$processedRefunds` dedup logic
   - Method now just: fetch from log table → format rows → write CSV

4. Remove from `ZipanUtil::createMonthlyRateCalculationFile`:
   - Same removals as CommonUtil

5. Simplify the 4 model `getLogMonthlyRateCalculation` methods:
   - Remove leftJoinSub to `trn_prorated_refund_charge`
   - Remove leftJoin to `log_refund_history` and `refund_t`
   - Remove groupBy
   - Result: simple SELECT with JOIN to `trn_charge` for `paid_at` and `charge_type` only

6. Run full regression (TC014-TC030) against DEV04 to confirm identical output

## Notes

- The `is_available_refund` flag in the CTE query REMAINS unchanged — it modifies the normal charge's paid_price formula for FLP/cooling-off scenarios. This is a different concern from the refund row emission.
- Refund rows bypass the `MonthlyRateCalculationResource` DTO — they are inserted as plain arrays since their shape is fixed and simple.
- The CalculationSummary aggregation (`getPaidPriceSumList`) already unions the monthly log table, so refund rows will automatically flow into the summary without additional changes.
