# ASC Projects — Master Timeline

**Date:** 2026-08-10 (Created) · 2026-08-20 (Consolidated — single authoritative timeline)  
**Status:** ACTIVE — Technical design agreed. All blockers cleared. Ready to start.  
**Overall Lead:** Noel Palo  
**Assisted by:** Kiro  
**Deadline:** ASCA + ASCI = 2026/12/17

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
ASCM Refactor (DEVOPS-6415):         W0 (3–5 days) — prep + regression
ASCA (Foundation + CAP Integration): W1–W7 — builds shared framework + CAP-specific logic
ASCI (CIP Integration):              W7–W8 — plugs CIP into working framework
QA (overlapping):                    W6–W11 — test planning, execution, regression
Upstream CAP (Keith's team):         In progress ════════════════════ Late Nov / Early Dec
Upstream CIP (Jefferson's team):     In progress ════════════════════ Late Nov / Early Dec
```

**What we're building:** A shared allocation framework that splits Coaching charge revenue between Coaching and App products, injected into the existing accounting batch commands.

**Architecture:** Scenario D (injection into existing commands) + Option 1 (Overwrite N→P). Single injection point in `CommonUtil::createDailyRateCalculation()`. Shared `log_alloc_*` tables with `project_code` column.

**Technical design:** `projects/asca/documentation/asc-allocation-framework-technical-design.md` (authoritative)

---

## Terminology

| Term | Full Name | What it is | Owner |
|---|---|---|---|
| **CAP** | Coaching and App Plan | Upstream project — creates new plans 1016–1027 in MBTI_backend | CAP team (Keith, Terry) |
| **CIP** | Coaching Intensive Plan | Upstream project — creates new product 10022 with plans 1028–1032 in MBTI_backend | CIP team (Jefferson) |
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
| Detection | product_id 10021 (App) + plan_id enums | Stable anchor. Works for both CAP and CIP. |
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

### ASCM Knowledge Base Application

| ASCM Lesson | How Scenario D applies it |
|---|---|
| KB #13: Tenant duplication | CAP/CIP is Bizmates-only. No Zipan path to duplicate. |
| KB #14: Pre/Final duplication | Single `AscAllocationService` with `$preFlg`. One codebase, two modes. |
| KB #15: Unsafe delete scope | Delete by `target_ym + project_code`. Never `created_at`. |
| KB #12: Stale aggregation | Clear-and-rebuild within transaction. Idempotent re-runs. |
| KB #10: Pre/Final table mismatch | N source table is explicit config, not implicit convention. |
| KB #16: Global mutable state | Service receives dates as parameters. Doesn't use `CommonUtil::setSystemDate()`. |

---

## Estimate

| Metric | Value | Confidence |
|---|---|---|
| **ASCM Refactor (DEVOPS-6415)** | 3–5 days | High — no blockers, can start immediately |
| **ASC-CAP Dev (incl. shared foundation)** | 4–5 weeks (Noel + Throy) | Medium-High — code analyzed, injection points identified |
| **ASC-CIP Dev (reuses foundation)** | 1–1.5 weeks (same team or Orlino + Cristoff) | High — only adds strategy + config |
| **Total Dev** | 5.5–6.5 weeks | Medium-High |
| **QA** | 4–5 weeks (overlapping with dev) | Medium |
| **End-to-end** | ~11 weeks (W0 refactor → W11 sign-off) | Medium |
| **Deadline** | 2026/12/17 | Fixed |
| **Latest start (comfortable)** | Mid-September | Gives 1 week buffer |
| **Latest start (tight)** | Early October | 3 days buffer ⚠️ |
| **First production batch** | 2027/01/01 | Fixed |

---

## Confirmed Data

| Item | CAP | CIP |
|---|---|---|
| Plan IDs | 1016–1027 (12 plans) | 1028–1032 (5 plans) |
| Coaching product_id | 10005 (15min) / 10015 (30min) | 10022 (Intensive) |
| App product_id | 10021 | 10021 |
| L_coaching (reference) | ¥19,800 (15min) / ¥39,600 (30min) | ¥84,020 (= plan ¥88,000 − L_app) |
| L_app (reference) | ¥3,980 | ¥3,980 |
| App charge in trn_charge | ¥0 (companion) | ¥0 (companion) |
| Date filter needed? | No (new plans) | No (new plans) |
| Upstream prod date | Late Nov / early Dec | Late Nov / early Dec |

---

## Implementation Phases — Detailed

### Phase 0: ASCM Refactor (DEVOPS-6415) — W0, 3–5 days

**Billed under:** [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) (maintenance). Linked to ASCA via [ASCA-7](https://bizmates.atlassian.net/browse/ASCA-7).

Scope: Refactoring and fixing EXISTING code only. No new features, no new tables.

| # | Category | Owner | Task | Detail |
|---|---|---|---|---|
| 1 | **Fix** | Lead | Fix DataCorrectionLogic drift | Add `BizmatesMonthlyPlanEnum::exists()` skip at top of `createDailyRateCalculation()`. Add missing `$condition` fields: `tax_free`, `country_id`, `gross_amount`. |
| 2 | **Extract** | Lead | Extract zip+email from DailyRateCalculationPreLogic | Move into `BatchReportDeliveryService::deliver($fileNameList, $mailType, $suffix)`. |
| 3 | **Extract** | Lead | Extract zip+email from SendJournalsDataLogic | Same extraction — replace inline zip+email with service call. |
| 4 | **Extract** | Lead | Extract zip+email from DataCorrectionLogic | Same extraction — replace inline zip+email with service call. |
| 5 | **Test** | Lead | Unit test BatchReportDeliveryService | Basic service test — zip creation, file cleanup, email dispatch. |
| 6 | **Test** | Lead | Verify DataCorrectionLogic fix via smoke test | Run DataCorrection on DEV04 to confirm monthly plans skipped + fields present. |
| 7 | **Verify** | Lead | Run Pre + Final + Correction commands on DEV04 | Check: no runtime errors, reports generated, email dispatch logged. |
| 8 | **Verify** | Lead | Collect generated reports/CSVs | Hand off to QA Team for manual verification. |
| 9 | **Verify** | QA Team | Manual verification of generated reports | Compare against known-good baseline. Confirm no regression. |

**NOT in DEVOPS-6415:** DB migrations, models, allocation service, test data seeder, reference prices — those are ASCA Spec 01.

**Deliverables:**
- `BatchReportDeliveryService` class (new, shared by all 3 commands)
- DataCorrectionLogic aligned with CommonUtil (skip + fields)
- Baseline documentation (CSV list, smoke test results)
- All 3 commands verified working on DEV04 after changes
- QA manual verification sign-off

---

### Phase 1: ASC Shared Foundation — W1–W4

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

---

### Phase 2: ASCA CAP Integration — W4–W7

**Billed under:** [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog)

| Step | What | Owner | Effort |
|---|---|---|---|
| 7 | Injection into CommonUtil (Option 1 Overwrite) | Lead | 2 days |
| 8 | CAP Detection Strategy + bundle generation | Dev 1 | Included in Step 4 |
| 9 | AllocationDetail CSV generation + config | Lead | 2–3 days |
| 10 | DataCorrectionLogic: add `allocateForCharge()` call | Dev 1 | 1 day |
| 11 | Refund allocation (record_kind = 1) | Lead + Dev 1 | 3–4 days |
| 12 | ASCA dev testing on DEV04 (full pipeline Pre + Final) | Lead + Dev 1 | 2–3 days |

---

### Phase 3: ASCI CIP Integration — W7–W8

**Billed under:** [ASCI](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog)

| Step | What | Owner | Effort |
|---|---|---|---|
| 13 | CIP Detection Strategy (`CoachingIntensivePlanEnum`: 1028–1032) | Dev 1 (or Orlino + Cristoff) | 3–5 days |
| 14 | CIP reference price config (L_coaching = ¥84,020) | Same | Included |
| 15 | ASCI dev testing on DEV04 | Lead | 1–2 days |

---

### Phase 4: Post-Release — W9+

| Step | What | Priority |
|---|---|---|
| 16 | Reversal (record_kind = 2) | Ships after first prod run — not on critical path |
| 17 | Metabase saved query for Accounting (allocation breakdown) | Post-deployment |

---

## Development Gantt

```
Upstream (other teams):
  CAP project  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ → Prod: late Nov / early Dec
  CIP project  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ → Prod: late Nov / early Dec

Dev Team:
  ASCM Refactor (DEVOPS-6415)  ━━━━┓
  ASCM Refactor Regression          ┣━┓
  ASC Shared Foundation                 ┣━━━━━━━━━━━━┓
  ASCA CAP Integration                               ┣━━━━━━━━━━━━┓
  ASCI CIP Integration                                              ┣━━━━┓
  QA (CAP scenarios)                                  ┣━━━━━━━━━━━━━━━━━━┓
  QA (CIP scenarios)                                                 ┣━━━━━━━━┓
  Final Regression                                                            ┣━━━━┓
  Buffer                                                                            ┣━━ → Dec 17
```

### Detailed Dev Gantt (Week by Week)

| Category | Owner | Task | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **ASCM Refactor** | Lead | Fix DataCorrectionLogic drift | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Extract BatchReportDeliveryService (3 files) | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Unit test extracted service | ■ | | | | | | | | | | | |
| **ASCM Regression** | Lead | Smoke test Pre + Final + Correction on DEV04 | ■ | | | | | | | | | | | |
| **ASCM Regression** | Lead | Collect generated CSVs/reports (baseline) | ■ | | | | | | | | | | | |
| **ASCM Regression** | QA Team | Manual verification: compare reports against expected | | ■ | | | | | | | | | | |
| **Foundation** | Dev 1 | DB migrations (10 tables + 1 view) + structure tests | | ■ | ■ | | | | | | | | | |
| **Foundation** | Lead | Models / enums / run lifecycle service | | | ■ | | | | | | | | | |
| **Foundation** | Lead | Reference-price master + price resolution + seeder | | | | ■ | | | | | | | | |
| **Foundation** | Dev 1 | Allocation engine + ΣN computation + validations | | | | ■ | ■ | | | | | | | |
| **Foundation** | Lead | Test data seeder (mock CAP/CIP charges) | | | | ■ | | | | | | | | |
| **ASCA Integration** | Lead | Injection into CommonUtil (Option 1 Overwrite) | | | | | ■ | | | | | | | |
| **ASCA Integration** | Dev 1 | CAP Detection Strategy + bundle generation | | | | | ■ | | | | | | | |
| **ASCA Integration** | Lead | AllocationDetail CSV generation + config | | | | | | ■ | | | | | | |
| **ASCA Integration** | Dev 1 | DataCorrectionLogic: add `allocateForCharge()` | | | | | | ■ | | | | | | |
| **ASCA Integration** | Lead + Dev 1 | Refund allocation (record_kind = 1) | | | | | | | ■ | | | | | |
| **ASCA Integration** | Lead + Dev 1 | ASCA dev testing on DEV04 (full pipeline) | | | | | | | | ■ | | | | |
| **ASCI Integration** | Dev 1 (or Orlino + Cristoff) | CIP Detection Strategy + reference prices | | | | | | | | ■ | ■ | | | |
| **ASCI Integration** | Lead | ASCI dev testing on DEV04 | | | | | | | | | ■ | | | |
| **Post-release** | Dev 1 | Reversal (record_kind = 2) | | | | | | | | | | ■ | | |
| **Buffer** | All | Bug fixes from QA / environment issues | | | | | | | | | | | ■ | ■ |

---

## QA Gantt

| Category | Owner | Task | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| QA | QA Team | ASCM Refactor: Manual report verification | | ■ | | | | | | | | | | |
| QA | QA Team | Test planning + strategy | | | ■ | ■ | | | | | | | | |
| QA | QA Team | Test case creation + data prep (CAP + CIP) | | | | ■ | ■ | ■ | | | | | | |
| QA | Miko | Test execution: ASCA CAP scenarios (10 cases) | | | | | | | ■ | ■ | ■ | | | |
| QA | Glenn | Test execution: ASCI CIP scenarios (11 cases) | | | | | | | | | ■ | ■ | | |
| QA | QA Team | Integration testing (cross-project, failure isolation) | | | | | | | | | | ■ | ■ | |
| QA | QA Team | Regression testing | | | | | | | | | | | ■ | ■ |
| QA | Dev + QA | Bug fix / retest (ongoing) | | | | | | ■ | ■ | ■ | ■ | ■ | ■ | |
| QA | QA Team | Release sign-off | | | | | | | | | | | | ■ |

**QA total:** ~7 weeks overlapping with dev. Active testing: W6–W11.

---

## Calendar Mapping

### Scenario A: Start Sep 15 (Recommended)

| Actual Dates | Week | Phase |
|---|---|---|
| Sep 15–19 | W0 | ASCM Refactor (DEVOPS-6415) |
| Sep 22–26 | W1 | ASC Shared Foundation starts + ASCM QA verification |
| Sep 29–Oct 3 | W2 | Foundation (models, enums, run lifecycle) |
| Oct 6–10 | W3 | Foundation (engine, reference prices) |
| Oct 13–17 | W4 | Foundation complete + ASCA CAP Integration starts |
| Oct 20–24 | W5 | ASCA Integration (injection, CSV) |
| Oct 27–31 | W6 | ASCA Integration (refunds, allocateForCharge) |
| Nov 3–7 | W7 | ASCA dev testing + ASCI CIP Integration starts |
| Nov 10–14 | W8 | ASCI CIP testing + QA starts CAP scenarios |
| Nov 17–21 | W9 | QA CAP scenarios |
| Nov 24–28 | W10 | QA CIP + Integration testing |
| Dec 1–5 | W11 | Regression testing + sign-off |
| Dec 8–12 | — | **Buffer (5 business days)** |
| **Dec 17** | — | **Production deadline** |
| Late Nov–Early Dec | — | Upstream CAP/CIP goes to production |
| **Jan 1, 2027** | — | **First real ASC batch run** |

### Scenario B: Start Oct 1 (Tight)

| Milestone | Calendar Date | Notes |
|---|---|---|
| ASCM Refactor starts | Oct 1 | |
| Foundation starts | Oct 6 | |
| Foundation complete | Oct 27 | |
| ASCA CAP dev complete | Nov 17 | |
| ASCI CIP dev complete | Nov 24 | |
| QA sign-off | Dec 15 | |
| **Buffer** | **Dec 15–17 (2 days)** | ⚠️ Very tight |
| **Deadline** | **Dec 17** | |

⚠️ Starting Oct 1 leaves only 2 business days buffer. **Strongly recommend Sep 15 start.**

---

## Milestones

| Milestone | Week | Sep 15 Start | Notes |
|---|---|---|---|
| ASCM Refactor complete | W0 | Sep 19 | Can start immediately — no blockers |
| ASCM QA verification passes | W1 | Sep 26 | Gate to Foundation phase |
| ASC Shared Foundation complete | W4 | Oct 17 | All tables + engine ready |
| ASCA CAP dev complete | W7 | Nov 7 | Full pipeline tested on seeded data |
| ASCI CIP dev complete | W8 | Nov 14 | CIP tested on seeded data |
| QA active testing begins | W6 | Oct 27 | CAP scenarios |
| Upstream CAP/CIP go to prod | — | Late Nov / early Dec | Real charges start flowing |
| QA sign-off | W11 | Dec 5 | All regression passing |
| **ASC production release** | — | **Dec 10–12** | Ready before deadline |
| **Buffer ends** | — | **Dec 17** | Production deadline |
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
ASCM Refactor → Regression gate → Foundation → ASCA CAP Integration → ASCI CIP → QA → Regression → Buffer → Dec 17
```

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
| O-1 | CAP App product_id | CAP team | ✅ Resolved — 10021 (2026-08-12) | — |
| O-2 | Asymmetric discount (CIP RA-04) | Accounting | Low risk — if rejected, proration_basis returns | — |
| O-4 | B2B App reversal logic | Accounting + CAP | Post-release (Phase 4) | — |
| O-5 | CIP coaching reference price | Accounting | ✅ Resolved — ¥84,020 (2026-08-17) | — |
| O-6 | Allocation breakdown for Accounting | Accounting | ✅ Resolved — CSV in zip + Metabase (2026-08-17) | — |
| P-3 | CAP new coaching product_id | CAP team | ⚠️ Non-blocking — detection uses product 10021 + plan_id. Config update if confirmed. | — |

**All blockers cleared.** Development can start immediately.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Existing ASC commands break | LOW | HIGH | try/catch isolation, ~25 lines added. Failure = today's behavior. |
| Allocation can't run independently | LOW | LOW | Thin debug command: `php artisan asc:allocation-debug {exeDate}` (~15 lines) |
| QA finds edge cases late | MEDIUM | MEDIUM | Buffer week. Property-based tests catch invariant violations early. |
| CIP reference prices change | LOW | LOW | Effective-dated config in `mst_alloc_reference_prices`. No code change needed. |
| CAP team creates new coaching product_id (P-3) | MEDIUM | LOW | Detection anchored on product 10021 + plan_id enum. Config update only. |
| Upstream delays (CAP/CIP not in prod by late Nov) | LOW | ZERO | ASC uses seeded test data. Real validation happens Jan 1. |

---

## DB Schema (10 tables + 1 view)

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
| 2026/08/20 | Timeline consolidated into single master document. |
| TBD | **Start date confirmed → ASCM Prep starts (DEVOPS-6415)** |
| TBD + 1 week | **Foundation starts (Step 1)** |
| ~W7 after start | **ASC-CAP dev complete** |
| ~W8 after start | **ASC-CIP dev complete** |
| Late Nov | Upstream CAP/CIP go to production |
| ~W11 after start | QA sign-off |
| **2026/12/17** | **Production deadline** |
| **2027/01/01** | **First real batch run** |

---

## Next Steps (as of 2026-08-20)

1. **Patrick-san:** Confirm start date and team availability.
2. **Noel:** Confirm P-3 with CAP team (Keith/Terry) — will coaching product_id change?
3. **Noel:** Begin ASCM Prep (DEVOPS-6415) — all blockers cleared, can start immediately.
4. **Noel:** After Prep → Step 1 (migrations with `log_alloc_*` prefix).

---

## Source Documents

| Document | What it covers |
|---|---|
| `projects/asca/documentation/asc-allocation-framework-technical-design.md` | **Authoritative technical design** — formula, data flow, code, injection |
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
