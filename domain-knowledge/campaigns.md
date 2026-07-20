# Campaigns Overview

**Last updated:** 2026-07-16

---

## First Month Campaign (新規キャンペーン)

### Types

- Within 3 days from signup (登録3日以内初月半額)
- After 4 days from signup (登録4日移行初月半額)

### Target: Contract Type

- B2C

### Condition

- The student is not enrolled in a plan.
- The student's registration date is within the applicable window (within 3 days, or after 4 days from signup).

### Check: How to Verify

If the student has a record in the table and the current date is within the related charge's `start_date` and `end_date`:

```sql
SELECT *
FROM log_first_month_enrollment_discount_apply l
JOIN trn_charge c
  ON l.enrollment_charge_id = c.id
  AND c.start_date <= NOW()
  AND c.end_date >= NOW()
  AND c.student_id = [STUDENT-ID];
```

### Creation

Dates are inserted manually into the database. The discount is checked and shown on the plan page before purchase. Near the end of each year, a Redmine ticket is created for the next year's campaign schedule.

- Redmine: https://redmine.bizmates.jp/issues/9297
- Jira: [DEVOPS-765](https://bizmates.atlassian.net/browse/DEVOPS-765)

### Benefits

A student with a valid First Month campaign is eligible for a **50% discount** on purchasing Online Lessons.

> **Note (confirmed 2026-07-03):** The 50% discount applies to both B2C and B2E students. Documentation listing this as "B2C only" is incomplete.

### Database Tables

- `mst_first_month_enrollment_discount_schedule`
- `log_first_month_enrollment_discount_apply`

### Related Files

**MBTI_backend:**
- `src/app/Services/Student/Campaign/FirstMonthEnrollmentDiscountService.php`
- `src/app/Models/MstFirstMonthEnrollmentDiscountSchedule.php`
- `src/app/GraphQL/Queries/Student/FirstMonthEnrollmentDiscount.php`

**bizmates.jp:**
- `/fuel/app/classes/model/mst/firstmonthenrollmentdiscountschedule.php`
- `/fuel/app/classes/model/FirstMonthEnrollmentDiscount.php`

---

## REST Campaign (休会キャンペーン / おかえりなさいキャンペーン)

### What is REST Status?

A REST account is one which has previously had an active, paid Online Lesson product, but currently does not.

> **Note:** A student may have FUTURE charges and still be in REST status. For example, if today is 2021/07/05 and the student has an Online Lesson charge starting 2021/08/01, they will be in REST status until 2021/08/01.

### Target: Contract Type

- B2C
- B2B2C (B2E)

### Condition

- Student is in REST status when the campaign is granted.
- Student has paid 2 or more times for an online lesson.
- At least 1 month has passed since entering REST status.
- Email notification is enabled.
- Student is not already enrolled in a REST campaign.
- Student has not used a REST campaign discount in their latest contract.
- Student does not have a charge for a future plan.

### Check: How to Verify

A student has a valid REST Campaign if they have a record in `trn_student_rest_campaign` where the current date is `>= start_date` and `<= end_date`.

### Creation

Created automatically when the `fuel/app/tasks/create_student_rest_campaign.php` task runs.

### Benefits

A student with a valid REST campaign is eligible for a **50% discount** on purchasing Online Lessons. Applies only to a new PayPal charge — cannot be used for an existing ongoing contract. Loyalty Benefits apply to REST campaign prices for at least some Online Lesson products.

### Database Tables

- `mst_rest_campaign`
- `trn_student_rest_campaign`

### Related Files

**bizmates.jp:**
- `/fuel/app/tasks/create_student_rest_campaign.php`
- `/fuel/app/classes/model/studentrestcampaign.php`
- `/fuel/app/classes/model/mst/restcampaign.php`

**MBTI_backend:**
- `src/app/Services/Student/Campaign/RestCampaignService.php`
- `src/app/Models/TrnStudentRestCampaign.php`
- `src/app/Models/MstRestCampaign.php`

---

## Coaching for Beginners (CFB)

### Target: Contract Type

- B2C
- B2B2C (B2E)

### Condition

- Student does not have an active or future coaching enrollment.
- Student does not already have a beginner and coaching package (product_id 1, 2, or 1005).

### Check: How to Verify

If the student's current plan id is `1009`.

### Creation

Start/end dates are hardcoded in `MBTI_backend/src/config/bizmatescoaching.php`.

### Benefits

Student can purchase the `beginner_package` (plan_id = 1009): Online lesson + Full Video Package + Coaching plans.

### Related Files

**MBTI_backend:**
- `src/app/Services/Student/Campaign/CoachingForBeginnersCampaignService.php`
- `src/config/bizmatescoaching.php`

---

## Coaching for Active Student

### Target: Contract Type

- B2C
- B2B (purchased as B2C)
- B2E
- B2E Partner

### Condition

- Student does not have a past, active, or future coaching plan.
- Student has an active Online Lesson plan.

### Check: How to Verify

Check if the price the student paid for plan_id 71 is half price (¥9,900 instead of ¥19,800):

```sql
SELECT *
FROM trn_student_product p
JOIN trn_charge c
  ON p.charge_id = c.id
  AND p.plan_id = 71
  AND c.paid_price = 9900
  AND c.student_id = [STUDENT-ID];
```

### Creation

Data is manually inserted into the database after receiving a request via Redmine ticket.

### Benefits

Student gets a **50% discount** for purchasing coaching plan (`plan_id = 71`).

### Database Tables

- `mst_campaign`

### Related Files

**MBTI_backend:**
- `src/app/Services/Student/Campaign/CoachingForActiveStudentCampaignService.php`

---

## B2B2C Campaign

### Target: Contract Type

- B2B
- B2B2C (B2E)

### Condition

- Student has not purchased a lesson yet (not enrolled).
- The department the student belongs to has an active campaign set from the admin panel.
- Student is not enrolled in another campaign.

### Check: How to Verify

Student should have a record in `mst_campaign` with valid date and `department_id`.

### Creation

Via Admin panel: Company Manager → 法人設定 → Click on the department → Edit → B2B2Cキャンペーン setting.

### Benefits

Student is eligible for a **50% discount** on purchasing Online Lessons.

### Database Tables

- `mst_campaign`

### Related Files

**bizmates.jp:**
- `/fuel/app/classes/libs/campaign.php`

---

## Focus Course (集中キャンペーン / フォーカスキャンペーン)

### Target: Contract Type

- Not B2B

### Condition

- Purchase date/time is inside the campaign period (with a grace period at the end).
- Student has not already purchased a product for this campaign period.
- Student does not have an ongoing or future Online Lesson product.

### Check: How to Verify

If a record exists in `trn_student_free_product_credits` with the student's `student_id` and the focus campaign's `focus_course_campaign_id`.

### Creation

Created manually by inserting data into `mst_focus_course_campaign`.

### Benefits

Students can purchase Online Lessons + 20 Lesson Tickets for a discounted price (or recently just a pack of 20 lesson tickets).

### Database Tables

- `mst_focus_course_campaign`
- `trn_student_free_product_credits` → `focus_course_campaign_id`

---

## Lesson Ticket Campaign

> **Note:** This campaign was last active in 2021 and has not been used since.

### Target: Contract Type

- Not B2B (unconfirmed)

### Condition

- Student has an active contract (`CONTRACT_STATUS_ACTIVE = 3`).
- Student has not purchased the maximum number of tickets for the campaign.

### Creation

Created by manually inserting data into the database after confirming dates and banner images with marketing.

### Benefits

Lesson tickets can be bought at a discounted price up to a certain limit (e.g., 10) by clicking on the banner.

### Database Tables

- `mst_lesson_ticket_campaign`

---

## General Notes

- Banners for all campaigns **except Focus Course** are stored in the `mst_student_banner` table (related: `mst_student_banner_target`).
- Near the end of each year, a Redmine ticket is created for the following year's campaign schedule (First Month, REST, Coaching for Active Student).

---

## Honki Set (本気セット)

**Status:** Campaign active since Jan 2026 (implemented by HCR project in MBTI_backend). Revenue proration (ASCH) in design phase within accounting system.

### What It Is

A **marketing bundle campaign** (not a product or plan) where students purchase a discounted combination of:
- Online Lessons (Daily 1, Daily 2, or Monthly 15)
- Bizmates Coaching (30-minute plan only)
- Bizmates App (free companion — ¥0 to student)

The campaign is **not a separate product** in the system. Students subscribe to each product individually; the campaign grants discounts and links them as a bundle for accounting purposes.

### Target: Contract Type

- B2C (`contract_type = 0`)
- B2E (`contract_type = 2`)
- B2E Partner (`contract_type = 2` with `department_id` in `mst_partner_department`)

**Excluded:**
- B2B (`contract_type = 1`)
- Non-Japan (`country_id ≠ 86`)

### Condition (Eligibility)

- Student has **never taken Coaching 30-min** in the past (any past Coaching experience = NOT eligible; cancellation does NOT reset eligibility).
- During the campaign application period, the student must:
  - (a) Sign up for Coaching 30-min plan, AND
  - (b) Have or newly sign up for one of the eligible Lesson plans
- Trial and REST students: eligible ONLY through "Bizmates & BCO Enroll/ReEnroll" simultaneous application (Lesson + Coaching at same time). Lesson-only or Coaching-only never qualifies.

**Eligible Lesson plans:**
- Daily 1 / Daily 2 / Daily 3 / Daily 4 / Monthly 15
- Legacy daily plans: Daily 25 / 50 / 75 / 100 minutes

**Eligible segments:**
- New customers (B2C)
- Existing Lesson students who have never taken Coaching
- Existing Coaching 15-min students (upgrading to 30-min)
- Returning students (REST — simultaneous application only)
- B2E students

**Excluded:**
- B2B (contract_type = 1)
- Overseas (country_id ≠ 86)
- Partner-company students (contract_type = 2 with department_id in {21, 22, 23})
- Students with ANY past Coaching 30-min history

**Important:** Coaching 15-min is NOT part of the bundle. Only Coaching 30-min qualifies.

### Application Period

The campaign runs quarterly. Known periods:
- Jan 2026 (first round — no proration was applied)
- Apr 2026 (second round — no proration was applied)
- 2026/7/1 – 2026/7/26 (current round — proration system being built)

### Benefit Period

6 months from application date (5 renewals after the first month).

### Benefits

| # | Benefit | Condition | Lost if... |
|---|---------|-----------|-----------|
| 1 | Month 1: Coaching 50% off | Automatic for all Honki Set members | N/A |
| 1b | Month 1: Lesson 50% off | Only for NEW Lesson contracts (existing Lesson students get Coaching discount only) | N/A |
| 2 | App free for 6 months | List price ¥3,980/month allocated for accounting | Student cancels Coaching → App lost from following month |
| 3 | Month 6: 50% off | Applies to plan active at month-6 payment date | Student cancels mid-way → permanently lost |

### Discount Interaction Rules

- **Honki Set discounts** (Coaching month-1 50%, month-6 50% for Lesson/Coaching): do NOT affect the proration basis → use List Price (L). The discount is reflected in ΣM being distributed, not in the ratio.
- **All other discounts** (First Month B2C/B2E, Okaeri/REST campaign, Loyal benefits, B2E campaign): the product's paid amount already includes the discount → use Paid Amount (M).
- **Month-1 overlap**: Both Lesson and Coaching appear 50% off, but only the Coaching discount is Honki Set. The Lesson month-1 discount is the standalone First Month campaign (non-Honki → uses M).
- **Month-6 trigger**: Coaching reaching its own month 6 (C6). Once C6 fulfilled, 50% applies to the first Lesson payment arriving after that point.
- **Priority**: Month-1/6 Honki Set 50% overrides B2E 5% and Loyal 5%/10% when they overlap (higher discount wins).

### Check: How to Verify

**Primary source (planned):** CDB project's `trn_campaign_discount_eligibility` table — one row per student × campaign × product, carrying `initial_charge_id`, `discount_flag`, `discount_eligibility_date`. ASCH snapshots these at batch run start.

**Current state (runtime):** Honki Set campaign period is identified by config ID (`utm_sources.honki_set_campaign_id` = 324) pointing to `mst_first_month_enrollment_discount_schedule`. No dedicated persisted eligibility table exists yet.

**Fallback:** If CDB not ready by 2026/10/1, ASCH falls back to self-contained cohort detection using charge/product data directly.

How ASCH will identify Honki Set members per batch run depends on CDB readiness (Open Item #7).

### Creation

Campaign is configured as a record in `mst_first_month_enrollment_discount_schedule` (ID referenced by `config('utm_sources.honki_set_campaign_id')` = 324 in MBTI_backend). Campaign period checking uses `CoachingPage::isHonkiSetCampaignPeriod()` and `AuthService::addHonkiSetCampaignIfActive()`.

Banner assets managed via `mst_student_banner` (seeder: `InsertBannerForHonkiCPSeeder` in ls-database-migrations).

### Accounting Impact (ASCH Project)

The total amount paid by the student must be split (prorated) across all 3 products based on list prices for JSOC-compliant revenue recognition:

```
O(product) = ΣM × (basis(product) / Σbasis(all products))
P(monthly) = O × (days_in_month / contract_days)
Adjustment = P − N (sent to Freee as correction journal)
```

Where:
- N = what the existing ASC system already booked for that charge
- basis = L (List Price) for products with Honki Set discounts
- basis = M (Paid Amount) for products with non-Honki discounts

**App list price:** ¥3,980 tax-included (from `mst_new_price_listing`). The App carries ¥0 in `trn_charge` (student pays nothing) but must receive allocated revenue via proration. 0-yen App charges exist in the system.

### Database Tables

| Table | Purpose | Status |
|---|---|---|
| `log_first_month_enrollment_discount_apply` | Detects First Month discount (affects proration basis) | Exists |
| `log_loyal_benefits_charge` | Detects Loyal discount (affects proration basis) | Exists |
| `trn_student_rest_history` | REST detection (Pattern 5) | Exists |

### Related Files

**MBTI_backend:**
- `src/app/GraphQL/Queries/Pages/Student/CoachingPage.php` — `isHonkiSetCampaignPeriod()` method
- `src/app/Services/Student/AuthService.php` — `addHonkiSetCampaignIfActive()`
- `src/app/Services/CoachingSoloPlanBannerEligibilityService.php` — honki set period check
- `src/config/utm_sources.php` — `honki_set_campaign_id = 324`
- `src/config/bizmatescoaching.php` — coaching plan config (plan_id, prices)

**ls-database-migrations:**
- `database/seeders/Bizmates/InsertBannerForHonkiCPSeeder.php` — banner seeder for campaign

**accounting_related_system_for_freee:**
- ASCH subsystem (in design phase — not yet implemented)

### Related Projects

- **HCR (Honki Customer Retention)** — the MBTI_backend feature that implements the campaign eligibility and frontend flow
- **ASCH (ASC Honki Set)** — the accounting system extension for revenue proration (design phase)
- **CDB (Campaign Discount Batch)** — daily batch that persists eligibility to `trn_campaign_discount_eligibility`
- **CAP (Coaching App Plan)** — bundles App with Coaching plans permanently (low overlap with ASCH)

---

## Quick Reference: Campaign Database Tables

| Campaign | Master Table | Transaction/Log Table |
|----------|-------------|----------------------|
| First Month | `mst_first_month_enrollment_discount_schedule` | `log_first_month_enrollment_discount_apply` |
| REST | `mst_rest_campaign` | `trn_student_rest_campaign` |
| Coaching for Beginners | N/A (hardcoded in config) | N/A |
| Coaching for Active Student | `mst_campaign` | N/A |
| B2B2C | `mst_campaign` | N/A |
| Focus Course | `mst_focus_course_campaign` | `trn_student_free_product_credits` |
| Lesson Ticket | `mst_lesson_ticket_campaign` | N/A |
| Honki Set | TBD | `trn_campaign_discount_eligibility` (CDB — planned) |
