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

ASCH requires ~9.5 weeks of development (1 developer) for either database design option. Both fit the 2026/10/1 deadline, but with minimal buffer in the expected case. The two options have nearly identical build cost — the difference is in long-term maintenance and audit capability.

---

## Context

### What We're Building

A batch subsystem that calculates revenue proration for Honki Set bundled payments across 3 products (Lesson, Coaching, App), reads what the existing accounting system already booked (N), and sends the difference (P − N) as adjustment journal entries to Freee. It runs monthly alongside the existing system without modifying it.

### Deadline & Constraints

| Constraint | Value |
|---|---|
| Production deadline | 2026/10/1 (quarterly closing — Jul–Sep revenue must be finalized) |
| Available calendar time | ~10 weeks (Jul 21 – Oct 1) |
| Team | 1 developer (Throy) executing tasks full-time. Lead (Noel) handles requirements → design → task generation → code review. |
| Key dependencies | CDB table readiness by Week 3 (Wu-san), PM sign-off turnaround, ASCH email template |

---

## Assumptions

- Lead developer handles requirements → design → task generation via spec-driven workflow (Kiro)
- 1 developer executes generated tasks full-time
- Dev environment and repo access available by start date
- CDB table ready for integration by Week 6 (fallback self-detection adds +1 week if not)
- PM clarification turnaround within 1 business day when design questions arise during spec authoring
- No major scope additions beyond confirmed Patterns 1–9
- QA testing (Alvin, Jaymiriz) handled separately — not included in this estimate

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

QA can start preparing and testing in parallel with development — no need to wait for all specs to be done.

| QA Activity | When | Depends on | Who |
|---|---|---|---|
| Test case preparation (from requirements) | **Week 1 onwards** | Requirements.md for each spec (available as soon as Lead generates them) | QA |
| Spec 01 testing (schema verification, command smoke test) | Week 3 (after Spec 01 merged + DEV04 deploy) | Spec 01 merged to ASCH-master | QA |
| Spec 02 testing (eligibility accuracy) | Week 4 | Spec 02 merged | QA |
| Spec 03 testing (Pattern 1 values match Excel) | Week 5–6 | Spec 03 merged | QA |
| Specs 06–09 testing (Patterns 2–9 values) | Week 7 | Specs 06–09 merged | QA |
| Spec 04 testing (Freee sandbox journals) | Week 8 | Spec 04 merged | QA |
| Spec 05 testing (CSV content + zip/email) | Week 8–9 | Spec 05 merged | QA |
| End-to-end integration test | Week 9 | All specs merged, DEV04 full run | QA + Lead |
| Regression test (existing ASC unaffected) | Week 9–10 | Full deploy on DEV04 | QA |

**How parallel testing works:**
- QA prepares test cases as soon as requirements are available (Gate 1 output)
- After each spec merges to ASCH-master and deploys to DEV04, QA tests that spec
- Bug fixes from QA are addressed immediately (within the same week or buffer)
- Final integration test runs the full batch end-to-end with real dev04 data
- QA does NOT wait for Week 9 — they test incrementally per spec

**QA timeline visual:**
```
Dev:  [==Spec 01==][02][====03====][==06-09==][04][05][DevTest][Buffer]
QA:   [Prep......][QA01][QA02][QA03........][QA06-09][QA04/05][E2E+Reg]
Week:  W1    W2    W3   W4    W5    W6    W7    W8    W9    W10
```

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
| **Best case** | 8 weeks | ✅ 2 weeks margin | No blockers, no rejections, CDB ready early |
| **Expected case** | 9.5 weeks | ✅ 0.5 week margin | Normal review cycles, minor issues |
| **Worst case** | 11–12 weeks | ❌ Overrun | Gate rejections + CDB delay + H-19 in scope |

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

**Option A (run_id model) has been decided (2026-07-22).** The timeline is 9.5 weeks with 1 developer.

**Immediate next steps:**
1. Delete existing spec content (outdated)
2. Regenerate Spec 01 (Foundation) with current requirements
3. Get PM sign-off → begin execution

**Key risk to actively manage:** CDB table readiness by Week 3. PM must track with Wu-san's team.

---

## Appendix

### Timeline Visual

```
Week:        W1      W2      W3      W4      W5      W6      W7      W8      W9      W10
Date:     Jul 21  Jul 28  Aug 4   Aug 11  Aug 18  Aug 25  Sep 1   Sep 8   Sep 15  Sep 22  Oct 1
             |       |       |       |       |       |       |       |       |       |       |
Dev:      [==01: Foundation==][02][====03: Pattern 1====][06-09: Patterns 2-9][04:Freee][05][DevTest][Buf]
QA:       [Prep.............][QA01][QA02][QA03..........][QA 06-09...][QA04/05][E2E + Regression]
             |       |       |       |       |       |       |       |       |       |       |
CDB needed:          ↑ Week 3 (Spec 02 starts — needs CDB table with data)
Deadline:                                                                                    ↑ 10/1

Dependency: 01 → 02 (needs CDB) → 03 → 06-09 → 04 → 05
```

### With 2 Developers — Realistic Assessment

| Track | Developer 1 (Throy) | Developer 2 |
|---|---|---|
| Weeks 1–2 | Foundation (schema, models, commands) | Eligibility + CDB integration |
| Weeks 3–4 | Pattern 1 calculation + validation | Patterns 2–5 |
| Weeks 5–6 | Patterns 6–9 | CSV generation + zip/email |
| Weeks 7–8 | Freee submission | Integration testing + bug fixes |

**2-developer estimate: ~7–8 weeks** (not 5 weeks — see below)

**Why 2 developers ≠ half the time:**

In spec-driven development, the Lead (Noel) is a single bottleneck across all specs:
- Requirements → design → task generation: Lead produces these sequentially (cannot parallelize own capacity)
- PR review: two PRs queued for review doesn't go faster than one — it queues
- Specs have sequential dependencies (Spec 02 needs Spec 01's tables to exist)

**What a 2nd developer actually adds:**
- Parallel execution of independent specs (e.g., Foundation + eligibility research simultaneously)
- One dev starts the next spec while the other's PR is in review — keeps momentum
- Insurance against sickness, leave, or unexpected blockers on one developer

**What it does NOT add:**
- Cannot reduce Lead review time (still one person reviewing)
- Cannot parallelize dependent specs (must wait for tables/models to exist)
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
