# 01 — Uniform Ticket Validity Window (The 60-Day Problem)

> **TL;DR:** All monthly plan tickets are created with a fixed 2-month (60-day) validity regardless of contract type, plan type, or service. This means the accounting CTE must *compute* when tickets actually expire based on business rules (last charge, contract end, order succession) — rather than simply reading a pre-determined expiry date off the ticket. This single upstream design decision is the root cause of most CTE boundary complexity (Topics 06, 07, and the "last charge" issues).

---

## Problem Pattern

An upstream system creates records with **generic, one-size-fits-all metadata** instead of encoding the business context known at creation time. Downstream systems must then reverse-engineer the correct business behavior through complex runtime logic — logic that could have been a simple data lookup if the upstream had stored the right value from the start.

This is the "**dumb data, smart consumer**" anti-pattern. The data is too generic to be useful directly, forcing every consumer to rebuild context that was available (and thrown away) at creation time.

---

## How We Encountered It

When a student's monthly subscription renews, the charge batch creates **lesson tickets** in `trn_ticket`. Each ticket gets an `end_datetime` calculated as:

```php
// ticketModel.php (bizmates.jp admin portal)
const MONTHLY_TICKET_EXPIRE_MONTH_DEFAULT = 2;  // 60 days for most plans

// Ticket creation: start_datetime + 2 months
$end_datetime = $start_datetime->copy()->addMonths(2);
```

This means:
- A January ticket is "valid" until March (technically end of February + carry-over)
- Every ticket — regardless of whether the student is B2C, B2B, B2E, on a 25-lesson plan or 15-lesson plan, on Bizmates or Zipan — gets the same 2-month window

The only exception is the 15-lesson/day plan (FLP), which gets 1 month:

```php
const PRODUCT_TICKET_VALIDITY_MONTHS = [
    PlanModel::MONTHLY_PLAN_PRODUCT_15LPM_1LPD => self::MONTHLY_TICKET_EXPIRE_MONTH_ONE,
];
```

### Why This Causes Problems for the Monthly CTE

The monthly rate calculation CTE needs to know: **in which month does each ticket actually expire?** The answer depends on business context that the ticket itself doesn't carry:

| Scenario | Real Expiry Rule | Ticket's `end_datetime` Says |
|---|---|---|
| B2B last charge in order | Expire at end of charge period | +2 months (wrong — too late) |
| Student cancels mid-month | Expire at cancellation | +2 months (wrong — too late) |
| Contract renewed (new charge follows) | Carry over to next charge | +2 months (might be right accidentally) |
| FLP plan | Expire at end of current month | +1 month (approximately right) |
| Refund processed | Expire immediately | +2 months (wrong — much too late) |

The CTE cannot simply check `WHERE end_datetime <= target_month_end` to determine expiry. It must instead:

1. Check if this is the last charge in the order (`LastChargeWithinOrder` CTE)
2. Check if a successor charge exists
3. Check if the charge's `end_date` has passed
4. Check if the ticket's 60-day window extends past the charge boundary
5. Apply different expulsion rules depending on combination of the above

This is the direct cause of:
- **Topic 06** (Complex CTE boundary logic) — all those `is_last_charge_month`, `is_ticket_expiry_month`, `is_last_charge_in_order` flags
- **Topic 07** (Data leaking across periods) — the 60-day window allows tickets to "exist" in months after they should be gone
- **ASC-254, ASC-258, ASC-264, ASC-266, ASC-267** — all are edge cases in "when does this ticket REALLY expire?"

---

## Root Cause

The ticket creation logic was designed for the **lesson booking system**, not for the **accounting system**. From the booking system's perspective, "this ticket is valid for 2 months" is sufficient — it controls whether a student can book a lesson.

But accounting needs a different answer: "in which reporting period should this ticket's revenue be recognized?" That answer depends on contract lifecycle, not on booking availability.

The fundamental mismatch:

| System | Question | Answer Encoded In Ticket |
|---|---|---|
| Lesson Booking | "Can the student use this ticket today?" | `end_datetime` (2 months out) ✓ works fine |
| Revenue Recognition | "In which month should this ticket's value be recognized as consumed/expired?" | Not encoded anywhere ✗ must be computed |

The accounting system (ASC) is forced to **recompute** expiry from business rules because the ticket doesn't carry the information it needs. The CTE is doing work that should have been done at ticket creation time.

---

## What The Correct Design Would Look Like

If tickets were created with business-context-aware metadata:

```sql
-- Proposed: tickets carry their actual accounting expiry
CREATE TABLE trn_ticket (
    ...
    end_datetime DATETIME,           -- booking availability (existing, keep for lesson system)
    accounting_expiry_month VARCHAR(6),  -- NEW: period in which this ticket's value expires for accounting
    contract_type ENUM('b2c','b2b','b2e'),  -- NEW: inherited from charge at creation
    is_last_in_order BOOLEAN,        -- NEW: known at creation for B2B orders
    ...
);
```

With this data available, the monthly CTE collapses from 700 lines to:

```sql
-- Dream scenario: accounting just reads pre-computed expiry
SELECT charge_id, accounting_expiry_month, COUNT(*) as tickets_expiring
FROM trn_ticket
WHERE accounting_expiry_month = :target_ym
GROUP BY charge_id, accounting_expiry_month
```

No recursion. No boundary logic. No "last charge" detection. The upstream system did the work once, at creation time, when the business context was readily available.

---

## Why We Can't Just Fix It

Changing ticket creation would require:

1. Modifying the charge batch in `bizmates.jp` (FuelPHP legacy monolith)
2. Modifying the student portal purchase flow in `MBTI_backend`
3. Backfilling `accounting_expiry_month` for millions of existing tickets
4. Coordinating a release across three systems simultaneously
5. Running the new and old accounting calculations in parallel to prove equivalence

This is a multi-quarter effort that crosses team boundaries. The ASC project couldn't change how tickets are created upstream — it had to work with what existed.

---

## How This Shaped the Entire ASC Project

The ASC project's original goal was straightforward: **add a monthly rate report** — a new calculation based on lesson consumption rather than calendar days. This required creating the monthly commands (`MonthlyRateCalculationCommand`, etc.).

But during development, the team discovered the deeply entangled reality:

### 1. The Existing Daily Commands Already Included Monthly Plans

The existing `DailyRateCalculationPreCommand` and `SendJournalsDataCommand` already processed *all* charges — including monthly-plan charges — using the daily (pro-rata by calendar days) formula. The new monthly commands needed to calculate those same charges using a *different* formula (by lesson consumption).

This meant: **monthly-plan charges had to be excluded from the daily commands** to avoid double-counting.

### 2. Exclusion Created a Summary Gap

The daily and monthly commands feed into a shared summary report (`log_sum_calculation` → CalculationSummary CSV). Once monthly plans were excluded from the daily path, the summary was missing those amounts. The workaround: **merge monthly results back into the summary** so the total still balances.

### 3. Different Formulas, Different Totals

Daily formula: `paid_price × (days_used / days_in_month)` — simple pro-rata
Monthly formula: `paid_price × (tickets_consumed / total_tickets)` — consumption-based

These produce different numbers for the same charge. The business wanted the monthly formula for monthly plans (more accurate for lesson-based services), but this means the final summary is no longer just "sum of daily rows" — it's a union of two differently-calculated datasets.

### The Cascade

```
Original scope: "Add a monthly report"
    → Discovery: daily commands already process monthly plans
        → Workaround: exclude monthly plans from daily
            → Problem: summary is now incomplete
                → Workaround: merge monthly results back into summary
                    → Problem: totals differ because formulas differ
                        → Acceptance: this is the correct business outcome
                            → But now: two code paths, two formulas, one summary
```

What started as "add a report" became "restructure how charges flow through the entire calculation pipeline." The 60-day ticket validity made this worse because the monthly CTE needed complex boundary logic just to determine *which month* each ticket's value belongs to — information that should have been simple to derive but wasn't, due to the generic ticket metadata.

This is why nearly every ASC bug (Topics 06, 07, the last-charge issues) traces back to the monthly CTE: it's doing the hardest work in the system, computing what upstream should have provided, while simultaneously being constrained by how the daily commands were restructured around it.

---

## Industry Standard / Best Practice

### How Stripe Creates Line Items with Full Context

When Stripe creates an invoice line item (their equivalent of a ticket), it carries:
- `period.start` and `period.end` — the exact billing period it covers
- `proration` — whether it's prorated and how
- `subscription_item` — which subscription it belongs to
- `amount` — the exact revenue for this period

Revenue recognition doesn't need to compute anything. It reads the line item's period and amount directly.

### How Zuora Pre-Computes Revenue Schedules

Zuora's revenue recognition module creates a `RevenueSchedule` at charge creation time. The schedule explicitly lists which months get which amounts:
- January: ¥12,980
- February: ¥12,980 (carry-over from unused)
- March: ¥0 (expired)

The monthly close just reads the schedule. It doesn't walk tickets or compute expiry.

### The "Enrich at Write Time" Principle

> Every piece of information that a downstream consumer will need should be computed and stored at the time the record is created — when the full business context is available.

Downstream systems should be **readers**, not **re-computers**. If a consumer needs to know "is this the last charge in an order?", that flag should be set when the charge is created (the charge batch knows the order state). Don't force every downstream consumer to re-derive it.

### The "Reports Should Just Read" Connection

This is the same principle as Topic 08 (reports shouldn't compute) applied one layer earlier:
- Topic 08: Reports shouldn't compute → data should be in log tables
- Topic 01: Log table computation shouldn't be heroic → source records should carry the context needed

The chain should be:
```
Ticket created (with full context) → Log table populated (simple read + store) → CSV exported (simple read)
```

Not:
```
Ticket created (minimal context) → Log table populated (700-line CTE recomputes context) → CSV exported
```

---

## Prevention Checklist

- [ ] When creating records that will be consumed by downstream systems, include all context the downstream will need — don't force them to re-derive it
- [ ] If different downstream systems need different "validity" answers from the same record, store both (e.g., `booking_end_datetime` for lesson system, `accounting_expiry_month` for accounting)
- [ ] Before building complex derivation logic in a consumer, ask: "Could the producer have given me this information directly?"
- [ ] When business rules determine a record's lifecycle (e.g., "B2B last charge → tickets expire at charge end"), encode that determination at the decision point, not at reporting time
- [ ] Accept that fixing upstream data quality is a long-term investment — but document the gap so future architects don't unknowingly build another complex consumer
