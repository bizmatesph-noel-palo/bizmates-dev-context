# REPORT-00 — ASCA-81: CAP refund produces no negative App allocation row (initial capture)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report (initial capture — from Jira ticket + comment) |
| **Date** | 2026-11-03 (captured) |
| **Author** | Noel Palo, Lead (Kiro-assisted) |
| **Status** | Initial capture — **claims are Cristoff-san's RCA, pending independent validation** (REPORT-01, in progress) |
| **Source** | Jira **ASCA-81** (reporter + assignee: Glenn Flamiano, QA; created 2026-10-26) + RCA comment by **Cristoff T. Danganan** (2026-10-30) |
| **Ticket** | [ASCA-81](https://bizmates.atlassian.net/browse/ASCA-81) — "[QA][Spec2b][For Investigation] Negative CAP refund Coaching charges do not generate negative App allocation rows" (Task under epic ASCA-44, Spec 02b Refund Allocation) |
| **Audience** | Dev (Throy, Cristoff), QA (Glenn), SDM (Patrick-san), PM (Kuroda-san) |

> ⚠️ **This is an initial capture, not independent verification.** It faithfully records what the ticket reports and what Cristoff-san's RCA comment claims. A separate validation pass (cross-checking the claims against the live code) is tracked as REPORT-01 in this same directory. Treat the root-cause + fix below as **"per Cristoff-san, to be validated."**

---

## 1. What QA reported (ticket, Glenn-san)

For CAP refunds on two students (both plan 1023, CAP), the batch wrote the negative **Coaching** row in the execution month but **no negative App (10022) row** appeared — so the refund's App portion is missing from the DailyRateCalculation output.

**Observed data (October CSV, from the ticket):**

| Student | Plan | Original Coaching | Refund Coaching | App companion |
|---|---|---|---|---|
| 471 | 1023 (CAP) | 10015, charge 3224205, +21,175 | 10015, charge 3224285, −21,175 | 10022, charge 3224206, ¥0 |
| 7185 | 1023 (CAP) | 10015, charge 3224139, +42,350 | 10015, charge 3224288, −42,350 | 10022, charge 3224140, ¥0 |

**Expected negative split (Spec 02b, 30-min CAP weights L_coaching 36,000 : L_app 3,618, ΣL 39,618):**
- 471, N = −21,175 → P_app = floor(−21,175 × 3,618 / 39,618) = **−1,934**; P_coaching = **−19,241**
- 7185, N = −42,350 → P_app = **−3,868**; P_coaching = **−38,482**

**Observed vs expected:** negative Coaching row present, App source row stays ¥0, **no negative App row** in the Sep/Oct/Nov DailyRateCalculation scan.

**QA classification:** SUSPECTED Spec 02b violation (Req 9(3) — the new execution-month negative App row is absent). QA flagged one confirmation limitation: the supplied `db_logs_october` lacks `log_refund_history`, so the refund→original linkage was not independently confirmed in the ticket.

**Excluded (correctly not violations):** students 2659 (Lesson-only negative), 7119 / 7376 / 7537 (non-CAP). Only 471 and 7185 are in-scope.

---

## 2. Root cause — AS CLAIMED by Cristoff-san (RCA comment, 2026-10-30)

> The following is Cristoff-san's analysis, recorded here verbatim-in-substance. **Not yet independently validated** — see §4.

**Classification (his):** a **Spec defect carried into code**, not a code-generation error. Status (his): root cause confirmed, fix applied + verified.

**Mechanism (his):** The refund path resolved the ¥0 App companion by requiring an **exact match on both `start_date` AND `end_date`** against the original Coaching charge. In a real CAP bundle, the Coaching charge covers a short sub-period while the App companion runs to **month-end**, so their `end_date`s differ. The match returns nothing → refund classified "not in scope" → dropped silently (no row, no outcome, no log line).

**Exact site (his):**
- **File:** `RefundLinkageResolver.php`, method `fetchAppCompanion()`
- **Defect:** `->where('start_date', $original->start_date)->where('end_date', $original->end_date)` — the `end_date` predicate
- **Silent-drop chain:** `fetchAppCompanion()` returns null → `resolveOriginalBundle()` returns null → `RefundChargeDetector::detect()` treats null as "not a tracked CAP refund" and `continue`s silently.

**Contradiction he flags:** this date-matching contradicts **02b Req 9.1**, which mandates pairing via `log_refund_history` + the stable bundle key, NOT date matching.

**Origin trail (his):** the "Coaching and App share identical dates" assumption originates in **Spec 01 Foundation Req 6.4** (+ Req 6.5, design Property 3), was implemented in `BundleDetectionService` (grouping key folds in both dates), rode through **02a** untouched, and surfaced as a guaranteed miss in **02b** refunds (the one case where Coaching vs App `end_date`s always differ).

**Fix (his):**
1. Drop the `end_date` predicate in `fetchAppCompanion()`; resolve the App companion on the stable key only (`student_id` + `plan_id` + `order_no` when present + `start_date`), per Req 9.1. (`RefundAppRowWriter` re-reads the App row by `charge_id`, so period columns aren't needed here.)
2. Make the silent drop visible — emit a `[REVENUE_ALLOCATION] refund App companion not found for in-scope CAP original` warning.
3. Spec cleanup — correct 02b text and Spec 01 Req 6.4 so the App companion shares `start_date` but NOT `end_date`.

**Verification (his):** regression test reproducing the 471 shape added; `RefundLinkageResolverTest` 8/8 pass; full `tests/Unit|Feature/RevenueAllocation` = 127 tests / 42,644 assertions, 1 unrelated error (`AllocationInjectorTest::test_container_resolves_injector_with_collaborators` — needs live MySQL, "Connection refused," not caused by this change).

**His stated provenance caveat:** the SQL linkage evidence was gathered in a prior session, not re-run (no live DB; `db_logs_october` lacks `log_refund_history`), so the refund→original linkage still rests on that earlier evidence.

---

## 3. Why this matters beyond ASCA — the ASCI impact (added by Lead)

**ASCI reused this exact pairing pattern.** The ASCI Spec 01 design models `CipBundlePairing` (Task 2) and `CipRefundLinkageResolver` (Task 6) on the CAP pairing rule + ASCA 02b's `RefundLinkageResolver`. If the ASCI code carried the same `start_date` + `end_date` match, **CIP refunds would have the identical missing-App-row bug.**

- ASCI-11 Coding was just reported done (2026-11-03) and is being deployed to DEV04.
- **Action:** ASCI-11 review/testing MUST verify `CipRefundLinkageResolver` resolves the App companion on the stable key (not an `end_date` match), and that a CIP half-price-month refund actually produces the negative App row. This is now a required check in the ASCI §7 refund pattern (and the DEV04 verification).

This cross-project consequence is the single most important reason ASCA-81 is worth a report, not just a ticket close.

---

## 4. What still needs independent validation (→ REPORT-01)

Cristoff-san's RCA is coherent and the date-mismatch evidence in the ticket CSV is compelling on its face. But per the three-point-verification discipline, the claims below are recorded as **unvalidated** until checked against the live code:

1. **The defect site** — confirm `fetchAppCompanion()` in `RefundLinkageResolver.php` actually matched on both dates (check git history/the pre-fix version), and confirm the silent-drop chain through `resolveOriginalBundle()` → `RefundChargeDetector::detect()`.
2. **The fix is actually applied** — confirm the current `RefundLinkageResolver.php` pairs on the stable key with the `end_date` predicate removed, and that the warning log line exists.
3. **The origin claim** — confirm Spec 01 Req 6.4 / design Property 3 / `BundleDetectionService` grouping key actually carry the identical-`end_date` assumption.
4. **The arithmetic** — re-verify P_app/P_coaching for 471 and 7185 (floor toward −∞).
5. **The test claim** — confirm `RefundLinkageResolverTest` passes and the regression test exists.
6. **The ASCI cross-check (§3)** — the highest-value item: does the ASCI code repeat the bug?

REPORT-01 (independent validation) covers these.

---

## 5. Status & recommendation (initial)

- ASCA-81 is a **credible, well-evidenced Spec 02b defect** with a fix reportedly applied + verified. Pending independent validation (REPORT-01).
- **If validated:** this is a definitive Req 9(3) failure fixed at `RefundLinkageResolver::fetchAppCompanion()`; the ASCA-81 ticket can move toward closure once the fix PR is reviewed/merged, and the **Spec 01 Req 6.4 wording should be corrected** so the assumption isn't reintroduced.
- **Regardless of validation:** the **ASCI impact (§3) must be checked now** — it touches the active critical path (ASCI-11).
