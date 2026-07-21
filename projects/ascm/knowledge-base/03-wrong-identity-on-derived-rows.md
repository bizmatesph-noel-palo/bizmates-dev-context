# 03 — Wrong Identity on Derived Rows

> **TL;DR:** Refund log rows were inserted with the *original charge's* ID instead of the refund's own ID. Refunds were untraceable — they looked like duplicates. Fix: every derived record carries its own identity; link to source via a separate FK field.

---

## Problem Pattern

A system generates derived records (refunds, adjustments) by copying from an original. The derived record inherits the original's identity instead of receiving its own. This makes reconciliation impossible.

---

## How We Encountered It

The ASC project's monthly rate calculation generates log rows for refund charges. The initial implementation cloned the original charge's log entry and negated amounts:

```php
$refundRow = clone $originalRow;
$refundRow->paid_price = -$originalRow->paid_price;
// BUG: $refundRow->charge_id still points to the original
```

A refund is a *separate transaction* in `trn_charge` with its own `charge_id`. The log row must reference the refund's ID, not the original's.

**JIRA:** ASC-244

---

## What We Did

```php
$refundRow = new LogMonthlyRateCalculation();
$refundRow->charge_id = $refundCharge->id;           // Own identity
$refundRow->original_charge_id = $originalCharge->id; // Explicit link back
$refundRow->paid_price = -$originalCharge->paid_price;
```

---

## Industry Standard / Best Practice

### How Stripe Models Refunds

A refund is `re_xxx` with its own ID, linked to `ch_xxx` via a `charge` field. Both directions are explicit.

### How Double-Entry Accounting Works

Every journal entry has its own transaction ID. A refund references the original via a linked-transaction field but has its own identity in the ledger.

### Never Clone for Derived Records

Use a factory that requires identity fields:

```php
RefundLogEntry::fromOriginal($originalCharge, $refundCharge)
    ->withAmount(-$originalCharge->paid_price)
    ->build();
```

---

## Prevention Checklist

- [ ] Every row is identifiable by its *own* primary key — never a copied FK
- [ ] Derived records are constructed fresh (factory/builder), not cloned
- [ ] Relationships use explicit FK fields (`parent_id`, `original_charge_id`)
- [ ] Unique constraints prevent duplicate `charge_id` insertions
- [ ] Tests verify derived rows are retrievable by their own identity