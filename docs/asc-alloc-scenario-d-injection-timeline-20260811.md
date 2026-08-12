# ASC Allocation Framework — Scenario D (Injection Approach)

**Date:** 2026-08-11  
**Author:** Noel Palo, Lead Developer  
**Assisted by:** Kiro (AI-assisted analysis, code review, and document generation)  
**Status:** PROPOSAL — alternative integration strategy. For review with Patrick-san and Kuroda-san.  
**Context:** Based on ASCM experience and code analysis of existing accounting commands.

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
| Freee sending | Dedicated thin sender (new, Step 7) | 2nd API call within existing SendJournalsDataLogic |
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
| CIP blocker | O-5 (CIP reference prices) still open — blocks CIP finalize |
| Team familiarity | Coaching+App bundle better understood from ASCH research |
| Business urgency | Equal — but CAP is more concrete today |

**Practical reality:** Whichever goes first carries the full infrastructure cost. The order doesn't change the total. But CAP's requirements are more concrete today, which reduces the risk of building foundation on assumptions that later change.

**Recommendation:** Start with CAP. If CIP requirements firm up first, swap — the foundation is project-agnostic anyway (`project_code` column).

---

## Estimate (Scenario D — Injection Approach)

| Metric | Value | Confidence |
|---|---|---|
| **CAP Dev Effort (incl. shared foundation)** | 4–5 weeks (Noel + Throy) | Medium-High — code analyzed, injection points identified |
| **CIP Dev Effort (reuses foundation)** | 1–1.5 weeks (same team or Orlino + Cristoff) | High — only adds strategy + config |
| **Total Dev Effort** | 5.5–6.5 weeks | Medium-High |
| **QA Effort** | 4–5 weeks (overlapping with dev) | Medium |
| **End-to-end** | 7–9 weeks | Medium |
| **Deadline** | 2026/12/17 | Fixed |
| **Latest start to fit deadline** | Early October | High |
| **First production run** | 2027/01/01 | Fixed |

### Why Shorter Than Scenario C (9–12 weeks → 5.5–6.5 weeks)

| Saved effort | Days saved | Reason |
|---|---|---|
| No unified email orchestrator (Step 8 in Scenario C) | 5 days | Uses existing email. CSVs added to existing zip. |
| No dedicated Freee thin sender (Step 7 in Scenario C) | 4 days | 2nd API call within existing `sendFreeeJournals2()`. Reuses `splitDetailListWithBalance`. |
| No command skeleton / cron setup | 2 days | No new commands. Injection into existing ones. |
| No zip/archive infrastructure | 2 days | Existing `createSendMailAttacheFile()` handles it (with extracted service). |
| Simpler testing (E2E = run existing command) | 3 days | No separate command integration tests needed. |
| **Total saved** | **~16 days (~3 weeks)** | |


---

## Implementation Steps (Scenario D)

| # | Step | Blocked by | Est. duration | Notes vs Scenario C |
|---|---|---|---|---|
| 0 | Extract BatchReportDeliveryService | None | 1–2 days | NEW — not in Scenario C. Low-risk extraction. |
| 1 | O-3 decision + 10 migrations + structure tests | O-3 (prefix) | 1 week | Same as Scenario C Step 1 |
| 2 | Models, enums, run lifecycle service | None | 3–4 days | Same as Scenario C Step 2 |
| 3 | Reference-price master + price resolution | None | 2–3 days | Same as Scenario C Step 3 |
| 4 | CAP Detection Strategy + bundle generation | ~~O-1 (CAP App product_id)~~ (O-1 RESOLVED: product_id 10021) | 3–4 days | Same as Scenario C Step 4 |
| 5 | Allocation engine + validations V-1 to V-5 | None | 4–5 days | Same as Scenario C Step 5 |
| 6 | Injection: DailyRateCalcPre + SendJournals | Steps 1–5 | 2 days | **REPLACES** Scenario C Steps 7–8 (Freee sender + email orchestrator) |
| 7 | 2nd Freee API call + delivery tracking | Step 6 | 3–4 days | Simpler than Scenario C Step 7 — reuses existing API util |
| 8 | CSV generation (detail + summary) | Step 6 | 2–3 days | Simpler than Scenario C Step 8 — adds to existing zip |
| 9 | Refund allocation (record_kind = 1) | Step 5 | 3–4 days | Same as Scenario C Step 6 |
| 10 | CIP Detection Strategy + config | Steps 1–5 done, O-5 | 3–5 days | Same concept — plug CIP into existing framework |
| 11 | Reversal (record_kind = 2) | O-4 | 3–4 days | Same as Scenario C Step 9 (post-release OK) |

**Steps 0–5 are unblocked now** (pending O-3 only). Steps 6–8 follow immediately.

### Critical Path

```
O-3 decision → Step 1 (migrations) → Steps 2–5 (parallel tracks) → Step 6 (injection) → Steps 7–8 → CAP complete
                                                                                           ↓
                                                                                    Step 10 (CIP) → CIP complete
```

---

## Gantt View — Scenario D (CAP First)

**Deadline:** 2026/12/17 (ASC production). First ASC batch run: 2027/01/01.  
**Upstream CAP/CIP projects:** Production late Nov / early Dec (provides upstream data to ASC).  
**Working backwards:** ASC QA sign-off by ~Dec 10. ASC dev complete by ~Nov 21.

### Parallel Development Model

```
Upstream (other teams):
  CAP project  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ → Prod: late Nov / early Dec
  CIP project  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ → Prod: late Nov / early Dec

ASC Team (Noel's team — this plan):
  ASCM Prep    ━━━━┓
  Foundation        ┣━━━━━━━━━━━━━━┓
  ASC-CAP                          ┣━━━━━━━━━━━━━━┓
  ASC-CIP                                         ┣━━━━┓
  QA                                                    ┣━━━━━━━━━━ → Dec 17 deadline
```

### Can ASC Develop Alongside Upstream?

**Yes.** Here's what ASC needs from upstream and WHEN:

| What ASC needs from upstream | When ASC needs it | When upstream delivers it | Blocked? |
|---|---|---|---|
| Upstream DB schema (tables that produce charges) | Not needed — ASC reads existing `trn_charge` + `log_daily_rate_calculation` | Already exists | ❌ No |
| Plan IDs for CAP/CIP products | Step 4 (detection strategy) — W3 | CAP/CIP teams define plan_ids early in their design | ⚠️ Maybe — ask early |
| Reference prices (L values) | Step 3 (reference price seeder) — W2 | Business/accounting decision — independent of dev | ⚠️ Open item O-5 |
| Actual charges in dev04 for testing | W6 (CAP dev testing) | Upstream charges appear when their product goes live | ⚠️ Need test data seeder |
| Upstream in production (real charges flowing) | Post-release (first real batch run Jan 1) | Late Nov / early Dec | ❌ No — we don't need upstream prod for OUR release |

**Key insight:** ASC-CAP/CIP calculates allocation on charges that ALREADY EXIST in `trn_charge`. The upstream projects create those charges. But for development and QA, we can seed test charges ourselves. We only need real upstream data for the first production batch run (Jan 1, 2027) — NOT for our Dec 17 release.

**Conclusion:** ASC development is NOT blocked by upstream CAP/CIP timelines. We can build and test the allocation engine independently using seeded test data. When upstream goes live (late Nov / early Dec), real charges start flowing, and our Jan 1 batch picks them up.

### Can ASC Finish Earlier Than Dec 17?

**Yes — dev can be complete by early November.** The Dec 17 deadline is for production readiness including QA sign-off. Dev completion (code done, DEV04 tested) can happen 4–6 weeks before that.

| Scenario | Dev complete | QA complete | Buffer |
|---|---|---|---|
| Start Sep 15 | Oct 27 (W6) | Dec 5 (W11) | 12 days |
| Start Sep 22 | Nov 3 (W6) | Dec 10 (W11) | 7 days |
| Start Oct 1 | Nov 10 (W6) | Dec 12 (W11) | 3 days ⚠️ |

---

### Assumed Start: 2026/09/15 (Monday)

| Actual Dates | Week | Phase |
|---|---|---|
| Sep 8–12 | Pre-W0 | ASCM Prep (can start before formal project kickoff) |
| Sep 15–19 | W0 | ASCM Prep + Foundation start |
| Sep 22–26 | W1 | Foundation |
| Sep 29–Oct 3 | W2 | Foundation |
| Oct 6–10 | W3 | Foundation + CAP starts |
| Oct 13–17 | W4 | CAP |
| Oct 20–24 | W5 | CAP |
| Oct 27–31 | W6 | CAP dev testing + CIP starts |
| Nov 3–7 | W7 | CIP + QA starts CAP testing |
| Nov 10–14 | W8 | QA CAP + QA CIP starts |
| Nov 17–21 | W9 | QA CIP |
| Nov 24–28 | W10 | Integration testing |
| Dec 1–5 | W11 | Regression + sign-off |
| Dec 8–12 | W12 | Buffer |
| **Dec 17** | — | **ASC Deadline** |
| Late Nov–Early Dec | — | **Upstream CAP/CIP goes to production** |
| **Jan 1, 2027** | — | **First real ASC batch run (on real upstream charges)** |

---

### ASCM Prep / Refactor Gantt (Pre-W0)

Work that should happen BEFORE the allocation project starts. Can begin immediately — no blockers.

| Category | Owner | Task / Phase | Week | Pre-W0 | W0 |
|---|---|---|---|---|---|
| **ASCM Refactor** | Lead | Extract BatchReportDeliveryService from DailyRateCalcPre + SendJournals | Pre-W0 | ■ | |
| **ASCM Refactor** | Lead | Unit test the extracted service (zip creation, email dispatch) | Pre-W0 | ■ | |
| **ASCM Verify** | Lead | Smoke test: run existing Pre + Final commands on DEV04 (baseline before changes) | Pre-W0 | ■ | |
| **ASCM Verify** | Lead | Document baseline CSV file list (what's in the zip today) | Pre-W0 | ■ | |
| **ASCM Prep** | Dev 1 | Review Kuroda-san DB design, prepare migration plan, confirm O-3 | Pre-W0 | ■ | |
| **ASCM Prep** | Lead | Create test data seeder for CAP/CIP charges (mock upstream data for dev04) | W0 | | ■ |

**Duration:** 3–5 days (can overlap with O-3 decision waiting period).  
**Blocker:** None — this is purely internal preparation on existing code.  
**Deliverable:** Working `BatchReportDeliveryService` + baseline verification + test data ready.

**Why do this first:**
- Proves the extraction works before we inject anything new
- Creates a clean "before" snapshot for comparison
- Test data seeder means we don't wait for upstream teams to populate dev04
- O-3 decision can happen in parallel

---

### Development Gantt (Main Build)

| Category | Owner | Task / Phase | Week | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Foundation** | Dev 1 | DB migrations (10 tables + 1 view) + structure tests | W0–W1 | ■ | ■ | | | | | | | | |
| **Foundation** | Lead | Models / enums / run lifecycle service | W1 | | ■ | | | | | | | | |
| **Foundation** | Lead | Reference-price master + price resolution service | W2 | | | ■ | | | | | | | |
| **Foundation** | Dev 1 | Allocation engine + validations V-1 to V-5 | W2–W3 | | | ■ | ■ | | | | | | |
| **Foundation** | Lead | Injection: wire into DailyRateCalcPre + SendJournals | W3 | | | | ■ | | | | | | |
| **ASC-CAP** | Dev 1 | CAP Detection Strategy + bundle generation | W3 | | | | ■ | | | | | | |
| **ASC-CAP** | Lead | 2nd Freee API call + journal entry builder + delivery tracking | W4 | | | | | ■ | | | | | |
| **ASC-CAP** | Dev 1 | CSV generation (detail + summary) + config entries | W4 | | | | | ■ | | | | | |
| **ASC-CAP** | Lead + Dev 1 | Refund allocation (record_kind = 1) | W5 | | | | | | ■ | | | | |
| **ASC-CAP** | Lead + Dev 1 | ASC-CAP dev testing on DEV04 (full pipeline with seeded data) | W6 | | | | | | | ■ | | | |
| **ASC-CIP** | Dev 1 (or Dev 2) | CIP Detection Strategy + reference prices + config | W6–W7 | | | | | | | ■ | ■ | | |
| **ASC-CIP** | Lead | ASC-CIP dev testing on DEV04 | W7 | | | | | | | | ■ | | |
| **Post-release** | Dev 1 | Reversal (record_kind = 2) — ships after first prod run | W8 | | | | | | | | | ■ | |
| **Buffer** | All | Bug fixes from QA / environment issues / holidays | W8–W9 | | | | | | | | | ■ | ■ |

### QA Gantt

| Category | Owner | Task / Phase | Week | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| QA | QA Team | Test Planning + Strategy | W2–W3 | | | ■ | ■ | | | | | | | | |
| QA | QA Team | Test Case Creation + Data Prep (CAP + CIP) | W3–W5 | | | | ■ | ■ | ■ | | | | | | |
| QA | Miko | Test Execution: ASC-CAP scenarios (10 cases) | W6–W8 | | | | | | | ■ | ■ | ■ | | | |
| QA | Glenn | Test Execution: ASC-CIP scenarios (11 cases) | W8–W9 | | | | | | | | | ■ | ■ | | |
| QA | QA Team | Integration Testing (cross-project, failure isolation) | W9–W10 | | | | | | | | | | ■ | ■ | |
| QA | QA Team | Regression Testing | W10–W11 | | | | | | | | | | | ■ | ■ |
| QA | Dev + QA | Bug Fix / Retest (ongoing) | W5–W10 | | | | | | ■ | ■ | ■ | ■ | ■ | ■ | |
| QA | QA Team | Release Sign-off | W11 | | | | | | | | | | | | ■ |

### Upstream Teams (Parallel — for context only)

| Category | Owner | Task / Phase | Week | W0 | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 | W12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Upstream | CAP Team | CAP project development | W0–W9 | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | | |
| Upstream | CIP Team | CIP project development | W0–W9 | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | | |
| Upstream | CAP + CIP | QA + production deployment | W10–W12 | | | | | | | | | | | ■ | ■ | ■ |
| **ASC** | **Noel's team** | **ASC-CAP/CIP allocation (this plan)** | **W0–W9** | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | |
| **ASC** | **QA** | **ASC QA + sign-off** | **W6–W11** | | | | | | | ■ | ■ | ■ | ■ | ■ | ■ | |

**Coordination points with upstream:**
- W0–W1: Get plan_ids from upstream teams (needed for detection strategy)
- W6: Need test charges seeded in dev04 (self-seeded or from upstream dev environment)
- Late Nov: Upstream goes to prod → real charges start appearing → validates our logic passively
- Jan 1: First real ASC batch run on real data

---

### Developer Track Detail

**Sequential: ASCM prep → Foundation → ASC-CAP → ASC-CIP**

| Phase | Weeks | Team Activity | Dependency on Upstream |
|---|---|---|---|
| ASCM Prep | Pre-W0 (3–5 days) | Extract delivery service, baseline verify, test data seeder | None |
| Shared Foundation | W0–W3 | DB, models, engine, injection points, run lifecycle | plan_ids from upstream (W1 latest) |
| ASC-CAP Integration | W3–W5 | Detection, Freee send, CSV, refunds | None (uses seeded data) |
| ASC-CAP Dev Testing | W6 | Full DEV04 run (Pre + Final pipeline) | None (seeded data) |
| ASC-CIP Integration | W6–W7 | Plug CIP strategy into working framework | CIP reference prices (O-5) |
| ASC-CIP Dev Testing | W7 | DEV04 validation | None (seeded data) |
| Buffer + Reversal | W8–W9 | QA support, reversal (post-release) | None |
| **First real batch** | **Jan 1** | **Run on actual upstream charges** | **Upstream in production** |

**Key rules:**
1. ASCM prep has NO blockers — can start immediately
2. Foundation needs only O-3 (prefix) and plan_ids
3. ASC-CAP and ASC-CIP dev testing uses seeded test data (not real upstream)
4. Real upstream data validation happens passively after upstream goes to prod (late Nov)
5. First real batch (Jan 1) is the true integration test — by then upstream has been live for ~4 weeks
6. Reversal (record_kind = 2) ships post-first-batch — not on critical path

---

### Calendar Mapping (Start: Sep 15)

| Milestone | Week | Calendar Date | Notes |
|---|---|---|---|
| ASCM prep starts | Pre-W0 | Sep 8 | Can start anytime — no blocker |
| ASC-CAP/CIP dev starts | W0 | Sep 15 | Needs O-3 decided |
| Foundation complete | W3 | Oct 6 | |
| ASC-CAP dev complete | W6 | Oct 27 | Tested on seeded data |
| ASC-CIP dev complete | W7 | Nov 3 | Tested on seeded data |
| ASC QA starts | W6 | Oct 27 | |
| Upstream CAP/CIP goes to prod | — | Late Nov / early Dec | Real charges start flowing |
| ASC QA sign-off | W11 | Dec 5–10 | |
| **ASC production release** | **W12** | **Dec 10–12** | **Ready before deadline** |
| **Buffer** | — | **Dec 12–17** | **5 business days** |
| **Deadline** | — | **Dec 17** | |
| First real batch run | — | Jan 1, 2027 | On real upstream charges |

### Calendar Mapping (Start: Oct 1)

| Milestone | Week | Calendar Date | Notes |
|---|---|---|---|
| ASCM prep starts | Pre-W0 | Sep 22 | 1 week before formal start |
| ASC-CAP/CIP dev starts | W0 | Oct 1 | |
| Foundation complete | W3 | Oct 20 | |
| ASC-CAP dev complete | W6 | Nov 10 | |
| ASC-CIP dev complete | W7 | Nov 17 | |
| Upstream goes to prod | — | Late Nov / early Dec | |
| ASC QA sign-off | W11 | Dec 12 | |
| **Buffer** | — | **Dec 12–17 (3 days)** | ⚠️ Tight |
| **Deadline** | — | **Dec 17** | |

⚠️ Starting Oct 1 leaves only 3 business days buffer. Strongly recommend Sep 15 start — this gives a full week of buffer AND allows ASCM prep to happen in the preceding week.


---

## QA Timeline (Scenario D)

See QA Gantt above. Summary:

| Phase | Duration | Dependencies |
|---|---|---|
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
| **CAP** (first — W1–W5) | Noel Palo | Throy Embudo | Miko (from W5) |
| **CIP** (second — W6) | Noel Palo | Throy (or Orlino + Cristoff) | Glenn (from W7) |

**Difference from Scenario C:** Since injection eliminates infrastructure work, the CAP phase is shorter. This means either:
- (a) Same team (Noel + Throy) builds both CAP and CIP sequentially (6 weeks total)
- (b) After CAP is proven (W5), hand CIP to Orlino + Cristoff (they configure detection + prices using the working CAP as template)

---

## Risk Comparison

| Risk | Scenario C (Standalone) | Scenario D (Injection) |
|---|---|---|
| Existing ASC commands break | Zero — completely separate | LOW — try/catch isolation, ~25 lines added |
| Allocation can't run independently | N/A — standalone command | MITIGATED — add thin debug command |
| Infrastructure not ready by deadline | MEDIUM — must build zip/email/cron from scratch | ELIMINATED — uses existing infrastructure |
| Accounting team confused by new email | MEDIUM — new format, new email to monitor | ZERO — same email, same format |
| Freee journals fail independently | N/A — separate process | LOW — 2nd API call, tracked in deliveries table |
| ASCH patterns don't translate | MEDIUM — never tested at runtime | LOW — we only borrow design concepts, not code |
| CIP reference prices arrive late (O-5) | Blocks CIP finalize | Same — but CIP is last anyway |
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
| ~W5 after start | CAP dev complete (allocation working, CSVs in zip, Freee sending) |
| ~W6 after start | CIP dev complete (CIP detection + prices configured) |
| ~W8–9 after start | QA complete + sign-off |
| **2026/12/17** | **Production deadline** |
| **2027/01/01** | **First production batch run** |

If started **early October** → dev complete by early November → QA through November → buffer December → deadline met with margin.

If started **mid-September** → even more buffer. Scenario D gives scheduling flexibility that Scenario C cannot.

---

## Source Documents

| Document | What it is |
|---|---|
| `asc-projects-master-timeline.md` | Scenario C: current plan (standalone, CAP first) |
| `asc-cap-cip-combined-estimate-20260808.md` | Effort estimate for Scenario C |
| `asc-alloc-integration-discussion-notes-20260811.md` | Technical design session notes for Scenario D |
| `diagrams/asc-alloc-injection-process-flow.md` | Process + data flow diagram for Scenario D |
| `REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md` | Kuroda-san's DB design (applies to both scenarios) |
| `projects/ascm/knowledge-base/` | ASCM lessons learned (informed this proposal) |
