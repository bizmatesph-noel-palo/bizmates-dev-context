# ASCA-XXX — [Fix][TBA] ls-db: unit-test/seeder DB-safety (no table drops / historic-data loss)

**Type:** Sub-task
**Parent:** ASCA-16 ([Spec 01] — Coding, ls-db)
**Priority:** Medium
**Status:** DRAFT / TBA — do NOT create in JIRA until the investigation findings are in.
**Depends on:** Investigation task under ASCA-9 (`...20261020-unit-test-table-drop-data-loss/REPORT-00-investigation-brief.md`)

---

## Summary (to be finalized from findings)

Address any ls-db-repo ASCA/ASCI test/seeder DB-safety items the investigation flags. Expected to be light: the ls-db ASCA structure tests are read-only (`hasTable`/`getColumnListing`/`getColumnType`), so this may be a guard-only / confirm-safe change. Include ONLY what the findings actually flag.

## Scope (fill from findings)

- [ ] (any flagged ls-db tests — TBA; expected none/minimal)
- [ ] (any flagged ls-db ASCA/ASCI seeders — TBA)
- [ ] Optional: enforce test-DB isolation in ls-db `phpunit.xml` (forced-SQLite lines currently commented out) for parity.

## Acceptance Criteria (baseline; extend from findings)

- [ ] ls-db ASCA/ASCI tests do not drop/recreate real tables or wipe persistent data.
- [ ] Seeders perform only intended requirement-driven changes; no unintended historic-data loss.
- [ ] ASCA/ASCI scope only — other projects' tests/seeders untouched.

## Notes
- Created from the investigation findings. If the findings confirm the structure tests are read-only and the seeders are scoped/intended, this may reduce to "no code change needed + add isolation guard."
