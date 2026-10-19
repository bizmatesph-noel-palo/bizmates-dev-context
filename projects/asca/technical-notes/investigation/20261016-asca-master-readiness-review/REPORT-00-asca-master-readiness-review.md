# ASCA-master Readiness Review — Code Review + Test-Run Assessment

| Field | Value |
|---|---|
| Document type | Investigation Report |
| Status | Final |
| Date | 2026-10-16 |
| Author / Investigator | bizdev |
| Assisted by | Kiro |
| Audience | ASCA engineering + accounting stakeholders (throy-san, cristoff-san) |
| Environment | Branch `feature/ASCA/ASCA-master` @ `47179527`; repo `/home/bizdev/dev/accounting_related_system_for_freee` (Laravel 8 batch/accounting); tests run in docker container `accounting-system` |
| JIRA | TBA |

Confidence markers used below: **(confirmed via code trace)**, **(confirmed via test run)**, **(inferred)**.

---

## 1. Summary (BLUF + readiness verdict)

**The allocation code on ASCA-master is in good shape and is READY for a controlled DEV04/local TEST-RUN of `command:DailyRateCalculationPreCommand`, subject to the data preconditions in §4.** No CONFIRMED correctness bugs, no TODO/FIXME/incomplete markers, and both allocation test suites are green (Unit 125/125, Feature 34/34) **(confirmed via test run)**.

The injection is wired exactly as the design describes: `AllocationInjector::allocate()` runs inside `CommonUtil::createDailyRateCalculation()` between the write-N loop and the sum build, wrapped in an outer try/catch so any unexpected throw leaves the month at N and the batch continues **(confirmed via code trace)**. Failure isolation is layered and sound — run-level pre-flight (V-6/V-4) leaves the whole month at N, per-pair/per-refund transactions roll back individually to N, outcome rows are written in their own commits after the loop, and the run row is always created/finalized/failed in its own committed transaction for auditability **(confirmed via code trace)**.

Two non-blocking issues are worth attention before (or alongside) the test run:

- **A CONFIRMED config/seeder drift** in `ReferencePriceSeeder`: the live `effective_from` comes from `config('revenue_allocation.launch.cap_first_target_month') = 2027-01-01`, not the `2026-12-01` its own docblock claims. This does NOT block a `target_ym = 2027-01` DEV04 run (prices still resolve for January), but it would cause a V-4 run-level failure for any 2026-12 close and contradicts the seeder's stated beta intent.
- **The known Open Item O-A** (Freee mapping rows for App `product_type = 100`) remains a DATA precondition for the Final/Freee leg — not exercised by a Pre (`_pre`) smoke run, but required before Final.

The deferred cosmetic cleanup (exception classes not under an `Exceptions/` dir; model-layer namespacing/`strict_types`) is confirmed present and is noted only — not a blocker.

---

## 2. Evidence — code review findings

Legend: severity is the risk if left unaddressed for a TEST-RUN. "Note" = intentional/known, no action needed for the test run.

| # | File / symbol | Finding | Confirmed / Suspected | Severity |
|---|---|---|---|---|
| E1 | `app/Libs/CommonUtil.php::createDailyRateCalculation` (≈L460–481) | Injection point present: `app(AllocationInjector::class)->allocate($targetYm, $preFlg)` sits after the write-N loop and before the sum build, wrapped in `try { … } catch (\Throwable)` that logs `[REVENUE_ALLOCATION] EXECUTION FAILED!` and lets the batch continue on N. Matches Scenario D + Option 1. | CONFIRMED (code trace) | Note (correct) |
| E2 | `app/Libs/DataCorrectionLogic.php::createDailyRateCalculation` (L344) | DataCorrection has its **own private** `createDailyRateCalculation()`; it does **not** call `CommonUtil::createDailyRateCalculation` and contains no `AllocationInjector` reference. The un-injection is structural, not accidental — consistent with Spec 02d decommissioning DataCorrectionCommand. | CONFIRMED (code trace) | Note (correct by design) |
| E3 | `app/Providers/AppServiceProvider.php` | `AllocationFormulaRegistry::foundation()`, `AllocationPersistenceService`, `AllocationValidator`, `RevenueAllocationService` are explicitly bound as singletons. `AllocationInjector` and the Refund collaborators (`RefundChargeDetector`, `RefundAppRowWriter`, `RefundLinkageResolver`) are **not** explicitly bound — they resolve via Laravel zero-config autowiring (all their constructor deps are autowirable or singleton-bound). Works, but the injector's wiring is implicit. | CONFIRMED (code trace) | Low (works; consider an explicit bind for parity/clarity) |
| E4 | `ReferencePriceSeeder.php` (L76–93) | `effective_from` fallback const is `2026-12-01` and the docblock states the beta uses `2026-12-01`, but the runtime value is `config('revenue_allocation.launch.cap_first_target_month') = 2027-01-01` (`config/revenue_allocation.php` L20). Seeded rows are therefore effective **2027-01-01**, not 2026-12-01. The seeder's own NOTE warns "keep both in step." Does not block a 2027-01 run; would V-4-fail a 2026-12 close. | CONFIRMED (code trace) | Medium (latent V-4 for Dec; doc/intent drift) |
| E5 | `AllocationInjector::allocate` / `runPreflightChecks` / `failPreflight` | Run-level pre-flight unions detected product ids with the canonical CAP set (`EXPECTED_PRODUCT_TYPE`), runs V-6 then V-4 before any overwrite; on failure marks run FAILED (own commit), overwrites nothing, returns empty — whole month stays at N. Does not re-throw (graceful degrade). | CONFIRMED (code trace) | Note (correct) |
| E6 | `AllocationInjector::allocateBundle` | Per-pair atomic transaction on `mysql`: snapshot → restore-N → V-7 → formula select → compute → overwrite N→P → persist group → V-1 assert; any throw rolls the pair back to N while committed pairs keep P. Re-run safety via snapshot restore (`restoreOriginalPaidPrices`). | CONFIRMED (code trace) | Note (correct) |
| E7 | `AllocationInjector::allocateRefund` + `RefundAppRowWriter::insertAppRow` | Refund path: restores original negative N from earliest snapshot, V-6/V-4 run-level (propagate), computes split via the same two-way formula, atomic (coaching overwrite + new App-row INSERT + persist + V-1) with per-refund rollback. Idempotent App-row insert deletes any prior negative refund App row for the charge+month before re-inserting (scoped to App product + `paid_price < 0`, so the ¥0 companion is untouched). | CONFIRMED (code trace) | Note (correct) |
| E8 | `AllocationInjector::allocateRefund` catch block | The atomic block catches only `UnbalancedGroupException`. A non-V-1 `Throwable` inside the refund transaction would roll back the DB but propagate out of `allocate()` to the CommonUtil try/catch (whole-injection abort → month stays at N). The positive `allocateBundle` catches `Throwable`. Asymmetry is defensible (refund V-6/V-4 are pre-computed and run-level), but an unexpected refund-time throw aborts the injection rather than isolating to the one refund. | SUSPECTED (code trace; no failing test) | Low |
| E9 | `TwoWayAllocationFormula::floorDiv` | True floor toward −∞ via `intdiv` + remainder correction, no float in the money math; `P_coaching = N − P_app` absorbs the remainder so `ΣP = ΣN` holds for positive and negative N. Zero-total-weight is deterministic (App 0, Coaching N). | CONFIRMED (code trace + test run: `TwoWayAllocationFormulaPropertyTest`, `*BalancePropertyTest`) | Note (correct) |
| E10 | `RunLifecycleService::finalize` | V-5 "at most one active Final" enforced by `INSERT IGNORE` anchor + `lockForUpdate` + supersede-then-activate + post-switch `activeFinal` count assert inside one transaction; failure rolls back and marks the run FAILED. `createRun`/`markFailed` each own their commit. `COMPLETED_WITH_ERRORS` supersedes exactly like `COMPLETED`. | CONFIRMED (code trace + test run: `RunLifecycleServiceTest`, `RunLifecycleActiveFinalPropertyTest`, `RunLifecycleConcurrencyTest`) | Note (correct) |
| E11 | `BundleDetectionService::fetchCandidateRows` | Positive detector excludes negative-`paid_price` coaching rows (`log.paid_price >= 0` OR non-coaching) so a same-month refund never turns a bundle into a 2-coaching V-3 skip. Group key always folds in `plan_id`+`start_date`+`end_date`; defensive `CoachingAndAppPlanEnum::exists()` re-filter in PHP. | CONFIRMED (code trace) | Note (correct) |
| E12 | `RefundChargeDetector::fetchNegativeCoachingRows` vs `BundleDetectionService` | The refund detector filters on `c.paid_price < 0` (the `trn_charge` column), while the positive detector's refund-exclusion filters on `log.paid_price >= 0` (the daily-rate-log column). If `trn_charge.paid_price` and `log.paid_price` could ever disagree in sign for a coaching row, a charge could be excluded from the positive set but not picked up as a refund (or vice-versa). In practice a refund clone carries a negative on both, so this is harmless; worth a one-line confirmation that both columns are sign-consistent for coaching. | SUSPECTED (code trace; needs data confirmation) | Low |
| E13 | `ReferencePriceResolver::resolve` | Resolves L on the **last day** of `target_ym`; throws `ReferencePriceResolutionException` on no row / overlap / inverted range / bad `target_ym`. `reference_price = 0` is a valid weight. Uses `MstAllocReferencePrice::query()`; the model pins `protected $connection = 'mysql'`, so the `mysql` connection is used (not a connection-leak bug). | CONFIRMED (code trace) | Note (correct) |
| E14 | All `app/Enums/RevenueAllocation/*` and `app/Libs/RevenueAllocation/*` | Every Libs and Enums file declares `declare(strict_types=1)`; PSR-12 structure, typed constructor-promoted deps, rich docblocks. | CONFIRMED (code trace) | Note (good) |
| E15 | `app/Models/RevenueAllocation/*` (12 files) | None of the 12 models declare `declare(strict_types=1)` (e.g. `MstAllocReferencePrice.php`, `LogAllocProration.php`). Consistent with the repo's existing Eloquent-model convention (models generally omit it), but inconsistent with the Libs/Enums in this feature. | CONFIRMED (code trace) | Note (cosmetic / deferred) |
| E16 | `ProductTypeMismatchException`, `ReferencePriceResolutionException`, `UnbalancedGroupException` | All three live directly in `App\Libs\RevenueAllocation` (not an `Exceptions/` subdir). Matches the known deferred-cleanup caveat. | CONFIRMED (code trace) | Note (deferred cosmetic) |
| E17 | `.kiro/steering/batch-execution-flow.md` (L98–103) | Smoke-test "Pass" string in steering is `[REVENUE_ALLOCATION] - END` and skip string `No bundles found`, but the injector actually logs `[REVENUE_ALLOCATION] inject allocate - END` and `… inject allocate - NO CAP BUNDLES (no-op)`. The grep keys on the `REVENUE_ALLOCATION` tag so it still surfaces the lines, but the documented literal match strings are stale. | CONFIRMED (code trace) | Low (doc drift) |

### No markers / clean signals
- `grep -rniE "TODO|FIXME|XXX|HACK|not implemented"` over `app/Libs/RevenueAllocation`, `app/Models/RevenueAllocation`, `app/Enums/RevenueAllocation` → **no matches** **(confirmed via code trace)**.
- Idempotency/re-run safety is designed in on both paths: source-document snapshot + restore-N (positive) and earliest-snapshot restore + negative-refund-App-row delete-then-insert (refund), with within-run de-dupe in `AllocationPersistenceService::snapshotSourceData` **(confirmed via code trace; exercised by `IdempotentReRunPropertyTest`, `ReRunIdempotencePropertyTest`, `RefundIdempotencePropertyTest` — confirmed via test run)**.

---

## 3. Test state **(confirmed via test run)**

Command (inside the running `accounting-system` container), output captured to a temp log and read back:

```
docker exec accounting-system php vendor/bin/phpunit tests/Unit/RevenueAllocation
docker exec accounting-system php vendor/bin/phpunit tests/Feature/RevenueAllocation
```

| Suite | Result | Tests | Assertions | Time |
|---|---|---|---|---|
| `tests/Unit/RevenueAllocation` | **OK (all pass)** | 125 | 42,761 | ~8.6 s |
| `tests/Feature/RevenueAllocation` | **OK (all pass)** | 34 | 28,067 | ~13.8 s |

PHPUnit 9.5.20. No failures, no errors, no skipped/incomplete reported. Coverage spans the correctness properties referenced in the code (balance, exclusion filtering, pair isolation, run-level failure, idempotence, reference-price December resolution, refund no-netting/positive-not-skipped, run-lifecycle concurrency, DEV04 end-to-end + smoke).

---

## 4. Readiness assessment — TEST-RUN of `command:DailyRateCalculationPreCommand {exeDate}`

Execution path **(confirmed via code trace)**: `DailyRateCalculationPreCommand::handle` → `new DailyRateCalculationPreLogic($exeDate)->execute()` → `CommonUtil::createDailyRateCalculation($targetYm, …, $preFlg = true)` (L73) → injection point → `AllocationInjector::allocate($targetYm, true)` (Preview run, writes `log_daily_rate_calculation_pre`). A Pre run never syncs Freee, so O-A (Freee mapping) is **not** on the critical path for a Pre smoke test.

| Item | State | Detail |
|---|---|---|
| Injection wiring | **READY** | E1/E3 — injector runs inside the Pre daily-rate step; outer try/catch isolates failure. (confirmed via code trace) |
| Allocation code correctness | **READY** | No CONFIRMED bugs; both suites green. (confirmed via test run) |
| Pre (`_pre`) target tables | **READY** | `$preFlg = true` routes every read/write to `log_daily_rate_calculation_pre`. (confirmed via code trace) |
| CAP master data (plans 1016–1027) | **PRECONDITION** | Seed via ls-db `CapCoachingAppPlansSeeder` (external repo) so CAP plan rows exist for detection's `trn_charge` join. Not seeded by this review. (inferred — not verified in this repo) |
| Reference prices (`mst_alloc_reference_prices`) | **PRECONDITION** (with caveat) | Seed via accounting-repo `ReferencePriceSeeder`. For a `target_ym = 2027-01` run the seeded `effective_from = 2027-01-01` rows resolve on 2027-01-31 → OK. See E4: do NOT assume 2026-12 coverage. (confirmed via code trace) |
| DEV04 CAP test charges | **PRECONDITION** | Seed via `Dev04CapTestDataSeeder` — one coaching+App pair per plan 1016–1027 at `target_ym = 2027-01`, coaching `paid_price = 20000`, App `0`. Align `exeDate` so `CommonUtil::getTargetYm()` yields `202701`. (confirmed via code trace) |
| Target-month alignment | **PRECONDITION** | The run's `target_ym` (derived from `exeDate`) must match the seeded charge month (2027-01) and be ≥ `cap_first_target_month`. A mismatched month yields the no-op path (zero bundles) — a valid but uninteresting smoke result. (confirmed via code trace) |
| Freee mapping for App `product_type = 100` (`mst_rule_for_journals` / `mst_code_change`) — **O-A** | **GAP (Final only)** | Required before a Final run routes the raised App row to a Freee journal. Not exercised by a Pre smoke test. DATA check, not code. (inferred — known open item) |
| Smoke-test observability | **READY** (doc drift) | Follow `.kiro/steering/batch-execution-flow.md`; grep `REVENUE_ALLOCATION`. Expect `inject allocate - END` (not the doc's `- END`) and inspect `log_alloc_calculation_runs` for status/`error_message`. See E17. (confirmed via code trace) |

**Verdict:** A Pre smoke run on DEV04/local can be done safely **once the three PRECONDITION seeders are applied and `exeDate` is aligned to 2027-01**. Expected healthy outcome: a Preview run in `log_alloc_calculation_runs` reaching `COMPLETED` (status 2) with `record_count` = number of valid CAP pairs, overwritten P in `log_daily_rate_calculation_pre`, and `[REVENUE_ALLOCATION] inject allocate - END` with no `EXECUTION FAILED!`. The Final/Freee leg stays gated on O-A.

---

## 5. Next steps (recommendations — implement nothing here)

1. **Resolve E4 before any 2026-12 processing.** Decide whether CAP beta truly starts 2026-12 (then set `cap_first_target_month = 2026-12-01` / align the seeder) or 2027-01 (then fix the `ReferencePriceSeeder` docblock + fallback const to stop claiming December). Today the config wins and seeds January; the docblock is misleading.
2. **Run the test-run preconditions in order:** ls-db `CapCoachingAppPlansSeeder` → accounting `ReferencePriceSeeder` → `Dev04CapTestDataSeeder`, then `command:DailyRateCalculationPreCommand` with an `exeDate` whose `target_ym = 202701`. Verify via the `REVENUE_ALLOCATION` grep and the `log_alloc_calculation_runs` row.
3. **Close O-A before Final.** Confirm `mst_rule_for_journals` / `mst_code_change` carry App `product_type = 100` mappings so the raised/negative App rows route to a Freee journal; this is the only thing between a green Pre smoke test and a trustworthy Final.
4. **Optional, low priority:** (a) consider an explicit container bind for `AllocationInjector` (E3) for wiring parity; (b) confirm coaching-row sign consistency between `trn_charge.paid_price` and `log.paid_price` (E12); (c) refresh the steering smoke-test literal match strings (E17); (d) fold the deferred cosmetic cleanup (exceptions → `Exceptions/` dir, model namespacing/`strict_types`, E15/E16) into a single Foundation-wide follow-up ticket.

---

### Appendix — files reviewed (code trace)

Libs: `AllocationInjector`, `RevenueAllocationService` (referenced), `BundleDetectionService`, `AllocationValidator`, `ReferencePriceResolver`, `RunLifecycleService`, `InjectionRunResult`, `Formula/TwoWayAllocationFormula`, `Persistence/AllocationPersistenceService`, `Refund/{RefundChargeDetector, RefundLinkageResolver, RefundAppRowWriter}`. Injection points: `CommonUtil::createDailyRateCalculation`, `DataCorrectionLogic::createDailyRateCalculation`, `DailyRateCalculationPreLogic::execute`, `DailyRateCalculationPreCommand`. Wiring/config: `AppServiceProvider`, `config/revenue_allocation.php`. Enums: `CoachingAndAppPlanEnum`, `RunStatus`. Models: `MstAllocReferencePrice` (+ 11 other `LogAlloc*` models for `strict_types` scan). Seeders: `ReferencePriceSeeder`, `Dev04CapTestDataSeeder`. Steering: `.kiro/steering/batch-execution-flow.md`. Tests executed: `tests/Unit/RevenueAllocation`, `tests/Feature/RevenueAllocation`.
