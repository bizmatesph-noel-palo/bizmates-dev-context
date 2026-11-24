# REPORT-01 — ASCA-81: Independent validation of Cristoff-san's RCA (CAP refund produces no negative App row)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report (independent validation — cross-checked against live code) |
| **Date** | 2026-11-03 |
| **Author** | Noel Palo, Lead (Kiro-assisted, READ-ONLY cross-check) |
| **Validates** | REPORT-00 (initial capture of Cristoff-san's RCA on ASCA-81) |
| **Code repo** | `/home/bizdev/dev/accounting_related_system_for_freee` |
| **Checkout at time of validation** | branch `feature/ASCA/ASCA-master` (HEAD) — **NOT** `feature/ASCI/ASCI-10-spec-1-tasks` as the brief assumed |
| **Method** | Read the live source + specs + tests; used `git show`/`git grep` across all local refs; re-derived the arithmetic. No code, spec, or test was modified. |

---

## 1. Summary answer (read this first)

Cristoff-san's **diagnosis is correct**: the CAP refund path resolves the ¥0 App companion by matching BOTH `start_date` AND `end_date` against the original Coaching charge, and when the App companion's `end_date` differs (it runs to month-end while Coaching covers a sub-period) the match returns nothing and the refund's App portion is silently dropped. The silent-drop chain, the Spec-01 origin, the Req 9.1 contradiction, and the arithmetic for 471/7185 **all check out against the live code**.

**But two of his claims are REFUTED by the current checkout:**

1. **The fix is NOT applied anywhere in this repo.** The `end_date` predicate is still present in `fetchAppCompanion()` on **every** local branch tip — ASCA-master, the 02b coding branch (`ASCA-47`), and all ASCI branches including `ASCI-11`. There is no warning-log line in any ref, and `git log -S` finds no commit that ever introduced the claimed warning string. Cristoff-san's "fix applied + verified" does not correspond to anything committed/fetched locally. Either it lives only in his un-pushed working tree / an un-fetched PR, or it was not actually made.
2. **The claimed regression test does not exist, and the test count is wrong.** `RefundLinkageResolverTest` has **7** test methods, not 8, and **none** of them reproduces the 471 shape (Coaching `end_date` ≠ App `end_date`). Every seed in that file gives the App companion the *same* dates as the Coaching charge, so all 7 tests pass **with the bug still in place** — they give false confidence, not regression coverage.

**Highest-value extension — ASCI/CIP: CONFIRMED-REPEATS.** The CIP code on `origin/feature/ASCI/ASCI-11-cip-integration` reproduces the identical bug in `CipBundlePairing::findPair()` (`->where('start_date', …)->where('end_date', …)`). Worse, the ASCI **spec, design, and tasks explicitly prescribe** reusing the CAP date-matching rule with no awareness of ASCA-81, and a CIP unit test (`test_null_order_no_with_mismatched_dates_is_not_paired`) actively **codifies the buggy behavior as expected**.

**Bottom line:** the RCA's *mechanism* is sound and the fix he describes is the right fix — but it is not in the code yet, the "regression test added / 8-8 pass" claim is inaccurate, and ASCI-11 ships the same defect and must be fixed before it recognizes any CIP refund.

---

## 2. Claim-by-claim validation table

| # | Cristoff's claim | Verdict | Evidence (file / line / git) |
|---|---|---|---|
| 1 | **Defect site**: `RefundLinkageResolver::fetchAppCompanion()` matches on both `start_date` AND `end_date` | **CONFIRMED** | `app/Libs/RevenueAllocation/Refund/RefundLinkageResolver.php`, `fetchAppCompanion()` — `->where('start_date', $original->start_date)->where('end_date', $original->end_date)`. See quoted code in §3. |
| 2 | **Silent-drop chain**: `fetchAppCompanion()` null → `resolveOriginalBundle()` null → `RefundChargeDetector::detect()` `continue`s silently | **CONFIRMED** | `RefundLinkageResolver::resolveOriginalBundle()`: `$appCharge = $this->fetchAppCompanion($original); if ($appCharge === null) { return null; }`. `RefundChargeDetector::detect()`: `if ($original === null) { … continue; }` with comment "not in scope, silently ignored (Req 9.2)". No log, no outcome row on that path. |
| 3 | **Req 9.1 contradiction**: 02b mandates pairing via `log_refund_history` + stable key, not date matching | **CONFIRMED (with a precision note)** | `.kiro/specs/asca-spec-02b-refund-allocation/requirements.md` Req 9 AC 1 (line 157): "SHALL link a refund charge to its original bundle via `log_refund_history` … **not via date/`order_no` matching**." Precision: Req 9.1 governs the **refund→original** hop (which the code does correctly). The defect is in the **original→App-companion** hop, which Req 9.1 does not literally cover — but the "pair by stable key, never by date" *principle* is contradicted, and Cristoff's fix (resolve the companion on the stable key) is the correct reading. See §4. |
| 4 | **Spec-01 origin**: identical-dates assumption originates in Foundation Req 6.4/6.5 + design Property 3, implemented in `BundleDetectionService` grouping key | **CONFIRMED** | `asca-spec-01-foundation/requirements.md` Req 6.4 (line 154): pair by `start_date`/`end_date`; Req 6.5 (line 155) + round-3 A note (line 156): "assumes the coaching and app charges … always share identical `start_date` AND `end_date` … to verify on DEV04". `design.md` Property 3 (line 274–276). `BundleDetectionService::groupKey()` folds both `normalizeDate(start_date)` and `normalizeDate(end_date)` into the key. |
| 5 | **Fix applied**: `end_date` predicate dropped, companion resolved on stable key only | **REFUTED** | `end_date` predicate present on **all** refs. Per-branch `git grep` of `fetchAppCompanion()`: `ASCA-master`, `ASCA-47-spec-02b-coding`, `ASCI-10-spec-1-tasks`, `ASCI-11-cip-integration`, `ASCI-master` — each shows `end_date_pred = 1`. Not applied anywhere locally. |
| 6 | **Warning log added**: `[REVENUE_ALLOCATION] refund App companion not found for in-scope CAP original` | **REFUTED** | `git log --all -S "refund App companion not found"` → **0 commits**. `git grep "companion not found"` on every ref → **0 hits**. `RefundLinkageResolver.php` imports no `Log` facade. The line does not exist in the repo. |
| 7 | **Regression test exists** (471 shape: Coaching end ≠ App end); `RefundLinkageResolverTest` 8/8 pass | **REFUTED** | `tests/Unit/RevenueAllocation/RefundLinkageResolverTest.php` has **7** `test_` methods (not 8). `seedLinkedRefund()` always gives the App companion `origStart`/`origEnd` — the **same** dates as the Coaching charge. `test_resolution_follows_linkage_not_dates` varies only the *refund* charge's dates, never the *App companion's* `end_date`. No test uses 471/7185 or an App-end ≠ Coaching-end shape (`grep` for `471/7185/21175/42350/1934/3868` in `tests/` → 0 hits). All 7 pass *because* they never exercise the bug. |
| 8 | **Arithmetic** 471: N=−21,175 → P_app=−1,934, P_coaching=−19,241; 7185: N=−42,350 → P_app=−3,868, P_coaching=−38,482 (floor toward −∞) | **CONFIRMED** | Re-derived: 471 → −21,175×3,618/39,618 = −1,933.746 → floor **−1,934**; remainder **−19,241**; Σ=−21,175. 7185 → −42,350×3,618/39,618 = −3,867.492 → floor **−3,868**; remainder **−38,482**; Σ=−42,350. Matches `TwoWayAllocationFormula::computeBundleAllocation()` + `floorDiv()` (true floor toward −∞, integer math). |

---

## 3. Is the fix ACTUALLY in the current checkout? (the key ambiguity)

**No. The fix is not present in any local ref of this repo.**

The current `fetchAppCompanion()` on `feature/ASCA/ASCA-master` (HEAD), verbatim:

```php
private function fetchAppCompanion(object $original): ?object
{
    $query = DB::connection(self::CONNECTION)
        ->table(self::TABLE_CHARGE)
        ->where('student_id', $original->student_id)
        ->where('plan_id', $original->plan_id)
        ->where('product_id', TwoWayAllocationFormula::PRODUCT_ID_APP)
        ->where('start_date', $original->start_date)
        ->where('end_date', $original->end_date);          // ← the defect, STILL PRESENT

    if ($original->order_no === null) {
        $query->whereNull('order_no');
    } else {
        $query->where('order_no', $original->order_no);
    }

    return $query->orderBy('id')
        ->select('id', 'student_id', 'order_no', 'product_id', 'plan_id', 'start_date', 'end_date')
        ->first();
}
```

The `->where('end_date', $original->end_date)` line is exactly the predicate Cristoff identified as the defect, and it is unchanged. There is no `Log::warning(...)` call anywhere in the class (the file does not even import a `Log` facade).

Cross-ref evidence:
- `git log --oneline -- …/RefundLinkageResolver.php` shows only two commits, both on `feature/ASCA/ASCA-47-spec-02b-coding`: `4f1b33e5 [ASCA-47] CAP Refund Allocation` and `c6aa44e8 [ASCA-47] Rename OriginalBundleRef DTO to OriginalBundleData`. No fix commit.
- `git log --all -S "refund App companion not found"` returns nothing — the warning was never committed on any fetched ref.
- Per-branch `git grep` confirms the `end_date` predicate is present on every tip (ASCA-master, ASCA-47, ASCI-10-tasks, ASCI-11, ASCI-master).

**Interpretation (fair to Cristoff):** his RCA is coherent and his described fix is correct. The most likely explanation is that the fix is in his **local working tree or an un-pushed/un-fetched branch or PR** that this checkout has not received — the brief itself flagged this "fix applied per Cristoff vs. what's actually in this checkout" ambiguity. **What is certain: as of this validation, the bug is live in the code, and ASCA-81 cannot be closed on the basis of a merged fix because no such fix is in the repo.**

---

## 4. Precision note on the Req 9.1 "contradiction" (fairness to the RCA)

There are **two** linkage hops in the refund path:

1. **Refund charge → original coaching charge** — done by `resolveOriginalChargeId()` via `log_refund_history` (`refund_charge_id` → `refunded_charge_id`). This is **correct** and is what Req 9.1 literally mandates. `RefundLinkageResolverTest::test_resolution_follows_linkage_not_dates` proves this hop ignores dates.
2. **Original coaching charge → its ¥0 App companion** — done by `fetchAppCompanion()`, which matches on `start_date` **and** `end_date`. **This is the defect.**

Cristoff frames the whole thing as "the refund path matches on dates, contradicting Req 9.1." Strictly, Req 9.1 is about hop (1), and the engine does hop (1) correctly. The defect is in hop (2), which Req 9.1 does not word-for-word cover. So the "contradiction" is slightly **overstated as worded** — but the underlying principle Req 9.1 establishes ("pair via the stable bundle key, never by date") is exactly what hop (2) violates, and Cristoff's prescribed fix (resolve the companion on `student_id + plan_id + order_no(when present) + start_date`, drop `end_date`) is the right correction. Verdict stays **CONFIRMED**, with this nuance recorded.

(One further detail worth capturing for the implementer: even the stable key Cristoff proposes keeps `start_date`. That is safe for the 471/7185 shape because Coaching and App share the same `start_date` and differ only on `end_date`. If a future case ever has differing `start_date` too, the resolver should fall back to `charge_id`-based linkage — but that is out of scope for ASCA-81.)

---

## 5. Why `RefundAppRowWriter` justifies dropping the period predicate

Cristoff argues the resolver doesn't need period columns because `RefundAppRowWriter` re-reads the App row by `charge_id`. **Confirmed.** `RefundAppRowWriter::readOriginalAppRow()` and `deletePriorRefundAppRow()` both key on `charge_id` (the resolved `originalAppChargeId`), and `buildRow()` mirrors identity columns from that row (or reconstructs from `OriginalBundleData` when the month was cleared). So once `fetchAppCompanion()` returns the right App charge **id**, the writer handles periods correctly — matching on `end_date` in the resolver buys nothing and only causes the miss.

---

## 6. ASCI (CIP) cross-check — **CONFIRMED-REPEATS**

The CIP code is **not on the current checkout** but **is fetched** as `origin/feature/ASCI/ASCI-11-cip-integration` (tip `2e87224d`, 2026-10-30), under `app/Libs/RevenueAllocation/Cip/`. This let me validate it directly.

**The bug is reproduced in `CipBundlePairing::findPair()`** (verbatim from the ASCI-11 branch):

```php
$query = DB::connection(self::CONNECTION)
    ->table('trn_charge')
    ->where('student_id', $ci->student_id)
    ->where('plan_id', $ci->plan_id)
    ->where('start_date', $ci->start_date)
    ->where('end_date', $ci->end_date)                    // ← same defect as ASCA
    ->whereIn('product_id', [self::PRODUCT_ID_COACHING_INTENSIVE, self::PRODUCT_ID_APP]);
```

Chain: `CipRefundLinkageResolver::resolveOriginalBundle()` does the refund→original hop correctly via `log_refund_history`, then calls `$this->pairing->findPair(...)` for the original→App hop; `findPair()` returns null on an `end_date` mismatch → `resolveOriginalBundle()` returns null → the CIP refund's App portion is silently dropped. **Identical failure to ASCA-81.**

**The trigger condition holds for CIP.** ASCI Req 4.10 states the site creates a negative **only on the Coaching Intensive charge** and the App companion is **¥0** — the same CAP shape where the ¥0 App companion runs its own (month-end) period while the CI charge covers a shorter sub-period. So the `end_date`-mismatch trap will actually fire on real CIP refunds.

**The ASCI design/tasks *prescription* itself carries the bug (not just the code):**
- `asci-spec-01-cip-integration/requirements.md` Req 2.7 (line 80): "pair … by **reusing the CAP pairing rule (ASCA Spec 01 G1 1-5)** … match by contract period (`start_date`/`end_date`)."
- `design.md` Component 2 (line 101): "match by `start_date` AND `end_date`."
- `tasks.md` T2 (line 31): "when `order_no` is NULL, match by `start_date` AND `end_date` (ASCA Spec 01 G1 1-5)."
- The ASCI spec contains **no reference to ASCA-81** and no date-mismatch risk note — it faithfully inherited the Foundation assumption.
- The dev-context source (`.../projects/asci/specs/asci-spec-01-cip-integration/requirements.md` Req 2.7, line 74) matches the code-repo spec exactly.

**The CIP tests lock the bug in as "expected."** `tests/Unit/RevenueAllocation/CipBundlePairingTest.php::test_null_order_no_with_mismatched_dates_is_not_paired` sets the App companion's `end_date` to `2027-02-28` (CI is `2027-01-31`) and asserts `findPair()` returns **null**. That is the ASCA-81 failure written down as a passing expectation — so fixing the bug will require **changing this test**, not just adding one.

---

## 7. What Cristoff's RCA got wrong / overstated / left unverified

Being fair — the core analysis is strong. The issues are about **status claims**, not the diagnosis:

1. **"Fix applied + verified" — not in the code.** No ref contains the dropped-predicate fix or the warning log. (Most likely un-pushed/un-fetched; still must not be treated as merged.)
2. **"Regression test added; 8/8 pass."** The file has **7** tests, and none reproduces the 471 shape. The existing tests pass *despite* the bug, so "verified by tests" is not supported by what's in the repo.
3. **Req 9.1 "contradiction" is slightly overstated as worded** — Req 9.1 covers the refund→original hop (which is correct); the defect is the original→companion hop. The fix direction is still right (see §4).
4. **Spec-cleanup claim (correcting 02b text + Spec 01 Req 6.4) is unverified / not done** — Spec 01 Req 6.4/6.5 still assert identical `start_date` AND `end_date`; no correction is committed.
5. Everything else — defect site, silent-drop chain, Spec-01 origin, `RefundAppRowWriter` justification, and the 471/7185 arithmetic — is **accurate**.

---

## 8. Recommendation

**ASCA-81:**
- The diagnosis is validated; the described fix is the correct one. **But do not close ASCA-81 as "fixed" yet** — the fix is not in any branch of this repo. Required before close:
  1. Land the actual change in `fetchAppCompanion()` (drop the `end_date` predicate; resolve on `student_id + plan_id + order_no`-when-present + `start_date`) on a reviewable branch/PR.
  2. Add the warning log (`[REVENUE_ALLOCATION] refund App companion not found for in-scope CAP original`) so a future miss is never silent.
  3. Add a **real** regression test reproducing the 471 shape (Coaching `end_date` ≠ App `end_date`, App runs to month-end) and assert a non-null bundle + the −1,934 / −3,868 App splits. Correct the "8/8" bookkeeping (file currently has 7).
  4. Correct Spec 01 Req 6.4/6.5 + design Property 3 so the App companion is paired on `start_date` only (not `end_date`), so the assumption isn't reintroduced.
- Once the PR is merged and the regression test is green, ASCA-81 is safe to close.

**ASCI-11 (required action — this is the high-value outcome):**
- **ASCI-11 ships the same bug and must be fixed before it recognizes any CIP refund.** Treat it as a blocker for the DEV04 CIP-refund verification.
  1. Fix `CipBundlePairing::findPair()` the same way — pair the App companion on the stable key without the `end_date` predicate. (The refund→original hop in `CipRefundLinkageResolver` is already correct.)
  2. **Change** `CipBundlePairingTest::test_null_order_no_with_mismatched_dates_is_not_paired` — it currently asserts the buggy behavior; it must instead assert that a month-end App companion with a differing `end_date` **is** paired. Add a CIP half-price-month refund test that produces the negative App row.
  3. Correct ASCI Req 2.7 / design Component 2 / tasks T2 to drop the `end_date` match from the prescribed pairing rule, and add an explicit ASCA-81 cross-reference so the lineage is documented.
- On DEV04, verify a real CIP half-price-month (or post-contract) refund actually produces the negative App (10022) row — the same end-to-end check ASCA-81 demands for CAP.

---

## 9. Evidence index (files read, read-only)

- Code (HEAD `feature/ASCA/ASCA-master`): `app/Libs/RevenueAllocation/Refund/{RefundLinkageResolver,RefundChargeDetector,RefundAppRowWriter}.php`; `app/Libs/RevenueAllocation/BundleDetectionService.php`; `app/Libs/RevenueAllocation/Formula/TwoWayAllocationFormula.php`.
- Tests: `tests/Unit/RevenueAllocation/RefundLinkageResolverTest.php` (7 methods).
- Specs: `.kiro/specs/asca-spec-01-foundation/{requirements.md Req 6.4/6.5, design.md Property 3}`; `.kiro/specs/asca-spec-02b-refund-allocation/requirements.md Req 9 AC 1`.
- ASCI (via `git show origin/feature/ASCI/ASCI-11-cip-integration:…`): `app/Libs/RevenueAllocation/Cip/{CipRefundLinkageResolver,CipBundlePairing}.php`; `.kiro/specs/asci-spec-01-cip-integration/{requirements.md Req 2.7/Req 4, design.md Component 2, tasks.md T2/T6}`; `tests/Unit/RevenueAllocation/CipBundlePairingTest.php`.
- Dev-context: `projects/asci/specs/asci-spec-01-cip-integration/requirements.md Req 2.7` (matches code-repo spec).
- Git: `git log --all -S "refund App companion not found"` (0 commits); per-branch `git grep` of the `end_date` predicate (present on all tips); `git log` of `RefundLinkageResolver.php` (2 commits, both ASCA-47, no fix).
- Arithmetic independently re-derived (floor toward −∞): 471 → −1,934 / −19,241; 7185 → −3,868 / −38,482.

> Note on environment: the host has no PHP CLI (PHP runs in Docker), so the PHPUnit suite was **not** executed. The test findings above are from reading the test source, which was sufficient to establish that the claimed regression case is absent and that the existing 7 tests do not exercise the bug.
