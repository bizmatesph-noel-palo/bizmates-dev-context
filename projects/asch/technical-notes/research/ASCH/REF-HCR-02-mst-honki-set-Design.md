# mst_honki_set Design and Implementation

**Author:** Jaysser Balido
**Type:** Reference — HCR project DB design
**Source:** Confluence

---

## Overview

Database schema design, Eloquent model class, and service integration pattern for the `mst_honki_set` table — the master configuration table for the Honki Set campaign.

---

## Table Schema

```sql
CREATE TABLE `mst_honki_set` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `start_date` DATETIME NOT NULL COMMENT 'Campaign start date',
  `end_date` DATETIME NOT NULL COMMENT 'Campaign end date',
  `status` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1=active, 0=inactive',
  `tier` INT NOT NULL DEFAULT 2 COMMENT 'Pricing tier (2=half price)',
  `plan_ids` JSON NOT NULL COMMENT 'Eligible plan IDs [1010, 1011]',
  `banner_pc` VARCHAR(255) NULL COMMENT 'PC banner image path',
  `banner_sp` VARCHAR(255) NULL COMMENT 'SP/mobile banner image path',
  `badge_text` VARCHAR(100) DEFAULT '本気セット' COMMENT 'Badge display text',
  `enable_first_month_discount` TINYINT(1) DEFAULT 1 COMMENT 'Include first month enrollment cohort',
  `enable_rest_campaign` TINYINT(1) DEFAULT 1 COMMENT 'Include rest campaign cohort',
  `enable_active_coaching` TINYINT(1) DEFAULT 1 COMMENT 'Include active coaching cohort',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Honki Set campaign configuration';
```

**Key fields:**
- `plan_ids` — JSON array of eligible coaching plan IDs (`[1010, 1011]`). Lesson eligibility is defined by plan condition (Daily 1/Daily 2/Monthly 15), NOT by this field.
- `tier = 2` — `PLAN_TIER_HALF_PRICE` = 50% discount
- `enable_*` flags — allow Marketing to run for specific cohorts only

---

## Eloquent Model

```php
class MstHonkiSet extends Model
{
    protected $table = 'mst_honki_set';

    protected $casts = [
        'start_date' => 'datetime',
        'end_date' => 'datetime',
        'status' => 'bool',
        'tier' => 'int',
        'plan_ids' => 'array',
        'enable_first_month_discount' => 'bool',
        'enable_rest_campaign' => 'bool',
        'enable_active_coaching' => 'bool',
    ];

    public static function getActiveCampaign($date = null): ?self
    {
        $date = $date ?? Carbon::now()->format('Y-m-d');
        return self::where('status', true)
            ->where('start_date', '<=', $date)
            ->where('end_date', '>=', $date)
            ->first();
    }

    public function isPlanEligible(int $planId): bool
    {
        return in_array($planId, $this->plan_ids);
    }
}
```

**Location:** `[MBTI] app/Models/MstHonkiSet.php`

---

## Service Integration Pattern

The eligibility checking sequence waterfalls through the 3 cohorts:

```php
// HonkiSetService.php
public function checkEligibility($student, $planId): ?array
{
    $campaign = MstHonkiSet::getActiveCampaign();
    if (!$campaign || !$campaign->isPlanEligible($planId)) {
        return null;
    }

    $isEligible = false;
    $cohort = null;

    // 1. First month enrollment discount cohort
    if ($campaign->enable_first_month_discount) {
        $discount = FirstMonthEnrollmentDiscountService::checkStudentEligibility($student, true);
        if (FirstMonthEnrollmentDiscountService::isEligibleForFirstMonthEnrollmentDiscount(
            $discount['first_enroll_discount_eligibility']
        )) {
            $isEligible = true;
            $cohort = 'first_month';
        }
    }

    // 2. Rest campaign cohort
    if (!$isEligible && $campaign->enable_rest_campaign) {
        if (LogReenrollment::hasAppliedRestCampaign($student->student_id, [$planId])) {
            $isEligible = true;
            $cohort = 'rest';
        }
    }

    // 3. Active coaching cohort
    if (!$isEligible && $campaign->enable_active_coaching) {
        $activeCampaignService = app()->make(CoachingForActiveStudentCampaignService::class);
        if ($activeCampaignService->verifyEligibilityForCampaign()) {
            $isEligible = true;
            $cohort = 'active_coaching';
        }
    }

    if (!$isEligible) {
        return null;
    }

    return [
        'campaign_id' => $campaign->id,
        'tier' => $campaign->tier,
        'cohort' => $cohort,
        'campaign_type' => 'HonkiSet',
    ];
}
```

**ASCH relevance:** ASCH will need to replicate or call this waterfall to identify which charges belong to Honki Set members for each batch run.
