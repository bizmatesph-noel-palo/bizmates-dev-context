# DEVOPS-6596 — Accounting: add Zipan 20-lesson plan (product_id 38) to monthly-plan enum

## Ticket Info

| | |
|---|---|
| **JIRA** | [DEVOPS-6596](https://bizmates.atlassian.net/browse/DEVOPS-6596) |
| **Type** | Task (DEVOPS — accounting-system maintenance) |
| **Project** | DEVOPS (no ASC project; handled like the ASCM refactor) |
| **Assignee** | Cristoff-san (delegated by Patrick-san) |
| **Reporter** | Noel Palo |
| **Repo** | `accounting_related_system_for_freee` |
| **Related upstream** | ZPR (Zipan Price Revision) — released to production |
| **Effort** | ~0.5 day (1 enum case + test + smoke) |

---

## Summary

The upstream **ZPR** project added a new Zipan **20-lesson monthly plan (`product_id = 38`)**. The accounting system recognizes Zipan monthly plans via `ZipanMonthlyPlanEnum`. Add `product_id 38` to that enum so the new plan is routed through the existing Zipan monthly-rate pipeline. **No computation change** (confirmed: Wu-san via Harvey-san).

## Context

- Zipan monthly plans currently in the enum: 16 (5L), 17 (10L), 18 (15L). Missing: **38 (20L)**.
- `ZipanMonthlyPlanEnum` is the single source of truth — verified: all usages (`ZipanUtil`, `MonthlyRateCalculationLogic`, `MonthlyRateCalculationPreLogic`, the Zipan daily-rate models) call `::exists()` / `::toArray()`. No hardcoded `[16,17,18]` anywhere.
- Product 38 is `product_type = 1` (Skype), `lesson_type = 2` (monthly) → it belongs in the monthly-rate pipeline, same as 16/17/18.
- Zipan-only. No Bizmates impact. Schema/pricing changes live upstream in `ls-database-migrations` seeders — not this repo.

## Implementation (reference for Cristoff-san — not yet applied)

> These are reference snippets for the assignee to apply in the code repo. No code has been changed yet.

**1. Add the enum case** — `app/Enums/ZipanMonthlyPlanEnum.php`, after the 15L case:
```php
case MONTHLY_PLAN_PRODUCT_20LPM_1LPD = 38; // 20 lessons per month, 1 lesson per day (ZPR)
```

**2. Update the test** — `tests/Unit/Enums/ZipanMonthlyPlanEnumTest.php`:

`test_enum_cases_have_correct_values()` — add:
```php
$this->assertSame(38, ZipanMonthlyPlanEnum::MONTHLY_PLAN_PRODUCT_20LPM_1LPD->value);
```

`test_exists_returns_correct_boolean()` — add (18 also worth asserting):
```php
$this->assertTrue(ZipanMonthlyPlanEnum::exists(18));
$this->assertTrue(ZipanMonthlyPlanEnum::exists(38));
```

`test_to_array_returns_correct_mapping()` — the `assertCount(count(...cases()), ...)` line already covers the new case; optionally add:
```php
$this->assertEquals(38, $array['MONTHLY_PLAN_PRODUCT_20LPM_1LPD']);
```

## Running the tests (Docker + Laravel)

Tests run **inside the Docker container** (not the host's `vendor/bin/phpunit`):

```bash
make php-root                                             # enter the PHP container
php artisan test tests/Unit/Enums/ZipanMonthlyPlanEnumTest.php   # run this test file
php artisan test --filter ZipanMonthlyPlanEnum                  # or filter by name
php artisan test                                                # full suite before PR
```

- Run inside the container so DB connections/env match.
- Do NOT run `vendor/bin/phpunit` on the host directly.

## Acceptance Criteria

- WHEN a Zipan charge with `product_id = 38` is processed, THE system SHALL treat it as a monthly plan (skipped in daily-rate, included in the monthly-rate CTE) — identical handling to plans 16/17/18.
- THE `ZipanMonthlyPlanEnum::exists(38)` SHALL return `true`.
- THE unit tests SHALL pass, including the new 38 assertions.
- THE change SHALL affect Zipan only — no change to Bizmates behaviour.
- THE existing plans (16/17/18) SHALL continue to behave unchanged.

## Verification

- Run `tests/Unit/Enums/ZipanMonthlyPlanEnumTest.php` — all pass.
- Smoke: after ZPR seeders exist on DEV04, run the monthly-rate batch for Zipan for a period containing a product-38 charge; confirm it lands in `log_monthly_rate_calculation` (not daily) with correct consumption.

## Notes

- Depends on the upstream ZPR seeders (product 38 + plans + pricing) existing in the target DB before the smoke test — but the enum change itself has no dependency and can merge independently.
- No new command, no computation change, no new tables/columns.
