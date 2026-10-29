# B2BEC Alert-Mail Batch: Investigation Report

## 1. Incident Timeline

| Date | Batch Duration | Avg Latency (ms) | Rows Examined/call |
|------|---------------|-------------------|--------------------|
| 2026-06-29 | ~2.5h | 2,367.68 | 478,462.67 |
| 2026-07-06 | ~13h | 19,580.47 | 4,778,503.36 |

Reported by Wu-san. AWS Aurora Performance Insights identified the culprit SQL.

## 2. Code Flow

```
b2bec_send_alert_mail::run()
  └─ sendToStudent()
       └─ CorporateAlertEmailSettingModel::getPendingQue()
            → returns all active settings scheduled for today
       └─ foreach ($targetList as $target)
            └─ CorporateAlertEmailSettingModel::runB2b2cSendAlertMailFromTarget($target)
                 ├─ validates department/plan exist
                 ├─ updateAlertMailSettingFromTarget($target)
                 ├─ ** BROAD plan_charges lookup ** ← DEFECT
                 └─ new Alertmailtask($target, false)->handle()
                      └─ _send($setting)
                           └─ $setting->findSendTargetStudent()  ← already target-specific
                           └─ (sends mail or returns early if no students)
```

## 3. The Defect

**Location**: `CorporateAlertEmailSettingModel::runB2b2cSendAlertMailFromTarget()` (line ~280)

```php
$plan_charges = self::find(function ($query) {
    return $query
        ->join(['trn_charge', 'charge'])
            ->on('trn_corporate_alert_mail_setting.plan_id', '=', 'charge.plan_id')
            ->on('trn_corporate_alert_mail_setting.department_id', '=', 'charge.department_id')
        ->join(['mst_product', 'product'])
            ->on('charge.product_id', '=', 'product.product_id')
        ->where('start_date', '<=', date('Y-m-d'))
        ->where('end_date', '>=', date('Y-m-d'))
        ->where('paid', 1)
        ->where('charge.status', 1)
        ->where('product_type', PlanModel::PRODUCT_TYPE_SKYPE)
        ->limit(1);
});
```

### Problems

1. **No target binding**: The query does not filter by `$target->plan_id` or `$target->department_id`. It joins ALL rows from `trn_corporate_alert_mail_setting` against ALL matching charges.

2. **`pre_find` adds `WHERE status = 1`** (from `Base` model), which constrains `trn_corporate_alert_mail_setting.status` but does NOT scope to the current target's `id`.

3. **Repeated execution**: This identical broad query runs once per target in the foreach loop. For N scheduled settings, the same expensive scan executes N times.

4. **Logical incorrectness**: If ANY other alert-mail setting has a matching active charge, the guard passes even when the CURRENT target has none. The guard is therefore not a target-specific validity check.

### Generated SQL (matches Performance Insights)

```sql
SELECT * FROM trn_corporate_alert_mail_setting
JOIN trn_charge AS charge
  ON trn_corporate_alert_mail_setting.plan_id = charge.plan_id
 AND trn_corporate_alert_mail_setting.department_id = charge.department_id
JOIN mst_product AS product
  ON charge.product_id = product.product_id
WHERE start_date <= ?
  AND end_date >= ?
  AND paid = ?
  AND charge.status = ?
  AND product_type = ?
  AND trn_corporate_alert_mail_setting.status = ?
LIMIT ?;
```

## 4. Why Performance Degraded

- The query scans the cross-product of `trn_corporate_alert_mail_setting × trn_charge × mst_product` limited only by date range and status predicates.
- Between June 29 and July 6, rows examined per call jumped 10× (478K → 4.7M), likely due to Aurora's query optimizer choosing a different execution plan (possibly after an Aurora failover, statistics refresh, or buffer pool eviction).
- Since the query runs N times and the per-call cost increased 10×, total batch time also increased proportionally.

## 5. Downstream Safety Check

`Alertmailtask::handle()` → `_send($setting)`:
1. Calls `$setting->findSendTargetStudent()` which is **already target-specific** — it uses `$this->department_id` and `$this->plan_id` throughout.
2. If `$setting->send_student_list` is empty after the call, the method logs and returns without sending any mail.

This means the broad `plan_charges` guard is **redundant** — the downstream code already handles the "no eligible students" case safely.

## 6. Recommended Fix

### Option A: Remove the guard (preferred)

Remove the entire `plan_charges` block. The downstream `findSendTargetStudent()` already:
- Queries only the target's plan_id/department_id
- Returns early if no students match
- Sends no mail when the list is empty

This eliminates N expensive queries per batch run.

### Option B: Make the guard target-specific (if business requires it)

Replace `self::find(...)` with a direct query against `trn_charge`:

```php
$today = date('Y-m-d');
$plan_charges = DB::select('charge.id')
    ->from(['trn_charge', 'charge'])
    ->join(['mst_product', 'product'])
        ->on('charge.product_id', '=', 'product.product_id')
    ->where('charge.plan_id', $plan_id)
    ->where('charge.department_id', $department_id)
    ->where('charge.start_date', '<=', $today)
    ->where('charge.end_date', '>=', $today)
    ->where('charge.paid', 1)
    ->where('charge.status', 1)
    ->where('product.product_type', PlanModel::PRODUCT_TYPE_SKYPE)
    ->limit(1)
    ->execute()
    ->as_array();
```

This:
- Binds to the current target's `plan_id` and `department_id`
- Does NOT re-join `trn_corporate_alert_mail_setting`
- Returns at most 1 row via index seek instead of a full scan

## 7. Open Questions

Before implementing, confirm with the team:

1. **Is the guard needed?** — If `findSendTargetStudent()` already handles the no-students case safely, removing the guard is the cleanest fix.
2. **Should the batch log when no active charge exists for a target?** — If yes, keep the guard with Option B and add a log line before returning.
3. **Production DDL for `trn_charge`** — Does a composite index on `(plan_id, department_id, paid, status, start_date, end_date)` already exist? If not, consider adding one after the code fix lands (via `ls-database-migrations`).
