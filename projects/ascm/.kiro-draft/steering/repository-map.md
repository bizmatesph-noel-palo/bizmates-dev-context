---
inclusion: auto
---

# Repository Map

## Workspace Repositories

| Repo | Shorthand | Role for ASC | Access |
|---|---|---|---|
| `accounting_related_system_for_freee` | `[ASC]` | **Primary** — all code changes happen here | Read + Write |
| `ls-database-migrations` | `[Migrations]` | Source of truth for table schemas | Read-only (create migrations here if new tables needed) |
| `bizmates.jp` | `[Admin]` | Upstream — writes charges, tickets, student products | Read-only reference |
| `MBTI_backend` | `[MBTI]` | Upstream — writes charges (student portal PayPal) | Read-only reference |
| `asc-kiro` | `[asc-kiro]` | Working directory — test cases, reports, documentation | Write docs, read TCs |

## Boundaries

| If you need to... | Do it in... | NOT in... |
|---|---|---|
| Modify calculation logic | `[ASC]` app/Libs/ | — |
| Check table/column names | `[Migrations]` database/migrations/ | Don't guess from code |
| Understand how charges are created | `[Admin]` or `[MBTI]` (read-only) | Don't modify upstream |
| Create investigation reports | `[asc-kiro]` Technical_Notes/ | Don't put in `[ASC]` |
| Create test cases | `[asc-kiro]` Testcases/ | — |
| Create new DB tables | `[Migrations]` database/migrations/ | Don't create migrations in `[ASC]` |

## Cross-Reference Format

When referencing files across repos, always prefix with the shorthand:

```markdown
- Code: `[ASC] app/Libs/CommonUtil.php` lines ~2174
- Model: `[ASC] app/Models/TrnCharge.php`
- Schema: `[Migrations] database/migrations/2025_01_15_create_log_table.php`
- Report: `[asc-kiro] Technical_Notes/Issue_Investigation/...`
```
