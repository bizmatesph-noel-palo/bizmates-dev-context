# ASCA-83 — [Spec 01][DB Safety] Codify the test-DDL guard so a future ls-db test can't wipe a real DB

> **Created in JIRA 2026-10-27 as [ASCA-83](https://bizmates.atlassian.net/browse/ASCA-83)** — Sub-task under ASCA-16, Priority Medium, Unassigned, status To Do. Linked "relates to" ASCA-70. This file is the source of record; the JIRA ticket carries the same content (renders Markdown). Dev handover prompt: `ASCA-83-dbsafety-lsdb-dev-handover-prompt.md`.

**Type:** Subtask
**Parent:** ASCA-16 ([Spec 01] — Coding (ls-db migrations))
**Priority:** Medium
**Assignee:** Dev
**Grounded on:** ls-db repo `feature/ASCA/ASCA-master` HEAD `94ec95d`
**Source (investigations):** ASCA-70 (Cristoff's findings, Done) · verification + re-grounding reports (see accounting ticket)

---

## The key point — this is PREVENTIVE, not a bug fix

ls-db is **already safe**: the only DDL-issuing test (`AllocMigrationRoundTripTest`) is fully guarded. The job is to **extract that test's existing guards into something reusable** and add a tripwire so a FUTURE test can't add unguarded DDL. **Do NOT change `AllocMigrationRoundTripTest`'s behavior** — only lift its guard methods into a shared trait/base and have it use them (no behavior change). There is no present defect to fix. Companion to the accounting guard (ASCA-82).

## Summary

ls-db is **already safe** — the one DDL-issuing test (`AllocMigrationRoundTripTest`) is fully guarded. Make that safety **structural/reusable** so a FUTURE ls-db test cannot issue `CREATE`/`DROP TABLE`/`DROP DATABASE` against a real database without the same guards. No present defect; this is preventive ("codify the guarantee").

## Context (grounded on current HEAD `94ec95d`)

- `grep` across `ls-database-migrations/tests/` for DDL → **one file only:** `tests/Unit/Database/AllocMigrationRoundTripTest.php`. All table-structure tests are read-only; no ASCI/alloc seeders on this branch.
- That test's guards (the gold-standard pattern to reuse — exact names from the re-grounding report §E):
  - **Opt-in:** `hasOptedIn()` (line 312) reads `ALLOC_ROUNDTRIP_TEST`; `markTestSkipped()` otherwise — a plain `vendor/bin/phpunit` never runs it.
  - **Name allowlist + fail-loud:** `REQUIRED_NAME_SUFFIX = '_roundtrip_test'`; `assertScratchDatabaseNameIsDisposable()` (line 334) — fails (not skips) on a bad name.
  - **Collision refusal / owns-what-it-drops:** `resolveProtectedDatabases()` (371), `configuredDatabase()` (390); refuses to adopt a pre-existing scratch DB; drops only a DB this run created.
  - **Assert-before-DDL:** `redirectAllocConnectionToScratchDatabase()` (403) + `assertAllocConnectionPointsAtScratchDatabase()` (417).
  - **Guaranteed restore:** `restoreAllocConnectionConfig()` (441) in tearDown.
- Risk here is **future regression** — nothing stops a new ls-db test from adding unguarded DDL.

## Scope (ls-db repo `ls-database-migrations`)

- [ ] **Extract the guard pattern** from `AllocMigrationRoundTripTest` into a reusable trait or base class (the opt-in / name-allowlist / collision-refusal / assert-before-DDL / fail-loud methods), and have `AllocMigrationRoundTripTest` use it (no behavior change).
- [ ] **Add a guardrail against unguarded DDL** — **DECIDED (Lead, 2026-10-28): use (a) the CI/grep check** that flags any new `tests/` file containing `dropIfExists` / `Schema::drop` / `DROP TABLE` / `DROP DATABASE` / `TRUNCATE` / `CREATE DATABASE` not using the shared guard. NOT the base-`TestCase` assertion (b): `AllocMigrationRoundTripTest` legitimately uses a **real `bizmates_mysql` scratch DB** (it can't be sqlite — the alloc migrations hard-code `Schema::connection('bizmates_mysql')`), so a "must be disposable/sqlite" assertion would fail that guarded test. Wire (a) into the PR pipeline; if ls-db has no CI gate, it degrades to a convention/pre-commit check (flag to Lead). Do not build both.
- [ ] **Document** (repo steering or a test README) that any DDL in ls-db tests MUST go through the guard pattern.

## Out of scope / do NOT touch

- `AllocMigrationRoundTripTest` behavior (correct as-is; only extract/reuse its guards).
- Structure tests, migrations, seeders (all verified safe).
- The accounting-repo guard (separate sub-ticket under ASCA-17).

## Acceptance Criteria (Definition of Done)

- [ ] The round-trip test's guard logic is a reusable trait/base class, and `AllocMigrationRoundTripTest` uses it (no behavior change).
- [ ] A guardrail prevents a new ls-db test from issuing DDL on a non-test connection without the guards (CI check or base-class assertion).
- [ ] Documented for future contributors.
- [ ] `vendor/bin/phpunit` still green; round-trip test still SKIPS without `ALLOC_ROUNDTRIP_TEST` and still runs (guarded) with it + a `_roundtrip_test` scratch DB.

## Verification

- `vendor/bin/phpunit` green; round-trip test skips by default.
- Negative check: a scratch test file with unguarded `DROP TABLE` is caught by the CI check / aborted by the assertion.

## Handover — resources the dev needs

1. **Paste-ready dev-Kiro prompt (START HERE):** `projects/asca/technical-notes/jira/tickets/ASCA-83-dbsafety-lsdb-dev-handover-prompt.md`.
2. **Read-only grounding (§E = the guard method names/lines to extract):** `projects/asca/technical-notes/investigation/20261023-dbsafety-reground-post-asca78/REPORT-00-dbsafety-reground.md`.
3. **Branch:** `git checkout feature/ASCA/ASCA-master && git pull && git checkout -b feature/ASCA/ASCA-83-dbsafety-guard-lsdb`.

Verify against live code first; only ask the Lead (Noel) if the live code differs. PR referencing ASCA-83; do not merge without Lead review.

## Tracking

- Follow-on from the ASCA-70 investigation (Done). No present defect — preventive. Log time here.
