# ascm — Project Context

> Load this at the start of each session for ASC Monthly Plans project context.
> All project rules are in this file. Follow them exactly.
> If context gets compacted, re-read this file before continuing.

---

## Workspace Overview

| Directory | What it is |
|-----------|-----------|
| `accounting_related_system_for_freee` | **Main project (ASC).** Laravel batch system that calculates monthly/daily rate calculations, generates CSVs, and sends accounting data to Freee. |
| `bizmates.jp` | **Admin Portal (Legacy).** FuelPHP monolith — handles student enrollment, B2B/B2E changes, refund processing, and the charge batch. |
| `MBTI_backend` | **Student Portal Backend.** Laravel + GraphQL API serving MyBizmates (Bizmates and Zipan). Students buy plans, book lessons, request refunds. |
| `ls-database-migrations` | **Database Migrations (standalone).** Source of truth for all table structures. |
| `bizmates-dev-context/projects/ascm` | **Dev workspace.** Test cases, reports, documentation. |

---

## The Accounting System

### What It Does

- Runs batch commands (artisan) monthly to calculate revenue recognition
- Separates charges into **daily rate** (pro-rata by calendar days) and **monthly rate** (by lesson consumption)
- Generates CSV reports sent to Freee for journal entries
- Handles both **Bizmates** (mysql connection) and **Zipan** (zipan connection) tenants

### Key Commands

| Command | Purpose |
|---------|---------|
| `DailyRateCalculationPreCommand` | Pre (速報) — daily + monthly calculation, generates preliminary CSVs |
| `MonthlyRateCalculationCommand` | Final — monthly rate CTE calculation only |
| `MonthlyRateCalculationPreCommand` | Pre — monthly rate CTE calculation only |
| `SendJournalsDataCommand` | Final — daily calc + Freee journal sync + balance transition + CSVs |
| `DataCorrectionCommand` | Manual CSV-driven corrections |
| `ClearCalculationLogsCommand` | Cleanup log tables |

### Key Tables

| Table | Purpose |
|-------|---------|
| `log_monthly_rate_calculation` | Monthly lesson consumption data (Final) |
| `log_monthly_rate_calculation_pre` | Same (Pre/速報) |
| `log_daily_rate_calculation` | Daily pro-rata calculation (Final) |
| `log_daily_rate_calculation_pre` | Same (Pre) |
| `log_sum_calculation` | Aggregated summary (feeds CalculationSummary CSV) |
| `trn_charge` | Source of all charges (from student portal / admin) |
| `trn_ticket` | Lesson tickets per student_product |
| `trn_student_product` | Links students to charges and plans |
| `log_refund_history` | Refund linkage (refunded_charge_id → refund_charge_id) |
| `trn_prorated_refund_charge` | Prorated refund data (cooling-off, partial) |

### Monthly Rate CTE Pipeline

```
trn_ticket → TicketMonths (recursive) → MonthlyUsage → FilteredUsage → Grouped → FinalResult
```

The CTE calculates: total, carried_over, taken, expired, remaining, paid_price per charge per month.

After the CTE runs, additional queries are merged before DB insert:
- **Refund query** (ASC-276): fetches monthly-plan charges with paid_price < 0
- **Orphaned charge query** (ASC-280 + ASC-297): catches charges with deleted tickets

### FinalResult Expiry Conditions

The FinalResult CTE determines expired/remaining via CASE with these triggers:
1. `is_last_charge_in_order = 1` — B2B terminal charge
2. `is_last_charge_month = 1 AND charge_in_past = 1 AND max_ticket_end_datetime < DATE_ADD(...)` — B2C/FLP contract end
3. `is_ticket_expiry_month = 1` — ticket validity ends mid-order
4. `has_new_contract_after_refund = 1` — refund with successor

### Multi-Tenancy

- **Bizmates:** mysql connection, BizmatesMonthlyPlanEnum (product_id 16-23, 27-29)
- **Zipan:** zipan connection, ZipanMonthlyPlanEnum (product_id 16-18)
- Both run through the same code path with different DB connections

### Table-to-Connection Mapping (⚠️ Naming Inconsistency)

| Table | Bizmates (`mysql`) | Zipan (`zipan`) | Notes |
|---|---|---|---|
| Daily rate (Final) | `log_daily_rate_calculation` | `log_daily_rate_calculation_zipan` | ⚠️ Has `_zipan` suffix |
| Daily rate (Pre) | `log_daily_rate_calculation_pre` | `log_daily_rate_calculation_pre_zipan` | ⚠️ Has `_zipan` suffix |
| Monthly rate (Final) | `log_monthly_rate_calculation` | `log_monthly_rate_calculation` | ⚠️ NO suffix — same name, different DB |
| Monthly rate (Pre) | `log_monthly_rate_calculation_pre` | `log_monthly_rate_calculation_pre` | ⚠️ NO suffix |

**Rule:** Always verify table names from model `$table` property. Never pattern-match.

---

## Testing & Verification

### How To Run Test Case Simulations

Test cases in `testcases/` contain expected values for specific charge_ids.
CSV files in `generated-files/` contain actual system output.

**Workflow (no DB access needed):**
1. Read the test case `.md` file — find charge_id(s) and expected values in [Expected]
2. Search for that charge_id in the corresponding CSV in `generated-files/`
3. Compare CSV values (total, carried_over, taken, expired, remaining, paid_price) against expected
4. For "NOT present" assertions, confirm charge_id does NOT appear in CSV
5. Report results as PASS/FAIL scorecard

**Important:** We do NOT run SQL, artisan commands, or connect to any database during simulations.

### Test Case Simulation Levels

| Level | Command | What it runs |
|---|---|---|
| **Smoke** | "Run smoke test" | Execute batch command locally, check logs for errors |
| **Unit** | "Run test case simulation" | Only the specific TC for the change |
| **Functional** | "Run functional test case simulation" | Target TC + related TCs sharing same code path |
| **Acceptance** | "Run full test case simulation" | Entire active suite (use -a overrides, skip non-a) |

### Smoke Test (Manual)

```bash
make php-root
php artisan command:MonthlyRateCalculationCommand {exeDate}
tail -30 storage/logs/laravel.log | grep -E "ERROR|FAILED|COMPLETED"
```

**Pass:** `DATA CREATION COMPLETED SUCCESSFULLY!`
**Fail:** SQL error, PHP error, or `EXECUTION FAILED!`

---

## Recent Work

| JIRA | What | Status |
|------|------|--------|
| ASC-254–267 | Monthly CTE fixes (expiry, carry-over, filtering) | ✅ Deployed |
| ASC-276 | Move refund logic into monthly commands | ✅ Deployed |
| ASC-280 | Orphaned charges — deleted tickets | ✅ Deployed |
| ASC-285 | NULL order_no premature expiry | ✅ Deployed |
| ASC-287 | 2-day lookahead double-attribution | ✅ Deployed |
| ASC-296 | FLP expiry boundary fix | ✅ Deployed |
| ASC-297 | Orphaned charge start-month visibility | ✅ Deployed |
| ASC-301 | Premature expiry lookahead | ✅ QA Passed, awaiting decision |
| ASC-304 | PaypalPaymentSum CSV missing monthly data | 🔧 In Progress |

---

## Environment

- **Local:** Docker environment (container: `accounting-system`)
- **DEV04:** Shared test environment with production-like data
- **Production:** No direct DB access — queries via Metabase
- **No direct DB connection in sessions** — data checked via CSV files or manual queries
