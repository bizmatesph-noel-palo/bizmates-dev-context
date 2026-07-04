# 07 — Data Leaking Across Periods

> **TL;DR:** Expired charges produced "ghost rows" (all zeros) in the next month's output because the CTE lacked explicit expulsion rules. The recursion kept generating rows until the target date, not until the business lifecycle ended. Fix: expel by business state, not by absence of data.

---

## Problem Pattern

Records that belong to Period N unexpectedly appear in Period N+1. They're not duplicates — they were processed in N but the system fails to *expel* them when generating N+1.

---

## How We Encountered It

The monthly CTE pipeline — created by the ASC project — recursively walks tickets month-by-month. This was especially problematic because tickets carry a generic 60-day validity window (Topic 01). The CTE couldn't simply check `ticket.end_datetime` — it had to compute the real business expiry. Without explicit expulsion rules tied to that computed expiry, dead records leaked forward.

Result: a charge that expired in March produced a row in April's output with all values zero.

**JIRA:** ASC-267

---

## Root Cause

The CTE had inclusion logic ("generate a row if tickets exist") but lacked **expulsion logic** ("stop generating rows once the charge lifecycle is complete"). Without explicit expulsion, the recursion produced empty rows for every month between "charge expired" and "target month reached."

---

## What We Did

Added explicit expulsion rules in `FilteredUsage`:

```sql
FilteredUsage AS (
    SELECT * FROM MonthlyAccumulation
    WHERE NOT (
        (is_expired = 1 AND remaining = 0)
        OR (total_tickets = taken_cumulative AND remaining = 0)
        OR (current_month > charge_end_month AND is_last_charge = 1)
    )
)
```

Expulsion is based on **positive business conditions** ("this charge is done"), not absence of data.

---

## Industry Standard / Best Practice

### How Snowflake Partitions Guarantee Isolation

Queries for March literally cannot see April's partition. Physical separation = correctness guarantee.

### How Zuora Models Subscription Lifecycle

Each charge has explicit `startDate` and `endDate`. Once past, no more recognition entries — period.

### The Expulsion Principle

> A record fully processed in Period N must be **actively excluded** from Period N+1. Don't rely on passive disappearance.

---

## Prevention Checklist

- [ ] Every time-partitioned pipeline has explicit **expulsion rules** — not just inclusion rules
- [ ] Expulsion based on business state (charge expired, lifecycle complete), not on derived values being zero
- [ ] Records carry their effective period as a first-class attribute
- [ ] Recursive CTEs terminate on business lifecycle, not just on reaching target date
- [ ] Add reconciliation query detecting records in periods after their lifecycle ended
