# ASCA Spec 01 — Foundation · Requirements

## Document Info

| | |
|---|---|
| **Spec** | ASCA Spec 01 — Foundation |
| **Phase** | Specify (Requirements) — awaiting G1 sign-off |
| **Date** | 2026-09-03 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Approver (G1)** | Kuroda-san (PM) |
| **Status** | Draft — for G1 review |
| **Repos** | `ls-database-migrations` (schema), `accounting_related_system_for_freee` (models/enums/service) |
| **Authoritative sources** | `projects/asca/documentation/asc-allocation-framework-technical-design.md`, `projects/asca/documentation/asc-alloc-db-schema.md` |

---

## Introduction

The ASC Allocation Framework splits bundled Coaching charge revenue between the Coaching product and the App product so Freee journals reflect correct per-product revenue. This **Foundation** spec delivers the shared infrastructure that both ASCA (CAP) and ASCI (CIP) build on: the database schema, Eloquent models, plan-detection enums, the run-lifecycle service, the allocation engine (formula + idempotency + validations), the reference-price master with its seeder, and a test-data seeder for DEV04.

Foundation delivers a working, testable allocation engine. It does **not** wire the engine into the live batch — that injection (into `CommonUtil` and `DataCorrectionLogic`), the AllocationDetail CSV, and refund handling are **Spec 02 (CAP Integration)**.

**Scope:** Bizmates only (`mysql` at runtime, `bizmates_mysql` in migrations). No Zipan.

> **Sizing note (deviation from the 5-requirement heuristic):** SDD standards flag a requirements doc with 5+ requirements as a candidate to split. This spec intentionally exceeds that as a **Foundation spec** — the shared infrastructure (schema, models, enums, engine, audit) that both ASCA and ASCI depend on, which SDD explicitly permits extracting as one foundation unit. At the design/tasks phase it is expected to fan out into separate coding stories (ls-db migrations vs. accounting-app code), per the master timeline. Called out here per the deviation protocol.

---

## Out of Scope (this spec)

- Injection into `CommonUtil::createDailyRateCalculation()` — Spec 02
- Injection into `DataCorrectionLogic` (`allocateForCharge()`) — Spec 02
- AllocationDetail CSV generation and `config/const.php` header — Spec 02
- Refund allocation (`record_kind = 1`) and reversal (`record_kind = 2`) — Spec 02 / Post-release
- CIP-specific detection and CIP reference-price seed row — ASCI Spec 01
- Freee `mst_code_change` / `mst_rule_for_journals` mappings for App (data check) — Spec 02 go-live

---

## Confirmed Decisions (inputs, not open for G1)

| # | Decision | Value |
|---|---|---|
| D-1 | Architecture | Scenario D (injection) + Option 1 (Overwrite). Foundation builds the engine only. |
| D-2 | `bundle_type` column | TINYINT int-backed enum `BundleType` (1=CAP, 2=CIP), `label()` → `'cap'`/`'cip'`. **O-9 confirmed by Kuroda-san 2026-09-02** (renamed+retyped from `project_code` VARCHAR). |
| D-3 | Product ids | App **10022**, CIP Coaching Intensive **10025** (changed 2026-08-19). Coaching 15min 10005, 30min 10015. |
| D-4 | Money type | Integer yen (matches existing `paid_price`). Ratio DECIMAL(8,6). |
| D-5 | Idempotency basis | N = Σ(paid_price) across the bundle (coaching + app). |

---

## Open Items (need G1 decision)

| # | Item | Impact on Foundation | Ask |
|---|---|---|---|
| **O-5** | CIP Coaching Intensive reference price. Plan repriced ¥88,000 → ¥75,900; prior L_coaching ¥84,020 is stale (likely ¥71,920 = 75,900 − 3,980, unconfirmed). | Foundation builds the `mst_alloc_reference_prices` **table** and CAP seed rows. The CIP coaching seed row cannot be finalized until this value is confirmed. Does not block CAP Foundation. | Confirm the CIP L_coaching value (or defer the CIP seed row to ASCI Spec 01). |

---

## Requirements

### Requirement 1 — Allocation database schema

**User story:** As the accounting system, I want the allocation tables to exist with correct structure, so that allocation runs, bundles, prorations, and reference prices can be persisted and audited.

**Acceptance criteria:**
1. WHEN the migrations run THE SYSTEM SHALL create 10 tables (`log_alloc_calculation_runs`, `log_alloc_source_documents`, `log_alloc_bundles`, `log_alloc_bundle_charges`, `log_alloc_groups`, `log_alloc_prorations`, `mst_alloc_reference_prices`, `log_alloc_sum_calculation`, `log_alloc_sum_calculation_history`, `log_alloc_deliveries`) and 1 view (`v_alloc_prorations_active`).
2. THE SYSTEM SHALL create every table on the `bizmates_mysql` connection.
3. THE SYSTEM SHALL store money columns (reference_price, original_amount, allocated_amount, sum_n, sum_p) as integer yen, and `ratio` as DECIMAL(8,6).
4. THE SYSTEM SHALL store enum columns (`bundle_type`, `run_type`, `status`, `product_role`, `channel`) as TINYINT.
5. THE SYSTEM SHALL define physical foreign keys between allocation tables per the schema reference.
6. WHERE a table's structure changes THE SYSTEM SHALL have a regenerated structure test asserting column presence and type.
7. THE view `v_alloc_prorations_active` SHALL return prorations from only the latest completed Final run per (`bundle_type`, `target_ym`).

> Field-level detail (columns, nullability, keys) is authoritative in `asc-alloc-db-schema.md`. This requirement asserts the table set and structural rules, not each column.

### Requirement 2 — Eloquent models

**User story:** As a developer, I want an Eloquent model per allocation table, so that the engine reads and writes through typed models with the correct connection and table binding.

**Acceptance criteria:**
1. THE SYSTEM SHALL provide one typed Eloquent model per allocation table.
2. THE SYSTEM SHALL bind each model to the correct Bizmates connection and its exact table name.
3. THE SYSTEM SHALL declare model properties with accurate nullability for static analysis.
4. WHERE a model relates to another allocation table THE SYSTEM SHALL expose the relationship matching the physical FK.

> Namespace, class-naming, and property conventions are settled by steering (`coding-standards.md`) and detailed in design.md — not pinned here.

### Requirement 3 — Plan-detection enums

**User story:** As the allocation engine, I want plan-id enums, so that I can identify CAP (and later CIP) charges without hard-coded id lists.

**Acceptance criteria:**
1. THE SYSTEM SHALL provide `CoachingAndAppPlanEnum` (int-backed) with cases for plan_ids 1016–1027.
2. THE SYSTEM SHALL provide `CoachingIntensivePlanEnum` (int-backed) with cases for plan_ids 1028–1032.
3. THE SYSTEM SHALL provide `BundleType` (int-backed: CAP=1, CIP=2) with a `label()` method returning `'cap'`/`'cip'`.
4. THE SYSTEM SHALL provide `RunType` (Preview, Final) and `RunStatus` (Creating, Completed, Failed) as int-backed enums.
5. THE plan enums SHALL use the shared `HasEnumHelperTrait` so `exists(int $planId)` and `toArray()` are available.
6. WHEN detection checks a plan_id THE SYSTEM SHALL apply no date filter (these plan_ids have no historical charges).

### Requirement 4 — Reference-price master and resolution

**User story:** As the allocation engine, I want effective-dated reference prices, so that allocation weights can change without code changes and every run uses the price valid for its target date.

**Acceptance criteria:**
1. THE SYSTEM SHALL store reference prices in `mst_alloc_reference_prices` keyed by (`bundle_type`, `product_id`) with `effective_from` / nullable `effective_to`.
2. WHEN the engine resolves a reference price for a product on a target date THE SYSTEM SHALL return the row whose effective window contains that date.
3. IF no effective reference-price row exists for an applied product on the target date THEN THE SYSTEM SHALL fail the run (validation V-4) rather than allocate with a missing weight.
4. THE seeder SHALL insert CAP rows: App (10022) ¥3,980; Coaching 15min (10005) ¥19,800; Coaching 30min (10015) ¥39,600.
5. THE seeder SHALL be idempotent (skip rows that already exist).
6. WHERE the CIP Coaching Intensive (10025) price is confirmed (O-5) THE seeder SHALL insert the CIP rows; otherwise the CIP coaching row is deferred to ASCI Spec 01.

### Requirement 5 — Allocation engine (formula)

**User story:** As the accounting system, I want the engine to split N into P_coaching and P_app by reference-price weight, so that revenue is correctly apportioned between Coaching and App.

**Acceptance criteria:**
1. WHEN the engine allocates a bundle THE SYSTEM SHALL compute `P_app = floor(N × L_app / (L_coaching + L_app))` and `P_coaching = N − P_app`.
2. THE SYSTEM SHALL define N as Σ(paid_price) across the bundle (coaching row + app row) for the target_ym.
3. THE SYSTEM SHALL guarantee `P_coaching + P_app = N` for every bundle (remainder absorbed by Coaching).
4. THE SYSTEM SHALL compute amounts in integer yen using `floor()` for the App share.

### Requirement 6 — Bundle detection and grouping

**User story:** As the allocation engine, I want to detect Coaching+App bundles from the daily-rate log, so that each contract's pair is allocated as a unit.

**Acceptance criteria:**
1. WHEN detecting bundles THE SYSTEM SHALL join the daily-rate log to `trn_charge` (the log has no `plan_id`) and select rows whose `plan_id` is in the CAP (or CIP) enum and whose `product_id` is in {10005, 10015, 10025, 10022}.
2. THE SYSTEM SHALL group detected rows by (`student_id`, `order_no`) so each contract is isolated.
3. IF a group is missing either the coaching row or the app row THEN THE SYSTEM SHALL skip that group, log a warning, and mark the bundle incomplete (V-3) — without failing the whole run.
4. THE SYSTEM SHALL identify the App row by `product_id = 10022` and the coaching row as the non-App product in the group.

### Requirement 7 — Run lifecycle

**User story:** As an operator, I want every allocation run recorded with status, so that successes and failures are auditable even when the calculation fails.

**Acceptance criteria:**
1. WHEN a run begins THE SYSTEM SHALL create a `log_alloc_calculation_runs` row with status Creating in its own committed transaction, so the row persists even if the run later fails.
2. WHEN a run completes THE SYSTEM SHALL set status Completed and record `record_count` and `finalized_at`.
3. IF the run throws THEN THE SYSTEM SHALL set status Failed and record `error_message`, then re-throw to the caller.
4. THE SYSTEM SHALL support both `run_type` values (Preview for `_pre`, Final for the live table).

### Requirement 8 — Audit trail and idempotency

**User story:** As an auditor, I want an immutable record of pre-allocation values and re-run-safe behavior, so that the original figures are preserved and re-running never corrupts the numbers or the audit.

**Acceptance criteria:**
1. WHEN a run processes a bundle THE SYSTEM SHALL snapshot the original N (`original_paid_price`) into `log_alloc_source_documents` before any overwrite.
2. IF a source-document snapshot already exists for (`charge_id`, `target_ym`) THEN THE SYSTEM SHALL NOT insert a second snapshot (prevents recording allocated values as "original" on re-run).
3. WHEN a bundle is re-run THE SYSTEM SHALL produce the same P values as the first run (idempotent, because N = ΣN is invariant).
4. THE SYSTEM SHALL persist per-product proration detail (L, ratio, N, P) to `log_alloc_prorations` and the ΣN/ΣP totals to `log_alloc_groups`.

### Requirement 9 — Validation invariants

**User story:** As the accounting system, I want the run to enforce correctness invariants, so that an unbalanced or mis-priced allocation cannot finalize.

**Acceptance criteria:**
1. (V-1) WHEN a bundle group is evaluated THE SYSTEM SHALL set `is_balanced = 1` only if `sum_p == sum_n`; IF unbalanced THEN THE run SHALL NOT finalize.
2. (V-4) IF any applied reference-price row is not effective for the target date THEN THE run SHALL NOT finalize.
3. (V-5) THE SYSTEM SHALL allow only one active (Completed) Final run per (`bundle_type`, `target_ym`).
4. WHERE a bundle is incomplete (V-3) THE SYSTEM SHALL record it as a warning and exclude it from allocation without failing the run.

### Requirement 10 — Test-data seeder (DEV04)

**User story:** As the dev/QA team, I want mock CAP bundle charges on DEV04, so that the engine can be exercised end-to-end before real upstream data exists.

**Acceptance criteria:**
1. THE SYSTEM SHALL provide a seeder that creates representative CAP charge pairs (coaching + ¥0 app) for a range of plans (1016–1027).
2. THE seeder SHALL be idempotent and clearly separated from production reference-price data.
3. WHERE run on DEV04 THE seeder SHALL produce data sufficient to detect bundles and verify the formula, idempotency, and validations.

> **Correctness properties** (ΣP = ΣN, idempotence, reference-price effectivity, single-snapshot) will be defined in **design.md** — per `conventions.md`, the design doc's "Correctness Properties" section is the home for these, and `tasks.md` maps each property test to them. They derive from R5, R8, and R9.

---

## Traceability

| Requirement | Technical design ref |
|---|---|
| R1 schema | db-schema §1–11 |
| R4 reference prices | §6 |
| R5 formula | §4 |
| R6 detection | §7, §9 (detectBundles) |
| R7 run lifecycle | §9 (allocate) |
| R8 idempotency/audit | §9 (snapshot, idempotency) |
| R9 validations | §9, db-schema (V-1/V-4/V-5) |
