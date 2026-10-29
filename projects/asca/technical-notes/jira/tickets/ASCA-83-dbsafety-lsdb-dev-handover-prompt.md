# Dev Handover Prompt — DB-safety guard (ls-db, sub-task under ASCA-16)

> Paste-ready context + instructions for the assigned dev's Kiro. Grounded on ls-db `feature/ASCA/ASCA-master` HEAD `94ec95d`.
>
> **Working agreement (important):** ls-db is ALREADY safe — this is preventive. Verify against live code. **If anything is unclear or the CI-check approach is harder than expected, STOP and ask the Lead (Noel) immediately — do not guess or over-build.**

---

## Branch

```
git checkout feature/ASCA/ASCA-master
git pull
git checkout -b feature/ASCA/ASCA-83-dbsafety-guard-lsdb
```

## Paste this into the dev's Kiro (one message)

```
Context load (ASCA):
Learn the agentic-toolkit and bizmates-dev-context, then read projects/asca/project-context.md, then learn the related repos: accounting_related_system_for_freee, ls-database-migrations, bizmates.jp, MBTI_backend

Task: Codify the DB-safety guard in ls-database-migrations so a FUTURE test cannot issue CREATE/DROP TABLE/DROP DATABASE/TRUNCATE against a real DB without the same guards the one existing DDL test already uses. ls-db is ALREADY safe today — this is preventive hardening, NOT a fix.

Read first (ground truth):
- The CR ticket: projects/asca/technical-notes/jira/tickets/ASCA-83-dbsafety-guard-lsdb.md
- The re-grounding report §E (exact guard method names): projects/asca/technical-notes/investigation/20261023-dbsafety-reground-post-asca78/REPORT-00-dbsafety-reground.md
- The ONLY DDL-issuing test (the pattern to extract): ls-database-migrations/tests/Unit/Database/AllocMigrationRoundTripTest.php

Grounding (verify on live code): in ls-database-migrations/tests, AllocMigrationRoundTripTest is the ONLY file issuing DDL. Confirm with:
grep -rn "dropIfExists\|Schema::drop\|->drop(\|DROP TABLE\|DROP DATABASE\|TRUNCATE\|CREATE DATABASE" tests/
Its guards to reuse: hasOptedIn() (ALLOC_ROUNDTRIP_TEST opt-in), REQUIRED_NAME_SUFFIX='_roundtrip_test' + assertScratchDatabaseNameIsDisposable() (fail-loud), resolveProtectedDatabases()/configuredDatabase() (collision refusal + owns-what-it-drops), redirectAllocConnectionToScratchDatabase() + assertAllocConnectionPointsAtScratchDatabase() (assert-before-DDL), restoreAllocConnectionConfig() (guaranteed restore).

Implement:
1. Extract that guard logic into a reusable trait or base class; have AllocMigrationRoundTripTest use it with NO behavior change.
2. Add a guardrail against future unguarded DDL — either a lightweight CI/grep check that flags any new tests/ file with CREATE/DROP TABLE/DROP DATABASE/TRUNCATE not using the shared guard, OR a base-TestCase assertion mirroring the accounting fail-closed guard.
3. Document (repo steering or a test README) that DDL in ls-db tests MUST go through the guard pattern.

Do NOT:
- Change AllocMigrationRoundTripTest behavior (only extract/reuse its guards).
- Touch structure tests, migrations, seeders (all verified safe), or the accounting repo (separate ticket).

Verify:
- vendor/bin/phpunit green; AllocMigrationRoundTripTest still SKIPS without ALLOC_ROUNDTRIP_TEST and still runs (guarded) with it + a _roundtrip_test scratch DB.
- Negative check: a scratch test file with unguarded DROP TABLE is caught by the CI check / aborted by the assertion. Remove the scratch file after.

If you're unsure whether to go the CI-check route or the base-class-assertion route, STOP and ask the Lead — don't build both or guess.

Then open a PR referencing this sub-ticket. Do NOT merge without Lead (Noel) review. Log JIRA time against the sub-ticket.
```

---

## Notes for the Lead (not the dev prompt)

- This ticket is genuinely preventive (ls-db has no present defect). If you'd rather not spend dev time on hardening now, it's the one of the two that could be deferred — but it's cheap and prevents regression. Your call at assignment.
- Decide which guardrail you prefer (CI grep check vs base-class assertion) so Cristoff doesn't deliberate — the prompt tells him to ask, but a one-line steer from you removes the question entirely.
