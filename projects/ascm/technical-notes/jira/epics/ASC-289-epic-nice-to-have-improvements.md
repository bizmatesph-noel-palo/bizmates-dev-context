# ASC-289: Nice to Have / Tech Debt — Low-Risk Improvements

## User Story

As a developer maintaining the ASC accounting system, I want to reduce technical debt in utility classes and configuration files so that the codebase is more readable, type-safe, and easier to debug when batch commands fail.

## Current Situation

- Two enum files lack `declare(strict_types=1)` while the third already has it — inconsistency across the same directory.
- Config keys `applicationErrotMail` and `errotMail` contain a typo that has persisted since initial development, making grep-based searches unreliable.
- Two logic classes (`DailyRateCalculationPreLogic`, `DataCorrectionLogic`) call `exit;` on access token failure, which kills the process without Laravel shutdown hooks, proper exit codes, or transaction cleanup.
- Utility methods `getMonthLastDate` and `getSegment2Id` in `CommonUtil` and `ZipanUtil` have no parameter or return type declarations, which limits IDE autocomplete and static analysis coverage.

## Proposed Solution

Address these issues across 4 isolated sub-tickets, each safe to merge independently:

| JIRA | Title | Scope |
|------|-------|-------|
| ASC-290 | Add `declare(strict_types=1)` to Enum files | Micro — 1 line per file |
| ASC-291 | Add correct-spelling aliases for `errotMail` config keys | Small — 4 lines additive |
| ASC-292 | Replace `exit` with `throw RuntimeException` | Small — 3 lines per file |
| ASC-293 | Add type hints to `getMonthLastDate` + `getSegment2Id` | Micro — signature only |

## Constraints

- No changes to core CTE logic (`generateBizmatesQuery`, `generateZipanQuery`, etc.)
- No changes to CSV output format
- No changes to `paid_price` calculations
- Each sub-ticket is isolated — can be merged in any order

## Acceptance Criteria

- [ ] All 4 sub-tickets pass full test suite (`vendor/bin/phpunit`)
- [ ] No behavioral change to batch output or calculation results
- [ ] Each sub-ticket merged to ASC-master via PR with code review

## Reference

Detailed per-item implementation specs: `Tickets/NiceToHave-20260609/`
