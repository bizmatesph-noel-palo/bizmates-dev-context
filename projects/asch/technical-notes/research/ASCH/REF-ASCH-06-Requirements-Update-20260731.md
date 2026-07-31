# ASCH Requirement Updates — 2026-07-31

**Source:** Kuroda-san (Confluence: "Update — 2026-07-31: Month-6 Discount Timing Correction, Plan-Change Pricing, and Eligibility-Loss Handling")  
**Status:** AUTHORITATIVE for the topics it covers — supersedes the 2026-07-06/07-07/07-15 sequence-based month-6 trigger description (H-3), and Pattern 3 / Pattern 9 walkthroughs where they rely on payment sequence.  
**Scope:** Five clarifications: month-6 timing, plan-change pricing, eligibility-loss handling, target_month anchoring, and H-4 Freee mapping production confirmation.

---

## What's New or Changed (vs REF-ASCH-05, 2026-07-24)

| # | Item | Change | Impact |
|---|---|---|---|
| 1 | Month-6 discount timing | **CORRECTED** — calendar-month based, not payment-sequence based | Trigger logic in ASCH and CDB must key off calendar month, not charge post order |
| 2 | Discount base on plan change | **CONFIRMED** — discount applies to new plan's price, not signup-time price | No locked-in price mechanism needed |
| 3 | Eligibility-loss handling | **CONFIRMED** — future-only reversion, past discounts kept as-is | No retroactive recalculation |
| 4 | Lesson target_month anchor | **CONFIRMED** — must follow Coaching's timeline, not Lesson's own start | component_month_seq alignment rule |
| 5 | H-4 Freee mapping (partial) | **CONFIRMED** — mst_code_change code=100, mst_rule_for_journals rows exist | 2 of 5 original checks done; 3 narrower items remain |

---

## §1. Month-6 Discount Timing — CORRECTED

### Previous Understanding (WRONG)

The 6th-month 50% Lesson discount applies to the first Lesson payment that comes **after** the Coaching 6th-month payment (sequence-based). This produced the Pattern 3 vs. Pattern 9 split in earlier walkthroughs.

### Corrected Rule

The discount applies to the Lesson payment that falls within the **calendar month** in which Coaching reaches its 6th month — regardless of whether that Lesson payment occurs before or after the Coaching payment within that month.

### Example

If the Lesson payment date precedes the Coaching 6th-month payment date within the same calendar month, the Lesson payment is discounted immediately. It does not wait for the Coaching payment to post.

### Impact

- Trigger-charge identification logic (both ASCH's `component_month_seq` evaluation and CDB's eligibility-date evaluation) must key off **calendar month**, not payment sequence.
- Pattern 3 and Pattern 9 walkthroughs need to be re-read under this rule — the sequence-based split they illustrate **no longer applies**.
- Acceptance Scenario #13 ("C6 date before and after Lesson payment date") from REF-ASCH-05 §12 remains valid but the expected behavior changes: both sub-cases now result in the discount being applied (same calendar month = discount triggers).

---

## §2. Discount Base Price on Lesson Plan Change (CDB Clarification No.17)

**Confirmed:** As long as the changed Lesson plan is still a Honki Set–eligible plan, the discount applies to the price of the **new (changed) plan**, not the plan price at the time of original campaign signup.

There is no mechanism that locks in a signup-time price; the discount is always evaluated against the actual charge for that month.

### Impact

- ASCH proration uses the actual `trn_charge.paid_price` (M) for the current month — no historical price lookup needed.
- Plan-change patterns (Pattern 4, Pattern 6) already use the current charge's price. This confirms that approach is correct.

---

## §3. Eligibility-Loss Handling — Retroactive Treatment (CDB Clarification No.18b)

**Confirmed:** When a student loses Honki Set eligibility partway through the 6-month cycle, only **future months** (from the point eligibility is lost onward) revert to regular pricing. Discounts already applied in past months (e.g., the month-1 half-price discount) are kept as-is — no refund, no retroactive cancellation.

This follows the same principle already applied to other eligibility-loss patterns:
- B2E → B2B contract change
- Cooling-off cancellation

**Rule:** Stop future application, do not undo the past.

### Impact

- ASCH does not need a retroactive recalculation mechanism.
- When processing a month where the student has lost eligibility, ASCH simply excludes that student from the current run. Prior runs' results remain untouched.
- Revision/supersession logic (run management) does NOT apply to eligibility loss — it only applies to corrections of calculation errors.

---

## §4. Lesson target_month Anchor (CDB Clarification No.7/8/11)

**Confirmed:** A Lesson component's `target_month` must NOT be anchored to the Lesson's own contract start date. It must be anchored to **Coaching's contract timeline** (Coaching's `component_month_seq`).

### Rationale

Direct consequence of §1: since both the month-1 and month-6 discount timing are keyed off Coaching's calendar-month progression, the Lesson side's month index must follow the same anchor to stay consistent.

This includes students who added Coaching to an already-existing Lesson contract (eligibility-path definitions from CDB Clarification answers — out of scope for ASCH-side implementation, but ASCH must consume the anchor correctly from CDB data).

### Impact

- `asch_bundle_components.component_month_seq` for Lesson rows follows Coaching's timeline, not Lesson's own charge history start.
- When ASCH identifies which month a Lesson charge belongs to, it counts from Coaching's enrollment month, not Lesson's.

---

## §5. H-4 Freee Mapping — Production Confirmation (Partial)

### What Was Confirmed

During a related project session (CAP) on dev04:

| Item | Before | After |
|---|---|---|
| `mst_code_change.code` for App (product_id=10012) | Row existed (freee_code=236270504), code column unconfirmed | **Confirmed: code=100** (id=43, freee_code=236270504, item_name='Bizmates App', created_at 2025-04-03) |
| `mst_rule_for_journals` for product_type=236270504 | Assumed "likely not registered yet" | **4 rows already exist** covering B2B/B2C/B2B2C/Partner (id=102/109/110/111) |

### mst_rule_for_journals Detail

| id | Contract Type | segment1_id | department_id | Notes |
|---|---|---|---|---|
| 102 | B2B | 261923 (B-series) | 1652032 | Updated 2026-05-20 |
| 109 | B2C | 261923 (B-series) | 1652034 | ⚠️ Different department_id. Updated 2026-05-20 |
| 110 | B2B2C | 261923 (B-series) | 1652032 | |
| 111 | Partner | 261923 (B-series) | 1652032 | |

**Key observation:** All 4 rows use segment1_id=261923 (B-series / Lesson-style accounting classification). App is booked under B-series regardless of contract type.

### Remaining Open Points Under H-4

Previously: 5 unconfirmed items → Now: **3 narrower items remain**

1. Why the B2C row's `department_id` (1652034) differs from the other 3 (1652032)
2. What changed in the 2026-05-20 update to rows 102 and 109
3. Whether rows 109–111 were added specifically for ASCH (needs confirmation from accounting team)

---

## Updated Open Items List

| # | Item | Owner | Status |
|---|---|---|---|
| 4 | MySQL version (json/utf8mb4) | Dev | Open (minor) |
| 7 | CDB table name alignment | CDB team (Wu-san) | ⚠️ Still pending final confirmation |
| 8 | ASCH email subject/body | Kuroda-san | Open — must approve before go-live |
| 5a | H-4: B2C department_id difference | Accounting / Kuroda-san | ⚠️ New (narrowed from H-4) |
| 5b | H-4: 2026-05-20 update context | Accounting / Kuroda-san | ⚠️ New (narrowed from H-4) |
| 5c | H-4: Were rows 109–111 ASCH-specific? | Accounting / Kuroda-san | ⚠️ New (narrowed from H-4) |

---

## Pattern Impact Assessment

| Pattern | Affected by §1? | Notes |
|---|---|---|
| 1 | No | Same calendar month — no sequence ambiguity |
| 2 | No | Different start dates — but §4 (anchor) may affect month counting |
| 3 | **YES** | Previously split from Pattern 9 based on sequence — that split no longer applies |
| 4 | No | Plan change — §2 confirms existing approach |
| 5 | No | REST/cancellation — eligibility loss (§3) |
| 6 | No | Plan type change — §2 applies |
| 7 | No | B2E→B2B — eligibility loss (§3) |
| 8 | No | Cooling-off — eligibility loss (§3) |
| 9 | **YES** | Previously split from Pattern 3 based on sequence — that split no longer applies |

**Key simplification:** Patterns 3 and 9 no longer need separate handling for "Lesson payment before vs after Coaching payment." The month-6 discount simply applies if both payments fall in the same calendar month as Coaching C6.
