# ASCI Spec 01 — CIP Integration — Requirements (DRAFT for G1)

> **Staging note:** Dev-context DRAFT pending PM sign-off (Kuroda-san, G1). On approval, `requirements.md` is promoted to the code repos' `.kiro/specs/` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do NOT begin design/tasks from this draft.

## Document status

| | |
|---|---|
| **Spec** | ASCI Spec 01 — CIP Integration |
| **Phase** | G1 (requirements) — DRAFT, not signed off |
| **Date** | 2026-10-20 |
| **Author** | Noel Palo, Lead (Kiro-assisted) |
| **PM (sign-off)** | Kuroda-san |
| **Sources** | REF-CIP-04 (IDs/prices), REF-CIP-05 (no engine / residual pricing), REF-CIP-06 (refund patterns), REF-CIP-07 (refund-type ID), REF-CIP-08 (lesson-bundled refund) |

## Introduction

ASCI makes the accounting batch correctly recognize revenue for the Coaching Intensive Plan (CIP, plan_id 1028–1032). Per **REF-CIP-05**, CIP does **NOT** use the ASCA allocation engine for normal charges: CIP issues separate, already-priced charges (Lesson, Coaching Intensive, App) that flow through the **existing daily pro-ration** unchanged. The only CIP case that needs a split is **refunds** — a CIP refund is booked as one negative on the Coaching Intensive charge and distributed to App by a fixed per-type rule.

So ASCI is three things: (1) a new master **price record** so Coaching Intensive books as a real charge; (2) **verification** that existing pro-ration/discount logic produces the right per-charge amounts; (3) the **CIP refund split**.

Bizmates-only (`mysql`). Depends on the ASCA foundation + DEV04 env. Deadline 2026/12/17, first prod run 2027/01/01.

### Glossary (CIP-specific — see `domain-knowledge/plans-and-products.md`)

- **CIP plans:** 1028 (Solo), 1029–1032 (+ 1–4 daily Lesson). All new, no history.
- **Coaching Intensive:** product_id **10025**, booked at **¥71,920 tax-incl** (¥65,382 tax-excl) via a new `mst_new_price_listing` `price_flag = 3` record (= 75,900 − 3,980).
- **App:** product_id **10022** (same as CAP), **¥3,980 tax-incl** (existing `price_flag = 2`), settled at ¥0 on site but booked at its real price for CIP.
- **Lesson (1029–1032):** its own existing standalone price, a separate charge — never touched by the CIP split.
- **Coaching+App portion = ¥75,900** — the divisor for the CIP refund split; same for Solo and bundled.
- **No allocation engine for CIP** — no formula, no `mst_alloc_reference_prices` weight, no run/anchor tracking.

### Out of scope

- The ASCA allocation engine (CIP does not use it).
- CAP (1016–1027) — handled by ASCA.
- The Lesson charge's own recognition/refund (existing ASC; CIP never touches it).
- Any Metabase/reporting change.

### Open decision for G1 (PM)

- **CIP-refund home:** behavior is fully specified (REF-CIP-07/08) but the implementation home is undecided — extend ASCA 02b / new sub-spec / inside ASCI. **Proposed: inside this spec (ASCI-01)**, keeping CIP work in one place. Please confirm at G1.

---

## Requirement 1: CIP Coaching Intensive booking price record

**User Story:** As Accounting, I want Coaching Intensive to book as a real, non-zero charge, so that CIP revenue appears in the existing DailyRateCalculation output without an allocation step.

#### Acceptance Criteria
1. THE system SHALL have a `mst_new_price_listing` record for product_id **10025**, `price_flag = 3`, price **¥65,382 tax-excl (¥71,920 tax-incl)** (= CIP Solo 75,900 − App 3,980), seeded in `ls-database-migrations` (`database/seeders/Bizmates/`).
2. THE record SHALL NOT replace or invalidate the existing 10025 `price_flag = 2` (66,500/3,618) or `price_flag = 4` (69,000/75,900) rows.
3. THE App charge SHALL use the existing `price_flag = 2` = ¥3,980 record — NO new App record is created.
4. WHERE the CIP plan/product rows already exist from prior seeding (CoachingIntensivePlanSeeder), THE seeder SHALL be idempotent and add only the `price_flag = 3` booking record.

## Requirement 2: Normal CIP charges recognized via existing pro-ration (no engine)

**User Story:** As Accounting, I want each CIP product recognized independently by the existing daily pro-ration, so that no allocation engine or formula is involved.

#### Acceptance Criteria
1. WHEN a CIP charge is processed, THE system SHALL recognize Coaching Intensive (¥71,920), App (¥3,980), and — for 1029–1032 — Lesson (its own price) as **independent charges**, each day-prorated by the existing logic.
2. THE system SHALL NOT invoke the allocation engine, formula, `mst_alloc_reference_prices`, or run/anchor tracking for any CIP normal charge.
3. WHERE a first-month (or other) discount applies, THE discount SHALL apply per charge via the existing mechanism, with no CIP special-casing.
4. THE existing DailyRateCalculation CSV SHALL show the CIP amounts with no format change (per REF-CAP-16 direction: existing CSV, no AllocationDetail CSV).

## Requirement 3: CIP refund split (Coaching Intensive negative → App)

**User Story:** As Accounting, I want a CIP refund split correctly between Coaching and App, so that each product's revenue reversal is recognized on the right account.

#### Acceptance Criteria
1. WHEN a refund is booked as a negative on the Coaching Intensive charge (10025), THE system SHALL split it into Coaching and App using the fixed ratio: App = `FLOOR(refund × 3,980 / 75,900)`, Coaching = refund − App (true floor toward −∞ for the negative). (REF-CIP-07)
2. THE divisor SHALL be **75,900** (the Coaching+App portion), identical for Solo (1028) and lesson-bundled (1029–1032) — NOT the full bundled plan total. (REF-CIP-08)
3. THE Lesson portion of a 1029–1032 refund SHALL be a separate negative on the **Lesson charge**, handled by existing ASC; the CIP split SHALL NOT touch it. (REF-CIP-08)
4. WHEN the refund is a **shareholder-benefit** refund — identified by `refund_charge_id` present in `trn_receipt_locked_charge` — THE system SHALL book the full amount to **Coaching only (no App split)**, capped at the interim ¥19,800. (REF-CIP-07)
5. WHEN the refund is **cooling-off (90%)** or **consumption-tax exemption**, THE system SHALL split per Req 3.1 (worked: cooling-off CI −68,310 → Coaching −64,728 / App −3,582; tax-exemption CI −6,900 → Coaching −6,538 / App −362).
6. WHEN the case is an **individual↔corporate contract overlap**, THE system SHALL produce **no CIP refund** (only the Lesson may be refunded on its own charge). (REF-CIP-06 §3.8)
7. THE negative SHALL be recognized as a single lump in the `paid_at` (execution) month — not day-prorated, not spread back. (REF-CIP-06 §2.2)
8. THE refund negative SHALL be identified and consumed through the same entry point as other negative charges (no separate refund pipeline).

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

1. ASCA foundation complete (shared env/scaffolding; the CAP refund design 02b parallels the CIP refund rule).
2. CIP plans/products already seeded (CoachingIntensivePlanSeeder, CapCoachingAppPlansSeeder).
3. The new `price_flag = 3` booking record (Req 1) must exist before CIP revenue books correctly.

## Correctness properties (for the design phase)

- **Refund split balance:** App + Coaching = refund (exact, no ¥1 drift), true floor toward −∞.
- **Divisor invariance:** the split always uses 75,900 regardless of plan (Solo vs bundled).
- **Lesson isolation:** no CIP split ever alters a Lesson charge.
- **Shareholder exclusion:** a shareholder refund never distributes to App.
- **No-engine invariant:** no CIP charge touches `mst_alloc_*` or the allocation run tables.

## References

- `research/CIP/REF-CIP-04..08`, `research/CAP/REF-CAP-16` (CSV direction), `projects/asca/documentation/asc-allocation-framework-technical-design.md`, `domain-knowledge/plans-and-products.md`.
