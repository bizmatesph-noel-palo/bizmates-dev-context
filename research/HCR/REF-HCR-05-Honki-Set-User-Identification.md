# Honki Set User Identification — Technical Proposal

**Author:** Francis Nikko V. Perez
**Type:** Reference — HCR project technical proposal
**Source:** Confluence (HCR project space)

---

## Introduction

This document is a technical proposal for the "Honki Set" user identification batch task (`honki_set_user_identification`). It covers the proposed implementation of eligibility logic, database design, and open design decisions that need confirmation before finalizing.

### Scope Clarification

The purpose of this batch task is to determine which students are **active Honki Set participants who still have the cashback benefit at stake**. When `eligible = 1`, the frontend shows a warning notification when the student attempts to rest or cancel, alerting them they will lose the 1-month cashback offer.

The Honki Set campaign also includes a free 6-month Bizmates App subscription, but that is granted at enrollment and is not forfeitable.

**The three states:**
- `trn_honki_set_eligibility.eligible = 1` → student is an active Honki Set participant, still in the benefit period → show warning notification
- `trn_honki_set_eligibility.eligible = 0, reason = "Completed"` → student completed 6 months of continuous subscription, earned the cashback → no warning needed
- `trn_honki_set_eligibility.eligible = 0, reason = forfeiture reason` → student forfeited (rested, canceled, downgraded, etc.) → no warning, benefits lost

The actual cashback grant is a separate manual process managed via `trn_student_eligible_cashback` by admin CSV upload. This batch task does NOT directly grant cashback.

---

## 1. Eligibility Logic

### Overview

The batch task runs daily and performs the following for each candidate student:
1. Did the student purchase Coaching 30m + Online Lesson within the campaign window? → If yes, insert with `eligible = 1` (active participant from day one)
2. On subsequent runs, has the student broken their streak? (rest, cancel, gap, downgrade) → If yes, set `eligible = 0` with forfeiture reason
3. Has the student completed 6 months of continuous subscription? → If yes, set `eligible = 0` with `reason = "Completed"` (earned the benefit, no warning needed)

While `eligible = 1`, the student sees the warning notification. Once `eligible = 0` (for any reason), the notification stops.

### Candidate Identification Queries

Two query strategies are used to find candidates, because bundle plans and separate purchases have different data structures in `trn_charge`.

#### Strategy A: Bundle Purchase (plan_id 1010 or 1011)

Students who purchased a bundle plan that includes both Online Lesson and Coaching 30-min in a single charge record.

```sql
SELECT DISTINCT
    c.student_id,
    c.plan_id,
    c.start_date AS coaching_applied_date,
    'bundle' AS purchase_type
FROM trn_charge c
INNER JOIN trn_student s ON s.student_id = c.student_id
WHERE c.plan_id IN (1010, 1011)
  AND c.paid = 1
  AND c.status = 1
  AND c.start_date BETWEEN '2026-04-01' AND '2026-04-26'
  AND s.contract_type != 1   -- Exclude B2B only (B2C=0 and B2B2C=2 are eligible)
  AND c.rest_flag = 0
  AND c.canceled = 0
  AND c.paid_price < c.sales_price  -- Campaign discount purchases only
```

- `plan_id 1010` = Online Lesson 25-min + Coaching 30-min bundle
- `plan_id 1011` = Online Lesson 50-min + Coaching 30-min bundle
- A single charge record covers both products, so the query is straightforward

#### Strategy B: Separate Purchase (Online Lesson + Coaching 30 standalone)

Students who purchased Online Lesson and Coaching 30-min as separate charges.

```sql
SELECT DISTINCT
    ol.student_id,
    ol.plan_id AS lesson_plan_id,
    co.plan_id AS coaching_plan_id,
    co.start_date AS coaching_applied_date,
    'separate' AS purchase_type
FROM trn_charge ol
INNER JOIN trn_charge co ON ol.student_id = co.student_id
INNER JOIN trn_student s ON s.student_id = ol.student_id
INNER JOIN mst_product mp ON mp.product_id = ol.product_id
WHERE mp.product_type = 1          -- Online Lesson
  AND ol.paid = 1 AND ol.status = 1
  AND ol.start_date BETWEEN '2026-04-01' AND '2026-04-26'
  AND co.product_id = 10015        -- Coaching 30
  AND co.paid = 1 AND co.status = 1
  AND co.start_date BETWEEN '2026-04-01' AND '2026-04-26'
  AND s.contract_type != 1         -- Exclude B2B only
  AND ol.rest_flag = 0 AND ol.canceled = 0
  AND co.rest_flag = 0 AND co.canceled = 0
  AND ol.plan_id NOT IN (1010, 1011)  -- Bundles already covered by Strategy A
  AND co.paid_price < co.sales_price  -- Campaign discount purchases only
```

- Self-joins `trn_charge` to match Online Lesson and Coaching 30 charges for the same student
- Joins `mst_product` to identify Online Lesson by `product_type`
- Excludes bundle plans (1010, 1011) since those are handled by Strategy A

#### Why Two Strategies?

Bundle plans and separate purchases have different data structures in `trn_charge`:
- **Bundle (1010, 1011):** A single charge record covers both products → can identify by `plan_id` alone
- **Separate:** Online Lesson and Coaching 30 are in separate charge records → requires a self-join

Results are merged in PHP using `student_id` as the key, with bundle results taking priority to avoid duplicates.

### Continuity Check Logic

After candidates are identified, we verify 6 months of continuous subscription:
1. Fetch charge history from `coaching_applied_date` (initial purchase date) to `target_date`
2. Check consecutive charge pairs for gaps > 1 day between `end_date` and next `start_date`
3. Check for `rest_flag = 1`, `canceled = 1`, or `paid = 0` in any charge record
4. Count months from first charge `start_date` to `target_date`

Both Online Lesson and Coaching 30 are checked independently. If either has an issue, the student is forfeited.

### Forfeiture Conditions

| Condition | How It's Detected | reason Value |
|-----------|-------------------|-------------|
| REST application | `trn_student_product.no_refresh = 1` | "REST gap" |
| REST/Cancel flag | `trn_charge.rest_flag = 1` or `canceled = 1` | "REST gap" |
| Charge gap | Gap > 1 day between consecutive charges | "REST gap" |
| Plan downgrade | Current coaching charge `plan_id` not in Coaching 30 plans list (94, 1010, 1011, 1012, 1013, 1014) | "Plan downgrade" |
| Lost Online Lesson | No active Online Lesson charge during tracking period | "No lesson plan" |

Forfeiture is irreversible. Once a student has `eligible = 0` and `reason IS NOT NULL`, they are skipped on subsequent batch runs. Note that "Completed" is also a terminal state — a student who completed 6 months no longer needs re-evaluation.

---

## 2. Database Table Design

### Current DDL: trn_honki_set_eligibility

```sql
CREATE TABLE trn_honki_set_eligibility (
    id                    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id            BIGINT NOT NULL,
    campaign_period       VARCHAR(7) NOT NULL DEFAULT '2026-04',
    coaching_applied_date DATE NOT NULL,
    campaign_pattern      VARCHAR(50) NOT NULL,
    eligible              TINYINT NOT NULL DEFAULT 0,
    reason                VARCHAR(255) NULL,
    last_checked_at       TIMESTAMP NOT NULL,
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_student_campaign (student_id, campaign_period),
    INDEX idx_student_eligible (student_id, eligible),
    FOREIGN KEY (student_id) REFERENCES trn_student(student_id)
);
```

### Field-by-Field Review

| Field | Purpose | Assessment |
|-------|---------|-----------|
| `student_id` | Identifies the student | ✅ Sufficient |
| `campaign_period` | Identifies which campaign (e.g. "2026-04") | ✅ Sufficient |
| `coaching_applied_date` | When coaching was first purchased | ✅ Sufficient |
| `campaign_pattern` | How they purchased (bundle_1010, bundle_1011, separate_lesson_coaching) | ✅ Sufficient |
| `eligible` | 0 or 1 | ✅ Sufficient |
| `reason` | Forfeiture reason or NULL | ✅ Sufficient |
| `last_checked_at` | When the batch last evaluated this student | ✅ Sufficient |
| `created_at` / `updated_at` | Standard timestamps | ✅ Sufficient |

### Potential Fields to Add

#### a) `continuous_months` (Continuous Month Count)

| Aspect | Detail |
|--------|--------|
| Type | TINYINT NOT NULL DEFAULT 0 |
| Purpose | Store how many months the student has been continuously subscribed so far |
| Benefit | Admin dashboards can show progress (e.g. "4 of 6 months complete") without re-querying charge history |
| Drawback | Needs to be updated on every batch run. Additional calculation logic |
| Recommendation | Add if admin dashboard progress display is needed |

#### b) `eligible_at` (Eligibility Timestamp)

| Aspect | Detail |
|--------|--------|
| Type | TIMESTAMP NULL |
| Purpose | Record when `eligible` was set to 1 |
| Benefit | Cashback processing can immediately reference when the student became eligible |
| Recommendation | Add if cashback processing needs precise timing |

#### c) `forfeited_at` (Forfeiture Timestamp)

| Aspect | Detail |
|--------|--------|
| Type | TIMESTAMP NULL |
| Purpose | Record when forfeiture was detected |
| Benefit | Support inquiries can immediately answer "when did they lose eligibility?" |
| Recommendation | Add if support operations need this information |

#### d) `initial_charge_id` (Initial Charge Reference)

| Aspect | Detail |
|--------|--------|
| Type | BIGINT NULL |
| Purpose | Store the `trn_charge.id` of the qualifying purchase |
| Benefit | Direct traceability to the original purchase for auditing |
| Recommendation | Optional. Only if strict audit requirements exist |

### 🔴 Decisions Needed
- Add `continuous_months` field?
- Add `eligible_at` / `forfeited_at` timestamps?

---

## 3. Price Verification at Purchase Time

### The Question
Should we verify that a student purchased at the campaign discount price (50% off) rather than full price?

### Current Implementation
We check `trn_charge.paid_price < trn_charge.sales_price` on the initial charge.

### Three Approaches Compared

#### Option A: `paid_price < sales_price` (Current Implementation)

```sql
AND c.paid_price < c.sales_price
```

| Aspect | Detail |
|--------|--------|
| How it works | `sales_price` always stores the full price. `paid_price` stores the actual amount paid. If discounted, `paid_price < sales_price` |
| Pros | Simple single WHERE condition. Covers ALL campaign types (FirstMonthEnrollment, Rest, ActiveStudent). No extra JOINs needed |
| Cons | Could match non-Honki discounts (e.g. loyalty benefits, B2B2C contract type discounts). Does not distinguish which campaign gave the discount |
| Reliability | High — the price columns are always populated during the payment flow |

#### Option B: Verify via Campaign Log Tables

| Aspect | Detail |
|--------|--------|
| How it works | JOIN against `log_first_month_enrollment_discount_apply` (for FirstMonthEnrollment), `trn_campaign_apply` (for Rest/other campaigns), `log_reenrollment` (for REST-type campaigns) |
| Pros | Precisely identifies which campaign was applied. No false positives from other discount types |
| Cons | **ActiveStudent campaign does NOT persist to any database table** — it only uses BizmatesCache (temporary). So this approach cannot cover all campaign types. Requires complex multi-table JOIN or UNION |
| Reliability | Incomplete — misses ActiveStudent campaign entirely |

#### Option C: No Price Verification

| Aspect | Detail |
|--------|--------|
| How it works | Any purchase of qualifying plans within the campaign window qualifies, regardless of price paid |
| Pros | Simplest implementation. No edge cases around discount detection |
| Cons | Would include students who purchased at full price during the campaign window but were not part of the Honki Set promotion |

**Recommendation:** Option A is recommended. Option B is incomplete because the ActiveStudent campaign doesn't persist to any database table. Option C risks including full-price purchasers who weren't part of the promotion. Option A covers all campaign types and keeps the implementation simple.

### 🔴 Decision Needed
Should a student who purchased Coaching 30m + Lesson within the campaign window at full price (no discount) be considered Honki Set eligible?
- Yes → Option C (remove price check entirely)
- No, and `paid_price < sales_price` is sufficient → Option A (keep current implementation)
- No, and we need exact campaign verification → Need to address the ActiveStudent campaign logging gap first (Option B)

---

## 4. Campaign Period: Static Dates vs Dynamic

Campaign dates are hardcoded as class constants:
```php
const CAMPAIGN_START = '2026-04-01';
const CAMPAIGN_END = '2026-04-26';
const CAMPAIGN_PERIOD_KEY = '2026-04';
```

### Alternative: Dynamic Dates from `mst_first_month_enrollment_discount_schedule`

The `mst_first_month_enrollment_discount_schedule` table already stores campaign periods with `start_datetime` and `end_datetime`. The CoachingPage already uses this table via `config('utm_sources.honki_set_campaign_id')` to determine `isHonkiSetCampaignPeriod()`.

### Comparison

| Aspect | Static Constants | Dynamic from DB |
|--------|-----------------|-----------------|
| Simplicity | ✅ Very simple, no DB query needed | Requires querying `mst_first_month_enrollment_discount_schedule` at startup |
| Maintainability | ❌ Requires code change + deployment for each new campaign | ✅ New campaigns can be configured via DB/admin without code changes |
| Multi-campaign support | ❌ Only supports one campaign at a time | ✅ Can process multiple campaign periods by iterating over active schedules |
| Risk | Low — dates are explicit and auditable | Low — but depends on correct data in the schedule table |
| Existing pattern | Other batch tasks use hardcoded dates | CoachingPage already reads from this table dynamically |

**Recommendation:** If Honki Set campaigns will recur with different dates, dynamic is recommended. The `trn_honki_set_eligibility` table's unique key `(student_id, campaign_period)` already supports multiple campaigns, so no table design changes are needed.

### 🔴 Decision Needed
Should campaign dates remain hardcoded, or be read from `mst_first_month_enrollment_discount_schedule`?
- One-time campaign → Static constants are fine
- Recurring campaigns → Dynamic approach recommended

---

## Summary of Decisions Needed

| # | Decision | Options | Current Default |
|---|----------|---------|-----------------|
| 1 | Verify discount price at purchase? | (A) `paid_price < sales_price`, (B) Campaign log tables, (C) No verification | A — `paid_price < sales_price` |
| 2 | Static or dynamic campaign dates? | Static constants vs. `mst_first_month_enrollment_discount_schedule` | Static constants |
| 3 | Add `continuous_months` field to table? | Yes / No | No (not currently in DDL) |
| 4 | Add `eligible_at` / `forfeited_at` timestamps? | Yes / No | No (not currently in DDL) |

---

## ASCH Relevance

This document details the eligibility logic and `trn_honki_set_eligibility` table design. Key implications for ASCH:

- `campaign_pattern` values confirm purchase structure: `bundle_1010`, `bundle_1011`, `separate_lesson_coaching`
- Bundle plan_ids (1010, 1011) map to specific lesson+coaching combinations
- Separate purchases use `product_id = 10015` for Coaching 30 and `product_type = 1` for Online Lesson
- Forfeiture is irreversible — once `eligible = 0` with a reason, the student is in a terminal state
- The `continuous_months` field (if added) could help ASCH determine which month of the 6-month window a student is in
