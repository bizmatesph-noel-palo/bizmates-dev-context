# Proposal: Monthly Rate CTE Query Builder Refactor

## Status: Future (Phase 2 — after current fixes are stable)

## Problem
The CTE query is duplicated between MonthlyRateCalculationLogic (Bizmates) and
MonthlyRateCalculationPreLogic (Pre), and again between Bizmates/Zipan within each file.
~2,500 lines of near-identical SQL. Every fix must be applied 4 times.

## Proposed Solution
Single `MonthlyRateQueryBuilder` class with named methods per CTE segment.
Bizmates/Zipan differences passed as a tenant parameter (not inheritance).

See full design discussion in session notes.

## Key Decision
- Raw SQL stays (WITH RECURSIVE not supported by Laravel Query Builder)
- Each CTE becomes a named method (~50 lines each)
- Tenant differences parameterized via simple if/config, not abstract classes
- No inheritance — composition approach

## Affected Files
- New: app/Libs/MonthlyRateQueryBuilder.php (or app/Services/Calculation/)
- Modified: MonthlyRateCalculationLogic.php (calls builder instead of inline SQL)
- Deleted: MonthlyRateCalculationPreLogic.php (merged into one class)

## Dependencies
- ASC-276 (refund migration) must be merged first
- ASC-277 (is_payment_in_period) must be merged first
- Orphaned charges fix must be merged first
