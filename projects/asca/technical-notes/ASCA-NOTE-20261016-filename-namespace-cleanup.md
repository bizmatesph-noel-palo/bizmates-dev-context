# Deferred Cleanup — Filename & Namespace Convention Review (Laravel standards)

## Document Info

| | |
|---|---|
| **Document type** | Technical Design |
| **Date** | 2026-10-16 (Created) |
| **Author** | Noel Palo, Lead |
| **Assisted by** | Kiro |
| **Status** | Active — deferred (tech debt) |
| **Audience** | Dev team (ASCA/ASCI), SDM |
| **JIRA** | TBA (to raise) |

---

## 1. Summary

A deliberate, **deferred** cleanup: review the `RevenueAllocation` code against Laravel / project filename and namespace conventions and correct the deviations. Deferred to keep Spec 02 moving; captured here so it is not lost. **Rename/move only — no behavior change, no spec regeneration.**

## 2. Why deferred (not now)

Spec 02c is in coding and 02d just started. The items below are cosmetic (structure/naming) — zero behavioral impact, all green tests. Fixing mid-flight risks churn/merge noise across in-progress branches. Do it as one pass once 02c/02d land.

## 3. Items to review

| # | Item | Current | Target (per convention) |
|---|---|---|---|
| 1 | **Allocation exception classes** not in an `Exceptions/` dir | `app/Libs/RevenueAllocation/ProductTypeMismatchException.php`, `ReferencePriceResolutionException.php`, `UnbalancedGroupException.php` (top level) | Move to `app/Libs/RevenueAllocation/Exceptions/` |
| 2 | **DTO namespacing** — role-based vs concern-based | DTOs co-located with services under `Formula/`, `Persistence/`, `Refund/` | Decide: keep concern-based (Spec 01 precedent) OR split DTOs into a `Data/` sub-namespace — **must be a project-wide decision applied to Spec 01 + 02 together, not piecemeal** |
| 3 | **General filename/namespace audit** | — | Sweep the whole `RevenueAllocation` namespace against Laravel + project `structure.md`/`coding-standards.md` naming (classes, DTOs `*Data`, services, enums) and fix any other deviations |

## 4. Scope & constraints

- **Foundation-wide:** applies to Spec 01 + Spec 02 code together. Doing it on one sub-spec alone creates drift (the thing this cleanup is meant to remove).
- **Rename/move only** — no logic change. Semantic/IDE rename + reference update; `grep` to confirm zero stale references; run `tests/Unit/RevenueAllocation` + Feature tests green.
- **No task-execution / regeneration needed** — structural moves never require it.
- Confirm the DTO-namespacing decision (item 2) with the team before touching code, since it sets a convention.

## 5. Trigger

Schedule after 02c (ASCA-55) and 02d coding land, before/with ASCI reuse of the foundation. Raise a JIRA ticket under the ASCA scaffolding/epic when picked up.

## 6. Cross-Reference

| Document | Relevance |
|---|---|
| `accounting_related_system_for_freee/.kiro/steering/coding-standards.md` | File organization + naming conventions for allocation code |
| `accounting_related_system_for_freee/.kiro/steering/conventions.md` | File placement rules |
| `projects/asca/project-context.md` | Next-actions list references this note |
