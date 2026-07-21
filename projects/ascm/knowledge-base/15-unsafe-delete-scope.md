# 15 — Unsafe Delete Scope for Re-Runs

> **TL;DR:** Re-running the batch for March could wipe April's data because the DELETE used `created_at` (when written) instead of `target_ym` (which period it belongs to). Fix: always delete by business key, never by timestamp.

---

## Problem Pattern

A batch cleans up previous output before re-running. But the DELETE scope is too broad — it removes records from *other* periods too.

---

## How We Encountered It

The cleanup logic used `created_at` or no period filter. After the ASC project restructured the pipeline (daily + monthly feeding shared summary), re-running one command for one month could affect other months in the summary table.

**Status:** Identified. No active fix planned — operational workaround (strict sequential execution) remains in effect. Risk is low given current process discipline.

---

## Root Cause

DELETE scope based on **technical metadata** (created_at) rather than **business keys** (target_ym).

---

## Proposed Fix

```php
// Delete by business key:
LogTable::where('target_ym', $targetYearMonth)->where('service_id', $serviceId)->delete();
```

---

## Industry Standard / Best Practice

### How dbt Handles Incremental Rebuilds

Uses explicit `unique_key` (business key) for MERGE operations. When rebuilding a partition, only rows matching the specified business predicate are affected. The scope is declared, not inferred.

### How Snowflake Partitions Guarantee Isolation

DELETE targets rows by predicate on business columns (e.g. `WHERE report_month = '2026-04'`). Physical storage partitioning reinforces this — you literally cannot accidentally touch another month's data without explicitly referencing it.

### How Laravel's Soft Deletes Provide Safety Nets

`SoftDeletes` trait means records are never truly gone. Even if the wrong scope fires, `withTrashed()` can recover them. For financial systems where reversibility matters, soft deletes add a recovery layer that hard deletes cannot.

### How Airflow's Backfill Works

When re-running a past DAG execution, Airflow only clears task instances for that specific `execution_date`. Other dates' task instances are untouched because the scope is explicitly bound to the run's logical date.

### The Scope Invariant

> The DELETE scope must be **identical** to the subsequent INSERT scope. If you're about to insert rows for `target_ym = 202604`, you delete only `target_ym = 202604`. Nothing else.

---

## Prevention Checklist

- [ ] DELETE uses business keys (period, tenant) — never timestamps
- [ ] DELETE scope exactly matches subsequent INSERT scope
- [ ] Idempotency tested: re-run period P doesn't affect period P±1
- [ ] Delete + insert wrapped in a single transaction
- [ ] Runbooks document safe re-run order
