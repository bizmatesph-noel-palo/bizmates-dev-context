---
inclusion: auto
---

# Batch Execution Flow

> **Scope:** How the existing batch runs, and where allocation fits inside it. ASCA adds **no new command** — it injects into the commands below. (The older ASCH plan of a separate command with its own CSV/email does NOT apply.)

## exeDate Logic

All calculation commands accept an optional `exeDate`. The system ALWAYS processes the **previous month** relative to that date.

| You pass | System processes |
|---|---|
| `2026-05-01` | April 2026 (2026-04-01 ~ 2026-04-30) |
| `2026-06-01` | May 2026 (2026-05-01 ~ 2026-05-31) |
| *(no date)* | Previous month relative to today |

**Important:** Passing `2026-03-01` does NOT process March — it processes February.

## Commands (verified signatures)

Run inside the container (`make php-root`):

```bash
php artisan command:MonthlyRateCalculationPreCommand {exeDate?}
php artisan command:DailyRateCalculationPreCommand {exeDate?}
php artisan command:MonthlyRateCalculationCommand {exeDate?}
php artisan command:SendJournalsDataCommand {exeDate?} {no_send_flag?} {no_dailyratecalculation_flag?}
php artisan command:DataCorrectionCommand
php artisan logs:clear-calculations {date}          # note: no "command:" prefix; date required
```

`SendJournalsDataCommand` flags are useful when testing allocation:
- `no_send_flag=1` — run the full pipeline but do NOT send to Freee
- `no_dailyratecalculation_flag=1` — skip creating daily-rate records

## Command Sequence

```
Normal monthly cycle:
─────────────────────
1. MonthlyRateCalculationPreCommand   → _pre tables
2. DailyRateCalculationPreCommand     → _pre tables + Pre CSVs   ← allocation runs here (Preview)

   (QA / verification)

3. MonthlyRateCalculationCommand      → production log tables
4. SendJournalsDataCommand            → daily calc + Freee sync + Final CSVs  ← allocation runs here (Final)
```

## Where Allocation Injects

| Host command | Injection site | Call | Scope |
|---|---|---|---|
| `DailyRateCalculationPreCommand` | `CommonUtil::createDailyRateCalculation()` | `allocate($targetYm, preFlg: true)` | Full month, `_pre` table |
| `SendJournalsDataCommand` | `CommonUtil::createDailyRateCalculation()` | `allocate($targetYm, preFlg: false)` | Full month, production table |
| `DataCorrectionCommand` | `DataCorrectionLogic::createDailyRateCalculation()` | `allocateForCharge($chargeId, $targetYm)` | One corrected charge only |

Allocation runs **between** writing N to the daily-rate log and building the sum — so the sum, Freee journals, CSVs, and balance transition all inherit the allocated (P) values automatically. Monthly rate calculation is untouched.

**Failure isolation:** the call is wrapped in try/catch. If allocation fails, the log keeps N (today's behavior), the batch continues, and the run is marked Failed in `log_alloc_calculation_runs`.

## Pre vs Final

| Aspect | Pre (速報) | Final (確定) |
|---|---|---|
| Target tables | `log_*_pre` | `log_*` (production) |
| When it runs | 1st of month (draft) | 3rd of month (official) |
| CSVs generated | Preliminary | Official — sent to accounting |
| Freee sync | No | Yes (`SendJournalsDataCommand`) |
| Allocation `run_type` | Preview | Final |

## Dependencies

| Command | Must run AFTER |
|---|---|
| `MonthlyRateCalculationCommand` | Nothing — reads source tables directly |
| `SendJournalsDataCommand` | `MonthlyRateCalculationCommand` (needs `log_monthly_rate_calculation` populated) |
| `DailyRateCalculationPreCommand` | Nothing |
| `logs:clear-calculations` | Should run BEFORE re-processing a month |

Allocation has no extra ordering requirement — it runs inside the daily-rate step, and re-runs are safe (idempotent by ΣN).

## Re-Running a Month

1. `php artisan logs:clear-calculations {date}` for the target month
2. Re-run the calculation command(s)
3. Old data is wiped, new data inserted fresh

Allocation is re-run safe on its own too: N = Σ(paid_price) across the bundle is invariant, and source-document snapshots skip when already recorded (see `coding-standards.md` → Idempotency).

## Smoke Test (after an allocation change)

```bash
make php-root
php artisan command:DailyRateCalculationPreCommand {exeDate}
tail -50 storage/logs/laravel.log | grep -E "REVENUE_ALLOCATION|ERROR|FAILED|COMPLETED"
```

- **Pass:** `[REVENUE_ALLOCATION] - END` with no `EXECUTION FAILED!` / ERROR lines.
- **Allocation skipped:** `[REVENUE_ALLOCATION] No bundles found` — expected when the month has no CAP/CIP charges (use the test-data seeder on DEV04).
- **Fail:** `[REVENUE_ALLOCATION] EXECUTION FAILED!` — check the run row in `log_alloc_calculation_runs` for `error_message`.
