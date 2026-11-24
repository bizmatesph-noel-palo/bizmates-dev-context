# ASCA-90 — [DB Safety] Remove the migration round-trip test and its guard (ls-db)

> **Created in JIRA 2026-11-09 as [ASCA-90](https://bizmates.atlassian.net/browse/ASCA-90)** — Sub-task under ASCA-16, Priority Medium, **Unassigned**, status To Do. This file is the source of record; the JIRA ticket carries the same content. Follows ASCA-83. Companion: ASCA-91 (accounting).

**Type:** Sub-task
**Parent:** ASCA-16 ([Spec 01] — Coding (ls-db migrations))
**Priority:** Medium
**Repo:** `ls-database-migrations`, base branch `feature/ASCA/ASCA-master`
**Lead decision recorded here:** keep `NoUnguardedDdlInTestsTest`, simplified to forbid any create or drop of a table or database in a test file (cheap, reads files only, stops the pattern coming back). Delete the round-trip test, its helper trait and the README.

---

## Goal

Remove `AllocMigrationRoundTripTest` and the helper code that exists only for it, so that no ls-db test creates or drops tables or databases. Keep one small check that fails if a test like that is added again.

## Why

`AllocMigrationRoundTripTest` runs real `migrate` and `migrate:rollback` against a real MySQL database. It is the only ls-db test that does this, and it is the reason the opt-in flag `ALLOC_ROUNDTRIP_TEST` and the `_roundtrip_test` database name rule exist. Every other ls-db test only reads the schema (`hasTable`, `getColumnListing`, `getColumnType`) and needs none of that.

In production we roll forward with a new migration, so proving that a rollback is clean is not needed. The ASC tables are already covered by read-only tests: the `LogAlloc*` and `MstAlloc*` structure tests, `AllocConstraintsTest` (foreign keys) and `AllocProrationsActiveViewTest` (the view). Nothing else in the repo uses the round-trip test or its helper.

## Steps

### Step 1 - Create the branch

Create a branch from `feature/ASCA/ASCA-master`, named after this ticket key.

### Step 2 - Delete three files

```
git rm tests/Unit/Database/AllocMigrationRoundTripTest.php
git rm tests/Concerns/GuardsDisposableDatabase.php
git rm tests/README-db-safety.md
```

### Step 3 - Replace the tripwire test

Replace the whole content of `tests/Unit/DbSafety/NoUnguardedDdlInTestsTest.php` with the file below. It no longer mentions the helper you just deleted, and it now fails on any create or drop of a table or database in a test file.

```php
<?php

namespace Tests\Unit\DbSafety;

use PHPUnit\Framework\Attributes\TestDox;
use Tests\TestCase;

/**
 * DB-safety tripwire (ASCA-83, simplified).
 *
 * ls-db tests only READ the schema (hasTable, getColumnListing, getColumnType) and clean up
 * their own rows. No test may create or drop tables or databases. This test scans every PHP
 * file under tests/ for destructive DDL tokens and fails, naming the file, if it finds one.
 */
class NoUnguardedDdlInTestsTest extends TestCase
{
    /**
     * @var array<int, string>
     */
    private const DDL_PATTERNS = [
        'dropIfExists',
        'Schema::drop(',
        'DROP TABLE',
        'DROP DATABASE',
        'CREATE DATABASE',
        'TRUNCATE',
        '->truncate(',
    ];

    /**
     * Files allowed to contain the tokens (this file holds them as data).
     *
     * @var array<int, string>
     */
    private const ALLOWLISTED_BASENAMES = [
        'NoUnguardedDdlInTestsTest.php',
    ];

    #[TestDox('no tests/ file creates or drops tables or databases')]
    public function test_no_ddl_in_tests(): void
    {
        $testsDir = $this->testsDirectory();
        $violations = [];

        foreach ($this->phpFilesUnder($testsDir) as $file) {
            if (in_array(basename($file), self::ALLOWLISTED_BASENAMES, true)) {
                continue;
            }

            $contents = (string) file_get_contents($file);
            $hits = [];
            foreach (self::DDL_PATTERNS as $pattern) {
                if (str_contains($contents, $pattern)) {
                    $hits[] = $pattern;
                }
            }

            if ($hits !== []) {
                $rel = ltrim(str_replace($testsDir, '', $file), DIRECTORY_SEPARATOR);
                $violations[] = sprintf('%s  (DDL token(s): %s)', $rel, implode(', ', $hits));
            }
        }

        $this->assertSame(
            [],
            $violations,
            "ls-db tests must not create or drop tables or databases. Check the schema with "
            . "hasTable / getColumnListing / getColumnType instead.\n\n  "
            . implode("\n  ", $violations)
        );
    }

    /**
     * Absolute path to the tests/ directory (this file lives at tests/Unit/DbSafety/).
     */
    private function testsDirectory(): string
    {
        return dirname(__DIR__, 2);
    }

    /**
     * All *.php files under a directory, recursively.
     *
     * @return array<int, string>
     */
    private function phpFilesUnder(string $dir): array
    {
        $files = [];
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($dir, \FilesystemIterator::SKIP_DOTS)
        );

        /** @var \SplFileInfo $info */
        foreach ($iterator as $info) {
            if ($info->isFile() && strtolower($info->getExtension()) === 'php') {
                $files[] = $info->getPathname();
            }
        }

        sort($files);

        return $files;
    }
}
```

### Step 4 - Check nothing is left

Both commands must print nothing:

```
git grep -nE "ALLOC_ROUNDTRIP|roundtrip_test|GuardsDisposableDatabase|AllocMigrationRoundTrip|README-db-safety"
grep -rnE "dropIfExists|Schema::drop\(|DROP TABLE|DROP DATABASE|CREATE DATABASE|TRUNCATE|->truncate\(" tests --include=*.php | grep -v NoUnguardedDdlInTestsTest
```

### Step 5 - Run the tests

```
vendor/bin/phpunit --filter NoUnguardedDdlInTestsTest
vendor/bin/phpunit --filter '/LogAlloc|MstAlloc|AllocConstraints|AllocProrationsActiveView/'
```

The second command runs the ASC schema tests. They only read the schema, so they need your local database with the migrations applied, as usual. Do not run the whole test suite against a shared database: some older seeder tests delete rows. Leave those older tests alone.

### Step 6 - Open the PR

Open a PR to `feature/ASCA/ASCA-master` and ask for review. Mention ASCA-83 in the description.

## How to know it's done

- The three files are gone and both Step 4 commands print nothing.
- The tripwire test passes, and the ASC schema tests still pass.
- Optional proof that the tripwire works: add a line containing `dropIfExists` to any test file, run the tripwire (it must fail and name the file), then remove the line.

## Do NOT

- Do not change any migration.
- Do not change non-ASC tests. The older seeder tests that delete rows are known and out of scope.
- Do not delete `NoUnguardedDdlInTestsTest.php`. We keep it as the check that DDL does not come back.

## Background (read last)

This follows ASCA-83 (the interim guard, already merged). Root cause, evidence and the reasoning for removing the round-trip test: `projects/asca/technical-notes/investigation/20261105-roundtrip-test-overengineering/REPORT-00-roundtrip-test-root-cause.md` in the bizmates-dev-context repo.
