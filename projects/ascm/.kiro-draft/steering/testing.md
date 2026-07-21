---
inclusion: manual
---

# Testing & Verification

## Test Case Simulation Levels

| Level | Command | What it runs | Who |
|---|---|---|---|
| **Smoke** | "Run smoke test" | Execute batch command locally, check logs | Manual (user runs) |
| **Unit** | "Run test case simulation" | Specific TC for the change | Kiro (simulation) |
| **Functional** | "Run functional test case simulation" | Target TC + related TCs sharing same code path | Kiro (simulation) |
| **Acceptance** | "Run full test case simulation" | Entire active suite (TC001–TC035, -A overrides, skip non-A) | Kiro (simulation) |
| **Acceptance (all)** | "Run full test case simulation (include non-A)" | Everything including historical variants | Kiro (simulation) |

## Test Case Override Rule

When a `-A` variant exists, it **overrides** the non-A version:
- The `-A` is the active test case
- The non-A is kept for historical reference, skipped during simulation
- Always use the `-A` version when running checks

## How Simulation Works

1. Read the test case `.md` file — find charge_id(s) and expected values in [Expected]
2. Search the corresponding CSV in `DEV04_Generated_Files/` for matching charge_id
3. Compare CSV values (total, carried_over, taken, expired, remaining, paid_price) against expected
4. For "NOT present" assertions, confirm charge_id does NOT appear in CSV
5. Report PASS/FAIL scorecard

**No DB access, no commands** — file comparison only.

## Smoke Test (Manual)

When requested, provide these commands:

```bash
# 1. Enter container
make php-root

# 2. Run command (replace date)
php artisan command:MonthlyRateCalculationCommand {exeDate}
# OR for CSV generation:
php artisan command:SendJournalsDataCommand {exeDate}

# 3. Check logs
tail -30 storage/logs/laravel.log | grep -E "ERROR|FAILED|COMPLETED"
```

**Pass:** `DATA CREATION COMPLETED SUCCESSFULLY!`
**Fail:** SQL error, PHP error, or `EXECUTION FAILED!`

## Test Case Format

```markdown
# [ASC-XXX]
[Description]

[Precondition]
* charge data, dates, plan details

[Steps]
1. Run batch for month X
2. Check output

[Expected]
target_ym,charge_id,total,carried_over,taken,expired,remaining,paid_price
```
