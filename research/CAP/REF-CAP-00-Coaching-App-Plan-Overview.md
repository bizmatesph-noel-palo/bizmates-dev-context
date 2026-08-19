# CAP (Coaching App Plan) — Reference for ASCH

**Last updated:** 2026-07-16  
**Source:** Confluence — CAP Development Plan  
**Status:** Project not yet started. May run in parallel with ASCH.  
**Relevance to ASCH:** Medium — new plan composition may affect how ASCH identifies products and calculates proration.

---

## What CAP Is

CAP (Coaching App Plan / アプリ自動付帯) bundles the Bizmates App automatically with Coaching plans. Instead of App being a separate free product in Honki Set, CAP makes App a standard component of all Coaching plans.

**Selected approach: Approach A** — create new `mst_plan` IDs only, reusing existing atomic products:
- Lesson (product_id 1)
- FVP (product_id 10011)
- Coaching 30min (product_id 10015)
- App (product_id 10012)

Composed via `mst_plan_content` (4 junction rows per plan). No new `mst_product` rows.

**Key principle:** Products stay separate → all detection logic unchanged:
- `hasActiveMobileContract()` → product_type = 100 (App 10012) still works
- `isCoachingProduct()` → product_id = 10015 still works
- App remains independently identifiable

---

## Timeline & Effort

- POC: ~8 working days (1.5 weeks)
- Full development: ~30 working days (6 weeks)
- Total: ~38 working days (7.5 weeks) with 2 engineers
- **Not yet started** — prerequisites pending (dev server access, plan pricing, plan_id assignment)

---

## How CAP Differs from Honki Set

| Aspect | Honki Set (current) | CAP (planned) |
|---|---|---|
| App inclusion | Free for 6 months as campaign benefit | Permanent component of Coaching plans |
| Plan structure | Student buys Lesson + Coaching separately; App added as benefit | Single plan contains all 4 products |
| `trn_student_product` rows | Separate rows for each product | Still separate rows (Approach A preserves this) |
| App charge | ¥0 in `trn_charge` (free benefit) | TBD — may have package_price on `mst_plan` |
| Duration | 6-month benefit period | Permanent (as long as Coaching active) |
| Eligibility | Campaign-specific (quarterly window) | All new Coaching purchasers |
| product_id for App | 10012 (same) | 10012 (same — reused) |

---

## ASCH Impact Assessment

### What ASCH cares about from CAP:

1. **App product_id stays 10012** — ASCH already uses this. No change needed.

2. **App product_type stays 100** — ASCH's Freee mapping gap (Open Item #5) is the same regardless of CAP.

3. **New plan_ids for Coaching+App bundles** — ASCH identifies Honki Set members by campaign eligibility, not by plan_id. As long as the student is enrolled through the Honki Set campaign window AND has Coaching 30min + Lesson + App, the plan_id doesn't matter for proration.

4. **App is no longer ¥0-only** — if CAP introduces a package_price where App has implicit value, the proration formula's `M(App) = 0` assumption may change for CAP students. However, for Honki Set students specifically, App is still ¥0 (free 6-month benefit, not a paid plan component).

5. **Overlap scenario:** A student on a CAP plan (Lesson+FVP+Coaching+App) who also qualifies for Honki Set campaign discounts. In this case:
   - The student already has App as part of their plan (not as a Honki Set benefit)
   - Does Honki Set proration still apply? Or is the App already "paid for" through the bundle?
   - **This is a new open question for business.**

### Risk Level for ASCH: LOW

- CAP uses Approach A (same products, new plans) — no structural change to how charges/products work
- App detection via product_type = 100 is preserved
- The 4 products create 4 separate `trn_student_product` rows — ASCH can still identify them individually
- Proration formula doesn't depend on plan_id — it works at the product/charge level

### Potential Coordination Items

| Item | Risk | When it matters |
|---|---|---|
| Student on CAP plan qualifies for Honki Set | Medium | When both CAP and Honki Set are live simultaneously |
| App's M value changes (package_price allocation) | Low | Only if business decides CAP App carries a price — currently unconfirmed |
| ASC-97 (Coaching in Daily/Monthly CSV) — PARKED | Low | Accounting reporting only — not blocking purchase or proration |
| `mst_plan_content` query for identifying bundle | Low | ASCH doesn't query by plan; queries by product + charge |

---

## ASC/ASCH Status Note (from CAP doc)

> "There is not much parallel between CAP and ASC for this initiative. The ASC work related to coaching is currently parked — ASC-97 'Coaching Plan in Daily and Monthly CSV' (status: PARKED)."
>
> "Because there is little overlap, the CAP purchase + charge-batch work does not block on ASC, and vice versa."

This confirms:
- CAP and ASCH can proceed independently
- The only shared concern is accounting/reporting of the new plans (ASC-97, parked)
- No blocking dependency in either direction

---

## Data Model Summary (Approach A)

```
mst_plan (new, ~12-14 rows)
├── plan_id: TBD
├── plan_name: "Lesson 25+FVP+Coaching+App 30min"
├── contract_type: coaching
└── mst_plan_content (4 rows per plan)
    ├── product_id: 1      (Lesson 25)      → product_type: 1
    ├── product_id: 10011  (FVP)            → product_type: 7
    ├── product_id: 10015  (Coaching 30min) → product_type: 9
    └── product_id: 10012  (App)            → product_type: 100
```

Each product creates its own `trn_student_product` row and its own `trn_charge` row (confirmed in POC Phase 2 task B1: "Verify charge batch renews all 4 product rows of the bundle").

---

## Repos Involved

| Repo | CAP Role | ASCH Overlap |
|---|---|---|
| ls-database-migrations | Seed mst_plan + mst_plan_content | None (ASCH tables are separate) |
| MBTI_backend | Purchase, recovery, plan change | Read-only reference for ASCH |
| MBTI_frontend | Student UI | None |
| bizmates.jp | Charge batch, admin, pricing, emails | None (ASCH reads trn_charge after charge batch writes) |
| accounting_related_system_for_freee | Not involved in CAP | ASCH lives here |

---

## Open Question for Business (New from this analysis)

**Q:** If a student purchases a CAP plan (Coaching+App bundled) AND also qualifies for the Honki Set campaign in the same period — does ASCH proration apply?

Scenarios:
- (A) CAP student is excluded from Honki Set (App is already included in their plan, no need for the "free 6-month App" benefit)
- (B) CAP student can still get Honki Set discounts (50% month-1, 50% month-6) but App proration is different because M(App) ≠ 0

This needs business clarification if both CAP and Honki Set campaigns will be live simultaneously.
