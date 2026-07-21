# ASC Project — Improvements & Tech Debt

## Overview

This section lists all quality improvements, tech debt fixes, and refactoring work the ASC project has contributed to the accounting system — beyond the core monthly rate calculation features. These include existing issue fixes, code quality improvements, typed resources, and planned future enhancements.

---

## Existing Issue Fixes

Issues that existed in the accounting system before the ASC project. Fixed as part of enabling the monthly commands to work correctly in local/dev environments.

| JIRA | What | Status |
|------|------|--------|
| ASC-57 | Fix Undefined array key issue | ✅ Deployed |
| ASC-106 | Fix error when running SendJournalsDataCommand | ✅ Deployed |
| ASC-121 | Update the Utility classes | ✅ Deployed |
| ASC-128 | Fix Undefined array key in ZipanUtil | ✅ Deployed |

---

## Code Quality — ServiceName Enum

Introduced type-safe service identification to replace magic strings throughout the codebase.

| JIRA | What | Status |
|------|------|--------|
| ASC-134 | Create ServiceName String-Backed Enum and Unit Tests | ✅ Deployed |
| ASC-135 | Refactor CommonUtil to Use ServiceName Enum | ✅ Deployed |
| ASC-136 | Refactor ZipanUtil to Use ServiceName Enum | ✅ Deployed |

---

## Code Quality — Typed Resource / DTO (ASC-158 Epic)

Introduced structured data objects (DTOs) for the monthly rate calculation commands, replacing loose array-based data passing.

| JIRA | What | Status |
|------|------|--------|
| ASC-158 (Epic) | Introduce Typed Resource (DTO) for Command Logic Classes | ✅ Deployed |
| ASC-152 | Create Initializable Interface for Array-Based Object Construction | ✅ Deployed |
| ASC-153 | Create Reusable Traits for Array-Based Construction and Serialization | ✅ Deployed |
| ASC-154 | Create a Resource (DTO) for Monthly Rate Calculation Data | ✅ Deployed |
| ASC-155 | Integrate MonthlyRateCalculationResource into Logic Classes | ✅ Deployed |

---

## Low-Risk Improvements (ASC-289 Epic)

Small, isolated quality improvements bundled as a single epic. No behavioral change to batch output.

**Epic:** ASC-289
**Risk:** Low
**Status:** ✅ All deployed to production (2026-06-18)

| JIRA | What | Files Affected |
|------|------|----------------|
| ASC-290 | Add `declare(strict_types=1)` to Enum files | `BizmatesMonthlyPlanEnum.php`, `ZipanMonthlyPlanEnum.php` |
| ASC-291 | Add correct-spelling aliases for `errotMail` config keys | Config files |
| ASC-292 | Replace `exit` with `throw RuntimeException` | `DailyRateCalculationPreLogic.php`, `DataCorrectionLogic.php` |
| ASC-293 | Add type hints to `getMonthLastDate` + `getSegment2Id` | `CommonUtil.php`, `ZipanUtil.php` |
| ASC-300 | Update Makefile to docker-compose v1 for legacy support | `Makefile` |

Detailed specs: `Technical_Notes/Tickets/NiceToHave/NiceToHave-20260609/`

---

## Planned / Future Improvements

Documented proposals not yet assigned a JIRA ticket or pending clarification.

| Item | What | Status |
|------|------|--------|
| EvaluationResult Enum + Filter | Add int-backed enum for `trn_evaluation.result` values, change filter from `IN (0,1,2,3,4)` to `IN (1,2,3,4)` | Documented — pending Accounting team clarification |

Detailed specs: `Technical_Notes/Tickets/TechDebts/`
