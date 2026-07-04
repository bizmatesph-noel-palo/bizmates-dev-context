# Kuroda-san Questions — Lookahead & Cleanup Analysis (20260625)

**Reported by:** Kuroda-san (code review questions)
**JIRA Ticket:** [ASC-301](https://bizmates.atlassian.net/browse/ASC-301) (lookahead), TBA (cleanup)
**Investigated by:** Noel
**Date:** 2026-06-25
**Environment:** Code analysis against `[ASC] app/Libs/MonthlyRateCalculationLogic.php`

**Related:** `REPORT_00_Lookahead_Condition_Investigation.md`

---

## Question 1: Can the Lookahead Be Removed Entirely (Option B)?

**Answer: Yes.**

### Why It's Safe to Remove

The recursive expansion of `TicketMonths` generates a next-month row when:
```sql
WHERE DATE_ADD(tm.month_start, INTERVAL 1 MONTH) < DATE(tm.end_datetime)
```

For charges with `end_date` on day 1-2 of the next month, `ticket.end_datetime` **always** extends past the 1st of that next month. This was verified via Metabase query against both Bizmates and Zipan — no charge exists where `max(ticket.end_datetime) <= first of the end_date month` (empty results for both DBs).

This means the CTE **always generates a next-month row** for these charges. In that next-month row, expiry fires via:
- `is_last_charge_month = 1` (end_date month = current month) AND `charge_in_past = 1` AND `max_ticket_end_datetime < LAST_DAY + INTERVAL 2 DAY`
- OR `is_last_charge_in_order = 1` (for B2B charges with `order_no`)

There is **no structural reason** in `ticket.end_datetime` handling that requires the lookahead path. The scenario it guards (ticket ending exactly at midnight on day 1, meaning no next-month row) has never existed in production.

### What to Remove

The entire OR block (with the ASC-301 gate) in the Grouped CTE `is_ticket_expiry_month`:

```sql
-- REMOVE THIS BLOCK (all 4 locations):
OR (
    om.rn = om.total_rows
    AND om.end_date > LAST_DAY(om.month_start)
    AND om.end_date <= DATE_ADD(LAST_DAY(om.month_start), INTERVAL 2 DAY)
    AND NOT EXISTS (
        SELECT 1 FROM StudentProduct sp3
        WHERE sp3.student_id = om.student_id
            AND sp3.product_id = om.product_id
            AND (sp3.order_no <=> om.order_no)
            AND sp3.start_date > om.end_date
    )
)
```

**Locations (4):**
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Bizmates Grouped CTE (~L620)
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Zipan Grouped CTE
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Bizmates Grouped CTE
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Zipan Grouped CTE

### Impact on Test Cases

- TC013 (B2B REST, end_date = 03/01): Expiry still fires via `is_last_charge_in_order` in March. No change to output.
- TC035 (FLP REST, end_date = 05/02): Expiry fires in May via `is_last_charge_month` (next-month row). Correct behavior — this is what the fix was designed to achieve.
- All other TCs: Lookahead was never triggered. No change.

---

## Question 2a: Can the `lessons_taken` CASE Be Simplified?

**Answer: Yes.**

### Current Code (MonthlyRateCalculationLogic.php ~L420)

```sql
AND ef.lesson_datetime < CASE
    WHEN tm.month_start = DATE_FORMAT(DATE({startDate}), '%Y-%m-01')
    THEN DATE_ADD(LAST_DAY(DATE({startDate})), INTERVAL 1 DAY)
    ELSE DATE_ADD(tm.month_start, INTERVAL 1 MONTH)
END
```

### Why Both Branches Are Equivalent

- **Target month:** `DATE_ADD(LAST_DAY(DATE({startDate})), INTERVAL 1 DAY)` = first day of next month
- **Prior months:** `DATE_ADD(tm.month_start, INTERVAL 1 MONTH)` = first day of next month

Since `month_start` is always the 1st of a month, and `LAST_DAY(1st) + 1 DAY` always equals `1st + 1 MONTH`, both branches produce the same date for any month:
- January: `LAST_DAY('2026-01-01')` = `2026-01-31`, +1 = `2026-02-01`. `'2026-01-01' + 1 MONTH` = `2026-02-01`. ✅
- February: `LAST_DAY('2026-02-01')` = `2026-02-28`, +1 = `2026-03-01`. `'2026-02-01' + 1 MONTH` = `2026-03-01`. ✅
- Any month: both formulas resolve to "first day of the following month." ✅

### Why the CASE Existed

The CASE was introduced in ASC-287. At that time, the target month branch used `INTERVAL 2 DAY` (to match the old lookahead-style 2-day boundary for lesson counting). ASC-287 tightened it to `INTERVAL 1 DAY`, which made both branches equivalent. The CASE became dead logic.

### Simplified Version

```sql
AND ef.lesson_datetime < DATE_ADD(tm.month_start, INTERVAL 1 MONTH)
```

**Locations (4):**
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Bizmates MonthlyUsage (~L420)
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Zipan MonthlyUsage
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Bizmates MonthlyUsage
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Zipan MonthlyUsage

---

## Question 2b: Can the EvaluationFilter `+2 DAY` Be Reduced?

**Answer: Yes, safely — but lower priority.**

### Current Code (MonthlyRateCalculationLogic.php ~L314-315)

```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({startDate}), INTERVAL 3 MONTH)
                      AND DATE_ADD(LAST_DAY(DATE({startDate})), INTERVAL 2 DAY)
```

This fetches evaluations up to 2 days past the last day of the target month.

### Why `+2 DAY` Is Now Unnecessary

The `lessons_taken` counting bound (after simplification) is:
```sql
ef.lesson_datetime < DATE_ADD(tm.month_start, INTERVAL 1 MONTH)
```

This means lessons on day 1 and 2 of the next month are **never counted** for the target month. The EvaluationFilter fetches them, but the counting logic discards them. The extra rows are harmless but unused.

### Why It Was `+2 DAY` Originally

The comment says: "must be able to see lessons that fall on that execution date (e.g., 3/1)." This was from before ASC-287, when the target month's upper bound was `LAST_DAY + 2 DAY` — lessons on day 1-2 of next month WERE counted for the target month. After ASC-287 tightened to `+1 DAY`, those lessons are no longer attributed to the target month.

### Safe Reduction

```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({startDate}), INTERVAL 3 MONTH)
                      AND DATE_ADD(LAST_DAY(DATE({startDate})), INTERVAL 1 DAY)
```

Or equivalently:
```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({startDate}), INTERVAL 3 MONTH)
                      AND LAST_DAY(DATE({startDate}))
```

Wait — `lesson_date` is a DATE column. A lesson on the 1st of next month has `lesson_date = '2026-05-01'`. The counting boundary is `lesson_datetime < '2026-05-01'` — so this lesson is NOT counted for April. Therefore the EvaluationFilter only needs to include up to `LAST_DAY(startDate)`:

```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({startDate}), INTERVAL 3 MONTH)
                      AND LAST_DAY(DATE({startDate}))
```

**However,** this needs careful consideration: the CTE generates rows for prior months too (recursive expansion). A lesson on 2026-04-01 with `month_start = 2026-03-01` needs `lesson_datetime < 2026-04-01` — this lesson IS counted for March. But since `startDate` is the target month and the evaluation filter goes back 3 months, lessons from prior months are already covered by `DATE_SUB(startDate, INTERVAL 3 MONTH)` on the lower bound.

**Recommendation:** Reduce to `INTERVAL 1 DAY` to match the counting boundary. This is a safe cleanup — no output change, just fewer unused rows fetched.

**Update (2026-06-26, follow-up from Kuroda-san):** Further analysis confirms `LAST_DAY(startDate)` with NO offset is the minimal safe bound:
- The counting logic uses `lesson_datetime < first of next month (midnight)`
- Any countable lesson must have `lesson_date ≤ LAST_DAY` (a lesson can't have datetime before midnight on the 1st but date ON the 1st)
- No downstream CTE stage references EvaluationFilter rows beyond the counting bound
- The recursive month expansion's prior-month lessons are covered by `DATE_SUB(startDate, INTERVAL 3 MONTH)` on the leading edge

**Tightest safe reduction:**
```sql
AND e.lesson_date BETWEEN DATE_SUB(DATE({startDate}), INTERVAL 3 MONTH)
                      AND LAST_DAY(DATE({startDate}))
```

**Locations (4):**
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Bizmates EvaluationFilter (~L314)
- `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — Zipan EvaluationFilter
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Bizmates EvaluationFilter
- `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — Zipan EvaluationFilter

---

## Summary of Recommended Changes

| # | Change | Risk | Priority |
|---|---|---|---|
| 1 | Remove lookahead OR block entirely | Low — verified scenario doesn't exist | High — removes the ASC-301 root cause |
| 2a | Simplify `lessons_taken` CASE to single bound | None — both branches produce identical output | Medium — dead code cleanup |
| 2b | Reduce EvaluationFilter from `+2 DAY` to `+1 DAY` | None — extra rows are already discarded by counting logic | Low — performance cleanup only |

All three changes are independent. They can be applied together in one ticket or separately.

---

## Regression Simulation

Ran test case simulation with Kiro against all 35 test cases (TC001–TC035, using -A overrides where applicable).

**Result: 0 regressions — all three changes are output-neutral.**

| Change | Affected TCs | Reasoning |
|---|---|---|
| Remove Lookahead | 0 / 35 | TC013-A (active override): end_date = 12/29, mid-month — lookahead never triggered. TC035: expiry fires in May via `is_last_charge_month` in next-month row. All others: either have successors (blocks lookahead) or end_date is mid-month (doesn't trigger). |
| Simplify CASE | 0 / 35 | Both branches produce identical dates for any month — mathematically proven. |
| Reduce EvaluationFilter | 0 / 35 | Lessons on day 2 of next month were fetched but never counted by `lessons_taken` logic. Reducing just stops fetching unused rows. |

**Key TC traces:**
- **TC013-A** (B2B REST, end_date = 12/29, no successor): end_date is mid-month. Lookahead condition (`end_date > LAST_DAY`) is FALSE. Expiry fires via `is_last_charge_month`. No change.
- **TC035** (FLP REST, end_date = 05/02, no successor): CTE generates May row. Expiry fires via `is_last_charge_month` in May. No change.
- **TC001** (end_date = 03/01, HAS successor): `NOT EXISTS` = FALSE → lookahead never fired. No change.
- **TC032** (end_date = 05/01, 05/02, HAS successor): Same as TC001 — successor blocks. No change.

---

## Status

Awaiting Kuroda-san's decision on whether to proceed. If approved, a JIRA ticket is needed for implementation.

---

## Cross-Reference

- Parent report: `REPORT_00_Lookahead_Condition_Investigation.md`
- Code references:
  - `[ASC] app/Libs/MonthlyRateCalculationLogic.php` lines ~608-635 (lookahead)
  - `[ASC] app/Libs/MonthlyRateCalculationLogic.php` lines ~412-421 (lessons_taken CASE)
  - `[ASC] app/Libs/MonthlyRateCalculationLogic.php` lines ~314-315 (EvaluationFilter)
- Ticket: `[asc-kiro] Technical_Notes/Tickets/TechDebts/ASC-XXX_Lookahead_Removal_And_Cleanup.md`
