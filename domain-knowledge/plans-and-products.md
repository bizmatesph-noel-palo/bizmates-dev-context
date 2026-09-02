# Plans & Products — System Reference

## Document Info

| | |
|---|---|
| **Document type** | Domain Knowledge (system reference) |
| **Date** | 2026-08-14 (Created) · 2026-08-28 (product_id changes: App 10021→10022, CIP coaching 10022→10025; CIP prices updated per REF-CIP-04) |
| **Author** | Noel Palo |
| **Assisted by** | Kiro |
| **Status** | Active |
| **Audience** | Dev team (all ASC projects), PM, SDM |
| **Source** | Database queries (dev04), confirmed against `ls-database-migrations` schema; CAP/CIP updates from `research/CAP/` and `research/CIP/REF-CIP-04` |
| **Scope** | All plan and product data relevant to the accounting system (ASC) |

---

## How ASC Routes Charges

The accounting system categorizes charges by `product_id` / `product_type` and routes them through different calculation pipelines:

```
trn_charge (all charges)
│
├─── product_id IN BizmatesMonthlyPlanEnum (16–23, 27–29)
│    → SKIP daily rate calculation
│    → MonthlyRateCalculationLogic (CTE pipeline)
│    → log_monthly_rate_calculation
│
├─── product_type = 8 (Bizmates Test)
│    → SKIP daily proration (NotDailyCalculationProductType)
│    → Writes full amount at start_date
│
├─── product_id = 10022 (App — new id, was 10021) with plan_id IN CAP/CIP plans
│    → Daily rate (writes ¥0)
│    → ★ ASC Allocation overwrites 0 → P_app
│
├─── product_id IN (10005, 10015, 10025) with plan_id IN CAP/CIP plans
│    → Daily rate (writes N = full coaching amount)
│    → ★ ASC Allocation overwrites N → P_coaching
│    (10005/10015 = CAP coaching, 10025 = CIP coaching intensive — new id, was 10022)
│
└─── Everything else
     → CommonUtil::createDailyRateCalculation()
     → Daily proration: ceil(paid_price / total_days × contract_days)
     → log_daily_rate_calculation
```

---

## Bizmates — Product Types

| product_type | Category | Products | ASC Pipeline |
|---|---|---|---|
| 1 | Online Lesson | 1, 2, 3, 4, 16–23, 27–29 | Daily (1–4) or Monthly (16–29) |
| 5 | Full Video Package (FVP) | 10011 | Daily (always ¥0 companion) |
| 8 | Bizmates Test | (various) | Excluded from daily proration |
| 9 | Coaching | 10005, 10015, 10025 | Daily rate (10025 = CIP intensive, new id) |
| 100 | App | 10012, 10022 | Daily rate (¥0 for CAP/CIP, allocated). 10022 = new App id (was 10021) |

---

## Bizmates — Products

| product_id | Name | product_type | Category | Notes |
|---|---|---|---|---|
| 1 | 毎日25分プラン | 1 | Online Lesson (Daily) | Legacy daily + current 1-lesson |
| 2 | 毎日50分プラン | 1 | Online Lesson (Daily) | Legacy daily + current 2-lesson |
| 3 | 毎日75分プラン | 1 | Online Lesson (Daily) | Legacy daily + current 3-lesson |
| 4 | 毎日100分プラン | 1 | Online Lesson (Daily) | Legacy daily + current 4-lesson |
| 16 | 月8回プラン | 1 | Monthly (8L/month, 1/day) | `BizmatesMonthlyPlanEnum` |
| 17 | 月12回プラン | 1 | Monthly (12L/month, 1/day) | `BizmatesMonthlyPlanEnum` |
| 18 | 月16回プラン | 1 | Monthly (16L/month, 1/day) | `BizmatesMonthlyPlanEnum` |
| 19 | 月20回プラン | 1 | Monthly (20L/month, 1/day) | `BizmatesMonthlyPlanEnum` |
| 20 | 月8回1日2回プラン | 1 | Monthly (8L/month, 2/day) | `BizmatesMonthlyPlanEnum` |
| 21 | 月12回1日2回プラン | 1 | Monthly (12L/month, 2/day) | `BizmatesMonthlyPlanEnum` |
| 22 | 月16回1日2回プラン | 1 | Monthly (16L/month, 2/day) | `BizmatesMonthlyPlanEnum` |
| 23 | 月20回1日2回プラン | 1 | Monthly (20L/month, 2/day) | `BizmatesMonthlyPlanEnum` |
| 27 | 月10回プラン | 1 | Monthly (10L/month, 1/day) | `BizmatesMonthlyPlanEnum` |
| 28 | 月10回1日2回プラン | 1 | Monthly (10L/month, 2/day) | `BizmatesMonthlyPlanEnum` |
| 29 | 月15回プラン | 1 | Monthly (15L/month, 1/day) | `BizmatesMonthlyPlanEnum` — FLP |
| 10005 | Bizmates Coaching 15分 | 9 | Coaching | 15-minute sessions |
| 10011 | Full Video Package | 5 | FVP | Always ¥0 companion |
| 10012 | Bizmates App 標準コース | 100 | App (Legacy) | Standalone App — retained untouched |
| 10015 | Bizmates Coaching 30分 | 9 | Coaching | 30-minute sessions |
| 10022 | Bizmates Appプレミアム | 100 | App (CAP/CIP) | New — ¥0 companion in bundles. **id changed 10021→10022 (2026-08-19, Go-san)** |
| 10025 | Bizmates Coaching 30分 短期集中プラン | 9 | Coaching Intensive | New — CIP product. **id changed 10022→10025 (2026-08-19)**. Solo plan ¥75,900 tax-incl (was ¥88,000) |

---

## Bizmates — Plans (By Category)

### Legacy Daily Plans (plan_id 1–4)

Single-product plans. No FVP, no coaching.

| plan_id | Name | package_price (tax-excl) | Products |
|---|---|---|---|
| 1 | 毎日25分プラン | ¥12,000 | product 1 |
| 2 | 毎日50分プラン | ¥18,000 | product 2 |
| 3 | 毎日75分プラン | ¥27,000 | product 3 |
| 4 | 毎日100分プラン | ¥36,000 | product 4 |

### Current Daily + FVP Plans (plan_id 1001–1004)

Lesson + Full Video Package bundle.

| plan_id | Name | package_price | Products |
|---|---|---|---|
| 1001 | 毎日1レッスンプラン | ¥14,850 | 1 + 10011 (FVP) |
| 1002 | 毎日2レッスンプラン | ¥21,450 | 2 + 10011 |
| 1003 | 毎日3レッスンプラン | ¥31,350 | 3 + 10011 |
| 1004 | 毎日4レッスンプラン | ¥41,250 | 4 + 10011 |

### Monthly 15 Plan (plan_id 1015)

| plan_id | Name | package_price | Products |
|---|---|---|---|
| 1015 | 毎月15回まとめてレッスンプラン | ¥14,850 | 29 + 10011 (FVP) |

Note: Product 29 (月15回プラン) is in `BizmatesMonthlyPlanEnum` — processed by monthly CTE, not daily rate.

### Coaching Standalone Plans (plan_id 71, 94)

| plan_id | Name | package_price | Products |
|---|---|---|---|
| 71 | Bizmates Coaching 15分 | ¥18,000 | 10005 |
| 94 | Bizmates Coaching 30分 | ¥39,600 | 10015 |

Note: plan_id 94 package_price is ¥39,600 (tax-inclusive). Inconsistent with plan 71 which is ¥18,000 (tax-exclusive).

### Coaching + Lesson + FVP Packages (plan_id 1005–1014)

Existing coaching packages. Lesson + FVP + Coaching (no App).

| plan_id | Name | package_price | Products | Coaching |
|---|---|---|---|---|
| 1005 | 毎日1レッスン + Coaching 15分 | ¥34,650 | 1 + 10005 + 10011 | 15min |
| 1006 | 毎日2レッスン + Coaching 15分 | ¥41,250 | 2 + 10005 + 10011 | 15min |
| 1007 | 毎日3レッスン + Coaching 15分 | ¥51,150 | 3 + 10005 + 10011 | 15min |
| 1008 | 毎日4レッスン + Coaching 15分 | ¥61,050 | 4 + 10005 + 10011 | 15min |
| 1009 | 初心者パッケージ + Coaching 15分 | ¥34,650 | 1 + 10005 + 10011 | 15min |
| 1010 | 毎日1レッスン + Coaching 30分 | ¥54,450 | 1 + 10015 + 10011 | 30min |
| 1011 | 毎日2レッスン + Coaching 30分 | ¥61,050 | 2 + 10015 + 10011 | 30min |
| 1012 | 毎日3レッスン + Coaching 30分 | ¥70,950 | 3 + 10015 + 10011 | 30min |
| 1013 | 毎日4レッスン + Coaching 30分 | ¥80,850 | 4 + 10015 + 10011 | 30min |
| 1014 | 初心者パッケージ + Coaching 30分 | ¥54,450 | 1 + 10015 + 10011 | 30min |

Note: Plans 1010/1011 are eligible for Honki Set campaign.

### CAP Plans (plan_id 1016–1027) — Coaching + App Bundles

New plans bundling Coaching + App. App charges at ¥0 (companion). **ASC allocation required.**

| plan_id | Name | package_price | Products | Coaching | App |
|---|---|---|---|---|---|
| 1016 | Solo C15 + App | ¥22,550 | 10005 + 10022 | 15min | ¥0 |
| 1017 | Solo C30 + App | ¥42,350 | 10015 + 10022 | 30min | ¥0 |
| 1018 | L25 + FVP + C15 + App | ¥37,400 | 1 + 10011 + 10005 + 10022 | 15min | ¥0 |
| 1019 | L50 + FVP + C15 + App | ¥44,000 | 2 + 10011 + 10005 + 10022 | 15min | ¥0 |
| 1020 | L75 + FVP + C15 + App | ¥53,900 | 3 + 10011 + 10005 + 10022 | 15min | ¥0 |
| 1021 | L100 + FVP + C15 + App | ¥63,800 | 4 + 10011 + 10005 + 10022 | 15min | ¥0 |
| 1022 | L25 + FVP + C30 + App | ¥57,200 | 1 + 10011 + 10015 + 10022 | 30min | ¥0 |
| 1023 | L50 + FVP + C30 + App | ¥63,800 | 2 + 10011 + 10015 + 10022 | 30min | ¥0 |
| 1024 | L75 + FVP + C30 + App | ¥73,700 | 3 + 10011 + 10015 + 10022 | 30min | ¥0 |
| 1025 | L100 + FVP + C30 + App | ¥83,600 | 4 + 10011 + 10015 + 10022 | 30min | ¥0 |
| 1026 | L15mo + FVP + C15 + App | ¥37,400 | 29 + 10011 + 10005 + 10022 | 15min | ¥0 |
| 1027 | L15mo + FVP + C30 + App | ¥57,200 | 29 + 10011 + 10015 + 10022 | 30min | ¥0 |

> **App product_id = 10022** (changed from 10021 on 2026-08-19, Go-san approved). CAP plan package prices above are pre-change figures — verify against latest CAP price matrix.

**Upstream project:** CAP (Coaching and App Plan)  
**ASC project:** ASC-CAP  
**package_price:** Tax-inclusive  
**Source:** REF-CAP-08 (PO-confirmed plan spreadsheet)

### CIP Plans (plan_id 1028–1032) — Coaching Intensive + App Bundles

New premium coaching product. **ASC allocation required.**

| plan_id | Name | package_price (tax-excl) | Products | Coaching | App |
|---|---|---|---|---|---|
| 1028 | Coaching Intensive (Solo) | ¥75,900 | 10025 + 10022 | Intensive | ¥0 |
| 1029 | 1L + FVP + Coaching Intensive | ¥90,750 | 1 + 10011 + 10025 + 10022 | Intensive | ¥0 |
| 1030 | 2L + FVP + Coaching Intensive | ¥97,350 | 2 + 10011 + 10025 + 10022 | Intensive | ¥0 |
| 1031 | 3L + FVP + Coaching Intensive | ¥107,250 | 3 + 10011 + 10025 + 10022 | Intensive | ¥0 |
| 1032 | 4L + FVP + Coaching Intensive | ¥117,150 | 4 + 10011 + 10025 + 10022 | Intensive | ¥0 |

> **Updated 2026-08-24 (REF-CIP-04):** Coaching Intensive product_id = **10025** (was 10022). App = **10022** (was 10021). Prices are tax-incl full price per Jefferson's matrix (Solo ¥75,900, was ¥88,000). Base formula: ¥69,000 pre-tax (Coaching Intensive + App) + Online Lesson.
> **⚠️ O-8:** Plans 1029–1032 bundle Lesson + Coaching Intensive + App (3 products) — confirm whether allocation is 2-way (Coaching+App) or 3-way before ASCI.

**Upstream project:** CIP (Coaching Intensive Plan)  
**ASC project:** ASC-CIP  
**package_price:** Tax-exclusive  
**Source:** REF-CIP-03 (Jefferson's project spec)

---

## Zipan — Products

Zipan is a Japanese-language training service. All products are lesson-based (product_type = 1). No coaching, no App.

| product_id | Name | product_type | lesson_volume | Notes |
|---|---|---|---|---|
| 16 | 月5回プラン | 1 | 5 | `ZipanMonthlyPlanEnum` |
| 17 | 月10回プラン | 1 | 10 | `ZipanMonthlyPlanEnum` |
| 18 | 月15回プラン | 1 | 15 | `ZipanMonthlyPlanEnum` |
| 19 | 2 times/month for demo | 1 | 2 | Trial/demo only |
| 20 | ビデオプラン | 1 | — | Video plan (demo) |
| 25 | 1 time/month for demo | 1 | 1 | Trial/demo only |
| 30 | 3 time/month for demo | 1 | 3 | Trial/demo only |
| 31 | 4 time/month for demo | 1 | 4 | Trial/demo only |
| 32 | 5 time/month for demo | 1 | 5 | Trial/demo only |

### Zipan Plan Structure

| Category | plan_id range | Count | Notes |
|---|---|---|---|
| Standard B2C | 16 | 1 | 月5回プラン, ¥13,500 |
| B2B Corporate (日本語研修) | 20000001–20000201 | ~200 | All ¥0 (company-paid), products 16/17/18 |
| B2B2C Partner | 30000021–30012009 | ~700+ | All ¥0, product 16 only |
| Demo/Trial | 20000003, 20000012, etc. | ~50 | Products 19/25/30/31/32 |

**Key difference from Bizmates:** Zipan is B2B-only (Japanese companies paying for foreign employees to learn Japanese). The only paid B2C plan is plan_id 16 (月5回プラン). Everything else is corporate-sponsored at ¥0.

**ASC impact:** All Zipan products are monthly-plan type. They go through `ZipanUtil::createDailyRateCalculation()` and `ZipanMonthlyPlanEnum` — completely separate from Bizmates. No coaching or App products exist on Zipan. CAP/CIP allocation does NOT apply to Zipan.

---

## ASC Allocation Reference Prices

For charges that go through ASC allocation (CAP/CIP plans only):

| Project | Product | product_id | L (reference price, tax-incl) | Used as |
|---|---|---|---|---|
| ASC-CAP | App Premium | **10022** (was 10021) | ¥3,980 | Numerator weight |
| ASC-CAP | Coaching 15min | 10005 | ¥19,800 | Denominator component |
| ASC-CAP | Coaching 30min | 10015 | ¥39,600 | Denominator component |
| ASC-CIP | App Premium | **10022** (was 10021) | ¥3,980 | Numerator weight |
| ASC-CIP | Coaching Intensive | **10025** (was 10022) | 🔴 ¥84,020 STALE — O-5 reopened (plan now ¥75,900; new L_coaching pending) | Denominator component |

Formula: `P_app = floor(N × L_app / (L_coaching + L_app))`

---

## Cross-Reference: How to Identify Plan Categories in Code

| Category | Detection method | Where used |
|---|---|---|
| Monthly plans | `BizmatesMonthlyPlanEnum::exists($productId)` | CommonUtil line 401 (skip in daily rate) |
| Zipan monthly | `ZipanMonthlyPlanEnum::exists($productId)` | ZipanUtil (skip in daily rate) |
| CAP bundles | `CoachingAndAppPlanEnum::exists($planId)` or `product_id = 10022` | RevenueAllocationService (new) |
| CIP bundles | `CoachingIntensivePlanEnum::exists($planId)` or `product_id = 10022` | RevenueAllocationService (new) |
| Excluded from proration | `NotDailyCalculationProductType` config (product_type 8) | CommonUtil (full amount at start_date) |

---

## Key Rules

1. **product_id determines the ASC pipeline** — not plan_id. Monthly plan enum checks product_id. Allocation detects by App product_id 10022 (changed from 10021 on 2026-08-19).
2. **plan_id determines bundle membership** — for distinguishing CAP vs CIP vs existing coaching.
3. **Zipan never has coaching or App** — CAP/CIP allocation is Bizmates-only.
4. **¥0 companions (FVP, App) still create log rows** — they're not filtered out by any price check in getTrnChargeList() or getContractDateInfoList().
5. **Monthly plan products (16–29) are EXCLUDED from daily rate** — they go through the separate MonthlyRateCalculationLogic CTE pipeline.
6. **package_price inconsistency** — some plans store tax-exclusive (plan 71: ¥18,000), some store tax-inclusive (plan 94: ¥39,600, CAP plans). Always verify per plan.
