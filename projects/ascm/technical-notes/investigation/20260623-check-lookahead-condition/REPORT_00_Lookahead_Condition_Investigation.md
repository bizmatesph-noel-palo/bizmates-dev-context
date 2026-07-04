# Lookahead Condition — Analysis Report (20260623)

**Reported by:** Kuroda-san (requested investigation)
**JIRA Ticket:** [ASC-301](https://bizmates.atlassian.net/browse/ASC-301)
**Investigated by:** Noel
**Date:** 2026-06-23
**Environment:** Production (Metabase queries against both Bizmates and Zipan databases)

---

## Background

During the ASC-301 fix review, Kuroda-san asked:

> For charges with `end_date` on day 1–2 of the next month, does the next-month row always exist in the CTE to handle expiry on its own? Or is there a case where no next-month row is generated and the lookahead is the only path to expiry?

The current ASC-301 fix gates the lookahead on `rn = total_rows` (keep it as a fallback). If the lookahead is never the only path, it can be removed entirely for a cleaner fix.

---

## Origin of the Lookahead

### Timeline Context

The team adopted Kiro on **2026-05-20 (Wednesday)** with a hard deployment deadline of **2026-05-29 (Friday)** — 8 working days.

The weeks prior were defined by a relentless fix-and-bug cycle: each CTE fix introduced new edge cases, DEV04 deployment and batch execution for validation was slow, and there were no unit tests to benchmark correctness. After ASC-246, when the fixes were still not enough and the cycle continued, the team decided that AI-assisted checking, debugging, and automated help was necessary. The team needed a tool that could analyze the code, identify possible regressions, and validate output — fast.

Creating PHPUnit tests was not feasible:
- The CTE queries are highly complex (multi-level recursive with dozens of boundary conditions)
- Translating SQL CTE behavior into PHP unit test mocks would be extremely difficult even without time pressure
- Processing JIRA ticket data into useful test assertions that truly cover the needed scenarios would take longer than the available window

The JIRA tickets had defined ACs with sample/expected output formatted as CSV rows. To make these usable as automated benchmarks, Noel obtained a copy of all existing test cases (see ASC-247), and together with the team processed the tickets and ACs into a structured format. Noel had to study and develop a workflow: prompting Kiro to define what it needs as test case input, generating that as a prompt for Google Gemini, then feeding Gemini the ticket/AC data so it could produce structured `.md` test case files in the exact format Kiro requires for simulation — checking correctness, cross-checking against DEV04 CSV output, and detecting regressions after each code change.

This became the **three-point verification method** (see `Documentation/09_Verification_Methodology.md`): Code Logic ↔ Test Cases ↔ CSV Output. Test case simulation via Kiro replaced what would normally be unit tests — providing fast feedback on whether code changes produce correct results.

This is the environment in which ASC-256 was developed — Kiro analyzing code for edge cases, suggesting preventive fixes, with test case simulation as the primary validation method. The approach worked well for catching regressions, but could not catch issues in code paths that no test case exercised.

### How the Lookahead Was Introduced

Initially, the lookahead OR condition was thought to be from ASC-157/ASC-211 since the code comment block `-- FIX ASC-157/ASC-211 (lookahead expiry):` is directly above it. The lookahead falls under that same comment block because it addresses the same class of issue — ensuring terminal contracts fire expiry at the right time. However, upon examining git history, the lookahead OR condition itself was introduced in the ASC-256 refactor.

**Introduced in:** ASC-256 (commit `ad8e1022`, 2026-05-25 Monday) — 3 work days after Kiro adoption, 4 work days before deadline.

ASC-256 was a large CTE refactor that introduced the "rolling ledger execution model." The lookahead expiry condition was added to detect terminal contracts ending within 2 days past month-end and fire expiry in the current month, treating it as the "last chance" to process that charge.

The "2-day horizon" concept was already established in the ASC-261 fix comparison discussion. ASC-256 extended the same principle to expiry logic as a preventive measure for a theoretical scenario — a charge where `ticket.end_datetime` ends exactly at midnight on the 1st of the next month, meaning no next-month CTE row would be generated. This scenario has **never been observed in production data** (verified: empty results for both Bizmates and Zipan).

Given the timeline (Kiro adopted 3 work days prior, deadline 4 work days away, no unit tests, team relying on Kiro for edge case analysis), this is consistent with a Kiro-suggested theoretical edge case fix. The exact origin cannot be confirmed from git history alone — commit messages do not carry conversation logs — but the pattern matches the approach used during that period.

**Code:**
```sql
OR (
    om.end_date > LAST_DAY(om.month_start)
    AND om.end_date <= DATE_ADD(LAST_DAY(om.month_start), INTERVAL 2 DAY)
    AND NOT EXISTS (same-order successor)
)
```

---

## Was the Lookahead a Valid Addition?

Given the constraints at the time (ASC-256, 2026-05-25):

**Why it seemed valid:**
- The rolling ledger execution model conceptually required handling terminal contracts whose `end_date` crosses into the next month
- The "2-day horizon" pattern was already established in ASC-261
- All existing test cases passed with the lookahead in place
- The team had no unit tests and relied on Kiro's edge case analysis as a substitute
- Under extreme time pressure (4 work days to deadline), a preventive measure for a theoretical scenario appeared prudent

**Verdict:** The addition was understandable given the time pressure and tooling limitations. However, it was never validated against real data — no test case exercised the path, and no production scenario required it. Whether this made it "valid" depends on perspective: as a defensive measure under deadline pressure, it was a reasonable judgment call. As a correctness decision, it introduced a latent defect. The sections below detail the evidence.

---

## Why the Lookahead Was Never Questioned

### All Test Cases (TC001–TC034) — Lookahead Analysis

None of the existing test cases (prior to TC035) were designed to test or could have caught the lookahead causing a double-fire issue:

| TC | Type | end_date pattern | Has successor? | Lookahead fires? | Why not problematic |
|---|---|---|:---:|:---:|---|
| TC001 (ASC-149) | B2B 8-lesson | 2026-03-01 | Yes (same order) | No | Successor blocks |
| TC001-A (ASC-149) | B2B 8-lesson | 12/29 | Yes | No | end_date mid-month |
| TC002 (ASC-151) | FLP → B2B | 2026-02-24 | Yes | No | Successor blocks |
| TC003 (ASC-151) | Zipan | mid-month | Yes | No | end_date mid-month |
| TC003-A (ASC-151) | Zipan | mid-month | Yes | No | end_date mid-month |
| TC004 (ASC-151) | FLP refund | 2026-01-31 | Yes | No | last day + successor |
| TC005 (ASC-151) | FLP refund | 2026-01-31 | Yes | No | last day + successor |
| TC006 (ASC-151) | FLP cooling-off | 2026-01-31 | No | No | last day → `is_last_charge_month` |
| TC007 (ASC-151) | FLP cooling-off | 2026-01-31 | No | No | Same as TC006 |
| TC008 (ASC-151) | FLP cooling-off | 2026-02-27 | No | No | end_date mid-month |
| TC009 (ASC-151) | FLP → B2B | 2026-02-24 | Yes | No | Successor blocks |
| TC010 (ASC-151) | FLP → B2B | 2026-02-28 | Yes | No | Successor blocks |
| TC011 (ASC-151) | FLP → B2B | 2026-02-28 | Yes | No | Successor blocks |
| TC012 (ASC-157) | B2B 8-lesson | 60-day expiry | Yes | No | Successor blocks |
| TC013 (ASC-157)* | B2B REST | 2026-03-01 | No | Yes | [See detailed analysis below](#tc013-and-tc013-a--both-valid-neither-prevents-the-lookahead)* |
| TC013-A (ASC-157)* | B2B REST | 2025-12-29 | No | No | [See detailed analysis below](#tc013-and-tc013-a--both-valid-neither-prevents-the-lookahead)* |
| TC014–015 (ASC-211) | B2B order transition | 2026-01-10 | Yes (new order) | No | end_date mid-month |
| TC016 (ASC-205) | Zipan carry-over | mid-month | Yes | No | end_date mid-month |
| TC017 (ASC-203) | Summary | N/A | N/A | No | Not expiry-related |
| TC018 (ASC-244) | Refund identity | N/A | N/A | No | Not expiry-related |
| TC019 (ASC-234) | B2B last charge | mid-month | No | No | `is_last_charge_month` handles |
| TC020 (ASC-236) | Refund | N/A | N/A | No | Not expiry-related |
| TC021 (ASC-232) | Zipan ghost | mid-month | Yes | No | end_date mid-month |
| TC022 (ASC-247) | Formula matrix | various | Yes | No | All have successors |
| TC023 (ASC-254) | B2B premature | mid-month | Yes | No | Successor blocks |
| TC024 (ASC-258) | B2B last charge | mid-month | No | No | `is_last_charge_in_order` |
| TC025 (ASC-260) | Branch B lookahead | mid-month | Yes | No | Different lookahead (Branch B) |
| TC026 (ASC-261) | Regression | mid-month | Yes | No | end_date mid-month |
| TC027 (ASC-264) | Boundary | various | Various | No | end_date mid-month |
| TC028 (ASC-266) | FilteredUsage | mid-month | Yes | No | end_date mid-month |
| TC029 (ASC-267) | Ghost row leak | mid-month | No | No | Expelled by ASC-267 rule |
| TC030 (ASC-269) | Refund missing | N/A | N/A | No | Not expiry-related |
| TC031 (ASC-280) | Orphaned | end-month | N/A | No | Orphaned query handles |
| TC032 (ASC-283) | Multiple patterns | 05/01, 05/02 | Yes | No | Successor blocks |
| TC033 (ASC-296) | FLP expiry | 04/30, 05/31 | Yes | No | last day of month |
| TC034 (ASC-297) | Orphaned start | 06/09 | N/A | No | Orphaned query handles |
| **TC035 (ASC-301)** | **FLP REST** | **2026-05-02** | **No** | **Yes** | **The issue — first B2C detection, no `is_last_charge_in_order` backup** |

### TC013 and TC013-A — Both Valid, Neither Prevents the Lookahead*

Both TC013 and TC013-A are recognized test cases for the same scenario (ASC-157 Case 3: B2B REST expiry). They use different dates:

| TC | end_date | Origin | Lookahead fires? | Expiry handled by |
|---|---|---|:---:|---|
| TC013 | 2026-03-01 (day 1 next month) | ASC-247 rewrite | Yes | `is_last_charge_in_order` (March) + lookahead (February) |
| TC013-A | 2025-12-29 (within month) | Original ASC-157 spec | No | `is_last_charge_month` (December) |

TC013-A uses the original ASC-157 dates where `end_date = 12/29` falls within December — the lookahead is never evaluated. TC013 was rewritten in ASC-247 with `end_date = 03/01`, which placed it in the lookahead window. Both are valid representations of the B2B REST scenario with different date boundaries.

**Why neither TC caught the issue:**
- TC013 triggers the lookahead in February, but `is_last_charge_in_order` also fires in March — from a single-month perspective, expiry appears in the correct month
- The TC only validates one month's output at a time — it never checks that expiry fires ONLY once across both months
- TC013-A never enters the lookahead path at all
- Neither TC was designed to test the lookahead — both test "B2B REST expiry"

The Zipan B2B double-count (charges 12480, 12501 matching TC013's pattern) was only discovered when we specifically queried production data during this investigation. This confirms that even with both TCs in the suite, the lookahead double-fire remained invisible until ASC-301 was reported for a B2C/FLP charge where no parallel trigger masked the problem.

### Key Observations

**The lookahead causes double-fire for ALL contract types** — not just FLP/B2C:

| Contract Type | Lookahead fires? | Also has backup trigger? | Double-count visible? | Evidence |
|---|:---:|:---:|:---:|---|
| B2B (has `order_no`) | Yes (TC013) | Yes — `is_last_charge_in_order` | Yes — confirmed in Zipan (charges 12480, 12501) | Zipan Q1 data |
| B2C / FLP (no `order_no`) | Yes (TC035) | No | Yes — confirmed (ASC-301: charge 3001753) | Production |
| B2B2C (no `order_no`) | Possible | No | Not yet observed | Zipan has 993 B2B2C charges |

- **TC013** triggers the lookahead in February (end_date = 03/01), and `is_last_charge_in_order` fires in March. The Zipan Q1 query confirmed that B2B charges (12480, 12501) with this pattern show `paid_price > 0` in BOTH months — the double-fire produces double revenue even for B2B.
- **TC013-A** does NOT trigger the lookahead (end_date = 12/29, within the month) — expiry fires via `is_last_charge_month` only.
- **TC035** (ASC-301) is the first case where the double-fire was **reported and detected** — because FLP/B2C charges have no `is_last_charge_in_order` backup, so nothing "normalizes" the result when both months are examined independently.

The original assumption that `is_last_charge_in_order` provides a "safety net" for B2B was incorrect — both triggers fire, both insert rows, and both months show revenue. The difference is operational: for B2B, this went unnoticed because the same `order_no` grouping may have obscured it in downstream Freee journals. For FLP/B2C, Wu-san detected it because `paid_price` across April + May exceeded the charge total.

### Contract Type Distribution (Zipan Monthly Plans)

Verified via Metabase:

| Contract Type | Identifier | Count |
|---|---|---:|
| B2C (PayPal) | `order_no = NULL` | 768 |
| B2B | Has `order_no` | 11,484 |
| B2B2C | `order_no = NULL` | 993 |

All three contract types exist in Zipan. The lookahead issue affects any charge where `end_date` falls on day 1-2 of the next month with no successor — regardless of contract type.

### FLP is Exclusively B2C

Verified via Metabase: all 2,587 FLP (product_id 29) charges in Bizmates production have `order_no = NULL`.

Per FLP-352, B2B students can purchase FLP as a B2E advance application — an individual purchase outside their B2B order. This is consistent with FLP charges always having `order_no = NULL`.

Because FLP charges have no `order_no`:
- `is_last_charge_in_order` can never fire for FLP (requires `order_no IS NOT NULL`)
- When the lookahead fires for FLP, there is no alternative trigger that masks the issue
- This is why TC035 (FLP, no `order_no`) made the problem immediately visible

Student 121073 (ASC-301) is a pure B2C student — all charges have `order_no = NULL`. Not a B2B→FLP advance application scenario.

### Why TC035 Was the First Detection

TC035 is the **first and only** test case that combines:
1. FLP charge (1-month ticket validity)
2. `end_date` on day 1-2 of next month
3. No successor (student requested REST)
4. No `order_no` (no `is_last_charge_in_order` backup)

While TC013 also triggers the lookahead, the double-count for B2B was not noticed because:
- B2B charges are managed through orders with `is_last_charge_in_order` as a parallel trigger
- The TC013 test case validates that expiry fires in the correct month (February/March) — it does not validate that expiry fires ONLY once across both months
- The Zipan B2B double-count (charges 12480, 12501) was only discovered when we specifically queried for it during this investigation

### How It Became a Problem

The lookahead causes the CTE to generate expiry in BOTH the current month (via lookahead) and the next month (via ticket validity check or `is_last_charge_in_order`). When both months are processed as separate batch runs, both rows are inserted — resulting in double revenue recognition.

This affects all contract types where a charge has `end_date` on day 1-2 of the next month with no successor. The issue was always present since ASC-256, but:
- For B2B: went unnoticed because `is_last_charge_in_order` also fires (both triggers produce the same expiry, just in different months)
- For B2C/FLP: became visible when Wu-san detected `paid_price` sum exceeding charge total (ASC-301)

This specific combination was not part of the test matrix until ASC-301 was reported in production.

### Assessment

The lookahead was **faulty from the start**:
- The scenario it guards against (ticket ending exactly at midnight on day 1) has never existed in production
- It actively causes double revenue recognition for ALL contract types (B2B, B2C, B2B2C) when `end_date` falls on day 1-2 of the next month with no successor
- It went undetected because no test case intentionally exercised the lookahead path
- TC013's accidental triggering (via ASC-247 date rewrite) was masked by `is_last_charge_in_order` firing in the same month

It passed all test cases because none of them tested the specific combination it fires on. The structured test case files that served as the primary validation tool at the time (TC001–TC022 at ASC-256's commit date) did not include FLP + no successor + day 1-2 end_date scenarios — that combination only entered the test matrix when ASC-301 was reported in production (TC035).

---

## Key Question

The CTE generates a next-month row when:
```sql
DATE_ADD(month_start, INTERVAL 1 MONTH) < DATE(end_datetime)
```

If `ticket.end_datetime` extends past the 1st of next month, a next-month row exists and can handle expiry via the ticket validity check. The lookahead would only be needed if NO next-month row is generated — meaning `ticket.end_datetime <= 1st of next month (midnight)`.

**Note:** This theoretical scenario has not been observed in actual data. The lookahead follows the same "2-day horizon" pattern used in ASC-261 (lesson counting boundary), which was a design approach adopted during the ASC refactoring sessions to cover potential edge cases preemptively.

---

## Results

| Database | Result |
|----------|--------|
| Bizmates | **Empty** — no matching charges |
| Zipan | **Empty** — no matching charges |

For every charge with `end_date` on day 1–2 of the next month in production:
- `max(ticket.end_datetime)` always extends past the 1st
- The CTE always generates a next-month row
- The next-month row handles expiry via the ticket validity check or `is_last_charge_in_order`
- **The lookahead is never the only path to expiry**

The theoretical scenario (ticket ending exactly at midnight on the 1st) does not exist in production data and has no real-world occurrence.

---

## Recommendation

The investigation confirms:
- The scenario the lookahead guards against (ticket ending exactly at midnight on day 1) has **never existed** in production (empty results for both Bizmates and Zipan)
- The lookahead actively causes double revenue recognition for all contract types
- The CTE always generates a next-month row for charges with `end_date` on day 1-2 — expiry is always handled there

**Options:**

| | Option A: Keep gate (`rn = total_rows`) | Option B: Remove lookahead entirely |
|---|---|---|
| **Approach** | Lookahead remains in code but only fires on last row | Remove the OR block completely |
| **Pros** | Conservative; preserves fallback for a theoretical scenario | Simpler code; removes dead logic that has only caused harm |
| **Cons** | Retains code for a scenario that doesn't exist; adds complexity | If the theoretical scenario ever occurs in the future, no safety net |
| **Risk** | Low — gate prevents the double-fire | Low — scenario has never occurred in production |

**Based on the evidence, Option B is the stronger choice** — the lookahead serves no purpose for any real production scenario and its presence adds complexity to an already complex CTE. However, Option A is already deployed and QA-passed, so the decision comes down to whether to do additional work for a cleaner codebase.

Awaiting Kuroda-san's decision.

---

## Appendix: Queries Used

### Primary Query — Does the lookahead-only scenario exist?

Checked both Bizmates and Zipan for charges where `end_date` is day 1 or 2 of a month AND `max(ticket.end_datetime)` does NOT extend past the 1st of that month (meaning no next-month row would be generated).

Query saved as: `query_check_lookahead_needed.sql` in this directory.

```sql
SELECT
    sp.charge_id,
    sp.student_id,
    sp.product_id,
    sp.start_date,
    sp.end_date,
    MAX(t.end_datetime) AS max_ticket_end,
    DATE_FORMAT(sp.end_date, '%Y-%m-01') AS end_date_month_start
FROM trn_student_product sp
JOIN trn_ticket t ON t.student_product_id = sp.id
JOIN mst_product p ON p.product_id = sp.product_id AND p.lesson_type = 2
WHERE DAY(sp.end_date) IN (1, 2)
    AND sp.status IN (0, 1)
    AND t.ticket_type = 3
    AND sp.product_id NOT IN (61, 62, 63, 64)
GROUP BY sp.charge_id, sp.student_id, sp.product_id, sp.start_date, sp.end_date
HAVING MAX(t.end_datetime) <= DATE_FORMAT(sp.end_date, '%Y-%m-01')
LIMIT 20;
```

**Result:** Empty for both Bizmates and Zipan.

### Additional Query — B2B double-count verification

Checked if any B2B charges with `end_date` day 1-2 and no successor have rows in both months (to verify whether the lookahead causes double-count for B2B).

```sql
SELECT
    l.charge_id,
    l.target_ym,
    l.number_of_expired_lessons,
    l.number_of_remaining_lessons,
    l.paid_price,
    c.order_no,
    c.end_date
FROM log_monthly_rate_calculation l
JOIN trn_charge c ON c.id = l.charge_id
WHERE c.order_no IS NOT NULL
    AND DAY(c.end_date) IN (1, 2)
    AND c.product_id IN (16,17,18,19,20,21,22,23,27,28,29)
    AND NOT EXISTS (
        SELECT 1 FROM trn_student_product sp2
        WHERE sp2.student_id = l.student_id
            AND sp2.product_id = c.product_id
            AND sp2.start_date > c.end_date
    )
ORDER BY l.charge_id, l.target_ym;
```

**Result:** Bizmates — empty. Zipan — results found (charges 12480, 12501 show double revenue; others show paid_price=0 in second month).

### Additional Query — Student 121073 full charge history

Verified whether student 121073 (ASC-301) has B2B history.

```sql
SELECT
    id AS charge_id,
    student_id,
    product_id,
    order_no,
    start_date,
    end_date,
    paid_price,
    status
FROM trn_charge
WHERE student_id = 121073
ORDER BY start_date;
```

**Result:** All charges have `order_no = NULL`. Student 121073 is a pure B2C student (daily plan → FLP) with no B2B history.

### Query Results

Saved as CSV files in this directory:
- `METABASE_Q1_Zipan_monthly_log_B2B_double_count_*.csv`
- `METABASE_Q2_Bizmates_sid_121073_B2B_FLP_*.csv`

---

## Cross-Reference

- Investigation report: `20260618_data_adjustments_2/REPORT_01_Detailed_Analysis.md`
- KB article: `Knowledge_Base/20_Lookahead_Premature_Expiry.md`
- Test case: `Testcases/ASC-XXX_TestCase035.md`
