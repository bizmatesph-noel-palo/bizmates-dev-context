# Accounting System — System Overview

## What This System Does

The **Accounting Related System for Freee** is a Laravel-based batch processing system that handles revenue recognition for the Bizmates and Zipan online lesson services.

It runs monthly to:
1. Calculate how lesson tickets were consumed (taken, expired, remaining) per student charge
2. Calculate daily pro-rata revenue by calendar days
3. Generate CSV accounting reports
4. Submit journal entries to the Freee external accounting API
5. Generate balance transition files for financial reconciliation

The system processes real money — its output directly feeds into the company's official accounting ledger.

---

## Where It Sits in the Ecosystem

The accounting system sits **downstream** of multiple other systems. It reads data that those systems wrote but has no control over how or when they write it.

```
┌──────────────────────────────┐     ┌─────────────────────────────────────────┐
│  bizmates.jp (Admin Portal)  │     │  Student Portal                         │
│  FuelPHP, ~2014              │     │                                         │
│                              │     │  Main backend:                          │
│  • Bizmates Admin App ──┐    │     │  • MBTI_backend (Laravel + GraphQL)     │
│  • Zipan Admin App ───┐ │    │     │                                         │
│  (separate repos,     │ │    │     │  Microservices:                         │
│   own AWS each)       │ │    │     │  • BCO (Coaching service)               │
│                       │ │    │     │  • NLP API Service                      │
│  Handles:             │ │    │     │  • Other services                      │
│  • Student enrollment │ │    │     │                                         │
│  • Contract changes   │ │    │     │  Handles:                               │
│  • Refund processing  │ │    │     │  • Plan purchases                       │
│  • Charge batch       │ │    │     │  • Lesson booking                       │
│    (auto-renewal +    │ │    │     │  • Rest/refund requests                 │
│     PayPal billing)   │ │    │     │  • PayPal payments                      │
└───────────────────────┼─┼────┘     └──────────────────┬──────────────────────┘
                        │ │                              │
                        │ │                              │ r/w (within their
                        │ │                              │ Bizmates/Zipan context)
       Zipan Admin ─────┘ └───── Bizmates Admin         │
       r/w                       r/w                     │
        │                         │                      │
        ▼                         ▼                      ▼
┌────────────────────────────┐   ┌────────────────────────────┐
│  Zipan Database (MySQL)    │   │  Bizmates Database (MySQL) │
│  (Own server)              │   │  (Own server)              │
│                            │   │                            │
│  • trn_charge              │   │  • trn_charge              │
│  • trn_ticket              │   │  • trn_ticket              │
│  • trn_student_product     │   │  • trn_student_product     │
│  • log_refund_history      │   │  • log_refund_history      │
└──────────────┬─────────────┘   └──────────────┬─────────────┘
               │ reads (zipan connection)         │ reads (mysql connection)
               └────────────────┬─────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────┐
│  Accounting Related System for Freee                        │
│  Laravel 8, ~2021                                           │
│                                                             │
│  • Revenue recognition (monthly + daily)                    │
│  • CSV report generation                                    │
│  • Freee journal submission                                 │
│  • Balance transition files                                 │
└───────────────────────────┬─────────────────────────────────┘
                            │ sends
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Freee (External Accounting API)                            │
│  • Receives journal entries                                 │
│  • Official company ledger                                  │
└─────────────────────────────────────────────────────────────┘
```

**Note on Student Portal services:**
- **BCO (Coaching service):** Supports coaching operations behind the scenes. Direct users are consultants and administrators. Manages sessions (training) that consultants give to students, calculates consultant compensation, etc.
- **NLP API Service:** AI-based API service for all Bizmates services (Bizmates, Zipan, GitTap, GTalent).

---

## Multi-Tenancy

The system supports two separate products:

| Service | DB Connection | Monthly Plan Product IDs |
|---------|--------------|--------------------------|
| **Bizmates** | `mysql` | 16–23, 27–29 |
| **Zipan** | `zipan` | 16–18 |

Key points:
- Bizmates and Zipan have **separate Admin Portals** (bizmates.jp), each running on its own AWS infrastructure with its own repository
- Bizmates and Zipan databases have their own structure on **separate servers**
- **MBTI_backend** (Student Portal Backend) shares the same codebase with context switching between Bizmates and Zipan
- The accounting system connects to both databases (they are not shared)

The accounting system processes each tenant sequentially with different DB connections and product ID enums (`BizmatesMonthlyPlanEnum`, `ZipanMonthlyPlanEnum`).

---

## Batch Commands

All processing is triggered via Laravel artisan commands, scheduled by cron.

| Command | Type | What It Does |
|---------|------|-------------|
| `command:DailyRateCalculationPreCommand` | Pre (速報) | Daily pro-rata calculation + monthly rate calculation. Generates preliminary CSVs for the accounting team to review. |
| `command:SendJournalsDataCommand` | Final (確定) | Daily pro-rata calculation + Freee journal sync + balance transition + final CSVs. This is the authoritative run. |
| `command:MonthlyRateCalculationPreCommand` | Pre | Monthly rate CTE calculation only (no daily, no Freee). Used when only monthly data needs refreshing. |
| `command:MonthlyRateCalculationCommand` | Final | Monthly rate CTE calculation only. Stores results in `log_monthly_rate_calculation`. |
| `command:DataCorrectionCommand` | Manual | Reads correction data from a CSV file and applies adjustments to log tables. |
| `logs:clear-calculations` | Maintenance | Deletes log table entries for a given period. Used before re-runs. |
| `command:TestJournalsDelete` | Test only | Deletes test journal entries from Freee (not for production use). |

**Parameter:** Commands that accept `{exeDate?}` take a date as the 1st day of the target month (e.g., `2026-03-01`). The command uses this to determine the processing period.

### Pre vs Final

- **Pre (速報):** Draft/preliminary. Results go to `_pre` tables. Runs on the **1st day of the month**. Used for internal review before month-end close.
- **Final (確定):** Authoritative. Results go to production tables. Runs on the **3rd business day** of the month (skips weekends/holidays — e.g., if the 3rd falls on a Sunday, it runs on Monday the 4th). Triggers Freee journal submission.

Both use identical calculation logic — only the destination table and whether Freee submission occurs differ.

---

## Two Calculation Methods

### Pre-ASC State (Before the Monthly Rate Calculation Was Added)

Before the ASC project, the system only had two commands:

| Command | What It Did |
|---------|-------------|
| `command:DailyRateCalculationPreCommand` | Pre (速報) — calculated ALL charges using the daily pro-rata formula |
| `command:SendJournalsDataCommand` | Final (確定) — same calculation + Freee journal sync + balance transition |

**All charges** — including monthly lesson plans — were processed with the same simple formula:

```
paid_price × (days_used / days_in_month)
```

The system would:
1. Calculate daily rate for every charge in `trn_charge`
2. Aggregate into summaries
3. Fetch invoice info from Freee
4. Collate (突合) Freee invoices against aggregated calculations
5. Send transfer slips (振替伝票) to Freee

There was no distinction between daily-plan charges and monthly-plan charges. No lesson consumption tracking. No ticket expiry logic. Just pro-rata by calendar days.

### What ASC Added

The accounting team needed a separate calculation for monthly lesson plans — one based on **actual lesson consumption** rather than calendar days. This required:
- New commands: `MonthlyRateCalculationCommand`, `MonthlyRateCalculationPreCommand`
- New tables: `log_monthly_rate_calculation`, `log_monthly_rate_calculation_pre`
- Excluding monthly plans from the existing daily commands (to avoid double-counting)
- Merging monthly results back into the shared summary
- The recursive CTE pipeline to track ticket lifecycle across months

### Current State: Two Formulas

#### Daily Rate (Pro-Rata by Calendar Days)

```
paid_price × (days_used / days_in_month)
```

Simple formula. Applies to charges that aren't monthly lesson plans (one-off purchases, daily plans, etc.).

### Monthly Rate (By Lesson Consumption)

```
paid_price × (tickets_consumed / total_tickets)
```

Complex formula. Requires tracking:
- How many tickets the student started with (total)
- How many carried over from a previous period (carried_over)
- How many lessons were taken this month (taken)
- How many expired unused at contract end (expired)
- How many remain for next month (remaining)

This is implemented as a **recursive CTE pipeline** — the most complex part of the system.

---

## Key Database Tables

### Source Tables (read by the accounting system)

| Table | What It Contains |
|-------|-----------------|
| `trn_charge` | Every charge: student_id, product_id, start_date, end_date, paid_price, order_no, status |
| `trn_ticket` | Lesson tickets: one per bookable lesson slot, linked to a student_product |
| `trn_student_product` | Links a student to a charge and their subscription plan |
| `log_refund_history` | Maps refunded_charge_id → refund_charge_id |
| `trn_prorated_refund_charge` | Prorated/partial refund amounts |

### Output Tables (written by the accounting system)

**Bizmates database (`mysql` connection):**

| Table | What It Contains |
|-------|-----------------|
| `log_monthly_rate_calculation` | Monthly lesson consumption per charge per month (Final) |
| `log_monthly_rate_calculation_pre` | Same (Pre/速報) |
| `log_daily_rate_calculation` | Daily pro-rata per charge per month (Final) |
| `log_daily_rate_calculation_pre` | Same (Pre) |
| `log_sum_calculation` | Aggregated summary combining daily + monthly (Final) |
| `log_sum_calculation_pre` | Same (Pre) |
| `log_sum_calculation_history` | Historical summary snapshots |
| `log_freee_invoices` | Invoice data fetched from Freee |
| `log_balance_transition` | Period-to-period balance movements |
| `log_balance_transition_with_order_number` | Same, grouped by order number |

**Zipan database (`zipan` connection):**

| Table | What It Contains |
|-------|-----------------|
| `log_monthly_rate_calculation` | Monthly lesson consumption per charge per month (Final) |
| `log_monthly_rate_calculation_pre` | Same (Pre/速報) |
| `log_daily_rate_calculation` | Daily pro-rata (Final) |
| `log_daily_rate_calculation_pre` | Same (Pre) |
| `log_sum_calculation` | Aggregated summary (Final) |
| `log_sum_calculation_pre` | Same (Pre) |
| `log_sum_calculation_history` | Historical summary snapshots |
| `log_daily_rate_calculation_zipan` | Zipan-specific daily rate (Final) |
| `log_daily_rate_calculation_pre_zipan` | Zipan-specific daily rate (Pre) |
| `log_sum_calculation_zipan` | Zipan-specific summary (Final) |
| `log_sum_calculation_pre_zipan` | Zipan-specific summary (Pre) |
| `log_sum_calculation_history_zipan` | Zipan-specific historical summary |

### Output Columns (Monthly Rate)

Each row in `log_monthly_rate_calculation` represents one charge in one month:

| Column | Meaning |
|--------|---------|
| `student_id` | The student |
| `charge_id` | The specific charge being tracked |
| `target_ym` | Which month this row represents (e.g., `202604`) |
| `total` | Total lesson tickets for this charge (lesson_volume) |
| `number_of_carried_over_lessons` | Tickets carried from previous month |
| `number_of_lessons_taken` | Lessons actually taken this month |
| `number_of_expired_lessons` | Tickets that expired unused (contract ended) |
| `number_of_remaining_lessons` | Tickets still available for next month |
| `paid_price` | Revenue recognized this month: `unit_price × (taken + expired)` |

Other output tables (`log_daily_rate_calculation`, `log_sum_calculation`, etc.) follow similar structures but with different column sets appropriate to their calculation method. The monthly rate table is the most complex due to the ticket lifecycle tracking.

---

## Generated CSV Reports

The system generates multiple CSV files per batch run. These are packaged into a ZIP and emailed to the accounting team.

**Calculation Reports (core output):**

| CSV | Source | Content |
|-----|--------|---------|
| DailyRateCalculation | `log_daily_rate_calculation` | Daily pro-rata revenue per charge |
| MonthlyRateCalculation | `log_monthly_rate_calculation` | Monthly lesson consumption per charge |
| CalculationSummary (DailyRateCalculationSum) | `log_sum_calculation` | Aggregated totals combining daily + monthly |

**Balance Transition Reports:**

| CSV | Source | Content |
|-----|--------|---------|
| BalanceTransition | Computed from log tables | Period-to-period balance movements |
| BalanceTransitionV2 | Computed from log tables | Updated version with cancel list handling |
| BalanceTransitionWithOrderNumber | Computed from log tables | Same, grouped by order number |
| MaeukeUrikakeBalanceTransition | Freee invoices + calculations | 前受金/売掛金 (advance received / accounts receivable) transition |
| MaeukeUrikakeBalanceTransitionWithOrderNumber | Same, by order | Same, grouped by order number |

**Reference / Supporting Reports:**

| CSV | Source | Content |
|-----|--------|---------|
| TrnCharge | `trn_charge` | Raw charge data for the period |
| Ticket | `trn_ticket` | Ticket data for the period |
| SendJournalsHistory | `log_send_journals_history` | Record of journal entries sent to Freee |
| PaypalPayment | Computed from charges | PayPal payment breakdown |
| PaypalPaymentSum | Aggregation | PayPal payment summary |
| ErrorInfo | Runtime | Any errors encountered during processing |

File naming convention: `{target_ym}_{seq}_{ReportType}({YYYYMMDD}).csv`

Example: `202604_03_MonthlyRateCalculation(20260501).csv`

---

## Execution Flow

### Monthly Rate Commands (`command:MonthlyRateCalculationCommand`, `command:MonthlyRateCalculationPreCommand`)

These commands **only** calculate monthly rate data and insert into log tables. No CSV generation, no Freee submission.

```
1. Command starts
2. Determine batch parameters (startDate, endDate, targetYm)
3. For each tenant (Bizmates, then Zipan):
      ├── Run Monthly Rate CTE pipeline
      ├── Run Refund Query
      ├── Run Orphaned Charge Query
      ├── Merge all results
      └── DELETE old rows for target_ym, then INSERT merged results
```

### Daily Rate Pre Command (`command:DailyRateCalculationPreCommand`)

The "all-in-one" Pre command. Runs on the **1st of the month**.

```
1. Daily rate calculation (pro-rata) for non-monthly charges
2. Monthly rate calculation (CTE pipeline) for monthly-plan charges
3. Summary aggregation (combines daily + monthly)
4. CSV file generation (all report types)
```

### Send Journals Command (`command:SendJournalsDataCommand`)

The "all-in-one" Final command. Runs on the **3rd business day** of the month.

```
1. Daily rate calculation (pro-rata)
2. Monthly rate calculation (CTE pipeline)
3. Summary aggregation
4. CSV file generation
5. Submit journal entries to Freee API
6. Generate balance transition file
```

Steps 5 and 6 are exclusive to this command — they only happen on the Final run.

---

## Tech Stack

| Component | Version/Tool |
|-----------|-------------|
| Framework | Laravel 8 (PHP 8.0+) |
| Database | MySQL 5.7 (separate servers per tenant) |
| External API | Freee Accounting SDK 2.3 |
| OAuth | SocialiteProviders (custom FreeeAccounting provider) |
| Local Dev | Docker (docker-compose + Makefile) |
| Testing | PHPUnit 9.3 |

### Code Patterns

| Pattern | Usage |
|---------|-------|
| Int-backed Enums | `BizmatesMonthlyPlanEnum`, `ZipanMonthlyPlanEnum`, `ServiceNameEnum` — product IDs, service identification |
| Resource/DTO | `MonthlyRateCalculationResource` — typed data object for monthly rate log rows |
| Interface + Trait | `MonthlyPlanEnumInterface` + `HasEnumHelperTrait` — shared enum helpers (`exists()`, `toArray()`) |

---

## Environment Setup

| Environment | Purpose | Access |
|-------------|---------|--------|
| Local (Docker) | Dev machine | Each dev has their own |
| DEV04 | Shared test environment | Production-like data, manual queries |
| Production | Live | No direct DB access, deployed via release process |

---

## Related Repositories

| Repository | Role |
|-----------|------|
| `accounting_related_system_for_freee` | This system |
| `bizmates.jp` | Admin portal — creates charges, tickets, manages students |
| `MBTI_backend` | Student portal backend — plan purchases, lesson booking |
| `ls-database-migrations` | Source of truth for all DB table structures |
