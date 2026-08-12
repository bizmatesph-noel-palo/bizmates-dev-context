# ASC for CAP & CIP — Revised Estimation (Post-ASCH Cancellation)

## Document Info

| | |
|---|---|
| **Document type** | Project Estimation (Revised) |
| **Date** | 2026-08-08 |
| **Author** | Noel Palo, Lead Developer |
| **Audience** | Kuroda-san (PM), Patrick-san (SDM), QA Team |
| **Status** | TENTATIVE — pending updated requirements from Kuroda-san |
| **Context** | ASCH project cancelled (2026-08-07). CAP and CIP proceed without ASCH as prerequisite. Requirements not yet confirmed for this new context. |

---

## Executive Summary

With ASCH cancelled, the shared infrastructure that CAP and CIP were going to inherit must now be built directly. The recommended approach is a **combined ASC Allocation Framework** (Scenario C) where both CAP and CIP are configurations of a single generic system. This saves 4–5 weeks vs building them as separate projects.

**⚠️ This estimate is rough/tentative.** It's based on previous CAP/CIP research (July 2026) which assumed ASCH exists. With ASCH gone, the scope may change once Kuroda-san provides updated requirements and design.

| Metric | Value | Confidence |
|---|---|---|
| **CAP Dev Effort (incl. shared foundation)** | 6–8 weeks (Noel + Throy) | Low — pending requirements |
| **CIP Dev Effort (reuses foundation)** | 3–4 weeks (Orlino + Cristoff, Noel oversees) | Low — pending requirements |
| **Total Dev Effort (sequential)** | 9–12 weeks | Low |
| **Total QA Effort** | 5–7 weeks (overlaps with dev) | Low — scenarios not confirmed |
| **Combined Timeline (dev + QA)** | 10–13 weeks end-to-end | Low |
| **Deadline** | 2026/12/17 | Fixed |
| **Latest start to fit deadline** | ~Mid-September | Medium |
| **Execution model** | Sequential: CAP first (builds foundation), CIP second (reuses it) | Confirmed (Kuroda-san 2026-08-08) |
| **Feasible?** | ✅ Yes — if requirements confirmed and started by mid-Sept | |

### What's Blocking Finalization

1. Updated requirements from Kuroda-san (CAP/CIP without ASCH context)
2. Confirmation: does the allocation formula stay the same?
3. Confirmation: how is App bundled in CAP/CIP now?
4. Design updates from Kuroda-san
5. Start date decision

---

## What Changed (ASCH Cancellation Impact)

| Before (with ASCH) | After (without ASCH) |
|---|---|
| ASCH provides proven run management, Freee sender, CSV/email | Must build infrastructure as part of CAP/CIP |
| CAP estimate: 6–7 weeks (reusing ASCH patterns) | CAP estimate: 8–9 weeks (building infrastructure in-place) |
| CIP estimate: 6–7 weeks (reusing ASCH/CAP patterns) | CIP estimate: 5–6 weeks (reuses CAP infrastructure) |
| Sequential: ASCH → CAP → CIP | No ASCH prerequisite — CAP and CIP can start immediately |

**Key insight:** CAP and CIP use the **exact same formula**. Only reference prices and plan_id detection differ. Building them as a single framework eliminates duplication.

---

## Recommended Approach: Scenario C (Combined Framework)

### Why Combined?

```
CAP formula:  App_alloc = N × App_ref / (Coaching_ref + App_ref)
CIP formula:  App_alloc = N × App_ref / (Coaching_ref + App_ref)
```

Same formula. Same operational model. Same Freee sending. Same CSV format. Different config values.

### Architecture

```
ASC Allocation Framework (generic):
├── Run management (create/finalize/supersede — any project)
├── Source document snapshotting (audit)
├── Allocation calculation engine (configurable ratio)
├── Sum calculation + Freee sending (T1 journals, per-project)
├── CSV generation + unified email delivery
└── DB tables: asc_alloc_* (shared structure, project_code column)

CAP (configuration):
├── plan_id detection → which charges are CAP
├── Reference prices: App=¥3,980, Coaching=per-plan lookup
├── Scenarios: ~10 acceptance cases

CIP (configuration):
├── plan_id detection → which charges are CIP  
├── Reference prices: App=TBD, Coaching=TBD
├── Scenarios: ~11 acceptance cases
```

---

## Development Estimate (Scenario C)

### Phase Breakdown

| # | Phase | Scope | Duration | Team | CAP side | CIP side |
|---|---|---|---|---|---|---|
| 1 | **Shared Foundation** | DB tables (~6 generic `asc_alloc_*` tables), run lifecycle service, command skeleton, 3-transaction model, models, enums | 2 weeks | Lead + 2 devs | ⚪︎ | × |
| 2 | **Allocation Engine** | Generic formula implementation, rounding (floor), invariant validation (App + Coaching = N), configurable reference prices | 1.5 weeks | Lead + 2 devs | ⚪︎ | × |
| 3 | **CAP Integration** | CAP plan_id detection, CAP reference prices, CAP-specific eligibility rules, N source reading | 1 week | Lead + 1 dev | ⚪︎ | × |
| 4 | **CIP Integration** | CIP plan_id detection, CIP reference prices, CIP-specific eligibility rules (B2B from day 1) | 1 week | Lead + 1 dev | × | ⚪︎ |
| 5 | **Scenarios (both)** | Refund, plan change, contract-type change, cooling-off, suspension, post-release correction | 2 weeks | Lead + 2 devs | ⚪︎ | × |
| 6 | **Freee + CSV + Email** | Journal factory (T1), Freee API, detail CSV, summary CSV, unified email orchestrator | 1.5 weeks | Lead + 2 devs | ⚪︎ | × |
| 7 | **Buffer** | PR reviews, gate rejections, environment issues, bugs, holidays | 1–2 weeks | — | ⚪︎ | ⚪︎ |
| | **Total Dev** | | **10–12 weeks** | Lead + 2 devs | — | — |

### Optimistic vs Conservative

| | Optimistic | Conservative |
|---|---|---|
| Dev | 8 weeks | 11 weeks |
| QA (overlapping) | 5 weeks | 7 weeks |
| End-to-end | 10 weeks | 13 weeks |

---

## QA Estimate

### QA Phase Breakdown

| # | Phase | Scope | Duration | Dependencies |
|---|---|---|---|---|
| Q1 | **Test Planning** | Review requirements, define test scenarios, prepare test data | 1 week | After Phase 1 (foundation) complete |
| Q2 | **CAP Scenario Testing** | Execute ~10 acceptance scenarios, validate CSV output against fixtures, verify Freee journals | 2 weeks | After Phase 3 (CAP integration) complete |
| Q3 | **CIP Scenario Testing** | Execute ~11 acceptance scenarios, validate CSV output, verify Freee journals | 2 weeks | After Phase 4 (CIP integration) complete |
| Q4 | **Integration Testing** | Unified email delivery (both projects in one email), failure isolation verification, cross-project independence | 1 week | After Phase 6 (Freee + CSV) complete |
| Q5 | **Regression / UAT** | End-to-end validation, accounting team sign-off, production-readiness check | 1 week | After all dev complete |
| | **Total QA** | | **5–7 weeks** | Overlaps with dev from Q1 onward |

### QA Acceptance Scenarios

#### CAP Scenarios (~10)

| # | Scenario | What to verify |
|---|---|---|
| 1 | Standard Coaching 30-min + App (full month) | Correct allocation ratio, P values, adjustment |
| 2 | Coaching 15-min + App (full month) | Different reference price, correct ratio |
| 3 | Mid-month start (partial month) | Day-prorated allocation correct |
| 4 | Refund before proration (same-month cooling-off) | Refund not prorated |
| 5 | Refund after proration (cross-month) | Refund prorated with original ratio |
| 6 | Plan change (15-min → 30-min) | New reference price, new allocation |
| 7 | Contract type change (B2C → B2E) | Freee journal dimensions change |
| 8 | Coaching suspension | Allocation stops, App removed |
| 9 | Preview vs Final N source | Preview reads _pre, Final reads confirmed |
| 10 | Revision run (supersession) | Previous run superseded, delta journal correct |

#### CIP Scenarios (~11)

| # | Scenario | What to verify |
|---|---|---|
| 1 | Standard CIP Coaching + App (full month, B2C) | Correct allocation, correct Freee mapping |
| 2 | Standard CIP (full month, B2E) | Department/partner dimensions correct |
| 3 | Standard CIP (full month, B2B) | Order_no populated, B2B Freee dimensions |
| 4 | Mid-month start | Day-prorated allocation |
| 5 | Refund same-month (cooling-off) | Not prorated |
| 6 | Refund cross-month | Prorated with original ratio |
| 7 | Plan change (to/from CIP plan) | Allocation starts/stops correctly |
| 8 | Contract type change | Freee dimensions update |
| 9 | Suspension | Allocation stops |
| 10 | Post-release correction (revision run) | Delta journal, supersession |
| 11 | Preview vs Final | N source selection correct |

#### Integration Scenarios

| # | Scenario | What to verify |
|---|---|---|
| 1 | Both CAP and CIP succeed | Single email with both project CSVs, correct summary table |
| 2 | CAP fails, CIP succeeds | Email sent with CIP CSVs only, CAP status = "failed" in body |
| 3 | Both fail | Email sent with no CSVs, both statuses = "failed" |
| 4 | CAP revision doesn't affect CIP | CIP Freee journals unchanged when CAP re-runs |
| 5 | Unified email body format | Per-project summary table (status, records, amount, validation) |

### QA Deliverables

| Deliverable | Format | When |
|---|---|---|
| Test plan document | Markdown (in bizmates-dev-context) | After Phase 1 |
| CAP test case matrix | Spreadsheet / Markdown table | After Phase 3 |
| CIP test case matrix | Spreadsheet / Markdown table | After Phase 4 |
| CSV fixture files (expected output) | CSV files (accounting-approved) | Before scenario execution |
| Bug reports | JIRA tickets | During Q2–Q5 |
| Sign-off report | Summary document | End of Q5 |

### QA Environment Requirements

| Requirement | Details |
|---|---|
| Test database | dev04 with sample Coaching+App charges for both CAP and CIP plans |
| Freee sandbox | Test environment for journal verification |
| Sample N values | Pre-populated `log_daily_rate_calculation` rows for test charges |
| Expected CSV fixtures | Accounting-team-provided expected output files |

---

## Timeline (Combined Dev + QA)

### With 2 developers + 1 QA

```
Week 1-2:   [DEV] Shared Foundation
Week 2:     [QA]  Test planning starts (overlapping)
Week 3-4:   [DEV] Allocation Engine + CAP Integration
Week 4-5:   [QA]  CAP scenario testing
Week 5-6:   [DEV] CIP Integration + Scenarios
Week 6-7:   [QA]  CIP scenario testing
Week 7-8:   [DEV] Freee + CSV + Email
Week 8-9:   [QA]  Integration testing
Week 9-10:  [DEV] Buffer + bug fixes from QA
Week 10:    [QA]  Regression / UAT + sign-off
```

**Start: TBD (pending requirements) → End: ~10 weeks after start** (10 weeks)  
**Latest start to fit Dec 17:** ~Mid-September  
**Buffer to Dec 17 (if started mid-Sept):** ~3–4 weeks

### With 2 developers + 2 QA (parallel CAP/CIP QA)

```
Week 1-2:   [DEV] Shared Foundation + [QA] Test planning
Week 3-4:   [DEV] Allocation Engine + CAP
Week 4-5:   [DEV] CIP + Scenarios + [QA1] CAP testing + [QA2] prep CIP
Week 6-7:   [DEV] Freee + CSV + [QA2] CIP testing
Week 7-8:   [DEV] Buffer + [QA] Integration testing
Week 8-9:   [QA] Regression + sign-off
```

**Start: TBD → End: ~8 weeks after start**  
**Latest start to fit Dec 17:** ~Mid-October

### Gantt View — Development (Lead + 2 Devs)

**Note:** Dates below are relative (W1 = first week of development). Actual dates TBD pending start date confirmation.

| Category | Owner | Task / Phase | Week | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Development | Lead | Requirements / design / task generation (ongoing) | W1–W8 | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | |
| Development | Dev 1 | Shared Foundation: DB migrations (tables + FK + UK + structure tests) | W1–W2 | ■ | ■ | | | | | | | | |
| Development | Dev 2 | Shared Foundation: Models / enums / run lifecycle / command skeleton | W1–W2 | ■ | ■ | | | | | | | | |
| Development | Dev 1 | Allocation Engine: Formula, rounding, invariant validation | W3–W4 | | | ■ | ■ | | | | | | |
| Development | Dev 2 | CAP Integration: Plan detection, reference prices, eligibility | W3–W4 | | | ■ | ■ | | | | | | |
| Development | Dev 1 | CIP Integration: Plan detection, reference prices, B2B support | W5–W6 | | | | | ■ | ■ | | | | |
| Development | Dev 2 | Scenarios: Refund, plan change, contract-type change (CAP) | W5–W6 | | | | | ■ | ■ | | | | |
| Development | Dev 1 | Scenarios: Cooling-off, suspension, correction (CIP) | W7–W8 | | | | | | | ■ | ■ | | |
| Development | Dev 2 | Freee + CSV + Unified Email Orchestrator | W7–W8 | | | | | | | ■ | ■ | | |
| Development | Lead + Dev | Dev Testing & Validation (DEV04 full run, both projects) | W9 | | | | | | | | | ■ | |
| Buffer | All | Bug fixes from QA / environment issues / holidays | W10 | | | | | | | | | | ■ |

### Gantt View — QA

| Category | Owner | Task / Phase | Week | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 | W11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| QA | QA Team | Test Planning + Strategy | W2 | | ■ | | | | | | | | | |
| QA | QA Team | Test Case Creation + Data Prep (CAP + CIP) | W3–W5 | | | ■ | ■ | ■ | | | | | | |
| QA | QA (CAP) | Test Execution: CAP scenarios | W5–W7 | | | | | ■ | ■ | ■ | | | | |
| QA | QA (CIP) | Test Execution: CIP scenarios | W7–W9 | | | | | | | ■ | ■ | ■ | | |
| QA | QA Team | Integration Testing (cross-project isolation) | W10 | | | | | | | | | | ■ | |
| QA | QA Team | Regression Testing | W10–W11 | | | | | | | | | | ■ | ■ |
| QA | Dev + QA | Bug Fix / Retest (ongoing) | W3–W10 | | | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | |
| QA | QA Team | Release Sign-off | W11–W12 | | | | | | | | | | | ■ |

**Key rules:**
1. QA tests a phase the week AFTER dev delivers it
2. Foundation (shared) must be done before CAP/CIP-specific work begins
3. CAP and CIP scenario testing can partially overlap (different QA members)
4. Integration testing (unified email, cross-project isolation) needs both projects complete
5. Dev testing on DEV04 happens Week 9 — QA integration testing follows immediately

### Developer Track Detail

**Sequential: CAP first (builds foundation), then CIP (reuses it)**

| Phase | Weeks | CAP Team (Noel + Throy) | CIP Team (Orlino + Cristoff) |
|---|---|---|---|
| Shared Foundation | W1–W2 | Building DB migrations, models, run lifecycle, command | — (can observe/learn) |
| Allocation Engine | W3–W4 | Formula, rounding, invariants, configurable prices | — |
| CIP Integration + Scenarios | W5–W6 | Plan detection, eligibility, CIP scenarios | — |
| CIP Freee + CSV | W7 | Journal factory, Freee API, CSV, unified email | — |
| CIP Dev Testing | W8 | DEV04 validation | CAP starts: plan detection, reference prices |
| CAP Integration + Scenarios | W8–W9 | Support / PR review | Allocation logic (reuses engine), CAP scenarios |
| CAP Freee + CSV | W10 | Support | Plug into existing Freee + CSV + email |
| CAP Dev Testing | W11 | Oversee | DEV04 validation |
| Buffer | W12 | QA support | QA support |

**QA assignment:** Miko (CIP testing from W5), Glenn (CAP testing from W9)

---

## Comparison of Approaches

| Dimension | Scenario A (Separate, sequential) | Scenario B (Separate, parallel) | Scenario C (Combined framework, sequential) ✅ |
|---|---|---|---|
| Total dev effort | 13–15 weeks | 8–10 weeks (needs 4 devs) | 9–12 weeks (sequential: CAP then CIP) |
| Total QA effort | 5–7 weeks | 5–7 weeks | 5–7 weeks |
| Team needed | Lead + 2 devs | Lead + 4 devs | CAP: Lead + 1 dev. CIP: sub-lead + 1 dev (Lead oversees) |
| Code duplication | High (2 separate projects) | High | Low (shared framework) |
| Maintenance cost | 2× (separate codebases) | 2× | 1× (single framework) |
| Fits Dec 17? | ⚠️ Tight | ✅ Yes (if 4 devs available) | ✅ Yes (if started by mid-Sept) |
| Risk | Low (proven pattern) | Medium (coordination) | Low–Medium (first build) |

**Decided (Kuroda-san 2026-08-08):** Scenario C, sequential execution. CAP first (Noel + Throy, builds foundation), then CIP (Orlino + Cristoff, reuses foundation). Not parallel — simpler coordination, second project benefits from first.

---

## Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| No ASCH reference implementation | Slightly longer foundation phase | Certain | ASCH design docs still usable as architectural reference |
| Reference prices not yet confirmed (CIP) | Cannot finalize constants | Medium | Design is price-agnostic; constants change last |
| Combined framework over-abstraction | Design takes longer than needed | Low | Keep it simple — config-driven, not plugin architecture |
| Dec holiday season | Reduced availability | Medium | Start by mid-Sept, finish dev before holidays |
| QA bottleneck | Testing blocks release | Medium | Start QA planning in Week 2 (overlap with dev) |

---

## Dependencies

| ID | Dependency | Required by | Status |
|---|---|---|---|
| D-1 | CIP reference prices (Coaching + App list prices) | Phase 4 | **OPEN** |
| D-2 | CAP dedicated App product_id | Phase 3 | **OPEN** (from previous estimate) |
| D-3 | Freee sender approach decision (REF-ASCH-08) | Phase 6 | **OPEN** — recommend dedicated thin sender |
| D-4 | Unified email approval (subject/body format) | Phase 6 | **OPEN** |
| D-5 | QA test environment (dev04 with sample data) | QA Phase Q2 | TBD |
| D-6 | Accounting-approved CSV fixture files | QA Phase Q2 | TBD |

---

## What's Salvaged from ASCH

| ASCH Artifact | Reused in CAP/CIP? | How |
|---|---|---|
| Run management design (3-transaction, lifecycle) | ✅ Directly | Becomes the shared foundation |
| Engineering standards doc | ✅ Directly | Same patterns, DTOs, enums, strategies |
| Unified email delivery design (REF-07) | ✅ Directly | Multi-project orchestrator |
| Freee sending approach analysis (REF-08) | ✅ Directly | Same decision needed |
| DB table structure (calculation_runs, source_docs, sum_calc) | ✅ Renamed | `asc_alloc_*` prefix instead of `asch_*` |
| Proration formula (O = ΣM × basis/Σbasis) | ❌ Not needed | CAP/CIP use simpler fixed ratio |
| 9 calculation patterns | ❌ Not needed | CAP/CIP have their own simpler scenarios |
| CDB integration | ❌ Not needed | CAP/CIP use plan_id detection |
| Honki Set eligibility logic | ❌ Not needed | Campaign-specific |
| calc_rule_code convention | ✅ Pattern reusable | Different codes, same idea |

---

## Recommendation

1. **Start once requirements are confirmed** — combined framework approach, sequential (CAP first, CIP second)
2. **CAP team (Noel + Throy)** builds shared foundation + CAP allocation — 6–8 weeks
3. **CIP team (Orlino + Cristoff, Noel oversees)** plugs CIP into existing framework — 3–4 weeks
4. **QA starts test planning in Week 2** — overlapping with dev (Miko for CAP, Glenn for CIP)
5. **Target: dev complete ~10 weeks after start** — gives buffer before Dec 17
6. **Use ASCH design docs as architectural reference** — not wasted, just renamed/generalized
7. **Decision needed from Kuroda-san:** Updated requirements + Freee sender approach (option a vs b from REF-ASCH-08)

*This is a rough/tentative estimate. Numbers will be refined once:*
- *Full requirements for CAP/CIP without ASCH are confirmed*
- *Reference prices are provided*
- *Team allocation is finalized*
- *Start date is decided*
