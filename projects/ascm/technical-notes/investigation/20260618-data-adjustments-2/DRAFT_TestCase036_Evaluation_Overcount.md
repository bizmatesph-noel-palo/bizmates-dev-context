# [ASC-302]
[Bizmates] FLP Charge Over-Count — Multiple Evaluations Per Ticket Inflates lessons_taken

[Story]
When a ticket has multiple evaluation records in `trn_evaluation`, the monthly rate CTE counts each evaluation as a separate lesson. This causes `lessons_taken` across months to exceed `total` (lesson_volume), resulting in `paid_price` exceeding the charge's original amount.

The CTE counts evaluations correctly based on the data it sees. The question is whether multiple evaluations per ticket is expected upstream behavior or a data integrity issue.

[Precondition]
* **Student ID:** S00000210462 (B2C Student)
* **Plan:** 月15回プラン (15 lesson plan, product_id 29)
* **Charge:** 3033180
  - start_date: 2026-04-07
  - end_date: 2026-05-06
  - paid_price: ¥14,107
  - order_no: NULL
  - status: 1
  - tickets: 15 (ticket IDs 70236135–70236149)
* **Predecessor:** charge 2985544 (2026-03-07 → 2026-04-06)
* **Successor:** charge 3069060 (2026-05-07 → 2026-06-06)

[Steps]
1. Run the calculation batch for May 2026.
2. Inspect the output for charge_id 3033180 across April and May.
3. Verify that `lessons_taken` across both months does not exceed `total`.

[Expected]

**Total lessons_taken across all months should NOT exceed total (15):**

```
April taken + May taken <= 15
```

**paid_price across all months should NOT exceed charge paid_price (¥14,107):**

```
April paid_price + May paid_price <= ¥14,107
```

[Actual — Bug Present]

```csv
charge_id,target_ym,total,carried_over,taken,expired,remaining,paid_price
3033180,202604,15,0,14,0,1,13167
3033180,202605,15,1,2,0,0,1881
```

- Total taken: 14 + 2 = **16** (exceeds total of 15)
- Total paid_price: 13,167 + 1,881 = **¥15,048** (exceeds charge ¥14,107 by ¥941 = 1 unit price)

[Root Cause]

4 of 15 tickets have multiple evaluation records:

| ticket_id | evaluation_count | dates |
|-----------|-----------------|-------|
| 70236137 | 2 | 2026-04-12 |
| 70236141 | 3 | 2026-04-19 |
| 70236148 | 2 | 2026-05-01, 2026-05-04 |
| 70236149 | 2 | 2026-05-05 |

The CTE's MonthlyUsage stage counts each evaluation row as one lesson:
```sql
SUM(CASE WHEN ef.lesson_datetime >= ... AND ef.lesson_datetime < ... THEN 1 ELSE 0 END) AS lessons_taken
```

Multiple evaluations per ticket = multiple counts = over-reported lessons.

[Open Questions]
1. Is multiple evaluations per ticket expected behavior in the platform? (e.g., re-evaluations, corrections)
2. If expected: should the CTE use `COUNT(DISTINCT ticket_id)` instead of counting each evaluation row?
3. If not expected: this is an upstream data quality issue to report to the platform team.

[Status]
On hold — not ASC project scope. Miyachi-san creating Redmine ticket for Accounting team to clarify ticket consumption counting rules. No fix from ASC side unless their decision requires changes to the CTE counting logic.
