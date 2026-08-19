# ASC-301 Solution Comparison — Three Approaches (20260709)

**JIRA Ticket:** [ASC-301](https://bizmates.atlassian.net/browse/ASC-301)
**Prepared by:** Noel (Kiro-assisted)
**Date:** 2026-07-09
**Context:** Kuroda-san requested a change in approach after QA passed the original fix.

---

## Background

ASC-301 addresses premature expiry caused by the 2-day lookahead condition in the Grouped CTE. Three approaches are now on the table:

| Option | Name | Origin |
|--------|------|--------|
| A | CTE Gate (`rn = total_rows`) | Original ASC-301 fix — QA passed, pending prod deploy |
| B | Post-Processing Correction | Kuroda-san's request (2026-07-09) |
| C | Lookahead Removal (clean-up) | Investigation conclusion (REPORT_00, 2026-06-23) |

---

## Option A — CTE Gate (`rn = total_rows`)

**What it does:** Adds a guard to the lookahead OR block so it only fires on the last CTE row for a charge. If a next-month row exists, expiry defers to that row instead.

**Code change:**
```sql
OR (
    om.rn = om.total_rows  -- ASC-301 gate
    AND om.end_date > LAST_DAY(om.month_start)
    AND om.end_date <= DATE_ADD(LAST_DAY(om.month_start), INTERVAL 2 DAY)
    AND NOT EXISTS (same-order successor)
)
```

**Status:** Merged to ASC-master, deployed to DEV04, QA passed. Awaiting production deployment decision.

**Locations:** 4 (Bizmates/Zipan × Final/Pre)

| Strengths | Weaknesses |
|-----------|------------|
| Already QA-tested and validated | Adds complexity to an already 700-line CTE |
| Covers all contract types automatically | Relies on TicketMonths always generating correct row count |
| Single mechanism — no secondary logic | If FilteredUsage or TicketMonths changes in the future, gate may silently break |
| Minimal code diff (1 line per location) | Hard to debug — tracing `rn` vs `total_rows` through recursive CTEs |
| | Retains the lookahead block (dead code that has only ever caused harm) |
| | Makes the CTE responsible for self-correction of its own defect |

---

## Option B — Post-Processing Correction

**What it does:** Lets the CTE run unmodified. After rows are inserted into `log_monthly_rate_calculation`, a query detects wrong rows and corrects them via UPDATE.

**Detection (from Kuroda-san):**
- Product: 15 lessons/month
- `trn_charge.end_date` is in the next month (charge period crosses boundary)
- `number_of_remaining_lessons = 0` AND `number_of_expired_lessons != 0`

**Correction:**
- `number_of_expired_lessons` → 0
- `number_of_remaining_lessons` → (what was expired)
- `paid_price` → recalculated for `taken` only

**Locations:** 2 (Final + Pre, new method + call in `execute()`)

| Strengths | Weaknesses |
|-----------|------------|
| Main CTE query stays untouched — zero risk to existing logic | The lookahead still fires and inserts wrong data (then gets corrected) |
| Surgically targets only the affected pattern (FLP cross-month) | Two writes per affected row (INSERT wrong → UPDATE correct) |
| Easy to debug — logged per-row, visible in DB | Must be maintained alongside CTE changes |
| Easy to unit test independently | If detection criteria drift from the actual bug pattern, rows escape correction |
| Safe to disable (comment out call) without breaking anything | |
| Follows "fix the data" philosophy — CTE is treated as a black box | |

---

## Option C — Lookahead Removal

**What it does:** Removes the entire lookahead OR block from the Grouped CTE. The scenario it guards (ticket ending exactly at midnight on day 1) has never existed in production data (confirmed via Metabase queries — REPORT_00).

**Code change:** Delete the OR block entirely (4 locations).

**Locations:** 4 (Bizmates/Zipan × Final/Pre)

| Strengths | Weaknesses |
|-----------|------------|
| Eliminates root cause — the condition that generates wrong data is gone | Removes a "safety net" for a theoretical scenario (even though it's never occurred) |
| Simplifies the CTE — fewer branches to reason about | Requires re-QA since it's different from the tested Option A |
| No residual wrong data at any point (nothing to correct) | If the theoretical scenario ever materializes in the future, no fallback |
| Test case simulation: 35/35 PASS (REPORT_02) | Additional code review + testing cycle needed |
| No performance penalty (simpler query) | |

---

## Comparison Matrix

| Criteria | A (CTE Gate) | B (Post-Processing) | C (Removal) |
|----------|:---:|:---:|:---:|
| **Root cause eliminated** | No — lookahead still fires, gate suppresses it | No — wrong data generated then corrected | Yes — condition removed |
| **CTE complexity** | Increased (+1 condition) | Unchanged | Decreased (−1 OR block) |
| **Blast radius risk** | Medium — gate interacts with window functions | Low — isolated to post-fix | Low — deletion only |
| **Regression risk** | Low (QA passed) | Low (CTE unchanged) | Low (35/35 pass in simulation) |
| **Covers all plan types** | Yes (any `total_rows`) | FLP only (by design) | Yes (block is gone for all) |
| **Debuggability** | Hard (CTE trace) | Easy (logged, visible in DB) | N/A (problem doesn't occur) |
| **QA status** | ✅ QA passed | ❌ Not yet tested | ❌ Not yet tested (simulation passed) |
| **Future maintenance** | Must verify gate holds after any CTE refactor | Must verify detection criteria after changes | None needed |
| **Auditability** | Silent — row never has wrong value | Logged — before/after visible | Silent — problem never occurs |
| **Performance** | Neutral | +1 SELECT + N UPDATEs (negligible, ~5-10 rows) | Slightly better (simpler query) |

---

## Interaction: Can Options Be Combined?

| Combination | Viability | Assessment |
|-------------|-----------|------------|
| A + B | Redundant | Gate prevents wrong data → post-fix finds 0 rows. Pointless. |
| A + C | Contradictory | Can't gate something that's been removed. |
| **B + C** | **Complementary** | Removal eliminates root cause; post-fix is safety net. Belt + suspenders. |
| B alone | Works but incomplete | Wrong data still generated (then fixed). Lookahead remains as dead code. |
| C alone | Works and complete | Cleanest solution but lacks Kuroda-san's "post-processing" requirement. |

---

## Recommendation

**Option B + C combined** aligns with both:
- Kuroda-san's direction ("fix wrong data after the process saves it" — don't gate the CTE)
- Investigation conclusion ("remove the lookahead — it's dead code that only causes harm")

**Flow:**
1. Remove the lookahead OR block (eliminates the source of wrong data)
2. Add post-processing after INSERT (catches any remaining edge cases as safety net)
3. The post-fix should find 0 rows in practice (since the removal prevents the wrong data)
4. If a new edge case is discovered in the future, the post-fix catches it without CTE surgery

**This replaces Option A** (the CTE gate) — which should NOT be deployed to production since the approach has been changed.

---

## Note on Option A Status

Option A (CTE gate) was deployed to DEV04 and QA passed but has **not been released to production**. Switching to B+C does not require a production revert — only a branch-level change before the next deploy.

---

## Verification Path

- **DEV:** All existing TCs (1–35) must pass after implementation.
- **Production release:** Requires QA pass (standard release gate).

---

## Cross-Reference

- Investigation (lookahead never needed): `REPORT_00_Lookahead_Condition_Investigation.md`
- Clean-up analysis + simulation: `REPORT_01_Kuroda_Questions_Analysis.md`
- Full TC simulation scorecard: `REPORT_02_Full_TC_Simulation_Scorecard.md`
- Test case: `testcases/TC035.md`
- Knowledge base: `knowledge-base/20-lookahead-premature-expiry.md`
