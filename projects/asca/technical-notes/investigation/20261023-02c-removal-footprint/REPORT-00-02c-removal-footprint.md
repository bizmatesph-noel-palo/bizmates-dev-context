# Spec 02c AllocationDetail CSV — Exact Removal Footprint (READ-ONLY investigation)

- **Repo:** `/home/bizdev/dev/accounting_related_system_for_freee`
- **Branch inspected:** `feature/ASCA/ASCA-79-spec-2-steering-updates` (HEAD `4023d20f`)
  - This branch = `feature/ASCA/ASCA-master` (`9eda279c`) + ONE unrelated steering-note change in `.kiro/steering/batch-execution-flow.md`. The 02c code is byte-identical to ASCA-master. Treat ASCA-master as the removal base; ignore the steering diff.
- **02c source commit:** `4c133642` — `[ASCA-48] Spec 02c - AllocationDetail CSV` (38 files, +6457/-134).
- **Reference:** REF-CAP-16 / ADR-20261020 — the AllocationDetail CSV is being DROPPED.
- **Mode:** read-only. No code was edited. Every line number below matches the file on the current branch.

---

## Summary answer (read this first)

The 02c footprint is **surgical, not a revert.** Do **NOT** `git revert 4c133642` — that commit also introduced KEEP code (the `RowKind` / `OutcomeType` enums, now consumed by the ASCA-66 `LogAllocBundleOutcome` model, plus edits to `AllocationInjector` and several 02a/02b/ASCA-66 tests). A revert would delete surviving engine/model code.

Remove exactly:

- **DELETE whole file:** 1 service + 16 test files (3 under `tests/Unit/Libs`, 8 under `tests/Unit/RevenueAllocation`, 5 under `tests/Feature/RevenueAllocation`).
- **REMOVE block + 3 imports** in each of the two batch-wiring classes (`DailyRateCalculationPreLogic`, `SendJournalsDataLogic`).
- **REMOVE 1 config entry** (`config/const.php` lines 280–304).
- **REMOVE 1 standalone model method** `LogAllocCalculationRun::hasCompletedRun()` (lines 125–150) — it was added FOR 02c and has no other caller.

**Open question 1 verdict — `hasCompletedRun()`: DELETE the method.** Its only callers are the two CSV injection points; ASCA-68's view/run-status logic uses `scopeActiveFinal()`, a different method. KEEP the model class and `scopeActiveFinal()`.

**Open question 2 verdict — mixed-name `tests/Unit/Libs` files: DELETE all three whole. No test needs EDITING.** The two base behavior tests (`DailyRateCalculationPreLogicTest`, `SendJournalsDataLogicTest`) have zero AllocationDetail entanglement and are untouched.

---

## A. Exact removal list

### A.1 — DELETE whole file

**Production (1):**

| File | Reason |
|---|---|
| `app/Libs/RevenueAllocation/RevenueAllocationCsvService.php` | The 02c service. `final class RevenueAllocationCsvService` (line 44); public entry `createAllocationDetailFile()` (line 149); helpers `buildAllocatedRows()` (236), `buildExceptionRows()` (326). Sole non-test consumers are the two wiring blocks removed in A.2. |

**Tests — `tests/Unit/Libs/` (3) — see §B.2 for per-file verdicts:**

- `tests/Unit/Libs/DailyRateCalculationPreLogicCreateSendMailAttacheFileTest.php`
- `tests/Unit/Libs/SendJournalsDataLogicAllocationDetailInjectionTest.php`
- `tests/Unit/Libs/AllocationDetailGuardedInjectionCrossCuttingTest.php`

**Tests — `tests/Unit/RevenueAllocation/` (8):**

- `AllocationDetailBomAndStorageTest.php`
- `AllocationDetailLabelMapsTest.php`
- `AllocationDetailReproducibilityPropertyTest.php`
- `CommonUtilAllocationDetailFileConfigTest.php`  *(tests the config entry removed in A.3)*
- `RevenueAllocationCsvServiceAllocatedRowsTest.php`
- `RevenueAllocationCsvServiceExceptionRowsTest.php`
- `RevenueAllocationCsvServiceWriteTest.php`
- `LogAllocCalculationRunHasCompletedRunTest.php`  *(tests the method removed in A.5 — see §B.1)*

**Tests — `tests/Feature/RevenueAllocation/` (5):**

- `AllocationDetailCipExclusionPropertyTest.php`
- `AllocationDetailCompletenessPropertyTest.php`
- `AllocationDetailConsistencyPropertyTest.php`
- `AllocationDetailDev04SmokeTest.php`
- `AllocationDetailGuardPropertyTest.php`

> **KEEP (do NOT delete) in these two test dirs:** every `Injection*`, `Refund*`, `RunLifecycle*`, `Allocation{Balance,Persistence,Formula}*`, `Bundle*`, `ReferencePrice*`, `LogAllocBundleOutcomeTest`, `RevenueAllocationEnumTest`, `RevenueAllocationModelBindingTest`, etc. These are 02a/02b/ASCA-66/ASCA-68 and are unrelated to the CSV. The two dirs are **mixed** — do not delete the directories.

### A.2 — REMOVE guarded block + imports (two wiring classes)

**`app/Libs/DailyRateCalculationPreLogic.php`** (Pre / 速報版):

- Remove the guarded block, **lines 137–142** (comment + `if`):
  ```php
  // 配分明細ファイル作成 (ASCA 02c) — 速報版の完了したPreview実行がある場合のみ追加
  if (LogAllocCalculationRun::hasCompletedRun($targetYm, RunType::PREVIEW)) {
      [$fileName, $name] = app(RevenueAllocationCsvService::class)
          ->createAllocationDetailFile($targetYm, true);
      $fileNameList[$fileName] = $name;
  }
  ```
- Remove the three now-orphaned imports (each used ONLY by that block — verified by grep, no other occurrence in the file):
  - line 5 `use App\Enums\RevenueAllocation\RunType;`
  - line 6 `use App\Libs\RevenueAllocation\RevenueAllocationCsvService;`
  - line 9 `use App\Models\RevenueAllocation\LogAllocCalculationRun;`
- KEEP: `use App\Libs\CommonUtil;` (line 5- context, used throughout) and `use App\Libs\ZipanUtil;` (line 7) — still used.

**`app/Libs/SendJournalsDataLogic.php`** (Final / 確定版):

- Remove the guarded block, **lines 1029–1035** (comment + `if`):
  ```php
  // 配分明細ファイル作成（Final実行が完了している場合のみ）
  if (LogAllocCalculationRun::hasCompletedRun($targetYm, RunType::FINAL)) {
      [$allocationDetailFileName, $allocationDetailName] = app(RevenueAllocationCsvService::class)
          ->createAllocationDetailFile($targetYm, false);
      $fileNameList[$allocationDetailFileName] = $allocationDetailName;
  }
  ```
- Remove the three now-orphaned imports (each used ONLY by that block — verified by grep):
  - line 7 `use App\Libs\RevenueAllocation\RevenueAllocationCsvService;`
  - line 8 `use App\Enums\RevenueAllocation\RunType;`
  - line 12 `use App\Models\RevenueAllocation\LogAllocCalculationRun;`

> Both blocks sit between the existing PayPal-sum CSV append and the `ZipanUtil::addZipan*` call. Removing them leaves the surrounding zip/email pipeline (`ArchiverService` / `MailerService`) untouched.

### A.3 — REMOVE config entry

**`config/const.php`** — remove the `allocationDetailFile` entry, **lines 280–304** (comment through its closing `],`):

```php
// 配分明細ファイル（ASCA 02c AllocationDetail CSV）
'allocationDetailFile' => [
    'fileName' => '{YYYYMM}_10_AllocationDetail({execDate}).csv',
    ... // headerItem list
],
```
- Line 279 `],` closes the preceding entry; line 305 `],` closes the enclosing `csvFile` array. Remove exactly 280–304, leaving 279 and 305 intact.

### A.4 — (no additional production touchpoints)

Grep of `database/`, `routes/`, and `app/Providers/` for `AllocationDetail`, `RevenueAllocationCsv`, `allocationDetailFile`, `hasCompletedRun` returned **nothing**. There is no migration, route, or service-provider binding to remove.

### A.5 — REMOVE standalone model method

**`app/Models/RevenueAllocation/LogAllocCalculationRun.php`** — remove `hasCompletedRun()`, **lines 125–150** (its docblock 125–139 + method body 140–150). It is a standalone `public static` method; no other method in the class calls it. See §B.1 for the KEEP/DELETE reasoning.

- KEEP the class and all other members, notably `scopeActiveFinal()` (lines ~114–123) — that is the ASCA-68 active-Final selector, a different method.

---

## B. The two open-question verdicts

### B.1 — Is `LogAllocCalculationRun::hasCompletedRun()` safe to delete?

**Verdict: DELETE the method (and its dedicated test). KEEP the model class and `scopeActiveFinal()`.**

Grep evidence (`hasCompletedRun` across `app/` + `tests/` + `config/` + `database/` + `routes/`):

- **Definition:** `app/Models/RevenueAllocation/LogAllocCalculationRun.php:140`.
- **Production callers (only two, both 02c CSV injection points):**
  - `app/Libs/DailyRateCalculationPreLogic.php:139` — `hasCompletedRun($targetYm, RunType::PREVIEW)`
  - `app/Libs/SendJournalsDataLogic.php:1031` — `hasCompletedRun($targetYm, RunType::FINAL)`
  - (also a doc mention at `RevenueAllocationCsvService.php:127`)
- **Test callers (all 02c AllocationDetail tests, each in the A.1 delete list):**
  `tests/Unit/Libs/DailyRateCalculationPreLogicCreateSendMailAttacheFileTest.php`,
  `tests/Unit/Libs/SendJournalsDataLogicAllocationDetailInjectionTest.php`,
  `tests/Unit/Libs/AllocationDetailGuardedInjectionCrossCuttingTest.php`,
  `tests/Unit/RevenueAllocation/LogAllocCalculationRunHasCompletedRunTest.php`,
  `tests/Feature/RevenueAllocation/AllocationDetailGuardPropertyTest.php`.
- **ASCA-68 view/run-status logic does NOT call it.** The run-status/active-Final selection uses `scopeActiveFinal()` (same file, lines ~114–123), which is a separate query. `hasCompletedRun()`'s own docblock (lines 129–135) states it is the *"Read-only guard consumed by the AllocationDetail CSV injection points (Req 3.2, 3.3)"* — i.e. it was added **for 02c**. Commit check: `git log -S"public static function hasCompletedRun"` → only `4c133642` (the 02c commit).

Therefore the method is 02c-only and safe to delete.

- **Test that is purely about the CSV path → DELETE:** `tests/Unit/RevenueAllocation/LogAllocCalculationRunHasCompletedRunTest.php`. Despite the method name in its title, its entire purpose is to prove the `hasCompletedRun()` guard behaves (COMPLETED / COMPLETED_WITH_ERRORS → true; FAILED / none → false) so the CSV append fires correctly. The method it guards is being removed, so the test goes with it. (`AllocationDetailGuardPropertyTest.php` is the Feature-level equivalent — also deleted.)
- There is **no** test that exercises `hasCompletedRun()` as a shared method for a KEEP feature. If `hasCompletedRun()` were ever kept (not recommended), the only test to retain would be `LogAllocCalculationRunHasCompletedRunTest.php` — but with no remaining callers, keep neither.

### B.2 — Mixed-name `tests/Unit/Libs/` files: delete whole vs edit?

**Verdict: all three are WHOLLY about the AllocationDetail CSV → DELETE whole. None asserts a standalone zip/email/attachment guarantee that must survive, so NO test needs editing.**

Per-file:

| File | Test methods | What they assert | Decision |
|---|---|---|---|
| `DailyRateCalculationPreLogicCreateSendMailAttacheFileTest.php` | `test_file_appended_exactly_once_when_preview_run_completed`, `test_file_not_appended_when_preview_run_not_completed` | The AllocationDetail guarded block appends the file exactly once when the Preview run is complete and not at all otherwise. Docblock: *"Task 8 (ASCA Spec 02c, AllocationDetail CSV) … Covers the guarded AllocationDetail block."* All static collaborators (`CommonUtil`, `ZipanUtil`, `LogAllocCalculationRun`) are alias-mocked precisely so the CSV/zip/mail machinery is **not** under test (it has its own tests). | **DELETE whole** |
| `SendJournalsDataLogicAllocationDetailInjectionTest.php` | `test_appends_allocation_detail_file_when_final_run_completed`, `test_does_not_append_allocation_detail_file_when_no_completed_final_run` | The Final-side guarded injection — appends when `hasCompletedRun(..., FINAL)` is true, skips otherwise. | **DELETE whole** |
| `AllocationDetailGuardedInjectionCrossCuttingTest.php` | `test_final_injection_appends_file_when_final_run_completed_with_errors`, `test_pre_injection_appends_file_when_preview_run_completed_with_errors`, `test_final_injection_does_not_attach_file_when_final_failed_despite_completed_preview_run_same_month` | Cross-cutting COMPLETED_WITH_ERRORS / per-run-type guard behavior for both injection points. Entirely AllocationDetail. | **DELETE whole** |

The incidental "the rest of `$fileNameList` is left unaffected" assertions inside these tests are not a standalone contract for the zip/email pipeline — that contract is owned by the base tests below, which are **not** AllocationDetail tests.

**Base behavior tests — verified NO entanglement, leave untouched (no edit):**

- `tests/Unit/Libs/DailyRateCalculationPreLogicTest.php` — grep for `alloc|hasCompletedRun|RevenueAllocationCsv|RunType` → **no matches**.
- `tests/Unit/Libs/SendJournalsDataLogicTest.php` — same grep → **no matches**.

---

## C. Hidden-consumer check

Repo-wide grep (`app/ config/ tests/ database/ routes/`, plus `app/Providers/`) for the four identifiers:

| Identifier | Locations found | All accounted for in removal list? |
|---|---|---|
| `RevenueAllocationCsvService` | service file (self); `DailyRateCalculationPreLogic` (import+call); `SendJournalsDataLogic` (import+call); the 16 test files in A.1 | ✅ Yes |
| `createAllocationDetailFile` | service file (def); two wiring calls; A.1 test files | ✅ Yes |
| `allocationDetailFile` | `config/const.php:281`; `RevenueAllocationCsvService.php` (151, 395 comment); `SendJournalsDataLogic.php:1032,1034` (local var names in the removed block); A.1 test files | ✅ Yes |
| `AllocationDetail` | service + wiring blocks + A.1 test files only | ✅ Yes |
| `hasCompletedRun` | model def + two wiring calls + A.1 test files (see §B.1) | ✅ Yes |

**No dangling consumer found anywhere else.** No references in `database/`, `routes/`, or `app/Providers/` (no migration, route, or DI binding). The service is resolved ad-hoc via `app(RevenueAllocationCsvService::class)` at the two call sites only — there is no container binding to unregister.

**Entanglement flagged — do NOT remove (would break KEEP code):**

- `app/Enums/RevenueAllocation/RowKind.php` and `app/Enums/RevenueAllocation/OutcomeType.php` were **created** in the 02c commit, but are now consumed by the **KEEP** `LogAllocBundleOutcome` model (`@property` docblocks + `{@see RowKind::NORMAL}` / `{@see OutcomeType::SKIPPED}` mirroring its `ROW_KIND_*` / `OUTCOME_*` constants), and the 02a/02b engine `AllocationInjector` writes `LogAllocBundleOutcome` using those constants. `RevenueAllocationCsvService` also references `RowKind`, but it is not the sole consumer. **KEEP both enums.** This is the concrete reason a blind `git revert 4c133642` is wrong — it would also delete these enums and revert `LogAllocBundleOutcome` / `AllocationInjector` / the 02a-02b-ASCA-66 test edits bundled into the same commit.

---

## D. Post-removal verification plan

1. **Zero-reference grep (must return nothing):**
   ```bash
   cd /home/bizdev/dev/accounting_related_system_for_freee
   grep -rn "RevenueAllocationCsvService\|createAllocationDetailFile\|allocationDetailFile\|hasCompletedRun\|AllocationDetail" \
     app/ config/ tests/ database/ routes/
   ```
   Expected: **no output.** (Equivalently, confirm `app/Libs/RevenueAllocation/RevenueAllocationCsvService.php` no longer exists and the two wiring files + `config/const.php` + the model have no match.)

2. **Confirm KEEP enums survive:**
   ```bash
   ls app/Enums/RevenueAllocation/RowKind.php app/Enums/RevenueAllocation/OutcomeType.php   # both present
   grep -rn "RowKind\|OutcomeType" app/Models/RevenueAllocation/LogAllocBundleOutcome.php    # still referenced
   ```

3. **Run the (now-trimmed) suites — expect green, with the 02c files gone:**
   ```bash
   vendor/bin/phpunit tests/Unit/RevenueAllocation
   vendor/bin/phpunit tests/Feature/RevenueAllocation
   vendor/bin/phpunit tests/Unit/Libs
   ```
   - `tests/Unit/Libs` is the key regression check: the two base tests (`DailyRateCalculationPreLogicTest`, `SendJournalsDataLogicTest`) must still pass unchanged, proving the zip/email wiring survives the block removal. No `tests/Unit/Libs` file was edited, so none should newly fail; any failure there means a surviving import/block was over-removed.
   - In the two RevenueAllocation dirs, only the 02c-named files are gone; all `Injection*` / `Refund*` / `RunLifecycle*` / engine / model tests must still pass.

4. **Static/sanity:** run the project's full `vendor/bin/phpunit` once to confirm no other suite referenced the deleted symbols. (I did not run any tests in this read-only pass.)

---

## E. Spec-folder note

`.kiro/specs/asca-spec-02c-allocation-detail-csv/` **exists** and contains `design.md`, `requirements.md`, `tasks.md`, `.config.kiro`.

Per the brief: **stamp it SUPERSEDED — do NOT regenerate.** Add a superseded banner/front-matter pointing at REF-CAP-16 / ADR-20261020 as the decision that dropped the CSV. Leave the content as the historical record of what was built and removed.

---

## Appendix — line-number ground truth (current branch)

| File | Lines | Content |
|---|---|---|
| `app/Libs/RevenueAllocation/RevenueAllocationCsvService.php` | 44 / 149 / 236 / 326 | class / `createAllocationDetailFile()` / `buildAllocatedRows()` / `buildExceptionRows()` |
| `app/Libs/DailyRateCalculationPreLogic.php` | 5,6,9 / 137–142 | orphaned imports / guarded block |
| `app/Libs/SendJournalsDataLogic.php` | 7,8,12 / 1029–1035 | orphaned imports / guarded block |
| `config/const.php` | 280–304 | `allocationDetailFile` entry (279 and 305 are KEEP delimiters) |
| `app/Models/RevenueAllocation/LogAllocCalculationRun.php` | 125–150 | `hasCompletedRun()` docblock+method (KEEP `scopeActiveFinal` ~114–123) |

*Investigation was read-only. No files in the accounting repo were modified. Quotations are short identifier-level fragments; longer content is paraphrased.*
