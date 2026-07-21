# 08 — Computation at Report Time vs Storage Time

> **TL;DR:** Refunds processed after the batch ran were invisible in accounting reports because the system computed values at report time instead of storing them when processed. Fix: compute and store at processing time. Reports become read-only views.

---

## Problem Pattern

A system generates reports by querying live data and computing derived values at report generation time. When underlying data changes after the processing window, the report misses it entirely.

---

## How We Encountered It

The ASC project created new monthly commands that needed refund charges in the monthly report. Originally, the plan was to handle refunds within the CTE pipeline. But late-arriving refunds (processed after the batch ran) were invisible because the CTE only processes charges whose tickets exist at batch time.

Additionally, the pre-existing CSV generation code computed refunds on-the-fly at report time rather than storing them. When the ASC project added monthly commands, this pattern was initially inherited.

**JIRA:** ASC-269, ASC-276

---

## Root Cause

Two competing responsibilities in one step:
1. **Detect** which records need processing (query live data)
2. **Materialize** the results for reporting (insert into log table)

Late-arriving records fell outside the detection window but belonged to the prior period.

---

## What We Did

1. **Moved refund computation into batch commands** (ASC-276) — refunds inserted into log table during batch, not at CSV time
2. **Added fallback query** (ASC-269) — catches refunds the main pipeline missed
3. **Reports became read-only** — CSV export = `SELECT * FROM log`

---

## Industry Standard / Best Practice

### How Stripe Handles This

Stripe writes every financial event to an immutable ledger in real-time. Monthly reports are projections over the ledger. A refund on the 7th appears in the correct period because it was stored at write time.

### How Data Warehouses Handle Late-Arriving Facts

Snowflake/BigQuery allow inserts into historical partitions. Load first, transform second.

### The Golden Rule

> **Reports should never compute. They should only read pre-computed, stored results.**

---

## Prevention Checklist

- [ ] Every derived value in a report is materialized in a table during processing — never computed at export
- [ ] Late-arriving records have an explicit catch-up mechanism
- [ ] Batch processing is idempotent — re-running produces the same result without duplicates
- [ ] Report generation code contains zero business logic — it reads, formats, outputs
- [ ] Period membership determined by business date (charge_date), not processing date (created_at)
