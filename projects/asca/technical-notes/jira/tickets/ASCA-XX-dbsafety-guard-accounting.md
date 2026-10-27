# ASCA-82 — [Spec 01][DB Safety] Structural guard so tests cannot drop a real/shared DB (accounting)

> **Created in JIRA 2026-10-27 as [ASCA-82](https://bizmates.atlassian.net/browse/ASCA-82)** — Sub-task under ASCA-17, Priority High, Unassigned, status To Do. Linked "relates to" ASCA-70. This file is the source of record; the JIRA ticket carries the same content (renders Markdown). Dev handover prompt: `ASCA-XX-dbsafety-accounting-dev-handover-prompt.md`.

**Type:** Subtask
**Parent:** ASCA-17 ([Spec 01] — Coding (accounting application))
**Priority:** High
**Assignee:** Dev
**Grounded on:** accounting repo `feature/ASCA/ASCA-master` HEAD `07ab9ab6` (post ASCA-78 + ASCA-79)
**Source (investigations):** ASCA-70 (Cristoff's findings, Done) · verification `projects/asca/technical-notes/investigation/20261023-asca70-dbsafety-verification/REPORT-00-asca70-verification.md` · **re-grounding (current HEAD)** `projects/asca/technical-notes/investigation/20261023-dbsafety-reground-post-asca78/REPORT-00-dbsafety-reground.md`

---

## The one trap — do NOT miss this

**The guard MUST act at BOOTSTRAP, not in a base `setUp()`.** Every risky test re-points `mysql→sqlite` INSIDE its own `setUp()` (after `parent::setUp()`). A guard placed in a base `setUp()` runs BEFORE that switch and would fail every test. Bootstrap (`CreatesApplication::createApplication()`) runs before all `setUp()`, so neutralising there is order-proof and needs zero edits to the 43 tests. Get this wrong and either every test fails, or the guard does nothing. (Full rationale in the dev-handover prompt.)

## Summary

Add a structural guard so an ASCA test can NEVER issue table-destroying DDL (`dropIfExists` / `drop`) against a real/shared database. Today the only protection is a fragile per-test, inline runtime switch to in-memory SQLite in each test's `setUp()`; there is no backstop. A real-table wipe already happened once on DEV04.

## Context (grounded on current HEAD `07ab9ab6`)

- **43 test files** still issue table-destroying DDL in `setUp()`: **35 Tier A** (drop at least one REAL/shared table — `trn_charge`, `trn_charge_forex`, `mst_product`, `mst_new_price_listing`, `log_daily_rate_calculation(_pre)`, `log_monthly_rate_calculation`, `log_sum_*`, `log_refund_history`, `v_lesson_ticket_history_stat_monthly`) and **8 Tier B** (drop only new `log_alloc_*` / `mst_alloc_*`). Full list in the re-grounding report §A.
- **Root cause (still true on HEAD):** `phpunit.xml` has the forced-SQLite lines COMMENTED OUT; there is no `.env.testing`; `tests/TestCase.php` is bare (no `setUp()`, no guard). The active `.env` points `DB_CONNECTION=mysql` / `DB_DATABASE=bizmates_new` at a live DEV04 host. So absent the per-test switch, both the default AND the `mysql` connection resolve to the real `bizmates_new`.
- **The switch is inline per test** (`Config::set('database.connections.mysql', [...sqlite/:memory:...])` + `$this->app['db']->purge('mysql')` before the drop). There is NO shared trait/base doing it — only one private `useSqliteSchema()` in `AllocationInjectorTest`. All 43 extend the bare `Tests\TestCase`.
- **Tests target BOTH connections:** most use `Schema::connection('mysql')->...`; `CommonUtilCreateDailyRateCalculationInjectionTest` also drops on the **default** connection. So a default-only phpunit guard is NOT sufficient.
- **Technical constraint:** `config/database.php` hardcodes `'driver' => 'mysql'` for the `mysql` connection, so `phpunit.xml` env alone CANNOT flip that connection to sqlite — the real backstop must be a code-level assertion.
- This is a **test-infrastructure safety fix**, not an allocation-logic change.

## Scope (accounting repo `accounting_related_system_for_freee`)

Structural guard applied at **bootstrap** (before any test's `setUp()` runs), so it is order-proof and needs zero edits to the 43 tests. (A base-class `setUp()` assertion would be WRONG — it runs before each test's inline `mysql→sqlite` switch and would fail every test. See the dev-handover prompt for the full rationale.)

1. **`phpunit.xml`** — uncomment the two forced-SQLite lines in `<php>`:
   - `<server name="DB_CONNECTION" value="sqlite"/>`
   - `<server name="DB_DATABASE" value=":memory:"/>`
   Makes the DEFAULT connection sqlite for the suite. (Necessary but NOT sufficient — the `mysql` connection driver is hardcoded in `config/database.php`, and most tests drop via `Schema::connection('mysql')`.)
2. **`tests/CreatesApplication.php` — neutralise + assert at app-boot.** In `createApplication()`, after the app bootstraps:
   - **Neutralise:** force the `mysql` and `zipan` connections to disposable sqlite `:memory:` in config and `purge` both, so a test that forgets its inline switch inherits sqlite instead of real `bizmates_new`.
   - **Fail-closed assert:** immediately after, if the default / `mysql` / `zipan` connection is still non-disposable (driver not `sqlite`, database not `:memory:`, name not on a `_test` allowlist) → throw a loud `RuntimeException` that aborts the whole run before any DDL executes. Never silently skip. (Mirrors the ls-db gold-standard: assert-before-DDL, fail-loud — see `AllocMigrationRoundTripTest`.)
   Because bootstrap precedes every test's `setUp()`, this covers all 43 files and the tests' own inline switches still work harmlessly on top.
3. **Cleanup (same PR):** convert the one hard `->drop()` at `tests/Unit/RevenueAllocation/Dev04CapTestDataSeederTest.php:307` (`Schema::connection('mysql')->drop('log_daily_rate_calculation')`) to `dropIfExists` for consistency (same data-loss risk, removes a sharp edge).

## Out of scope / do NOT touch

- Do NOT rewrite the 43 tests individually — the base-class guard protects them all.
- Do NOT reference or chase any `AllocationDetail*` / `RevenueAllocationCsvService*` test — **ASCA-78 deleted all 16**; they no longer exist.
- Allocation logic (02a/02b engine incl. `AllocationInjector::overwriteDailyRateRows()`), seeders (verified safe — scoped deletes), ls-db (separate sub-ticket under ASCA-16), production code.

## Acceptance Criteria (Definition of Done)

- [ ] `phpunit.xml` forces `DB_CONNECTION=sqlite` / `DB_DATABASE=:memory:` for the test run.
- [ ] `tests/CreatesApplication.php` neutralises the `mysql` + `zipan` connections to sqlite `:memory:` at app-boot AND fail-closed throws (loud, aborts the run) if any default/`mysql`/`zipan` connection is non-disposable — BEFORE any test `setUp()` / DDL runs.
- [ ] Verified by a deliberate NEGATIVE test: make the boot-time neutralisation point `mysql` at a non-sqlite target (or comment it so env `bizmates_new` is used) → the run ABORTS at the assertion, does NOT issue a DROP. Revert after.
- [ ] The hard `->drop()` at `Dev04CapTestDataSeederTest.php:307` is `dropIfExists`.
- [ ] Full `vendor/bin/phpunit` passes with the guard active (all 43 RevenueAllocation + base tests green; tests' inline switches still work on top of the boot sqlite).
- [ ] No allocation-logic or seeder behavior changed; no `AllocationDetail*` file referenced.

## Verification

- `vendor/bin/phpunit` → green with the guard active.
- Negative check (above): guard aborts, no DROP on a real connection. Revert.

## Handover — resources the dev needs

1. **Paste-ready dev-Kiro prompt (START HERE):** `projects/asca/technical-notes/jira/tickets/ASCA-XX-dbsafety-accounting-dev-handover-prompt.md` — context-load + branch step + the decided A/B/C approach. Paste into the assigned dev's Kiro.
2. **Read-only grounding (exact files/lines on current HEAD):** `projects/asca/technical-notes/investigation/20261023-dbsafety-reground-post-asca78/REPORT-00-dbsafety-reground.md`.
3. **Gold-standard guard to mirror:** `ls-database-migrations/tests/Unit/Database/AllocMigrationRoundTripTest.php` (assert-before-DDL, fail-loud).
4. **Branch:** `git checkout feature/ASCA/ASCA-master && git pull && git checkout -b feature/ASCA/ASCA-82-dbsafety-guard-accounting`.

Verify against live code first; only ask the Lead (Noel) if the live code differs from the prompt — do NOT improvise a different design. PR referencing ASCA-82; do not merge without Lead review.

## Tracking

- Follow-on from the ASCA-70 investigation (Done). Grounded on current HEAD post-ASCA-78/79. Log time here.
