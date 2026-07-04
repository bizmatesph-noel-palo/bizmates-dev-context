# Campaigns Overview

**Author:** Rashid Shamloo
**Source:** Confluence
**Verified:** 2026-07-03

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
| Honki Set | `mst_honki_set` | N/A (eligibility checked at runtime) |
