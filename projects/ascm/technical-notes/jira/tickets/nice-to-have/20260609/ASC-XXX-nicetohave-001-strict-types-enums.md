# ASC-XXX: Add `declare(strict_types=1)` to Enum Files

**Epic:** Nice to Have / Tech Debt  
**Scope:** Micro (1 line per file)  
**Difficulty:** 1  
**Files:** `app/Enums/BizmatesMonthlyPlanEnum.php`, `app/Enums/ZipanMonthlyPlanEnum.php`

---

## Context

`ServiceNameEnum.php` already has `declare(strict_types=1)`. The other two enum files don't. This creates inconsistency and misses the type safety benefit.

---

## Steps

### File 1: `app/Enums/BizmatesMonthlyPlanEnum.php`

**Before (lines 1-3):**
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

**Before (lines 1-3):**
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

---

## Verification

```bash
vendor/bin/phpunit tests/Unit/Enums/
```

All existing enum tests must pass. No behavioral change expected — the enums have `int` backing types which already reject non-int values.
