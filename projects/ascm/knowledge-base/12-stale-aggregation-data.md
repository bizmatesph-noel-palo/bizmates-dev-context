# 12 — Stale Aggregation Data

> **TL;DR:** Re-running the batch added new summary rows without removing old ones. Aggregation doubled because both runs' rows coexisted. Fix: delete-and-reinsert within a transaction (clear-and-rebuild).

---

## Problem Pattern

A batch computes aggregated summaries and stores them. On re-run, old summaries aren't cleaned up. New + old = inflated totals.

---

## How We Encountered It

The `log_sum_calculation` table aggregates from daily and monthly log tables. This summary became critical when monthly plans were excluded from daily — monthly results had to merge back.

On re-run, old summary rows remained. The aggregation summed both old and new, doubling amounts.

**JIRA:** ASC-203

---

## Root Cause

No cleanup before computing new summaries. The code assumed single execution per period.

---

## What We Did

Added clear-and-rebuild within a transaction:

```php
DB::transaction(function () use ($targetYm, $newSummary) {
    LogSumCalculation::where('target_ym', $targetYm)->delete();
    LogSumCalculation::insert($newSummary);
});
```

---

## Industry Standard / Best Practice

### How dbt Handles Incremental Idempotency

Uses `unique_key` to MERGE. Second run updates, doesn't duplicate.

### How Looker's PDTs Work

Builds new table, then atomically swaps names. Old + new never coexist.

### How Event Sourcing Re-Projects

Materialized views rebuilt from scratch — old view replaced entirely.

### The Idempotency Invariant

> Running the batch N times for the same period must produce the same output as running it once.

---

## Prevention Checklist

- [ ] Every batch has explicit cleanup that removes/supersedes prior output
- [ ] Cleanup + insertion wrapped in a transaction
- [ ] Idempotency tested: run twice, assert identical output
- [ ] Consider whether summary table is needed — can it be computed from source at read time?
- [ ] If using versioned runs, add periodic cleanup for old versions
