# Monthly CTE Pipeline — Technical Reference

## Overview

The monthly rate calculation uses a **recursive Common Table Expression (CTE)** to walk lesson tickets across months, computing how many were taken, expired, carried over, and remaining — per charge, per month.

This is the most complex piece of the system (~700 lines of SQL embedded in PHP). This document explains each stage.

---

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
│  TicketMonths   │  Recursive: expands each charge across its active months
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  MonthlyUsage   │  Per-month lesson counting (how many taken this month)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  FilteredUsage  │  Expulsion rules: remove dead/ghost rows
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Grouped        │  Aggregation: compute flags (is_last_charge_month, etc.)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  FinalResult    │  Output: total, carried_over, taken, expired, remaining, paid_price
└────────┬────────┘
         │
         ▼
    INSERT into log_monthly_rate_calculation
```

After the CTE, two additional queries are merged before INSERT:
- **Refund Query** — charges with `paid_price < 0`
- **Orphaned Charge Query** — charges with all tickets deleted

---

## Stage 1: ChargeData

**Purpose:** Collect base charge information and pre-compute flags.

**Inputs:** `trn_ticket`, `trn_student_product`, `trn_charge`

**Key fields produced:**

| Field | What It Means |
|-------|--------------|
| `charge_id` | The actual charge (uses `true_charge_id` to handle NULL) |
| `student_id` | Student |
| `product_id` | Plan type |
| `start_date` / `end_date` | Charge contract period |
| `paid_price` | Amount charged |
| `lesson_volume` | Total tickets for this charge (e.g., 15 for FLP) |
| `order_no` | B2B order string (NULL for B2C) |
| `is_payment_in_period` | Was this charge paid within the target month? |
| `charge_in_past` | Has the charge's contract period ended? (`end_date <= endDate`) |
| `max_ticket_end_datetime` | Latest ticket expiry for this charge |

**Key fixes in this stage:**
- **ASC-277:** `is_payment_in_period` uses `DATE_ADD(endDate, INTERVAL 1 DAY)` as upper bound instead of direct DATE comparison, ensuring charges paid on the last day of the month are correctly identified.
- **ASC-296 (Part 1):** `charge_in_past` uses `<=` not `<`, so charges ending on the last day of the target month are correctly flagged.

---

## Stage 2: TicketMonths (Recursive)

**Purpose:** Expand each charge into one row per active month.

**How it works:**
- **Base case:** The first month the charge's tickets are active
- **Recursive step:** Add one month at a time until contract end or target month reached

**Produces:** One row per (charge × month) combination, carrying forward running totals.

**Branch A:** Tickets that started on or before `endDate` (normal path)
**Branch B:** Lookahead — charges whose `start_date` is within the batch window but tickets haven't started yet

---

## Stage 3: MonthlyUsage

**Purpose:** Count lessons actually taken in each month.

**How it works:** Joins against lesson completion data (or evaluations) to count how many tickets were used in each calendar month.

**Key fix (ASC-287):** The lesson-date upper bound uses `INTERVAL 1 DAY` past end-of-month for the target month. This prevents lessons at month boundaries from being double-counted.

**Important:** This `INTERVAL 1 DAY` is for lesson counting and is DIFFERENT from the `INTERVAL 2 DAY` in FinalResult (which is for expiry boundary). Do not confuse them.

---

## Stage 4: FilteredUsage

**Purpose:** Remove rows that shouldn't appear in the output.

**Expulsion rules (in order):**

1. **Zero-activity historical rows** — charges from past months with no lessons taken and no remaining tickets
2. **Terminal charges past lifecycle** — last charge in order, contract ended before current month, no successor
3. **Mid-order charges past expiry** — only if last charge in order (mid-order charges preserved for correct expiry timing)

**Key fixes:**
- ASC-264: Newly-started charges NOT expelled even if zero lessons taken
- ASC-266: Only fires for last charge in order (preserves mid-order charges)
- ASC-267: Terminal charges expelled after lifecycle ends (prevents ghost rows)
- ASC-286 (Zipan): Added start_date month check — port of the Bizmates ASC-264 fix. Zipan charges starting mid-month with zero lessons were being expelled when a different-order successor existed.

---

## Stage 5: Grouped

**Purpose:** Aggregate per (student × product × charge × month) and compute business flags.

**Key flags produced:**

| Flag | Meaning | How Computed |
|------|---------|-------------|
| `is_last_charge_month` | Is this the charge's final month? | `end_date` falls within or before this month |
| `is_last_charge_in_order` | Is this the terminal charge of its B2B order? | `LastChargeWithinOrder` sub-CTE (no same-order successor using NULL-safe `<=>`) |
| `is_ticket_expiry_month` | Do tickets expire within this month (by validity)? | `max_ticket_end_datetime < DATE_ADD(LAST_DAY(month_start), INTERVAL 2 DAY)` |
| `charge_in_past` | Has the contract period ended? | `end_date <= endDate` |
| `remaining_before` | Tickets available before expiry is applied | `total - cumulative_taken` |
| `has_new_contract_after_refund` | Does a successor charge exist after a refund? | Checks for same-student, same-product successor |
| `is_available_refund` | Is this a refundable charge? | Based on refund history linkage |

**Critical notes:**
- The `INTERVAL 2 DAY` in `is_ticket_expiry_month` (line ~580) existed before ASC-296. It accommodates FLP tickets whose `end_datetime` is `00:59:59` on the 1st of next month.
- **ASC-285:** Same-order successor checks use NULL-safe equality (`<=>`) instead of `=` for `order_no` comparisons. Previously, `NULL = NULL` returned false in SQL, causing B2C charges with `order_no = NULL` to be treated as terminal (no successor), which caused premature expiry.

---

## Stage 6: FinalResult

**Purpose:** Compute the final output columns — the numbers that go into the log table and CSV.

**The expiry CASE expression** — this is the core business logic:

```sql
CASE
    -- Trigger 1: B2B terminal charge → expire all remaining
    WHEN g.is_last_charge_in_order = 1
    THEN g.remaining_before

    -- Trigger 2: Contract end + ticket validity confirmed
    WHEN (g.is_last_charge_month = 1 OR g.is_ticket_expiry_month = 1
          OR g.has_new_contract_after_refund = 1)
        AND (
            (g.is_last_charge_month = 1 AND g.charge_in_past = 1
                AND g.max_ticket_end_datetime < DATE_ADD(LAST_DAY(g.month_start), INTERVAL 2 DAY))
            OR g.is_ticket_expiry_month = 1
            OR g.has_new_contract_after_refund = 1
        )
    THEN g.remaining_before

    -- Default: no expiry
    ELSE 0
END AS number_of_expired_lessons
```

**The same logic (inverted) produces `number_of_remaining_lessons`:**
- If expired → remaining = 0
- If not expired → remaining = remaining_before

**`paid_price` calculation:**
```sql
ROUND(
    (g.paid_price / NULLIF(g.lesson_volume, 0)) *
    (lessons_taken + expired_lessons),
    0
) AS paid_price
```

Revenue recognized = unit price × (taken + expired). Remaining tickets don't generate revenue yet.

**Exception:** If `is_available_refund = 1 AND has_new_contract_after_refund = 0`, only `lessons_taken` is used (no expired added). This is because the refund means unused tickets won't generate revenue.

---

## Expiry Triggers Explained

There are **4 triggers** that cause remaining tickets to expire:

| # | Trigger | When It Fires | Typical Scenario |
|---|---------|---------------|-----------------|
| 1 | `is_last_charge_in_order = 1` | Unconditionally | B2B student finishes their order. All remaining expire. |
| 2 | `is_last_charge_month + charge_in_past + max_ticket_end < boundary` | All 3 must be true | B2C/FLP charge contract ended, tickets validity confirmed expired |
| 3 | `is_ticket_expiry_month = 1` | Ticket validity ends within month | Mid-order: tickets expire by their own timeline |
| 4 | `has_new_contract_after_refund = 1` | Refund with successor | Old charge's remaining expire; new charge takes over |

**ASC-296 fixed Trigger 2:**
- Part 1: `charge_in_past` was `FALSE` when `end_date = last day of month` (strict `<` instead of `<=`)
- Part 2: `max_ticket_end < boundary` was `FALSE` because FLP tickets have `end_datetime = 00:59:59` on the 1st, and boundary was midnight on the 1st (`INTERVAL 1 DAY`). Changed to `INTERVAL 2 DAY`.

---

## Additional Queries (Post-CTE)

### Refund Query (ASC-276)

**Purpose:** Capture charges with `paid_price < 0` (refunds).

The CTE can't process refunds naturally because they don't have the same ticket lifecycle. They're fetched separately by `generateRefundQuery` and merged into the result set before DB insert. This replaces the previous approach where refunds were detected at CSV generation time — late-arriving refunds were invisible under the old method.

Output:
- `total = 0`, `taken = 0`, `expired = 0`, `remaining = 0`
- `paid_price = negative amount` (the refund value)

### Orphaned Charge Query (ASC-280 + ASC-297)

**Purpose:** Capture charges whose tickets were all deleted (consumed lessons, then tickets removed from `trn_ticket`).

The CTE uses ticket data to trace back to charges. In certain business flows (e.g., B2B→B2E transitions, FLP plan consumption), tickets are physically deleted from `trn_ticket` after they've served their purpose. Charges that once had tickets but no longer do become invisible to the main CTE. The `generateOrphanedChargeQuery` finds them separately:

- **End-month recognition (ASC-280):** Charge's `end_date` is in the target month → output with total=lesson_volume, taken=0, expired=lesson_volume, paid_price=full amount
- **Start-month recognition (ASC-297):** Charge's `start_date` is in the target month but `end_date` is in a later month → output with remaining=lesson_volume, paid_price=0 (active but invisible to CTE)

---

## Bizmates vs Zipan Differences

The CTE logic is 95% identical. Differences:

| Aspect | Bizmates | Zipan |
|--------|----------|-------|
| DB connection | `mysql` | `zipan` |
| Product IDs | 16–23, 27–29 | 16–18 |
| Additional expiry trigger | — | `is_contract_expiry_month` (Zipan contracts have explicit expiry) |
| Lesson counting source | Evaluations | Evaluations (same) |
| `paid_price` denominator | `lesson_volume` | `total` (g.total from Grouped) |

The Zipan section has one extra OR condition in the expiry CASE: `OR g.is_contract_expiry_month = 1`.

---

## File Locations

| File | Contains |
|------|----------|
| `app/Libs/MonthlyRateCalculationLogic.php` | Final CTE (Bizmates section ~lines 200–800, Zipan section ~lines 850–1400) |
| `app/Libs/MonthlyRateCalculationPreLogic.php` | Pre CTE (identical logic, different target table) |
| `app/Console/Commands/MonthlyRateCalculationCommand.php` | Final command (thin wrapper) |
| `app/Console/Commands/MonthlyRateCalculationPreCommand.php` | Pre command (thin wrapper) |

**Important:** When fixing a bug in the CTE, apply the fix to ALL 4 locations:
1. MonthlyRateCalculationLogic.php — Bizmates section
2. MonthlyRateCalculationLogic.php — Zipan section
3. MonthlyRateCalculationPreLogic.php — Bizmates section
4. MonthlyRateCalculationPreLogic.php — Zipan section

---

## Summary of Fixes by Stage

| Stage | JIRA | Fix |
|-------|------|-----|
| ChargeData | ASC-277 | `is_payment_in_period` upper bound uses `DATE_ADD(endDate, INTERVAL 1 DAY)` |
| ChargeData | ASC-296 Part 1 | `charge_in_past` changed from `<` to `<=` |
| MonthlyUsage | ASC-287 | Lesson counting upper bound tightened from `INTERVAL 2 DAY` to `INTERVAL 1 DAY` |
| FilteredUsage | ASC-286 | Zipan start-month preservation (port of Bizmates ASC-264) |
| Grouped | ASC-285 | NULL-safe `<=>` for order_no successor checks |
| Grouped | ASC-301 | Lookahead gated on `rn = total_rows` — only fires on last row for the charge |
| FinalResult | ASC-296 Part 2 | Expiry boundary changed from `INTERVAL 1 DAY` to `INTERVAL 2 DAY` |
| Post-CTE: Refund | ASC-276 | Refund query replaces CSV-time detection |
| Post-CTE: Orphaned | ASC-280 | End-month orphaned charge recognition |
| Post-CTE: Orphaned | ASC-297 | Start-month orphaned charge recognition |
