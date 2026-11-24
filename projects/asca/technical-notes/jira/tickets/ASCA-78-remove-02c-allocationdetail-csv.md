# ASCA-78 — [CR] Remove Spec 02c AllocationDetail CSV

> **Created in JIRA 2026-10-22 as [ASCA-78](https://bizmates.atlassian.net/browse/ASCA-78)** — Sub-task under ASCA-55, Priority High, status To Do. This file is the source of record; the JIRA ticket carries the same content (this Jira renders Markdown).
>
> **Handover to the dev:** the grounded footprint trace and paste-ready dev-Kiro prompt are below (see "Handover — how the dev executes this"). The dev follows that prompt so their Kiro's POV matches the authoring POV.

**Type:** Sub-task
**Parent:** ASCA-55 ([Spec 02c] — Coding)
**Epic:** ASCA-52 ([Spec 02c] — AllocationDetail CSV)
**Priority:** High
**Assignee:** Dev
**Hard deadline:** Remove before the CAP beta release **2026-12-01** (REF-CAP-16, the 3:01 PM confirmation / Kuroda-san)
**Source:** `research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md`
**Decision:** `projects/asca/documentation/ASCA-ADR-20261020-drop-02c-allocationdetail-csv.md`

---

## Summary

Two goals:

1. **Remove** the AllocationDetail CSV delivered by Spec 02c (merged under ASCA-55, PR #312). Per REF-CAP-16 (Kuroda-san, 2026-10-19), the new plans' revenue is already shown in the existing DailyRateCalculation CSV, and the CAP allocation breakdown moves to a Metabase table on ASCA-8. The dedicated CSV is no longer wanted.
2. **Make sure the allocated value lands in the daily-rate table.** With the report gone, the allocated amount (P) must be the `paid_price` stored in `log_daily_rate_calculation(_pre)` so it flows into the existing DailyRateCalculation CSV. **This already works** — 02a's `AllocationInjector::overwriteDailyRateRows()` overwrites `paid_price` with the allocated value in place (Option 1 overwrite N→P), and Glenn-san's ASCA-71 verification (2026-10-21) confirmed the allocated App amounts appear in the DailyRateCalculation CSV. So this goal is a **verification/assertion**, not new code: confirm the overwrite still holds after the report removal. Do NOT add a second write path — that would duplicate 02a.

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
- [ ] **The allocated value (P) is the `paid_price` in `log_daily_rate_calculation(_pre)`** after a run — confirmed still true after the report removal (02a's `overwriteDailyRateRows()` overwrite is untouched; the existing DailyRateCalculation CSV shows the allocated amounts, as on ASCA-71). No second/duplicate write path added.
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

---

## Handover — how the dev executes this

This is a **Change Request to a completed spec** — supersede, don't edit (toolkit: `workflows/spec-driven-development.md` → "Change Requests to an Already-Completed Spec"). It is a **lightweight CR** (surgical removal; no design cycle).

**Grounding (read-only trace, line-level):**
`projects/asca/technical-notes/investigation/20261023-02c-removal-footprint/REPORT-00-02c-removal-footprint.md` — exact files, lines, imports, the two open-question verdicts, and the hidden-consumer check, captured against live code on a branch equal to `feature/ASCA/ASCA-master`.

**Paste-ready dev-Kiro prompt:**
`projects/asca/technical-notes/jira/tickets/ASCA-78-dev-handover-prompt.md` — the context-load + task instructions for the assigned dev's Kiro, with the branch step and the "verify against live code first" discipline.

**The one trap that makes this non-trivial (do NOT miss):**
Do **not** `git revert` the 02c commit (`4c133642`). That commit also introduced KEEP code — the `RowKind` / `OutcomeType` enums now consumed by the ASCA-66 `LogAllocBundleOutcome` model and the 02a/02b `AllocationInjector`. A revert would delete surviving engine code. This is a **surgical** removal, not a revert.

**Resolved open questions (from the trace):**
- `LogAllocCalculationRun::hasCompletedRun()` → **DELETE the method** (only the two CSV sites call it; ASCA-68 uses `scopeActiveFinal()`).
- All three mixed-name `tests/Unit/Libs/` files → **DELETE whole** (no editing; the base behavior tests are clean and must pass unchanged as the regression proof).

**Supersede the spec:** stamp `.kiro/specs/asca-spec-02c-allocation-detail-csv/` SUPERSEDED (pointer to REF-CAP-16 / ADR-20261020). Do NOT regenerate or re-run its spec flow.

**Tracking:** original 02c stories stay **Done**; log removal effort against ASCA-78.
