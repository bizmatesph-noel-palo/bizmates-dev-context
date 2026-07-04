# 14 — Pre/Final Logic Duplication

> **TL;DR:** Pre (draft) and Final (confirmed) calculations share 95% identical logic but were implemented as separate classes — 2,500 lines duplicated. Every bug fix applied twice. Fix: single implementation parameterized by execution mode.

---

## Problem Pattern

Multiple execution environments perform the same logic but differ in timing, data freshness, or output destination. Logic is duplicated per environment — every fix applied N times.

---

## How We Encountered It

The monthly commands were **new code** that followed the existing Pre/Final pattern from the daily commands — separate classes for Pre and Final.

The differences are small (different source/destination tables, slightly different date windows, Pre skips Freee submission). But the logic — the 700-line CTE, the refund query, the filtering — is identical.

Multiple times, a fix was applied to Final but missed on Pre, discovered days later.

**Status:** Acknowledged as tech debt. Proposed: single `MonthlyRateQueryBuilder` parameterized by mode. No active refactoring planned — current mitigation is a review checklist ensuring changes are applied to both Pre and Final files.

---

## Industry Standard / Best Practice

### How Netflix Manages Preview vs Live

Same evaluation engine. Canary vs production = a property on the execution context. Never separate engines.

### How Airflow Manages Dev/Staging/Prod

One DAG, environment resolves connections/tables. Adding a new environment = adding a config profile.

### The Maintenance Multiplier

2 tenants × 2 environments = 4 copies of every fix. Unsustainable beyond 2 axes.

---

## Prevention Checklist

- [ ] When adding a new execution mode, refactor existing into parameterized version — don't copy
- [ ] Mode differences are configuration, not code paths
- [ ] Track duplication as tech debt with clear refactoring target
- [ ] PR reviews for duplicated paths require explicit confirmation all copies received the change
- [ ] Add "mode parity" test: run both modes on identical input, assert matching output
