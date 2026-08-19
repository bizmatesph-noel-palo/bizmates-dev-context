# ASCH — Honki Set Revenue Proration Batch: Specification

**Author:** Hayato Kuroda  
**Source:** Confluence (shared 2026-07-03)  
**Scope:** Campaign rules, target students, proration logic summary, new DB tables, and open items.

---

## 1. Background

The "Honki Set" is a bundle campaign of 3 products: Lesson (online English) + Coaching 30-min + Bizmates App. The App is provided free for 6 months, so the customer pays nothing for it. For accounting, we must split (prorate) the total amount the customer actually paid across all 3 products, based on list prices.

The existing revenue aggregation system (ASC) **will not be modified**. ASCH is a new, separate batch that:

1. **Reads** contract and payment data from the main system (MBTI_backend DB) and the existing ASC result tables (read-only).
2. **Calculates** the prorated revenue per product per month.
3. **Outputs** new CSV files for the accounting team.
4. **Sends** adjustment journal entries (difference between prorated amount and the amount already booked by ASC) to Freee.

**Target DB:** Bizmates side only (`mysql` connection). Coaching and App do not exist on Zipan.

> **Note:** The Honki Set campaign already ran in Jan 2026 and Apr 2026 without any change to the revenue system (no proration was booked for those months). Whether we need retroactive correction is an open item (see Section 7).

---

## 2. Campaign Rules

### 2.1 Eligible Students

Students who have **never taken Coaching 30-min** in the past and are not taking it now (a student who cancelled it before becomes eligible again).

They must, during the campaign period:
- (a) sign up for the Coaching 30-min plan, AND
- (b) have or newly sign up for one of the Lesson plans: Daily 1 / Daily 2 / Monthly 15.

**Eligible segments:**
- New customers
- Existing Lesson students who have not taken Coaching
- Existing Coaching 15-min students
- Returning students (rest / 休会). For returning students, Lesson and Coaching must be applied for at the same time.

**Important:** Coaching 15-min is NOT part of the bundle. Only Coaching 30-min.

**Application period (this round):** 2026/7/1 – 2026/7/26. The campaign is expected to repeat quarterly.

**Contract period of the benefits:** 6 months from the application date (5 renewals after the first month).

### 2.2 Benefits

| # | Benefit | Notes |
|---|---------|-------|
| 1 | Month 1: 50% off | Coaching is 50% off in the first month. For Lesson, 50% off applies only to new Lesson contracts (existing Lesson students get the discount on Coaching only). Marketing still confirming details. |
| 2 | App free for 6 months | List price 3,600 JPY/month. If the student cancels mid-way, the right is lost from the following month. |
| 3 | Month 6: 50% off | Lost if the student cancels mid-way. |

### 2.3 Detailed Rules That Affect Calculation

**Month-6 discount and plan change:**
- If the student changes Lesson plan (Daily1 / Monthly15 ↔ Daily2) during the 6 months, the discount applies to the plan active at the month-6 contract date.
- The 6-month count itself starts from the original contract date.

**Month-6 discount when Lesson started before the campaign:**
- The Coaching discount applies at Coaching's own month-6 payment.
- The Lesson discount applies at the first Lesson payment after that date.
- Example: Lesson contracted 6/25, Coaching 7/1 → Coaching discount on 12/1 payment, Lesson discount on 12/25 payment.
- Because Lesson and Coaching payment dates differ, the discount month differs per product.

**Loyal customers and B2E:**
- The regular monthly Lesson discount (5% / 10%) still applies each month.
- But in month 1 and month 6, **only the 50% discount applies** (not stacked).

**Cancelling Coaching 30-min mid-way (including changing to 15-min):**
- The App membership is also removed from the month after the cancellation.

**Re-start after mid-way cancellation:**
- Even if the student re-subscribes within the 6 months, the month-6 discount and the free App right are permanently lost.

---

## 3. Proration Logic (Summary)

### Definitions per row (one row = one charge × one month)

| Symbol | Meaning |
|--------|---------|
| L | List price (monthly) |
| M | Paid amount (after discount; negative for refunds; 0 for App) |
| N | Amount already booked by existing ASC (from `log_daily_rate_calculation` / `log_monthly_rate_calculation`; 0 for App) |
| O | Proration base amount per charge (intermediate value) |
| P | Final prorated revenue for the month |
| I / J | Contract days (or total tickets) / days in month (or tickets consumed) |

### Step 1 — Build a proration group

All charges that newly start in the month for one enrollment form a group. Distribute the group's total payment (ΣM) across products:

```
O(product) = ΣM × ( basis(product) / Σ basis(all products) )

Where:
  basis = paid amount (M) when a non-Honki discount applies to that product
          (first-month Lesson discount, Loyal, B2E)
        = list price (L) otherwise (Honki Set discounts use list price)
```

### Step 2 — Monthly amount

```
P = O × (J / I)
```

- For a charge that continues into the next month, **O is carried over** (not recalculated).
- For the Monthly-15 plan, I/J are ticket counts instead of days, so P can exceed the list price in a month when consumption is skewed.

### Invariants to validate (IMPORTANT)

| Invariant | Rule |
|-----------|------|
| Per group at proration time | ΣO = ΣM (total payment is fully distributed) |
| Per charge over its whole lifetime | ΣP = O (the distributed amount is fully booked over time) |
| Monthly ΣP = ΣM | ❌ Does NOT hold and must NOT be validated. A charge starting mid-month is prorated by days, so the monthly P is smaller than M. |

### Adjustment for Freee

```
adjustment = P − N per row
```

Aggregated adjustments are sent to Freee as additional journal entries. **Existing ASC journals are never modified.**

### 9 Patterns Defined in the Requirement Excel

1. Simultaneous start
2. Different start dates
3. Start before campaign
4. Plan change Daily1 → Daily2
5. Coaching rest
6. Plan change Daily1 → Monthly15
7. B2E → B2B switch with refund
8. Cooling-off refund / B2E + Loyal
9. (Unnamed — likely combination case)

> All 9 are in scope but there will be other cases to handle.

---

## 4. Batch Schedule

Same operational timing as the existing ASC:
- **1st of each month:** preview run → preview CSV.
- **3rd of each month:** final run → final CSV + Freee journal submission.

**Run management proposal:** A `run_id` (generation) model — one table `asch_calculation_runs` records each run (preview / final / revision), and every result row carries `run_id`.

This replaces the existing `_pre` / final two-table pattern and keeps full history for retroactive recalculation (useful for JSOC audit).

> This is a proposal, not decided (open item; the `_pre` two-table pattern is also possible).

---

## 5. New Tables (10)

All tables are new, on the Bizmates DB only. No foreign key constraints (same as existing convention).

| # | Table | Purpose | Key Columns |
|---|-------|---------|-------------|
| 1 | `asch_calculation_runs` | One row per batch run. Generation key for all result tables. (Proposal — depends on run-management decision) | `target_ym`, `run_type` (preview/final/revision), `is_finalized`, `superseded_by_run_id`, `validation_status` |
| 2 | `asch_app_price_master` | The App list price used for proration. Needed because `mst_product_price` (2,500 JPY) does not match the business requirement sheet (3,600 JPY) — under confirmation | `sales_price`, `effective_from`, `effective_to` |
| 3 | `asch_source_documents` | Snapshot (JSON) of input data at the time of each run. For audit and retroactive recalculation. Deduplicated by hash | `source_system`, `source_type`, `source_key`, `payload_json`, `payload_hash` |
| 4 | `asch_bundle_enrollments` | One row per student enrolled in the Honki Set | `student_id`, `order_no` (B2B only), `bundle_start_date`, `coaching_start_date`, `app_free_end_date`, `status` |
| 5 | `asch_enrollment_contract_periods` | Contract type history (B2C / B2B / B2E) with validity period. Handles the B2E→B2B switch (Pattern 7) | `contract_type`, `department_id`, `partner_id`, `effective_from/to` |
| 6 | `asch_bundle_components` | One row per product (lesson / coaching / app) per revision. Plan changes and rest create new revisions | `component_type`, `component_variant`, `product_id` (App=10012), `sales_price`, `revision_no`, `status` |
| 7 | `asch_proration_groups` | One row per proration group (the ΣO = ΣM unit). Stores the validation result and which row absorbed rounding | `paid_total`, `denominator_total`, `base_amount_total`, `is_balanced` |
| 8 | `asch_monthly_prorations` | **Core table.** One row = one row of the Excel sheet. Holds E–P columns plus N, its source reference, and the adjustment | `target_ym`, `record_kind` (proration/standalone/refund), `I`, `J`, `K`, `L`, `M`, `proration_basis`, `N` (gross_amount_asc), `asc_source_table/id`, `O`, `P`, `adjustment_amount` (P−N), month sequences, `calc_rule_code` |
| 9 | `asch_sum_calculation` | Aggregation for Freee, same granularity as existing `log_sum_calculation`. `adjustment_amount = ΣP − ΣN` is what we send | `partner_id`, `order_no`, `department_id`, `product_type`, `contract_type`, `summary_kind`, `adjustment_amount`, `send_date`, `status` |
| 10 | `asch_sum_calculation_history` | Trace: which proration rows were aggregated into which summary row (same shape as existing `log_sum_calculation_history`) | `asch_sum_calculation_id`, `asch_monthly_proration_id` |

### Existing Tables Used as Input (read-only, no changes)

- `trn_charge`, `trn_student_product`, `mst_product`, `mst_product_price` — contracts and payments (same DB/tables for both ASC and MBTI_backend, confirmed 2026-07-03)
- `log_daily_rate_calculation(_pre)` — N for daily-plan Lessons and Coaching
- `log_monthly_rate_calculation(_pre)` — N for monthly-count-plan Lessons
- `trn_prorated_application`, `trn_prorated_refund(_charge)` — B2E→B2B switch and cooling-off refunds (Patterns 7/8)
- `log_first_month_enrollment_discount_apply`, `log_loyal_benefits_charge` — to detect which discount applies per charge (decides the proration basis M vs L)
- `trn_student_rest_history`, `trn_student_product.status` — REST detection (Pattern 5)

**App product data:** `mst_product` `product_id=10012` "Bizmates App Premium Plan", `product_type=100`.

> **Note:** `has_app_subscription` in `trn_student_app_info` is an in-app-purchase flag and is NOT usable to detect Honki Set members.

---

## 6. Outputs

### CSV for accounting review (not sent to Freee)

Following the existing `{YYYYMM}_NN_Name({execDate}).csv` naming:
- `AschComponentDetail_{YYYYMM}.csv` — one row per proration row (detail level)
- `AschCalculationSummary_{YYYYMM}.csv` — Freee-submission granularity, with N, P and adjustment columns

### Freee journals

Adjustment entries only (`ΣP − ΣN`), reusing the T1/T2/T3 logic of `SendJournalsDataLogic` as a reference implementation.

---

## 7. Open Items (not decided yet)

Items that block or may change the estimate are marked **[estimate impact]**.

| # | Open Item | Owner | Notes |
|---|-----------|-------|-------|
| 1 | Run management model — `run_id` generation model (our proposal) vs. existing `_pre` / final two-table split. | Dev | **[estimate impact]** table count doubles with `_pre` model |
| 2 | App list price mismatch — requirement sheet says 3,600 JPY but `mst_product_price` has 2,500 JPY. Which price is used for proration? | Accounting / Business | |
| 3 | Rounding rule — round half-up vs. truncation, and which row absorbs the remainder. Current default: half-up, largest row in the group absorbs. | Accounting | |
| 4 | Month-6 discount baseline — count 6 months per product (each product's own contract date; matches the marketing note) or from the Lesson (bundle) start date. Both month counters are stored so either can be adopted. | Accounting / Marketing | |
| 5 | Freee product item for App — `product_type=100` exists in `mst_product`, but the mapping in `config/code.php` (`freeeProductType`) has no App entry. New Freee item / account mapping needed. | Accounting | |
| 6 | Monthly-15 plan: P can exceed list price in a month — accounting treatment to confirm. | Accounting | |
| 7 | B2E→B2B switch (Pattern 7) — after the switch, is the App excluded from proration? Default: stop the App component at the switch date. | Accounting | |
| 8 | Refund month allocation — do refunds (cooling-off, B2E daily-rate refund) ever span months? Default: book in the month the refund occurs (same as existing ASC refund rows). | Accounting / existing spec check | |
| 9 | N source for preview runs — use `log_*_pre` tables for the preview run? Default: preview → `_pre`, final → confirmed tables. | Dev | |
| 10 | Retroactive correction for Jan 2026 / Apr 2026 campaigns — proration was not booked for the past campaign rounds. Default: out of scope (a revision run can handle it later if needed). | Accounting / Segawa-san | **[estimate impact if in scope]** |
| 11 | How to identify Honki Set members — `is_honki_eligible` (CPF-56 / PR #5531) exists in MBTI_backend GraphQL; we need to confirm whether there is a persisted table/log that records the actual enrollment. | Dev | **[estimate impact]** intake logic depends on this |
| 12 | First-month Lesson discount detail — marketing note says Lesson 50% off applies "only to new Lesson contracts" and is still marked as "to be confirmed" on the marketing sheet. | Marketing | |
| 13 | CS operation for App cancellation — when Coaching 30-min is cancelled, App removal operation flow is still being confirmed with CS. | CS / Marketing | |

---

## ERD

An ERD diagram showing the relationships between the 10 new tables is provided as an attached image. Key relationships:

- `asch_calculation_runs.id` → `run_id` (shared across all result tables)
- `asch_bundle_enrollments.id` → `bundle_enrollment_id` (links to contract periods, components, proration groups)
- `asch_proration_groups.id` → links to `asch_monthly_prorations` (new proration rows only)
- `asch_bundle_components.id` → `bundle_component_id` in monthly prorations
- `asch_monthly_prorations.id` → `asch_sum_calculation_history` → `asch_sum_calculation`
- `asch_source_documents.id` → `source_document_id` in enrollments and components
