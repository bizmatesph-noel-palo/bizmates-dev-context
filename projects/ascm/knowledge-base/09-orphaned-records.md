# 09 — Orphaned Records — Missing Dependencies

> **TL;DR:** Charges whose tickets were hard-deleted became invisible because the pipeline starts from tickets. No tickets = no join match = charge vanishes. Fix: drive the pipeline from the authoritative source (charges), and use soft deletes.

---

## Problem Pattern

A record depends on a related record to be "visible." When the dependency is deleted, the primary record becomes orphaned — valid but invisible.

---

## How We Encountered It

The monthly rate calculation pipeline starts from `trn_ticket` and traces back to charges. Some charges had tickets **hard-deleted** through admin operations or refund cleanup.

Once monthly plans were excluded from the daily commands, the monthly pipeline became the *only* path for these charges. Invisible in monthly = invisible everywhere.

This connects to Topic 01: if the pipeline could start from charges and look up pre-computed consumption values, orphans would be impossible.

See also: Topic 05 (Invisible Records) covers a related scenario where *refund* charges become invisible due to deleted tickets. Topic 09 covers the general case of *any* charge orphaned by ticket deletion.

**JIRA:** ASC-280 (merged to ASC-master), ASC-297 (extended to cover start-month visibility)

---

## Root Cause

1. **Hard deletes** severed join paths permanently
2. **Pipeline entry via dependency** — parent visibility depends on children existing

---

## What We Did

Proposed orphaned charge detection query:

```sql
SELECT c.* FROM trn_charge c
LEFT JOIN log_monthly_rate_calculation log ON log.charge_id = c.id AND log.target_ym = :period
WHERE c.payment_date >= :start AND c.payment_date < :next_start
  AND c.status IN (valid statuses)
  AND log.charge_id IS NULL
```

---

## Industry Standard / Best Practice

### How Shopify Prevents This

Never hard-deletes line items. Cancellations add `cancelled_at`. Financial records are append-only.

### How Stripe Handles Subscription Cancellation

Subscription becomes `status: 'canceled'` but all charges/invoices remain queryable. Nothing deleted.

### How PostgreSQL FK Constraints Help

```sql
ALTER TABLE trn_ticket ADD CONSTRAINT fk_ticket_charge
FOREIGN KEY (charge_id) REFERENCES trn_charge(id) ON DELETE RESTRICT;
```

---

## Prevention Checklist

- [ ] Never hard-delete records in JOIN paths — use soft deletes
- [ ] Pipeline entry = authoritative table, not a dependency table
- [ ] DB constraints (FK + ON DELETE RESTRICT) prevent accidental orphaning
- [ ] Admin operations run impact checks before deleting
- [ ] Periodic reconciliation detects and alerts on orphaned records
