# 11 — Rounding Loss Accumulation (The Missing ¥7)

> **TL;DR:** `floor(14107 / 15) = 940`. Multiply back: `940 × 15 = 14100`. The ¥7 difference is accumulated rounding loss from floor() across all units. Fix: if refunding all units, use the original total directly.

---

## Problem Pattern

A total is divided into N equal units using floor(). Reconstructing the total by multiplying back produces a value that's up to N-1 currency units short.

---

## How We Encountered It

The FLP (15-lesson plan) refund calculation:

```php
public static function getFLPProratedUnitPrice($price) {
    return floor($price / 15);
}
```

For ¥14,107: `floor(14107/15)` = 940. Full refund: `940 × 15` = ¥14,100. **Missing: ¥7.**

This wasn't an ASC bug — it existed in MBTI_backend. But it surfaced during ASC because accounting reports showed refund amounts not matching original charges.

**JIRA:** ASC-239

---

## What We Did

```php
if ($studentTicketCount >= 15) {
    $refund_price = $refund_charge['paid_price'];  // Full refund: use original
} else {
    $refund_price = $studentTicketCount * $refundPerUnitPrice;  // Partial: per-unit is fine
}
```

---

## Industry Standard / Best Practice

### How Stripe Splits Amounts

Assigns remainder to one specific recipient. 14 get ¥940, one gets ¥947. Total always equals original.

### How Banks Handle Installments

Last installment = total - sum(all other installments). Sum always equals original.

### The Fundamental Rule

> `floor(total / N) × N ≠ total` for most values. Any time you see floor() followed by multiplication back, there's a gap.

---

## Prevention Checklist

- [ ] Full-quantity refund = use original total, never multiply rounded unit price back
- [ ] For partial quantities, accept slight underage (unavoidable)
- [ ] Document rounding strategy in code comments
- [ ] Test: `refund_price == paid_price` when all units are refunded
- [ ] Verify displayed totals match actual charge/refund amounts
