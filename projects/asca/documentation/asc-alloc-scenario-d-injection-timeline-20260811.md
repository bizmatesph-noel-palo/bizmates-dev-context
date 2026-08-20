# ASC Allocation Framework — Scenario D (Injection Approach)

## Document Info

| | |
|---|---|
| **Document type** | Project Estimation |
| **Date** | 2026-08-11 (Created) · 2026-08-17 (aligned with Option 1 + JIRA codes + parallel flow) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro (code analysis, estimation modeling, document generation) |
| **Status** | Historical |
| **Audience** | Dev team, Patrick-san (SDM), Kuroda-san (PM) |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) · [ASCI](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) |
| **Superseded by** | `docs/asc-projects-master-timeline.md` (timeline content consolidated there) |

> ⚠️ **HISTORICAL REFERENCE ONLY** (as of 2026-08-20)
>
> This document is the original Scenario D proposal. Its timeline, Gantt, calendar mapping, and QA schedule have been **consolidated into the master timeline:**
>
> **→ `docs/asc-projects-master-timeline.md`** (single authoritative timeline for ASCM Refactor, ASCA, and ASCI)
>
> This file is preserved for historical context — the rationale, Scenario C vs D comparison, and lead dev assessment remain useful background. For current schedule and task tracking, always refer to the master timeline.

---

**Context:** Based on ASCM experience and code analysis of existing accounting commands.

### Terminology

| Term | Full Name | What it is |
|---|---|---|
| **CAP** | Coaching and App Plan | Upstream project (MBTI_backend) — creates new bundled plans 1016–1027 |
| **CIP** | Coaching Intensive Plan | Upstream project (MBTI_backend) — creates new Coaching Intensive product (10022) with new plans 1028–1032 |
| **ASCA** | ASC for CAP | Our accounting project — allocates CAP coaching revenue between Coaching + App |
| **ASCI** | ASC for CIP | Our accounting project — allocates CIP coaching revenue between Coaching + App |

The upstream projects (CAP/CIP) create the charges and go to production late Nov / early Dec. Our projects (ASCA/ASCI) allocate the revenue and target Dec 17 production readiness, with first real batch run Jan 1, 2027.

---

## How This Relates to Existing Plans

### Scenario History

| Scenario | What it proposed | Status |
|---|---|---|
| **Scenario A** | Separate projects, built sequentially | ❌ Rejected (too much duplication, 13–15 weeks) |
| **Scenario B** | Separate projects, built in parallel | ❌ Rejected (needs 4 devs, coordination risk) |
| **Scenario C** | Combined framework, standalone commands, unified email | ✅ Decided (2026-08-08, Kuroda-san) — current master timeline |
| **Scenario D** | **Combined framework, injected into existing commands** | 📋 This proposal |

### What Scenario D Shares with Scenario C

- Same DB design (10 `asc_alloc_*` tables + 1 view — Kuroda-san's REF-CAP-04)
- Same allocation formula (`P_app = floor(N × L_app / (L_coaching + L_app))`)
- Same validation invariants (V-1 to V-5)
- Same `project_code` column distinguishing CAP vs CIP
- Same sequential execution (one project builds foundation, other reuses)
- Same team structure

### What Scenario D Changes from Scenario C

| Dimension | Scenario C (Current Plan) | Scenario D (This Proposal) |
|---|---|---|
| Execution order | CAP first → CIP second | **CAP first** → CIP second (same) |
| Commands | New standalone commands | Inject into existing DailyRateCalcPre + SendJournals |
| Email delivery | Unified email orchestrator (new, Step 8) | Same existing email, allocation CSVs added to zip |
| Freee sending | Dedicated thin sender (new, Step 7) | 1 Freee API call (already correct — Option 1 Overwrite) |
| Step 8 blocker (email) | Needs O-6 (email format approval) | **Eliminated** — uses existing email format |
| Step 7 blocker (Freee) | Needs CIP RA-05 | **Reduced** — reuses existing Freee infrastructure |
| Infrastructure effort | ~10 days (zip, email, cron, command skeleton) | ~1 day (inject into existing + extract delivery service) |
| Total dev effort | 9–12 weeks (from estimate) | **5.5–6.5 weeks** |

---

## Why CAP First

Both Scenario C and Scenario D agree: **CAP goes first**. The reasoning:

| Factor | Why CAP first |
|---|---|
| Requirements readiness | Reference prices confirmed (¥3,980 App, ¥19,800/¥39,600 Coaching), App product_id 10021 confirmed (O-1 RESOLVED 2026-08-12) |
| CIP blocker | O-5 (CIP reference prices) ✅ Resolved — ¥88,000 tax-inclusive (product 10022, confirmed 2026-08-14) |
| Team familiarity | Coaching+App bundle better understood from ASCH research |
| Business urgency | Equal — but CAP is more concrete today |

**Practical reality:** Whichever goes first carries the full infrastructure cost. The order doesn't change the total. But CAP's requirements are more concrete today, which reduces the risk of building foundation on assumptions that later change.

**Recommendation:** Start with CAP. If CIP requirements firm up first, swap — the foundation is project-agnostic anyway (`project_code` column).

---

## Estimate (Scenario D — Injection Approach)

| Metric | Value | Confidence |
|---|---|---|
| **ASCM Refactor (DEVOPS-6415)** | 3–5 days | High — no blockers, can start immediately |
| **CAP Dev Effort (incl. ASC Shared Foundation)** | 4–5 weeks (Noel + Throy) | Medium-High — code analyzed, injection points identified |
| **CIP Dev Effort (reuses foundation)** | 1–1.5 weeks (same team or Orlino + Cristoff) | High — only adds strategy + config |
| **Total Dev Effort** | 5.5–6.5 weeks | Medium-High |
| **QA Effort** | 4–5 weeks (overlapping with dev) | Medium |
| **End-to-end** | ~11 weeks (W0 refactor + W1–W4 foundation + W4–W7 CAP integration + W7–W8 CIP + W8–W11 QA + buffer) | Medium |
| **Deadline** | 2026/12/17 | Fixed |
| **Latest start to fit deadline** | Early October | High |
| **First production run** | 2027/01/01 | Fixed |

### Why Shorter Than Scenario C (9–12 weeks → 5.5–6.5 weeks)

| Saved effort | Days saved | Reason |
|---|---|---|
| No unified email orchestrator (Step 8 in Scenario C) | 5 days | Uses existing email. CSVs added to existing zip. |
| No dedicated Freee thin sender (Step 7 in Scenario C) | 4 days | Option 1 Overwrite — single Freee API call, allocation happens inside CommonUtil before sum is built. No 2nd call needed. |
| No command skeleton / cron setup | 2 days | No new commands. Injection into existing ones. |
| No zip/archive infrastructure | 2 days | Existing `createSendMailAttacheFile()` handles it (with extracted service). |
| Simpler testing (E2E = run existing command) | 3 days | No separate command integration tests needed. |
| **Total saved** | **~16 days (~3 weeks)** | |

---

## Implementation Steps (Scenario D)

| # | Step | Phase | Blocked by | Est. duration | Notes |
|---|---|---|---|---|---|
| 1 | Fix DataCorrectionLogic drift (skip + missing fields) | ASCM Refactor (DEVOPS-6415) | None | 0.5–1 day | Add `BizmatesMonthlyPlanEnum::exists()` skip + missing `$condition` fields |
| 2 | Extract BatchReportDeliveryService from DailyRateCalculationPreLogic | ASCM Refactor (DEVOPS-6415) | None | 0.5 day | Move zip+email into shared service |
| 3 | Extract BatchReportDeliveryService from SendJournalsDataLogic | ASCM Refactor (DEVOPS-6415) | None | 0.5 day | Same extraction pattern |
| 4 | Extract BatchReportDeliveryService from DataCorrectionLogic | ASCM Refactor (DEVOPS-6415) | None | 0.5 day | Same extraction pattern |
| 5 | Unit test BatchReportDeliveryService | ASCM Refactor (DEVOPS-6415) | Steps 2–4 | 0.5 day | Basic service test — zip creation, file cleanup, email dispatch |
| 6 | 10 migrations + 1 view + structure tests (`log_alloc_*`) | ASC Shared Foundation | ✅ O-3 resolved | 1 week | Foundation |
| 7 | Models, enums, run lifecycle service | ASC Shared Foundation | None | 3–4 days | Foundation |
| 8 | Reference-price master + price resolution + seeder | ASC Shared Foundation | None | 2–3 days | Foundation |
| 9 | CAP Detection Strategy + bundle generation | ASC Shared Foundation | ✅ O-1 resolved | 3–4 days | Foundation |
| 10 | Allocation engine + ΣN computation + validations V-1 to V-5 | ASC Shared Foundation | None | 4–5 days | Foundation |
| 11 | Test data seeder (mock CAP/CIP charges for DEV04) | ASC Shared Foundation | None | 1 day | Foundation |
| 12 | Injection into CommonUtil (Option 1 Overwrite) | ASCA CAP Integration | Steps 6–10 | 2 days | Single Freee API call — allocation overwrites N→P before sum |
| 13 | AllocationDetail CSV generation + config | ASCA CAP Integration | Step 12 | 2–3 days | CAP Integration |
| 14 | DataCorrectionLogic: add `allocateForCharge()` call | ASCA CAP Integration | Step 12 | 1 day | CAP Integration |
| 15 | Refund allocation (record_kind = 1) | ASCA CAP Integration | Step 12 | 3–4 days | CAP Integration |
| 16 | DEV04 full pipeline testing (Pre + Final) | ASCA CAP Integration | Steps 12–15 | 2–3 days | CAP Integration |
| 17 | ASCA dev testing on DEV04 (full pipeline) | ASCA CAP Integration | Step 16 | 1–2 days | CAP Integration |
| 18 | CIP Detection Strategy + reference price config | ASCI CIP Integration | Steps 6–10 | 3–5 days | CIP Integration |
| 19 | DEV04 testing for CIP plans | ASCI CIP Integration | Step 18 | 1–2 days | CIP Integration |
| 20 | ASCI dev testing on DEV04 | ASCI CIP Integration | Step 19 | 1 day | CIP Integration |

**Steps 1–5 are unblocked now** (DEVOPS-6415 — no dependencies). Steps 6–11 follow after ASCM Refactor regression passes.

### Critical Path

```
ASCM Refactor (DEVOPS-6415) → Regression gate → ASC Shared Foundation → ASCA CAP Integration → ASCI CIP Integration → QA → Regression → Buffer → Deadline (Dec 17)
```

---

## Gantt View — Scenario D (CAP First)

**Deadline:** 2026/12/17 (ASC production). First ASC batch run: 2027/01/01.  
**Upstream CAP/CIP projects:** Production late Nov / early Dec (provides upstream data to ASC).  
**Working backwards:** ASC QA sign-off by ~Dec 10. ASC dev complete by ~Nov 21.

### Parallel Development Model

```
Upstream (other teams):
  CAP project  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ → Prod: late Nov / early Dec
  CIP project  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ → Prod: late Nov / early Dec

Dev Team:
  ASCM Refactor (DEVOPS-6415)  ━━━━┓
  ASCM Refactor Regression          ┣━┓
  ASCA Foundation                       ┣━━━━━━━━━━━━┓
  ASCA CAP Integration                               ┣━━━━━━━━━━━━┓
  ASCI CIP Integration                                              ┣━━━━┓
  QA (CAP scenarios)                                  ┣━━━━━━━━━━━━━━━━━━┓
  QA (CIP scenarios)                                                 ┣━━━━━━━━┓
  Final Regression                                                            ┣━━━━┓
  Buffer                                                                            ┣━━ → Dec 17
```

**What's parallel:**
- QA starts planning/prepping while ASC Shared Foundation is being built
- QA tests CAP scenarios while CIP integration is being built
- Requirements for ASCA/ASCI unique logic can be identified while ASC Shared Foundation is being built
- Upstream CAP/CIP teams develop independently from our ASC work

**What's sequential (dependencies):**
- ASCM Refactor (DEVOPS-6415) → ASCM Refactor Regression (verify existing commands still work)
- ASCM Refactor Regression passes → ASC Shared Foundation can safely start (building on stable code)
- ASC Shared Foundation → must finish before CAP Integration (needs tables + models + engine)
- ASCA CAP Integration → must be proven before ASCI CIP starts (CIP reuses the framework)
- Final Regression → runs after all dev is complete (validates nothing broke end-to-end)

### Can ASC Develop Alongside Upstream?

**Yes.** ASC is NOT blocked by upstream timelines:

| What ASC needs from upstream | Status |
|---|---|
| Plan IDs for CAP/CIP products | ✅ Confirmed (CAP: 1016–1027, CIP: 1028–1032) |
| Reference prices (L values) | ✅ Confirmed (CAP: ¥19,800/¥39,600 + ¥3,980, CIP: ¥84,020 + ¥3,980) |
| Upstream DB schema | ✅ Not needed — ASC reads existing `trn_charge` + `log_daily_rate_calculation` |
| Actual charges in dev04 for testing | ⚠️ We seed test data ourselves (test data seeder in ASCA Spec 01) |
| Upstream in production (real charges) | Not needed until first batch run (Jan 1, 2027) |

### Can ASC Finish Earlier Than Dec 17?

**Yes — dev can be complete by early November.** The Dec 17 deadline is for production readiness including QA sign-off.

| Scenario | Dev complete | QA + Regression complete | Buffer |
|---|---|---|---|
| Start Sep 15 | Oct 27 (W6) | Dec 5 (W11) | 12 days |
| Start Sep 22 | Nov 3 (W7) | Dec 10 (W11) | 7 days |
| Start Oct 1 | Nov 10 (W7) | Dec 12 (W11) | 3 days ⚠️ |

---

### ASCM Refactor (DEVOPS-6415) — W0

**Billed under:** [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) (maintenance)  
**Scope:** Refactoring and fixing EXISTING code only. No new features, no new tables.

| # | Category | Owner | Task | Detail |
|---|---|---|---|---|
| 1 | **Fix** | Lead | Fix DataCorrectionLogic drift | Add `BizmatesMonthlyPlanEnum::exists()` skip at top of `createDailyRateCalculation()`. Add missing `$condition` fields: `tax_free`, `country_id`, `gross_amount`. Isolated fix — does not depend on anything else. |
| 2 | **Extract** | Lead | Extract zip+email from DailyRateCalculationPreLogic | Move `ZipArchive` creation + file cleanup + `sendMail()` call (~20 lines) into `BatchReportDeliveryService::deliver($fileNameList, $mailType, $suffix)`. Replace original code with service call. |
| 3 | **Extract** | Lead | Extract zip+email from SendJournalsDataLogic | Same extraction — replace inline zip+email with `BatchReportDeliveryService::deliver()` call. |
| 4 | **Extract** | Lead | Extract zip+email from DataCorrectionLogic | Same extraction — replace inline zip+email with `BatchReportDeliveryService::deliver()` call. |
| 5 | **Test** | Lead | Unit test BatchReportDeliveryService | Basic service test — zip creation, file cleanup, email dispatch. Mock `CommonUtil::sendMail()`. |
| 6 | **Test** | Lead | Verify DataCorrectionLogic fix via smoke test | Not unit testable — no existing unit tests for commands. Verify monthly plan charges are skipped and missing fields are present by running DataCorrection on DEV04. |
| 7 | **Verify** | Lead | Run Pre + Final + Correction commands on DEV04 | Check: no runtime errors, reports generated, email dispatch logged. |
| 8 | **Verify** | Lead | Collect generated reports/CSVs | Hand off to QA Team for manual verification against expected output. |
| 9 | **Verify** | QA Team | Manual verification of generated reports | Compare against known-good baseline. Confirm no regression from extraction or fix. |

**Duration:** 3–5 days.  
**Blocker:** None — purely internal preparation on existing code.  
**Deliverables:**
- `BatchReportDeliveryService` class (new, shared by all 3 commands)
- DataCorrectionLogic aligned with CommonUtil (skip + fields)
- Baseline documentation (CSV list, smoke test results)
- All 3 commands verified working on DEV04 after changes
- QA manual verification sign-off on generated reports

**NOT in DEVOPS-6415:** DB migrations, models, allocation service, test data seeder, reference prices — those are ASCA Spec 01.

---

### Development Gantt — Full Flow

| Category | Owner | Task / Phase | Week | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **ASCM Refactor** | Lead | Fix DataCorrectionLogic drift (skip + missing fields) | W0 | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Extract BatchReportDeliveryService (3 files — Freee API/report generation extraction) | W0 | ■ | | | | | | | | | | | |
| **ASCM Refactor** | Lead | Unit test extracted service (delivery service extraction) | W0 | ■ | | | | | | | | | | | |
| **ASCM Regression** | Lead | Smoke test: run Pre + Final + Correction on DEV04 (verify no runtime errors) | W0 | ■ | | | | | | | | | | | |
| **ASCM Regression** | Lead | Collect generated CSVs/reports (baseline artifacts) | W0 | ■ | | | | | | | | | | | |
| **ASCM Regression** | QA Team | Manual verification: compare generated reports against expected output | W1 | | ■ | | | | | | | | | | |
| **ASC Shared Foundation** | Dev 1 | DB migrations (10 tables + 1 view) + structure tests | W1–W2 | | ■ | ■ | | | | | | | | | |
| **ASC Shared Foundation** | Lead | Models / enums / run lifecycle service | W2 | | | ■ | | | | | | | | | |
| **ASC Shared Foundation** | Lead | Reference-price master + price resolution service + seeder | W3 | | | | ■ | | | | | | | | |
| **ASC Shared Foundation** | Dev 1 | Allocation engine + ΣN computation + validations | W3–W4 | | | | ■ | ■ | | | | | | | |
| **ASC Shared Foundation** | Lead | Test data seeder (mock CAP/CIP charges) | W3 | | | | ■ | | | | | | | | |
| **ASCA Integration** | Lead | Injection into CommonUtil (Option 1 Overwrite — single Freee API call) | W4 | | | | | ■ | | | | | | | |
| **ASCA Integration** | Dev 1 | CAP Detection Strategy + bundle generation | W4 | | | | | ■ | | | | | | | |
| **ASCA Integration** | Lead | AllocationDetail CSV generation + config | W5 | | | | | | ■ | | | | | | |
| **ASCA Integration** | Dev 1 | DataCorrectionLogic: add `allocateForCharge()` | W5 | | | | | | ■ | | | | | | |
| **ASCA Integration** | Lead + Dev 1 | Refund allocation (record_kind = 1) | W6 | | | | | | | ■ | | | | | |
| **ASCA Integration** | Lead + Dev 1 | ASCA dev testing on DEV04 (full pipeline) | W7 | | | | | | | | ■ | | | | |
| **ASCI Integration** | Dev 1 (or Orlino + Cristoff) | CIP Detection Strategy + reference prices + config | W7–W8 | | | | | | | | ■ | ■ | | | |
| **ASCI Integration** | Lead | ASCI dev testing on DEV04 | W8 | | | | | | | | | ■ | | | |
| **Post-release** | Dev 1 | Reversal (record_kind = 2) | W9 | | | | | | | | | | ■ | | |
| **Buffer** | All | Bug fixes from QA / environment issues | W10–W11 | | | | | | | | | | | ■ | ■ |

### QA Gantt

| Category | Owner | Task / Phase | Week | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| QA | QA Team | ASCM Refactor QA: Manual report verification | W1 | | ■ | | | | | | | | | | |
| QA | QA Team | Test Planning + Strategy | W2–W3 | | | ■ | ■ | | | | | | | | |
| QA | QA Team | Test Case Creation + Data Prep (CAP + CIP) | W3–W5 | | | | ■ | ■ | ■ | | | | | | |
| QA | Miko | Test Execution: ASCA CAP scenarios (10 cases) | W6–W8 | | | | | | | ■ | ■ | ■ | | | |
| QA | Glenn | Test Execution: ASCI CIP scenarios (11 cases) | W8–W9 | | | | | | | | | ■ | ■ | | |
| QA | QA Team | Integration Testing (cross-project, failure isolation) | W9–W10 | | | | | | | | | | ■ | ■ | |
| QA | QA Team | Regression Testing | W10–W11 | | | | | | | | | | | ■ | ■ |
| QA | Dev Team + QA Team | Bug Fix / Retest (ongoing) | W5–W10 | | | | | | ■ | ■ | ■ | ■ | ■ | ■ | |
| QA | QA Team | Release Sign-off | W11 | | | | | | | | | | | | ■ |

### Upstream Teams (Parallel — for context only)

| Category | Owner | Task / Phase | Week | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 | W12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Upstream | CAP Team | CAP project development | W0–W9 | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | | |
| Upstream | CIP Team | CIP project development | W0–W9 | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | | |
| Upstream | CAP + CIP | QA + production deployment | W10–W12 | | | | | | | | | | | ■ | ■ | ■ |
| **ASC** | **Dev Team** | **ASCA/ASCI allocation (this plan)** | **W0–W9** | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | | |
| **ASC** | **QA Team** | **ASC QA + sign-off** | **W6–W11** | | | | | | | ■ | ■ | ■ | ■ | ■ | ■ | |

**Coordination points with upstream:**
- W0–W1: Get plan_ids from upstream teams (needed for detection strategy)
- W6: Need test charges seeded in dev04 (self-seeded or from upstream dev environment)
- Late Nov: Upstream goes to prod → real charges start appearing → validates our logic passively
- Jan 1: First real ASC batch run on real data

---

### Developer Track Detail

**Sequential: ASCM Refactor (DEVOPS-6415) → ASC Shared Foundation → ASCA CAP Integration → ASCI CIP Integration**

| Phase | Weeks | Team Activity | Dependency on Upstream |
|---|---|---|---|
| ASCM Refactor (DEVOPS-6415) | W0 (3–5 days) | Extract delivery service, fix DataCorrectionLogic drift (monthly plan skip + missing fields), baseline verify, test data seeder | None |
| ASC Shared Foundation | W1–W4 | DB, models, engine, injection points, run lifecycle | plan_ids from upstream (W1 latest) |
| ASCA CAP Integration | W4–W7 | Detection, Option 1 Overwrite injection, CSV, refunds | None (uses seeded data) |
| ASCA CAP Dev Testing | W7 | Full DEV04 run (Pre + Final pipeline) | None (seeded data) |
| ASCI CIP Integration | W7–W8 | Plug CIP strategy into working framework | ✅ O-5 resolved (¥88,000 tax-inclusive) |
| ASCI CIP Dev Testing | W8 | DEV04 validation | None (seeded data) |
| Buffer + Reversal | W9–W11 | QA support, reversal (post-release) | None |
| **First real batch** | **Jan 1** | **Run on actual upstream charges** | **Upstream in production** |

**Key rules:**
1. ASCM Refactor (DEVOPS-6415) has NO blockers — can start immediately
2. ASC Shared Foundation needs only O-3 (prefix) and plan_ids — both resolved
3. ASCA and ASCI dev testing uses seeded test data (not real upstream)
4. Real upstream data validation happens passively after upstream goes to prod (late Nov)
5. First real batch (Jan 1) is the true integration test — by then upstream has been live for ~4 weeks
6. Reversal (record_kind = 2) ships post-first-batch — not on critical path

---

### Calendar Mapping (Start: Sep 15)

| Actual Dates | Week | Phase |
|---|---|---|
| Sep 15–19 | W0 | ASCM Refactor (DEVOPS-6415) |
| Sep 22–26 | W1 | ASC Shared Foundation starts (migrations) + ASCM QA verification |
| Sep 29–Oct 3 | W2 | ASC Shared Foundation (models, enums, run lifecycle) |
| Oct 6–10 | W3 | ASC Shared Foundation (engine, reference prices) |
| Oct 13–17 | W4 | ASC Shared Foundation complete + ASCA CAP Integration starts |
| Oct 20–24 | W5 | ASCA CAP Integration (injection, CSV) |
| Oct 27–31 | W6 | ASCA CAP Integration (refunds, allocateForCharge) |
| Nov 3–7 | W7 | ASCA dev testing (DEV04) + ASCI CIP Integration starts |
| Nov 10–14 | W8 | ASCI CIP testing + QA starts CAP scenario testing |
| Nov 17–21 | W9 | QA CAP scenarios |
| Nov 24–28 | W10 | QA CIP scenarios + Integration testing |
| Dec 1–5 | W11 | Regression testing + sign-off |
| Dec 8–12 | — | Buffer |
| **Dec 17** | — | **ASC Deadline** |
| Late Nov–Early Dec | — | **Upstream CAP/CIP goes to production** |
| **Jan 1, 2027** | — | **First real ASC batch run (on real upstream charges)** |

| Milestone | Week | Calendar Date | Notes |
|---|---|---|---|
| ASCM Refactor (DEVOPS-6415) starts | W0 | Sep 15 | Can start anytime — no blocker |
| ASC Shared Foundation starts | W1 | Sep 22 | After ASCM Refactor regression passes |
| ASC Shared Foundation complete | W4 | Oct 13 | |
| ASCA CAP dev complete | W7 | Nov 3 | Tested on seeded data |
| ASCI CIP dev complete | W8 | Nov 10 | Tested on seeded data |
| ASC QA starts | W6 | Oct 27 | |
| Upstream CAP/CIP goes to prod | — | Late Nov / early Dec | Real charges start flowing |
| ASC QA sign-off | W11 | Dec 5–10 | |
| **ASC production release** | — | **Dec 10–12** | **Ready before deadline** |
| **Buffer** | — | **Dec 12–17** | **5 business days** |
| **Deadline** | — | **Dec 17** | |
| First real batch run | — | Jan 1, 2027 | On real upstream charges |

### Calendar Mapping (Start: Oct 1)

| Milestone | Week | Calendar Date | Notes |
|---|---|---|---|
| ASCM Refactor (DEVOPS-6415) starts | W0 | Oct 1 | |
| ASC Shared Foundation starts | W1 | Oct 6 | After ASCM Refactor regression passes |
| ASC Shared Foundation complete | W4 | Oct 27 | |
| ASCA CAP dev complete | W7 | Nov 17 | |
| ASCI CIP dev complete | W8 | Nov 24 | |
| Upstream goes to prod | — | Late Nov / early Dec | |
| ASC QA sign-off | W11 | Dec 15 | |
| **Buffer** | — | **Dec 15–17 (2 days)** | ⚠️ Very tight |
| **Deadline** | — | **Dec 17** | |

⚠️ Starting Oct 1 leaves only 2 business days buffer. Strongly recommend Sep 15 start — this gives a full week of buffer.

---

## QA Timeline (Scenario D)

See QA Gantt above. Summary:

| Phase | Duration | Dependencies |
|---|---|---|
| ASCM Refactor QA: Manual report verification | W1 | After ASCM Refactor smoke test complete |
| Test planning + strategy | W2–W3 | After models known |
| Test case creation + data prep | W3–W5 | After engine working |
| CAP scenario testing (10 cases) | W6–W8 | After CAP dev complete |
| CIP scenario testing (11 cases) | W8–W9 | After CIP dev complete |
| Integration testing | W9–W10 | After both projects complete |
| Regression + sign-off | W10–W11 | After integration |
| Bug fix / retest | W5–W10 (ongoing) | — |

**QA total:** ~7 weeks overlapping with dev. Active testing: W6–W11.

---

## Team Assignments (Scenario D)

| Phase | Lead | Developer | QA |
|---|---|---|---|
| **ASCM Refactor (DEVOPS-6415)** (W0) | Noel Palo | — | QA Team (manual verification at W1) |
| **ASCA** (W1–W7) | Noel Palo | Throy Embudo | Miko (from W6) |
| **ASCI** (W7–W8) | Noel Palo | Orlino Monares + Cristoff Danganan | Glenn (from W8) |

**Difference from Scenario C:** Since injection eliminates infrastructure work, the CAP phase is shorter. This means either:
- (a) Same team (Noel + Throy) builds both CAP and CIP sequentially (6 weeks total)
- (b) After CAP is proven (W7), hand CIP to Orlino + Cristoff (they configure detection + prices using the working CAP as template)

---

## Risk Comparison

| Risk | Scenario C (Standalone) | Scenario D (Injection) |
|---|---|---|
| Existing ASC commands break | Zero — completely separate | LOW — try/catch isolation, ~25 lines added |
| Allocation can't run independently | N/A — standalone command | MITIGATED — add thin debug command |
| Infrastructure not ready by deadline | MEDIUM — must build zip/email/cron from scratch | ELIMINATED — uses existing infrastructure |
| Accounting team confused by new email | MEDIUM — new format, new email to monitor | ZERO — same email, same format |
| Freee journals fail independently | N/A — separate process | LOW — single API call, tracked in deliveries table |
| ASCH patterns don't translate | MEDIUM — never tested at runtime | LOW — we only borrow design concepts, not code |
| CIP reference prices (O-5) | ✅ Resolved — ¥88,000 tax-inclusive (confirmed 2026-08-14) | ✅ Resolved |
| CAP App product_id not decided (O-1) | Blocks CAP detection | ✅ **RESOLVED** (product_id 10021, confirmed 2026-08-12) |

---

## What This Approach Learns from ASCM

The ASCM knowledge base (20 documented issues) taught us specific lessons that Scenario D applies:

| ASCM Lesson | How Scenario D applies it |
|---|---|
| KB #13: Tenant duplication | CAP/CIP is Bizmates-only. No Zipan path to duplicate. |
| KB #14: Pre/Final duplication | Single `AscAllocationService` with `$preFlg`. One codebase, two modes. |
| KB #15: Unsafe delete scope | Delete by `target_ym + project_code`. Never `created_at`. |
| KB #12: Stale aggregation | Clear-and-rebuild within transaction. Idempotent re-runs. |
| KB #10: Pre/Final table mismatch | N source table is explicit config, not implicit convention. |
| KB #16: Global mutable state | Service receives dates as parameters. Doesn't use `CommonUtil::setSystemDate()`. |
| Design Context: "One pipeline, many outputs" | Single service produces both CSVs + Freee entries. No separate pipelines. |
| Design Context: "Tenant = config, not code" | `project_code` column. CAP vs CIP = config, not separate classes. |

**The injection approach is specifically designed to NOT repeat the architectural mistakes we documented during ASCM.**

---

## Lead Dev Assessment

As lead developer who built and maintained the ASCM monthly rate commands through 20+ production issues (ASC-254 to ASC-311), my assessment:

**Scenario D (injection) is the better approach for this project.** Here's why:

1. **We've done this exact pattern before.** The MonthlyRateCalculation was injected into `DailyRateCalculationPreLogic` in exactly this way. It's been running in production since June 2026 without incident. The pattern is proven.

2. **The infrastructure already exists and is battle-tested.** The zip/email/Freee API/access token/error handling code has been running monthly for 2+ years. Building a parallel version introduces new failure modes that don't exist today.

3. **ASCM taught us that complexity kills.** Every time we added a new moving part (separate Pre/Final classes, separate tenant paths, separate CSV generation steps), we got bugs. The injection approach adds one service call — not new moving parts.

4. **The accounting team shouldn't need to change their workflow.** They check one email, open one zip, verify CSVs. Adding new CSVs to the existing package is invisible to their process. A second email creates confusion and risk of missed data.

5. **3 weeks saved is 3 weeks of buffer.** With a Dec 17 deadline and a history of QA finding edge cases, extra buffer time is worth more than architectural purity. We can always extract to standalone commands later if needed — but we can't get back lost weeks.

6. **The "disadvantage" (can't re-run alone) has a clean mitigation.** A thin debug command (`php artisan asc:allocation-debug {exeDate} {--project=cap}`) that calls the same `AscAllocationService` directly — bypassing the daily rate calculation step. This is a 15-line artisan command (argument parsing + service call) that we include as part of the standard implementation, not an afterthought.

**Bottom line:** Scenario C solves a problem we don't have (operational independence) at a cost we can't afford (3 extra weeks). Scenario D solves the actual problem (calculate allocation, send to Freee, report in CSV) by riding on infrastructure that already works.

---

## Decision Requested

| # | Question for Patrick-san / Kuroda-san | Options |
|---|---|---|
| 1 | Which approach? | Scenario C (standalone — master timeline) or **Scenario D (injection — this proposal)** |
| 2 | Execution order? | **CAP first** → CIP second (agreed across all scenarios) |
| 3 | O-3 table prefix? | `asc_alloc_*` (recommended — same in both scenarios) |
| 4 | Start date? | Earliest: once O-3 decided |

---

## Key Dates (Scenario D)

| Date | Event |
|---|---|
| 2026/08/11 | Scenario D proposal created |
| TBD | Decision: Scenario C vs D |
| TBD | O-3 prefix decided → development unblocked |
| ~W7 after start | ASCA CAP dev complete (allocation working, CSVs in zip, Freee sending) |
| ~W8 after start | ASCI CIP dev complete (CIP detection + prices configured) |
| ~W10–11 after start | QA complete + sign-off |
| **2026/12/17** | **Production deadline** |
| **2027/01/01** | **First production batch run** |

If started **mid-September** → dev complete by early November → QA through November → buffer December → deadline met with margin.

If started **early October** → even more compressed. Scenario D gives scheduling flexibility that Scenario C cannot.

---

## Source Doc