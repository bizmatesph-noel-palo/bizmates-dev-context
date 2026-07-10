# RESEARCH-04: CSV/Zip/Email Integration Points

**Date:** 2026-07-10  
**Purpose:** Determine how ASCH CSV reports integrate into the existing zip/email pipeline without breaking current behavior.

---

## 1. Current Architecture

### Three Independent Pipelines

| Pipeline | Logic Class | Mail Type | Zip Name | When |
|---|---|---|---|---|
| Pre (速報) | `DailyRateCalculationPreLogic` | `dailyRateCalculationPreMail` (1) | `YYYYMMDD_pre.zip` | 1st of month |
| Final (確定) | `SendJournalsDataLogic` | `sendJournalsMail` (3) | `YYYYMMDD.zip` | 3rd of month |
| Correction | `DataCorrectionLogic` | `reCalculation` (10) | `YYYYMMDD.zip` | Manual |

Each has its own `createSendMailAttacheFile()` method. They share no base class.

### File Creation Pattern

Every CSV follows the same 3-step pattern:

```php
// Step 1: Get file info from config
[$fileName, $name, $headerTitle] = CommonUtil::getCsvFileInfo('someFileKey');
// Resolves: '{YYYYMM}_03_DailyRateCalculation({execDate}).csv'
//        → '202606_03_DailyRateCalculation(20260703).csv'

// Step 2: Write CSV to storage/app/public/
CommonUtil::createCsvFile($fileName, $headerTitle, $dataRows);

// Step 3: Track for zip
$fileNameList[$fileName] = $name;
```

### Zipan "Append" Pattern (Critical Detail)

Zipan does NOT create separate files. It APPENDS rows to the same CSV file that CommonUtil already created:

```
CommonUtil::createDailyRateCalculationFile() → WRITES header + Bizmates rows to file X
ZipanUtil::createDailyRateCalculationFile()  → APPENDS Zipan rows to the SAME file X
```

How: `ZipanUtil` calls `CommonUtil::getCsvFileInfo('dailyRateCalculationFile')` to get the same filename, then uses `appendCsv()` (fopen mode `"a"`) to add rows. The file is already tracked in `$fileNameList` from the Bizmates call.

**Exception:** `ZipanUtil::createPaypalPaymentFile()` creates SEPARATE Zipan-specific files (filename contains "Zipan" via `{type}` replacement) and explicitly adds them to `$fileNameList`.

### $fileNameList Structure

```php
$fileNameList = [
    // key = physical filename on disk, value = display name for email body
    '202606_01_Invoice(20260703).csv' => '請求情報ファイル',
    '202606_02_Ticket(20260703).csv' => 'チケット情報ファイル',
    '202606_03_DailyRateCalculation(20260703).csv' => '日割計算結果ファイル',
    '202606_03_MonthlyRateCalculation(20260703).csv' => '月回数プラン計算結果ファイル',
    '202606_04_CalculationSummary(20260703).csv' => '日割計算集計結果ファイル',
    // ... balance transition, journals history, paypal files ...
];
```

Consumed by:
1. **Zip:** `foreach keys → $zip->addFile(storage_path(dir . $key), $key)`
2. **Cleanup:** `foreach keys → unlink(storage_path(dir . $key))`
3. **Email body:** `$contents->fileList = $fileNameList` → template renders display names

No ordering dependency. No positional access. No array manipulation beyond foreach and assignment.

### Email Mechanism

```php
// sendResultMail() passes zip path as attachment
CommonUtil::sendMail(mailType, [$zipFilePath], $contents);

// CommonUtil::sendMail() delegates to Laravel Mailable
Mail::to($to)->send(new CommonSendMail($mailType, $tempFileList, $contents));

// CommonSendMail::build() attaches the zip file
foreach ($this->tempFileList as $tempFile) {
    $filepath = storage_path($tempFile);
    if (File::exists($filepath)) {
        $mail->attach($filepath);
    }
}
```

- `$tempFileList` = array of zip paths (always just one: the zip file)
- `$contents->fileList` = the `$fileNameList` array (used in email view to list what's inside)
- Template and recipients come from `mst_mail_template` table (keyed by `mailType`)

---

## 2. Where ASCH Must Integrate

### Final Flow (SendJournalsDataLogic)

```php
private function createSendMailAttacheFile($targetYm, $targetStartDate, $targetEndDate, $cancelList)
{
    $fileNameList = array();

    // ① Bizmates CSVs (CommonUtil::create* → writes + tracks)
    [$f, $n] = CommonUtil::createTrnChargeFile(...);         $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createTicketFile(...);            $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createDailyRateCalculationFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createMonthlyRateCalculationFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createDailyRateCalculationSumFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createMaeukeUrikakebalanceTransitionFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createSendJournalsHistoryFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createBalanceTransitionFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createMaeukeUrikakebalanceTransitionWithOrderNumberFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createBalanceTransitionWithOrderNumberFile(...); $fileNameList[$f] = $n;
    [$f, $n] = CommonUtil::createBalanceTransitionV2File(...); $fileNameList[$f] = $n;
    // PayPal (6 months + sum)
    for (...) { [$f, $n] = CommonUtil::createPaypalPaymentFile(...); $fileNameList[$f] = $n; }
    [$f, $n] = CommonUtil::createPaypalPaymentSumFile(...); $fileNameList[$f] = $n;

    // ② Zipan (appends to existing files + adds PayPal-specific files)
    ZipanUtil::addZipanData($targetYm, $targetStartDate, $targetEndDate, $fileNameList);

    // ③ ← ASCH INSERTION POINT (after Zipan, before error)

    // ④ Error file (conditional)
    if (count($this->errorList) > 0) { ... }

    // ⑤ Zip all tracked files → single .zip
    // ⑥ Delete source CSVs
    // ⑦ Return [$zipPath, $fileNameList]
}
```

### Pre Flow (DailyRateCalculationPreLogic)

Same pattern but fewer files (no balance transition, no journals history, no paypal history):

```php
// ① Bizmates CSVs (5 files)
// ② ZipanUtil::addZipanPreData(...)
// ③ ← ASCH PRE INSERTION POINT
// ④ Error file
// ⑤ Zip → YYYYMMDD_pre.zip
// ⑥ Delete + Return
```

---

## 3. ASCH Integration Approach (Validated)

### Recommended: Follow the Zipan Precedent

ASCH integrates exactly how Zipan was integrated — static method that receives `&$fileNameList` and appends entries. This is a proven pattern already in production.

```php
// In SendJournalsDataLogic::createSendMailAttacheFile()
// After: ZipanUtil::addZipanData(...)
// Before: error file check

AschCsvUtil::addAschData($targetYm, $fileNameList);
```

```php
// In DailyRateCalculationPreLogic::createSendMailAttacheFile()
// After: ZipanUtil::addZipanPreData(...)
// Before: error file check

AschCsvUtil::addAschPreData($targetYm, $fileNameList);
```

### AschCsvUtil Implementation

```php
<?php

declare(strict_types=1);

namespace App\Libs\Asch;

use App\Libs\CommonUtil;

class AschCsvUtil
{
    /**
     * Add ASCH Final CSVs to the report package.
     * Follows ZipanUtil::addZipanData() pattern.
     *
     * @param string $targetYm Target year-month (YYYYMM)
     * @param array &$fileNameList Mutable file tracking array
     */
    public static function addAschData(string $targetYm, array &$fileNameList): void
    {
        // Guard: only add files if ASCH has data for this month
        if (!self::hasAschDataForMonth($targetYm)) {
            return; // No Honki Set proration for this month — zero impact
        }

        [$fileName, $name] = self::createComponentDetailFile($targetYm);
        $fileNameList[$fileName] = $name;

        [$fileName, $name] = self::createCalculationSummaryFile($targetYm);
        $fileNameList[$fileName] = $name;
    }

    /**
     * Add ASCH Pre CSVs to the report package.
     * Follows ZipanUtil::addZipanPreData() pattern.
     */
    public static function addAschPreData(string $targetYm, array &$fileNameList): void
    {
        if (!self::hasAschDataForMonth($targetYm)) {
            return;
        }

        [$fileName, $name] = self::createComponentDetailFile($targetYm);
        $fileNameList[$fileName] = $name;

        [$fileName, $name] = self::createCalculationSummaryFile($targetYm);
        $fileNameList[$fileName] = $name;
    }

    private static function createComponentDetailFile(string $targetYm): array
    {
        [$fileName, $name, $headerTitle] = CommonUtil::getCsvFileInfo('aschComponentDetailFile');
        $rows = self::getComponentDetailRows($targetYm);
        CommonUtil::createCsvFile($fileName, $headerTitle, $rows);
        return [$fileName, $name];
    }

    private static function createCalculationSummaryFile(string $targetYm): array
    {
        [$fileName, $name, $headerTitle] = CommonUtil::getCsvFileInfo('aschCalculationSummaryFile');
        $rows = self::getCalculationSummaryRows($targetYm);
        CommonUtil::createCsvFile($fileName, $headerTitle, $rows);
        return [$fileName, $name];
    }

    private static function hasAschDataForMonth(string $targetYm): bool
    {
        // Check if any finalized ASCH run exists for this month
        // Returns false for months without Honki Set campaigns → zero impact
        return \DB::table('asch_calculation_runs')
            ->where('target_ym', $targetYm)
            ->where('status', 'completed')
            ->exists();
    }

    private static function getComponentDetailRows(string $targetYm): array { /* TBD */ }
    private static function getCalculationSummaryRows(string $targetYm): array { /* TBD */ }
}
```

### Config Additions Required

```php
// config/const.php → 'csvFile' array
'aschComponentDetailFile' => [
    'fileName' => '{YYYYMM}_12_AschComponentDetail({execDate}).csv',
    'name' => 'ASCH Component Detail',
    'headerItem' => [
        'target_ym', 'student_id', 'enrollment_id', 'product_id',
        'product_type', 'component_type', 'list_price', 'paid_amount',
        'proration_basis', 'allocated_amount', 'i_period', 'j_period',
        'p_value', 'n_value', 'adjustment',
    ],
],
'aschCalculationSummaryFile' => [
    'fileName' => '{YYYYMM}_13_AschCalculationSummary({execDate}).csv',
    'name' => 'ASCH Calculation Summary',
    'headerItem' => [
        'target_ym', 'product_type', 'contract_type', 'partner_id',
        'n_total', 'p_total', 'adjustment_total', 'row_count',
    ],
],
```

Sequence numbers `_12_` and `_13_` chosen to not conflict with existing `_01_` through `_09_` files.

---

## 4. Safety Guarantees

### Why This Cannot Break Existing Reports

| Concern | Guarantee |
|---|---|
| Existing CSV content | CommonUtil create* methods are NOT modified. Same calls, same data, same output. |
| Existing CSV file names | No changes to `config/const.php` existing entries. ASCH adds NEW entries only. |
| Zipan append behavior | `ZipanUtil::addZipanData()` call happens BEFORE ASCH. Zipan appends to files as before. |
| Zip file structure | Same `ZipArchive::CREATE` logic iterates `$fileNameList`. ASCH just adds 2 more entries at the end. |
| Zip file name | Same `YYYYMMDD.zip` / `YYYYMMDD_pre.zip` — unchanged. |
| Email template | `$contents->fileList` now has 2 more entries at the bottom. Template iterates all — shows more files listed. |
| Email recipients | Same `mst_mail_template` row, same `mailType` — no change. |
| Email attachment | Same single zip file attached — just slightly larger (2 extra CSVs inside). |
| Months without ASCH | `hasAschDataForMonth()` returns false → no files created, `$fileNameList` unchanged → **byte-for-byte identical** to pre-ASCH behavior. |
| DataCorrectionLogic | Has its own separate `createSendMailAttacheFile()`. ASCH does NOT touch it. Correction emails unaffected. |

### Verification Strategy

1. Deploy ASCH table schema (empty tables, no data yet)
2. Run existing Final/Pre batch — ASCH guard returns false → output is identical
3. Populate ASCH test data for a specific month
4. Run batch for that month — verify zip now contains 2 additional CSVs
5. Compare all non-ASCH CSVs byte-for-byte with previous run — must be identical

---

## 5. Facade Refactor (Phase 2 — Optional, Later)

The research confirms a facade/builder pattern IS technically feasible but NOT required for Phase 1. The reasons:

- `$fileNameList` is a simple key-value array with no hidden behavior
- ZipanUtil's `&$fileNameList` by-reference works because PHP objects are passed by reference implicitly (a builder would work the same way)
- No ordering dependency in the zip or email

If the team wants to do this later (for maintainability, not necessity):

```php
// Phase 2: Extract builder (AFTER ASCH is proven in production)
$builder = new ReportPackageBuilder();
CommonUtil::createTrnChargeFile(...) → $builder->addFile($f, $n);
// ... all existing calls ...
ZipanUtil::addZipanData($targetYm, ..., $builder);
AschCsvUtil::addAschData($targetYm, $builder);
$builder->zip($zipName)->send($mailType);
```

**Do NOT block ASCH on this refactor.** The Zipan-precedent approach (Phase 1) is proven, safe, and requires minimal code change (2 lines per pipeline: one `use` statement + one method call).

---

## 6. Files Modified by ASCH CSV Integration

| File | Change | Risk |
|---|---|---|
| `config/const.php` | Add 2 new entries to `csvFile` array | Zero risk — additive only |
| `app/Libs/Asch/AschCsvUtil.php` | New file | Zero risk — new code |
| `app/Libs/SendJournalsDataLogic.php` | Add 1 line: `AschCsvUtil::addAschData(...)` after ZipanUtil call | Low risk — follows proven pattern |
| `app/Libs/DailyRateCalculationPreLogic.php` | Add 1 line: `AschCsvUtil::addAschPreData(...)` after ZipanUtil call | Low risk — follows proven pattern |

**Total existing code touched: 2 lines (one per pipeline).** Everything else is new files/config.

---

## 7. Decision Summary

| Decision | Choice | Rationale |
|---|---|---|
| Same zip or separate zip? | **Same zip** | Accounting gets one package. Follows operational norm. |
| Same email or separate email? | **Same email** | No new mail template needed. No operational change. |
| Integration pattern | **Zipan precedent** (`addAschData(&$fileNameList)`) | Proven in production. Minimal change. Team familiar. |
| Guard for months without ASCH | **`hasAschDataForMonth()` early return** | Zero impact on non-Honki months. |
| Facade/builder refactor | **Phase 2 (optional, not now)** | Not required. Don't block ASCH on architectural cleanup. |
| Config file sequence numbers | **`_12_` and `_13_`** | No conflict with existing `_01_` through `_09_`. |
| ASCH creates separate files? | **Yes** — NOT appending to existing CSVs | Unlike Zipan (which appends Lesson/Coaching data to Bizmates files), ASCH data is conceptually separate (adjustments vs absolute values). Own files. |
