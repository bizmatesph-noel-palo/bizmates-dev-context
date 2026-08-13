# ASC Allocation — Overwrite Process Flow (Option 1)

**Source:** Kuroda-san (Confluence)  
**Date:** 2026-08-12  
**Filed by:** Noel Palo  
**Assisted by:** Kiro  
**Status:** Proposal from Kuroda-san — questions directed to our team (Section 11)

---

## Prior Discussion (Slack thread, 2026-08-10 to 2026-08-12)

Before the Confluence document was released, Kuroda-san, Patrick-san and Noel discussed the approach in chat. Key points from that discussion that **led to** the Confluence doc:

### Evolution of the Approach

1. **Kuroda-san (08-10):** Identified that THREE batches produce CSVs (Pre, Final, DataCorrection), not just SendJournalsDataLogic. All three call the same `CommonUtil` functions. Exclusion must cover all three.

2. **Noel (08-10):** Agreed. Pointed to `CommonUtil::createDailyRateCalculation()` as the right injection point. Noted Zipan doesn't need changes (CAP/CIP is Bizmates-only).

3. **Kuroda-san (08-12):** Realized that excluding at `createDailyRateCalculation()` also removes CAP/CIP from Freee journals (since `log_sum_calculation` feeds journals). This means we can send **allocated amounts as actual values** instead of adjustment journals — which became **Option 1 (Overwrite)**. Dropped `adjustment_amount` column and one validation rule from the design.

### Critical Insight (from Kuroda-san, 08-12)

> "Since excluding there also removes CAP/CIP from the Freee journals, we send the allocated amounts as actual values (replacement) instead of sending difference journals to correct them afterwards."

This is the genesis of Option 1. The Confluence doc formalizes this insight.

### Open Questions from Chat (Not in Confluence Doc)

| # | Question | From | Status |
|---|---|---|---|
| K-1 | Three batches affected (Pre, Final, DataCorrection) — all call same function | Kuroda-san | ✅ Confirmed — single injection point covers all |
| K-2 | Can exclusion go in CommonUtil::create*File() or in the log query? | Kuroda-san | ✅ Answered: goes in `createDailyRateCalculation()` before log write |
| K-3 | ZipanUtil::addZipanData() — does exclusion need duplication? | Kuroda-san | ✅ Not needed — Zipan never has CAP/CIP plans |
| N-1 | Filtering logic "might need to be different" — different how? | Kuroda-san asking Noel | ✅ **Answered** — use `plan_id` enum, not `product_id`. See Lead Dev Assessment. |
| N-2 | addZipanData() "needs further investigation" | Kuroda-san asking Noel | ✅ **Answered** — no change needed. Zipan is separate path, no CAP/CIP overlap. |
| N-3 | Should allocation call `getContractDateInfoList()` directly or decouple? | Kuroda-san asking Noel | ✅ **Answered** — reuse directly for Dec 17. Decouple later if needed. |
| P-1 | Is CAP/CIP identification deterministic across Pre/Final? (mid-month changes?) | Patrick-san | ✅ Yes — plan_id is immutable on the charge |
| P-2 | Does Accounting need a raw log footprint for excluded charges? | Patrick-san | ⚠️ **OPEN** — `asc_alloc_source_documents` may suffice, but needs Accounting confirmation |
| P-3 | Can CAP/CIP share plan codes with non-CAP products? | Patrick-san | ✅ No — CAP plans (1016–1027) are unique |

### Patrick-san's Recommendations (08-12)

1. Use a centralized check (e.g., `CoachingAndAppPlanEnum::exists()` / `CoachingIntensivePlanEnum::exists()`) — mirroring `BizmatesMonthlyPlanEnum::exists()` pattern at line 401.
2. Reuse `CommonUtil::getContractDateInfoList()` directly for the allocation N calculation — safest for 12/17 deadline, eliminates calculation drift risk. Decouple later.
3. Quick query check to confirm Zipan has no CAP/CIP plan overlap (low risk).

---

### What the Confluence Doc Adds Beyond the Chat

The Confluence document (below) formalizes Option 1 with:
- Complete process flow diagrams
- Data examples with actual numbers
- Side-by-side comparison (Option 1 vs Option 2)
- Naming clarification (architecture axis vs timing axis)
- Explicit questions for us to answer

**Where the Confluence doc differs from chat discussion:**

| Topic | Chat (08-10/08-12) | Confluence Doc |
|---|---|---|
| Mechanism | "Exclude from log_daily_rate_calculation" | "Write N then UPDATE to P" |
| Phrasing | "Exclusion" | "Overwrite" |

These are the same thing expressed differently:
- Chat said "exclude CAP/CIP from the existing log rows" (don't write N for CAP/CIP)
- Confluence says "write N first, then overwrite with P"

**The Confluence doc is authoritative.** It proposes writing N first (step [a]), then updating to P (step [b]). This is better than pure exclusion because:
- The ¥0 App row needs to become P_app (not just excluded)
- The Coaching row needs its N reduced to P_coaching (not excluded entirely)
- `asc_alloc_source_documents` preserves the original N for audit

We follow the Confluence doc's "write then overwrite" approach, not the chat's "exclude" phrasing.

---

## Summary

Kuroda-san proposes **Option 1 (Overwrite)** as an alternative allocation timing within Scenario D (injection). Instead of sending a 2nd Freee API call with adjustment journals, the allocation **overwrites** the N values in `log_daily_rate_calculation` before `log_sum_calculation` is built — so everything downstream (Freee journals, CSVs, balance transitions) is already correct on the first pass.

**Key difference from our original proposal (Option 2 / Adjust):**

| | Option 1 (Overwrite) | Option 2 (Adjust) |
|---|---|---|
| When allocation runs | INSIDE `createDailyRateCalculation()`, between writing N and building sum | AFTER daily calc completes, before Freee send |
| What happens to log_daily_rate_calculation | N is **overwritten with P** | N stays as-is |
| Freee API calls | 1 (already correct) | 2 (original + adjustment) |
| Existing CSVs | Amounts already allocated | Amounts unallocated |
| New CSVs needed | Only if Accounting asks for basis detail | Required (adjustment detail) |
| adjustment_amount column | Not needed | Needed |
| Raw N preserved in | `asc_alloc_source_documents` | `log_daily_rate_calculation` (untouched) |

---

## The Idea

```
Option 2 (our original — Adjust):
  write N → ... → send journals → send a 2nd set of journals to correct them

Option 1 (Kuroda-san's — Overwrite):
  write N → split into P → ... → send journals (already correct)
                ▲
                └── one new step, everything downstream inherits it
```

---

## Where the New Step Goes

```
CommonUtil::createDailyRateCalculation(preFlg)
│
├─ [a] EXISTING — loop over trn_charge
│        └→ writes log_daily_rate_calculation  (N per charge per month)
│
├─ [b] ★ NEW — AscAllocationService::allocate() ★
│        ├→ detects CAP/CIP bundles (product_id = 10021 + plan_id)
│        ├→ writes asc_alloc_* tables (bundles / prorations / source_documents)
│        └→ UPDATES log_daily_rate_calculation rows with P
│
└─ [c] EXISTING — getPaidPriceSumList()
         └→ writes log_sum_calculation + history  ← already sees P, not N
```

Because `log_sum_calculation` is built in step [c], everything downstream is correct
with no further changes: CSVs, Freee journals, balance transitions, PayPal reconciliation.

---

## Data Example

CIP contract, 2027/01/20–02/19, ¥88,000 tax-incl. January portion.
Reference prices: Coaching ¥84,020 / App ¥3,980 (tax-incl).

```
                  BEFORE (N)      OPTION 1 (Overwrite → P)

log_daily_rate_calculation:
  Coaching charge    34,065    →     32,525
  App charge (10021)      0    →      1,540
                    ───────          ───────
  total              34,065           34,065    ← unchanged
```

The App row already exists today (¥0). No rows are added or removed — only the amount changes.

---

## Final Command Flow (Option 1)

```
SendJournalsDataCommand
│
▼
SendJournalsDataLogic::execute()
│
├─── [1] Freee access token refresh
│
├─── [2] Daily Rate Calculation
│         CommonUtil::createDailyRateCalculation(preFlg=false)
│         → writes: log_daily_rate_calculation (N)
│         → ★ NEW: allocation runs here ★
│         → UPDATES: log_daily_rate_calculation (N → P)
│         → writes: asc_alloc_* tables
│         → writes: log_sum_calculation + history  (already allocated)
│
├─── [3] Zipan Daily Rate Calculation (unchanged — CAP/CIP is Bizmates only)
│
├─── [4] COMMIT checkpoint
│
├─── [5] Freee Journal Sending — EXISTING, unchanged
│         sendFreeeJournals2()
│         → reads: log_sum_calculation  (already allocated)
│         → sends: Freee API call #1
│         → writes: log_send_journals_history
│
│         ✗ NO 2nd API call needed
│
├─── [6] COMMIT checkpoint
│
├─── [7] Balance Transition (unchanged — inherits allocated figures)
│
├─── [8] Generate CSV Files
│         ├── existing 12+ CSVs — format unchanged, amounts now allocated
│         └── AllocationDetail + AllocationSummary — only if Accounting needs the basis
│
├─── [9] Create ZIP archive
│
└─── [10] Send Email (single email, unchanged)
```

---

## Pre Command Flow (Option 1)

```
DailyRateCalculationPreLogic::execute()
│
├─── CommonUtil::createDailyRateCalculation(preFlg=true)
│    → writes: log_daily_rate_calculation_pre (N)
│    → ★ NEW: allocation (preview run) ★
│    → UPDATES: log_daily_rate_calculation_pre (N → P)
│    → writes: log_sum_calculation_pre
│
└─── CSVs → ZIP → preliminary email
```

One code change covers the preliminary batch, the final batch, and DataCorrectionLogic —
all three call the same function.

---

## Freee Journals — Before vs After

```
BEFORE                 OPTION 2 (Adjust)           OPTION 1 (Overwrite)

API call #1            API call #1                 API call #1
  Coaching  34,065       Coaching  34,065            Coaching  32,525
  App            0       App            0            App        1,540

                       API call #2
                         Coaching  −1,540
                         App       +1,540
```

Option 1 sends one set of journals that is correct on the first write.

---

## Injection Points (Changes to Existing Files)

| File | Change | Size |
|---|---|---|
| `CommonUtil::createDailyRateCalculation()` | Call `AscAllocationService::allocate()` between [a] and [c] | ~10 lines |
| `ZipanUtil` | none | — |
| `SendJournalsDataLogic` | none | — |
| `DailyRateCalculationPreLogic` | none | — |
| `DataCorrectionLogic` | none | — |

New code lives in `AscAllocationService` and the `asc_alloc_*` tables, exactly as in Scenario D.

**Even fewer changes than Option 2.** Option 2 touched both Logic files + CommonUtil. Option 1 touches only CommonUtil.

---

## Failure Isolation

```php
try {
    AscAllocationService::allocate(...)
} catch {
    log error
    asc_alloc_calculation_runs → failed
    leave log_daily_rate_calculation as N  ← today's behaviour, nothing lost
}
```

If allocation fails, the batch produces exactly what it produces today: unallocated figures.
No revenue is lost, no journal is wrong — the split simply did not happen,
and it is visible in `asc_alloc_calculation_runs`.

---

## Option 1 vs Option 2 Comparison

| Dimension | Option 1 (Overwrite) | Option 2 (Adjust) |
|---|---|---|
| Freee API calls | 1 | 2 |
| Window where Freee ≠ our DB | none | between call #1 and call #2 |
| Existing CSVs | amounts allocated | amounts unallocated |
| Balance transition reports | allocated | depends on how adjustments are recorded |
| Freee item mapping for App | automatic (existing product_type mapping) | must be built for the adjustment journal |
| adjustment_amount column | not needed | needed |
| New CSVs | only if Accounting asks for the basis | required |
| Raw N kept in log_daily_rate_calculation | no — kept in asc_alloc_source_documents | yes |
| Rollback | re-run the batch | base data untouched |

Both are safe on revenue loss and on PayPal reconciliation.

---

## Naming Clarification

Two separate naming axes are in use. They are orthogonal and combinable:

| Axis | Options |
|---|---|
| **Execution architecture** (Noel's naming) | Scenario C = standalone commands / Scenario D = injection |
| **Allocation timing** (this document) | Option 1 = Overwrite / Option 2 = Adjust |

| Document | Architecture | Timing |
|---|---|---|
| Noel, timeline 2026-08-11 | Scenario D | Option 2 |
| Noel, process flow 2026-08-12 | Scenario D | Option 2 |
| Patrick-san, Strategic Execution Proposal | Scenario D (Conful) | Option 2 |
| **This document (Kuroda-san)** | **Scenario D** | **Option 1** |

Everything agreed so far is **Scenario D** (injection), and that is not in question.
The only open point is the **timing** (Option 1 vs Option 2).

---

## Questions Directed to Us (Section 11)

| # | Question | My Initial Assessment |
|---|---|---|
| 1 | Any objection to Option 1 on the flow above? | Need to evaluate — see below |
| 2 | Does Option 1 move the 5.5–6.5 week estimate? | Likely reduces it slightly (removes 2nd API call, adjustment column, one validation rule, possibly both new CSVs; adds a fallback path) |
| 3 | Confirm the ¥0 App charge (product_id = 10021) appears in `getB2CPaypalPayment()` | Need to verify in code — `Order::buy()` calls `charge() + pay()`, but must confirm PayPal reconciliation stays balanced |
| 4 | Does Accounting need the allocation basis in a monthly CSV? | Waiting on Nemoto-san's answer — decides CSV count |

---

## Lead Dev Assessment (Verified via Code Review)

**Option 1 is confirmed viable and preferred.** Code verification completed 2026-08-12.

### Verification: What Happens to a ¥0 App Charge Today

Traced the full path from `trn_charge` through to Freee sending:

```
trn_charge (product_id=10021, paid_price=0)
    │
    ▼ getTrnChargeList() — NO price filter, fetches ALL active paid charges
    │
    ▼ getContractDateInfoList(paid_price=0)
    │   → Not negative (skips refund path)
    │   → product_type=100 NOT in NotDailyCalculationProductType (only type 8 excluded)
    │   → Enters daily proration loop: ceil(0 / days * days) = 0
    │
    ▼ LogDailyRateCalculation::create(paid_price=0)
    │   → ✅ ROW IS CREATED with paid_price = 0
    │
    ▼ getPaidPriceSumList()
    │   → Groups by (target_ym, dept, order_no, product_type, contract_type)
    │   → App (product_type=100) creates its own sum row with paid_price = 0
    │
    ▼ LogSumCalculation::create(paid_price=0)
    │   → ✅ SUM ROW IS CREATED with paid_price = 0
    │
    ▼ sendFreeeJournals2()
        → if ($sumList->paid_price != 0) { ... }
        → ❌ SKIPPED — no Freee journal for ¥0 rows
```

**Key finding: The ¥0 App row ALREADY EXISTS in `log_daily_rate_calculation` today.** It is created, flows through to `log_sum_calculation`, and is silently skipped at Freee sending time.

### How Option 1 (Overwrite) Works With This

```
Step [a]: EXISTING — creates rows:
  Coaching charge → log_daily_rate_calculation (paid_price = 34,065)  ← N
  App charge      → log_daily_rate_calculation (paid_price = 0)       ← ¥0

Step [b]: ★ NEW — AscAllocationService::allocate() ★
  UPDATE log_daily_rate_calculation SET paid_price = 32,525 WHERE charge_id = {coaching}
  UPDATE log_daily_rate_calculation SET paid_price = 1,540  WHERE charge_id = {app}

Step [c]: EXISTING — getPaidPriceSumList() now reads:
  Coaching → sum row with paid_price = 32,525  (P_coaching)
  App      → sum row with paid_price = 1,540   (P_app)

Downstream: sendFreeeJournals2()
  Coaching: paid_price = 32,525 → passes != 0 check → journal created ✅
  App:      paid_price = 1,540  → passes != 0 check → journal created ✅
  (Previously App was 0 and was skipped — now it has a real amount)
```

**No rows added or removed. Only the amount changes. Everything downstream inherits it automatically.**

### Verified: PayPal Reconciliation Is Unaffected (Corrected per Kuroda-san)

**Original assessment was partially wrong.** Kuroda-san pointed out that `getB2CPaypalPayment()` does NOT only read `trn_charge.paid_price`. It also injects `selectRaw` subqueries (`uriage1`–`uriage6`) that read from `log_daily_rate_calculation`:

```php
// In createPaypalPaymentFile() — builds selectItem subqueries:
$selectItem[] = '(select case when 1={$isFuture} then 0 else 
    coalesce((select sum(paid_price) from log_daily_rate_calculation 
        where target_ym = {$ym} and charge_id = trn_charge.id), 0) 
    + coalesce((select sum(paid_price) from log_monthly_rate_calculation 
        where target_ym = {$ym} and charge_id = trn_charge.id), 0) 
    end) AS uriage{$i}';
```

These `uriage` columns ARE affected by the overwrite:
- **Before:** Coaching uriage = N (e.g., 22,550), App uriage = 0
- **After:** Coaching uriage = P_coaching (e.g., 18,776), App uriage = P_app (e.g., 3,774)

**Why the total still balances:**

The PayPal CSV shows per charge: `paid_price | sum(uriage) | diff = paid_price - sum(uriage)`

- Coaching charge: paid_price=22,550, uriage=18,776, diff=3,774
- App charge: paid_price=0, uriage=3,774, diff=-3,774
- **Student total: paid_price=22,550, uriage=22,550, diff=0** ✅

The ¥0 App charge stays in the result set (it passes the query filters: `paid=1`, `status=1`, `contract_type IN (0,2)`). Its uriage absorbs the amount moved from coaching. The per-student total is unchanged.

**Conclusion (corrected):** PayPal reconciliation stays balanced, but the REASON is that the App row with paid_price=0 remains in the result set and its uriage subquery now returns P_app instead of 0. The coaching row's uriage decreases by the same amount. Net effect per student = zero.

### Verified: NotDailyCalculationProductType Does Not Exclude App

```php
// config/const.php
'NotDailyCalculationProductType' => [
    8,  // Bizmates Test only
],
```

App product_type = 100 is NOT in this list. The App charge goes through the normal daily proration loop.

### Verified: No Price Filter Anywhere in the Fetch Path

- `getTrnChargeList()`: filters on `paid=1`, `status=1`, `paid_at` range only. No `paid_price > 0` filter.
- `getContractDateInfoList()`: only short-circuits for negative prices (refunds). Zero goes through normally.
- `LogDailyRateCalculation::create()`: no validation on paid_price. Stores whatever is passed.

### Answers to Kuroda-san's Questions

| # | Question | Verified Answer |
|---|---|---|
| 1 | Any objection to Option 1? | **No objection.** Code confirms the ¥0 App row already exists in `log_daily_rate_calculation`. Overwriting it with P_app before the sum step is clean. All downstream code (sum, Freee, CSV, balance) inherits automatically. |
| 2 | Does Option 1 move the 5.5–6.5 week estimate? | **Reduces by ~2–3 days.** Removes: 2nd API call logic, `adjustment_amount` column, JournalEntryBuilder for adjustment journals, one validation rule (Σadj=0). Adds: UPDATE queries in allocation service (trivial). Net positive. |
| 3 | Confirm ¥0 App charge appears in PayPal reconciliation? | **Confirmed — balances correctly.** `getB2CPaypalPayment()` uses `selectRaw` subqueries (`uriage1–6`) that read from `log_daily_rate_calculation`. After overwrite: Coaching uriage decreases, App uriage increases by same amount. Per-student total unchanged. The ¥0 App charge stays in the result set (passes all filters) and absorbs the shifted revenue. |
| 4 | Allocation basis CSV needed? | Waiting on Nemoto-san. Regardless, `asc_alloc_prorations` stores N (original), P (allocated), reference prices, and ratio for full audit trail. |

### Additional Observations

1. **DataCorrectionLogic inherits for free.** It calls the same `createDailyRateCalculation()` function. If a correction triggers recalculation, allocation runs again automatically — correct behavior (idempotent).

2. **The `paid_price != 0` check in sendFreeeJournals2 is our friend.** Today it silently skips the ¥0 App row. After Option 1, the App row has a real amount and passes the check — a Freee journal is automatically created. No code change needed in the Freee sending path.

3. **Existing App Freee mapping should already exist.** Since the ¥0 App row flows into `log_sum_calculation` (even with amount=0), the `product_type=100` must already have a path through `MstCodeChange` and `MstRuleForJournals`. If it doesn't exist today, it will need to be seeded — but this is needed for both Option 1 and Option 2. (Kuroda-san already confirmed 4 rows exist in mst_rule_for_journals for code=100 in REF-ASCH-06.)

### Recommendation

**Adopt Option 1 (Overwrite).** It is:
- Simpler (1 injection point vs 3)
- Fewer new components (no JournalEntryBuilder for adjustments, no 2nd API call handler)
- More elegant (everything downstream is correct automatically)
- Lower risk (no window where Freee state differs from our DB)
- Verified working with actual code paths

---

## Answers to Kuroda-san's Open Questions (N-1, N-2, N-3)

### N-1: "Filtering might need to be different" — Clarification

**What I meant:** The existing `BizmatesMonthlyPlanEnum` filters by `product_id`. For CAP/CIP, we need to filter by `plan_id` instead — because the same `product_id` (10005, 10015) is used by both CAP plans AND non-CAP standalone coaching plans.

**Verified in code:**
- `trn_charge` has a `plan_id` column (nullable bigint) — confirmed from migration
- `getTrnChargeList()` uses `SELECT trn_charge.*` — so `$trnCharge->plan_id` is available in the loop
- CAP plan_ids (1016–1027) are unique — no overlap with non-CAP plans
- CIP plan_ids (71, 94, 1005–1014) exist historically — needs date filter

**Proposed implementation (mirrors existing pattern):**

```php
// New enum: app/Enums/AscAlloc/CoachingAndAppPlanEnum.php
enum CoachingAndAppPlanEnum: int
{
    use HasEnumHelperTrait;  // gives us exists() and toArray()

    case SOLO_C15_APP       = 1016;
    case SOLO_C30_APP       = 1017;
    case L25_C15_APP        = 1018;
    case L50_C15_APP        = 1019;
    case L75_C15_APP        = 1020;
    case L100_C15_APP       = 1021;
    case L25_C30_APP        = 1022;
    case L50_C30_APP        = 1023;
    case L75_C30_APP        = 1024;
    case L100_C30_APP       = 1025;
    case L15MO_C15_APP      = 1026;
    case L15MO_C30_APP      = 1027;
}

// Usage in AscAllocationService::allocate():
// After step [a] writes all charges, identify which ones need allocation:
$capChargeIds = collect($writtenRows)
    ->filter(fn ($row) => CoachingAndAppPlanEnum::exists($row->plan_id))
    ->pluck('charge_id');
```

**For CIP (later):**

```php
enum CoachingIntensivePlanEnum: int
{
    use HasEnumHelperTrait;

    case STANDALONE_C15  = 71;
    case STANDALONE_C30  = 94;
    case L25_C15         = 1005;
    case L50_C15         = 1006;
    // ... etc
}

// CIP also needs a date guard (historical charges must not be allocated):
$cipChargeIds = collect($writtenRows)
    ->filter(fn ($row) => CoachingIntensivePlanEnum::exists($row->plan_id)
        && $row->start_date >= config('asc_alloc.cip_launch_date'))
    ->pluck('charge_id');
```

**Why plan_id and not product_id:**
- `product_id = 10005` (Coaching 15min) appears in BOTH CAP plans AND non-CAP standalone plans
- Only `plan_id` distinguishes "this coaching charge is part of a CAP bundle" vs "this is standalone coaching"
- The ¥0 App charge (product_id = 10021) also appears in both CAP and CIP — `plan_id` tells us which project it belongs to

### N-2: "addZipanData() needs further investigation" — Resolved

**Verified: No change needed. No investigation needed.**

Reasoning (confirmed via code review):

1. `addZipanData()` reads from Zipan log tables (`log_daily_rate_calculation_zipan`, etc.) via `ZipanUtil::createDailyRateCalculationFile()`
2. Those Zipan log tables are populated ONLY by `ZipanUtil::createDailyRateCalculation()` — a completely separate function from `CommonUtil::createDailyRateCalculation()`
3. `ZipanUtil::createDailyRateCalculation()` reads from the `zipan` DB connection
4. The Zipan database does NOT contain CAP/CIP plans (product 10021 doesn't exist on Zipan, plans 1016–1027 don't exist on Zipan)
5. Even if it did, the allocation service only runs inside `CommonUtil` (Bizmates path) — the Zipan path is never touched

**Conclusion:** `addZipanData()` will never encounter CAP/CIP data because:
- It reads from a separate DB connection (zipan)
- It's populated by a separate function (ZipanUtil)
- CAP/CIP products don't exist in that database

No filter, no guard, no multi-tenancy refactor needed for Dec 17.

**Long-term (post-deadline):** A `TenantFeatureService` or multi-tenancy refactor is the correct architectural direction (per KB #13 lessons). But it's a 2–3 week effort with high regression risk on the 1060-line `ZipanUtil`. Not justified for a scope where Zipan is completely unaffected.

### N-3: "Should allocation call getContractDateInfoList() directly?"

**Answer: Yes, reuse it directly.**

Reasons:
1. `getContractDateInfoList()` is the authoritative daily proration formula (`ceil(paidPrice / totalDays * contractDays)`)
2. The allocation needs the SAME N value that was written to `log_daily_rate_calculation` — calling the same function guarantees no calculation drift
3. Patrick-san's recommendation aligns: "safest choice for the 12/17 deadline"
4. Decoupling later is trivial (extract interface, inject) — but premature now

**How it's used in Option 1:** The allocation service doesn't actually need to call `getContractDateInfoList()` separately. Under Option 1, step [a] already called it and wrote N to the log table. Step [b] reads N back from the log (or from the in-memory result of step [a]) and computes P. The formula source is already guaranteed identical because the same function produced N.

If we ever need to recalculate N independently (e.g., for the debug command), we call `getContractDateInfoList()` directly — same function, same result.

---

*Content was rephrased for compliance with licensing restrictions*  
*Source: Kuroda-san, Confluence, 2026-08-12*
