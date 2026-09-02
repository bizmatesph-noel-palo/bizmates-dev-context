# ASC Allocation Framework — Technical Design Document

## Document Info

| | |
|---|---|
| **Document type** | Technical Design |
| **Date** | 2026-08-13 (Created) · 2026-08-20 (Open items updated) · 2026-09-01 (§11 table names synced with ADR) · 2026-09-01 (product_id changes 10021→10022 App, 10022→10025 CIP; O-5 reopened; O-7/O-8 added) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro (code analysis, data flow tracing, document generation) |
| **Status** | Active |
| **Audience** | Dev team (Noel, Throy, Orlino, Cristoff), Patrick-san (SDM), Kuroda-san (PM) |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) · [ASCI](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) |

---

## 1. Document Purpose

This is the single technical reference for the ASC Allocation Framework. It consolidates all decisions, code analysis, data mappings, and implementation details from the research phase into one actionable document.

**Use this when:**
- Starting implementation (what to build, where to inject, what tables to create)
- Onboarding a team member (full context in one place)
- Reviewing a PR (verify the implementation matches the design)
- Debugging in production (trace data flow from source to Freee)

---

## 2. Project Context

### What Was Cancelled

**ASCH (ASC Honki Set)** — cancelled 2026-08-07. Was going to prorate Honki Set bundled payments across 3 products (Lesson, Coaching, App). The architecture research and engineering standards from ASCH are reused in this framework.

### What We're Building

**ASC Allocation Framework** — a shared system that splits Coaching charge revenue between Coaching and App products for Freee journal accuracy. Two projects use the same codebase:

| Project | What it allocates | Plan IDs | When upstream goes live |
|---|---|---|---|
| **ASC-CAP** | CAP (Coaching and App Plan) bundles | 1016–1027 | Late Nov / early Dec 2026 |
| **ASC-CIP** | CIP (Coaching Intensive Plan) bundles | 1028–1032 | Late Nov / early Dec 2026 |

### Terminology

| Term | Meaning |
|---|---|
| **CAP** | Coaching and App Plan — upstream project (MBTI_backend) creating new plans |
| **CIP** | Coaching Intensive Plan — upstream project adding App to existing coaching plans |
| **ASC-CAP / ASC-CIP** | Our accounting projects that allocate revenue |
| **N** | The amount existing ASC already calculated (daily rate proration of paid_price) |
| **P** | The correctly allocated amount after splitting between Coaching and App |
| **L** | Reference price (standalone selling price used as allocation weight) |

---

## 3. The Business Problem

When a student purchases a CAP or CIP plan, they pay a single amount that covers both Coaching and App. For example:

```
Student buys plan 1018 (L25 + Coaching 15 + App):
  trn_charge for Coaching (product 10005): paid_price = ¥22,550 (includes App fee)
  trn_charge for App (product 10022):      paid_price = ¥0      (companion — App id now 10022, was 10021)
```

Existing ASC calculates daily rate for the Coaching charge and books the full ¥22,550 as Coaching revenue. But accounting standards require the revenue to be split:
- Coaching revenue: ¥22,550 minus App's share
- App revenue: App's proportional share (currently ¥0 → should be ¥1,540+)

**The allocation framework corrects this by splitting the Coaching N value into P_coaching + P_app before Freee journals are sent.**

---

## 4. The Formula

### Allocation Calculation

```
Given:
  N         = Σ(paid_price) across the bundle (coaching row + app row)
              This is the GROUP TOTAL, not the coaching row alone.
              Makes the formula idempotent — ΣN is invariant across re-runs.
  L_app     = ¥3,980 (App standalone price, tax-inclusive)
  L_coaching = ¥19,800 (Coaching 15min) or ¥39,600 (Coaching 30min)
               or ¥88,000 (Coaching Intensive), tax-inclusive

Calculate:
  P_app      = floor(N × L_app / (L_coaching + L_app))
  P_coaching = N − P_app

Invariants:
  P_coaching + P_app = N  (always — remainder absorption guarantees this)
  Σ(adjustments) = 0     (Coaching decreases, App increases by same amount)

Idempotency proof (why ΣN works):
  1st run:  N = 22,550 + 0     = 22,550 → P_coaching=18,776, P_app=3,774
  2nd run:  N = 18,776 + 3,774 = 22,550 → P_coaching=18,776, P_app=3,774  ✅ same
```

### Worked Example (Plan 1018, Coaching 15min, Full Month)

```
N = ¥22,550 (Σ paid_price across the bundle: coaching ¥22,550 + app ¥0)
L_app = ¥3,980
L_coaching = ¥19,800

P_app      = floor(22,550 × 3,980 / (19,800 + 3,980))
           = floor(22,550 × 3,980 / 23,780)
           = floor(22,550 × 0.16737...)
           = floor(3,774.3...)
           = 3,774

P_coaching = 22,550 − 3,774
           = 18,776

Freee journals:
  Coaching: ¥18,776 (was ¥22,550 before allocation)
  App:      ¥3,774  (was ¥0 before allocation)
  Total:    ¥22,550 (unchanged)
```

### Partial Month Example (Mid-Month Start)

```
Contract: 2027/01/20–02/19. January portion only.
Daily rate for January: N = ceil(22,550 / 31 * 12) = 8,729

P_app      = floor(8,729 × 3,980 / 23,780) = 1,460
P_coaching = 8,729 − 1,460 = 7,269
```

The formula works identically regardless of month or proration — it just splits whatever N value exists.

---

## 5. Data Field Mapping

### Key Variables

| Symbol | Full Name | Source | Stored In | Description |
|---|---|---|---|---|
| **N** | Bundle group total | Σ(paid_price) of coaching + app rows | Computed at allocation time | The sum of all rows in the bundle for a given target_ym. Using the group total (not coaching row alone) makes allocation idempotent — N is invariant across re-runs. |
| **P_coaching** | Allocated coaching amount | Allocation engine | `log_daily_rate_calculation.paid_price` (overwritten) | N minus App's share. What Freee should book as Coaching revenue. |
| **P_app** | Allocated app amount | Allocation engine | `log_daily_rate_calculation.paid_price` (overwritten from 0) | App's proportional share. What Freee should book as App revenue. |
| **L_app** | App reference price | `mst_alloc_reference_prices` | Config / DB | ¥3,980 tax-inclusive. Standalone selling price of App. |
| **L_coaching** | Coaching reference price | `mst_alloc_reference_prices` | Config / DB | ¥19,800 (15min) or ¥39,600 (30min) tax-inclusive. |

### Data Flow: Source → Calculation → Output

```
SOURCE TABLES (read-only)
┌─────────────────────────────────────────────────────┐
│ trn_charge                                          │
│   • charge_id, student_id, product_id, plan_id     │
│   • paid_price (tax-inclusive)                      │
│   • start_date, end_date                           │
│   • contract_type, department_id, order_no         │
│                                                     │
│ trn_student_product                                 │
│   • charge_id → links charge to plan               │
│                                                     │
│ mst_plan_content                                    │
│   • plan_id → product_id (confirms bundle)         │
└─────────────────────────────────────────────────────┘
         │
         ▼ getTrnChargeList() fetches all paid active charges
         ▼ getContractDateInfoList() prorates by calendar days
         │
INTERMEDIATE (written then overwritten)
┌─────────────────────────────────────────────────────┐
│ log_daily_rate_calculation (or _pre)                │
│   • charge_id, student_id, product_id              │
│   • product_type, contract_type, department_id     │
│   • target_ym, paid_price                          │
│   • order_no, start_date, contract_day, total_day  │
│                                                     │
│   BEFORE allocation: paid_price = N (coaching=full, app=0)
│   AFTER allocation:  paid_price = P (coaching=reduced, app=allocated)
└─────────────────────────────────────────────────────┘
         │
         ▼ getPaidPriceSumList() aggregates (sees P, not N)
         │
AGGREGATION (feeds Freee + CSVs)
┌─────────────────────────────────────────────────────┐
│ log_sum_calculation (or _pre)                       │
│   • target_ym, department_id, order_no             │
│   • product_type, contract_type, partner_id        │
│   • paid_price (already P — allocated)             │
│   • ticket_flg, tax_free, country_id              │
└─────────────────────────────────────────────────────┘
         │
         ├──▶ sendFreeeJournals2() → Freee API (T1/T2/T3 journals)
         ├──▶ createDailyRateCalculationSumFile() → CalculationSummary CSV
         └──▶ createDailyRateCalculationFile() → DailyRateCalculation CSV

AUDIT TABLES (new — allocation detail)
┌─────────────────────────────────────────────────────┐
│ log_alloc_calculation_runs                          │
│   • run_id, project_code, target_ym, run_type     │
│   • status (creating/completed/failed)             │
│                                                     │
│ log_alloc_prorations                                │
│   • charge_id, product_id, reference_price (L)     │
│   • original_amount (N), allocated_amount (P)      │
│   • ratio                                           │
│                                                     │
│ log_alloc_source_documents                          │
│   • Immutable snapshot of N values before overwrite│
└─────────────────────────────────────────────────────┘
```

---

## 6. Reference Prices

### Confirmed Values

> **🔴 PRODUCT ID CHANGE (2026-08-19, approved by Go-san — FINAL):** Two product_ids changed upstream (Soli-san, CIP Slack). **All `10021`/`10022` references below and elsewhere in this doc reflect the OLD ids** and are being reconciled. The authoritative mapping is:
> - **CAP Bizmates App: `10021` → `10022`** (this is the detection anchor — was 10021, now 10022)
> - **CIP Coaching Intensive: `10022` → `10025`**
>
> ⚠️ Note the collision: `10022` now means **App** (CAP), but older text uses `10022` to mean **Coaching Intensive** (CIP). When reading any `10022` below, check context. See `research/CIP/REF-CIP-04-Product-Plan-IDs-And-Price-Matrix-20260824.md`.
>
> **🟡 PRICE PENDING (O-5 reopened):** CIP Solo (1028) is now ¥75,900 tax-incl (was ¥88,000), bundling Coaching Intensive + App. `L_coaching = ¥84,020` below is stale. Awaiting Kuroda-san/Accounting confirmation of the new L_coaching (likely ¥71,920 = 75,900 − 3,980, unconfirmed).

| Project | Product | product_id (NEW) | L (reference price, tax-incl) | Source |
|---|---|---|---|---|
| CAP | App Premium | **10022** (was 10021) | ¥3,980 | REF-CAP-05 · id change REF-CIP-04 |
| CAP | Coaching 15min | 10005 | ¥19,800 | mst_new_price_listing flag 3 × 1.1 |
| CAP | Coaching 30min | 10015 | ¥39,600 | mst_new_price_listing flag 3 × 1.1 |
| CIP | App Premium | **10022** (was 10021) | ¥3,980 | Same product as CAP |
| CIP | Coaching Intensive | **10025** (was 10022) | ⚠️ ¥84,020 STALE — pending O-5 re-confirm | Was `plan ¥88,000 − ¥3,980`; plan now ¥75,900. Awaiting Accounting. |

### How Reference Prices Are Stored

Stored in `mst_alloc_reference_prices` (effective-dated, so prices can change without code changes):

```php
// Seeder data
[
    // CAP  (App product_id = 10022, changed from 10021 on 2026-08-19)
    ['project_code' => 'cap', 'product_id' => 10022, 'reference_price' => 3980,
     'effective_from' => '2026-01-01', 'effective_to' => null],
    ['project_code' => 'cap', 'product_id' => 10005, 'reference_price' => 19800,
     'effective_from' => '2026-01-01', 'effective_to' => null],
    ['project_code' => 'cap', 'product_id' => 10015, 'reference_price' => 39600,
     'effective_from' => '2026-01-01', 'effective_to' => null],
    // CIP  (App = 10022; Coaching Intensive = 10025, both changed 2026-08-19)
    ['project_code' => 'cip', 'product_id' => 10022, 'reference_price' => 3980,
     'effective_from' => '2026-01-01', 'effective_to' => null],
    // ⚠️ CIP Coaching Intensive reference_price PENDING (O-5 reopened) — plan now ¥75,900, not ¥88,000.
    //    Value below (84020) is STALE. Likely ¥71,920 (= 75,900 − 3,980) but awaiting Accounting.
    ['project_code' => 'cip', 'product_id' => 10025, 'reference_price' => 84020, // 🔴 STALE — confirm via O-5
     'effective_from' => '2026-01-01', 'effective_to' => null],
]
```

---

## 7. Plan Detection

### CAP Plans (1016–1027) — New Plans, No Historical Data

| plan_id | Plan Name | Coaching Product |
|---|---|---|
| 1016 | Solo C15 + App | 10005 |
| 1017 | Solo C30 + App | 10015 |
| 1018 | L25 + C15 + App | 10005 |
| 1019 | L50 + C15 + App | 10005 |
| 1020 | L75 + C15 + App | 10005 |
| 1021 | L100 + C15 + App | 10005 |
| 1022 | L25 + C30 + App | 10015 |
| 1023 | L50 + C30 + App | 10015 |
| 1024 | L75 + C30 + App | 10015 |
| 1025 | L100 + C30 + App | 10015 |
| 1026 | L15/mo + C15 + App | 10005 |
| 1027 | L15/mo + C30 + App | 10015 |

**Detection:** `CoachingAndAppPlanEnum::exists($trnCharge->plan_id)` — no date filter needed (these plans are new).

### CIP Plans (1028–1032) — New Plans, No Historical Data

| plan_id | Plan Name | Coaching Product |
|---|---|---|
| 1028 | Coaching Intensive (Solo) | 10025 |
| 1029 | 1L + FVP + Coaching Intensive | 10025 |
| 1030 | 2L + FVP + Coaching Intensive | 10025 |
| 1031 | 3L + FVP + Coaching Intensive | 10025 |
| 1032 | 4L + FVP + Coaching Intensive | 10025 |

> **product_id 10025** (was 10022) per 2026-08-19 change. Plans 1029–1032 also bundle Online Lesson (1L–4L) + FVP — see O-8 (2-way vs 3-way split) in §15.

**Detection:** `CoachingIntensivePlanEnum::exists($trnCharge->plan_id)` — no date filter needed (these plans are brand new, same as CAP).

**Note (corrected 2026-08-13):** CIP is a brand new product (10022) with brand new plan_ids — NOT a modification of existing coaching plans (71, 94, 1005–1014). No date filter is required because these plan_ids have zero historical charges.

### How plan_id Is Available

Verified from `ls-database-migrations`:
- `trn_charge` has `plan_id` column (nullable bigint)
- `getTrnChargeList()` uses `SELECT trn_charge.*` — includes plan_id
- `log_daily_rate_calculation` does NOT have plan_id — detection must use `trn_charge` join

---

## 8. Injection Point and Failure Isolation

### The Single Injection Point

All changes inject into ONE existing function: `CommonUtil::createDailyRateCalculation()`.

```php
public static function createDailyRateCalculation(
    string $targetYm, string $targetStartDate, string $targetEndDate, bool $preFlg = false
): void
{
    // ═══════════════════════════════════════════════════════════════
    // Step [a]: EXISTING — Write N to log_daily_rate_calculation
    // ═══════════════════════════════════════════════════════════════
    $trnCharges = TrnCharge::getTrnChargeList($targetStartDate, $targetEndDate);

    foreach ($trnCharges as $trnCharge) {
        // Skip monthly plans (existing filter)
        if (BizmatesMonthlyPlanEnum::exists($trnCharge->product_id)) {
            continue;
        }

        $ContractDateLists = static::getContractDateInfoList(
            $trnCharge->start_date, $trnCharge->end_date,
            $trnCharge->paid_at, $trnCharge->paid_price, $trnCharge->product_id
        );

        foreach ($ContractDateLists as $key => $value) {
            $condition = [
                'student_id'    => $trnCharge->student_id,
                'charge_id'     => $trnCharge->id,
                'product_id'    => $trnCharge->product_id,
                'product_type'  => $productIdTypeMap[$trnCharge->product_id],
                'target_ym'     => $key,
                'paid_price'    => $value["paidPrice"],  // ← This is N
                // ... other fields ...
            ];

            if ($preFlg) {
                LogDailyRateCalculationPre::create($condition);
            } else {
                LogDailyRateCalculation::create($condition);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Step [b]: ★ NEW — ASC Allocation (Overwrite N → P) ★
    // ═══════════════════════════════════════════════════════════════
    try {
        app(RevenueAllocationService::class)->allocate($targetYm, $preFlg);
    } catch (\Throwable $e) {
        Log::error('[ASC_ALLOC] Allocation failed: ' . $e->getMessage());
        Log::error($e->getTraceAsString());
        // Fallback: log table still has N — today's behavior, nothing lost
    }

    // ═══════════════════════════════════════════════════════════════
    // Step [c]: EXISTING — Build sum from log (now reads P)
    // ═══════════════════════════════════════════════════════════════
    if ($preFlg) {
        $sumLists = LogDailyRateCalculationPre::getPaidPriceSumList($targetYm);
    } else {
        $sumLists = LogDailyRateCalculation::getPaidPriceSumList($targetYm);
    }

    foreach ($sumLists as $sumList) {
        // ... existing sum logic (unchanged) ...
        // Now reads P_coaching and P_app instead of N and 0
    }
}
```

### Why This Works

1. **Step [a]** writes ALL charges including CAP/CIP normally (coaching gets N, app gets 0)
2. **Step [b]** queries the log table, identifies CAP/CIP pairs, computes P, UPDATEs in place
3. **Step [c]** reads from the log table — now sees P values — builds sum correctly
4. **Everything downstream** (Freee, CSVs, balance) inherits P automatically

### What Commands Call This Function

| Command | Logic Class | Injection Point | Result |
|---|---|---|---|
| `DailyRateCalculationPreCommand` | `DailyRateCalculationPreLogic` | `CommonUtil::createDailyRateCalculation()` | Writes `_pre` tables, sends preliminary email |
| `SendJournalsDataCommand` | `SendJournalsDataLogic` | `CommonUtil::createDailyRateCalculation()` | Writes final tables, sends Freee journals + final email |
| `DataCorrectionCommand` | `DataCorrectionLogic` | Private `createDailyRateCalculation()` at line 346 | Creates new log rows from correction CSV |

**Two injection points cover all three commands:**
1. `CommonUtil::createDailyRateCalculation()` — covers Pre + Final
2. `DataCorrectionLogic::createDailyRateCalculation()` — covers "addDaily" correction

Note: DataCorrectionLogic also has `correctDailyRateCalculation()` ("daily" operation) which reads from `log_daily_rate_calculation` directly — this is SAFE (data already allocated by the normal batch run). Only the "addDaily" path needs allocation because it reads from `trn_charge` (raw N).

### DataCorrectionLogic — Second Injection Point

```php
// DataCorrectionLogic.php line ~346 — private createDailyRateCalculation()
// This method reads from trn_charge and writes raw N to the log table.
// It does NOT call CommonUtil::createDailyRateCalculation().

private function createDailyRateCalculation($data)
{
    // ... existing: fetch from trn_charge, prorate, INSERT to log ...

    foreach ($ContractDateLists as $key => $value) {
        LogDailyRateCalculation::create($condition);  // writes N
    }

    // ═══════════════════════════════════════════════════════════════
    // ★ NEW — Same allocation call as CommonUtil ★
    // ═══════════════════════════════════════════════════════════════
    try {
        $targetYm = CommonUtil::getTargetYm();
        app(RevenueAllocationService::class)->allocate($targetYm, preFlg: false);
    } catch (\Throwable $e) {
        Log::error('[ASC_ALLOC] Allocation failed in DataCorrection: ' . $e->getMessage());
    }
}
```

**Why this is needed:** DataCorrectionLogic has its own private copy of the daily rate creation logic (not a call to CommonUtil). It reads `trn_charge.paid_price` directly and writes unallocated N to the log. Without the allocation call, correction-added charges would bypass allocation entirely.

**Confirmed drift (identified by Kuroda-san, 2026-08-12):** This private method lacks the `BizmatesMonthlyPlanEnum::exists()` skip that CommonUtil has (added during ASCM project). It also lacks `tax_free`, `country_id`, and `gross_amount` in the `$condition` array. These are bugs from the ASCM era — the correction batch was never updated when the monthly plan logic was introduced. Fixed in ASCM Prep phase (see below).

**Resolution — Two phases:**

**Phase 1 (ASCM Prep):** Fix the drift in DataCorrectionLogic to align with what ASCM should have delivered:
- Add `BizmatesMonthlyPlanEnum::exists()` skip (fix latent bug — monthly plans shouldn't be written to daily log via correction)
- Add missing `$condition` fields: `tax_free`, `country_id`, `gross_amount` (schema drift — CommonUtil has these, DataCorrection doesn't)
- Unit test the correction batch with these fixes
- Effort: 0.5–1 day

**Phase 2 (ASC-CAP):** Add allocation call to DataCorrectionLogic:
- Add `RevenueAllocationService::allocateForCharge($chargeId, $targetYm)` method to the service (targeted single-charge allocation, not full-month rebuild)
- Call it from DataCorrectionLogic after the INSERT loop
- Effort: included in allocation service design (~5 lines at call site)

**Why NOT refactor DataCorrectionLogic to call CommonUtil (revised from earlier claim):**

The two functions have fundamentally different semantics:

| | CommonUtil | DataCorrectionLogic |
|---|---|---|
| Scope | ALL charges for a month | ONE specific charge |
| Sum rebuild | Yes (getPaidPriceSumList → log_sum_calculation) | No — additive only |
| Delete-then-rebuild | Yes (deleteTargetYMData wipes the month first) | No — incremental fix |
| Pre/Final | Supports both via preFlg | Always final |
| Zipan | Separate ZipanUtil function | Inline if/else branching |

The correction batch is designed for incremental fixes to a completed month. Calling the full CommonUtil pipeline would wipe and rebuild the entire month — which is not the intent of a correction. The previous devs separated them for this reason.

**Implementation in DataCorrectionLogic (Phase 2):**

```php
// After the INSERT loop (~line 430):
foreach ($ContractDateLists as $key => $value) {
    LogDailyRateCalculation::create($condition);  // writes N
}

// ★ Phase 2 (ASC-CAP): Allocate this specific charge ★
try {
    $targetYm = array_key_first($ContractDateLists);  // target_ym from the first period
    app(RevenueAllocationService::class)->allocateForCharge($trnCharge->id, $targetYm);
} catch (\Throwable $e) {
    Log::error('[ASC_ALLOC] Allocation failed in DataCorrection: ' . $e->getMessage());
}
```

The `allocateForCharge()` method detects if this charge is part of a CAP/CIP bundle (by App product_id 10022 — was 10021), finds its coaching pair in the log, computes P, and updates — same logic as the full `allocate()` but scoped to one charge.

### Failure Isolation

```
CommonUtil::createDailyRateCalculation()
│
├── Step [a]: Write N to log table             ← ALWAYS succeeds (existing code)
│
├── Step [b]: try { allocate() } catch {       ← If fails:
│       Log error                                  - log table still has N
│       Mark run as failed                         - system behaves as today
│       Continue to step [c]                       - no revenue lost
│   }                                              - visible in log_alloc_calculation_runs
│
└── Step [c]: Build sum from log table         ← Works with N or P (either way valid)
```

**Guarantee:** If allocation fails, the batch produces exactly what it produces today — unallocated figures. The accounting team sees "allocation failed" in the run table and knows to investigate. No manual intervention needed to keep the batch running.

---

## 9. The Allocation Service — Internal Design

### RevenueAllocationService::allocate()

```php
class RevenueAllocationService
{
    public function allocate(string $targetYm, bool $preFlg): void
    {
        Log::info('[ASC_ALLOC] Allocation started', ['target_ym' => $targetYm, 'pre' => $preFlg]);

        $table = $preFlg ? 'log_daily_rate_calculation_pre' : 'log_daily_rate_calculation';
        $runType = $preFlg ? RunType::Preview : RunType::Final;

        // 1. Create run record (persists even if calculation fails)
        $run = $this->runLifecycle->createRun($targetYm, $runType);

        try {
            // 2. Detect CAP/CIP bundles in the log table
            $bundles = $this->detectBundles($table, $targetYm);

            if ($bundles->isEmpty()) {
                $this->runLifecycle->finalizeRun($run->id, recordCount: 0);
                Log::info('[ASC_ALLOC] No bundles found, skipping');
                return;
            }

            // 3. Snapshot original N values (audit trail)
            $this->snapshotSourceData($run->id, $bundles, $table);

            // 4. Compute allocation for each bundle
            $allocations = $this->computeAllocations($bundles);

            // 5. UPDATE log_daily_rate_calculation with P values
            $this->overwriteLogTable($table, $allocations);

            // 6. Write log_alloc_* / mst_alloc_* tables (detailed audit)
            $this->persistAllocationDetail($run->id, $allocations);

            // 7. Finalize run
            $this->runLifecycle->finalizeRun($run->id, recordCount: $allocations->count());

            Log::info('[ASC_ALLOC] Allocation completed', ['records' => $allocations->count()]);
        } catch (\Throwable $e) {
            $this->runLifecycle->markFailed($run->id, $e->getMessage());
            throw $e;  // re-thrown to outer try/catch in CommonUtil
        }
    }
}
```

### Bundle Detection Logic

```php
private function detectBundles(string $table, string $targetYm): Collection
{
    // Find coaching AND app charges that belong to CAP/CIP plans
    // Anchor detection on the App product_id — now 10022 (was 10021 before the 2026-08-19 change)
    // CIP Coaching Intensive is now 10025 (was 10022)
    return DB::table($table . ' as log')
        ->join('trn_charge as c', 'log.charge_id', '=', 'c.id')
        ->where('log.target_ym', $targetYm)
        ->where(function ($q) {
            $q->whereIn('c.plan_id', CoachingAndAppPlanEnum::toArray())    // CAP plans
              ->orWhere(function ($q2) {                         // CIP plans
                  $q2->whereIn('c.plan_id', CoachingIntensivePlanEnum::toArray());
              });
        })
        ->whereIn('c.product_id', [10005, 10015, 10025, 10022])  // 10005/10015 = CAP coaching, 10025 = CIP coaching intensive, 10022 = App (all NEW ids per 2026-08-19)
        ->select('log.id', 'log.charge_id', 'log.paid_price', 'c.product_id',
                 'c.plan_id', 'c.student_id', 'c.order_no', 'log.target_ym')
        ->get()
        ->groupBy(fn ($row) => $row->student_id . '|' . ($row->order_no ?? 'null'));
        // Group by student_id + order_no to isolate each contract
        // Handles: cancel+repurchase, CAP+CIP simultaneous, multiple billing cycles
}
```

**Grouping key: `student_id + order_no`** (not student_id alone)

A student can have multiple active contracts in the same month:
- Cancel and repurchase (two order_nos for same student)
- CAP and CIP simultaneously (different plans, different order_nos)
- B2B with multiple orders

Each `order_no` represents one billing unit. Charges sharing the same `order_no` belong to the same bundle. This matches the DB design (validation V-1 is ΣP = ΣN at bundle level, keyed on order_no).

**Open considerations (from Kuroda-san, 2026-08-17):**

| # | Item | Status | Impact |
|---|---|---|---|
| O-7 | Product ids changed (2026-08-19, FINAL): App 10021→10022, CIP coaching 10022→10025 | ✅ Confirmed by Go-san | Detection `whereIn` = [10005, 10015, 10025, 10022]. Freee mapping must use new App id 10022. |
| — | Plan 1028 (Solo CIP) includes App (10022) per seeder | ✅ Verified in REF-CIP-03 §9 | $appRow will not be null for Solo plans |
| — | CIP L_coaching is a dependent value (plan_price − L_app) | Noted | Must recalculate if plan_price changes |

### Compute Allocations — Uses ΣN (Group Total)

```php
private function computeAllocations(Collection $bundles): Collection
{
    // Each $bundle is a group of rows sharing (student_id, order_no)
    return $bundles->map(function ($bundleRows) {
        $coachingRow = $bundleRows->firstWhere('product_id', '!=', 10022);  // App is now 10022 (was 10021)
        $appRow = $bundleRows->firstWhere('product_id', 10022);              // App = 10022 (new id)

        if (!$coachingRow || !$appRow) {
            Log::warning('[ASC_ALLOC] Incomplete bundle — skipping', [
                'student_id' => $bundleRows->first()->student_id,
                'order_no' => $bundleRows->first()->order_no,
            ]);
            return null;
        }

        // N = GROUP TOTAL (coaching + app), NOT coaching row alone
        // This makes allocation idempotent — ΣN is invariant across re-runs
        $n = $coachingRow->paid_price + $appRow->paid_price;

        $lApp = $this->getReferencePrice($appRow->product_id, 'cip_or_cap');
        $lCoaching = $this->getReferencePrice($coachingRow->product_id, 'cip_or_cap');

        $pApp = (int) floor($n * $lApp / ($lCoaching + $lApp));
        $pCoaching = $n - $pApp;

        return new AllocationResult(
            coachingLogId: $coachingRow->id,
            appLogId: $appRow->id,
            pCoaching: $pCoaching,
            pApp: $pApp,
            originalN: $n,
        );
    })->filter();  // Remove nulls from incomplete bundles
}
```

### Overwrite Logic

```php
private function overwriteLogTable(string $table, Collection $allocations): void
{
    foreach ($allocations as $alloc) {
        // Update coaching row: current value → P_coaching
        DB::table($table)
            ->where('id', $alloc->coachingLogId)
            ->update(['paid_price' => $alloc->pCoaching]);

        // Update app row: current value → P_app
        DB::table($table)
            ->where('id', $alloc->appLogId)
            ->update(['paid_price' => $alloc->pApp]);
    }
}
```

### Idempotency Design (from Kuroda-san, 2026-08-14)

**Problem:** If N = coaching row alone, a second run would read the already-reduced coaching value and shrink revenue further on every pass.

**Solution:** N = Σ(paid_price) across the bundle (coaching + app). This is invariant:
- 1st run: N = 22,550 + 0 = 22,550 → P_coaching=18,776, P_app=3,774
- 2nd run: N = 18,776 + 3,774 = 22,550 → P_coaching=18,776, P_app=3,774 ✅

No guard needed. This aligns with DB design validation rule V-1 (ΣP = ΣN at bundle level).

### Snapshot Handling on Re-Runs

`snapshotSourceData()` (step 3) must **skip** when a proration row already exists for that (charge_id, target_ym). Otherwise it records allocated values as the "original N" — corrupting the audit trail even though the numbers stay correct.

```php
private function snapshotSourceData(int $runId, Collection $bundles, string $table): void
{
    foreach ($bundles->flatten() as $row) {
        // Skip if already snapshotted (prevents audit corruption on re-run)
        $exists = LogAllocSourceDocument::where('charge_id', $row->charge_id)
            ->where('target_ym', $row->target_ym)
            ->exists();

        if (!$exists) {
            LogAllocSourceDocument::create([
                'run_id' => $runId,
                'charge_id' => $row->charge_id,
                'target_ym' => $row->target_ym,
                'original_paid_price' => $row->paid_price,
                // ...
            ]);
        }
    }
}
```

### DataCorrectionLogic — Scoped Allocation

For `addDaily`, allocate ONLY the charge being added, not the entire target_ym:

```php
// After INSERT in DataCorrectionLogic::createDailyRateCalculation()
try {
    app(RevenueAllocationService::class)->allocateForCharge($trnCharge->id, $targetYm);
} catch (\Throwable $e) {
    Log::error('[ASC_ALLOC] Allocation failed in DataCorrection: ' . $e->getMessage());
}
```

`allocateForCharge()` detects only the specific bundle containing this charge_id, computes ΣN for that bundle, and overwrites. Other bundles in the same month are untouched.

---

## 10. Downstream Impact Assessment

### What Happens to ¥0 App Charges

#### Current Behavior (Before Allocation)

```
trn_charge (product_id=10022, paid_price=0, plan_id=1018)   // App — id now 10022 (was 10021)
    │
    ▼ getTrnChargeList() — fetches it (no price filter)
    ▼ getContractDateInfoList(paid_price=0) — prorates 0 → produces 0
    ▼ LogDailyRateCalculation::create(paid_price=0) — row created with ¥0
    ▼ getPaidPriceSumList() — creates sum row with paid_price=0
    ▼ LogSumCalculation::create(paid_price=0)
    ▼ sendFreeeJournals2() — if (paid_price != 0) → SKIPPED
```

**Result:** App row exists in all log tables but is invisible to Freee (¥0 is skipped).

#### After Allocation (Option 1 Overwrite)

```
Step [a]: LogDailyRateCalculation::create(paid_price=0)  ← same as today
Step [b]: UPDATE paid_price = 3,774 WHERE charge_id = {app_charge}  ← NEW
Step [c]: getPaidPriceSumList() → sum row with paid_price=3,774
          LogSumCalculation::create(paid_price=3,774)
          sendFreeeJournals2() → if (3,774 != 0) → JOURNAL CREATED ✅
```

**Result:** App revenue automatically flows to Freee. No new code in the Freee sending path.

#### Key Verifications

| Check | Result |
|---|---|
| Does getTrnChargeList() filter by price? | ❌ No — fetches all paid+active charges |
| Does getContractDateInfoList() skip ¥0? | ❌ No — prorates normally (ceil(0/days*days) = 0) |
| Is App product_type (100) in NotDailyCalculationProductType? | ❌ No — only type 8 (Bizmates Test) is excluded |
| Does sendFreeeJournals2 have a price gate? | ✅ Yes — `if ($sumList->paid_price != 0)` skips ¥0 rows |
| Does PayPal reconciliation read log tables? | ✅ Yes — `uriage1–6` subqueries read `log_daily_rate_calculation`. But totals balance because App row absorbs the shift. |

### CSV Report

#### Current State: Allocation Breakdown Required (O-6 Resolved 2026-08-17)

Kuroda-san confirmed with Accounting:
1. **Existing CSVs (DailyRateCalc, CalculationSummary) will show allocated amounts** — OK, no format change needed
2. **Accounting needs a breakdown showing HOW allocation was calculated** — new requirement
3. **Format is flexible** — Metabase view OR additional CSV (our choice)

**Decision:** Provide both:
- **CSV in the existing zip:** AllocationDetail CSV with breakdown — included in monthly email for archival (~30 lines of code)
- **Metabase:** A saved query on `log_alloc_prorations` joined with charge details — created post-deployment for ad-hoc checks between batch runs

Since `log_alloc_prorations` already stores: original N, allocated P, reference prices L, ratio, project_code, charge_id, product_id — both outputs read from the same source table.

#### What Needs to Be Added (if CSV is required)

##### 1. Config entry in `config/const.php`

```php
// ASC配分計算結果ファイル (Allocation Detail)
'allocationDetailFile' => [
    'fileName' => '{YYYYMM}_10_AllocationDetail({execDate}).csv',
    'name' => 'ASC配分計算結果ファイル',
    'headerItem' => [
        'コンテンツ',         // Service name (Bizmates)
        '対象年月',           // target_ym
        'プロジェクト',       // project_code (cap/cip)
        '生徒ID',            // student_id
        '部署ID',            // department_id
        '発注番号',          // order_no
        'プランID',          // plan_id
        'プロダクトID',      // product_id (coaching or app)
        'プロダクトタイプ',  // product_type
        '契約種類',          // contract_type
        '参照価格',          // reference_price (L)
        '配分比率',          // ratio
        '元金額(N)',         // original_amount (before allocation)
        '配分後金額(P)',     // allocated_amount (after allocation)
        'ステータス',        // run status
    ],
],
```

##### 2. New function to generate the CSV

Following the existing pattern (`createMonthlyRateCalculationFile`), create a new function:

```php
// In a new service class (or CommonUtil if following existing pattern)
public static function createAllocationDetailFile(string $targetYm, bool $preFlg = false): array
{
    [$fileName, $name, $headerTitle] = CommonUtil::getCsvFileInfo('allocationDetailFile');

    // Read from log_alloc_prorations for the target month
    $rows = LogAllocProration::getForTargetYm($targetYm, $preFlg);

    $detailDataLists = [];
    foreach ($rows as $row) {
        $detailDataLists[] = [
            ServiceNameEnum::Bizmates->value,
            $row->target_ym,
            $row->project_code,
            $row->student_id,
            $row->department_id,
            $row->order_no,
            $row->plan_id,
            $row->product_id,
            $row->product_type,
            $row->contract_type,
            $row->reference_price,
            $row->ratio,
            $row->original_amount,
            $row->allocated_amount,
            $row->status,
        ];
    }

    CommonUtil::createCsvFile($fileName, $headerTitle, $detailDataLists);
    return [$fileName, $name];
}
```

##### 3. Add to createSendMailAttacheFile() in SendJournalsDataLogic

```php
// In createSendMailAttacheFile(), after existing CSVs:

// ASC Allocation Detail CSV (only if allocation ran successfully)
if (LogAllocCalculationRun::hasCompletedRun($targetYm)) {
    [$fileName, $name] = RevenueAllocationCsvService::createAllocationDetailFile($targetYm, false);
    $fileNameList[$fileName] = $name;
}
```

Same for `DailyRateCalculationPreLogic::createSendMailAttacheFile()` with `$preFlg = true`.

#### Important: Under Option 1, Existing CSVs Already Show Allocated Amounts

With Option 1 (Overwrite), the EXISTING CSVs automatically contain allocated figures:
- `03_DailyRateCalculation` — shows P values (coaching reduced, app has value)
- `04_CalculationSummary` — shows allocated sums

**Confirmed by Accounting (via Kuroda-san, 2026-08-17):** This is acceptable. The dedicated allocation CSV provides the RATIO, ORIGINAL N, and reference prices for audit — the "why" behind the numbers in the existing CSVs.

### Freee Journal Sending

#### Does It Need Changes Under Option 1?

**No.** Here's why:

The journal building flow reads from `log_sum_calculation`:

```php
$sumLists = LogSumCalculation::getLogSumCalculationForTargetYm($targetYm);

foreach ($sumLists as $sumList) {
    // 1. Get freee product type from product_type
    $freeeProductType = MstCodeChange::getChangeCodeToFreeeCode(
        config('code.masterDataType.productType'),
        $sumList->product_type  // ← product_type 100 for App
    );

    // 2. Get contract type info (segment2_id)
    [$freeeContractType, $contractTypeName] = CommonUtil::getContractTypeInfo(
        $freeeProductType,
        $sumList->department_id,
        $sumList->contract_type
    );

    // 3. Get journal rules
    $mstRuleForJournals = MstRuleForJournals::getMstRuleForJournals(
        $freeeContractType,
        $freeeProductType
    );

    // 4. Skip if paid_price = 0
    if ($sumList->paid_price != 0) {
        // Build journal entry...
    }
}
```

**Under Option 1:**
- App sum row now has `paid_price = P_app` (e.g., 3,774) instead of 0
- It passes the `!= 0` check → journal is built
- `product_type = 100` flows through `MstCodeChange` to get `freeeProductType`
- `freeeProductType` flows through `getContractTypeInfo()` to get segment mapping
- `MstRuleForJournals` resolves the journal rules

#### Potential Issue: Does product_type 100 Have Freee Mappings?

The flow requires:
1. `mst_code_change` row: `master_data_type = 1` (productType), `code = 100` → `freee_code = ?`
2. `mst_rule_for_journals` row: `segment2_id = ?`, `product_type = {freee_code}` → journal rules

**From project context (REF-ASCH-06 §5):** Kuroda-san confirmed that `mst_rule_for_journals` has 4 rows for code=100 (App). This was confirmed for the original ASCH design and applies here.

**What we need to verify before go-live:**
- Does `mst_code_change` have a row mapping `code=100` → `freee_code` for `master_data_type=1`?
- Do the 4 `mst_rule_for_journals` rows exist for all contract type variants (B2C, B2B, B2E, Partner)?

If these rows exist → **zero code changes needed in sendFreeeJournals2()**.
If they don't exist → **seeder needed in ls-database-migrations** (data change, not code change).

#### getContractTypeInfo() — How App Routes

```php
// Product type 100 (App) → freeeProductType via mst_code_change
$freeeProductType = MstCodeChange::getChangeCodeToFreeeCode(1, 100);

// freeeProductType is checked against known types:
if (in_array($freeeProductType, config('code.freeeZipanCodes'))) {
    // Zipan → won't match (App is Bizmates only)
} elseif ($freeeProductType == config('code.freeeProductType.bizmatesCoaching')) {
    // Coaching → won't match (App is not coaching)
} else {
    // Falls to "Bizmates" path (masterDataType = contractTypeBizmates)
    $masterDataType = config('code.masterDataType.contractTypeBizmates');
}
```

**App will route through the Bizmates contract type path** (same as Online Lesson products). This means it uses segment2_id values like `B_B2C (261926)`, `B_B2B (261928)`, etc. — which is correct for a Bizmates product.

**Alternatively**, if Kuroda-san defined App-specific segment2_id values (like `C_B2C (261934)` for Coaching), the App's freee_code might need to be registered separately. This depends on what the 4 mst_rule_for_journals rows use.

#### Conclusion for sendFreeeJournals2

| Question | Answer |
|---|---|
| Code changes needed? | **No** — the function reads from log_sum_calculation which already has P values |
| Will App journals be created? | **Yes** — once paid_price > 0 (from overwrite), the `!= 0` check passes |
| Will correct Freee dimensions be used? | **Likely yes** — IF mst_code_change + mst_rule_for_journals rows exist for product_type 100 |
| What to verify before go-live? | Query mst_code_change and mst_rule_for_journals for code=100 / product_type 100 |

### Balance Transition

#### Does It Need Changes Under Option 1?

**No.** Here's why:

`createBalanceTransition()` calculates:
```
月末残高 = 月初残高 − 入金金額 + 当月売上
```

Where:
- **月初残高** (opening balance): from previous month's `log_balance_transition`
- **入金金額** (deposit): from `trn_charge` (unaffected by allocation)
- **当月売上** (monthly sales): from `LogSendJournalsHistory` (debit - credit amounts from sent journals)

The sales amount is read from **`log_send_journals_history`** — which is written AFTER journals are sent to Freee. Under Option 1, the journals sent to Freee already have the allocated amounts (P_coaching, P_app). So `log_send_journals_history` will contain the correct allocated figures.

#### What Changes Naturally

Before allocation:
```
Balance for Coaching partner: sales = ¥22,550 (full N)
Balance for App partner: ¥0 (no journals sent for App)
```

After allocation (Option 1):
```
Balance for Coaching partner: sales = ¥18,776 (P_coaching)
Balance for App partner: sales = ¥3,774 (P_app)
```

The **total across both** remains ¥22,550 — just split between two partner/product_type entries.

#### Potential Consideration

The balance transition groups by `partner_id + partner_name`. If the App journal uses the same partner_id as Coaching (which it will — same student, same payment method), the balance entries would be merged. This is actually correct behavior — the balance transition tracks cash flow per partner, and the total cash from the student hasn't changed.

**Conclusion:** No code changes needed. Balance transitions inherit the allocated amounts naturally through `log_send_journals_history`.

### Balance Transition With Order Number

#### Does It Need Changes?

**No.** Same reasoning as above. It reads from:
- `LogSendJournalsHistory::getAmountForUriagedakaWithOrderNumber()` — which will have allocated amounts
- `TrnCharge::getTrnChargeForNyukin()` — reads from trn_charge (unaffected)
- `LogFreeeInvoices` — invoice amounts (unaffected)

The order_no-level breakdown will show:
- Coaching product journals at P_coaching
- App product journals at P_app (if App has its own order_no, which it likely shares with coaching)

**No code changes needed.**

---

## 11. New Code Structure

> **⚠️ Table-prefix update (2026-08-17):** This section was written 2026-08-13, before the table-prefix ADR was approved. The ADR (`ASCA-ADR-20260817-table-prefix-decision.md`) renamed the tables:
> - `asc_alloc_*` → **`log_alloc_*`** (batch-generated tables)
> - `asc_alloc_reference_prices` → **`mst_alloc_reference_prices`** (master data)
> - `v_asc_alloc_prorations_active` → **`v_alloc_prorations_active`** (view)
>
> The **migration filenames and table names below have been updated** to match the ADR. The **PHP namespace was renamed** from the earlier `AscAlloc` to **`RevenueAllocation`** (2026-09-01) — a descriptive domain name, consistent with the ADR's principle that structure should reflect what the code IS (revenue allocation), not which project built it (ASC). **Model class names follow the existing table→model convention** (`log_alloc_*` → `LogAlloc*`, `mst_alloc_*` → `MstAlloc*`), so a model name predictably maps to its table. Feature grouping comes from the `RevenueAllocation` namespace/folder, not from the class-name prefix.

```
accounting_related_system_for_freee/
├── app/
│   ├── Enums/RevenueAllocation/
│   │   ├── CoachingAndAppPlanEnum.php   # CAP plan_ids 1016–1027
│   │   ├── CoachingIntensivePlanEnum.php # CIP plan_ids 1028–1032
│   │   ├── ProjectCode.php          # 'cap', 'cip'
│   │   ├── RunType.php              # Preview, Final
│   │   └── RunStatus.php            # Creating, Completed, Failed
│   │
│   ├── Libs/RevenueAllocation/
│   │   └── RevenueAllocationService.php # Main orchestrator (allocate method)
│   │
│   ├── Models/RevenueAllocation/    # models named after their table (LogAlloc* / MstAlloc*)
│   │   ├── LogAllocCalculationRun.php      → log_alloc_calculation_runs
│   │   ├── LogAllocSourceDocument.php      → log_alloc_source_documents
│   │   ├── LogAllocBundle.php              → log_alloc_bundles
│   │   ├── LogAllocBundleCharge.php        → log_alloc_bundle_charges
│   │   ├── LogAllocGroup.php               → log_alloc_groups
│   │   ├── LogAllocProration.php           → log_alloc_prorations
│   │   ├── MstAllocReferencePrice.php      → mst_alloc_reference_prices
│   │   ├── LogAllocSumCalculation.php      → log_alloc_sum_calculation
│   │   ├── LogAllocSumCalculationHistory.php → log_alloc_sum_calculation_history
│   │   └── LogAllocDelivery.php            → log_alloc_deliveries
│   │
│   └── Traits/
│       └── HasEnumHelperTrait.php   # Already exists — reused by new enums
│
├── config/
│   └── revenue_allocation.php       # NEW: allocation config (launch dates, feature flags)
│
└── tests/Unit/RevenueAllocation/
    ├── RevenueAllocationServiceTest.php
    ├── CoachingAndAppPlanEnumTest.php
    └── AllocationFormulaTest.php

ls-database-migrations/
├── database/migrations/          # table names per ADR (log_alloc_* / mst_alloc_* / v_alloc_*)
│   ├── YYYY_MM_DD_create_log_alloc_calculation_runs_table.php
│   ├── YYYY_MM_DD_create_log_alloc_source_documents_table.php
│   ├── YYYY_MM_DD_create_log_alloc_bundles_table.php
│   ├── YYYY_MM_DD_create_log_alloc_bundle_charges_table.php
│   ├── YYYY_MM_DD_create_log_alloc_groups_table.php
│   ├── YYYY_MM_DD_create_log_alloc_prorations_table.php
│   ├── YYYY_MM_DD_create_mst_alloc_reference_prices_table.php   # mst_ — master data
│   ├── YYYY_MM_DD_create_log_alloc_sum_calculation_table.php
│   ├── YYYY_MM_DD_create_log_alloc_sum_calculation_history_table.php
│   ├── YYYY_MM_DD_create_log_alloc_deliveries_table.php
│   └── YYYY_MM_DD_create_v_alloc_prorations_active_view.php
│
└── database/seeders/
    └── Bizmates/AscAllocReferencePriceSeeder.php   # seeds mst_alloc_reference_prices
```

---

## 12. Existing Files Changed

| File | Change | Lines Added | Risk |
|---|---|---|---|
| `app/Libs/CommonUtil.php` | Add `RevenueAllocationService::allocate()` call between step [a] and [c] | ~8 | LOW — additive, wrapped in try/catch |
| `app/Libs/DataCorrectionLogic.php` | ASCM Prep: add monthly plan skip + missing fields (fix drift). ASC-CAP: add `allocateForCharge()` call after "addDaily" INSERT | ~20 | LOW-MED — tested via correction batch smoke test |
| `config/const.php` | Add CSV header definitions for AllocationDetail | ~20 | ZERO — config only |
| `config/revenue_allocation.php` | New config file for allocation settings (launch dates, feature flags) | ~30 | ZERO — new file |

**Everything else is new code** — no modifications to existing logic.

### Files NOT Changed

| File | Why Not |
|---|---|
| `DailyRateCalculationPreLogic.php` | Unchanged — calls CommonUtil. |
| `SendJournalsDataLogic.php` | Sum already has P → journals are correct. No 2nd API call. |
| `ZipanUtil.php` | CAP/CIP is Bizmates-only. Zipan path untouched. |
| `sendFreeeJournals2()` | `paid_price != 0` check naturally includes P_app (was 0, now has value). |
| `createSendMailAttacheFile()` | Reads from log_sum_calculation which already has allocated amounts. |

---

## 13. Summary: What Needs Changes vs What Doesn't

### NEEDS CODE CHANGES

| Item | What | Effort |
|---|---|---|
| `CommonUtil::createDailyRateCalculation()` | Add allocation service call between [a] and [c] | ~8 lines |
| `DataCorrectionLogic::createDailyRateCalculation()` | ASCM Prep: fix drift (add skip + missing fields). ASC-CAP: add `allocateForCharge()` call | ~20 lines |
| `RevenueAllocationService` (NEW) | Main orchestrator — detect, compute, overwrite, persist | 1 new class |
| `CoachingAndAppPlanEnum` / `CoachingIntensivePlanEnum` (NEW) | Plan ID enums for detection | 2 new files |
| `LogAlloc*` / `MstAlloc*` models (NEW) | Eloquent models for audit tables (in `App\Models\RevenueAllocation\`) | 8–10 new files |
| `config/revenue_allocation.php` (NEW) | Config for launch dates, feature flags | 1 new file |
| `config/const.php` | CSV header definition for AllocationDetail | ~20 lines |
| `createSendMailAttacheFile()` | Add AllocationDetail CSV to file list | ~5 lines |
| Migrations (ls-database-migrations) | 10 tables + 1 view | 11 files |
| Seeder | Reference prices + mst_rule_for_journals (if missing) | 1–2 files |

### DOES NOT NEED CHANGES (Verified)

| Item | Why |
|---|---|
| `sendFreeeJournals2()` | Reads log_sum_calculation which already has P. App passes `!= 0` check. |
| `createBalanceTransition()` | Reads log_send_journals_history which has allocated journal amounts. |
| `createBalanceTransitionWithOrderNumber()` | Same — inherits from journal history. |
| `SendJournalsDataLogic::execute()` | Unchanged — CommonUtil handles allocation internally. |
| `DailyRateCalculationPreLogic::execute()` | Unchanged — calls CommonUtil. |
| `DataCorrectionLogic` | Unchanged — calls CommonUtil. |
| `ZipanUtil` (anything) | CAP/CIP is Bizmates-only. |
| `sendJournalDataToFreee()` | Just sends whatever $detailList contains. |
| `splitDetailListWithBalance()` | Balances are maintained (Coaching decrease = App increase). |
| `createDailyRateCalculationFile()` | Reads log table which already has P. Shows allocated amounts. |
| `createDailyRateCalculationSumFile()` | Reads log_sum_calculation which has P. Shows allocated sums. |
| `createPaypalPaymentFile/Sum` | Uses `selectRaw` subqueries on `log_daily_rate_calculation` (uriage1–6). Totals balance because App row absorbs the shifted amount. No code change needed. |

### TO VERIFY BEFORE GO-LIVE (Data, Not Code)

| Item | What to check | How |
|---|---|---|
| `mst_code_change` for product_type 100 | Row exists mapping code=100 → freee_code | Query DB |
| `mst_rule_for_journals` for App | 4 rows exist (B2C, B2B, B2E, Partner segments) | Query DB |
| App freee_code routing | Does it route to Bizmates or Coaching segment? | Check getContractTypeInfo flow |

---

## 14. Decisions Log

| # | Decision | Option Chosen | Alternative | Rationale |
|---|---|---|---|---|
| 1 | Architecture | Scenario D (injection) | Scenario C (standalone commands) | Saves ~3 weeks. Proven pattern (monthly rate). Same email/zip. |
| 2 | Timing | Option 1 (overwrite N→P) | Option 2 (send adjustment journals) | 1 API call. Zero downstream changes. Simpler. |
| 3 | Injection point | `CommonUtil::createDailyRateCalculation()` | SendJournalsDataLogic | Covers all 3 batches (Pre, Final, Correction) with one change. |
| 4 | Detection | plan_id enum | product_id check | product_id 10005/10015 is shared with non-CAP plans. plan_id is unique. |
| 5 | CIP guard | ~~Date filter~~ → Not needed (new plan_ids) | Date filter (historical charges) | CIP has brand new plan_ids (1028–1032) with zero history. Same detection as CAP. |
| 6 | Rounding | floor() on App, remainder to Coaching | Round both | Guarantees P_coaching + P_app = N exactly. No ¥1 gaps. |
| 7 | N preservation | log_alloc_source_documents | Keep N in log table | Option 1 overwrites log. Source_documents provides audit trail. |
| 8 | Tenant scope | Bizmates only | Both tenants | Coaching/App don't exist on Zipan. ZipanUtil untouched. |
| 9 | Pre/Final | Single service with preFlg parameter | Separate classes | Avoids duplication (KB #14 lesson). |
| 10 | CAP first | CAP builds foundation, CIP reuses | CIP first | CAP requirements more concrete. Same total effort either way. |
| 11 | Bundle grouping key | student_id + order_no | student_id alone | Handles cancel+repurchase, simultaneous CAP+CIP, B2B multi-order. One order_no = one billing unit. (Kuroda-san, 2026-08-17) |
| 12 | CIP L_coaching | ¥84,020 (plan − L_app) | ¥88,000 (plan price directly) | CIP has no standalone coaching price. Coaching = residual. ΣL = plan price. Full month → App gets exactly ¥3,980. (Kuroda-san + Accounting, 2026-08-17) |

---

## 15. Open Items

> **Note on table & code names:** Older code examples in this document may still show `asc_alloc_*` (the original DB design from Kuroda-san). The authoritative naming is:
> - **Tables:** `log_alloc_*` (batch-generated) / `mst_alloc_*` (reference prices) / `v_alloc_*` (view) — per O-3 ADR (2026-08-17). See `ASCA-ADR-20260817-table-prefix-decision.md`.
> - **PHP namespace:** `RevenueAllocation` (renamed from `AscAlloc` on 2026-09-01) — `App\Models\RevenueAllocation\`, `App\Libs\RevenueAllocation\`, `App\Enums\RevenueAllocation\`, `config/revenue_allocation.php`.
> - **Model class names:** follow the table→model convention — `log_alloc_*` → `LogAlloc*`, `mst_alloc_*` → `MstAlloc*` (e.g., `LogAllocProration`, `MstAllocReferencePrice`).
> - **Service:** `RevenueAllocationService`.

| # | Item | Owner | Status | Blocks |
|---|---|---|---|---|
| O-3 | Table prefix | Engineering team | ✅ **Resolved (2026-08-17)** — `log_alloc_*` for batch-generated, `mst_alloc_*` for reference prices. Approved by Kuroda-san. | — |
| O-5 | CIP coaching reference price | Business + Accounting | 🔴 **REOPENED (2026-08-28)** — was ¥84,020 (from plan ¥88,000). Plan is now ¥75,900 (REF-CIP-04). New L_coaching likely ¥71,920 (= 75,900 − 3,980) but UNCONFIRMED. Awaiting Kuroda-san/Accounting. | ASCI reference price seeder |
| O-7 | Product ID changes (2026-08-19) | Business (Go-san, done) | ✅ **Confirmed FINAL** — CAP App `10021→10022`, CIP Coaching Intensive `10022→10025`. Detection whereIn + reference-price product_id + Freee mapping must use new ids. | Detection + seeder + Freee mapping |
| O-8 | CIP split arity (2-way vs 3-way) | Accounting (Kuroda-san) | ✅ **Resolved (2026-08-28)** — **2-way (Coaching + App only)**, even for plans 1029–1032. Online Lesson handled separately by existing daily-rate logic. Same split as CAP → ASCI stays a config addition. [Kuroda-san Slack](https://bizmatesinc.slack.com/archives/C0BF8ABV74N/p1788340743121289?thread_ts=1788340577.655519&cid=C0BF8ABV74N) | — |
| ~~P-3~~ | ~~CAP new coaching product_id~~ | — | ✅ Superseded by O-7 — the actual change was the App id (10021→10022), not the CAP coaching id. CAP coaching stays 10005/10015. | — |
| O-6 | Allocation detail CSV needed? | Accounting (Nemoto-san) | ✅ **Resolved (2026-08-17):** Existing CSVs show allocated amounts (confirmed OK). Accounting needs a breakdown of how allocation was calculated. Deliverables: AllocationDetail CSV in zip (~30 lines code) + Metabase saved query (post-deployment). | — |
| — | ~~CIP launch date~~ | ~~CIP upstream team~~ | ✅ No longer needed — CIP has new plan_ids (1028–1032), no historical data | — |
| — | Option 1 vs 2 final confirmation | Kuroda-san | ✅ **Confirmed** — Option 1 (Overwrite) agreed. | — |
| — | Scenario C vs D final decision | Patrick-san / Kuroda-san | ✅ **Confirmed** — Scenario D (injection) agreed. | — |

---

## 16. Reference Documents

| Document | Location | What it covers |
|---|---|---|
| **Master timeline** | **`docs/asc-projects-master-timeline.md`** | **Authoritative timeline — Gantt, calendar mapping, team assignments, QA schedule** |
| Scenario D proposal (historical) | `projects/asca/documentation/asc-alloc-scenario-d-injection-timeline-20260811.md` | Original proposal — rationale, Scenario C vs D comparison, lead dev assessment |
| Table prefix ADR | `projects/asca/documentation/ASCA-ADR-20260817-table-prefix-decision.md` | O-3 decision: `log_alloc_*` / `mst_alloc_*` prefix |
| Discussion notes | `projects/asch/documentation/asc-alloc-integration-discussion-notes-20260811.md` | Decisions, scope assessment, refactoring discussion |
| Process flow diagram | `projects/asch/documentation/diagrams/asc-alloc-injection-process-flow.md` | Visual flow diagrams |
| Kuroda-san DB design | `projects/asch/technical-notes/research/CAP/REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md` | 10 tables + 1 view |
| Upstream pricing (Slack) | `projects/asch/technical-notes/research/CAP/REF-CAP-05-Upstream-Pricing-Discussion-20260812.md` | Confirmed prices, formula, product_ids |
| Upstream pricing (Confluence) | `projects/asch/technical-notes/research/CAP/REF-CAP-06-Upstream-Price-Mechanism-Draft-20260812.md` | CAP plan_ids, two-price model, approach comparison |
| Overwrite proposal | `projects/asch/technical-notes/research/CAP/REF-CAP-07-Overwrite-Process-Flow-20260812.md` | Option 1 design + verified code analysis |
| CIP campaigns reference | `projects/asch/technical-notes/research/CIP/REF-CIP-02-Coaching-Campaigns-Reference-20260812.md` | CIP plan_ids, campaign tiers |
| ASCM knowledge base | `projects/ascm/knowledge-base/00-index.md` | Lessons learned (what NOT to repeat) |
| Engineering standards | `projects/asch/documentation/asch-engineering-standards.md` | Patterns, naming, coding standards |
