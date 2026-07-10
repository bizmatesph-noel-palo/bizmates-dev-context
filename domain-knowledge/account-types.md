# Account Types (Contract Types)

**Last updated:** 2026-07-10

---

## Contract Type Constants

| Business Term | Code Constant | `contract_type` value | Payment Route | Notes |
|--------------|---------------|----------------------|---------------|-------|
| **B2C** | `CONTRACT_TYPE_PRIVATE` | `0` | Individual → Bizmates | Standard individual student |
| **B2B** | `CONTRACT_TYPE_B2B` | `1` | Company → Bizmates | Corporate-sponsored, company pays |
| **B2E** | `CONTRACT_TYPE_B2B2C` | `2` | Individual → Bizmates | Linked to company/dept like B2B, but individual pays like B2C |
| **B2E Partner** | `CONTRACT_TYPE_B2B2C` | `2` | Individual → Partner Company → Bizmates | Same `contract_type` as B2E, distinguished by `mst_partner_department` |

**Source:** `TrnStudent.php` lines 136–138:
```php
public const CONTRACT_TYPE_PRIVATE = 0;
public const CONTRACT_TYPE_B2B = 1;
public const CONTRACT_TYPE_B2B2C = 2;
```

---

## B2E vs B2E Partner — How to Distinguish

B2E and B2E Partner share the same `contract_type = 2`. The distinction is whether the student's `department_id` exists in `mst_partner_department`.

**Detection method:**
```php
// TrnStudent.php
public function isPartner(): bool
{
    return $this->isB2B2C() && $this->mst_partner_department()->get()->isNotEmpty();
}
```

**Logic:**
- `contract_type = 2` AND `department_id` IS in `mst_partner_department` → **B2E Partner**
- `contract_type = 2` AND `department_id` NOT in `mst_partner_department` → **B2E (standard)**

---

## Partner Companies (from seeder)

| `mst_partner_department.id` | `department_id` | Company Name | Status |
|----|------|------|--------|
| 4 | 1 | 東京インターカレッジコープ | Active |
| 5 | 21 | ベネフィット・ワン | Active |
| 6 | 22 | えらべる倶楽部 | Active |
| 7 | 23 | 株式会社イーウェル | Active |

**Source:** `[MBTI] src/database/seeders/MstPartnerDepartmentTableSeeder.php`

> **Note:** Seeder data may not reflect current production state. As of 2024/07/26, active partners were reported as department_id 21 and 23.

---

## `mst_partner_department` Table Schema

```sql
CREATE TABLE `mst_partner_department` (
    `id` BIGINT PRIMARY KEY,
    `department_id` BIGINT,
    `name` VARCHAR(99) COMMENT '会社名',
    `attention_path` VARCHAR(128) NULL COMMENT '特定部署用の利用規約パス',
    `status` INT DEFAULT 1 COMMENT '0=無効（契約解除）/1=有効（契約中）',
    `created_at` DATETIME,
    `updated_at` DATETIME
);
```

**Source:** `[Migrations] database/migrations/2025_07_03_055626_create_mst_partner_department_table.php`

---

## Related Helper Methods (TrnStudent)

```php
public function isPrivate(): bool    // B2C
public function isB2B2C(): bool      // B2E (includes Partners)
public function isB2B(): bool        // B2B
public function isPartner(): bool    // B2E Partner specifically
```

**Static variants for array context:**
```php
public static function isB2C(?array $student = null): bool
public static function getStudentContractType(?array $student = null): ?int
```
