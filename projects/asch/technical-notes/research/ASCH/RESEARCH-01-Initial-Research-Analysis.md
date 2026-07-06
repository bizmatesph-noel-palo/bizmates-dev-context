# ASCH — Honki Set Revenue Allocation: Technical Research Report (20260703)

**Project:** ASCH (ASC Honki Set)  
**JIRA Key:** ASCH (TBA — project not yet created)  
**Related Project:** [ASC](https://bizmates.atlassian.net/browse/ASC) (Accounting System for Freee)  
**Prepared by:** Noel Palo  
**Date prepared:** 2026-07-03  
**Sources:** MOM 2026-07-02 (Kuroda, Patrick, Throy, Glenn) + Confluence documentation + Kuroda-san's project brief  
**Status:** Research complete — full specification received from Kuroda-san (REF_09). Ready for design phase.

---

## 1. Executive Summary

The ASCH project extends the existing ASC accounting batch system to handle **revenue allocation for the Honki Set bundled discount campaign**. Unlike standard monthly-plan charges where one charge maps to one product, Honki Set involves a single discounted payment covering three products (Online Lesson + Coaching + Bizmates App). Accounting requires each product to carry a non-zero allocated sales value — even the "free" app.

This report consolidates findings from the July 2 kickoff meeting and existing Confluence documentation to provide the team with a shared understanding of what ASCH will likely involve, what we know today, and what gaps remain before design can begin.

**Key finding:** The core challenge is a **proportional revenue allocation** step that does not exist in the current ASC system. This is architecturally new — not a variation of the existing daily/monthly rate logic.

**Critical clarification (from Kuroda-san):** Honki Set is NOT a plan or product — it is a marketing campaign. There is no dedicated `product_id` for "Honki Set" in `trn_charge`. Identification of campaign participants must come from campaign rules, not product type.

---

## 2. Background & Context

### Purpose of This Research

The Honki Set campaign launched July 1, 2026. The accounting team needs revenue allocation data for bundled plans — a capability that does not exist in the current accounting system. Before the ASCH project formally begins (requirements, design, implementation), the team conducted advance research to:

1. **Learn what Honki Set is today** — how the campaign works, who qualifies, what products are bundled, and where the data lives (currently in MBTI_backend only)
2. **Understand the accounting gap** — why bundled plans break ASC's one-charge-one-product assumption, and what proportional allocation means for revenue recognition
3. **Map the existing campaign infrastructure** — which tables, services, and eligibility mechanisms Honki Set piggybacks on, and how those relate to what the accounting system can query
4. **Surface design risks early** — identify complexity (multiple patterns, conditional discounts, external vs Honki Set discounts), limitations (no campaign marker on `trn_charge`), and architectural questions (parallel output vs replacement of existing ASC calculations) before committing to a design direction

### Relationship to ASC

| Aspect | ASC | ASCH |
|--------|-----|------|
| Scope | Monthly plan revenue recognition | Bundle campaign revenue allocation |
| Input | `trn_charge` (one charge = one product) | `trn_charge` (one payment = three products) |
| Calculation | Daily pro-rata OR ticket consumption | Price-ratio allocation THEN daily/monthly rate |
| Output | Daily CSV, Monthly CSV, Freee journals | New separate Honki Set CSV + Freee journals |
| Timeline | In production since 2021, actively maintained | New — July 2026 kickoff |

ASCH will live in the same `accounting_related_system_for_freee` repository, extending the existing ASC codebase with new artisan commands. It produces its own isolated CSV output separate from the existing daily/monthly CSVs.

---

## 3. Current State: What Honki Set IS Today

### 3.1 Campaign Definition

Honki Set (本気セット) is a bundled discount campaign where students purchase:

| Product | Eligibility Requirement |
|---------|------------------------|
| Online Lessons | Daily 1, Daily 2, or 15 Lessons/month plan |
| Bizmates Coaching | 30-minute plan only (15-min not eligible) |
| Bizmates App | Free companion access (bundled at no charge to student) |

> ⚠️ **Honki Set is not a plan or product; it is a marketing campaign.** (Confirmed by Kuroda-san's project brief.) There is no `product_id` representing "Honki Set" — the system must identify participants through campaign rules and timing, not product type.

**Bundle condition:** Students must purchase BOTH an eligible lesson plan AND 30-minute coaching during the campaign period to receive benefits.

### 3.2 Campaign Benefits

- **Month 1:** 50% discount on first payment
- **Month 6:** 50% discount (conditional on 6 consecutive active months)

### 3.3 Continuity Rules

- Students must maintain both Online Lesson and Coaching continuously for 6 months
- Any "rest" (suspension) between months 1–6 **permanently forfeits** the 6th-month discount
- Re-subscribing after suspension does NOT reinstate eligibility
- Benefits are tied to the initial purchase during the campaign period only

### 3.4 Current Campaign Period

- Start: July 1, 2026
- End: October 27/31, 2026

### 3.5 Target Cohorts & Eligibility Rules

**General Rules:**
- Honki Set Campaign must be active (within campaign period defined in `mst_honki_set`)
- Uses existing campaign mechanisms as entry gates (not a new eligibility system)
- Student must take lessons within the Honki Set Campaign period

**Eligible Cohorts (entry paths):**

| # | Cohort | Entry Campaign | Contract Types | Discount | Key Table |
|---|--------|---------------|----------------|----------|-----------|
| 1 | B2E First Month | First Month Enrollment Discount | B2C | 50% off Online Lessons | `mst_first_month_enrollment_discount_schedule` |
| 2 | Active Coaching | Coaching for Active Student | B2C, B2B (as B2C), B2E, B2E Partner | 50% off Coaching (plan_id=71, ¥9,900 vs ¥19,800) | `mst_campaign` |
| 3 | REST | REST Campaign | B2C, B2E | 50% off Online Lessons (re-enrollment) | `mst_rest_campaign` / `trn_student_rest_campaign` |

> ⚠️ **Discrepancy to confirm:** The First Month Campaign (REF_07) targets **B2C** students only. However, the Honki Set cohort is called "B2E First Month." This needs clarification — does First Month also cover B2E students (undocumented in REF_07), or does the Honki Set eligibility extend it?

> 💡 **Terminology & Contract Types (confirmed from code):**
>
> | Business Term | Code Constant | `contract_type` value | How Identified | Payment Route |
> |--------------|---------------|----------------------|----------------|--------------|
> | **B2C** | `CONTRACT_TYPE_PRIVATE` | `0` | `contract_type = 0` | Individual → Bizmates |
> | **B2B** | `CONTRACT_TYPE_B2B` | `1` | `contract_type = 1` | Company → Bizmates |
> | **B2E** | `CONTRACT_TYPE_B2B2C` | `2` | `contract_type = 2` AND dept NOT in `mst_partner_department` | Individual → Bizmates |
> | **B2E Partner** | `CONTRACT_TYPE_B2B2C` | `2` | `contract_type = 2` AND dept IS in `mst_partner_department` | Individual → Partner Company → Bizmates |
>
> **Source:** `[MBTI] app/Models/TrnStudent.php` — constants and `isPartner()` method  
> **Source:** `[Migrations] database/seeders/MstPartnerDepartmentTableSeeder.php`
>
> **Key details:**
> - B2E and B2E Partner share the same `contract_type = 2`. The distinction is whether the student's `department_id` exists in `mst_partner_department`.
> - Partner companies (from seeder): department_id 1 (東京インターカレッジコープ), 21 (ベネフィット・ワン), 22 (えらべる倶楽部), 23 (株式会社イーウェル)
> - B2E Partner students do NOT purchase on the Student Portal plan page — payment routes through the partner company. This may affect how their charges are structured in `trn_charge`.
> - `TrnStudent.isPartner()`: `return $this->isB2B2C() && $this->mst_partner_department()->get()->isNotEmpty();`

**Exclusions:**
- B2B students (`contract_type=1`) are excluded
- Non-Japan students (`country_id≠86`) are excluded (from HCR eligibility rules)

**Continuity detection:**
- Consecutive charges: a charge where prior charge's `end_date = start_date - 1 day` is a renewal
- No gap > 1 day between consecutive charge periods = continuous subscription

### 3.6 How Entry Campaigns Work (from REF_07)

Each entry cohort uses an existing campaign mechanism with its own verification method:

**First Month Enrollment Discount:**
- Created manually — dates inserted into DB via yearly Redmine ticket
- Verified via `log_first_month_enrollment_discount_apply` joined with `trn_charge` (charge must be active: `start_date <= NOW() AND end_date >= NOW()`)
- Service: `FirstMonthEnrollmentDiscountService.php`

**REST Campaign:**
- Created automatically by `create_student_rest_campaign.php` batch task
- Verified via `trn_student_rest_campaign` where current date is between `start_date` and `end_date`
- Conditions: student in REST status, paid ≥2 times, ≥1 month in REST, email enabled, no existing campaign
- Service: `RestCampaignService.php`

**Coaching for Active Student:**
- Created manually — data inserted via Redmine ticket
- Verified by checking if student paid half-price for plan_id 71 (¥9,900 instead of ¥19,800)
- Conditions: no past/active/future coaching plan, must have active Online Lesson plan
- Service: `CoachingForActiveStudentCampaignService.php`

### 3.7 Current Technical Implementation (MBTI_backend only)

| Component | Location | Purpose |
|-----------|----------|---------|
| `mst_honki_set` table | Database | Campaign config (dates, plan IDs, cohort flags, banners, tier) |
| `MstHonkiSet` model | `[MBTI] app/Models/MstHonkiSet.php` | Eloquent model with `getActiveCampaign()`, `isPlanEligible()` |
| `HonkiSetService` | `[MBTI] app/Services/` | Eligibility checking across 3 cohorts (waterfall: first_month → rest → active_coaching) |
| HCR Eligibility API | `[MBTI] app/GraphQL/` | GraphQL query for churn-prevention warning modal (5-CTE SQL) |
| Eligible plan IDs | `mst_honki_set.plan_ids` | JSON array — currently `[1010, 1011]` (coaching plans) |
| Tier | `mst_honki_set.tier` | Pricing tier (2 = `PLAN_TIER_HALF_PRICE` = 50% discount) |

**Eligibility check flow (from REF_06 — `HonkiSetService.checkEligibility()`):**
1. Check if `mst_honki_set` has an active campaign for current date
2. Check if the plan is eligible (`plan_ids` JSON contains the plan_id)
3. Waterfall through cohorts (first_month → rest → active_coaching) based on enabled flags
4. Return campaign info with cohort identifier, or null if not eligible

**Key fact:** No accounting system integration exists today. The existing implementation handles student-facing eligibility and churn prevention only. ASCH is the project to build the accounting layer.

---

## 4. Problem Statement

### The Accounting Gap

Per Kuroda-san's project brief: the App is provided at no extra charge to bundle members, but from an accounting perspective, the entire bundle revenue cannot be treated as Lesson revenue alone. The total sales amount must be allocated across Lesson, Coaching, and App so that monthly revenue is recognized correctly.

The current ASC system assumes **one charge = one product**. It reads `paid_price` from `trn_charge` and applies either:
- Daily rate formula: `paid_price × days_used / days_in_period`
- Monthly rate formula: `paid_price × tickets_consumed / total_tickets`

Honki Set breaks this assumption:
- **One discounted payment** covers **three products** (lesson + coaching + app)
- The Bizmates App is "free" to the student but **cannot be zero** from an accounting perspective
- The total paid amount must be **proportionally allocated** across all three products before any daily/monthly rate logic applies

This proportional allocation step does not exist anywhere in the current ASC codebase.

---

## 5. Findings: Revenue Allocation Logic

### 5.1 Pattern 1 — Baseline: Same Start Date (from MOM + Project Brief + Google Sheet)

**Pattern 1** signifies that the Lesson and Coaching components start on the exact same date (月初 = 1st of month). This is the simplest scenario.

**Scenario:** B2C new enrollment, same start date, month-start  
**Reference:** [Honki Set Allocation Google Sheet](https://docs.google.com/spreadsheets/d/1NoaaoTNX8a-enGql_qZdGke8MofQX8AHThNF6XB0Sgk/edit?gid=824143910#gid=824143910)  
**Detailed data:** `[asch] technical-notes/research/ASCH/REF-ASCH-00_PATTERNS_Case1_Data.md`

**Product prices (standard / list):**
- Lesson Daily 1: ¥13,500/month
- Coaching 30 Min: ¥36,000/month
- App: ¥3,600/month (student pays ¥0)

**The 4-step allocation formula:**

```
Step 1: Determine ratio base per product
  IF product has an EXTERNAL discount (not from Honki Set):
    ratio_base = Paid Amount
  ELSE:
    ratio_base = List Price

Step 2: Calculate ratio
  ratio(product) = ratio_base(product) / sum(all ratio_bases)

Step 3: Allocate total paid
  consumed_price(product) = total_paid × ratio(product)

Step 4: Prorate by session usage
  accounting(product) = consumed_price × sessions / contract_days
```

**Month 1 example (discount month):**
- Total paid = ¥24,750 (Lesson ¥6,750 + Coaching ¥18,000 + App ¥0)
- Ratio bases: Lesson ¥6,750 (paid, external discount) + Coaching ¥36,000 (list) + App ¥3,600 (list) = ¥46,350
- Allocated: Lesson ¥3,604, Coaching ¥19,223, App ¥1,922 = ¥24,750 total ✓

### 5.2 Ratio Base Discrepancy — RESOLVED by Google Sheet Notes

The MOM noted that Online Lesson uses a discounted paid amount while Coaching and App use standard list price. The Google Sheet notes now explain WHY:

> **Note K4:** "Strictly speaking, this 50% discount on the lesson fee is not part of this Honki-set campaign. It is a lesson-specific discount that is applied only in the first month when the student starts that lesson."

**This answers the stacking question definitively:**
- The month-1 **Lesson 50% discount** comes from the **First Month Enrollment Campaign** (entry cohort) — it is EXTERNAL to Honki Set
- The month-1 and month-6 **Coaching 50% discount** IS the Honki Set campaign discount
- Because the Lesson discount is external, its ratio base uses **Paid Amount** (post-discount)
- Because the Coaching discount is from Honki Set, its ratio base uses **List Price** (pre-discount)

**Rule:** Products with external (non-Honki Set) discounts → use Paid Amount as ratio base. Products with Honki Set discounts → use List Price as ratio base.

**Key implication:** The system must distinguish which discount applies to which product. This is not just "is there a discount?" — it's "is the discount from Honki Set or from another campaign?"

### 5.3 Daily Rate After Allocation

After the allocation step, daily rate evaluation follows existing ASC logic:
- `Allocated amount ÷ total days in contract period × lesson/session counts`
- Similar to the current ASC project's daily rate calculation (referred to as "A project" in the MOM — likely shorthand for ASC)

### 5.4 Multiple Patterns (Not Yet Explained)

Kuroda-san's project brief refers to "Pattern 1" specifically — implying there are additional patterns. The MOM confirmed these will be explained in a follow-up meeting. Pattern 1 = same start date for Lesson and Coaching. Other patterns likely involve:

- **Different start dates** — Lesson and Coaching begin on different days (period boundary mismatch)
- Student rests mid-period → how to handle already-allocated revenue
- Student downgrades one product but keeps another
- Refund within Honki Set bundle
- Cross-boundary periods (campaign starts mid-month)
- Interaction with other concurrent campaign discounts
- Month 6 conditional discount: separate charge or retroactive adjustment?

**Confidence:** "Pattern 1 = same start date" is confirmed from Kuroda-san's brief. Other patterns are inferred — actual cases will come from the follow-up meeting.

---

## 6. Impact Analysis

### 6.1 Confirmed Scope (from Kuroda-san's project brief)

| Deliverable | Description | Source |
|-------------|-------------|--------|
| Calculate monthly allocated sales | Proportional split of bundle payment across 3 products | Confirmed (project brief) |
| Export CSV files for accounting | Separate from existing daily/monthly CSVs — Honki Set only | Confirmed (project brief) |
| Prepare summary data for Freee linkage | Accounting journal data for Freee system | Confirmed (project brief) |

### 6.2 Likely Technical Deliverables (Inferred)

| Deliverable | Description | Confidence |
|-------------|-------------|------------|
| New artisan command(s) | Batch processing for Honki Set calculations | Inferred (matches ASC pattern) |
| New log table(s) | Store allocated values per product per student per month | Inferred (project brief mentions "new ASCH tables if needed") |

### 6.3 Data Sources (Confirmed)

Per Kuroda-san's project brief:
- Existing ASC data (from `accounting_related_system_for_freee`)
- MBTI backend data (from `MBTI_backend` — where charges originate)
- New ASCH tables if needed (to be defined)

### 6.4 Repository Impact

| Repo | Expected Impact | Confidence |
|------|----------------|------------|
| `[ASC]` accounting_related_system_for_freee | **Primary.** New command(s), calculation logic, CSV generation | High |
| `[Migrations]` ls-database-migrations | New migration(s) for log table(s) | High |
| `[MBTI]` MBTI_backend | Read-only reference — Honki Set data originates here | Medium |
| `[Admin]` bizmates.jp | Unlikely unless admin needs Honki Set accounting management | Low |

### 6.5 Comparison: ASC vs ASCH Architecture

| Aspect | ASC (Monthly Plan) | ASCH (Honki Set) |
|--------|-------------------|------------------|
| Input | One charge → one product | One payment → three products |
| Calculation | Ticket consumption / daily pro-rata | Price-ratio allocation → THEN daily/monthly rate |
| Products per charge | 1 | 3 (lesson + coaching + app) |
| Discount handling | `paid_price` from `trn_charge` is final | Must decompose discounted bundle into per-product values |
| Campaign awareness | None — processes any charge blindly | Must identify Honki Set campaign charges specifically |
| Output | Existing daily/monthly CSVs | New separate CSV |
| Freee integration | Shared account codes | TBD — may need new account codes |

---

## 7. Open Questions & Risks

### 7.1 Blocking Questions (must answer before design)

| # | Question | Needed From | Risk if Unanswered | Status |
|---|----------|-------------|-------------------|--------|
| 1 | Where do Honki Set charges live in `trn_charge`? Is there a campaign marker/flag, or must we cross-reference `mst_honki_set` dates + eligible plan IDs? | Kuroda-san / DB investigation | Cannot identify target data | ⚠️ Kuroda-san confirmed "exact entry conditions still being confirmed" |
| 2 | What is the `product_id` for the Bizmates App? Does it appear in `trn_charge`? | Kuroda-san | Cannot allocate to 3rd product | 🔲 Open |
| 3 | Where are standard (non-discounted) sales prices stored? (`mst_product`? `mst_plan`?) | DB investigation | Cannot compute ratios | 🔲 Open |
| 4 | What are the other patterns beyond Pattern 1 (different start dates, rest, refund)? | Kuroda-san (next meeting) | Incomplete requirements | 🔲 Open |
| 5 | ~~Is the Honki Set 50% discount the SAME mechanism as the entry campaign's 50% discount, or a separate/additional discount?~~ | ~~Kuroda-san~~ | ~~Fundamentally affects the allocation formula's "total paid" input~~ | ✅ ANSWERED — They are separate. Lesson discount = First Month campaign (external). Coaching discount = Honki Set. |
| 6 | First Month Campaign targets B2C (`contract_type=0`) per REF_07, but Honki Set cohort is called "B2E First Month." Does First Month also cover B2E (`contract_type=2`) students? | Kuroda-san | Affects which students are in scope | ⚠️ Discrepancy identified |

### 7.2 Important Questions (answer before implementation)

| # | Question | Needed From |
|---|----------|-------------|
| 7 | Does Honki Set need new entries in `config/code.php` (Freee journal account code mappings) for the App product, or does it reuse existing Lesson/Coaching codes? | Kuroda-san / Accounting team |
| 8 | Forward-looking only (July 2026+), or must handle historical data? | Kuroda-san |
| 9 | ~~How do other general campaign discounts interact with Honki Set ratios?~~ | ~~Kuroda-san~~ | ✅ ANSWERED — External campaign discounts use Paid Amount as ratio base; Honki Set discounts use List Price. Same interaction pattern as existing ASC system. (See [Section 5.2](#52-ratio-base-discrepancy--resolved-by-google-sheet-notes)) |
| 10 | How does the 6th-month conditional discount affect allocation? (Separate charge? Retroactive adjustment? HCR doc calls it "1-month cashback") | Kuroda-san |
| 11 | The `mst_honki_set.plan_ids` stores `[1010, 1011]` — are these the coaching plan IDs only? Where are the lesson plan IDs tracked? | DB investigation |
| 12 | Are Honki Set students already processed by the current ASC daily/monthly CTE? If so, do we need to exclude them or is ASCH an additional overlay? | Code investigation | ⚠️ Partially answered — Google Sheet column N shows "Current sales calculated by ASC program," confirming ASC already processes these charges. ASCH appears to be a **parallel/replacement** calculation, not additive. |

### 7.3 Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| "Other patterns" significantly change the architecture | High — could require redesign | Wait for Kuroda-san's full explanation before committing to design |
| No clear campaign marker on `trn_charge` | Medium — complex identification logic | Investigate DB structure early; may need to replicate HCR's 5-CTE identification approach |
| Entry campaign discount vs Honki Set discount ambiguity | ~~High~~ → Resolved | ✅ Confirmed separate: Lesson discount = external (First Month), Coaching discount = Honki Set. Ratio formula uses different bases accordingly. |
| Ratio formula edge cases (rounding, zero-price products) | Medium — accounting precision issues | Define rounding rules with accounting team |
| Interaction with existing ASC exclusions (monthly plans already excluded from daily) | Low-Medium — potential double-processing | Verify Honki Set charges aren't already captured by ASC monthly CTE |
| Cohort contract type mismatch (B2C `contract_type=0` vs B2E `contract_type=2`) | Low — but affects scope | Confirm with Kuroda-san which contract types qualify for each cohort |

---

## 8. Recommendations

1. **Do not begin design until all patterns are explained.** Pattern 1 (same start date) is simple ratio math, but other patterns (different start dates, rest, refund) will determine whether we need a simple lookup table or a stateful calculation engine.
2. **Investigate `trn_charge` structure early.** Since Honki Set is a campaign (not a product), there may be no direct marker on charges. Understanding how to identify participants is the single most important architectural decision. This can be done in parallel with waiting for Pattern 2+.
3. **Clarify isolation from existing ASC.** Confirm that Honki Set charges are NOT already being processed by the monthly/daily CTE pipelines. If they are, we need an exclusion strategy (similar to how monthly plans were excluded from daily).

---

## 9. References

| Document | Location |
|----------|----------|
| ASCH Specification (Kuroda-san — full spec) | `[asch] technical-notes/research/ASCH/REF-ASCH-00_PRJ_Specification.md` |
| ASCH — Revenue Allocation for Bundled Plans (Kuroda-san) | `[asch] technical-notes/research/ASCH/REF-ASCH-00_PRJ_Brief_Kuroda.md` |
| MOM: ASC for Honkiset Discussion (2026-07-02) | `[asch] technical-notes/research/ASCH/REF-ASCH-01_MOM_20260702_Honkiset_Discussion.md` |
| Pattern 1 (Case 1) Data & Formula Derivation | `[asch] technical-notes/research/ASCH/REF-ASCH-00_PATTERNS_Case1_Data.md` |
| HCR — Honki Set Customer Retention: Project Overview | `[asch] technical-notes/research/ASCH/REF-HCR-00_Customer_Retention_Overview.md` |
| Honki Set (本気セット) Campaign Implementation | `[asch] technical-notes/research/ASCH/REF-HCR-01_Campaign_Implementation.md` |
| mst_honki_set Design and Implementation | `[asch] technical-notes/research/ASCH/REF-HCR-02_mst_honki_set_Design.md` |
| Honki Set Eligibility Checker | `[asch] technical-notes/research/ASCH/REF-HCR-03_Eligibility_Checker.md` |
| Campaigns Overview (all campaign types) | `[asch] technical-notes/research/ASCH/REF-DOC-01_Campaigns.md` |
| Account Types (Contract Types) | `[asch] technical-notes/research/ASCH/REF-DOC-02_Account_Types.md` |
| Honki Set Allocation Google Sheet | [Google Sheets](https://docs.google.com/spreadsheets/d/1NoaaoTNX8a-enGql_qZdGke8MofQX8AHThNF6XB0Sgk/edit?gid=824143910#gid=824143910) |
| ASC Session Context | `[ascm] project-context.md` |
| ASC Knowledge Base — Design Context | `[ascm] knowledge-base/00_Design_Context.md` |

---

## Appendix A: Architecture Diagram (Current + Planned)

```
┌─────────────────────────────────────────────────────────┐
│                    MBTI_backend                          │
│                                                         │
│  mst_honki_set ─── HonkiSetService ─── Eligibility API │
│       │                    │                            │
│       │            ┌───────┴────────┐                   │
│       │            │                │                   │
│  Campaign Config   Cohort Checks    HCR Modal           │
│  (dates, plans,    (FirstMonth,     (churn prevention)  │
│   cohort flags)    Rest, Active)                        │
│                                                         │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ Charges created in trn_charge
                            ▼
┌─────────────────────────────────────────────────────────┐
│           accounting_related_system_for_freee            │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │              CURRENT (ASC)                       │    │
│  │  DailyRateCalculation ──► Daily CSV             │    │
│  │  MonthlyRateCalculation ──► Monthly CSV         │    │
│  │  SendJournalsData ──► Freee API                 │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │              NEW (ASCH) — To Be Built            │    │
│  │                                                  │    │
│  │  1. Identify Honki Set charges                   │    │
│  │  2. Revenue Allocation (price-ratio split)       │    │
│  │  3. Daily/Monthly rate on allocated amounts      │    │
│  │       │                                          │    │
│  │       ▼                                          │    │
│  │  log_honki_set_calculation ──► Honki Set CSV     │    │
│  │       │                                          │    │
│  │       ▼                                          │    │
│  │  Freee Journal Sync (account codes TBD)          │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Appendix B: Campaign Infrastructure Map (ASCH-Relevant)

Summary of campaign tables and verification methods that ASCH may need to query for identifying Honki Set participants:

| Campaign | Master Table | Log/Transaction Table | Verification Method |
|----------|-------------|----------------------|-------------------|
| First Month Enrollment | `mst_first_month_enrollment_discount_schedule` | `log_first_month_enrollment_discount_apply` | JOIN `trn_charge` where `start_date <= NOW() AND end_date >= NOW()` |
| REST | `mst_rest_campaign` | `trn_student_rest_campaign` | Record exists with `start_date <= NOW() AND end_date >= NOW()` |
| Coaching for Active Student | `mst_campaign` | — | Check `trn_charge` where `plan_id=71 AND paid_price=9900` (half price) |
| **Honki Set** | `mst_honki_set` | — | Runtime eligibility check in `HonkiSetService` (waterfall through 3 cohorts) |

**Key insight for ASCH:** There is no single "Honki Set participant" flag on `trn_charge`. The HCR project (REF_03) uses a 5-CTE SQL query to determine eligibility at runtime. ASCH will likely need a similar approach — or may need to create a snapshot/log table that records which students are confirmed Honki Set members for each batch period.

**Banner note:** Banners for all campaigns except Focus Course are stored in `mst_student_banner` (related: `mst_student_banner_target`).

---

*Report created: 2026-07-03*  
*Last updated: 2026-07-03*  
*Status: Research complete — full specification received (REF-ASCH-00_PRJ_Specification). Project moves to design phase.*
