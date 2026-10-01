# ASCA Specs

This directory holds **dev-context spec drafts** for ASCA — authored here while they await PM sign-off (Kuroda-san, G1). On approval, each sub-spec's `requirements.md` is **promoted** to the code repo's `.kiro/specs/` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Nothing lands in the code repo unapproved.

## Where each spec lives

| Spec | Phase | Location (source of truth) |
|---|---|---|
| **Spec 01 — Foundation** | Promoted, in execution | Code repos, NOT here: `accounting_related_system_for_freee/.kiro/specs/asca-spec-01-foundation/` (engine) + `ls-database-migrations/.kiro/specs/asca-spec-01-database-migration/` (schema) |
| **Spec 02 — CAP Integration** | G1 returned with changes (2026-09-28) — 3 sub-specs (02a–02c); 02d dropped | Here (dev-context), pending G1 resolution + promotion — see below |

> Spec 01 is past its gates and coded from the code-repo copies; it is intentionally **not** duplicated here (its source of truth travels with the code).

## Spec 02 sub-specs (this directory)

Spec 02 (CAP Integration) is split into three independently shippable sub-specs (originally four; **02d dropped at G1**, 2026-09-28, REF-CAP-12 §0 — DataCorrection fix batch outdated). **Authoring order: 02a → 02b → 02c** (refund authored second to front-load its risk-carrying sign-off). Implementation order in the master-timeline Gantt is unchanged (injection W6, CSV W7, refund W8).

| Sub-spec | Folder | Scope | Requirements | G1 (Kuroda-san) | Promoted to code repo |
|---|---|---|---|---|---|
| **02a** CAP Core Injection | `asca-spec-02a-cap-core-injection/` | Inject `RevenueAllocationService::allocate()` into `CommonUtil::createDailyRateCalculation()` (overwrite N→P); CAP detection; failure isolation. The prerequisite spine. | ✅ drafted | ⏳ pending | ⏳ |
| **02b** Refund Allocation | `asca-spec-02b-refund-allocation/` | Negative-N via REF-CAP-09: true floor toward −∞, execution-month lump, overlap/cooling-off/tax-exemption/shareholder cashback, ¥19,800 cap, atomic write. CAP-only. | ✅ drafted | ⏳ pending | ⏳ |
| **02c** AllocationDetail CSV | `asca-spec-02c-allocation-detail-csv/` | `allocationDetailFile` config + `RevenueAllocationCsvService`; add one file to the existing zip/email via `ArchiverService`/`MailerService`, guarded by `hasCompletedRun()`. | ✅ drafted | ⏳ pending | ⏳ |
| ~~**02d** DataCorrection Integration~~ | ~~`asca-spec-02d-datacorrection-integration/`~~ | **❌ DROPPED at G1 (2026-09-28, REF-CAP-12 §0)** — DataCorrection fix batch outdated. Draft archived → `archive/projects/asca/specs/asca-spec-02d-datacorrection-integration/`. | — | ❌ dropped | — |

Each sub-spec = its own `.kiro/specs/` folder + branch + PR + G1/G2/G3 gate set (flat naming, matching the Spec 01 precedent).

> **G1 outcome (2026-09-28, REF-CAP-12):** 02d dropped (above). For 02a–02c, G1 **returned with 4 items to resolve** before sign-off: **02b** CAP refund→bundle pairing (**blocker** — linkage via `log_refund_history`, 1+1 interaction, where negative P_app is written, R-12 no-netting, tests i+ii); **02a** #2 mid-run failure-state + #3 re-run vs V-7; **02c** #4 `charge_id` + bundle/group id + row-kind. **CIP refunds ARE split** by a fixed per-type rule (REF-CIP-06) but the home (extend 02b / new sub-spec / ASCI) is **on hold** pending Kuroda-san's CIP refund-type-identification answer.

## Dependencies (all three sub-specs)

1. **Spec 01 Foundation merged** — the engine (`allocate` / `allocateForCharge`), `log_alloc_*` / `mst_alloc_*` tables, enums, run lifecycle, reference-price seeder. Spec 02 only *calls* the engine.
2. **DEVOPS updates (6415 + 6596) in the ASCA base** — 02c rides the extracted `ArchiverService`/`MailerService`. (Former 02d would have injected into the refactored `DataCorrectionLogic` — dropped at G1.)
   - **Requirements** (this directory) do NOT need the DEVOPS code — they are behavioral.
   - **Design/tasks** DO need the refactored files — ✅ 6415 + 6596 released to prod together 2026-09-28, so pull from `main` (see the master timeline).

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
