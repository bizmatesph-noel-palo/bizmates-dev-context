# 22 — CalculationSummary Is a Superset (Not Just Daily + Monthly)

> **TL;DR:** CalculationSummary includes data from 4 sources: DailyRate + MonthlyRate + Ticket Usage + OtherSales. Comparing only Daily + Monthly against CalculationSummary will always show a difference — the Ticket and OtherSales rows are additional input streams that only exist in the summary.

---

## Problem Pattern

A stakeholder compares the total paid_price from `DailyRateCalculation` + `MonthlyRateCalculation` CSVs against `CalculationSummary` CSV and finds a mismatch. The mismatch is not a bug — CalculationSummary intentionally includes more data.

---

## How We Encountered It

After the June 2026 Pre batch (2026-07-01), accounting reported a ¥4,501,467 discrepancy between CalculationSummary and Daily + Monthly combined. Investigation traced it to 3 row groups: Paypal(Tickets) for Bizmates/Zipan and OtherSales (product_type 11, B2B corporate materials).

**JIRA:** ASC-308

---

## The Composition

```
CalculationSummary = DailyRate + MonthlyRate + Ticket Usage + OtherSales
```

| Component | Source Table/View | Appears in individual CSV? |
|---|---|---|
| Daily charges | `log_daily_rate_calculation` (or `_pre`) | ✅ DailyRateCalculation CSV |
| Monthly charges | `log_monthly_rate_calculation` (or `_pre`) | ✅ MonthlyRateCalculation CSV |
| Ticket Usage | `v_lesson_ticket_history_stat_monthly` | ❌ Only in CalculationSummary |
| OtherSales | `trn_other_sales_charge` | ❌ Only in CalculationSummary |

---

## How Each Additional Stream Gets In

### Ticket Usage (`ticket_flg = 1`)

Inserted by `CommonUtil::createLogSumCalculation()` after the main aggregation:

```php
$ticketinfo = VLessonTicketHistoryStatMonthly::getVLessonTicketHistoryStatMonthly($targetYm);
// paid_price = used + expired (aggregate of all ticket consumption for the month)
// partner = "Paypal(Tickets)", contract_type = 0, ticket_flg = 1
```

This is NOT per-charge revenue — it's an aggregate metric of lesson ticket lifecycle across all students.

### OtherSales (product_type 11)

Inserted by `CommonUtil` during CalculationSummary CSV generation (~L1399):

```php
$sumLists = TrnOtherSalesCharge::getTrnOtherSalesChargeSumForDeliveryDate($start, $end);
// B2B corporate material/service sales, grouped by order_no
// Not lesson-based, not from trn_charge — separate source table
```

These are non-lesson B2B sales (corporate materials, custom services) with their own `delivery_date` recognition.

---

## Why This Was Never Visible Before ASC

Before the ASC project, only `DailyRateCalculation` CSV existed — and it was rarely compared against CalculationSummary directly. The ASC project introduced `MonthlyRateCalculation` as a separate CSV, which made people assume `Daily + Monthly = Summary`. That equation was never true.

---

## Prevention Checklist

- [ ] When comparing CSV totals, account for ALL input streams (not just Daily + Monthly)
- [ ] Document the CalculationSummary composition in any reconciliation guide given to accounting
- [ ] If new data streams are added to CalculationSummary, document them here

---

## How to Identify These Rows in CalculationSummary

| Row type | Identifying features |
|---|---|
| Paypal(Tickets) | `取引先名` = "Paypal(Tickets)", `プロダクトタイプ` = blank, `契約種類` = 0 |
| OtherSales | `プロダクトタイプ` = 11, `契約種類` = 1 (B2B), specific corporate order numbers |

---

## See Also

- **KB 12** — Stale Aggregation Data: related pattern of downstream consumers needing multiple sources
- **Investigation:** `[bizmates-dev-context] projects/ascm/technical-notes/investigation/20260701-calculation-summary-mismatch/REPORT_00_CalculationSummary_Mismatch_Investigation.md`
