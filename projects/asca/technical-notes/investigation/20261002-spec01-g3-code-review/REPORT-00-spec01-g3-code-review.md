# ASCA Spec 01 Foundation — G3 Code Review (findings + recommended verdict)

## Document Info

| | |
|---|---|
| **Document type** | Code Review (G3) — findings + recommended verdict |
| **Date** | 2026-10-02 |
| **Reviewer** | Noel Palo, Lead (Kiro-assisted) |
| **Gate** | G3 (ASCA-18). **Recommendation only — the Lead holds the final pass/fail sign-off.** |
| **Scope** | ASCA Spec 01 — Foundation. Two repos, reviewed one at a time. **This report: Repo 1 — `accounting_related_system_for_freee` (engine half).** Repo 2 (`ls-database-migrations`) appended in a later section. |
| **Context** | Spec 01 was **merged to `feature/ASCA/ASCA-master` ahead of G3** (both repos) to unblock Spec 02. G3 review is owed; this is it. |
| **Reviewed against** | `.kiro/specs/asca-spec-01-foundation/{requirements,design,tasks}.md` (requirements Req 1–9 read in full); ASCA technical design §1a/§1b; ASCA steering. |

> **How to read this:** each finding is tagged **[BLOCKER]** / **[SHOULD-FIX]** / **[NIT]** / **[OK]**. The recommended verdict is at the end of the repo section. Severity is my recommendation; the Lead decides what blocks G3.

---

## Repo 1 — `accounting_related_system_for_freee` (engine half)

### What was read (full)

- `app/Libs/RevenueAllocation/Formula/`: `AllocationFormulaInterface`, `TwoWayAllocationFormula`, `AllocationFormulaRegistry` (+ `BundleData`, `AllocationResult`, `ProductCharge` referenced).
- `app/Libs/RevenueAllocation/`: `RevenueAllocationService` (orchestrator), `RunLifecycleService`, `BundleDetectionService`, `AllocationValidator`, `ReferencePriceResolver`.
- Directory-level confirmation: all 11 models in `app/Models/RevenueAllocation/`; all 5 enums in `app/Enums/RevenueAllocation/`.

### Not yet line-read (recommended spot-check before final sign-off)

- `app/Models/RevenueAllocation/*` — confirmed to **exist** (all 11, exact names) but not line-read for `$connection='mysql'` / explicit `$table` / nullable property docblocks / relationships (Req 1.12–1.13).
- `app/Libs/RevenueAllocation/Persistence/*` (`AllocationPersistenceService`, `ProrationRow`, `SourceDocumentSnapshot`) — behavior inferred from callers; not line-read.
- The reference-price **seeder** and **test-data seeder** (Req 4 seeder, Req 10) — not located/read in this pass.
- `tests/Unit/RevenueAllocation/*` — not read; **test adequacy is the biggest open item** (see SHOULD-FIX-1).

---

### Findings — correctness-critical (all OK)

**[OK] Req 7.4 — true floor toward −∞ (the #1 refund-correctness requirement).** `TwoWayAllocationFormula::floorDiv()` uses `intdiv()` + remainder correction toward −∞, explicitly avoiding `(int)`/`intval()` truncation **and** float precision loss (no float touches the money math). Documented reasoning is correct. `P_coaching = N − P_app`, remainder absorbed by coaching ⇒ `ΣP = N` guaranteed (Req 7.2–7.4). This is exactly what REF-CAP-09 R-01 demanded.

**[OK] Req 3 — pluggable formula, no silent mis-split.** `AllocationFormulaInterface` + `AllocationFormulaRegistry`: list-per-family so ambiguity is representable; `selectFor()` returns `null` (V-3 skip) for both no-match and ambiguous — no default fallback, no tiebreak (Req 3.4–3.7). `foundation()` registers only CAP→TwoWay. **No `ThreeWayAllocationFormula` exists** (consistent with REF-CIP-05).

**[OK] Req 5 / V-5 — anchor-row finalize (the hardest requirement).** `RunLifecycleService::finalizeRun()` implements the retain-history model precisely: `INSERT IGNORE` the lock-only anchor (race-safe, empty-set-safe) → `SELECT … FOR UPDATE` → supersede prior active (`superseded_by_run_id` set via `activeFinal` scope, `whereKeyNot` self) → make this run active → **in-transaction guard that exactly one active Final remains, else `RuntimeException` → rollback → `markFailed`**. Preview runs correctly skip the anchor path. `createRun` commits in its own transaction (audit survives failure). Anchor is lock-only (no `active_run_id`); active = `superseded_by_run_id IS NULL` (Req 5.6–5.12). Matches §1b round-3 B.

**[OK] Req 6 — bundle detection/pairing.** `BundleDetectionService`: joins log→`trn_charge` to recover `plan_id` (log has none); filters CAP plans + {10005,10015,10022}; **grouping key always includes start/end dates** so a date mismatch can never pair even under one `order_no` (Req 6.5 enforced uniformly); explicit product_id role identification (App=10022, coaching∈{10005,10015} — not "non-app row", Req 6.9); ambiguous/incomplete → V-3 skip + warning, run continues (Req 6.7–6.8); defensive `exists()` re-check (Req 2.6); mid-month renewal splits by distinct dates (Req 6.10).

**[OK] Req 9 validations.** V-1 (`assertBalanced`, throws `UnbalancedGroupException`, blocks finalize); V-4 (sourced in `ReferencePriceResolver`: missing/overlapping/invalid-range/bad-target_ym all throw `ReferencePriceResolutionException`; zero price is valid); V-6 (`validateProductTypes` reads `mst_product` at runtime, exact-match against `EXPECTED_PRODUCT_TYPE` 10005→9/10015→9/10022→100, throws on mismatch/missing/unexpected — matches O-10/REF-CAP-11); V-7 (`guardNonZeroApp` returns skip-signal, does not throw — correct per Req 9.6).

**[OK] Req 4 — reference-price resolution.** `ReferencePriceResolver` uses last-calendar-day-of-target_ym as resolution date (Req 4.1); single covering row required (overlap → V-4); zero price valid (Req 4.5); invalid/inverted range → V-4.

**[OK] Req 7/8 orchestration + idempotency.** `RevenueAllocationService` wires the pipeline in the documented order (V-6 → V-7 → resolve L → snapshot-before-overwrite → select formula → split → persist → V-1); V-3 skips never fail the run; loud V-1/V-4/V-6 → `markFailed` + re-throw; N = Σ(paid_price) read back from the log gives re-run idempotency (Req 8.3–8.4). Snapshot written before any overwrite regardless of validity (Req 8.1).

**[OK] Req 1 & 2 — models and enums present.** All 11 models exist with exact spec names. All 5 enums exist (`CoachingAndAppPlanEnum`, `CoachingIntensivePlanEnum`, `BundleType`, `RunType`, `RunStatus`).

**[OK] Steering-deferred question RESOLVED.** `CoachingIntensivePlanEnum` is created (Req 2.2/2.7) but **referenced nowhere in `app/`** (grep = 0 non-test hits) — confirming Foundation detection is CAP-only and the enum exists only "for completeness." ⇒ The `coding-standards.md` file-structure diagram that lists `CoachingIntensivePlanEnum.php` is **accurate**; no steering edit needed there.

---

### Findings — to address

**[SHOULD-FIX-1] Test adequacy not verified in this pass.** `tests/Unit/RevenueAllocation/` exists (saw `RevenueAllocationEnumTest`, `RevenueAllocationModelBindingTest`) but was not read. Before final G3 sign-off, confirm tests cover the correctness-critical behaviors the design calls out — especially: (a) **floor toward −∞ on negative N** (the refund case, even though refunds are Spec 02 the floor ships now); (b) the **V-5 two-finalizers + empty-set** concurrency case (Req 5.13 explicitly requires this test); (c) **re-run idempotency**; (d) bundle **date-mismatch V-3 skip**. Recommend a targeted read of the test suite (or a `phpunit` run) as the gating evidence.

**[SHOULD-FIX-2] Models / Persistence / seeders not line-read.** Existence is confirmed but Req 1.12 (explicit `$connection`+`$table`, nullable docblocks), Req 1.13 (relationships), and the Req 4 seeder specifics (CAP rows App ¥3,618 / 10005 ¥18,000 / 10015 ¥36,000; `effective_from=2027-01-01`; idempotent; **no CIP 10025 row**) should be spot-checked. Note Req 4.3/4.4 flags C15/C30 (¥18,000/¥36,000) as **pending final `mst_new_price_listing` reconciliation (G1 2-1)** — verify the seeder's values against the final listing before the seeder is run in any environment.

**[NIT-1] Formula's defensive `else`-is-coaching branch.** `TwoWayAllocationFormula` treats any non-App charge as coaching. This is **safe** because `BundleDetectionService` already guarantees exactly 1 coaching(10005/10015)+1 app(10022) before the formula runs. No change needed; noting only that the formula's safety depends on detection's guarantee (they're correctly coupled).

---

### Recommended verdict — Repo 1

**RECOMMEND PASS, conditional on clearing SHOULD-FIX-1 (test adequacy) and SHOULD-FIX-2 (models/seeder spot-check) before final G3 sign-off.**

Rationale: every correctness-critical requirement I read — the true floor, the V-5 anchor finalize, bundle pairing/date-matching, the V-1/V-4/V-6/V-7 validations, resolution-date semantics, and the no-silent-mis-split guarantee — is implemented correctly and matches the spec and the §1a/§1b G1 decisions. The code is clean, single-responsibility, container-injected, and thoroughly documented. The two SHOULD-FIX items are **verification gaps in this review**, not known defects — they're what I'd confirm (or delegate) before you record the G3 pass. No blockers found.

> **Final G3 pass/fail is the Lead's call.** This section is a recommendation.

---

<!-- Repo 2 (ls-database-migrations) findings to be appended below in the next review pass. -->

## Repo 2 — `ls-database-migrations` (schema half)

Reviewed against `.kiro/specs/asca-spec-01-database-migration/requirements.md` (Req 1–20, read in full) and cross-checked against what the engine half (repo 1) actually binds to.

### What was read (full)

- Migrations: `create_log_alloc_calculation_runs`, `create_log_alloc_run_anchors`, `create_log_alloc_prorations`, `add_foreign_keys_to_alloc_tables` (full); directory-confirmed all 11 create-table migrations (`100000`–`100011`) + the FK migration (`100100`).
- `database/migrations/sql/view-table-migration.sql` — the `v_alloc_prorations_active` view definition (full).
- Directory-confirmed: all **11 structure tests** present under `tests/Unit/Database/` (LogAlloc{CalculationRuns,SourceDocuments,Bundles,BundleCharges,Groups,Prorations,SumCalculation,SumCalculationHistory,Deliveries,RunAnchors} + MstAllocReferencePrices), **plus** `AllocConstraintsTest.php` and `AllocMigrationRoundTripTest.php` (FK + round-trip integration — above the spec's ask).

### Not line-read (recommended spot-check)

- The other 7 create-table migrations (bundles/bundle_charges/groups/source_documents/sum_calculation/sum_calculation_history/deliveries) — column lists verified against Req 4–12 only at the directory/representative level; recommend a quick type pass or a `generate:db-tests` diff.
- The CAP reference-price **seeder** (Req 16) under `database/seeders/Bizmates/` — not located/read this pass (same gap as repo 1 SHOULD-FIX-2; the seeder is cross-repo-relevant).
- The structure-test and round-trip test **contents** — not read.

### Findings — correctness-critical (mostly OK)

**[OK] All 11 tables + FK migration present, correctly ordered, `bizmates_mysql`, reversible.** `create_*` 100000–100011, FKs in 100100 (after all tables, Req 13.11). Every table uses `Schema::connection('bizmates_mysql')`, `$table->id()` BIGINT UNSIGNED PK, `created_at`/`updated_at`, guarded `hasTable`, `dropIfExists` down() (Req 1).

**[OK] `log_alloc_run_anchors` (Req 3).** Lock-only (no `active_run_id`), UNIQUE `(bundle_type, target_ym)` created **with the table** so one anchor per month is guaranteed from creation. Exactly matches the engine's `INSERT IGNORE` + `SELECT … FOR UPDATE` finalize path. Comment documents the lock-only intent.

**[OK] `log_alloc_calculation_runs` (Req 2) + `superseded_by_run_id`.** Column types match (tinyint bundle_type/run_type/status, char(6) target_ym, nullable record_count/error_message/finalized_at). Carries `superseded_by_run_id` BIGINT UNSIGNED NULL — the active-run pointer the engine and the view rely on. **Note:** the ls-db requirements Req 2 list does not enumerate `superseded_by_run_id`, but it is present and correct — a (minor) spec-vs-impl doc gap, not a code defect; the column is required and right.

**[OK] FK + UNIQUE migration (Req 13, 8.2, 9.7).** 12 FKs (the 9 required + source_documents→applied_reference_price_id, prorations duplicate guard, and the self-referencing `superseded_by_run_id`→runs for V-5), all `restrict`/`restrict`. UNIQUEs: `source_documents(run_id, charge_id, target_ym)` (backs Req 8.2 snapshot idempotency) and `reference_prices(bundle_type, product_id, effective_from)` (Req 9.7). **Deliberately no raw UNIQUE on runs(bundle_type, target_ym)** — the migration comment correctly explains this would forbid Preview/Final coexistence + failed-run retries; V-5 is enforced by the anchor lock + `superseded_by_run_id` instead (matches engine + Req 9.3). `down()` drops FKs then UNIQUEs with per-constraint guards (tolerant of partial up()). Careful work.

**[OK] `log_alloc_prorations` (Req 8).** All 17 columns present with correct types incl. `ratio` DECIMAL(8,6), `product_type` INT (resolved at runtime, no DB constraint — Req 20.1), signed INT money columns.

**[OK] `v_alloc_prorations_active` EXISTS and is mostly correct (Req 14).** Appended to `database/migrations/sql/view-table-migration.sql` (the `db:migrate-view-table` raw-SQL pair, Req 14.1 — this is why a plain migrations-dir / `CREATE VIEW` grep misses it). Filters `status = 1` (Completed) AND `superseded_by_run_id IS NULL` AND `id = MAX(id)` per (bundle_type, target_ym). The active-run condition matches the engine's source-of-truth. Rollback drops the view (Req 14.4).

### Findings — to address

**[SHOULD-FIX-3 / possible BLOCKER — your call] The `v_alloc_prorations_active` view does NOT filter `run_type = Final` (Req 14.2).** The WHERE clause is `r.status = 1 AND r.superseded_by_run_id IS NULL AND r.id = (MAX … same conditions)`. It never restricts `run_type` to Final. **Why this matters:** the engine's `allocate($targetYm, preFlg: true)` creates a **Preview** run and *does* write proration rows for it (confirmed in repo 1 — `processBundles` runs for Preview, persisting prorations with `asc_source_table = log_daily_rate_calculation_pre`). A completed Preview run has `status = 1` and `superseded_by_run_id IS NULL` (Preview runs are never superseded — the finalize supersession path is Final-only). So a Preview run's prorations satisfy every condition in the view and **can surface in `v_alloc_prorations_active`** — and if a Preview run has a higher `id` than the active Final (the common case: Pre runs on the 1st, Final on the 3rd business day — Pre is earlier, but a re-run Preview after Final would have a higher id), the `MAX(id)` subquery can even select the Preview run over the Final. Req 14.2 explicitly requires "run_type = Final". **Recommended fix:** add `r.run_type = 1` (Final) to both the outer WHERE and the `MAX(id)` subquery. **Severity:** I'm flagging this as the one finding that could be a BLOCKER — it's a real spec-conformance + correctness gap in a consumer-facing view — but its live impact depends on whether anything reads the view before Spec 02 wiring (today nothing does), so you may reasonably treat it as SHOULD-FIX-before-Spec-02. Add a view test asserting a completed Preview run's prorations do NOT appear.

**[SHOULD-FIX-4] Seeder (Req 16) not reviewed.** Confirm the CAP seeder exists under `database/seeders/Bizmates/`, is idempotent (skip-on-existing by the `(bundle_type, product_id, effective_from)` key), per-row transactions, has `rollback()` (no TRUNCATE), seeds App 10022=3618 / 10005=18000 / 10015=36000 with `effective_from=2027-01-01` and **no CIP 10025 row** (Req 16.2–16.5). Per Req 20.2 / G1 2-1 the C15/C30 values are **pending final `mst_new_price_listing` reconciliation** — verify before the seeder is run anywhere.

**[NIT-2] Spec doc gap: `superseded_by_run_id` not listed in ls-db Req 2.** The column is correctly implemented and is essential (the whole V-5 active-run model depends on it). Only the requirements enumeration omits it. Recommend a one-line requirements fix for traceability; no code change.

### Recommended verdict — Repo 2

**RECOMMEND CHANGES before pass — one targeted view fix (SHOULD-FIX-3), then PASS.**

Rationale: the schema is otherwise complete and correct — all 11 tables + FKs + the 2 UNIQUEs + 11 structure tests + the view, correct types, correct connection, reversible, with a genuinely well-reasoned V-5 approach (anchor UNIQUE + no raw runs-UNIQUE) that matches the engine exactly, and bonus constraint/round-trip tests. The single substantive issue is the view's missing `run_type = Final` predicate (Req 14.2), which can leak Preview prorations into (or let them override) the active-Final result. It's a one-line SQL fix in `view-table-migration.sql` + a view test. Everything else is OK or a spot-check.

> **Final G3 pass/fail is the Lead's call.** The view fix is the one thing I'd want corrected (or consciously accepted) before recording the gate.

---

## Overall recommendation (both repos)

- **Repo 1 (engine):** RECOMMEND PASS, conditional on test-adequacy + models/seeder spot-check (SHOULD-FIX-1/2). No defects found; the correctness-critical logic (floor toward −∞, V-5 finalize, bundle pairing, validations) is right.
- **Repo 2 (schema):** RECOMMEND CHANGES — fix the `v_alloc_prorations_active` `run_type = Final` filter (SHOULD-FIX-3), then PASS. Everything else complete and correct.

**Net:** one real fix (the view predicate) + a set of verification spot-checks (tests, seeder, model property pass). No blockers in the engine. Both halves are high quality — thorough docblocks, single-responsibility, defensive, spec-traceable. Once the view predicate is corrected and the test/seeder spot-checks clear, this is a clean G3 pass in my assessment — **but the pass/fail decision is yours.**

### Suggested next actions (not done here)

1. Decide severity of SHOULD-FIX-3 (view `run_type` filter) and get it corrected in `view-table-migration.sql` + add a view test.
2. Spot-check: engine tests (floor-on-negative, V-5 concurrency/empty-set per Req 5.13, idempotency, date-mismatch), the two reference-price/test-data seeders (both repos), and the 11 model property/connection declarations.
3. Record the G3 outcome against ASCA-18.
