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

> **Update 2026-11-06** (after Kuroda-san's re-created requirements page, `REF-ASCH2027-02`, and his CDB Slack questions, `REF-ASCH2027-03`). "ASCH" = the NEW 2027 ASCH.
> - **Estimate accepted and unchanged:** Kuroda-san confirmed "testing only, 3–5 dev-days / about 2–2.5 weeks with buffer works for me". Scenario A stands; Scenario B stays a contingency.
> - **Deadline is looser:** ASC must be in production with CAP and CIP by the **end of January 2027** (first Honki charges 2027-01-04, first close = January, batch early February). ASCI keeps its own 2026-12-17 release.
> - **P5 refined:** on a Lesson plan change the CAP `plan_id` includes the lesson amount (1022 → 1023), so the Coaching and App charges are re-issued too, not only the Lesson. Plan changes take effect on the renewal date, so old and new charges do not overlap (CAP rule, 2026-08-03). Test data must re-issue all three charges. See the P5 row below.
> - **Closed by his page:** shareholder-App-share (App no share, Lesson eligible), App product ID 10022, the −181 half-price tax-exemption figure (Accounting-approved 2026-10-23).
> - **Still open upstream (CDB):** product IDs 10022 / 10025 are decided in HCI-11 Req 2 but the **released CDB code still has the old lists**; the half-price `price_flag = 4` amounts are in the charge-batch HCI requirements still being drafted (Paolo). Kuroda-san is aligning with Soli-san first; the Lead's reply to his dated plan is on hold. None of this changes ASC logic (see `REF-ASCH2027-03`).
> - **New dependency to watch:** CIP refunds and the conversion of refunded CIP bundles are **not yet working on DEV04** (`CipBundlePairing` counts the refund charge; fix tracked in **ASCI-19**). The CIP refund tests (pattern 8) need ASCI-19 verified first. This is an ASCI fix, not new ASCH work.

> **Update 2026-11-10 (Kuroda-san's third round 11-10 10:00 + 17:22; Glenn-san's QA estimate 11-09 18:31 + note 11-10 17:29; DSM answers). Reply drafted, sending not confirmed. Supersedes the 11-09 update where they differ.**
> - **QA (Glenn-san): 3–4 days** — test data 1–1.5, checks and comparison 1.5–2, rechecks 0.5–1. Glenn-san is available. Work stays **4.5–6.5 days** (QA 3–4, Lead 0.5–1, Dev 1–1.5).
> - **QA wait removed** (Glenn-san is free). Glenn-san read the wait as the development phase; it was buffer, not a phase.
> - **Buffer now 2.5–4 days:** Dev fix and rerun 0.5–1, review of results 0.5–1, DEV04 data issues 1.5–2. The Lead's review time and the Dev rerun time are estimates.
> - **Start Mon 12/7 (agreed at DSM):** the CAP/CIP team is fixing immediate REST (CAP-382) and the team needs time to apply the fix and test; 11/30 is a PH holiday; 12/1–12/4 pull the CAP/CIP/CDB changes into DEV04.
> - **Test sheet:** wanted from Kuroda-san as early as 11/23. Patterns still needed from him: **2, 4, 5, 6, 7** (1, 3, 8 are on his page).
> - **Finish: about 12/16–12/21** from 12/7 (12/8 counted as a PH holiday); about **12/15–12/18** if QA prepares the test data before 12/7.
> - **Scope wording:** "planned as testing only" (grounded on his requirements §6 and the 10/29 code check). A logic change is the full spec workflow and is not included. The "about 4–5 weeks" for that is a Kiro judgment from REPORT-00 Scenario B (phase nominals + ASCA slip + leave risk), not a measured figure.

> **Update 2026-11-09 (Kuroda-san's second round of questions, 11-09 21:30; final reply SENT to Kuroda-san on 11-09). Supersedes the "1 day / judgment buffer" notes below where they differ.**
> - **Buffer (about 5–6.5 days) grounded on project actuals, not a generic standard:** rework 1–1.5 (ASCA-81 passed on QA's 3rd recheck); waiting for QA / review 2.5–3 (ZPR: 8 working days from the DEV04 batch run 9/14 to QA complete 9/23); DEV04 data issues 1.5–2 (ZPR stale DEV04 DB → prod DB re-import; ASCA-86 deployed 11/4, not pulled on DEV04 until 11/6). A "20% standard" taken from the toolkit template was withdrawn.
> - **Roles:** expected values come from Kuroda-san's requirements and detailed test sheet (business decisions). QA prepares test cases and data and runs the checks. Dev runs the DEV04 batch commands per round, checks the pull, and helps when QA cannot or a setting change is needed. Work (estimates): Lead 0.5–1, QA 3–4 (Glenn-san to correct), Dev 1–1.5 → **4.5–6.5 days**.
> - **Sequential, not parallel.** A logic change / new feature = full spec workflow in order (about 4–5 weeks plus Dev time), not included. Small non-blocking change requests could run side by side.
> - **Levers:** detailed test sheet + QA test data before the start (about 2–3 days), ASCI-19 verified first (about 1–1.5 days), QA time reserved (depends on QA's schedule).
> - **Dates:** start Mon 11/30 → about 10–13 working days → **finish about 12/11–12/16**; with the first two levers → about **12/8–12/10**. Testing only; holidays not included.
> - **Values already on Kuroda-san's 11-04 page:** patterns **1, 3, 8** (§5, §4.4, §4.4b); partial for pattern 2 (§4.3).

> **Changes after Kuroda-san's estimate questions (2026-11-06 evening).** These are the proposed answers. Sending the reply is to be confirmed, and the numbers are provisional until QA confirms its time.
> - **Error fixed:** the phase table adds up to 4–5.5 days (0 + 0.5 + 1–1.5 + 2–3 + 0.5), not 3–5.
> - **New work counted:** the CAP half-price refund cases add about **+1 day (0.5–1.5)** to row 3. Work is now **5–6.5 days**, which is **0.25–0.33 man-months** (1 man-month = 20 days). Report the work days, not the buffer.
> - **Buffer:** a judgment range of about 5–6.5 days (rework after reconciling, QA and review gates, DEV04 data issues). It is not itemized, and any split is indicative only. Elapsed time stays about 2–2.5 weeks.
> - **ASCI wait removed:** ASCI-11 is merged and on DEV04. CIP refund cases still wait for ASCI-19.
> - **Leave:** not inside the 2–2.5 weeks. Verification starts at the end of November at the earliest.
> - **QA inserts the test data:** see the QA step under the phase table.
> - **Logic change is Scenario B:** about +4–5 weeks from the decision, not in the 2–2.5 weeks. To finish before the end of January it would have to start by about mid-December (rough; year-end holidays make it tighter).

---

## Executive Summary

The 2027 ASCH (revenue booking for the 2027 Honki Campaign) needs **almost no new ASC code** — it rides the ASCA allocation engine (CAP) and ASCI Spec 01 (CIP) on the already-discounted charge amounts. A 2026-10-29 code investigation (REPORT-00, read-only) **confirms there are NO ASCH-side logic changes** — every unique campaign case (the §7 transitions P5/P6/P7, §4.5 cancellation, §4.4 half-price refunds) resolves to "billing issues the correctly-discounted/separated charges; ASC books the `paid_price` through existing / ASCA / ASCI logic." So the base work is **~4–5.5 dev-days of testing** (corrected 2026-11-06: this was first written as 3–5, which did not match the phase table; **5–6.5 days** with the new CAP half-price refund cases, see the update note). **With the 1–2 week buffer folded in, the expected number is ~2–2.5 weeks** (DEV04 fixtures for the §7 patterns, one reconcile round, QA, and the wait for ASCI-01 to be testable). **Fits** before the 2027-01-04 window / 2027-01-01 first run — *provided ASCI-01 ships* (ASCI is the critical path; ASCH is downstream). A contingency (Scenario B, ~4–5 weeks) applies only if a §7 run surfaces an ASC-logic gap — the evidence says it won't; the residual risk is entirely **upstream** (CDB clean-charge issuance + App 10021→10022), not ASCH code.

---

## Context

### What We're Building

The 2027 Honki Campaign gives a 50% discount in the first and 6th months to customers taking Coaching 30 min (CAP) or Coaching Intensive (CIP) with a lesson plan. The discount is applied **on the billing side** (CDB + charge batch), so ASC simply books the already-discounted `paid_price` through existing logic. ASC never identifies "Honki" charges (Accounting-confirmed). So "ASCH 2027" on the ASC side is a **verification + testing effort over ASCA/ASCI**, not a build.

### Deadline & Constraints

| Constraint | Value |
|---|---|
| Campaign application window | from **2027-01-04** |
| First affected close | 2027/01 (first half-price charges) |
| ASC deadline (shared ASCA/ASCI) | **2026/12/17** (ASCI release); first prod run 2027/01/01. **ASCH:** ASC in production with CAP and CIP by the **end of January 2027** (first Honki close = January, batch early February) — Kuroda-san, 2026-10-30 / page of 2026-11-04 |
| Team | Lead (Noel), Dev (Cristoff/Throy), QA (Glenn) |
| Hard dependency | **ASCI Spec 01 must ship** (CIP conversion + refund split live) |
| Lead leave | **2026-11-11 → 11-23** |

---

## Assumptions

- **ASCI-01 ships as planned** (conversion Req 2 + refund split Req 4) — the 2027 ASCH's CIP behavior IS ASCI-01; no separate CIP build.
- **ASCA is unchanged** — the 2-way formula already operates on the discounted N; CAP work is test-only.
- **No new DB / services / CSV** — §6 confirms no schema, no AllocationDetail CSV, no Metabase change, no campaign lookup.
- **CDB fixes its catalog upstream** (App 10022 and CIP 10025 in the product lists, half-price `price_flag=4` amounts) before charges are issued — otherwise ASC books wrong numbers at the source (not an ASC-side effort, but a precondition). *Status 2026-11-06:* product IDs decided (HCI-11 Req 2, Paolo 2026-10-30) but not yet in the released CDB code; half-price amounts still in the HCI requirements being drafted. Because ASC only books the charges that exist, the P5–P7 fixtures can be built by inserting charges directly if CDB is late.
- Open items (shareholder-App-share; Lesson shareholder refund) don't materially expand scope.

---

## Estimate

**No build, verification over ASCA/ASCI** — the cancelled 2026 ASCH's build-a-subsystem shape is dead (§4.1), and the 2026-10-29 investigation confirms **no new ASC logic** is needed (grounded in `CommonUtil`, `BundleDetectionService`, `TwoWayAllocationFormula`, `RefundLinkageResolver`, `getContractDateInfoList`). Two scenarios:

- **Scenario A (expected, evidence-supported): testing-only + 1–2 week buffer → ~2–2.5 weeks.** The phase table below (4–5.5 dev-days of actual work, corrected 2026-11-06; 5–6.5 with the new CAP half-price refund cases) plus a buffer for rework after reconciling, QA and review gates, and DEV04 data issues. The buffer is a judgment range, not an itemized number. The wait for ASCI-11 is gone (ASCI-11 is merged and on DEV04); CIP refund cases still wait for ASCI-19.
- **Scenario B (contingency only): ~4–5 weeks.** Triggers ONLY if a §7 run surfaces an ASC-logic gap (evidence says it won't) — any ASC code change must run the full spec-dev lifecycle (requirements→G1→design→G2→tasks→coding→G3→QA) with gate turnarounds, and could collide with the Nov 11–23 leave. This seriously threatens the 2026-12-17 deadline, which is why closing the upstream confirmations (below) matters.

### Scenario A phase breakdown (the base work)

| # | Phase | Scope | Est. | Who |
|---|---|---|---|---|
| 1 | CIP (§4.3/§4.4) | **0 incremental** — conversion + refund split already in ASCI-01 (G1-approved). | 0 d | (in ASCI-11) |
| 2 | CAP half-price verification | Confirm ASCA 2-way on a discounted N gives same-rate App reduction (§5.1: 57,200 → 28,600). Test, no code. | ~0.5 d | Dev + QA |
| 3 | §7 test patterns 1–4, 8 | Largely covered by ASCI-01 tests + a CAP half-month case; assemble fixtures + confirm. **Added 2026-11-06:** CAP refunds in a half-price month (cooling-off, tax-exemption, shareholder, normal and half-price; the full refund is already seen on DEV04 with student 471), expected values in `REF-ASCH2027-02` §4.4b. | ~1–1.5 d, plus ~1 d (0.5–1.5) for the new CAP refund cases (provisional) | Dev + QA |
| 4 | §7 test patterns **5, 6, 7** (net-new) | Campaign-transition scenarios ASCI unit tests don't cover: plan change mid-campaign (5), CIP⇔CAP move losing 6th-month 50% (6), joins-coaching-later (7). Build fixtures, run on DEV04, reconcile expected booked amounts. | ~2–3 d | Dev + QA |
| 5 | §4.1 reconcile + wrap | Confirm "Lesson booked alone" holds post-ASCA/ASCI; summarize results for Kuroda-san. | ~0.5 d | Lead |
| | **Total** | | **~4–5.5 dev-days** (corrected 2026-11-06; **5–6.5** with the new CAP refund cases, 0.25–0.33 man-months at 20 days per man-month) | |

**QA step (explicit, added 2026-11-06).** The real CDB charge batch cannot issue half-price charges until the CDB release (~12/17), so QA inserts the half-price charges and refunds on DEV04. Sequence: Lead designs the expected values, QA inserts the charges and refunds, the batch runs, we compare. QA's time is inside rows 3 and 4. **To confirm with Glenn-san.**

**Logic-change contingency.** Any logic change is Scenario B, not testing only. That includes a gap found in a test run. (The CAP positive-side point QA found on 2026-11-06 was decided by Kuroda-san on 2026-11-09: no Spec 01 change; the CAP team fixes immediate REST upstream (CAP-382) and QA retests, so it is no longer a trigger.) It adds about 4–5 weeks from the decision date and is not inside the 2–2.5 weeks.

### Grounding — why "testing-only" (code evidence)

The zero-ASC-logic basis of this estimate is verified in the live tree, not assumed. Full detail in the investigation report (`../../investigation/20261029-asch2027-logic-vs-testonly/REPORT-00-asch2027-logic-vs-testonly.md`, read-only). The load-bearing facts:

1. **ASC is campaign-blind by construction.** `grep -rli "honki|asch|campaign_discount_eligibility" app config` in `accounting_related_system_for_freee` returns **nothing**. `CommonUtil::createDailyRateCalculation()` reads only `trn_charge.paid_price` + per-charge keys and calls `getContractDateInfoList()`; a half-price month is just a smaller `paid_price` flowing through unchanged. `trn_charge` (ls-db) has no campaign column.
2. **CAP formula is input-agnostic to a half-price amount.** `TwoWayAllocationFormula::computeBundleAllocation()`: `P_app = floorDiv(N × L_app, L_app + L_coaching)`, `P_coaching = N − P_app`. `N` is the actual (possibly discounted) paid amount; `L_app`/`L_coaching` are fixed reference-price weights (3,618 : 36,000), **not derived from N** — so a half-price N reduces App at the same rate (§5.1: 57,200 → 28,600). `floorDiv` is integer floor toward −∞, so even a half-price *refund* (negative N) is safe.
3. **CIP↔CAP transition months don't collide.** Billing issues separate, non-overlapping charges (`bizmates.jp` `prorated.php::contractShorten()` sets old `end_date = new start_date − 1`). ASCA's `BundleDetectionService` groups on `student_id|order_no|plan_id|start_date|end_date` and filters CAP plan_ids 1016–1027 only; CIP (1028–1032) is excluded from the engine and handled by ASCI's own path (`RefundLinkageResolver` returns null for CIP). So a month with both a CIP- and a CAP-originated charge splits into **two independent buckets** — no mis-pairing, no double-count, no transition-aware logic.
4. **Refunds / cancellation already handled.** `getContractDateInfoList()` recognises a `paid_price < 0` as a single execution-month lump (not day-prorated). There is **no ASC "reverse the first-month discount" path** and none is needed — the first-month discount stays booked (no reversing charge), and a "lost" 6th-month discount just means billing issues that month at full price. ASCI Req 4.2 already splits CIP refunds on the month's booked amount (via `log_refund_history`), generalising to any half-price month.

#### Per-scenario verdict (from REPORT-00 §2 — all testing-only)

| § / Pattern | Scenario | Verdict | Grounding |
|---|---|---|---|
| §7 P5 | Lesson plan change mid-campaign (CAP) | **ASC testing-only** (refined 2026-11-06) | `contractShorten()` truncates the old Lesson charge; Lesson booked alone (§4.1). **Correction:** the CAP `plan_id` includes the lesson amount (1022 → 1023), so the Coaching and App charges are re-issued on the renewal date together with the Lesson; old and new charges do not overlap (CAP rule 2026-08-03, per Kuroda-san 2026-11-04). The new charges form a new CAP bundle under the existing `plan_id` + date grouping key (plan 1016–1027 membership unchanged). Not yet exercised — confirm in the P5 run. Fixtures must re-issue all three charges. |
| §7 P6 | CIP↔CAP move mid-campaign (highest-risk) | **ASC testing-only — gap analysis found none** | Separate non-overlapping charges + `plan_id`+date grouping key → two independent buckets; CIP excluded from CAP engine, handled by ASCI path. |
| §7 P7 | Joins coaching later (first-month 50% on coaching only) | **ASC testing-only** | Later coaching = a new CAP/CIP pair with its own dates + discounted `paid_price`; pre-existing Lesson booked alone. No "join-later" branch exists or is needed. |
| §4.5 | Cancel within 6 months (first-month kept, 6th-month lost) | **ASC testing-only** | No reversing charge issued → nothing for ASC to do; 6th-month "loss" = full-price charge upstream. No discount-reversal path required. |
| §4.4 | CIP refunds in a half-price month | **ASC testing-only — already in ASCI Req 4** | Split basis = original charge's booking amount before day-proration (via `log_refund_history`); half-price = 1,990/37,950, not a hard-coded 3,980. Generalises by construction. |

**No scenario graded "needs new/changed ASC logic."** The residual risk is entirely upstream (see Dependencies + §5 of the report): billing must issue clean, correctly-discounted, correctly-separated charges — above all the CDB App `10021→10022` catalog fix.

### Risks

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| ASCI-01 slips | ASCH can't verify CIP until ASCI lands | Med | ASCH is explicitly downstream; sequence after ASCI-11. Don't start ASCH verification before ASCI CIP is testable. |
| CDB catalog and half-price amounts not ready (product IDs 10022 / 10025 decided but not in released code; `price_flag = 4` amounts in HCI requirements still being drafted) | ASC books wrong numbers if CDB issues wrong charges; real charge batch cannot generate half-price test data on DEV04 | Med | Owned by Kuroda-san / Soli-san / Paolo (2026-11-05 thread, `REF-ASCH2027-03`). Precondition, not ASC work. Our P5–P7 fixtures can be inserted directly if CDB is late. |
| ~~Shareholder-App-share reopens (Open Item 4)~~ | — | **Closed** | Closed 2026-10-23 (App no share, Lesson eligible); matches ASCI Req 4.4. |
| CIP refund split and conversion of refunded bundles not working on DEV04 (ASCI-19) | CIP pattern 8 cannot be verified until fixed; CIP readiness for the January close | Med | ASCI fix, not ASCH work. ASCI-19 raised 2026-11-06; deployed to DEV04 and the batch run on 2026-11-10 (ASCI-22); QA PASS 2026-11-10 (Glenn-san) for the five CIP refund students. Verify on DEV04 before running CIP refund tests. |
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

### Kuroda-san's proposed dated plan (2026-11-04) — recorded, reply on hold

Kuroda-san proposed this plan and asked the Lead to adjust the dates. The reply is on hold until he and Soli-san align on the CDB items (`REF-ASCH2027-03`). Lead is on leave 2026-11-11 → 11-23.

| When | What |
|---|---|
| Before 11/10 | Firm up the estimate; design the test data for P5–P7 |
| Early Dec | ASCI CIP testable on DEV04 (CIP conversion is already on DEV04; CIP refunds wait for ASCI-19) |
| ~12/11 | Run P5–P7 first; if they show a logic gap, Scenario B (4–5 weeks) still fits before end of January |
| 12/17 | ASCI release (unchanged) |
| Late Dec – mid Jan | Other patterns (1–4, 8), QA, Accounting check |
| End of January | Verification done; ASC in production |

Lead's read: P5–P7 fixtures can be designed after the leave without hurting this plan, since the run date is ~12/11. Not yet agreed with Kuroda-san.

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
