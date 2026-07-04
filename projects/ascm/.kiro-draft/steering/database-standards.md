---
inclusion: auto
---

# Database Standards

## Schema Ownership

Table definitions live in `ls-database-migrations`. If a new table or column is needed, create the migration THERE — not in the accounting repo.

## ASC's Relationship to the Database

**READS from (never modify):**
- `trn_charge` — source of all charges
- `trn_ticket` — lesson tickets per student_product
- `trn_student_product` — links students to charges and plans
- `trn_evaluation` — lesson evaluations (lessons taken)
- `mst_product` — product definitions (lesson_type, lesson_volume)
- `trn_charge_forex` — PayPal gross amounts
- `trn_prorated_refund_charge` — prorated refund data
- `log_refund_history` — refund linkage

**WRITES to (ASC owns these):**
- `log_monthly_rate_calculation` / `_pre` — monthly lesson consumption
- `log_daily_rate_calculation` / `_zipan` / `_pre` variants — daily pro-rata
- `log_sum_calculation` / `_zipan` / `_pre` / `_history` variants — aggregated summary

## Key Tables

| Table | Purpose |
|---|---|
| `log_monthly_rate_calculation` | Monthly lesson consumption data (Final) |
| `log_monthly_rate_calculation_pre` | Same (Pre/速報) |
| `log_daily_rate_calculation` | Daily pro-rata calculation (Final) |
| `log_daily_rate_calculation_pre` | Same (Pre) |
| `log_sum_calculation` | Aggregated summary (feeds CalculationSummary CSV) |
| `trn_charge` | Source of all charges (from student portal / admin) |
| `trn_ticket` | Lesson tickets per student_product |
| `trn_student_product` | Links students to charges and plans |

## When You Need a DB Change

1. Check if the table/column already exists in `[Migrations]`
2. If adding new: create migration in `[Migrations]`, not `[ASC]`
3. If reading existing: verify column names from `[Migrations]` or the model, not from memory
4. New columns on existing tables MUST be `nullable()` (shared DB — other services read these tables)
5. Always include `down()` method in migrations
