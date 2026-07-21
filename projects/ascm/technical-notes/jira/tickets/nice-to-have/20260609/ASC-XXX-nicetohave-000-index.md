# Nice to Have — Tech Debt Improvements (2026-06-09)

**Type:** Nice to Have / Tech Debt  
**Created:** 2026-06-09  
**Target window:** Wed 06/10 – Thu 06/11

---

## Status

| # | Item | Status | JIRA |
|---|------|--------|------|
| 1 | strict_types on Enum files | ✅ Approved | ASC-290 |
| 2 | `values()` helper on HasEnumHelperTrait | ❌ SKIPPED (risky — changes enum results used by commands) | — |
| 3 | Remove dead `$condition` init | ❌ SKIPPED (risky) | — |
| 4 | Fix `errotMail` config typo | ✅ Approved | ASC-291 |
| 5 | Type hints on `getMonthLastDate` | ✅ Approved | ASC-293 |
| 6 | Type hints on `getSegment2Id` | ✅ Approved | ASC-293 |
| 7 | Replace `exit` in DailyRateCalculationPreLogic | ✅ Approved | ASC-292 |
| 8 | Replace `exit` in DataCorrectionLogic | ✅ Approved | ASC-292 |
| 9 | Remove raw `echo` from SendJournalsDataLogic | ❌ SKIPPED (extremely dangerous — changes command display behavior) | — |
| 10 | DataCorrectionLogic type hints | ❌ SKIPPED (dangerous — changing return types of legacy code) | — |

---

## Grouped JIRA Tickets (4 total, under Epic ASC-289)

| JIRA | Ticket | Title | Items | Branch |
|------|--------|-------|-------|--------|
| ASC-290 | A | `declare(strict_types=1)` on Enum files | 1 | `feature/ASC/ASC-290` |
| ASC-291 | B | Config: errotMail typo alias | 4 | `feature/ASC/ASC-291` |
| ASC-292 | C | Replace exit with exception | 7, 8 | `feature/ASC/ASC-292` |
| ASC-293 | D | Type hints: getMonthLastDate + getSegment2Id | 5, 6 | `feature/ASC/ASC-293` |

---

## Constraints

- No changes to core CTE logic
- No changes to CSV output format
- No changes to paid_price calculations
- Each ticket is isolated and can be merged independently

## Reference

Detailed implementation specs for each item are in this directory (`_001` through `_010`).
