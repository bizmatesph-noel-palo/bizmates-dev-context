---
inclusion: manual
---

# Skill: ASC Batch Developer

## Role

You are a backend developer working on the ASC (Accounting System Changes) batch processing system. You produce code that handles monthly/daily revenue recognition calculations, CSV report generation, and Freee API journal synchronization.

## Architecture You Work With

```
Command → Logic class (raw SQL CTE) → DB::select() → INSERT → CSV generation
```

- No controllers, no API, no frontend
- Raw SQL strings in PHP (MySQL 5.7, no native CTE syntax)
- Multi-tenant: same code, different DB connections (Bizmates + Zipan)
- 4-location pattern: Logic Biz + Zipan, PreLogic Biz + Zipan

## Templates

### New Condition in Grouped CTE

```sql
-- FIX ASC-{XXX}: [Brief description]
-- [Explanation of what this condition guards and when it fires]
{condition}
AND NOT EXISTS (
    SELECT 1 FROM StudentProduct sp3
    WHERE sp3.student_id = om.student_id
        AND sp3.product_id = om.product_id
        AND (sp3.order_no <=> om.order_no)  -- NULL-safe comparison
        AND sp3.start_date > om.end_date
)
```

### Uriage Subquery (CSV generation — both log tables)

```php
$selectItem[] = '(select case when 1='. $isFuture .' then 0 else coalesce((select sum(paid_price) from log_daily_rate_calculation where target_ym = '. $date->format('Ym') .' and charge_id = trn_charge.id), 0) + coalesce((select sum(paid_price) from log_monthly_rate_calculation where target_ym = '. $date->format('Ym') .' and charge_id = trn_charge.id), 0) end) AS uriage'.$i;
```

For Zipan: use `log_daily_rate_calculation_zipan` but keep `log_monthly_rate_calculation` (NO `_zipan` suffix).

### Post-CTE Additional Query (Merge Pattern)

```php
// After main CTE query runs:
$mainRows = DB::connection($connection)->select($cteQuery);

// Additional query (e.g., refund, orphaned)
$additionalRows = DB::connection($connection)->select($additionalQuery);

// Merge
$allRows = array_merge($mainRows, $additionalRows);

// Insert
DB::connection($connection)->table($tableName)->insert(array_map($mapRow, $allRows));
```

### Logging Pattern

```php
Log::info('[MONTHLY_RATE_CALCULATION] - STARTED');
Log::info('Date range: ' . $startDate . ' ~ ' . $endDate);
// ... processing ...
Log::info('Refund rows: Bizmates=' . count($bizRefundRows) . ', Zipan=' . count($zipanRefundRows));
Log::info('Total   : ' . count($allRows) . '  rows to insert');
Log::info('DATA CREATION COMPLETED SUCCESSFULLY!');
Log::info('[MONTHLY_RATE_CALCULATION] - END');
```

## Example Scenarios

### "Add a new expiry condition to the Grouped CTE"

1. Identify where in `is_ticket_expiry_month` the condition belongs
2. Write the SQL condition with inline comment (FIX ASC-XXX)
3. Apply to all 4 locations (Logic Biz + Zipan, PreLogic Biz + Zipan)
4. Run test case simulation for the specific scenario
5. Run functional simulation for related TCs (other expiry scenarios)

### "Add a new post-CTE query (like orphaned charges)"

1. Create `generateNewQuery()` method in both Logic and PreLogic
2. Call it after existing queries in `execute()`
3. Merge results with existing rows before INSERT
4. Add logging for the new row count
5. Verify: run smoke test, check logs

### "Fix a CSV generation issue"

1. Identify which function generates the CSV (`CommonUtil` or `ZipanUtil`)
2. Check the data source (which log table is queried)
3. Verify table names from models (watch for `_zipan` trap)
4. Apply fix to both Bizmates and Zipan versions
5. Smoke test: run `SendJournalsDataCommand` locally

### "Add a new CSV file to the batch output"

1. Add config entry in `config/const.php` (file name pattern, headers)
2. Create `createNewFile()` method in `CommonUtil` (and `ZipanUtil` if needed)
3. Call it from `SendJournalsDataLogic` (or `DataCorrectionLogic`)
4. Follow existing patterns for CSV structure
5. Verify: check generated file exists and has correct headers
