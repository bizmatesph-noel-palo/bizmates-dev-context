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

## Key Commands

| Command | Purpose |
|---------|---------|
| `DailyRateCalculationPreCommand` | Pre (速報) — daily + monthly calculation, generates preliminary CSVs |
| `MonthlyRateCalculationCommand` | Final — monthly rate CTE calculation only |
| `MonthlyRateCalculationPreCommand` | Pre — monthly rate CTE calculation only |
| `SendJournalsDataCommand` | Final — daily calc + Freee journal sync + balance transition + CSVs |
| `DataCorrectionCommand` | Manual CSV-driven corrections |
| `ClearCalculationLogsCommand` | Cleanup log tables |

## Environment

- **Local development:** Docker container (`accounting-system`), accessible via `make php-root`
- **DEV04:** Shared test environment with production-like data
- **Production:** No direct DB access — queries run manually via Metabase
- **Freee:** External accounting API (journals sent via SendJournalsDataCommand)
