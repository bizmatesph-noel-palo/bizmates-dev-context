---
inclusion: fileMatch
fileMatchPattern: "**/CommonUtil.php,**/ZipanUtil.php,**/SendJournalsDataLogic.php,**/DailyRateCalculationPreLogic.php,**/RevenueAllocation/**"
---

# CSV Generation Reference

> **Timing:** the AllocationDetail CSV is **Spec 02 (CAP Integration)**, not Foundation. Foundation only produces the data (`log_alloc_prorations`) that this CSV reads.

## Existing ASC CSVs (CommonUtil.php / ZipanUtil.php)

| Function | CSV File | Data Source |
|---|---|---|
| `createPaypalPaymentFile()` | `Bizmates_PaypalPayment_YYYYMM` | `trn_charge` + `log_daily` + `log_monthly` |
| `createPaypalPaymentSumFile()` | `PaypalPaymentSum_YYYYMM` | Same as above, aggregated |
| `createDailyRateCalculationFile()` | `DailyRateCalculation_YYYYMM` | `log_daily_rate_calculation` |
| `createMonthlyRateCalculationFile()` | `MonthlyRateCalculation_YYYYMM` | `log_monthly_rate_calculation` |
| `createCalculationSummaryFile()` | `CalculationSummary_YYYYMM` | Both daily + monthly (merged) |

**Under Option 1 (Overwrite), the existing CSVs automatically show allocated amounts** — `DailyRateCalculation` and `CalculationSummary` read the log/sum tables, which already contain P. No format change to them, and Accounting confirmed that's acceptable.

## Allocation CSV Delivery (O-6 resolved 2026-08-17)

Accounting needs a breakdown showing **how** the allocation was calculated (the ratio, the original N, the reference prices) — the existing CSVs only show the resulting amounts.

| Decision | Choice |
|---|---|
| Same zip as existing CSVs? | **Yes — added to the existing zip** |
| Same email? | **Yes — the existing 速報版 / 確定版 email.** No separate/third email, no new `mst_mail_template` row |
| Separate command? | **No** — generated inside the existing pipeline |
| Additional output | A Metabase saved query on `log_alloc_prorations`, created post-deployment for ad-hoc checks |

### Output File

| File | Content | Granularity |
|---|---|---|
| `{YYYYMM}_10_AllocationDetail({execDate}).csv` | Per-product allocation breakdown: reference price (L), ratio, original N, allocated P, run status | Per bundle × product × month |

Source: `log_alloc_prorations` (joined for charge/plan context) — or `v_alloc_prorations_active` for the active Final run.

### Columns (per technical design)

コンテンツ (service), 対象年月 (target_ym), プロジェクト (bundle_type label — `cap`/`cip`), 生徒ID, 部署ID, 発注番号, プランID, プロダクトID, プロダクトタイプ, 契約種類, 参照価格 (L), 配分比率 (ratio), 元金額(N), 配分後金額(P), ステータス (run status).

Contract types include B2C / B2B / B2B2C / Partner, and `order_no` / `department_id` are populated where present (they are not restricted to a subset).

## CSV File Conventions

- Stored in `storage_path('app/public/')` — from `config('const.filedirectory')`
- Filename format: `{YYYYMM}_{NN}_{Name}({YYYYMMDD}).csv` where `NN` is the sequence number
- `{YYYYMM}` = target month (previous month from exeDate); `{execDate}` = today (Ymd)
- Encoding: UTF-8 with BOM (`EF BB BF`) for Excel compatibility
- Written via `CommonUtil::createCsvFile()` (fputcsv)
- Config entry lives in `config/const.php` as `allocationDetailFile` (fileName / name / headerItem)

## How CSV → Zip → Email Works

```
1. Each create*File() method:
   - getCsvFileInfo($key) → resolves filename + headers from config/const.php
   - createCsvFile($fileName, $headers, $rows) → writes to storage
   - Returns [$fileName, $displayName]

2. Caller accumulates: $fileNameList[$fileName] = $displayName

3. ZipanUtil::addZipanData() APPENDS Zipan rows to the Bizmates CSVs (same filename)
   - Allocation adds nothing here (Bizmates-only)

4. All tracked files zipped into a single YYYYMMDD.zip (or _pre.zip)

5. Source CSVs deleted after zip

6. Zip attached to email via CommonSendMail

7. $fileNameList passed as $contents->fileList → email template lists the files
```

Since the ASCM-prep refactor, zip creation and email dispatch are handled by the extracted `ArchiverService` / `MailerService` — the AllocationDetail CSV rides that same path.

## Implementation Pattern (Spec 02)

Allocation does NOT own a self-contained generate→zip→email cycle. It only **adds one file to the existing `$fileNameList`**:

```php
// In createSendMailAttacheFile() — SendJournalsDataLogic (Final) and
// DailyRateCalculationPreLogic (Pre), after the existing CSVs:
if (LogAllocCalculationRun::hasCompletedRun($targetYm)) {
    [$fileName, $name] = RevenueAllocationCsvService::createAllocationDetailFile($targetYm, $preFlg);
    $fileNameList[$fileName] = $name;
}
```

- Guarded by "did a run complete?" so a failed/absent allocation simply omits the file — the rest of the zip and the email are unaffected.
- Generation lives in the `RevenueAllocation` namespace (not `CommonUtil` — that file is already oversized).
- Add the `allocationDetailFile` entry to `config/const.php`. **No** new mail type and **no** `mst_mail_template` row are required.

## Reference Prices (for the CSV's L column)

| Product | product_id | L (tax-incl) |
|---|---|---|
| App | 10022 | ¥3,980 |
| Coaching 15min | 10005 | ¥19,800 |
| Coaching 30min | 10015 | ¥39,600 |
| Coaching Intensive (CIP) | 10025 | 🔴 pending (O-5) |

Values come from `mst_alloc_reference_prices` at runtime — never hard-code them in the CSV layer.
