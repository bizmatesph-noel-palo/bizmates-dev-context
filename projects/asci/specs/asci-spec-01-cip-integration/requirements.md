# ASCI Spec 01 — CIP Integration — Requirements (DRAFT for G1)

> **Staging note:** G1 **APPROVED** by Kuroda-san (2026-10-28), conditional on additions A + B — now both reflected. Next: promote `requirements.md` to the code repos' `.kiro/specs/` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design", then create the ASCI epic + stories. This dev-context copy is the pre-promotion source of record.

## Document Info

| | |
|---|---|
| **Spec** | ASCI Spec 01 — CIP Integration |
| **Document type** | Requirements (G1) |
| **Phase** | G1 (requirements) — **APPROVED** (Kuroda-san, 2026-10-28, additions A + B reflected) |
| **Date** | 2026-10-20 (drafted) · 2026-10-22 (polished for G1 submission) · 2026-10-26 (revised per G1 feedback, REF-CIP-09) · 2026-10-28 (round-2 additions A+B; G1 approved) |
| **Author** | Noel Palo, Lead (Kiro-assisted) |
| **PM (sign-off)** | Hayato Kuroda (PM) — **G1 approved 2026-10-28** |
| **SDM** | Patrick-san |
| **Status** | **G1 APPROVED** — all Kuroda-san feedback (round 1 + round 2 A/B) folded in; ready to promote to the code repos' `.kiro/specs/` |
| **Audience** | PM (Kuroda-san), SDM (Patrick-san), Dev (Throy, Cristoff), QA (Glenn) |
| **Sources** | REF-CIP-04 (IDs/prices), REF-CIP-05 (no engine / residual pricing), REF-CIP-06 (refund patterns), REF-CIP-07 (refund-type ID), REF-CIP-08 (lesson-bundled refund), REF-CIP-09 (Kuroda-san G1 feedback), REF-CAP-17 (CEIL proration correction) |

## G1 decision (confirmed)

1. **CIP-refund home = inside ASCI-01 — CONFIRMED (Kuroda-san, REF-CIP-09, 2026-10-22).** The CIP refund split is specified and implemented **inside this spec** — not by extending ASCA 02b (CAP refund) and not as a separate sub-spec. Kuroda-san: "Agreed. Please specify and implement the CIP refund split inside ASCI-01." ASCI stays one spec.

> **G1 feedback status (REF-CIP-09):** **G1 APPROVED by Kuroda-san on 2026-10-28** ("Once A and B are added, G1 is approved from my side" — both added). Round 1 (B-1 + W-1..W-5 + two 10-23 add-ons) and round 2 (wording: booked amount before day-proration; Addition A = Req 2 App-charge pairing; Addition B = Req 4 App-row insertion via ASCA 02b Req 9) are all folded in. The flag-2 "stays vs removed" open item is **closed** (Kuroda-san confirmed CIP-179 removes it). Three items are deferred to the design phase (see "Design-phase notes").

## Introduction

ASCI makes the accounting batch correctly recognize revenue for the Coaching Intensive Plan (CIP, plan_id 1028–1032). Per **REF-CIP-05**, CIP does **NOT** use the ASCA allocation engine. On the site a CIP contract issues separate charges, but the **App charge is settled at ¥0** and the **Coaching Intensive charge carries the whole Coaching+App amount (¥75,900 standard month)** — so the 71,920 / 3,980 split exists **only in the accounting batch** (REF-CIP-09, B-1). The batch applies a small **CIP-specific conversion** — splitting the Coaching Intensive site amount into Coaching ¥71,920 and App ¥3,980 (at the same ratio for any discounted month) — **before** the existing daily pro-ration runs. This conversion is a fixed per-month arithmetic transform, not the ASCA allocation engine, so the no-engine invariant still holds. The only CIP case that needs a *refund* split is **refunds** — a CIP refund is booked as one negative on the Coaching Intensive charge and distributed to App by the same booked-amount ratio (REF-CIP-07/09).

So ASCI is four things: (1) a master **price record** (the Coaching Intensive residual price) — which already exists via CIP-179; (2) the **site→booking conversion** step that turns the site amounts into booking amounts before pro-ration; (3) **verification** that the conversion + existing pro-ration/discount logic produces the right per-charge amounts; (4) the **CIP refund split** (home confirmed inside ASCI-01 — see the G1 decision above).

Bizmates-only (`mysql`). Depends on the ASCA foundation + DEV04 env. Deadline 2026/12/17, first prod run 2027/01/01.

### Glossary (CIP-specific — see `domain-knowledge/plans-and-products.md`)

- **CIP plans:** 1028 (Solo), 1029–1032 (+ 1–4 daily Lesson). All new, no history.
- **Site amount vs booking amount:** on the site, the Coaching Intensive (10025) charge carries the **whole Coaching+App amount** (¥75,900 standard month) and the App (10022) charge is **¥0**. The batch converts these into the **booking amounts** Coaching ¥71,920 / App ¥3,980 before pro-ration (REF-CIP-09 B-1). All "booked at" figures below are booking amounts.
- **Coaching Intensive:** product_id **10025**, **residual booking price ¥71,920 tax-incl** (¥65,382 tax-excl / tier2 ¥32,691), stored as the `mst_new_price_listing` `price_flag = 3` record (= 75,900 − 3,980). This record is **created by CIP-179** (Jefferson; created 2026-09-25, status **QA Passed** as of 2026-10-12 — verified in Jira); ASCI does not create it, and verifies it has shipped to the target environment.
- **App:** product_id **10022** (same as CAP). Its existing `price_flag = 2` row stores **¥3,618 tax-excl (≈ ¥3,980 tax-incl)**; the CIP App charge **books at ¥3,980 tax-incl**. Settled at ¥0 on site, booked at ¥3,980 by the conversion step. (The ¥3,618 tax-excl figure is also the CAP allocation *weight* — same row, different use.)
- **Lesson (1029–1032):** its own existing standalone price, a separate charge — never touched by the CIP conversion or refund split.
- **Coaching+App portion = ¥75,900** — the standard-month Coaching Intensive site amount and the basis the booking split derives from; same for Solo and bundled. On a discounted month it is the discounted paid amount (e.g. ¥37,950 at 50%).
- **No allocation engine for CIP** — no allocation formula, no `mst_alloc_reference_prices` weight, no run/anchor tracking. The site→booking conversion is a fixed per-month arithmetic transform, distinct from the engine.

### Out of scope

- The ASCA allocation engine (CIP does not use it).
- CAP (1016–1027) — handled by ASCA.
- The Lesson charge's own recognition/refund (existing ASC; CIP never touches it).
- Any Metabase/reporting change.

---

## Requirement 1: CIP Coaching Intensive residual booking price record (already exists)

**User Story:** As Accounting, I want the Coaching Intensive charge to book at its residual price (¥71,920), so that CIP revenue is recognized correctly in the existing DailyRateCalculation output without the allocation engine. (The Coaching Intensive charge is already non-zero on the site — this requirement is about the *residual booking* price the conversion step (Req 2) targets, not about making a zero charge non-zero. — REF-CIP-09 W-1.)

#### Acceptance Criteria
1. THE `mst_new_price_listing` record for product_id **10025**, `price_flag = 3`, price **¥65,382 tax-excl tier1 / ¥32,691 tax-excl tier2 (¥71,920 tax-incl)** (= CIP Solo 75,900 − App 3,980) **SHALL exist**. This record is **created by CIP-179** (Jefferson; Jira Task, created 2026-09-25, status **QA Passed** as of 2026-10-12 — verified in Jira). ASCI does **not** add a new seeder for it; ASCI verifies the record is present in the target environment. (REF-CIP-09 W-1)
2. CIP SHALL rely on the `price_flag = 3` record (10025) for the Coaching Intensive residual price. THE 10025 `price_flag = 2` rows (¥66,500 tier1 / ¥33,250 tier2 tax-excl) are **removed by CIP-179** and ASCI does **not** depend on them (REF-CIP-09 W-2, confirmed 2026-10-28 — Kuroda-san corrected his earlier "stays" comment; open item closed). The `price_flag = 4` row (¥69,000 tax-excl / ¥75,900 tax-incl — app-inclusive plan-pricing) is untouched. (The ¥3,618 App weight lives on a different product — App **10022** `price_flag = 2` — and is untouched.)
3. THE App charge SHALL book against the existing App (**10022**) `price_flag = 2` row (**¥3,618 tax-excl ≈ ¥3,980 tax-incl**); the booked CIP App charge amount is **¥3,980 tax-incl**. NO new App record is created.
4. WHERE verification finds the `price_flag = 3` record (CIP-179) absent or incorrect in a target environment, THAT SHALL be raised as an environment/data issue (confirm CIP-179 has been released beyond QA to that environment) — not resolved by ASCI adding a parallel seeder.

## Requirement 2: CIP site→booking amount conversion (the B-1 step)

**User Story:** As Accounting, I want the batch to convert the CIP site charge amounts into the correct Coaching/App booking amounts before pro-ration, so that revenue is recognized as Coaching ¥71,920 / App ¥3,980 even though the site books Coaching Intensive ¥75,900 / App ¥0. (REF-CIP-09, Blocker B-1 — agreed with Accounting, Wada-san 2026-09-28.)

#### Acceptance Criteria
1. THE system SHALL read the actual site `trn_charge.paid_price`: the Coaching Intensive (10025) charge carries the **Coaching+App** amount (¥75,900 for a standard month) and the App (10022) charge is **¥0**. The 71,920 / 3,980 split does not exist on the site — only in the batch.
2. BEFORE day-proration, THE system SHALL convert the Coaching Intensive site amount into two booking amounts: **App = `FLOOR(site_amount × 3,980 / 75,900)`**, **Coaching = site_amount − App**. For a standard month (¥75,900) this yields Coaching **¥71,920** / App **¥3,980**.
3. THE conversion SHALL be **campaign-agnostic**: it SHALL derive the split from the month's paid amount alone, at the fixed ratio in 2.2, and SHALL NOT detect, branch on, or require knowledge of any campaign (Honki Set, first-month, 6th-month, etc.). The batch does not need to know which charges are Honki charges. (REF-CIP-09 Comment 2 — Accounting-confirmed.)
4. WHERE a month is discounted (e.g. the 2027 Honki Campaign's 50% off in the first and sixth months), THE Coaching and App booking amounts SHALL be discounted at the **same rate** as a natural result of 2.2 applied to the discounted site amount — e.g. a half-price month (site ¥37,950) yields Coaching **¥35,960** / App **¥1,990**. No separate discounted-month logic is required.
5. AFTER conversion, THE two booking amounts SHALL each be day-prorated by the **existing** logic. (Day-proration uses **CEIL** on every month except the contract's last month, which takes the remainder — per REF-CAP-17; NOT floor. This governs the verification expected values in Req 5.)
6. THE conversion SHALL be a fixed per-month arithmetic transform — it SHALL NOT invoke the allocation engine, formula, `mst_alloc_reference_prices`, or run/anchor tracking. (The "no allocation engine" invariant holds: a per-charge arithmetic split is not the engine.)
7. THE converted App booking amount (¥3,980) SHALL be written onto the **paired App (10022) charge**. THE system SHALL pair the Coaching Intensive charge with its App charge by **reusing the CAP pairing rule (ASCA Spec 01 G1 1-5):** group by `student_id` + `order_no` + `plan_id`; when `order_no` is NULL, match by contract period (`start_date`/`end_date`). (REF-CIP-09 Addition A)
8. THE system SHALL perform the conversion ONLY when **exactly 1 Coaching Intensive + 1 App** charge is found for the pair. WHERE the pairing is ambiguous (not exactly 1+1), THE system SHALL **skip without guessing (V-3)** and **record the skip reason** (where CIP records skip reasons is a **design-phase decision** — CIP has no allocation run tables per the no-engine invariant, so it cannot reuse CAP's on-the-run recording; see Design-phase notes); the skipped pair's **site amounts stay as they are** (Coaching Intensive ¥75,900 / App ¥0 — no conversion applied). (REF-CIP-09 Addition A, Comment 5)

## Requirement 3: Normal CIP charges recognized via existing pro-ration (no engine)

**User Story:** As Accounting, I want each CIP product recognized independently by the existing daily pro-ration once the booking amounts are set, so that no allocation engine or formula is involved.

#### Acceptance Criteria
1. WHEN a CIP charge is processed, THE system SHALL recognize Coaching Intensive (booking ¥71,920), App (booking ¥3,980), and — for 1029–1032 — Lesson (its own price) as **independent charges**, each day-prorated by the existing logic after the Req 2 conversion. (Day-proration uses **CEIL** on every month except the contract's last month, which takes the remainder — per REF-CAP-17; NOT floor. This governs the verification expected values in Req 5.)
2. THE system SHALL NOT invoke the allocation engine, formula, `mst_alloc_reference_prices`, or run/anchor tracking for any CIP normal charge. The only CIP-specific step is the Req 2 site→booking conversion, which is a fixed arithmetic transform, not the engine.
3. WHERE a campaign discount applies (e.g. the 50% first-month/6th-month discount, B2C and B2E — campaigns.md), THE discounted site amount SHALL flow through the Req 2 conversion (yielding the same-rate Coaching/App split) and then pro-ration, with no CIP special-casing. (Note: because App is ¥0 on the site, the discount reaches the App booking amount **through the conversion step**, not by lowering a site App `paid_price`.) The CAP/ASCH "list-price-basis (L) vs paid-amount (M)" proration-basis rule is an **allocation-engine concern and does NOT apply to CIP** — CIP books already-priced charges with no allocation basis.
4. WHERE a CIP charge belongs to a B2B / B2E / B2E-Partner / B2B2C contract, THE system SHALL route its Freee journal by the existing per-charge `contract_type` / `department_id` / partner logic, unchanged — there is no CIP-specific journal routing. (account-types.md / REF-CIP-06 §3.7: a contract-type change alters only the journal target, not the recognized amounts.)
5. THE existing DailyRateCalculation CSV SHALL show the CIP amounts with no format change (per REF-CAP-16 direction: existing CSV, no AllocationDetail CSV).

## Requirement 4: CIP refund split (Coaching Intensive negative → App)

**User Story:** As Accounting, I want a CIP refund split correctly between Coaching and App, so that each product's revenue reversal is recognized on the right account.

#### Acceptance Criteria
1. WHEN a refund is booked as a negative on the Coaching Intensive charge (10025) AND it is **not** a shareholder refund, THE system SHALL split it so that **App = `FLOOR(refund × App_booked / original_site_amount)`** and **Coaching = refund − App**, using PHP `floor` (rounding toward −∞ for the negative). The applicable refund types are an **explicit list**: **cooling-off (90%)**, **consumption-tax exemption**, and **full refund** (REF-CIP-09 W-4). Shareholder refunds are the only exception — Coaching only, no split (Req 4.5).
2. THE split basis SHALL be the **original charge's booking amount**, not a fixed 3,980 (REF-CIP-09 Comment 2). `App_booked` and `original_site_amount` are the **original charge's booking amounts BEFORE day-proration** — NOT the day-prorated per-month figures — read from the original charge found via **`log_refund_history`** (same linkage as ASCA 02b). (Wording per REF-CIP-09 Comment 4.) For a standard month this is 3,980 / 75,900 (results identical to the prior fixed ratio); for a half-price month it is 1,990 / 37,950. The basis is identical for Solo (1028) and lesson-bundled (1029–1032). This booked-basis approach is also exact for non-divisible amounts (e.g. a ¥50,000 full refund reverses App −2,621, not the −2,622 a fixed ratio would over-reverse — REF-CIP-09 Comment 4).
3. THE Lesson portion of a 1029–1032 refund SHALL be a separate negative on the **Lesson charge**, handled by existing ASC; the CIP split SHALL NOT touch it. (REF-CIP-08)
4. WHEN the refund is a **shareholder-benefit** refund — identified by `refund_charge_id` present in `trn_receipt_locked_charge` — THE system SHALL book the amount to **Coaching only (no App split)** — a **confirmed rule** (REF-CIP-09 W-3, confirmed 2026-10-23: the App is not eligible because it is treated as paid together with Coaching). THE batch SHALL book the negative amount **exactly as provided in the shareholder CSV, without applying or truncating any cap** — the ¥19,800 (interim) cap is applied **upstream** when the CSV is prepared, before it reaches the batch (REF-CIP-09 W-3). The implementation SHALL NOT contain cap logic.
5. WHEN the refund is **cooling-off (90%)**, THE system SHALL use the Req 4.1/4.2 split. Worked (standard month): CI −68,310 → App = `FLOOR(−68,310 × 3,980 / 75,900)` = `FLOOR(−3,582.0)` = **−3,582**, Coaching = **−64,728**. (REF-CIP-07) Half-price month: CI −34,155 → App = `FLOOR(−34,155 × 1,990 / 37,950)` = **−1,791**, Coaching = **−32,364**. (REF-CIP-09 Comment 2)
6. WHEN the refund is a **consumption-tax exemption**, THE system SHALL use the **same split** (Req 4.1/4.2) — there is no separate method. Worked (standard month): CI −6,900 → App = `FLOOR(−6,900 × 3,980 / 75,900)` = `FLOOR(−361.8…)` = **−362** (floor toward −∞), Coaching = **−6,538**. (REF-CIP-07) This equals the per-product tax-delta figures in REF-CIP-06 (App −(3,980 − 3,618) = −362, Coaching −(71,920 − 65,382) = −6,538). Half-price month: CI −3,450 → App **−181** (= 1,990 − 1,809 tax-excl), Coaching **−3,269**. (REF-CIP-09 Comment 2)
7. WHEN the refund is a **full refund**, THE system SHALL use the same split (Req 4.1/4.2). Worked (standard month): CI −75,900 → App **−3,980**, Coaching **−71,920**. Half-price month: CI −37,950 → App **−1,990**, Coaching **−35,960**. (REF-CIP-09 W-4 / Comment 2)
8. WHEN the case is an **individual↔corporate contract overlap**, THE system SHALL produce **no negative on the Coaching Intensive charge** (only the Lesson may be refunded on its own charge) — consistent with Req 4.1's explicit-list scope. (REF-CIP-06 §3.8, REF-CIP-09 W-4)
9. THE negative SHALL be recognized as a single lump in the `paid_at` (execution) month — not day-prorated, not spread back. (REF-CIP-06 §2.2)
10. THE App portion of the refund SHALL be written as a **new App (10022) row inserted in the refund's execution month**, reusing the **ASCA 02b Req 9** mechanism. The site creates a negative only on the Coaching Intensive charge, so there is no existing App row for the App portion — and when the refund executes after the contract has ended (e.g. a consumption-tax exemption or a shareholder refund months later) there is no App row in that month at all; the inserted row carries the negative App amount. (REF-CIP-09 Addition B)
11. THE refund negative SHALL be identified and consumed through the same entry point as other negative charges (no separate refund pipeline).

#### Worked examples (refund split — for G1 review & test derivation)

All figures from REF-CIP-07 (identification + split), REF-CIP-08 (lesson-bundled clarification), REF-CIP-09 (G1 feedback — full refund, discounted-month basis) and REF-CAP-17 (CEIL proration). **One rule, one exception:** every non-shareholder refund (cooling-off, consumption-tax exemption, full refund) uses App = `FLOOR(refund × App_booked / original_site_amount)` with PHP floor toward −∞, Coaching = remainder. `App_booked` / `original_site_amount` are the **original charge's booking amounts before day-proration** (read via `log_refund_history`) — 3,980 / 75,900 for a standard month, 1,990 / 37,950 for a half-price month (REF-CIP-09 Comment 2/4). **Shareholder refunds are the only exception** — Coaching only, no App split, CSV amount booked as-is (no in-batch cap). Lesson is always a separate negative on its own charge, never touched by the CIP split.

**Standard month (site ¥75,900 → booking 71,920 / 3,980):**

| Refund type | Plan | Lesson charge (existing ASC) | Coaching Intensive charge (refund) | → Coaching | → App | CIP-split total (CI charge) |
|---|---|---|---|---|---|---|
| Cooling-off (90%) | 1028 Solo | — (no Lesson) | −68,310 (= 75,900 × 90%) | −64,728 | −3,582 | −68,310 |
| Cooling-off (90%) | 1029 (+1 Lesson) | −13,365 (= 14,850 × 90%) | −68,310 | −64,728 | −3,582 | −68,310 (Lesson separate; grand total −81,675) |
| Consumption-tax exemption | 1028 Solo | — | −6,900 | −6,538 | −362 | −6,900 |
| Consumption-tax exemption | 1029 (+1 Lesson) | −1,350 (= 14,850 − 13,500) | −6,900 | −6,538 | −362 | −6,900 (Lesson separate) |
| Full refund | 1028 Solo | — | −75,900 | −71,920 | −3,980 | −75,900 |
| Shareholder benefit | any CIP | Lesson row → Lesson charge (existing ASC) | −19,800 (CSV amount, interim cap applied upstream) | −19,800 | **no App split** | −19,800 (Coaching only) |
| Contract overlap (B2C/B2E → B2B) | 1029–1032 | Lesson refunded only | **no negative on CI charge** | — | — | none |

**Half-price month (site ¥37,950 → booking 35,960 / 1,990 — e.g. 2027 Honki first/6th month):**

| Refund type | Coaching Intensive charge (refund) | → Coaching | → App |
|---|---|---|---|
| Cooling-off (90%) | −34,155 | −32,364 | −1,791 (= 1,990 × 90%) |
| Consumption-tax exemption | −3,450 | −3,269 | −181 (= 1,990 − 1,809 tax-excl) |
| Full refund | −37,950 | −35,960 | −1,990 |

- The Coaching/App split is **the same for Solo and lesson-bundled** because the basis is the Coaching+App portion (the CI charge's own booked amounts), not the plan total.
- Cooling-off 1029 grand total **−81,675** = Lesson −13,365 + CI −68,310 (matches REF-CIP-08).
- Shareholder: Coaching only, no App distribution — a **confirmed rule** (REF-CIP-09 W-3, 2026-10-23); the batch books the CSV amount as-is and does **not** apply the ¥19,800 (interim) cap (cap is upstream — see Req 4.4).
- **Lesson shareholder row confirmed (REF-CIP-09 W-5, 2026-10-23):** for lesson-bundled plans (1029–1032) the Lesson portion **is** eligible for the shareholder benefit and lands on the Lesson charge (existing ASC). This is no longer TBD.

#### Known dependency (record as a risk)
- Shareholder detection relies on `trn_receipt_locked_charge` membership, a table built to hide charges from receipts — NOT to mark refund types. IF any other flow ever writes to it, detection silently breaks. (REF-CIP-07) — carry this as a documented risk.

## Requirement 5: Verification & tests

**User Story:** As the Lead, I want the CIP behavior verified on DEV04, so that go-live is trustworthy.

#### Acceptance Criteria
1. THE system SHALL be verified on DEV04 for CIP Solo (1028) and lesson-bundled (1029–1032): correct per-charge recognition for Coaching Intensive / App / Lesson after the Req 2 conversion.
2. THE site→booking conversion (Req 2) SHALL be verified for:
   - a **standard (full-price) month** — Coaching Intensive site ¥75,900 → booking Coaching ¥71,920 / App ¥3,980;
   - a **first-month 50% discount** (2027 Honki Campaign) — site ¥37,950 → booking Coaching ¥35,960 / App ¥1,990;
   - a **6th-month 50% discount** (2027 Honki Campaign — REF-CIP-09 Comment 2) — same split as the first-month case.
   Each case SHALL then be day-prorated and the per-month recognized amounts checked.
3. THE refund split SHALL be verified against the worked examples for **both** a standard month and a half-price month: cooling-off (standard CI −68,310 → −64,728 / −3,582; 1029 grand total −81,675; half-price CI −34,155 → −32,364 / −1,791), consumption-tax exemption (standard −6,900 → −6,538 / −362; half-price −3,450 → −3,269 / −181), full refund (standard −75,900 → −71,920 / −3,980; half-price −37,950 → −35,960 / −1,990), and shareholder (Coaching-only, CSV amount as-is, no App split).
4. Tests SHALL follow the ASCA/ASCI test-DB-safety rule (no dropping real tables / no historic-data loss) — pending the ASCA-70 investigation outcome.

---

## Dependencies

1. ASCA foundation complete (the merged allocation engine + daily-rate path + DEV04 env). The CAP refund design 02b only *parallels* the CIP refund rule — it does not cover CIP (verified in code: `RefundLinkageResolver` excludes CIP 1028–1032). **Note:** the ASCA 02c AllocationDetail-CSV removal (REF-CAP-16 / ADR-20261020) is a separate in-flight ASCA CR; it is NOT a prerequisite for ASCI and does not gate this spec.
2. CIP plans/products already seeded (CoachingIntensivePlanSeeder, CapCoachingAppPlansSeeder). **`CoachingIntensivePlanEnum` (1028–1032) already exists in the ASCA repo** — ASCI should reuse it rather than introduce a new enum (design-phase note).
3. The `price_flag = 3` booking record (Req 1) is **created by CIP-179** (Jefferson; Jira Task, created 2026-09-25, **QA Passed** as of 2026-10-12 — verified in Jira); ASCI verifies its presence rather than creating it. CIP revenue books correctly only when this record has been released to the target environment. CIP-179 also removes the 10025 `price_flag = 2` rows; ASCI does not depend on them (Req 1.2).

## Correctness properties (for the design phase)

- **Conversion balance:** for any month, Coaching_booked + App_booked = the Coaching Intensive **site amount** (exact, no ¥1 drift). App uses PHP `floor` toward −∞; Coaching takes the remainder.
- **Conversion ratio invariance / campaign-agnostic:** the conversion always applies App = `FLOOR(site × 3,980 / 75,900)` regardless of the month's paid amount; the batch never detects a campaign. Standard month → 71,920 / 3,980; half-price month → 35,960 / 1,990.
- **Refund split balance:** App + Coaching = refund (exact, no ¥1 drift). App uses PHP `floor` toward −∞; Coaching takes the remainder.
- **One rule + one exception:** every non-shareholder refund (cooling-off, consumption-tax exemption, full refund) uses the split App = `FLOOR(refund × App_booked / original_site_amount)`; the shareholder refund is the only exception (Coaching only, no App split, CSV amount as-is). REF-CIP-07 confirms the standard-month ratio also produces the tax-exemption −362/−6,538 figures, so there is no separate per-type formula.
- **Booked-amount basis invariance:** the refund split uses the **original charge's booking amount before day-proration** (App / site = 3,980 / 75,900 standard, 1,990 / 37,950 half-price), identical for Solo and bundled — not a hard-coded 3,980, and not the day-prorated per-month figure.
- **Shareholder detection:** `refund_charge_id` ∈ `trn_receipt_locked_charge` ⇒ shareholder; this is the sole discriminator, and only `addbycsv.php` writes that table today (known-dependency risk).
- **No in-batch cap:** the batch never applies or truncates the shareholder cap; it books the CSV amount as given (cap is upstream).
- **Lesson isolation:** no CIP conversion or split ever alters a Lesson charge.
- **Shareholder exclusion:** a shareholder refund never distributes to App (confirmed rule).
- **No-engine invariant:** no CIP charge touches `mst_alloc_*` or the allocation run tables; the site→booking conversion is a fixed arithmetic transform, not the engine.

## Design-phase notes (deferred from G1 — REF-CIP-09 Comment 4)

Kuroda-san explicitly deferred these to the design phase (not G1 requirements); recorded here so they are not lost:

1. **Missing original charge:** define behavior when the original charge cannot be found via `log_refund_history` (the refund split has no basis to read).
2. **Multiple refunds on one charge:** the total App refund across refunds SHALL NOT exceed the original App booking amount (cumulative cap).
3. **Non-divisible test:** add a test with a non-divisible amount (e.g. a ¥50,000 full refund → App −2,621) so the booked-basis behavior (exact, vs the −2,622 a fixed ratio would over-reverse) is actually covered.
4. **Where CIP records conversion skip reasons (Req 2.8):** CAP records a skip reason "on the run", but CIP has **no allocation run tables** (no-engine invariant), so it cannot reuse that. Decide in design where a CIP conversion skip (not exactly 1 CI + 1 App) is recorded — e.g. a log line, a dedicated lightweight table, or the existing batch log. (REF-CIP-09 Comment 5 — Kuroda-san, 2026-10-28.)

## References

- `research/CIP/REF-CIP-04..09`, `research/CAP/REF-CAP-16` (CSV direction), `research/CAP/REF-CAP-17` (CEIL proration), `domain-knowledge/campaigns.md` (Honki Set month-1/month-6 shape — campaign fact only), `projects/asca/documentation/asc-allocation-framework-technical-design.md`, `domain-knowledge/plans-and-products.md`.
