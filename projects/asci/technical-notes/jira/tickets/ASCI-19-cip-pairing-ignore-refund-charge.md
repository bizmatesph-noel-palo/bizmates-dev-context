# ASCI-19 — Fix CIP bundle pairing so a refund charge no longer blocks conversion and refund split (ASCI-17 follow-up)

> **Created in JIRA 2026-11-06 as [ASCI-19](https://bizmates.atlassian.net/browse/ASCI-19)** — Sub-task under ASCI-11, Priority High, **Unassigned**, status To Do. This file is the source of record; the JIRA ticket carries the same content. Investigation: `../investigation/20261106-cip-pairing-counts-refund-charge/REPORT-00-cip-pairing-counts-refund-charge.md`.

**Type:** Sub-task
**Parent:** ASCI-11 ([Spec 01] — Coding)
**Priority:** High (Lead on leave from 2026-11-11)
**Assignee:** Unassigned (Lead hands it to Throy-san)
**Repo:** `accounting_related_system_for_freee`, base branch `feature/ASCI/ASCI-master`
**Related:** ASCI-17 (stays open until this is verified on DEV04), ASCA-81/86 (CAP side, already verified)

---

## Goal

Make `CipBundlePairing::findPair()` ignore refund (negative) charges, so CIP charges that have a refund get converted and CIP refunds get split into Coaching and App.

## Why

On DEV04, five CIP refunds were not split and their original charges were not converted (students 1332, 1341, 2883, 303197, 1824). The refund charge has the same student, plan and start date as the original, so the code finds **two** Coaching Intensive charges instead of one and gives up. The DEV04 log shows it:

- `[CIP_CONVERSION] conversion skipped ... "CIP charge is not exactly 1 Coaching Intensive + 1 App"`
- `[CIP_REFUND] refund split skipped ... "No resolvable original CIP charge via log_refund_history; refund left on Coaching"`

## Steps

### Step 1 - Create the branch

Create a branch from `feature/ASCI/ASCI-master`, named after this ticket key, for example `feature/ASCI/ASCI-19-cip-pairing-ignore-refund`.

### Step 2 - Ignore refund charges in the group query

Open `app/Libs/RevenueAllocation/Cip/CipBundlePairing.php`, method `findPair()`. Find this query:

```php
$query = DB::connection(self::CONNECTION)
    ->table('trn_charge')
    ->where('student_id', $ci->student_id)
    ->where('plan_id', $ci->plan_id)
    ->where('start_date', $ci->start_date)
    ->whereIn('product_id', [self::PRODUCT_ID_COACHING_INTENSIVE, self::PRODUCT_ID_APP]);
```

Add one line so refund (negative) charges are not counted:

```php
$query = DB::connection(self::CONNECTION)
    ->table('trn_charge')
    ->where('student_id', $ci->student_id)
    ->where('plan_id', $ci->plan_id)
    ->where('start_date', $ci->start_date)
    ->whereIn('product_id', [self::PRODUCT_ID_COACHING_INTENSIVE, self::PRODUCT_ID_APP])
    // Refund charges (negative paid_price) share the original's bundle key. They must not
    // be counted, or the bundle looks like 2 Coaching Intensive + 1 App and is never paired.
    ->where('paid_price', '>=', 0);
```

### Step 3 - Return null when the charge you were asked about is itself a refund

In the same method, find the first guard:

```php
if (
    $ci === null
    || (int) $ci->product_id !== self::PRODUCT_ID_COACHING_INTENSIVE
    || !CoachingIntensivePlanEnum::exists((int) $ci->plan_id)
) {
    return null;
}
```

Add one condition:

```php
if (
    $ci === null
    || (int) $ci->product_id !== self::PRODUCT_ID_COACHING_INTENSIVE
    || !CoachingIntensivePlanEnum::exists((int) $ci->plan_id)
    || (int) $ci->paid_price < 0
) {
    return null;
}
```

Do not change anything else in the method. Keep the check that requires exactly one Coaching Intensive charge and one App charge.

### Step 4 - Add two tests to CipBundlePairingTest

File: `tests/Unit/RevenueAllocation/CipBundlePairingTest.php`. The helper `charge($id, $productId, $orderNo, $price, $studentId = 7001)` already inserts a charge with start date 2027-01-01.

```php
public function test_refund_charge_in_the_same_bundle_is_ignored(): void
{
    $this->charge(1, self::CI, null, 75900);
    $this->charge(2, self::APP, null, 0);
    $this->charge(3, self::CI, null, -75900); // refund: same student, plan and start date

    $pair = $this->pairing->findPair(1);

    $this->assertNotNull($pair);
    $this->assertSame(1, $pair->coachingChargeId);
    $this->assertSame(2, $pair->appChargeId);
}

public function test_refund_charge_itself_is_not_paired(): void
{
    $this->charge(1, self::CI, null, 75900);
    $this->charge(2, self::APP, null, 0);
    $this->charge(3, self::CI, null, -75900);

    $this->assertNull($this->pairing->findPair(3));
}
```

### Step 5 - Fix the refund helper in CipRefundLinkageResolverTest

File: `tests/Unit/RevenueAllocation/CipRefundLinkageResolverTest.php`.

**Watch out:** the helper `refundCharge()` says it builds a refund with the "same bundle key as original", but it passes `order_no` 999 while the original charges use 555 (the default in `charge()`). So in these tests the refund is **not** in the same bundle as the original. That is why the existing tests passed while DEV04 failed. If you use the helper as it is, a new test would also pass without the fix.

Change the last line of `refundCharge()` from:

```php
$this->charge($id, self::CI, $price, 1028, $start, $end, 999);
```

to:

```php
$this->charge($id, self::CI, $price, 1028, $start, $end, 555);
```

Now the existing refund tests (for example `test_standard_original_resolves_to_3980_over_75900`) use a refund that really shares the original's bundle key, so they become the regression test. If another test in this file breaks only because of the new order number, read it and adjust the test data while keeping its intent. If you are not sure, ask the Lead.

### Step 6 - Prove the tests catch the bug, then run the CIP tests

First, temporarily comment out the new `paid_price` lines from Steps 2 and 3. Run `vendor/bin/phpunit --filter CipBundlePairing` and `--filter CipRefundLinkageResolver`. The new tests (and `test_standard_original_resolves_to_3980_over_75900`) must **fail**. Then restore the lines and run them again: they must **pass**.

Then run `--filter CipRefundAllocator` and `--filter CipChargeConverter`. All must pass. The existing `test_two_ci_is_not_paired` (two positive Coaching Intensive charges) must still pass.

Before running tests, merge the latest `feature/ASCA/ASCA-master` into your branch. It contains the DB-safety guard (ASCA-82) that forces tests onto SQLite. Do not run the full suite against a shared database.

### Step 7 - Open the PR

Open a PR to `feature/ASCI/ASCI-master`. Please have it ready by **Monday 2026-11-09**: the Lead reviews it before leaving on 2026-11-11.

## How to know it's fixed

- The new tests fail without the fix, pass with it, and all existing CIP tests still pass.
- After the branch is merged and deployed to DEV04 (**check that the DEV04 server really pulled it before running**), rerun the 2026-11 batch. In `202611_03_DailyRateCalculation(...)` expect:

| Student | Refund row today (Coaching Intensive) | Expected Coaching refund | Expected App refund (new row) |
|---|---|---|---|
| 1332, 1341, 2883 | -75,900 | -71,920 | -3,980 |
| 303197, 1824 | -37,950 | -35,960 | -1,990 |

- The original charges of these five students are converted (a Coaching and App split instead of 75,900 and 0), like student 1311 (Coaching 62,331, App 3,450).
- Searching the DEV04 log for `[CIP_CONVERSION]` and `[CIP_REFUND]` shows no skip lines for these five students.

## Do NOT

- Do not change the `end_date` handling (that was ASCI-17 and stays as it is).
- Do not touch the CAP code (`RefundLinkageResolver`) or unrelated tests.

## Background (read last)

The CAP side does not have this problem because it only searches for the App charge. The CIP pairing searches for Coaching Intensive and App charges together, so a refund charge (also product 10025, same student, plan and start date) gets counted. The unit tests missed it because their refund helper used a different order number from the original (see Step 5), while real DEV04 charges have the same (null) order number. Full evidence (logs, CSV rows, code paths): `projects/asci/technical-notes/investigation/20261106-cip-pairing-counts-refund-charge/REPORT-00-cip-pairing-counts-refund-charge.md` in the bizmates-dev-context repo.
