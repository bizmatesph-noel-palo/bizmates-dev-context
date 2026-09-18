---
inclusion: auto
---

# Database Standards

> **Scope:** Schema ownership, connections, and conventions for the **allocation tables** (`log_alloc_*`, `mst_alloc_*`, `v_alloc_*`). Bizmates-only — no Zipan.

## Schema Ownership

| Repository | What it owns |
|---|---|
| `ls-database-migrations` | **All** table schemas (CREATE, ALTER). Source of truth. Allocation migrations + structure tests live here. |
| `accounting_related_system_for_freee` | Read/write queries, Eloquent models, the allocation engine. Does NOT own schema. |
| `MBTI_backend` | Where CAP/CIP plans and products originate upstream. Reference only — ASCA does not query it at runtime. |
| `bizmates.jp` | Admin portal, upstream charge writer. Reference only. |

## Connection Usage

| Context | Connection Name | Database | Notes |
|---|---|---|---|
| `accounting_related_system_for_freee` | `mysql` | Bizmates DB | Allocation read + write at runtime |
| `accounting_related_system_for_freee` | `zipan` | Zipan DB | NOT used by allocation |
| `ls-database-migrations` | `bizmates_mysql` | Bizmates DB | Used in migration files (`Schema::connection('bizmates_mysql')`) |
| `ls-database-migrations` | `zipan_mysql` | Zipan DB | NOT used by allocation |

**⚠️ Important:** the connection name differs between repos for the *same* database. Migrations use `bizmates_mysql`; runtime code uses `mysql`. Same DB, different config key.

## Column Type Conventions

Verified against the existing accounting tables (e.g. `log_daily_rate_calculation`) and confirmed for ASCA:

| Kind | Type | Examples |
|---|---|---|
| Money (yen) | **INT** | `reference_price`, `original_amount` (N), `allocated_amount` (P), `sum_n`, `sum_p` |
| Ratio | **DECIMAL(8,6)** | `ratio` |
| Enum-like | **TINYINT** | `bundle_type`, `run_type`, `status`, `product_role`, `channel` |
| Year-month | **CHAR(6)** | `target_ym` (`YYYYMM`) — matches existing log tables |
| PK | **BIGINT UNSIGNED AUTO_INCREMENT** | `id` |
| Timestamps | **DATETIME NOT NULL** | `created_at`, `updated_at` — matches existing log tables |

There is no decimal money and no `adjustment_amount` — allocation overwrites `paid_price` in place rather than sending a delta.

## Table Conventions

Allocation adds **10 tables + 1 view** (see the ls-db migration spec for the full field-level definition):

- `log_alloc_*` — batch-generated (runs, source documents, bundles, bundle charges, groups, prorations, sum calculation, sum history, deliveries)
- `mst_alloc_reference_prices` — master data (effective-dated allocation weights)
- `v_alloc_prorations_active` — view over the active Final run

Notable conventions:
- **Physical FKs** between allocation tables (differs from the older `log_*` tables, which have none) — per the table-prefix ADR.
- **Effective dating** on `mst_alloc_reference_prices` (`effective_from` / nullable `effective_to`) so prices change without code changes.
- **Traceability columns** on `log_alloc_prorations`: `asc_source_table` (which daily log N came from) and `asc_source_id` (row id there), plus `paid_at` snapshot.
- **Unique key** on `log_alloc_source_documents` (`charge_id`, `target_ym`) supporting the snapshot-skip rule.

## Read-Only Tables (allocation reads, never writes)

| Table | What allocation reads |
|---|---|
| `trn_charge` | `plan_id` (detection — the daily log has none), `product_id`, `student_id`, `order_no`, `paid_at`, `contract_type`, `department_id` |
| `log_daily_rate_calculation` | N (`paid_price`) for the Final run — **this row is then overwritten with P** |
| `log_daily_rate_calculation_pre` | Same, for the Preview run |
| `mst_product` | `product_type` mapping |
| `mst_code_change` / `mst_rule_for_journals` | Freee dimension mapping (verification before go-live; allocation itself sends no journals) |

Allocation does **not** read monthly-rate tables, campaign/CDB eligibility tables, or discount-detection tables — there is no basis selection or campaign membership in this design.

## Migration File Naming

In `ls-database-migrations`:

```
YYYY_MM_DD_HHMMSS_create_log_alloc_{table_name}_table.php
YYYY_MM_DD_HHMMSS_create_mst_alloc_reference_prices_table.php
YYYY_MM_DD_HHMMSS_add_foreign_keys_to_alloc_tables.php     # FKs + UKs, AFTER all CREATEs
```

Migrations must use the `bizmates_mysql` connection:

```php
Schema::connection('bizmates_mysql')->create('log_alloc_calculation_runs', function (Blueprint $table) {
    // columns per the migration spec
});
```

The view (`v_alloc_prorations_active`) is managed via the raw-SQL pair in `database/migrations/sql/` (`db:migrate-view-table` / `db:rollback-view-table`), not the schema builder.

Regenerate the table-structure test after any schema change (`generate:table-structure-test --table=...`).

## Eloquent Model Pattern

Models use the **`mysql`** connection (not `bizmates_mysql` — that's the migration repo's name for the same DB) and set `$table` explicitly.

```php
<?php

declare(strict_types=1);

namespace App\Models\RevenueAllocation;

use Illuminate\Database\Eloquent\Model;

class LogAllocCalculationRun extends Model
{
    protected $connection = 'mysql';
    protected $table = 'log_alloc_calculation_runs';
    protected $guarded = ['id'];
}
```

Never infer a table name from the model name — always read `$table` (consistent with the existing `_zipan` suffix inconsistency warning in `multi-tenancy.md`).
