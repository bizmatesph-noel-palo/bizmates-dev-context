---
inclusion: auto
---

# Glossary

| Term | Meaning |
|---|---|
| Pre (速報) | Preliminary calculation — writes to `_pre` tables. Draft numbers. |
| Final (確定) | Authoritative calculation — writes to production log tables. Official numbers. |
| target_ym | Year-month being processed (e.g., `202605` = May 2026) |
| exeDate | The date passed to the command — system thinks "today" is this date, processes the PREVIOUS month |
| startDate / endDate | Derived from exeDate — first and last day of the month being processed |
| uriage (売上) | Revenue — the `paid_price` recognized in a given month |
| 差引 (sahiki) | Difference — charged amount minus recognized amount |
| REST | Student status when contract expires and is not renewed |
| FLP | 月15回プラン — 15 lessons/month plan (product_id 29). B2C only, order_no = NULL. |
| B2B | Business-to-Business — has `order_no`, managed through department contracts |
| B2C | Business-to-Consumer — `order_no = NULL`, individual PayPal payment |
| B2B2C | Hybrid — `order_no = NULL`, partner arrangement |
| B2E | Advance application — B2B student buying FLP as individual before contract renewal |
| CTE | Common Table Expression — the recursive SQL pipeline that calculates monthly consumption |
| Orphaned charge | A charge whose tickets were all deleted (no lessons booked before renewal) |
| Cooling-off | Refund within cancellation period — special handling |
| carried_over | Tickets remaining from a prior month that can still be used |
| charge_in_past | Boolean flag — is the charge's end_date before or on the batch execution date? |
| is_last_charge_in_order | Boolean — is this the final charge in a B2B order sequence? |
| is_last_charge_month | Boolean — does end_date fall within this month? |
