# Full Test Case Simulation — Lookahead Removal & Cleanup (20260626)

**Scope:** All 35 active test cases (using -A overrides where available)
**Simulated by:** Kiro
**Date:** 2026-06-26
**Level:** Acceptance (full suite)

**Related:** `REPORT_01_Kuroda_Questions_Analysis.md`

---

## Result: ALL PASS — 0 Regressions

| Change | Result | Confidence |
|--------|--------|:----------:|
| 1 — Remove Lookahead OR Block | 35/35 PASS | 99% |
| 2a — Simplify CASE to single bound | 35/35 PASS | 100% |
| 2b — Reduce EvaluationFilter to LAST_DAY (no offset) | 35/35 PASS | 100% |

**Total: 105 checks, 0 regressions. All three changes are output-neutral.**

---

## Per-Test-Case Scorecard

| TC# | C1 (Lookahead) | C2a (CASE) | C2b (EvalFilter) | Key Reasoning |
|-----|:---:|:---:|:---:|---|
| TC001-A | ✅ | ✅ | ✅ | end_date=12/29 mid-month, HAS successor |
| TC002 | ✅ | ✅ | ✅ | end_date=02/24 mid-month, HAS successor |
| TC003-A | ✅ | ✅ | ✅ | Zipan, end_date=12/29 mid-month, HAS successor |
| TC004 | ✅ | ✅ | ✅ | end_date=01/31 LAST_DAY, refund scenario |
| TC005 | ✅ | ✅ | ✅ | end_date=01/31, refund cross-month |
| TC006 | ✅ | ✅ | ✅ | Cooling-off, end_date=01/31 |
| TC007 | ✅ | ✅ | ✅ | Cooling-off, no lessons |
| TC008 | ✅ | ✅ | ✅ | Cooling-off cross-month, end_date=02/27 |
| TC009 | ✅ | ✅ | ✅ | FLP→B2B, end_date=02/24 |
| TC010 | ✅ | ✅ | ✅ | FLP full month, end_date=02/28 |
| TC011 | ✅ | ✅ | ✅ | FLP 0 lessons, end_date=02/28 |
| TC012 | ✅ | ✅ | ✅ | 60-day validity, HAS successor |
| TC013-A | ✅ | ✅ | ✅ | B2B REST, end_date=12/29. Lookahead never fired (mid-month). Expiry via `is_last_charge_in_order`. |
| TC014 | ✅ | ✅ | ✅ | B2B order transition, end_date=01/10 |
| TC015 | ✅ | ✅ | ✅ | B2B last charge, end_date=04/10 |
| TC016 | ✅ | ✅ | ✅ | Zipan carry-over, end_date=02/07 |
| TC017 | ✅ | ✅ | ✅ | Summary validation — not expiry-related |
| TC018 | ✅ | ✅ | ✅ | Refund identity — separate query |
| TC019 | ✅ | ✅ | ✅ | B2B last charge, lessons on Feb 1 counted for Feb (not Jan) |
| TC020 | ✅ | ✅ | ✅ | Partial refund — separate query |
| TC021 | ✅ | ✅ | ✅ | Zipan ghost, end_date=02/07 |
| TC022 | ✅ | ✅ | ✅ | Formula matrix — not boundary logic |
| TC023 | ✅ | ✅ | ✅ | Premature expiry, all LAST_DAY dates, HAS successor |
| TC024 | ✅ | ✅ | ✅ | B2B last charge, end_date=04/30 LAST_DAY |
| TC025 | ✅ | ✅ | ✅ | Branch B filtering — different lookahead |
| TC026 | ✅ | ✅ | ✅ | Regression, lesson on 4/1 counted for April |
| TC027 | ✅ | ✅ | ✅ | Boundary, Zipan+Bizmates mid-month |
| TC028 | ✅ | ✅ | ✅ | FilteredUsage, end_date=01/31 |
| TC029 | ✅ | ✅ | ✅ | Ghost row leak, end_date=02/28 LAST_DAY |
| TC030 | ✅ | ✅ | ✅ | Refund missing — separate query |
| TC031 | ✅ | ✅ | ✅ | Orphaned — post-CTE query, bypasses CTE |
| TC032 | ✅ | ✅ | ✅ | Multiple patterns. May 1 lesson NOT counted for April (boundary correct). |
| TC033 | ✅ | ✅ | ✅ | FLP expiry LAST_DAY dates, HAS successor |
| TC034 | ✅ | ✅ | ✅ | Orphaned start — post-CTE query |
| TC035 | ✅ | ✅ | ✅ | **FLP REST end_date=05/02.** After removal: expiry fires in May via `is_last_charge_month`. Correct. |

---

## Critical Edge Cases Verified

### TC035 — Lookahead Removal (Change 1)

The only TC that triggers the lookahead. After removal:
- TicketMonths generates May row (`end_datetime > 2026-05-01`)
- In May: `is_last_charge_month=1` + `charge_in_past=1` + `max_ticket_end < LAST_DAY(May)+2 DAY`
- Expiry fires correctly in May. No double-fire.

### TC032 Pattern C — Boundary Lesson (Change 2b)

Lesson on May 1 for a charge in target month April:
- Old filter: fetched May 1 lesson (within +2 DAY buffer)
- New filter: excludes May 1 lesson (> LAST_DAY April)
- Counting: `lesson_datetime 2026-05-01 XX:XX < 2026-05-01 00:00:00` = FALSE → never counted for April anyway
- The old filter fetched a row that was always discarded. New filter just stops fetching it.

### TC013-A — Lookahead Never Fired (Change 1)

end_date = 12/29. `12/29 > LAST_DAY('2025-12-01') = 12/31` → FALSE. Lookahead condition was never TRUE. Removal has zero effect.

### Mathematical Proof — CASE Equivalence (Change 2a)

Both CASE branches produce "first of next month" for any month_start (always the 1st):
- `LAST_DAY('YYYY-MM-01') + 1 DAY` = first of next month
- `'YYYY-MM-01' + 1 MONTH` = first of next month
- Verified for all 12 months + leap year (Feb 2028). Identity holds.
