# CAP Open Items — Update as of 2026-07-28

**Source:** Kuroda-san (Confluence: "CAP Open Items — Update as of 20728")  
**Date:** 2026-07-28  
**Status:** Confirmed decisions

---

## Confirmed This Round (2026-07-28)

### 1. App Allocation Base Amount

**Decided:** Flat ¥3,980 (tax included), regardless of contract type (B2B / B2C / B2E).

No per-contract-type variation. Same price for all.

### 2. CAP Bundle Target Detection — NEW PRODUCT_ID (Not plan_id)

**Decided:** Whether a Coaching charge is a CAP bundle target is determined by the **presence of a newly created, auto-bundle-dedicated App product_id** (NOT by plan_id).

- If a charge with that product_id exists → linked Coaching charge IS an allocation target
- If not (e.g., existing standalone B2B App) → excluded
- The App charge itself continues to be registered at ¥0

> ⚠️ **This contradicts our recommendation and the original CAP scope doc (§5.1 "plan_id is the mandatory discriminator").** The decision is: a NEW App product_id (not 10012) will be created specifically for CAP-bundled App. Detection is by this new product_id, not by plan_id.

**Implication for ASC for CAP:**
- The eligibility query changes from "find Coaching charges on CAP plan_ids" to "find Coaching charges that have a linked App charge with the new CAP-dedicated product_id"
- Need to know: what is the new product_id? (TBD from application-side team)
- This resolves the ¥0 ambiguity completely — FVP (10011) and standard App (10012) won't match because they use different product_ids

### 3. Monthly-Count Plans — NO Combined Charge (Option B Eliminated)

**Decided:** For monthly-count plans (8L/10L etc.) sold with Coaching, Coaching and App are still created as **separate charges** — never merged into a single combined charge with Lesson.

**Impact:** Option B from the CAP scope doc is now eliminated. No extra allocation logic needed for monthly-count plans. **CAP is Option A only.**

This simplifies the estimate:
- No ticket-consumption allocation
- No partial-month lesson recognition
- Only Coaching charge allocation (same as daily-plan case)

### 4. Release Deadline Confirmed

**Decided:** Both CAP and CIP deadline = **2026-12-17**.

This is later than the original ~November 2026 target from the 4/13 estimate.

---

## Impact on Our Estimates and Docs

| Item | Previous State | After This Update |
|---|---|---|
| CAP eligibility key | plan_id (§5.1 of scope doc) | **New dedicated App product_id** (not plan_id, not 10012) |
| Option B (combined charge) | Open — needed D-1 answer | **Eliminated** — separate charges confirmed |
| CAP estimate Option B (+2.5 wk) | In scope as contingency | **Removed from scope** — only Option A applies |
| App reference price per contract type | Unknown if varies | **Flat ¥3,980 for all** — no branching needed |
| Deadline | TBD / ~November | **2026-12-17** (confirmed) |

---

## What Still Needs Clarification

| Question | Why it matters |
|---|---|
| What is the new CAP-dedicated App product_id? | ASC for CAP eligibility query needs this value |
| Will CIP use the same new product_id or another? | ASC for CIP eligibility may differ |
| Is this new product_id already in `mst_product`? | Need to know if migration is needed on our side |
| Does the existing App (10012) continue for non-CAP (e.g., Honki Set ASCH)? | ASCH should not be affected |
