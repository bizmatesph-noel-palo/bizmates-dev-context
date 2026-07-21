---
inclusion: fileMatch
fileMatchPattern: "**/MonthlyRateCalculation*.php"
---

# CTE Pipeline Reference

## Pipeline Stages

```
trn_ticket + trn_student_product + trn_charge
         │
         ▼
┌─────────────────┐
│  ChargeData     │  Base data: charge info, flags, ticket aggregates
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  EvaluationFilter │  Pre-filters evaluations by date range
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  TicketMonths   │  Recursive: expands each charge across its active months
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  MonthlyUsage   │  Per-month lesson counting (lessons_taken)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  FilteredUsage  │  Expels invalid rows (ghost rows, future charges)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Grouped        │  Calculates: carried_over, total, expiry flags
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  FinalResult    │  Determines: expired, remaining, paid_price
└────────┬────────┘
         │
         ▼
  INSERT into log_monthly_rate_calculation
```

After the CTE, additional queries are merged before INSERT:
- **Refund query** (ASC-276): monthly-plan charges with paid_price < 0
- **Orphaned charge query** (ASC-280 + ASC-297): charges with deleted tickets

## FinalResult Expiry Conditions

The FinalResult determines expired/remaining via CASE:
1. `is_last_charge_in_order = 1` — B2B terminal (fires unconditionally)
2. `is_last_charge_month = 1 AND charge_in_past = 1 AND max_ticket_end_datetime < LAST_DAY + INTERVAL 2 DAY` — B2C/FLP contract end
3. `is_ticket_expiry_month = 1` — ticket validity ends mid-order
4. `has_new_contract_after_refund = 1` — refund with successor

**Do NOT confuse:** FinalResult `INTERVAL 2 DAY` (expiry boundary) vs MonthlyUsage `INTERVAL 1 DAY` (lesson counting). Different CTEs, different purposes.

## Key Boundaries

- **EvaluationFilter:** `lesson_date BETWEEN startDate-3months AND LAST_DAY(startDate)`
- **lessons_taken upper bound:** `lesson_datetime < DATE_ADD(month_start, INTERVAL 1 MONTH)`
- **TicketMonths expansion:** generates next-month row when `month_start + 1 MONTH < DATE(end_datetime)`
- **Grouped lookahead:** Currently gated on `rn = total_rows` (ASC-301). Pending removal decision.
