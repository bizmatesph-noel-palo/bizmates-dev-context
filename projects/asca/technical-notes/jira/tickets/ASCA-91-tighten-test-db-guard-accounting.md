# ASCA-91 — [DB Safety] Tighten the test-database guard to sqlite or _test only (accounting)

> **Created in JIRA 2026-11-09 as [ASCA-91](https://bizmates.atlassian.net/browse/ASCA-91)** — Sub-task under ASCA-17 (the parent story is already Done), Priority Medium, **Unassigned**, status To Do. This file is the source of record; the JIRA ticket carries the same content. Follows ASCA-82. Companion: ASCA-90 (ls-db).

**Type:** Sub-task
**Parent:** ASCA-17 ([Spec 01] — Coding (accounting application))
**Priority:** Medium
**Repo:** `accounting_related_system_for_freee`, base branch `feature/ASCA/ASCA-master` (must contain ASCA-82)
**Lead decision recorded here:** do NOT uncomment the `phpunit.xml` SQLite lines (the 2026-11-05 plan had them as a hardening item). The bootstrap guard from ASCA-82 already forces `mysql` and `zipan` to SQLite and checks the default connection, and forcing the default connection could break older non-ASC tests, which are out of scope. Only the host rule is tightened.

---

## Goal

Make the test-database guard accept only in-memory SQLite or a database whose name ends in `_test`, and add a small test for that rule.

## Why

ASCA-82 added a guard in `tests/CreatesApplication.php`. It forces the `mysql` and `zipan` connections to SQLite when the tests start, and it aborts the run if a connection still looks like a real database. One rule in it is too loose: `connectionIsDisposable()` also accepts a real database name, such as `bizmates_new`, when the host is `localhost`, `127.0.0.1`, `::1`, `host.docker.internal`, `mysql` or `test-db`. A local copy of the real database, or a tunnel to DEV04 on `127.0.0.1`, would pass. After this change only the two safe cases pass.

## Steps

### Step 1 - Create the branch

Create a branch from `feature/ASCA/ASCA-master`, named after this ticket key. Check that `tests/CreatesApplication.php` contains `neutraliseGuardedConnections` (that is the ASCA-82 guard). If it does not, stop and ask the Lead.

### Step 2 - Delete the host list

In `tests/CreatesApplication.php`, delete the whole method `disposableHosts()` together with its comment block (the one that starts with `Hosts that are known to be a developer's own disposable database`).

### Step 3 - Change the check and the error message

In `assertTestDatabaseConnectionsAreDisposable()`, find this:

```php
if ($this->connectionIsDisposable($driver, $database, $host)) {
    continue;
}

throw new RuntimeException(sprintf(
    'DB-SAFETY (ASCA-82): test DB connection "%s" resolved to a non-disposable '
    . 'target "%s@%s" (driver "%s") — aborting before any test can drop a real '
    . 'table. Tests must run against sqlite :memory:, a database whose name ends '
    . 'in "_test", or a disposable local host (%s). Point your test .env at the '
    . 'local test database, never at a shared host such as DEV04.',
    $connection,
    $database !== '' ? $database : '(empty)',
    $host !== '' ? $host : '(none)',
    $driver !== '' ? $driver : '(none)',
    implode(', ', $this->disposableHosts())
));
```

Replace it with:

```php
if ($this->connectionIsDisposable($driver, $database)) {
    continue;
}

throw new RuntimeException(sprintf(
    'DB-SAFETY (ASCA-82): test DB connection "%s" resolved to a non-disposable '
    . 'target "%s@%s" (driver "%s") — aborting before any test can drop a real '
    . 'table. Tests must run against sqlite :memory: or a database whose name ends '
    . 'in "_test". Point your test .env at a throwaway database, never at a real or '
    . 'shared one such as DEV04 or a local copy of bizmates_new.',
    $connection,
    $database !== '' ? $database : '(empty)',
    $host !== '' ? $host : '(none)',
    $driver !== '' ? $driver : '(none)'
));
```

### Step 4 - Replace connectionIsDisposable()

Replace the whole method, including its comment block, with:

```php
/**
 * A connection is disposable only when it is in-memory SQLite, or its database name is
 * explicitly marked as a throwaway (ends in `_test`). The host is NOT considered: a real
 * database name on a local host is still a real database.
 *
 * @param  string  $driver
 * @param  string  $database
 * @return bool
 */
private function connectionIsDisposable(string $driver, string $database): bool
{
    if ($driver === 'sqlite' && $database === ':memory:') {
        return true;
    }

    return $database !== '' && substr($database, -5) === '_test';
}
```

### Step 5 - Add a test for the rule

Create `tests/Unit/DbSafety/CreatesApplicationGuardTest.php`. It needs no database and does not start the application:

```php
<?php

namespace Tests\Unit\DbSafety;

use PHPUnit\Framework\TestCase;
use ReflectionMethod;
use Tests\CreatesApplication;

/**
 * Checks the rule the test-database guard in tests/CreatesApplication.php uses to decide
 * whether a connection is disposable. Pure logic: no database, no application boot.
 */
class CreatesApplicationGuardTest extends TestCase
{
    private function isDisposable(string $driver, string $database): bool
    {
        $subject = new class {
            use CreatesApplication;
        };

        $method = new ReflectionMethod($subject, 'connectionIsDisposable');
        $method->setAccessible(true);

        return $method->invoke($subject, $driver, $database);
    }

    public function test_in_memory_sqlite_is_disposable(): void
    {
        $this->assertTrue($this->isDisposable('sqlite', ':memory:'));
    }

    public function test_database_name_ending_in_test_is_disposable(): void
    {
        $this->assertTrue($this->isDisposable('mysql', 'bizmates_test'));
    }

    public function test_real_database_name_is_not_disposable(): void
    {
        $this->assertFalse($this->isDisposable('mysql', 'bizmates_new'));
    }

    public function test_sqlite_file_is_not_disposable(): void
    {
        $this->assertFalse($this->isDisposable('sqlite', '/tmp/app.sqlite'));
    }

    public function test_empty_database_name_is_not_disposable(): void
    {
        $this->assertFalse($this->isDisposable('mysql', ''));
    }
}
```

### Step 6 - Run the tests

```
vendor/bin/phpunit --filter CreatesApplicationGuardTest
vendor/bin/phpunit tests/Unit/RevenueAllocation
vendor/bin/phpunit tests/Feature/RevenueAllocation
```

All must pass. The ASCA-82 guard moves these tests onto in-memory SQLite, so they do not touch a real database. If any of them fails with the message `DB-SAFETY (ASCA-82)`, stop and tell the Lead what your `.env` points to.

### Step 7 - Open the PR

Open a PR to `feature/ASCA/ASCA-master` and ask for review. Mention ASCA-82 in the description.

## How to know it's done

- `grep -n "disposableHosts\|host.docker.internal" tests/CreatesApplication.php` prints nothing.
- The new test and both RevenueAllocation suites pass.
- Only `tests/CreatesApplication.php` changed, plus the one new test file.

## Do NOT

- Do not edit `phpunit.xml`. The guard already protects the run, and forcing the default connection to SQLite could break older tests that are out of scope.
- Do not change `guardedConnections()` or `neutraliseGuardedConnections()`.
- Do not edit the `setUp()` of the existing tests, and do not touch tests outside ASCA and ASCI.

## Background (read last)

This follows ASCA-82 (the interim guard, already merged). Root cause, evidence and the reasoning: `projects/asca/technical-notes/investigation/20261105-roundtrip-test-overengineering/REPORT-00-roundtrip-test-root-cause.md` in the bizmates-dev-context repo. The ls-db companion ticket is ASCA-90.
