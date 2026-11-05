# ASCA-XXX — [DB Safety] Confirm no accounting test runs real migrations / drops real tables

> **DRAFT — NOT yet created in JIRA.** Local source of record. Key `ASCA-XXX` is a placeholder; update once created. Follow-on from ASCA-82 (the interim guard). Root-cause report: `../../investigation/20261105-roundtrip-test-overengineering/REPORT-00-roundtrip-test-root-cause.md`.

**Type:** Task
**Parent/Epic:** ASCA-9 (Ops) or under the DB-safety thread — Lead to place
**Priority:** Medium
**Assignee:** Unassigned (do not pre-assign)
**Repo:** `accounting_related_system_for_freee`
**Depends on:** ASCA-82 merged first

---

## Goal (one line)
Make sure no accounting test runs real migrations or drops/recreates a real table just to exercise a feature — tests should check an already-built schema + light seeded data only.

## Why
The accounting repo has no migrate/rollback round-trip test, but it has ~45 tests that re-point `mysql` to SQLite in `setUp()` and then issue `dropIfExists`/`create` on real-named tables. ASCA-82 adds a bootstrap-level structural guard so a missed switch can't hit a real DB. This ticket is the cleanup pass: confirm the guard covers everything and that no test's safety still depends on its own inline switch where a read-only check would do.

## Steps
1. With ASCA-82 merged, confirm the bootstrap guard (force mysql/zipan → sqlite `:memory:` + fail-closed assertion) is the single structural backstop; no test should rely solely on its own inline switch.
2. `grep` for any remaining hard `->drop(` (non-`dropIfExists`) — should be zero (the one at `Dev04CapTestDataSeederTest` was already converted).
3. Confirm the two hardening items from the ASCA-82 review are applied: disposable-host rule tightened to `:memory:` / `_test` only; `phpunit.xml` SQLite lines uncommented.
4. For any test that creates/drops a real-named table purely to assert the schema (not to exercise behavior), note whether a read-only structure check would be sufficient — list candidates for a later simplification (do not mass-rewrite in this ticket unless trivial).

## How to know it's done
- No hard `->drop(` on real tables in `tests/`.
- The bootstrap guard aborts loudly if any connection resolves to a non-disposable target (verified by a deliberate misconfig in a scratch run, then reverted).
- `phpunit.xml` forces SQLite; disposable-host allowlist no longer accepts a real DB name on a local host.
- Unit + feature suites pass against SQLite.

## Out of scope / do NOT touch
- Business-logic behavior of the refund/injection tests (only their DB-safety setup).
- Non-ASCA/ASCI tests.

## Background (read last)
Root cause + evidence in the investigation report linked above. This is the accounting companion to the ls-db round-trip-test removal.
