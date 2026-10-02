---
inclusion: auto
---

# Multi-Tenancy

## Tenants

| Tenant | DB Connection | Monthly Plan Product IDs |
|---|---|---|
| Bizmates | `mysql` | 16, 17, 18, 19, 20, 21, 22, 23, 27, 28, 29 (`BizmatesMonthlyPlanEnum`) |
| Zipan | `zipan` | 16, 17, 18 (`ZipanMonthlyPlanEnum`) |

Both tenants run through the same existing ASC code path with different DB connections.

## Allocation Scope — Bizmates Only

**Allocation (ASCA / ASCI) is Bizmates-only** and uses exclusively the `mysql` connection. The CAP and CIP bundled plans are Bizmates products, so there is no Zipan variant.

Practical consequences:
- Do NOT add allocation calls to `ZipanUtil` or any `_zipan` code path.
- The allocation tables exist only in the Bizmates database (see `database-standards.md`).
- No `$preFlg` × tenant duplication — one implementation, two run types (Preview / Final).

## Table-to-Connection Mapping (⚠️ CRITICAL)

The Zipan daily and summary tables use a `_zipan` suffix. The Zipan monthly tables do **NOT**. This is a known inconsistency.

**RULE:** Always verify table names from the model's `protected $table` property. NEVER pattern-match from the daily table naming.

| Table | Bizmates (`mysql`) | Zipan (`zipan`) | Notes |
|---|---|---|---|
| Daily rate (Final) | `log_daily_rate_calculation` | `log_daily_rate_calculation_zipan` | ⚠️ Has `_zipan` suffix |
| Daily rate (Pre) | `log_daily_rate_calculation_pre` | `log_daily_rate_calculation_pre_zipan` | ⚠️ Has `_zipan` suffix |
| Monthly rate (Final) | `log_monthly_rate_calculation` | `log_monthly_rate_calculation` | ⚠️ NO suffix — same name, different DB |
| Monthly rate (Pre) | `log_monthly_rate_calculation_pre` | `log_monthly_rate_calculation_pre` | ⚠️ NO suffix |
| Summary (Final) | `log_sum_calculation` | `log_sum_calculation_zipan` | Has `_zipan` suffix |
| Summary (Pre) | `log_sum_calculation_pre` | `log_sum_calculation_pre_zipan` | Has `_zipan` suffix |

Allocation only ever touches the **Bizmates** column of this table.

## Which Tables Allocation Touches

| Table | Access |
|---|---|
| `log_daily_rate_calculation` | **Read + WRITE** — N is read, then `paid_price` is **overwritten with P** (Final run) |
| `log_daily_rate_calculation_pre` | **Read + WRITE** — same, for the Preview run |
| `log_sum_calculation[_pre]` | Not written by allocation — but inherits P, because the existing sum step reads the overwritten log rows |
| `log_monthly_rate_calculation[_pre]` | **Not touched** — monthly rate is outside allocation's scope |
| `log_alloc_*` / `mst_alloc_*` | Allocation's own tables (Bizmates only) |

> **Important:** unlike the older ASCH design (which only *read* the ASC log tables and wrote its own adjustment rows), allocation **writes back into `log_daily_rate_calculation[_pre]`**. That in-place overwrite is the mechanism by which Freee journals, CSVs, and balance transition inherit the allocated values. Allocation reads the **daily** log only — never the monthly one.

Allocation's own tables are documented in `database-standards.md`; detection and overwrite behavior in `backend-patterns.md`.
