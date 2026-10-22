# ASCI Spec 01 — CIP Integration — Requirements (DRAFT for G1)

> **Staging note:** Dev-context DRAFT pending PM sign-off (Kuroda-san, G1). On approval, `requirements.md` is promoted to the code repos' `.kiro/specs/` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do NOT begin design/tasks from this draft.

## Document Info

| | |
|---|---|
| **Spec** | ASCI Spec 01 — CIP Integration |
| **Document type** | Requirements (G1) |
| **Phase** | G1 (requirements) — DRAFT, not signed off |
| **Date** | 2026-10-20 (drafted) · 2026-10-22 (polished for G1 submission) |
| **Author** | Noel Palo, Lead (Kiro-assisted) |
| **PM (sign-off)** | Hayato Kuroda (PM) |
| **SDM** | Patrick-san |
| **Status** | DRAFT — awaiting Kuroda-san G1 sign-off |
| **Audience** | PM (Kuroda-san), SDM (Patrick-san), Dev (Throy, Cristoff), QA (Glenn) |
| **Sources** | REF-CIP-04 (IDs/prices), REF-CIP-05 (no engine / residual pricing), REF-CIP-06 (refund patterns), REF-CIP-07 (refund-type ID), REF-CIP-08 (lesson-bundled refund), REF-CAP-17 (CEIL proration correction) |

## Decision requested at G1 (please confirm)

1. **CIP-refund home = inside ASCI-01.** The CIP refund split is proposed to be specified and implemented **inside this spec** — not by extending ASCA 02b (CAP refund) and not as a separate sub-spec. Rationale: keeps all CIP work in one place; the CAP refund design (02b) only *parallels* the rule, it does not own it. **Please confirm this placement** — it determines the spec's shape (one spec vs. split).

## Introduction

ASCI makes the accounting batch correctly recognize revenue for the Coaching Intensive Plan (CIP, plan_id 1028–1032). Per **REF-CIP-05**, CIP does **NOT** use the ASCA allocation engine for normal charges: CIP issues separate, already-priced charges (Lesson, Coaching Intensive, App) that flow through the **existing daily pro-ration** unchanged. The only CIP case that needs a split is **refunds** — a CIP refund is booked as one negative on the Coaching Intensive charge and distributed to App by a fixed per-type rule.

So ASCI is three things: (1) a new master **price record** so Coaching Intensive books as a real charge; (2) **verification** that existing pro-ration/discount logic produces the right per-charge amounts; (3) the **CIP refund split** (home proposed inside ASCI-01 — see the G1 decision above).

Bizmates-only (`mysql`). Depends on the ASCA foundation + DEV04 env. Deadline 2026/12/17, first prod run 2027/01/01.

### Glossary (CIP-specific — see `domain-knowledge/plans-and-products.md`)

- **CIP plans:** 1028 (Solo), 1029–1032 (+ 1–4 daily Lesson). All new, no history.
- **Coaching Intensive:** product_id **10025**, booked at **¥71,920 tax-incl** (¥65,382 tax-excl) via a new `mst_new_price_listing` `price_flag = 3` record (= 75,900 − 3,980).
- **App:** product_id **10022** (same as CAP). Its existing `price_flag = 2` row stores **¥3,618 tax-excl (≈ ¥3,980 tax-incl)**; the CIP App charge **books at ¥3,980 tax-incl**. Settled at ¥0 on site but booked at its real price for CIP. (The ¥3,618 tax-excl figure is also the CAP allocation *weight* — same row, different use.)
- **Lesson (1029–1032):** its own existing standalone price, a separate charge — never touched by the CIP split.
- **Coaching+App portion = ¥75,900** — the divisor for the CIP refund split; same for Solo and bundled.
- **No allocation engine for CIP** — no formula, no `mst_alloc_reference_prices` weight, no run/anchor tracking.

### Out of scope

- The ASCA allocation engine (CIP does not use it).
- CAP (1016–1027) — handled by ASCA.
- The Lesson charge's own recognition/refund (existing ASC; CIP never touches it).
- Any Metabase/reporting change.

---

## Requirement 1: CIP Coaching Intensive booking price record

**User Story:** As Accounting, I want Coaching Intensive to book as a real, non-zero charge, so that CIP revenue appears in the existing DailyRateCalculation output without an allocation step.

#### Acceptance Criteria
1. THE system SHALL have a `mst_new_price_listing` record for product_id **10025**, `price_flag = 3`, price **¥65,382 tax-excl (¥71,920 tax-incl)** (= CIP Solo 75,900 − App 3,980), added via a seeder. (Repo placement — `ls-database-migrations` vs the `accounting_related_system_for_freee` seeder path where the existing `ReferencePriceSeeder` lives — is a **G2/design decision**; the requirement is that the record exists and is idempotently seeded, not where it is seeded.)
2. THE record SHALL NOT replace or invalidate the existing **10025** rows: `price_flag = 2` (¥66,500 tax-excl — the coaching reference/shareholder-refund weight) or `price_flag = 4` (¥69,000 tax-excl / ¥75,900 tax-incl — the app-inclusive plan-pricing row). (The ¥3,618 App weight lives on a different product — App **10022** `price_flag = 2` — and is untouched.)
3. THE App charge SHALL use the existing App (**10022**) `price_flag = 2` row (**¥3,618 tax-excl ≈ ¥3,980 tax-incl**); the booked CIP App charge amount is **¥3,980 tax-incl**. NO new App record is created.
4. WHERE the CIP plan/product rows already exist from prior seeding (CoachingIntensivePlanSeeder), THE seeder SHALL be idempotent and add only the `price_flag = 3` booking record.

## Requirement 2: Normal CIP charges recognized via existing pro-ration (no engine)

**User Story:** As Accounting, I want each CIP product recognized independently by the existing daily pro-ration, so that no allocation engine or formula is involved.

#### Acceptance Criteria
1. WHEN a CIP charge is processed, THE system SHALL recognize Coaching Intensive (¥71,920), App (¥3,980), and — for 1029–1032 — Lesson (its own price) as **independent charges**, each day-prorated by the existing logic. (Day-proration uses **CEIL** on every month except the contract's last month, which takes the remainder — per REF-CAP-17; NOT floor. This governs the verification expected values in Req 4.)
2. THE system SHALL NOT invoke the allocation engine, formula, `mst_alloc_reference_prices`, or run/anchor tracking for any CIP normal charge.
3. WHERE a first-month (or other) campaign discount applies (e.g. the 50% first-month discount, B2C and B2E — campaigns.md), THE discount SHALL lower each charge's `paid_price` and pro-ration SHALL follow, via the existing mechanism, with no CIP special-casing. The CAP/ASCH "list-price-basis (L) vs paid-amount (M)" proration-basis rule is an **allocation-engine concern and does NOT apply to CIP** — CIP books already-priced charges with no allocation basis.
4. WHERE a CIP charge belongs to a B2B / B2E / B2E-Partner / B2B2C contract, THE system SHALL route its Freee journal by the existing per-charge `contract_type` / `department_id` / partner logic, unchanged — there is no CIP-specific journal routing. (account-types.md / REF-CIP-06 §3.7: a contract-type change alters only the journal target, not the recognized amounts.)
5. THE existing DailyRateCalculation CSV SHALL show the CIP amounts with no format change (per REF-CAP-16 direction: existing CSV, no AllocationDetail CSV).

## Requirement 3: CIP refund split (Coaching Intensive negative → App)

**User Story:** As Accounting, I want a CIP refund split correctly between Coaching and App, so that each product's revenue reversal is recognized on the right account.

#### Acceptance Criteria
1. WHEN a refund is booked as a negative on the Coaching Intensive charge (10025) AND it is **not** a shareholder refund (cooling-off, consumption-tax exemption, or any other Admin refund), THE system SHALL split it by the fixed ratio: App = `FLOOR(refund × 3,980 / 75,900)`, Coaching = refund − App, using PHP `floor` (rounding toward −∞ for the negative). (REF-CIP-07) Shareholder refunds are the only exception — Coaching only, no split (Req 3.4).
2. THE divisor SHALL be **75,900** (the Coaching+App portion), identical for Solo (1028) and lesson-bundled (1029–1032) — NOT the full bundled plan total. (REF-CIP-08)
3. THE Lesson portion of a 1029–1032 refund SHALL be a separate negative on the **Lesson charge**, handled by existing ASC; the CIP split SHALL NOT touch it. (REF-CIP-08)
4. WHEN the refund is a **shareholder-benefit** refund — identified by `refund_charge_id` present in `trn_receipt_locked_charge` — THE system SHALL book the full amount to **Coaching only (no App split)**, capped at the **interim** ¥19,800. (REF-CIP-07) ⚠️ The ¥19,800 cap is **interim** — the final cap for these plans is expected to be decided by the executives around Nov–Dec and is **out of scope through December**; the implementation must not hard-code ¥19,800 as permanent.
5. WHEN the refund is **cooling-off (90%)**, THE system SHALL use the fixed ratio (Req 3.1). Worked: CI −68,310 → App = `FLOOR(−68,310 × 3,980 / 75,900)` = `FLOOR(−3,582.0)` = **−3,582**, Coaching = **−64,728**. (REF-CIP-07)
6. WHEN the refund is a **consumption-tax exemption**, THE system SHALL use the **same fixed ratio** (Req 3.1) — there is no separate method. Worked: CI −6,900 → App = `FLOOR(−6,900 × 3,980 / 75,900)` = `FLOOR(−361.8…)` = **−362** (floor toward −∞), Coaching = **−6,538**. (REF-CIP-07) This equals the per-product tax-delta figures in REF-CIP-06 (App −(3,980 − 3,618) = −362, Coaching −(71,920 − 65,382) = −6,538) — the two derivations agree, so the single fixed-ratio rule covers both.
7. WHEN the case is an **individual↔corporate contract overlap**, THE system SHALL produce **no CIP refund** (only the Lesson may be refunded on its own charge). (REF-CIP-06 §3.8)
8. THE negative SHALL be recognized as a single lump in the `paid_at` (execution) month — not day-prorated, not spread back. (REF-CIP-06 §2.2)
9. THE refund negative SHALL be identified and consumed through the same entry point as other negative charges (no separate refund pipeline).

#### Worked examples (refund split — for G1 review & test derivation)

All figures from REF-CIP-07 (identification + split), REF-CIP-08 (lesson-bundled clarification) and REF-CAP-17 (the corrected Confluence refund patterns). **One rule, one exception:** every non-shareholder refund uses the fixed ratio App = `FLOOR(refund × 3,980 / 75,900)` with PHP floor toward −∞ (this yields −362 for the −6,900 tax-exemption case, matching REF-CIP-06's per-product derivation); **shareholder refunds are the only exception** — Coaching only, no App split. Lesson is always a separate negative on its own charge, never touched by the CIP split.

| Refund type | Plan | Lesson charge (existing ASC) | Coaching Intensive charge (N) | → Coaching | → App | CIP-split total (CI charge) |
|---|---|---|---|---|---|---|
| Cooling-off (90%) | 1028 Solo | — (no Lesson) | −68,310 (= 75,900 × 90%) | −64,728 | −3,582 | −68,310 |
| Cooling-off (90%) | 1029 (+1 Lesson) | −13,365 (= 14,850 × 90%) | −68,310 | −64,728 | −3,582 | −68,310 (Lesson separate; grand total −81,675) |
| Consumption-tax exemption | 1028 Solo | — | −6,900 | −6,538 | −362 | −6,900 |
| Consumption-tax exemption | 1029 (+1 Lesson) | −1,350 (= 14,850 − 13,500) | −6,900 | −6,538 | −362 | −6,900 (Lesson separate) |
| Shareholder benefit | any CIP | Lesson row → Lesson charge (existing ASC) | −19,800 (interim cap) | −19,800 | **no App split** | −19,800 (Coaching only) |
| Contract overlap (B2C/B2E → B2B) | 1029–1032 | Lesson refunded only | **no CIP refund** | — | — | none |

- The Coaching/App split is **the same for Solo and lesson-bundled** because the divisor is the Coaching+App portion (75,900), not the plan total.
- Cooling-off 1029 grand total **−81,675** = Lesson −13,365 + CI −68,310 (matches REF-CIP-08).
- Shareholder: Coaching only, no App distribution (REF-CIP-07); cap is interim (see Req 3.4).

#### Known dependency (record as a risk)
- Shareholder detection relies on `trn_receipt_locked_charge` membership, a table built to hide charges from receipts — NOT to mark refund types. IF any other flow ever writes to it, detection silently breaks. (REF-CIP-07) — carry this as a documented risk.

## Requirement 4: Verification & tests

**User Story:** As the Lead, I want the CIP behavior verified on DEV04, so that go-live is trustworthy.

#### Acceptance Criteria
1. THE system SHALL be verified on DEV04 for CIP Solo (1028) and lesson-bundled (1029–1032): correct per-charge recognition for Coaching Intensive / App / Lesson.
2. THE refund split SHALL be verified against the REF-CIP-08 worked examples (cooling-off 1029 totals −81,675; tax-exemption; shareholder Coaching-only).
3. Tests SHALL follow the ASCA/ASCI test-DB-safety rule (no dropping real tables / no historic-data loss) — pending the ASCA-70 investigation outcome.

---

## Dependencies

1. ASCA foundation complete (the merged allocation engine + daily-rate path + DEV04 env). The CAP refund design 02b only *parallels* the CIP refund rule — it does not cover CIP (verified in code: `RefundLinkageResolver` excludes CIP 1028–1032). **Note:** the ASCA 02c AllocationDetail-CSV removal (REF-CAP-16 / ADR-20261020) is a separate in-flight ASCA CR; it is NOT a prerequisite for ASCI and does not gate this spec.
2. CIP plans/products already seeded (CoachingIntensivePlanSeeder, CapCoachingAppPlansSeeder). **`CoachingIntensivePlanEnum` (1028–1032) already exists in the ASCA repo** — ASCI should reuse it rather than introduce a new enum (design-phase note).
3. The new `price_flag = 3` booking record (Req 1) must exist before CIP revenue books correctly.

## Correctness properties (for the design phase)

- **Refund split balance:** App + Coaching = refund (exact, no ¥1 drift). App uses PHP `floor` toward −∞; Coaching takes the remainder.
- **One rule + one exception:** every non-shareholder refund (cooling-off, consumption-tax exemption, any other Admin refund) uses the fixed ratio (75,900 divisor, App numerator 3,980); the shareholder refund is the only exception (Coaching only, no App split). REF-CIP-07 confirms the ratio also produces the tax-exemption −362/−6,538 figures, so there is no separate per-type formula.
- **Divisor invariance:** the ratio split always uses 75,900 regardless of plan (Solo vs bundled).
- **Shareholder detection:** `refund_charge_id` ∈ `trn_receipt_locked_charge` ⇒ shareholder; this is the sole discriminator, and only `addbycsv.php` writes that table today (known-dependency risk).
- **Lesson isolation:** no CIP split ever alters a Lesson charge.
- **Shareholder exclusion:** a shareholder refund never distributes to App.
- **No-engine invariant:** no CIP charge touches `mst_alloc_*` or the allocation run tables.

## References

- `research/CIP/REF-CIP-04..08`, `research/CAP/REF-CAP-16` (CSV direction), `projects/asca/documentation/asc-allocation-framework-technical-design.md`, `domain-knowledge/plans-and-products.md`.
