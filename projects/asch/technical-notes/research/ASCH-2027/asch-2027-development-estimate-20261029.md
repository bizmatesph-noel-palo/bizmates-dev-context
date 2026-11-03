# ASCH 2027 — Light Development Estimate & Timeline

## Document Info

| | |
|---|---|
| **Document type** | Project Estimation (light / rough) |
| **Date** | 2026-10-29 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Draft — **backed by the 2026-10-29 investigation** (`../../investigation/20261029-asch2027-logic-vs-testonly/REPORT-00-...md`): testing-only confirmed in code, buffer folded in. Rough number for Kuroda-san. |
| **Audience** | PM (Kuroda-san), SDM (Patrick-san) |
| **Source** | `REF-ASCH2027-01-Requirements-20261023.md` (Kuroda-san Confluence [DRAFT] + Slack thread) |
| **Companion** | `docs/asc-projects-master-timeline.md`, `docs/asc-projects-task-tracker.md` |

> **Light estimate, by request.** Rough order-of-magnitude, not a committed baseline. A firmer number follows once ASCI-11 Coding is underway (so the §7 test-pattern effort is grounded in real code) — targeted before the Lead's 2026-11-11 leave.

---

## Executive Summary

The 2027 ASCH (revenue booking for the 2027 Honki Campaign) needs **almost no new ASC code** — it rides the ASCA allocation engine (CAP) and ASCI Spec 01 (CIP) on the already-discounted charge amounts. A 2026-10-29 code investigation (REPORT-00, read-only) **confirms there are NO ASCH-side logic changes** — every unique campaign case (the §7 transitions P5/P6/P7, §4.5 cancellation, §4.4 half-price refunds) resolves to "billing issues the correctly-discounted/separated charges; ASC books the `paid_price` through existing / ASCA / ASCI logic." So the base work is **~3–5 dev-days of testing**. **With the 1–2 week buffer folded in, the expected number is ~2–2.5 weeks** (DEV04 fixtures for the §7 patterns, one reconcile round, QA, and the wait for ASCI-01 to be testable). **Fits** before the 2027-01-04 window / 2027-01-01 first run — *provided ASCI-01 ships* (ASCI is the critical path; ASCH is downstream). A contingency (Scenario B, ~4–5 weeks) applies only if a §7 run surfaces an ASC-logic gap — the evidence says it won't; the residual risk is entirely **upstream** (CDB clean-charge issuance + App 10021→10022), not ASCH code.

---

## Context

### What We're Building

The 2027 Honki Campaign gives a 50% discount in the first and 6th months to customers taking Coaching 30 min (CAP) or Coaching Intensive (CIP) with a lesson plan. The discount is applied **on the billing side** (CDB + charge batch), so ASC simply books the already-discounted `paid_price` through existing logic. ASC never identifies "Honki" charges (Accounting-confirmed). So "ASCH 2027" on the ASC side is a **verification + testing effort over ASCA/ASCI**, not a build.

### Deadline & Constraints

| Constraint | Value |
|---|---|
| Campaign application window | from **2027-01-04** |
| First affected close | 2027/01 (first half-price charges) |
| ASC deadline (shared ASCA/ASCI) | **2026/12/17**; first prod run 2027/01/01 |
| Team | Lead (Noel), Dev (Cristoff/Throy), QA (Glenn) |
| Hard dependency | **ASCI Spec 01 must ship** (CIP conversion + refund split live) |
| Lead leave | **2026-11-11 → 11-23** |

---

## Assumptions

- **ASCI-01 ships as planned** (conversion Req 2 + refund split Req 4) — the 2027 ASCH's CIP behavior IS ASCI-01; no separate CIP build.
- **ASCA is unchanged** — the 2-way formula already operates on the discounted N; CAP work is test-only.
- **No new DB / services / CSV** — §6 confirms no schema, no AllocationDetail CSV, no Metabase change, no campaign lookup.
- **CDB fixes its catalog upstream** (App 10021→10022, CIP 10025, half-price `price_flag=4`) before charges are issued — otherwise ASC books wrong numbers at the source (not an ASC-side effort, but a precondition).
- Open items (shareholder-App-share; Lesson shareholder refund) don't materially expand scope.

---

## Estimate

**No build, verification over ASCA/ASCI** — the cancelled 2026 ASCH's build-a-subsystem shape is dead (§4.1), and the 2026-10-29 investigation confirms **no new ASC logic** is needed (grounded in `CommonUtil`, `BundleDetectionService`, `TwoWayAllocationFormula`, `RefundLinkageResolver`, `getContractDateInfoList`). Two scenarios:

- **Scenario A (expected, evidence-supported): testing-only + 1–2 week buffer → ~2–2.5 weeks.** The phase table below (3–5 dev-days of actual work) plus buffer for DEV04 data prep, fixture reconciliation, the ASCI-ship wait, and QA/gate turnaround.
- **Scenario B (contingency only): ~4–5 weeks.** Triggers ONLY if a §7 run surfaces an ASC-logic gap (evidence says it won't) — any ASC code change must run the full spec-dev lifecycle (requirements→G1→design→G2→tasks→coding→G3→QA) with gate turnarounds, and could collide with the Nov 11–23 leave. This seriously threatens the 2026-12-17 deadline, which is why closing the upstream confirmations (below) matters.

### Scenario A phase breakdown (the base work)

| # | Phase | Scope | Est. | Who |
|---|---|---|---|---|
| 1 | CIP (§4.3/§4.4) | **0 incremental** — conversion + refund split already in ASCI-01 (G1-approved). | 0 d | (in ASCI-11) |
| 2 | CAP half-price verification | Confirm ASCA 2-way on a discounted N gives same-rate App reduction (§5.1: 57,200 → 28,600). Test, no code. | ~0.5 d | Dev + QA |
| 3 | §7 test patterns 1–4, 8 | Largely covered by ASCI-01 tests + a CAP half-month case; assemble fixtures + confirm. | ~1–1.5 d | Dev + QA |
| 4 | §7 test patterns **5, 6, 7** (net-new) | Campaign-transition scenarios ASCI unit tests don't cover: plan change mid-campaign (5), CIP⇔CAP move losing 6th-month 50% (6), joins-coaching-later (7). Build fixtures, run on DEV04, reconcile expected booked amounts. | ~2–3 d | Dev + QA |
| 5 | §4.1 reconcile + wrap | Confirm "Lesson booked alone" holds post-ASCA/ASCI; summarize results for Kuroda-san. | ~0.5 d | Lead |
| | **Total** | | **~3–5 dev-days** | |

### Grounding — why "testing-only" (code evidence)

The zero-ASC-logic basis of this estimate is verified in the live tree, not assumed. Full detail in the investigation report (`../../investigation/20261029-asch2027-logic-vs-testonly/REPORT-00-asch2027-logic-vs-testonly.md`, read-only). The load-bearing facts:

1. **ASC is campaign-blind by construction.** `grep -rli "honki|asch|campaign_discount_eligibility" app config` in `accounting_related_system_for_freee` returns **nothing**. `CommonUtil::createDailyRateCalculation()` reads only `trn_charge.paid_price` + per-charge keys and calls `getContractDateInfoList()`; a half-price month is just a smaller `paid_price` flowing through unchanged. `trn_charge` (ls-db) has no campaign column.
2. **CAP formula is input-agnostic to a half-price amount.** `TwoWayAllocationFormula::computeBundleAllocation()`: `P_app = floorDiv(N × L_app, L_app + L_coaching)`, `P_coaching = N − P_app`. `N` is the actual (possibly discounted) paid amount; `L_app`/`L_coaching` are fixed reference-price weights (3,618 : 36,000), **not derived from N** — so a half-price N reduces App at the same rate (§5.1: 57,200 → 28,600). `floorDiv` is integer floor toward −∞, so even a half-price *refund* (negative N) is safe.
3. **CIP↔CAP transition months don't collide.** Billing issues separate, non-overlapping charges (`bizmates.jp` `prorated.php::contractShorten()` sets old `end_date = new start_date − 1`). ASCA's `BundleDetectionService` groups on `student_id|order_no|plan_id|start_date|end_date` and filters CAP plan_ids 1016–1027 only; CIP (1028–1032) is excluded from the engine and handled by ASCI's own path (`RefundLinkageResolver` returns null for CIP). So a month with both a CIP- and a CAP-originated charge splits into **two independent buckets** — no mis-pairing, no double-count, no transition-aware logic.
4. **Refunds / cancellation already handled.** `getContractDateInfoList()` recognises a `paid_price < 0` as a single execution-month lump (not day-prorated). There is **no ASC "reverse the first-month discount" path** and none is needed — the first-month discount stays booked (no reversing charge), and a "lost" 6th-month discount just means billing issues that month at full price. ASCI Req 4.2 already splits CIP refunds on the month's booked amount (via `log_refund_history`), generalising to any half-price month.

#### Per-scenario verdict (from REPORT-00 §2 — all testing-only)

| § / Pattern | Scenario | Verdict | Grounding |
|---|---|---|---|
| §7 P5 | Lesson plan change mid-campaign (CAP) | **ASC testing-only** | `contractShorten()` truncates old Lesson charge; Lesson booked alone (§4.1); CAP pair unaffected (plan 1016–1027 membership unchanged on a Lesson swap). |
| §7 P6 | CIP↔CAP move mid-campaign (highest-risk) | **ASC testing-only — gap analysis found none** | Separate non-overlapping charges + `plan_id`+date grouping key → two independent buckets; CIP excluded from CAP engine, handled by ASCI path. |
| §7 P7 | Joins coaching later (first-month 50% on coaching only) | **ASC testing-only** | Later coaching = a new CAP/CIP pair with its own dates + discounted `paid_price`; pre-existing Lesson booked alone. No "join-later" branch exists or is needed. |
| §4.5 | Cancel within 6 months (first-month kept, 6th-month lost) | **ASC testing-only** | No reversing charge issued → nothing for ASC to do; 6th-month "loss" = full-price charge upstream. No discount-reversal path required. |
| §4.4 | CIP refunds in a half-price month | **ASC testing-only — already in ASCI Req 4** | Split basis = original charge's booking amount before day-proration (via `log_refund_history`); half-price = 1,990/37,950, not a hard-coded 3,980. Generalises by construction. |

**No scenario graded "needs new/changed ASC logic."** The residual risk is entirely upstream (see Dependencies + §5 of the report): billing must issue clean, correctly-discounted, correctly-separated charges — above all the CDB App `10021→10022` catalog fix.

### Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| ASCI-01 slips | ASCH can't verify CIP until ASCI lands | Med | ASCH is explicitly downstream; sequence after ASCI-11. Don't start ASCH verification before ASCI CIP is testable. |
| CDB catalog not fixed (App 10021→10022) | ASC books wrong numbers from wrong charges | Med | Flag to Soli-san now; precondition, not ASC work. |
| Shareholder-App-share reopens (Open Item 4) | Small refund-logic change in ASCI + retest | Low–Med | Reconcile ASCI Req 4.4 vs the ASCH doc; confirm with Accounting (Ito-san). |
| §7 patterns 5/6/7 reveal an ASCI gap | Could add ASCI code, not just ASCH tests | Low | These exercise transitions; if a real gap appears it's an ASCI fix, surfaced early by running the patterns. |

---

## Timeline

Anchored to the shared ASC deadline and the Lead's leave. ASCH is **downstream of ASCI-11** — it should not start until ASCI's CIP conversion + refund split are testable.

```
Now (10-29) ──> ASCI G2 sign-off ──> ASCI-11 Coding ──> ASCI G3 ──┐
                                                                   ├─> ASCH 2027 verification (~2–2.5 wk buffered; 3–5 dev-days of work) ──> report to Kuroda-san
   Lead leave 11-11 → 11-23 ───────────────────────────────────────┘ (ASCH verification ideally lands around/after ASCI is testable)
                              Shared deadline 12-17 · first prod run 2027-01-01 · campaign window 2027-01-04
```

| Scenario | Duration (Scenario A, buffered) | When ASCH verification runs | Fits? |
|---|---|---|---|
| Best | ~1 week | ASCI-11 done before 11-11; patterns pass first run | ✅ comfortable |
| Expected | **~2–2.5 weeks** | ASCI-11 + G3 late Nov; ASCH verification + one reconcile + QA early Dec | ✅ within 12-17 |
| Worst | ~3 weeks | ASCI-11 slips into/through the leave; ASCH can't start until ASCI CIP is testable; one re-run | ⚠️ tight but still before 2027-01-01 |

> **Scenario B (contingency, ~4–5 wk)** is the only path that breaches 12-17, and only if a §7 run finds an ASC-logic gap requiring the full spec workflow across the leave. Keep it a contingency by closing the upstream confirmations.

**Key point:** ASCH 2027 has slack because it's small, downstream, and (now verified) needs no ASC code — the schedule risk lives almost entirely in **ASCI-01** and in **upstream CDB** (clean charges + App 10021→10022), not in ASCH itself.

---

## Why This Estimate

The irreducible work is **writing and running the §7 test patterns**, especially the three transition scenarios (5/6/7) that span CAP+CIP+Lesson and aren't covered by ASCI's unit tests. Everything else is "confirm existing behavior on a discounted amount." There is no engine to build, no schema to migrate, no service to write — that work was already done (or is being done) in ASCA and ASCI. This is why the number is days, not weeks: the 2027 ASCH is a thin verification layer on top of machinery that already exists.

---

## Dependencies & Prerequisites

| Prerequisite | Needed by | Status |
|---|---|---|
| ASCI Spec 01 shipped (CIP conversion + refund split) | Phase 1/3/4 | In build (ASCI-11 gated on G2 sign-off) |
| ASCA merged + DEV04-verified | Phase 2 | ✅ Done |
| CDB catalog fixed (App 10021→10022, CIP 10025, half-price tier) | Before charges issued (upstream) | ⚠️ Open — Soli-san (CDB Open Item 3) |
| Shareholder-App-share decision | Phase 4 (if it changes refund logic) | ⚠️ Open — Accounting (Ito-san) |
| 2027 ASCH board / project structure | Before ticket creation | Deferred (reuse old ASCH board vs new — Lead) |

---

## Recommendation

Give Kuroda-san the **~2–2.5 week expected number (Scenario A)** — i.e. 3–5 dev-days of actual testing work with the 1–2 week buffer folded in — with the framing: *no ASC build, no new ASC logic (code-verified, REPORT-00); it rides ASCA/ASCI; the CIP points are already in ASCI-01; the effort is the §7 test patterns, dominated by 5/6/7.* **Sequence ASCH verification after ASCI-11** (ASCH is downstream). Treat the CDB catalog fix (App 10021→10022) as the real upstream risk and flag it to Soli-san. Keep Scenario B (~4–5 wk) as a contingency; firm the estimate once ASCI-11 Coding is underway, before the 11-11 leave.
