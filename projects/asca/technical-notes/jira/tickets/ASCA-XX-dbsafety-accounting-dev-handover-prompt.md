# Dev Handover Prompt — DB-safety guard (accounting, sub-task under ASCA-17)

> Paste-ready context + instructions for the assigned dev's Kiro. Grounded on accounting `feature/ASCA/ASCA-master` HEAD `07ab9ab6` (post ASCA-78/79).
>
> **Working agreement (important):** The approach below is fully specified — the exact files, the exact mechanism, and the one subtle ordering issue are all decided for you. **All you need to do is understand the ticket's goal (prevent a test from dropping a real/shared table) and implement the steps exactly.** Verify the cited files/line numbers against the LIVE code first. **Only stop and ask the Lead (Noel) if the live code does NOT match what's described here (e.g. `CreatesApplication::createApplication()` looks different than expected) — in that case ask immediately, do NOT improvise a different design.** Asking early beats guessing.

---

## Branch

```
git checkout feature/ASCA/ASCA-master
git pull
git checkout -b feature/ASCA/ASCA-XX-dbsafety-guard-accounting
```

## Paste this into the dev's Kiro (one message)

```
Context load (ASCA):
Learn the agentic-toolkit and bizmates-dev-context, then read projects/asca/project-context.md, then learn the related repos: accounting_related_system_for_freee, ls-database-migrations, bizmates.jp, MBTI_backend

Task: Add a STRUCTURAL DB-safety guard so ASCA tests cannot drop/truncate a real shared DB (e.g. DEV04 bizmates_new, tables like trn_charge). Today the only protection is a fragile per-test inline sqlite switch; a real-table wipe already happened once on DEV04. This is a test-infrastructure fix, NOT an allocation-logic change.

Read first (ground truth — do not act from memory, and do not reference deleted files):
- The CR ticket: projects/asca/technical-notes/jira/tickets/ASCA-XX-dbsafety-guard-accounting.md
- The re-grounding report (current HEAD, exact files/lines): projects/asca/technical-notes/investigation/20261023-dbsafety-reground-post-asca78/REPORT-00-dbsafety-reground.md
- The ls-db gold-standard guard to mirror: ls-database-migrations/tests/Unit/Database/AllocMigrationRoundTripTest.php

CRITICAL groundings (verify against live code before editing):
1. Do NOT reference or chase any AllocationDetail* or RevenueAllocationCsvService* test — ASCA-78 deleted all 16; they no longer exist. grep "AllocationDetail\|RevenueAllocationCsvService" tests/ app/ must return nothing.
2. phpunit.xml alone CANNOT fix this: config/database.php hardcodes driver=mysql for the 'mysql' connection, and most tests drop via Schema::connection('mysql'). So the real backstop is a code-level assertion, not just env.
3. The sqlite switch today is INLINE in each test's setUp() (Config::set('database.connections.mysql',[...sqlite/:memory:...]) + $this->app['db']->purge('mysql')). There is NO shared trait. All 43 risky tests extend the bare Tests\TestCase (tests/TestCase.php) — that is the single place to add the guard.

THE APPROACH IS DECIDED (do not design your own; implement exactly this). The guard must act at BOOTSTRAP, before any test's setUp() runs — NOT as an assertion inside a base setUp(). Reason: every risky test re-points mysql→sqlite INSIDE its own setUp() AFTER parent::setUp(); a base setUp() assertion would run before that switch and fail every test. Bootstrap precedes all setUp(), so neutralising there is order-proof and needs zero edits to the 43 tests.

Implement (three parts, all required):

A. phpunit.xml <php> block: uncomment the two lines
   <server name="DB_CONNECTION" value="sqlite"/>
   <server name="DB_DATABASE" value=":memory:"/>
   This makes the DEFAULT connection sqlite for the suite.

B. tests/CreatesApplication.php — this trait's createApplication() currently reads exactly:
     $app = require __DIR__.'/../bootstrap/app.php';
     $app->make(Kernel::class)->bootstrap();
     return $app;
   Insert the guard BETWEEN the bootstrap() line and `return $app;` (runs at app-boot, before every test's setUp()):
   B1. Force the 'mysql' and 'zipan' connections to disposable sqlite in config, so a test that FORGETS to switch inherits sqlite (not real bizmates_new):
       config(['database.connections.mysql' => ['driver'=>'sqlite','database'=>':memory:','prefix'=>'','foreign_key_constraints'=>false]]);
       config(['database.connections.zipan' => ['driver'=>'sqlite','database'=>':memory:','prefix'=>'','foreign_key_constraints'=>false]]);
       (and purge both so the new config takes effect: app('db')->purge('mysql'); app('db')->purge('zipan');)
   B2. FAIL-CLOSED assertion: immediately after B1, re-read config for the default, 'mysql' and 'zipan' connections and if ANY has driver !== 'sqlite' AND database is not ':memory:' AND the db name is not on a '_test' allowlist → throw a RuntimeException with a loud message (e.g. "DB-SAFETY: test DB connection '<name>' resolved to a non-disposable target '<db>@<host>' — aborting before any test can drop a real table"). Throwing here aborts the whole run before a single DDL executes. Never silently skip.
   (A test's own later Config::set(mysql→sqlite) still works — it just re-sets to the same sqlite; harmless.)

C. Cleanup: convert the one hard ->drop() at tests/Unit/RevenueAllocation/Dev04CapTestDataSeederTest.php:307 (Schema::connection('mysql')->drop('log_daily_rate_calculation')) to dropIfExists. Re-confirm the line number on live code first (it may shift).

Do NOT:
- Add a guard assertion inside a base-class setUp() (wrong ordering — see above).
- Rewrite the 43 tests individually — the bootstrap neutralisation covers them all.
- Touch allocation logic (AllocationInjector incl. overwriteDailyRateRows), seeders, production code, or the ls-db repo (separate ticket).
- Reference any AllocationDetail*/RevenueAllocationCsvService* file.

Verify:
- vendor/bin/phpunit → green with the guard active (all RevenueAllocation + base tests pass; the tests' own inline switches still work on top of the bootstrap sqlite).
- NEGATIVE check: temporarily make B1 point 'mysql' at the real mysql driver/host (or comment B1 so the env mysql/bizmates_new is used) → the B2 assertion must THROW and abort the run before any DROP. Revert after.
- grep "AllocationDetail\|RevenueAllocationCsvService" tests/ app/ → nothing (confirms you didn't resurrect deleted files).

Then open a PR referencing this sub-ticket. Do NOT merge without Lead (Noel) review. Log JIRA time against the sub-ticket.
```

---

## Notes for the Lead (not the dev prompt)

- **The ordering decision is now MADE and baked into the prompt** (option: neutralise + assert at **bootstrap** in `CreatesApplication::createApplication()`, not in a base `setUp()`). This is order-proof because bootstrap runs before every test's inline sqlite switch, and it needs zero edits to the 43 tests. Cristoff has nothing to decide — he implements A/B/C as written. He only asks if the live `CreatesApplication` doesn't look as described.
- Grounded on the real pattern: every risky test does `parent::setUp()` → `Config::set(mysql→sqlite)` → `purge('mysql')` → first `dropIfExists`. The bootstrap neutralisation sits under all of that.
- Priority High (real incident). ls-db is the separate Medium ticket.
