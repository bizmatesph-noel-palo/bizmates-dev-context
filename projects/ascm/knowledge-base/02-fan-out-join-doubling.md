# 02 — Fan-Out Join Doubling Values

> **TL;DR:** A JOIN between charges and tickets (1:N) caused `SUM(paid_price)` to multiply by the ticket count. A ¥12,980 charge appeared as ¥389,400. Fix: pre-aggregate the N-side in a subquery before joining.

---

## Problem Pattern

A SQL query joins a parent table to a child table that has multiple rows per parent. Aggregations (SUM, COUNT) on the parent's columns are silently multiplied by the number of matching child rows. The query returns results without errors, but the financial amounts are doubled, tripled, or worse — depending on the fan-out ratio.

---

## How We Encountered It

The monthly rate calculation pipeline — created by the ASC project — joins charges to tickets to compute lesson consumption. A single charge can have multiple ticket records (e.g., 30 tickets for a 30-lesson plan). When the query joined `trn_charge` to `trn_ticket` without pre-aggregating, `paid_price` was repeated once per ticket row.

After `SUM(paid_price)`: ¥12,980 × 30 = **¥389,400**. The numbers were large enough to look plausible as monthly totals, which delayed detection.

**JIRA:** ASC-236

---

## Root Cause

```sql
SELECT charge.id, SUM(charge.paid_price), COUNT(ticket.id)
FROM charges JOIN tickets ON tickets.charge_id = charges.id
GROUP BY charge.id
```

The SUM is inflated because `charge.paid_price` repeats for every matching ticket row *before* GROUP BY collapses them. A **1:N join was treated as 1:1.**

---

## What We Did

Pre-aggregate the child table to one row per parent:

```sql
SELECT charge.id, charge.paid_price, ticket_summary.tickets_used
FROM charges
LEFT JOIN (
    SELECT charge_id, COUNT(*) as tickets_used
    FROM tickets GROUP BY charge_id
) AS ticket_summary ON ticket_summary.charge_id = charges.id
```

---

## Industry Standard / Best Practice

### How dbt Guards Against This

dbt's best practices warn about "fan-out joins" and recommend row_count checks after every JOIN. Projects at GitLab and JetBrains enforce: if a JOIN changes the grain, it must be commented and validated.

### How Looker/Metabase Handle This

BI tools use "symmetric aggregates" as a workaround, but recommend pre-aggregation for production models.

### The Cardinal Rule

> Never aggregate columns from Table A after joining to Table B at a different cardinality. Pre-aggregate Table B first.

### Detection Techniques

- **Row count checks:** More rows than the driving table = fan-out
- **Sanity bounds:** A single charge > ¥100,000 for a ¥12,980/month service is a red flag
- **DISTINCT test:** If `SUM(DISTINCT x)` ≠ `SUM(x)`, you have a fan-out

---

## Prevention Checklist

- [ ] Before JOIN + GROUP BY, state expected cardinality: "Table A = 1 row per X, Table B = N rows per X"
- [ ] If cardinalities don't match, pre-aggregate the N-side in a subquery
- [ ] Add sanity-check assertions: if amount exceeds business bounds, log a warning
- [ ] Code review: any JOIN + SUM/COUNT gets scrutinized for fan-out
- [ ] Consider denormalized aggregates for high-frequency queries