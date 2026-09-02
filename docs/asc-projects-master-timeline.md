# ASC Projects — Master Timeline

## Document Info

| | |
|---|---|
| **Document type** | Project Timeline |
| **Date** | 2026-08-10 (Created) · 2026-08-20 (Consolidated — single authoritative timeline) · 2026-08-26 (Added Phase 0.5: Spec Preparation) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro (AI-assisted timeline consolidation and document generation) |
| **Status** | Active |
| **Audience** | Dev team (Noel, Throy, Orlino, Cristoff), Patrick-san (SDM), Kuroda-san (PM), QA Team |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) · [ASCI](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) · [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) |
| **Supersedes** | `projects/asca/documentation/asc-alloc-scenario-d-injection-timeline-20260811.md` (timeline content), `docs/asc-cap-cip-combined-estimate-20260808.md` (Scenario C estimate) |

---

**Deadline:** ASCA + ASCI = 2026/12/17  
**Start date:** Aug 24, 2026 (Monday) — per Kuroda-san's ASAP directive.  
**Work schedule:** Mon–Fri only. PH holidays skipped. No weekend work.

### JIRA Projects

| Code | Project | Board | Backlog |
|---|---|---|---|
| ASC | ASCM (Accounting System Changes — Monthly) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASC/boards/1186/backlog) |
| ASCH | ASC Honki Set (cancelled) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/boards/1753/backlog) |
| **ASCA** | **ASC for CAP** (active — builds foundation) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog) |
| **ASCI** | **ASC for CIP** (active — reuses foundation) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog) |

**Note:** "ASC" is the JIRA code for ASCM. The original project was named just "ASC" before subsequent projects (ASCH, ASCA, ASCI) were created.

---

## Overview

```
ASCH (Honki Set):                    Jul 30 ═══ Aug 7 ╳ CANCELLED
ASCM Refactor (DEVOPS-6415):         Aug 24–28 (W0) — prep + regression
Spec Preparation (Lead):             Aug 31–Sep 5 (W1) — steering files + spec session (parallel with QA)
ASCM QA Verification:                Aug 31–Sep 5 (W1) — gate to Foundation
ASCA (Foundation + CAP Integration): Sep 7–Oct 30 (W2–W9) — shared framework + CAP logic
ASCI (CIP Integration):              Nov 2–13 (W10–W11) — plugs CIP into working framework
QA (overlapping):                    Oct 5–Dec 11 (W6–W15) — planning, execution, regression
Buffer:                              Nov 16–Dec 11 (W12–W15) — absorbed into QA schedule
Upstream CAP (Keith's team):         In progress ════════════════════ Late Nov / Early Dec
Upstream CIP (Jefferson's team):     In progress ════════════════════ Late Nov / Early Dec
Production deadline:                 Dec 17
First real batch:                    Jan 1, 2027
```

**What we're building:** A shared allocation framework that splits Coaching charge revenue between Coaching and App products, injected into the existing accounting batch commands.

**Architecture:** Scenario D (injection into existing commands) + Option 1 (Overwrite N→P). Single injection point in `CommonUtil::createDailyRateCalculation()`. Shared `log_alloc_*` tables with `project_code` column.

**Technical design:** `projects/asca/documentation/asc-allocation-framework-technical-design.md` (authoritative)

---

## Terminology

| Term | Full Name | What it is | Owner |
|---|---|---|---|
| **CAP** | Coaching and App Plan | Upstream project — creates new plans 1016–1027 in MBTI_backend | CAP team (Keith, Terry) |
| **CIP** | Coaching Intensive Plan | Upstream project — creates new product **10025** with plans 1028–1032 in MBTI_backend | CIP team (Jefferson) |
| **ASCA** | ASC for CAP | Our project — allocates CAP coaching charge revenue | Noel's team |
| **ASCI** | ASC for CIP | Our project — allocates CIP coaching charge revenue | Noel's team |

**The upstream projects create the charges. Our projects allocate the revenue.**

---

## People & Roles

**Management Partners (JP ↔ PH):**

| Japan (JP) | Philippines (PH) | Scope |
|---|---|---|
| Hayato Kuroda (PM) | Roi Patrick Florentino (SDM) | ASC / Accounting projects |
| Soli Sahukar (PM) | Jasser Balido (SDM) | CAP / CIP upstream projects |

**Development Teams:**

| Project | Lead | Sub-Lead | Developer(s) | SDM |
|---|---|---|---|---|
| **CAP** (upstream) | Keith Manuntag | — | Terry Balahadia | Jasser-san |
| **CIP** (upstream) | Jefferson Gernale | — | Haggai Rei Cacacho | Jasser-san |
| **ASCA** (first) | Noel Palo | — | Throy Embudo | Patrick-san |
| **ASCI** (second) | Noel Palo | Orlino Monares | Cristoff Danganan | Patrick-san |
| **CDB** (upstream) | Paolo Sandoval | — | Efren Petarte | Patrick-san |
| **ASCM** (completed) | Noel Palo | — | Team (deployed Jun 2026) | Patrick-san |
| **ASCH** (cancelled) | Noel Palo | — | — | Patrick-san |

**QA Team Assignments:**

| Phase | QA Owner | Scope |
|---|---|---|
| ASCM Refactor verification | QA Team | Manual report comparison |
| ASCA CAP scenarios (10 cases) | Miko | CAP allocation testing |
| ASCI CIP scenarios (11 cases) | Glenn | CIP allocation testing |
| Integration + Regression | QA Team (both) | Cross-project, failure isolation |

---

## Current Approach (Scenario D + Option 1)

| Decision | Chosen | Why |
|---|---|---|
| Architecture | Scenario D — inject into existing commands | Saves ~3 weeks vs standalone. Proven pattern (monthly rate). Same email/zip. |
| Timing | Option 1 — Overwrite N→P inside CommonUtil | 1 Freee API call. Zero downstream changes. Idempotent. |
| Injection point | `CommonUtil::createDailyRateCalculation()` | Covers Pre, Final, and DataCorrection batches. |
| N definition | Σ(paid_price) across bundle (coaching + app) | Idempotent by construction — safe on re-runs. |
| Bundle grouping | student_id + order_no | Handles cancel+repurchase, simultaneous plans. |
| Detection | product_id 10022 (App, new id) + plan_id enums | Anchor on App id. Works for both CAP and CIP. (App id changed 10021→10022 on 2026-08-19) |
| Execution order | ASC-CAP first → ASC-CIP second | CAP requirements more concrete. CIP reuses foundation. |

### Why Scenario D Over Scenario C

| Saved effort | Days saved | Reason |
|---|---|---|
| No unified email orchestrator | 5 days | Uses existing email. CSVs added to existing zip. |
| No dedicated Freee thin sender | 4 days | Option 1 Overwrite — single Freee API call. |
| No command skeleton / cron setup | 2 days | No new commands. Injection into existing ones. |
| No zip/archive infrastructure | 2 days | Existing `createSendMailAttacheFile()` handles it. |
| Simpler testing (E2E = run existing command) | 3 days | No separate command integration tests needed. |
| **Total saved** | **~16 days (~3 weeks)** | |

---

## Implementation Phases — Detailed

### Phase 0: ASCM Refactor (DEVOPS-6415) — W0, Aug 24–28 (3–5 days)

**Billed under:** [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) (maintenance). Linked to ASCA via [ASCA-7](https://bizmates.atlassian.net/browse/ASCA-7).

Scope: Refactoring and fixing EXISTING code only. No new features, no new tables.

| # | Category | Owner | Task | Detail |
|---|---|---|---|---|
| 1 | **Fix** | Lead | Fix DataCorrectionLogic drift | Add `BizmatesMonthlyPlanEnum::exists()` skip at top of `createDailyRateCalculation()`. Add missing `$condition` fields: `tax_free`, `country_id`, `gross_amount`. |
| 2 | **Extract** | Lead | Extract zip into ArchiverService | Move `ZipArchive` creation + file cleanup into `ArchiverService::create($fileNameList, $suffix)`. |
| 3 | **Extract** | Lead | Extract email into MailerService | Move email dispatch into `MailerService::send($zipFilePath, $fileNameList, $mailType)`. |
| 4 | **Refactor** | Lead | Update 3 Logic files to call services | Replace inline zip+email with `app(ArchiverService::class)->create(...)` + `app(MailerService::class)->send(...)`. |
| 5 | **Test** | Lead | Unit test ArchiverService + MailerService | Zip creation, file cleanup, email dispatch tested in isolation. |
| 6 | **Test** | Lead | Verify DataCorrectionLogic fix via smoke test | Run DataCorrection on DEV04 to confirm monthly plans skipped + fields present. |
| 7 | **Verify** | Lead | Run Pre + Final + Correction commands on DEV04 | Check: no runtime errors, reports generated, email dispatch logged. |
| 8 | **Verify** | Lead | Collect generated reports/CSVs | Hand off to QA Team for manual verification. |
| 9 | **Verify** | QA Team | Manual verification of generated reports | Compare against known-good baseline. Confirm no regression. |

**NOT in DEVOPS-6415:** DB migrations, models, allocation service, test data seeder, reference prices — those are ASCA Spec 01.

**Deliverables:**
- `ArchiverService` class (zip creation + file cleanup)
- `MailerService` class (email dispatch)
- DataCorrectionLogic aligned with CommonUtil (skip + fields)
- Baseline documentation (CSV list, smoke test results)
- All 3 commands verified working on DEV04 after changes
- QA manual verification sign-off

---

### Phase 0.5: Spec Preparation — W1, Aug 31–Sep 5 (4 days, parallel with QA gate)

**Billed under:** [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog)

**Purpose:** While QA verifies ASCM Refactor reports, Lead prepares the Foundation phase for immediate execution on W2 Day 1. This eliminates a week of idle dev time and ensures Throy (Dev 1) has a clear task list when Foundation begins.

**Prerequisite chain:** Steering files must exist before the spec session can produce correct, convention-aligned output. The spec session (requirements → design → tasks) uses steering rules to enforce naming, file placement, and architecture decisions.

| # | Category | Owner | Task | Detail |
|---|---|---|---|---|
| 1 | **Steering** | Lead | Create `accounting_related_system_for_freee/.kiro/steering/` files | Codify patterns from technical design: file structure (`AscAlloc/` dirs), naming conventions, enum pattern (int-backed + `HasEnumHelperTrait`), log prefix `[ASC_ALLOC]`, error handling (3-transaction model), testing expectations. Scoped to new `AscAlloc` code only — existing code untouched. |
| 2 | **Spec** | Lead | ASCA Spec 01: requirements.md | Formalize Foundation requirements from the technical design doc. Covers: DB schema (10 tables + 1 view), models, enums, allocation service, run lifecycle, reference prices, test data seeder. |
| 3 | **Gate 1** | PM | Requirements sign-off | Kuroda-san approves scope, allocation formula, reference prices, plan detection before design begins. |
| 4 | **Spec** | Lead | ASCA Spec 01: design.md | Technical design decisions specific to implementation — class responsibilities, method signatures, injection points, validation invariants, DTO shapes (if needed). References the authoritative technical design doc. Starts after G1 pass (can spill into early W2). |
| 5 | **Spec** | Lead | ASCA Spec 01: tasks.md | Executable task list derived from design. Each task scoped to a single PR, with clear acceptance criteria. Maps to Gantt steps in Phase 1. |
| 6 | **Gate 2** | Lead + Dev | Design & tasks approval | Lead reviews with Throy — confirm architecture is sound and tasks are clear before execution begins. |

**Dependency:** Step 1 (steering files) must complete before Steps 2–6 (spec session). The spec session runs with steering loaded to ensure generated artifacts follow the conventions. G1 (PM sign-off on requirements) must pass before design begins. G2 (Lead + Dev approval) must pass before task execution.

**Deliverables:**
- Steering files in `accounting_related_system_for_freee/.kiro/steering/`
- `requirements.md` — ASCA Foundation requirements (submitted for G1)
- G1 pass — PM approves requirements
- `design.md` — implementation design decisions (after G1)
- `tasks.md` — executable task list for W2+ (after G1)
- G2 pass — Lead + Dev confirm tasks are ready for execution

**Why this matters:**
- Throy starts W2 with a ready task list (no "what do I build?" delay)
- Steering files ensure all W2+ code follows consistent patterns from Day 1
- Spec documents serve as the single reference for PR reviews during Foundation
- QA gate runs in parallel — no dev idle time wasted

---

### Phase 1: ASC Shared Foundation — W2–W5 (Sep 7 – Oct 2)

**Billed under:** [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog)

Scope: New DB tables, models, enums, services. The shared infrastructure that both ASCA and ASCI use.

| Step | What | Owner | Effort | Blocked by |
|---|---|---|---|---|
| 1 | 10 migrations + 1 view + structure tests (`log_alloc_*`) | Dev 1 | 1 week | ✅ None |
| 2 | Models / enums / run lifecycle service | Lead | 3–4 days | None |
| 3 | Reference-price master + price resolution + seeder | Lead | 2–3 days | None |
| 4 | Detection strategy + bundle generation | Dev 1 | 3–4 days | None |
| 5 | Allocation engine + ΣN computation + validations V-1 to V-5 | Dev 1 | 4–5 days | None |
| 6 | Test data seeder (mock CAP/CIP charges for DEV04) | Lead | 1 day | None |

**DB Schema (Step 1 deliverable — 10 tables + 1 view):**

| # | Table | Prefix | Role |
|---|---|---|---|
| 1 | `log_alloc_calculation_runs` | `log_*` | Run lifecycle (status, timing, error messages) |
| 2 | `log_alloc_source_documents` | `log_*` | Immutable input snapshots (original N before overwrite) |
| 3 | `log_alloc_bundles` | `log_*` | Bundle header (primary_charge_id, match_rule) |
| 4 | `log_alloc_bundle_charges` | `log_*` | Products per bundle (always 2 today) |
| 5 | `log_alloc_groups` | `log_*` | One bundle × one month (ΣN, ΣP, is_balanced) |
| 6 | `log_alloc_prorations` | `log_*` | Core: one row per product per group (L, ratio, N, P) |
| 7 | `mst_alloc_reference_prices` | `mst_*` | Allocation weights (effective-dated) — master data |
| 8 | `log_alloc_sum_calculation` | `log_*` | Freee aggregation |
| 9 | `log_alloc_sum_calculation_history` | `log_*` | Trace: summary → allocation rows |
| 10 | `log_alloc_deliveries` | `log_*` | Freee/CSV/email attempt tracking |
| 11 | `v_alloc_prorations_active` | `v_*` | View for active-run queries |

---

### Phase 2: ASCA CAP Integration — W6–W9 (Oct 5 – Oct 30)

**Billed under:** [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog)

**Spec:** ASCA Spec 02 — CAP Integration ⚠️ (may split into 2–4 smaller specs during requirements generation; see Spec Overview note)

**Prerequisite:** Phase 1 Foundation complete (G3 passed — all Foundation PRs merged).

| # | Category | Owner | Task | Detail |
|---|---|---|---|---|
| 1 | **Spec** | Lead | ASCA Spec 02: requirements.md | Formalize CAP injection requirements — CommonUtil overwrite, detection strategy, AllocationDetail CSV format, DataCorrectionLogic scoped allocation, refund handling. Written during W5 (overlaps with Foundation completion). |
| 2 | **Gate 1** | PM | Requirements sign-off | Kuroda-san approves CAP injection scope, CSV format, refund handling rules. |
| 3 | **Spec** | Lead | ASCA Spec 02: design.md + tasks.md | Implementation plan — injection point, detection query, CSV columns, refund sign-flip logic. If scope splits, each sub-spec gets its own design + tasks. |
| 4 | **Gate 2** | Lead + Dev | Design & tasks approval | Lead reviews with Dev — confirm task list is executable. |
| 5 | **Execute** | Lead | Injection into CommonUtil (Option 1 Overwrite) | ~2 days |
| 6 | **Execute** | Dev 1 | CAP Detection Strategy + bundle generation | Included with injection |
| 7 | **Execute** | Lead | AllocationDetail CSV generation + config | ~2–3 days |
| 8 | **Execute** | Dev 1 | DataCorrectionLogic: add `allocateForCharge()` call | ~1 day |
| 9 | **Execute** | Lead + Dev 1 | Refund allocation (record_kind = 1) | ~3–4 days |
| 10 | **Gate 3** | Lead | Code review — CAP Integration PRs | PR approved before merge. |
| 11 | **Verify** | Lead + Dev 1 | ASCA dev testing on DEV04 (full pipeline Pre + Final) | ~2–3 days |

---

### Phase 3: ASCI CIP Integration — W10–W11 (Nov 2 – Nov 13)

**Billed under:** [ASCI](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog)

**Spec:** ASCI Spec 01 — CIP Integration ⚠️ (may split if CIP introduces edge cases not present in CAP)

**Prerequisite:** Phase 2 CAP Integration complete (G3 passed) — proves the allocation engine works end-to-end with real injection.

| # | Category | Owner | Task | Detail |
|---|---|---|---|---|
| 1 | **Spec** | Lead | ASCI Spec 01: requirements.md | Formalize CIP requirements — plans 1028–1032 detection, product **10025**, L_coaching (🔴 pending O-5 re-confirm). Split confirmed 2-way (O-8). Written during W9. |
| 2 | **Gate 1** | PM | Requirements sign-off | Kuroda-san approves CIP plan detection and reference price (pending O-5). Split arity already confirmed 2-way. |
| 3 | **Spec** | Lead | ASCI Spec 01: design.md + tasks.md | Implementation plan — CIP enum, reference price seeder row, detection query addition. Minimal design since it reuses ASCA engine. |
| 4 | **Gate 2** | Lead + Dev | Design & tasks approval | Lead reviews with Dev 2 (Orlino/Cristoff) — confirm scope is config-only addition. |
| 5 | **Execute** | Dev 2 | CIP Detection Strategy (`CoachingIntensivePlanEnum`: 1028–1032) + reference price config | ~3–5 days |
| 6 | **Gate 3** | Lead | Code review — CIP Integration PRs | PR approved before merge. |
| 7 | **Verify** | Lead | ASCI dev testing on DEV04 | ~1–2 days |

---

### Phase 4: Post-Release — W12+ (Nov 16+)

| Step | What | Priority |
|---|---|---|
| 16 | Reversal (record_kind = 2) | Ships after first prod run — not on critical path |
| 17 | Metabase saved query for Accounting (allocation breakdown) | Post-deployment |

---

## Development Gantt

```
                          Aug    Sep         Oct              Nov         Dec
                          24     |           |                |           17
Upstream:                 ║══════════════════════════════════════════════║
  CAP project             ║━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━║→ Prod late Nov
  CIP project             ║━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━║→ Prod late Nov

Dev Team:                 ║══════════════════════════════════════════════║
  ASCM Refactor           ║■■■■┓                                        ║
  Spec Prep (Lead)             ┣■┓                                      ║
  QA Verification              ┣■┓                                      ║
  Foundation                     ┣━━━━━━━━━━━━━━━━┓                     ║
  ASCA CAP Integration                            ┣━━━━━━━━━━━━━━━━┓    ║
  ASCI CIP Integration                                              ┣━━━┓║
  QA (CAP scenarios)                          ┣━━━━━━━━━━━━━━━━━━━━━━━━━║
  QA (CIP scenarios)                                            ┣━━━━━━━║
  Regression + Sign-off                                              ┣━━║
                                                                     Dec 17
```

### Detailed Dev Gantt (Week by Week)

**Spec Overview:**

| Spec | Full Name | What it delivers |
|---|---|---|
| **ASCA Spec 01** | Foundation | New DB tables (`log_alloc_*`, `mst_alloc_*`), Eloquent models, plan detection enums, allocation engine (formula + idempotency), run lifecycle service, reference price seeder, test data seeder |
| **ASCA Spec 02** | CAP Integration ⚠️ | Injection into `CommonUtil::createDailyRateCalculation()` (overwrite N→P), CAP bundle detection (plans 1016–1027), AllocationDetail CSV for Accounting, `allocateForCharge()` in DataCorrectionLogic, refund allocation |
| **ASCI Spec 01** | CIP Integration | CIP bundle detection (plans 1028–1032, product **10025**), CIP reference prices (L_coaching 🔴 pending O-5). Config-only addition — 2-way split confirmed (O-8), same as CAP. |

> ⚠️ **Spec sizing note (ASCA Spec 02 and ASCI Spec 01):**
>
> The scope listed above is preliminary grouping based on the technical design. Per spec-driven development standards, each spec targets 5–15 tasks and a design document of 1–3 pages. If a spec exceeds these thresholds during requirements generation, it will be split into smaller, independently shippable specs.
>
> **ASCA Spec 02** is the most likely candidate for splitting. It covers 4 distinct concerns (injection, CSV, refund, DataCorrection) across 4 weeks. Probable split:
> - Spec 02a: CAP Core Injection (CommonUtil + detection + overwrite)
> - Spec 02b: AllocationDetail CSV (reporting layer)
> - Spec 02c: Refund Allocation (record_kind = 1)
> - Spec 02d: DataCorrection Integration (`allocateForCharge()`)
>
> **ASCI Spec 01** may remain as-is (config-only addition to existing engine) or split if CIP introduces edge cases not present in CAP (e.g., different bundle structure, multi-product detection).
>
> **Impact on timeline:** Splitting does not change the W6–W9 / W10–W11 time allocation — it changes the number of G1 sign-offs Kuroda-san receives during those weeks. Final spec boundaries will be determined when requirements are written (W5 for ASCA Spec 02, W9 for ASCI Spec 01).

| Category | Owner | Task | W0 (Aug 24) | W1 (Aug 31)🔴 | W2 (Sep 7) | W3 (Sep 14) | W4 (Sep 21) | W5 (Sep 28) | W6 (Oct 5) | W7 (Oct 12) | W8 (Oct 19) | W9 (Oct 26) | W10 (Nov 2)🔴 | W11 (Nov 9) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **ASCM Refactor** | Lead | Fix DataCorrectionLogic drift | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Extract ArchiverService + MailerService (from 3 files) | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Unit test extracted services | ■ | | | | | | | | | | | |
| **ASCM Regression** | Lead | Smoke test Pre + Final + Correction on DEV04 | ■ | | | | | | | | | | | |
| **ASCM Regression** | QA Team | Manual verification: compare reports | | ■ | | | | | | | | | | |
| ══ **GATE** ══ | QA Team | **ASCM Regression gate pass** | | ■ | | | | | | | | | | |
| **Spec Prep** | Lead | Create steering files for `accounting_related_system_for_freee` | | ■ | | | | | | | | | | |
| **Spec Prep** | Lead | ASCA Spec 01 (Foundation): requirements.md | | ■ | | | | | | | | | | |
| ══ **GATE 1** ══ | PM | **Requirements sign-off — Foundation scope, formula, reference prices** | | ■ | | | | | | | | | | |
| **Spec Prep** | Lead | ASCA Spec 01 (Foundation): design.md + tasks.md | | | ■ | | | | | | | | | |
| ══ **GATE 2** ══ | Lead + Dev | **Design & tasks approval — Foundation architecture + task list** | | | ■ | | | | | | | | | |
| **Foundation** | Dev 1 | DB migrations (10 tables + 1 view) + structure tests | | | ■ | ■ | | | | | | | | |
| **Foundation** | Lead | Models / enums / run lifecycle service | | | | ■ | | | | | | | | |
| **Foundation** | Lead | Reference-price master + price resolution + seeder | | | | | ■ | | | | | | | |
| **Foundation** | Dev 1 | Allocation engine + ΣN computation + validations | | | | | ■ | ■ | | | | | | |
| **Foundation** | Lead | Test data seeder (mock CAP/CIP charges) | | | | | | ■ | | | | | | |
| ══ **GATE 3** ══ | Lead | **Code review — Foundation PRs (DB + models + engine)** | | | | | | ■ | | | | | | |
| **Spec Prep** | Lead | ASCA Spec 02 (CAP Integration): requirements.md → design.md → tasks.md | | | | | | ■ | | | | | | |
| ══ **GATE 1** ══ | PM | **Requirements sign-off — CAP injection scope, CSV format, refund handling** | | | | | | ■ | | | | | | |
| ══ **GATE 2** ══ | Lead + Dev | **Design & tasks approval — CAP integration task list** | | | | | | ■ | | | | | | |
| **ASCA Integration** | Lead | Injection into CommonUtil (Option 1 Overwrite) | | | | | | | ■ | | | | | |
| **ASCA Integration** | Dev 1 | CAP Detection Strategy + bundle generation | | | | | | | ■ | | | | | |
| **ASCA Integration** | Lead | AllocationDetail CSV generation + config | | | | | | | | ■ | | | | |
| **ASCA Integration** | Dev 1 | DataCorrectionLogic: add `allocateForCharge()` | | | | | | | | ■ | | | | |
| **ASCA Integration** | Lead + Dev 1 | Refund allocation (record_kind = 1) | | | | | | | | | ■ | | | |
| ══ **GATE 3** ══ | Lead | **Code review — CAP Integration PRs (injection + CSV + refund)** | | | | | | | | | ■ | | | |
| **ASCA Integration** | Lead + Dev 1 | ASCA dev testing on DEV04 (full pipeline) | | | | | | | | | | ■ | | |
| **Spec Prep** | Lead | ASCI Spec 01 (CIP Integration): requirements.md → design.md → tasks.md | | | | | | | | | | ■ | | |
| ══ **GATE 1** ══ | PM | **Requirements sign-off — CIP plans 1028–1032, product 10025, L_coaching (O-5) + split arity (O-8)** | | | | | | | | | | ■ | | |
| ══ **GATE 2** ══ | Lead + Dev | **Design & tasks approval — CIP detection strategy + config** | | | | | | | | | | ■ | | |
| **ASCI Integration** | Dev 2 | CIP Detection Strategy + reference prices | | | | | | | | | | | ■ | ■ |
| ══ **GATE 3** ══ | Lead | **Code review — CIP Integration PRs (detection + config)** | | | | | | | | | | | | ■ |
| **ASCI Integration** | Lead | ASCI dev testing on DEV04 | | | | | | | | | | | | ■ |

🔴 = week with PH holiday (1 lost workday): W1 = National Heroes Day (Aug 31), W10 = All Souls' Day (Nov 2)

**Gate legend:**
- **GATE 1** = PM requirements sign-off (Kuroda-san approves scope before design begins)
- **GATE 2** = Lead + Dev design/tasks approval (architecture confirmed, Dev understands scope before coding)
- **GATE 3** = Lead code review (PR approved before merge)
- **Regression gate** = QA confirms no regression from refactor (blocks Foundation start)

---

## QA Gantt

| Category | Owner | Task | W1 (Aug 31) | W2 (Sep 7) | W3 (Sep 14) | W4 (Sep 21) | W5 (Sep 28) | W6 (Oct 5) | W7 (Oct 12) | W8 (Oct 19) | W9 (Oct 26) | W10 (Nov 2)🔴 | W11 (Nov 9) | W12 (Nov 16) | W13 (Nov 23) | W14 (Nov 30)🔴 | W15 (Dec 7)🔴 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| QA | QA Team | ASCM Refactor: Manual report verification | ■ | | | | | | | | | | | | | | |
| QA | QA Team | Test planning + strategy | | ■ | ■ | | | | | | | | | | | | |
| QA | QA Team | Test case creation + data prep (CAP + CIP) | | | ■ | ■ | ■ | | | | | | | | | | |
| QA | Miko | Test execution: ASCA CAP scenarios (10 cases) | | | | | | | ■ | ■ | ■ | ■ | | | | | |
| QA | Glenn | Test execution: ASCI CIP scenarios (11 cases) | | | | | | | | | | | ■ | ■ | | | |
| QA | QA Team | Integration testing (cross-project, failure isolation) | | | | | | | | | | | | | ■ | ■ | |
| QA | QA Team | Regression testing | | | | | | | | | | | | | | | ■ |
| QA | Dev + QA | Bug fix / retest (ongoing) | | | | | | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | |
| QA | QA Team | Release sign-off | | | | | | | | | | | | | | | ■ |

🔴 = week with PH holiday: W10 = All Souls' Day (Nov 2), W14 = Bonifacio Day (Nov 30), W15 = Immaculate Conception (Dec 8)

**QA total:** W1–W15 (~15 weeks including planning). Active testing: W7–W15. Buffer absorbed into QA schedule.

---

## Calendar Mapping

**Start date:** Aug 24, 2026 (Monday) — per Kuroda-san's ASAP directive.  
**Work schedule:** Mon–Fri only. No weekends. PH holidays skipped.  
**Total available workdays to deadline:** 80 days (Aug 24 – Dec 17)  
**Project needs:** ~55 workdays (11 weeks × 5 days) — leaves ~25 workdays (~5 weeks) buffer.

### PH Holidays in Project Period (Workdays Lost)

| Date | Day | Holiday | Impact |
|---|---|---|---|
| Aug 31 | Mon | National Heroes Day | W1 reduced to 4 days |
| Nov 2 | Mon | All Souls' Day | W10 reduced to 4 days |
| Nov 30 | Mon | Bonifacio Day | W14 reduced to 4 days |
| Dec 8 | Tue | Feast of the Immaculate Conception | W15 reduced to 4 days |

### Week-by-Week Calendar (Actual Dates)

| Week | Dates | Workdays | Phase | Notes |
|---|---|---|---|---|
| **W0** | Aug 24–28 | 5 | ASCM Refactor (DEVOPS-6415) | Start date. Full week. |
| **W1** | Aug 31–Sep 5 | 4 | QA verification + Lead: steering files + spec session | 🔴 Aug 31 = National Heroes Day (Mon off). Lead prepares ASCA Spec 01 while QA runs regression gate. |
| **W2** | Sep 7–11 | 5 | Foundation: migrations + structure tests | |
| **W3** | Sep 14–18 | 5 | Foundation: models, enums, run lifecycle | |
| **W4** | Sep 21–25 | 5 | Foundation: reference prices, engine | |
| **W5** | Sep 28–Oct 2 | 5 | Foundation complete → CAP Integration starts | |
| **W6** | Oct 5–9 | 5 | ASCA: injection + detection | |
| **W7** | Oct 12–16 | 5 | ASCA: CSV, DataCorrection allocateForCharge | |
| **W8** | Oct 19–23 | 5 | ASCA: refund allocation | |
| **W9** | Oct 26–30 | 5 | ASCA dev testing (DEV04) + ASCI starts | |
| **W10** | Nov 2–6 | 4 | ASCI CIP integration | 🔴 Nov 2 = All Souls' Day (Mon off) |
| **W11** | Nov 9–13 | 5 | ASCI dev testing + QA CAP scenarios | Dev complete |
| — | — | — | **--- Buffer zone starts below ---** | |
| **W12** | Nov 16–20 | 5 | QA: CAP + CIP scenario testing | Buffer / QA |
| **W13** | Nov 23–27 | 5 | QA: Integration testing | Buffer / QA |
| **W14** | Nov 30–Dec 4 | 4 | QA: Regression | 🔴 Nov 30 = Bonifacio Day (Mon off) |
| **W15** | Dec 7–11 | 4 | QA: Final regression + sign-off | 🔴 Dec 8 = Immaculate Conception (Tue off) |
| **W16** | Dec 14–17 | 4 | **Production release** | Deadline week (Mon–Thu) |

### Key Observations

- **Dev complete by W11 (Nov 13)** — 5 full weeks before the Dec 17 deadline
- **QA has W6–W15** (~10 weeks overlapping with dev + buffer) for test planning, execution, and regression
- **Buffer is generous:** W12–W15 (4 weeks) available for QA overflow, bug fixes, and surprises
- **Holiday impact is minimal:** 4 lost workdays spread across the project. Only W1 (Refactor week) and W10 (CIP) are affected during dev. The remaining 2 holidays hit buffer/QA weeks.
- **Worst case:** Even if dev slips 2 weeks, QA still has W13–W15 (3 weeks) for testing before deadline

### Comparison to Previous Scenarios

| Start | Dev Complete | Buffer to Deadline | Verdict |
|---|---|---|---|
| **Aug 24 (actual)** | **~Nov 13** | **~5 weeks** | ✅ Very comfortable |
| Sep 15 (old recommendation) | ~Dec 5 | ~1 week | Adequate |
| Oct 1 (latest acceptable) | ~Dec 15 | 2 days | ⚠️ No room for error |

---

## Milestones

| Milestone | Week | Date | Notes |
|---|---|---|---|
| **Project starts** | **W0** | **Aug 24** | ASCM Refactor begins |
| ASCM Refactor complete | W0 | Aug 28 | No blockers |
| ASCM QA verification passes | W1 | Sep 5 | Gate to Foundation (1 day lost to holiday) |
| ASC Shared Foundation complete | W5 | Oct 2 | All tables + engine ready |
| ASCA CAP dev complete | W9 | Oct 30 | Full pipeline tested on seeded data |
| ASCI CIP dev complete | W11 | Nov 13 | CIP tested on seeded data |
| QA active testing begins | W6 | Oct 5 | CAP scenarios (parallel with dev) |
| Upstream CAP/CIP go to prod | — | Late Nov / early Dec | Real charges start flowing |
| QA sign-off | W15 | Dec 12 | All regression passing |
| **ASC production release** | **W16** | **Dec 14–17** | **Ready for deadline** |
| **Deadline** | — | **Dec 17** | |
| First real batch run | — | Jan 1, 2027 | On real upstream charges |

---

## Parallel Development Model

**What's parallel:**
- QA starts planning/prepping while Foundation is being built
- QA tests CAP scenarios while CIP integration is being built
- Upstream CAP/CIP teams develop independently from our ASC work

**What's sequential (dependencies):**
- ASCM Refactor → Regression gate → ASC Shared Foundation
- Foundation must finish before CAP Integration (needs tables + models + engine)
- ASCA CAP must be proven before ASCI CIP starts (CIP reuses the framework)
- Final Regression → after all dev complete

**Critical path:**
```
ASCM Refactor → Regression gate + Spec Prep (parallel) → Foundation → ASCA CAP Integration → ASCI CIP → QA → Regression → Buffer → Dec 17
```

---

## Sign-Off Gates (Schedule View)

Each phase runs through 3 mandatory gates. Full gate definitions, JIRA structure, branch strategy, and roles live in the **development workflow doc** — this section shows only *when* each gate falls in the schedule.

**→ Full workflow: `projects/asca/documentation/asca-development-workflow.md`**

| Gate | Who Approves | What's Approved |
|---|---|---|
| **G1** | PM (Kuroda-san) | Requirements — scope, formula, reference prices, plan detection |
| **G2** | Lead + Dev | Design & tasks — architecture sound, task list executable |
| **G3** | Lead | Code review — correct, follows standards, no regressions |

### Gate Timing (Mapped to Weeks)

```
W1:  ┣━━━━ Steering + Spec 01 requirements → ══ G1: PM Sign-Off ══
W2:  ┣━━━━ Spec 01 design + tasks (after G1) → ══ G2: Lead + Dev Review ══
W2:  ┣━━━━ Task execution begins (after G2)
W5:  ┣━━━━ All Spec 01 PRs → ══ G3: Code Review ══ → Foundation complete
W6:  ┣━━━━ Spec 02 requirements → ══ G1 ══ → design → ══ G2 ══ → execution
W9:  ┣━━━━ All Spec 02 PRs → ══ G3 ══ → CAP Integration complete
W10: ┣━━━━ ASCI Spec 01 requirements → ══ G1 ══ → design → ══ G2 ══ → execution
W11: ┣━━━━ All ASCI PRs → ══ G3 ══ → CIP Integration complete → Dev done
```

**Gate failure impact:** G1 rejection = 1–2 days slip. G2 = 0.5–1 day. G3 = 0.5 day per round. All absorbed by the W12–W15 buffer.

---

### Upstream Independence

ASC is NOT blocked by upstream timelines:

| What ASC needs from upstream | Status |
|---|---|
| Plan IDs for CAP/CIP | ✅ Confirmed (CAP: 1016–1027, CIP: 1028–1032) |
| Reference prices (L values) | ✅ Confirmed |
| Upstream DB schema | ✅ Not needed — reads existing `trn_charge` |
| Actual charges in DEV04 | Self-seeded (test data seeder in Foundation) |
| Upstream in production | Not needed until first batch run (Jan 1, 2027) |

---

## Blockers & Open Items

| ID | Item | Owner | Status | Blocks |
|---|---|---|---|---|
| **O-3** | **Table prefix** | **Engineering** | **✅ Resolved (2026-08-17)** — `log_alloc_*` for batch-generated, `mst_alloc_*` for reference prices. Approved by Kuroda-san. | — |
| O-1 | CAP App product_id | CAP team | ✅ Resolved — was 10021; changed to **10022** on 2026-08-19 (see O-7) | — |
| O-2 | Asymmetric discount (CIP RA-04) | Accounting | Low risk — if rejected, proration_basis returns | — |
| O-4 | B2B App reversal logic | Accounting + CAP | Post-release (Phase 4) | — |
| O-5 | CIP coaching reference price | Accounting | 🔴 **REOPENED (2026-08-28)** — plan price ¥88,000 → ¥75,900. ¥84,020 stale. New L_coaching pending (likely ¥71,920). | ASCI seeder |
| O-6 | Allocation breakdown for Accounting | Accounting | ✅ Resolved — CSV in zip + Metabase (2026-08-17) | — |
| O-7 | Product ID changes | Business (Go-san) | ✅ **Confirmed FINAL (2026-08-19)** — CAP App `10021→10022`, CIP Coaching Intensive `10022→10025`. | Detection + seeder + Freee mapping |
| O-8 | CIP split arity | Accounting (Kuroda-san) | ✅ **Resolved (2026-08-28)** — **2-way (Coaching + App)**, even for 1029–1032. Lesson handled separately. Same as CAP → ASCI stays config-only. [Slack](https://bizmatesinc.slack.com/archives/C0BF8ABV74N/p1788340743121289?thread_ts=1788340577.655519&cid=C0BF8ABV74N) | — |

**Blockers for ASCA Foundation:** cleared — Foundation is project-agnostic and unaffected by the CIP price question.
**Blockers for ASCI:** O-5 (reference price) must resolve before ASCI design (W10). O-8 resolved (2-way).

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Existing ASC commands break | LOW | HIGH | try/catch isolation, ~25 lines added. Failure = today's behavior. |
| Allocation can't run independently | LOW | LOW | Thin debug command: `php artisan asc:allocation-debug {exeDate}` (~15 lines) |
| QA finds edge cases late | MEDIUM | MEDIUM | Buffer week. Property-based tests catch invariant violations early. |
| CIP reference prices change | LOW | LOW | Effective-dated config in `mst_alloc_reference_prices`. No code change needed. |
| Product ids changed (O-7, done) | — | LOW | App 10021→10022, CIP coaching 10022→10025 (2026-08-19, final). Detection whereIn + seeder + Freee mapping use new ids. |
| Upstream delays (CAP/CIP not in prod by late Nov) | LOW | ZERO | ASC uses seeded test data. Real validation happens Jan 1. |

---

## Key Dates (History + Future)

| Date | Event |
|---|---|
| 2026/08/07 | ASCH cancelled |
| 2026/08/10 | DB design received from Kuroda-san |
| 2026/08/11 | Scenario D proposed |
| 2026/08/12 | CAP pricing + plan_ids confirmed (REF-CAP-05/06/08) |
| 2026/08/13 | CIP project spec received — new product 10022, plans 1028–1032 |
| 2026/08/14 | Option 1 (Overwrite) proposed. Idempotency design (ΣN). |
| 2026/08/17 | O-3/O-5/O-6 resolved. JIRA projects created. Bundle grouping (order_no). |
| 2026/08/20 | Timeline consolidated. Kuroda-san directive: start ASAP. |
| **2026/08/24** | **W0 — ASCM Refactor starts (DEVOPS-6415)** |
| 2026/08/31 | 🔴 National Heroes Day (W1 loses 1 day) |
| ~2026/09/05 | ASCM QA verification passes → Foundation starts |
| ~2026/10/02 | ASC Shared Foundation complete |
| ~2026/10/30 | ASCA CAP dev complete |
| ~2026/11/02 | 🔴 All Souls' Day (W10 loses 1 day) |
| ~2026/11/13 | ASCI CIP dev complete |
| Late Nov | Upstream CAP/CIP go to production |
| 2026/11/30 | 🔴 Bonifacio Day |
| 2026/12/08 | 🔴 Feast of Immaculate Conception |
| ~2026/12/12 | QA sign-off |
| **2026/12/17** | **Production deadline** |
| **2027/01/01** | **First real batch run** |

---

## Current Status

**Last updated:** 2026-08-27 (Thursday)  
**Current week:** W0 (Aug 24–28) — ASCM Refactor (DEVOPS-6415)

| Item | Status |
|---|---|
| DataCorrectionLogic drift fix | ✅ Complete — monthly plan skip + missing fields added |
| ArchiverService + MailerService extraction | ✅ Complete — all 3 Logic files refactored |
| Unit tests | ✅ Complete — ArchiverServiceTest + MailerServiceTest |
| Smoke test on DEV04 | ⏳ Pending — deploy branch and run 3 commands |
| QA manual verification (W1) | ⏳ Not started — blocked by smoke test |
| P-3: Confirm coaching product_id with CAP team | ⏳ Open — non-blocking |
| Throy availability for W2 | ⏳ Confirm with Patrick-san |

---

## Reference: Confirmed Data

| Item | CAP | CIP |
|---|---|---|
| Plan IDs | 1016–1027 (12 plans) | 1028–1032 (5 plans) |
| Coaching product_id | 10005 (15min) / 10015 (30min) | **10025** (Intensive — changed from 10022 on 2026-08-19) |
| App product_id | **10022** (changed from 10021 on 2026-08-19) | **10022** (same as CAP) |
| L_coaching (reference) | ¥19,800 (15min) / ¥39,600 (30min) | 🔴 ¥84,020 STALE — O-5 reopened (plan now ¥75,900, new L_coaching pending) |
| L_app (reference) | ¥3,980 | ¥3,980 |

> **🔴 Product ID change (2026-08-19, Go-san approved, FINAL):** CAP App `10021→10022`, CIP Coaching Intensive `10022→10025`. See `research/CIP/REF-CIP-04-*`. Note `10022` now = App (was CIP coaching).
> **🔴 O-5 reopened:** CIP plan price dropped ¥88,000 → ¥75,900, so the ¥84,020 L_coaching is stale. Awaiting Kuroda-san/Accounting.
> **✅ O-8 resolved (2026-08-28):** CIP is **2-way (Coaching + App)**, even for plans 1029–1032. Online Lesson handled separately by existing daily-rate logic. Same split as CAP.
| App charge in trn_charge | ¥0 (companion) | ¥0 (companion) |
| Date filter needed? | No (new plans) | No (new plans) |
| Upstream prod date | Late Nov / early Dec | Late Nov / early Dec |

---

## Source Documents

| Document | What it covers |
|---|---|
| `projects/asca/documentation/asc-allocation-framework-technical-design.md` | **Authoritative technical design** — formula, data flow, code, injection |
| `projects/asca/documentation/asca-development-workflow.md` | **Development workflow** — spec lifecycle, gates, JIRA structure, branch strategy, roles |
| `projects/asca/documentation/asc-alloc-scenario-d-injection-timeline-20260811.md` | Historical — original Scenario D proposal (timeline now consolidated here) |
| `projects/asca/documentation/ASCA-ADR-20260817-table-prefix-decision.md` | O-3 decision: `log_alloc_*` prefix |
| `docs/asc-cap-cip-combined-estimate-20260808.md` | Historical — Scenario C estimate (superseded) |
| `research/CAP/REF-CAP-04` | Kuroda-san DB design |
| `research/CAP/REF-CAP-05` | Confirmed pricing (Slack thread) |
| `research/CAP/REF-CAP-06` | CAP price mechanism (Confluence) |
| `research/CAP/REF-CAP-07` | Option 1 Overwrite (Confluence + verified) |
| `research/CAP/REF-CAP-08` | CAP requirements decision log |
| `research/CIP/REF-CIP-03` | CIP project spec (Jefferson) |
| `domain-knowledge/plans-and-products.md` | Full plan/product reference |
| `projects/ascm/knowledge-base/` | ASCM lessons learned |
