---
inclusion: auto
---

# Tech Stack

> **Scope:** Describes the host system ASCA lives inside. Allocation code targets this same stack. Where allocation deviates from existing conventions (it uses Eloquent + property tests), it's noted below.

## Core

- **PHP 8.0 / 8.1** with `declare(strict_types=1)` in all new files
- **Laravel 8.x** (`^8.40`) — artisan commands, service container, config, logging
- **MySQL 5.7** (multiple connections — see `multi-tenancy.md`). ASCA is Bizmates-only (`mysql`).
- **Docker** for local development

## Key Libraries

- `freee/freee-accounting-sdk` (2.3) — Freee API client (journal submission)
- `guzzlehttp/guzzle` — HTTP client
- `laravel/framework` (`^8.40`) — core framework
- `phpunit/phpunit` (`^9.3`) — testing

## Architecture Style

This is NOT a standard Laravel web application. It is a **batch processing system**:

- No HTTP controllers (except the OAuth callback for Freee)
- No views / frontend (except the Freee OAuth page)
- Existing business logic lives in artisan commands and their Logic classes
- Existing calculations use heavy raw SQL (CTEs) inside PHP strings — no Eloquent for the core daily/monthly rate paths (performance)
- Eloquent is used for simpler CRUD (models, resources)

### Where allocation fits the stack

- **Allocation uses Eloquent models** (`LogAlloc*`, `MstAlloc*` under `App\Models\RevenueAllocation`) for reads/writes to its own tables — this is the intended pattern, not a violation of the "raw SQL for core calculations" convention (that convention is about the existing rate pipeline).
- Bundle **detection** and the log-table **overwrite** use `DB::table()` query-builder against the daily-rate log — raw-ish, but not string CTEs.
- Allocation adds **no artisan command** and **no HTTP surface** — it injects into existing commands (see `system-overview.md`, `batch-execution-flow.md`).

## Development Commands

```bash
make restart          # Rebuild and start containers
make up               # Start containers (detached)
make down             # Stop containers
make php-root         # Enter PHP container as root
make nginx            # Enter nginx container
```

## Testing

Tests run **inside the Docker container**, via Laravel's test runner. Enter the container first, then run:

```bash
make php-root                              # enter the PHP container
php artisan test                           # run the full suite
php artisan test tests/Unit/RevenueAllocation   # run a directory
php artisan test path/to/TheTest.php       # run a specific test file
php artisan test --filter TestName         # run a specific test by name
```

- Do NOT run the host's `vendor/bin/phpunit` directly — run inside the container so the DB connections and env match.
- Example-based tests: `{Subject}Test.php`
- Property-based tests (allocation invariants — ΣP = ΣN, idempotence): `{Subject}PropertyTest.php`, min 100 iterations (see `coding-standards.md`).
