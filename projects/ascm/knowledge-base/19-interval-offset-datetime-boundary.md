# 19 — INTERVAL Offset vs DATETIME Column (Off-by-Hours)

> **TL;DR:** When a DATETIME column stores values past midnight (e.g. `2026-05-01 00:59:59` for an April charge), a boundary computed via `DATE_ADD(LAST_DAY(...), INTERVAL 1 DAY)` resolves to midnight (`2026-05-01 00:00:00`) and excludes the record. The INTERVAL must be large enough to cover the maximum time-of-day offset in the data.

---

## Problem Pattern

A SQL condition compares a DATETIME column against a DATE boundary:

```sql
WHERE datetime_column < DATE_ADD(LAST_DAY(some_date), INTERVAL N DAY)
```

If `N` is too small, records with a time component past midnight on the boundary day are excluded — even though they logically belong to the current period.

This is a cousin of Topic 04 (BETWEEN with DATE) but more insidious because:
- The comparison looks correct at the DATE level
- It only fails for records with a non-zero time-of-day component
- It passes all test cases where time = `00:00:00`

---

## How We Encountered It

The FinalResult CTE determines whether remaining tickets should expire at contract end:

```sql
-- Expiry gate (simplified):
CASE
    WHEN g.is_last_charge_month = 1
         AND g.charge_in_past = 1
         AND g.max_ticket_end_datetime < DATE_ADD(LAST_DAY(g.month_start), INTERVAL 1 DAY)
    THEN g.remaining_before  -- expire them
    ELSE 0                   -- keep as remaining
END
```

For FLP (15-lesson plan) charges, ticket `end_datetime` values are:

| charge end_date | max_ticket_end_datetime | Boundary (INTERVAL 1 DAY) | Result |
|----------------|------------------------|---------------------------|--------|
| 2026-04-30 | 2026-05-01 **00:59:59** | 2026-05-01 00:00:00 | `00:59:59 < 00:00:00` = **FALSE** ❌ |
| 2026-05-31 | 2026-06-01 **00:59:59** | 2026-06-01 00:00:00 | `00:59:59 < 00:00:00` = **FALSE** ❌ |

The tickets are logically "within the month" but the time component pushes them past the midnight boundary.

**JIRA:** ASC-296 (Part 2)

---

## What We Did

Changed `INTERVAL 1 DAY` to `INTERVAL 2 DAY` in the FinalResult expiry condition:

```sql
-- Before:
AND g.max_ticket_end_datetime < DATE_ADD(LAST_DAY(g.month_start), INTERVAL 1 DAY)

-- After:
AND g.max_ticket_end_datetime < DATE_ADD(LAST_DAY(g.month_start), INTERVAL 2 DAY)
```

New boundary: `2026-05-02 00:00:00`. Since `2026-05-01 00:59:59 < 2026-05-02 00:00:00` = TRUE, expiry now fires correctly.

This same boundary was already in use in the Grouped CTE's `is_ticket_expiry_month` (line ~580) without issues — the FinalResult section was the only place still using `INTERVAL 1 DAY`.

---

## Why Not Just Use `INTERVAL 1 DAY` + Time Padding?

An alternative like `< DATE_ADD(LAST_DAY(...), INTERVAL 1 DAY) + INTERVAL 1 HOUR` is fragile — it assumes the maximum offset is always under 1 hour. Using `INTERVAL 2 DAY` provides a full 24-hour buffer and matches the pattern established elsewhere in the codebase.

---

## Relationship to Topic 04

| | Topic 04 | Topic 19 |
|---|----------|----------|
| **Pattern** | `BETWEEN date1 AND date2` excludes times after midnight | `< DATE_ADD(..., INTERVAL N)` excludes times past the computed boundary |
| **Root cause** | Implicit midnight truncation | INTERVAL too small for the time-of-day range |
| **Fix** | Half-open interval (`>= start AND < next`) | Increase INTERVAL to cover max time offset |
| **Detection** | Fails for ANY record with time > 00:00:00 on last day | Only fails when time-of-day exceeds (N-1) days past midnight |

Topic 04 is about the general DATE vs DATETIME trap. Topic 19 is specifically about **choosing the right INTERVAL offset** when you already know to use `<` (exclusive) but the offset itself is wrong.

---

## Industry Standard / Best Practice

### How MySQL Documentation Warns About DATE vs DATETIME

The MySQL docs explicitly state that comparing a DATETIME column to a DATE value implicitly casts the DATE to `YYYY-MM-DD 00:00:00`. Any DATETIME value on the same calendar day but after midnight will NOT match `< DATE`. This is why boundary computation must account for time-of-day.

### How Temporal Databases Handle Period Boundaries

Temporal DB systems (SQL:2011 period predicates) use `CONTAINS`, `OVERLAPS`, `PRECEDES` operators that handle both DATE and DATETIME transparently. They never rely on manual INTERVAL arithmetic — the semantic operators encapsulate boundary logic.

### How ClickHouse Recommends Partition Boundaries

ClickHouse documentation recommends partition keys at the DATE level but filter predicates at the DATETIME level. Their pattern: `WHERE event_time < toStartOfDay(toDate('2026-05-01') + 1)` — which explicitly computes "start of the next day" rather than relying on INTERVAL arithmetic that might be wrong.

### How Stripe Stores Period Boundaries

Stripe stores `period_start` and `period_end` as Unix timestamps (seconds). Comparisons are always numeric — no DATE/DATETIME mismatch possible. When they do use human-readable dates, boundaries are stored as explicit timestamps (`1714521600` = `2026-05-01 00:00:00 UTC`), never computed from INTERVAL.

### Know Your Data's Time Range

Before writing `INTERVAL N DAY`, query the actual max time-of-day in the column:

```sql
SELECT MAX(TIME(end_datetime)) FROM trn_ticket;
-- Result: 00:59:59
```

If the max is `00:59:59`, then `INTERVAL 1 DAY` (= midnight) is insufficient. `INTERVAL 2 DAY` covers up to `23:59:59` on the next day.

### Document the Assumption

When choosing an INTERVAL value, leave a comment explaining what time range it covers:

```sql
-- Boundary: 2nd of next month (00:00:00). Covers tickets with end_datetime
-- up to 23:59:59 on the 1st. Current max in data: 00:59:59.
AND col < DATE_ADD(LAST_DAY(month_start), INTERVAL 2 DAY)
```

### Prefer Explicit Ceiling Over Tight Boundary

If the business rule is "belongs to this month", use a ceiling that unambiguously captures everything:

```sql
-- "Did the ticket expire within this calendar month?"
-- Ceiling = start of month + 2 (covers any time on day 1 of next month)
WHERE end_datetime < DATE_ADD(LAST_DAY(month_start), INTERVAL 2 DAY)
```

---

## Prevention Checklist

- [ ] When comparing DATETIME < DATE_ADD(..., INTERVAL N DAY), verify N covers the max time-of-day in the column
- [ ] Query `MAX(TIME(column))` before choosing the INTERVAL — don't assume midnight
- [ ] If multiple CTEs use the same boundary, ensure they all use the same INTERVAL value
- [ ] Add inline SQL comments documenting what time range the chosen INTERVAL covers
- [ ] Test with records at the maximum observed time-of-day (e.g. 00:59:59) — not just midnight
- [ ] When a boundary works in one CTE but not another, check if INTERVAL values diverged

---

## See Also

- **Topic 04** (DateTime Range Boundary) — the parent pattern. Topic 04 covers DATE vs DATETIME in general (BETWEEN, half-open intervals). Topic 19 covers the specific case where the half-open interval is correct but the INTERVAL arithmetic is wrong.
