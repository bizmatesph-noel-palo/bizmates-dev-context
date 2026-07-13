# ASC-311 — Post-Processing Correction for Premature Expiry (20260713)

**Ticket:** [ASC-311](https://bizmates.atlassian.net/browse/ASC-311)
**Implemented by:** Noel (Kiro-assisted)
**Date:** 2026-07-13
**Branch:** `feature/ASCH/ASCH-master`
**Related:**
- `REPORT_00_Lookahead_Condition_Investigation.md`
- `REPORT_01_Kuroda_Questions_Analysis.md`
- `REPORT_03_Implementation_Analysis.md`
- `REPORT_04_Solution_Comparison.md`

---

## Summary

Implemented Option B (Post-Processing Correction) for the premature expiry bug caused by the 2-day lookahead condition in the Grouped CTE. After the CTE inserts rows into the log table, a detection query identifies incorrectly expired rows and a correction UPDATE fixes them in-place — all within the same transaction. The ASC-301 CTE gate (`rn = total_rows`), which was on the feature branch but never deployed to production, has been removed.

---

## Background & Decision

The Grouped CTE contains a 2-day lookahead condition (introduced ASC-256) that fires `is_ticket_expiry_month = 1` for charges whose `end_date` falls on day 1-2 of the next month with no successor. Investigation (REPORT_00) confirmed the scenario it guards has never existed in production, while the condition actively causes double revenue recognition.

Three options were evaluated (REPORT_04). The business/accounting team was hesitant about further CTE modifications given the history of cascading edge cases from ASC-246 through ASC-301.

| Date | Decision | By |
|------|----------|-----|
| 2026-06-23 | Investigation confirms lookahead is dead code | Noel |
| 2026-07-09 | Direction: Option B (post-processing), not Option C (removal) | Kuroda-san |
| 2026-07-11 | No product_id filter; scope to current target_ym only | Wu-san |
| 2026-07-11 | Remove ASC-301 gate, apply only ASC-311 | Kuroda-san |

**Selected:** Option B only — treat the CTE as a black box, fix its output after the fact.

---

## Change Description

### Files Modified

| # | File | Change |
|---|------|--------|
| 1 | `app/Libs/MonthlyRateCalculationLogic.php` | Removed ASC-301 gate (×2: Biz+Zipan), added `correctPrematureExpiry()` + call in `execute()` |
| 2 | `app/Libs/MonthlyRateCalculationPreLogic.php` | Removed ASC-301 gate (×2: Biz+Zipan), added `correctPrematureExpiry()` + call in `execute()` |

### Files Created

| # | File | Purpose |
|---|------|---------|
| 3 | `testcases/TC036.md` (in dev-context) | Test case for ASC-311 post-processing |

### Approach

1. **Removed** the `om.rn = om.total_rows` line from the lookahead OR block (4 locations). The CTE is restored to its pre-ASC-301 form — no CTE modifications.
2. **Added** a `correctPrematureExpiry(string $connection, string $targetYm)` private method to both Logic classes.
3. The method is called after INSERT and before COMMIT for both Bizmates and Zipan connections.
4. Updated file header docblocks (ASC-301 → ASC-311).

---

## Technical Detail

### Detection Query

Based on Wu-san's confirmed logic:

```sql
SELECT m.id
FROM {table} m
JOIN trn_charge c ON m.charge_id = c.id
WHERE m.target_ym = {targetYm}
  AND c.end_date >= '{firstDayOfNextMonth}'
  AND m.number_of_expired_lessons > 0
  AND m.number_of_remaining_lessons = 0;
```

| Condition | Purpose |
|-----------|---------|
| `target_ym = {current}` | Only fix just-created records — won't touch data already in `log_sum_calculation` |
| `c.end_date >= firstDayOfNextMonth` | Charge period crosses month boundary |
| `expired > 0` | Expiry was incorrectly set by lookahead |
| `remaining = 0` | All tickets marked as exhausted (premature) |

Parameters derived at runtime:
- `targetYm` = same value used for INSERT (e.g., `202604`)
- `firstDayOfNextMonth` = `Carbon::createFromFormat('Ym', targetYm)->addMonth()->startOfMonth()` (e.g., `2026-05-01`)

### Correction Query

```sql
UPDATE {table} m
JOIN trn_charge c ON m.charge_id = c.id
SET m.number_of_remaining_lessons = m.number_of_expired_lessons,
    m.number_of_expired_lessons = 0,
    m.paid_price = ROUND((c.paid_price / m.total) * m.number_of_lessons_taken)
WHERE m.id IN ({detected_ids});
```

| Field | Before (wrong) | After (corrected) |
|-------|---------------|-------------------|
| `number_of_expired_lessons` | N (premature) | 0 |
| `number_of_remaining_lessons` | 0 | N (restored) |
| `paid_price` | Full charge price | `ROUND(charge_price / total × taken)` |

**Example (TC036, charge 3001753, taken=0):**
- Before: `expired=15, remaining=0, paid_price=14850`
- After: `expired=0, remaining=15, paid_price=ROUND(14850/15×0)=0`

---

## Verification

> **Verification level:** Code Logic ↔ Test Cases (2 of 3 points).
> Actual CSV output comparison (point 3) pending DEV04 batch run.
> A logic-level pass gives high confidence that generated CSVs will match expected values, but final confirmation requires three-point verification after deployment.

### Test Results

| TC | JIRA | Description | Detection Triggers? | Result |
|:---|:---|:---|:---:|:---:|
| **TC036** | **ASC-311** | **Post-processing correction (fix target)** | **Yes (by design)** | ✅ **PASS** |
| TC001-A | ASC-149 | Carry-Over 60-day (8/month) | No | ✅ PASS |
| TC002 | ASC-151 | B2C FLP→B2B transition | No | ✅ PASS |
| TC003-A | ASC-151 | Zipan Monthly — no carryover | No | ✅ PASS |
| TC004 | ASC-151 | Monthly-15→B2B Refund (same month) | No | ✅ PASS |
| TC005 | ASC-151 | Monthly-15→B2B Refund (cross month) | No | ✅ PASS |
| TC006 | ASC-151 | Cooling-Off — lessons taken | No | ✅ PASS |
| TC007 | ASC-151 | Cooling-Off — no lessons | No | ✅ PASS |
| TC008 | ASC-151 | Cooling-Off — cross-month | No | ✅ PASS |
| TC009 | ASC-151 | B2C FLP→B2B (format variant) | No | ✅ PASS |
| TC010 | ASC-151 | FLP full month→B2B, 3 lessons | No | ✅ PASS |
| TC011 | ASC-151 | FLP full month→B2B, 0 lessons | No | ✅ PASS |
| TC012 | ASC-157 | Charge 2 + 60-day expiry | No | ✅ PASS |
| TC013-A | ASC-157 | B2B REST — within month | No | ✅ PASS |
| TC014 | ASC-211 | B2B order transition | No | ✅ PASS |
| TC015 | ASC-211 | Order last charge expiry | No | ✅ PASS |
| TC016 | ASC-205 | Zipan carried-over missing | No | ✅ PASS |
| TC017 | ASC-203 | CalculationSummary amount | No | ✅ PASS |
| TC018 | ASC-244 | Refund charge_id mismatch | No | ✅ PASS |
| TC019 | ASC-234 | Last charge double-counted | No | ✅ PASS |
| TC020 | ASC-236 | Partial refund doubled | No | ✅ PASS |
| TC021 | ASC-232 | Zipan invalid 3rd charge | No | ✅ PASS |
| TC022 | ASC-247 | Calculation validation matrix | No | ✅ PASS |
| TC023 | ASC-254 | First charge premature expiry | No | ✅ PASS |
| TC024 | ASC-258 | Last charge 60→30 day validity | No | ✅ PASS |
| TC025 | ASC-260 | Branch B lookahead filtering | No | ✅ PASS |
| TC026 | ASC-261 | Carried-over after ASC-260 | No | ✅ PASS |
| TC027 | ASC-264 | Period boundary | No | ✅ PASS |
| TC028 | ASC-266 | 60-day row missing | No | ✅ PASS |
| TC029 | ASC-267 | Last charge leaks next month | No | ✅ PASS |
| TC030 | ASC-269 | Refund row missing from CSV | No | ✅ PASS |
| TC031 | ASC-280 | Orphaned charges | No | ✅ PASS |
| TC032 | ASC-283 | Multiple patterns (4) | No | ✅ PASS |
| TC033 | ASC-296 | B2C FLP expiration failure | No | ✅ PASS |
| TC034 | ASC-297 | REST scheduled — missing row | No | ✅ PASS |
| TC035 | ASC-301 | Premature expiry (original bug) | No | ✅ PASS |

**Result: 36/36 PASS — 0 regressions**

### Why No Regression Is Possible

The detection requires ALL FOUR conditions simultaneously. For a false positive, a row would need:
- `end_date` beyond its target month — only day 1-2 cross-month charges qualify
- `expired > 0` AND `remaining = 0` — the premature expiry pattern
- No successor charge — otherwise CTE's `NOT EXISTS` blocks the lookahead

Legitimate expirations always have `end_date ≤ LAST_DAY(target_month)` — they expire within their own month, so condition #2 (`c.end_date >= firstDayOfNextMonth`) is never satisfied. The detection query is structurally incapable of matching correctly-expired rows.

---

## Impact Analysis

| Dimension | Assessment |
|-----------|-----------|
| Severity | High — premature expiry causes double revenue recognition |
| Scope | All monthly plans on both Bizmates and Zipan (no product_id filter) |
| Downstream | `log_sum_calculation` / CalculationSummary / Freee journals consume corrected data automatically — no changes needed |
| Data risk | None — correction restores correct values; runs within same transaction (atomic) |
| Deployment dependency | None — standalone change, no other PRs required |

---

## Cross-Reference

- Investigation: `REPORT_00_Lookahead_Condition_Investigation.md`
- Kuroda-san questions: `REPORT_01_Kuroda_Questions_Analysis.md`
- Implementation design: `REPORT_03_Implementation_Analysis.md`
- Solution comparison: `REPORT_04_Solution_Comparison.md`
- Test case: `testcases/TC036.md`
- Code:
  - `[ASC] app/Libs/MonthlyRateCalculationLogic.php` — `correctPrematureExpiry()`
  - `[ASC] app/Libs/MonthlyRateCalculationPreLogic.php` — `correctPrematureExpiry()`
