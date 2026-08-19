# CAP Upstream Price Mechanism — Confluence Draft Summary

**Source:** CAP Confluence space — "[DRAFT] CAP Coaching+App — Price Mechanism: Approach Comparison and Required Fixes" by Terry Merwin C Balahadia  
**Status:** DRAFT — pending PO decision on Q1–Q3  
**Date received:** 2026-08-12  
**Filed by:** Noel Palo  
**Assisted by:** Kiro

---

## Why This Matters for ASC-CAP/ASC-CIP

This document confirms:
1. **All 12 CAP plan_ids** (1016–1027) — these are the upstream CAP (Coaching and App Plan) plans
2. **App product_id = 10021** (already known)
3. **App charge is ¥0** in trn_charge (companion approach — Approach 2 recommended)
4. **The ¥2,500 vs ¥3,980 question is resolved** — both exist for different purposes
5. **Detection strategy confirmed:** Look for plans in `mst_plan_content` containing product 10021
6. **Campaign eligibility:** CAP plans ARE eligible for first-month campaign (tier 2)

**Note:** "CAP" = Coaching and App Plan (upstream project in MBTI_backend). "ASC-CAP" = our accounting allocation project that splits the coaching revenue for CAP charges.

---

## Confirmed CAP Plan IDs (12 plans)

| plan_id | Plan | package_price (tax-incl) | Ex-tax total | Coaching product |
|---|---|---|---|---|
| 1016 | Solo C15 + App | ¥22,550 | ¥20,500 | 10005 |
| 1017 | Solo C30 + App | ¥42,350 | ¥38,500 | 10015 |
| 1018 | L25 + C15 + App | ¥37,400 | ¥34,000 | 10005 |
| 1019 | L50 + C15 + App | ¥44,000 | ¥40,000 | 10005 |
| 1020 | L75 + C15 + App | ¥53,900 | ¥49,000 | 10005 |
| 1021 | L100 + C15 + App | ¥63,800 | ¥58,000 | 10005 |
| 1022 | L25 + C30 + App | ¥57,200 | ¥52,000 | 10015 |
| 1023 | L50 + C30 + App | ¥63,800 | ¥58,000 | 10015 |
| 1024 | L75 + C30 + App | ¥73,700 | ¥67,000 | 10015 |
| 1025 | L100 + C30 + App | ¥83,600 | ¥76,000 | 10015 |
| 1026 | L15/mo + C15 + App | ¥37,400 | ¥34,000 | 10005 |
| 1027 | L15/mo + C30 + App | ¥57,200 | ¥52,000 | 10015 |

**Solo plans (1016, 1017):** Coaching + App only — no lesson product.

---

## Two-Price Model (Confirmed)

| Table | Product | Value | Purpose | Read by |
|---|---|---|---|---|
| `mst_product_price` | 10021 | ¥3,980 | Standalone charge price (PO-confirmed) | `bizmates.jp` PlanModel |
| `mst_new_price_listing` | 10021, flag 3, tier 1 | ¥2,500 | Bundle display contribution | MBTI_backend `Libs_Price_Service` |
| `mst_new_price_listing` | 10021, flag 3, tier 2 | ¥2,500 | Half-price campaign tier | MBTI_backend |

**For ASC allocation:**
- We use **¥3,980 (tax-inclusive)** as the App reference price (standalone selling price)
- This is the value for revenue recognition allocation per Option (C) proportional method
- The ¥2,500 is irrelevant to us — it's a display/package_price reconciliation value only

---

## Approach 2 (Recommended by CAP Team) — Impact on ASC

**Approach 2 = Product-level pricing.** Each product carries its own price. App = ¥2,500 in `mst_new_price_listing`. App charge is ¥0 in `trn_charge`.

What this means for ASC allocation:
- `trn_charge` for App (product 10021) has `paid_price = 0` and `sales_price = 0`
- `trn_charge` for Coaching (product 10005/10015) has the COMBINED coaching+app amount
- Existing ASC daily rate calculation books the full coaching charge amount as coaching revenue
- **ASC allocation corrects this:** splits the coaching N into P_coaching + P_app

If Approach 1 were chosen instead (price_flag=4, App invisible):
- Same outcome for ASC — the coaching charge still carries the combined amount
- Our allocation logic works identically regardless of which approach upstream uses
- The only difference is whether there's a ¥0 App row in `trn_charge` to detect the bundle

**Key insight:** Our detection strategy should NOT rely on the ¥0 App charge existing in `trn_charge`. Instead, detect by `plan_id` (from `trn_student_product`) being in the CAP plan list (1016–1027). This works for both Approach 1 and Approach 2.

---

## Detection Strategy (Updated)

Based on this document, the safest detection is:

```sql
-- Find CAP coaching charges for a target month
SELECT c.id AS charge_id, c.student_id, c.product_id, c.paid_price,
       sp.plan_id
FROM trn_charge c
JOIN trn_student_product sp ON sp.charge_id = c.id
WHERE c.product_id IN (10005, 10015)          -- Coaching products
  AND sp.plan_id IN (1016, 1017, 1018, 1019, 1020, 1021,
                     1022, 1023, 1024, 1025, 1026, 1027)  -- CAP plans
  AND c.status = 1
  AND c.paid = 1
```

**Why plan_id, not product 10021 detection:**
- Works regardless of Approach 1 or 2
- `plan_id` is stored on `trn_student_product` (linked to charge)
- Deterministic — no ambiguity about which coaching charges need allocation
- No dependency on whether the ¥0 App row exists

---

## Tier 2 (First-Month Campaign) — Confirmed Behavior

CAP plans ARE campaign-eligible. At tier 2:

| Plan type | Tier 1 (N value) | Tier 2 (N value) |
|---|---|---|
| Solo C15 + App | ¥22,550 | ¥11,275* |
| Solo C30 + App | ¥42,350 | ¥21,175* |
| L25 + C15 + App | ¥22,550 (coaching portion) | ¥11,275* |
| L25 + C30 + App | ¥42,350 (coaching portion) | ¥21,175* |

*Tax-inclusive values that appear in `trn_charge.paid_price` for the coaching line.

**For ASC:** We don't care about tier. N is whatever `paid_price` the existing ASC daily rate calculated. Our formula just splits it.

---

## Honki Set Interaction (Open Question Q3)

The document asks whether CAP 30-minute plans (1022–1025, 1027, 1017) should be eligible for the Honki campaign. This is relevant because:

- If YES: A student could be in BOTH Honki Set AND CAP simultaneously
- The ASCH project (cancelled) would have handled Honki allocation
- With ASCH cancelled, this combination might need special handling in ASC-CAP

**Current state:** `CoachingPage::HONKI_ELIGIBLE_PLAN_IDS` does NOT include CAP plans. So currently no overlap. If PO decides to add them, we need to flag this as a future consideration.

---

## Impact on ASC Open Items

| Item | Update |
|---|---|
| O-1 (App product_id) | ✅ Already resolved: 10021 |
| CAP plan_ids (needed for detection) | ✅ **NOW KNOWN: 1016–1027** |
| Reference prices | ✅ Confirmed: App ¥3,980, Coaching ¥19,800/¥39,600 |
| Detection approach | ✅ Use `plan_id` from `trn_student_product` (via `mst_plan_content` or hardcoded list) |
| Upstream DB schema | ✅ `mst_plan_content` links plan_id → product_id (confirmed from ls-db-migrations) |

---

## What We Still Need

| Item | From whom | Blocking? |
|---|---|---|
| PO decision on Q1 (App as own billing line or invisible) | PO / Business | ❌ No — our allocation works either way |
| PO decision on Q3 (Honki + CAP overlap) | PO / Business | ❌ No — only relevant if both active simultaneously |
| Fix #2 and #3 merged (campaign_target_plans updated) | CAP team | ❌ No — affects display/purchase, not ASC allocation |
| CIP plan_ids | CIP team / Business | ⚠️ Needed for CIP detection (but CIP is second) |

---

*Content was rephrased for compliance with licensing restrictions*  
*Source: CAP Confluence space, Terry Merwin C Balahadia, DRAFT document*
