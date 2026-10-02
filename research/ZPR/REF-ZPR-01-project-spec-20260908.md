# REF-ZPR-01 — Zipan Plan & Price Revisions (upstream project spec, verbatim)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-09-08 (Received) |
| **Author (source)** | ZPR upstream team |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — upstream reference (released to production) |
| **Audience** | ASC/accounting dev team |
| **Relevance to us** | Only the new 20-lesson plan `product_id = 38` matters — add it to `ZipanMonthlyPlanEnum`. No computation change. |

> ⚠️ **Verbatim source document** from the ZPR upstream team. Preserved in full. Our accounting-system interpretation lives in `projects/zpr/`. Do not edit this content.

---

## project.md : Zipan Plan & Price Revisions (REVISED)

### 1. Overview

Expand Zipan's online-lesson catalog from a single 5-lesson/month plan to four plans (5, 10, 15, and 20 lessons/month), introduce a brand-new 20-lesson plan (`product_id = 38`), add the first-month 50% discount (Tier 2) pricing for the 10, 15, and 20-lesson plans, open the 10/15/20-lesson plans to B2C and B2E (B2B2C) students, and give B2C/B2E students a self-service plan-change feature on the student portal.

Zipan is one tenant of a shared platform. The work spans four repositories — the Zipan FuelPHP application, the centralized database migrations repo, the shared Laravel/GraphQL backend, and the shared Nuxt/Vue student portal. Every change is strictly scoped to Zipan and must not affect Bizmates Japan or Bizmates Taiwan.

Delivery follows **three phases**: **Phase 1 — Backend First**, **Phase 2 — Admin Portal**, and **Phase 3 — Final Release (Student Portal)**. There is **no beta/gradual rollout** — once the final release is deployed, all features and final pricing become immediately effective for all Zipan B2C/B2E students in production. The pricing effective-date strategy is confirmed as **Option B — new pricing applies immediately after release**.

> **REVISION NOTE**: This document supersedes the original `zipan-plan-price-revisions-project.md`. Key changes: (1) Beta feature mechanism (`enable_beta`) completely removed — no gradual rollout. (2) Phases reduced from 4 to 3. (3) Final pricing applied in Phase 1 (no separate beta/final pricing split). (4) Solo lesson ticket price updated in Phase 1.

> **Confirmed facts** used throughout this document:
> 20-lesson plan = `product_id = 38` / `plan_id = 38` (`月20回プラン`, `20 lessons / month plan`);
> Zipan plan IDs `16` (5L), `17` (10L), `18` (15L), `38` (20L) — each `plan_id` matches its `product_id`;
> **Final pricing** (tax-exclusive base): 5L T1 = ¥13,500 / T2 = ¥6,750; 10L T1 = ¥22,700 / T2 = ¥11,350; 15L T1 = ¥32,400 / T2 = ¥16,200; 20L T1 = ¥42,000 / T2 = ¥21,000;
> **Solo lesson ticket**: ¥1,800 → ¥2,273 (tax-excl), ¥1,980 → ¥2,500 (tax-incl);
> Package prices: 10L ¥22,700, 15L ¥32,400, 20L ¥42,000;
> 5-lesson plan visibility: hidden from Plan Page and Plan Change modal for new B2C/B2E; remains for existing subscribers and B2B Admin Portal;
> Zipan pricing discriminator = `price_flag = 2`, `country_id = 86` (Japan).

### 2. Current State

Zipan currently offers a single online-lesson plan to B2C students — the 5-lesson/month plan (`product_id = 16`, `plan_id = 16`). Products `17` (10 lessons) and `18` (15 lessons) already exist in `mst_product`, but they have **no** `mst_plan` / `mst_plan_content` records and **no** Tier 2 (first-month discount) pricing rows, so they are not selectable through the student portal. There is no 20-lesson product at all.

- **Charge batch (recurring billing)**: `zipan/fuel/app/tasks/charge.php` — PayPal recurring transaction batch. Prices renewals generically from `mst_new_price_listing`.
- **Plan change API (existing)**: `zipan/fuel/app/classes/controller/api/students/plan.php` (`Controller_Api_Students_Plan`) already implements `post_change`, `post_reset`, and `get_estimate`, with an admin branch — but the Zipan catalog only exposes the 5-lesson plan.
- **Order / ticket orchestration**: `Order` (`change`, `pay`, `stop`, `cancelChange`, `estimate`, `makeRefreshCharge`) and `TicketManager` (`expire`, `distribute`) under `zipan/fuel/app/classes/libs/`.
- **Shared backend**: `MBTI_backend` (Laravel + Lighthouse GraphQL). Zipan plan availability is served by `App\Services\Student\Plan\PlanServiceForZipan`, injected for the Zipan tenant via `config/dependencyInjection.php`. Today `getAvailableOnlineLessonPlans()` returns only the 5-lesson plan.
- **Shared frontend**: `MBTI_frontend` (Nuxt 2 / Vue 2). The plan page is at `src/pages/MyBizmates/student/plan/index.vue` → `Plan.vue` → `PlanUsageStatus.vue`, which renders `<PlanChangeStatus v-if="$isBizmates()" />` inside a `CONTRACT_STATUS_ACTIVE` block. No Zipan plan-change UI exists yet.

### 3. User Stories

| # | Role | Story |
|---|------|-------|
| 1 | B2C / B2E Student | See the 10, 15, and 20-lesson plans as selectable options so I can pick a plan that fits my learning goals |
| 2 | Zipan Student | See both the regular price and the first-month 50% discount price for every plan before subscribing |
| 3 | B2C / B2E Student | Change my subscription plan from the student portal (e.g. 5 → 15 lessons) immediately, paying only the prorated difference |
| 4 | B2C / B2E Student | See the prorated breakdown (credit for unused days, amount due now) before confirming a plan change |
| 5 | B2C / B2E Student | Cancel a future-dated scheduled plan change before its cancellable deadline (Admin-Portal-scheduled case) |
| 6 | System Operator | Have the charge batch correctly bill the new 20-lesson plan and updated pricing on renewal |
| 7 | Administrator | Bulk-assign compensation lesson tickets to a list of student IDs |
| 8 | Administrator | Manage plan pricing entries and plan availability from the Admin Portal |
| 9 | Administrator | Change a student's plan from the Admin Portal (B2B and assisted B2C/B2E), with PayPal RT or bank settlement |

### 4. Functional Requirements

#### 4.1 Plan Catalog Expansion

- Zipan offers four online-lesson plans: 5 (`product_id = 16`), 10 (`17`), 15 (`18`), and 20 (`38`) lessons/month.
- B2C (`contract_type = 0`) and B2E / B2B2C (`contract_type = 2`) students see the 10L, 15L, and 20L plans on the student portal. The 5L plan is **hidden from the Plan Page and Plan Change modal** for all B2C/B2E students upon release — no gradual rollout.
- B2B (`contract_type = 1`) subscriptions are handled **exclusively via the Admin Portal**; B2B plan selection is never exposed through the student-portal-facing API.
- Existing 5L subscribers continue service and billing unaffected. B2B assignments of the 5L plan via the Admin Portal remain available.
- The 20-lesson plan enforces the existing concurrent-booking limit (`lesson_in_day = 1`).
- All four Zipan monthly plans follow the no-carryover rule: unused lesson tickets expire at the end of each subscription period (product IDs 16, 17, 18, 38).

#### 4.2 Pricing

- All Zipan prices are read exclusively from `mst_new_price_listing` rows where `price_flag = 2` and `country_id = 86`.
- Each plan returns both **Tier 1** (regular) and **Tier 2** (first-month 50% discount).
- **Final pricing** (tax-exclusive, applied in Phase 1):

| Plan | `product_id` | Tier 1 (regular) | Tier 2 (first month) | Action |
|------|--------------|------------------|----------------------|--------|
| 5 lessons | 16 | ¥13,500 | ¥6,750 | UPDATE T1 + UPDATE T2 |
| 10 lessons | 17 | ¥22,700 | ¥11,350 | UPDATE T1 + INSERT T2 |
| 15 lessons | 18 | ¥32,400 | ¥16,200 | UPDATE T1 + INSERT T2 |
| 20 lessons | 38 | ¥42,000 | ¥21,000 | INSERT Tier 1 + Tier 2 |

- **Solo Lesson Ticket Price** (updated in Phase 1):
  - Old: ¥1,800 (tax-excl) / ¥1,980 (tax-incl)
  - New: ¥2,273 (tax-excl) / ¥2,500 (tax-incl)
- Prices displayed to students are tax-inclusive.
- If a price row is missing or `status != 1`, the system returns null/zero and logs a warning.
- New pricing applies immediately after release (Option B).

#### 4.3 Self-Service Plan Change (B2C / B2E — Student Portal, Phase 3)

The student plan change replicates the **Bizmates prorated approach exactly** (`Order::estimate()`), for **both upgrades and downgrades**. It is an **immediate, mid-cycle** change effective on the change date.

- A Zipan-specific mutation (`zipanPlanChange`) lets a B2C or B2E student change to any of the three available target plans (10, 15, 20 lessons) other than their current one. The 5-lesson plan is **not** offered as a plan change target.
- **Proration formula (mirrors Bizmates `Order::estimate()` exactly):**
  - `contract_total_days`, `consumed_days`, `rest_days`, `rest_price`, `to_price`, `total_price` computed per the canonical algorithm.
  - On confirmation: `Order::estimate()` → `Order::change()` → `Order::pay()`.
  - B2B rejected; invalid/same product rejected; negative `total_price` rejected.
  - All writes transaction-wrapped.
- `canPlanChangeProduct` query returns valid targets (excludes current + 5L).
- `zipanPlanChangeEstimate` read-only query returns the prorated breakdown for the confirm step.
- Bizmates BPV/video and FLP-15 branches do **not** apply to Zipan.
- **Optional future-dated scheduling** (Admin-Portal-driven only): `refresh_charge_id`, `zipanCancelPlanChange`, and `refresh_charge` object in plan query.

#### 4.4 Student Portal UI (Phase 3)

- The plan page shows the three purchasable plans (10, 15, 20 — Tier 1 + Tier 2 from the API) to all B2C/B2E Zipan students unconditionally. The 5L plan is **not** shown.
- Prices are **never hardcoded** — all amounts come from the API.
- `PlanChangeStatus_Zipan` component with Edit → Confirm → Success/Error modal flow.
- Cancel flow appears **only** when a future-dated `refresh_charge` is present.
- MyStage dashboard banner promotes the 20-lesson plan.
- All new UI text uses WOVN translation keys.
- All new components under `src/zipan/`; GraphQL under `src/graphql/zipan/`.

#### 4.5 Charge Batch (Phase 1)

- Retrieves correct `sales_price` for all four plans from `mst_new_price_listing`.
- Missing price row → log error, skip that student's renewal (no ABEND).

#### 4.6 Admin Portal (Phase 2)

- **Plan & pricing management:** display, edit (with audit), and toggle plan availability.
- **Admin plan change:** future-dated, immediate+PayPal RT, immediate+bank. `get_estimate`, `tax_free`, `new_price` override, cancel, admin notification emails.
- **Bulk lesson ticket assignment:** `bulkGrantZipanLessonTickets`.

#### 4.7 Supporting Changes

- **Existing-user transition:** bulk compensation tickets via Admin Portal. Customer notification emails are **not in scope**.

### 5. Data Model Changes

All schema is **data-only** (INSERT/UPDATE) owned by `ls-database-migrations`. No new columns, no new tables. The `refresh_charge_id` column already exists on `trn_student_product`.

#### 5.1 New `mst_product` row (20-lesson plan)

| Column | Value |
|--------|-------|
| `product_id` | `38` |
| `name` / `name_en` | `月20回プラン` / `20 lessons / month plan` |
| `lesson_volume` | `20` |
| `lesson_in_day` | `1` |
| `product_type` | `1` (Skype) |
| `lesson_type` | `2` (monthly) |

#### 5.2 New `mst_plan` + `mst_plan_content` rows

| `plan_id` | `product_id` | `name` / `name_en` | `package_price` |
|-----------|--------------|--------------------|-----------------|
| 17 | 17 | `月10回プラン` / `10 lessons / month plan` | 22,700 |
| 18 | 18 | `月15回プラン` / `15 lessons / month plan` | 32,400 |
| 38 | 38 | `月20回プラン` / `20 lessons / month plan` | 42,000 |

#### 5.3 Pricing rows (`mst_new_price_listing`, `price_flag = 2`, `country_id = 86`)

| `product_id` | `tier` | `price` | Action |
|--------------|--------|---------|--------|
| 16 (5L) | 1 | 13,500 | UPDATE |
| 16 (5L) | 2 | 6,750 | UPDATE |
| 17 (10L) | 1 | 22,700 | UPDATE |
| 17 (10L) | 2 | 11,350 | INSERT |
| 18 (15L) | 1 | 32,400 | UPDATE |
| 18 (15L) | 2 | 16,200 | INSERT |
| 38 (20L) | 1 | 42,000 | INSERT |
| 38 (20L) | 2 | 21,000 | INSERT |

#### 5.4 GraphQL contract (MBTI_backend → MBTI_frontend)

```graphql
# Student queries
zipan_pricing_page: ZipanPricingPage!          # { tax_rate, plans:[ZipanPlanPrice] }
zipan_plan_page_info: ZipanPlanPageInfo!
zipan_can_plan_change_product: CanPlanChangeProductInfo
zipan_plan_change_estimate(product_id: Int!, charge_type: Int, start_date: Date): ZipanPlanChangeEstimate!

# Student mutations
zipanPlanChange(product_id: Int!, charge_type: Int): ZipanPlanChangeResult!
zipanCancelPlanChange: Result!

# Admin mutations (admin-guarded)
bulkGrantZipanLessonTickets(student_ids: [Int!]!, quantity: Int!): ZipanBulkGrantResult!
```

> Note: `beta_enabled` field removed from `ZipanPricingPage` type — no longer applicable.

### 6. Affected Components

| Repository | File / Area | Change |
|------------|-------------|--------|
| `ls-database-migrations` | `database/seeders/Zipan/*` | 5 seeders (product 38, plans 17/18/38, final pricing) |
| `zipan` (FuelPHP) | `fuel/app/classes/controller/api/students/plan.php` | Admin plan-change path |
| `zipan` | `fuel/app/classes/model/ticketModel.php` | `LESSON_TICKET_PRICE` 1800 → 2273 |
| `zipan` | `fuel/app/classes/libs/order.php` | `tax_free` threading |
| `zipan` | `fuel/app/classes/model/planModel.php` | 20T constants + product→plan mapping |
| `zipan` | `fuel/app/tasks/charge.php` | Missing-price guard |
| `zipan` | `fuel/app/classes/libs/service/planAvailability.php` | **Remove beta gate** — return plans unconditionally for B2C/B2E |
| `zipan` | `fuel/app/classes/model/studentothersetting.php` | **Remove `isBetaEnabled()` / `setBeta()` methods** |
| `zipan` | `fuel/app/tests/model/studentOtherSettingTest.php` | **Remove beta-related tests** |
| `zipan` | `fuel/app/tests/libs/service/planAvailabilityTest.php` | **Remove beta-gated test logic** |
| `zipan` | Admin views | Plan-change screen, pricing screen, bulk-ticket UI |
| `MBTI_backend` | `App\Services\Student\Plan\PlanServiceForZipan` | **Remove `ZipanBetaGate` injection** — return 10L/15L/20L unconditionally for B2C/B2E |
| `MBTI_backend` | `App\Zipan\Services\ZipanBetaGate.php` | **DELETE this file entirely** |
| `MBTI_backend` | `App\Zipan\Services\ZipanPricingService` | Price scoping (unchanged) |
| `MBTI_backend` | `App\Zipan\Services\ZipanPlanChangeService` | Plan-change writes (unchanged) |
| `MBTI_backend` | New `App\Zipan\GraphQL\*` resolvers | Remove `beta_enabled` from pricing page response |
| `MBTI_backend` | `App\Models\MstProduct` | Constants + `getDailyPlans()` (unchanged) |
| `MBTI_backend` | `src/graphql/Types/Zipan/*` | Remove `beta_enabled` field from `ZipanPricingPage` type |
| `MBTI_frontend` | `src/zipan/components/student/plan/*` | Plan components (no beta-gate logic needed) |
| `MBTI_frontend` | `src/zipan/components/HomeMainContents.vue` | MyStage banner (no beta check) |
| `MBTI_frontend` | `src/graphql/zipan/*` | Remove any `beta_enabled` field consumption |

### 7. Edge Cases & Constraints

- **Tenant isolation (hard constraint):** all new code under `App\Zipan\` / `src/zipan/`.
- **No beta gate / no gradual rollout:** all plans visible to all B2C/B2E students immediately.
- **B2B routing:** Admin-Portal-only; student-portal rejects with authorization error.
- **Missing/inactive price row:** null/zero + warning log (never ABEND).
- **No hardcoded prices/strings in frontend:** all from API; WOVN keys for text.
- **Atomicity:** all plan-change and cancel writes transaction-wrapped.
- **Booking & no-carryover:** enforced generically for all four plans.

### 8. Success Metrics

- Adoption of 10/15/20-lesson plans by B2C/B2E students.
- Plan-change usage (requests, completions, cancellations).
- Accurate renewal billing (zero ABENDs / pricing mismatches).
- No regressions to Bizmates Japan / Bizmates Taiwan.

### 9. Out of Scope

- **Beta feature mechanism** (`enable_beta` flag, `ZipanBetaGate`, gradual rollout) — completely removed from the project. All features go live for all students at once.
- **Terms of Service and FAQ updates** — handled separately.
- **Sales reporting and KPI metrics** — handled separately.
- **Customer notification emails and website announcements** — handled outside this spec.
- **Grace period / temporary price freeze** — not applicable (immediate release).
- Database schema changes (new columns/tables) — none required.
- Credit-card settlement in Admin Portal — Zipan uses PayPal RT and bank only.
- Mobile (SP) banner/cover display on login flow.
- Any modification of Bizmates Japan / Bizmates Taiwan behavior.

### 10. Beta Feature Removal — Code Impact Tracker

The following files contain `enable_beta` / `ZipanBetaGate` / `isBetaEnabled` logic that must be removed or refactored as part of this revision:

#### MBTI_backend

| File | Action |
|------|--------|
| `src/app/Zipan/Services/ZipanBetaGate.php` | **DELETE** entire file |
| `src/app/Services/Student/Plan/PlanServiceForZipan.php` | Remove `ZipanBetaGate` import/injection; return plans unconditionally |
| `src/app/Zipan/GraphQL/Queries/ZipanPricingPage.php` | Remove beta gate check; always return all plans |
| `src/graphql/Types/Zipan/zipan_pricing.graphql` | Remove `beta_enabled: Boolean!` field from `ZipanPricingPage` type |
| `src/tests/Unit/Zipan/*` | Remove beta-gated property tests (Property 1 beta branch, Property 2) |

#### Zipan (FuelPHP)

| File | Action |
|------|--------|
| `fuel/app/classes/model/studentothersetting.php` | Remove `ENABLE_BETA_ON`, `isBetaEnabled()`, `setBeta()` |
| `fuel/app/classes/libs/service/planAvailability.php` | Remove beta check; always return `[17, 18, 38]` for B2C/B2E |
| `fuel/app/tests/model/studentOtherSettingTest.php` | Remove all beta-related test methods |
| `fuel/app/tests/libs/service/planAvailabilityTest.php` | Remove beta-gated test logic |

#### MBTI_frontend

| File | Action |
|------|--------|
| Any component reading `beta_enabled` from API | Remove the conditional; always show full plan catalog |

### Notes

#### Phasing (revised — 3 phases)

| Phase | Focus | Key deliverables |
|-------|-------|------------------|
| Phase 1 — Backend First | DB + APIs + charge batch + final pricing | 5 seeders with **final prices**; `PlanServiceForZipan` returns 10L/15L/20L unconditionally for B2C/B2E (no beta gate); pricing API; `product_id = 38` support; `LESSON_TICKET_PRICE = 2273`; booking & no-carryover verification |
| Phase 2 — Admin Portal | Internal tools | Pricing management UI; admin plan-change; `bulkGrantZipanLessonTickets` |
| Phase 3 — Final Release (Student Portal) | Student-facing features | `zipanPlanChange` / `zipanCancelPlanChange`; `refresh_charge` in plan query; `canPlanChangeProduct`; pricing page; plan-change UI + cancel; MyStage banner; WOVN keys |

#### Key references

- Zipan pricing discriminator: `price_flag = 2`, `country_id = 86` (Japan).
- **No beta gate** — plans visible to all B2C/B2E students unconditionally.
- Plan change: immediate, mid-cycle **prorated** change (mirrors Bizmates `Order::estimate()`).
- Future-dated scheduled change (Admin-Portal only): `refresh_charge_id` → pending `trn_charge`.
- Contract types: B2C = `0`, B2B = `1`, B2B2C / B2E = `2`.
- Effective date: Option B — apply immediately after release.
- Final pricing: 5L T1 ¥13,500 / T2 ¥6,750; 10L T1 ¥22,700 / T2 ¥11,350; 15L T1 ¥32,400 / T2 ¥16,200; 20L T1 ¥42,000 / T2 ¥21,000.
- Solo lesson ticket: ¥2,273 (tax-excl) / ¥2,500 (tax-incl).
- 5L plan: hidden from Plan Page and Plan Change modal for B2C/B2E; remains for existing subscribers and B2B Admin Portal.
