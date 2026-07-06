# Honki Set (本気セット) Campaign Implementation

**Author:** Jaysser Balido
**Type:** Reference — HCR project implementation design
**Source:** Confluence

---

## Overview & Requirements

This document details the campaign logic and requirements from the marketing team for the Honki Set campaign. Marketing requires **3 cohorts** to be able to access the Honki Set during the campaign period:

1. First month enrollment discount
2. Rest campaign
3. Active coaching campaign

---

## Current State

The codebase handles multiple campaign types through separate services and tables:

* **First Month Enrollment Discount:** Uses `mst_first_month_enrollment_discount_schedule` and `FirstMonthEnrollmentDiscountService.php`
* **Rest Campaign:** Uses `mst_rest_campaign` and `trn_student_rest_campaign` with `StudentBannerService.php`
* **Active Coaching Campaign:** Uses `mst_campaign` with `CoachingPage.php`

---

## Proposed Architectural Paths

### Path A — Create a New Table (`mst_honki_set`) ✅ Selected

Creates a dedicated master table specifically for this campaign type.

* **Why it fits:** Follows existing codebase patterns where distinct campaign types use isolated master tables.
* **Flexibility:** Allows independent definition of campaign periods, eligible plan IDs (`1010`, `1011`), specific banner assets, and cohort tracking without hardcoded logic.
* **Maintainability:** Marketing can manage schedules via DB records rather than code or env deployments.

### Path B — Reuse `mst_campaign` Table (Alternative)

Instead of a new table, leverage the existing `mst_campaign` table by introducing a new `campaign_type` constant and a lightweight JSON configuration field.

```json
{
  "enable_first_month": true,
  "enable_rest": true,
  "enable_active_coaching": true,
  "badge_text": "本気セット",
  "plan_ids": [1010, 1011]
}
```

Path A was selected over Path B for isolation and maintainability.
