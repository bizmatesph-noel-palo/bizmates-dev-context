# Ghost Row Issue — Detailed Analysis & Investigation (20260619)

**Reported by:** Wu-san (Sizhe Wu)
**JIRA Ticket:** [ASC-301](https://bizmates.atlassian.net/browse/ASC-301), TBA (Evaluation Over-Count — Redmine ticket by Miyachi-san, not ASC scope)
**Investigated by:** Noel
**Date:** 2026-06-18
**Environment:** Production (Metabase queries against production database)
**Batch run analyzed:** April 2026 and May 2026

> **Note:** Report composed with AI assistance (Kiro). Investigation performed using Metabase data from production and code analysis of the CTE pipeline.

**Related:** See `REPORT_00_Initial_Investigation.md` for the initial report with affected data summary and high-level root cause.

---

## Summary of Findings

> **⚠️ Correction (2026-06-19):** The original Category A analysis ("ghost row in May") was based on an incorrect assumption that April expiry was correct. After feedback from Kuroda-san, we determined that the April row is also incorrect — charges with `end_date` in May should NOT expire in April. Category A has been re-investigated with corrected understanding.

The 9 reported charges fall into **three distinct categories**:

| Category | Charges | Issue | Status |
|----------|---------|-------|--------|
| A — Premature expiry (ASC-301) | 3001753, 3026886, 3026990, 2998736, 3028080, Zipan 12480, 12501 | Charges with `end_date` in May showing expiry in April — edge case where lookahead and next-month row both fire | ✅ Fix merged, deployed to DEV04, waiting QA |
| B — Over-count (TBA) | 3033180 (Bizmates), 12997 (Zipan) | Cross-month charges with `lessons_taken` exceeding `total` due to multiple evaluation records per ticket | ⏸️ Pending — scope TBD |
| C — Correct | 3026093 | Cross-month charge, sum of paid_price = charge paid_price exactly | ✅ No fix needed |

---

## Category A: Premature Expiry (7 charges) — FIX CONFIRMED

> **Business rule confirmed by Kuroda-san (2026-06-19):** Expiry should always appear in the month where `end_date` falls. This was the original intent from ASC-157. The fix ensures the lookahead only fires when no next-month row exists to handle expiry.

### Business Rule (from Miyachi-san — ASC-301 AC)

If a student is requesting REST and the REST date is next month, tickets remain valid in the current month. Expiry happens in the month where `end_date` falls — not the prior month.

**Expected for charge 3001753 (period: 2026-04-03 ~ 2026-05-02, 0 lessons taken):**
- **April:** remaining=15, expired=0, paid_price=0 (tickets still valid)
- **May:** carried_over=15, expired=15, paid_price=14,850 (contract ends, all expire)

### Pattern

These charges:
- Are FLP (product_id 29) or Zipan 10-lesson (product_id 17)
- Have `end_date` on day 1 or 2 of May (2026-05-01 or 2026-05-02)
- Have NO successor charge (student requested REST / no renewal)
- The CTE fires expiry in April (premature) AND May (duplicate) — both wrong

### Root Cause: Lookahead Fires Prematurely

The `is_ticket_expiry_month` lookahead condition in the Grouped CTE (line ~605):

```sql
OR (
    -- Lookahead expiry: contract ends within 2 days past this month
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

For charge 3001753 in the April row:
- `end_date (2026-05-02) > LAST_DAY('2026-04-01') (2026-04-30)` = TRUE
- `end_date (2026-05-02) <= DATE_ADD('2026-04-30', INTERVAL 2 DAY) (2026-05-02)` = TRUE
- No successor (student requested REST) → NOT EXISTS = TRUE
- **Result: `is_ticket_expiry_month = 1` in April** → premature expiry

### Why the Lookahead Exists

Added in ASC-256 (CTE refactor, May 2026) to handle terminal charges (no successor) where `end_date` falls within 2 days past month-end. It ensures expiry fires for these charges within the batch cycle where the contract ends.

> **Correction (2026-06-23):** The report originally referenced ASC-157/ASC-211 based on the code comment block above the lookahead. Git history confirms the lookahead OR condition itself was introduced in ASC-256, not in the original ASC-157/ASC-211 implementation.

The original ASC-157 spec tested charges with `end_date` mid-month (e.g., 12/29), where expiry is handled by `is_last_charge_month`. The lookahead covers the additional case where `end_date` crosses into the first days of the next month.

**The edge case (ASC-301):** FLP charges naturally produce `end_date` on day 1-2 of the next month (e.g., contract 04/03 → 05/02) because contracts start on day 1-3 and run exactly 1 month. This date pattern was not covered in the original spec. When these charges hit the lookahead, the CTE also generates a next-month row (because FLP ticket `end_datetime` extends past `end_date`). The lookahead fires in the current month while the next-month row also handles expiry — resulting in double recognition.

### Confirmed Fix

Gate the lookahead on `om.rn = om.total_rows` — only fire if this is the LAST row for the charge. If a next-month row exists, expiry will fire there via the ticket validity check instead.

```sql
OR (
    om.rn = om.total_rows  -- FIX ASC-301: Only fire on the last row.
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

**Applies to:** 4 locations (Logic Bizmates + Zipan, PreLogic Bizmates + Zipan)

### Regression Check (Kiro Simulation)

Traced all existing test cases (TC001–TC035) against the fix logic:

| Test Cases | With Fix | Impact |
|-----------|----------|--------|
| TC001–TC012 | No change | ✅ Safe — `end_date` mid-month, lookahead never evaluated |
| TC013 (ASC-157 Case 3) — B2B | No impact on current behavior | ✅ Safe — aligns with confirmed business rule |
| TC014–TC032 | No change | ✅ Safe — either `end_date` mid-month or successor exists (blocks lookahead) |
| TC033–TC034 | No change | ✅ Safe — `end_date` on last day of month, not day 1-2 of next |
| TC035 (ASC-301) — FLP | Expiry moves from April → May | ✅ This is the fix |

**No unintended regressions.**

### Other Aspects Investigated as Possible Causes

#### Command Execution Order — Is It a Possible Cause? (Verified: NOT the cause)

Used Kiro to simulate both execution scenarios by tracing the CTE logic against the production data (from Metabase) to determine whether the order produces different results:
- May-first, April-second (what Wu-san did)
- April-first, May-second (normal order)

Both produce the same result. The lookahead fires based on charge data (end_date, successor existence), not on what's in the log table from a prior run. Each batch run is independent — the CTE reads from source tables (`trn_charge`, `trn_ticket`, `trn_student_product`), not from `log_monthly_rate_calculation`.

Additionally, the final SELECT filters output to only the target month (`WHERE target_ym = DATE_FORMAT(DATE({$startDate}), '%Y%m')`), so each batch only inserts its own month's rows regardless of what the CTE generates internally.

**Production logs from Wu-san (confirming two separate runs):**

```
Log 1 (May batch):
[2026-06-18 17:33:34] production.INFO: [MONTHLY_RATE_CALCULATION] - STARTED
[2026-06-18 17:33:34] production.INFO: Date range: 2026/05/01 ~ 2026/05/31
[2026-06-18 17:37:58] production.INFO: Refund rows: Bizmates=3, Zipan=0
[2026-06-18 17:37:59] production.INFO: Orphaned charge rows: Bizmates=146, Zipan=1
[2026-06-18 17:37:59] production.INFO: Total   : 1325  rows to insert
[2026-06-18 17:37:59] production.INFO: DATA CREATION COMPLETED SUCCESSFULLY!
[2026-06-18 17:37:59] production.INFO: [MONTHLY_RATE_CALCULATION] - END

Log 2 (April batch — ran after send command completed):
[2026-06-18 19:26:13] production.INFO: [MONTHLY_RATE_CALCULATION] - STARTED
[2026-06-18 19:26:13] production.INFO: Date range: 2026/04/01 ~ 2026/04/30
[2026-06-18 19:26:40] production.INFO: Refund rows: Bizmates=2, Zipan=0
[2026-06-18 19:26:41] production.INFO: Orphaned charge rows: Bizmates=143, Zipan=2
[2026-06-18 19:26:41] production.INFO: Total   : 1223  rows to insert
[2026-06-18 19:26:41] production.INFO: DATA CREATION COMPLETED SUCCESSFULLY!
[2026-06-18 19:26:41] production.INFO: [MONTHLY_RATE_CALCULATION] - END
```

The double-count is not caused by running the batches on the same day or in reverse order. It occurs because both the lookahead (in April) and the ticket validity check (in May) fire for the same charge when both months are processed. Any time two consecutive months are processed for a charge ending on day 1-2, the same double-count would occur — regardless of when or in what order the batches run.

#### Relationship to ASC-296, ASC-297, and Orphaned Charges (Verified: NOT related)

**Is this caused by ASC-296?** No. ASC-296 addressed `charge_in_past` and the FinalResult `INTERVAL` boundary — a different code path. The lookahead condition in the Grouped CTE has existed since ASC-157/ASC-211 and was not modified by ASC-296.

**Is this caused by ASC-297?** No. ASC-297 added the orphaned charge start-month query. The affected charge (3001753) has 15 tickets — it is not orphaned. ASC-297's UNION ALL is not involved.

**Is this an orphaned charge issue?** No. The charge has tickets, is visible to the CTE, and is processed normally through the standard pipeline.

**Why did this become visible after the deployment?** The deployment included a catch-up run where both April and May were processed. In normal operations, both months would also have been processed (just on different days). The issue would have surfaced regardless — the deployment timing just made both rows appear simultaneously, making the double-count immediately obvious.

**Why was this not caught before?** This is a newly identified edge case. The original ASC-157 spec tested charges with `end_date` mid-month (12/29). FLP charges naturally produce `end_date` on day 1-2 of the next month due to their 1-month contract cycle — a date pattern that was not part of the original test matrix.

---

## Category B: Over-Count (2 charges)

### Charge 3033180 (Bizmates)

| Field | Value |
|-------|-------|
| student_id | 210462 |
| product_id | 29 (FLP — 月15回プラン) |
| start_date | 2026-04-07 |
| end_date | 2026-05-06 |
| paid_price | ¥14,107 |
| unit_price | ¥14,107 / 15 = ¥940.47 |
| tickets | 15 (confirmed — ticket IDs 70236135–70236149) |

**Log data:**

| target_ym | total | carried_over | taken | expired | remaining | paid_price |
|-----------|-------|-------------|-------|---------|-----------|-----------|
| 202604 | 15 | 0 | 14 | 0 | 1 | 13,167 |
| 202605 | 15 | 1 | 2 | 0 | 0 | 1,881 |

**Total paid_price:** 13,167 + 1,881 = 15,048
**Charge paid_price:** 14,107
**Over by:** 941 (= 1 unit price)

**Multiple evaluations per ticket (all with `result = 1`):**

| ticket_id | lesson_count | dates |
|-----------|-------------|-------|
| 70236137 | 2 | 2026-04-12 |
| 70236141 | 3 | 2026-04-19 |
| 70236148 | 2 | 2026-05-01, 2026-05-04 |
| 70236149 | 2 | 2026-05-05 |

### Charge 12997 (Zipan) — reported by Wu-san 2026-06-19

| Field | Value |
|-------|-------|
| student_id | 4282 |
| product_id | 16 (Zipan — 月5回プラン) |
| order_no | 10029118 |
| start_date | 2026-04-02 (approx, based on ticket start) |
| end_date | 2026-05-01 (approx) |
| paid_price | ¥2,750 (April) + ¥16,500 (May) per log |
| tickets | 5 |

**Log data:**

| target_ym | total | carried_over | taken | expired | remaining | paid_price |
|-----------|-------|-------------|-------|---------|-----------|-----------|
| 202604 | 5 | 0 | 1 | 0 | 4 | 2,750 |
| 202605 | 5 | 4 | 6 | 0 | 0 | 16,500 |

**Total taken:** 1 + 6 = 7. **Exceeds total (5) by 2.**

**Evaluation data (7 records total, only 5 with `result = 1`):**

| ticket_id | lesson_date | result | Notes |
|-----------|------------|--------|-------|
| 111392 | 2026-04-27 | 1 | Normal — 1 evaluation |
| 111393 | 2026-05-02 | 1 | Normal — 1 evaluation |
| 111394 | 2026-05-04 | 1 | Normal — 1 evaluation |
| 111395 | 2026-05-09 | 1 | Lesson completed |
| 111395 | 2026-05-09 | **0** | Same ticket, same datetime — duplicate with result=0 |
| 111395 | 2026-05-09 | **0** | Same ticket, same datetime — duplicate with result=0 |
| 111396 | 2026-05-11 | 1 | Normal — 1 evaluation |

Ticket 111395 has 3 evaluation records (1× result=1, 2× result=0) — all for the same lesson datetime (`2026-05-09 22:00`). The CTE counts all 3.

### Root Cause: CTE Counts All Evaluation Records Without Filtering

Investigation revealed that the CTE counts ALL evaluation records joined to a ticket, without filtering by `result` or deduplicating per ticket. Two patterns observed:

**Pattern 1 (charge 3033180 — Bizmates):** Multiple evaluations per ticket, all with `result = 1`. Possibly re-evaluations or multiple lesson types per ticket.

**Pattern 2 (charge 12997 — Zipan):** Multiple evaluations per ticket with mixed `result` values (1 and 0). The `result = 0` records appear to be failed/cancelled evaluations that should not count as lessons taken.

The CTE counts evaluations via `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` — each evaluation row joined to a ticket counts as one lesson regardless of `result` value. This produces `lessons_taken` > actual ticket count.

### Why This Happens

The `trn_evaluation` table can have multiple records per ticket. This could be:
- Duplicate entries from the lesson booking/completion system
- Re-evaluations or corrections recorded as additional rows
- A known platform behavior where one ticket can be associated with multiple evaluation events

The CTE is counting correctly based on what it sees in the data — it counts each evaluation record. The question is whether this is the intended behavior or a data integrity gap upstream.

### Student Context

Student 210462 is a high-activity student:
- 21 evaluations in April, 18 in May (across all charges, not just 3033180)
- Continuous FLP enrollment: charges from Feb through July 2026

### Assessment

**This is not a CTE logic bug.** The counting logic works as designed — it counts all evaluation records. The issue is that certain tickets have multiple evaluation records. Whether these should all be counted as lessons, or filtered by `result = 1`, or capped at one per ticket — this is the counting rule that needs to be defined by the Accounting team.

> **Note (2026-06-19, from Miyachi-san):**
> - Noel does not need to fix charge 3033180 — this is NOT confirmed as an ASC project issue.
> - This is a ticket consumption logic issue — how evaluations are counted per ticket.
> - Miyachi-san will create a Redmine ticket and verify with the Accounting team how to handle this issue.

**Status:** Pending. As per Miyachi-san, it is still not known if this should be in ASC scope. Will be verified with the Accounting team.

Until clarified, the current behavior is: `lessons_taken` = number of evaluation records on this charge's tickets within the month boundary.

---

## Category C: Correct (1 charge)

### Charge 3026093

| Field | Value |
|-------|-------|
| student_id | 290872 |
| product_id | 29 (FLP — Taiwan 15/month plan, higher price point) |
| start_date | 2026-04-10 |
| end_date | 2026-05-09 |
| paid_price | ¥22,041 |

**Log data:**

| target_ym | total | carried_over | taken | expired | remaining | paid_price |
|-----------|-------|-------------|-------|---------|-----------|-----------|
| 202604 | 15 | 0 | 8 | 0 | 7 | 11,755 |
| 202605 | 15 | 7 | 6 | 1 | 0 | 10,286 |

**Total paid_price:** 11,755 + 10,286 = 22,041
**Charge paid_price:** 22,041
**Match:** ✅ Exact

**Total lessons:** 8 + 6 = 14 taken + 1 expired = 15 = total ✅

This charge legitimately spans two months (Apr 10 – May 9). It correctly:
- Shows 8 lessons in April with 7 remaining
- Carries over 7 to May, takes 6 more, expires 1 (reaches total of 15)
- Sum of paid_price exactly matches the charge

**Acknowledged by Wu-san:** Confirmed correct. This is a Taiwan 15/month plan with a higher price point than JP plans — the higher paid_price is expected.

**No fix needed.** Excluded from scope.

---

## Summary of Actions

| Category | Action | Status |
|----------|--------|--------|
| A — ASC-301 (7 charges) | Gate lookahead on `rn = total_rows` — universal fix for all plan types | ✅ Fix merged, deployed to DEV04, waiting QA |
| B — TBA (2 charges) | Ticket consumption logic issue. CTE counts all evaluation records without filtering by `result`. Miyachi-san creating Redmine ticket for Accounting team to clarify counting rules. | ⏸️ Pending — scope TBD |
| C (1 charge) | No action — Wu-san confirmed correct (Taiwan plan, higher price) | ✅ Closed |

---

## Appendix: Queries Used

### Initial Investigation Queries (Q1–Q4)

**Q1: Bizmates monthly log data for affected charges**
```sql
SELECT
    charge_id,
    target_ym,
    total,
    number_of_carried_over_lessons,
    number_of_lessons_taken,
    number_of_expired_lessons,
    number_of_remaining_lessons,
    paid_price
FROM log_monthly_rate_calculation
WHERE charge_id IN (3001753, 3033180, 3026886, 2998736, 3028080, 3026990, 3026093)
ORDER BY charge_id, target_ym;
```

**Q2: Zipan monthly log data for affected charges**
```sql
SELECT
    charge_id,
    target_ym,
    total,
    number_of_carried_over_lessons,
    number_of_lessons_taken,
    number_of_expired_lessons,
    number_of_remaining_lessons,
    paid_price
FROM log_monthly_rate_calculation
WHERE charge_id IN (12480, 12501)
ORDER BY charge_id, target_ym;
```

**Q3: Bizmates charge info**
```sql
SELECT id, student_id, product_id, order_no, start_date, end_date, paid_price, status
FROM trn_charge
WHERE id IN (3001753, 3033180, 3026886, 2998736, 3028080, 3026990, 3026093);
```

**Q4: Zipan charge info**
```sql
SELECT id, student_id, product_id, order_no, start_date, end_date, paid_price, status
FROM trn_charge
WHERE id IN (12480, 12501);
```

### Additional Queries (Category B Investigation)

**Q5: Tickets for charge 3033180**
```sql
SELECT
    t.id AS ticket_id,
    t.student_product_id,
    t.start_datetime,
    t.end_datetime,
    t.status
FROM trn_ticket t
JOIN trn_student_product sp ON sp.id = t.student_product_id
WHERE sp.charge_id = 3033180;
```

**Q6: Evaluations per ticket (duplicates only)**
```sql
SELECT
    e.ticket_id,
    COUNT(*) AS lesson_count,
    MIN(e.lesson_date) AS first_lesson,
    MAX(e.lesson_date) AS last_lesson
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
GROUP BY e.ticket_id
HAVING COUNT(*) > 1
ORDER BY e.ticket_id;
```

**Q7: Adjacent charges for student 210462**
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
WHERE student_id = 210462
    AND product_id = 29
ORDER BY start_date;
```

**Q8: Total lessons per month for student 210462**
```sql
SELECT
    DATE_FORMAT(e.lesson_date, '%Y-%m') AS lesson_month,
    COUNT(*) AS total_lessons
FROM trn_evaluation e
WHERE e.student_id = 210462
    AND e.lesson_date >= '2026-04-01'
    AND e.lesson_date < '2026-06-01'
GROUP BY DATE_FORMAT(e.lesson_date, '%Y-%m');
```

### Verification Queries (Category B — Evaluation Count)

**Q9: All evaluations for charge 3033180's tickets with lesson dates**
```sql
SELECT
    e.ticket_id,
    e.lesson_date,
    e.lesson_datetime
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
ORDER BY e.lesson_date, e.ticket_id;
```

**Q10: Count evaluations per month for charge 3033180's tickets**
```sql
SELECT
    CASE
        WHEN e.lesson_date >= '2026-04-01' AND e.lesson_date < '2026-05-01' THEN '202604'
        WHEN e.lesson_date >= '2026-05-01' AND e.lesson_date < '2026-06-01' THEN '202605'
        ELSE 'other'
    END AS month,
    COUNT(*) AS evaluation_count
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
GROUP BY 1;
```

**Q11: Log table creation timestamps for charge 3033180**
```sql
SELECT
    charge_id,
    target_ym,
    created_at
FROM log_monthly_rate_calculation
WHERE charge_id = 3033180
ORDER BY target_ym;
```

**Q12: Evaluation created_at for charge 3033180's tickets**
```sql
SELECT
    e.ticket_id,
    e.lesson_date,
    e.lesson_datetime,
    e.created_at
FROM trn_evaluation e
WHERE e.ticket_id BETWEEN 70236135 AND 70236149
    AND e.student_id = 210462
ORDER BY e.created_at;
```

### Verification Queries (Category A — Premature Expiry)

**Q13: Refund data check for charge 3001753**
```sql
SELECT
    sp.charge_id AS true_charge_id,
    sp.student_id,
    sp.order_no,
    sp.start_date,
    sp.end_date,
    prc.refund_charge_id,
    prc.result,
    prc.refund_price
FROM trn_student_product sp
LEFT JOIN trn_prorated_refund_charge prc ON prc.refund_charge_id = sp.charge_id
WHERE sp.charge_id = 3001753;
```

**Q14: Ticket count for charge 3001753 (orphaned check)**
```sql
SELECT
    sp.charge_id,
    sp.student_id,
    sp.product_id,
    sp.start_date,
    sp.end_date,
    (SELECT COUNT(*) FROM trn_ticket t WHERE t.student_product_id = sp.id) AS ticket_count
FROM trn_student_product sp
WHERE sp.charge_id = 3001753;
```

**Q15: Log data with charge details for charge 3001753**
```sql
SELECT
    l.charge_id,
    l.target_ym,
    l.total,
    l.number_of_carried_over_lessons,
    l.number_of_lessons_taken,
    l.number_of_expired_lessons,
    l.number_of_remaining_lessons,
    l.paid_price,
    c.start_date,
    c.end_date,
    c.paid_price AS charge_paid_price
FROM log_monthly_rate_calculation l
JOIN trn_charge c ON c.id = l.charge_id
WHERE l.charge_id = 3001753
ORDER BY l.target_ym;
```

**Q16: Charge chain for student 121073 (successor check)**
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
    AND product_id = 29
ORDER BY start_date;
```

### Query Results

Saved as CSV files in this directory:
- `METABASE_Q1_Bizmates_monthly_log_charges_*.csv`
- `METABASE_Q2_Zipan_monthly_log_charges_*.csv`
- `METABASE_Q3_Bizmates_charge_info_*.csv`
- `METABASE_Q4_Zipan_charge_info_*.csv`
- `METABASE_Q5_Bizmates_charge_3033180_ticket_info_*.csv`
- `METABASE_Q5_Bizmates_charge_3033180_evaluation_*.csv`
- `METABASE_Q7_Bizmates_sid_210462_charge_*.csv`
- `METABASE_Q8_Bizmates_sid_210462_evaluation_*.csv`
- `METABASE_Q9_Bizmates_charge_3033180_evaluation_*.csv`
- `METABASE_Q10_Bizmates_sid_210462_evaluation_per_month_*.csv`
- `METABASE_Q11_Bizmates_monthly_log_*.csv`
- `METABASE_Q12_Bizmates_eval_vs_log_data_*.csv`
- `METABASE_Q13_Bizmates_charge_3001753_*.csv`
- `METABASE_Q14_Bizmates_orphaned_charge_*.csv`
- `METABASE_Q15_Bizmates_charge_3001753_CTE_Flag_*.csv`
- `METABASE_Q16_Bizmates_sid_121073_charge_*.csv`
