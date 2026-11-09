# ASCA-XXX — [Fix][TBA] Accounting: unit-test/seeder DB-safety (no table drops / historic-data loss)

**Type:** Sub-task
**Parent:** ASCA-17 ([Spec 01] — Coding, accounting)
**Priority:** High
**Status:** DRAFT / TBA — do NOT create in JIRA until the investigation findings are in.
**Depends on:** Investigation task under ASCA-9 (`...20261020-unit-test-table-drop-data-loss/REPORT-00-investigation-brief.md`)

---

## Summary (to be finalized from findings)

Fix the accounting-repo ASCA/ASCI unit tests + seeders flagged by the investigation so that running tests can NEVER drop/recreate a real table or wipe persistent/historic data, and seeders only perform intended requirement-driven changes.

## Scope (fill from findings)

- [ ] (per-file list of flagged accounting tests — TBA)
- [ ] (per-file list of flagged accounting seeders — TBA)
- [ ] Enforce test-DB isolation so a test cannot hit a real DB — e.g. force SQLite in `phpunit.xml` (uncomment/activate) and/or a base `TestCase` guard that refuses to run when the connection points at a non-test DB.

## Acceptance Criteria (baseline; extend from findings)

- [ ] Unit tests only create/delete their OWN test data; no drop/recreate of real tables; no persistent-data wipe in setUp/tearDown.
- [ ] Seeders perform only intended requirement-driven changes; no unintended historic-data loss.
- [ ] ASCA/ASCI scope only — other projects' tests/seeders untouched.
- [ ] Allocation suites still green after the change.

## Notes
- Created from the investigation findings (JIRA comment on the ASCA-9 task). Fill scope + ACs before creating in JIRA.
