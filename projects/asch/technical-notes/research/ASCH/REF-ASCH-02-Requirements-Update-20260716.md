# ASCH Requirement Updates — 2026-07-16

**Source:** Kuroda-san (Confluence: "Requirement Updates as of 260716")  
**Status:** Supersedes corresponding sections of REF-ASCH-00-PRJ-Specification.md  
**Impact:** Multiple open items resolved; schedule confirmed; new decisions.

---

## 1. Schedule (CONFIRMED)

- **First production run: 2026/10/1**
- Reason: quarterly closing (fiscal Q Jul–Sep). Accounting needs July–September revenue finalized on 10/1.
- Regular cadence: preview on 1st, final + Freee on 3rd (same as ASC)
- **Parallel projects:** CAP and CDB will run in parallel — need to sync status

## 2. Eligible Students (UPDATED / CORRECTED)

**Correction:** Students with **any past Coaching experience are NOT eligible.** The earlier note saying "cancelled Coaching → eligible again" is WRONG.

**Eligible paths:**
- Trial and REST students: only through "Bizmates & BCO Enroll/ReEnroll" simultaneous application (Lesson + Coaching at same time)
- Lesson-only or Coaching-only contract NEVER makes them eligible

**Eligible Lesson plans (EXPANDED):**
- Daily 1 / Daily 2 / Daily 3 / Daily 4 / Monthly 15
- Legacy daily plans: Daily 25 / 50 / 75 / 100 minutes (predecessors of Daily 1–4)
- `component_variant` values to be added for legacy plans

**Exclusions (unchanged):**
- B2B (contract_type=1)
- Overseas (country_id≠86)
- Partner-company students (contract_type=2 with department_id in {21, 22, 23})

**Reference:** BizmateCampaignMap.xlsx (Marketing) — orange cells = Honki Set

## 3. Proration Basis — DECIDED

**General rule:**
- Discounts that belong to Honki Set itself (Coaching month-1 50%, month-6 50% for Lesson/Coaching) → use **List Price (L)**. The discount is reflected in ΣM being distributed, not in the ratio.
- Discounts unrelated to Honki Set (ALL others: First Month B2C/B2E, Okaeri/REST campaign, Loyal benefits, B2E campaign) → use **Paid Amount (M)**.

**Background fact:** At Honki Set enrollment, both Lesson and Coaching appear to be 50% off in month 1, but only the Coaching discount is Honki Set. The Lesson month-1 discount is the standalone First Month campaign for B2C/B2E.

## 4. Month-6 Discount — DECIDED (Coaching-based trigger)

- **Trigger:** Coaching reaching its own month 6 (C6)
- Once C6 is fulfilled → 50% discount applies to the **first Lesson payment after that point**
- If Lesson payment falls **after** Coaching month-6 date → discount applies to that month's Lesson
- If Lesson payment falls **before** it → discount applies to next Lesson payment (e.g., L7)
- **Lesson payments subject to proration: L1–L6** (not L2–L7)
- Plan change within campaign period does NOT reset the 6-month count

**Rounding:** Follow existing ASC rounding/remainder-absorption as-is (DECIDED).  
**Monthly-15 plan:** Months where P > list price → booked as-is (DECIDED). Warning line in validation report.

## 5. Refunds — UNIFIED PRINCIPLE (DECIDED)

> If the original payment was already prorated → refund is prorated (same list-price ratio).  
> If the original payment was never prorated → refund booked directly (no proration).

### 5.1 B2E→B2B Switch (Pattern 7)

- Refund (daily-rate refund of B2E Lesson) IS prorated — same ratio as original payment
- Negative M and negative P; negative M included in group's ΣM → ΣO=ΣM holds with signs
- **Switch month denominator: Coaching + App only** — B2B Lesson fully excluded (B2B out of Honki Set scope)
- App included in proration for switch month; from following month eligibility lost, App proration stops
- Expected frequency: very low. Manual adjustment acceptable as fallback.

### 5.2 Cooling-off (Pattern 8)

**Actual operation:**
1. Admin refunds full charge amount minus 10% fee (90% refunded) via Charge History
2. Admin manually sets student to REST
3. Final status is REST — no "cancelled" status

**Detection:** Must use refund records (`trn_prorated_refund` / negative charges) as source of truth. Takes priority over REST status (disambiguates Pattern 5 vs Pattern 8).

**Two cases:**
- Before batch books the month (Pattern 8-1): payment never prorated → refund booked directly
- After payment was prorated (Pattern 8-2): refund prorated with same ratio. Per-product lifetime = O × (1 − refund rate)

### 5.3 App at Cooling-off (NEW SCOPE DECISION)

- Admin REST covers Lesson/Coaching only — no function to immediately suspend App
- ASCH will NOT implement App suspension logic
- That function is planned for the "auto-attach App to Coaching" project (release Jan 2027)
- **Operational rule:** Fix data directly in DB case by case (Honki Set cooling-off expected to be rare)
- App remaining until its month-end is correct behavior under current system

### 5.4 Pattern 9 (B2E + Loyal)

- Loyal discount applies to each month's Lesson payment
- Proration uses discounted paid amount as Lesson basis (M) — per Section 3 principle

## 6. Member Identification — CDB Integration (UPDATED)

**Primary source:** Table from CDB project  
**Tentative table name:** `trn_campaign_discount_eligibility`  
**Change history:** `log_campaign_discount_eligibility`

**Structure:**
- One row per student × campaign × product (Lesson / Coaching / App)
- Carries: `initial_charge_id`, `discount_flag`, `discount_eligibility_date`
- Rows created at purchase time

**ASCH integration pattern:**
1. At run start, ASCH snapshots relevant CDB rows into `asch_source_documents`
2. Builds enrollment layer from the snapshot
3. CDB table is upsert-overwritten → revision runs must NEVER read "as-of" from CDB directly
4. ASCH snapshot is source of truth for past runs

**New columns on `asch_bundle_components`:**
- `cdb_eligibility_id` (logical FK)
- `discount_eligibility_date` (snapshot — cross-checking only; month-6 judgment follows Section 4)
- `source_charge_id` (from CDB's `initial_charge_id` — real charge_id expected even for App, since 0-yen App charges exist)

**Table count: 9** (asch_app_price_master ABOLISHED)  
**App list price:** ¥3,980 tax-included, read from `mst_new_price_listing`

**Fallback:** If CDB production + July-cohort backfill not ready before 10/1, ASCH falls back to self-contained cohort detection.

## 7. Open Items (CURRENT — as of 2026-07-16)

| # | Item | Owner | Notes |
|---|---|---|---|
| 1 | Run management model: run_id generation vs _pre/final two-table | Dev | |
| 2 | N source for preview runs (log_*_pre vs confirmed; default: preview→_pre, final→confirmed) | Dev | |
| 3 | Verify 0-yen App charges in existing ASC output (do they produce N=0 rows for product_id=10012; Freee behavior for 0-yen journals; generation pattern) | Dev | |
| 4 | MySQL version of target DB (json type / utf8mb4 assumptions) | Dev | |
| 5 | Tax handling of App list price (¥3,980 tax-incl → ¥3,618.18 tax-excl; rounding must match existing ASC) | Dev / Accounting | |
| 6 | Retroactive proration for Jan/Apr 2026 campaigns (default: out of scope; revision run can cover later) | Accounting | |
| 7 | CDB prerequisites: production rollout + July backfill before 10/1; change-log guarantees; App-row flag; month-6 trigger date alignment | CDB team (Wu-san) | |

---

## What Was Resolved (Previously Open, Now Decided)

| Previous Open Item | Resolution |
|---|---|
| App list price (¥3,600 vs ¥2,500) | **Resolved:** ¥3,980 tax-included from `mst_new_price_listing`. `asch_app_price_master` table ABOLISHED. |
| Rounding rule | **Resolved:** Follow existing ASC rounding as-is. |
| Month-6 discount baseline | **Resolved:** Coaching-based trigger (C6). Lesson subject to proration: L1–L6. |
| Monthly-15 P > list price | **Resolved:** Booked as-is. Warning in validation report. |
| B2E→B2B switch — App excluded? | **Resolved:** App included in switch month; proration stops from following month. |
| Refund month allocation | **Resolved:** Unified principle — prorated if original was prorated, direct if not. |
| Honki Set member identification | **Resolved:** CDB table (`trn_campaign_discount_eligibility`) with ASCH snapshot fallback. |
| Eligible plans | **Expanded:** Now includes Daily 3, Daily 4, and legacy plans (Daily 25/50/75/100 min). |
| Cancelled Coaching → re-eligible? | **Corrected:** NO — any past Coaching experience = NOT eligible. |

---

## Impact on ASCH Tables

| Table | Change |
|---|---|
| `asch_app_price_master` | **REMOVED** — App price from `mst_new_price_listing` instead |
| `asch_bundle_components` | New columns: `cdb_eligibility_id`, `discount_eligibility_date`, `source_charge_id` |
| Total table count | **9** (was 10; asch_app_price_master removed) |

---

## Impact on ASCH Project Context

| Section | Update Needed |
|---|---|
| project-context.md | Table count 10→9; open items list; schedule (10/1 deadline) |
| Eligibility spec | Corrected rules; expanded plans; CDB integration |
| Proration spec | Basis rule confirmed; month-6 trigger; refund principle |
| Foundation spec | One fewer table; new columns on bundle_components |
| Steering files | Update where they reference 10 tables or unresolved items |
