# 05 — Invisible Records — No Upstream Entry

> **TL;DR:** The CTE pipeline starts from tickets. Charges with deleted tickets never enter the pipeline, so they never appear in reports — even though they're valid financial records. Fix: standalone fallback query that catches anything the main pipeline missed.

---

## Problem Pattern

A batch pipeline's entry query defines which records are "visible." Records that don't match the entry criteria — despite being valid business data — are permanently invisible to downstream consumers.

---

## How We Encountered It

The monthly rate calculation pipeline — created by the ASC project — starts from `trn_ticket` and works backward to charges. Some refund charges had their tickets **deleted** before the batch ran. No tickets = no join match = charge vanishes.

Once monthly plans were excluded from the daily commands, the monthly pipeline became the *only* path for these charges to appear in reports. If the monthly pipeline missed them, they were invisible everywhere.

See also: Topic 09 (Orphaned Records) covers the broader case where *any* charge loses visibility due to hard-deleted tickets. Topic 05 specifically covers refund charges that arrive after the batch window.

**JIRA:** ASC-269

---

## Root Cause

The pipeline assumed: "every charge that matters has at least one associated ticket." This broke for refund charges whose tickets were deleted as part of refund processing.

---

## What We Did

Added a **standalone fallback query** that runs after the main CTE pipeline:

```php
$orphanedRefunds = $this->findRefundChargesNotInLogTable($targetYm);
foreach ($orphanedRefunds as $refund) {
    $this->insertRefundLogEntry($refund);
}
```

This ensures 100% coverage: main pipeline handles normal cases, fallback catches the rest.

---

## Industry Standard / Best Practice

### How AWS Billing Ensures Completeness

A daily reconciliation compares "resources provisioned" against "line items generated." Any gap triggers reprocessing.

### How Xero's Bank Reconciliation Works

Every imported transaction must be matched or categorized. Invisibility is impossible by design.

### The Coverage Invariant

> For every record R matching business criteria for period P, there MUST exist a corresponding entry in the log table for period P.

---

## Prevention Checklist

- [ ] Document entry criteria: "Which source records will this pipeline see?" — verify 100% coverage
- [ ] Add reconciliation: count source records vs processed records, alert on discrepancy
- [ ] For records that can lose dependencies, ensure visibility through an alternative path
- [ ] Pipeline entry = the authoritative source (charges), not a derivative (tickets)
- [ ] Test: "What happens with zero children?" — if invisible, that's a design gap