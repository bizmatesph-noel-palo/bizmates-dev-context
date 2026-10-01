# ASCA Spec 02 — CAP Integration — JIRA Ticket Draft

## Document Info

| | |
|---|---|
| **Document type** | JIRA Ticket Draft |
| **Date** | 2026-09-28 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Draft — **NOT yet created in JIRA** |
| **Audience** | Dev team (Noel, Throy), Patrick-san (SDM), Kuroda-san (PM) |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) |
| **Related** | `projects/asca/documentation/asca-development-workflow.md` (JIRA structure); `projects/asca/specs/` (requirements drafts); `docs/asc-projects-master-timeline.md` (schedule) |

---

## Purpose

Draft the JIRA tickets for ASCA Spec 02 (CAP Integration), which was split into 4 sub-specs on 2026-09-23 and **reduced to 3 (02a–02c) at G1 (2026-09-28, REF-CAP-12 §0)** — 02d (DataCorrection Integration) dropped by Kuroda-san (fix batch outdated). Per the dev workflow (**1 Epic = 1 Spec**), each surviving sub-spec gets **its own epic** with the standard 6-story set. This is a **draft only** — tickets are not created in JIRA until the Lead confirms (and normally after G1 sign-off on the corresponding requirements).

**Status as of 2026-09-30:** requirements for 02a–02c drafted in `projects/asca/specs/` and submitted to Kuroda-san for **G1 review (2026-09-28)**; **G1 returned with 4 items to resolve** (REF-CAP-12) — see the per-epic notes below. **02d dropped** (draft archived under `archive/`).

## Conventions (from the dev workflow)

- **1 Epic = 1 sub-spec.** Story titles prefixed `[Spec 02x] —` so the sub-spec is identifiable from the title.
- **Standard story set (6):** Requirements + Sign-off (G1) · Architecture/Design+Tasks (G2) · Coding · Code Review (G3) · Dev/Manual Testing · QA Testing.
- **Repo:** all Spec 02 work is in `accounting_related_system_for_freee` (single repo — unlike Spec 01 which spanned two).
- **Author/gate order:** 02a → 02b → 02c. (Former 02d dropped at G1.)
- **Branch per sub-spec:** `feature/ASCA/ASCA-{story}-spec02{a,b,c}-...` targeting `feature/ASCA/ASCA-master`.

## Cross-cutting dependencies (note on every epic)

1. **Spec 01 Foundation merged** — provides the engine (`allocate` / `allocateForCharge`), `log_alloc_*` / `mst_alloc_*` tables, enums, run lifecycle, reference-price seeder. Spec 02 only *calls* the engine.
2. **DEVOPS 6415 + 6596 in the ASCA base** — 02c rides the extracted `ArchiverService`/`MailerService`. ✅ Released to prod 2026-09-28, so the refactored files are now pullable from `main` for the design/tasks phase.
3. **02a is the prerequisite** for 02b / 02c.

---

## Epic 1 — [Spec 02a] — CAP Core Injection

**Requirements draft:** `projects/asca/specs/asca-spec-02a-cap-core-injection/requirements.md`
**Scope:** Inject `RevenueAllocationService::allocate()` into `CommonUtil::createDailyRateCalculation()` (Option 1 overwrite N→P, step [b] between existing [a]/[c]), CAP detection (plans 1016–1027), try/catch failure isolation. Covers Pre + Final. The prerequisite spine.

| Story | Assignee | Gate |
|---|---|---|
| [Spec 02a] — Requirements + Sign-off | PM (Kuroda-san) | G1 |
| [Spec 02a] — Architecture (Design + Tasks) | Lead (Noel) | G2 |
| [Spec 02a] — Coding | Dev (Throy) | — |
| [Spec 02a] — Code Review | Lead (Noel) | G3 |
| [Spec 02a] — Dev/Manual Testing | Lead (Noel) | — |
| [Spec 02a] — QA Testing | QA (Miko) | — |

**Notes:** Open item O-A (App Freee-mapping rows — `mst_code_change` / `mst_rule_for_journals` for App product_type) to verify before go-live — data, not code. **G1 items to resolve (REF-CAP-12):** #2 mid-run failure state — pick (a) whole-run transaction rollback vs (b) per-pair atomic + completed-with-errors + failed-pair list; #3 re-run idempotency vs V-7 — restore N from `log_alloc_prorations.original_paid_price` before recompute, or apply V-7 to pre-allocation values only (+ add a "re-run an already-allocated month" acceptance test). Also remove the former Req 5.4 / 02d references (02d dropped).

---

## Epic 2 — [Spec 02b] — Refund Allocation

**Requirements draft:** `projects/asca/specs/asca-spec-02b-refund-allocation/requirements.md`
**Scope:** Negative-N via REF-CAP-09 — same pipeline, true floor toward −∞, execution-month lump (no spread-back), fixed/capped + overlap + shareholder scenarios, ¥19,800 coaching cap, atomic Coaching+App write. CAP-only (CIP uses no engine).

| Story | Assignee | Gate |
|---|---|---|
| [Spec 02b] — Requirements + Sign-off | PM (Kuroda-san) | G1 |
| [Spec 02b] — Architecture (Design + Tasks) | Lead (Noel) | G2 |
| [Spec 02b] — Coding | Dev (Throy) | — |
| [Spec 02b] — Code Review | Lead (Noel) | G3 |
| [Spec 02b] — Dev/Manual Testing | Lead (Noel) | — |
| [Spec 02b] — QA Testing | QA (Miko) | — |

**Notes:** Risk-carrying sub-spec. Flag REF-CAP-09 open items on the Requirements story: shareholder cap under executive discussion (proceed with ¥19,800), tax-exemption calc path (O-R3), cooling-off original-charge recognition (O-R2, Engineering/Miyaji-san). Depends on 02a. **G1 blocker (REF-CAP-12 #1):** CAP refund charges won't pair with the App row (a refund clone shares start/end date but breaks the "1 coaching + 1 app" check both when the contract still covers the execution month and when it doesn't), so refunds never allocate. The spec must define: ① refund↔original linkage (via `log_refund_history`), ② the 1+1 interaction, ③ **where the negative P_app is written (open design decision)**, ④ N per charge with +/− never netted (R-12); add acceptance tests for the same-month (i) and later-month (ii) cases. **CIP refunds ARE split** by a fixed per-type rule (REF-CIP-06) but whether that lives here (currently CAP-only), in a new sub-spec, or in ASCI is **on hold** pending Kuroda-san's CIP refund-type-identification answer.

---

## Epic 3 — [Spec 02c] — AllocationDetail CSV

**Requirements draft:** `projects/asca/specs/asca-spec-02c-allocation-detail-csv/requirements.md`
**Scope:** `allocationDetailFile` config in `config/const.php` + `RevenueAllocationCsvService::createAllocationDetailFile()`; add one file to `$fileNameList` via the extracted `ArchiverService`/`MailerService`, guarded by `hasCompletedRun()`. No new email/mail template. Reporting only.

| Story | Assignee | Gate |
|---|---|---|
| [Spec 02c] — Requirements + Sign-off | PM (Kuroda-san) | G1 |
| [Spec 02c] — Architecture (Design + Tasks) | Lead (Noel) | G2 |
| [Spec 02c] — Coding | Dev (Throy) | — |
| [Spec 02c] — Code Review | Lead (Noel) | G3 |
| [Spec 02c] — Dev/Manual Testing | Lead (Noel) | — |
| [Spec 02c] — QA Testing | QA (Miko) | — |

**Notes:** Depends on 02a + DEVOPS-6415 (ArchiverService/MailerService). Open items: column-set completeness (O-C1), filename sequence `10` collision (O-C2), Pre-vs-Final content (O-C3). **G1 item (REF-CAP-12 #4):** the 15 columns can't link a bundle's coaching and App rows (most CAP bundles have `order_no` NULL, paired by start/end date, and a student can have >1 bundle/month) — add `charge_id`, a bundle/group ID, and a row kind (normal/refund) so rows are matchable against DailyRateCalculation.csv and P is recomputable. Smaller items pending from Kuroda-san: Pre/Final-specific CSV guard, per-row status incl. skipped bundles, tax labels in headers.

---

## Epic 4 — [Spec 02d] — DataCorrection Integration — ❌ DROPPED at G1 (2026-09-28, REF-CAP-12 §0)

> **DROPPED.** Kuroda-san dropped 02d at G1 review (2026-09-28) — "since this fix batch has been outdated I think we don't need to handle this." **Do NOT create this epic.** The requirements draft has been archived under `archive/projects/asca/specs/asca-spec-02d-datacorrection-integration/`. The 02a Req 5.4 reference to 02d was removed. Section retained below for the decision trail.

**Requirements draft (archived):** `archive/projects/asca/specs/asca-spec-02d-datacorrection-integration/requirements.md`
**Scope (dropped):** Scoped `allocateForCharge()` after the `addDaily` INSERT in the private `DataCorrectionLogic::createDailyRateCalculation()`; CAP-only (non-Zipan branch), try/catch isolation. Smallest sub-spec (one call site).

| Story | Assignee | Gate |
|---|---|---|
| [Spec 02d] — Requirements + Sign-off | PM (Kuroda-san) | G1 |
| [Spec 02d] — Architecture (Design + Tasks) | Lead (Noel) | G2 |
| [Spec 02d] — Coding | Dev (Throy) | — |
| [Spec 02d] — Code Review | Lead (Noel) | G3 |
| [Spec 02d] — Dev/Manual Testing | Lead (Noel) | — |
| [Spec 02d] — QA Testing | QA (Miko) | — |

**Notes:** Depends on 02a + DEVOPS-6415 (refactored DataCorrectionLogic, incl. the drift fix). Open items: injection point vs the refactored file (O-D1), `$targetYm` derivation for multi-month charges (O-D2), DataCorrection-retirement note (O-D3 — does not reduce scope).

---

## Creation checklist (when Lead approves — after G1)

- [ ] Confirm with Lead/PM that tickets should be created (this doc is draft-only).
- [ ] Resolve the G1 items (REF-CAP-12) before creating: 02b refund→bundle pairing (blocker), 02a failure-state + re-run/V-7, 02c linking columns.
- [ ] Create **3 epics** (02a, 02b, 02c) in ASCA with the titles above. **Do NOT create 02d (dropped).**
- [ ] Under each epic, create the 6 stories with the `[Spec 02x] —` prefix and assignees.
- [ ] Link each epic to its requirements draft in `projects/asca/specs/`.
- [ ] Record the created keys back into this doc and the master timeline.
- [ ] Order sign-offs 02a → 02b → 02c.

> **Do not create in JIRA without explicit Lead confirmation.** MCP Jira writes are gated per the toolkit workflow.
