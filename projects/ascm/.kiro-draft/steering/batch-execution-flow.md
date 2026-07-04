---
inclusion: manual
---

# Batch Execution Flow

## exeDate Logic

All batch commands accept an optional `exeDate`. The system ALWAYS processes the **previous month** relative to that date.

| You pass | System processes |
|---|---|
| `2026-05-01` | April 2026 (2026-04-01 ~ 2026-04-30) |
| `2026-06-01` | May 2026 (2026-05-01 ~ 2026-05-31) |
| `2026-07-01` | June 2026 (2026-06-01 ~ 2026-06-30) |
| *(no date)* | Previous month relative to today |

**Important:** Passing `2026-03-01` does NOT process March — it processes February.

## Command Sequence

```
Normal monthly cycle:
─────────────────────

1. MonthlyRateCalculationPreCommand     → Writes to _pre tables
2. DailyRateCalculationPreCommand       → Writes to _pre tables + generates Pre CSVs

   (QA/verification happens here)

3. MonthlyRateCalculationCommand        → Writes to production log tables
4. SendJournalsDataCommand              → Daily calc + Freee sync + Final CSVs
```

## Dependencies

| Command | Depends on | Must run AFTER |
|---|---|---|
| MonthlyRateCalculationCommand | Source data (trn_charge, trn_ticket) | Nothing — reads source tables directly |
| SendJournalsDataCommand | `log_monthly_rate_calculation` having data | MonthlyRateCalculationCommand |
| DailyRateCalculationPreCommand | Source data | Nothing |
| ClearCalculationLogsCommand | Nothing | Should run BEFORE re-processing a month |

## Pre vs Final

| Aspect | Pre (速報) | Final (確定) |
|---|---|---|
| Target tables | `log_*_pre` | `log_*` (production) |
| When it runs | Early in month (draft) | After QA approval (official) |
| CSVs generated | Preliminary | Official — sent to accounting team |
| Freee sync | No | Yes (SendJournalsDataCommand) |

## What Gets Generated (SendJournalsDataCommand)

| CSV File | Source |
|---|---|
| DailyRateCalculation | `log_daily_rate_calculation` |
| MonthlyRateCalculation | `log_monthly_rate_calculation` |
| CalculationSummary | Both daily + monthly (merged) |
| PaypalPaymentSum | `trn_charge` + both log tables |
| Bizmates_PaypalPayment | `trn_charge` + both log tables |
| Zipan_PaypalPayment | `trn_charge` + both log tables |
| BalanceTransition | Freee API data |
| Journal entries | Sent to Freee API |

## Re-Running a Month

1. Run `ClearCalculationLogsCommand` for the target month first
2. Then run the calculation command(s) again
3. The old data is wiped, new data is inserted fresh
