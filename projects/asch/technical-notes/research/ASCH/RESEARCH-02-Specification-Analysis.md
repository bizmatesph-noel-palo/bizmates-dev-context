# ASCH — Specification Analysis & Project Summary (20260703)

**Project:** ASCH (ASC Honki Set — Revenue Proration Batch)  
**JIRA Key:** ASCH (TBA — project not yet created)  
**Related Project:** [ASC](https://bizmates.atlassian.net/browse/ASC) (Accounting System for Freee)  
**Prepared by:** Noel Palo  
**Date prepared:** 2026-07-03  
**Sources:** Full specification from Kuroda-san (REF-ASCH-00_PRJ_Specification) + Kuroda's response to RESEARCH-01 (RESEARCH-01_REF_Kuroda_Response) + initial research (RESEARCH-01) + all REF docs  
**Status:** Specification confirmed — dev team action items identified, ready for estimation  
**Prior research:** `RESEARCH-01-Initial-Research-Analysis.md` (initial research before spec)

---

## 1. Executive Summary

The ASCH project adds a **revenue proration batch** to the existing accounting system. It calculates how to allocate bundled payments across 3 products (Lesson, Coaching, App) for students enrolled in the Honki Set campaign, then sends **adjustment journal entries** to Freee representing the difference between the prorated amount and what ASC already booked.

**Key architectural decision:** ASCH does NOT modify existing ASC. It reads ASC's output (N), calculates the correct prorated amount (P), and sends the difference (P − N) as an adjustment. Existing ASC journals are never touched.

**Scope:** Bizmates-only (`mysql` connection). Coaching and App do not exist on Zipan.

**Scale:** 10 new database tables, 2 new CSV outputs, Freee adjustment journals, 9+ calculation patterns.

**Status:** Full specification received and confirmed by Kuroda-san. 13 open items remain (several with estimate impact). 4 dev team action items identified. Design decisions pending on run management model and several accounting rules.

---

## 2. Architecture: How ASCH Fits Into the System

```
┌─────────────────────────────────────────────────────────────┐
│                    Source Data (read-only)                    │
│                                                              │
│  trn_charge, trn_student_product, mst_product               │
│  log_daily_rate_calculation ──── N (daily plans)             │
│  log_monthly_rate_calculation ── N (monthly plans)           │
│  log_first_month_enrollment_discount_apply                   │
│  log_loyal_benefits_charge                                   │
│  trn_student_rest_history                                    │
│  trn_prorated_application, trn_prorated_refund_charge        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    ASCH Batch (NEW)                           │
│                                                              │
│  1. Identify Honki Set enrollments                           │
│  2. Build proration groups (ΣM per enrollment)               │
│  3. Allocate: O = ΣM × (basis / Σbasis)                     │
│  4. Prorate:  P = O × (J / I)                               │
│  5. Calculate adjustment: P − N                              │
│       │                                                      │
│       ▼                                                      │
│  asch_monthly_prorations (core table)                        │
│  asch_sum_calculation (Freee granularity)                    │
│       │                                                      │
│       ├──► AschComponentDetail CSV                           │
│       ├──► AschCalculationSummary CSV                        │
│       └──► Freee adjustment journals (ΣP − ΣN)              │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Existing ASC (UNCHANGED)                   │
│                                                              │
│  DailyRateCalculation ──► Daily CSV ──► Freee journals       │
│  MonthlyRateCalculation ──► Monthly CSV                      │
│  SendJournalsData ──► Freee (original entries)               │
│                                                              │
│  ASC continues to run exactly as before.                     │
│  ASCH adjustments ADD to ASC journals, never modify them.    │
└─────────────────────────────────────────────────────────────┘
```

**Key principle:** `Final accounting value = ASC value (N) + ASCH adjustment (P − N) = P`

**Precondition (from Kuroda-san):** Honki Set charges MUST flow through the existing ASC pipelines as normal charges. This is required for N values to exist. Dev team needs to verify this explicitly.

**Separation rule:** ASCH can run within the same batch execution as ASC, but its processing and queries must be completely separated. No modification to existing ASC queries.

---

## 3. Campaign Rules (Confirmed)

### 3.1 Eligibility

**Who qualifies:**
- Students who have **never taken Coaching 30-min** (or cancelled it — cancellation makes them eligible again)
- Must sign up for Coaching 30-min AND have/sign up for Lesson (Daily 1 / Daily 2 / Monthly 15) during campaign period

**Eligible segments:**
- New customers
- Existing Lesson students (no prior Coaching)
- Existing Coaching 15-min students (upgrading to 30-min)
- Returning students (REST) — Lesson and Coaching must be applied at the same time

**Exclusions:**
- B2B students (`contract_type=1`)
- Non-Japan students (`country_id≠86`)
- Coaching 15-min is NOT part of the bundle

**Campaign period (current round):** 2026/7/1 – 2026/7/26 (application window — when students can sign up). Expected to repeat quarterly.  
**Benefit period:** 6 months from application date (5 renewals after first month).

> **Important distinction:** Application window (7/1–7/26) ≠ benefit period (6 months). The `mst_honki_set.end_date` may represent when the last enrolled student's month-1 benefits end (approximately end of October for July enrollees), not the application deadline.

> **Note:** Previous rounds ran Jan 2026 and Apr 2026 without proration. Retroactive correction is an open item.

### 3.2 Benefits

| # | Benefit | Condition |
|---|---------|-----------|
| 1 | Month 1: Coaching 50% off | Automatic for all Honki Set members. Lesson 50% off only for NEW Lesson contracts (existing Lesson students get Coaching discount only). Marketing still confirming details. **Note (from Kuroda):** The first-month 50% also applies to B2E students — same calculation regardless of contract type. |
| 2 | App free for 6 months | List price ¥3,600/month. Lost from following month if student cancels. |
| 3 | Month 6: 50% off | Lost permanently if student cancels mid-way. Even re-subscribing doesn't restore it. Applied as a discount at payment time (not cashback/retroactive). |

### 3.3 Detailed Rules

| Rule | Detail |
|------|--------|
| Plan change mid-campaign | Month-6 discount applies to the plan active at month-6 contract date. 6-month count starts from original date. |
| Lesson started before campaign | Month-6 discount per product based on each product's own contract date (Coaching discount on Coaching's month-6, Lesson discount on Lesson's month-6). |
| Loyal/B2E discount (5%/10%) | Applies normally each month EXCEPT months 1 and 6 — only the 50% applies (not stacked). |
| Coaching cancellation mid-way | App membership also removed from month after cancellation. |
| Re-start after cancellation | Month-6 discount and App right are permanently lost. |

---

## 4. Proration Formula (Confirmed)

### The 4-step calculation

```
Step 1: Build proration group
  Group = all charges newly starting in the month for one enrollment
  Total paid = ΣM (sum of paid amounts; App = 0)

Step 2: Determine basis per product
  basis = M (paid amount) → when NON-Honki discount applies (First Month, Loyal, B2E)
  basis = L (list price) → when Honki Set discount applies, or no discount

Step 3: Allocate
  O(product) = ΣM × ( basis(product) / Σ basis(all products) )

Step 4: Monthly proration
  P = O × (J / I)
  Where: I = contract days (or total tickets), J = days in month (or tickets consumed)
```

### Key behaviors

- **O carries over** — for continuing charges, O is not recalculated each month
- **Monthly-15 plan** — uses ticket counts for I/J, so P can exceed list price when consumption is skewed
- **Invariant ΣO = ΣM** must always hold (validation check)
- **Invariant ΣP = O** over charge lifetime must always hold
- **Monthly ΣP ≠ ΣM** — this is expected for mid-month starts and must NOT be validated

### Adjustment sent to Freee

```
adjustment = P − N (per row)
```

Where N = amount already booked by existing ASC (from `log_daily_rate_calculation` or `log_monthly_rate_calculation`).

**Existing ASC journals are never modified.** ASCH sends adjustment-only entries.

---

## 5. Calculation Patterns (9 defined, more expected)

| # | Pattern | Description | Key Complexity |
|---|---------|-------------|---------------|
| 1 | Simultaneous start | Lesson and Coaching start same date, month-start | Baseline — simplest case |
| 2 | Different start dates | Lesson and Coaching start on different days | Period boundary mismatch — J/I differs per product |
| 3 | Start before campaign | Lesson contracted before campaign, Coaching joins during | Month-6 discount dates differ per product |
| 4 | Plan change Daily1 → Daily2 | Plan upgrade mid-campaign | New revision created; discount applies to active plan at month-6 |
| 5 | Coaching rest | Student suspends Coaching mid-way | App removed from following month; month-6 lost |
| 6 | Plan change Daily1 → Monthly15 | Switch from daily to ticket-based plan | I/J switches from days to ticket counts |
| 7 | B2E → B2B switch with refund | Corporate contract type change | Contract period history; App possibly excluded after switch |
| 8 | Cooling-off refund / B2E + Loyal | Refund within cooling-off period + loyalty discount | Negative M values; basis uses M (non-Honki discount) |
| 9 | (Additional) | Combination or edge cases | TBD |

> "All 9 are in scope but there will be other cases we need to handle." — Kuroda-san

---

## 6. Database Schema (10 New Tables)

### Table overview

| # | Table | Role | Record Count Estimate |
|---|-------|------|----------------------|
| 1 | `asch_calculation_runs` | Run management (preview/final/revision) | ~2-3 per month |
| 2 | `asch_app_price_master` | App list price (⚠️ discrepancy: ¥3,600 vs ¥2,500) | ~1-5 rows total |
| 3 | `asch_source_documents` | Input data snapshot for audit (JSON, deduped by hash) | Grows with each run |
| 4 | `asch_bundle_enrollments` | Honki Set member registry | ~hundreds per campaign |
| 5 | `asch_enrollment_contract_periods` | Contract type history per enrollment | ~1-2 per enrollment |
| 6 | `asch_bundle_components` | Products per enrollment (revisions for plan changes) | ~3-6 per enrollment |
| 7 | `asch_proration_groups` | Grouping unit for ΣO = ΣM validation | ~1 per enrollment per new-start month |
| 8 | `asch_monthly_prorations` | **Core result table** (equivalent to Excel rows) | ~3 products × 6 months per enrollment |
| 9 | `asch_sum_calculation` | Freee aggregation (adjustment amounts) | ~per product_type per contract_type per month |
| 10 | `asch_sum_calculation_history` | Trace: proration → summary linkage | Same count as #8 |

### Key design decisions in the schema

- **`run_id` model (proposed):** Every result row carries a `run_id` linking to `asch_calculation_runs`. Enables full history and revision runs. Alternative: existing `_pre`/final two-table pattern (would double the table count).
- **`asch_bundle_enrollments`:** This is the "Honki Set member" registry — solves the identification problem from RESEARCH-01.
- **`asch_source_documents`:** JSON snapshots for audit — enables retroactive recalculation without re-querying source tables.
- **`revision_no` on components:** Plan changes create new revisions, not updates. Full history preserved.
- **No foreign key constraints:** Same convention as existing ASC tables.

### App product identification (CONFIRMED)

- `product_id = 10012` — "Bizmates App Premium Plan"
- `product_type = 100`
- ⚠️ `has_app_subscription` in `trn_student_app_info` is NOT usable for Honki Set detection (it's an in-app-purchase flag)

---

## 7. Outputs

| Output | Target | Content |
|--------|--------|---------|
| `AschComponentDetail_{YYYYMM}.csv` | Accounting team (review) | One row per proration row — detail level |
| `AschCalculationSummary_{YYYYMM}.csv` | Accounting team (review) | Freee-submission granularity with N, P, adjustment |
| Freee adjustment journals | Freee API | `ΣP − ΣN` — reuses T1/T2/T3 logic from `SendJournalsDataLogic` |

### Batch schedule

- **1st of each month:** Preview run → preview CSV
- **3rd of each month:** Final run → final CSV + Freee journal submission

Same timing as existing ASC batches.

---

## 8. Open Items (14 from spec + resolved from RESEARCH-01)

### 8.1 Spec Open Items (from Kuroda-san)

| # | Item | Owner | Impact | Notes |
|---|------|-------|--------|-------|
| 1 | Run management model — `run_id` vs `_pre`/final two-table | Dev | **[estimate]** Table count doubles with `_pre` | Proposal: `run_id` model |
| 2 | App list price — ¥3,600 (requirement) vs ¥2,500 (`mst_product_price`) | Accounting / Business | Affects all proration calculations | `asch_app_price_master` table handles this |
| 3 | Rounding rule — half-up vs truncation, who absorbs remainder | Accounting | | Default: half-up, largest row absorbs |
| 4 | Month-6 discount baseline — per product's own date vs bundle start date | Accounting / Marketing | | Both counters stored; either adoptable |
| 5 | Freee mapping for App — `config/code.php` has no `product_type=100` entry | Accounting | New account code needed | |
| 6 | Monthly-15: P can exceed list price in a month — treatment? | Accounting | | Ticket consumption skew |
| 7 | B2E→B2B switch — App excluded from proration after switch? | Accounting | | Default: stop App at switch date |
| 8 | Refund month allocation — do refunds span months? | Accounting | | Default: book in month refund occurs |
| 9 | N source for preview — use `log_*_pre` tables? | Dev | | Default: preview→_pre, final→confirmed |
| 10 | Retroactive correction (Jan/Apr 2026) — in scope? | Accounting / Segawa-san | **[estimate if in scope]** | Default: out of scope |
| 11 | Honki Set member identification — persisted table/log exists? | Dev | **[estimate]** Intake logic depends on this | `is_honki_eligible` (CPF-56 / PR #5531) exists in MBTI_backend GraphQL. Kuroda asks: can we build identification on `mst_honki_set` + `HonkiSetService` waterfall (or HCR 5-CTE query)? What does actual `mst_honki_set` data look like for current campaign? |
| 12 | First-month Lesson discount — "new contracts only" still being confirmed | Marketing | | Affects which students get Lesson 50% off |
| 13 | CS operation for App cancellation flow | CS / Marketing | | When Coaching cancelled, how is App removed? |
| 14 | DDL location — `document/sql` in ASC repo vs `ls-database-migrations` repo | Dev | | Kuroda assumed `document/sql`. Dev team to advise current practice. |

### 8.2 Questions Resolved (from Spec + Kuroda's Response)

These were open in RESEARCH-01 and are now answered:

| RESEARCH-01 Question | Answer | Source |
|---------------------|--------|--------|
| Where do Honki Set charges live? How to identify? | `asch_bundle_enrollments` table will be the registry. Identification logic to be built on `mst_honki_set` + `HonkiSetService` waterfall. | Spec + Kuroda response |
| What is the App `product_id`? | `product_id = 10012`, `product_type = 100`. Does NOT appear in `trn_charge` (student pays ¥0). ASCH synthesizes App rows with N=0. | Kuroda response |
| Where are standard prices stored? | `mst_product` / `mst_product_price`. App discrepancy (¥2,500 vs ¥3,600) handled by `asch_app_price_master`. Using ¥3,600 until confirmed. | Kuroda response |
| What are the other patterns? | 9 patterns defined. Details walkthrough session to be scheduled. | Spec + Kuroda response |
| Does Honki Set need new `config/code.php` entries? | Yes — `product_type=100` has no Freee mapping. New account code needed. | Kuroda response |
| Forward-looking only or historical? | Forward-looking by default. Retroactive (Jan/Apr 2026) handled later via revision run if needed. | Kuroda response |
| How does month-6 discount work? | Payment discount (not cashback). Per product's own contract date. Discount month can differ between Lesson and Coaching. | Kuroda response |
| Are Honki Set charges already processed by ASC? | Yes — ASCH is additive (adjustment = P−N). **Precondition: dev team must verify Honki Set charges flow through ASC.** | Kuroda response (architecture correction) |
| B2E First Month discrepancy (B2C vs B2E) | **Resolved.** First Month 50% discount DOES apply to B2E students. REF_09 (Campaigns Overview) was incomplete. Same calculation regardless of contract type. | Kuroda response |
| plan_ids [1010, 1011] — coaching only? | Confirmed coaching plans. Lesson eligibility defined by plan condition (Daily 1/Daily 2/Monthly 15), not by `mst_honki_set.plan_ids`. | Kuroda response |

---

## 9. Dev Team Action Items (from Kuroda-san)

These are specific requests from Kuroda-san for the estimate:

| # | Action | Priority | Detail |
|---|--------|----------|--------|
| 1 | Investigate participant identification via `mst_honki_set` / `HonkiSetService` | **High** | Main design blocker. Can we build identification on the existing waterfall or HCR 5-CTE query? What does actual `mst_honki_set` data look like for the current campaign? |
| 2 | Confirm Honki Set charges appear in existing ASC daily/monthly results | **High** | Precondition for the adjustment approach. If N doesn't exist for these charges, the entire architecture fails. |
| 3 | Opinion on run management model | **Medium** | `run_id` generation model (proposed) vs existing `_pre`/final two-table pattern. Affects table count, migration scope, and batch lifecycle. |
| 4 | Advise on DDL location | **Medium** | Kuroda-san assumed raw DDL under `document/sql` in ASC repo. Our convention is `ls-database-migrations`. Which practice applies? |

### Items Kuroda-san's Side is Confirming

- Campaign period: application window (7/1–7/26) vs benefit period — verifying against `mst_honki_set` data
- App price (¥2,500 vs ¥3,600)
- Exact cohort scope with marketing
- Remaining accounting items in Spec Section 7

---

## 10. Key Insights & Implications for Development

### What changed from our initial understanding (RESEARCH-01)

| Assumption in RESEARCH-01 | Reality from Spec |
|--------------------------|-------------------|
| ASCH replaces ASC output for Honki Set students | ASCH **supplements** ASC with adjustment entries (P−N). ASC is unchanged. |
| Might need 1-2 new tables | **10 new tables** with full schema design |
| "Pattern 2" was unknown | 9 patterns defined, all in scope |
| Freee might share existing codes | App needs a NEW Freee account mapping (`product_type=100` not in `config/code.php`) |
| Might need to exclude Honki Set from ASC | No exclusion needed — ASCH reads ASC output as input (N) |
| Campaign is July 2026 only | Campaign ran in Jan and Apr 2026 too — retroactive correction possible |
| Simple ratio calculation | Same formula but with carry-over logic (O persists across months), ticket-based plans, and complex revision handling |

### Critical technical takeaways

1. **ASCH reads ASC output.** It depends on ASC running first. Batch sequencing matters.
2. **O carries over.** Once calculated for a charge, O is not recalculated in subsequent months. Only P changes (based on that month's J/I).
3. **9+ patterns means extensive test coverage.** Each pattern likely becomes a test case set.
4. **The `run_id` proposal is an architectural upgrade** over the existing `_pre`/final pattern. If adopted, it sets a precedent that could eventually be backported to ASC.
5. **App list price discrepancy** (¥3,600 vs ¥2,500) is a blocker for accurate calculations.
6. **Honki Set member identification** is still the biggest unknown — without a persisted enrollment record, the batch can't know who to process.

---

## 11. Recommendations

1. **Prioritize resolving Open Items #2, #5, and #11** — these block development. App price, Freee mapping, and member identification are foundational.
2. **Decide run management model early** (Open Item #1) — it affects table count, migration scope, and the entire batch lifecycle architecture.
3. **Start with Pattern 1 implementation** — it's the simplest and validates the core formula. Layer other patterns incrementally.
4. **Establish test case methodology** — 9 patterns × preview/final × validations = significant test matrix. Define the approach early.
5. **Confirm retroactive scope** (Open Item #10) — if Jan/Apr 2026 are in scope, it significantly increases the estimate.

---

## 12. References

| Document | Location |
|----------|----------|
| ASCH Specification (Kuroda-san — full spec) | `[asch] technical-notes/research/ASCH/REF-ASCH-00_PRJ_Specification.md` |
| ASCH Project Brief (Kuroda-san) | `[asch] technical-notes/research/ASCH/REF-ASCH-00_PRJ_Brief_Kuroda.md` |
| Pattern 1 (Case 1) Data & Formula | `[asch] technical-notes/research/ASCH/REF-ASCH-00_PATTERNS_Case1_Data.md` |
| MOM: Honkiset Discussion (2026-07-02) | `[asch] technical-notes/research/ASCH/REF-ASCH-01_MOM_20260702_Honkiset_Discussion.md` |
| Kuroda-san's Response to RESEARCH-01 | `[asch] technical-notes/research/ASCH/RESEARCH-01_REF_Kuroda_Response.md` |
| ASCH Initial Research | `[asch] technical-notes/research/ASCH/RESEARCH-01-Initial-Research-Analysis.md` |
| HCR — Customer Retention Overview | `[asch] technical-notes/research/ASCH/REF-HCR-00_Customer_Retention_Overview.md` |
| Campaigns Overview | `[asch] technical-notes/research/ASCH/REF-DOC-01_Campaigns.md` |
| Account Types (Contract Types) | `[asch] technical-notes/research/ASCH/REF-DOC-02_Account_Types.md` |
| Honki Set Allocation Google Sheet | [Google Sheets](https://docs.google.com/spreadsheets/d/1NoaaoTNX8a-enGql_qZdGke8MofQX8AHThNF6XB0Sgk/edit?gid=824143910#gid=824143910) |
| ASC Session Context | `[ascm] project-context.md` |

---

*Research created: 2026-07-03*  
*Last updated: 2026-07-03 (updated with Kuroda-san's response to RESEARCH-01)*  
*Status: Specification confirmed — dev team action items identified, ready for estimation*
