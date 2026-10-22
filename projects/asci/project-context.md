# ASCI — Project Context

> Load this at the start of each ASCI session.
> Also load `projects/asca/project-context.md` for the shared framework context, and `domain-knowledge/plans-and-products.md`.
> If context gets compacted, re-read these before continuing.

---

## ⚠️ Important: ASCI is NOT an allocation-engine config exercise

An earlier version of this file described ASCI as "a configuration exercise — same formula, same injection point, add CIP plan_ids + reference prices." **That is superseded and wrong.** Per **REF-CIP-05 (2026-09-17)**, CIP does **NOT** use the ASCA allocation engine for normal charges. Do not build ASCI on the old "add CIP to the engine" assumption.

---

## What ASCI Is (grounded in REF-CIP-04/05/06/07/08)

**ASCI (ASC for CIP)** makes the accounting system correctly recognize revenue for the Coaching Intensive Plan (CIP, plan_id 1028–1032). Unlike ASCA/CAP, CIP revenue is split by **issuing separate, already-priced charges** that flow through the **existing daily pro-ration** — there is **no allocation engine, no formula, no reference-price weight, no run/anchor tracking** for CIP normal charges.

**The only place CIP needs a split is REFUNDS** — a CIP refund is booked as one negative on the Coaching Intensive charge and then distributed to App by a fixed per-type rule (the exception to "no engine" — REF-CIP-06/07/08).

**Scope:** Bizmates-only. Depends on the ASCA foundation being complete (shared framework + the DEV04 environment), but reuses little of the engine — mostly the project scaffolding, the DEV04 setup, and the refund-handling patterns.

**JIRA:** [ASCI Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) · [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog)

---

## Key Info

| Item | Value |
|---|---|
| Project code | ASCI |
| Full name | ASC for CIP (Coaching Intensive Plan) |
| Upstream project | CIP (Jefferson's team) |
| Code repo | `accounting_related_system_for_freee`, `ls-database-migrations` |
| Lead | Noel Palo |
| Developer | Throy Embudo, Cristoff Danganan |
| QA | Glenn Flamiano |
| SDM | Patrick-san |
| PM | Kuroda-san |
| Deadline | 2026/12/17 |
| First batch run | 2027/01/01 |
| Depends on | ASCA foundation (shared) — and the ASCA CAP-refund design (02b), which the CIP refund rule parallels |

---

## Corrected CIP master data (vs the old stale values)

| Item | CORRECT value (REF-CIP-04/05/06) | Old stale value (do NOT use) |
|---|---|---|
| Coaching Intensive product_id | **10025** | ~~10022~~ |
| Auto-bundled App product_id | **10022** (same product as CAP) | ~~10021~~ |
| CIP plan_ids | **1028–1032** (5 plans, all new, no history) | (unchanged) |
| CIP Solo (1028) plan price | **¥75,900 tax-incl** (¥69,000 pre-tax = Coaching+App) | ~~¥88,000~~ |
| Coaching Intensive booking price | **¥71,920 tax-incl** (¥65,382 tax-excl) — new `mst_new_price_listing` `price_flag = 3` record (= 75,900 − 3,980) | ~~L_coaching ¥84,020 weight~~ (no weight exists — no engine) |
| App price | **¥3,980 tax-incl** (existing `price_flag = 2`, reused directly) | (unchanged) |
| Lesson (1029–1032) | its own existing standalone lesson price, separate charge | — |
| Allocation weight / L_coaching | **N/A — CIP is not engine-allocated** | ~~¥84,020~~ |

---

## What ASCI actually builds

1. **New master price record (ls-db seeder):** the Coaching Intensive `price_flag = 3` row (10025, ¥65,382 tax-excl / ¥71,920 tax-incl) so CIP coaching is booked as a real charge. (The App `price_flag = 2` = ¥3,980 already exists; no new App record.) — CIP plans/products/banners are already seeded (CapCoachingAppPlansSeeder created App 10022; CoachingIntensivePlanSeeder created 10025 + plans 1028–1032).
2. **Verify existing pro-ration + discounts** produce the expected per-charge amounts for CIP Solo (1028) and lesson-bundled (1029–1032): Lesson, Coaching Intensive (71,920), App (3,980) each day-prorated independently; first-month discounts apply per charge, no special-casing.
3. **CIP refund split (the real logic):** a negative on the Coaching Intensive charge is distributed to App by a fixed per-type rule. Lesson refunds always land on the Lesson charge (existing ASC, untouched). See the refund table below.
4. **DEV04 validation** for CIP plans.

**Estimated effort:** small for normal flow (price record + verification); the refund split is the substantive piece. (The old "1–1.5 weeks, config-only" estimate predates the refund scope.)

---

## CIP refund rules (fully specified — REF-CIP-06 §3, REF-CIP-07, REF-CIP-08)

CIP refunds are booked as one negative on the **Coaching Intensive charge** (Admin cannot refund a ¥0 App), then distributed to App by a fixed rule. The **divisor is the Coaching+App portion (75,900)** — NOT the full bundled plan total. Lesson is always a separate negative on the Lesson charge (existing ASC; the CIP split never touches it).

| Refund type | Lesson charge | Coaching Intensive charge | App split | Detection |
|---|---|---|---|---|
| Cooling-off (90%) | negative, existing ASC (e.g. 1029: −13,365) | −68,310 (= 75,900 × 90%) | Coaching −64,728 / App −3,582 | — |
| Consumption-tax exemption | negative, existing ASC (e.g. −1,350) | −6,900 | Coaching −6,538 / App −362 | — |
| Shareholder benefit | Lesson row → Lesson charge (existing ASC) | Coaching only, −19,800 (interim cap) | **no App split** | refund_charge_id in `trn_receipt_locked_charge` ⇒ shareholder |
| Contract overlap (B2C/B2E → B2B) | Lesson refunded only | **no refund** | no refund | — |

- App fixed-ratio (non-shareholder): App = `FLOOR(refund × 3,980 / 75,900)`, Coaching = refund − App (REF-CIP-07).
- Negative recognized as a lump in the `paid_at` (execution) month; not day-prorated, not spread back.

---

## Open decision (for Kuroda-san / Lead)

**CIP-refund home** — identification + behavior are fully specified (REF-CIP-07/08), but WHERE the CIP-refund split is implemented is not yet decided: extend ASCA 02b (CAP refund), a new sub-spec, or inside ASCI. Proposed: handle it **inside ASCI-01** (CIP-specific, keeps CIP work in one place). To confirm at ASCI G1.

---

## Spec shape (proposed — for G1)

Because the normal flow is small and the refund rules are fully specified, ASCI is proposed as **one spec, ASCI-01**, with sections for: (a) the CIP booking price record, (b) existing-proration/discount verification, (c) the CIP refund split. Split into a second spec only if the refund home lands elsewhere.

---

## Related Projects

| Code | JIRA | Relationship |
|---|---|---|
| ASCA | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog) | Sister project — built the foundation + the CAP refund design (02b) the CIP refund parallels |
| ASC (ASCM) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/boards/1186/backlog) | Base system — CIP charges ride its existing daily pro-ration |
| CIP (upstream) | — | Jefferson's team — creates the CIP charges ASCI recognizes |

---

## Key Documents

| Document | Location |
|---|---|
| CIP no-engine decision (normative) | `research/CIP/REF-CIP-05-Residual-Value-Pricing-Replaces-Allocation-20260917.md` |
| CIP refund patterns (normative) | `research/CIP/REF-CIP-06-CAP-CIP-Refund-Patterns-Overview-20260928.md` |
| CIP refund-type identification | `research/CIP/REF-CIP-07-CIP-Refund-Type-Identification-20261005.md` |
| Lesson-bundled CIP refund clarification | `research/CIP/REF-CIP-08-Lesson-Bundled-CIP-Refund-Clarification-20261020.md` |
| CIP product/plan IDs + price matrix | `research/CIP/REF-CIP-04-Product-Plan-IDs-And-Price-Matrix-20260824.md` |
| Technical design (shared framework) | `projects/asca/documentation/asc-allocation-framework-technical-design.md` |
| Master timeline (all ASC projects) | `docs/asc-projects-master-timeline.md` |
| ASCA project context (shared) | `projects/asca/project-context.md` |
| Plans & products reference | `domain-knowledge/plans-and-products.md` |

---

> **Status note (2026-10-20):** this file was rewritten to the REF-CIP-05/06/07/08 reality (no engine, product_id 10025/10022, residual ¥71,920, refund split). The prior version (engine-based, 10022/10021, ¥84,020) was fully superseded.
