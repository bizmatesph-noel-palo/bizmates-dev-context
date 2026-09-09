# ZPR — Project Context

> Load this at the start of each ZPR session.
> Accounting-system scope only. The broader ZPR project (Zipan/backend/frontend) is upstream — see `research/ZPR/`.

---

## What ZPR Is (for us)

**ZPR (Zipan Price Revision)** is an upstream project that expands Zipan's online-lesson catalog from 1 plan (5-lesson) to 4 plans (5/10/15/20-lesson), adds a **new 20-lesson plan (`product_id = 38`)**, revises pricing, and adds self-service plan change. It was released to production for the upstream services.

**Our scope (accounting system):** exactly one change — add the new 20-lesson plan (`product_id = 38`) to `ZipanMonthlyPlanEnum`. Zipan-only. No computation change.

**Handling:** DEVOPS ticket (like the ASCM refactor), **not** a new ASC project. There is no ASCZ.

---

## Key Info

| Item | Value |
|---|---|
| Project code | ZPR (upstream) — our work billed under DEVOPS ([DEVOPS-6596](https://bizmates.atlassian.net/browse/DEVOPS-6596)) |
| Upstream owner | Zipan / shared-platform teams |
| Code repo (our change) | `accounting_related_system_for_freee` |
| Scope | Add product_id 38 to `ZipanMonthlyPlanEnum` (+ test) |
| Tenant | Zipan only (`zipan` connection) — no Bizmates impact |
| Computation change | **None** (confirmed: Wu-san via Harvey-san) |
| Delegated to | Cristoff-san (via Patrick-san) |
| Lead | Noel Palo |

---

## Why This Is the Only Accounting Change

- Product 38 is `product_type = 1` (Skype), `lesson_type = 2` (monthly) → routes through the existing Zipan monthly-rate pipeline.
- `ZipanMonthlyPlanEnum` is the **single source of truth** — verified: all 6 usages call `::exists()` / `::toArray()`, no hardcoded `[16,17,18]` anywhere in the accounting repo.
- Adding case 38 automatically propagates to: daily-rate skip (`ZipanUtil`), monthly CTE + refund + orphaned queries (`MonthlyRateCalculationLogic` / `PreLogic`), CSV generation, and the Zipan daily-rate models.
- All schema + pricing changes live upstream in `ls-database-migrations` seeders — not in the accounting repo.

---

## The Change

`app/Enums/ZipanMonthlyPlanEnum.php`:
```php
case MONTHLY_PLAN_PRODUCT_20LPM_1LPD = 38; // 20 lessons per month, 1 lesson per day
```

`tests/Unit/Enums/ZipanMonthlyPlanEnumTest.php`: add assertions for 38 (`value`, `exists(38)`, `toArray` count/mapping).

---

## Key Documents

| Document | Location |
|---|---|
| Upstream ZPR project spec (verbatim) | `research/ZPR/REF-ZPR-01-project-spec-20260908.md` |
| JIRA grooming (DEVOPS ticket) | `projects/zpr/technical-notes/jira/tickets/` |
| Zipan products reference | `domain-knowledge/plans-and-products.md` |
| Base accounting context (ASCM) | `projects/ascm/project-context.md` |
