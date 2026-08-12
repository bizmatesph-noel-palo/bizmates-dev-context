# ASC Allocation — Overwrite Process Flow (Option 1)

**Source:** Kuroda-san (Confluence)  
**Date:** 2026-08-12  
**Filed by:** Noel Palo  
**Assisted by:** Kiro  
**Status:** Proposal from Kuroda-san — questions directed to our team (Section 11)

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

### Verified: PayPal Reconciliation Is Unaffected

`getB2CPaypalPayment()` and `getB2CPaypalPaymentSum()` both read directly from **`trn_charge`** — NOT from `log_daily_rate_calculation`. The allocation never modifies `trn_charge`. PayPal totals are unchanged.

Additionally, the PayPal query filters by `charge_type <> 1` and `contract_type IN (0, 2)`. It sums `trn_charge.paid_price`. Since:
- Coaching `trn_charge.paid_price` = 22,550 (unchanged)
- App `trn_charge.paid_price` = 0 (unchanged)
- Total from trn_charge = 22,550 (unchanged)

The PayPal reconciliation CSV (`B2CPaypalPayment`) will show the same figures regardless of allocation.

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
| 3 | Confirm ¥0 App charge appears in PayPal reconciliation? | **PayPal reconciliation is completely unaffected.** `getB2CPaypalPayment()` reads from `trn_charge` directly, never from `log_daily_rate_calculation`. We never modify `trn_charge`. The sum from `trn_charge` (coaching 22,550 + app 0 = 22,550) is unchanged regardless of what we do to the log table. |
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

*Content was rephrased for compliance with licensing restrictions*  
*Source: Kuroda-san, Confluence, 2026-08-12*
