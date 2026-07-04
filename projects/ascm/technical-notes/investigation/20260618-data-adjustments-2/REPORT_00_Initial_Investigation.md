# Ghost Row Issue — Initial Investigation Report (20260618)

**Reported by:** Wu-san (Sizhe Wu)
**JIRA Ticket:** [ASC-301](https://bizmates.atlassian.net/browse/ASC-301), TBA (Evaluation Over-Count — Redmine ticket by Miyachi-san, not ASC scope)
**Investigated by:** Noel
**Date:** 2026-06-18
**Environment:** Production (Metabase queries against production database)
**Batch run analyzed:** April 2026 (`startDate = 2026-04-01`, `endDate = 2026-04-30`) and May 2026 (`startDate = 2026-05-01`, `endDate = 2026-05-31`)

> **Note:** Report composed with AI assistance (Kiro) for structure and formatting. Root cause analysis and data verification were performed via Metabase against the production database.

> **⚠️ Correction (2026-06-19):** The original version of this report incorrectly assumed that the April expiry data was correct and identified the May row as a "ghost." After review (feedback from Kuroda-san), we determined that the April row is also incorrect — charges with `end_date` in May should NOT be expiring in April. The root cause analysis and proposed fix from the original report are invalid. See the detailed analysis (`Notes_Ghost_Row_02_Detailed_Analysis.md`) for the corrected investigation.

**Related:** See `REPORT_01_Detailed_Analysis.md` for corrected code-level investigation.

---

## Executive Summary

Following the June 18 deployment (ASC-276 through ASC-300), Wu-san reported charges where the sum of `paid_price` across April (202604) and May (202605) exceeds the charge's original `paid_price`. This indicates revenue is being double-recognized.

**Observed data (production):** Charges with `end_date` in early May (May 1st, 2nd) are showing expiry in BOTH April AND May. The sum of paid_price across both months exceeds the charge's total.

| Tenant | Affected Charges | Pattern |
|--------|-----------------|---------|
| Bizmates | 7 charges | FLP (product_id 29), order_no NULL, end_date in early May |
| Zipan | 2 charges | 10-lesson plan (product_id 17), B2B, end_date 2026-05-01 |

**Severity:** High — revenue over-recognized by up to 2x for affected charges.

---

## Affected Data

### Bizmates (7 charges)

| charge_id | student_id | product_id | start_date | end_date | charge paid_price | Apr paid_price | May paid_price | Total (over) |
|-----------|-----------|-----------|-----------|----------|-------------------|---------------|---------------|--------------|
| 3001753 | 121073 | 29 | 2026-04-03 | 2026-05-02 | 14,850 | 14,850 | 14,850 | 29,700 |
| 3026886 | 233228 | 29 | 2026-04-02 | 2026-05-01 | 14,850 | 14,850 | 14,850 | 29,700 |
| 3026990 | 289315 | 29 | 2026-04-02 | 2026-05-01 | 14,850 | 14,850 | 14,850 | 29,700 |
| 2998736 | 275247 | 29 | 2026-04-02 | 2026-05-01 | 14,107 | 14,107 | 10,345 | 24,452 |
| 3028080 | 286489 | 29 | 2026-04-03 | 2026-05-02 | 14,850 | 14,850 | 9,900 | 24,750 |
| 3033180 | 210462 | 29 | 2026-04-07 | 2026-05-06 | 14,107 | 13,167 | 1,881 | 15,048 |
| 3026093 | 290872 | 29 | 2026-04-10 | 2026-05-09 | 22,041 | 11,755 | 10,286 | 22,041 |

### Zipan (2 charges)

| charge_id | student_id | product_id | order_no | start_date | end_date | charge paid_price | Apr paid_price | May paid_price | Total (over) |
|-----------|-----------|-----------|----------|-----------|----------|-------------------|---------------|---------------|--------------|
| 12480 | 4148 | 17 | 10027005 | 2026-04-02 | 2026-05-01 | 23,100 | 23,100 | 23,100 | 46,200 |
| 12501 | 4155 | 17 | 10027005 | 2026-04-02 | 2026-05-01 | 23,100 | 23,100 | 23,100 | 46,200 |

---

## Observed Data (from log_monthly_rate_calculation)

**Example — charge 3001753 (period: 2026-04-03 ~ 2026-05-02, 0 lessons taken):**

| target_ym | total | carried_over | taken | expired | remaining | paid_price |
|-----------|-------|-------------|-------|---------|-----------|-----------|
| 202604 | 15 | 0 | 0 | 15 | 0 | 14,850 |
| 202605 | 15 | 15 | 0 | 15 | 0 | 14,850 |

Both rows show full expiry. Total paid_price = ¥29,700 — double the charge's ¥14,850.

---

## ~~Root Cause (Original — INCORRECT)~~

~~The original analysis assumed April was correct and May was a ghost row. This was wrong.~~

## Corrected Understanding (2026-06-19)

For charge 3001753 (period: 2026-04-03 ~ 2026-05-02):
- **April:** The charge is still active (tickets usable until May 2nd). April should show `remaining=15, expired=0, paid_price=0`.
- **May:** The charge ends May 2nd. This is where expiry should happen: `expired=15, paid_price=14,850`.

The CTE is incorrectly triggering expiry in April for charges whose `end_date` is in May. The real question is: **why is the expiry condition firing in April when `end_date` has not been reached?**

Root cause investigation in progress — see detailed analysis.

---

## Appendix: DB Evidence

### Queries Used

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

### Query Results

Saved as CSV files in this directory:
- `METABASE_Q1_Bizmates_monthly_log_charges_*.csv`
- `METABASE_Q2_Zipan_monthly_log_charges_*.csv`
- `METABASE_Q3_Bizmates_charge_info_*.csv`
- `METABASE_Q4_Zipan_charge_info_*.csv`
