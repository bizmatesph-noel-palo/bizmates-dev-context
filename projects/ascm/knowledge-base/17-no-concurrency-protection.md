# 17 — No Concurrency Protection

> **TL;DR:** Two instances of the same batch can run simultaneously (cron overlap, manual re-run). Both delete and reinsert to the same table, causing duplicates or data loss. Fix: acquire a distributed lock before writing.

---

## Problem Pattern

Batch process reads/writes shared tables. Concurrent instances interfere — both read stale data, both write, resulting in corruption.

---

## How We Encountered It

The ASC batch commands have no mechanism to prevent concurrent execution. Risk scenarios: cron overlap, manual re-run during scheduled run, race conditions in delete-and-reinsert.

**Status:** Proposed fix (Cache::lock / flock), not yet implemented. Risk is low given current cron spacing and manual coordination.

---

## Proposed Fix

```php
$lock = Cache::lock('monthly-rate-calculation', 3600);
if (!$lock->get()) {
    Log::warning('Already in progress, skipping.');
    return self::FAILURE;
}
try { $this->execute(); }
finally { $lock->release(); }
```

---

## Industry Standard / Best Practice

### How Kubernetes CronJobs Handle This

`concurrencyPolicy: Forbid` — the scheduler skips the new run if the previous is still active. `Replace` terminates the old one. Most financial batch jobs use `Forbid` because partial writes from a killed run are dangerous.

### How Laravel's Scheduler Handles This

`->withoutOverlapping(60)` on scheduled commands acquires a cache-based lock. If the lock exists, the command exits immediately. TTL prevents deadlocks if the process crashes. This is the exact pattern we should adopt.

### How PostgreSQL Advisory Locks Work

`pg_advisory_lock(hash)` provides application-level mutual exclusion without table-level locks. MySQL equivalent: `GET_LOCK('name', timeout)`. Both provide process-level exclusion suitable for batch commands.

### How AWS Step Functions Prevent Overlap

State machines have built-in execution tracking. Starting a new execution while one is running can be configured to queue, fail, or replace. The orchestrator owns concurrency — individual tasks don't need to manage it.

### How Sidekiq Unique Jobs Work

The `sidekiq-unique-jobs` gem provides configurable uniqueness: `until_executed`, `until_expired`, `while_executing`. Financial jobs typically use `while_executing` — the job acquires a lock for its duration and rejects duplicates.

### The Pattern

```php
// Laravel implementation:
$lock = Cache::lock('monthly-rate-' . $targetYm . '-' . $serviceId, 3600);
if (!$lock->get()) {
    $this->warn("Batch already running for {$targetYm}. Skipping.");
    return self::FAILURE;
}
try {
    $this->execute();
} finally {
    $lock->release();
}
```

Key design choices:
- Lock key includes the **period and tenant** — different months can run in parallel
- TTL (3600s) prevents deadlocks if process is killed
- Lock released in `finally` for normal completion

---

## Prevention Checklist

- [ ] Every batch that writes shared tables acquires an exclusive lock
- [ ] Locks have TTL to prevent deadlocks if process crashes
- [ ] Failed lock acquisition is logged and alerted
- [ ] Batch designed to be idempotent as defense-in-depth
- [ ] Cron schedules include margin; monitoring alerts if runs exceed expected duration
