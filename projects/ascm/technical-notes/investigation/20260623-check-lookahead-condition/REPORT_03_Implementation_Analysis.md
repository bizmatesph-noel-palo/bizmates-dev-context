# ASC-301 Implementation Analysis — Post-Processing + Lookahead Removal (20260709)

**Reported by:** Kuroda-san (implementation direction change)
**JIRA Ticket:** [ASC-301](https://bizmates.atlassian.net/browse/ASC-301)
**Investigated by:** Noel (Kiro-assisted)
**Date:** 2026-07-09
**Environment:** Code analysis against `feature/ASCH/ASCH-master`

**Related:**
- `REPORT_00_Lookahead_Condition_Investigation.md` — proves lookahead is dead code
- `REPORT_01_Kuroda_Questions_Analysis.md` — confirms safe removal + cleanup

---

## Summary

Kuroda-san directed a change in the ASC-301 fix approach:

> Instead of fixing the condition in the query, we fix wrong data after the process saves
> the data in log_monthly_rate_calculation. After it fixes the data correctly, the data
> will be calculated in CalculationSummary or sent to Freee as it is.

This combines with the earlier investigation conclusion (REPORT_00) that the lookahead OR block can be removed entirely — the scenario it guards has never existed in production.

**Two-part fix:**
1. **Remove** the 2-day lookahead OR block from the Grouped CTE (dead code removal)
2. **Add** a post-processing step after DB insert to correct any premature expiry rows

---

## Analysis

### Part 1: Lookahead Removal

**What to remove:**

```sql
OR (
    om.end_date > LAST_DAY(om.month_start)
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

**Why it's safe (confirmed by REPORT_00):**
- The scenario it guards (ticket ending exactly at midnight on day 1) has **never existed** in production (empty results for both Bizmates and Zipan)
- The CTE always generates a next-month row for these charges — expiry fires there via `is_last_charge_month` or `is_last_charge_in_order`
- The lookahead actively causes double revenue recognition for ALL contract types

**Affected locations (4):**

| # | File | Section |
|---|------|---------|
| 1 | `app/Libs/MonthlyRateCalculationLogic.php` | Bizmates Grouped CTE |
| 2 | `app/Libs/MonthlyRateCalculationLogic.php` | Zipan Grouped CTE |
| 3 | `app/Libs/MonthlyRateCalculationPreLogic.php` | Bizmates Grouped CTE |
| 4 | `app/Libs/MonthlyRateCalculationPreLogic.php` | Zipan Grouped CTE |

**Test case impact:** 0 regressions (confirmed by REPORT_01 simulation — all 35 TCs pass without the lookahead).

---

### Part 2: Post-Processing Correction

**Why post-processing in addition to removal:**

Even with the lookahead removed, Kuroda-san's direction is clear: don't rely solely on CTE logic changes. The post-processing serves as a safety net to catch any premature expiry rows regardless of source. This follows the "fix wrong data" philosophy over "prevent wrong data from being generated."

**Detection criteria (from Kuroda-san's message):**

| Condition | SQL |
|-----------|-----|
| Product: 15 lessons/month | `log.total = 15` |
| Charge period crosses into next month | `trn_charge.end_date > LAST_DAY(target_month)` |
| Premature expiry present | `number_of_remaining_lessons = 0 AND number_of_expired_lessons != 0` |

**Additional guard (from investigation):** limit to within the 2-day window:
```sql
AND tc.end_date <= DATE_ADD(LAST_DAY(target_month), INTERVAL 2 DAY)
```

This prevents false positives from charges that legitimately expire far past month-end.

**Correction logic:**

```
number_of_expired_lessons   → 0
number_of_remaining_lessons → (was number_of_expired_lessons)
paid_price                  → ROUND((charge_paid_price / total) × number_of_lessons_taken)
```

**Where to add:**
- In `execute()` method, after the INSERT and before COMMIT
- Same transaction — correction is atomic with the insert
- Applies to both Bizmates and Zipan connections

**Affected locations (2):**

| # | File | Section |
|---|------|---------|
| 5 | `app/Libs/MonthlyRateCalculationLogic.php` | `execute()` + new private method |
| 6 | `app/Libs/MonthlyRateCalculationPreLogic.php` | `execute()` + new private method |

---

### Interaction Between Part 1 and Part 2

| Scenario | With removal only | With removal + post-processing |
|----------|------------------|-------------------------------|
| Normal charge (end_date mid-month) | Unaffected | Unaffected (post-fix finds 0 rows) |
| Charge with end_date day 1-2 next month, HAS successor | Unaffected (successor blocks) | Unaffected (no expiry row to fix) |
| Charge with end_date day 1-2 next month, NO successor | ✅ Lookahead gone, expiry fires in next month via normal path | ✅ Double-safe: even if somehow wrong, post-fix catches it |
| Future unknown edge case | Depends on CTE correctness | Post-fix catches it if it matches the pattern |

**With both applied:** The lookahead removal eliminates the root cause. The post-processing provides belt-and-suspenders defense for any scenario where premature expiry appears in the log table.

---

## Scope Assessment

| Dimension | Value |
|-----------|-------|
| Severity | High — double revenue recognition |
| Data loss risk | None — correction restores correct values |
| Tenants affected | Both Bizmates and Zipan |
| Downstream impact | CalculationSummary + Freee journals consume corrected data automatically |
| Test coverage | TC035 validates the fix; TC001–TC034 validate no regression |

---

## Open Questions

1. **Pre logic (`MonthlyRateCalculationPreLogic.php`):** Does it have identical structure? Need to verify before implementing there.
2. **Should the post-processing also catch non-15-lesson plans?** The investigation found B2B charges (8-lesson) with the same double-fire pattern (Zipan 12480, 12501). The lookahead removal handles these, but should the post-fix be broader (`total IN (5, 8, 10, 12, 15, 16, 20)`) as additional safety?
3. **Logging granularity:** Per-row logging vs summary count only?

---

## Next Steps

- [ ] Confirm with Kuroda-san: post-fix scope — 15-lesson only or all monthly plans?
- [ ] Verify `MonthlyRateCalculationPreLogic.php` has the same lookahead block (4 locations total)
- [ ] Implement: remove lookahead (4 locations) + add post-processing (2 locations)
- [ ] Run test case simulation against all 35 TCs
- [ ] Present changes for review

---

## Cross-Reference

- Parent investigation: `REPORT_00_Lookahead_Condition_Investigation.md`
- Kuroda-san questions: `REPORT_01_Kuroda_Questions_Analysis.md`
- Test case: `testcases/TC035.md`
- Knowledge base: `knowledge-base/20-lookahead-premature-expiry.md`
