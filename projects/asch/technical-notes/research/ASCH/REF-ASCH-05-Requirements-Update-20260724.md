# ASCH Requirement Updates — 2026-07-24 (Definitive)

**Source:** Kuroda-san (Confluence: "Requirement Updates as of 260724")  
**Status:** AUTHORITATIVE — supersedes all prior requirement documents where conflicts exist  
**Scope:** Complete consolidated specification for ASCH implementation

---

## What's New or Changed (vs REF-ASCH-04, 2026-07-22)

| Item | Change | Impact |
|---|---|---|
| CDB table name | Uses `trn_campaign_price_eligibility` (tentative) in §5, but references `trn_campaign_discount_eligibility` structure in §5.1 | Need to confirm final name with CDB team |
| N source selection (§10) | **DECIDED** — preview reads `_pre` tables, final reads confirmed tables. Explicit requirement to persist `asc_source_table` and `asc_source_id` per row. | New columns on `asch_monthly_prorations` |
| Freee App mapping (§11.2) | **RESOLVED** — App uses freee_code = 236270504 via `mst_code_change` for product_id=10012. No config change needed. | H-4 closed |
| CSV layout (§11.1.1) | Authoritative fixture files specified. Japanese column labels confirmed. No record_kind/component_type/unit_kind in output. | Spec 05 can now be fully specified |
| Acceptance scenarios (§12) | 16 explicit test scenarios defined | QA test planning input |
| asc_source_table + asc_source_id | Must be stored per proration row (source tables differ across components in same month) | New columns on `asch_monthly_prorations` |
| CDB "v1.2" referenced | Three tables + specific behaviors (create at enrollment, retain through plan change, clear on B2E→B2B) | Confirms CDB contract |

## Items Confirmed (Already in Our Docs)

- Option A (run_id) decided ✅
- Separate command + separate email ✅
- T1 journals only ✅
- 9 tables ✅
- Tax-inclusive amounts ✅
- Eligibility rules ✅
- Month-6 trigger (Coaching C6) ✅
- Refund principle ✅
- App price from mst_new_price_listing ✅
- Floor rounding, remainder-absorption ✅
- All pattern rules (1–9) ✅

---

## Full Document Content

(Stored as-is from Confluence for reference. The sections below are the authoritative specification.)

---

## Key Decisions Now Fully Documented

### N Source (§10) — DECIDED

| ASCH Run | N Source |
|---|---|
| Preview (1st) | `log_daily_rate_calculation_pre` / `log_monthly_rate_calculation_pre` |
| Final (3rd) | `log_daily_rate_calculation` / `log_monthly_rate_calculation` |

Must persist `asc_source_table` and `asc_source_id` per proration row.

### Freee App Mapping (§11.2) — RESOLVED

- App product_type = 100
- Freee product code: resolved through `mst_code_change` for product_id = 10012
- freee_code = 236270504
- No configuration change needed — existing mapping covers it
- ASCH sends T1 adjustment journal under this mapping

### CSV Authoritative Source

The physical layout is defined by fixture files:
- `sample_csv/pattern1_cp202607/AschComponentDetail_{YYYYMM}.csv`
- `sample_csv/pattern1_cp202607/AschCalculationSummary_{YYYYMM}.csv`
- `sample_csv/pattern1_cp202607/AschComponentDetail_column_guide_EN.csv`
- `sample_csv/pattern1_cp202607/AschCalculationSummary_column_guide_EN.csv`

### Acceptance Scenarios (§12) — 16 Required

1. Pattern 1: Simultaneous start
2. Pattern 2: Different Lesson/Coaching start dates
3. Pattern 3: Lesson start before campaign
4. Pattern 4: Daily-plan change
5. Pattern 5: Coaching REST during campaign
6. Pattern 6: Daily → Monthly 15 plan change
7. Pattern 7: B2E → B2B switch/refund
8. Pattern 8: Cooling-off (including cross-month)
9. Pattern 9: B2E with Loyal benefit
10. Daily 3/Daily 4 and legacy plan variants
11. Zero-yen App charge behavior (M=N=0, P allocated)
12. Preview vs final N source selection
13. C6 date before and after Lesson payment date
14. Normal finalization, failed validation, revision/supersession
15. CSV column order and absence of adjustment column
16. April cohort at first production run

---

## Impact on Open Items

| Previous Open Item | Status after 260724 |
|---|---|
| H-4 (Freee App mapping) | ✅ **RESOLVED** — freee_code=236270504 via mst_code_change. No config change needed. |
| H-9 (Run model) | ✅ Decided (Option A) — reconfirmed |
| H-10 (N source) | ✅ **DECIDED** — preview→_pre, final→confirmed. Persist source per row. |
| CDB table name | ⚠️ Document uses "trn_campaign_price_eligibility (tentative)" but CDB team confirmed "trn_campaign_discount_eligibility" in session. Need final alignment. |
| MySQL version | Still open (§13) |
| ASCH email copy | Still open — Kuroda-san to approve (§13) |

---

## New Columns Required on asch_monthly_prorations

From this document, columns not previously tracked:
- `paid_at` (DATE — snapshot of trn_charge.paid_at date part)
- `asc_source_table` (VARCHAR — which log table N was read from)
- `asc_source_id` (BIGINT — ID of the row in that log table)

These are in addition to previously specified columns.
