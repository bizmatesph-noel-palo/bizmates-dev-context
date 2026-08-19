# ASC Allocation (CAP/CIP) — Process & Data Flow Diagram

> **Correction (2026-08-14):** This document describes Option 2 (Adjust / 2nd Freee API call). The chosen approach is **Option 1 (Overwrite)** — allocation overwrites N→P in `log_daily_rate_calculation` before sum is built, eliminating the need for a 2nd Freee API call. See `docs/asc-allocation-framework-technical-design.md` for the current design.

> **Pricing confirmed (2026-08-12):** App product_id = 10021, App reference price = ¥3,980 (tax-incl), Coaching 15min = ¥19,800, 30min = ¥39,600. Allocation method = Option (C) proportional. See `REF-CAP-05-Upstream-Pricing-Discussion-20260812.md` for full details.

**Purpose:** Show how ASC-CAP and ASC-CIP inject into the existing accounting batch pipeline  
**Audience:** Patrick-san, Kuroda-san  
**Date:** 2026-08-11  
**Author:** Noel Palo

---

## 1. Current System Overview (ASCM — Before Injection)

### Batch Execution Schedule

```
┌─────────────────────────────────────────────────────────────────────────┐
│  pre.sh — 1st of month, 06:00                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 1. MonthlyRateCalculationPreCommand                              │   │
│  │    → MonthlyRateCalculationPreLogic                              │   │
│  │    → writes: log_monthly_rate_calculation_pre                    │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │ 2. DailyRateCalculationPreCommand                                │   │
│  │    → DailyRateCalculationPreLogic                                │   │
│  │    → writes: log_daily_rate_calculation_pre                      │   │
│  │    → writes: log_sum_calculation_pre                             │   │
│  │    → generates: CSVs → ZIP → Email (Pre)                         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  send.sh — ~3rd business day, 00:00                                     │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ 1. MonthlyRateCalculationCommand                                 │   │
│  │    → MonthlyRateCalculationLogic                                 │   │
│  │    → writes: log_monthly_rate_calculation                        │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │ 2. SendJournalsDataCommand                                       │   │
│  │    → SendJournalsDataLogic                                       │   │
│  │    → writes: log_daily_rate_calculation                          │   │
│  │    → writes: log_sum_calculation + log_sum_calculation_history   │   │
│  │    → sends:  Freee API (T1/T2/T3 journals)                       │   │
│  │    → writes: log_send_journals_history                           │   │
│  │    → writes: log_balance_transition(_with_order_number)          │   │
│  │    → generates: CSVs → ZIP → Email (Final)                       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Proposed System (After ASC-CAP/CIP Injection)

### Pre Command Flow (DailyRateCalculationPreLogic)

```
DailyRateCalculationPreCommand
│
▼
DailyRateCalculationPreLogic::execute()
│
├─── [1] Delete stale data (existing + NEW: asc_alloc_* for target_ym)
│
├─── [2] Freee access token refresh
│
├─── [3] Daily Rate Calculation (EXISTING — unchanged)
│         CommonUtil::createDailyRateCalculation(preFlg=true)
│         → reads: trn_charge (excludes monthly plans)
│         → writes: log_daily_rate_calculation_pre
│         → writes: log_sum_calculation_pre
│
├─── [4] Zipan Daily Rate Calculation (EXISTING — unchanged)
│         ZipanUtil::createDailyRateCalculation(preFlg=true)
│
├─── [5] ★ NEW: ASC Allocation (CAP + CIP) ★
│         AscAllocationService::calculate(targetYm, preFlg=true)
│         │
│         ├── Detect bundles (CAP charges + CIP charges)
│         │   → reads: trn_charge, trn_student_product
│         │   → reads: asc_alloc_reference_prices
│         │
│         ├── Read N values
│         │   → reads: log_daily_rate_calculation_pre (preFlg=true)
│         │
│         ├── Calculate allocation
│         │   P_app = floor(N × L_app / (L_coaching + L_app))
│         │   P_coaching = N − P_app
│         │   adjustment_app = +P_app
│         │   adjustment_coaching = −P_app
│         │
│         ├── Store results
│         │   → writes: asc_alloc_calculation_runs
│         │   → writes: asc_alloc_bundles
│         │   → writes: asc_alloc_bundle_charges
│         │   → writes: asc_alloc_groups
│         │   → writes: asc_alloc_prorations
│         │   → writes: asc_alloc_sum_calculation
│         │   → writes: asc_alloc_sum_calculation_history
│         │
│         └── Validate (ΣP = ΣN per group, Σadjustment = 0 per run)
│
├─── [6] Generate CSV Files
│         ├── (existing CSVs — unchanged)
│         │   Invoice, Ticket, DailyRateCalculation,
│         │   MonthlyRateCalculation, CalculationSummary
│         │
│         └── ★ NEW: Allocation CSVs ★
│             AllocationDetail_{YYYYMM}.csv
│             AllocationSummary_{YYYYMM}.csv
│
├─── [7] Create ZIP archive (all CSVs → single .zip)
│
└─── [8] Send Email (single email with zip attachment)
```

### Final Command Flow (SendJournalsDataLogic)

```
SendJournalsDataCommand
│
▼
SendJournalsDataLogic::execute()
│
├─── [1] Freee access token refresh
│
├─── [2] Daily Rate Calculation (EXISTING — unchanged)
│         CommonUtil::createDailyRateCalculation(preFlg=false)
│         → writes: log_daily_rate_calculation
│         → writes: log_sum_calculation + history
│
├─── [3] Zipan Daily Rate Calculation (EXISTING — unchanged)
│
├─── [4] COMMIT checkpoint ← (save daily calc to DB)
│
├─── [5] ★ NEW: ASC Allocation (CAP + CIP) ★
│         AscAllocationService::calculate(targetYm, preFlg=false)
│         → reads: log_daily_rate_calculation (N values — final)
│         → writes: asc_alloc_* tables (same as Pre, final tables)
│
├─── [6] COMMIT checkpoint ← (save allocation to DB)
│
├─── [7] Freee Journal Sending — EXISTING (unchanged)
│         sendFreeeJournals2()
│         → reads: log_sum_calculation
│         → builds: T1 (revenue), T2 (advance), T3 (wash) journals
│         → sends: Freee API call #1 (existing journals)
│         → writes: log_send_journals_history
│
├─── [8] ★ NEW: Freee Journal Sending — Allocation ★
│         → reads: asc_alloc_sum_calculation
│         → builds: T1 adjustment journals (App +, Coaching −)
│         → sends: Freee API call #2 (allocation adjustments only)
│         → writes: asc_alloc_deliveries
│         → writes: log_send_journals_history (with alloc prefix)
│
├─── [9] COMMIT checkpoint
│
├─── [10] Balance Transition (EXISTING — unchanged)
│
├─── [11] COMMIT checkpoint
│
├─── [12] Generate CSV Files
│          ├── (existing 12+ CSVs — unchanged)
│          └── ★ NEW: AllocationDetail + AllocationSummary CSVs ★
│
├─── [13] Create ZIP archive (all CSVs → single .zip)
│
└─── [14] Send Email (single email with zip attachment)
```

---

## 3. Data Flow Diagram (Tables)

### Data Sources (read-only — existing tables)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  EXISTING TABLES (read-only by allocation)                              │
│                                                                         │
│  ┌──────────────────────────┐    ┌──────────────────────────────────┐   │
│  │ trn_charge               │    │ log_daily_rate_calculation(_pre) │   │
│  │ ─────────────────────    │    │ ─────────────────────────────    │   │
│  │ • charge_id              │    │ • charge_id                      │   │
│  │ • student_id             │    │ • target_ym                      │   │
│  │ • product_id / plan_id   │    │ • paid_price  ← THIS IS "N"      │   │
│  │ • paid_price             │    │ • product_type                   │   │
│  │ • contract_type          │    │ • contract_type                  │   │
│  │ • department_id          │    │ • department_id                  │   │
│  │ • order_no               │    │ • order_no                       │   │
│  │ • start_date / end_date  │    └──────────────────────────────────┘   │
│  └──────────────────────────┘                                           │
│                                                                         │
│  ┌──────────────────────────┐    ┌──────────────────────────────────┐   │
│  │ trn_student_product      │    │ mst_rule_for_journals            │   │
│  │ ─────────────────────    │    │ ─────────────────────────────    │   │
│  │ • charge_id              │    │ • segment2_id                    │   │
│  │ • product_id             │    │ • product_type                   │   │
│  │ • plan_id                │    │ • account_item_id                │   │
│  │ • contract_type          │    │ • tax_code                       │   │
│  │ • start_date / end_date  │    │ • department_id                  │   │
│  └──────────────────────────┘    │ • segment1_id / segment2_id      │   │
│                                   └─────────────────────────────────┘   │
│  ┌──────────────────────────┐    ┌──────────────────────────────────┐   │
│  │ mst_code_change          │    │ mst_product                      │   │
│  │ ─────────────────────    │    │ ─────────────────────────────    │   │
│  │ • code → freee_code      │    │ • product_id                     │   │
│  │ • master_data_type       │    │ • product_type                   │   │
│  └──────────────────────────┘    └──────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### New Tables (written by allocation — asc_alloc_* prefix)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  NEW TABLES (ASC Allocation Framework)                                  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_calculation_runs                                        │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, project_code (cap/cip), target_ym, run_type (pre/final)     │  │
│  │ • status (creating/completed/failed/superseded)                   │  │
│  │ • started_at, completed_at, error_message                         │  │
│  │ PURPOSE: Run lifecycle tracking + audit                           │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_source_documents                                        │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, run_id, document_type, content_hash, content_json           │  │
│  │ PURPOSE: Immutable snapshot of input data for audit               │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_bundles                                                 │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, run_id, student_id, primary_charge_id                       │  │
│  │ • contract_type, department_id, order_no, match_rule              │  │
│  │ • bundle_status (0=active, 1=suspended, 2=terminated)             │  │
│  │ PURPOSE: One row per detected Coaching+App bundle                 │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_bundle_charges                                          │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, bundle_id, charge_id, product_id, product_type              │  │
│  │ • component_role (coaching/app)                                   │  │
│  │ PURPOSE: Products within a bundle (always 2 today)                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_reference_prices                                        │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, project_code, product_type, plan_id                         │  │
│  │ • reference_price (L value), effective_from, effective_to         │  │
│  │ PURPOSE: Allocation weights / list prices (effective-dated)       │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_groups                                                  │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, run_id, bundle_id, target_ym                                │  │
│  │ • sum_n (ΣN), sum_p (ΣP), is_balanced (ΣP=ΣN?)                    │  │
│  │ PURPOSE: One bundle × one month — validation unit                 │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_prorations  ← CORE TABLE                                │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, group_id, bundle_charge_id, record_kind (0/1/2)             │  │
│  │ • reference_price (L), ratio, n_value (N)                         │  │
│  │ • accounting_amount (P), adjustment_amount (P−N)                  │  │
│  │ • calc_rule_code, asc_source_table, asc_source_id                 │  │
│  │ PURPOSE: One row per product per group — the calculation result   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_sum_calculation                                         │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, run_id, project_code, target_ym                             │  │
│  │ • product_type, contract_type, department_id, partner_id          │  │
│  │ • adjustment_amount (ΣP−ΣN aggregated for Freee)                  │  │
│  │ PURPOSE: Freee journal granularity — feeds API call               │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_sum_calculation_history                                 │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, sum_calculation_id, proration_id                            │  │
│  │ PURPOSE: Trace: which proration rows → which summary row          │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ asc_alloc_deliveries                                              │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • id, run_id, delivery_type (freee/csv/email)                     │  │
│  │ • status (pending/sent/failed), attempted_at, response            │  │
│  │ PURPOSE: Track each Freee send / CSV gen / email attempt          │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ v_asc_alloc_prorations_active (VIEW)                              │  │
│  │ ─────────────────────────────────────────                         │  │
│  │ • Filters asc_alloc_prorations to latest non-superseded run       │  │
│  │ PURPOSE: Active results for queries without manual run filtering  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Data Flow — Allocation Calculation

```
                    ┌───────────────────────────┐
                    │     trn_charge            │
                    │     trn_student_product   │
                    └────────────┬──────────────┘
                                 │ detect CAP/CIP bundles
                                 │ (by plan_id + product_id)
                                 ▼
                    ┌───────────────────────────┐
                    │  asc_alloc_bundles        │
                    │  asc_alloc_bundle_charges │
                    └────────────┬──────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
              ▼                  ▼                   ▼
┌──────────────────┐  ┌─────────────────┐  ┌────────────────────┐
│ log_daily_rate_  │  │ asc_alloc_      │  │ asc_alloc_         │
│ calculation      │  │ reference_      │  │ groups             │
│ (_pre)           │  │ prices          │  │ (one bundle×month) │
│                  │  │                 │  │                    │
│ → N value        │  │ → L_app         │  └─────────┬──────────┘
│   (per charge)   │  │ → L_coaching    │            │
└────────┬─────────┘  └───────┬─────────┘            │
         │                    │                      │
         └─────────┬──────────┘                      │
                   │                                 │
                   ▼                                 │
         ┌──────────────────────────────┐            │
         │  ALLOCATION ENGINE           │            │
         │                              │            │
         │  P_app = floor(              │            │
         │    N × L_app /               │            │
         │    (L_coaching + L_app)      │            │
         │  )                           │            │
         │  P_coaching = N − P_app      │            │
         │                              │            │
         │  adj_app = P_app − 0 = +P    │            │
         │  adj_coaching = P_c − N = −P │            │
         │                              │            │
         │  Validate: Σadj = 0          │            │
         └──────────────┬───────────────┘            │
                        │                            │
                        ▼                            │
         ┌──────────────────────────────┐            │
         │  asc_alloc_prorations        │◄───────────┘
         │  (CORE RESULT TABLE)         │
         │                              │
         │  • one row per product       │
         │  • per group (bundle×month)  │
         │  • L, ratio, N, P, adj       │
         └──────────────┬───────────────┘
                        │
                        │ aggregate by
                        │ (product_type, contract_type, dept, partner)
                        ▼
         ┌──────────────────────────────┐
         │  asc_alloc_sum_calculation   │
         │  (Freee journal granularity) │
         └──────────────┬──────────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
              ▼                   ▼
    ┌─────────────────┐  ┌─────────────────────┐
    │  Freee API      │  │  CSV Files          │
    │  (2nd call)     │  │                     │
    │                 │  │  • AllocationDetail │
    │  T1 journals:   │  │  • AllocSummary     │
    │  App: +P_app    │  │                     │
    │  Coaching: −P   │  │  → into same ZIP    │
    │  (net = 0)      │  │  → same email       │
    └─────────────────┘  └─────────────────────┘
```

---

## 5. Freee Journal Sending — Before vs After

### Before (Current)

```
sendFreeeJournals2()
  │
  ├── Build $detailList from log_sum_calculation
  │   (T1: revenue, T2: advance payment, T3: wash)
  │
  ├── splitDetailListWithBalance($detailList)
  │   (split into balanced chunks of max 100 entries)
  │
  └── Freee API call(s) — one per chunk
      → log_send_journals_history
```

### After (With Allocation)

```
sendFreeeJournals2()
  │
  ├── Build $detailList from log_sum_calculation
  │   (T1: revenue, T2: advance payment, T3: wash)
  │   ← UNCHANGED
  │
  ├── splitDetailListWithBalance($detailList)
  │
  ├── Freee API call #1 — existing journals
  │   → log_send_journals_history
  │   ← UNCHANGED
  │
  └── ★ NEW: Allocation Freee send ★
      │
      ├── Build $allocDetailList from asc_alloc_sum_calculation
      │   (T1 only: App revenue +, Coaching revenue −)
      │   (guaranteed balanced: Σadjustment = 0)
      │
      ├── splitDetailListWithBalance($allocDetailList)
      │
      └── Freee API call #2 — allocation adjustments
          → asc_alloc_deliveries (new tracking table)
          → log_send_journals_history (with 'asc_alloc:' prefix in description)
```

**Key property:** API call #2 is independent. If #1 succeeds and #2 fails:
- Existing journals are safe (already sent)
- Allocation failure is logged in `asc_alloc_deliveries`
- Can retry allocation send later without re-running entire command

---

## 6. CSV / ZIP / Email — Before vs After

### Before (Current)

```
createSendMailAttacheFile()
  │
  ├── Generate 12+ CSV files (Invoice, Ticket, Daily, Monthly, Summary, etc.)
  ├── Add Zipan CSVs
  ├── Add Error CSV (if errors)
  ├── Create ZipArchive → {YYYYMMDD}.zip
  ├── Delete individual CSVs
  └── sendMail(mailType, [zipFile], contents)
```

### After (With Allocation — using extracted BatchReportDeliveryService)

```
$fileNameList = generateExistingCsvFiles()  ← UNCHANGED
│
├── ★ NEW: Add allocation CSVs (if allocation succeeded) ★
│   $allocFiles = allocationService->generateCsvFiles(targetYm, preFlg)
│   $fileNameList = array_merge($fileNameList, $allocFiles)
│
└── BatchReportDeliveryService::deliver($fileNameList, mailType, suffix)
    │
    ├── Create ZipArchive (all files → single .zip)
    ├── Delete individual CSVs
    └── sendMail() — same email, same format
```

**Result:** Accounting team receives the SAME email, SAME zip, with 2 additional CSV files inside.
No second email. No operational change.

---

## 7. Injection Points Summary (Changes to Existing Files)

| File | What's Added | Lines |
|---|---|---|
| `DailyRateCalculationPreLogic.php` | Service call at step [5], CSV merge at step [6], alloc tables in delete | ~12 |
| `SendJournalsDataLogic.php` | Service call at step [5], 2nd Freee send at step [8], CSV merge at step [12] | ~18 |
| `config/const.php` | CSV definitions for AllocationDetail + AllocationSummary | ~30 |
| `config/code.php` | App product_type mapping (if needed) | ~5 |

**Everything else is new code** in `app/Libs/AscAllocation/`, `app/Models/AscAlloc/`, `app/Enums/AscAlloc/`.

---

## 8. Failure Isolation

```
DailyRateCalculationPreLogic::execute()
│
├── [existing daily calc]  ← if this fails, entire command fails (existing behavior)
│
├── try {
│       AscAllocationService::calculate(...)  ← NEW
│   } catch (\Throwable $e) {
│       Log::error('[ASC_ALLOC] Allocation failed: ' . $e->getMessage());
│       // Mark run as failed in asc_alloc_calculation_runs
│       // Continue — do NOT re-throw
│   }
│
├── [generate CSVs]  ← allocation CSVs skipped if failed
│
└── [zip + email]  ← proceeds normally with available CSVs
```

If allocation fails:
- ✅ Existing daily/monthly calculation is unaffected
- ✅ Existing CSVs still generated and sent
- ✅ Email still goes out (without allocation CSVs)
- ✅ Failure logged in `asc_alloc_calculation_runs` (status = 'failed')
- ✅ Can be re-triggered manually for debugging
