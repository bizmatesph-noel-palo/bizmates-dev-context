# DB-Safety Test-Guard — Re-grounding against current HEAD (post-ASCA-78 / ASCA-79)

**Investigation date:** 2026-10-23
**Mode:** READ-ONLY. No code was changed.
**accounting repo:** `/home/bizdev/dev/accounting_related_system_for_freee`, branch `feature/ASCA/ASCA-master`, HEAD `07ab9ab6` (Merge PR #316 ASCA-78 "Remove Spec 02c AllocationDetail CSV"; parent merge e8fda4e0 = PR #315 ASCA-79).
**ls-db repo:** `/home/bizdev/dev/ls-database-migrations`, branch `feature/ASCA/ASCA-master`, HEAD `94ec95d`.

---

## Summary answer (read this first)

The root cause is **unchanged** on current HEAD. There is still **no structural backstop** against wiping a real shared DB from a test run:

- `phpunit.xml` still has the two forced-SQLite lines **commented out** (`DB_CONNECTION=sqlite`, `DB_DATABASE=:memory:`).
- There is still **no `.env.testing`** file.
- `tests/TestCase.php` is still **bare** — it only pulls in `CreatesApplication`; no connection guard, no `setUp()`.
- The active `.env` has `DB_CONNECTION=mysql` + `DB_DATABASE=bizmates_new` pointing at a live DEV04 host (`host.docker.internal:21323`), and `config/database.php` `default => env('DB_CONNECTION','mysql')`. So absent the per-test runtime switch, the `mysql` (and default) connection points at the real `bizmates_new`.

The only protection today is a **per-test runtime switch** done inline in each test's `setUp()`: re-point `database.connections.mysql` to `sqlite`/`:memory:` via `Config::set(...)`, then `$this->app['db']->purge('mysql')`, **before** any `dropIfExists`. This is fragile — if any new/edited test forgets it, or runs its DDL before the switch, it drops real tables.

**Current risky-test inventory (post-ASCA-78):** 43 test files still issue table-destroying DDL — **35 Tier A** (touch at least one real/shared table) and **8 Tier B** (only `log_alloc_*` / `mst_alloc_*`). ASCA-78 deleted 16 test files + the `RevenueAllocationCsvService`; many of those deletions were previously Tier A, so the inventory shrank. **Do not chase any `AllocationDetail*` or `RevenueAllocationCsvService*` file — they no longer exist.**

**One hard `->drop()` (non-`dropIfExists`) still exists:** `tests/Unit/RevenueAllocation/Dev04CapTestDataSeederTest.php:307`, dropping the Tier-A table `log_daily_rate_calculation`.

**Tests target BOTH connections:** most use `Schema::connection('mysql')->...`; at least one (`CommonUtilCreateDailyRateCalculationInjectionTest`) also drops on the **default** connection. So forcing only the default connection in `phpunit.xml` is **NOT sufficient** — the guard must cover the `mysql` connection too.

**Best hook for a fail-closed assertion:** all RevenueAllocation tests extend the shared `Tests\TestCase`, but that base is bare and performs no `setUp()` switch (the switch is inline per test). The single best structural place is the shared `tests/TestCase.php` base (a `setUp()` fail-closed assertion there is inherited by every test), complemented by uncommenting the two `phpunit.xml` lines.

**ls-db:** `tests/Unit/Database/AllocMigrationRoundTripTest.php` is still the **only** DDL-issuing test and remains fully guarded (opt-in flag, name-suffix allowlist, collision refusal, create-then-own, pre-DDL assertion).

---

## A. Current risky-test inventory (post-ASCA-78)

Discovery command (current HEAD):
```
grep -rn "dropIfExists|Schema::drop|->drop(|DROP TABLE|TRUNCATE|->truncate(" tests/
```
Findings:
- `TRUNCATE` / `->truncate(` / raw `DROP TABLE`: **none** in `tests/`.
- `dropIfExists` / `->drop(`: **43 unique files**.

Tier split uses the real/shared table list: `trn_charge, trn_charge_forex, mst_product, mst_new_price_listing, log_daily_rate_calculation(_pre), log_monthly_rate_calculation, log_sum_*, log_refund_history, v_lesson_ticket_history_stat_monthly`.

### Tier A — drops at least one REAL/shared table (35 files)

Unit (17):
1. `tests/Unit/CommonUtilCreateDailyRateCalculationInjectionTest.php` — `mst_product, trn_charge, trn_charge_forex, log_daily_rate_calculation, log_monthly_rate_calculation, log_sum_*, v_lesson_ticket_history_stat_monthly` (also drops on the **default** connection)
2. `tests/Unit/RevenueAllocation/ReRunIdempotencePropertyTest.php`
3. `tests/Unit/RevenueAllocation/OutcomeRecordingSurvivesRollbackPropertyTest.php`
4. `tests/Unit/RevenueAllocation/RefundOutcomeRecordingTest.php`
5. `tests/Unit/RevenueAllocation/RefundPositiveNotSkippedExampleTest.php`
6. `tests/Unit/RevenueAllocation/InjectionPreFinalBatchCoverageTest.php`
7. `tests/Unit/RevenueAllocation/AllocationInjectorTest.php`
8. `tests/Unit/RevenueAllocation/ProductTypeGuardPropertyTest.php` (`mst_product`)
9. `tests/Unit/RevenueAllocation/ExclusionFilteringPropertyTest.php`
10. `tests/Unit/RevenueAllocation/BundleDetectionServicePropertyTest.php`
11. `tests/Unit/RevenueAllocation/Dev04CapTestDataSeederTest.php` **(contains the one hard `->drop()` — see D)**
12. `tests/Unit/RevenueAllocation/RefundAppRowWriterTest.php` (`log_daily_rate_calculation`)
13. `tests/Unit/RevenueAllocation/RefundLinkageResolverTest.php` (`trn_charge, log_refund_history`)
14. `tests/Unit/RevenueAllocation/InjectionBalancePropertyTest.php`
15. `tests/Unit/RevenueAllocation/InjectionReferencePriceAndActiveRunAuthorityTest.php`
16. `tests/Unit/RevenueAllocation/RefundChargeDetectorTest.php`
17. `tests/Unit/RevenueAllocation/ReferencePriceSeederTest.php` (`mst_new_price_listing`, `mst_alloc_reference_prices`)

Feature (18):
18. `tests/Feature/RevenueAllocation/RefundNewAppRowPropertyTest.php`
19. `tests/Feature/RevenueAllocation/RefundNoNettingPropertyTest.php`
20. `tests/Feature/RevenueAllocation/InjectionRunLevelFailurePropertyTest.php`
21. `tests/Feature/RevenueAllocation/Dev04CapInjectionSmokeTest.php` (widest real-table footprint, incl. `v_lesson_ticket_history_stat_monthly`)
22. `tests/Feature/RevenueAllocation/RefundPositiveNotSkippedPropertyTest.php`
23. `tests/Feature/RevenueAllocation/RefundExecutionMonthLumpPropertyTest.php`
24. `tests/Feature/RevenueAllocation/RefundNewAppRowDownstreamTest.php`
25. `tests/Feature/RevenueAllocation/InjectionStandaloneAppAndZeroAppGateTest.php`
26. `tests/Feature/RevenueAllocation/RefundPairIsolationPropertyTest.php`
27. `tests/Feature/RevenueAllocation/InjectionPairIsolationPropertyTest.php`
28. `tests/Feature/RevenueAllocation/RefundShareholderCashbackTest.php`
29. `tests/Feature/RevenueAllocation/RefundIdempotencePropertyTest.php`
30. `tests/Feature/RevenueAllocation/InjectionFailureClassificationPropertyTest.php`
31. `tests/Feature/RevenueAllocation/RefundDev04SmokeTest.php` (widest real-table footprint)
32. `tests/Feature/RevenueAllocation/InjectionExclusionPropertyTest.php`
33. `tests/Feature/RevenueAllocation/RefundLaterMonthCaseIiTest.php`
34. `tests/Feature/RevenueAllocation/RefundLinkagePropertyTest.php`
35. `tests/Feature/RevenueAllocation/AllocateEndToEndDev04Test.php` (`mst_new_price_listing` among others)

### Tier B — drops only `log_alloc_*` / `mst_alloc_*` (8 files)
1. `tests/Unit/RevenueAllocation/ReferencePriceResolverPropertyTest.php` (`mst_alloc_reference_prices`)
2. `tests/Unit/RevenueAllocation/AllocationPersistenceSnapshotPropertyTest.php`
3. `tests/Unit/RevenueAllocation/RunLifecycleActiveFinalPropertyTest.php`
4. `tests/Unit/RevenueAllocation/LogAllocBundleOutcomeTest.php`
5. `tests/Unit/RevenueAllocation/RunLifecycleServiceTest.php`
6. `tests/Unit/RevenueAllocation/AllocationBalancePropertyTest.php`
7. `tests/Feature/RevenueAllocation/ReferencePriceDecemberResolutionTest.php` (`mst_alloc_reference_prices`)
8. `tests/Feature/RevenueAllocation/RunLifecycleConcurrencyTest.php`

> Note: Tier B still issues DDL and still relies on the runtime sqlite switch; the structural guard must protect them too. A failed switch in a Tier-B test would still drop a real `mst_alloc_reference_prices` / `log_alloc_*` table on the shared DB (those tables exist on DEV04 from the Spec-02 migrations).

### Files now GONE because ASCA-78 deleted them (do NOT chase these)
ASCA-78 (commit `94a8d88d`) deleted `app/Libs/RevenueAllocation/RevenueAllocationCsvService.php` (473 lines) and **16 test files**. Of those deletions, the following were previously flagged as DDL-issuing / Tier-A risks and no longer exist:
- `tests/Feature/RevenueAllocation/AllocationDetailCipExclusionPropertyTest.php` (was Tier A — `log_daily_rate_calculation`)
- `tests/Feature/RevenueAllocation/AllocationDetailCompletenessPropertyTest.php` (was Tier A)
- `tests/Feature/RevenueAllocation/AllocationDetailConsistencyPropertyTest.php` (was Tier A)
- `tests/Feature/RevenueAllocation/AllocationDetailDev04SmokeTest.php` (was Tier A)
- `tests/Feature/RevenueAllocation/AllocationDetailGuardPropertyTest.php` (DDL, alloc-only)
- `tests/Unit/RevenueAllocation/AllocationDetailReproducibilityPropertyTest.php` (was Tier A)
- `tests/Unit/RevenueAllocation/AllocationDetailBomAndStorageTest.php` (was Tier A)
- `tests/Unit/RevenueAllocation/AllocationDetailLabelMapsTest.php` (was Tier A)
- `tests/Unit/RevenueAllocation/RevenueAllocationCsvServiceWriteTest.php` (was Tier A)
- `tests/Unit/RevenueAllocation/RevenueAllocationCsvServiceAllocatedRowsTest.php` (was Tier A)
- `tests/Unit/RevenueAllocation/RevenueAllocationCsvServiceExceptionRowsTest.php` (was Tier A)
- `tests/Unit/RevenueAllocation/LogAllocCalculationRunHasCompletedRunTest.php` (DDL, alloc-only)
- `tests/Unit/RevenueAllocation/CommonUtilAllocationDetailFileConfigTest.php`
- `tests/Unit/Libs/AllocationDetailGuardedInjectionCrossCuttingTest.php` (referenced `trn_charge`)
- `tests/Unit/Libs/SendJournalsDataLogicAllocationDetailInjectionTest.php` (referenced `trn_charge`)
- `tests/Unit/Libs/DailyRateCalculationPreLogicCreateSendMailAttacheFileTest.php`

`grep -rln "RevenueAllocationCsvService|AllocationDetail" tests/ app/` returns **nothing** — no leftover references remain.

---

## B. Root-cause state still holds on current HEAD

### `phpunit.xml` `<php>` block (verbatim, current HEAD)
```xml
<php>
    <server name="APP_ENV" value="testing"/>
    <server name="BCRYPT_ROUNDS" value="4"/>
    <server name="CACHE_DRIVER" value="array"/>
    <!-- <server name="DB_CONNECTION" value="sqlite"/> -->
    <!-- <server name="DB_DATABASE" value=":memory:"/> -->
    <server name="MAIL_MAILER" value="array"/>
    <server name="QUEUE_CONNECTION" value="sync"/>
    <server name="SESSION_DRIVER" value="array"/>
    <server name="TELESCOPE_ENABLED" value="false"/>
</php>
```
The forced-SQLite lines are **still commented out**. Unchanged by ASCA-78/79.

### `.env.testing`
`ls -la .env.testing` → **No such file or directory**. Only `.env`, `.env.compose`, `.env.compose.example`, `.env.example` exist. Unchanged.

### `tests/TestCase.php` (verbatim, current HEAD)
```php
<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    use CreatesApplication;
}
```
Still bare — no connection guard, no `setUp()`. `CreatesApplication` only boots the app from `bootstrap/app.php`. Unchanged.

### Live-DB exposure (why this is dangerous)
`.env` (active block): `DB_CONNECTION=mysql`, `DB_HOST=host.docker.internal`, `DB_PORT=21323`, `DB_DATABASE=bizmates_new`, `DB_USERNAME=root`. `config/database.php`: `'default' => env('DB_CONNECTION','mysql')` and the `mysql`/`zipan` connections read `DB_DATABASE`/`DB_HOST` from env. So with `APP_ENV=testing` but **no** DB override, both the default and the `mysql` connection resolve to the real DEV04 `bizmates_new`. (Secrets referenced by key name only; values not reproduced.)

ASCA-78/79 changed **none** of B.

---

## C. Bootstrap grounding for the fix (the key new part)

### Where/how the sqlite switch happens today
The switch is **inline in each test's `setUp()`**, not in a shared base/trait. The canonical block (example from `tests/Unit/RevenueAllocation/RefundPositiveNotSkippedExampleTest.php`, setUp after `parent::setUp()`):
```php
Config::set('database.connections.mysql', [
    'driver'                  => 'sqlite',
    'database'                => ':memory:',
    'prefix'                  => '',
    'foreign_key_constraints' => false,
]);

$this->app['db']->purge('mysql');

Schema::connection('mysql')->dropIfExists('log_daily_rate_calculation');  // DDL AFTER the switch
```
- The same Config::set + `$this->app['db']->purge('mysql')` pattern is repeated across ~30+ files (grep: `Config::set('database.connections.mysql'` and `->purge('mysql')` / `->purge(self::CONNECTION)`).
- Many files use a class constant `self::CONNECTION = 'mysql'` and call `$this->app['db']->purge(self::CONNECTION)`.
- **Only one file** has an extracted helper: `tests/Unit/RevenueAllocation/AllocationInjectorTest.php` defines a **private** `useSqliteSchema()` (line 52) that does the same Config::set + purge then creates tables. It is private and not shared — other tests do not use it.

### Which connection(s) tests target
- **Most** Tier A/B tests: `Schema::connection('mysql')->dropIfExists(...)` — they explicitly target the **`mysql`** connection.
- **At least one** also targets the **default** connection: `tests/Unit/CommonUtilCreateDailyRateCalculationInjectionTest.php` switches BOTH (`Config::set("database.connections.{$default}", $sqlite)` and `Config::set('database.connections.mysql', $sqlite)`, purges both) and then calls bare `Schema::dropIfExists('mst_product')` (default connection) as well as `trn_charge`, `trn_charge_forex`, etc.

**Consequence:** forcing only the **default** connection to sqlite in `phpunit.xml` is **NOT sufficient**. The guard/override must also neutralise the **`mysql`** connection, because the majority of tests drop via `Schema::connection('mysql')`.

### Single best place for a fail-closed assertion
- All RevenueAllocation tests (and the CommonUtil injection test) extend `Tests\TestCase` (`use Tests\TestCase;` in every file). They share **one** base, but that base currently does nothing in `setUp()`.
- There is **no shared trait** performing the switch (the only helper, `useSqliteSchema()`, is private to one file).
- **Recommendation:** put the fail-closed assertion in the shared `tests/TestCase.php` base, in a `setUp()` that calls `parent::setUp()` then asserts the active DB connections are disposable (sqlite/`:memory:`), so **every** test inherits it automatically. No new trait needs to be introduced; the base class already exists and is universally extended.

### Exact base-test-case path
`tests/TestCase.php` → `namespace Tests; abstract class TestCase extends Illuminate\Foundation\Testing\TestCase (aliased BaseTestCase); use CreatesApplication;`. The `CreatesApplication` trait lives at `tests/CreatesApplication.php`.

---

## D. Exact fix recipe (grounded, for the dev prompt)

### D1. `phpunit.xml` — uncomment the two forced-SQLite lines
File: `phpunit.xml`, inside `<php>`. Change:
```xml
<!-- <server name="DB_CONNECTION" value="sqlite"/> -->
<!-- <server name="DB_DATABASE" value=":memory:"/> -->
```
to active:
```xml
<server name="DB_CONNECTION" value="sqlite"/>
<server name="DB_DATABASE" value=":memory:"/>
```
This makes the **default** connection sqlite for the whole suite. **Not sufficient alone** — see D2 — because tests drop via `Schema::connection('mysql')`, whose config is still the env-driven mysql block. Also add a sqlite `mysql` (and `zipan`) connection override, or force `DB_HOST`/`DB_DATABASE` to an obviously-disposable value, so a missed inline switch cannot reach DEV04. (Because `config/database.php` hardcodes `'driver' => 'mysql'` for the `mysql` connection, the cleanest structural override is the fail-closed assertion in D2 plus pointing `DB_DATABASE` at a non-real name; a pure phpunit.xml change cannot flip the `mysql` connection's driver.)

### D2. Fail-closed assertion — in the shared base `tests/TestCase.php`
File: `tests/TestCase.php`, method: add `protected function setUp(): void`.
Logic (abort/skip the whole test before any DDL can run) for **both** the default connection AND the `mysql` connection:
- Resolve the active connection name (`config('database.default')`) and also explicitly check the `mysql` connection.
- For each, read its config and **fail-closed** unless it is clearly disposable:
  - driver is `sqlite`, OR
  - database is `:memory:`, OR
  - database name matches a known disposable/test allowlist (e.g. ends in `_test` / is `:memory:`), AND host is not a real DEV host.
- If the active `mysql`/default connection's driver is **not** sqlite / database is **not** `:memory:` / name is **not** on the disposable allowlist → `$this->fail(...)` (loud, never silently skip) BEFORE the test body / before `setUp()` returns.

Mirror the ls-db pattern (see E): assert-before-DDL, fail (not skip) on a non-disposable target, never adopt a real DB. Because this lives in the shared base and runs in `setUp()` before each test's own `setUp()` DDL body executes, every Tier A and Tier B test inherits it. (Note: with inline switches still present, the base assertion must either run after the app boots and read the *resolved* config, or the inline switches should be refactored to the base; the safest incremental step is to keep the inline switches and add the base-class assertion as a backstop that verifies the connection is disposable immediately before the first DDL — plus the phpunit.xml override so the default never starts as real mysql.)

### D3. The one hard `->drop()` still exists post-ASCA-78
Re-check command (excluding safe variants):
```
grep -rn "Schema::.*->drop(\|->drop('" tests/ | grep -v "dropIfExists|dropColumn|dropForeign|dropIndex|dropPrimary|dropUnique"
```
Result — **one** match:
- `tests/Unit/RevenueAllocation/Dev04CapTestDataSeederTest.php:307` → `Schema::connection('mysql')->drop('log_daily_rate_calculation');`

Context (test `test_warns_and_continues_when_data_is_thin`): it deliberately `->drop()`s `log_daily_rate_calculation` (a Tier-A real table) to force every daily insert to fail, then recreates it at line ~320. This is the single most dangerous line if the sqlite switch is ever skipped — it is a hard drop of a real table on the `mysql` connection. The structural guard (D2) must be in force before this runs.

---

## E. ls-db re-confirm

**Repo/branch:** `/home/bizdev/dev/ls-database-migrations`, `feature/ASCA/ASCA-master`, HEAD `94ec95d`.

`grep -rln "dropIfExists|Schema::drop|->drop(|DROP TABLE|TRUNCATE|->truncate(" tests/` → **one file only**:
`tests/Unit/Database/AllocMigrationRoundTripTest.php`. It is still the ONLY DDL-issuing test and is **fully guarded**. The reusable guard pattern (quote the exact method/const names in the ls-db ticket):

- **Opt-in flag:** `private const` driven by `ALLOC_ROUNDTRIP_TEST`; `private function hasOptedIn()` (line 312); if not set, `markTestSkipped(...)` in `setUp()` so a plain `vendor/bin/phpunit` never runs it.
- **Name-suffix allowlist + collision refusal:** `private const REQUIRED_NAME_SUFFIX = '_roundtrip_test'`; `private function assertScratchDatabaseNameIsDisposable(string $scratchDatabase)` (line 334) — uses `assertMatchesRegularExpression` + `assertStringEndsWith`, and **fails (never skips)** on a bad name ("a misconfigured scratch name is an operator error that must be loud").
- **Owns-what-it-drops (create-then-own):** Guard 4 in `setUp()` — `assertFalse($this->databaseExists($scratchDatabase), ...)` refuses to adopt a pre-existing DB; only a DB this run created is ever dropped. Supporting: `private function resolveProtectedDatabases()` (line 371), `private function configuredDatabase()` (line 390).
- **Connection redirect + pre-DDL assertion:** `private function redirectAllocConnectionToScratchDatabase()` (line 403) then `private function assertAllocConnectionPointsAtScratchDatabase()` (line 417) — asserts the connection points at the scratch DB **before any DDL**; `assertNotContains(...)` guards against protected DB names.
- **Guaranteed restore:** `private function restoreAllocConnectionConfig()` (line 441) in `tearDown()` restores config even if an assertion failed, then drops the scratch DB only if this run created it and the name still passes every guard.
- **No-residue assertions:** `assertNoAllocTablesRemain()` (585), `assertNoAllocForeignKeysRemain(string $stage)` (644), `assertNoForeignKeyBackingIndexesRemain(...)`.

Constants it operates on: `CONNECTION = 'bizmates_mysql'`, `DEFAULT_SCRATCH_DATABASE = 'bizmates_alloc_roundtrip_test'`, `VIEW_NAME = 'v_alloc_prorations_active'`, plus `ALLOC_TABLES`, `FOREIGN_KEYS`, `CONSTRAINT_UNIQUE_KEYS`, `ANCHOR_UNIQUE_KEY = 'uk_bundle_type_target_ym'`.

This is the proven, reusable template the accounting-repo fix (D2) should imitate: **opt-in, name-allowlist, collision-refusal, owns-what-it-drops, assert-before-DDL, fail-loud-never-skip**.

---

## Conclusions & recommendations

1. **The fix is still needed and still well-scoped.** Nothing in ASCA-78/79 added a structural guard. The three root-cause facts (commented phpunit lines, missing `.env.testing`, bare `TestCase`) all hold on HEAD `07ab9ab6`.
2. **Two-part structural guard (accounting repo):**
   - (a) Uncomment the two `phpunit.xml` forced-SQLite lines and ensure the `mysql`/`zipan` connections cannot resolve to a real host during tests (override `DB_DATABASE`/`DB_HOST` to a disposable value, since the `mysql` driver is hardcoded in config and can't be flipped by phpunit.xml alone).
   - (b) Add a **fail-closed `setUp()` assertion in the shared `tests/TestCase.php`** that aborts (loudly, `fail()` not skip) unless BOTH the default connection AND the `mysql` connection are disposable (sqlite / `:memory:` / name on a `_test` allowlist). This is the single inheritance point for all 43 risky files.
3. **Cover the `mysql` connection explicitly** — the majority of tests drop via `Schema::connection('mysql')`, and one also targets the default. A default-only guard misses them.
4. **Watch the one hard `->drop()`** at `Dev04CapTestDataSeederTest.php:307` (`log_daily_rate_calculation`) — it is the highest-impact line if the runtime switch is ever skipped.
5. **Do not reference deleted artifacts** — all `AllocationDetail*` and `RevenueAllocationCsvService*` files were removed by ASCA-78; the ticket/dev prompt must not list them.
6. **ls-db needs no change** — `AllocMigrationRoundTripTest.php` is already the gold-standard guarded pattern; reference its named guard methods as the template for the accounting fix.
