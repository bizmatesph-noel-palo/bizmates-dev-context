# 10 — Source Table Mismatch Between Environments

> **TL;DR:** The Pre (draft) command silently read from the Final table instead of the Pre table. Result: empty reports that looked like "no data" instead of a bug. Fix: make the execution mode an explicit parameter, never inferred.

---

## Problem Pattern

Multiple execution modes (preview/final, staging/prod) produce equivalent results from different data. One mode reads from the wrong source, producing empty results — undetected because the other mode works fine.

---

## How We Encountered It

The Pre command was reading from the Final table (`log_monthly_rate_calculation` instead of `log_monthly_rate_calculation_pre`). Since the Final table was empty at Pre execution time, reports came back blank. This looked like "no data to process" rather than a bug.

**JIRA:** ASC-274 (hotfix)

---

## Root Cause

A refactor unified some shared logic but inadvertently fixed the table name to the Final variant. The execution context (Pre vs Final) was implicit rather than explicit.

---

## What We Did

Made the mode parameter explicit throughout the call chain:

```php
$this->service->calculate(mode: ExecutionMode::PRE);
```

---

## Industry Standard / Best Practice

### How Airflow Manages Environments

DAGs run identically in dev/staging/prod. The environment determines connections and tables via Variables — the task code is the same.

### How Django/Rails Handle This

Connection/table info resolved from a single environment key. A service never hardcodes "which database."

---

## Prevention Checklist

- [ ] Every execution mode is an explicit parameter — never inferred from call order
- [ ] Table names resolved from the mode parameter, not hardcoded
- [ ] Integration tests for *each* mode independently
- [ ] Verify both modes produce expected output after refactoring shared code
- [ ] Empty results trigger a log warning — "zero rows" is suspicious in a system that always has data
