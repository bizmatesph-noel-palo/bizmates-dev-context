# CalculationSummary Mismatch — Extra Rows Not in Daily/Monthly (20260701)

**Reported by:** Kuroda-san
**JIRA Ticket:** [ASC-308](https://bizmates.atlassian.net/browse/ASC-308)
**Investigated by:** Noel
**Date:** 2026-07-01
**Environment:** Production (Pre batch output CSVs)
**Batch run analyzed:** June 2026 Pre (exeDate = 2026-07-01)

---

## Summary

CalculationSummary total (¥288,564,252) is ¥4,501,467 higher than DailyRateCalculation (¥273,598,754) + MonthlyRateCalculation (¥10,464,031) combined (¥284,062,785).

**Root cause (confirmed via code trace + CSV verification):** CalculationSummary includes data from **additional input streams** beyond Daily and Monthly — specifically Ticket Usage aggregation and OtherSales (B2B corporate materials). These are separate code paths that insert directly into `log_sum_calculation` and were never designed to appear in the individual Daily or Monthly CSVs.

**This is NOT a side effect of the ASC project split.** The code already correctly unions both Daily and Monthly logs when building CalculationSummary. The additional Ticket + OtherSales rows existed before ASC and were always CalculationSummary-only.

---

## The Discrepancy Breakdown

| # | Content | Product Type | Contract Type | Rows | Amount | Source |
|---|---|---|---|---|---|---|
| 1 | Bizmates | (blank) | 0 | 1 | ¥1,853,940 | Paypal(Tickets) — `v_lesson_ticket_history_stat_monthly` |
| 2 | Bizmates | 11 | 1 | 9 | ¥2,631,687 | OtherSales — `trn_other_sales_charge` (9 corporate orders) |
| 3 | Zipan | (blank) | 0 | 1 | ¥15,840 | Paypal(Tickets) — `v_lesson_ticket_history_stat_monthly` |

**Sum: ¥1,853,940 + ¥2,631,687 + ¥15,840 = ¥4,501,467** — matches the full discrepancy exactly. No other rows are involved.

Verified from generated CSVs: these rows exist ONLY in `CalculationSummary(20260701).csv` and have zero matching entries in `DailyRateCalculation(20260701).csv` or `MonthlyRateCalculation(20260701).csv`.

---

## What CalculationSummary Actually Contains

CalculationSummary is a **superset** — it aggregates multiple input streams:

```
CalculationSummary = Daily charges + Monthly charges + Ticket Usage + OtherSales
```

| Component | Source | Appears in individual CSV? |
|---|---|---|
| Daily charges | `log_daily_rate_calculation_pre` | ✅ DailyRateCalculation CSV |
| Monthly charges | `log_monthly_rate_calculation_pre` | ✅ MonthlyRateCalculation CSV |
| Ticket Usage | `v_lesson_ticket_history_stat_monthly` | ❌ Only in CalculationSummary |
| OtherSales | `trn_other_sales_charge` | ❌ Only in CalculationSummary |

The comparison `CalculationSummary = Daily + Monthly` was never the correct equation.

---

## Code Trace

### How CalculationSummary is Built

**Function:** `[ASC] app/Libs/CommonUtil.php` → `createLogSumCalculation()` (~L460-565)

**Step 1:** Aggregate Daily + Monthly (via `getPaidPriceSumList`)
```php
if ($preFlg) {
    $sumLists = \App\Models\LogDailyRateCalculationPre::getPaidPriceSumList($targetYm);
} else {
    $sumLists = \App\Models\LogDailyRateCalculation::getPaidPriceSumList($targetYm);
}
```

**Step 2:** Insert Ticket Usage row
```php
$ticketinfo = \App\Models\VLessonTicketHistoryStatMonthly::getVLessonTicketHistoryStatMonthly($targetYm);
if (!empty($ticketinfo)) {
    $condition = array(
        'target_ym' => $targetYm,
        'contract_type' => 0,
        'partner_id' => config('code.partnerId.paypal'),  // Partner: "Paypal(Tickets)"
        'paid_price' => $ticketinfo->used + $ticketinfo->expired,
        'ticket_flg' => 1,
    );
    // Inserts directly into log_sum_calculation (or _pre)
}
```

**Step 3:** (In CalculationSummary CSV generation) Insert OtherSales rows
```php
$sumLists = \App\Models\TrnOtherSalesCharge::getTrnOtherSalesChargeSumForDeliveryDate(
    $targetYmd->format('Y/m/d'), $targetYmd->lastOfMonth()->format('Y/m/d')
);
// Adds directly to CalculationSummary CSV data (product_type from mst_product)
```

### getPaidPriceSumList Already Handles the ASC Split

**File:** `[ASC] app/Models/LogDailyRateCalculationPre.php` (~L73-100)

```php
$daily = DB::table('log_daily_rate_calculation_pre')
    ->select([...])
    ->where('target_ym', '=', $targetYm)
    ->whereNotIn('product_id', BizmatesMonthlyPlanEnum::toArray()); // Excludes monthly plans

$monthly = DB::table('log_monthly_rate_calculation_pre')
    ->select([...])
    ->where('target_ym', '=', $targetYm);

return $daily->unionAll($monthly);  // Both sources combined
```

This UNION ALL was added during the ASC project to ensure CalculationSummary includes both Daily and Monthly data after the split. It works correctly — the mismatch is NOT from missing monthly data in the summary.

---

## Is This a Side Effect of the ASC Project?

**No.**

| Phase | What happened | CalculationSummary formula |
|---|---|---|
| **Before ASC** | All charges (daily + monthly plans) in one `log_daily_rate_calculation` | `DailyRate(all) + Tickets + OtherSales` |
| **After ASC** | Monthly plans separated into `log_monthly_rate_calculation` | `DailyRate(non-monthly) + MonthlyRate + Tickets + OtherSales` |

The `getPaidPriceSumList` function correctly unions both tables with a `UNION ALL`. The Ticket and OtherSales additions existed BEFORE the ASC project and were always CalculationSummary-only — they were never part of the Daily calculation output.

If someone had compared `DailyRateCalculation CSV total` vs `CalculationSummary total` before the ASC project, the same Ticket + OtherSales difference would have been present. The ASC split didn't create this gap — it was always there.

---

## Why This Surfaced Now

Before the ASC project, only `DailyRateCalculation` CSV existed — and it was rarely compared against CalculationSummary directly. The original developer who built the system knew CalculationSummary was a superset (it included Tickets and OtherSales). That knowledge was implicit — never explicitly documented.

After ASC introduced `MonthlyRateCalculation` as a separate CSV, it created the natural expectation that `Daily + Monthly = Summary`. This formula was never true, but it looks like it should be — two parts that make up the whole. The separation made people compare the parts against the whole for the first time, revealing a difference that always existed but was previously hidden inside one aggregate number.

This is not a bug that was missed — it's a **documentation gap**. The composition of CalculationSummary was never explicitly stated. The restructuring surfaced implicit knowledge that wasn't transferred when the pipeline was split.

---

## The 3 Data Streams Explained

### 1. Paypal(Tickets) — Ticket Usage Aggregation

- **What it is:** Total value of lesson tickets consumed (used + expired) in the month
- **Source:** `v_lesson_ticket_history_stat_monthly` — a database view that aggregates ticket lifecycle
- **Why it's separate:** This is not per-charge revenue. It's an aggregate metric of ticket consumption across ALL students for the month. There's no individual `trn_charge` record for this — it's computed from ticket status changes.
- **Identified by:** `ticket_flg = 1`, partner = "Paypal(Tickets)", blank product_type

### 2. OtherSales (product_type 11) — B2B Corporate Materials

- **What it is:** B2B corporate sales of materials/services (not lesson-based)
- **Source:** `trn_other_sales_charge` — a separate charge table for non-lesson products
- **Why it's separate:** These charges don't have tickets, don't have lesson consumption, and don't go through the Daily or Monthly calculation pipeline. They're direct sales with `delivery_date` as the recognition trigger.
- **Identified by:** `product_type = 11`, `contract_type = 1` (B2B), specific corporate `order_no` values
- **The 9 orders:** 10026308, 100267261, 10028578, 10028508, 10029243, 10030027, 10029994, 10030050, 10030248

### 3. Zipan Paypal(Tickets)

- Same as #1 but for Zipan tenant. Separate row because it's a different DB view query on the Zipan connection.

---

## Scope Assessment

| Aspect | Assessment |
|---|---|
| Is this a bug? | **No** — by design. CalculationSummary is a superset. |
| Is this ASC-related? | **No** — the Ticket + OtherSales paths existed before ASC. |
| Is this ASC-304 related? | **No** — ASC-304 is about PayPal CSVs missing monthly data (different issue). |
| Data loss? | **No** — all data is present where it should be. |
| Action needed? | Clarification from accounting team on whether this is expected or needs a change. |

---

## Next Steps

- [ ] Confirm with Kuroda-san / accounting team: is this expected behavior?
- [ ] If expected: document the CalculationSummary composition (Daily + Monthly + Tickets + OtherSales)
- [ ] If change requested: determine whether to add Tickets/OtherSales to a separate CSV breakdown, or remove them from CalculationSummary, or add them to Daily/Monthly CSVs

---

## Cross-Reference

- Code: `[ASC] app/Libs/CommonUtil.php` — ticket insertion (~L545), OtherSales CSV insertion (~L1399)
- Model: `[ASC] app/Models/TrnOtherSalesCharge.php` — `getTrnOtherSalesChargeSumForDeliveryDate()`
- Model: `[ASC] app/Models/VLessonTicketHistoryStatMonthly.php` — `getVLessonTicketHistoryStatMonthly()`
- Model: `[ASC] app/Models/LogDailyRateCalculationPre.php` — `getPaidPriceSumList()` (UNION ALL proof)
- NOT related: ASC-304 (PayPal CSV missing monthly data — different issue, different data paths)
- KB: `[bizmates-dev-context] projects/ascm/knowledge-base/12-stale-aggregation-data.md`
