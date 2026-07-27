# ASCH — Development Estimation

## Document Info

| | |
|---|---|
| **Document type** | Project Estimation |
| **Date** | 2026-07-20 |
| **Author** | Noel Palo, Lead Developer (SCM) |
| **Audience** | Kuroda-san (PM), Patrick-san (SDM), Stakeholders |
| **Status** | Draft |

---

## Executive Summary

ASCH requires ~7–8 weeks of development with 2 developers (Throy + Cristoff), fitting comfortably within the 10/1 deadline. Option A (run_id model, 9 tables) is decided. ASCH runs as a separate command with separate email — no modification to existing ASC batch.

---

## Context

### What We're Building

A batch subsystem that calculates revenue proration for Honki Set bundled payments across 3 products (Lesson, Coaching, App), reads what the existing accounting system already booked (N), and sends the difference (P − N) as adjustment journal entries to Freee. It runs monthly alongside the existing system without modifying it.

### Deadline & Constraints

| Constraint | Value |
|---|---|
| Production deadline | 2026/10/1 (quarterly closing — Jul–Sep revenue must be finalized) |
| Available calendar time | ~10 weeks (Jul 21 – Oct 1) |
| Team | 2 developers (Throy + Cristoff) executing tasks. Lead (Noel) handles requirements → design → task generation → code review. |
| Key dependencies | CDB table readiness by Week 3 (Wu-san), PM sign-off turnaround, ASCH email template |

---

## Assumptions

- Lead developer (Noel) handles requirements → design → task generation via spec-driven workflow (Kiro)
- 2 developers (Throy + Cristoff) execute generated tasks
- Dev environment and repo access available by start date
- CDB table structure finalized (ASCH creates in own dev branch with seed data)
- PM clarification turnaround within 1 business day when design questions arise during spec authoring
- No major scope additions beyond confirmed Patterns 1–9
- QA testing (Alvin + Jaymiriz) handled separately — not included in this estimate

---

## Estimation Options

### Option A: run_id Generation Model (New Design — 9 tables)

Single set of 9 new `asch_*` tables. Every result row carries `run_id` as a generation key. Run lifecycle (create → finalize → supersede). All runs preserved — supports revision and audit.

#### Phase Breakdown

| # | Phase | Spec | Scope | Duration | Who |
|---|---|---|---|---|---|
| 1 | Schema & Foundation | Spec 01 | 9 migrations, models, FK migrations, structure tests. Run lifecycle. "Active run" resolution. Single command with `--run-type`. | 2 wk | Lead: req + design. PM: sign-off. Dev: execution. Lead: PR review. |
| 2 | Eligibility & Enrollment | Spec 02 | CDB snapshot (per run_id), enrollment/component/period build, fallback detection. **Requires CDB table to exist with data.** | 1 wk | Lead: req + design. PM: sign-off. Dev: execution. Lead: PR review. |
| 3 | Pattern 1 Calculation | Spec 03 | Core proration: O allocation, P proration, N reading, adjustment. Invariants (ΣO=ΣM, ΣP=O). | 1.5 wk | Lead: req + design. PM: sign-off. Dev: execution. Lead: PR review. |
| 4 | Patterns 2–9 | Specs 06–09 | All remaining patterns. Single code path (no duplication). | 1.5 wk | Lead: design + task gen. Dev: execution. Lead: PR review. |
| 5 | Freee Submission | Spec 04 | Journal factory (T1 only), Freee API, chunking. Final run only. | 1 wk | Lead: design. Dev: execution. Lead: PR review. |
| 6 | CSV + Zip/Email | Spec 05 | AschCsvUtil, config, zip, separate ASCH email. **No hook into existing pipeline** (decided 2026-07-22). | 0.5 wk | Dev: execution. Lead: PR review. |
| 7 | Dev Testing & Validation | — | Unit tests, pattern walkthroughs, run lifecycle tests, invariant checks. DEV04 deploy. | 1 wk | Dev + Lead. |
| | **Subtotal (dev)** | | | **8.5 wk** | |
| 8 | Buffer | — | PM review cycles, gate rejections, environment issues, CDB alignment, bug fixes. | 1 wk | All |
| | **Dev Total** | | | **9.5 wk** | |

**Dependency chain:** Spec 01 → Spec 02 → Spec 03 → Specs 06–09 → Spec 04 → Spec 05

**CDB dependency (clarified with Kuroda-san 2026-07-22):**

| Need | For development (Week 3) | For production (10/1) |
|---|---|---|
| Table structure (DDL) | ASCH creates in own dev branch | CDB owns in production |
| Test data | ASCH seeds dummy data | CDB batch populates real data |
| Real student eligibility | Not needed | Must be ready |

Development is **NOT blocked** by CDB. ASCH creates the CDB table structure and seeds test data itself. The real dependency is: **CDB batch must be running with real July + April cohort data before the 10/1 production run.**

---

#### QA Testing (Parallel Track)

QA runs in parallel with development but **always tests AFTER dev delivers** — never during.

| QA Phase | When | Depends on | Output |
|---|---|---|---|
| Test Planning | Week 1 | Requirements available | Test strategy, scope |
| Test Case Creation | Weeks 1–3 | Requirements + design per spec | Test cases ready before code arrives |
| Test Data Preparation | Weeks 2–4 | Pattern data from Kuroda-san's Excel | Seed data for each pattern |
| **Test Execution: Spec 01** | Week 3 | Spec 01 merged + DEV04 deploy | Schema verified, commands smoke-tested |
| **Test Execution: Spec 02** | Week 4 | Spec 02 merged | Eligibility accuracy verified |
| **Test Execution: Pattern 1** | Week 5 | Spec 03 merged | P values match Excel |
| **Test Execution: Patterns 2–5** | Week 6 | Dev 2 patterns merged | Values match Excel |
| **Test Execution: Patterns 6–9** | Week 7 | Dev 1 patterns merged | Values match Excel |
| **Test Execution: Freee + CSV** | Week 8 | Specs 04 + 05 merged | Journals correct, CSVs correct |
| **End-to-end integration** | Week 9 | All specs merged | Full batch run on DEV04 |
| **Regression + Release sign-off** | Weeks 9–10 | Full deploy | Existing ASC unaffected |
| Bug Fix / Retest | Weeks 3–10 (ongoing) | QA finds bugs | Dev fixes, QA retests |

**QA cannot test a spec until:**
1. Dev has finished coding (PR merged)
2. Lead has reviewed and approved the PR
3. Code is deployed to DEV04

This means QA testing for Pattern 2-3-9 starts in **Week 6** (after dev delivers end of Week 5), not Week 4 as in Kuroda-san's draft timeline.

#### Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| **CDB not ready for production by 10/1** | **Fallback self-detection needed for production** | **Medium** | PM tracks CDB delivery with Wu-san. Dev is unblocked (uses own seed data). |
| Run lifecycle complexity | +2–3 days | Low | Well-defined pattern; single service class |
| Team unfamiliarity with run_id model | +1–2 days | Low | Clear helper method + documentation |
| H-19 (April 2026 cohort in scope) | +0.5 week | Medium | Revision run — clean, no forward-cascade |
| QA finds bugs in pattern validation | +3–5 days | Medium | Parallel testing catches bugs early (not at Week 9) |

#### Trade-offs

| For | Against |
|---|---|
| Full audit trail — every run preserved (JSOC compliance) | New concept for operations team |
| Retroactive correction is clean (revision run, no data loss) | Queries always need run_id filter |
| 9 tables (fewer migrations, fewer structure tests) | Tables grow over time (needs retention policy) |
| No code duplication — single logic class | Slightly more complex foundation phase |
| Supports quarterly campaign recurrence naturally | |

---

### Option B: Pre/Final Two-Table Model — DROPPED (2026-07-22)

> ⚠️ **This option was NOT adopted.** Kept here as historical reference for why the decision was made. Build against Option A only.

Adopts the same `_pre` / final table pattern used by existing ASC commands. 12–13 new `asch_*` tables (not reusing existing `log_*` tables — same architectural pattern, different data model). Result tables are paired (`_pre` + final); enrollment tables are single with DELETE→INSERT rebuild.

#### Phase Breakdown

| # | Phase | Scope | Duration | Who |
|---|---|---|---|---|
| 1 | Schema & Foundation | 12–13 migrations, models, FK migrations, structure tests. Pre + Final commands. DELETE→INSERT idempotency. | 1.5 wk | Lead: req + design. PM: sign-off. Dev: execution. Lead: PR review. |
| 2 | Eligibility & Enrollment | CDB snapshot, enrollment/component/period build, fallback detection. | 1 wk | Lead: req + design. PM: sign-off. Dev: execution. Lead: PR review. |
| 3 | Pattern 1 Calculation | Core proration: O allocation, P proration, N reading, adjustment. Invariants. Both Pre and Final paths. | 1.5 wk | Lead: req + design. PM: sign-off. Dev: execution. Lead: PR review. |
| 4 | Patterns 2–9 | All remaining patterns. Must verify both Pre and Final paths. | 2 wk | Lead: design + task gen. Dev: execution. Lead: PR review. |
| 5 | CSV + Zip/Email | AschCsvUtil, config, integration hook in SendJournals + PreLogic. | 0.5 wk | Dev: execution. Lead: PR review. |
| 6 | Freee Submission | Journal factory (T1 only), Freee API, chunking. Final run only. | 1 wk | Lead: design. Dev: execution. Lead: PR review. |
| 7 | Testing & Validation | Unit tests, pattern walkthroughs, Pre/Final path tests, invariant checks. | 1 wk | Dev + Lead. DEV04 deploy + manual validation. |
| | **Subtotal (core)** | | **8.5 wk** | |
| 8 | Buffer | PM review cycles, gate rejections, environment issues, CDB alignment, bug fixes. | 1 wk | All |
| | **Total** | | **9.5 wk** | |

#### Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| Pre/Final code duplication drift | +2–3 days | Medium | Single parameterized class (learned from existing ASC tech debt) |
| CDB not ready by Week 6 | +1 week | Medium | Fallback: self-contained cohort detection |
| H-19 (April 2026 cohort in scope) | +1 week | Medium | DELETE→INSERT + forward-cascade O values |
| No DB-level audit for re-runs | Operational risk | Low | CSV retention + source_documents table |

#### Trade-offs

| For | Against |
|---|---|
| Team familiarity — same pattern as existing ASC | No DB-level audit trail (re-runs overwrite) |
| No new concepts (no run lifecycle, no supersede) | Retroactive correction requires forward-cascade |
| N source for preview auto-resolves (_pre tables) | If April 2026 added later, original data is lost |
| Simpler batch process control | 12–13 tables (more migrations, more structure tests) |

---

## Comparison

| Dimension | Option A (New Design) | Option B (Existing Pattern) |
|---|---|---|
| **Total estimate** | **9.5 weeks** | **9.5 weeks** |
| Tables to create | 9 | 12–13 |
| Logic classes | 1 (parameterized by run_type) | 1 (parameterized) or 2 (Pre+Final) |
| Foundation phase | 2 weeks (run lifecycle) | 1.5 weeks (simpler) |
| Pattern implementation | 1.5 weeks (single code path) | 2 weeks (verify Pre/Final separately) |
| Retroactive (if H-19 = yes) | +0.5 week | +1 week |
| Audit trail | Full DB-level history | CSVs + source_documents only |
| Long-term maintenance | Lower | Higher (duplication risk) |
| Operational learning curve | Medium (new concepts) | Low (familiar) |

The estimates are nearly equal because Option A's extra foundation cost is offset by Option B's extra pattern verification cost. The core formula work (Phases 3–4) is identical. The difference shows in **long-term cost**, not initial build.

---

## Timeline Confidence

| Scenario | Duration | Fits 10/1? | Condition |
|---|---|---|---|
| **Best case** | 6 weeks | ✅ 4 weeks margin | No blockers, parallel execution, no rejections |
| **Expected case** | 7–8 weeks | ✅ 2–3 weeks margin | Normal review cycles, minor issues |
| **Worst case** | 10–11 weeks | ⚠️ Tight / slight overrun | Gate rejections + CDB production delay + pattern bugs |

### What could push past deadline

| Risk | Impact | Probability |
|---|---|---|
| **CDB not ready for production** AND **fallback self-detection needed** | +1 week | Low (only if CDB fully fails by 10/1) |
| PM sign-off takes >3 days per spec | +1 week | Low (if PM aware of timeline pressure) |
| H-19 (April 2026 cohort) added to scope | +0.5–1 week | Medium |
| Dev environment not available Week 1 | Shifts entire timeline | Unknown |
| Multiple PR rejections per spec | +0.5 week | Low (design reviewed upfront) |
| QA finds critical bugs in pattern logic | +0.5 week | Medium (mitigated by parallel testing) |

### Mitigation options (if worst case materializes)

- **Add 2nd developer** → reduces to ~7–8 weeks (provides margin, not dramatic speed increase — see Appendix)
- **Descope Patterns 7–9 to post-10/1 release** (rarest edge cases; can ship as Phase 2)
- **Pre-align PM sign-off:** share requirements drafts before formal submission to reduce turnaround

---

## Why This Timeline

### What spec-driven dev + AI accelerates (already reflected in the 9.5 weeks)

- Requirements → design → task breakdown: hours, not days
- Boilerplate code (migrations, models, DTOs, factories): generated, not hand-typed
- Test scaffolding and pattern validation: automated
- Documentation and spec alignment: maintained in real-time

**Without this workflow, the same project would take 18–24 weeks (4.5–6 months).** The 9.5-week estimate already reflects the ~55–60% acceleration.

### What cannot be compressed regardless of tooling

| Factor | Why it takes real time | Share |
|---|---|---|
| **9 calculation patterns** | Each has unique business rules. Must match Kuroda-san's Excel values to the yen. Implemented and validated one by one. | ~3.5 wk |
| **Review gates (3 per spec × 5 specs)** | PM sign-off, Lead design review, Lead PR review. Quality gates — not optional. | ~1 wk (distributed) |
| **Integration with existing code** | `SendJournalsDataLogic` (1100 lines), `CommonUtil` (2200 lines). Must hook in without breaking. | ~1 wk |
| **Correctness verification** | Accounting system → official ledger. Every invariant (ΣO=ΣM, ΣP=O) must be proven. "Close enough" is not acceptable. | ~1.5 wk |
| **Freee API integration** | External API, rate limits, chunking, sandbox testing. | ~1 wk |
| **External dependencies** | CDB readiness, H-9 decision, environment setup. Blocked time = blocked time. | ~0.5 wk |

### The honest comparison

| Approach | Duration | Notes |
|---|---|---|
| Traditional development (no AI, no spec-driven) | 18–24 weeks | Assumes senior dev who knows the codebase. Includes manual design docs, code reading, hand-written tests. |
| **Spec-driven dev with AI (our approach)** | **9.5 weeks** | ~55–60% faster. AI handles boilerplate, design synthesis, test scaffolding. |
| Unrealistic expectation ("AI does it fast") | 4–5 weeks | Would require no integration, no review gates, no correctness verification. |

The 4–5 week expectation would require: no integration with existing code, no review gates, no 9 distinct patterns, no yen-exact validation, no external API, and no external dependencies. None of those conditions hold.

**This is an accounting system that directly feeds the company's official ledger. Speed without correctness is worse than no system at all.**

---

## Development Workflow

Each spec (5 total in Phase 1) follows the full lifecycle:

```
Requirements (Lead + AI) → PM Sign-off → Design (Lead + AI) → Task Review (Lead + Dev)
→ Task Execution (Dev + AI) → PR Review (Lead) → Merge
```

Three mandatory quality gates per spec:
1. **Gate 1:** PM approves requirements (business rules correct)
2. **Gate 2:** Lead approves design + tasks (architecture sound, tasks executable)
3. **Gate 3:** Lead approves PR (code correct, no regressions)

Review turnaround is included within each phase's time allocation — not a separate phase. See `asch-development-workflow.md` for full process detail.

---

## Dependencies & Prerequisites

| Prerequisite | Needed by | Status | Impact if late |
|---|---|---|---|
| H-9 decision (run_id vs _pre/final) | Week 1 start | ✅ **Decided: Option A** (2026-07-22) | — |
| Dev environment + repo access | Week 1 start | TBD | Blocks everything |
| **CDB table structure finalized** | **Week 1** (ASCH creates in own branch) | **Only need final column spec from Wu-san** | None (ASCH self-creates) |
| **CDB batch running with real data** | **Before 10/1** (production gate) | **Pending (Wu-san)** | Fallback: self-detection for production |
| App tax conversion rule (H-16) | Week 4 (calculation start) | Mostly resolved (tax-incl) | Minor |
| H-19 decision (April 2026 cohort) | Week 7 (Freee scope) | Resolved (in scope, no retro) | — |
| App Freee mapping confirmation (H-4) | Week 7 (Freee submission) | Partially resolved | May block Spec 04 |
| CDB April cohort backfill | Week 7 | Pending (Wu-san) | Needed for production run |
| ASCH email template (subject/body) | Week 8 (Spec 05) | TBD (Kuroda-san) | Blocks email send |

---

## Recommendation

**Option A (run_id model) decided (2026-07-22). 2 developers assigned (Throy + Cristoff). Timeline: ~7–8 weeks with comfortable margin to 10/1.**

**Immediate next steps:**
1. Regenerate Spec 01 (Foundation) with current requirements
2. Get PM sign-off → begin execution (Throy starts Foundation, Cristoff preps eligibility research)
3. Lead manages spec pipeline — always 1 spec ahead in requirements/design

---

## Appendix

### Timeline (Aligned with Kuroda-san's Excel Format)

**Header:**

| Item | Details |
|---|---|
| Development Approach | run_id (Option A — decided 2026-07-22) |
| Development Team | 2 Developers + Lead |
| Development Estimate | 7–8 weeks |
| Production Deadline | 2026/10/01 |
| Start Date | 2026/07/21 |
| QA | Parallel track (starts Week 1 with prep, tests after dev delivers) |
| Key Dependencies | CDB (production readiness) / H-16 / H-4 |
| Expected Buffer | Approx. 2 weeks (dev W9 + W10) |
| Assumption | PM clarification within 1 business day |
| Note | Lead review remains a single bottleneck. Dependencies are sequential — parallelism is limited. |

**Development:**

| Category | Owner | Task / Phase | Start Date | End Date | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Development | Lead + PM | Requirements / design / task generation / approval (ongoing) | 2026/07/21 | 2026/09/08 | ■ | ■ | ■ | ■ | ■ | ■ | ■ | ■ | | |
| Development | Dev 1 (Throy) | Spec 01: Foundation (schema / models / commands / run lifecycle) | 2026/07/21 | 2026/08/03 | ■ | ■ | | | | | | | | |
| Development | Dev 2 (Cristoff) | Spec 01: Foundation (FK migrations / structure tests / seeders) | 2026/07/21 | 2026/08/03 | ■ | ■ | | | | | | | | |
| Development | Dev 1 (Throy) | Spec 02: Eligibility + CDB snapshot + enrollment build | 2026/08/04 | 2026/08/10 | | | ■ | | | | | | | |
| Development | Dev 2 (Cristoff) | Spec 03: Pattern 1 — O allocation, P proration | 2026/08/04 | 2026/08/17 | | | ■ | ■ | | | | | | |
| Development | Dev 1 (Throy) | Spec 03: Pattern 1 — N reading, adjustment, invariants | 2026/08/11 | 2026/08/17 | | | | ■ | | | | | | |
| Development | Dev 1 (Throy) | Specs 06–09: Patterns 2–5 | 2026/08/18 | 2026/08/31 | | | | | ■ | ■ | | | | |
| Development | Dev 2 (Cristoff) | Specs 06–09: Patterns 6–9 | 2026/08/18 | 2026/08/31 | | | | | ■ | ■ | | | | |
| Development | Dev 1 (Throy) | Spec 04: Freee submission (T1 journals, API, chunking) | 2026/09/01 | 2026/09/08 | | | | | | | ■ | | | |
| Development | Dev 2 (Cristoff) | Spec 05: CSV generation / zip / separate email | 2026/09/01 | 2026/09/08 | | | | | | | ■ | | | |
| Development | Lead + Dev | Dev Testing & Validation (DEV04 full run) | 2026/09/08 | 2026/09/14 | | | | | | | | ■ | | |
| Buffer | All | Development buffer / bug fixes / QA support | 2026/09/15 | 2026/10/01 | | | | | | | | | ■ | ■ |

**Dependency logic for parallel work:**
- W1–2: Both devs on Spec 01 (large spec — 9 tables, migrations split between devs)
- W3: Spec 01 done → Dev 1 starts Spec 02 (1 wk), Dev 2 starts Spec 03 (Spec 02 tables exist by mid-W3 when Dev 2 needs them for N-reading)
- W4: Dev 1 joins Spec 03 (invariants, adjustment). Both finish Pattern 1 by end of W4.
- W5–6: Spec 03 done → Patterns 2–9 split between devs (independent from each other, all extend same engine)
- W7: Specs 06–09 done → Spec 04 (Freee) and Spec 05 (CSV) can run in parallel (Spec 05 depends on Spec 04 for aggregation, but CSV structure/template work can start while Freee is built)
- W8: Dev testing on DEV04
- W9–10: Buffer

**QA:**

| Category | Owner | Task / Phase | Start Date | End Date | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| QA | QA Team | Test Planning | 2026/07/21 | 2026/07/25 | ■ | | | | | | | | | |
| QA | QA Team | Test Case Creation | 2026/07/28 | 2026/08/14 | | ■ | ■ | ■ | | | | | | |
| QA | QA Team | Test Data Preparation | 2026/07/28 | 2026/08/14 | | ■ | ■ | ■ | | | | | | |
| QA | QA Team | Test Execution: Spec 01 (schema, commands) | 2026/08/04 | 2026/08/10 | | | ■ | | | | | | | |
| QA | QA Team | Test Execution: Spec 02 (eligibility) | 2026/08/11 | 2026/08/17 | | | | ■ | | | | | | |
| QA | QA Team | Test Execution: Pattern 1 (Spec 03) | 2026/08/18 | 2026/08/24 | | | | | ■ | | | | | |
| QA | QA Team | Test Execution: Patterns 2–9 (Specs 06–09) | 2026/09/01 | 2026/09/08 | | | | | | | ■ | | | |
| QA | QA Team | Test Execution: Freee + CSV (Specs 04 + 05) | 2026/09/08 | 2026/09/15 | | | | | | | | ■ | | |
| QA | Dev + QA | Bug Fix / Retest (ongoing) | 2026/08/04 | 2026/09/25 | | | ■ | ■ | ■ | ■ | ■ | ■ | ■ | |
| QA | QA Team | End-to-end integration | 2026/09/15 | 2026/09/21 | | | | | | | | | ■ | |
| QA | QA Team | Regression / Release Sign-off | 2026/09/22 | 2026/09/30 | | | | | | | | | | ■ |

**Week Start Dates:** W1=07/21, W2=07/28, W3=08/04, W4=08/11, W5=08/18, W6=08/25, W7=09/01, W8=09/08, W9=09/15, W10=09/22

**Key rules:**
1. QA tests a spec the week AFTER dev delivers it
2. Spec dependencies are respected: 01 → 02 → 03 → 06-09 → 04 → 05
3. Within a spec, two devs can split tasks (e.g., Spec 01: one does migrations, other does models)
4. Between specs, parallelism is limited by the dependency chain

### With 2 Developers — Actual Plan (Throy + Cristoff)

| Track | Developer 1 (Throy) | Developer 2 (Cristoff) |
|---|---|---|
| Weeks 1–2 | Foundation (schema, models, commands) | Eligibility + CDB integration |
| Weeks 3–4 | Pattern 1 calculation + validation | Patterns 2–5 |
| Weeks 5–6 | Patterns 6–9 | CSV generation + zip/email |
| Weeks 7–8 | Freee submission | Integration testing + bug fixes |

**2-developer estimate: ~7–8 weeks**

**Why 2 developers ≠ half the time:**

In spec-driven development, the Lead (Noel) is a single bottleneck across all specs:
- Requirements → design → task generation: Lead produces these sequentially (cannot parallelize own capacity)
- PR review: two PRs queued for review doesn't go faster than one — it queues
- Specs have sequential dependencies (Spec 02 needs Spec 01's tables to exist)

**What 2 developers add:**
- Parallel execution of independent work within a spec (e.g., one does migrations while other does models)
- One dev starts the next spec while the other's PR is in review — keeps momentum
- Insurance against sickness, leave, or unexpected blockers on one developer
- Pattern work (Specs 06–09) can be split between them

**What it does NOT add:**
- Cannot reduce Lead review time (still one person reviewing)
- Cannot parallelize dependent specs at the foundation level
- Does not change PM sign-off turnaround

**Bottom line:** A 2nd developer provides ~2 weeks of margin (from 9.5 → 7–8 weeks). The value is **safety margin and insurance**, not a dramatic speed increase. With 1 developer the timeline already fits 10/1.

### Reference Documents

| Document | Location |
|---|---|
| DB design (dual-option) | `REF-ASCH-03-DB-Table-Design-Draft.md` |
| Requirements update | `REF-ASCH-02-Requirements-Update-20260716.md` |
| CSV/zip/email integration | `RESEARCH-04-CSV-Zip-Email-Integration.md` |
| Code integration points | `RESEARCH-03-Integration-Points-Analysis.md` |
| Development workflow | `asch-development-workflow.md` |
| Engineering standards | `asch-engineering-standards.md` |
