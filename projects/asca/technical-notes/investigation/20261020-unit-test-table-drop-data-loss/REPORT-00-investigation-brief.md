# Unit Test + Seeder DB-Safety Investigation — Brief (20261020)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report (brief / plan) |
| **Status** | Active — not started |
| **Date** | 2026-10-20 (Created) |
| **Author** | Noel Palo, Lead |
| **Assisted by** | Kiro |
| **Audience** | Cristoff (investigator, junior dev) · Lead |
| **Repos** | `accounting_related_system_for_freee` + `ls-database-migrations`, branch `feature/ASCA/ASCA-master` |
| **JIRA** | Investigation task under ASCA-9 (TBA key) |

> **Two readers:**
> 1. **Cristoff** — follow this top-to-bottom in your Kiro. It tells you exactly what to run and what to write down. **You will not change any code — only look and report.**
> 2. **A future Lead Kiro session** — §7 explains what to do when the findings come back.

---

## 1. In one paragraph: what's wrong and why we care

When you run the ASCA unit tests, some of them **delete a database table and rebuild it empty** before the test runs. That is fine on a throwaway test database. But on **DEV04 (a shared server with real data)**, if a test points at the real database by mistake, it will **wipe a real table** — for example `trn_charge`, which holds historical charge data we cannot get back. That already happened on DEV04. **Your job: find which ASCA/ASCI tests and seeders can do this, and say why. Do not "fix" anything and do not decide it's a non-issue — it is a real issue; we are mapping how big it is.**

## 2. Plain-language background (so the rest makes sense)

- A **unit test** sometimes needs database tables to exist. Instead of using the real database, the ASCA tests **switch the database to a fake, in-memory one (SQLite)** at the start of the test, then create empty tables there. SQLite lives only in memory and vanishes after the test — safe.
- The danger: that "switch to SQLite" step must happen **before** the test deletes/creates any table. If the switch is missing, happens too late, or doesn't work on DEV04 (because DEV04's database settings differ from local Docker), the delete/create hits the **real** database instead of the fake one.
- The exact dangerous code looks like: `Schema::dropIfExists('trn_charge')` followed by `Schema::create('trn_charge', ...)`. On the real DB that = "delete the real table, make a new empty one."
- A **seeder** is different from a test. Seeders are *supposed* to change data (add plans, prices, etc.). So a seeder deleting/altering data is often fine. We only worry about a seeder destroying data it was **not** meant to.

## 3. What counts as a problem (your decision rule)

Judge **tests** and **seeders** differently.

### Unit tests — strict
- OK: a test adds a few rows for itself and deletes those same rows afterward.
- PROBLEM (flag it): a test calls `dropIfExists` / `Schema::drop` / `Schema::create` on a table, OR deletes/changes rows it did not create itself, OR wipes data in setUp/tearDown.

### Seeders — depends on intent
- OK: a seeder adds master data (plans/products/prices/banners), updates existing rows on purpose, or even deletes/drops something **because the project asked for it**.
- PROBLEM (flag it): a seeder deletes historical data or drops a table as a **side effect** that the project did NOT ask for.
- Rule of thumb: *was this deletion the point of the seeder, or an accident?* On purpose = OK. Accident / collateral = flag.

**If you are not sure whether something is a problem, FLAG it and write "unsure — needs Lead review." Do not guess it's fine.**

## 4. Which files to look at (and which to ignore)

**ONLY look at files made by the ASCA or ASCI projects.** Ignore everything else — do not even open other projects' files.

How to tell an ASCA/ASCI test: it has a line like `Feature: asca-spec-...` in the comment block at the top, OR it lives in a `RevenueAllocation` folder.

**Ignore (do NOT look at, do NOT report) — examples of other projects:** `TrnOtherSalesChargeTest` (project BARS-8), `MstCurrencySeeder`, `AddTaiwanPricesSeeder`, `MstTrainerKpiVideoRebookabilitySeeder`, `MstVideoLessonHtmlLevel0Seeder`, and anything without the `asca-spec` tag that isn't in the seeder list below.

**ASCA/ASCI seeders to check (only these):**
- accounting repo: `ReferencePriceSeeder`, `Dev04CapTestDataSeeder`
- ls-db repo: `CapCoachingAppPlansSeeder`, `MstCapCoachingAppB2b2cPlansSeeder`, `CoachingIntensivePlanSeeder`, `InsertCoachingIntensiveSoloPlanBannerSeeder` (+ its honki variant)

## 5. Exactly what to do — step by step

Do this in BOTH repos. Copy-paste the commands. (If git opens a pager, press `q`, or prefix with `GIT_PAGER=cat`.)

**Step A — list the ASCA tests (accounting repo):**
```
grep -rln "Feature: asca-spec" tests/
```
Also include these two by name: `tests/Unit/CommonUtilCreateDailyRateCalculationInjectionTest.php` and `tests/Unit/Libs/AllocationDetailGuardedInjectionCrossCuttingTest.php`.
For ls-db, look at the allocation structure tests: `grep -rln "LogAlloc" tests/`.

**Step B — in that list, find the dangerous calls:**
```
grep -rlnE "dropIfExists|Schema::drop|DROP TABLE|TRUNCATE" <the files from Step A>
```

**Step C — open each file that showed up, and answer these for the table being dropped/created:**
1. What table? Is it a **real/shared** table (`trn_charge`, `trn_charge_forex`, `mst_product`, `log_daily_rate_calculation`, `log_daily_rate_calculation_pre`, `log_monthly_rate_calculation`, any `log_sum_*`, a `v_...` view) — OR a **new allocation table** (`log_alloc_...` / `mst_alloc_...`)? Real/shared = higher risk.
2. Does the code switch to SQLite (look for `Config::set('database.connections.mysql'` with `'sqlite'` and `':memory:'`, plus `->purge('mysql')`) **before** the drop/create? Answer yes or no.
3. Does `setUp()` or `tearDown()` delete anything that isn't the test's own data?
→ Verdict: **SAFE** (switches to SQLite before any drop) or **RISK** (could hit a real DB).

**Step D — why did DEV04 break?** Open `.env.testing` and `config/database.php` in each repo. Compare how the `mysql` connection is set on DEV04 vs local Docker (different DB name/host?). Write down why the SQLite switch didn't protect the real DB on DEV04.

**Step E — seeders (only the ones listed in §4):**
```
grep -nE "dropIfExists|Schema::drop|DROP TABLE|TRUNCATE|->delete\(" <seeder file>
```
For each hit, decide using §3: was the delete **on purpose (OK)** or an **accident (FLAG)**?

## 6. What to write — POST THIS AS A COMMENT ON THE JIRA TICKET

You can read the dev-context repo but cannot push to it, so **put your results in a comment on the investigation ticket**, using these tables. Fill a row per file. If a section has nothing, write "none found."

```
## Findings — unit-test / seeder DB-safety investigation

### Tests — accounting repo
| File | Dangerous call | Table(s) | Real/shared or log_alloc_* | Switches to SQLite before drop? | Verdict (SAFE/RISK) | Note |
|---|---|---|---|---|---|---|

### Tests — ls-db repo
| File | Dangerous call | Table(s) | Real/shared or log_alloc_* | Switches to SQLite before drop? | Verdict (SAFE/RISK) | Note |
|---|---|---|---|---|---|---|

### Seeders (ASCA/ASCI only)
| File | Repo | Delete/drop call | On purpose (per requirement)? | Verdict (OK/FLAG) | Note |
|---|---|---|---|---|---|

### Why DEV04 broke (connection mismatch)
(what differs in .env.testing / config/database.php between DEV04 and local; why the SQLite switch didn't protect the real DB)

### My recommended fix idea (per repo)
- Accounting: ...
- ls-db: ...
```

### A worked example so you know what a row looks like
If you open a test and see: it calls `Config::set(... 'sqlite' ... ':memory:')` and `->purge('mysql')` in `setUp()` FIRST, and only AFTER that does `dropIfExists('trn_charge')` + `Schema::create('trn_charge', ...)` → that row is:
`| AllocationInjectorTest.php | dropIfExists + create | trn_charge, log_alloc_* | real + log_alloc | YES | SAFE | switches to SQLite first |`

If a test does `dropIfExists('trn_charge')` with **no** SQLite switch before it → that row is **RISK**.

### Hard rules for you
- **Do NOT change any code, test, seeder, config, or phpunit.xml.** Look and report only.
- **Do NOT look at or report non-ASCA/ASCI files.**
- **If unsure, write "unsure — needs Lead review." Never guess "it's fine."**

## 7. For the Lead's future Kiro session — when findings are pasted back

The two fix tickets are intentionally NOT created yet. When the Lead pastes Cristoff's findings:

1. Create **two fix tickets** from the flagged items:
   - **Accounting fix** → sub-task under **ASCA-17**. Scope: the flagged accounting tests/seeders + enforce test-DB isolation (e.g. activate the commented-out SQLite lines in `phpunit.xml`, and/or a base `TestCase` guard that refuses to run against a non-test DB) so a test can never drop/recreate a real table or wipe persistent data.
   - **ls-db fix** → sub-task under **ASCA-16**. Likely light (ls-db structure tests are read-only); include only what the findings flag.
2. Draft the ticket files under `projects/asca/technical-notes/jira/tickets/` first, create in JIRA on the Lead's go.
3. Carry the §3 rules into the fix acceptance criteria.
4. Stay ASCA/ASCI-only.

## 8. Confirmed starting facts (for the Lead / to sanity-check the findings — Cristoff can skip)

- `phpunit.xml` in BOTH repos has the forced-SQLite lines commented out → no structural isolation guard.
- Accounting: ~56 ASCA tests use the "switch to SQLite then drop/create" pattern over real-named tables. Safe only if the switch reliably precedes every drop and actually takes on DEV04.
- `CommonUtilCreateDailyRateCalculationInjectionTest.php` drops `trn_charge` — scrutinize most.
- ls-db ASCA tests (`*TableStructureTest`) are read-only (`hasTable`/`getColumnListing`/`getColumnType`) — expected SAFE.
- Accounting ASCA seeders (`ReferencePriceSeeder`, `Dev04CapTestDataSeeder`) use scoped `->delete()` (own rows / rollback) — expected OK, confirm no blanket truncate/drop.
- Expected overall: accounting tests = the real risk; ls-db = read-only/safe; seeders = scoped/intended.

## 9. Cross-reference

- Related reviews: `projects/asca/technical-notes/investigation/20261016-asca-master-readiness-review/`, `.../20261019-asca-command-correctness-review/` (both noted test teardown hitting a real MySQL on DEV04).
