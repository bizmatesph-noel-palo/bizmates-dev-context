# PaypalPaymentSum Discrepancy — paid_price Mismatch (20260625)

**Reported by:** Wu-san (Sizhe Wu)
**JIRA Ticket:** [ASC-304](https://bizmates.atlassian.net/browse/ASC-304)
**Investigated by:** Noel
**Date:** 2026-06-25
**Environment:** Production (Metabase) + Local Docker
**Batch run analyzed:** May 2026 (target_ym = 202605, generated 2026-06-18)

---

## Summary

The `PaypalPaymentSum_202605(20260618).csv` reports a total `paid_price` (J7+J8 cells) that does not match the sum of `paid_price` from `202605_03_MonthlyRateCalculation(20260618).csv` + `202605_03_DailyRateCalculation(20260618).csv` for the same charges (filtered by `contract_type IN (0, 2)` and `charge_type <> 1`).

**Root cause (confirmed with code trace + production data):** The PaypalPaymentSum and PaypalPayment CSV files only query `log_daily_rate_calculation` for the "uriage" (revenue) breakdown — they do not include `log_monthly_rate_calculation`. Since ASC separated monthly-plan charges into their own calculation path, those charges are no longer in the daily log table, creating a gap.

**Fix status:** Code fix applied to 4 locations (CommonUtil × 2, ZipanUtil × 2). Merged to ASC-master. Smoke test passed locally (`SendJournalsDataCommand` completed without error). Data verification confirms the gap (monthly log has data, daily log is empty for affected charges). Local CSV output shows correct behavior (Zipan 差引=0 for fully-processed months).

---

## Affected Files

| CSV File | What it reports | Source table |
|---|---|---|
| `PaypalPaymentSum_YYYYMM` | Monthly summary: total PayPal paid_price vs sum of revenue breakdown | `trn_charge` (paid_price) vs `log_daily_rate_calculation` (uriage) |
| `PayPalPayment_YYYYMM` | Per-charge detail: paid_price vs 6-month revenue breakdown | `trn_charge` (paid_price) vs `log_daily_rate_calculation` (uriage) |
| `MonthlyRateCalculation_YYYYMM` | Monthly plan revenue (lesson consumption) | `log_monthly_rate_calculation` |
| `DailyRateCalculation_YYYYMM` | Daily rate revenue (pro-rata) | `log_daily_rate_calculation` |

---

## PayPal CSV Files — How They Work

### The 3 Files

| File | Granularity | What each row represents |
|---|---|---|
| **Bizmates_PaypalPayment_YYYYMM** | Per-charge | One row per B2C/B2B2C PayPal charge paid in that month |
| **Zipan_PaypalPayment_YYYYMM** | Per-charge | Same as above, for Zipan |
| **PaypalPaymentSum_YYYYMM** | Per-month | One row per month — total of all PayPal charges paid in that month (contains both Bizmates and Zipan sections in one file) |

### What Each File Shows

**Detail files (Bizmates/Zipan_PaypalPayment):**

| Column | Source | Meaning |
|---|---|---|
| 支払金額 (paid) | `trn_charge.paid_price` | What was actually charged to the student |
| 合計 (uriage sum) | `log_daily_rate_calculation` + `log_monthly_rate_calculation` | Total revenue recognized across the 6-month window |
| 差引 (difference) | paid − uriage sum | Should be 0 when fully recognized |
| 月別売上 (monthly breakdown) | Same log tables, per month | Revenue attributed to each of the 6 months |

**Summary file (PaypalPaymentSum):**

| Column | Source | Meaning |
|---|---|---|
| 入金額 (paid) | SUM of `trn_charge.paid_price` for all charges paid in that month | Total PayPal income for the month |
| 売上合計 (uriage sum) | SUM of revenue breakdown for those charges | Total recognized revenue |
| 差引 (difference) | paid − uriage sum | Should converge to 0 as all months are processed |
| 月別売上 | Same, aggregated per month | Revenue distribution across the 6-month rolling window |

### How They Relate

```
Bizmates_PaypalPayment  ──┐
(per-charge detail)       │     PaypalPaymentSum
                          ├──→  (monthly totals, Bizmates + Zipan in one file)
Zipan_PaypalPayment     ──┘
(per-charge detail)

Note: They query the same data independently — the summary is NOT derived
from the detail files. Both read from trn_charge + log tables directly.
```

### The 6-Month Rolling Window

Each file shows a 6-month window of revenue recognition. For a charge paid in January:
- The revenue might be recognized across Jan–Jun (depending on when lessons are taken/expired)
- The 差引 (difference) shows how much is NOT YET recognized
- When all 6 months are processed, 差引 should equal 0

### Filter Conditions

All three files use the same base filter for which charges to include:
- `paid = 1` (payment completed)
- `status = 1` (active)
- `charge_type <> 1` (excludes ticket purchases)
- `contract_type IN (0, 2)` (B2C + B2B2C only — B2B excluded)

---

## Code Trace

### PaypalPayment file (`createPaypalPaymentFile`, CommonUtil.php ~L2174)

```php
$selectItem[] = '(select case when 1='. $isFuture .' then 0 else sum(paid_price) end as paid_price
    from log_daily_rate_calculation
    where target_ym = '. $startDate->format('Ym') .'
    and charge_id = trn_charge.id
    group by charge_id) AS uriage'.$i;
```

**Only reads from `log_daily_rate_calculation`.** Monthly-plan charges that now go to `log_monthly_rate_calculation` are not included in the uriage subquery.

### PaypalPaymentSum file (`createPaypalPaymentSumFile`, CommonUtil.php ~L2268)

```php
$selectItem[] = '(select case when sum(paid_price) is null then 0 else sum(paid_price) end as paid_price
    from log_daily_rate_calculation
    where target_ym = '. $uriageStartDate->format('Ym') .'
    and charge_id = trn_charge.id
    group by charge_id) AS uriage'.$j;
```

**Same issue.** Only reads `log_daily_rate_calculation`.

### Base query filter (TrnCharge::getB2CPaypalPayment)

```php
->where('trn_charge.charge_type', '<>', 1)
->whereIn('trn_charge.contract_type', [0, 2])
```

This selects B2C (`contract_type = 0`) and B2B2C (`contract_type = 2`) PayPal charges — which includes both daily-rate charges AND monthly-plan charges. The `paid_price` column from `trn_charge` correctly reflects what was charged. But the "uriage" (revenue) breakdown only queries `log_daily_rate_calculation`, so monthly-plan charges show `uriage = 0` (no row in daily log).

---

## The Gap

Before the ASC monthly rate commands existed, ALL charges (including monthly plans) were calculated via the daily rate formula and stored in `log_daily_rate_calculation`. The PayPal CSV files were designed for that world.

After the ASC project:
- Monthly-plan charges are **excluded** from `log_daily_rate_calculation` (to avoid double-counting)
- Monthly-plan charges are calculated separately and stored in `log_monthly_rate_calculation`
- The PayPal CSV files were **never updated** to also query `log_monthly_rate_calculation`

**Result:** The "sum of revenue" column in the PayPal CSVs is missing all monthly-plan revenue, while the "paid_price" column correctly includes those charges from `trn_charge`.

---

## Expected Fix

Include `log_monthly_rate_calculation` in the uriage subquery via UNION ALL — so both daily-rate and monthly-plan charges are captured in the revenue breakdown. A charge exists in one OR the other log table (never both), so no double-count risk.

Two functions need the same change: `createPaypalPaymentFile` and `createPaypalPaymentSumFile`.

Detailed solution: `Technical_Notes/Tickets/ASC-304_Fix_PaypalPaymentSum_Missing_Monthly.md`

---

## Similar Pattern: CalculationSummary

This is the same class of issue as the CalculationSummary merge. When monthly plans were excluded from the daily path, any downstream report that only read `log_daily_rate_calculation` became incomplete. The CalculationSummary was already fixed (it merges both sources). The PayPal CSVs were missed.

---

## Scope Assessment

| Aspect | Assessment |
|---|---|
| Is this an ASC scope issue? | **Yes** — the gap was introduced when ASC excluded monthly plans from daily calculation |
| Severity | Medium — affects accounting reconciliation reports, not revenue recognition itself |
| Data loss? | No — the data exists in `log_monthly_rate_calculation`, it's just not queried |
| Which tenants? | Bizmates and Zipan (both have PayPal CSV generation: CommonUtil + ZipanUtil) |
| Pre vs Final? | Confirmed: Final only (`SendJournalsDataCommand` + `DataCorrectionCommand`). Pre does not generate PayPal CSVs. |

---

## Data Verification (2026-06-26)

Root cause confirmed via Metabase queries against production:

**Q1: B2C/B2B2C PayPal monthly-plan charges for May 2026**
```sql
SELECT c.id AS charge_id, c.student_id, c.product_id, c.contract_type,
       c.paid_at, c.paid_price AS charge_paid_price, c.order_no
FROM trn_charge c
WHERE c.paid = 1 AND c.status = 1 AND c.charge_type <> 1
    AND c.contract_type IN (0, 2)
    AND c.product_id IN (16,17,18,19,20,21,22,23,27,28,29)
    AND c.paid_at BETWEEN '2026-05-01 00:00:00' AND '2026-05-31 23:59:59'
ORDER BY c.paid_at LIMIT 20;
```
**Result:** Data found — monthly-plan PayPal charges exist. ✅

**Q2: Same charges in `log_monthly_rate_calculation`**
```sql
SELECT l.charge_id, l.target_ym, l.paid_price
FROM log_monthly_rate_calculation l
WHERE l.charge_id IN ({charge_ids_from_Q1})
ORDER BY l.charge_id, l.target_ym;
```
**Result:** Data found — these charges have rows in the monthly log. ✅

**Q3: Same charges in `log_daily_rate_calculation`**
```sql
SELECT l.charge_id, l.target_ym, l.paid_price
FROM log_daily_rate_calculation l
WHERE l.charge_id IN ({charge_ids_from_Q1})
ORDER BY l.charge_id, l.target_ym;
```
**Result:** Empty — these charges are NOT in the daily log. ✅ (Confirms the gap)

**Conclusion:** The PayPal CSV code queries only Q3's table (empty) → uriage=0 → discrepancy. The fix adds Q2's table → correct paid_price returned.

Query results saved as CSV in this directory.

---

## Local Validation (2026-06-26)

Ran `SendJournalsDataCommand` locally with `exeDate = 2026-02-01` (processes January 2026). Command completed successfully — no SQL errors. Generated CSVs saved in `Generated_Files/` subdirectory.

### Smoke Test Result

```
[2026-06-26 14:55:12] local.INFO: DATA CREATION COMPLETED SUCCESSFULLY!
[2026-06-26 15:04:53] local.INFO: END SendJournalsDataLogic
```

The COALESCE queries against both `log_daily_rate_calculation` and `log_monthly_rate_calculation` executed without error on MySQL 5.7. ✅

### Cross-Check: CSV Output vs Local DB

Queried local DB to verify where uriage data comes from:

**Zipan (Aug 2025 charges — pre-split):**
```
charge_id | paid_price | product_id | daily_sum | monthly_sum
10528     | 6,875      | 16         | 6,875     | 0
10515     | 13,750     | 16         | 13,750    | 0
...all 12 charges show daily_sum = paid_price, monthly_sum = 0
```

**Explanation:** August 2025 is before the ASC monthly split was deployed (2026-06-01). At that time, ALL charges (including monthly plans) went into `log_daily_rate_calculation_zipan`. The fix correctly picks this up via `COALESCE(daily, 0) + COALESCE(monthly, 0)` — the daily_sum provides the value. PaypalPaymentSum shows 差引=0 (perfect match) for Zipan 202508–202511. ✅

**Bizmates (Jan 2026 charge 2912934, product_id 29 = FLP):**
```
charge_id | product_id | paid_price | daily_sum | monthly_sum
2912934   | 29         | 14,107     | 0         | 0
```

**Explanation:** Both daily and monthly sums are 0 because the `SendJournalsDataCommand` was only run locally for `exeDate = 2026-02-01` (processes January 2026). The monthly rate calculation for this charge's period was never executed locally. The CSV correctly shows difference = 14,107 (full charge unrecognized). This is expected for limited local data, not a bug.

### Conclusion

The COALESCE pattern works correctly for both scenarios:
- **Pre-split charges** (before June 2026): data in daily log → `COALESCE(daily, 0)` returns the value
- **Post-split charges** (June 2026+): data in monthly log → `COALESCE(monthly, 0)` returns the value
- **Uncalculated charges** (not yet processed): both return 0 → shows full difference (correct — charge hasn't been processed)

Full validation on DEV04 (where all months are processed) will confirm end-to-end correctness.

### Second Run: `exeDate = 2026-03-01` (processes February 2026)

Ran `SendJournalsDataCommand` again with `exeDate = 2026-03-01` to see how the rolling 6-month window fills in as more months are calculated.

**PaypalPaymentSum comparison — Bizmates 202601:**

| | Run 20260201 | Run 20260301 | Change |
|---|---|---|---|
| 入金額 (paid) | 51,166,630 | 51,166,630 | — |
| 売上合計 (uriage) | 47,666,813 | 51,152,523 | +3,485,710 |
| 差引 (difference) | 3,499,817 | **14,107** | Converging → 0 |

The difference dropped from 3.5M → 14,107. The February calculation filled in revenue for January charges. The remaining 14,107 is exactly charge `2912934` (FLP, product_id 29) — the one charge not yet calculated locally.

**PaypalPaymentSum comparison — Zipan 202601:**

| | Run 20260201 | Run 20260301 | Change |
|---|---|---|---|
| 入金額 (paid) | 101,564 | 101,564 | — |
| 売上合計 (uriage) | 2,750 | 101,564 | +98,814 |
| 差引 (difference) | 98,814 | **0** ✅ | Perfect match |

Zipan 202601 now shows **0 difference** — all January charges have their revenue fully recognized across the 6-month window.

**What this proves:**
- The COALESCE query correctly sums data from both log tables as months are processed
- The rolling 6-month window fills in progressively as more batch runs execute
- On DEV04/production (where all months are calculated), differences should converge to 0 for fully-processed charges
- The only non-zero difference remaining is from a charge whose calculation hasn't been run — not a code issue

---

## Next Steps

- [x] ~~Verify with data: compare against monthly + daily for May 2026~~ — **Done (2026-06-26)**
- [x] ~~Confirm which monthly-plan product_ids are affected~~ — **All monthly plans: product_id 16-23, 27-29**
- [x] ~~Pre vs Final?~~ — **Final only (SendJournalsDataCommand + DataCorrectionCommand)**
- [ ] Check if there are other CSV files that only read `log_daily_rate_calculation` and may have the same gap
- [x] ~~Wait for JIRA ticket assignment~~ — **ASC-304 confirmed**
- [x] ~~Implement fix~~ — **Code done (4 locations), merged to ASC-master**
- [x] ~~Smoke test (SendJournalsDataCommand)~~ — **Passed locally (2026-06-26)**
- [x] ~~Data verification (local DB cross-check)~~ — **Confirmed: monthly log has data, daily log empty for affected charges**
- [x] ~~Local CSV output verification~~ — **Zipan 差引=0 for fully-processed months**
- [ ] Wait for sample CSVs from Kuroda-san (JIRA AC) → formalize test case
- [ ] Deploy to DEV04 for final verification with production-like data

---

## Cross-Reference

- Related pattern: `[asc-kiro] Documentation/05_Engineering_Knowledge_Base.md` — Topic 08 (Invisible Records)
- Design context: `[asc-kiro] Knowledge_Base/00_Design_Context.md` — Section 3 (Daily Commands Already Handled Monthly Plans)
- Code: `[ASC] app/Libs/CommonUtil.php` lines ~2174 (PaypalPayment) and ~2268 (PaypalPaymentSum)
- Model: `[ASC] app/Models/TrnCharge.php` — `getB2CPaypalPayment()`, `getB2CPaypalPaymentSum()`
- Ticket: `[asc-kiro] Technical_Notes/Tickets/ASC-304_Fix_PaypalPaymentSum_Missing_Monthly.md`
