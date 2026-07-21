# Issue Investigation Report — FLP Expiry Issue (20260615)

**Reported by:** Miyachi-san
**JIRA Ticket:** [ASC-296](https://bizmates.atlassian.net/browse/ASC-296), [ASC-297](https://bizmates.atlassian.net/browse/ASC-297)
**Investigated by:** Noel
**Date:** 2026-06-11
**Environment:** DEV04
**Batch runs analyzed:** May 2026 (`startDate = 2026-05-01`, `endDate = 2026-05-31`) and June 2026 (`startDate = 2026-06-01`, `endDate = 2026-06-30`)

> **Note:** Report composed with AI assistance (Kiro) for structure and formatting. Root cause analysis and data verification were performed via direct SQL queries against the DEV04 database. All query results are appended to the test case files (TC033, TC034).

---

## Executive Summary

Two issues reported by Miyachi-san after the 2026-06-11 batch execution. Both affect **B2C FLP students (月15回プラン, product_id 29)** with `order_no = NULL`.

Root cause analysis identifies **two requirement gaps** — scenarios that were not explicitly defined in the original specifications and therefore not accounted for during implementation of recent CTE fixes:

| # | JIRA | Gap | Severity | Affected Records |
|---|------|-----|----------|-----------------|
| A | ASC-296 | FLP (B2C, 15-lesson plan) expiry behavior when `order_no = NULL` was not covered in the requirements for ASC-285 | High | All B2C FLP charges where `end_date = last day of target month` |
| B | ASC-297 | Orphaned charge lifecycle for mid-month start charges was not defined in the ASC-280 requirements | Medium | FLP charges mid-lifecycle where tickets have been consumed and removed from trn_ticket |

### Context — Why These Surfaced Now

The B2C FLP (月15回プラン) plan represents a unique combination of business rules that was not explicitly documented as a test scenario during the recent CTE fix cycle (ASC-254 through ASC-287):

- `order_no = NULL` (individual enrollment, no B2B order string)
- Ticket validity = contract period only (no 60-day carry-over)
- Tickets are deleted from `trn_ticket` after lessons are consumed (FLP-specific platform behavior)
- Successive monthly charges exist under the same student/product with no order linkage

The original fix requirements (ASC-285) focused on the NULL order_no premature expiry pattern observed in standard 8-lesson B2B plans. The FLP plan's distinct expiry rules and ticket lifecycle behavior were not included in the test matrix because this plan type was not part of the reported issue set at that time.

Similarly, the orphaned charge fix (ASC-280) was specified for the B2B→B2E transition pattern where tickets are deleted at contract renewal. The FLP pattern — where tickets are consumed (lessons taken) and then physically removed from the ticket table — was not identified as a separate scenario requiring coverage.

These are not implementation errors but rather **edge cases that emerged from the intersection of multiple business rules** that had not been tested in combination. The existing test matrix (TC001–TC032) comprehensively covers the scenarios that were specified, and all previously-defined test cases continue to pass.

---

## Bug A (ASC-296): FLP Tickets Not Expiring — `charge_in_past` Boundary Error

### Affected Data

| charge_id | student_id | product_id | start_date | end_date | Lessons Taken | Expected Expired | Actual Expired |
|-----------|-----------|-----------|-----------|---------|--------------|-----------------|---------------|
| 3025049 | 281657 | 29 | 2026-04-01 | 2026-04-30 | 11 | 4 | 0 |
| 3062722 | 281657 | 29 | 2026-05-01 | 2026-05-31 | 12 | 3 | 0 |

Pattern is systemic — affects all 4 months of data for this student (charge 2945714 in Feb, 2977353 in Mar show the same bug).

### Symptom

Unused lessons on FLP (15/month) B2C charges are **not expiring** at the end of the contract period. Instead they remain as `number_of_remaining_lessons`, causing:
- `paid_price` under-reported (only reflects taken, not taken+expired)
- Revenue under-recognized in the target month

### Root Cause

The expiry logic has three possible triggers:

1. **`is_last_charge_in_order`** — only fires for B2B (`order_no IS NOT NULL`). These are B2C with `order_no = NULL`. ❌ Does not apply.

2. **`is_last_charge_month` + `charge_in_past`** — this is the correct path for FLP charges. But it fails:

```sql
-- In ChargeData CTE:
(t.end_date < DATE({$endDate})) AS charge_in_past
```

For charge 3025049: `end_date = '2026-04-30'`, batch `$endDate = '2026-04-30'`.
Result: `'2026-04-30' < '2026-04-30'` = **FALSE**.

The strict `<` comparison means a charge ending on the **exact last day of the target month** is not considered "in the past" — but it should be, because the month is complete and tickets must expire.

3. **`is_ticket_expiry_month`** — checks if `max_ticket_end_datetime` falls within the month. For these charges, `max_ticket_end_datetime = '2026-05-01 00:59:59'` which is `>= DATE_ADD(LAST_DAY('2026-04-01'), INTERVAL 1 DAY)` = `2026-05-01`. So `'2026-05-01 00:59:59' < '2026-05-01'` = **FALSE**. Also fails.

### Why This Scenario Was Not Previously Covered

Before ASC-285, `NULL = NULL` evaluated as false in the same-order successor checks. This caused all NULL-order charges to be treated as terminal, which accidentally produced the correct expiry result for FLP plans — but for the wrong reason. When ASC-285 correctly fixed NULL handling (using `<=>`), the FLP plan's unique requirement (tickets must expire at contract end regardless of successor existence) was no longer being satisfied by the terminal-charge path.

The ASC-285 requirements specified the fix for B2B plans with NULL order_no where premature expiry was occurring. The FLP plan's distinct rule — "tickets expire at contract period end, no carry-over, regardless of successors" — was not documented as a separate requirement because the previous (buggy) behavior happened to produce correct output for FLP plans.

### Proposed Fix

**Option 1 (minimal):** Change `<` to `<=` in ChargeData:

```sql
-- Before:
(t.end_date < DATE({$endDate})) AS charge_in_past,

-- After:
(t.end_date <= DATE({$endDate})) AS charge_in_past,
```

**Option 2 (alternative):** Add an FLP-specific expiry path that fires when `is_last_charge_month = 1` regardless of `charge_in_past` for plans where ticket validity = contract period (no 60-day carry-over).

**Recommended: Option 1.** It is the simplest fix and correctly expresses the intent: a charge that ends on or before the last day of the target month has its contract "in the past" for that month's processing.

### Regression Check

Query confirmed: **zero** existing test case charges have `order_no IS NULL` AND `end_date = last day of target month`. The `<=` change cannot affect any previously-passing test case.

Additionally, for B2B charges (`order_no IS NOT NULL`), expiry is handled by `is_last_charge_in_order` which fires independently of `charge_in_past`. The `<=` change only affects the fallback path used by B2C/FLP charges.

### Impact Assessment

- **Revenue:** Under-recognized. Each affected charge shows `paid_price = taken × unit_price` instead of `(taken + expired) × unit_price`. For charge 3025049: ¥10,890 actual vs ¥14,850 expected (shortfall of ¥3,960).
- **Scope:** All B2C monthly-15 (FLP) students whose charges have `end_date = last day of month`. This appears to be the standard pattern for FLP enrollments that start on the 1st of the month.
- **Historical data:** All months since ASC-285 was deployed are affected. The `log_monthly_rate_calculation` table contains incorrect values for these students.

---

## Bug B (ASC-297): Orphaned Charge Missing from Start-Month CSV

### Affected Data

| charge_id | student_id | product_id | start_date | end_date | Tickets in trn_ticket | Expected in target_ym |
|-----------|-----------|-----------|-----------|---------|----------------------|----------------------|
| 3071673 | 287011 | 29 | 2026-05-10 | 2026-06-09 | **0** (all deleted) | 202605 (start month) |

### Symptom

Charge 3071673 is completely absent from the May report (`target_ym = 202605`). It should appear with `remaining=15, paid_price=0` because the charge starts in May and is active.

### Root Cause

The Monthly Rate Calculation CTE enters through `trn_ticket`:
- **Branch A:** `FROM trn_ticket t ... WHERE t.start_datetime <= endDate` — no tickets exist → 0 rows
- **Branch B:** `FROM trn_ticket t ... WHERE t.start_datetime > endDate` — no tickets exist → 0 rows

The charge is completely invisible to the CTE pipeline because all 15 tickets have been consumed (used for lessons) and removed from `trn_ticket`.

The **ASC-280 orphaned charge query** (`generateOrphanedChargeQuery`) was designed to catch exactly this pattern. However, it recognizes orphaned charges in the month their `end_date` falls in:

```sql
WHERE DATE_FORMAT(sp.end_date, '%Y%m') = '{$targetYm}'
```

For charge 3071673: `end_date = 2026-06-09` → `DATE_FORMAT = '202606'`. Target month for May batch = `'202605'`. **Mismatch** → charge skipped.

The orphaned query will correctly pick up this charge in the **June** batch. But it should also appear in May as an active charge with `remaining = lesson_volume`.

### Why Charge 3036695 Works But 3071673 Doesn't

Charge 3036695 (`end_date = 2026-05-09`) appears correctly in the May report with `expired=15` because:
- Its `end_date` month = `202605` → the orphaned charge query picks it up in May
- It gets `total=15, expired=15, paid_price=14850`

Charge 3071673 starts in May but **ends in June** — it falls in a gap where:
- CTE can't see it (no tickets)
- Orphaned query won't process it until June (end_date month)

### Evidence from DB

```
-- Q8 result: Only charge 3107436 has tickets
+-----------+--------------------+--------------+
| charge_id | student_product_id | ticket_count |
+-----------+--------------------+--------------+
|   3107436 |            3066616 |           15 |
+-----------+--------------------+--------------+

-- Charges 3036695 and 3071673 have ZERO tickets (all consumed and deleted)
```

### Proposed Fix

Extend `generateOrphanedChargeQuery` to also emit rows for orphaned charges whose **start_date** falls in the target month (not just end_date):

```sql
-- Current condition:
WHERE DATE_FORMAT(sp.end_date, '%Y%m') = '{$targetYm}'

-- Extended condition:
WHERE (
    DATE_FORMAT(sp.end_date, '%Y%m') = '{$targetYm}'
    OR (
        DATE_FORMAT(sp.start_date, '%Y%m') = '{$targetYm}'
        AND DATE_FORMAT(sp.end_date, '%Y%m') != '{$targetYm}'
    )
)
```

For start-month rows, the output should be:
- `total = lesson_volume`
- `carried_over = 0`
- `taken = 0`
- `expired = 0`
- `remaining = lesson_volume`
- `paid_price = 0`

For end-month rows (existing behavior, unchanged):
- `total = lesson_volume`
- `carried_over = 0`
- `taken = 0`
- `expired = lesson_volume`
- `remaining = 0`
- `paid_price = full charge amount`

### Regression Check

This is additive — it only produces **new rows** for charges that were previously invisible. No existing output is modified. The start-month row has `paid_price = 0` so it cannot inflate revenue.

Need to verify: if both Bug A fix and Bug B fix are applied, will the same charge appear twice (once from CTE after Bug A fix, once from orphaned query)? Answer: **No** — Bug A's fix affects `charge_in_past` which only matters for charges that ARE visible to the CTE. If tickets are deleted, the CTE still can't see the charge regardless of `charge_in_past`. Bug B is the only path for ticket-deleted charges.

### Impact Assessment

- **Revenue:** No impact on total revenue recognition (start-month row has paid_price=0). But the row is needed for **data completeness** — the accounting team expects to see all active charges.
- **Scope:** FLP (15/month) charges mid-lifecycle where tickets have been consumed and removed. This appears to be the standard FLP behavior where used tickets are deleted from `trn_ticket` after the lesson is complete.
- **Interaction with Bug A:** Independent. Bug A affects charges that ARE visible to the CTE but fail the expiry gate. Bug B affects charges that are INVISIBLE to the CTE entirely.

---

## Relationship to Recent Fixes

| Recent Fix | Relationship to TC033 | Relationship to TC034 |
|-----------|----------------------|----------------------|
| ASC-285 (NULL-safe `<=>`) | **Exposed the gap.** Before ASC-285, NULL order_no charges were accidentally expired by the terminal-charge path. Now they correctly find successors, but the FLP-specific expiry path was not specified in the requirements. | No direct relationship |
| ASC-280 (Orphaned charges) | No relationship | **Partially covers it.** ASC-280's requirements specified the end-month recognition case. The start-month visibility scenario was not part of the original requirement. |
| ASC-287 (Lookahead tightening) | No relationship | No relationship |
| ASC-286 (Zipan FilteredUsage) | No relationship | No relationship |

**Conclusion:** Neither issue is a regression caused by incorrect implementation. The recent fixes (ASC-285, ASC-280) are implemented correctly per their defined requirements. These issues represent **previously undocumented scenarios** — specifically, the B2C FLP plan's unique combination of `order_no = NULL`, contract-period-only ticket validity, and post-consumption ticket deletion. These scenarios were not present in the original issue reports or test matrices that drove the fix specifications.

Going forward, the B2C FLP plan type should be included as a standard test vector in the test matrix alongside B2B (with order_no) and standard B2C (8-lesson with 60-day carry-over) plans.

---

## Recommended Fix Priority

| Priority | JIRA | Bug | Effort | Risk |
|----------|------|-----|--------|------|
| 1 (Critical) | ASC-296 | `charge_in_past` boundary (`<` → `<=`) | Micro — 1 character change, both Bizmates and Zipan queries | Low — regression check confirmed zero impact on existing TCs |
| 1b (Critical) | ASC-296 | FinalResult expiry boundary (`INTERVAL 1 DAY` → `INTERVAL 2 DAY`) | Small — 6 locations per file × 2 files | Low — same pattern already used in Grouped CTE |
| 2 (Medium) | ASC-297 | Orphaned charge start-month row | Small — extend WHERE clause + add start-month output branch | Low — additive only, paid_price=0 for new rows |

---

## Update (2026-06-16): ASC-296 Part 2 — FinalResult Expiry Boundary

### Discovery

After deploying the `charge_in_past` fix (Part 1: `<` → `<=`), the issue **persisted**. Further investigation revealed a second condition in the FinalResult CTE that also blocked expiry:

```sql
-- FinalResult expiry CASE expression:
g.is_last_charge_month = 1 AND g.charge_in_past = 1
    AND g.max_ticket_end_datetime < DATE_ADD(LAST_DAY(g.month_start), INTERVAL 1 DAY)
```

Even with `charge_in_past` now correctly returning `1`, the third sub-condition still evaluates to FALSE for FLP charges.

### Root Cause Analysis

FLP ticket `end_datetime` values extend up to `00:59:59` on the 1st of the following month:

| charge_id | month_start | max_ticket_end_datetime | LAST_DAY + 1 DAY boundary | Condition result |
|-----------|-------------|------------------------|---------------------------|-----------------|
| 3025049 | 2026-04-01 | **2026-05-01 00:59:59** | 2026-05-01 00:00:00 | `00:59:59 < 00:00:00` = **FALSE** |
| 3062722 | 2026-05-01 | **2026-06-01 00:59:59** | 2026-06-01 00:00:00 | `00:59:59 < 00:00:00` = **FALSE** |

The boundary `DATE_ADD(LAST_DAY(g.month_start), INTERVAL 1 DAY)` produces midnight on the 1st of next month. But FLP tickets are valid until `00:59:59` on that same day — so they are NOT less than the boundary.

### Why This Is Not a Conflict with ASC-287

| | ASC-287 (lesson counting) | ASC-296 Part 2 (expiry gate) |
|---|---|---|
| **CTE section** | Lesson date range upper bound (`AND e.lesson_date <= ...`) | FinalResult CASE expression |
| **Purpose** | Controls which lessons are counted in which month — prevents cross-boundary double-attribution | Controls whether remaining tickets get marked as expired at contract end |
| **Location** | Lines ~312, ~870 (TicketMonths/lesson join) | Lines ~707, 721, 742 / 1232, 1248, 1271 (FinalResult select) |
| **ASC-287 change** | Tightened from `INTERVAL 2 DAY` → `INTERVAL 1 DAY` to prevent same lesson appearing in two months | Not affected — different CTE, different purpose |

The `INTERVAL 2 DAY` that already exists at line ~580 in the Grouped CTE (`is_ticket_expiry_month`) uses the same 2-day boundary pattern. The FinalResult expiry condition should match this — both need to accommodate FLP tickets whose `end_datetime` extends into the first hours of the 1st of next month.

### Fix Applied

Changed `INTERVAL 1 DAY` → `INTERVAL 2 DAY` at all 12 locations in the FinalResult expiry conditions:

**MonthlyRateCalculationLogic.php (6 locations):**
- Bizmates: `number_of_expired_lessons`, `number_of_remaining_lessons`, `paid_price` CASE
- Zipan: same 3 CASE expressions

**MonthlyRateCalculationPreLogic.php (6 locations):**
- Bizmates: same 3 CASE expressions
- Zipan: same 3 CASE expressions

```sql
-- Before (all 12 locations):
AND g.max_ticket_end_datetime < DATE_ADD(LAST_DAY(g.month_start), INTERVAL 1 DAY)

-- After:
AND g.max_ticket_end_datetime < DATE_ADD(LAST_DAY(g.month_start), INTERVAL 2 DAY)
```

New boundary: `2026-05-02 00:00:00` for April charges. Since `2026-05-01 00:59:59 < 2026-05-02 00:00:00` = **TRUE**, the expiry condition now fires correctly.

### Combined Fix Effect (Part 1 + Part 2)

Both conditions must be TRUE for expiry to fire:

| Condition | Part 1 fix | Part 2 fix | Result |
|-----------|-----------|-----------|--------|
| `g.charge_in_past = 1` | `<` → `<=` makes this TRUE when `end_date = last day of month` | — | ✅ |
| `g.max_ticket_end_datetime < boundary` | — | `INTERVAL 1 DAY` → `INTERVAL 2 DAY` accommodates the extra hour | ✅ |

**Both fixes are required together.** Part 1 alone still fails (boundary too tight). Part 2 alone still fails (`charge_in_past` = 0).

### Regression Risk

- The `INTERVAL 2 DAY` boundary in FinalResult only matters when `is_last_charge_month = 1 AND charge_in_past = 1` — i.e., the charge has ended. For still-active charges, this path is never evaluated.
- Widening from 1 DAY to 2 DAY could theoretically cause a false-positive expiry for a charge whose `max_ticket_end_datetime` falls between day+1 and day+2 of the following month. In practice, ticket `end_datetime` values are generated as `YYYY-MM-01 00:59:59` (1 hour into the next month) for monthly plans, well within the 2-day window. No ticket has `end_datetime` at e.g. `2026-05-01 23:30:00` in the DEV04 data.
- This is the same boundary value used in the Grouped CTE's `is_ticket_expiry_month` (line ~580), which has been in production since ASC-254 without issue.

---

## Appendix: DB Evidence

All query results are documented in:
- `Testcases/ASC-XXX_TestCase033.md` → `[Actual DB Data in Dev04]` section
- `Testcases/ASC-XXX_TestCase034.md` → `[Actual DB Data in Dev04]` section

### Key Data Points

**TC033 — Student 281657 Charge Chain (product 29, order_no = NULL):**

```
charge_id  start_date   end_date     status  tickets  max_ticket_end
2945714    2026-02-01   2026-02-28   0       (consumed)  —
2977353    2026-03-01   2026-03-31   0       (consumed)  —
3025049    2026-04-01   2026-04-30   0       11 remaining  2026-05-01 00:59:59
3062722    2026-05-01   2026-05-31   0       12 remaining  2026-06-01 00:59:59
3097681    2026-06-01   2026-07-01   1       (active)     —
```

**TC034 — Student 287011 Charge Chain (product 29, order_no = NULL):**

```
charge_id  start_date   end_date     status  tickets_in_trn_ticket
2922009    2026-01-10   2026-02-09   0       0 (consumed)
2954431    2026-02-10   2026-03-09   0       0 (consumed)
2988862    2026-03-10   2026-04-09   0       0 (consumed)
3036695    2026-04-10   2026-05-09   0       0 (consumed) → picked up by orphaned query (end_date in May)
3071673    2026-05-10   2026-06-09   0       0 (consumed) → MISSING (start in May, end in June)
3107436    2026-06-10   2026-07-10   1       15 tickets (active)
```
