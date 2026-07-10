# ASCH Integration Points — Code-Level Research Report

**Date:** 2026-07-10  
**Purpose:** Map ASCH integration points against the existing ASCM codebase, compare DB designs, evaluate Pre/Final approaches, and identify design improvements.

---

## 1. Existing ASCM Code Architecture (Summary)

### Command → Logic → Model Layering

```
Commands (app/Console/Commands/)
├── DailyRateCalculationPreCommand    → DailyRateCalculationPreLogic (Pre: 1st of month)
├── MonthlyRateCalculationPreCommand  → MonthlyRateCalculationPreLogic (Pre: 1st of month)
├── MonthlyRateCalculationCommand     → MonthlyRateCalculationLogic   (Final: 3rd of month)
└── SendJournalsDataCommand           → SendJournalsDataLogic         (Final: 3rd of month)
```

### Pre Flow (1st of month — 速報)

1. `DailyRateCalculationPreCommand` triggers `DailyRateCalculationPreLogic::execute()`
2. Pre logic:
   - Deletes any existing data for target month (cleanup from prior failed runs)
   - Calls `CommonUtil::createDailyRateCalculation($targetYm, ..., preFlg=true)`
   - Writes to `log_daily_rate_calculation_pre` and `log_sum_calculation_pre`
   - Also runs `MonthlyRateCalculationPreLogic` → writes to `log_monthly_rate_calculation_pre`
   - Generates preview CSVs, sends via email
   - **Does NOT send to Freee**

### Final Flow (3rd of month — 確定)

1. `SendJournalsDataCommand` triggers `SendJournalsDataLogic::execute()`
2. Final logic:
   - Calls `CommonUtil::createDailyRateCalculation($targetYm, ..., preFlg=false)`
   - Writes to `log_daily_rate_calculation` and `log_sum_calculation`
   - Also creates `log_sum_calculation_history` linking rows
   - `MonthlyRateCalculationCommand` (run separately) writes to `log_monthly_rate_calculation`
   - Calls `sendFreeeJournals2()` — builds T1/T2/T3 journal entries and sends to Freee API
   - Creates balance transition records
   - Generates final CSVs, sends via email

### Pre/Final Table Duplication Pattern

| Concept | Pre Table | Final Table |
|---------|-----------|-------------|
| Daily rate per charge | `log_daily_rate_calculation_pre` | `log_daily_rate_calculation` |
| Monthly rate (CTE) | `log_monthly_rate_calculation_pre` | `log_monthly_rate_calculation` |
| Aggregated summary | `log_sum_calculation_pre` | `log_sum_calculation` |
| History/trace | (none for Pre) | `log_sum_calculation_history` |
| Balance transition | (none for Pre) | `log_balance_transition`, `log_balance_transition_with_order_number` |

**Key observation:** Pre and Final use **identical logic** (MonthlyRateCalculationLogic vs MonthlyRateCalculationPreLogic are near-clones differing only in `$TABLE_NAME`). This duplication is a known tech debt.

---

## 2. SendJournalsDataLogic — Freee Integration (T1/T2/T3)

### How Journals Are Built

The `sendFreeeJournals2()` method reads from `log_sum_calculation` and constructs journal entries:

**T1 — Revenue Recognition (売上仕訳)**
- Reads each row from `log_sum_calculation` for the target month
- Maps `product_type` → Freee product code via `MstCodeChange::getChangeCodeToFreeeCode()`
- Maps `(segment2_id, freee_product_type)` → journal rules via `MstRuleForJournals`
- Determines account item combinations (前受金/売上高/売掛金) based on contract_type and country
- Subtracts PayPal-linked amounts to avoid double-counting

**T2 — Advance Payment (前受金登録)**
- For B2B invoices where cumulative payments exceed cumulative revenue
- Creates debit/credit pairs for the difference

**T3 — Reversal/Wash (洗替処理)**
- Reverses prior-period advance payments when new revenue is recognized

### Mapping Chain: product_type → Freee

```
trn_charge.product_id
  → mst_product.product_type
    → mst_code_change (master_data_type=1) → freee_code (e.g., 191155067 for Coaching)
      → mst_rule_for_journals (segment2_id, product_type) → item_id, section_id, segment_1/2_tag_id
```

**Critical gap for ASCH:** `product_type=100` (App) has NO entry in `config/code.php` `freeeProductType` and likely no row in `mst_code_change` or `mst_rule_for_journals`. This mapping must be created before ASCH can send App journals.

---

## 3. log_sum_calculation — The Aggregation Hub

### Schema

```sql
log_sum_calculation (
  id BIGINT PK,
  target_ym CHAR(6),       -- YYYYMM
  department_id BIGINT,    -- B2B partner department
  order_no BIGINT,         -- Purchase order number
  product_type INT,        -- Maps to Freee item
  contract_type INT,       -- 0=B2C, 1=B2B, 2=B2B2C
  partner_id INT,          -- Freee partner ID
  tax_free INT DEFAULT 0,
  paid_price INT,          -- Aggregated amount for Freee
  ticket_flg INT DEFAULT 0,
  send_date DATE,          -- When sent to Freee
  status INT DEFAULT 1,
  country_id BIGINT,       -- 86=Japan, 194=Taiwan
  gross_amount DECIMAL,
  created_at, updated_at
)
```

### How It Feeds SendJournals

`LogSumCalculation::getLogSumCalculationForTargetYm($targetYm)` retrieves all rows for the target month, scoped to current batch run by `created_at` month filter. Each row becomes one T1 journal entry set.

### ASCH Integration Point

ASCH's `asch_sum_calculation` table mirrors this structure but stores **adjustment amounts** (P − N) rather than absolute values. ASCH would either:
- (A) Insert adjustment rows into `log_sum_calculation` directly (risky — pollutes existing data)
- (B) Use its own `asch_sum_calculation` and a separate Freee-send step (spec proposal)

**Recommendation: Option B** — keeps ASCH isolated, auditable, and doesn't risk regression on existing ASC reports.

---

## 4. ASCH Database Design (from REF-ASCH-00-PRJ-Specification.md)

### 10 New Tables — Purpose Summary

| # | Table | Analogy to ASCM | Notes |
|---|-------|-----------------|-------|
| 1 | `asch_calculation_runs` | (no equivalent — ASCM has no run management) | **New concept.** Tracks run_type (preview/final/revision), allows supersession |
| 2 | `asch_app_price_master` | `mst_product_price` (but discrepancy) | Needed because the App list price for proration ≠ mst_product_price |
| 3 | `asch_source_documents` | (no equivalent) | JSON snapshots for audit — ASCM has no audit trail |
| 4 | `asch_bundle_enrollments` | (no equivalent) | Registry of Honki Set members |
| 5 | `asch_enrollment_contract_periods` | (no equivalent) | B2E→B2B switch history |
| 6 | `asch_bundle_components` | (no equivalent) | Per-product per-revision tracking |
| 7 | `asch_proration_groups` | (no equivalent) | Grouping for ΣO = ΣM validation |
| 8 | `asch_monthly_prorations` | `log_daily_rate_calculation` + `log_monthly_rate_calculation` | **Core result table** — the row-level calculation |
| 9 | `asch_sum_calculation` | `log_sum_calculation` | Aggregation for Freee — stores adjustment amounts |
| 10 | `asch_sum_calculation_history` | `log_sum_calculation_history` | Trace linkage |

### Key Design Differences from ASCM

1. **Run management (`asch_calculation_runs`)** — ASCM has none; relies on delete-and-rerun
2. **Source document snapshots** — ASCM has no audit trail for input data
3. **Enrollment domain model** — ASCH explicitly models the bundle enrollment lifecycle; ASCM has no equivalent (charges are the only entity)
4. **Single core result table** — ASCH merges daily + monthly into one `asch_monthly_prorations` table; ASCM splits into 2 separate tables

---

## 5. ASCM vs ASCH — Scope Comparison

| Dimension | ASCM (Existing) | ASCH (Proposed) |
|-----------|-----------------|-----------------|
| **Purpose** | Calculate revenue recognition for ALL charges | Calculate proration adjustments for Honki Set bundle only |
| **Scope** | Bizmates + Zipan, all product types | Bizmates only, 3 products (Lesson, Coaching, App) |
| **Input** | `trn_charge` directly | ASCM results (N) + `trn_charge` + enrollment data |
| **Output** | Absolute revenue amounts → Freee | Adjustment amounts (P − N) → Freee |
| **Calculation** | Daily pro-rata (days) or Monthly (ticket consumption) | Bundle proration (ΣM allocation) then daily/monthly sub-calculation |
| **Tables touched** | ~6 log tables + history | 10 new `asch_*` tables (read-only on existing) |
| **Run management** | Delete-and-rerun (destructive) | `run_id` generation model (proposed) |
| **Audit** | None | Source document snapshots |
| **Pre/Final split** | Separate `_pre` tables (code duplication) | TBD — `run_type` field OR `_pre` tables |
| **Freee send** | Direct from `log_sum_calculation` in T1/T2/T3 | Separate send from `asch_sum_calculation` |

---

## 6. Pros and Cons: Pre/Final Two-Table Pattern vs run_id Model

### Option A: Pre/Final Two-Table Pattern (same as ASCM)

**How it would work for ASCH:**
- `asch_monthly_prorations_pre` + `asch_monthly_prorations` (2 tables)
- `asch_sum_calculation_pre` + `asch_sum_calculation` (2 tables)
- Total: 10 base tables → ~14-16 tables (some tables don't need Pre variants)

**Pros:**
- Team familiarity — operations staff know the pattern
- Simple mental model: Pre = preview, Final = confirmed
- No ambiguity about which data is authoritative
- No risk of querying wrong run_id
- Matches existing operational procedures exactly

**Cons:**
- Code duplication (MonthlyRateCalculationLogic vs MonthlyRateCalculationPreLogic are 1400+ line clones)
- Table proliferation — 10 base tables could become 16+
- No historical runs preserved — Pre is deleted on each rerun
- Cannot do retroactive recalculation (revision runs) without additional tables
- Cannot compare Pre vs Final results (no common key to join)
- Migration maintenance doubles

### Option B: run_id Generation Model (ASCH Specification Proposal)

**How it would work:**
- Single `asch_calculation_runs` table with `run_type` (preview/final/revision)
- All result tables carry `run_id` FK
- `is_finalized` flag marks the authoritative run
- `superseded_by_run_id` chains revisions

**Pros:**
- No code duplication — same logic writes to same table, different `run_id`
- Full run history preserved — JSOC audit compliance
- Supports revision runs for retroactive correction (Jan/Apr 2026 if needed)
- Can compare any two runs programmatically (Pre vs Final, old vs new)
- Single table = simpler indexes, joins, and model classes
- Better foundation for future campaign rounds (quarterly recurrence)
- Enables dry-run/simulation without destroying data

**Cons:**
- Operational unfamiliarity — team needs to learn "which run_id is current?"
- Queries must always filter by `run_id` or `is_finalized` (forgotten filter = wrong data)
- Slightly more complex cleanup — cannot just `TRUNCATE` a Pre table
- Risk of stale/orphaned runs accumulating (needs retention policy)
- Not yet battle-tested in this codebase

### Recommendation

**Use the run_id model for ASCH.** The retroactive correction requirement (Open Item #10), quarterly campaign recurrence, and JSOC audit needs all strongly favor it. The two-table pattern's only advantage is familiarity, which can be addressed by:
- A helper method `AschCalculationRun::currentFinal($targetYm)` that resolves the latest finalized run_id
- Clear documentation and naming conventions
- A cleanup command for old runs

---

## 7. What If ASCH Uses the Pre/Final Approach (Same as ASCM)

### Tables Required (Pre/Final duplication)

| Base Table | Needs Pre? | Reason |
|-----------|-----------|--------|
| `asch_calculation_runs` | No | Not needed — the Pre/Final split replaces this |
| `asch_app_price_master` | No | Reference data, not per-run |
| `asch_source_documents` | Maybe | Could snapshot both Pre and Final inputs separately |
| `asch_bundle_enrollments` | No | Reference/registry — built once |
| `asch_enrollment_contract_periods` | No | Reference data |
| `asch_bundle_components` | No | Reference data |
| `asch_proration_groups` | Yes | Different groupings possible between Pre and Final |
| `asch_monthly_prorations` | **Yes** | Core result — main candidate for Pre/Final split |
| `asch_sum_calculation` | **Yes** | Aggregation differs between runs |
| `asch_sum_calculation_history` | Yes | Trace differs |

**Result:** 10 base tables → 13-14 tables total (add `_pre` for groups, prorations, sum_calc, history)

### Impact on Commands

Would need to duplicate:
- `AschCalculationCommand` → `AschCalculationPreCommand`
- `AschCalculationLogic` → `AschCalculationPreLogic`
- Or: a single logic with `$preFlg` parameter switching table names (like existing `CommonUtil::createDailyRateCalculation`)

### Impact on Retroactive Correction (Open Item #10)

**Cannot do it cleanly.** If Jan/Apr 2026 correction is in scope, a third variant table would be needed (`_revision`?), or the Pre tables would be repurposed. Neither is clean.

---

## 8. What If ASCH Uses the Specification's Design (run_id Model)

### Commands

```
AschCalculationCommand {exeDate?} {--run-type=final} {--supersedes=}
```

Single command, single logic class. `--run-type` takes `preview|final|revision`.

### Flow

1. Create `asch_calculation_runs` row → get `run_id`
2. Build enrollment data → `asch_bundle_enrollments` (idempotent — reuse existing)
3. Calculate prorations → `asch_monthly_prorations` (all rows carry `run_id`)
4. Aggregate → `asch_sum_calculation` (rows carry `run_id`)
5. If `run_type=final`: Send to Freee, set `is_finalized=true`
6. If `run_type=preview`: Stop after CSV generation

### Querying

```php
// Get current finalized run
$run = AschCalculationRun::where('target_ym', $targetYm)
    ->where('is_finalized', true)
    ->whereNull('superseded_by_run_id')
    ->latest()
    ->first();

// Get all prorations for that run
$prorations = AschMonthlyProration::where('run_id', $run->id)->get();
```

### Revision Runs

```bash
php artisan asch:calculate 2026/01/03 --run-type=revision --supersedes=42
```

Creates a new run that supersedes run_id=42. Old run remains for audit. New run becomes authoritative.

---

## 9. Changes Needed to Existing Monthly/Daily/SendJournal for ASCH

### Principle: ASCH Does NOT Modify Existing ASC

The spec is explicit: "The existing revenue aggregation system (ASC) will not be modified." ASCH reads ASC output as N, calculates P, and sends the adjustment (P − N). Existing journals are never touched.

### What ASCH Needs to Read (Read-Only Integration Points)

| Existing Table | What ASCH Reads | Purpose |
|----------------|-----------------|---------|
| `log_daily_rate_calculation` | `paid_price` per charge/month | N for daily-plan Lessons and Coaching |
| `log_daily_rate_calculation_pre` | Same | N for preview runs |
| `log_monthly_rate_calculation` | `paid_price` per charge/month | N for Monthly-15 Lessons |
| `log_monthly_rate_calculation_pre` | Same | N for preview runs |
| `log_sum_calculation` | Aggregated amounts | Reference for summary-level comparison |

### Changes Actually Needed in Existing Commands

**None required for core ASCM logic.** However, these supporting changes are needed:

1. **`config/code.php` — Add App product type mapping**
   ```php
   'freeeProductType' => [
       // ... existing
       'bizmatesApp' => <new_freee_item_id>,  // OPEN ITEM: accounting must provide
   ],
   ```

2. **`mst_code_change` table — Add App entry**
   - `master_data_type=1, code=100, freee_code=<TBD>` for App product type

3. **`mst_rule_for_journals` table — Add App journal rules**
   - New row(s) mapping `(segment2_id, app_product_type)` → item_id, section_id, segments

4. **SendJournalsDataLogic — ASCH Freee Send (New, Separate)**
   - ASCH should have its own `AschSendJournalsLogic` class
   - Reuses the T1 pattern (debit/credit pair construction) but reads from `asch_sum_calculation`
   - Does NOT need T2 (advance payment) or T3 (wash) — ASCH adjustments are one-shot corrections
   - References `MstRuleForJournals` and `MstCodeChange` for mapping (same lookup chain)

5. **DailyRateCalculationPreLogic::deleteTargetYMData() — No change needed**
   - This deletes `log_*` tables for the month before rerunning
   - ASCH tables (`asch_*`) are NOT in the delete list → ASCH data is safe
   - BUT: If ASCH uses the run_id model, it doesn't need delete-and-rerun anyway

### Changes If ASCH Shares `log_sum_calculation` (NOT recommended)

If ASCH wrote adjustments directly to `log_sum_calculation`:
- `SendJournalsDataLogic::sendFreeeJournals2()` would automatically pick them up
- BUT: `DailyRateCalculationPreLogic::deleteTargetYMData()` would also delete them
- Need to add `WHERE source != 'asch'` guards everywhere
- Breaks the "ASC unchanged" principle
- **Conclusion: Do not share tables.**

---

## 10. Design Improvements to Fix in ASCM Before Proceeding with ASCH

These are improvements that should be addressed regardless of ASCH, but become more urgent if ASCH reuses ASCM patterns or shares the same operational window:

### Priority 1: Critical (Must fix before ASCH if sharing DB)

| # | Issue | Current State | Risk | Improvement |
|---|-------|--------------|------|-------------|
| 1 | **Destructive cleanup** | `deleteTargetYMData()` bulk-deletes by `created_at >= month_start` | If ASCH runs in the same window and someone reruns Pre, ASCH data could be caught in cross-fire (if same tables) | Add explicit table-name guards; ASCH uses own tables with own cleanup |
| 2 | **No run identification** | Rows have no `batch_run_id`; only `created_at` distinguishes runs | Cannot trace which batch produced which rows; cannot safely rerun without full delete | Add `batch_run_id` column to `log_sum_calculation` and `log_daily_rate_calculation` (additive, non-breaking) |
| 3 | **`created_at` as a batch filter** | `whereRaw('date_format(created_at,"%Y-%m")=...')` is used everywhere in `LogSumCalculation` | If a batch spans midnight or is rerun in a different month, data is lost/invisible | Replace with explicit `batch_month` or `run_date` column |

### Priority 2: Important (Should fix for maintainability)

| # | Issue | Current State | Risk | Improvement |
|---|-------|--------------|------|-------------|
| 4 | **Pre/Final code duplication** | `MonthlyRateCalculationLogic` and `MonthlyRateCalculationPreLogic` are 1400+ line clones | Every CTE fix must be applied twice; bugs drift between them | Refactor into single class with injectable `$tableName` parameter |
| 5 | **No idempotent reruns** | Re-running Final requires manual deletion or trusting `deleteTargetYMData()` | Partial failures leave inconsistent state | Add upsert semantics or soft-delete + batch_id |
| 6 | **Monolithic SendJournalsDataLogic** | Single 1100+ line file handles daily calc + Freee send + balance transition + CSV + email | Hard to extend; ASCH would need to copy patterns from a monster file | Extract: `FreeeJournalBuilder`, `BalanceTransitionService`, `CsvGenerationService` |
| 7 | **Magic numbers in journal construction** | `config('code.partnerId.dummy')`, `config('const.accounItemInfo...')` scattered through logic | New product types (App) require tracing the full config chain | Centralize into a `JournalEntryFactory` that takes structured input |

### Priority 3: Nice to Have (Long-term health)

| # | Issue | Current State | Risk | Improvement |
|---|-------|--------------|------|-------------|
| 8 | **No validation framework** | Results are trusted after insert; no post-calculation integrity checks | Silent data corruption (e.g., ΣO ≠ ΣM would go unnoticed in ASCM) | Add validation step that asserts invariants before commit |
| 9 | **No dry-run capability** | Must actually write to DB to see results | Testing formula changes requires destructive operations | Add `--dry-run` flag that generates CSV without DB writes |
| 10 | **Hardcoded table name in Zipan** | `log_daily_rate_calculation_zipan` vs `log_daily_rate_calculation` (same name, different DB) | Confusing; new developers mis-target tables | Document clearly; consider unifying naming |

---

## 11. Design Changes to Observe for Existing Reports (Even If ASCH Has Its Own Report)

Even though ASCH produces separate CSV outputs (`AschComponentDetail`, `AschCalculationSummary`), the following design considerations affect the **existing reports** and the **operational flow**:

### 11.1 Execution Order Dependency

ASCH reads N from `log_daily_rate_calculation` / `log_monthly_rate_calculation`. These tables are populated by the existing commands. Therefore:

```
Execution order MUST be:
  1. MonthlyRateCalculationCommand (or Pre)    → populates N source
  2. SendJournalsDataCommand                   → populates log_sum_calculation (N source for daily)
  3. AschCalculationCommand                    → reads N, calculates P, stores adjustment
  4. AschSendJournalsCommand                   → sends adjustments to Freee
```

**Design observation:** If ASC fails mid-run and is rerun, ASCH must also be rerun (it would read stale N values otherwise). This argues for either:
- An orchestration script that runs all in sequence with failure gates
- ASCH storing the N values it read (already in the spec: `asch_monthly_prorations.N` column)

### 11.2 CalculationSummary CSV — Reconciliation

The existing `CalculationSummary` CSV (from `log_sum_calculation`) shows what ASC sent to Freee. After ASCH sends adjustments, the accounting team needs to reconcile:

```
Total Freee balance = ASC amount (N) + ASCH adjustment (P − N) = P
```

**Design observation:** The `AschCalculationSummary` CSV should include both N and P alongside the adjustment, so accounting can cross-reference without manually joining two CSVs.

### 11.3 Balance Transition Report

`createBalanceTransition()` and `createBalanceTransitionWithOrderNumber()` in `SendJournalsDataLogic` track cumulative balances. ASCH adjustments change the economic reality but are NOT reflected in these existing balance tables.

**Options:**
- (A) Create separate `asch_balance_transition` tables (isolated, simple)
- (B) Extend existing balance transition to include ASCH adjustments (complex, risky)
- (C) Accept that balance transition only reflects ASC values; ASCH has its own reconciliation view

**Recommendation:** Option C for now. Balance transition is used for T2/T3 advance payment logic which is B2B-specific. Honki Set is B2C-only (B2B excluded from campaign). No conflict.

### 11.4 PayPal Payment Sum CSV

ASC-304 is currently in progress to fix missing monthly data in PaypalPaymentSum. Honki Set students are B2C (pay via PayPal/credit card). Their charges already flow through ASC normally. ASCH adjustments are accounting-internal (revenue allocation between products) and do NOT affect payment-side reports.

**No change needed** to PaypalPaymentSum or payment-related reports.

### 11.5 Email Notifications

Both ASC and ASCH generate CSVs and send them via email. The existing email infrastructure (`CommonUtil::sendMail()`) can be reused for ASCH CSVs. Consider:
- Separate email templates for ASCH results
- Different recipient list (accounting team members who handle bundle proration)
- Clear naming to distinguish ASCH from ASC emails

### 11.6 Freee API Rate Limits and Journal Grouping

`SendJournalsDataLogic::sendJournalDataToFreee()` splits `$detailList` into chunks (DEFAULT_CHUNK_SIZE = 100) using `splitDetailListWithBalance()`. ASCH's journal send should follow the same chunking pattern. If both ASC and ASCH run on the same day (3rd of month), they hit the same Freee API. Consider:
- Staggering execution times
- Or combining into a single Freee call (not recommended — breaks isolation)

---

## 12. Summary of Recommendations

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Run management | **run_id model** | Audit needs, retroactive correction, quarterly recurrence |
| Table isolation | **Own `asch_*` tables, never share `log_*`** | "ASC unchanged" principle; prevents cascade failures |
| Pre/Final handling | **Single logic + run_type** | Avoids ASCM's code duplication tech debt |
| Freee send | **Separate `AschSendJournalsLogic`** | Isolated, auditable; reuses mapping chain but not T2/T3 |
| ASCM refactoring | **Optional but valuable** — extract Freee journal builder | ASCH can reference the pattern; long-term the builder becomes shared |
| Existing reports | **No changes needed** | ASCH is additive; B2C-only means no balance transition conflict |
| Execution orchestration | **Sequential with failure gates** | ASCH depends on ASC completing first |
| Config/master data | **Must add App mappings** before ASCH can send to Freee | `mst_code_change`, `mst_rule_for_journals`, `config/code.php` |

---

## 13. Open Questions for Next Steps

1. Should ASCM's `batch_run_id` improvement (Priority 1, #2) be done proactively, or is ASCH's full isolation sufficient?
2. If ASCH uses run_id model, does the team want a unified orchestration command (`asc:run-all`) that sequences both ASC and ASCH?
3. Should the Freee journal builder be extracted from `SendJournalsDataLogic` as a shared service, or should ASCH just copy the T1 pattern?
4. What retention policy for old ASCH runs? (e.g., keep last 12 months, archive to S3?)
