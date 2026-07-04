# ASC Project — Summary & Changelog

## What Is the ASC Project?

The ASC (Accounting System Changes) project added **monthly rate calculation** to the existing accounting batch system. 
Before ASC, all charges were processed using a simple daily pro-rata formula.
The accounting team needed a separate consumption-based calculation for monthly lesson plans.

**Original scope:** "Add a monthly rate report based on lesson consumption."

**Actual scope (what it became):**
1. Build a new monthly rate CTE pipeline (recursive SQL across months)
2. Add monthly log tables (`log_monthly_rate_calculation`, `log_monthly_rate_calculation_pre`)
3. Exclude monthly plans from the existing daily commands (avoid double-counting)
4. Merge monthly results back into the shared summary report
5. Move refund logic from CSV-generation-time to batch-processing-time
6. Handle orphaned charges (tickets deleted before batch runs)
7. Fix 40+ boundary/edge-case bugs discovered during QA and production testing

---

## Why It Was More Complex Than Expected

The system wasn't designed for this. Three factors made it hard:

1. **Tickets carry generic metadata.** All tickets get a 60-day validity window regardless of plan type and student contract. The CTE must recompute real expiry from business rules at runtime — the ticket data alone doesn't tell you when a charge's revenue should be recognized. This is a natural gap that occurs when data created for one purpose (lesson booking) is later consumed by a different system (accounting) with different needs. Neither is wrong — each system was built to its own spec without visibility into future cross-service dependencies.

2. **Ticket deletion removes visibility.** In certain business flows (e.g., B2B→B2E transitions, FLP plan consumption), tickets are physically deleted from `trn_ticket` after they've served their purpose. Since the CTE pipeline uses ticket data to trace back to charges, charges that once had tickets but no longer do become invisible to the main query. Additional queries were added to detect and include these cases separately.

3. **Daily commands already processed monthly plans.** Separating monthly plans from the daily path and giving them their own dedicated calculation pipeline broke the shared summary. A merge-back step was added to keep CalculationSummary totals balanced.

---

## Timeline & Phases

### Initial Build (pre-ASC-149)

**Pre-ASC state:** The accounting system originally processed ALL charges (daily plans and monthly plans alike) using a single daily pro-rata formula: `paid_price × (days_used / days_in_month)`. There was no lesson consumption tracking.

The initial ASC tickets built the foundational monthly rate calculation from scratch:
- Created the recursive CTE pipeline to walk tickets across months
- Added `MonthlyRateCalculationCommand` and `MonthlyRateCalculationPreCommand`
- Created `log_monthly_rate_calculation` and `log_monthly_rate_calculation_pre` tables
- Excluded monthly plans from the existing daily commands to avoid double-counting
- Merged monthly results back into the shared summary report (CalculationSummary)

These tickets delivered the original scope: "Add a monthly rate report based on lesson consumption." The system was functional and about ready for UAT when additional requirements arrived that changed the scope dramatically.

### Code Quality & Existing Issue Fixes (pre-ASC-149)

Alongside the initial build, several tickets addressed existing code issues and introduced code quality improvements:

**Existing issue fixes (local/dev environment):**

| JIRA | What | Impact |
|------|------|--------|
| ASC-57 | Fix Undefined array key issue | Runtime error resolved |
| ASC-106 | Fix error when running SendJournalsDataCommand | Command runs without error |
| ASC-121 | Update the Utility classes | Code maintenance |
| ASC-128 | Fix Undefined array key in ZipanUtil | Runtime error resolved |

**Nice-to-have improvements (no epic):**

| JIRA | What | Impact |
|------|------|--------|
| ASC-134 | Create ServiceName String-Backed Enum and Unit Tests | Type-safe service identification |
| ASC-135 | Refactor CommonUtil to Use ServiceName Enum | Removes magic strings |
| ASC-136 | Refactor ZipanUtil to Use ServiceName Enum | Consistency with CommonUtil |

**Typed Resource / DTO (ASC-158 Epic):**

| JIRA | What | Impact |
|------|------|--------|
| ASC-158 | Epic: Introduce Typed Resource (DTO) for Command Logic Classes | Structured data objects |
| ASC-152 | Create Initializable Interface for Array-Based Object Construction | Foundation interface |
| ASC-153 | Create Reusable Traits for Array-Based Construction and Serialization | Shared trait |
| ASC-154 | Create a Resource (DTO) for Monthly Rate Calculation Data | MonthlyRateCalculationResource |
| ASC-155 | Integrate MonthlyRateCalculationResource into Logic Classes | DTO used in commands |

### 1. Expanded Requirements & Refund Workaround (ASC-149 through ASC-211)

As the system was tested against more diverse student data, additional requirements surfaced — scenarios that weren't part of the original spec but were needed for production accuracy.

Additionally, **ASC-162** addressed refund handling. Due to the complexity of the main CTE query, the tight deadline, and the need for more developers to work on it in parallel, the team decided to place the refund processing logic in the CSV generation step rather than the batch calculation step. The refund data already existed in the database, so generating it at report time saved compute time and avoided further complicating the CTE. This was a deliberate trade-off — it worked but created a gap where late-arriving refunds were invisible (later addressed by ASC-276).

| JIRA | What | Impact |
|------|------|--------|
| ASC-149/151/157 | TicketMonths base case with lookahead window | New charges captured correctly |
| ASC-157/211 | Expiry uses contract end_date, not 60-day ticket window | Correct expiry timing |
| ASC-162 | Refund logic placed in CSV generation (deliberate trade-off) | Refunds visible at report time, not stored in log tables |
| ASC-203 | Clear old log rows before re-run (idempotency) | Re-runs don't duplicate data |
| ASC-205 | Carried-over charges not dropped (Zipan) | Cross-month charges visible |
| ASC-211 | Last charge expiry via contract end_date | Terminal charges expire correctly |

### 2. CTE Boundary Fixes (ASC-232 through ASC-267)

QA testing revealed edge cases at every boundary of the recursive CTE.

| JIRA | What | Impact |
|------|------|--------|
| ASC-232 | Zero-activity historical rows expelled (Zipan) | Ghost rows removed |
| ASC-234 | Last charge double-counted across 3 months | Correct period attribution |
| ASC-236 | Fan-out join inflated SUM(paid_price) by ticket count | ¥12,980 → ¥389,400 fixed |
| ASC-239 | Rounding loss: floor(14107/15) × 15 ≠ 14107 | ¥7 discrepancy fixed |
| ASC-244 | Refund rows carried wrong charge_id | Refunds traceable by own ID |
| ASC-254/258 | `is_last_charge_in_order` via LastChargeWithinOrder CTE | B2B terminal expiry works |
| ASC-260 | Future charges appearing prematurely in current month | Lookahead restricted |
| ASC-261 | Per-month lesson counting upper bound | No double-counting across months |
| ASC-264 | Start-month preservation in FilteredUsage | Newly-started charges not expelled |
| ASC-266 | Mid-order charges preserved (60-day ticket window) | Tickets expire in correct month |
| ASC-267 | Terminal charges expelled after lifecycle ends | No ghost rows in subsequent months |

### 3. Production Hotfixes (ASC-269, ASC-274)

First deployment to production. Immediate issues surfaced with real data. ASC-274 was deployed as a standalone hotfix.

| JIRA | What | Impact |
|------|------|--------|
| ASC-269 | Late refund rows missing from monthly CSV | Refunds visible in reports |
| ASC-274 | Pre command reading from Final table (**hotfix — solo deployment**) | Pre reports not empty anymore |

### 4. Refund & Orphaned Charge Architecture (ASC-276 through ASC-280)

Structural improvements — moving refund logic to batch time and adding orphaned charge detection.

| JIRA | What | Impact |
|------|------|--------|
| ASC-276 | Refund logic moved into batch commands (storage time) | Late refunds no longer invisible |
| ASC-277 | is_payment_in_period DATE boundary fix | Charges on last day of month flagged correctly |
| ASC-280 | Orphaned charge query — catches charges with deleted tickets | 100% charge coverage |

### 5. NULL Safety & Parity Fixes (ASC-285 through ASC-287)

Post-deployment testing revealed issues with NULL handling and cross-boundary lesson attribution.

| JIRA | What | Impact |
|------|------|--------|
| ASC-285 | NULL order_no safe comparison (`<=>` operator) | B2C charges not prematurely expired |
| ASC-286 | Zipan FilteredUsage missing start-month preservation | Parity with Bizmates |
| ASC-287 | Lesson-date upper bound tightened (INTERVAL 2→1 DAY) | No double-attribution across months |

### 6. FLP Plan Expiry Issues (ASC-296, ASC-297)

QA (Miyachi-san) reported B2C FLP (15-lesson plan) charges not expiring correctly.

| JIRA | What | Impact |
|------|------|--------|
| ASC-296 Part 1 | `charge_in_past`: `<` → `<=` | Charges ending on last day of month flagged as past |
| ASC-296 Part 2 | FinalResult expiry: `INTERVAL 1 DAY` → `INTERVAL 2 DAY` | FLP tickets with end_datetime at 00:59:59 on 1st of next month included |
| ASC-297 | Orphaned charge query extended for start-month visibility | Mid-lifecycle orphaned charges visible in start month |

### 7. Tech Debt / Nice-to-Have (ASC-289 Epic)

Low-risk quality improvements bundled into the same release. No behavioral change to batch output.

| JIRA | What | Impact |
|------|------|--------|
| ASC-290 | Add `declare(strict_types=1)` to Enum files | Consistency — third enum file already had it |
| ASC-291 | Fix `errotMail` config key typo (additive alias) | Config keys now grep-friendly |
| ASC-292 | Replace `exit` with `throw RuntimeException` | Proper shutdown hooks, exit codes, transaction cleanup |
| ASC-293 | Add type hints to `getMonthLastDate` + `getSegment2Id` | IDE autocomplete + static analysis coverage |
| ASC-300 | Update Makefile to docker-compose v1 for legacy support | Dev environment works on systems with legacy docker-compose |

---

## What Changed Architecturally

### Before ASC

```
Daily Command → calculates ALL charges (daily formula) → CSV → Freee
```

### After ASC

```
Daily Command → calculates non-monthly charges (daily formula) → CSV → Freee
Monthly Command → calculates monthly-plan charges (consumption formula) → log table
Summary merge → combines daily + monthly into CalculationSummary
```

### Key Architectural Decisions Made During ASC

| Decision | Why | Trade-off |
|----------|-----|-----------|
| Recursive CTE for monthly calculation | Must walk tickets across months to track carry-over | ~700 lines of SQL, hard to debug |
| Separate Refund Query (ASC-276) | Refunds can arrive after batch; CTE can't see them | Additional query merged before INSERT |
| Separate Orphaned Charge Query (ASC-280) | Deleted tickets make charges invisible to CTE | Another additional query |
| Pre/Final as separate files | Followed existing daily command pattern | 2,500 lines duplicated (tech debt) |
| Tenant code duplicated (Bizmates/Zipan) | Followed existing pattern | Every fix applied in 4 locations |

---

## Current State (as of June 2026)

### What's Working

- Monthly rate calculation produces correct results for all 34 test cases
- Both Bizmates and Zipan tenants process correctly
- Refunds, orphaned charges, and FLP plans all handled
- Pre and Final commands produce consistent output
- CSV reports generated and sent to Freee successfully

### Known Tech Debt

| Issue | Severity | Mitigation |
|-------|----------|-----------|
| Pre/Final logic duplicated (2,500 lines) | High | Review checklist ensures both updated |
| Tenant code duplicated (Bizmates/Zipan) | High | PR review checks both paths |
| CommonUtil.php (2,225 lines, global mutable state) | Medium | Single-month processing only |
| No static analysis (PHPStan) | Medium | Manual review |
| No CI/CD pipeline | Medium | Manual testing + testcase simulations |
| No concurrency protection | Low | Cron spacing + team coordination |
| Laravel 8 (EOL) | Low | Functional, upgrade planned separately |

### Branch State

| Branch | Contains | Status |
|--------|----------|--------|
| `ASC-master` | All fixes through ASC-300 | ✅ Deployed to production (2026-06-18) |
| `feature/ASC/ASC-301` | Lookahead premature expiry fix | ✅ Merged to ASC-master, deployed to DEV04, QA passed. Awaiting production deployment. |
| `feature/ASC/ASC-304` | PaypalPaymentSum/PaypalPayment CSV — include monthly rate data | 🔧 Code fix done, awaiting code review. |

---

## Test Coverage

34 test cases (TC001–TC034) covering:
- B2B charges with order succession
- B2B terminal charges (last in order)
- B2C charges with NULL order_no
- FLP (15-lesson) plan expiry
- Refund charges (full and prorated)
- Orphaned charges (deleted tickets)
- Cross-month charges (start in one month, end in another)
- Zipan-specific scenarios

Test validation is done via CSV comparison against expected values defined in test case documents.

---

## Lessons Learned

Documented in the Engineering Knowledge Base (19 articles). Key takeaways:

1. **Incomplete requirements compound investigation effort.** Boundary conditions that weren't explicitly defined in the spec (e.g., `<` vs `<=`, FLP ticket timing) required investigation across multiple test cases and data scenarios to identify and resolve.
2. **Duplication multiplies risk.** The 4x fix factor (Pre × Final × Bizmates × Zipan) means one oversight becomes four bugs.
3. **Pipeline entry point matters.** Starting from tickets instead of charges made orphans invisible by design.
4. **Generic upstream data forces complex downstream logic.** The 60-day ticket window forced a 700-line CTE that would be 10 lines if tickets carried their actual accounting expiry.
5. **Storing computed results at batch time improves reliability.** Moving refund calculation from CSV-generation-time to batch-processing-time (ASC-276) eliminated an entire class of "late refund" invisibility issues and established the pattern used for subsequent features (orphaned charges, etc.).

---

## Release Notes — June 2026

**Release scope:** ASC-276, ASC-277, ASC-280, ASC-285, ASC-286, ASC-287, ASC-296, ASC-297, ASC-290, ASC-291, ASC-292, ASC-293, ASC-300

**QA:** All passed. UAT passed. No regression detected.

**Deployed:** 2026-06-18. Production commands executed successfully.

### Main Features / Enhancements

**ASC-280: Orphaned Charge Recognition (End-Month)**
- Orphaned charges (all tickets deleted) are now captured by a separate query (`generateOrphanedChargeQuery`) that runs after the CTE. Finds paid monthly-plan charges with zero tickets remaining, outputs total=lesson_volume, taken=0, expired=lesson_volume, paid_price=full amount. Recognized in the month the charge's end_date falls in (tickets deleted at contract renewal).

**ASC-276: Refund Logic Moved to Batch Processing**
- Refund charges (paid_price < 0) are now fetched by a separate query (`generateRefundQuery`) and merged into the result set before DB insert.
- Replaces the previous approach of detecting refunds at CSV generation time.

**ASC-277: is_payment_in_period Boundary Fix**
- `is_payment_in_period` uses `DATE_ADD(endDate, INTERVAL 1 DAY)` as upper bound instead of direct DATE comparison, ensuring charges paid on the last day of the month are correctly identified as paid in period.

**ASC-285: NULL-Safe Order Comparison**
- Same-order successor checks now use NULL-safe equality (`<=>`) instead of `=` for `order_no` comparisons. Previously, charges with `order_no = NULL` were treated as terminal (no successor) because `NULL = NULL` is false in SQL, causing premature expiry of remaining lessons instead of carry-over to the next month.

**ASC-286: Zipan FilteredUsage Start-Month Preservation**
- Added start_date month check to Zipan FilteredUsage (port of existing Bizmates ASC-264 fix). Zipan charges starting mid-month with zero lessons were being expelled when a different-order successor existed.

**ASC-287: Lesson Counting Upper Bound Tightened**
- Per-month lesson counting upper bound tightened from `LAST_DAY + 2 DAY` to `LAST_DAY + 1 DAY`. The 2-day lookahead caused lessons on the 1st of the following month to be double-counted across both batch runs (boundary-overlap).
- Lessons are now attributed to the calendar month they occurred in.

**ASC-296: FLP Expiry Failure (Two-Part Fix)**
- Part 1: `charge_in_past` boundary changed from strict `<` to `<=` for Bizmates ChargeData. Charges ending on the last day of the target month (`end_date = endDate`) were not being flagged as "in the past", preventing the `is_last_charge_month` expiry path from firing. This caused B2C FLP (product_id 29) tickets with `order_no NULL` to remain as "remaining" instead of expiring at contract end. Zipan already had `<=` (unaffected).
- Part 2: FinalResult expiry boundary changed from `INTERVAL 1 DAY` to `INTERVAL 2 DAY`. FLP tickets can have `end_datetime` up to `00:59:59` on the 1st of next month (e.g. `2026-05-01 00:59:59` for April). The old boundary (1st at 00:00:00) excluded these; the new boundary (2nd at 00:00:00) includes them correctly.

**ASC-297: Orphaned Charge Recognition (Start-Month)**
- Orphaned charges (tickets deleted after consumption) are now also surfaced in their `start_date` month with remaining=lesson_volume, paid_price=0.
- Previously only recognized in `end_date` month (ASC-280).
- This covers FLP charges mid-lifecycle where tickets are consumed and removed from `trn_ticket`.

### Nice-to-Have / Tech Debt

**ASC-290:** Add `declare(strict_types=1)` to Enum files.

**ASC-291:** Add correct-spelling aliases for `errotMail` config keys.

**ASC-292:** Replace `exit` with `throw RuntimeException`.

**ASC-293:** Add type hints to `getMonthLastDate` + `getSegment2Id`.

**ASC-300:** Update Makefile to use docker-compose v1 and support systems using the legacy version.
