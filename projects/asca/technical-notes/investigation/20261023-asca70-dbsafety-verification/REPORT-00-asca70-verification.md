# ASCA-70 DB-Safety Finding — Independent Verification Report

- **Date:** 2026-10-23
- **Verifier:** read-only code verification (no code/test/seeder/config changed)
- **Repos / branches verified:**
  - `accounting_related_system_for_freee` @ `feature/ASCA/ASCA-79-spec-2-steering-updates` (HEAD `4023d20f`; = ASCA-master + one steering-doc change — test/seeder code identical to ASCA-master `9eda279c`)
  - `ls-database-migrations` @ `feature/ASCA/ASCA-master` (HEAD `94ec95d`)
- **Subject:** Cristoff-san's ASCA-70 comment classifying which ASCA unit/feature tests & seeders can wipe real shared DB tables if a test run is pointed at a real DB (e.g. DEV04) instead of a throwaway test DB.

---

## 1. Summary answer (verdict first)

**Cristoff's investigation is TRUSTWORTHY. Every one of his key claims is confirmed by the code.** The two fix sub-tickets (accounting under ASCA-17, ls-db under ASCA-16) can be based on his finding as-is. No misclassification was found. Only minor, non-material notes below.

| # | Claim | Verdict |
|---|-------|---------|
| A | **Root cause:** runtime SQLite switch in `setUp()` is the ONLY guard; `phpunit.xml` forced-SQLite lines are COMMENTED OUT; no structural guard | **CONFIRMED** |
| 1a | Tier A tests do the SQLite switch + `purge` BEFORE any drop | **CONFIRMED** (every drop-issuing file; 5+ spot-checked in detail) |
| 1b | `phpunit.xml` leaves DB connection unforced / SQLite lines commented; no `.env.testing`; no `phpunit.xml.dist` | **CONFIRMED** |
| 2 | Tier A = drops real/shared tables; Tier B = drops only new `log_alloc_*`/`mst_alloc_*` | **CONFIRMED** — classification accurate, no dangerous misclassification |
| 3 | `CommonUtilCreateDailyRateCalculationInjectionTest.php` drops the broadest real set incl. `trn_charge` | **CONFIRMED** |
| 4 | `Dev04CapTestDataSeederTest.php` L307 is a hard `->drop()` (not IfExists) in a test | **CONFIRMED** — and it is the ONLY hard drop in the whole suite |
| 5 | ls-db: only `AllocMigrationRoundTripTest.php` issues DDL and it is fully guarded | **CONFIRMED** |
| 6 | Seeders only do scoped `->delete()` of own rows; 4 ASCI ls-db seeders not on branch | **CONFIRMED** |
| 7 | ~52 accounting tests flagged (~36 Tier A / ~16 Tier B); in-scope filter correct | **CONFIRMED order-of-magnitude** — I count **56** drop-issuing files; scope filter is right |

**The single most important verdict (A):** the root-cause claim is **correct**. The protection against wiping real tables is purely the per-test runtime re-point to in-memory SQLite. There is no structural backstop — `phpunit.xml` does NOT force the connection, and the default connection is `mysql` → `bizmates_new`. Any drop-issuing test whose `setUp()` SQLite switch is skipped, reordered, forgotten (in a future/new test), or defeated by a differently-loaded env would issue its `DROP`/`TRUNCATE` against whatever real DB the environment points at.

---

## 2. Evidence

### A / 1b — phpunit.xml forced-SQLite is commented out (ROOT CAUSE)

`accounting_related_system_for_freee/phpunit.xml`, `<php>` block, verbatim:

```xml
<server name="APP_ENV" value="testing"/>
<server name="BCRYPT_ROUNDS" value="4"/>
<server name="CACHE_DRIVER" value="array"/>
<!-- <server name="DB_CONNECTION" value="sqlite"/> -->
<!-- <server name="DB_DATABASE" value=":memory:"/> -->
<server name="MAIL_MAILER" value="array"/>
```

- The two `DB_CONNECTION=sqlite` / `DB_DATABASE=:memory:` lines are **commented out** → PHPUnit does NOT force a sqlite connection.
- **No `.env.testing`** exists (repo root has only `.env`, `.env.compose`, `.env.compose.example`, `.env.example`). The sole `phpunit.xml.dist` is under `OpenAPIClient/` (unrelated vendor sub-package), not the app root.
- Default connection resolves to real MySQL: `.env` → `DB_CONNECTION=mysql`, `DB_DATABASE=bizmates_new`; `.env.example` likewise `mysql` / `bizmates_new`.
- `tests/TestCase.php` is bare — `abstract class TestCase extends BaseTestCase { use CreatesApplication; }` — **no connection assertion / no guard** before tests run.

➡️ Confirms: the ONLY thing standing between a test's `DROP` and `bizmates_new` is the in-`setUp()` runtime switch. This is the structural-guard gap the fix must close.

### 1a — Tier A tests switch to SQLite + purge BEFORE dropping

Mechanically verified for **all 56** drop-issuing files (each contains a `sqlite`/`:memory:` switch; none lacks it) and inspected in detail for 5 representative Tier A files. The pattern in each `setUp()` (or a `useSqliteSchema()` helper it calls) is, in order:

1. `Config::set('database.connections.mysql', [ 'driver' => 'sqlite', 'database' => ':memory:', ... ])` (and the default connection too)
2. `$this->app['db']->purge('mysql')` (and purge default)
3. only then `Schema::...dropIfExists(...)` / `Schema::create(...)`

Line-ordering evidence (sqlite config line < purge line < first drop line):

| File | sqlite cfg | purge | first drop |
|------|-----------|-------|-----------|
| `tests/Unit/RevenueAllocation/RunLifecycleServiceTest.php` | L58 | L65 | L67 |
| `tests/Unit/RevenueAllocation/AllocationInjectorTest.php` | L55 | L61 | L64 |
| `tests/Feature/RevenueAllocation/AllocateEndToEndDev04Test.php` | L89 | L96 | L118 |
| `tests/Unit/RevenueAllocation/InjectionReferencePriceAndActiveRunAuthorityTest.php` | L126 | L132 | L324 |
| `tests/Unit/CommonUtilCreateDailyRateCalculationInjectionTest.php` | L~79 (`useSqliteSchema`) | `purge('mysql')` | first `dropIfExists('mst_product')` after purge |

Note the drops explicitly target the `mysql` connection, e.g. `Schema::connection('mysql')->dropIfExists('log_alloc_calculation_runs')`. That is exactly why the pre-drop re-point of the **`mysql`** connection (not just the default) is load-bearing — and why its absence/misordering would be catastrophic.

➡️ Confirms 1a: on a correct run the tests are safe; the safety is entirely the runtime switch.

### 2 — Tier A vs Tier B classification is accurate

Dropped table names extracted per file (from `dropIfExists(...)` literals and table-array loops). Classification rule: **Tier A** = drops at least one real/shared table (`trn_charge`, `trn_charge_forex`, `mst_product`, `mst_new_price_listing`, `log_daily_rate_calculation(_pre)`, `log_monthly_rate_calculation`, `log_sum_calculation_history`, `log_refund_history`, `v_lesson_ticket_history_stat_monthly`); **Tier B** = drops ONLY new project tables (`log_alloc_*`, `mst_alloc_*`).

Spot-check — Tier A (confirmed drop real tables):

- `tests/Unit/CommonUtilCreateDailyRateCalculationInjectionTest.php` → `trn_charge`, `trn_charge_forex`, `mst_product`, `log_monthly_rate_calculation`, `log_sum_calculation_history`, `v_lesson_ticket_history_stat_monthly` (+ `log_daily_rate_calculation(_pre)`, `log_sum_calculation(_pre)`)
- `tests/Feature/RevenueAllocation/Dev04CapInjectionSmokeTest.php` → `trn_charge`, `trn_charge_forex`, `mst_product`, `log_sum_calculation_history`, `v_lesson_ticket_history_stat_monthly` (+ log_alloc_*)
- `tests/Feature/RevenueAllocation/RefundDev04SmokeTest.php` → `trn_charge`, `trn_charge_forex`, `mst_product`, `log_refund_history`, `log_sum_calculation_history`, `v_lesson_ticket_history_stat_monthly`
- `tests/Unit/RevenueAllocation/BundleDetectionServicePropertyTest.php` → `trn_charge`, `log_daily_rate_calculation`
- `tests/Unit/RevenueAllocation/ProductTypeGuardPropertyTest.php` → `mst_product`
- `tests/Unit/RevenueAllocation/ReferencePriceSeederTest.php` → `mst_new_price_listing` (real) + `mst_alloc_reference_prices` (new)
- `tests/Unit/RevenueAllocation/RefundChargeDetectorTest.php` → `trn_charge`, `log_refund_history`, `log_daily_rate_calculation(_pre)`

Spot-check — Tier B (confirmed drop only new tables):

- `tests/Unit/RevenueAllocation/RunLifecycleServiceTest.php` → `log_alloc_calculation_runs`, `log_alloc_run_anchors`
- `tests/Unit/RevenueAllocation/LogAllocBundleOutcomeTest.php` → `log_alloc_bundle_outcomes`
- `tests/Unit/RevenueAllocation/AllocationBalancePropertyTest.php` → `log_alloc_groups`, `log_alloc_prorations`
- `tests/Unit/Libs/AllocationDetailGuardedInjectionCrossCuttingTest.php` → `log_alloc_calculation_runs`
- `tests/Feature/RevenueAllocation/AllocationDetailGuardPropertyTest.php` → `log_alloc_calculation_runs`

**No misclassification found** — in particular, no "Tier B" file was observed dropping a real table (the dangerous error class). One classification nuance to make explicit for the ticket: `mst_alloc_reference_prices` is a **new** table (Tier B), so files touching only it (e.g. `ReferencePriceResolverPropertyTest`, `ReferencePriceDecemberResolutionTest`) are correctly Tier B, whereas `ReferencePriceSeederTest` is Tier A because it also drops the real `mst_new_price_listing`. Cristoff's split is consistent with this.

### 3 — Highest-risk file confirmed

`tests/Unit/CommonUtilCreateDailyRateCalculationInjectionTest.php` drops the broadest real set: `mst_product`, `trn_charge`, `trn_charge_forex`, `log_daily_rate_calculation`, `log_daily_rate_calculation_pre`, `log_monthly_rate_calculation`, `log_sum_calculation`, `log_sum_calculation_pre`, `log_sum_calculation_history`, `v_lesson_ticket_history_stat_monthly`. This is the single most destructive blast radius if the SQLite switch failed. **Confirmed.**

### 4 — Hard `->drop()` (not IfExists) in a test

`tests/Unit/RevenueAllocation/Dev04CapTestDataSeederTest.php:307`:

```php
Schema::connection('mysql')->drop('log_daily_rate_calculation');
```

- It is in a **test** (`test_warns_and_continues_when_data_is_thin`), intentionally dropping the real-named table `log_daily_rate_calculation` to force insert failures.
- It is the **only** hard `->drop(` / `Schema::drop(` (excluding `dropIfExists`/`dropColumn`/`dropForeign`/`dropIndex`) in the entire `tests/` tree — grep returns exactly this one line.
- Safe only because the same file re-points `mysql` to sqlite in `setUp()` (L60–68: `Config::set('database.connections.mysql', ['driver'=>'sqlite','database'=>':memory:'...])` then `purge('mysql')`). A hard `drop()` is strictly more dangerous than `dropIfExists` because it also throws if the table is absent, but the data-loss risk is identical. **Confirmed.**

### 5 — ls-db SAFE claim

In `ls-database-migrations/tests`, the ONLY file issuing any DDL (drop/create table or database, truncate) is `tests/Unit/Database/AllocMigrationRoundTripTest.php`. Its guards, all present:

1. **Opt-in env flag** — `hasOptedIn()` reads `env('ALLOC_ROUNDTRIP_TEST')`; false/empty → `markTestSkipped(...)`. A plain `vendor/bin/phpunit` never runs it.
2. **Name suffix required** — `REQUIRED_NAME_SUFFIX = '_roundtrip_test'`; `assertStringEndsWith('_roundtrip_test', $scratchDatabase)` **fails** (not skips) otherwise. Name must also match `/^[A-Za-z0-9_]+$/`.
3. **Collision refusal** — `assertNotContains($scratchDatabase, $this->protectedDatabases)` where `protectedDatabases` = Bizmates connection's real DB + the default connection's DB. Refuses to run if the scratch name equals a configured real DB.
4. **Drops only a DB it created** — `createdScratchDatabase` flag set true only right after its own `CREATE DATABASE IF NOT EXISTS`; it `assertFalse(...)` and refuses to **adopt** a pre-existing scratch DB; `tearDown()` calls `dropScratchDatabaseIfOwned()` which drops only when this run created it and the name still passes every guard.
5. **Pre-DDL connection assertion** — the test body asserts `assertAllocConnectionPointsAtScratchDatabase()` before issuing migration DDL ("The real safety net: nothing below touches the Bizmates dev database.").

**Confirmed: ls-db is SAFE and already structurally guarded (defence in depth).** No other ls-db test creates/drops real tables.

### 6 — Seeders SAFE claim

Source seeders live at `accounting_related_system_for_freee/database/seeders/`. Neither `ReferencePriceSeeder.php` nor `Dev04CapTestDataSeeder.php` contains any `dropIfExists` / `Schema::drop` / `->drop(` / `DROP TABLE` / `TRUNCATE` / `->truncate(` (grep returns nothing). Scoped deletes only:

- `ReferencePriceSeeder::rollback()` (L108) — `->where('bundle_type', BundleType::CAP->value)->where('product_id', $productId)->delete()`: deletes only its own CAP reference-price rows.
- `Dev04CapTestDataSeeder::rollback()` (L137) — deletes `->where('charge_id', '>=', self::CHARGE_ID_BASE)->delete()` and `->where('id', '>=', self::CHARGE_ID_BASE)->delete()`, with `CHARGE_ID_BASE = 990000000` (reserved high id range). A paired unit test asserts a row at `id = 42` survives rollback.

**4 ASCI ls-db seeders are NOT on this branch** — confirmed. `ls-database-migrations/database/seeders/` lists no alloc/ASCI seeder; grep for `asci|alloc` there returns nothing. In the accounting repo the only `asci` hit is a doc comment in `ReferencePriceSeeder.php:43` ("no CIP (10025) row is seeded here; that lives in ASCI") — a forward reference, not a seeder. **Confirmed.**

### 7 — Counts & in-scope filter

- **56** test files issue `dropIfExists`/`Schema::drop`/`->drop(`/`TRUNCATE`/`->truncate(` in the accounting repo: **54** under `tests/**/RevenueAllocation/` + **2** outside it (`tests/Unit/CommonUtilCreateDailyRateCalculationInjectionTest.php` and `tests/Unit/Libs/AllocationDetailGuardedInjectionCrossCuttingTest.php`).
- Cristoff's "**52** (~36 Tier A / ~16 Tier B)" is the correct **order of magnitude** (I find 56; difference ≈ 4, immaterial and likely a counting-boundary nuance such as truncate-only or helper-class exclusion). I did not do an exact per-tier recount, but the Tier A:Tier B ratio he gives (roughly 2:1 toward Tier A) matches what the drop-table map shows.
- **In-scope filter is right.** 68 files carry a `Feature: asca-spec*` tag; the risk-relevant subset is "asca-spec-tagged / under a RevenueAllocation folder **and** issues drop/truncate," plus the 2 named files — which is the 56 above.
- **Out-of-scope exclusions are correct:** `tests/Unit/TrnOtherSalesChargeTest.php` (BARS-8) issues **zero** drop/truncate DDL and is correctly excluded. I saw no obvious in-scope drop-issuing file left out of his two tiers.

---

## 3. Conclusions

- **A (most important):** Root cause is **correct and precisely stated**. The runtime in-`setUp()` re-point to in-memory SQLite (`Config::set(...sqlite/:memory:...)` + `DB::purge('mysql')`) executed before each drop is the **sole** protection. `phpunit.xml` does not force sqlite (both lines commented), there is no `.env.testing`, and the base `TestCase` adds no assertion — so there is **no structural guard**. The default connection points at real `bizmates_new`.
- **B:** Tier A / Tier B real-vs-new classification is **accurate**; no misclassified file, and specifically no "Tier B" file that secretly drops a real table.
- **C:** ls-db SAFE and seeders SAFE claims are **both correct**; ls-db's single DDL test is already defensively guarded, and both seeders use scoped deletes only. The 4 ASCI ls-db seeders are not on this branch.
- **D:** **Cristoff's investigation is trustworthy enough to base the two fix sub-tickets on.** The only adjustments worth noting are immaterial: the raw drop-issuing count is 56 (he said 52, same order of magnitude), and it is worth stating explicitly in the ticket that `mst_alloc_reference_prices` counts as a *new* (Tier B) table while `mst_new_price_listing` is *real* (Tier A) — his split already respects this, but spelling it out prevents a future mis-tag.

---

## 4. Recommended fix shape (for the Lead; DO NOT implement here)

The risk is "a drop/truncate test executed against a non-test DB." The right fix is a **structural guard that makes it impossible** for an accounting test to issue DDL against a non-sqlite/non-test connection, so the fix no longer depends on every test (and every future test) remembering to re-point in `setUp()`.

### Accounting repo (sub-ticket under ASCA-17) — defence in depth, pick 1 + 2 at minimum

1. **Force the test connection at the harness level.** Uncomment / add in `phpunit.xml` `<php>`:
   `DB_CONNECTION=sqlite` and `DB_DATABASE=:memory:` (the two currently-commented lines). This makes the default connection sqlite even if a test forgets to switch. (Caveat: several tests explicitly re-point the **`mysql`** connection and call `Schema::connection('mysql')`, so this alone is not sufficient — hence #2.)
2. **Add a hard assertion in the base `TestCase` (or a dedicated trait/`setUp`) that aborts before any DDL if the active/`mysql` connection driver is not `sqlite` (or the database is not `:memory:` / not a known disposable test DB).** This is the real structural backstop: a mis-ordered or missing per-test switch, or an env that points `mysql` at a real host, fails fast instead of dropping `trn_charge`. Mirror the ls-db approach: assert-connection-is-disposable *before* DDL.
3. **Optional hardening:** convert the lone hard `->drop()` at `Dev04CapTestDataSeederTest.php:307` to `dropIfExists` for consistency (doesn't change the data-loss risk, but removes a sharp edge), and consider centralising the repeated `useSqliteSchema()` setup into a shared trait so the switch cannot be partially copied.

### ls-db repo (sub-ticket under ASCA-16) — essentially a no-op / codify-the-guarantee

- ls-db is **already safe**. The sub-ticket should (a) document/assert that `AllocMigrationRoundTripTest` remains the only DDL-issuing test, and optionally (b) add a CI check or a base-class assertion to prevent a future ls-db test from issuing `CREATE/DROP TABLE`/`DATABASE` without the same opt-in + name-suffix + collision-refusal guards. No data-loss fix is required on this branch.

### Why this shape
The incident ("already happened once on DEV04") is only possible because protection is per-test and runtime. Moving the guarantee into the harness (forced sqlite) **and** a pre-DDL connection assertion (fail-closed) converts a convention every test must follow into an invariant the suite enforces — matching the pattern ls-db already uses and considers safe.
