# Architecture Patterns — Design Phase Reference

**Context:** Lead Dev's early thinking on ASCH architecture before design.md generation.
**When to use:** Load this when generating design.md for Spec 03 (Pattern 1 Calculation) and Phase 2 specs.

---

## Recommended Pattern Combination: Collector + Pipeline + Strategy

| Layer | Pattern | Responsibility |
|---|---|---|
| `AschProrationCollector` | Collector | Iterates all eligible enrollments, collects all proration results into one result set |
| `AschProrationPipeline` | Pipeline | Fixed 5-stage sequential flow per enrollment |
| `BasisStrategy` | Strategy | Determines M vs L per product (swapped based on discount type) |
| `ProrationStrategy` | Strategy | Determines J/I formula per product (swapped based on plan type) |

## Pipeline Stages (Fixed Order)

```
Stage 1: GroupBuilder      → Build proration groups for the month
Stage 2: BasisResolver     → Determine basis (M or L) per product (strategy selection)
Stage 3: Allocator         → Calculate O = ΣM × (basis / Σbasis)
Stage 4: Prorator          → Calculate P = O × (J / I) (strategy selection)
Stage 5: AdjustmentCalc    → Calculate P − N
```

## Where Pattern Complexity Lives

| Concern | Where it's handled | Not a separate class |
|---|---|---|
| Cross-month contract splitting | GroupBuilder (Stage 1) | — |
| Multiple O values in one month | GroupBuilder (new group detected) | — |
| Plan change / component revision | GroupBuilder (detects new group from revision) | — |
| Month-6 discount detection | BasisResolver (selects HonkiSetDiscountBasis) | — |
| I/J type switching (days vs tickets) | ProrationStrategy selection | DailyProrator vs TicketProrator |
| Termination detection | AschBundleEnrollmentService (enrollment status) | — |
| Negative M / cooling-off | GroupBuilder (includes refund charges) | — |
| Discount priority (50% > 5% > none) | BasisResolver (picks highest-priority strategy) | — |

## Key Insight

Patterns 1-9 are NOT separate code branches. They are **combinations of composable concerns** that cause different strategies to be selected at each pipeline stage. A student can hit multiple patterns simultaneously (e.g., Pattern 3 + 4 = pre-campaign start AND plan change).

## Strategy Interfaces

```php
interface BasisStrategy {
    public function determine(Component $component, Charge $charge): int;
}
// Implementations: HonkiSetDiscountBasis (→ L), NonHonkiDiscountBasis (→ M), NoDiscountBasis (→ L)

interface ProrationStrategy {
    public function calculate(int $oValue, Charge $charge, string $targetYm): int;
}
// Implementations: DailyProrator (days), TicketProrator (tickets consumed)
```

## Why NOT Decorator

Patterns don't "wrap" each other adding layers. They're different execution paths through the same pipeline with different strategy selections. Decorator implies additive behavior — ASCH is selective behavior.

## Phase 2 Spec Grouping (by composable concern)

| Spec | Patterns | What it adds to the pipeline |
|---|---|---|
| 06 | 2 + 3 + 9 | GroupBuilder: cross-month splitting, independent month-6 counting. BasisResolver: discount priority rules. |
| 07 | 4 + 6 | GroupBuilder: revision detection, O recalc on price change. ProrationStrategy: TicketProrator added. |
| 08 | 5 + 7 | Enrollment status: termination detection. GroupBuilder: negative M, partial bundle exit. |
| 09 | 8 | GroupBuilder: cooling-off detection (same-month charge + refund). |
