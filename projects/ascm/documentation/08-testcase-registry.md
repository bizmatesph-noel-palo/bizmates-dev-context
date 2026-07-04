# Testcase Registry (TC001–TC035)

## Overview

35 test cases + 3 overrides (001-A, 003-A, 013-A) validating the monthly rate calculation pipeline. Each test case defines a specific charge scenario with expected output values for `total`, `carried_over`, `taken`, `expired`, `remaining`, and `paid_price`.

**Status:** TC001–TC034 passing. TC035 (ASC-301) deployed to DEV04, QA passed. Awaiting production deployment.

**Source files:** `asc-kiro/Testcases/`

---

## Registry

| TC# | JIRA | Description | Tenant | Category |
|-----|------|-------------|--------|----------|
| TC001 | ASC-149 | Carry-over tickets, 60-day validity, new charge with 0 lessons | Bizmates | Carry-over |
| TC001-A | ASC-149 | Same as TC001 (override with updated AC) | Bizmates | Carry-over |
| TC002 | ASC-151 | B2C FLP → B2B transition mid-contract | Bizmates | Plan transition |
| TC003 | ASC-151 | Zipan monthly plan — no carryover (ticket = contract period) | Zipan | Expiry |
| TC003-A | ASC-151 | Same as TC003 (override with updated AC) | Zipan | Expiry |
| TC004 | ASC-151 | Monthly-15 → B2B refund (same month execution) | Bizmates | Refund |
| TC005 | ASC-151 | Monthly-15 → B2B refund (following month execution) | Bizmates | Refund |
| TC006 | ASC-151 | Cooling-off — lessons taken, same-month execution | Bizmates | Cooling-off |
| TC007 | ASC-151 | Cooling-off — no lessons taken, same-month execution | Bizmates | Cooling-off |
| TC008 | ASC-151 | Cooling-off — lessons taken, cross-month execution | Bizmates | Cooling-off |
| TC009 | ASC-151 | B2C FLP → B2B transition mid-contract (variant) | Bizmates | Plan transition |
| TC010 | ASC-151 | FLP full month → B2B transition, 3 lessons taken | Bizmates | Plan transition |
| TC011 | ASC-151 | FLP full month → B2B transition, 0 lessons taken | Bizmates | Plan transition |
| TC012 | ASC-157 | Expired timing based on ticket expiry date (60-day validity) | Bizmates | Expiry timing |
| TC013 | ASC-157 | B2B REST — remaining expire when contract ends (no renewal) | Bizmates | Expiry |
| TC014 | ASC-211 | B2B order transition — last charge incorrectly treated as 60-day | Bizmates | Last charge |
| TC015 | ASC-211 | B2B order — last charge expiration failure (same pattern) | Bizmates | Last charge |
| TC016 | ASC-205 | Missing carried-over charge ID — only current charge recorded | Zipan | Carry-over |
| TC017 | ASC-203 | Incorrect sales amount in CalculationSummary (aggregation) | Bizmates | Summary |
| TC018 | ASC-244 | Refund record displays incorrect charge ID | Bizmates | Refund identity |
| TC019 | ASC-234 | Last charge double-counted in 3 consecutive months | Bizmates | Ghost rows |
| TC020 | ASC-236 | Partial refund doubled and leaking to subsequent months | Bizmates | Fan-out |
| TC021 | ASC-232 | Zipan — expired data leak (invalid 3rd charge appears) | Zipan | Ghost rows |
| TC022 | ASC-247 | Calculation validation matrix (B2E, B2C, campaign, coaching) | Bizmates | Formula |
| TC023 | ASC-254 | First charge expiration bug — premature expiry | Bizmates | Premature expiry |
| TC024 | ASC-258 | Last charge tickets not expiring (60-day validity overrides) | Bizmates | Last charge |
| TC025 | ASC-260 | Future charge appearing prematurely in current month | Bizmates | Lookahead |
| TC026 | ASC-261 | Carried-over lessons broken after ASC-260 fix (regression) | Bizmates | Regression |
| TC027 | ASC-264 | Charge row processing failure at period boundaries (Zipan + Bizmates) | Both | Boundary |
| TC028 | ASC-266 | 60-day ticket row missing from month N+1 (newer order bug) | Bizmates | FilteredUsage |
| TC029 | ASC-267 | Last charge incorrectly appears in following month (leak) | Bizmates | Ghost rows |
| TC030 | ASC-269 | Refund row missing from monthly CSV (B2C monthly plan) | Bizmates | Refund |
| TC031 | ASC-280 | Orphaned charges — deleted tickets missing from log table | Bizmates | Orphaned |
| TC032 | ASC-283 | Incorrect records (duplicates, over-count, wrong carry-over) | Bizmates | Multiple |
| TC033 | ASC-296 | B2C FLP expiration failure — tickets counted as remaining | Bizmates | FLP expiry |
| TC034 | ASC-297 | Missing row when REST scheduled for following month (orphan) | Bizmates | Orphaned |
| TC035 | ASC-301 | Premature expiry — lookahead fires in April for charge ending May 1-2 | Bizmates | Lookahead expiry |
| TC013-A | ASC-157 | B2B REST expiry — original dates (end_date mid-month, no lookahead) | Bizmates | Expiry (B2B REST) |

---

## Categories

| Category | TCs | What It Validates |
|----------|-----|-------------------|
| Carry-over | 001, 001-A, 016 | Tickets correctly passed to next month |
| Expiry | 003, 003-A, 013, 012 | Tickets expire at correct time |
| Last charge | 014, 015, 024 | Terminal B2B charge fires expiry |
| Plan transition | 002, 009, 010, 011 | FLP → B2B handoff |
| Refund | 004, 005, 018, 030 | Refund rows appear correctly |
| Cooling-off | 006, 007, 008 | Cooling-off refund scenarios |
| Ghost rows | 019, 021, 029 | Dead rows don't leak to next month |
| Fan-out | 020 | JOIN doesn't inflate amounts |
| Lookahead | 025, 035 | Future charges don't appear early / lookahead edge case |
| Boundary | 027 | Period boundary edge cases |
| FilteredUsage | 028 | Expulsion rules don't over-filter |
| Regression | 026 | Fix doesn't break prior behavior |
| Orphaned | 031, 034 | Deleted-ticket charges still visible |
| FLP expiry | 033 | B2C 15-lesson plan specific expiry |
| Formula | 022 | paid_price = (taken + expired) × unit_price |
| Summary | 017 | CalculationSummary aggregation correct |
| Multiple | 032 | Multi-issue validation (ASC-285/286/287) |
| Premature expiry | 023 | Active charges not expired early |
| Expiry (B2B REST) | 013-A | Original ASC-157 dates — expiry in end_date month |

---

## Validation Workflow

1. Run the batch command against DEV04
2. Download generated CSV files
3. For each TC, grep the CSV for the expected charge_id
4. Compare CSV values against the [Expected] section in the TC file
5. Report as PASS/FAIL

No database access needed for simulation — all validation is CSV-based.
