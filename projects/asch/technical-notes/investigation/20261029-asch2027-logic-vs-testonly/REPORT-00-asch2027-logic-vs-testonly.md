# REPORT-00 — ASCH 2027: Does it need new ASC logic, or is it genuinely testing-only?

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report (read-only — no code/spec modified) |
| **Date** | 2026-10-29 |
| **Author** | Noel Palo, Lead (Kiro-assisted) |
| **Status** | Complete |
| **Audience** | PM (Kuroda-san), SDM (Patrick-san), Dev (Throy, Cristoff), QA (Glenn) |
| **Question under test** | Is the 2027 ASCH "~3–5 dev-days, testing only" credible, or do its unique campaign-transition business rules (§7 patterns 5/6/7, §4.4, §4.5) require new/changed ASC code? |
| **Inputs read** | `REF-ASCH2027-01-Requirements-20261023.md`, `asch-2027-development-estimate-20261029.md`, ASCI Spec 01 `requirements.md` + `design.md` (promoted in the code repo), ASCA/ASCI `project-context.md`, `domain-knowledge/{plans-and-products,campaigns}.md`, `asca-development-workflow.md`, `docs/asc-projects-{master-timeline,task-tracker}.md` |
| **Code read** | `accounting_related_system_for_freee` @ `feature/ASCI/ASCI-10-spec-1-tasks` (ASCA foundation merged): `CommonUtil::createDailyRateCalculation()` + `getContractDateInfoList()`; `RevenueAllocation/{BundleDetectionService, Formula/TwoWayAllocationFormula, Refund/RefundLinkageResolver}.php`. `ls-database-migrations`: `trn_charge` + `log_refund_history` migrations. `bizmates.jp`: `fuel/app/classes/libs/prorated.php` (charge issuance / refund / contract-shorten) |

---

## 1. Summary answer (grounded)

**The "testing-only" claim holds for the ASC side, with ONE qualifier that is NOT an ASC-code item.** Every one of the five scenarios under test (§7 patterns 5, 6, 7; §4.5 cancellation; §4.4 CIP half-price refunds) resolves to: **the billing side issues the correct charges, and ASC books whatever `paid_price` it receives through existing / ASCA / ASCI logic.** I found **no scenario that requires new or changed ASC (accounting-batch) logic.**

The verdicts are grounded in three load-bearing code facts, each verified in the live tree:

1. **ASC is campaign-blind by construction.** `grep` for `honki|asch|campaign_discount_eligibility` across `app/` + `config/` in the ASC repo returns **nothing**. The daily-rate path reads only `trn_charge.paid_price` and the per-charge keys — it never looks up a campaign. A half-price month is just a smaller `paid_price` flowing through unchanged.

2. **The CAP allocation formula is a pure function of the paid amount N and the fixed reference-price weights** — it has no hidden full-price assumption, so a half-price N produces a same-rate split with no edge case. (`TwoWayAllocationFormula`.)

3. **A mid-campaign plan change / CIP↔CAP move produces clean, non-overlapping, separately-dated charges on the billing side** (`prorated.php::contractShorten()` shortens the old charge's `end_date` to the day before the new charge's `start_date`), and ASCA's detection **keys its grouping on `plan_id` + `start_date` + `end_date`** (`BundleDetectionService`), so CIP-originated and CAP-originated charges in a transition month land in **different buckets and are never mis-paired or double-counted.**

**The one qualifier** is that the 2027 ASCH's CIP half-price behaviour depends on ASCI Spec 01 (Req 2 conversion + Req 4 refund split) shipping — and it already does, by design: ASCI's conversion is explicitly **campaign-agnostic** (ASCI design Property 2) and its refund split uses the **month's booked amount** via `log_refund_history` (Req 4.2 / Property 4), which generalises to any half-price month with no additional ASCH logic. So the CIP points are **0 incremental ASCH code**, exactly as the estimate assumes. They are an ASCI dependency, not ASCH work.

**Net: there are no ASCH-side logic changes.** The irreducible work is writing and running the §7 test patterns — genuinely testing.

> **Caveat the estimate must carry (not an ASC-code item):** the whole chain is valid **only if the billing side (CDB + charge batch) issues clean, correctly-discounted, correctly-separated charges** — in particular CDB Open Item 3 (catalog still expects App 10021, must be 10022; CIP 10025; half-price `price_flag=4` tier). If billing issues wrong charges, ASC books wrong numbers at the source. That is an upstream precondition owned by Soli-san (CDB), not ASCH code. See §5.

---

## 2. Per-scenario verdict table

| § / Pattern | Scenario | Verdict | Code evidence |
|---|---|---|---|
| **§7 P5** | Lesson plan change during the 6 months (e.g. 15↔2 lessons) — CAP | **ASC testing-only** | Billing: `prorated.php::contractShorten()` truncates the old Lesson charge's `end_date`, a new Lesson charge is inserted with its own dates/`paid_price`. ASC: Lesson is booked alone through `getContractDateInfoList()` day-proration (REF-ASCH2027 §4.1); the Coaching/App pair is unaffected. The Coaching 30-min plan membership (1016–1027) doesn't change on a *Lesson* swap, so `BundleDetectionService` keeps pairing the same CAP bundle. Nothing cross-aware needed. |
| **§7 P6** | Move between CIP (1028–1032) and Coaching-30 CAP (1016–1027) mid-campaign, both directions; loses 6th-month 50%, keeps first-month 50% | **ASC testing-only (highest-risk → verified no gap)** | Billing issues **separate** charges with **distinct date ranges** (`contractShorten()` makes the periods non-overlapping). ASC routes each by `plan_id`: CAP charges enter `BundleDetectionService` (filter `CoachingAndAppPlanEnum` 1016–1027); CIP charges are **explicitly excluded** there and handled by the ASCI CIP path (`RefundLinkageResolver` returns null for `CoachingIntensivePlanEnum` 1028–1032; ASCI design confirms `BundleDetectionService` never admits CIP). Because the grouping key is `student_id|order_no|plan_id|start_date|end_date`, a month containing BOTH a CIP-originated and a CAP-originated charge splits into **two independent buckets** — no cross-aware transition logic, no mis-pairing, no double-count. See §3.2 for the explicit gap analysis. |
| **§7 P7** | Already has a Lesson plan, joins coaching later (first-month 50% on coaching only) | **ASC testing-only** | The later coaching sign-up is just a new CAP (or CIP) charge pair with its own dates and its own (discounted) `paid_price`. ASC detects/books it exactly like any other CAP/CIP contract — the pre-existing Lesson charge is booked alone (§4.1) and never pooled with it. No "join-later" branch exists or is needed. |
| **§4.5** | Cancellation within 6 months — first-month discount NOT reversed; only 6th-month discount lost | **ASC testing-only** | ASC does nothing special. It books whatever charges were actually issued. If a refund negative is issued, `getContractDateInfoList()` recognises a `paid_price < 0` as a **single lump in the `paid_at` execution month** (not day-prorated) — see §3.3. There is **no ASC-side "reverse the first-month discount" path**, and none is required: the first-month discount simply stays booked because no reversing charge is issued. "Losing the 6th-month discount" means the 6th-month charge is issued at full price upstream — ASC books that full price with no awareness it was ever a campaign. |
| **§4.4** | CIP refunds in a half-price month (cooling-off, consumption-tax, shareholder) | **ASC testing-only — already covered by ASCI Spec 01 Req 4** | ASCI Req 4.2 / design Property 4: the refund split basis is the **original charge's booking amount before day-proration**, read via `log_refund_history` — `3,980/75,900` standard, `1,990/37,950` half-price — explicitly **not** a hard-coded `3,980`. Worked half-price values are in ASCI Req 4.5–4.7 (cooling-off −34,155 → −32,364/−1,791; tax-exemption −3,450 → −3,269/−181; full −37,950 → −35,960/−1,990) and Req 5.3 verifies them. The split **generalises to any month's booked amount by construction** — no additional ASCH logic. |

**Legend:** *ASC testing-only* = resolves entirely to "billing issues the correct charges; ASC books through existing/ASCA/ASCI logic." No scenario graded *needs new/changed ASC logic*.

---

## 3. Evidence detail (file + symbol citations)

### 3.1 ASC books the discounted `paid_price` through existing logic — it never knows about the campaign

`CommonUtil::createDailyRateCalculation()` (accounting repo) loops `TrnCharge::getTrnChargeList()` and for each charge calls:

```php
$ContractDateLists = static::getContractDateInfoList(
    $trnCharge->start_date, $trnCharge->end_date,
    $trnCharge->paid_at, $trnCharge->paid_price, $trnCharge->product_id);
```

The discount is already inside `$trnCharge->paid_price`. The loop writes the per-month N rows, then calls `app(AllocationInjector::class)->allocate($targetYm, $preFlg)` for CAP only. There is **no campaign lookup, no Honki flag, no eligibility read** anywhere in this path — confirmed by `grep -rli "honki|asch|campaign_discount_eligibility" app config` returning empty. `trn_charge` (ls-db migration) has no campaign column; `paid_price` is simply "the amount actually paid." This is the architectural basis for every "testing-only" verdict: a half-price charge is indistinguishable from a full-price charge except that the number is smaller.

### 3.2 Pattern 6 (the highest-risk case) — explicit gap analysis: no transition-aware logic needed

The worry is a transition month that contains **both** a CIP-originated and a CAP-originated coaching charge — could they be mis-detected, mis-paired, or double-counted? Verified they cannot:

- **Billing separates them cleanly.** `prorated.php::contractShorten($charge_id, $next_charge_start_date)` sets the old charge's `end_date = next_start_date − 1 day`. So the pre-switch and post-switch charges have **non-overlapping date ranges**. Each side (Coaching Intensive + App, or Coaching 30 + App) is its own pair with its own dates.
- **ASC routes by `plan_id`, and the engine is CAP-only.** `BundleDetectionService::fetchCandidateRows()` filters `whereIn('c.plan_id', CoachingAndAppPlanEnum::toArray())` (1016–1027) and re-guards in PHP with `CoachingAndAppPlanEnum::exists()`. **CIP plan_ids 1028–1032 never reach grouping** — the docblock states it explicitly ("CIP plans (1028–1032) … are excluded here by the `CoachingAndAppPlanEnum` membership filter … no CIP row ever reaches grouping"). The CAP refund path agrees: `RefundLinkageResolver::resolveOriginalBundle()` returns null when `CoachingIntensivePlanEnum::exists($planId)`.
- **The grouping key folds in dates, so same-month different-pairs split.** `BundleDetectionService::groupKey()` = `student_id | order_no | plan_id | start_date | end_date`. A CIP charge and a CAP charge in the same calendar month have different `plan_id` AND different dates, so they key into **different buckets**. The docblock's Req 6.10 note: "a mid-month renewal / cancel-and-rebuy that produces two same-plan pairs with different dates naturally splits into two separate bundles." The same mechanism separates a CIP→CAP switch.
- **CIP is handled by its own ASCI path.** The CIP-originated charge is converted + booked by ASCI's `CipChargeConverter` / `CipRefundAllocator` (ASCI design §Architecture), which run alongside — not inside — the CAP engine. No shared state, no cross-aware pairing.

**Conclusion for P6:** a transition month is just two independent pairs, each booked by the path that owns its `plan_id`. There is **no gap** requiring ASC transition-aware logic. The only thing that must be true is that **billing issues the two charges with clean, non-overlapping dates and the right discounted amounts** — an upstream (CDB/charge-batch) property, not ASC code. This is the single item worth an explicit human confirmation (see §5).

### 3.3 §4.5 cancellation & refunds — the negative path already exists, no "reverse the discount" logic

`CommonUtil::getContractDateInfoList()` opens with:

```php
// 支払い金額がマイナスの場合、日割計算を行わない
if ($paidPrice < 0) {
    $returnList[$paidDate->format('Ym')] = array( ... 'paidPrice' => $paidPrice, );
    return $returnList;   // single lump in the paid_at (execution) month
}
```

So any refund negative is recognised as a lump in its execution month, never day-prorated — matching ASCI Req 4.9. On the billing side, `prorated.php::doReferenceTransactionRefund()` clones the charge, sets `paid_price = -$refund_price`, inserts a new `trn_charge` row and a `log_refund_history` row (`refunded_charge_id` → `refund_charge_id`). That `log_refund_history` row is exactly what ASCA 02b and ASCI Req 4 read to link a refund to its original.

For §4.5 specifically: a first-month discount is "not reversed" because **no reversing charge is issued** — there is simply nothing for ASC to do. A 6th-month discount is "lost" because the 6th-month charge is **issued at full price upstream**; ASC books that full price with no campaign awareness. **No ASC-side discount-reversal expectation exists, and none is required.**

### 3.4 Half-price input robustness — CAP formula and CIP conversion are input-agnostic (verified)

The estimate assumes ASCA/ASCI are "input-agnostic" to a half-price amount. Verified in code:

- **CAP (`TwoWayAllocationFormula::computeBundleAllocation`):** `P_app = floorDiv(N × L_app, L_app + L_coaching)`, `P_coaching = N − P_app`. `N` is `Σ paidPrice` across the bundle (the actual, possibly-discounted amount). `L_app`/`L_coaching` are **fixed reference-price weights** (App 3,618 : Coaching 36,000 — from `mst_alloc_reference_prices`), **not derived from N**. So a half-price N (e.g. 19,242 vs 38,483) yields a proportionally smaller `P_app` — the App reduces at the **same rate** as Coaching, which is exactly §4.2 / §5.1 (57,200 → 28,600). **No full-price assumption, no reference-price-vs-N coupling.** `floorDiv()` is a true floor toward −∞ computed with integer arithmetic (no float precision loss), and it handles negative N (refunds) correctly — so even a half-price *refund* month is safe. The `totalWeight === 0` branch is deterministic (all to Coaching). No integer-floor edge case that breaks on a half-price input.
- **CIP (`CipChargeConverter`, ASCI design):** `App_booking = FLOOR(site × 3,980 / 75,900)`, `Coaching = site − App`. ASCI design Property 2 ("campaign-agnostic ratio invariance") states the ratio is applied regardless of the month's paid amount; `S=75,900→71,920/3,980` and `S=37,950→35,960/1,990` both follow from the one rule. The `3,980/75,900` constants are **fixed ratios, not reference prices**, and are not read from `mst_alloc_*`. So a half-price input is handled by the same arithmetic with no branch.

### 3.5 The CIP asks are already inside ASCI Spec 01 (0 incremental ASCH)

REF-ASCH2027 §6 + Open Items 1–2 name only two CIP changes the 2027 ASCH needs: the site→booking conversion that follows the paid amount, and the refund split on the App's booked amount. Both are in the **G1-approved** ASCI Spec 01 (`requirements.md` Req 2 + Req 4; `design.md` components `CipChargeConverter` + `CipRefundAllocator` + Properties 2/3/4). ASCI is at G2 (ASCI-9/10 PRs raised; Coding ASCI-11 not started). So the 2027 ASCH contributes **no new CIP code** — it rides ASCI. The only ASCH concern is that ASCI ships.

---

## 4. Revised estimate

Two scenarios. The **expected** scenario is "testing-only + buffer" (what the evidence supports). The **worst** scenario prices in "if a transition unexpectedly needs ASC logic" — not because the evidence predicts it, but because the Lead asked to see it and because a §7 run *could* surface an ASCI gap (low probability).

### Scenario A — Testing-only (evidence-supported) + 1–2 week buffer

Base from `asch-2027-development-estimate-20261029.md` = **3–5 dev-days** (CAP half-price verification ~0.5d; §7 patterns 1–4,8 ~1–1.5d; §7 patterns 5/6/7 net-new fixtures+DEV04 ~2–3d; §4.1 reconcile+wrap ~0.5d). Add the Lead-requested **1–2 week buffer** for DEV04 data prep, fixture reconciliation, ASCI-dependency wait, and gate/QA turnaround.

| Estimate | Calendar | Rationale |
|---|---|---|
| **Best** | ~1 week (3 dev-days) | ASCI-11 done before the leave; DEV04 data clean; patterns pass first run. |
| **Expected** | **~2–2.5 weeks** (4–5 dev-days of work + buffer) | Realistic DEV04 fixture build + one reconcile round + QA pass. Buffer absorbs the normal slip. |
| **Worst** | ~3 weeks | ASCI-11 slips into the leave window; ASCH verification can't start until ASCI CIP is testable; one re-run after a fixture defect. Still lands before the 2027-01-01 first prod run. |

This is the number to give Kuroda-san: **testing-only, ~2–2.5 weeks expected with the buffer folded in.**

### Scenario B — IF a §7 transition is found to need new ASC logic (contingency only)

The evidence says this should not happen — but if a §7 run surfaces a real gap, **any ASC code change must run the full spec-driven lifecycle** (requirements → G1 → design → G2 → tasks → coding → G3 → QA), which is far more than 3–5 days. Using the workflow's own gate-turnaround table (`asca-development-workflow.md`: G1 reject 1–2d, G2 0.5–1d, G3 0.5d/round) and the observed ASCA realism factor (ASCA ran **~1.5–2 weeks behind** its Foundation-coding baseline, per the master timeline):

| Phase | Nominal | With gate turnaround + realism |
|---|---|---|
| Requirements + G1 (PM = Kuroda-san) | 1–2 d | +1–2 d if rejected; PM is the external dependency |
| Design + tasks + G2 (Lead) | 2–3 d | +0.5–1 d/round |
| Coding (Dev) | 2–4 d | depends on surface |
| Code review G3 (Lead) | 1 d | +0.5 d/round |
| Dev/manual test + QA (Glenn) | 2–3 d | — |
| **Spec-dev subtotal** | **~8–13 dev-days** | **~2–3 weeks calendar** |
| **+ the testing work from Scenario A** | +3–5 d | — |
| **+ Nov 11–23 Lead leave** | — | +up to 2 weeks if the critical path crosses it (Lead owns requirements/design/G3) |

**Scenario B best/expected/worst:** **best ~3 weeks** (small, well-scoped change, no gate rejections, lands outside the leave); **expected ~4–5 weeks** (one G1 + one G2 round, realism slip); **worst ~6+ weeks** (the change lands across the Nov 11–23 leave with the Lead as the requirements/design/G3 bottleneck and no sub-lead — see `project-context.md` "no sub-lead"). **Scenario B seriously threatens the 2026-12-17 shared deadline.**

**The gap between A (~2.5 wk) and B (~4–5 wk) is the entire reason this investigation matters:** the estimate's credibility rests on the "no ASC logic" claim, and the evidence supports it. The decisive de-risking action is confirming the upstream preconditions in §5 so Scenario B stays a contingency.

---

## 5. Upstream / human confirmations needed to collapse the uncertainty

The ASC-side verdicts are grounded in code. The residual uncertainty is **all upstream (billing)** — these confirmations convert the remaining risk to zero and keep Scenario B a contingency:

1. **CDB / Paolo (charge batch): a mid-campaign CIP↔CAP move issues clean, separate charges with non-overlapping dates and the correctly-discounted `paid_price` on each.** This is the one load-bearing assumption behind Pattern 6's "testing-only" verdict. Confirm the charge batch uses the `contractShorten`-style truncation (old `end_date` = new `start_date` − 1) so the two pairs never share a date range.
2. **CDB / Soli-san (Open Item 3): the 2027 catalog is fixed — auto-attached App is `10022` (not `10021`), CIP Coaching Intensive is `10025`, and the half-price tier is read from `price_flag = 4`.** If billing issues charges on the wrong App product_id, ASC books wrong numbers at the source. This is the **single highest upstream risk**; flag it before the 2027-01-04 application window.
3. **CIP-179 released to the target environment** (the `mst_new_price_listing` 10025 `price_flag=3` record) — ASCI Req 1 verifies it; if absent, CIP books wrong. (Already a pending ASCI human-check.)
4. **Accounting / Ito-san (Open Item 4): shareholder-benefit App share for CAP/CIP, and whether lesson-bundled CIP also refunds the Lesson for shareholder benefit.** ASCI Req 4.4 currently books shareholder refunds Coaching-only; if that reopens, it is a small **ASCI** change (not ASCH), but it would pull into Scenario B territory. Reconcile ASCI Req 4.4 against the ASCH doc so the two agree.
5. **Accounting (Wada-san): bless the −181 half-price tax-exemption figure** (ASCI pending check) — confirms the half-price refund worked examples ASCH will test against.

---

## 6. Conclusion & recommendation

- **Will there be no logic changes?** For the **ASC accounting batch: yes, no new or changed logic is required** — grounded in `CommonUtil`, `BundleDetectionService`, `TwoWayAllocationFormula`, `RefundLinkageResolver`, `getContractDateInfoList`, and the ASCI Spec 01 requirements/design. Every §7 transition and §4.4/§4.5 case resolves to "billing issues the charges; ASC books the `paid_price` through existing / ASCA / ASCI logic." The CIP half-price points are already inside the G1-approved ASCI Spec 01 and add **0 incremental ASCH code**.
- **The 3–5 day "testing-only" base is credible** — but present it **with the 1–2 week buffer folded in (~2–2.5 weeks expected, Scenario A)**, because the real work (DEV04 fixtures for patterns 5/6/7, one reconcile round, QA) plus the ASCI-ship dependency and the Nov 11–23 leave consume the slack the raw day-count hides. ASCA's own **~1.5–2 week** baseline slip is the realism factor.
- **Keep Scenario B (full spec workflow, ~4–5 weeks, threatens 12-17) as a contingency**, and **close it out by getting the §5 upstream confirmations** — above all #1 (clean separate charges on a CIP↔CAP move) and #2 (CDB App 10021→10022). Those are where the "no ASC logic" claim could break, and both are **upstream of ASC**, not ASCH code.
- **Sequence ASCH verification after ASCI-11 is testable.** ASCH is downstream of ASCI; do not start the §7 CIP patterns before the ASCI CIP conversion + refund split are running on DEV04.

**No code or spec files were modified during this investigation.**
