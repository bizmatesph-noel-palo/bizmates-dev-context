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

## Release Plan (decided 2026-09-23)

**Release ASCM–ZPR (DEVOPS-6596) together with the ASCM Refactor (DEVOPS-6415).**

- On `deployment/dev04`, 6596 is **stacked on top of** 6415, and both were deployed, executed, and QA-tested there as one combined set. A combined release ships exactly the validated artifact.
- Splitting ZPR out would require rebasing it off 6415 and re-testing an untested combination — more work and risk.
- The combined package **inherits ZPR's hard pre-Oct-1 deadline** (Oct 1 PRE batch). If UAT surfaces a Refactor-side issue late, the **break-glass fallback** is to release ZPR alone to protect Oct 1.
- **Status (2026-09-23):** dev complete, deployed + executed on DEV04, reports to QA; QA testing done; **UAT starts 2026-09-24** (per DSM).

Authoritative schedule + rationale: `docs/asc-projects-master-timeline.md` (Phase 0.1 + Status/Actuals).

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
