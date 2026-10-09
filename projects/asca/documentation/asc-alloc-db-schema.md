# ASC Allocation Framework — Database Schema Reference

## Document Info

| |                                                                                                                                                                                                                                                     |
|---|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Document type** | Database Schema Reference                                                                                                                                                                                                                           |
| **Date** | 2026-09-01 (Created) · 2026-09-16 (Updated for G1 Round-3 / REF-CAP-11: 11 tables incl. `log_alloc_run_anchors` + `superseded_by_run_id`; product_type O-10 resolved 9/9/100; CAP reference prices tax-EXCLUSIVE 3,618 / 18,000 / 36,000; pairing key + `bundle_type` O-9 confirmed) |
| **Author** | Noel Palo, Lead Developer                                                                                                                                                                                                                           |
| **Assisted by** | Kiro                                                                                                                                                                                                                                                |
| **Status** | Active — schema source of truth for ASCA Spec 01 (Foundation)                                                                                                                                                                                       |
| **Audience** | Dev team (migrations in `ls-database-migrations`, models in `accounting_related_system_for_freee`), Kuroda-san (PM)                                                                                                                                 |
| **Based on** | [REF-CAP-04 (Kuroda-san's DB design)](../../../research/CAP/REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md), [Technical design](asc-allocation-framework-technical-design.md), [Table-prefix ADR](ASCA-ADR-20260817-table-prefix-decision.md) |

---

## Purpose

The complete field-level schema for the 11 allocation tables + 1 view. REF-CAP-04 (Kuroda-san) defines the original 10-table set and roles; the 11th table (`log_alloc_run_anchors`, the V-5 lock-only anchor) was added per REF-CAP-11 (Round-3, 2026-09-10). This doc adds the **columns, data types, nullability, keys, and field descriptions** needed to write the migrations (Spec 01a) and models (Spec 01b).

> **⚠️ CIP 3-way notes below are SUPERSEDED (REF-CIP-05, 2026-09-17).** Kuroda-san withdrew proportional allocation for CIP entirely: CIP (1028–1032) now uses **residual-value pricing** — separate, already-priced charges (App ¥3,980; Coaching Intensive ¥71,920 from a new `product_id 10025` `price_flag=3` record; Lesson at its own price) through existing daily pro-ration, **no allocation engine, no proration rows, no 3-way formula**. The R-16 3-way references retained below are historical (they describe the pre-2026-09-17 plan) and do NOT drive the schema. **CAP (1016–1027) is unchanged** — it keeps the engine and this schema. See technical design §1c.

## Conventions

- **Connection:** `mysql` (Bizmates) at runtime; `bizmates_mysql` in migrations. Bizmates-only — no Zipan.
- **Table prefixes (per ADR 2026-08-17):** `log_alloc_*` = batch-generated, `mst_alloc_*` = master data, `v_alloc_*` = view.
- **Money types:** reference prices (L) and paid amounts (N, P) = `INT` (yen), matching the existing `paid_price` column. Ratio = `DECIMAL(8,6)`.
- **Enum columns:** all `TINYINT`, mapped to int-backed PHP enums (`bundle_type`, `run_type`, `status`, `product_role`, `channel`, etc.). Values are `1`-based (`0` = unset). Human-readable strings come from the enum's `label()` method — never stored. Consistent with the existing accounting-system convention (status/type columns are int).
- **Standard columns:** every table has `id BIGINT UNSIGNED AUTO_INCREMENT PK`, `created_at`, `updated_at`. `deleted_at` only where soft-delete is needed.
- **Physical FKs:** allocation tables use real foreign keys between themselves (differs from the older `log_*` tables which have none).

---

## ✅ Confirmed: `project_code` (VARCHAR) → `bundle_type` (TINYINT)

REF-CAP-04 named the CAP/CIP discriminator column `project_code`. **This was changed** (O-9 — confirmed FINAL by Kuroda-san 2026-09-02):

1. **Rename** `project_code` → `bundle_type` — the column reflects **what the data IS** (a CAP-type or CIP-type bundle), not **which project created it** (same principle as the table-prefix ADR).
2. **Retype** VARCHAR → **TINYINT** — for schema consistency with the other enum columns (`run_type`, `run_status`, etc. are all TINYINT). Stored as int (`1`=CAP, `2`=CIP); human-readable `'cap'`/`'cip'` comes from the `BundleType` enum's `label()` method for CSV/Metabase.

This doc uses **`bundle_type` TINYINT** throughout and notes the original (`project_code` VARCHAR) inline for traceability against REF-CAP-04.

**Enum mapping:** `BundleType: int { CAP = 1; CIP = 2; }` with `label()` → `'cap'`/`'cip'`.

---

## Table Overview

| # | Table | Prefix | Role |
|---|---|---|---|
| 1 | `log_alloc_calculation_runs` | `log_` | Run lifecycle — one row per batch execution (preview/final) |
| 2 | `log_alloc_source_documents` | `log_` | Immutable snapshot of original N values before overwrite |
| 3 | `log_alloc_bundles` | `log_` | Bundle header — one detected Coaching+App pair per run |
| 4 | `log_alloc_bundle_charges` | `log_` | Products within a bundle in the split (2 for CAP + CIP 1028; **3 for CIP 1029–1032 — Lesson + coaching + app, per R-16**) |
| 5 | `log_alloc_groups` | `log_` | One bundle × one month (ΣN, ΣP, is_balanced) |
| 6 | `log_alloc_prorations` | `log_` | **Core result** — one row per product per group (L, ratio, N, P). 2 rows (CAP + CIP 1028) or **3 rows (CIP 1029–1032: Lesson + coaching + app, per R-16)** |
| 7 | `mst_alloc_reference_prices` | `mst_` | Allocation weights (L), effective-dated master data |
| 8 | `log_alloc_sum_calculation` | `log_` | Freee-level aggregation |
| 9 | `log_alloc_sum_calculation_history` | `log_` | Trace: summary row → proration rows |
| 10 | `log_alloc_deliveries` | `log_` | Freee/CSV/email delivery attempt tracking |
| 11 | `log_alloc_run_anchors` | `log_` | **V-5 lock-only anchor** — one row per (`bundle_type`, `target_ym`); serializes Final finalizers (REF-CAP-11 B). No `active_run_id`, no FK |
| 12 | `v_alloc_prorations_active` | `v_` | View — prorations from the active final run only |

---

## 1. `log_alloc_calculation_runs`

Run management. One row per batch execution. Persists even if the calculation fails (own commit), so failures are auditable.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `bundle_type` | TINYINT | NO | Enum `BundleType`: 1=CAP, 2=CIP — which bundle family this run processed. *(was `project_code` VARCHAR in REF-CAP-04 — rename+retype confirmed O-9, 2026-09-02)* |
| `target_ym` | CHAR(6) | NO | Target year-month, `YYYYMM` (e.g. `202701`) |
| `run_type` | TINYINT | NO | Enum `RunType`: 0=Preview, 1=Final |
| `status` | TINYINT | NO | Enum `RunStatus`: 0=Creating, 1=Completed, 2=Failed |
| `record_count` | INT | YES | Number of allocations processed (set on finalize) |
| `error_message` | TEXT | YES | Failure reason (set when status=Failed) |
| `started_at` | DATETIME | NO | When the run began |
| `finalized_at` | DATETIME | YES | When the run completed or failed |
| `superseded_by_run_id` | BIGINT UNSIGNED | YES | Self-FK → `log_alloc_calculation_runs.id`. NULL = this is the active run (V-5). A superseded Final points at its successor (REF-CAP-11 B, 2026-09-10) |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

**Keys / rules:** V-5 — only one active Final run per (`bundle_type`, `target_ym`), i.e. exactly one Completed Final with `superseded_by_run_id IS NULL`. Enforced within the finalize transaction via the `log_alloc_run_anchors` lock (not a raw UNIQUE), so it holds even in the empty-set case (REF-CAP-11 B).

---

## 2. `log_alloc_source_documents`

Immutable snapshot of the original N (paid_price) values **before** allocation overwrites them. The audit proof of what the numbers were pre-allocation.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `run_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_calculation_runs.id` |
| `charge_id` | BIGINT UNSIGNED | NO | FK to source `trn_charge.id` (logical) |
| `target_ym` | CHAR(6) | NO | Year-month of the snapshot |
| `product_id` | INT | NO | Product being snapshotted (coaching or app) |
| `original_paid_price` | INT | NO | The N value before overwrite (yen) |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

**Rule:** snapshot skip — do NOT insert if a row already exists for (`charge_id`, `target_ym`). Prevents recording already-allocated values as "original" on re-runs (technical design §9).

---

## 3. `log_alloc_bundles`

Bundle header — one row per detected Coaching+App pair per run.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `run_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_calculation_runs.id` |
| `bundle_type` | TINYINT | NO | Enum `BundleType`: 1=CAP, 2=CIP *(was `project_code` VARCHAR)* |
| `student_id` | BIGINT UNSIGNED | NO | Student who owns the bundle |
| `order_no` | VARCHAR(64) | YES | Order number — part of the bundle grouping key |
| `plan_id` | INT | NO | The CAP/CIP plan_id (1016–1027 or 1028–1032) |
| `primary_charge_id` | BIGINT UNSIGNED | NO | The coaching charge (bundle anchor) |
| `match_rule` | VARCHAR(32) | NO | How the bundle was detected (e.g. `student_order_no_plan` when `order_no` present, or `student_plan_dates` for the NULL-`order_no` date-matched fallback — REF-CAP-11 A) |
| `bundle_status` | TINYINT | NO | 0=complete (coaching+app both present). Non-zero = incomplete (V-3 warning) |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

**Grouping key (REF-CAP-11 Round-3 A, 2026-09-10):** (`student_id`, `order_no`, `plan_id`) when `order_no` is present; when `order_no` is NULL (the common case — NULL for B2C and B2E), pair by (`student_id`, `plan_id`, `start_date`, `end_date`) — the coaching charge (10005/10015) and app charge (10022) that share the same `start_date` AND `end_date`. Mismatched dates ⇒ do not guess: mark incomplete and skip (V-3). Isolates each contract (handles cancel+repurchase, simultaneous plans, mid-month renewal → two bundles).

---

## 4. `log_alloc_bundle_charges`

One row per product inside a bundle's split (2 for CAP + CIP 1028: coaching + app; **3 for CIP 1029–1032: Lesson + coaching + app, per R-16 2026-09-08**). Links individual charges to their bundle.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `bundle_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_bundles.id` |
| `charge_id` | BIGINT UNSIGNED | NO | FK to `trn_charge.id` (logical) |
| `product_id` | INT | NO | Coaching (10005/10015/10025) or App (10022) |
| `product_role` | TINYINT | NO | 0=coaching, 1=app — which side of the split. *(A `2=lesson` role was reserved for the former CIP 3-way plan; that plan is **withdrawn — REF-CIP-05, 2026-09-17**, so no Lesson role is needed. The TINYINT is future-proof either way; no schema change.)* |
| `log_daily_rate_calculation_id` | BIGINT UNSIGNED | YES | The log row this charge maps to (the one overwritten) |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

---

## 5. `log_alloc_groups`

One bundle × one month. Holds the ΣN / ΣP totals and the balance check for validation V-1.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `bundle_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_bundles.id` |
| `target_ym` | CHAR(6) | NO | The month this grouping covers |
| `sum_n` | INT | NO | ΣN — total original paid_price across the bundle (yen) |
| `sum_p` | INT | NO | ΣP — total allocated amount (must equal sum_n) |
| `is_balanced` | TINYINT(1) | NO | 1 if sum_p == sum_n (V-1). 0 blocks finalize |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

**Invariant V-1:** `sum_p == sum_n` per group. If not balanced, run cannot finalize.

---

## 6. `log_alloc_prorations`  ★ Core result table

One row per product per group. Stores the reference price (L), the ratio, the original N, and the allocated P. Drives CSV generation and the Metabase breakdown.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `group_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_groups.id` |
| `run_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_calculation_runs.id` |
| `bundle_type` | TINYINT | NO | Enum `BundleType`: 1=CAP, 2=CIP *(was `project_code` VARCHAR)* |
| `charge_id` | BIGINT UNSIGNED | NO | The charge this proration is for |
| `product_id` | INT | NO | Coaching or App product |
| `product_type` | INT | NO | Freee product_type, read from `mst_product` at runtime and validated exactly per product (V-6). ✅ O-10 RESOLVED (REF-CAP-11 Round-3, 2026-09-10): Coaching 10005 = 9, Coaching 10015 = 9, App 10022 = 100 (same as existing App 10012); CIP 10025 = 9 (ASCI, out of Foundation scope). |
| `reference_price` | INT | NO | L — the allocation weight (yen) from `mst_alloc_reference_prices` |
| `ratio` | DECIMAL(8,6) | NO | This product's share of the weight total |
| `original_amount` | INT | NO | N — pre-allocation paid_price (yen) |
| `allocated_amount` | INT | NO | P — post-allocation paid_price (yen) |
| `contract_type` | TINYINT | YES | B2C/B2B/B2B2C/Partner (for CSV + Freee) |
| `department_id` | INT | YES | Department (for CSV + Freee) |
| `order_no` | VARCHAR(64) | YES | Order number |
| `asc_source_table` | VARCHAR(64) | NO | Which log table N was read from (`log_daily_rate_calculation[_pre]`) |
| `asc_source_id` | BIGINT UNSIGNED | NO | ID of the source row in that table |
| `paid_at` | DATE | YES | Snapshot of `trn_charge.paid_at` (date part) |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

**Formula (2-way — CAP + CIP 1028):** `allocated_amount` (P) computed as `P_app = floor(N × L_app / (L_coaching + L_app))`, `P_coaching = N − P_app`.

**~~3-way (CIP 1029–1032, R-16)~~ — SUPERSEDED (REF-CIP-05, 2026-09-17):** CIP no longer flows through allocation, so no CIP proration rows (2-way or 3-way) are written at all. This table is populated by CAP (2-way) only. The former 3-way note is retained for history; see technical design §1c.

---

## 7. `mst_alloc_reference_prices`  ★ Master data

Effective-dated allocation weights (L). Configurable without code changes.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `bundle_type` | TINYINT | NO | Enum `BundleType`: 1=CAP, 2=CIP *(was `project_code` VARCHAR)* |
| `product_id` | INT | NO | The product this price applies to |
| `reference_price` | INT | NO | L value (yen, **tax-EXCLUSIVE** list price from `mst_new_price_listing.price`, so the ASCA-8 breakdown recomputes an identical floored P — REF-CAP-09 / REF-CAP-11) |
| `effective_from` | DATE | NO | Start of validity |
| `effective_to` | DATE | YES | End of validity (NULL = open-ended) |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

**Seed values (CAP rows per REF-CAP-11 Round-3, tax-EXCLUSIVE = `mst_new_price_listing.price`; CIP rows are ASCI scope, values pending):**

| bundle_type | product_id | reference_price | Note |
|---|---|---|---|
| 1 (cap) | 10022 (App) | 3618 | tax-excl, `price_flag = 2`; `effective_from = 2027-01-01` |
| 1 (cap) | 10005 (Coaching 15min) | 18000 | tax-excl; confirm exact `mst_new_price_listing` row before seeding (G1 2-1) |
| 1 (cap) | 10015 (Coaching 30min) | 36000 | tax-excl; confirm exact `mst_new_price_listing` row before seeding (G1 2-1) |
| 2 (cip) | 10022 (App) | 3980 | |
| 2 (cip) | 10025 (Coaching Intensive) | 🔴 PENDING (O-5) | was 84020; plan repriced ¥88,000→¥75,900 |

> **✅ CAP weights are TAX-EXCLUSIVE (resolved — REF-CAP-11 Round-3, 2026-09-10; REF-CAP-09).** CAP: App 3,618, Coaching 15min 18,000, Coaching 30min 36,000 — each equal to `mst_new_price_listing.price` so the ASCA-8 breakdown recomputes an identical floored P (no ¥1 divergence). The earlier tax-inclusive figures (¥3,980 / ¥19,800 / ¥39,600) are superseded. CIP tax-excl weights (Lesson 13,500 : Coaching 66,500 : App 3,618) are ASCI scope; the CIP coaching value is still pending final confirmation (O-5).
>
> **✅ R-16 (CIP 3-way) SUPERSEDED by REF-CIP-05 (2026-09-17):** CIP no longer uses reference-price weights at all — it books separate, already-priced charges (App ¥3,980; Coaching Intensive ¥71,920 from a new `product_id 10025` `price_flag=3` record) through existing pro-ration. No CIP rows (Coaching, App, or Lesson) are seeded in `mst_alloc_reference_prices`. The CAP rows above are the only allocation weights. CIP's new `price_flag=3` record lives in `mst_new_price_listing` (ASCI seeder), not here.

**Invariant V-4:** all applied reference-price rows must be effective for the target date, or the run cannot finalize.

---

## 8. `log_alloc_sum_calculation`

Freee-level aggregation — what gets reflected in Freee journals (via the existing sum pipeline reading the overwritten log values).

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `run_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_calculation_runs.id` |
| `bundle_type` | TINYINT | NO | Enum `BundleType`: 1=CAP, 2=CIP *(was `project_code` VARCHAR)* |
| `target_ym` | CHAR(6) | NO | Year-month |
| `product_type` | INT | NO | Freee product_type |
| `contract_type` | TINYINT | YES | Contract type |
| `department_id` | INT | YES | Department |
| `partner_id` | BIGINT UNSIGNED | YES | Freee partner |
| `order_no` | VARCHAR(64) | YES | Order number |
| `allocated_amount` | INT | NO | Aggregated P (yen) |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

---

## 9. `log_alloc_sum_calculation_history`

Trace linkage — which proration rows rolled up into which summary row. Audit trail from a Freee journal back to individual allocations.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `sum_calculation_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_sum_calculation.id` |
| `proration_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_prorations.id` |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

---

## 10. `log_alloc_deliveries`

Delivery attempt tracking (Freee / CSV / email). Supports retry and failure isolation (design D-6).

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `run_id` | BIGINT UNSIGNED | NO | FK → `log_alloc_calculation_runs.id` |
| `channel` | TINYINT | NO | 0=Freee, 1=CSV, 2=Email |
| `status` | TINYINT | NO | 0=Pending, 1=Delivered, 2=Failed |
| `attempts` | INT | NO | Retry count |
| `detail` | TEXT | YES | Response / error detail |
| `delivered_at` | DATETIME | YES | When delivery succeeded |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

---

## 11a. `log_alloc_run_anchors`  ★ V-5 lock-only anchor (added REF-CAP-11 B)

Lock-only row, one per (`bundle_type`, `target_ym`). The finalizer takes `SELECT … FOR UPDATE` on it before switching the active pointer, so concurrent/re-run/crash-recovery Final finalizations serialize even when there is no prior active Final. There is intentionally **no** `active_run_id` column and **no** FK — the single source of truth for "which Final is active" is `superseded_by_run_id IS NULL` on `log_alloc_calculation_runs`.

| Column | Type | Null | Description |
|---|---|---|---|
| `id` | BIGINT UNSIGNED | NO | PK |
| `bundle_type` | TINYINT | NO | Enum `BundleType`: 1=CAP, 2=CIP |
| `target_ym` | CHAR(6) | NO | Year-month, `YYYYMM` |
| `created_at` / `updated_at` | TIMESTAMP | NO | Standard |

**Keys / rules:** UNIQUE (`bundle_type`, `target_ym`) — exactly one anchor row per bundle family per month. Created race-safely via `INSERT … ON DUPLICATE KEY UPDATE` / `INSERT IGNORE`, then `SELECT … FOR UPDATE`. Lock-only: no data columns beyond the key.

---

## 11. `v_alloc_prorations_active` (view)

Convenience view returning prorations from the **active final run only** (latest completed final run per `bundle_type` + `target_ym`). Used by CSV generation and Metabase so consumers don't have to filter runs manually.

```sql
-- Conceptual definition — actual SQL lives in ls-database-migrations sql/ pair
SELECT p.*
FROM log_alloc_prorations p
JOIN log_alloc_calculation_runs r ON p.run_id = r.id
WHERE r.run_type = 1        -- Final
  AND r.status   = 1        -- Completed
  AND r.id = (
      SELECT MAX(r2.id) FROM log_alloc_calculation_runs r2
      WHERE r2.bundle_type = r.bundle_type
        AND r2.target_ym   = r.target_ym
        AND r2.run_type = 1 AND r2.status = 1
  );
```

---

## Entity Relationships

**Diagram source:** [`diagrams/erd/asc-alloc-schema.puml`](diagrams/erd/asc-alloc-schema.puml)

![ASC Allocation ERD](diagrams/erd/asc-alloc-schema.png)

<!-- To regenerate the image:
     1. Open diagrams/erd/asc-alloc-schema.puml
     2. Render via PlantUML (IDE plugin, or plantuml.com server, or `plantuml asc-alloc-schema.puml`)
     3. Export the PNG as diagrams/erd/asc-alloc-schema.png (same folder)
-->

**Text summary (fallback):**

```
log_alloc_calculation_runs (1)
├──< log_alloc_source_documents      (snapshot per charge)
├──< log_alloc_bundles (1)
│     ├──< log_alloc_bundle_charges  (2: coaching + app; 3 for CIP 1029–1032: +lesson, per R-16)
│     └──< log_alloc_groups (1)
│           └──< log_alloc_prorations (2 per group; 3 for CIP 1029–1032: lesson+coaching+app, per R-16)
├──< log_alloc_sum_calculation (1)
│     └──< log_alloc_sum_calculation_history >── log_alloc_prorations
└──< log_alloc_deliveries

log_alloc_run_anchors       (standalone lock-only — one row per bundle_type+target_ym; no FK)
log_alloc_calculation_runs.superseded_by_run_id → log_alloc_calculation_runs.id  (self-ref; NULL = active Final, V-5)
mst_alloc_reference_prices  (standalone master — read by the engine)
v_alloc_prorations_active   (view over prorations + runs; active = Completed run with superseded_by_run_id IS NULL)
```

---

## Open Items Affecting This Schema

| Item | Impact | Status |
|---|---|---|
| ~~R-16: CIP 3-way~~ **SUPERSEDED** | ~~CIP 1029–1032 are 3-way (Lesson : Coaching : App)~~ — **withdrawn by REF-CIP-05 (2026-09-17).** CIP no longer uses the allocation engine at all (residual-value pricing: separate charges + existing pro-ration). No Lesson `product_role`, no CIP Lesson seed row, no 3-way prorations are needed. `product_role`/columns stay as-is (CAP-only, harmless); no migration change. | ✅ Superseded (REF-CIP-05, 2026-09-17) — no schema change; CAP unaffected |
| Tax-incl vs tax-excl weights | Resolved for CAP: seed table now uses tax-**exclusive** (App 3,618, Coaching 18,000 / 36,000) = `mst_new_price_listing.price`. CIP weights (Coaching 66,500, Lesson 13,500) are ASCI scope. | ✅ CAP resolved (REF-CAP-11 Round-3, 2026-09-10); CIP coaching pending (O-5) |
| O-5 | `mst_alloc_reference_prices` CIP coaching seed value (¥84,020 stale) | 🔴 Pending Kuroda-san/Accounting (REF-CAP-09 gives tax-excl L_coaching = 66,500 — reconcile) |
| O-7 | product_ids in seeds + `product_id` columns (App 10022, CIP coaching 10025) | ✅ Confirmed |
| O-9: `bundle_type` rename + retype | Column across 6 tables: `project_code` VARCHAR → `bundle_type` TINYINT (1=CAP, 2=CIP) | ✅ Confirmed by Kuroda-san 2026-09-02 |
| O-10: new-product `product_type` | `product_type` read from `mst_product` at runtime, validated exactly per product (V-6) | ✅ Resolved (REF-CAP-11 Round-3, 2026-09-10): 10005 = 9, 10015 = 9, App 10022 = 100, CIP 10025 = 9 (ASCI) |
| V-5 anchor table | Adds `log_alloc_run_anchors` (11th table, lock-only, UNIQUE `bundle_type`+`target_ym`, no `active_run_id`) + `superseded_by_run_id` on `log_alloc_calculation_runs` | ✅ Confirmed (REF-CAP-11 Round-3 B, 2026-09-10) — see §11a below |

---

## Cross-Reference

| Document | Relevance |
|---|---|
| [REF-CAP-04](../../../research/CAP/REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md) | Kuroda-san's original table list + roles (this doc adds fields) |
| [technical design](asc-allocation-framework-technical-design.md) | Formula, data flow, injection, validations |
| [table-prefix ADR](ASCA-ADR-20260817-table-prefix-decision.md) | Table prefix decision (`log_alloc_*` / `mst_alloc_*`) |
| [REF-CIP-04](../../../research/CIP/REF-CIP-04-Product-Plan-IDs-And-Price-Matrix-20260824.md) | Product_id + price updates feeding the seed values |
