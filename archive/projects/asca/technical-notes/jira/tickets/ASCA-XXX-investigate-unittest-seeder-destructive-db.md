# ASCA-XXX — [Investigation] ASCA/ASCI unit tests + seeders: table-drop / historic-data-loss risk

**Type:** Task
**Epic:** ASCA-9 — ASCA Project Scaffolding
**Priority:** High
**Assignee:** Cristoff T. Danganan
**Repos:** accounting_related_system_for_freee + ls-database-migrations
**Brief (read first, pull-only in dev-context):** `projects/asca/technical-notes/investigation/20261020-unit-test-table-drop-data-loss/REPORT-00-investigation-brief.md`

---

## Summary

Investigation only — READ AND REPORT, do NOT change any code, test, seeder, config, or phpunit.xml.

Running the ASCA unit tests on DEV04 (after the 2026-10-19 deploy) surfaced a DB error from the test DB connection. The ASCA tests re-point `mysql` to in-memory SQLite, but on DEV04 a real MySQL exists and the connection differs from local; if the re-point does not take, a test's `dropIfExists` + `Schema::create` can hit the real DB and recreate a table EMPTY, destroying historic data (e.g. `trn_charge`). This already happened — do NOT conclude "no issue." Identify which ASCA/ASCI tests and seeders can do this, and why the SQLite guard did not protect the real DB.

Full brief + scope + steps + required output format: see the brief file above. Follow it exactly.

## Scope (STRICT — ASCA/ASCI only)

- IN: tests tagged `Feature: asca-spec`, the `tests/{Unit,Feature}/RevenueAllocation/` folders, the 2 named injection tests; ASCA/ASCI seeders only (ReferencePriceSeeder, Dev04CapTestDataSeeder; CapCoachingAppPlansSeeder, MstCapCoachingAppB2b2cPlansSeeder, CoachingIntensivePlanSeeder, CIP banner seeders).
- OUT: anything not ASCA/ASCI (e.g. TrnOtherSalesChargeTest/BARS-8, MstCurrencySeeder, AddTaiwanPricesSeeder). Do not touch or flag.

## Two bars (classification rule)

- Unit tests (STRICT): may create/delete ONLY their own test data; must NOT drop/recreate tables, alter/delete data they didn't create, or wipe persistent data in setUp/tearDown.
- Seeders (INTENT-BASED): may populate/alter/even delete data/columns/tables WHEN it is an intended, requirement-driven change; must NOT drop tables or delete historic data as an unintended side-effect.

## What to deliver

Post findings AS A COMMENT on this ticket, in the exact table format in §6 of the brief:
1. Per in-scope test: destructive call, tables touched, real/shared vs log_alloc_*, re-point-before-drop (yes/no), verdict SAFE/RISK.
2. Per in-scope seeder: destructive call, intended-per-requirement (yes/no), verdict OK/FLAG.
3. Root cause of the DEV04 connection mismatch (why SQLite re-point didn't protect the real DB).
4. Recommended fix direction per repo.

## Acceptance Criteria

- [ ] All in-scope ASCA/ASCI tests + seeders in BOTH repos reviewed; out-of-scope items untouched.
- [ ] Findings posted as a comment in the required format.
- [ ] DEV04 connection-mismatch root cause stated.
- [ ] No code/test/seeder/config changes made (investigation only).

## Notes

- Fix is a SEPARATE effort: two sub-tickets (accounting under ASCA-17, ls-db under ASCA-16) will be created from these findings. Not part of this task.
- Expected (confirm, don't assume): accounting tests = drop/recreate risk; ls-db structure tests = read-only/safe; seeders = scoped/intended.
