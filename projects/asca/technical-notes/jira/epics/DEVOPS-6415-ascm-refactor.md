# DEVOPS-6415 — ASCM Refactor (Pre-ASCA Prep)

## Document Info

| | |
|---|---|
| **Document type** | JIRA Epic Description |
| **Date** | 2026-08-24 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro (code analysis and document generation) |
| **Status** | Active |
| **JIRA** | [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) |

---

**Type:** Epic  
**Owner:** Noel Palo  
**Target:** Aug 24–28, 2026 (W0 of ASCA timeline)  
**Linked to:** [ASCA-7](https://bizmates.atlassian.net/browse/ASCA-7)

---

## Goal

Fix latent bugs in DataCorrectionLogic (drift from ASCM) and extract duplicated zip+email delivery logic into a shared service — clearing the path for ASCA/ASCI injection.

---

## Background

The ASCA project (ASC for CAP — revenue allocation framework) injects into the existing batch commands. Two issues in the current code must be resolved first:

1. **DataCorrectionLogic drift** — During ASCM (deployed Jun 2026), `CommonUtil::createDailyRateCalculation()` got a monthly plan skip and 3 additional fields (`tax_free`, `country_id`, `gross_amount`). The private copy in `DataCorrectionLogic` was never updated. Monthly plan charges can incorrectly enter the daily rate log via correction, and correction-generated rows are missing fields that CommonUtil writes.

2. **Duplicated zip+email logic** — The same ZipArchive → add CSVs → cleanup → sendMail pattern is copy-pasted across 3 Logic files. ASCA adds a new CSV to the zip — extracting to a shared service means ASCA only modifies a file list, not 3 separate zip blocks.

---

## Scope

### In Scope

- Fix DataCorrectionLogic: add `BizmatesMonthlyPlanEnum::exists()` skip (Bizmates only)
- Fix DataCorrectionLogic: add missing `$condition` fields (`tax_free`, `country_id`, `gross_amount`)
- Extract zip+email from `DailyRateCalculationPreLogic` into `BatchReportDeliveryService`
- Extract zip+email from `SendJournalsDataLogic` into `BatchReportDeliveryService`
- Extract zip+email from `DataCorrectionLogic` into `BatchReportDeliveryService`
- Unit test for `BatchReportDeliveryService`
- Smoke test all 3 commands on DEV04
- QA verification of generated reports

### Out of Scope

- DB migrations (`log_alloc_*` tables) — ASCA Spec 01
- New models or enums (allocation framework) — ASCA Spec 01
- Allocation service or injection into CommonUtil — ASCA Spec 01
- Test data seeder / reference price seeder — ASCA Spec 01
- AllocationDetail CSV — ASCA Spec 01

---

## Stories

Stories already exist under this epic (created by Patrick-san per standard KPI structure). Technical details below support whichever story the work is logged against.

---

## Success Criteria

- [ ] DataCorrectionLogic skips monthly plans (`BizmatesMonthlyPlanEnum::exists()` — Bizmates only)
- [ ] DataCorrectionLogic writes `tax_free`, `country_id`, `gross_amount` to log table
- [ ] `BatchReportDeliveryService` exists and is called by all 3 Logic files
- [ ] All 3 batch commands produce identical output to pre-refactor baseline
- [ ] Unit test passes
- [ ] QA verifies generated reports match expected output on DEV04

---

## Risks & Dependencies

| Risk/Dependency | Impact | Mitigation |
|---|---|---|
| Monthly plan skip changes correction behavior | None — monthly plans have never been corrected via this path (zero historical impact) | Verify by querying `log_daily_rate_calculation` for monthly product_ids via DataCorrection |
| Extraction breaks zip/email output | Reports stop reaching Accounting team | Smoke test all 3 commands on DEV04 before merge. Compare output byte-for-byte against baseline. |
| DEV04 environment not available | Cannot smoke test | Not blocking coding — test when access confirmed |

---

## Technical Details

### 1. Fix DataCorrectionLogic Drift

**File:** `app/Libs/DataCorrectionLogic.php`  
**Method:** `private function createDailyRateCalculation($data)` (line ~346)

**Add monthly plan skip** (after charge is fetched, before `getContractDateInfoList()`):

```php
// Skip monthly plans — aligned with CommonUtil (ASCM project, Jun 2026)
if ($data->containts !== 'Zipan' && BizmatesMonthlyPlanEnum::exists($trnCharge->product_id)) {
    Log::info("Skipping monthly plan product_id: {$trnCharge->product_id} for charge_id: {$trnCharge->id}");
    return;
}
```

**Add missing fields** to the `$condition` array (line ~405):

```php
'tax_free' => $trnCharge->tax_free,           // ← missing from ASCM
'country_id' => $trnCharge->country_id,       // ← missing from ASCM
'gross_amount' => $trnCharge->gross_amount,   // ← missing from ASCM
```

Place them in the same positions as CommonUtil: `tax_free` after `start_date`, `country_id` and `gross_amount` after `paid_price`.

### 2. Extract BatchReportDeliveryService

**New file:** `app/Libs/BatchReportDeliveryService.php`

```php
class BatchReportDeliveryService
{
    /**
     * Create zip from generated CSVs, send email, clean up source files.
     *
     * @param array  $fileNameList  Map of filename => display name
     * @param string $mailType      Config key for mail template
     * @param string $suffix        Zip filename suffix ('_pre', '', etc.)
     * @return string               Path to created zip file
     */
    public static function deliver(array $fileNameList, string $mailType, string $suffix = ''): string
    {
        // 1. Create ZipArchive
        // 2. Add all CSVs from $fileNameList
        // 3. Close zip
        // 4. Delete source CSVs
        // 5. Send email via CommonUtil::sendMail()
        // 6. Return zip path
    }
}
```

**Replace in each Logic file:**

| File | Mail type config key | Suffix |
|---|---|---|
| `DailyRateCalculationPreLogic` | `dailyRateCalculationPreMail` | `'_pre'` |
| `SendJournalsDataLogic` | `sendJournalDataMail` | `''` |
| `DataCorrectionLogic` | `reCalculation` | `''` |

Each file keeps its `createSendMailAttacheFile()` for CSV generation but delegates zip/cleanup/email to the shared service.

### 3. Verification

After implementation, run on DEV04:

```bash
php artisan command:DailyRateCalculationPreCommand {exeDate}
php artisan command:SendJournalsDataCommand {exeDate}
php artisan command:DataCorrectionCommand {exeDate}
```

Pass: no errors in log, reports generated, CSVs match baseline.

---

## Affected Files

| File | Change |
|---|---|
| `app/Libs/DataCorrectionLogic.php` | Fix: monthly plan skip + 3 missing fields |
| `app/Libs/DailyRateCalculationPreLogic.php` | Refactor: extract zip+email to service |
| `app/Libs/SendJournalsDataLogic.php` | Refactor: extract zip+email to service |
| `app/Libs/BatchReportDeliveryService.php` | **NEW** — shared delivery service |
| `tests/Unit/Libs/BatchReportDeliveryServiceTest.php` | **NEW** — unit test |

---

## Cross-Reference

- Master timeline: `docs/asc-projects-master-timeline.md` (Phase 0)
- Technical design: `projects/asca/documentation/asc-allocation-framework-technical-design.md` (§8, §12)
- ASCM Knowledge Base: `projects/ascm/knowledge-base/` (KB #14, KB #13)
- Development workflow reference: `projects/asch/documentation/asch-development-workflow.md`
