---
inclusion: auto
---

# Coding Standards

## PHP Standards

- **PSR-12** coding style
- **`declare(strict_types=1)`** in all new/modified files
- **Type hints** on all method parameters and return types
- **Docblocks** on classes and complex methods

## Principles

| Principle | How it applies to ASC |
|---|---|
| **KISS** | SQL conditions should be readable. Document INTERVAL choices with inline comments. Don't over-engineer boundary logic. |
| **DRY** | Acknowledged tech debt: 4-location duplication (Pre × Final × Bizmates × Zipan). Don't make it worse. |
| **Single Responsibility** | Don't grow god classes. CommonUtil.php (2,225 lines) is already too large — don't add more. |
| **Composition over Inheritance** | Prefer standalone helper methods over extending base classes. |

## SQL in PHP Strings

The CTE queries are raw SQL inside PHP double-quoted strings. Special rules:

1. **Never use `"` (double quotes) inside SQL comments** — breaks the PHP string
2. **Document every INTERVAL choice** with an inline comment explaining what time range it covers:
   ```sql
   -- Boundary: 2nd of next month (00:00:00). Covers tickets with end_datetime
   -- up to 23:59:59 on the 1st. Current max in data: 00:59:59.
   AND col < DATE_ADD(LAST_DAY(month_start), INTERVAL 2 DAY)
   ```
3. **Reference the fix ticket** in comments when adding/modifying conditions:
   ```sql
   -- FIX ASC-301: Only fire on the last row for this charge.
   om.rn = om.total_rows
   ```
4. **Use `<=>` for NULL-safe comparisons** (not `=` which fails for NULL values)

## Error Handling

```php
try {
    // business logic
    Log::info('DATA CREATION COMPLETED SUCCESSFULLY!');
} catch (\Exception $e) {
    Log::error('EXECUTION FAILED!');
    Log::error($e->getMessage());
    throw new \RuntimeException($e->getMessage()); // Never use exit()
}
```

## Code Formatting

- Use `throw new \RuntimeException()` instead of `exit` (ASC-292)
- Use `config('key')` with additive aliases for typo fixes (ASC-291)
- Always add `declare(strict_types=1)` when touching Enum files (ASC-290)
