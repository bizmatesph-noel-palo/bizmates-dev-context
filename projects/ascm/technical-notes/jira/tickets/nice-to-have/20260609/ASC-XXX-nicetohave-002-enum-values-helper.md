# ASC-XXX: Add `values()` Helper to `HasEnumHelperTrait`

**Epic:** Nice to Have / Tech Debt  
**Scope:** Small (8-10 lines)  
**Difficulty:** 1  
**Files:** `app/Traits/HasEnumHelperTrait.php`, `app/Contracts/MonthlyPlanEnumInterface.php`

---

## Context

Call sites use `BizmatesMonthlyPlanEnum::toArray()` inside `whereNotIn()` and `in_array()`. But `toArray()` returns `['CASE_NAME' => 16, ...]` (keyed by name). Consumers actually need just the flat list of product IDs. A dedicated `values()` method makes intent explicit.

---

## Steps

### File 1: `app/Contracts/MonthlyPlanEnumInterface.php`

**Before (full file):**
```php
<?php

namespace App\Contracts;

interface MonthlyPlanEnumInterface
{
    /**
     * Checks if a given product ID corresponds to a valid monthly plan.
     *
     * @param int|null $productId The product ID to validate.
     * @return bool True if the product ID exists in this enum, false otherwise.
     */
    public static function exists(?int $productId = null): bool;

    /**
     * Returns an associative array of name => value.
     *
     * @return array<string, int> An array where keys are case names and the values are the product IDs.
     */
    public static function toArray(): array;
}
```

**After:**
```php
<?php

namespace App\Contracts;

interface MonthlyPlanEnumInterface
{
    /**
     * Checks if a given product ID corresponds to a valid monthly plan.
     *
     * @param int|null $productId The product ID to validate.
     * @return bool True if the product ID exists in this enum, false otherwise.
     */
    public static function exists(?int $productId = null): bool;

    /**
     * Returns an associative array of name => value.
     *
     * @return array<string, int> An array where keys are case names and the values are the product IDs.
     */
    public static function toArray(): array;

    /**
     * Returns a flat array of product ID values (no keys).
     *
     * @return array<int, int>
     */
    public static function values(): array;
}
```

### File 2: `app/Traits/HasEnumHelperTrait.php`

**Add after the existing `toArray()` method:**

```php
    /**
     * Returns a flat array of enum values (product IDs).
     *
     * @return array<int, int>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
```

**Full file after change:**
```php
<?php

namespace App\Traits;

trait HasEnumHelperTrait
{
    /**
     * Checks if a given product ID corresponds to a valid monthly plan.
     *
     * @param int|null $productId The product ID to validate.
     * @return bool True if the product ID exists in this enum, false otherwise.
     */
    public static function exists(?int $productId = null): bool
    {
        if ($productId === null) {
            return false;
        }

        return self::tryFrom($productId) !== null;
    }

    /**
     * Returns an associative array of name => value.
     *
     * @return array<string, int> An array where keys are case names and the values are the product IDs.
     */
    public static function toArray(): array
    {
        return array_combine(
            array_column(self::cases(), 'name'),
            array_column(self::cases(), 'value')
        );
    }

    /**
     * Returns a flat array of enum values (product IDs).
     *
     * @return array<int, int>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
```

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/Enums/
```

Optionally add a quick assertion in the existing enum tests:

```php
$this->assertEquals([16, 17, 18], ZipanMonthlyPlanEnum::values());
```

No existing call sites need to change — this is purely additive. Future PRs can migrate `::toArray()` usages to `::values()` where appropriate.
