# CIP Coaching Campaigns — Confluence Reference

**Source:** CIP Confluence space — "Coaching Campaigns" by Jefferson Gernale  
**Date received:** 2026-08-12  
**Filed by:** Noel Palo  
**Assisted by:** Kiro

---

## Why This Matters for ASC-CIP

This document confirms:
1. **CIP plan_ids** — standalone coaching plans (71, 94) + coaching packages (1005–1014)
2. **CIP does NOT include App product 10021** — these are pre-CAP plans (App added by upstream CIP project later)
3. **Campaign tiers affect the N value** — tier 2 = half price → different N for allocation
4. **Honki Set is 30min only** (1010, 1011) — overlap with ASCH (cancelled) but relevant if ASC-CIP allocates these

**Note:** "CIP" = Coaching Intensive Plan (upstream project in MBTI_backend that adds App companion to existing plans). "ASC-CIP" = our accounting allocation project that splits the coaching revenue for CIP charges.

---

## CIP Plans (Coaching WITHOUT App)

### Products
- **Coaching 15min:** product_id = 10005, standalone plan_id = 71
- **Coaching 30min:** product_id = 10015, standalone plan_id = 94

### Plan Map

| Plan Type | Coaching 15min plan_ids | Coaching 30min plan_ids |
|---|---|---|
| Standalone Coaching Only | 71 | 94 |
| Online Lesson (25min) + FVP + Coaching | 1005 | 1010 |
| Online Lesson (50min) + FVP + Coaching | 1006 | 1011 |
| Online Lesson (75min) + FVP + Coaching | 1007 | 1012 |
| Online Lesson (100min) + FVP + Coaching | 1008 | 1013 |
| Beginner Package (25min) + FVP + Coaching | 1009 | 1014 |

**Total CIP plan_ids:** 71, 94, 1005–1014 (12 plans)

### Key Distinction from CAP

| | CAP Plans (1016–1027) | CIP Plans (71, 94, 1005–1014) |
|---|---|---|
| Includes App (10021)? | ✅ Yes | ❌ No |
| App charge in trn_charge? | ¥0 companion | None |
| Allocation needed? | Split coaching N into coaching + app | Split coaching N into coaching + app (CIP adds App retrospectively) |

---

## Campaign Types That Affect N Value

All campaigns change the `paid_price` (N) in `trn_charge`. ASC allocation doesn't need to know WHICH campaign — it just reads N from `log_daily_rate_calculation` and splits it. But understanding the tiers helps with test scenarios.

| Campaign | Discount | Tier | Affects plan_ids |
|---|---|---|---|
| B2C New Enrollment | 50% off first month | tier 2 | All coaching plans |
| B2B2C | 50% off first month | tier 2 | All coaching plans (if mst_campaign row) |
| Rest (Win-Back) | 50% off first month | tier 2 | All coaching plans |
| First Month Enrollment | 50% off first month | tier 2 | Package plans only (1005–1014, NOT 71/94) |
| Honki Set | 50% off first month + 6mo cashback | tier 2 | 1010, 1011 ONLY |

### Pricing Reference (from trn_charge)

| Product | Tier 1 (full, tax-incl) | Tier 2 (campaign, tax-incl) |
|---|---|---|
| Coaching 15min (10005) | ¥19,800 | ¥9,900 |
| Coaching 30min (10015) | ¥36,000* | ¥18,000* |

*Tax-exclusive values shown in source doc. Tax-inclusive = × 1.1:
- Coaching 15: ¥19,800 × 1.1 = ¥21,780 (tier 1), ¥9,900 × 1.1 = ¥10,890 (tier 2)
- Coaching 30: ¥36,000 × 1.1 = ¥39,600 (tier 1), ¥18,000 × 1.1 = ¥19,800 (tier 2)

**Wait — correction needed.** The source doc lists prices as tax-exclusive (confirmed by cross-reference with REF-CAP-05 where coaching standalone is ¥18,000 tax-excl). The N value in `trn_charge.paid_price` is tax-INCLUSIVE. So:

| Product | N at tier 1 (tax-incl) | N at tier 2 (tax-incl) |
|---|---|---|
| Coaching 15min standalone | ¥21,780 | ¥10,890 |
| Coaching 30min standalone | ¥39,600 | ¥19,800 |

---

## How CIP Allocation Differs from CAP

**CAP:** Student buys a CAP plan (1016–1027) → Coaching charge includes App fee → ASC splits N.

**CIP:** Student buys a legacy coaching plan (71, 94, 1005–1014) that does NOT include App. But CIP wants to ALSO allocate App revenue from the coaching charge — meaning the same formula applies, just to a different set of plans.

Wait — **is this actually what CIP does?** Let me cross-reference with Kuroda-san's design (REF-CAP-04):

From the Slack thread (REF-CAP-05): Kuroda-san confirmed "CIP will use the same product 10021" and "same ¥2,500 assumption."

From the master timeline: "CIP = Coaching Intensive Plan" — the upstream CIP project adds App as a companion to existing coaching plans.

**Conclusion:** CIP is the SAME allocation concept applied to different plans. When the CIP project launches:
- Existing coaching plans (71, 94, 1005–1014) will ALSO get a ¥0 App companion charge (product 10021)
- The coaching charge stays the same amount
- ASC-CIP allocation splits that coaching N into coaching revenue + app revenue
- Same formula: `P_app = floor(N × 3980 / (L_coaching + 3980))`

**The only difference between ASC-CAP and ASC-CIP is the plan_id detection list:**
- CAP: plans 1016–1027
- CIP: plans 71, 94, 1005–1014 (once CIP upstream goes live)

This confirms our architecture — single `AscAllocationService` with `project_code` column distinguishing which plans belong to which project.

---

## Detection Strategy for CIP

```sql
-- CIP coaching charges (once CIP upstream is live)
SELECT c.id AS charge_id, c.student_id, c.product_id, c.paid_price, sp.plan_id
FROM trn_charge c
JOIN trn_student_product sp ON sp.charge_id = c.id
WHERE c.product_id IN (10005, 10015)
  AND sp.plan_id IN (71, 94, 1005, 1006, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014)
  AND c.status = 1 AND c.paid = 1
  -- Additional filter: only charges AFTER CIP launch date
  -- (existing coaching charges before CIP should NOT be allocated)
  AND c.start_date >= '2026-XX-XX'  -- CIP launch date TBD
```

**Important:** CIP needs a date filter. Unlike CAP (new plans that never existed before), CIP plan_ids already have historical charges. We must only allocate charges created AFTER CIP goes live — otherwise we'd retroactively split years of historical coaching revenue.

---

## CIP Reference Prices (Pending O-5)

| Product | Reference price | Status |
|---|---|---|
| App (10021) | ¥3,980 (tax-incl) | ✅ Confirmed (same as CAP) |
| Coaching 15min (10005) | TBD | ⚠️ Open item O-5 |
| Coaching 30min (10015) | TBD | ⚠️ Open item O-5 |

**Question for Kuroda-san:** Are CIP coaching reference prices the same as CAP (¥19,800 / ¥39,600)? Or does CIP use different standalone prices because the plans don't include the App fee in the package_price?

This is open item O-5. The formula is the same — only the constants might differ.

---

## Honki Set Overlap Consideration

Honki Set applies to plans 1010 and 1011 (Coaching 30min packages). These are CIP plan_ids.

If a student is simultaneously in Honki Set AND CIP (App companion added):
- ASCH was supposed to handle the Honki allocation (cancelled)
- CIP allocation would split the coaching charge
- If both ran, the coaching charge would be split twice → error

**Current resolution:** ASCH is cancelled. Honki Set allocation is NOT happening. CIP can safely allocate for 1010/1011 without conflict.

**Future risk:** If Honki Set allocation is ever re-introduced (under a different project), it must coordinate with CIP for plans 1010/1011.

---

## Summary for ASC Team

| What we now know | Source |
|---|---|
| CIP plan_ids: 71, 94, 1005–1014 | This document |
| CIP uses same product 10021 | REF-CAP-05 (Kuroda-san confirmed) |
| CIP uses same formula | REF-CAP-04 (Kuroda-san DB design) |
| CIP needs date filter (historical charges exist) | Logical — legacy plans have years of data |
| CIP reference prices: App ¥3,980, Coaching TBD (O-5) | Partially confirmed |
| Campaign tiers don't affect our logic | We just read N from log_daily_rate_calculation |
| Honki overlap: safe (ASCH cancelled) | Confirmed |

---

*Content was rephrased for compliance with licensing restrictions*  
*Source: CIP Confluence space, Jefferson Gernale*
