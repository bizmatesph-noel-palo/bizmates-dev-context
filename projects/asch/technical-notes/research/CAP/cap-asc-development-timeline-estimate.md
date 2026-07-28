# ASC for CAP — Development Estimation

## Document Info

| | |
|---|---|
| **Document type** | Project Estimation |
| **Date** | 2026-07-24 |
| **Author** | Noel Palo, Lead Developer |
| **Audience** | Kuroda-san (PM), Patrick-san (SDM), Stakeholders |
| **Status** | Draft (preliminary — pending D-1 resolution) |

---

## Executive Summary

ASC for CAP is structurally similar to ASCH but ~25% smaller in scope (2 products vs 3, simple fixed ratio vs conditional basis logic, plan_id discriminator vs CDB campaign eligibility). Estimated at **5–6 weeks with 2 developers (Option A)** or **7–8 weeks (Option B, if combined monthly-count charges are in scope)**. The ASCH implementation provides a proven architectural template, significantly reducing design risk.

---

## Context

### What We're Building

A batch subsystem that allocates the customer-paid Coaching amount between Coaching and App products, then sends the adjustment (P − N) to Freee. Same operational model as ASCH: preview on 1st, final on 3rd, run_id generation model, separate command.

### Formula

```
App allocation     = N × App_ref / (Coaching_ref + App_ref)
Coaching allocation = N - App allocation
Adjustment         = Allocated amount - Existing recognized amount
```

Where:
- N = amount already recognized by existing ASC (read from log tables)
- App_ref = ¥3,980 (tax-incl, constant)
- Coaching_ref = applicable Coaching 15-min or 30-min reference price

### Key Simplifications vs ASCH

| ASCH complexity | CAP equivalent |
|---|---|
| 3 products with conditional basis (L vs M) | 2 products with fixed ratio (always same formula) |
| 9 calculation patterns | ~10 scenarios (standard accounting events) |
| CDB eligibility + campaign window + cohort detection | plan_id lookup (deterministic) |
| Discount-type branching per row | No discount branching (App_ref is constant) |
| Month-6 trigger logic (Coaching C6) | None — permanent allocation, not campaign-limited |
| Bundle enrollment lifecycle (6 months, forfeiture) | No lifecycle — allocation runs as long as CAP plan active |

### Deadline & Constraints

| Constraint | Value |
|---|---|
| Production deadline | TBD (not yet set — Kuroda-san to confirm) |
| Team | Same as ASCH (2 developers + Lead) — TBD whether sequential or parallel with ASCH |
| Key dependencies | D-1 (monthly-count plan structure), D-2 (Freee sender approach), D-3 (App Freee mapping) |
| Prerequisite | ASCH implementation provides architectural template — CAP benefits from lessons learned |

---

## Assumptions

- ASCH is implemented first (or concurrently) — CAP reuses the architectural patterns (run_id model, CSV generation, Freee sending)
- Lead developer handles requirements → design → task generation
- 2 developers execute tasks
- `cap_*` table namespace (not reusing `asch_*` tables)
- App Freee mapping (freee_code=236270504) already confirmed for ASCH — reusable for CAP
- Option A is the base estimate; Option B is additive

---

## Option A: Separate Coaching + App Charges (Base Estimate)

CAP Coaching and App are separate charges. CAP allocates only the Coaching charge amount between Coaching and App. Existing lesson recognition is untouched.

### Phase Breakdown

| # | Phase | Scope | Duration (2 devs) | Notes |
|---|---|---|---|---|
| 1 | Schema & Foundation | ~5 `cap_*` tables (runs, source docs, allocation detail, Freee summary, trace). Run lifecycle. Command skeleton. | 1 wk | Reuses ASCH run_id pattern |
| 2 | Eligibility & Source | Plan_id mapping. Source charge/contract verification. Zero-yen App charge validation. N reading from log tables. | 0.5 wk | Simple — plan_id is deterministic |
| 3 | Core Allocation | Formula implementation. Rounding. Per-charge allocation. Invariant: App + Coaching = N. | 1 wk | Simple fixed ratio — no branching |
| 4 | Scenarios | Refund (before/after booking), plan change (15→30min), contract-type change (B2C/B2E/B2B), cooling-off, suspension, legacy exclusion, store-App coexistence. | 1.5 wk | ~10 scenarios vs ASCH's 9 complex patterns |
| 5 | Freee + CSV | Journal factory (T1), Freee API, detail CSV, summary CSV, zip, separate email. | 1 wk | Same pattern as ASCH — can reference implementation |
| 6 | Testing | Automated tests for all acceptance scenarios. Accounting-reviewed CSV fixtures. | 0.5 wk | Fewer patterns to validate |
| | **Subtotal** | | **5.5 wk** | |
| 7 | Buffer | PR reviews, gate rejections, environment issues, bugs. | 0.5 wk | |
| | **Total (Option A)** | | **6 wk** | |

### Timeline (2 developers)

| Week | Dev 1 | Dev 2 | Lead |
|---|---|---|---|
| W1 | Foundation (tables, models, run lifecycle) | Foundation (migrations, seeders, structure tests) | Req + Design |
| W2 | Eligibility + Core allocation | Scenarios (refund, plan change) | PM sign-off + PR review |
| W3 | Scenarios (contract change, cooling-off) | Freee + CSV | Design + PR review |
| W4 | Testing + validation | Testing + bug fixes | PR review + DEV04 deploy |
| W5 | Dev testing | Dev testing | Validation |
| W6 | Buffer | Buffer | Buffer |

---

## Option B: Combined Monthly-Count Charges (Additional Scope)

If 8L/10L/15L plans create a combined Lesson+Coaching+App charge, CAP must handle ticket-consumption allocation for the lesson component. This approaches ASCH-level complexity for those plan types.

### Additional Work (on top of Option A)

| # | Phase | Scope | Duration | Notes |
|---|---|---|---|---|
| B1 | Monthly-count allocation logic | Ticket consumption (I/J), partial months, carry-over | 1 wk | Similar to ASCH Monthly-15 handling |
| B2 | Additional scenarios | Suspension mid-month, ticket expiry, plan change with ticket transfer | 1 wk | ASCH Pattern 6 equivalent |
| B3 | Testing for combined plans | Additional fixtures + validation | 0.5 wk | |
| | **Option B additional** | | **+2.5 wk** | |
| | **Total (Option A + B)** | | **8.5 wk** | |

---

## Comparison Summary

| Dimension | Option A (Separate charges) | Option B (+ Combined charges) |
|---|---|---|
| **Total (2 devs)** | **6 weeks** | **8.5 weeks** |
| Complexity | Simple ratio allocation | + Ticket consumption |
| Tables | ~5 | ~5 (same — extra logic, not tables) |
| Acceptance scenarios | ~10 | ~15 |
| Risk | Low | Medium (monthly-count adds ASCH-level complexity for subset) |
| Depends on | ASCH patterns (reference only) | ASCH Monthly-15 implementation (direct dependency) |

---

## Impacted Repositories

| Repository | Role | Changes |
|---|---|---|
| `ls-database-migrations` | Schema source of truth | New `cap_*` table migrations (~5 tables) |
| `accounting_related_system_for_freee` | Main codebase | New CAP command, logic, models, services, CSV utility |
| `MBTI_backend` | Source of plan_id mapping | Read-only reference (no changes) |
| `bizmates.jp` | Source of charges | Read-only reference (no changes) |

---

## Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| D-1 unresolved (monthly-count plan structure) | Cannot finalize Option B scope | High (currently unconfirmed) | Estimate both options; start with Option A |
| ASCH not yet complete when CAP starts | No architectural reference to copy | Medium | CAP can still design independently; just slower |
| Coaching reference price differs by plan (15-min vs 30-min) | Formula needs plan-aware pricing | Low | Map plan_id → reference price (small lookup table) |
| App Freee mapping | Already resolved for ASCH (freee_code=236270504) | Low | Reuse same mapping |
| Combined lesson+coaching charge (Option B) | Significant complexity increase | Medium | Isolate as separate scope; estimate separately |

---

## Dependencies

| ID | Dependency | Required by | Status |
|---|---|---|---|
| D-1 | 15L/8L/10L CAP plan_ids, product composition, charge structure | Before design starts | **OPEN — blocks Option B scope** |
| D-2 | CAP Freee sender approach (reuse ASCH pattern or new adapter) | Phase 5 (Freee) | Recommend: same pattern as ASCH (dedicated command) |
| D-3 | Production App Freee mapping dimensions | Phase 5 (Freee) | Resolved (freee_code=236270504, same as ASCH) |
| D-4 | ASCH implementation (architectural reference) | Design phase | In progress (ASCH Spec 01 starting) |

---

## Workstream Breakdown (as requested by Kuroda-san)

| Workstream | Option A Effort | Option B Additional |
|---|---|---|
| CAP batch / data model | 2.5 weeks | +1 week |
| Freee / CSV integration | 1.5 weeks | — |
| Testing / UAT support | 1 week | +1.5 weeks |
| Buffer + review | 1 week | — |
| **Total** | **6 weeks** | **+2.5 weeks = 8.5 weeks** |

---

## Earliest Feasible Delivery Schedule

| Scenario | Start | End | Condition |
|---|---|---|---|
| **After ASCH (sequential)** | ~Oct 2026 | Nov–Dec 2026 | ASCH patterns available as reference. Cleanest. |
| **Parallel with ASCH (overlap)** | Aug 2026 | Oct–Nov 2026 | Can start once ASCH Foundation (Spec 01) is done. Needs coordination. |
| **Before ASCH** | Not recommended | — | No architectural template; would duplicate design effort. |

**Recommendation:** Start CAP design during ASCH Phase 2 (Weeks 5–6). By then, ASCH Foundation + Pattern 1 are done — CAP can reference the proven patterns. CAP development starts when ASCH developers become available (~Week 9–10 of ASCH).

---

## Why This Is Faster Than ASCH

| Factor | ASCH (9.5 wk / 1 dev) | CAP (6 wk / 2 devs) | Reason |
|---|---|---|---|
| Formula complexity | Conditional basis (L vs M per row) | Fixed ratio (constant) | No branching logic |
| Patterns | 9 complex patterns | ~10 simpler scenarios | No monthly-count (Option A), no campaign lifecycle |
| Eligibility | CDB + campaign window + cohort detection | plan_id lookup | Deterministic |
| Architectural design | From scratch | Copy ASCH patterns | Proven template exists |
| Discount logic | 5+ discount types interact | No discount branching | App_ref is constant |
| Month-6 trigger | Complex (Coaching C6 → Lesson L7) | None | Permanent allocation |
| Code investigation | Needed (existing monolith was unknown) | Already done for ASCH | RESEARCH-03/04 reusable |
