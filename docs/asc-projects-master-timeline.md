# ASC Projects — Master Timeline

## Document Info

| | |
|---|---|
| **Document type** | Project Timeline |
| **Date** | 2026-08-10 (Created) · 2026-08-20 (Consolidated — single authoritative timeline) |
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
| **ASCM Refactor (DEVOPS-6415)** | 3–5 days | High — starts Aug 24 |
| **ASC-CAP Dev (incl. shared foundation)** | 4–5 weeks (Noel + Throy) | Medium-High — code analyzed, injection points identified |
| **ASC-CIP Dev (reuses foundation)** | 1–1.5 weeks (same team or Orlino + Cristoff) | High — only adds strategy + config |
| **Total Dev** | 5.5–6.5 weeks | Medium-High |
| **QA** | 4–5 weeks (overlapping with dev) | Medium |
| **End-to-end** | ~11 weeks (W0–W11) | Medium |
| **Available time** | 17 weeks / 80 workdays (Aug 24 → Dec 17) | — |
| **Buffer** | ~5 weeks (~25 workdays) | High — very comfortable margin |
| **Deadline** | 2026/12/17 | Fixed |
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

### Phase 0: ASCM Refactor (DEVOPS-6415) — W0, Aug 24–28 (3–5 days)

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

---

### Phase 2: ASCA CAP Integration — W6–W9 (Oct 5 – Oct 30)

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

### Phase 3: ASCI CIP Integration — W10–W11 (Nov 2 – Nov 13)

**Billed under:** [ASCI](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog)

| Step | What | Owner | Effort |
|---|---|---|---|
| 13 | CIP Detection Strategy (`CoachingIntensivePlanEnum`: 1028–1032) | Dev 1 (or Orlino + Cristoff) | 3–5 days |
| 14 | CIP reference price config (L_coaching = ¥84,020) | Same | Included |
| 15 | ASCI dev testing on DEV04 | Lead | 1–2 days |

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

| Category | Owner | Task | W0 (Aug 24) | W1 (Aug 31)🔴 | W2 (Sep 7) | W3 (Sep 14) | W4 (Sep 21) | W5 (Sep 28) | W6 (Oct 5) | W7 (Oct 12) | W8 (Oct 19) | W9 (Oct 26) | W10 (Nov 2)🔴 | W11 (Nov 9) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **ASCM Refactor** | Lead | Fix DataCorrectionLogic drift | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Extract BatchReportDeliveryService (3 files) | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Unit test extracted service | ■ | | | | | | | | | | | |
| **ASCM Regression** | Lead | Smoke test Pre + Final + Correction on DEV04 | ■ | | | | | | | | | | | |
| **ASCM Regression** | QA Team | Manual verification: compare reports | | ■ | | | | | | | | | | |
| **Foundation** | Dev 1 | DB migrations (10 tables + 1 view) + structure tests | | | ■ | ■ | | | | | | | | |
| **Foundation** | Lead | Models / enums / run lifecycle service | | | | ■ | | | | | | | | |
| **Foundation** | Lead | Reference-price master + price resolution + seeder | | | | | ■ | | | | | | | |
| **Foundation** | Dev 1 | Allocation engine + ΣN computation + validations | | | | | ■ | ■ | | | | | | |
| **Foundation** | Lead | Test data seeder (mock CAP/CIP charges) | | | | | | ■ | | | | | | |
| **ASCA Integration** | Lead | Injection into CommonUtil (Option 1 Overwrite) | | | | | | | ■ | | | | | |
| **ASCA Integration** | Dev 1 | CAP Detection Strategy + bundle generation | | | | | | | ■ | | | | | |
| **ASCA Integration** | Lead | AllocationDetail CSV generation + config | | | | | | | | ■ | | | | |
| **ASCA Integration** | Dev 1 | DataCorrectionLogic: add `allocateForCharge()` | | | | | | | | ■ | | | | |
| **ASCA Integration** | Lead + Dev 1 | Refund allocation (record_kind = 1) | | | | | | | | | ■ | | | |
| **ASCA Integration** | Lead + Dev 1 | ASCA dev testing on DEV04 (full pipeline) | | | | | | | | | | ■ | | |
| **ASCI Integration** | Dev 1 (or Orlino + Cristoff) | CIP Detection Strategy + reference prices | | | | | | | | | | | ■ | ■ |
| **ASCI Integration** | Lead | ASCI dev testing on DEV04 | | | | | | | | | | | | ■ |

🔴 = week with PH holiday (1 lost workday): W1 = National Heroes Day (Aug 31), W10 = All Souls' Day (Nov 2)

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
| **W1** | Aug 31–Sep 5 | 4 | ASCM Refactor → QA verification | 🔴 Aug 31 = National Heroes Day (Mon off) |
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

## Next Steps (as of 2026-08-20)

**Start date: Aug 24, 2026.** All blockers cleared.

1. **Noel:** Begin ASCM Refactor (DEVOPS-6415) on Aug 24 — first action on the critical path.
2. **Noel:** Confirm P-3 with CAP team (Keith/Terry) — will coaching product_id change? (non-blocking, but good to settle in W0)
3. **Patrick-san:** Confirm Throy's availability for W2 (Foundation phase — migrations + allocation engine).
4. **Noel:** After Refactor regression passes (~Sep 5) → Step 1 (migrations with `log_alloc_*` prefix).

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
