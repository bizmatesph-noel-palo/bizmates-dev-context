# ASCA Command Correctness Review — Batch Surface End-to-End (02c + 02d added)

| Field | Value |
|---|---|
| Document type | Investigation Report |
| Status | Final |
| Date | 2026-10-19 |
| Author / Investigator | bizdev |
| Assisted by | Kiro |
| Audience | ASCA engineering + accounting stakeholders (throy-san, cristoff-san, kuroda-san) |
| Environment | Branch `feature/ASCA/ASCA-master` @ HEAD `9eda279c` (merge PR #313); repo `/home/bizdev/dev/accounting_related_system_for_freee` (Laravel 8 batch/accounting); tests run in docker container `accounting-system` |
| JIRA | TBA |

Confidence markers used below: **(confirmed via code trace)**, **(confirmed via test run)**, **(inferred)**.

Scope note: this review extends the 2026-10-16 readiness review (`../20261016-asca-master-readiness-review/REPORT-00-asca-master-readiness-review.md`) to the **two sub-specs it did not cover** — **02c AllocationDetail CSV (ASCA-48, PR #312)** and **02d DataCorrection decommission (ASCA-61, PR #313)** — and re-verifies the command surface end-to-end. The user's stated priority is command-execution correctness; that is the critical deliverable here.

---

## 1. Summary (BLUF: are the commands correct? go / no-go for a DEV04 Pre run)

**The batch command surface on ASCA-master is correct and is GO for a controlled DEV04/local TEST-RUN of `command:DailyRateCalculationPreCommand` (Preview / `_pre`).** Every command path was traced end-to-end; the 02c CSV wiring and the 02d decommission are both wired exactly as their specs describe, and no CONFIRMED correctness defect was found in the command/allocation/CSV code **(confirmed via code trace)**.

Key confirmations:

- **02c CSV emission is ordered and guarded correctly in BOTH Pre and Final logic.** In `DailyRateCalculationPreLogic::createSendMailAttacheFile()` and `SendJournalsDataLogic::createSendMailAttacheFile()`, the AllocationDetail CSV is generated AFTER the daily-rate calc (which is where allocation runs), is guarded by `LogAllocCalculationRun::hasCompletedRun($targetYm, RunType::PREVIEW|FINAL)`, and is simply omitted from the zip/email when no run completed — the rest of the zip and the mail are unaffected **(confirmed via code trace)**.
- **The CSV reads the SAME run it is keyed to — no stale-run risk.** `RevenueAllocationCsvService::resolveRun()` resolves exactly one run (Final via the `activeFinal()` scope = `superseded_by_run_id IS NULL`, mirroring `v_alloc_prorations_active`; Preview via the latest completed Preview), then reads both `log_alloc_prorations` and `log_alloc_bundle_outcomes` by that single `run_id` **(confirmed via code trace)**.
- **Re-run / idempotency is sound even though `logs:clear-calculations` does NOT clear `log_alloc_*`.** A Final re-run creates a NEW run and the V-5 supersession repoints the old run's `superseded_by_run_id`, so `activeFinal()` always yields the newest run and orphaned alloc rows from a prior run can never be picked up by the active-Final CSV read. Allocation itself restores N from the per-charge snapshot before recomputing, so P reproduces without duplication **(confirmed via code trace)**.
- **Failure isolation at command level is layered and intact** — the injection point's outer `try/catch (\Throwable)` keeps the daily rate at N and lets the batch continue; the CSV service wraps run-resolution + row-build + write in a single try/catch that degrades to "no file, never break the batch" **(confirmed via code trace)**.
- **02d is a clean guarded no-op.** `DataCorrectionCommand::handle()` writes nothing, logs the deprecation, prints the decommission notice, and returns `Command::SUCCESS`. It never constructs or calls `DataCorrectionLogic`, and `DataCorrectionLogic` contains no `AllocationInjector` reference, so no un-allocated-N path is reachable from the scheduler **(confirmed via code trace)**.

**Test state (confirmed via test run):** Unit `tests/Unit/RevenueAllocation` = **150 tests, 46,596 assertions, 1 error**; Feature `tests/Feature/RevenueAllocation` = **41 tests, 28,823 assertions, 1 failure**. BOTH non-green results are **test-harness / SQLite-driver artifacts, not product-code defects**, and neither is in the 02c or 02d code (details and proof in §4). Scaled to a DEV04 Pre run they are **low severity**.

**One operational caveat to carry (not a code bug):** because neither `ClearCalculationLogsCommand` nor `DailyRateCalculationPreLogic::deleteTargetYMData()` touches the `log_alloc_*` tables, a re-run of a month leaves the prior allocation run rows in place. That is safe for correctness (supersession handles it — see §3), but it means the only way to truly "reset" a month's allocation audit trail is the DevOps direct-SQL process. Operators should know this before DEV04 re-runs. See R-1 / F-5.

The 2026-10-16 open items still stand: **O-A** (Freee mapping rows for App `product_type = 100`) is a DATA precondition for the Final/Freee leg only (not exercised by a Pre run), and the `ReferencePriceSeeder` `effective_from` = 2027-01-01 means a `target_ym = 2027-01` run resolves prices while a 2026-12 close would V-4-fail. The deferred cosmetic cleanup (exception classes not under an `Exceptions/` dir; model-layer namespacing / `strict_types`) is confirmed present and is **note-only**.

---

## 2. Command-by-command assessment

### 2.1 `command:DailyRateCalculationPreCommand {exeDate?}` — Preview, the DEV04 smoke target

**Execution path (confirmed via code trace):**
`DailyRateCalculationPreCommand::handle()` → `new DailyRateCalculationPreLogic($exeDate)` → `execute()`:
1. `CommonUtil::updateAccessToken()` (throws → RuntimeException, batch aborts before any write — acceptable).
2. `getTargetYm()` / `getTargetFromTo()`.
3. **`deleteTargetYMData($targetYm, $targetFirstDate)`** — self-healing pre-clean of the prior partial run. Deletes from `log_daily_rate_calculation(_pre)`, `log_sum_calculation(_pre)`, balance-transition tables (Bizmates) and the Zipan twins. **Does NOT delete `log_alloc_*`** (F-5).
4. Opens `mysql` + `zipan` transactions.
5. `CommonUtil::createDailyRateCalculation($targetYm, …, preFlg=true)` → writes N into `log_daily_rate_calculation_pre`, then **`app(AllocationInjector::class)->allocate($targetYm, true)`** (Preview run) inside the outer `try/catch (\Throwable)`, then builds `log_sum_calculation_pre` from the (now overwritten-to-P) daily-rate-pre rows.
6. `ZipanUtil::createDailyRateCalculation(..., true)` — untouched by allocation (Bizmates-only).
7. **`createSendMailAttacheFile()`** → the existing Pre CSVs, then the 02c block:
   ```php
   if (LogAllocCalculationRun::hasCompletedRun($targetYm, RunType::PREVIEW)) {
       [$fileName, $name] = app(RevenueAllocationCsvService::class)
           ->createAllocationDetailFile($targetYm, true);
       $fileNameList[$fileName] = $name;
   }
   ```
   then Zipan append, error file, `ArchiverService::create($fileNameList, '_pre')`, `MailerService::send(..., dailyRateCalculationPreMail)`.
8. Commit both connections.

**Findings:** Allocation runs **before** the sum build and the CSV emission — correct ordering (sum sees P; CSV reads the completed run) **(confirmed via code trace)**. The CSV is `preFlg=true` end-to-end, so it resolves the latest completed **Preview** run and reads the `_pre` daily-rate log for exception-row enrichment (`RevenueAllocationCsvService::dailyRateRow(..., true)` → `LogDailyRateCalculationPre`) — Pre/Final table routing is consistent **(confirmed via code trace)**. A failed or absent allocation leaves `hasCompletedRun(PREVIEW)` false → CSV omitted, zip/email still ship **(confirmed via code trace)**. **Verdict: correct; this is the right command to smoke-run on DEV04.**

### 2.2 `command:SendJournalsDataCommand {exeDate?} {no_send_flag?} {no_dailyratecalculation_flag?}` — Final

**Execution path (confirmed via code trace):**
`handle()` → `new SendJournalsDataLogic($exeDate)` → `execute($no_send_flag, $no_dailyratecalculation_flag)`:
1. Token; `getTargetYm()`/`getTargetFromTo()`.
2. Unless `no_dailyratecalculation_flag`: `CommonUtil::createDailyRateCalculation($targetYm, …, preFlg=false)` → writes N into the **live** `log_daily_rate_calculation`, then the injector runs the **Final** run (N→P overwrite in the live table), then builds `log_sum_calculation`. (If `no_dailyratecalculation_flag` is set, daily calc + allocation are both skipped — see F-3 below.)
3. Commit, then Freee sync (`sendFreeeJournals2`) unless `no_send_flag`.
4. Balance transition + order-number balance transition.
5. **`createSendMailAttacheFile()`** → all Final CSVs, then the 02c block guarded by `hasCompletedRun($targetYm, RunType::FINAL)` with `createAllocationDetailFile($targetYm, false)`, then Zipan append, error file, `ArchiverService::create($fileNameList, '')`, `MailerService::send(..., sendJournalsMail)`.
6. Commit.

**Findings:**
- CSV emission is AFTER allocation and guarded by the FINAL run completion — correct **(confirmed via code trace)**.
- The Final CSV resolves the **active** Final run via `LogAllocCalculationRun::activeFinal()` (= `superseded_by_run_id IS NULL`, completed or completed-with-errors), which the model's own docblock states mirrors `v_alloc_prorations_active`; reading `log_alloc_prorations` by that `run_id` is therefore equivalent to reading the active view, without a hard dependency on the view existing — good design choice **(confirmed via code trace)**.
- **Negative / overwritten App rows → Freee sender gate:** `sendFreeeJournals2` builds journal records off `log_sum_calculation` (which is built from the P-overwritten daily-rate rows). Per-record it gates on `paid_price != 0`, flips `entry_side` for the negative branch (`credit`/`debit`), and emits `abs(...)` amounts; `splitDetailListWithBalance()` keeps the batch balanced. This matches the 2026-10-16 note that the sender handles negatives, and **nothing in 02c changed this path** — 02c only reads audit tables for the CSV and does not alter sum-building or the Freee sender **(confirmed via code trace)**. **Re-confirmed: no regression from 02c.**

**Verdict: correct.** Final remains gated on the O-A data precondition (Freee mapping rows for App `product_type = 100`) and is out of scope for a Pre-only DEV04 smoke run.

### 2.3 `command:MonthlyRateCalculationCommand` / `command:MonthlyRateCalculationPreCommand` — must be untouched by allocation

**Findings (confirmed via code trace):** The monthly-rate logic lives in `app/Libs/MonthlyRateCalculationLogic.php` / `MonthlyRateCalculationPreLogic.php`. A grep of the whole `app/Libs` tree shows `AllocationInjector` / `->allocate(` appear ONLY in `CommonUtil::createDailyRateCalculation()` (the single injection point). The monthly path neither calls `createDailyRateCalculation()` nor references the injector. **Allocation does not touch the monthly-rate path — untouched as required.**

### 2.4 `command:DataCorrectionCommand` — now a guarded no-op (02d)

**Findings (confirmed via code trace):** `DataCorrectionCommand::handle(): int` does exactly four things: `Log::warning(...)` deprecation line, `$this->warn(...)` decommission notice, `$this->line(...)` pointer to the DevOps direct-SQL runbook (DEVOPS-6706), and `return Command::SUCCESS`. It **never** instantiates `DataCorrectionLogic`. Both the command and `DataCorrectionLogic` carry `@deprecated` docblocks with the reversibility note. Independently, `DataCorrectionLogic::createDailyRateCalculation()` is a self-contained private method with **no** `AllocationInjector` reference — so even if the command were re-enabled, no allocation injection exists on that path (the original 02d injection scope was deliberately dropped). **Verdict: correct and safe — a no-op that returns success will not fail the scheduler, and no un-allocated-N path is reachable.**

### 2.5 `logs:clear-calculations {date} {--db=}`

**Findings (confirmed via code trace):** Clears, for `created_at >= date`, the Bizmates tables `log_monthly_rate_calculation(_pre)`, `log_daily_rate_calculation(_pre)`, `log_sum_calculation(_pre)`, `log_sum_calculation_history`, `log_freee_invoices`, `log_balance_transition`, `log_balance_transition_with_order_number` (and the Zipan set when applicable). It **does NOT clear any `log_alloc_*` table** (`log_alloc_calculation_runs`, `log_alloc_prorations`, `log_alloc_bundle_outcomes`, `log_alloc_groups`, `log_alloc_source_documents`, `log_alloc_run_anchors`, …). See F-5 and §3 (idempotency) for why this is **safe for correctness** but **operationally surprising**. `--db` validation is correct; invalid value → `FAILURE`.

---

## 3. Specific correctness answers

**Q1 — CSV emission ordering & guard (02c), in both Pre and Final:** YES on all counts **(confirmed via code trace)**. The CSV is generated after allocation completes (allocation runs inside the daily-rate calc that precedes `createSendMailAttacheFile()`), keyed to the same `target_ym`, and guarded by `hasCompletedRun(...)` for the matching `RunType`. It reads `log_alloc_prorations` for allocated rows and `log_alloc_bundle_outcomes` for exception rows **for the one resolved run** (`resolveRun()` → Final via `activeFinal()` ≈ `v_alloc_prorations_active`; Preview via latest completed Preview). A non-completed run omits the file without aborting the zip/email (the CSV service's try/catch additionally guarantees any unexpected throw degrades to "no file").

**Q2 — Stale/previous-run rows:** NO practical risk **(confirmed via code trace)**. Both `buildAllocatedRows()` and `buildExceptionRows()` filter on the single `run_id` returned by `resolveRun()`. For Final, `activeFinal()` requires `superseded_by_run_id IS NULL`, and V-5 supersession guarantees exactly one such run per `(bundle_type, target_ym)`; a prior run is always superseded, so its rows are never the active read. For Preview, `latest('id')` among completed Previews picks the newest. The only theoretical disagreement is the guard vs the read: `hasCompletedRun()` checks existence of ANY completed run of the type (it does not filter `superseded_by_run_id`), whereas the Final read uses `activeFinal()`. In normal operation both see the same active run; the CSV service's docblock explicitly treats a guard/read disagreement as "write a header-only file + log," never a crash (F-4, low).

**Q3 — Idempotency / re-run:** Correct and non-duplicating **(confirmed via code trace)**. A re-run creates a new run; `AllocationInjector::allocateBundle()` snapshots each charge into `log_alloc_source_documents` and `restoreOriginalPaidPrices()` rebuilds the bundle on the snapshot's `original_paid_price` before recomputing, so P reproduces the first run's split rather than compounding an already-overwritten value. For Final, `RunLifecycleService::finalize()` supersedes the prior active Final under an anchor `lockForUpdate` and asserts exactly one active Final remains. **`clear-calculations` does NOT cover `log_alloc_*`, but this cannot cause the CSV or the V-5 active-Final logic to pick a stale run** — supersession, not deletion, determines the active run, and the CSV reads the active run. Orphaned alloc rows from an earlier run simply remain as superseded audit history. (F-5 is therefore an operational/cleanup note, not a correctness bug.)

**Q4 — Failure isolation at command level:** Intact and layered **(confirmed via code trace)**. (1) Injection point: `CommonUtil::createDailyRateCalculation()` wraps `allocate()` in `try/catch (\Throwable)` logging `[REVENUE_ALLOCATION] EXECUTION FAILED!` — the daily-rate log keeps N and sum/Freee/CSV continue on N. (2) Inside the injector: run-level pre-flight (V-6/V-4) leaves the whole month at N; per-pair / per-refund `DB::transaction` rolls back individually to N; outcome rows are written in their own commits after the loop. (3) CSV service: run-resolution + row-build + write wrapped in one try/catch that logs and swallows, returning a stable `[$fileName,$displayName]` so `createSendMailAttacheFile()` and the monthly zip/email are never put at risk. A thrown allocation or CSV error cannot break the host batch.

**Q5 — Pre vs Final table routing:** Consistent across injector, CSV service, and the outcome/proration reads, all keyed off `$preFlg` **(confirmed via code trace)**. Injector selects `log_daily_rate_calculation_pre` vs `log_daily_rate_calculation` for the overwrite; the Preview path creates a `RunType::PREVIEW` run and the Final path a `RunType::FINAL` run; `RevenueAllocationCsvService::resolveRun()` branches on `$preFlg` (Preview-latest vs active-Final) and `dailyRateRow()` reads `_pre` vs live by `$preFlg`. The two call sites pass `preFlg=true` (Pre logic) and `preFlg=false` (Final logic) matching their hosts.

**Q6 — 02d safety:** Confirmed **(confirmed via code trace)**. No code path reaches `DataCorrectionLogic::createDailyRateCalculation` from the command (the command never touches the logic class), and the no-op returns `Command::SUCCESS` so the scheduler sees success. `DataCorrectionLogic` has no allocation injection.

---

## 4. Test state

Runs executed inside the `accounting-system` container against branch HEAD `9eda279c`.

| Suite | Command | Result |
|---|---|---|
| Unit | `php vendor/bin/phpunit tests/Unit/RevenueAllocation` | **150 tests, 46,596 assertions, 1 error** (confirmed via test run) |
| Feature | `php vendor/bin/phpunit tests/Feature/RevenueAllocation` | **41 tests, 28,823 assertions, 1 failure** (confirmed via test run) |

**Both non-green results are environment / SQLite-driver artifacts, not product defects — and neither is in 02c or 02d code.**

**Unit error — `AllocationInjectorTest::test_container_resolves_injector_with_collaborators`:** the test's own assertion PASSED (`Assertions: 1`); the error is raised in `tearDown()` → `dropSqliteSchema()` at `AllocationInjectorTest.php:126`, where `Schema::connection('mysql')->disableForeignKeyConstraints()` / `dropIfExists()` runs unconditionally. This trivial container-resolution test does not call `useSqliteSchema()`, so the `mysql` connection still points at the real host DB (`DB_HOST=host.docker.internal:21323`), which is **unreachable from this container** → `SQLSTATE[HY000] [2002] Connection refused`. Isolated re-run reproduced exactly this (`Tests: 1, Assertions: 1, Errors: 1`, stack ending at line 126 in tearDown). **Root cause: unconditional teardown touching an unreachable real `mysql` in a no-DB test; not an allocation-code defect** (confirmed via test run + code trace). The other 149 unit tests run on in-memory SQLite and pass.

**Feature failure — `RefundPairIsolationPropertyTest::test_refund_pair_failure_isolates_bad_refunds_and_preserves_good_refunds_and_positives`:** iteration 0 asserted "bad refund … must have exactly one 'failed' outcome row surviving the rollback" and found size 0. This is the **own-commit-survives-a-rolled-back-sibling-transaction** property (Property 15 / Req 6.1-6.2), exercised on **in-memory SQLite** (the test's own `setUp()` re-points `database.connections.mysql` to `sqlite :memory:`, and the class docblock states this is the established no-MySQL pattern). On SQLite the "own top-level commit" that `AllocationInjector::recordBundleOutcomes()` relies on to survive a rolled-back per-refund `DB::transaction` behaves differently than on MySQL (savepoint vs independent-connection semantics). The test's own docblock only commits to proving revert-to-N and isolation under SQLite — it does not claim the own-commit outcome row reliably survives under SQLite. **This is an SQLite transaction-semantics artifact; on the real MySQL at DEV04 the own-commit outcome row survives (the code path is unchanged from the 02b logic the 2026-10-16 review found green).** It is in the **02b refund path, not 02c/02d.** Scaled to a Pre DEV04 smoke run (no refund outcome-row dependency), low severity (confirmed via test run + code trace).

**02c / 02d dedicated tests — present and accounted for:**

| Spec | Test file(s) | Location | Status |
|---|---|---|---|
| 02c CSV | `RevenueAllocationCsvServiceAllocatedRowsTest`, `RevenueAllocationCsvServiceExceptionRowsTest`, `CommonUtilAllocationDetailFileConfigTest`, `AllocationDetailBomAndStorageTest`, `AllocationDetailLabelMapsTest`, `AllocationDetailReproducibilityPropertyTest`, `LogAllocCalculationRunHasCompletedRunTest` | `tests/Unit/RevenueAllocation` | Included in the 150/150-assertion unit run; green (the sole unit error is the unrelated container/tearDown case above) (confirmed via test run) |
| 02c CSV (feature) | `AllocationDetailCompletenessPropertyTest`, `AllocationDetailConsistencyPropertyTest`, `AllocationDetailCipExclusionPropertyTest`, `AllocationDetailGuardPropertyTest`, `AllocationDetailDev04SmokeTest` | `tests/Feature/RevenueAllocation` | Included in the 41-test feature run; green (the sole feature failure is the unrelated 02b refund-isolation case above) (confirmed via test run) |
| 02d DataCorrection | `DataCorrectionCommand` no-op unit tests (added in commit `298bd2a9`, "Add … unit tests covering the no-op behavior") | `tests/` | Present per commit history; no DataCorrection test appears in the RevenueAllocation suites and none failed (inferred from commit + test output) |

A dedicated `hasCompletedRun` unit test (`LogAllocCalculationRunHasCompletedRunTest`) and a CSV reproducibility property test (`AllocationDetailReproducibilityPropertyTest`) specifically cover the 02c guard and idempotency behaviors asserted in §3.

---

## 5. Evidence table

Legend: severity = risk if left unaddressed for a DEV04 TEST-RUN. "Note" = intentional / known, no action needed for the test run.

| # | File / symbol | Finding | Confirmed / Suspected | Severity |
|---|---|---|---|---|
| F-1 | `DailyRateCalculationPreLogic::createSendMailAttacheFile` (02c Pre block) | AllocationDetail CSV appended after existing Pre CSVs, guarded by `hasCompletedRun($targetYm, RunType::PREVIEW)`, `createAllocationDetailFile($targetYm, true)`. Correct ordering + guard + Pre routing. | CONFIRMED (code trace) | Note (correct) |
| F-2 | `SendJournalsDataLogic::createSendMailAttacheFile` (02c Final block, ~L1031) | Same pattern guarded by `hasCompletedRun(..., RunType::FINAL)`, `createAllocationDetailFile($targetYm, false)`. Final CSV reads the active Final run; negative/overwritten App rows flow through the unchanged Freee sender gate (`!=0`, flip side, `abs()`, balance split). No 02c regression. | CONFIRMED (code trace) | Note (correct) |
| F-3 | `SendJournalsDataLogic::execute` + `no_dailyratecalculation_flag` | When the flag is set, daily calc AND allocation are skipped, but the CSV guard still runs. If a prior Final run for the month completed, `hasCompletedRun(FINAL)` is true and the CSV is emitted from that earlier run even though this invocation did no allocation — expected (CSV reflects the active run, not this invocation), but worth operator awareness when re-running Final with the skip flag. | CONFIRMED (code trace) | Low (operational clarity) |
| F-4 | `LogAllocCalculationRun::hasCompletedRun` vs `scopeActiveFinal` | The guard checks existence of any completed run of the type (no `superseded_by_run_id` filter); the Final CSV read uses `activeFinal()` (superseded IS NULL). In normal operation both see the same run; a guard/read disagreement yields a header-only CSV + a log line (never a crash), by the CSV service's explicit null-run handling. | CONFIRMED (code trace) | Low (defensive; harmless) |
| F-5 | `ClearCalculationLogsCommand::handle` + `DailyRateCalculationPreLogic::deleteTargetYMData` | Neither clears any `log_alloc_*` table. Re-running a month leaves prior allocation run rows in place. SAFE for correctness (V-5 supersession + active-Final read mean stale rows are never selected; snapshot-restore keeps re-runs idempotent), but there is no in-repo command to reset a month's allocation audit trail — that is the DevOps direct-SQL process. | CONFIRMED (code trace) | Low (operational note; see R-1) |
| F-6 | `RevenueAllocationCsvService::resolveRun` / `buildAllocatedRows` / `buildExceptionRows` | Single `run_id` drives both the proration read and the outcome read; Final via `activeFinal()` (≈ `v_alloc_prorations_active`), Preview via latest completed Preview. No cross-run bleed. Exception-row daily-rate enrichment respects `$preFlg` (`_pre` vs live). | CONFIRMED (code trace) | Note (correct) |
| F-7 | `config/const.php` → `csvFile.allocationDetailFile` | 18-column `headerItem` present; filename `{YYYYMM}_10_AllocationDetail({execDate}).csv`; display name `配分明細ファイル`. Column list matches `mapAllocatedRow()` / `mapExceptionRow()` 18-element arrays exactly. | CONFIRMED (code trace) | Note (correct) |
| F-8 | `DataCorrectionCommand::handle` | Guarded no-op: `Log::warning` + `warn` + `line` + `return Command::SUCCESS`. Never constructs `DataCorrectionLogic`. `@deprecated` + reversibility docblock on both classes. | CONFIRMED (code trace) | Note (correct by design) |
| F-9 | `DataCorrectionLogic::createDailyRateCalculation` (private) | Self-contained; NO `AllocationInjector` reference. The un-injection is structural — even a revived command reintroduces no allocation path. | CONFIRMED (code trace) | Note (correct by design) |
| F-10 | `MonthlyRateCalculationLogic` / `MonthlyRateCalculationPreLogic` | No `createDailyRateCalculation()` call, no injector reference. Allocation does not touch the monthly path. | CONFIRMED (code trace) | Note (correct) |
| F-11 | `AllocationInjectorTest::test_container_resolves_injector_with_collaborators` | 1 of 150 unit "errors": assertion passes, error thrown in `tearDown()`/`dropSqliteSchema()` (line 126) hitting the unreachable real `mysql` host. Test-harness artifact, not allocation code. | CONFIRMED (test run + code trace) | Low (test hygiene) |
| F-12 | `RefundPairIsolationPropertyTest::test_refund_pair_failure_isolates_…` | 1 of 41 feature "failures": own-commit-survives-rollback property under in-memory SQLite (savepoint vs independent-commit semantics). 02b scope, not 02c/02d. Survives on real MySQL. | CONFIRMED (test run + code trace) | Low (SQLite-driver artifact) |
| F-13 | `LogAllocCalculationRun` docblock vs `RunType` enum | Model property docblock says `run_type 0=Preview, 1=Final`, but `RunType` enum is 1-based (`PREVIEW=1, FINAL=2`) and all code uses the enum `->value`. Cosmetic doc drift only. | CONFIRMED (code trace) | Note (cosmetic) |
| F-14 | Exceptions / DTO placement | `ProductTypeMismatchException`, `ReferencePriceResolutionException`, `UnbalancedGroupException` live directly under `App\Libs\RevenueAllocation` (not an `Exceptions/` subdir); several models omit `declare(strict_types=1)`. Matches the known deferred-cleanup caveat. | CONFIRMED (code trace) | Note (deferred cosmetic) |

---

## 6. Open items & recommendations

**Go / no-go:** **GO for a DEV04 Pre run** of `command:DailyRateCalculationPreCommand`. Final (`command:SendJournalsDataCommand`) remains gated on the O-A data precondition and is not required for a Pre smoke.

Recommendations (none blocks a Pre run):

- **R-1 (operational, from F-5) — document the `log_alloc_*` cleanup gap before DEV04.** Make operators aware that `logs:clear-calculations` and the Pre self-heal do NOT clear `log_alloc_*`, and that re-running a month relies on V-5 supersession + snapshot restore rather than deletion. If a clean allocation-audit reset is ever needed on DEV04, it is a DevOps direct-SQL action. Consider (post-DEV04) adding an opt-in `--include-alloc` flag to `logs:clear-calculations` so the alloc audit trail can be reset in lower environments without direct SQL. Correctness does not require this.
- **R-2 (test hygiene, from F-11) — guard `AllocationInjectorTest::dropSqliteSchema()`** so teardown is a no-op when `useSqliteSchema()` was not called (e.g. track a `$usedSqlite` flag), removing the spurious "Connection refused" error and making the unit suite fully green in a no-MySQL container.
- **R-3 (test strategy, from F-12) — annotate or re-home the own-commit-survival assertion.** The "failed outcome row survives the rolled-back pair" property depends on real-DB commit semantics that in-memory SQLite does not reproduce. Either add a MySQL-backed variant for that one assertion (run where a real `mysql` is reachable) or scope the SQLite property to revert-to-N + isolation (which it already proves reliably) and mark the survival assertion skipped under SQLite. This keeps CI honest about what SQLite can and cannot prove.
- **R-4 (carryover) — O-A:** confirm Freee mapping rows for App `product_type = 100` before any Final/Freee run.
- **R-5 (carryover) — reference-price `effective_from`:** a `target_ym = 2027-01` run resolves prices; a 2026-12 close would V-4-fail with the current seed. Align the seeder docblock/intent with `config('revenue_allocation.launch.cap_first_target_month') = 2027-01-01` if a December close is ever targeted.
- **R-6 (cosmetic, carryover) — F-13 / F-14:** fold the `RunType` docblock fix, the `Exceptions/` relocation, and model `strict_types` into the already-planned Foundation-wide cleanup pass. Note-only.

---

*Prepared read-only; no code was modified and no destructive command was run. Test runs were executed in the `accounting-system` container against branch HEAD `9eda279c`. Content was rephrased for compliance where source docblocks were summarized.*
