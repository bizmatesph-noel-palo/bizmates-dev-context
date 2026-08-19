# CDB ↔ ASCH Alignment Gaps

**Source:** Efren-san (Confluence: "KIRO Review CDB and ASCH cross-check requirements")  
**Date:** 2026-07-27  
**Status:** 3 gaps assigned to ASCH team (Noel) for response

---

## Gaps Assigned to ASCH Team

### Gap #5: Proration Basis — How ASCH Identifies Honki Discounts

**Question:** How will ASCH identify that a charge was discounted by CDB (Honki Set 50%)?

**Options presented:**
- (a) ASCH reads `trn_campaign_discount_eligibility.discount_flag = 2` and cross-references `initial_charge_id`
- (b) CDB writes a marker on `trn_charge` (flag or discount_type column)
- (c) ASCH infers from `paid_price < sales_price` during eligibility window

**ASCH Team Answer: Option (a) — read from CDB table.**

Rationale:
- ASCH already snapshots `trn_campaign_discount_eligibility` at run start (per REF-ASCH-05 §5.1)
- `discount_flag = 2` means "granted as discount" — this IS the Honki Set 50% being applied
- `initial_charge_id` links to the original charge, and `discount_eligibility_date` tells us WHEN the discount fires
- No modification to `trn_charge` needed (aligns with "don't modify existing tables" principle)
- Option (c) is fragile — can't distinguish Honki 50% from First Month 50% by price alone

**How ASCH determines basis per row:**
1. Read CDB snapshot: student has `discount_flag` in (1, 2) for this campaign
2. For the month-6 charge specifically: if the charge's `paid_at` matches around `discount_eligibility_date` AND `discount_flag = 2` → this charge received the Honki Set 50% → basis = L (list price)
3. For month-1 Coaching: always Honki Set 50% (automatic for all members) → basis = L
4. For month-1 Lesson: check `log_first_month_enrollment_discount_apply` — if present, it's a SEPARATE First Month campaign → basis = M (paid amount)
5. For all other months: no Honki Set discount active → basis = L (full list price, no discount)

**What ASCH needs from CDB (no changes needed beyond current schema):**
- `discount_flag` values clearly indicate: 1 = eligible (not yet granted), 2 = granted (discount applied)
- `discount_eligibility_date` per product row (Lesson and Coaching can differ — already confirmed in Gap #11)

---

### Gap #6: ASCH Schema Dependency — Additional Columns Needed?

**Question:** ASCH needs these columns at minimum: `student_id`, `product_id`, `plan_id`, `initial_charge_id`, `discount_flag`, `discount_eligibility_date`. Are there additional columns ASCH will need?

**ASCH Team Answer: Current schema is sufficient.**

The 6 columns listed cover everything ASCH needs:
- `student_id` — match to charges
- `product_id` — identify which product (Lesson/Coaching/App)
- `plan_id` — determine plan variant (Daily 1/2/3/4, Monthly 15)
- `initial_charge_id` — link to `trn_charge` for start date, contract period, paid_price
- `discount_flag` — active/ineligible/granted status
- `discount_eligibility_date` — month-6 trigger date reference

**One request (not a new column, just clarification):**
- When `discount_flag` changes (e.g., student forfeits mid-campaign), does `log_campaign_discount_eligibility` capture the change with a timestamp? ASCH needs this for revision runs — if we re-run a past month, we need to know the state AT THAT TIME (which our snapshot handles, but the log confirms integrity).

---

### Gap #7: Discounted charge_id Not Recorded

**Question:** Should CDB record which specific `charge_id` received the discount (e.g., `discounted_charge_id`)? Or can ASCH derive it?

**ASCH Team Answer: ASCH can derive it. No new column needed on CDB.**

How ASCH derives it:
1. From CDB: `discount_eligibility_date` tells us WHEN the month-6 discount fires
2. ASCH queries `trn_charge` for the student's charge where `paid_at` is on or after `discount_eligibility_date` AND `product_id` matches AND `paid_price` reflects the 50% discount
3. The Coaching-based trigger rule (§7 in REF-ASCH-05) determines which Lesson charge gets the discount

This derivation is already part of ASCH's calculation logic — it doesn't need CDB to pre-compute it.

**However:** If CDB later adds `discounted_charge_id` for its own purposes (e.g., charge batch idempotency), ASCH would happily use it as a shortcut. But it's not a requirement.

---

## Gaps for JP Confirmation (Not ASCH Team)

| # | Gap | Severity | Our alignment |
|---|---|---|---|
| 1 | Campaign periods (quarterly vs Apr/Jul only) | Medium | ASCH is campaign-agnostic — driven by CDB records. No ASCH issue. |
| 2 | Simultaneous purchase for Trial/REST | High | ASCH requirement is clear (REF-ASCH-05 §4.1). CDB needs JP confirmation. |
| 3 | B2E partner dept exclusion ({21,22,23}) | Medium | ASCH requires this exclusion. CDB should enforce it too (or ASCH filters on its side). |
| 4 | Master table relationship (FK to mst_first_month_enrollment_discount_schedule) | Medium | No ASCH opinion — CDB internal design. |

## Already Resolved

| # | Gap | Resolution |
|---|---|---|
| 9 | Segment mapping | 3 CDB types map to 5 ASCH segments ✅ |
| 10 | "Never taken Coaching" | CDB seed verifies ✅ |
| 11 | Month-6 cascade timing | Separate dates per product ✅ |
| 12 | Month-1 mechanism | Not CDB scope ✅ |
| 13 | App lifecycle | All records ineligible when coaching cancelled ✅ |
| 14 | Lesson plan allowlist | Use plan page product_ids ✅ |
| 15 | Discount priority | Higher discount wins, max 50% ✅ |
