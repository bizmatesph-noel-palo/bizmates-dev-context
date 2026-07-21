# ASC-280: Monthly Rate Calculation — Orphaned Charges (Deleted Tickets) Missing

## Status: In Progress (confirmed by Kuroda-san 2026-06-08)
## Epic: ASC-237
## Branch from: ASC-master (with ASC-276/277 merged)

## Context

Charges whose tickets are all deleted (due to B2B→B2E transition or plan change) are absent from `log_monthly_rate_calculation`. Discussed with Wu-san and Kuroda-san.

## Business Rules (Confirmed 2026-06-09)

1. Tickets are deleted **at contract renewal** (= charge end_date), not at charge start
2. Tickets are only deleted when **none were ever used for a booking** (zero lessons taken)
3. If at least one ticket was used → tickets are NOT deleted → charge appears normally via CTE
4. The orphaned charge is recognized in the **month its end_date falls in** (the month when tickets get deleted at renewal)

## Testcase

See: `asc-kiro/Testcases/ASC-XXX_TestCase031.md`

## Solution (Implemented)

Add a `generateOrphanedChargeQuery` method to `MonthlyRateCalculationLogic::execute()` and `MonthlyRateCalculationPreLogic::execute()` — same merge pattern as `generateRefundQuery` (ASC-276).

### Key Design Decisions

- **Date filter:** Uses `sp.end_date BETWEEN targetStart AND targetEnd` (not `paid_at`)
  - Because tickets are deleted at renewal (= end_date), the orphaned charge belongs to the month it expires
  - `paid_at` would be incorrect for pre-paid charges (e.g., Zipan pays months in advance)
- **Values:** `total = lesson_volume`, `taken = 0`, `expired = lesson_volume`, `remaining = 0`, `paid_price = full charge amount`
  - Since tickets are only deleted when zero bookings were made, taken is always 0
- **NOT EXISTS check:** `NOT EXISTS (SELECT 1 FROM trn_ticket WHERE student_product_id = sp.id AND ticket_type = 3)`
  - Only catches charges with ALL tickets deleted (partial deletion → CTE handles normally)

### Execution Flow

```
1. CTE query runs → produces normal rows (charges with tickets)
2. Refund query runs → produces refund rows (ASC-276)
3. Orphaned charge query runs → produces orphaned rows (ASC-280)
4. All three merged → inserted into log table
```

## Affected Files

- `app/Libs/MonthlyRateCalculationLogic.php`
- `app/Libs/MonthlyRateCalculationPreLogic.php`

## Changes Made

1. Added `generateOrphanedChargeQuery(string $targetYm, array $monthlyPlanIds): string` method to both files
2. Added call + merge in both `execute()` methods (after refund rows, before empty-result check)
3. Added logging: `Log::info("Orphaned charge rows: Bizmates=" . count(...) . ", Zipan=" . count(...))`

## Verification

1. Run April batch → orphaned charges with end_date in April should appear
2. Run May batch → orphaned charges with end_date in May should appear
3. Validate against TC031 Cases 1-5
4. Confirm no regression on TC014-TC030
5. Confirm daily pipeline unaffected
