# ASC for CIP — Development Estimation

## Document Info

| | |
|---|---|
| **Document type** | Project Estimation |
| **Date** | 2026-07-28 (revised) |
| **Author** | Noel Palo, Lead Developer |
| **Audience** | Kuroda-san (PM), Patrick-san (SDM), Stakeholders |
| **Status** | Draft (preliminary — pending D-1 reference prices) |

---

## Executive Summary

ASC for CIP is structurally identical to CAP Option A (2-product allocation: Coaching + App, simple list-price ratio, plan_id discriminator, daily-rate N source only). Estimated at **6–7 weeks with 2 developers** or **8–9 weeks with 1 developer**. December 2026 delivery is **feasible** with either team size if development starts by mid-October to early November.

> **Honesty note:** These estimates include real-world friction (PR cycles, environment issues, scenario edge cases, QA rework). Even though CIP is "the same formula as CAP," it's still a distinct project with its own test scenarios, table namespace, and unknowns around reference prices and contract-type handling.

---

## Context

### What We're Building

A batch subsystem that allocates the customer-paid CIP Coaching amount between Coaching and App, then sends the adjustment (P − N) to Freee. Same operational model as ASCH/CAP: preview on 1st, final on 3rd, run_id generation model, separate command, separate email.

### Formula

```
App allocation     = N × App_list_price / (Coaching_list_price + App_list_price)
Coaching allocation = N - App allocation
Adjustment         = Allocated amount - Existing recognized amount (N)
```

Where:
- N = amount already recognized by existing ASC (from `log_daily_rate_calculation`)
- App_list_price = TBD (D-1 — placeholder until confirmed)
- Coaching_list_price = TBD (D-1 — likely derived from ¥80,000/month tax-excl pricing)
- Allocation basis = **list price** (confirmed — same as ASCH's Honki Set discount treatment)

### Why CIP = CAP Option A (Nearly Identical Scope)

| CAP Option A | CIP | Same? |
|---|---|---|
| 2 products (Coaching + App) | 2 products (Coaching + App) | ✅ |
| Simple list-price ratio | Simple list-price ratio | ✅ |
| plan_id discriminator | plan_id discriminator | ✅ |
| N from `log_daily_rate_calculation` | N from `log_daily_rate_calculation` | ✅ |
| No monthly-count/ticket dependency | No monthly-count/ticket dependency | ✅ |
| App = ¥0 paid, separate charge | App = ¥0 paid, separate charge (working assumption) | ✅ |
| `cap_*` tables | `cip_*` tables | Different namespace, same structure |
| B2C + B2E (B2B staged) | B2C + B2E + B2B (all from day 1) | CIP slightly broader |
| Taiwan included | Taiwan excluded | CIP excludes |

### Deadline

| Constraint | Value |
|---|---|
| Application-side release | December 2026 |
| First accounting batch run | 2027/01/01 (January monthly close covers December CIP sales) |
| Accounting system must be ready by | December 2026 (cannot trail application release) |
| Available time (if start mid-Oct) | ~10 weeks (Oct 13 → Dec 22) |
| Available time (if start Nov) | ~7 weeks (Nov 3 → Dec 22) — tight |

---

## Assumptions

- ASCH is completed first (provides proven architectural template)
- CAP may be in parallel — if CAP is done first, CIP can reuse even more directly
- Lead developer handles requirements → design → task generation
- 2 developers execute tasks
- `cip_*` table namespace (separate from `asch_*` and `cap_*`)
- App Freee mapping (freee_code=236270504) already confirmed — reusable
- Daily-rate recognition only (no monthly-count/ticket complexity)
- Reference prices are placeholder until D-1 confirmed (changes constants only, not design)
- Coaching + App start/suspend/end simultaneously (RA-06)

---

## Phase Breakdown

### Lead + 2 Developers: 6–7 weeks

| # | Phase | Scope | Duration | Notes |
|---|---|---|---|---|
| 1 | Schema & Foundation | ~5 `cip_*` tables. Run lifecycle. Command skeleton. | 1.5 wk | Copies ASCH/CAP pattern — still needs implementation + review |
| 2 | Eligibility & Source | CIP plan_id mapping. Source charge verification. Zero-yen App charge validation. N reading. | 0.5 wk | Deterministic — plan_id lookup |
| 3 | Core Allocation | Formula implementation. Rounding. Per-charge allocation. Invariant: App + Coaching = N. | 1 wk | Simple ratio — but needs test fixtures |
| 4 | Scenarios | Refund, plan change (to/from CIP), contract-type change (B2C/B2E/B2B), cooling-off, suspension, post-release correction. | 1.5 wk | ~11 acceptance scenarios |
| 5 | Freee + CSV | Journal factory (T1), Freee API, CSV, zip, email. | 1 wk | Same pattern as ASCH/CAP |
| 6 | Testing + Buffer | Automated tests. Bug fixes. PR rework. Environment issues. | 1.5 wk | Real-world friction included |
| | **Total (2 devs)** | | **7 wk** | |

### Lead + 1 Developer: 8–9 weeks

| # | Phase | Scope | Duration | Notes |
|---|---|---|---|---|
| 1 | Schema & Foundation | Same | 2 wk | Sequential — no task splitting |
| 2 | Eligibility & Source | Same | 1 wk | |
| 3 | Core Allocation | Same | 1 wk | |
| 4 | Scenarios | Same | 2 wk | Sequential execution |
| 5 | Freee + CSV | Same | 1.5 wk | |
| 6 | Testing + Buffer | Same | 1.5 wk | |
| | **Total (1 dev)** | | **9 wk** | |

---

## Timeline (2 developers)

| Week | Dev 1 | Dev 2 | Lead |
|---|---|---|---|
| W1 | Foundation (tables, models, run lifecycle) | Foundation (migrations, seeders, tests) | Req + Design |
| W2 | Eligibility + Core allocation | Scenarios (refund, plan change) | PM sign-off + PR review |
| W3 | Scenarios (contract change, cooling-off, correction) | Freee + CSV | Design + PR review |
| W4 | Testing + validation | Testing + bug fixes | PR review + DEV04 deploy |
| W5 | Dev testing | Dev testing | Validation |
| W6 | Buffer | Buffer | Buffer |

---

## December 2026 Feasibility

### With 2 developers:

| Start Date | End Date | Duration | Buffer to Jan 1 | Feasible? |
|---|---|---|---|---|
| Oct 6 | Nov 23 | 7 weeks | 5 weeks | ✅ Very comfortable |
| Oct 20 | Dec 7 | 7 weeks | 3 weeks | ✅ Comfortable |
| Nov 3 | Dec 21 | 7 weeks | 1.5 weeks | ⚠️ Tight (holidays) |
| Nov 17 | Jan 4 | 7 weeks | ❌ Overrun | ❌ |

### With 1 developer:

| Start Date | End Date | Duration | Buffer to Jan 1 | Feasible? |
|---|---|---|---|---|
| Oct 6 | Dec 7 | 9 weeks | 3 weeks | ✅ Comfortable |
| Oct 20 | Dec 21 | 9 weeks | 1.5 weeks | ⚠️ Tight (holidays) |
| Nov 3 | Jan 4 | 9 weeks | ❌ Overrun | ❌ |

**Conclusion: December delivery is feasible with either team size, but start date matters.**
- 2 devs: start by early November at latest
- 1 dev: start by mid-October at latest
- Recommended: start mid-October (after ASCH stabilizes) with 2 devs for maximum confidence

---

## Workstream Breakdown (as requested)

| Workstream | Lead + 2 Devs | Lead + 1 Dev |
|---|---|---|
| CIP batch / data model | 3 weeks | 4 weeks |
| Freee / CSV integration | 1.5 weeks | 2 weeks |
| Testing / UAT support | 1 week | 1.5 weeks |
| Buffer + review + friction | 1.5 weeks | 1.5 weeks |
| **Total** | **7 weeks** | **9 weeks** |

---

## Impacted Repositories

| Repository | Role | Changes |
|---|---|---|
| `ls-database-migrations` | Schema source of truth | New `cip_*` table migrations (~5 tables) |
| `accounting_related_system_for_freee` | Main codebase | New CIP command, logic, models, services, CSV utility |
| `MBTI_backend` | Source of plan_id mapping | Read-only reference (no changes from CIP accounting side) |
| `bizmates.jp` | Source of charges | Read-only reference (no changes from CIP accounting side) |

---

## Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| D-1 (reference prices) unresolved | Cannot finalize allocation constants | Medium | Design is price-agnostic; constants change, not structure |
| D-2 (App charge mechanism) differs from CAP assumption | May need different source join logic | Low | Working assumption confirmed; verify with sample data |
| D-3 (Freee sender approach) | Architectural decision needed | Low | Recommend: same dedicated-command pattern as ASCH |
| ASCH delays impact CIP start | Less architectural reference available | Low | CIP can start independently; just slightly less efficient |
| D-5 (contract-type/dept values on new charges) | May affect Freee journal dimensions | Medium | Estimate assumes charge-time attributes usable as-is |
| Holiday season (Dec) | Reduced availability | Medium | Start mid-Oct to build margin before holidays |

---

## Dependencies

| ID | Dependency | Required by | Status |
|---|---|---|---|
| D-1 | Coaching and App list prices (JPY, tax basis, per contract type) | Before calculation implementation | **OPEN** — placeholder prices for now |
| D-2 | App charge creation mechanism (zero-yen independent charge, CAP-style) | Foundation phase | Working assumption (confirmed 2026-07-27) |
| D-3 | CIP Freee sender approach | Phase 5 (Freee) | Recommend: dedicated command (same as ASCH/CAP) |
| D-4 | Production Freee mapping for CIP App | Phase 5 (Freee) | Likely same as ASCH (freee_code=236270504) — confirm |
| D-5 | Contract-type/dept/order_no on new CIP charges | Phase 4 (scenarios) | Assume charge-time attributes usable |
| D-6 | Post-release correction process | Phase 4 (revision run) | Assume ASCH-style revision run mechanism |
| D-7 | ASCH completion (architectural reference) | Before CIP start (ideal) | ASCH targets Oct 1 |

---

## Comparison to CAP Estimate

| Dimension | CAP Option A | CIP | Difference |
|---|---|---|---|
| Total effort (Lead + 2 devs) | 6–7 weeks | 6–7 weeks | Same |
| Total effort (Lead + 1 dev) | 8–9 weeks | 8–9 weeks | Same |
| Formula | App_ref / (Coaching_ref + App_ref) × N | Same formula | None |
| Scenarios | ~10 | ~11 (+ post-release correction) | Minor |
| B2B from day 1 | No (staged) | Yes | +1 test scenario |
| Monthly-count risk | Option B exists | None | CIP is simpler |
| Deadline pressure | TBD | December 2026 | CIP has a hard date |

**CIP and CAP are essentially the same accounting project with different plan_ids and reference prices.** If both are built, significant architectural patterns are shared — but per RA-09, tables remain separate (`cap_*` vs `cip_*`).

---

## Recommendation

**December 2026 delivery is feasible with 6 weeks of development (2 developers).**

Recommended approach:
1. Complete ASCH (target Oct 1) — establishes all patterns
2. Start CIP mid-October (after ASCH stabilizes)
3. Deliver CIP by end of November — 4 weeks buffer before Jan 1 batch

If CAP is also targeting December, consider whether CIP and CAP can share a common abstract allocation service (same formula, different config) while keeping tables separate. This is an engineering decision, not a business one — flag for design phase.
