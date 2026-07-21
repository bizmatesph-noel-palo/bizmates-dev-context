---
inclusion: manual
---

# Troubleshooting

## Common Issues

### "Command runs but 0 rows inserted"

**Check:**
- Are there charges in the target month? (`trn_charge` with matching product_ids and dates)
- Is the correct DB connection being used? (Bizmates vs Zipan)
- Did `ClearCalculationLogsCommand` wipe the data?
- Is the exeDate correct? (Remember: processes PREVIOUS month)

### "SQL error: table doesn't exist"

**Check:**
- Table naming trap: Zipan monthly = `log_monthly_rate_calculation` (NO `_zipan` suffix)
- Verify from model's `protected $table` property
- Check which DB connection the query runs on

### "Paid_price sum doesn't match / 差引 ≠ 0"

**Check:**
- Is the charge in `log_daily_rate_calculation` OR `log_monthly_rate_calculation`? (One or the other, never both)
- Was the month actually calculated? (Check if log table has rows for that target_ym)
- Multiple evaluations per ticket inflating lessons_taken? (Category B issue)

### "Duplicate rows in log table"

**Check:**
- Was the same month run twice without clearing first?
- Run `ClearCalculationLogsCommand` for that month, then re-run the calculation

### "Expiry fires in wrong month"

**Check:**
- Lookahead condition: is `end_date` on day 1-2 of next month?
- `charge_in_past`: is `end_date <= endDate` (not `<`)?
- `INTERVAL 2 DAY` boundary: is `max_ticket_end_datetime` crossing it?
- Which expiry trigger is firing? (`is_last_charge_in_order`, `is_last_charge_month`, `is_ticket_expiry_month`)

### "Charge appears in wrong month"

**Check:**
- FilteredUsage expulsion rules — is the charge being expelled from the correct month?
- TicketMonths expansion — is it generating too many or too few month rows?
- Branch B (lookahead for new charges) — is a future charge appearing too early?

### "Orphaned charge missing from report"

**Check:**
- Does the charge have ANY tickets in `trn_ticket`? (If yes, not orphaned — CTE handles it)
- Is `sp.end_date` within the target month boundaries?
- Is the orphaned charge query's product_id filter correct?

## Recovery Steps

### Re-run a specific month

```bash
# 1. Clear existing data for that month
php artisan command:ClearCalculationLogsCommand {YYYYMM}

# 2. Re-run calculation
php artisan command:MonthlyRateCalculationCommand {exeDate}

# 3. Re-run send (if Final)
php artisan command:SendJournalsDataCommand {exeDate}
```

### Check what's in the log table

```sql
SELECT charge_id, target_ym, total, number_of_carried_over_lessons,
       number_of_lessons_taken, number_of_expired_lessons,
       number_of_remaining_lessons, paid_price
FROM log_monthly_rate_calculation
WHERE charge_id = {id}
ORDER BY target_ym;
```
