# ASCA Specs

This directory holds **dev-context spec drafts** for ASCA — authored here while they await PM sign-off (Kuroda-san, G1). On approval, each sub-spec's `requirements.md` is **promoted** to the code repo's `.kiro/specs/` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Nothing lands in the code repo unapproved.

## Where each spec lives

| Spec | Phase | Location (source of truth) |
|---|---|---|
| **Spec 01 — Foundation** | Promoted, in execution | Code repos, NOT here: `accounting_related_system_for_freee/.kiro/specs/asca-spec-01-foundation/` (engine) + `ls-database-migrations/.kiro/specs/asca-spec-01-database-migration/` (schema) |
| **Spec 02 — CAP Integration** | 4 sub-specs (02a–02d). 02a/02b Round-3 submitted for sign-off; 02c pending a schema decision; **02d repurposed to decommission `DataCorrectionCommand`** (confirmed by Kuroda-san 2026-10-05, low priority) | Here (dev-context), pending G1 sign-off + promotion — see below |

> Spec 01 is past its gates and coded from the code-repo copies; it is intentionally **not** duplicated here (its source of truth travels with the code).

## Spec 02 sub-specs (this directory)

Spec 02 (CAP Integration) is split into four independently shippable sub-specs. **Authoring order: 02a → 02b → 02c → 02d** (refund authored second to front-load its risk-carrying sign-off). Implementation order in the master-timeline Gantt is unchanged (injection W6, CSV W7, refund W8; 02d is low priority).

> **02d repurposed to decommission — confirmed by Kuroda-san (2026-10-05).** 02d was dropped at G1 (2026-09-28), retained by the Lead (2026-10-01) on a drift-risk basis, then — after Wu-san (08-28) and Harvey-san (10-05) confirmed `DataCorrectionCommand` is unused (corrections are DevOps direct SQL only, no future need) — **repurposed to disable/deprecate the command** rather than inject allocation. Kuroda-san confirmed in-thread: "02d becomes 'disable DataCorrectionCommand' only … the `allocateForCharge()` injection is no longer needed," at **low priority**. See `projects/asca/documentation/ASCA-ADR-20261005-datacorrection-decommission.md` + `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md`.

| Sub-spec | Folder | Scope | Requirements | G1 (Kuroda-san) | Promoted to code repo |
|---|---|---|---|---|---|
| **02a** CAP Core Injection | `asca-spec-02a-cap-core-injection/` | Inject `RevenueAllocationService::allocate()` into `CommonUtil::createDailyRateCalculation()` (overwrite N→P); CAP detection; failure isolation. The prerequisite spine. | ✅ Round-3 | ✅ good to go (cleanups applied) | ⏳ |
| **02b** Refund Allocation | `asca-spec-02b-refund-allocation/` | Negative-N via REF-CAP-09: true floor toward −∞, execution-month lump, cooling-off (90%)/tax-exemption/shareholder cashback, refund→bundle pairing (Req 9), atomic write. CAP-only. | ✅ Round-3 | ✅ good to go (cleanups applied) | ⏳ |
| **02c** AllocationDetail CSV | `asca-spec-02c-allocation-detail-csv/` | `allocationDetailFile` config + `RevenueAllocationCsvService`; add one file to the existing zip/email via `ArchiverService`/`MailerService`, guarded by `hasCompletedRun()`. | ✅ drafted | ⚠️ pending schema decision (skipped/failed-row source — see proposal) | ⏳ |
| **02d** DataCorrection **Decommission** | `asca-spec-02d-datacorrection-integration/` | **Disable + deprecate `DataCorrectionCommand`** (fail fast with a deprecated message). NOT an allocation injection — the command is confirmed unused. Low priority. | ✅ repurposed | ✅ confirmed (Kuroda-san 2026-10-05) | ⏳ |

Each sub-spec = its own `.kiro/specs/` folder + branch + PR + G1/G2/G3 gate set (flat naming, matching the Spec 01 precedent).

> **G1 resolution (Rounds 1–2, REF-CAP-12 + REF-CAP-13):** All four Round-1 items resolved: **02b** refund→bundle pairing (Req 9 — `log_refund_history` linkage, refunds excluded from normal grouping, new App row in the execution month, R-12 no-netting, tests i+ii); **02a** #2 mid-run failure (option b: per-pair atomic, completed-with-errors) + #3 re-run (restore N from snapshot, V-7 on restored value); **02c** #4 linking columns (charge_id + bundle/group id + row-kind). Round-2 cleanups applied to 02a/02b (now "good to go" per Kuroda-san). **02c** has one remaining schema decision (skipped/failed-row source — a dedicated `log_alloc_bundle_outcomes` table is proposed; with Kuroda-san). **CIP refunds ARE split** by a fixed per-type rule; identification resolved (REF-CIP-07 — shareholder via `trn_receipt_locked_charge`, else fixed ratio), but the **home** (extend 02b / new sub-spec / ASCI) is still **on hold** pending the scope decision.

## Dependencies (all four sub-specs)

1. **Spec 01 Foundation merged** — the engine (`allocate` / `allocateForCharge`), `log_alloc_*` / `mst_alloc_*` tables, enums, run lifecycle, reference-price seeder. Spec 02 only *calls* the engine.
2. **DEVOPS updates (6415 + 6596) in the ASCA base** — 02c rides the extracted `ArchiverService`/`MailerService`. (02d no longer injects into `DataCorrectionLogic` — it disables the command.)
   - **Requirements** (this directory) do NOT need the DEVOPS code — they are behavioral.
   - **Design/tasks** DO need the refactored files — ✅ 6415 + 6596 released to prod 2026-09-28, and **merged `main` → `feature/ASCA/ASCA-master` on 2026-10-01**, so the refactored files are now present in the ASCA base (no separate pull needed).

## Promotion checklist (per sub-spec, on G1 pass)

1. Create the spec folder in the accounting repo via the spec UI (generates a valid `.config.kiro` with a `specId`) — or hand-author `.config.kiro` as `{"specId": "<uuid>", "workflowType": "requirements-first", "specType": "feature"}` (the fix applied to Spec 01).
2. Place the approved `requirements.md` into `accounting_related_system_for_freee/.kiro/specs/<folder>/`.
3. Ensure 6415/6596 are merged into the base before "Continue to Design".
4. Use the spec UI's "Continue to Design" — not chat — for the design phase.

## References

- Authoritative schedule + split rationale: `docs/asc-projects-master-timeline.md` (Spec Overview, Phase 2)
- Technical design (sub-spec mapping + DEVOPS dependency): `projects/asca/documentation/asc-allocation-framework-technical-design.md` §1d
- Refund source (02b): `research/CAP/REF-CAP-09-Refund-Allocation-Requirements-20260908.md`
- CIP scope (out of engine): `research/CIP/REF-CIP-05-Residual-Value-Pricing-Replaces-Allocation-20260917.md`
