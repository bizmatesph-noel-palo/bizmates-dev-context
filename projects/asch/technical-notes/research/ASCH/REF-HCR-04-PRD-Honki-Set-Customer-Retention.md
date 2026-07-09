# PRD: Honki Set Customer Retention

**Author:** Soli Sahukar
**Type:** Reference — HCR project PRD
**Source:** Confluence (HCR project space)

---

## 1. Overview

### 1.1 Project Name
Honki Set Customer Retention (本気セット休会時のコミュニケーション改善)

### 1.2 Business Objective
Reduce the withdraw rate (離脱率 / churn rate) among "Honki Set" users by displaying a warning when they attempt to cancel their Online Lesson or Bizmates Coaching subscription within six months of their Honki Set purchase. The warning informs them they will forfeit their 1-month cashback benefit if they proceed.

### 1.3 Background
The "Honki Set" is a marketing package (not a system-level product) consisting of Online Lesson + Bizmates Coaching 30分 + Bizmates App. Students who purchase both Online Lesson and Bizmates Coaching 30分 between 2026-04-01 and 2026-04-26 are eligible for two benefits:

- A free 6-month Bizmates App subscription (added manually by admin)
- A 1-month cashback after maintaining continuous subscription for 6 months

The cashback benefit is forfeited if the student cancels (rests) either their Online Lesson or Coaching plan before completing 6 continuous months.

### 1.4 Scope
- **In scope:** Warning display on the Inquiry page and Rest Request pages (Online Lesson + Coaching) in the MBTI frontend; backend eligibility batch and API; database table
- **Out of scope:** Admin Portal changes; Bizmates App subscription management; actual cashback processing; legacy FuelPHP Inquiry page (contact.twig)

---

## 2. User Stories

| ID | Role | Story | Acceptance Criteria |
|----|------|-------|---------------------|
| US-1 | Student (Honki Set purchaser) | As a Honki Set student, when I visit the Inquiry page and click a rest/cancellation link, I want to see a warning that I will lose my cashback benefit | Warning modal appears before navigation to rest request page |
| US-2 | Student (Honki Set purchaser) | As a Honki Set student, when I land on the Online Lesson rest request page, I want to see a warning banner about losing my cashback | Warning banner is visible at the top of RestRequestOnline edit form |
| US-3 | Student (Honki Set purchaser) | As a Honki Set student, when I land on the Coaching rest request page, I want to see a warning banner about losing my cashback | Warning banner is visible at the top of RestRequestCoaching edit form |
| US-4 | System | As the system, I want to identify Honki Set eligible students via a daily batch job and store their eligibility in a database table | Batch runs daily; trn_honki_set_eligibility table is populated/updated |
| US-5 | System | As the system, I want to expose a GraphQL query that returns whether the logged-in student is Honki Set eligible | is_honki_set_eligible query returns true/false |
| US-6 | Student (non-Honki Set) | As a student who did NOT purchase the Honki Set, I want the Inquiry and rest request pages to behave exactly as they do today | No warning is shown; no behavioral changes |

---

## 3. Technical Architecture

### 3.1 Architectural Decision: Batch over Runtime

The eligibility check uses a daily batch task that pre-computes results into a lookup table, rather than running the complex Metabase query at runtime. This follows the existing `trn_student_eligible_cashback` pattern used for cashback notifications.

**Rationale:**
- The Metabase query has 5 CTEs, window functions (ROW_NUMBER, LAG), and multiple correlated subqueries — too expensive for per-request execution
- Eligibility changes only when charges are processed (monthly billing), so daily freshness is sufficient
- The campaign window (2026-04-01 to 2026-04-26) bounds the eligible student set to a small, finite number
- Precedent: TrnStudentEligibleCashback model + CashbackNotification resolver uses the same batch-then-lookup pattern

---

## 4. Detailed Requirements

### 4.1 Database: trn_honki_set_eligibility Table

**Repository:** bizmatesinc/MBTI_backend

```sql
CREATE TABLE trn_honki_set_eligibility (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      BIGINT NOT NULL,
    campaign_period VARCHAR(7) NOT NULL DEFAULT '2026-04',
    coaching_applied_date DATE NOT NULL,
    campaign_pattern VARCHAR(50) NOT NULL,
    eligible        TINYINT NOT NULL DEFAULT 0,   -- 0 = not eligible, 1 = eligible
    reason          VARCHAR(255) NULL,             -- reason if not eligible
    last_checked_at TIMESTAMP NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_student_campaign (student_id, campaign_period),
    INDEX idx_student_eligible (student_id, eligible),
    FOREIGN KEY (student_id) REFERENCES trn_student(student_id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
```

A corresponding raw SQL file should also be created in bizmatesinc/bizmates.jp under `database/01.structure/`.

### 4.2 Backend: Eloquent Model

**File:** `MBTI_backend/src/app/Models/TrnHonkiSetEligibility.php`

```php
class TrnHonkiSetEligibility extends Model
{
    protected $table = 'trn_honki_set_eligibility';
    protected $fillable = [
        'student_id', 'campaign_period', 'coaching_applied_date',
        'campaign_pattern', 'eligible', 'reason', 'last_checked_at',
    ];
    const NOT_ELIGIBLE = 0;
    const ELIGIBLE = 1;
}
```

Also add a relationship on TrnStudent:

```php
public function trn_honki_set_eligibility(): HasOne
{
    return $this->hasOne(TrnHonkiSetEligibility::class, 'student_id');
}
```

### 4.3 Backend: Batch Command

**File:** `MBTI_backend/src/app/Console/Commands/HonkiSetEligibilityBatch.php`
**Signature:** `honki-set:check-eligibility`

**Logic:**
- Translates the provided Metabase SQL into a raw DB query
- For each student identified: compute the "Final Status"
- Upsert into `trn_honki_set_eligibility` with `eligible = 1` if status is "Eligible", `eligible = 0` otherwise (with reason populated)

**Scheduling:** Register in Kernel.php to run daily at 06:00 JST (after the nightly charge batch):
```php
$schedule->command('honki-set:check-eligibility')->dailyAt('06:00');
```

**Simplification:** The batch does NOT need to produce the full Metabase report output. It only needs to determine per-student:
1. Did the student purchase Coaching 30m + Lesson in the campaign window (2026-04-01 to 2026-04-26)?
2. Are they still within their 6-month benefit period?
3. Have they maintained continuous subscription (no gaps > 1 day, no plan downgrades from 30m)?

If all three are true → `eligible = 1`.

### 4.4 Backend: GraphQL Query

**Schema File:** `MBTI_backend/src/graphql/Types/Student/honki_set.graphql`

```graphql
extend type Query @guard {
    is_honki_set_eligible: Boolean!
        @field(resolver: "Student\\HonkiSetWarning@isHonkiSetEligible")
}
```

**Resolver File:** `MBTI_backend/src/app/GraphQL/Queries/Student/HonkiSetWarning.php`

```php
class HonkiSetWarning
{
    public function isHonkiSetEligible($_, array $args, GraphQLContext $context): bool
    {
        $student = $context->user;
        return (int) optional($student->trn_honki_set_eligibility)->eligible
            === TrnHonkiSetEligibility::ELIGIBLE;
    }
}
```

This is a single indexed lookup — O(1) at runtime.

### 4.5 Frontend: Inquiry Page Warning Modal

**Affected files:**
- `MBTI_frontend/src/components/pages/student/BizmatesInquiry.vue`
- `MBTI_frontend/src/components/pages/student/inquiry-links/JapanInquiryLinks.vue`
- New: `MBTI_frontend/src/components/modal/ModalHonkiSetWarning.vue`

**Behavior:**
- Fetch eligibility: Add a GraphQL call to `is_honki_set_eligible` during `beforeCreate()`
- Pass prop: Pass `isHonkiSetEligible` as a prop to JapanInquiryLinks
- Intercept links: When `isHonkiSetEligible === true`, intercept clicks on rest/cancellation links
- Show modal: Display ModalHonkiSetWarning with warning text and two buttons: "Continue to cancellation" and "Go back"

**Warning text (draft):**
> 【ご注意ください】
> お客様は「本気セット」キャンペーンの対象です。
> 休会・退会のお手続きをされますと、1ヶ月分キャッシュバック特典が受けられなくなります。
> 本当にお手続きを続けますか？

### 4.6 Frontend: Rest Request Page Warnings

As a secondary safeguard (students can navigate directly to these URLs), add a warning banner on the rest request pages themselves.

- **Online Lesson Rest (RestRequestOnline.vue):** Fetch `is_honki_set_eligible` during `beforeCreate()`. If eligible, show a non-blocking warning banner above the questionnaire form.
- **Coaching Rest (RestRequestCoaching.vue):** Same pattern.

The warning does NOT block submission — it is informational only.

---

## 5. Non-Functional Requirements

| Requirement | Detail |
|-------------|--------|
| Performance | Runtime eligibility check must be a single indexed DB lookup (< 5ms). No complex queries at page load. |
| Data freshness | Daily batch is sufficient. Eligibility changes only on monthly charge events. |
| Backward compatibility | No changes to existing rest request submission logic. Warning is informational only — students can still proceed. |
| Scope limitation | Japan-only (country_id = 86), B2C/B2E only (contract_type <> 1). |
| Campaign extensibility | The campaign_period column allows reuse for future Honki Set campaigns without schema changes. |
| Legacy system | The FuelPHP Inquiry page (contact.twig) is out of scope for this phase. |

---

## 6. Test Plan

### 6.1 Backend Unit Tests

**GraphQL resolver tests:**

| Test Case | Setup | Expected |
|-----------|-------|----------|
| Eligible student | `trn_honki_set_eligibility.eligible = 1` | `is_honki_set_eligible = true` |
| Not eligible student | `trn_honki_set_eligibility.eligible = 0` | `is_honki_set_eligible = false` |
| No record exists | No row in `trn_honki_set_eligibility` | `is_honki_set_eligible = false` |

**Batch command tests:**

| Test Case | Setup | Expected |
|-----------|-------|----------|
| New enrollment, 6 continuous months | Student with coaching + lesson charges, no gaps | `eligible = 1` |
| Gap > 1 day in subscription | Student with a rest period > 1 day | `eligible = 0, reason = "REST gap"` |
| Plan downgrade from 30m | Student switched from 30m to 15m coaching | `eligible = 0, reason = "Plan downgrade"` |
| Missing lesson plan | Student has coaching but no lesson for 6 months | `eligible = 0, reason = "No lesson plan"` |
| B2B student excluded | B2B student with coaching + lesson | No row created |
| Outside campaign window | Purchase on 2026-04-27 | No row created |

---

## 7. Work Breakdown

| Phase | Task | Repository |
|-------|------|-----------|
| Data Layer | Create migration + raw SQL | MBTI_backend, bizmates.jp |
| Data Layer | Create Eloquent model | MBTI_backend |
| Data Layer | Create FuelPHP model | bizmates.jp |
| Data Layer | Add TrnStudent relationship | MBTI_backend |
| Batch | Create Artisan command | MBTI_backend |
| Batch | Register in scheduler | MBTI_backend |
| Batch | Write batch unit tests | MBTI_backend |
| API | Create GraphQL schema | MBTI_backend |
| API | Create resolver | MBTI_backend |
| API | Extend rest request types (optional) | MBTI_backend |
| API | Write resolver unit tests | MBTI_backend |
| Frontend - Inquiry | Create warning modal component | MBTI_frontend |
| Frontend - Inquiry | Fetch eligibility + pass prop | MBTI_frontend |
| Frontend - Inquiry | Intercept rest links with modal | MBTI_frontend |
| Frontend - Rest Pages | Add warning banner to online rest | MBTI_frontend |
| Frontend - Rest Pages | Add warning banner to coaching rest | MBTI_frontend |
| Frontend - Rest Pages | Write frontend tests | MBTI_frontend |

---

## 8. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Batch fails silently | Eligible students not warned | Add logging, monitoring, and alerting. Include a health check that verifies the batch ran within the last 24 hours. |
| Student cancels between batch runs | Student cancels before batch marks them ineligible | Acceptable: the warning is a retention tool, not a hard block. Daily is sufficient. |
| Campaign period changes | New Honki Set campaign with different dates | The campaign_period column and configurable date range allow easy extension. |
| Legacy Inquiry page not covered | Students on the old FuelPHP page don't see warnings | Out of scope for Phase 1. The FuelPHP model is created for future use. |

---

## 9. Open Questions

1. **Warning copy:** The exact Japanese warning text needs to be finalized with the marketing team.
2. **Withdrawal link:** Should the warning also intercept the "退会のお手続き" (withdrawal) Zendesk link on the Inquiry page, or only the rest (休会) links?
3. **Legacy page:** Is there a timeline for covering the FuelPHP Inquiry page (contact.twig) as well?
4. **Feature flag:** Should this feature be behind a feature flag for gradual rollout?
5. **Batch initial run:** The batch needs to be run manually once before the scheduled daily runs begin, to populate the table for existing Honki Set purchasers.

---

## ASCH Relevance

This PRD defines the `trn_honki_set_eligibility` table that ASCH may use as a source for identifying Honki Set members. The table answers "who is a Honki Set member and are they still active?" — which is Step 1 of ASCH's pipeline. See `RESEARCH-03-CDB-Shared-Table-Analysis.md` for the gap analysis.
