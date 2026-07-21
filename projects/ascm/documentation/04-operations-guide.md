# Operations Guide — Running & Troubleshooting Batch Commands

## Command Reference

### How the Execution Date Works

All batch commands accept an optional `exeDate` parameter. This applies to `MonthlyRateCalculationPreCommand`, `MonthlyRateCalculationCommand`, `DailyRateCalculationPreCommand`, and `SendJournalsDataCommand`.

The `exeDate` tells the system "pretend today is this date." The system then **always processes the previous month** relative to that date.

| You pass | System thinks "today" is | Processes data for |
|----------|--------------------------|-------------------|
| `2026-04-01` | April 1st | **March 2026** (2026-03-01 ~ 2026-03-31) |
| `2026-05-01` | May 1st | **April 2026** (2026-04-01 ~ 2026-04-30) |
| `2026-06-18` | June 18th | **May 2026** (2026-05-01 ~ 2026-05-31) |
| *(no date)* | Today's actual date | **Previous month** |

**Important:** Passing `2026-03-01` does NOT process March — it processes **February**. The date is "when the command runs," not "what month to process."

**When no date is passed:** The command defaults to today's date and processes the previous month. For normal monthly operations on the scheduled cron day, no date parameter is needed.

---

### Monthly Rate Calculation

```bash
# Pre (速報) — draft calculation, writes to _pre tables
php artisan command:MonthlyRateCalculationPreCommand 2026-05-01

# Final (確定) — authoritative calculation, writes to production tables
php artisan command:MonthlyRateCalculationCommand 2026-05-01
```

Example — to process April 2026 data, pass any day in May:
```bash
php artisan command:MonthlyRateCalculationPreCommand 2026-05-01
php artisan command:MonthlyRateCalculationCommand 2026-05-01
```

### Daily Rate Calculation (Pre)

```bash
# Includes both daily AND monthly calculation + CSV generation
php artisan command:DailyRateCalculationPreCommand 2026-05-01
```

This is the "all-in-one" Pre command. It runs:
1. Daily rate calculation (pro-rata)
2. Monthly rate calculation (CTE)
3. Summary aggregation
4. CSV file generation

### Send Journals (Final)

```bash
# Daily calc + monthly calc + Freee journal sync + balance transition + CSVs
php artisan command:SendJournalsDataCommand 2026-05-01 {no_send_flag?} {no_dailyratecalculation_flag?}
```

This is the "all-in-one" Final command. Same as DailyRateCalculationPreCommand but also:
- Submits journal entries to Freee API
- Generates balance transition file
- Writes to production tables (not _pre)

Optional flags:
- `no_send_flag = 1` — skip actual Freee submission (dry run)
- `no_dailyratecalculation_flag = 1` — skip daily rate calculation

### Data Correction

```bash
php artisan command:DataCorrectionCommand
```

Reads a correction CSV file and applies adjustments to log tables.

### Clear Logs

```bash
php artisan logs:clear-calculations {date} {--db=}
```

Deletes all log entries for a given period. Used before re-runs to ensure idempotency.

---

## How to Re-Run a Month Safely

### Step 1: Clear previous data

```bash
php artisan logs:clear-calculations 2026-04-01
php artisan logs:clear-calculations 2026-04-01 --db=bizmates   # Bizmates only
php artisan logs:clear-calculations 2026-04-01 --db=zipan      # Zipan only
```

### Step 2: Re-run the calculation

```bash
# To reprocess April 2026, pass May as the execution date
php artisan command:MonthlyRateCalculationPreCommand 2026-05-01
```

### Step 3: Verify output

Check the generated CSV or query the log table:
```sql
SELECT * FROM log_monthly_rate_calculation_pre
WHERE target_ym = '202604'
ORDER BY student_id, charge_id;
```

### Important: Do NOT skip months

The CTE uses running totals. If March hasn't been processed, April's carry-over values will be wrong. Always process months in sequence.

---

## Batch Execution Schedule

Commands are grouped into two shell scripts and triggered by cron:

### `pre.sh` — Runs on the 1st of every month at 06:00

```bash
# Execution order matters:
php artisan command:MonthlyRateCalculationPreCommand 2026-03-01
php artisan command:DailyRateCalculationPreCommand 2026-03-01
```

### `send.sh` — Runs on approximately the 3rd business day of each month at 00:00

```bash
# Execution order matters:
php artisan command:MonthlyRateCalculationCommand 2026-03-01
php artisan command:SendJournalsDataCommand 2026-03-01
```

### Cron Schedule (Production)

The `send.sh` dates are manually configured per year because the 3rd business day varies by month (weekends/holidays shift it). The schedule must be updated by the end of December for the following year.

```
# pre.sh — 1st of every month at 06:00
00 06 01 * * /home/imasuoka/work/bizmates_accounting/pre.sh

# send.sh — ~3rd business day per month at 00:00
00 00 06 01 * /home/imasuoka/work/bizmates_accounting/send.sh   # Jan → 6th
00 00 03 02 * /home/imasuoka/work/bizmates_accounting/send.sh   # Feb → 3rd
00 00 03 03 * /home/imasuoka/work/bizmates_accounting/send.sh   # Mar → 3rd
00 00 05 04 * /home/imasuoka/work/bizmates_accounting/send.sh   # Apr → 5th
00 00 08 05 * /home/imasuoka/work/bizmates_accounting/send.sh   # May → 8th
00 00 05 06 * /home/imasuoka/work/bizmates_accounting/send.sh   # Jun → 5th
00 00 05 07 * /home/imasuoka/work/bizmates_accounting/send.sh   # Jul → 5th
00 00 03 08 * /home/imasuoka/work/bizmates_accounting/send.sh   # Aug → 3rd
00 00 05 09 * /home/imasuoka/work/bizmates_accounting/send.sh   # Sep → 5th
00 00 04 10 * /home/imasuoka/work/bizmates_accounting/send.sh   # Oct → 4th
00 00 06 11 * /home/imasuoka/work/bizmates_accounting/send.sh   # Nov → 6th
00 00 05 12 * /home/imasuoka/work/bizmates_accounting/send.sh   # Dec → 5th
```

**Note:** The monthly rate command runs FIRST in both scripts. This ensures the monthly log tables are populated before the daily/journals command aggregates them into the summary.

---

## Troubleshooting

### Problem: CSV shows wrong paid_price

**Check:** Is `number_of_expired_lessons` correct?

`paid_price = unit_price × (taken + expired)`

If expired = 0 when it should have a value, the expiry logic isn't firing. Common causes:
- `charge_in_past` not flagged (check if `end_date` matches `endDate`)
- `max_ticket_end_datetime` exceeds the boundary (FLP tickets at 00:59:59)
- `is_last_charge_in_order` not detected (check order_no and successor existence)

### Problem: Charge missing from CSV entirely

**Check:** Does the charge have tickets in `trn_ticket`?

```sql
SELECT COUNT(*) FROM trn_ticket WHERE student_product_id = (
    SELECT id FROM trn_student_product WHERE charge_id = {charge_id}
);
```

If 0: the charge is orphaned. It should be picked up by the orphaned charge query. If it's still missing, check whether `start_date` or `end_date` falls in the target month.

If >0: the tickets exist but might have `start_datetime` outside the batch window. Check the TicketMonths base case criteria.

### Problem: Charge appears twice

**Check:** Is it appearing once from the CTE and once from the refund/orphaned query?

```sql
SELECT charge_id, COUNT(*) FROM log_monthly_rate_calculation_pre
WHERE target_ym = '202604'
GROUP BY charge_id HAVING COUNT(*) > 1;
```

Duplicates usually mean the charge matches criteria in both the CTE and an additional query. Review the merge logic.

### Problem: Re-run produces different results

**Check:** Was `clear-calculation-logs` run first?

Without clearing, old rows + new rows coexist. The system does DELETE-then-INSERT within the calculation, but summary tables may accumulate.

Also check: was the previous month processed? Carry-over depends on prior month's remaining value.

### Problem: Pre and Final show different numbers

They should be identical (same logic, different tables). If they differ:
1. Check if a fix was applied to one file but not the other
2. Check if the batch ran with different dates
3. Run both with same parameters and compare log tables directly

---

## Monitoring & Verification

### Quick sanity checks after a run

```sql
-- Total charges processed this month
SELECT COUNT(DISTINCT charge_id) FROM log_monthly_rate_calculation
WHERE target_ym = '202604';

-- Any negative remaining (should never happen)
SELECT * FROM log_monthly_rate_calculation
WHERE target_ym = '202604' AND number_of_remaining_lessons < 0;

-- Any taken > total (should never happen)
SELECT * FROM log_monthly_rate_calculation
WHERE target_ym = '202604' AND number_of_lessons_taken > total;

-- Total revenue this month
SELECT SUM(paid_price) FROM log_monthly_rate_calculation
WHERE target_ym = '202604';
```

### Compare Pre vs Final

```sql
SELECT
    p.charge_id,
    p.paid_price AS pre_price,
    f.paid_price AS final_price,
    p.number_of_expired_lessons AS pre_expired,
    f.number_of_expired_lessons AS final_expired
FROM log_monthly_rate_calculation_pre p
JOIN log_monthly_rate_calculation f ON f.charge_id = p.charge_id AND f.target_ym = p.target_ym
WHERE p.target_ym = '202604'
AND (p.paid_price != f.paid_price OR p.number_of_expired_lessons != f.number_of_expired_lessons);
```

If this returns rows, Pre and Final have diverged — investigate which fix is missing.

---

## Known Gotchas

1. **Never run two instances simultaneously.** No concurrency protection exists. Two runs for the same period will corrupt data.

2. **Don't skip months.** The CTE carries forward values. Processing June without May means June's carry-over = 0.

3. **FLP tickets extend past midnight.** `end_datetime` can be `00:59:59` on the 1st of next month. Boundary comparisons must use `INTERVAL 2 DAY` not `INTERVAL 1 DAY`.

4. **NULL order_no is special.** B2C charges have `order_no = NULL`. NULL comparisons require `<=>` operator. Standard `=` returns NULL (falsy).

5. **Deleted tickets make charges invisible.** The CTE starts from `trn_ticket`. The orphaned charge query catches these, but only if `start_date` or `end_date` falls in the target month.

6. **Every fix must be applied 4 times.** Pre Logic (Bizmates + Zipan) and Final Logic (Bizmates + Zipan). Missing one location = regression discovered later.
