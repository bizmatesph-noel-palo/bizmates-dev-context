# 04 — DateTime Range Boundary (BETWEEN with DATE)

> **TL;DR:** Using `BETWEEN` on a DATETIME column with DATE boundaries excludes records after midnight on the last day. Charges on March 31 afternoon vanished from both March and April. Fix: always use `>= start AND < next_period_start` (half-open interval).

---

## Problem Pattern

`BETWEEN '2024-03-01' AND '2024-03-31'` is interpreted as `BETWEEN '2024-03-01 00:00:00' AND '2024-03-31 00:00:00'`. Records timestamped after midnight on the last day are excluded.

---

## How We Encountered It

The `is_payment_in_period` logic used:

```sql
WHERE payment_date BETWEEN :start_date AND :end_date
```

Charges on March 31 at 14:30:00 were excluded from March AND April — they fell into a crack.

**JIRA:** ASC-277

---

## What We Did

```sql
-- Before (buggy):
WHERE payment_date BETWEEN :start_date AND :end_date

-- After (correct):
WHERE payment_date >= :start_of_month
  AND payment_date < :start_of_next_month
```

---

## Industry Standard / Best Practice

### How PostgreSQL Docs Address This

PostgreSQL explicitly recommends against BETWEEN for timestamp ranges.

### How Stripe's API Works

Stripe uses `created[gte]` and `created[lt]` — explicit inclusive/exclusive with no ambiguity.

### The Half-Open Interval

```sql
WHERE column >= :period_start AND column < :next_period_start
```

Works regardless of DATE, DATETIME, TIMESTAMP, or sub-second precision.

### The "23:59:59" Anti-Pattern

`<= '2024-03-31 23:59:59'` still misses microseconds. Always use `< next_day`.

---

## Prevention Checklist

- [ ] Never use BETWEEN for DATETIME columns — use `>= start AND < next_period_start`
- [ ] Period end = "start of next period" (exclusive), not "end of current period" (inclusive)
- [ ] Code review flag: any BETWEEN on a datetime column is suspect
- [ ] Test with records at 23:59:59 on the last day — they must be included
- [ ] Standardize a date range utility that enforces half-open intervals project-wide

---

## See Also

- **Topic 19** (INTERVAL Offset vs DATETIME) — a related trap where the half-open interval is correct but the INTERVAL offset used to compute the boundary is too small, excluding records with time-of-day past midnight.