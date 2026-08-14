# CIP (Coaching Intensive Plan) — Upstream Project Spec Summary

**Source:** CIP Confluence space — "Project.md" by Jefferson Gernale (rough draft)  
**Date received:** 2026-08-13  
**Filed by:** Noel Palo  
**Assisted by:** Kiro  
**Status:** Rough draft — aligned to CAP implementation (¥0 App, price_flag = 4)

---

## ⚠️ CRITICAL FINDING: CIP Is NOT What We Assumed

**Our previous assumption (from REF-CIP-02):**
> CIP adds App as companion to EXISTING coaching plans (71, 94, 1005–1014)

**What CIP actually is:**
> CIP is a BRAND NEW product (10022) with BRAND NEW plan_ids (1028–1032). It does NOT modify existing coaching plans.

This changes our ASC-CIP detection strategy entirely.

---

## What CIP Actually Is

**Coaching Intensive Plan (コーチング短期集中プラン)** — a NEW premium coaching product:
- **product_id: 10022** (new — not 10005 or 10015)
- **product_type: 9** (same as existing coaching — `PRODUCT_TYPE_BIZMATES_COACHING`)
- **Price: ¥88,000** (tier 1) / ¥44,000 (tier 2) per month
- **Plan_ids: 1028–1032** (brand new, do not exist yet)
- 4×30min monthly consultations + extras
- Bundles with App product 10021 (same as CAP)
- Uses `price_flag = 4` (PRICE_FLAG_CAP) — same pricing mechanism as CAP

---

## CIP Plans (1028–1032)

| plan_id | Bundle | Products | Pre-tax price |
|---|---|---|---|
| 1028 | Solo Coaching Intensive | 10022 + 10021 | ¥88,000 |
| 1029 | L25 + FVP + Coaching Intensive + App | 1 + 10011 + 10022 + 10021 | ¥102,850 |
| 1030 | L50 + FVP + Coaching Intensive + App | 2 + 10011 + 10022 + 10021 | ¥109,450 |
| 1031 | L75 + FVP + Coaching Intensive + App | 3 + 10011 + 10022 + 10021 | ¥119,350 |
| 1032 | L100 + FVP + Coaching Intensive + App | 4 + 10011 + 10022 + 10021 | ¥129,250 |

**Key:** All 5 plans include App product 10021 — same companion pattern as CAP.

---

## Impact on ASC-CIP Allocation

### What Changes from Our Previous Design

| Aspect | Previous assumption | Actual |
|---|---|---|
| CIP product_id | 10005/10015 (existing coaching) | **10022** (brand new) |
| CIP plan_ids | 71, 94, 1005–1014 (existing) | **1028–1032** (brand new) |
| Historical data risk | ⚠️ Yes — needed date filter | **None** — these plans don't exist yet |
| Detection approach | plan_id + date filter | **plan_id only** (same as CAP — new plans, no history) |
| Reference price (L_coaching) | ¥19,800/¥39,600 (pending O-5) | **¥96,800** (= ¥88,000 × 1.1 tax-incl) for product 10022 |
| App reference price | ¥3,980 | ¥3,980 (unchanged — same product 10021) |

### Revised Detection for ASC-CIP

```php
// OLD assumption (WRONG):
// CoachingIntensivePlanEnum with plan_ids 71, 94, 1005–1014 + date filter

// CORRECT:
enum CoachingIntensivePlanEnum: int
{
    use HasEnumHelperTrait;

    case SOLO_INTENSIVE         = 1028;
    case L25_INTENSIVE          = 1029;
    case L50_INTENSIVE          = 1030;
    case L75_INTENSIVE          = 1031;
    case L100_INTENSIVE         = 1032;
}

// Detection: same as CAP — no date filter needed (plans are brand new)
// CoachingIntensivePlanEnum::exists($trnCharge->plan_id)
```

**No date filter needed!** These plan_ids (1028–1032) have zero historical charges — they don't exist until CIP goes live.

### Revised Formula for ASC-CIP

```
N = daily-prorated amount from coaching intensive charge (product 10022)
L_app = ¥3,980 (same as CAP)
L_coaching_intensive = ¥96,800 (= ¥88,000 × 1.1, tax-inclusive)

P_app      = floor(N × 3,980 / (96,800 + 3,980)) = floor(N × 3,980 / 100,780)
P_coaching = N − P_app
```

### What Stays the Same

- App product is still 10021 (same as CAP)
- App charge is still ¥0 in trn_charge (companion pattern)
- Same allocation formula structure: `P_app = floor(N × L_app / (L_coaching + L_app))`
- Same injection point in CommonUtil
- Same `project_code` column distinguishes CAP vs CIP
- Detection by product_id 10021 works for BOTH (Kuroda-san's preference)

---

## O-5 (CIP Reference Prices) — NOW ANSWERABLE

Previously O-5 was "CIP coaching reference prices — pending Business + Accounting."

**Now we know:**
- CIP coaching product is 10022 (not 10005/10015)
- Standalone price: ¥88,000 tax-exclusive = **¥96,800 tax-inclusive**
- This is the L_coaching value for CIP allocation

**O-5 can be resolved** — need Kuroda-san/Accounting to confirm ¥96,800 as the CIP coaching reference price. (It should be straightforward since it's the published standalone price, same logic as CAP.)

---

## What This Means for Our Architecture

**Good news:** The framework design holds perfectly. CAP and CIP are structurally identical:
- Both have new plan_ids with no history
- Both bundle App product 10021 at ¥0
- Both use the same formula (different L_coaching constant)
- Both detected by product_id 10021 (or by their own plan_id enum)

The only change needed in our design docs:
- Update `CoachingIntensivePlanEnum` from plan_ids [71, 94, 1005–1014] to [1028–1032]
- Remove the CIP date filter requirement (no longer needed)
- Update CIP reference price from "TBD" to ¥96,800 (pending Accounting confirmation)
- Add product_id 10022 to the reference prices table

---

## Additional Notes from the Spec

1. **CIP uses PRICE_FLAG_CAP = 4** — same pricing mechanism as CAP. Both are "coaching priced together with bundled App companion."

2. **CIP has its own beta gating** — independent of CAP's beta. They share numeric value 9 today but have separate constants and check methods.

3. **Honki Set is NOT applicable** to CIP — confirmed in §4 (exclusive to existing Coaching 30 packages 1010/1011 only).

4. **No B2B-specific CIP variants** — the spec mentions B2B, B2C, B2E are all supported with the same 5 plans.

5. **CIP bundles the CAP App product (10021)** — explicitly stated: "Coaching Intensive bundle/solo plans also link the CAP App product (10021) per the seeder in §9."

---

*Content was rephrased for compliance with licensing restrictions*  
*Source: CIP Confluence space, Jefferson Gernale, rough draft*
