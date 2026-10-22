# ASCA-78 — [CR] Remove Spec 02c AllocationDetail CSV

> **Created in JIRA 2026-10-22 as [ASCA-78](https://bizmates.atlassian.net/browse/ASCA-78)** — Sub-task under ASCA-55, Priority High, status To Do. This file is the full-Markdown source of record; the JIRA ticket carries the same content in Jira markup.

**Type:** Sub-task
**Parent:** ASCA-55 ([Spec 02c] — Coding)
**Epic:** ASCA-52 ([Spec 02c] — AllocationDetail CSV)
**Priority:** High
**Assignee:** Dev
**Hard deadline:** Remove before the CAP beta release **2026-12-01** (REF-CAP-17 / Kuroda-san)
**Source:** `research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md`
**Decision:** `projects/asca/documentation/ASCA-ADR-20261020-drop-02c-allocationdetail-csv.md`

---

## Summary

Remove the AllocationDetail CSV delivered by Spec 02c (merged under ASCA-55, PR #312). Per REF-CAP-16 (Kuroda-san, 2026-10-19), the new plans' revenue is already shown in the existing DailyRateCalculation CSV, and the CAP allocation breakdown moves to a Metabase table on ASCA-8. The dedicated CSV is no longer wanted.

This is a change-request REMOVAL of already-merged code — not a new spec (mirrors the Spec 01 CR pattern and the 02d decommission).

## Context

- 02c was reviewed (REF-CAP-14), signed off (REF-CAP-15), coded, and merged to `feature/ASCA/ASCA-master`.
- Direction change arrived after merge, so this removes merged code rather than cancelling unstarted work.
- KEEP (confirmed by Kuroda-san): `log_alloc_bundle_outcomes` (ASCA-66) and the run-status extension (ASCA-68). Do NOT touch those.

## Scope — accounting repo (`accounting_related_system_for_freee`)

- [ ] Delete `app/Libs/RevenueAllocation/RevenueAllocationCsvService.php`.
- [ ] Remove the `allocationDetailFile` entry from `config/const.php`.
- [ ] Remove the CSV wiring from `app/Libs/DailyRateCalculationPreLogic.php` (Pre) — the `hasCompletedRun()`-guarded `createAllocationDetailFile(...)` call and any now-unused imports.
- [ ] Remove the same CSV wiring from `app/Libs/SendJournalsDataLogic.php` (Final).
- [ ] Delete the 02c tests (AllocationDetail / RevenueAllocationCsv under `tests/Unit/RevenueAllocation` and `tests/Feature/RevenueAllocation`).
- [ ] Stamp `.kiro/specs/asca-spec-02c-allocation-detail-csv/` as superseded by REF-CAP-16 (do NOT regenerate — already merged; add a superseded note only).

## Out of scope / do NOT touch

- `log_alloc_bundle_outcomes` / ASCA-66 (kept — 02a writes outcome rows).
- Run-status extension / ASCA-68 (kept — Metabase needs it).
- CAP allocation engine (02a), refund (02b), CIP, Foundation.
- The Metabase table + allocation-basis-amount column — owned by ASCA-8, not this repo.

## QA scope note (Glenn)

Per REF-CAP-16/17 (Kuroda-san): the **AllocationDetail CSV is OUT of QA scope** — it is being removed by this CR, so QA should NOT test or sign it off as a deliverable. What QA verifies instead:

- CAP allocated amounts appear correctly in the **existing DailyRateCalculation CSV** (Option 1 overwrite N→P) — already verified on ASCA-71.
- On DEV04, the AllocationDetail CSV may remain as a **temporary verification aid** until this removal lands; it is not a QA pass/fail item.

## Shared-code check before deletion (do this first)

- [ ] `LogAllocCalculationRun::hasCompletedRun()` was added for 02c but **may be referenced by ASCA-68's view/run-status logic.** Grep for `hasCompletedRun` across `app/` before deleting its test or method. If ASCA-68 uses it → KEEP the method, delete only the AllocationDetail-specific test (`LogAllocCalculationRunHasCompletedRunTest` if it is purely about the CSV path).
- [ ] For each mixed-name test in `tests/Unit/Libs/` (e.g. `DailyRateCalculationPreLogicCreateSendMailAttacheFileTest`), confirm it is wholly about the AllocationDetail CSV → delete; if it also asserts surviving zip/email behavior → edit to drop only the AllocationDetail assertions.

## Acceptance Criteria (Definition of Done)

- [ ] `RevenueAllocationCsvService` and the `allocationDetailFile` config entry no longer exist.
- [ ] Neither `DailyRateCalculationPreLogic` nor `SendJournalsDataLogic` references the AllocationDetail CSV; both batches still build their existing CSVs and ship their zip/email unchanged.
- [ ] `grep -r "AllocationDetail\|RevenueAllocationCsv\|allocationDetailFile" app/ config/ tests/` returns zero matches.
- [ ] `php vendor/bin/phpunit tests/Unit/RevenueAllocation` and `tests/Feature/RevenueAllocation` pass (no regression; 02a/02b/outcomes/run-status untouched).
- [ ] The 02c spec folder carries a superseded note; ASCA-66 and ASCA-68 code is unchanged.

## Verification

- Run the allocation suites (above).
- Smoke `php artisan command:DailyRateCalculationPreCommand <exeDate>` on DEV04: the batch completes and the zip no longer contains the AllocationDetail CSV; allocation still overwrites N->P and the existing DailyRateCalculation CSV shows the allocated amounts.

## Dependencies / timing

- **DEV04 command verification is DONE** (ASCA-24 Done; CAP allocation verified in the DailyRateCalculation CSV by Glenn-san on ASCA-71, 2026-10-21). The earlier "execute after DEV04" gate is **satisfied** — this CR is unblocked.
- **No dependency on ASCA-8 / Metabase.** The system does not read from Metabase; removal does not wait for the Metabase table to be ready.
- **No dependency on ASCA-66 / ASCA-68** (those stay).
- **Hard deadline: 2026-12-01** (CAP beta). Batch with any other post-DEV04 changes if convenient, but do not slip past Dec 1.

## JIRA housekeeping (separate from this sub-task)

- Close 02c epic ASCA-52 and its non-coding stories (ASCA-53/54/56/57/58) as won't-do / superseded.
- This removal CR is the one piece of ASCA-52 that still gets worked, as a sub-task under ASCA-55.

## References

- REF-CAP-16 (source): `research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md`
- ADR (decision): `projects/asca/documentation/ASCA-ADR-20261020-drop-02c-allocationdetail-csv.md`
- Decommission precedent: `projects/asca/documentation/ASCA-ADR-20261005-datacorrection-decommission.md`
