# CDB (Campaign Discount Batch) — Initial Design Proposal

**Source:** Devin (AI Software Engineer), Confluence — Jul 9, 2026  
**Received:** 2026-07-21 (from session with CDB team)  
**Relevance to ASCH:** CDB provides the eligibility table ASCH reads from. Table name and structure affect Spec 02.

---

## Key Findings for ASCH

### Table Name: `trn_campaign_price_eligibility`

NOT `trn_campaign_discount_eligibility` as previously referenced in ASCH docs. The CDB proposal uses:

```
trn_campaign_price_eligibility (
    student_id,
    campaign_id,
    tier,
    eligible_renewal_date,
    status,
    created_at,
    updated_at
)
```

### What ASCH Needs vs What CDB Provides

| ASCH needs | CDB provides | Gap? |
|---|---|---|
| student_id | ✅ student_id | None |
| Campaign round identifier | ✅ campaign_id | None |
| Coaching start date | ❌ Not directly — has `eligible_renewal_date` (trigger_start_date + 6 months) | ASCH can derive: coaching_start = eligible_renewal_date - 6 months |
| Lesson start date | ❌ Not provided | ASCH must query `trn_charge` / `trn_student_product` |
| Lesson plan type | ❌ Not provided | ASCH must query product data |
| Purchase structure | ❌ Not explicit | ASCH infers from charge data |
| Active/forfeited status | ✅ status | Need to confirm status values |
| When forfeiture occurred | ❌ Not directly | Would need log table or timestamp |

### Critical Differences from ASCH's Earlier Assumptions

1. **Table name changed:** `trn_campaign_discount_eligibility` → `trn_campaign_price_eligibility`
2. **No `initial_charge_id` column** — Kuroda-san's REF-ASCH-02 assumed this existed. CDB proposal doesn't include it.
3. **No `discount_flag` column** — uses `tier` instead (PLAN_TIER_HALF_PRICE = tier 2)
4. **No `discount_eligibility_date`** — uses `eligible_renewal_date` (the date of the 6th renewal)
5. **No per-product rows** — CDB has one row per student × campaign, NOT per student × campaign × product. ASCH expected one row per product.
6. **No log/history table mentioned** — Kuroda-san's spec assumed `log_campaign_discount_eligibility` for change history. Not in CDB proposal.

### CDB's Purpose vs ASCH's Need

**CDB is designed for the charge batch** — it tells `charge.php` "this student's next renewal should be tier 2 (half price)." It's a pricing instruction, not an enrollment registry.

**ASCH needs an enrollment registry** — "which students are Honki Set members, what products are in their bundle, when did they start." This is a different question.

**Implication:** CDB's table may not be sufficient as ASCH's primary source. ASCH likely needs to:
1. Read CDB's `trn_campaign_price_eligibility` for "who is a Honki Set member" (student_id + campaign_id)
2. Then query `trn_charge` / `trn_student_product` / `mst_product` to build the full enrollment picture (products, start dates, plan types)

This aligns with what RESEARCH-03-CDB-Shared-Table-Discussion.md already identified: "Items 4–5 and 8 likely need ASCH to query trn_charge / trn_student_product independently."

---

## CDB Architecture Summary

### Component 1: Eligibility Batch (MBTI_backend)

- New Artisan command: `campaign:price-eligibility`
- Scheduled daily via `Kernel.php`
- Campaign-agnostic service with evaluator pattern
- First evaluator: wraps `HonkiSetEligibilityService` (5-CTE SQL)
- Upserts to `trn_campaign_price_eligibility`

### Component 2: Charge Batch Override (bizmates.jp)

- In `charge.php`, before price computation
- Looks up `trn_campaign_price_eligibility` where `eligible_renewal_date` matches renewal being processed
- If tier 2 found → pass `PLAN_TIER_HALF_PRICE` to `PlanPriceService::getOnlineLessonPlanDiscountPrice()`
- Only fires for the 6th-month charge (date matching = natural guard)

### Open Decision (CDB-internal, affects ASCH indirectly)

> "Whether Honki keeps the existing cashback behavior AND adds a discounted 6th renewal, or the discounted renewal replaces the cashback"

If cashback is kept AND tier-2 discount added, the student pays less in month 6. ASCH's M value for month 6 would reflect the discounted price. This is already handled by ASCH's formula (month-6 50% = Honki Set discount → basis = L).

---

## Impact on ASCH Timeline

| Item | Impact | Action |
|---|---|---|
| Table name change | Low | Update all docs referencing `trn_campaign_discount_eligibility` → `trn_campaign_price_eligibility` |
| Missing columns (initial_charge_id, per-product rows) | Medium | ASCH Spec 02 must build enrollment details from charge data, not just read CDB table |
| No history/log table | Low | ASCH's `asch_source_documents` snapshot approach already handles this |
| CDB provides less than assumed | Already planned | Fallback self-detection path was always part of the design |

**Timeline impact: None.** The estimate already assumed ASCH would need to query `trn_charge` / `trn_student_product` for product details. CDB just provides the "who" (student_id list), not the "what" (products, dates, amounts). This matches our existing design.


---

## UPDATE (2026-07-21): Final CDB Table Structure Confirmed

The CDB team confirmed 3 tables. The table name reverts to the original: `trn_campaign_discount_eligibility` (not `trn_campaign_price_eligibility` from the initial Devin proposal).

### Tables

| Table | Purpose |
|---|---|
| `trn_campaign_discount_eligibility` | Per-student × product eligibility records |
| `mst_campaign_discount_eligibility` | Campaign configuration / master data |
| `log_campaign_discount_eligibility` | Change history (updates logged here) |

### `trn_campaign_discount_eligibility` — Column Structure

| Column | Type | Description | ASCH Use |
|---|---|---|---|
| `id` | BIGINT | Primary key | — |
| `student_id` | BIGINT | FK to student | ✅ Match to charges |
| `discount_campaign_id` | INT | FK to mst_campaign_discount_eligibility | ✅ Campaign identification |
| `discount_campaign_type` | INT | Campaign group (1=Jul Honki, 2=Oct Honki, 3=Jan Honki) | ✅ Campaign round identification |
| `product_id` | INT | FK to product purchased | ✅ Identifies which product (Lesson/Coaching/App) |
| `plan_id` | INT | FK to plan purchased | ✅ Determines plan variant (Daily 1/2/3/4, Monthly 15) |
| `initial_charge_id` | BIGINT | FK to first charge when campaign was purchased | ✅ Links to trn_charge for start date / contract period |
| `discount_flag` | TINYINT | Status: -1=Ineligible, 0=Not yet eligible, 1=Eligible, 2=Granted as discount, 3=Granted as tickets, 4=Granted as gift cert | ✅ Determines if student is active member |
| `discount_eligibility_date` | DATE | Date when eligibility is evaluated/reached | ✅ Month-6 trigger date reference |
| `created_at` | TIMESTAMP | Record creation | — |
| `updated_at` | TIMESTAMP | Record update (changes logged to log table) | — |

### What This Means for ASCH (vs Earlier Assumptions)

| Previous assumption | Actual (confirmed) | Match? |
|---|---|---|
| Table: `trn_campaign_discount_eligibility` | ✅ `trn_campaign_discount_eligibility` | ✅ Original name correct |
| One row per student × campaign × product | ✅ Has `product_id` and `plan_id` per row | ✅ Per-product rows |
| Has `initial_charge_id` | ✅ Present | ✅ |
| Has `discount_flag` | ✅ Present (with detailed status values) | ✅ |
| Has `discount_eligibility_date` | ✅ Present | ✅ |
| History table exists | ✅ `log_campaign_discount_eligibility` | ✅ |

**Conclusion:** The final CDB structure matches what Kuroda-san's REF-ASCH-02 originally specified. The earlier "initial design proposal" from Devin was a preliminary proposal that evolved. The confirmed structure gives ASCH everything it needs.

### ASCH Can Read Directly

With the confirmed structure, ASCH can extract:
- **Who:** `student_id` WHERE `discount_campaign_type` IN (1,2,3) AND `discount_flag` IN (1, 2)
- **What product:** `product_id` + `plan_id` per row
- **When started:** `initial_charge_id` → join to `trn_charge` for `start_date`, `paid_price`
- **Month-6 date:** `discount_eligibility_date`
- **Active/forfeited:** `discount_flag` (-1 = ineligible, 0 = not yet, 1 = eligible, 2+ = granted)

ASCH's `asch_bundle_components.source_charge_id` maps directly to CDB's `initial_charge_id`.
