# ASCA ADR — Drop Spec 02c (AllocationDetail CSV)

## Document Info

| | |
|---|---|
| **Document type** | ADR (Architecture Decision Record) |
| **Date** | 2026-10-20 (Created) |
| **Author** | Noel Palo, Lead |
| **Assisted by** | Kiro |
| **Status** | Accepted |
| **Audience** | Dev team (ASCA/ASCI), PM (Kuroda-san), SDM (Patrick-san), Accounting |
| **Source** | `research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md` |

---

## Context

Spec 02c delivered a new **AllocationDetail CSV** (`RevenueAllocationCsvService` + an `allocationDetailFile` entry in `config/const.php`, added to the existing zip/email from both the Pre and Final batch logic, guarded by `hasCompletedRun()`). It was reviewed over several rounds (REF-CAP-14) and signed off (REF-CAP-15), then **coded and MERGED to `feature/ASCA/ASCA-master`** (02c Coding story ASCA-55, PR #312).

On **2026-10-19 (REF-CAP-16)**, after discussion with Accounting, Kuroda-san changed direction: the new plans' revenue is already visible in the **existing DailyRateCalculation CSV** (CAP = Option-1 overwrite amounts; CIP = residual ¥71,920 + App ¥3,980 via existing proration), and the "how was CAP allocated" breakdown will be provided by a **Metabase table on ASCA-8** instead. The dedicated AllocationDetail CSV is therefore **no longer wanted**.

## Decision

1. **Drop Spec 02c (AllocationDetail CSV) from scope.** Remove the merged 02c code, config, wiring, and tests.
2. **Vehicle: a change-request (removal task), NOT a new spec.** This mirrors the Spec 01 CR precedent (sub-tasks under the relevant story) and the 02d decommission precedent (remove merged code, no design phase). There is nothing to design; a full spec would be ceremony with no value.
3. **CR home:** a sub-task under the **02c Coding story (ASCA-55)**, parallel to how the Foundation CRs (ASCA-34/66/67/68) sit as sub-tasks under the Spec 01 Code-Review story (ASCA-18).
4. **Keep what Kuroda-san confirmed to keep:**
   - `log_alloc_bundle_outcomes` (ASCA-66) — 02a writes skip/fail outcome rows to it independent of the CSV.
   - Run-status extension (ASCA-68: `COMPLETED_WITH_ERRORS` + `v_alloc_prorations_active` / V-5 / supersede treating completed-with-errors as an active Final) — needed so Metabase shows allocated rows correctly.
5. **Metabase table + allocation-basis-amount column change are NOT ASCA-repo work** — they are a Metabase query owned under ASCA-8 (Accounting's replacement for the CSV). We acknowledge the dependency; we do not implement it.
6. **Timing:** execute the removal **after** the DEV04 command verification (ASCA-24), batched with any other code changes arising from that verification and from Kuroda-san's requirement changes, so the team does one consolidated pass rather than several.

## Removal scope (what the CR will touch — accounting repo)

- Delete `app/Libs/RevenueAllocation/RevenueAllocationCsvService.php`.
- Remove the `allocationDetailFile` entry from `config/const.php`.
- Remove the CSV wiring (the `hasCompletedRun()`-guarded `createAllocationDetailFile(...)` calls) from `app/Libs/DailyRateCalculationPreLogic.php` (Pre) and `app/Libs/SendJournalsDataLogic.php` (Final).
- Delete the 02c tests (AllocationDetail / RevenueAllocationCsv under `tests/Unit` and `tests/Feature`).
- Mark the spec folder `.kiro/specs/asca-spec-02c-allocation-detail-csv/` superseded by REF-CAP-16 (do NOT regenerate — it is already merged; just stamp superseded).

Rename/move/delete only — **no behavior change to the allocation engine, 02a/02b, ASCA-66, or ASCA-68.** Re-run the allocation test suites after removal to confirm no regression.

## Consequences

- **Positive:** removes a now-unwanted deliverable + its maintenance; the existing CSV already shows the amounts; Accounting gets a richer verification surface in Metabase.
- **Cost:** rework of already-merged, reviewed, and signed-off code (acknowledged by Kuroda-san). Caught before go-live, so the cost is a clean removal, not a production issue.
- **JIRA:** 02c epic **ASCA-52** and its non-coding stories (ASCA-53/54/56/57/58) are closed as **won't do / superseded**; the removal CR sits under ASCA-55.
- **No impact** on CAP allocation (02a), refund (02b), CIP (no engine), or the Foundation CRs.

## Alternatives considered

- **New Spec 3 for the removal** — rejected. Removal needs no requirements/design; a spec adds process without value.
- **Leave 02c merged but unused** — rejected. Dead code + a CSV Accounting explicitly does not want, shipping in every zip/email, is a liability.
- **Repurpose an existing ASCA-52 story instead of a CR sub-task** — rejected for traceability; a dedicated CR under ASCA-55 mirrors the established Spec 01 CR pattern.

## References

- Source: `research/CAP/REF-CAP-16-ASCA-Spec02c-Drop-AllocationDetail-CSV-20261019.md`
- Prior 02c sign-off (superseded): `research/CAP/REF-CAP-15-ASCA-Spec02c-SignOff-20261013.md`, `research/CAP/REF-CAP-14-ASCA-Spec02c-Review-Round3-20261013.md`
- Decommission precedent: `projects/asca/documentation/ASCA-ADR-20261005-datacorrection-decommission.md`
- Removal CR ticket: `projects/asca/technical-notes/jira/tickets/ASCA-XXX-remove-02c-allocationdetail-csv.md`
