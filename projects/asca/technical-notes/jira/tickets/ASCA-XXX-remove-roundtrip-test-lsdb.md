# ASCA-XXX — [DB Safety] Remove the over-engineered migration round-trip test (ls-db)

> **DRAFT — NOT yet created in JIRA.** Local source of record. Key `ASCA-XXX` is a placeholder; update once created. Follow-on from ASCA-83 (the interim guard). Root-cause report: `../../investigation/20261105-roundtrip-test-overengineering/REPORT-00-roundtrip-test-root-cause.md`.

**Type:** Task
**Parent/Epic:** ASCA-9 (Ops) or under the DB-safety thread — Lead to place
**Priority:** Medium
**Assignee:** Unassigned (do not pre-assign)
**Repo:** `ls-database-migrations`
**Depends on:** ASCA-83 merged first (this removes what ASCA-83 guards)

---

## Goal (one line)
Remove `AllocMigrationRoundTripTest` and its DB-safety machinery, relying on the existing read-only structure/constraint tests that already verify the ASC schema.

## Why
`AllocMigrationRoundTripTest` runs real `migrate` + `migrate:rollback` against a real MySQL — integration behavior in the unit folder. It is the sole reason ls-db tests need the opt-in flag (`ALLOC_ROUNDTRIP_TEST=1`) and the `_roundtrip_test` scratch-DB machinery, and it is what created the DB-wipe risk ASCA-83 had to guard. The only thing it proves — that a migration rolls back cleanly — is not something the project uses (production rolls forward; a change ships as a *new* migration, never a routine rollback). The schema is already fully covered read-only.

## What already covers the schema (so nothing is lost)
- `LogAlloc*TableStructureTest` + `MstAllocReferencePricesTableStructureTest` — table existence, columns, types (read-only).
- `AllocConstraintsTest` — foreign keys.
- `AllocProrationsActiveViewTest` — the `v_alloc_prorations_active` view.
- These match the repo-wide pattern: 439 structure tests, all read-only, zero DDL.

## Steps
1. Delete `tests/Unit/Database/AllocMigrationRoundTripTest.php`.
2. If now unused, delete `tests/Concerns/GuardsDisposableDatabase.php` and `tests/Unit/DbSafety/NoUnguardedDdlInTestsTest.php` (confirm no other test references them — currently only these three files reference each other).
3. Confirm the ASC schema is still covered by the read-only structure/constraint/view tests above; if any gap, add a read-only check (no DDL).
4. Optionally add a light read-only check that each ASC table's key columns exist, matching the existing `*TableStructureTest` style — only if a gap is found.

## How to know it's done
- `grep -rnE "dropIfExists|Schema::drop|CREATE DATABASE|Artisan::call\('migrate" tests/` returns nothing (no DDL-issuing test remains).
- `ALLOC_ROUNDTRIP_TEST` and `_roundtrip_test` no longer appear anywhere in the repo.
- `vendor/bin/phpunit --testsuite Unit` passes with the ASC structure/constraint/view tests green.

## Out of scope / do NOT touch
- The migrations themselves (unchanged).
- Non-ASC tests.
- Spec-01-database-migration's design "Property 1" is noted; if the removal contradicts a written correctness property, flag to Lead rather than silently diverging (Lead will reconcile the spec wording separately).

## Background (read last)
Full root cause + evidence (439 read-only tests, nothing depends on the round-trip test, production-practice rationale) in the investigation report linked above. Prior DB-safety reports (20261020, 20261023 x2) remain valid records; this ticket is the agreed follow-on simplification.
