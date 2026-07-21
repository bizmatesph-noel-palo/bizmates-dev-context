# ASC-290: Add `declare(strict_types=1)` to Enum Files

## User Story

As a developer working on the ASC accounting system, I want all enum files to use `declare(strict_types=1)` consistently so that type coercion bugs are caught at compile time and the codebase follows a uniform standard.

## Current Situation

`app/Enums/ServiceNameEnum.php` already has `declare(strict_types=1)`. The other two enum files (`BizmatesMonthlyPlanEnum.php`, `ZipanMonthlyPlanEnum.php`) do not. This creates inconsistency within the same directory.

## Proposed Solution

Add `declare(strict_types=1);` after `<?php` in both files.

### File 1: `app/Enums/BizmatesMonthlyPlanEnum.php`

**Before (lines 1–3):**
```php
<?php

namespace App\Enums;
```

**After:**
```php
<?php

declare(strict_types=1);

namespace App\Enums;
```

### File 2: `app/Enums/ZipanMonthlyPlanEnum.php`

Same change — add `declare(strict_types=1);` between `<?php` and `namespace`.

## Acceptance Criteria

- [ ] `app/Enums/BizmatesMonthlyPlanEnum.php` has `declare(strict_types=1)`
- [ ] `app/Enums/ZipanMonthlyPlanEnum.php` has `declare(strict_types=1)`
- [ ] `vendor/bin/phpunit tests/Unit/Enums/` passes
- [ ] Full test suite passes (`vendor/bin/phpunit`)

## Technical Notes

- **Branch:** `feature/ASC/ASC-290`
- **Epic:** ASC-289
- **Estimated time:** 5 minutes
- **Risk:** Zero. PHP enums with `int` backing already reject non-int values at the boundary. The declaration only tightens calling code inside that file, and neither file has any method body beyond the trait delegation.
