# CIP refunds and conversion skipped — `CipBundlePairing` counts the refund charge in the bundle

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report |
| **Status** | Active — fix ticket raised (see §7) |
| **Date** | 2026-11-06 |
| **Author** | Noel Palo, Lead |
| **Assisted by** | Kiro |
| **Mode** | READ-ONLY (logs pasted by Throy-san, generated CSVs, git/code reading). No code changed. |
| **Repo / branch read** | `accounting_related_system_for_freee`, `origin/feature/ASCI/ASCI-master` |
| **Related tickets** | ASCI-17 (stays open), ASCI-11, ASCA-81/86 (CAP side, verified) |

---

## 1. Summary (verdict first)

On DEV04, CIP refunds are **not split** into Coaching + App, and the original charges of refunded CIP bundles are **not converted**. Five students are affected in the 2026-11 data (1332, 1341, 2883, 303197, 1824). Both symptoms come from one cause:

> `CipBundlePairing::findPair()` collects every Coaching Intensive (10025) and App (10022) charge that shares the original's `student_id`, `plan_id`, `order_no` and `start_date`, and requires **exactly one of each**. A refund charge is also a 10025 row with the same key, so a refunded bundle contains **two** Coaching Intensive rows (original + refund) and `findPair()` returns `null`.

ASCI-17 (CIP verification on DEV04) therefore **cannot be closed**. The CAP side (ASCA-81/86) was verified separately and is fine.

This is a code defect, not stale data or a deployment problem. I do not think ASCI-17 caused it (§5).

## 2. Evidence

### 2.1 DEV04 log (Throy-san, 2026-11-06; same lines in every run from 12:46 to 15:42)
Filtered to the affected students:

- `[CIP_CONVERSION] conversion skipped … "CIP charge is not exactly 1 Coaching Intensive + 1 App"` for the **original** charges: 3224397 (1332), 3224385 (1824), 3224377 (2883), 3224311 (1341), 3224315 (303197).
- `[CIP_REFUND] refund split skipped … "No resolvable original CIP charge via log_refund_history; refund left on Coaching"` for the **refund** charges: 3224415 (2883), 3224418 (1341), 3224419 (303197), 3224422 (1824), 3224423 (1332).

Both messages appear for exactly the same five students.

### 2.2 Generated CSV — `202611_03_DailyRateCalculation(20261201).csv`
- The five refund rows are still the full site amounts on the Coaching Intensive row: 1332 −75,900; 1341 −75,900; 2883 −75,900; 303197 −37,950; 1824 −37,950. Each student's App row is 0, with no negative App row.
- Their original charges are unconverted (example 1332: 65,780 = 26/30 × 75,900, App 0).
- CIP students **without** a refund are converted, e.g. 1311 Coaching 62,331 / App 3,450; 1133 Coaching 64,729 / App 3,582; 7098 Coaching 32,365 / App 1,791; 303193 Coaching 20,880 / App 1,155.
- In the CSV the refund rows carry the original contract's start date for all five students (e.g. 1332: both 2026-11-05; 1341 and 303197: both 2026-10-20; 1824 and 2883: both 2026-11-04).

### 2.3 Code (`feature/ASCI/ASCI-master`)
- `CipBundlePairing::findPair()` builds the group with `student_id`, `plan_id`, `start_date`, `order_no` and `product_id IN (10025, 10022)`, then returns `null` unless there is exactly 1 Coaching Intensive row and 1 App row. It does **not** exclude refund (negative) charges.
- `CipChargeConverter` skips negative charges itself ("Refund (negative) / zero charges are not converted here") but still calls `findPair()` for the positive original, and logs the "not exactly 1 … + 1 App" skip when it returns `null`.
- `CipRefundLinkageResolver::resolveOriginalBundle()` returns `null` if there is no `log_refund_history` link, if the original is not a Coaching Intensive charge, **if `findPair()` returns `null`**, or if the site amount is not positive. `CipRefundAllocator` logs all four cases with the same "No resolvable original CIP charge" message.
- The CIP code already treats a refund as `paid_price < 0` (`CipRefundAllocator`, `CipRefundAppRowWriter`).
- Contrast with CAP: `RefundLinkageResolver::fetchAppCompanion()` searches **only** product 10022, so a refund charge can never get in its way.

### 2.4 What is verified vs inferred
- **Verified:** the log lines, the CSV amounts, the code paths above.
- **Verified later on 2026-11-06 (Throy-san's query on DEV04):** `log_refund_history` has a link row for each of the five refund charges, and each `refunded_charge_id` is exactly the original charge flagged in the conversion log: 3224415 → 3224377 (2883), 3224418 → 3224311 (1341), 3224419 → 3224315 (303197), 3224422 → 3224385 (1824), 3224423 → 3224397 (1332). So the "no link" exit of `resolveOriginalBundle()` is ruled out, and the refund path fails at the `findPair(original)` step, as described in §3. (His earlier SQL checks for students 471 and 7185 returned nothing and are still unexplained.)
- **Inferred:** that the refund charge row in `trn_charge` has the same `plan_id`, `order_no` (null) and `start_date` as the original. The CSV start dates and the plan_id in the log lines support this. I have not seen the `trn_charge` rows. Throy-san's earlier read-only SQL checks on DEV04 returned nothing even for students present in the CSV, so they probably ran against a different database than the batch uses.
- **Why the unit tests missed it (verified in the test code):** `CipBundlePairingTest` has no case with a refund charge in the bundle. `CipRefundLinkageResolverTest::refundCharge()` is documented as "same bundle key as original but negative", but it creates the refund with `order_no` 999 while the original charges use 555. In those tests the refund is therefore never in the same bundle, so the bug cannot show. Real DEV04 charges have the same (null) order number. Not checked: the other CIP test files.
- **Independent confirmation:** Throy-san's own analysis (his Kiro, 2026-11-06) reached the same cause and the same fix, and noted it is not from the ASCI-17 change.

## 3. Why both symptoms share one cause
1. Conversion of the original → `findPair(original)` → group = original + refund + App → 2 Coaching Intensive rows → `null` → conversion skipped (original stays at 75,900 / App 0).
2. Refund split → `resolveOriginalBundle(refund)` → `findPair(original)` → same group → `null` → "No resolvable original CIP charge" → refund left on Coaching.

## 4. Impact
- Any CIP bundle that has a refund in the same bundle key is left unsplit. Coaching carries the whole amount, App stays 0, the refund stays on Coaching.
- Totals net out, but the Coaching/App split is wrong by the App share (¥3,980 on a full refund, ¥1,990 on a half-price one).
- Bundles without a refund are unaffected.
- Because a refund charge normally keeps the original contract's dates, this likely affects **every** CIP refund, not only these five.
- DEV04 only so far. Not seen in production data (CIP is not live).

## 5. Relation to ASCI-17
ASCI-17 removed the `end_date` match in `findPair()`. That fixed the ASCA-81 shape (App row running to month-end). I do **not** believe it caused this problem: the refund row keeps the original's contract dates (CSV: full 30/31-day contract, same start date), so the old `start_date + end_date` match would probably not have separated the refund either. The group definition counts refund rows regardless of the date rule.

## 6. Recommended fix (proposed, for Lead/dev review)
In `CipBundlePairing::findPair()`, exclude refund charges from the group by adding `->where('paid_price', '>=', 0)` to the group query. The original Coaching Intensive charge is positive, the App charge is 0, and a refund is negative — the same signal the CIP code already uses elsewhere.

Alternatives considered:
- Exclude by membership in `log_refund_history.refund_charge_id`: more precise but adds a join and depends on the link existing, which is the thing the refund path is trying to resolve.
- Re-add the `end_date` match: does not help, the refund shares the dates.

Add a regression test to `CipBundlePairingTest`: original (75,900) + App (0) + refund (−75,900), all with the same key → `findPair(original)` returns a pair with the App charge. The existing `test_two_ci_is_not_paired` (two positive charges) must still pass.

## 7. Follow-up
- Fix ticket: sub-task under ASCI-11 (ticket key recorded in the tracker and in `../../jira/tickets/`).
- After the fix, rerun the 2026-11 batch on DEV04 and expect, for the five students:
  - full refunds (1332, 1341, 2883): Coaching −71,920 / App −3,980
  - half-price refunds (303197, 1824): Coaching −35,960 / App −1,990
  - the original charges converted like 1311 (Coaching/App split instead of 75,900 / 0)
  - no `[CIP_CONVERSION]` or `[CIP_REFUND]` skip lines for these students.
- Ask Throy-san which database his SQL checks ran on, so DB checks can be trusted next time.
