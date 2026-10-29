# Implementation Plan: B2BEC Alert-Mail Batch Fix

## Target File

`fuel/app/classes/model/corporateAlertEmailSettingModel.php`  
Method: `runB2b2cSendAlertMailFromTarget()`

---

## Option A: Remove the redundant guard (preferred)

### Before (current code, lines ~278-300)

```php
// Handle normal send type
if ($send_type == self::SEND_TYPE_NORMAL) {
   
    $plan_charges = self::find(function ($query) {
        return $query->join(['trn_charge', 'charge'])->on('trn_corporate_alert_mail_setting.plan_id', '=', 'charge.plan_id')->on('trn_corporate_alert_mail_setting.department_id', '=', 'charge.department_id')
            ->join(['mst_product', 'product'])->on('charge.product_id', '=', 'product.product_id')
            ->where('start_date', '<=', date('Y-m-d'))->where('end_date', '>=', date('Y-m-d'))->where('paid', 1)->where('charge.status', 1)
            ->where('product_type', PlanModel::PRODUCT_TYPE_SKYPE)->limit(1);
    });

    if (is_array($plan_charges) || ($plan_charges instanceof Countable)) {
        Log::info("[B2b2cSendAlertMail] " . count($plan_charges) . " active charge found.", __METHOD__);
    } else {
        Log::info("[B2b2cSendAlertMail] No active charges found or plan_charges is not countable.", __METHOD__);
    }

    Log::info("[B2b2cSendAlertMail]start_date <= " . date('Y-m-d') . " check.", __METHOD__);
    Log::info("[B2b2cSendAlertMail]product_type check.", __METHOD__);
    
    if (empty($plan_charges)) {
        Log::info("[B2b2cSendAlertMail]active charge not found.", __METHOD__);
        return ['result' => false, 'message' => '送信できませんでした。配信条件を確認してください。'];
    }
    Log::info("[B2b2cSendAlertMail] finished. " . print_r($setting->id, true), __METHOD__);
    $alert_mail = new Alertmailtask($target, false);
    $studentEmailSentCount = $alert_mail->handle();

    Log::info("[B2b2cSendAlertMail]finished. send alert mail", __METHOD__);

}
```

### After (guard removed)

```php
// Handle normal send type
if ($send_type == self::SEND_TYPE_NORMAL) {

    Log::info("[B2b2cSendAlertMail] processing setting id={$setting->id}, plan_id={$plan_id}, department_id={$department_id}", __METHOD__);
    $alert_mail = new Alertmailtask($target, false);
    $studentEmailSentCount = $alert_mail->handle();

    Log::info("[B2b2cSendAlertMail]finished. send alert mail, sent={$studentEmailSentCount}", __METHOD__);

}
```

### Justification

- `Alertmailtask::handle()` → `_send($setting)` → `$setting->findSendTargetStudent()` already queries `trn_charge` with `$this->plan_id` and `$this->department_id`.
- When `send_student_list` is empty, `_send()` logs and returns without sending.
- The guard was effectively a no-op for correctness (it passed whenever ANY setting had a matching charge) and only added cost.

---

## Option B: Target-specific guard (alternative)

### After (guard made target-specific)

```php
// Handle normal send type
if ($send_type == self::SEND_TYPE_NORMAL) {

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

    if (empty($plan_charges)) {
        Log::info("[B2b2cSendAlertMail]active charge not found for plan_id={$plan_id}, department_id={$department_id}.", __METHOD__);
        return ['result' => false, 'message' => '送信できませんでした。配信条件を確認してください。'];
    }

    Log::info("[B2b2cSendAlertMail] processing setting id={$setting->id}, plan_id={$plan_id}, department_id={$department_id}", __METHOD__);
    $alert_mail = new Alertmailtask($target, false);
    $studentEmailSentCount = $alert_mail->handle();

    Log::info("[B2b2cSendAlertMail]finished. send alert mail, sent={$studentEmailSentCount}", __METHOD__);

}
```

---

## Test Cases

| # | Case | Setup | Expected |
|---|------|-------|----------|
| 1 | Matching active charge | Setting + paid/active Skype charge with same plan_id/department_id; date in range | Target processing continues; eligible recipients may receive mail |
| 2 | No matching charge (other setting has one) | Different setting has active charge but current target has none | Current target is skipped (Option B) or handled gracefully downstream (Option A) |
| 3 | Inactive/expired/unpaid charge | Same plan/department but `paid=0` OR `status=0` OR date out of range | Target skipped (B) or no students found (A) |
| 4 | Non-Skype product type | Same plan/department, active charge, but `product_type != PRODUCT_TYPE_SKYPE` | Target skipped (B) or no students found (A) |
| 5 | Multiple scheduled settings | 2+ settings due today | Each evaluated independently; no shared/global lookup |
| 6 | No eligible recipients | Matching charge but `findSendTargetStudent()` returns empty | No mail sent; batch continues normally |

### Test file location

`fuel/app/tests/unit/model/CorporateAlertEmailSettingModelTest.php` (new file)

### Test structure (PHPUnit 7)

```php
<?php

namespace Tests\Unit\Model;

use PHPUnit\Framework\TestCase;
use Model\CorporateAlertEmailSettingModel;
use Model\PlanModel;

class CorporateAlertEmailSettingModelTest extends TestCase
{
    /**
     * @test
     * Case 1: With Option A, ensure handle() is called even without
     * a separate charge guard — findSendTargetStudent handles it.
     */
    public function it_processes_target_when_active_charge_exists()
    {
        // Setup: mock or seed trn_charge with matching plan_id/department_id
        // Assert: Alertmailtask::handle() is invoked and returns > 0
    }

    /**
     * @test
     * Case 2: No charge for this target's plan/department.
     * With Option A: findSendTargetStudent() returns empty → no mail sent.
     * With Option B: guard returns early.
     */
    public function it_skips_target_when_no_matching_charge()
    {
        // Setup: no trn_charge row for target plan/department
        // Assert: no mail sent, batch continues
    }

    /**
     * @test
     * Case 5: Multiple settings run independently.
     */
    public function it_evaluates_each_setting_independently()
    {
        // Setup: 2 settings scheduled today, only 1 has matching charge
        // Assert: each processed in isolation, only the one with students sends mail
    }
}
```

---

## Deployment Checklist

1. [ ] Implement fix in a feature branch off the current production branch
2. [ ] Write unit tests covering cases 1-6
3. [ ] Run `php ../../fuel/vendor/bin/phpunit tests/unit/model/CorporateAlertEmailSettingModelTest.php` inside php-fpm container
4. [ ] Deploy to staging environment with representative data
5. [ ] Run `EXPLAIN ANALYZE` on staging for the remaining queries in the batch
6. [ ] Monitor next staging batch run: confirm the broad query no longer appears in Performance Insights
7. [ ] Deploy to production
8. [ ] Monitor the 08:55 JST run: compare batch duration, target count, and sent-mail count against previous normal day (June 29 baseline)
9. [ ] If notifications are unexpectedly skipped or sent to wrong recipients → rollback application deployment (no schema change involved)

## Follow-up (post-fix)

- If `findSendTargetStudent()` still shows high latency, evaluate a composite index on `trn_charge(plan_id, department_id, paid, status, start_date, end_date)` via `ls-database-migrations`
- Check production DDL for `trn_corporate_alert_mail_setting` — only has PK index. A covering index on `(status, is_deleted, send_start_date, send_timing, send_day_of_the_week)` could benefit `getPendingQue()` if the table grows large.
