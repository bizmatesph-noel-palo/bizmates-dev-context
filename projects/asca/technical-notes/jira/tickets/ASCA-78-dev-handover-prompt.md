# ASCA-78 — Dev Handover Prompt (02c AllocationDetail CSV removal)

> **Purpose:** paste-ready context + instructions for the assigned dev's Kiro, so their session's POV matches the authoring POV and the removal lands accurately. This is a **Change Request to a completed spec** — supersede, don't edit (see `agentic-toolkit/workflows/spec-driven-development.md` → "Change Requests to an Already-Completed Spec").
>
> **How to use:** open the accounting repo multi-root workspace (per `docs/workspace-setup.md`), check out a branch off `feature/ASCA/ASCA-master`, then paste the prompt below into a fresh Kiro session.

---

## Branch

Create the working branch off `feature/ASCA/ASCA-master`:

```
git checkout feature/ASCA/ASCA-master
git pull
git checkout -b feature/ASCA/ASCA-78-remove-02c-allocationdetail-csv
```

---

## Paste this into the dev's Kiro (one message)

```
Context load (ASCA):
Learn the agentic-toolkit and bizmates-dev-context, then read projects/asca/project-context.md, then learn the related repos: accounting_related_system_for_freee, ls-database-migrations, bizmates.jp, MBTI_backend

Task: ASCA-78 — remove the Spec 02c AllocationDetail CSV from the accounting repo. This is a Change Request to an already-completed/merged spec. Follow the toolkit's "Change Requests to an Already-Completed Spec" rule: supersede the 2c spec, do NOT edit it; the original spec/stories stay as the record of what was built.

Authoritative sources to read first (do not act from memory):
- Decision + confirmation: research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md (this is the merged 02c thread: the 11:23 AM drop decision AND the 3:01 PM confirmation carrying the Dec-1 deadline + QA-exclude)
- ADR: projects/asca/documentation/ASCA-ADR-20261020-drop-02c-allocationdetail-csv.md
- The CR ticket: projects/asca/technical-notes/jira/tickets/ASCA-78-remove-02c-allocationdetail-csv.md
- The grounded footprint trace (exact files/lines, line-number ground truth): projects/asca/technical-notes/investigation/20261023-02c-removal-footprint/REPORT-00-02c-removal-footprint.md

CRITICAL — verify before you change:
1. Do NOT `git revert` the 02c commit (4c133642). That commit also introduced KEEP code — the RowKind and OutcomeType enums now consumed by the ASCA-66 LogAllocBundleOutcome model and the 02a/02b AllocationInjector. A revert would delete surviving engine code. This is a SURGICAL removal.
2. The trace report's line numbers were captured on a branch equal to ASCA-master. Re-confirm each line/block against the live files on YOUR checkout before removing — if anything has shifted, trust the live code and the identifiers, not the stale line numbers.

Removal (surgical — per the trace report §A):
- DELETE app/Libs/RevenueAllocation/RevenueAllocationCsvService.php
- In app/Libs/DailyRateCalculationPreLogic.php: remove the AllocationDetail guarded block (the `if (LogAllocCalculationRun::hasCompletedRun(..., RunType::PREVIEW))` block) and its 3 now-orphaned imports (RunType, RevenueAllocationCsvService, LogAllocCalculationRun). KEEP CommonUtil and ZipanUtil imports.
- In app/Libs/SendJournalsDataLogic.php: remove the same AllocationDetail guarded block (RunType::FINAL) and its 3 now-orphaned imports (RevenueAllocationCsvService, RunType, LogAllocCalculationRun).
- In config/const.php: remove the `allocationDetailFile` entry (the comment line through its closing `],`). Leave the surrounding csvFile entries intact.
- In app/Models/RevenueAllocation/LogAllocCalculationRun.php: DELETE the `hasCompletedRun()` method (docblock + body). Its only callers are the two CSV sites above. KEEP the class and KEEP `scopeActiveFinal()` (that is ASCA-68's active-Final selector, a different method).
- DELETE the 16 AllocationDetail / RevenueAllocationCsv test files listed in the trace §A.1 (3 in tests/Unit/Libs, 8 in tests/Unit/RevenueAllocation, 5 in tests/Feature/RevenueAllocation). All three mixed-name tests/Unit/Libs files are WHOLLY AllocationDetail — delete whole, no edits.

Do NOT touch (KEEP):
- RowKind.php, OutcomeType.php (consumed by LogAllocBundleOutcome).
- log_alloc_bundle_outcomes / LogAllocBundleOutcome (ASCA-66).
- scopeActiveFinal(), RunStatus, RunLifecycleService, v_alloc_prorations_active (ASCA-68).
- The CAP engine (02a), refund (02b), CIP, Foundation.
- The base tests tests/Unit/Libs/DailyRateCalculationPreLogicTest.php and SendJournalsDataLogicTest.php (zero AllocationDetail entanglement — must still pass unchanged as the regression proof).
- The existing DailyRateCalculation / CalculationSummary CSVs and the ArchiverService/MailerService zip+email pipeline.

Supersede the spec (do NOT regenerate):
- Add a SUPERSEDED banner to .kiro/specs/asca-spec-02c-allocation-detail-csv/ (e.g. top of requirements.md) pointing to REF-CAP-16 / ADR-20261020. Leave the spec content as the historical record. Do not re-run the spec flow on it.

Verify (per trace §D):
- grep -rn "RevenueAllocationCsvService\|createAllocationDetailFile\|allocationDetailFile\|hasCompletedRun\|AllocationDetail" app/ config/ tests/ database/ routes/  → must return nothing.
- Confirm RowKind.php and OutcomeType.php still exist and LogAllocBundleOutcome still references them.
- vendor/bin/phpunit tests/Unit/RevenueAllocation && vendor/bin/phpunit tests/Feature/RevenueAllocation && vendor/bin/phpunit tests/Unit/Libs  → green; the two base Libs tests must pass unchanged.
- Then run the full vendor/bin/phpunit once to confirm no other suite referenced the deleted symbols.

Then open a PR referencing ASCA-78. Do NOT merge without Lead (Noel) review. Log JIRA time against ASCA-78.
```

---

## Notes for the Lead (not for the dev prompt)

- This is a **lightweight CR** per the toolkit's proportionality rule — a surgical removal, no `design.md` cycle.
- Tracking: the completed 02c stories (ASCA-53/54/56/57/58) stay **Done**; ASCA-55 (Coding) stays open as the parent of this CR; removal effort logs against **ASCA-78**.
- The `git revert` trap (RowKind/OutcomeType enums bundled into the 02c commit) is the single most important thing the dev must not miss — it's called out twice in the prompt deliberately.
