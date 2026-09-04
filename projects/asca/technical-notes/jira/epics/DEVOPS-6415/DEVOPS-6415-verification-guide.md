# DEVOPS-6415 — Verification & QA Guide

## Document Info

| | |
|---|---|
| **Document type** | Team Guide |
| **Date** | 2026-08-24 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Active |
| **Audience** | QA Team, Patrick-san (SDM) |
| **JIRA** | [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) |

---

## TL;DR

The DEVOPS-6415 refactor makes two changes: (1) fixes a latent bug in DataCorrectionLogic and (2) extracts duplicated zip+email code into a shared service. Neither change alters visible CSV output. QA verification = confirm the 3 batch commands still produce the same reports as before. Unit tests cover the correction-specific logic.

---

## Context

The ASCM Refactor (DEVOPS-6415) prepares the accounting batch system for the upcoming ASCA/ASCI allocation project. It fixes code drift (missing fields and a missing skip condition in the correction batch) and refactors duplicated delivery logic. These are internal code improvements — no new features, no output format changes.

---

## How DataCorrectionCommand Works

Unlike the Daily/SendJournals commands which query `trn_charge` directly, the Correction command reads from a **manually-provided CSV file**:

**File location:** `storage/app/csv/correction_{Ym}.csv` (where `{Ym}` is the current year-month, e.g., `correction_202608.csv`)

**Who provides it:** Accounting team (Kuroda-san's side) — when they identify charges that need manual correction after a batch has already run.

**CSV format (13 columns):**

| # | Column | Description | Example |
|---|---|---|---|
| 1 | コンテンツ | Service: `Bizmates` or `Zipan` | `Bizmates` |
| 2 | 対象年月 | Target year-month (YYYYMM) | `202608` |
| 3 | 生徒ID | Student ID | `12345` |
| 4 | 発注番号 | Order number | `67890` |
| 5 | プロダクトタイプ | Product type | `1` |
| 6 | 開始日 | Start date | `2026/08/01` |
| 7 | 終了日 | End date | `2026/08/31` |
| 8 | チケット | Ticket count | `0` |
| 9 | 取引先ID | Freee partner ID | `0` |
| 10 | 取引先名 | Partner name | `` |
| 11 | データ対象 | Operation type | `addDaily` |
| 12 | 修正額 | Fix amount | `0` |
| 13 | チャージID | Charge ID | `99999` |

**Operation types (column 11 — データ対象):**

| Value | What it does | Our fix affects it? |
|---|---|---|
| `addDaily` | Fetches charge from `trn_charge`, writes new row to `log_daily_rate_calculation` | ✅ Yes — monthly plan skip + missing fields |
| `daily` | Updates existing `log_daily_rate_calculation` row | ❌ No — reads from log (already allocated) |
| `balance` | Corrects balance transition | ❌ No |
| `deposit` | Corrects deposit amount | ❌ No |
| `addBalance` | Creates new balance transition row | ❌ No |
| `balanceAmount` | Creates balance amount row | ❌ No |

**Key point:** Our DEVOPS-6415 fix only affects the `addDaily` operation. If QA wants to specifically test the skip, the correction CSV would need a row with `addDaily` in column 11 and a `charge_id` (column 13) that belongs to a monthly plan product (product_id 16–23 or 27–29 for Bizmates). In practice, Accounting has never provided such a row — the fix is preventive.

---

## What Changed

### Change 1: DataCorrectionLogic Drift Fix

**What:** Added a monthly plan skip and 3 missing fields (`tax_free`, `country_id`, `gross_amount`) to `DataCorrectionLogic::createDailyRateCalculation()`.

**Why:** CommonUtil (used by Daily/SendJournals commands) already has these. DataCorrectionLogic was never updated during ASCM — creating a schema inconsistency.

**Observable impact on reports:** None. The correction command generates the same CSVs as before. The added fields are not columns in any CSV output — they only exist in the DB table (`log_daily_rate_calculation`). The monthly plan skip prevents a hypothetical future bug (no monthly plan charges have ever been corrected via this path).

### Change 2: ArchiverService + MailerService Extraction

**What:** Extracted the zip creation + file cleanup code into `ArchiverService` and email sending code into `MailerService`. Both are called from the 3 Logic files via `app()->make()`.

**Why:** Eliminate duplication (SOLID: Single Responsibility). ASCA will add a new CSV to the zip — with separated services, that's a file list change, not a service change. Each service is independently testable and mockable for ASCA/ASCI.

**Observable impact on reports:** None. The zip contents, file names, and email recipients are identical. Only the internal code structure changed.

---

## What QA Needs to Verify

### Primary: No Regression in Report Output

Run all 3 batch commands and confirm the generated reports are unchanged.

| Command | What it produces | How to verify |
|---|---|---|
| `DailyRateCalculationPreCommand` | Zip with: TrnCharge, Ticket, DailyRateCalculation, MonthlyRateCalculation, CalculationSummary CSVs | Compare zip contents against previous run |
| `SendJournalsDataCommand` | Zip with: DailyRateCalculation, MonthlyRateCalculation, CalculationSummary, BalanceTransition, PaypalPayment CSVs | Compare zip contents against previous run |
| `DataCorrectionCommand` | Zip with: DailyRateCalculation, MonthlyRateCalculation, CalculationSummary, BalanceTransition, PaypalPayment CSVs | Compare zip contents against previous run |

**Pass criteria:**
- ✅ No runtime errors in logs
- ✅ Zip files created successfully
- ✅ Email dispatched
- ✅ CSV content matches baseline (same columns, same data — byte-for-byte comparison not required, but data values should match)

### Secondary: Correction-Specific Logic (covered by unit test)

The monthly plan skip and missing fields fix are verified by automated unit tests (`tests/Unit/Libs/DataCorrectionLogicTest.php`). QA does not need to manually test these — there's no way to trigger the skip path without a correction CSV containing a monthly plan charge_id, which doesn't exist in practice.

| Test case | What it verifies | Coverage |
|---|---|---|
| Monthly plan skip (Bizmates) | product_id 16–23, 27–29 are rejected by correction `addDaily` path | Unit test ✅ |
| Monthly plan skip (Zipan) | product_id 16–18 are rejected by correction `addDaily` path | Unit test ✅ |
| Missing fields added | `tax_free`, `country_id`, `gross_amount` written to DB | Unit test ✅ |
| Null charge handling | Charge not found returns error gracefully | Unit test ✅ |

---

## What QA Does NOT Need to Test

- ❌ The monthly plan skip behavior in isolation (unit test covers it)
- ❌ New CSV formats or columns (none were added)
- ❌ New email templates (none were changed)
- ❌ Zipan-specific paths separately (same code path, covered by unit test)
- ❌ ASCA allocation features (not in scope of DEVOPS-6415)

---

## Test Environment

| Item | Detail |
|---|---|
| Environment | DEV04 |
| Branch | `feature/DEVOPS/DEVOPS-6415-ASCM-fix-data-correction-logic` |
| Correction CSV | **Required if running DataCorrectionCommand** — must exist at `storage/app/csv/correction_{Ym}.csv` (where `{Ym}` is the current year-month). The command will fail with an error if the file is missing. Not required for Daily/SendJournals commands. |
| Baseline comparison | Compare against reports from the last successful DEV04 run (Harvey-san's recent run) |

---

## Execution Steps (DEV04)

```bash
# 1. Deploy the branch to DEV04

# 2. Run Pre command (no CSV needed)
php artisan command:DailyRateCalculationPreCommand {exeDate}

# 3. Run Final command (no CSV needed)
php artisan command:SendJournalsDataCommand {exeDate}

# 4. Run Correction command (REQUIRES correction CSV at storage/app/csv/correction_{Ym}.csv)
#    - Place the CSV file first, or the command will fail
#    - Can use a minimal test CSV (header + 1 row with a valid charge_id and operation 'addDaily')
#    - If no correction scenario needs testing, skip this step — Daily/SendJournals cover the regression
php artisan command:DataCorrectionCommand {exeDate}

# 5. Check logs
tail -50 storage/logs/laravel.log | grep -E "ERROR|FAILED|COMPLETED"

# 6. Collect generated zip files for comparison
```

---

## FAQ

| Question | Answer |
|---|---|
| Do I need a correction CSV to test? | **For Daily/SendJournals:** No. **For DataCorrectionCommand:** Yes — it reads from `storage/app/csv/correction_{Ym}.csv` and will error if the file doesn't exist. You can use an empty CSV (header only) or one with test rows. |
| What if the reports differ from baseline? | Check if the diff is in data (normal — DEV04 data changes over time) or in structure/format (that would be a bug). Column count and header names must match. |
| Is there a new report file? | No. Same file set as before. |
| When does this deploy to production? | After QA sign-off. It will be active for the next monthly batch run (1st of the month). |
| What happens if the fix is wrong? | Worst case: the correction command would skip a charge that shouldn't be skipped. But monthly plans have never been corrected via this path historically — zero practical risk. |
