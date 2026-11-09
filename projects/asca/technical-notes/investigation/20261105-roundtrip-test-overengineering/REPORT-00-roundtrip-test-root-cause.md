# DB-Safety Root Cause — the migration round-trip test is over-engineered

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report |
| **Status** | Active — current conclusion of the DB-safety thread |
| **Date** | 2026-11-05 (Created) |
| **Author** | Noel Palo, Lead |
| **Assisted by** | Kiro |
| **Mode** | READ-ONLY code + git + spec trace. No code changed. |
| **Repos** | `accounting_related_system_for_freee` (branch `feature/ASCA/ASCA-82-dbsafety-guard-accounting`) + `ls-database-migrations` (branch `feature/ASCA/ASCA-83-dbsafety-guard-lsdb`) |
| **JIRA** | ASCA-82, ASCA-83 (follow-on from ASCA-70 / ASCA-16) |
| **Supersedes (recommendation only)** | The *fix recommendation* in the three prior DB-safety reports (see §6). Their findings remain valid and are NOT archived. |

---

## 1. Summary (verdict first)

The DB-safety incident (a test wiping a real table on DEV04) has a single structural root cause: the migration round-trip test `AllocMigrationRoundTripTest` (added under ASCA-16). It executes real `migrate` + `migrate:rollback` against a real MySQL, which is **integration-test behavior filed in the unit-test folder**. To run safely it had to bolt on an opt-in flag (`ALLOC_ROUNDTRIP_TEST=1`) and a required throwaway DB name suffix (`_roundtrip_test`).

**Conclusion:** this test is over-engineered for little real benefit. It adds genuine risk and complexity to prove one thing the project does not use — that a migration rolls back cleanly. The prior reports' structural guards (ASCA-82/83) correctly reduce the blast radius, but the cleaner fix is to **remove the round-trip test** and rely on the existing read-only structure/constraint tests, which already verify the schema with zero DDL and zero risk.

This report does not blame any person or phase. It documents the technical root cause and the recommended simplification.

## 2. Evidence

### 2.1 It is not a unit test (it runs real migrations)
- `AllocMigrationRoundTripTest` calls `Artisan::call('migrate', ...)` and `Artisan::call('migrate:rollback', ...)` against the `bizmates_mysql` connection on a scratch database.
- It is the **only** DDL-issuing test in ls-db (`grep` for `dropIfExists|Schema::drop|CREATE DATABASE|Artisan::call('migrate` across `tests/` returns only this file + the guard trait/tripwire it introduced).

### 2.2 The repo's established pattern is read-only (verified)
- **439** `*TableStructureTest.php` files in `ls-database-migrations/tests/Unit/Database/`. A grep for `migrate` / `Schema::create` / `dropIfExists` across all of them returns **none** — every one is read-only.
- Each uses only `Schema::connection(...)->hasTable()`, `->getColumnListing()`, and `getColumnType()` to assert the table and columns exist with the right types against an already-built DB (sampled: `TrnChargeTableStructureTest`, `MstPlanTableStructureTest`, `LogLoginTableStructureTest`, `MstProductTableStructureTest`).
- Seeder tests (`FlpB2eCampaignSeederTest`, `FlpRequiredDataSeederTest`, `MonthlyPlanPromotionBannerSeederTest`, `B2E15MonthlyLessonPlanContentSeederTest`) run the seeder then read with `DB::table` / `assertDatabaseHas` and clean up their own rows with scoped `->delete()`. None run migrations.
- The 12 ASC tables already have this exact read-only coverage: `LogAlloc*TableStructureTest`, `MstAllocReferencePricesTableStructureTest`, plus `AllocConstraintsTest` (foreign keys) and `AllocProrationsActiveViewTest` (the view).

**So the round-trip test is the single exception to a 439-test, repo-wide read-only pattern.**

### 2.3 Nothing depends on it
- `grep` for `AllocMigrationRoundTrip` / `GuardsDisposableDatabase` / `ALLOC_ROUNDTRIP_TEST` across the whole repo returns only the three DB-safety files themselves. No seeder, seeder test, or other test uses them. Removing the round-trip test touches nothing else.

### 2.4 Production practice
- Production rolls forward. A migration that has shipped is not rolled back as routine; a table/column change is made via a *new* migration that supersedes the old one. Automating "rollback is clean" from day one is a guarantee the project does not rely on, so the risk it introduced is not bought back by value.

## 3. Why the complexity exists
The flag + name-suffix machinery is not gratuitous — it is the *safety patch* for a test that must create/drop real tables. The problem is upstream of the patch: a migrate/rollback test does not belong in the unit suite at all. Remove the test and the entire machinery (flag, scratch-name rule, guard trait's reason-for-being) is no longer needed for ASC.

## 4. Current state of the two PRs (as reviewed, static — no tests run)
- **ASCA-83 (ls-db):** extracts the guards into a reusable `GuardsDisposableDatabase` trait + adds a `NoUnguardedDdlInTestsTest` tripwire. No real-table drops (only guarded scratch-DB `DROP DATABASE` / `migrate:rollback`). The `log_alloc_bundle_outcomes` omission in the round-trip test was fixed (commit `6b5dc55`). Clear to merge.
- **ASCA-82 (accounting):** forces `mysql`/`zipan` to SQLite `:memory:` at bootstrap (B1) + a fail-closed assertion covering default + guarded connections (B2); the one hard `->drop()` is now `dropIfExists`. Meets the prior reports' required fix shape. Minor hardening remains (tighten the disposable-host rule to `:memory:`/`_test` only; uncomment the `phpunit.xml` SQLite lines).

## 5. Recommendation
1. **Merge ASCA-82 and ASCA-83** — they reduce the immediate blast radius and are the agreed interim guard.
2. **Then raise a new ticket per repo** to remove the root cause:
   - **ls-db:** delete `AllocMigrationRoundTripTest` (and, if it becomes unused, the `GuardsDisposableDatabase` trait + `NoUnguardedDdlInTestsTest`). Rely on the existing `LogAlloc*`/`MstAlloc*` structure tests + `AllocConstraintsTest` + `AllocProrationsActiveViewTest`.
   - **accounting:** confirm no remaining ASC test runs real migrations / drops a real table; keep only schema + light seeded-data checks against an already-built DB.
3. **Principle to carry forward:** tests should not run migrations. The migration builds the DB once (setup); tests then check the already-built structure (table/columns/types) + a light seeded-data check — exactly how the other 439 structure tests and the seeder tests already work.

## 6. Relationship to the prior DB-safety reports
These remain valid records and are **NOT archived or superseded in their findings**. This report supersedes only their *fix recommendation* (add structural guards) by adding the simpler root-cause fix (remove the round-trip test):

- `20261020-unit-test-table-drop-data-loss/REPORT-00-investigation-brief.md` — the original risk discovery + classification brief. Findings stand.
- `20261023-asca70-dbsafety-verification/REPORT-00-asca70-verification.md` — independent verification of the risk classification. Findings stand.
- `20261023-dbsafety-reground-post-asca78/REPORT-00-dbsafety-reground.md` — re-grounding of the fix shape against post-ASCA-78 HEAD. Its recommended guard shape is the ASCA-82/83 interim fix; this report adds the follow-on removal.

No file is moved to `archive/`. The three prior reports are cross-referenced as the earlier layers of the same thread.
