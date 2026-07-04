# 06 — Complex Boundary Logic in Recursive CTEs

> **TL;DR:** The recursive CTE that walks tickets across months had bugs at every boundary: first charge, last charge, period transitions. Errors compound because each row depends on the previous. Fix: pre-compute boundary flags in a non-recursive CTE, then reference them in the recursion.

---

## Problem Pattern

A recursive CTE walks records across time periods computing running totals. It works in the "middle" but fails at boundaries. Each row depends on all prior rows, so errors compound.

---

## How We Encountered It

The monthly CTE pipeline — created by the ASC project — recursively walks tickets month-by-month. Since tickets carry a generic 60-day validity (Topic 01) rather than a business-rule-aware expiry, the CTE must compute the actual expiry at runtime.

Boundary bugs discovered:

1. **Last charge in order** (ASC-254): Remaining tickets should become zero but continued carrying forward — the CTE didn't know this was the "last" charge.
2. **Carry-over at charge boundaries** (ASC-258): Tickets double-counted at charge transitions.
3. **Timing guards** (ASC-211): `<=` vs `<` caused tickets counted in both expiring and following month.
4. **Future charges appearing prematurely** (ASC-260): Charges with `start_date` in May appeared in April's CSV. The CTE's recursive expansion didn't filter out charges that hadn't started yet — a lookahead boundary failure.
5. **Regression from fix** (ASC-261): After fixing ASC-260's premature inclusion, the carried-over counter dropped to zero in subsequent months. Fixing one boundary condition broke another because the same CTE flag controlled both behaviors.
6. **Missing carried-over charges** (ASC-205): When a charge carries over (e.g., Jan charge valid into Feb), the older charge disappeared from the report because the CTE only emitted the "current" charge row.
7. **Last charge double-counted** (ASC-234): B2B final charge appeared in three consecutive months instead of two — the 60-day window (Topic 01) prevented the CTE from detecting that the order had ended.
8. **Zipan expired data leak** (ASC-232): Zipan's 1-month ticket validity should never produce more than 2 charge rows per period, but an old expired charge appeared with zero values.

---

## Root Cause

1. **Generic ticket data forced runtime computation** — the CTE had to compute "is this the last charge?", "does a successor exist?" at query time (Topic 01)
2. **Implicit boundaries** — "last charge" and "charge transition" were emergent, not pre-computed
3. **Compound recursion** — off-by-one in month 1 propagates through all subsequent months
4. **Business rules as arithmetic** — expiry rules encoded as conditional math, impossible to read

---

## What We Did

1. **`LastChargeWithinOrder` sub-CTE** — pre-computes `is_last` before recursion
2. **Explicit expiry guards** — `CASE WHEN is_last_charge AND current_month > end_month THEN 0`
3. **Timing boundary standardization** — `>=` start, `<` next period everywhere

---

## Industry Standard / Best Practice

### How BigQuery's Subscription Templates Work

Pre-compute flags: `is_first_period`, `is_last_period`, `is_churn_period`. The recursive walk only handles arithmetic.

### How Recurly/Chargebee Do It

They **pre-generate period records** at subscription creation. No recursion because all periods are materialized upfront.

### Decompose CTEs into Named Segments

```sql
WITH
    TicketBase AS (...),
    BoundaryFlags AS (...),           -- is_first, is_last, is_transition
    MonthlyAccumulation AS (...),     -- simple recursion referencing flags
    FinalResult AS (...)
```

---

## Prevention Checklist

- [ ] Pre-compute boundary flags (is_first, is_last, is_transition) in a non-recursive CTE
- [ ] Every date comparison uses explicit inclusive/exclusive notation
- [ ] Test cases for EVERY boundary: first, last, transition, single-record series
- [ ] If a recursive CTE exceeds ~30 lines, consider moving logic to application code
- [ ] Each CTE segment has one responsibility — name reveals intent