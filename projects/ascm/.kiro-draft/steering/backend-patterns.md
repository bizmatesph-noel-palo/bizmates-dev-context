---
inclusion: auto
---

# Backend Patterns

ASC is NOT a standard Laravel application. It has no controllers, no routes, no GraphQL, no API endpoints. It is a batch processing system with its own architecture.

## Architecture

```
Artisan Command (entry point)
    → Logic class (business logic + raw SQL)
        → DB::select() / DB::table()->insert() (data access)
            → Log tables (output)
    → Util class (CSV generation + external API)
        → CSV files (output)
        → Freee API (journal sync)
```

## Key Classes

| Type | Location | Purpose |
|---|---|---|
| Commands | `app/Console/Commands/` | Entry points — parse args, call Logic |
| Logic classes | `app/Libs/*Logic.php` | Core calculation — contains raw SQL CTEs |
| Utility classes | `app/Libs/CommonUtil.php`, `app/Libs/ZipanUtil.php` | CSV generation, Freee API, shared helpers |
| Models | `app/Models/` | Eloquent models (read-only for source data) |
| Enums | `app/Enum/` | `BizmatesMonthlyPlanEnum`, `ZipanMonthlyPlanEnum`, `ServiceNameEnum` |
| Resources/DTOs | `app/Resources/` | `MonthlyRateCalculationResource` (typed DTO for log rows) |

## Patterns in Use

| Pattern | How it's used |
|---|---|
| Raw SQL in PHP strings | CTEs are ~700 lines of SQL inside PHP double-quoted strings |
| Multi-tenant via connection | Same Logic class, different `DB::connection()` per tenant |
| Pre/Final duplication | `*Logic.php` + `*PreLogic.php` — nearly identical, different target tables |
| Post-CTE merge | Main CTE result + refund query + orphaned charge query → merged before INSERT |
| CSV generation in Util | Util classes handle all file output (daily, monthly, summary, PayPal) |

## What NOT to Assume

- No Service layer — Logic classes do everything
- No Repository pattern — direct DB access in Logic classes
- No DI/IoC for Logic — they're called statically or instantiated in Commands
- No REST/GraphQL — purely artisan command-driven
- No queue/job system — synchronous execution only
