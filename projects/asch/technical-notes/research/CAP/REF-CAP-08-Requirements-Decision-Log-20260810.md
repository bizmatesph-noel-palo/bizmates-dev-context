# CAP Phase 1+2 — Requirements Decision Log (Summary)

**Source:** CAP Confluence space — "CAP Phase 1+2 — Requirements Decision Log" by Terry Merwin C Balahadia  
**Date:** Updated 2026-08-10  
**Filed by:** Noel Palo  
**Assisted by:** Kiro  
**Status:** All blocking questions resolved (2026-07-31). Non-blocking items (Q4, Q6, Q7) pending Design/PO.

---

## What's Relevant for ASC-CAP/ASC-CIP

This document is the **authoritative upstream source** confirming plan_ids, product_ids, pricing, and the operational model. Key confirmations for our allocation work:

### 1. Plan Table — Final (Q1, confirmed by PO 2026-07-31)

| Plan ID | Bundle | Products (product_ids) | Pre-tax | Tax-incl |
|---|---|---|---|---|
| 1016 | Solo C15 + App | 10005 + 10021 | ¥20,500 | ¥22,550 |
| 1017 | Solo C30 + App | 10015 + 10021 | ¥38,500 | ¥42,350 |
| 1018 | L25 + FVP + C15 + App | 1 + 10011 + 10005 + 10021 | ¥34,000 | ¥37,400 |
| 1019 | L50 + FVP + C15 + App | 2 + 10011 + 10005 + 10021 | ¥40,000 | ¥44,000 |
| 1020 | L75 + FVP + C15 + App | 3 + 10011 + 10005 + 10021 | ¥49,000 | ¥53,900 |
| 1021 | L100 + FVP + C15 + App | 4 + 10011 + 10005 + 10021 | ¥58,000 | ¥63,800 |
| 1022 | L25 + FVP + C30 + App | 1 + 10011 + 10015 + 10021 | ¥52,000 | ¥57,200 |
| 1023 | L50 + FVP + C30 + App | 2 + 10011 + 10015 + 10021 | ¥58,000 | ¥63,800 |
| 1024 | L75 + FVP + C30 + App | 3 + 10011 + 10015 + 10021 | ¥67,000 | ¥73,700 |
| 1025 | L100 + FVP + C30 + App | 4 + 10011 + 10015 + 10021 | ¥76,000 | ¥83,600 |
| 1026 | L15mo + FVP + C15 + App | 29 + 10011 + 10005 + 10021 | ¥34,000 | ¥37,400 |
| 1027 | L15mo + FVP + C30 + App | 29 + 10011 + 10015 + 10021 | ¥52,000 | ¥57,200 |

**Also noted but out of scope:**
- 8L/10L B2B variants — no plan_id assigned yet
- Beginner variants — 販売停止 (discontinued, do not implement)

### 2. Product 10021 — Confirmed Details

| Field | Value |
|---|---|
| product_id | 10021 |
| name | Bizmatesアプリプレミアム |
| product_type | 100 (same as legacy 10012) |
| price (mst_product_price) | ¥3,980 (tax-excl standalone) |
| Used in | All 12 CAP bundle plans (1016–1027) |
| Legacy 10012 | Retained untouched — no migration, no deprecation |

### 3. Detection — product_type based (verified by CAP team)

All detection paths in existing code filter on `product_type = 100`, not `product_id`:
- `TrnStudentProduct::scopeForMobileProducts()`
- `TrnStudent::scopeHasActiveMobileContract()`
- `ActiveStudentProducts.php`
- `bizmates.jp studentProductModel::hasActiveMobileContract()`
- `bizmates.jp chargeModel.php`

**For ASC allocation:** Kuroda-san's preference is `product_id = 10021` for detection (more explicit than product_type). This is consistent — the upstream team uses product_type for "is this student an App subscriber?" while we use product_id for "is this specific charge part of a CAP/CIP bundle?"

### 4. Renewal Model — Coaching = Anchor, App = ¥0 Companion (Q10)

- **Lesson bundles (1018–1027):** Lesson is anchor, Coaching + App renew at ¥0 as companions (FVP pattern)
- **Solo bundles (1016–1017):** Coaching is anchor, App renews at ¥0 companion

This confirms the ¥0 App charge pattern:
- `trn_charge` for App always has `paid_price = 0`
- Revenue is embedded in the Coaching (or Lesson) anchor charge
- Our allocation splits the Coaching charge's N between Coaching and App

### 5. Old Plans vs New Plans — NOT a Replacement at Data Layer (Q1 + Q2)

The word "replace" refers ONLY to the coaching page display:
- Students see new bundle plans instead of old coaching-only plans
- Old plans (71, 94, 1005–1014) and product 10012 are **retained untouched**
- No migration, no deprecation, no deletion of legacy rows

**For ASC-CIP:** This means old plan_ids still have active subscribers. The CIP upstream project adds App as companion to these EXISTING plans. Our CIP allocation must only target charges AFTER CIP goes live (date filter). Students on legacy plans without App companion are not allocated.

### 6. Pricing Model — Single package_price (Q5)

Each plan has ONE package_price — NOT a sum of individual product prices. The tax-inclusive price in the plan table above is what the student pays. The per-product split (Coaching vs App) is not visible anywhere in the purchasing system — that's what our allocation calculates.

### 7. What's Displayed vs What's Seeded

| Category | Plans | Displayed on coaching page? |
|---|---|---|
| Currently displayed (swapped) | 1016–1019, 1022–1023 | ✅ Yes (6 plans) |
| Seeded but not displayed | 1020–1021, 1024–1025, 1026–1027 | ❌ No (but purchasable via admin) |

**For ASC:** All 12 plans need allocation regardless of whether they're displayed on the coaching page. If a charge exists for plan 1020 (created via admin registration), it still needs its coaching revenue split.

---

## What This Confirms/Changes for Our Technical Design

| Item | Before this doc | After this doc |
|---|---|---|
| Plan_ids | 1016–1027 (already confirmed) | ✅ Re-confirmed with full product breakdown |
| Product contents per plan | Assumed | ✅ Now have exact product_ids per plan |
| App product | 10021 (already confirmed) | ✅ Re-confirmed with pricing model |
| Legacy 10012 | Assumed retained | ✅ Explicitly confirmed retained untouched |
| Renewal model | Assumed ¥0 companion | ✅ Confirmed: Coaching anchor, App = ¥0 companion (Q10) |
| B2B variants | Unknown | ⚠️ Deferred — no plan_id yet (out of scope Phase 1) |
| 6 vs 12 plans displayed | Unknown | Clarified — all 12 need allocation, only 6 are on the coaching page |
| Detection approach | product_id 10021 (Kuroda-san) | ✅ Validated — upstream uses product_type=100 for feature detection; we use product_id=10021 for charge-level bundle identification |

---

## Status of Upstream CAP Implementation

| Repo | Status | PR |
|---|---|---|
| ls-database-migrations | ✅ Done (Keith, PR #804) | Product 10021 + 12 plans seeded |
| MBTI_backend | Requirements updated, coding in progress | PR #6310 |
| bizmates.jp | Requirements updated, coding in progress | PR #20763 |
| MBTI_frontend | Requirements updated | PR #6413 |

**All blocking questions resolved.** Non-blocking: Q4 (copy text), Q6 (icon asset), Q7 (layout).

---

## Related Jira (CAP upstream)

- Shared Epics: CAP-36 (Requirements) · CAP-38 (Coding) · CAP-37 (Code Review)
- ls-database-migrations: CAP-59 / CAP-60 / CAP-61
- MBTI_backend: CAP-79 / CAP-80 / CAP-81
- bizmates.jp: CAP-69 / CAP-70 / CAP-71
- MBTI_frontend: CAP-89 / CAP-90 / CAP-91

---

*Content was rephrased for compliance with licensing restrictions*  
*Source: CAP Confluence space, Terry Merwin C Balahadia, 2026-08-10*
