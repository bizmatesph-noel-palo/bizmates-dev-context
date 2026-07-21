# Data Adjustment Investigation Report (20260608)

**Reported by:** Wu-san (Sizhe Wu)
**JIRA Ticket:** [ASC-285](https://bizmates.atlassian.net/browse/ASC-285), [ASC-286](https://bizmates.atlassian.net/browse/ASC-286), [ASC-287](https://bizmates.atlassian.net/browse/ASC-287)
**Investigated by:** Noel
**Date:** 2026-06-08
**Environment:** Production (Metabase queries against prod DB)
**Batch run analyzed:** April 2026 (`startDate = 2026-04-01`, `endDate = 2026-04-30`) and May 2026 (`startDate = 2026-05-01`, `endDate = 2026-05-31`)

> **Note:** Report composed with AI assistance (Kiro) for structure and formatting. Root cause analysis, data verification, and queries were performed manually via Metabase against the production database. Source queries are provided in the Appendix at the bottom of this report.

---

## Executive Summary

Four distinct data issues were reported during monthly data adjustment.
Root cause analysis identifies **three underlying bugs** in the Monthly Rate Calculation CTE pipeline:

| # | Bug | Severity | Affected Records |
|---|-----|----------|-----------------|
| A | Zipan FilteredUsage missing ASC-264 fix | Medium | Zipan charges starting mid-month with zero lessons in start month |
| B | NULL order_no causes premature expiry | High | All Bizmates students with NULL order_no on monthly plans |
| C | 2-day lookahead double-counts cross-boundary lessons | Medium | Charges where a lesson falls on day 1-2 of the next month |

---

## Bug A: Zipan Cross-Month Charges Missing from Start Month

### Affected Charges

| charge_id | student_id | product_id | sp_start | sp_end | Lessons in April | Lessons in May |
|-----------|-----------|-----------|----------|--------|-----------------|---------------|
| 11590 | 3818 | 17 (10/mo) | 2026-04-10 | 2026-05-09 | 0 | 1 |
| 11745 | 1749 | 16 (5/mo) | 2026-04-11 | 2026-05-10 | 0 | 4 |
| 12555 | 2104 | 17 (10/mo) | 2026-04-25 | 2026-05-24 | 0 | 6 |
| 12631 | 1931 | 17 (10/mo) | 2026-04-28 | 2026-05-27 | 0 | 10 |

### Symptom

These charges span April–May but do not appear in `log_monthly_rate_calculation` with `target_ym = 202604`.
They only appear in `target_ym = 202605`.

### Root Cause

The **Zipan** `FilteredUsage` CTE is missing the ASC-264 fix that was applied to Bizmates.

In the **Bizmates** query, FilteredUsage includes this OR condition:

```sql
-- FIX ASC-264: Always show charges that started in the current month
OR DATE_FORMAT(mu.start_date, '%Y-%m-01') = mu.month_start
```

This condition is **absent in the Zipan query**.
Without it, charges that:
1. Start mid-month (e.g., April 10)
2. Have zero lessons taken in the start month
3. Have a different-order successor charge

…are expelled by FilteredUsage because:
- The "no newer order" check finds a successor (e.g., student 3818 has order 10030076 starting June 10)
- None of the other OR conditions apply (`end_date` month ≠ April, `lessons_taken = 0`)

### Proof

Taking charge 11590 (student 3818) in the April batch:
- `start_date = 2026-04-10` → `DATE_FORMAT('2026-04-10', '%Y-%m-01') = '2026-04-01'`
- `month_start = '2026-04-01'` (from TicketMonths Branch A)
- These are **equal** → the ASC-264 condition would save the row
- But Zipan's FilteredUsage lacks this condition → row expelled

### Fix

Add to Zipan's FilteredUsage OR block:

```sql
-- FIX ASC-264 (Zipan): Always show charges that started in the current month
OR DATE_FORMAT(mu.start_date, '%Y-%m-01') = mu.month_start
```

### Impact of the Data Issue

- These charges should have appeared in April with `remaining = lesson_volume, paid_price = 0` (no lessons consumed, no expiry yet)
- The May output is correct on its own (the May batch independently sees these charges)
- **Accounting impact:** April CSV under-reports remaining lessons for these students. The total paid_price recognition across months is still correct (all revenue recognized in May where expiry/consumption happens), but the month-over-month split is wrong

### Estimated Scope

Any Zipan monthly-plan charge that:
- Starts after the 1st of the month
- Has zero lessons in its start month
- Has a different-order successor

---

## Bug B: NULL `order_no` Causes Premature Expiry

### Affected Charges

| charge_id | student_id | product_id | order_no | sp_start | sp_end | Lessons in April |
|-----------|-----------|-----------|----------|----------|--------|-----------------|
| 3026692 | 1236 | 29 (15/mo) | NULL | 2026-04-02 | 2026-05-01 | 3 |
| 3001753 | 121073 | 29 (15/mo) | NULL | 2026-04-03 | 2026-05-02 | 0 |
| 3026886 | 233228 | 29 (15/mo) | NULL | 2026-04-02 | 2026-05-01 | 0 |

### Symptom

Two rows generated per charge_id with `number_of_expired_lessons` showing the full remaining count in April (premature expiry), then the same lessons re-expiring in May.

**Charge 3026692 output:**

| target_ym | total | carried_over | taken | expired | remaining | paid_price |
|-----------|-------|-------------|-------|---------|-----------|-----------|
| 202604 | 15 | 0 | 3 | 12 | 0 | 14107 |
| 202605 | 15 | 12 | 0 | 12 | 0 | 11286 |

**Expected (correct) behavior for 202604:**
- Same-order successor exists (charge 3064554, start 2026-05-02)
- April should show: `taken=3, remaining=12, expired=0, paid_price=2821`
- Carry-over to May: `carried_over=12, expired=12, paid_price=11286`

### Root Cause

The same-order successor check uses standard equality on `order_no`:

```sql
AND NOT EXISTS (
    SELECT 1 FROM StudentProduct sp3
    WHERE sp3.student_id = om.student_id
        AND sp3.product_id = om.product_id
        AND sp3.order_no = om.order_no      -- ← NULL = NULL is NULL (falsy) in SQL
        AND sp3.start_date > om.end_date
)
```

**In SQL, `NULL = NULL` evaluates to `NULL`, not `TRUE`.** This means the `NOT EXISTS` subquery always returns TRUE for charges with `order_no IS NULL`, regardless of whether a successor exists.

The system incorrectly treats every NULL-order charge as a terminal charge (no successor), firing the `is_last_charge_in_order` / `is_ticket_expiry_month` logic, which expires all remaining lessons immediately.

### Proof

Student 1236's charge history (all product 29, all `order_no = NULL`):

| charge_id | start_date | end_date |
|-----------|-----------|---------|
| 2858116 | 2025-12-02 | 2026-01-01 |
| 2912934 | 2026-01-02 | 2026-02-01 |
| 2946562 | 2026-02-02 | 2026-03-01 |
| 2978357 | 2026-03-02 | 2026-04-01 |
| **3026692** | **2026-04-02** | **2026-05-01** |
| 3064554 | 2026-05-02 | 2026-06-01 |
| 3099087 | 2026-06-02 | 2026-07-02 |

Charge 3064554 is clearly the successor to 3026692. But the NULL equality check fails → system thinks 3026692 is terminal → fires expiry in April.

### Fix

Replace all `sp3.order_no = om.order_no` comparisons (in `is_ticket_expiry_month`, `is_last_charge_in_order`, and FilteredUsage successor checks) with NULL-safe equality:

```sql
AND (sp3.order_no = om.order_no OR (sp3.order_no IS NULL AND om.order_no IS NULL))
```

This applies to:
- The `Grouped` CTE's `is_ticket_expiry_month` CASE expression (multiple NOT EXISTS subqueries)
- The `LastChargeWithinOrder` CTE GROUP BY (must handle NULL grouping)
- The `FilteredUsage` same-order successor checks (ASC-266 condition)
- Both Bizmates and Zipan queries

**Alternative:** MySQL's null-safe equality operator `<=>`:
```sql
AND sp3.order_no <=> om.order_no
```

### Impact of the Data Issue

- **Double-expiry:** Lessons are expired in April AND carried-over/expired again in May. The total `paid_price` across both months exceeds the charge's actual `paid_price`
- For charge 3026692: April paid_price = 14107 (full) + May paid_price = 11286 → total attributed = **25393 vs actual 14107**
- **Accounting impact:** Revenue over-recognized. Freee journal entries will show inflated monthly rate amounts for affected students
- **Scope:** All Bizmates monthly-plan students whose charges have `order_no = NULL`. This appears to be the case for individual (non-B2B) enrollments where the legacy system didn't assign order numbers

### Estimated Scope

Any monthly-plan charge (product_id 16-23, 27-29) where:
- `trn_student_product.order_no IS NULL`
- A successor charge exists for the same student/product
- The charge has remaining lessons that should carry over

---

## Bug C: 2-Day Lookahead Double-Counts Cross-Boundary Lessons

### Affected Charges

| charge_id | student_id | product_id | sp_start | sp_end | Lesson on boundary |
|-----------|-----------|-----------|----------|--------|-------------------|
| 3028086 | 67915 | 29 (15/mo) | 2026-04-03 | 2026-05-02 | May 1 (1 lesson) |
| 3028147 | 62241 | 29 (15/mo) | 2026-04-03 | 2026-05-02 | May 1 (2 lessons), May 2 (3 lessons) |

### Symptom

**Charge 3028086:**

| target_ym | total | carried_over | taken | expired | remaining | paid_price |
|-----------|-------|-------------|-------|---------|-----------|-----------|
| 202604 | 15 | 0 | **15** | 0 | 0 | 14107 |
| 202605 | 15 | **1** | **1** | 0 | 0 | 940 |

Sum of `taken` = 15 + 1 = **16**, exceeding the plan's 15-lesson volume.

**Charge 3028147:**

| target_ym | total | carried_over | taken | expired | remaining | paid_price |
|-----------|-------|-------------|-------|---------|-----------|-----------|
| 202604 | 15 | 0 | **8** | 7 | 0 | 14107 |
| 202605 | 15 | **9** | **5** | 4 | 0 | 8464 |

April shows `taken=8` but only 6 evaluations exist before May 1. May shows `carried_over=9` = 15-6, ignoring the 2 lessons on May 1 that April counted.

### Root Cause

The per-month lesson counting uses a **2-day lookahead** for the target month (ASC-261 fix):

```sql
AND ef.lesson_datetime < CASE
    WHEN tm.month_start = DATE_FORMAT(DATE({$startDate}), '%Y-%m-01')
    THEN DATE_ADD(LAST_DAY(DATE({$startDate})), INTERVAL 2 DAY)   -- target month: last_day + 2
    ELSE DATE_ADD(tm.month_start, INTERVAL 1 MONTH)               -- other months: strict boundary
END
```

For the **April batch** (`startDate = 2026-04-01`):
- Target month = April → upper bound = `LAST_DAY('2026-04-01') + 2 = 2026-05-02`
- A lesson on May 1 (`2026-05-01 10:30`) is `< 2026-05-02` → **counted in April**

For the **May batch** (`startDate = 2026-05-01`):
- Target month = May → lower bound = `month_start = 2026-05-01`
- The same May 1 lesson is `>= 2026-05-01` → **counted in May**

The same lesson is counted in **both** batches because each batch runs independently.

Additionally, when the May batch processes earlier months (for carry-over calculation), it uses the strict boundary for April:
- Non-target month April upper bound = `month_start + 1 MONTH = 2026-05-01`
- The May 1 lesson is NOT `< 2026-05-01` → **not counted in April from May's perspective**

This creates an inconsistency:
- April batch says: "April taken = 14 + 1 (May 1 via lookahead) = 15, remaining = 0"
- May batch says: "April taken = 14 (strict boundary), remaining = 1 → carried_over to May = 1"

### Proof — Charge 3028086 (student 67915)

Evaluations:
- April: 14 lessons (Apr 4 through Apr 29)
- May: 1 lesson (May 1, 10:30)

**April batch execution:**
- April upper bound = 2026-05-02 (lookahead)
- Counts May 1 lesson → April `taken = 15`, `remaining = 0`
- `is_ticket_expiry_month` fires (NULL order issue + all consumed) → no carry-over

**May batch execution:**
- April (non-target month) upper bound = 2026-05-01 (strict)
- Does NOT count May 1 lesson in April → April `taken = 14`, `remaining = 1`
- Carries `1` to May
- May counts the May 1 lesson → May `taken = 1`
- Total across both batches: 15 + 1 = **16** (exceeds plan)

### Fix

The 2-day lookahead (ASC-261) was applied at two levels:
1. **EvaluationFilter WHERE clause:** `lesson_date BETWEEN ... AND DATE_ADD(LAST_DAY, INTERVAL 2 DAY)` — ensures evaluation rows are fetched into the working set
2. **Per-month counting in MonthlyUsage:** `lesson_datetime < LAST_DAY + 2` — attributes them to the target month

Level 1 is correct and necessary (the batch runs on the 1st of the next month; without it, evaluations on that date would be excluded entirely).

Level 2 is the source of the double-counting. It pulls lessons from May 1-2 into April's count, but when the May batch runs, those same lessons fall naturally into May's window.

**Fix:** Tighten the per-month counting upper bound for the target month from `LAST_DAY + 2 DAY` to `LAST_DAY + 1 DAY` (first day of next month, exclusive):

```sql
WHEN tm.month_start = DATE_FORMAT(DATE({$startDate}), '%Y-%m-01')
THEN DATE_ADD(LAST_DAY(DATE({$startDate})), INTERVAL 1 DAY)  -- = first of next month (exclusive)
```

This means: a lesson on May 1 is `NOT < May 1` → not counted in April. It will only be counted when the May batch runs.

**Risk:** ASC-157 originally needed the lookahead because some lessons have `lesson_datetime` on the batch execution date (1st of next month). If we tighten to `+ 1 DAY`, a lesson at `2026-05-01 10:30` is exactly at the boundary (`NOT < 2026-05-01`). These lessons would be attributed to May (their calendar month) rather than April. This is arguably correct behavior — the lesson happened in May, it belongs to May. But we need to verify there is no business rule that says "lessons on the batch execution date belong to the previous month."

### Nature of the Bug

This is a **boundary-overlap / double-attribution** bug — not a database concurrency issue.

The April and May batches are independent executions (run days or weeks apart, no concurrency involved). Both read the same stable evaluation data. The problem is that they define **overlapping counting boundaries** for the same lesson:

- April batch's upper bound: `LAST_DAY(April) + 2 = May 2` → includes lessons on May 1
- May batch's lower bound: `month_start = May 1` → also includes lessons on May 1

The same lesson is attributed to **both** months because the boundaries overlap by 1-2 days.

Each batch produces internally consistent output. But when the two outputs are viewed together (as they are in the monthly CSV / accounting data), they are **globally inconsistent**:

- April batch says: "I counted 15 lessons for this charge (including May 1 via lookahead). All consumed."
- May batch says: "April only had 14 lessons (strict boundary for non-target months). 1 remaining carries to May. I count 1 lesson in May."
- Combined output: 15 + 1 = 16 > plan limit of 15

The closest analogy is **double-booking in accounting** — the same transaction (lesson) is recognized in two periods because the period boundaries overlap.

### Decision Required from Business

The fix (tightening the upper bound to `LAST_DAY + 1 DAY`) means that **lessons taken on the 1st of the following month will always be attributed to that following month** rather than the current target month.

Example: If a student takes a lesson on May 1 and the April batch runs on May 1, that lesson will appear in the **May CSV**, not the April CSV.

**Question for business team:** Is it acceptable that a lesson on May 1 is recognized in May's revenue, even though the April accounting batch hasn't been finalized yet? Or is there a business rule that says "lessons on batch execution day belong to the previous month"?

If lessons on the 1st always belong to the current calendar month (May 1 → May), the fix is clean and correct. If there's a special rule for batch-day attribution, we need a different approach.

### Impact of the Data Issue

- **Over-counting lessons:** `number_of_lessons_taken` sum exceeds `lesson_volume` (plan limit)
- **Over-recognition of revenue:** Charge 3028086 shows paid_price = 14107 + 940 = 15047 vs actual 14107
- **Incorrect carry-over:** May batch creates phantom carry-over (1 lesson) that doesn't actually exist
- **Accounting impact:** Monthly rate CSV contains paid_price values that, when summed across months for a single charge, exceed the charge's actual paid_price
- **Scope:** Any charge where a lesson falls on the 1st or 2nd of the month following the charge's target month, and the charge's ticket validity extends into that month

### Interaction with Bug B

For charge 3028147, **both Bug B and Bug C** contribute:
- Bug B (NULL order_no) causes premature expiry of remaining=7 in April
- Bug C (lookahead) makes April count 8 lessons instead of 6 (May 1 lessons pulled into April)
- Combined effect: April shows `taken=8, expired=7` instead of the correct `taken=6, remaining=9, expired=0`

If Bug B is fixed first:
- April would show: `taken=8 (includes May 1 via lookahead), remaining=7, expired=0` (no premature expiry because successor recognized)
- May would show: `carried_over=9 (May batch says April taken=6), taken=5, expired=4`
- The discrepancy in `carried_over` (7 vs 9) would still exist due to Bug C

---

## Overall Impact Assessment

### Revenue Recognition

| Bug | Revenue Effect | Direction |
|-----|---------------|-----------|
| A (Zipan missing April) | Month allocation shifted (April → May) | Neutral over lifetime, wrong month split |
| B (NULL order premature expiry) | Double-expiry inflates total paid_price | **Over-recognized** |
| C (Lookahead double-count) | Phantom carry-over inflates total paid_price | **Over-recognized** |

### Affected Population Estimate

| Bug | Scope |
|-----|-------|
| A | Zipan monthly-plan charges starting after day 1 with 0 lessons in start month + different-order successor |
| B | **All Bizmates monthly-plan students with NULL order_no** (appears to be individual/non-B2B enrollments) |
| C | Any charge where a lesson occurs on day 1-2 of the following month |

Bug B is likely the highest-volume issue since it affects a structural category of students, not just edge-case timing.

---

## Recommended Fix Priority

| Priority | Bug | Effort | Risk |
|----------|-----|--------|------|
| 1 | B (NULL order_no) | Low — replace `=` with NULL-safe comparison in ~6 locations per query | Low — strictly more correct, no behavioral change for non-NULL orders |
| 2 | A (Zipan ASC-264) | Low — add one OR condition to Zipan FilteredUsage | Low — direct port of existing Bizmates fix |
| 3 | C (Lookahead) | Medium — needs careful boundary analysis | Medium — changing the lookahead may affect the original ASC-157 fix |

---

## Appendix: Data Evidence

### Bug B — Student 1236 Charge Chain (all order_no = NULL)

```
charge_id  start_date   end_date     successor
2858116    2025-12-02   2026-01-01   → 2912934
2912934    2026-01-02   2026-02-01   → 2946562
2946562    2026-02-02   2026-03-01   → 2978357
2978357    2026-03-02   2026-04-01   → 3026692
3026692    2026-04-02   2026-05-01   → 3064554  ← affected charge
3064554    2026-05-02   2026-06-01   → 3099087
3099087    2026-06-02   2026-07-02   (current)
```

### Bug C — Charge 3028086 Evaluation Timeline

```
lesson_datetime         counted_in_april_batch  counted_in_may_batch
2026-04-04 18:30        ✓ (< 2026-05-02)       ✓ (April strict: < 2026-05-01)
2026-04-06 08:30        ✓                       ✓
... (12 more in April)
2026-04-29 09:00        ✓                       ✓
2026-05-01 10:30        ✓ (< 2026-05-02)       ✗ (not < 2026-05-01 for April)
                                                 ✓ (>= 2026-05-01 for May)
─────────────────────────────────────────────────────────────────────
April total:            15                      14
May total:             n/a                      1
Cross-batch sum:       15 + 1 = 16 > 15 (OVER)
```

### Bug A — Zipan Charge 11590 FilteredUsage Walk-Through

```
April batch (startDate=2026-04-01, endDate=2026-04-30):

TicketMonths Branch A:
  ticket_start = 2026-04-10 01:00 (≤ endDate ✓)
  ticket_end   = 2026-06-10 00:59 (≥ startDate ✓)
  → month_start = 2026-04-01, target_ym = 202604

MonthlyUsage:
  lessons_taken = 0 (all lessons in May)

FilteredUsage check:
  Different-order successor exists? → YES (order 10030076 starts 2026-06-10)
  OR end_date month = month_start? → 2026-05-01 ≠ 2026-04-01 → NO
  OR lessons_taken > 0? → NO
  OR start_date month = month_start? → NOT CHECKED (missing ASC-264)
  
  → Row EXPELLED. Charge absent from 202604.
```

---

## Appendix: Metabase Queries Used

All queries were run against the production database via Metabase.

### Bizmates — Charge + StudentProduct + Tickets

```sql
SELECT
    c.id AS charge_id,
    c.student_id,
    c.product_id,
    c.order_no,
    c.paid_price,
    c.paid_at,
    c.start_date AS charge_start,
    c.end_date AS charge_end,
    sp.id AS student_product_id,
    sp.start_date AS sp_start,
    sp.end_date AS sp_end,
    sp.order_no AS sp_order_no,
    t.id AS ticket_id,
    t.start_datetime AS ticket_start,
    t.end_datetime AS ticket_end,
    t.ticket_type
FROM trn_charge c
JOIN trn_student_product sp ON sp.charge_id = c.id AND sp.main_product = 1
LEFT JOIN trn_ticket t ON t.student_product_id = sp.id AND t.ticket_type = 3
WHERE c.id IN (3026692, 3001753, 3026886, 3028086, 3028147)
ORDER BY c.id, t.start_datetime;
```

### Bizmates — Evaluations (Lessons Taken)

```sql
SELECT
    e.student_id,
    e.ticket_id,
    e.lesson_datetime,
    e.lesson_date,
    e.result,
    t.student_product_id,
    sp.charge_id
FROM trn_evaluation e
JOIN trn_ticket t ON t.id = e.ticket_id AND t.ticket_type = 3
JOIN trn_student_product sp ON sp.id = t.student_product_id AND sp.main_product = 1
WHERE sp.charge_id IN (3026692, 3001753, 3026886, 3028086, 3028147)
    AND e.ticket_type = 3
    AND e.status IN (0, 1)
    AND e.result IN (0, 1, 2, 3, 4)
ORDER BY sp.charge_id, e.lesson_datetime;
```

### Bizmates — log_monthly_rate_calculation Output

```sql
SELECT *
FROM log_monthly_rate_calculation
WHERE charge_id IN (3026692, 3001753, 3026886, 3028086, 3028147)
ORDER BY charge_id, target_ym;
```

### Bizmates — Same-Student Other Charges (Order Succession)

```sql
SELECT sp2.student_id, sp2.charge_id, sp2.product_id, sp2.order_no, sp2.start_date, sp2.end_date
FROM trn_student_product sp2
WHERE sp2.student_id IN (
    SELECT c.student_id FROM trn_charge c WHERE c.id IN (3026692, 3001753, 3026886, 3028086, 3028147)
)
AND sp2.main_product = 1
AND sp2.status IN (0, 1)
ORDER BY sp2.student_id, sp2.start_date;
```

### Zipan — Charge + StudentProduct + Tickets

```sql
SELECT
    c.id AS charge_id,
    c.student_id,
    c.product_id,
    c.order_no,
    c.paid_price,
    c.paid_at,
    c.start_date AS charge_start,
    c.end_date AS charge_end,
    sp.id AS student_product_id,
    sp.start_date AS sp_start,
    sp.end_date AS sp_end,
    sp.order_no AS sp_order_no,
    t.id AS ticket_id,
    t.start_datetime AS ticket_start,
    t.end_datetime AS ticket_end,
    t.ticket_type
FROM trn_charge c
JOIN trn_student_product sp ON sp.charge_id = c.id AND sp.main_product = 1
LEFT JOIN trn_ticket t ON t.student_product_id = sp.id AND t.ticket_type = 3
WHERE c.id IN (11590, 11745, 12555, 12631)
ORDER BY c.id, t.start_datetime;
```

### Zipan — Evaluations (Lessons Taken)

```sql
SELECT
    e.student_id,
    e.ticket_id,
    e.lesson_datetime,
    e.lesson_date,
    e.result,
    t.student_product_id,
    sp.charge_id
FROM trn_evaluation e
JOIN trn_ticket t ON t.id = e.ticket_id AND t.ticket_type = 3
JOIN trn_student_product sp ON sp.id = t.student_product_id AND sp.main_product = 1
WHERE sp.charge_id IN (11590, 11745, 12555, 12631)
    AND e.ticket_type = 3
    AND e.status IN (0, 1)
    AND e.result IN (0, 1, 2, 3, 4)
ORDER BY sp.charge_id, e.lesson_datetime;
```

### Zipan — log_monthly_rate_calculation Output

```sql
SELECT *
FROM log_monthly_rate_calculation
WHERE charge_id IN (11590, 11745, 12555, 12631)
ORDER BY charge_id, target_ym;
```

### Zipan — Same-Student Other Charges (Order Succession)

```sql
SELECT sp2.student_id, sp2.charge_id, sp2.product_id, sp2.order_no, sp2.start_date, sp2.end_date
FROM trn_student_product sp2
WHERE sp2.student_id IN (
    SELECT c.student_id FROM trn_charge c WHERE c.id IN (11590, 11745, 12555, 12631)
)
AND sp2.main_product = 1
AND sp2.status IN (0, 1)
ORDER BY sp2.student_id, sp2.start_date;
```
