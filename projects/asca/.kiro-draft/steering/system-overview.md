---
inclusion: auto
---

# System Overview

The **Accounting Related System for Freee** (`accounting_related_system_for_freee`) is a Laravel-based batch processing system that handles revenue recognition for Bizmates and Zipan online lesson services.

## What It Does

- Runs batch commands (artisan) monthly to calculate revenue recognition
- Separates charges into **daily rate** (pro-rata by calendar days) and **monthly rate** (by lesson consumption)
- Generates CSV accounting reports
- Submits journal entries to the Freee external accounting API
- Generates balance transition files for financial reconciliation

The system processes real money — its output directly feeds into the company's official accounting ledger.

## History

The system originally processed ALL charges using a single daily pro-rata formula. The **ASCM project** (Accounting System Changes — Monthly plans) added a separate consumption-based calculation pipeline for monthly lesson plans. That pipeline is now deployed and stable.

The **ASCH project** (Honki Set) was **cancelled 2026-08-07** before implementation. Its research and engineering standards are reused, but its design (separate command, own journals) does NOT apply here.

The **ASC Allocation Framework** (ASCA / ASCI) is the active work. It splits Coaching charge revenue between the Coaching and App products so Freee journals reflect the correct per-product revenue. Unlike ASCH, it does **not** add a new command or send its own journals — it **injects** into the existing daily-rate batch and **overwrites** the log-table amounts in place (Scenario D + Option 1). Two projects share one framework: **ASCA (CAP**, plans 1016–1027, builds the foundation) and **ASCI (CIP**, plans 1028–1032, reuses it). Bizmates-only. Deadline 2026/12/17, first production run 2027/01/01.

## Key Commands

### Daily/Monthly Rate (existing)

| Command | Purpose |
|---------|---------|
| `DailyRateCalculationPreCommand` | Pre (速報) — daily + monthly calculation, generates preliminary CSVs |
| `MonthlyRateCalculationCommand` | Final — monthly rate CTE calculation only |
| `MonthlyRateCalculationPreCommand` | Pre — monthly rate CTE calculation only |
| `SendJournalsDataCommand` | Final — daily calc + Freee journal sync + balance transition + CSVs |
| `DataCorrectionCommand` | Manual CSV-driven corrections |
| `ClearCalculationLogsCommand` | Cleanup log tables |

### Revenue Allocation (ASCA / ASCI)

Allocation adds **no new command.** It injects into the existing daily-rate batch at two points:

| Host command | Injection | Scope |
|---------|---------|-------|
| `DailyRateCalculationPreCommand` / `SendJournalsDataCommand` | `CommonUtil::createDailyRateCalculation()` → `allocate($targetYm, $preFlg)` | Full month — all CAP/CIP bundles (Pre + Final) |
| `DataCorrectionCommand` | `DataCorrectionLogic::createDailyRateCalculation()` → `allocateForCharge($chargeId, $targetYm)` | Single corrected charge only |

> For command sequencing and Pre/Final lifecycle, see `batch-execution-flow.md`.
> For CSV output details, see `csv-generation.md`.
> For DB design and the full technical design, see:
> `projects/asca/documentation/asc-alloc-db-schema.md`
> `projects/asca/documentation/asc-allocation-framework-technical-design.md`

## Key Tables

### Source Tables (Read-Only — the system never modifies these)

| Table | Purpose |
|-------|---------|
| `trn_charge` | Source of all charges (from student portal / admin) |
| `trn_charge_forex` | PayPal gross amounts (foreign currency transactions) |
| `trn_ticket` | Lesson tickets per student_product |
| `trn_student_product` | Links students to charges and plans |
| `trn_evaluation` | Lesson evaluations (lessons taken — used for monthly rate counting) |
| `trn_prorated_refund_charge` | Prorated refund data (cooling-off, partial) |
| `trn_other_sales_charge` | Non-lesson charges (used in daily rate) |
| `trn_lesson_ticket_history_stat` | Ticket history statistics |
| `mst_product` | Product definitions (lesson_type, lesson_volume, product_type) |
| `mst_department` | Department master (maps to Freee accounts) |
| `mst_rule_for_journals` | Freee journal mapping rules |
| `mst_code_change` | Code change tracking |
| `mst_admin_setting` | Admin settings |
| `mst_mail_template` | Email templates (for notifications) |
| `log_refund_history` | Refund linkage (refunded_charge_id → refund_charge_id) |
| `v_lesson_ticket_history_stat_monthly` | View — monthly ticket statistics |

### Owned Tables (Written by batch commands)

The system owns these log/summary tables. Some existed before ASCM (daily rate, sum calculation); others were added by ASCM (monthly rate).

| Table | Purpose | Connection |
|-------|---------|------------|
| `log_daily_rate_calculation` | Daily pro-rata calculation (Final) | mysql |
| `log_daily_rate_calculation_pre` | Same (Pre) | mysql |
| `log_daily_rate_calculation_zipan` | Daily (Final, Zipan) | zipan |
| `log_daily_rate_calculation_pre_zipan` | Daily (Pre, Zipan) | zipan |
| `log_monthly_rate_calculation` | Monthly lesson consumption (Final) | mysql / zipan (same name, different DB) |
| `log_monthly_rate_calculation_pre` | Monthly (Pre) | mysql / zipan (same name, different DB) |
| `log_sum_calculation` | Aggregated summary (Final, Bizmates) | mysql |
| `log_sum_calculation_pre` | Aggregated summary (Pre, Bizmates) | mysql |
| `log_sum_calculation_zipan` | Aggregated summary (Final, Zipan) | zipan |
| `log_sum_calculation_pre_zipan` | Aggregated summary (Pre, Zipan) | zipan |
| `log_sum_calculation_history` | Summary → proration linkage (Bizmates) | mysql |
| `log_sum_calculation_history_zipan` | Same (Zipan) | zipan |
| `log_send_journals_history` | Freee journal submission log | mysql |
| `log_balance_transition` | Balance transition data | mysql |
| `log_balance_transition_with_order_number` | Balance transition (with order) | mysql |
| `log_freee_invoices` | Freee invoice tracking | mysql |

### Allocation Tables (ASCA — Bizmates only, `mysql` connection)

10 `log_alloc_*` / `mst_alloc_*` tables + 1 view. Batch-generated tables use `log_alloc_*`; master data uses `mst_alloc_*`. This is a roles-only summary — full field-level schema (authoritative): `projects/asca/documentation/asc-alloc-db-schema.md`

| Table | Role |
|-------|------|
| `log_alloc_calculation_runs` | Run lifecycle (status, timing, error) — one row per execution |
| `log_alloc_source_documents` | Immutable snapshot of original N before overwrite |
| `log_alloc_bundles` | Bundle header — one detected Coaching+App pair per run |
| `log_alloc_bundle_charges` | Products within a bundle (2 today: coaching + app) |
| `log_alloc_groups` | One bundle × one month (ΣN, ΣP, is_balanced → V-1) |
| `log_alloc_prorations` | **Core result** — one row per product per group (L, ratio, N, P) |
| `mst_alloc_reference_prices` | Allocation weights (L), effective-dated master data |
| `log_alloc_sum_calculation` | Freee-level aggregation |
| `log_alloc_sum_calculation_history` | Trace: summary row → proration rows |
| `log_alloc_deliveries` | Freee/CSV/email delivery attempt tracking |
| `v_alloc_prorations_active` | View — prorations from the active final run only |

> `bundle_type` (CAP/CIP discriminator) is int-backed TINYINT — renamed+retyped from `project_code` VARCHAR (O-9 — confirmed by Kuroda-san 2026-09-02). CIP coaching reference price 🔴 pending (O-5).

## Environment

- **Local development:** Docker container (`accounting-system`), accessible via `make php-root`
- **DEV04:** Shared test environment with production-like data
- **Production:** No direct DB access — queries run manually via Metabase
- **Freee:** External accounting API (journals sent via SendJournalsDataCommand)
