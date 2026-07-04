# 18 — Batch Sequencing Dependency

> **TL;DR:** The batch only processes the target month's window. If a previous month was skipped, those records are permanently lost — the next run doesn't catch up. Fix: select "everything not yet processed up to target month" instead of strictly "this month only."

---

## Problem Pattern

A periodic batch assumes it runs every period without gaps. Skipped runs lose data permanently because the next run only looks at its own window.

---

## How We Encountered It

Once monthly plans were excluded from daily commands, the monthly batch became the *only* path for those charges. A skipped monthly run means charges appear *nowhere*.

**Status:** Confirmed operational issue. Mitigated by scheduling discipline — the team ensures no months are skipped. No active fix planned; a monitoring alert would further reduce risk.

---

## Root Cause

Data selection is **point-in-time** (single month) rather than **cumulative** (everything unprocessed). No mechanism detects or recovers from gaps.

---

## Proposed Fix

```php
// Before: strict single-month
$charges = Charge::whereBetween('payment_date', [$start, $end])->get();

// After: everything unprocessed up to target
$charges = Charge::where('payment_date', '<', $nextMonthStart)
    ->whereNotIn('id', fn($q) => $q->select('charge_id')->from('log_monthly_rate_calculation'))
    ->get();
```

---

## Industry Standard / Best Practice

### How Apache Airflow Prevents Skipped Runs

`catchup=True` (default) — when a DAG is unpaused or the scheduler restarts, Airflow automatically creates and runs all missed execution dates in chronological order. This guarantees no gaps in processing, even after outages.

### How Stripe's Billing Engine Handles Gaps

Each subscription tracks a `current_period_end`. When generating the next invoice, Stripe asks "what hasn't been billed since `current_period_end`?" — not "what happened in this calendar month." The high-water mark approach means gaps are impossible by design.

### How Kafka Consumer Groups Work

Consumers track their offset (last successfully processed position). On restart, the consumer picks up from the committed offset — not from "now." Gaps only occur if offsets are explicitly advanced without processing.

### How dbt Incremental Models Handle Late Data

dbt's incremental strategy uses a high-water mark (`max(updated_at)` from the target table). Each run processes everything since the last successful run, regardless of calendar alignment. Skipping a day doesn't lose data — the next run catches up automatically.

### How Financial Close Processes Work

Accounting close procedures require explicit period sign-off. A period cannot be "closed" until all entries are posted. If March wasn't processed, April's close is blocked. This is the "gated sequence" pattern — each period depends on the prior period's completion.

### The High-Water Mark Pattern

```php
// Instead of: "process this specific month"
$lastProcessed = LogTable::max('target_ym');  // e.g. '202603'
$monthsToProcess = $this->getMonthsBetween($lastProcessed, $targetYm);

foreach ($monthsToProcess as $month) {
    $this->processMonth($month);
}
```

---

## Prevention Checklist

- [ ] Batch records a completion marker per successfully processed period
- [ ] Before processing N, verify N-1 completed — catch up or alert
- [ ] Data selection uses "not yet processed" criteria, not strict date window
- [ ] Monitoring alert fires if expected batch hasn't completed by deadline
- [ ] Runbooks document recovery from skipped months
