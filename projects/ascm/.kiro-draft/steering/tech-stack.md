---
inclusion: auto
---

# Tech Stack

| Component | Version / Tool |
|---|---|
| PHP | 8.1 |
| Laravel | 8 |
| MySQL | 5.7 (no native CTE support — CTEs are raw SQL strings in PHP) |
| Docker | docker-compose v1 (legacy support — ASC-300) |
| Container | `accounting-system` |
| External API | Freee Accounting API (journal sync, OAuth2) |
| HTTP Client | Guzzle |
| Date handling | Carbon |
| ORM | Eloquent (read-only for source tables, raw INSERT for log tables) |
| Testing | PHPUnit (limited), Test Case Simulation via Kiro |
| Static Analysis | None currently (PHPStan Level 5 proposed) |

## Important Constraints

- **MySQL 5.7:** No native WITH (CTE) syntax. All CTEs are written as raw SQL strings inside PHP and executed via `DB::select()`.
- **Laravel 8:** Not the latest — some newer Laravel features are unavailable.
- **No CI/CD for ASC:** Deployment is manual (artisan commands run on DEV04/production).
- **No queue/job system:** Everything is synchronous batch processing.
