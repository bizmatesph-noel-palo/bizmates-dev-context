# CAP — Proration Target Detection Discussion

**Source:** Kuroda-san (Slack, 2026-07-30), raised by Soli-san  
**Status:** Under consideration — pending business team approval  
**Affects:** ASC for CAP eligibility logic (how the batch identifies which charges to allocate)

---

## The Question

How does the ASC for CAP batch know that a Coaching charge is a CAP allocation target?

**Current approach (for B2B only):**
- A CAP purchase creates a linked ¥0 App charge with a **newly created App product_id**
- If that product_id exists on the linked App charge → Coaching charge gets allocated
- If not (e.g., existing standalone B2B App) → excluded

**Alternative under consideration:**
- Skip creating a new App product_id
- Trigger allocation simply off the App charge being ¥0 (`paid_price = 0`)
- No dedicated product_id needed

---

## Kuroda-san's Assessment

He thinks the ¥0-trigger approach CAN work, but has concerns:

> "¥0 App charges may not be unique to CAP bundling. FVP's bundled product is also registered at ¥0, and there could be other free/promotional App grants in the future. Without a distinct product_id, it becomes hard to explain — for the allocation batch logic and for future audits — why one ¥0 App charge is an allocation target and another isn't."

Needs business team approval before proceeding.

---

## Impact on ASC for CAP

| Approach | Eligibility logic | Risk | Clarity |
|---|---|---|---|
| **New product_id** (current) | Check for specific product_id on linked App charge | Low — deterministic | High — product_id is unambiguous |
| **¥0 trigger** (proposed) | Check `paid_price = 0` on App charge linked to CAP plan | Medium — false positives possible | Low — why is THIS ¥0 charge allocated but not THAT one? |

**For our estimate:** Both approaches take the same development effort. The eligibility check is one query either way. The question is a business/data-modeling decision, not an engineering effort question.

**For ASCH:** No impact. ASCH identifies Honki Set members via CDB table (completely different mechanism). But the principle is the same — you need a **deterministic discriminator** that won't accidentally match non-target charges.

---

## Our Recommendation (if asked)

Use the **plan_id approach** that's already in the CAP scope doc (Section 5.1):

> "plan_id is the mandatory discriminator. A real App purchase must never become a CAP allocation target merely because the student also has a CAP contract."

If the Coaching charge is on a CAP plan_id → it's a target. The App charge is just verification (confirm it exists and is synchronized). Whether the App has a new product_id or uses the existing 10012 with ¥0 doesn't change the primary eligibility — the **Coaching plan_id** is what triggers allocation, not the App charge's properties.

This aligns with what Kuroda-san already specified and avoids the ambiguity of ¥0-based detection entirely.

## Code Evidence: FVP Already Creates ¥0 Charges (Confirms Kuroda-san's Concern)

### MBTI_backend (`MstPlan.php`)

```php
public const PRODUCT_FULL_VIDEO_PACKAGE = 10011;    // product_id
public const PRODUCT_TYPE_FULL_VIDEO_PACKAGE = 5;    // product_type
const FULL_VIDEO_PACKAGE_PRODUCT_PRICE = 0;          // ¥0 when bundled
const IS_FVP = 1;                                    // mst_plan.is_fvp flag

public static function isFvpProduct(int $productId): bool
{
    return $productId === self::PRODUCT_FULL_VIDEO_PACKAGE;
}
```

FVP plans (all include product_id=10011 at ¥0):
- 1001–1004: Online Lesson + FVP
- 1005–1008: Online Lesson + FVP + Coaching 15min
- 1010–1013: Online Lesson + FVP + Coaching 30min
- 1014: Beginner + FVP + Coaching 30min
- 1015: Monthly 15 + FVP

### bizmates.jp (`fuel/app/tasks/charge.php`)

FVP charge is created at ¥0 during the lesson product renewal:

```php
// Line ~348: FVP charges are SKIPPED in normal refresh — handled alongside Lesson
if ($refreshChargeEntry['product_id'] == PlanModel::PRODUCT_FULL_VIDEO_PACKAGE) {
    \Log::info('[SKIP] Full Video Package. Handled alongside Skype Product');
    \Order::stop($refreshChargeEntry['student_product_id']);
}

// Line ~660: FVP ¥0 charge CREATED when lesson renews (if plan includes FVP)
if (PlanModel::isFvpPlan($refresh_charge['plan_id'])
    && $refreshChargeEntry['product_type'] == PlanModel::PRODUCT_TYPE_SKYPE) {
    $fvpRefreshChargeId = \Order::charge(
        $refresh_charge['student_id'],
        PlanModel::PRODUCT_FULL_VIDEO_PACKAGE,       // product_id = 10011
        $refresh_charge['plan_id'],
        $refresh_charge['charge_type'],
        false,
        PlanModel::FULL_VIDEO_PACKAGE_PRODUCT_PRICE, // ¥0
        $refresh_charge['start_date'],
        $refresh_charge['end_date'],
        null,
        $refresh_charge['contract_type']
    );
}
```

### What This Proves

| Product | product_id | paid_price in trn_charge | product_type |
|---|---|---|---|
| FVP (Full Video Package) | 10011 | ¥0 | 5 |
| App (Bizmates App) | 10012 | ¥0 | 100 |

**Both exist at ¥0 in `trn_charge`.** A query like `WHERE paid_price = 0` would match BOTH. Only `product_id` or `product_type` distinguishes them. This is why the ¥0-trigger approach is unreliable for CAP allocation detection — it would incorrectly match FVP charges as allocation targets.

**Safe approach:** Use `plan_id` as primary discriminator (per Kuroda-san's scope doc §5.1), then verify `product_id = 10012` for the App component specifically.

### MBTI_backend — PaypalService.php (Purchase Flow)

FVP is created at ¥0 during the initial PayPal purchase — same pattern CAP/CIP will use for App:

```php
// src/app/Services/Student/Payment/PaypalService.php (line ~113)
if (MstPlan::isOnlineLessonFvpPlan((int)$item['plan_id'])) {
    // Manually call `buy` because FVP will not be added to $items since its price is 0
    $fvpChargeInfo = Order::buy(
        $student_id,
        MstPlan::PRODUCT_FULL_VIDEO_PACKAGE,       // product_id = 10011
        $item['plan_id'],
        $charge_type,
        $transaction_id,
        MstPlan::FULL_VIDEO_PACKAGE_PRODUCT_PRICE, // paid_price = 0
        MstPlan::FULL_VIDEO_PACKAGE_PRODUCT_PRICE  // sales_price = 0
    );
}
```

**Key observations:**
- FVP is `Order::buy()` with `paid_price = 0` AND `sales_price = 0`
- It shares the same `plan_id` and `transaction_id` as the main lesson purchase
- It creates a separate `trn_charge` row and `trn_student_product` row
- B2E contract-type update is applied to BOTH main product AND FVP (line ~162-166)
- Plan change syncs FVP end_date to match the lesson product (line ~699)

**This is the proven precedent for CAP/CIP App creation.** The application-side teams will likely replicate this pattern: detect CAP/CIP plan_id → manually create App charge at ¥0 alongside the Coaching charge. The resulting `trn_charge` row has `product_id=10012`, `paid_price=0`, `sales_price=0`, same pattern as FVP's `product_id=10011`.

---

## Status

- Pending business team approval (Kuroda-san to confirm)
- No estimate change regardless of outcome
- Flagged for CAP sub-lead awareness when onboarding
- Code evidence added: FVP (10011) confirmed at ¥0 in both MBTI_backend and charge.php
