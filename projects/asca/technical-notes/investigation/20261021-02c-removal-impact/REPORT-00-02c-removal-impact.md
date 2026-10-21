# 02c AllocationDetail CSV Removal — Impact Report (20261021)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report (impact / scope) |
| **Status** | Active |
| **Date** | 2026-10-21 (Investigated) |
| **Author / Investigator** | Noel Palo, Lead |
| **Assisted by** | Kiro (code trace) |
| **Audience** | Dev team (Cristoff/Throy), PM (Kuroda-san), SDM (Patrick-san) |
| **Environment** | `accounting_related_system_for_freee` @ `feature/ASCA/ASCA-master` (PR #313) |
| **JIRA** | CR to be created under ASCA-55 (TBA) |
| **Source** | `research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md` |

---

## 1. Summary

Kuroda-san (REF-CAP-16, 2026-10-19) dropped the Spec 02c **AllocationDetail CSV** from scope: the new plans' revenue already shows in the existing DailyRateCalculation CSV, and the CAP allocation breakdown moves to a Metabase table on ASCA-8. The 02c code was already **merged** to ASCA-master (ASCA-55/PR #312), so this is a **removal of merged code**, handled as a change-request under the 02c coding story — not a new spec.

**Footprint is small and self-contained (confirmed via code trace):** 1 service + 1 config entry + 2 guarded wiring blocks + 15 tests + 1 spec folder. **No other consumers** reference the service or config key. Removal does not touch the allocation engine, 02a/02b, ASCA-66 (`log_alloc_bundle_outcomes`), or ASCA-68 (run-status/view) — all of which REF-CAP-16 explicitly keeps.

**Confidence:** footprint confirmed by grep across `app/`, `config/`, `tests/` on ASCA-master (2026-10-21). Behavioral no-regression to be confirmed by re-running the allocation suites after removal.

---

## 2. Exact removal footprint (code trace)

| # | Item | Location | Action |
|---|---|---|---|
| 1 | CSV service | `app/Libs/RevenueAllocation/RevenueAllocationCsvService.php` | Delete file |
| 2 | Config entry | `config/const.php` → `allocationDetailFile` (L281) | Remove the entry |
| 3 | Pre wiring | `app/Libs/DailyRateCalculationPreLogic.php` — `use` L7 + guarded block L139–141 (`hasCompletedRun(..., PREVIEW)` → `createAllocationDetailFile($targetYm, true)`) | Remove import + block |
| 4 | Final wiring | `app/Libs/SendJournalsDataLogic.php` — `use` L7 + guarded block L1031–1034 (`hasCompletedRun(..., FINAL)` → `createAllocationDetailFile($targetYm, false)` + `$fileNameList[...]`) | Remove import + block |
| 5 | Tests (15) | `tests/Unit/Libs/` (3: DailyRateCalculationPreLogicCreateSendMailAttacheFileTest, SendJournalsDataLogicAllocationDetailInjectionTest, AllocationDetailGuardedInjectionCrossCuttingTest) + `tests/Unit/RevenueAllocation/` (7: AllocationDetailBomAndStorageTest, AllocationDetailReproducibilityPropertyTest, LogAllocCalculationRunHasCompletedRunTest, RevenueAllocationCsvServiceAllocatedRowsTest, RevenueAllocationCsvServiceWriteTest, CommonUtilAllocationDetailFileConfigTest, AllocationDetailLabelMapsTest, RevenueAllocationCsvServiceExceptionRowsTest) + `tests/Feature/RevenueAllocation/` (5: AllocationDetailCompletenessPropertyTest, AllocationDetailGuardPropertyTest, AllocationDetailCipExclusionPropertyTest, AllocationDetailConsistencyPropertyTest, AllocationDetailDev04SmokeTest) | Delete the AllocationDetail / RevenueAllocationCsv tests |
| 6 | Spec folder | `.kiro/specs/asca-spec-02c-allocation-detail-csv/` | Stamp superseded by REF-CAP-16 (do NOT regenerate) |

> ⚠️ Nuance on item 5: three of the Unit/Libs tests have mixed names — e.g. `LogAllocCalculationRunHasCompletedRunTest` and `DailyRateCalculationPreLogicCreateSendMailAttacheFileTest`. Confirm during removal whether each is wholly about the AllocationDetail CSV (delete) or also covers surviving behavior (edit, not delete). `hasCompletedRun()` on `LogAllocCalculationRun` was added for 02c but may be referenced by ASCA-68's view logic — verify before deleting that test/method.

**Verified no hidden consumers:** grep for `RevenueAllocationCsvService` / `allocationDetailFile` across `app/` + `config/` returns only the 4 production files above. Removal will not dangle any reference.

## 3. What is explicitly KEPT (REF-CAP-16)

- `log_alloc_bundle_outcomes` (ASCA-66) — 02a writes skip/fail outcome rows independent of the CSV.
- Run-status extension (ASCA-68: `COMPLETED_WITH_ERRORS` + `v_alloc_prorations_active` / V-5 / supersede) — Metabase needs it.
- CAP allocation engine (02a), refund (02b), CIP, Foundation — untouched.
- The existing DailyRateCalculation / CalculationSummary CSVs — unchanged (they already carry the allocated amounts).

## 4. Parallel-vs-contradiction check: REF-CAP-16 (drop 02c) vs REF-CIP-08 (CIP bundled refund)

**Finding: the two do NOT contradict and CAN be done fully in parallel. No shared files, no shared code area, different projects.**

| Axis | REF-CAP-16 (drop 02c CSV) | REF-CIP-08 (CIP bundled refund) |
|---|---|---|
| Project | ASCA (CAP) | ASCI (CIP) |
| Nature | Remove merged CSV output | Specify CIP refund per-charge behavior (not yet built) |
| Code area | `RevenueAllocationCsvService` + CSV wiring + config | CIP refund logic (future ASCI scope) |
| Allocation engine? | No | No |
| `log_alloc_*` / outcomes / run-status? | No (keeps ASCA-66/68) | No |
| Existing DailyRateCalculation CSV | Relies on it (CAP amounts already there) | Relies on it (CIP per-charge amounts already there) |

**Why they are consistent (not just non-overlapping):** both rest on the same foundation — CIP uses no engine and books real per-charge amounts (REF-CIP-05). REF-CAP-16 says CIP revenue appears in the existing CSV via existing proration; REF-CIP-08 says CIP *refunds* book per-charge the same way. They agree; REF-CIP-08 is downstream of the same model REF-CAP-16 assumes.

**Prioritization:** no dependency forces an order. They sequence by **project phase**, not by conflict:
- **02c removal → now** (ASCA, merged code to remove, part of the pre-Nov-10 cleanup; blocks nothing).
- **CIP bundled refund → later** (ASCI; not built yet; waits on ASCI G1 + the CIP-refund-home decision). Already captured in the ASCI-01 requirements draft (Req 3).

So "which to prioritize" is answered by phase: do 02c removal in the current ASCA cycle; REF-CIP-08 is already parked correctly in ASCI and does not compete for the same code.

## 5. Risk / scope assessment

- **Severity:** Low. Pure removal of a self-contained, newly-added feature; no downstream consumer.
- **Reversibility:** High (git history retains 02c if ever needed).
- **Main care point:** item 5 nuance — confirm the shared-name tests (`hasCompletedRun`, the PreLogic send-mail test) don't also cover surviving behavior before deleting; keep ASCA-68's dependence on `hasCompletedRun`/the view intact.
- **Timing:** execute AFTER DEV04 command verification (ASCA-24), batched with other post-verification changes (Lead's plan). Removing it now vs after DEV04 is harmless to the DEV04 run (the CSV just rides along until removed).

## 6. Next steps

1. This report grounds the CR. Refresh the existing CR draft (`projects/asca/technical-notes/jira/tickets/ASCA-XXX-remove-02c-allocationdetail-csv.md`) to match the exact footprint in §2.
2. Create the CR in JIRA (sub-task under ASCA-55) when ready to delegate — after DEV04 verification per the batching plan.
3. On execution: remove items 1–5, stamp the spec (item 6), re-run `tests/Unit/RevenueAllocation` + `tests/Feature/RevenueAllocation`, and grep `app/ config/ tests/` for `AllocationDetail|RevenueAllocationCsv|allocationDetailFile` = zero.

## 7. Cross-reference

- Source: `research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md`
- Decision: `projects/asca/documentation/ASCA-ADR-20261020-drop-02c-allocationdetail-csv.md`
- CR draft: `projects/asca/technical-notes/jira/tickets/ASCA-XXX-remove-02c-allocationdetail-csv.md`
- CIP refund (parallel, ASCI): `research/CIP/REF-CIP-08-Lesson-Bundled-CIP-Refund-Clarification-20261020.md`, `projects/asci/specs/asci-spec-01-cip-integration/requirements.md` (Req 3)
