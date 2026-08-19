# ASC for CAP — Scope for Development Estimation

**Source:** Kuroda-san (Confluence: "ASC for CAP - Scope for Development (as of 260724)")  
**Date:** 2026-07-24  
**Status:** Draft for engineering estimation  
**Companion:** `docs/CAP-Initial analysis and breakdown for Coaching App Plan (アプリ自動付帯)-240726-045237.pdf` (application-side analysis, separate)

> ⚠️ **Partially superseded (2026-07-28):** Key decisions in `REF-CAP-02-Open-Items-Update-20260728.md` override parts of this document:
> - Eligibility: NEW dedicated App product_id (not plan_id as stated in §3/§5.1)
> - Option B: ELIMINATED (always separate charges — §7 is no longer applicable)
> - App price: confirmed flat ¥3,980 regardless of contract type

---

## 1. Objective

CAP changes Coaching sales so that Bizmates App is automatically attached to eligible Coaching purchases. The customer sees and pays a single Coaching price that includes the App benefit; the App price is not displayed separately.

For accounting, the received Coaching amount must be allocated between Coaching and App:

```
Existing Coaching / ASC recognition (unchanged) → recognized Coaching amount N
CAP allocation batch                            → final Coaching and App amounts P
Freee adjustment                                → P − N
```

---

## 2. Scope Boundaries

### In Scope
- CAP-eligible Coaching/App charges and their existing-recognition records
- Monthly accounting processing (refund, plan-change, contract-type-change effects)
- CAP revenue allocation, audit/detail output, summary output, Freee adjustment journals

### Out of Scope (Non-negotiable)
- Do not modify existing ASC calculation logic or overwrite existing ASC journals
- Do not alter App Store / Google Play payment processing (not a CAP allocation input)
- Do not allocate revenue for legacy Coaching plans that do not include App
- LMS display unchanged
- **New CAP tables must use `cap_*` namespace. Do not reuse ASCH tables merely because their design is similar.**
- Application-side work excluded (plan/master creation, purchase flows, renewal, Admin Portal UI, LP/terms, email, LMS/LAZ) — covered by companion analysis

---

## 3. Confirmed Functional and Data Assumptions

| Topic | Assumption |
|---|---|
| App contract creation | CAP purchase creates separate App contract/charge for product_id=10012, synchronized with Coaching contract period |
| App amount in CAP | paid_price=0 and sales_price=0 for all CAP payment paths |
| Coaching amount | Contains customer-paid, App-inclusive Coaching amount. Without CAP adjustment, existing recognition books entirely as Coaching. |
| CAP eligibility | CAP-specific plan_id is primary eligibility key. Must maintain explicit mapping of all CAP plan IDs. |
| Store App subscription | Represented by subscription status (trn_student_app_info.has_app_subscription). NOT a CAP allocation target. |
| App reference price | **JPY 3,980 tax inclusive** (CAP batch configuration constant). Do not update mst_product_price or mst_new_price_listing for CAP. |
| Rounding | Follow existing ASC rounding and remainder-absorption behavior |
| Freee | Required. CAP sends adjustment journals only; existing journals unchanged. |

---

## 4. Application-Side Boundary

The companion application-side analysis covers:
- New CAP plan IDs and mst_plan_content composition
- Price/plan master and model constants in bizmates.jp and MBTI_backend
- B2C purchase and B2B/B2E Admin Portal registration flows
- Monthly charge and redo-charge batches
- BCO renewal/ticket-related plan mappings
- Legacy-plan recovery behavior and payment-error notifications
- Coaching plan-change mappings, email templates, Admin Portal/report mappings
- Regression testing of low/no-impact consumers (LMS, BDash/Sprocket, credit-card expiry, MyStage, Trainer Portal)

These are prerequisites and sources of CAP charge data, but not included in this accounting-system estimate.

---

## 5. Revenue Allocation Design

### 5.1 Eligibility and Source Records

For each accounting month, select CAP Coaching charges using plan_id mapping:
- Read existing recognized amount for Coaching charge
- Verify related zero-yen App contract/charge (product_id=10012, synchronized period)
- Exclude legacy Coaching plans and independently purchased App contracts
- Preserve source charge IDs, plan ID, product IDs, contract type, partner/department, source-recognition record ID

**plan_id is mandatory discriminator.** A real App purchase must never become a CAP allocation target merely because the student also has a CAP contract.

### 5.2 Amount Formula

```
App allocation       = N × App reference price / (Coaching reference price + App reference price)
Coaching allocation  = N − App allocation
```

- All tax-inclusive JPY
- App reference price: **JPY 3,980** (tax inclusive)
- Coaching reference price: applicable Coaching 15-minute or 30-minute reference price
- Apply existing ASC rounding/remainder rule (App + Coaching always = N)
- Freee adjustment = final allocated amount − existing recognized amount

### 5.3 Refunds and Changes

- Refund of already-allocated amount: same original ratio, negative values
- Refund before booking: must not produce duplicate allocation
- Contract-type changes: preserve effective contract_type, partner, department for accounting period
- Plan change: processed charge by charge (month can have >1 CAP allocation record)

---

## 6. Existing-Recognition Inputs

CAP must use existing recognized amount, not independently reimplement recognition.

| Underlying plan type | Recognition input | CAP responsibility |
|---|---|---|
| Daily lesson / Coaching arrangement | `log_daily_rate_calculation` (or preview equivalent) | Allocate recognized CAP Coaching amount between Coaching and App |
| Monthly-count lesson arrangement | `log_monthly_rate_calculation` (or preview equivalent), if CAP transaction is represented there | Allocate only CAP-eligible amount; do not recreate ticket-consumption logic |

Must store specific source table and join key per CAP allocation detail row. Support preview and final source records consistently.

---

## 7. Monthly-Count Plan Dependency (Required Before Final Estimate)

New-plan list includes monthly-count cases:

| Existing lesson plan | CAP availability |
|---|---|
| 15L | B2C: Coaching + App can be added to existing lesson plan. B2B: not available. |
| 8L | B2B: available as a set once enabled in Admin Portal. |
| 10L | B2B: available as a set once enabled in Admin Portal. |

Application-side proposes new plan IDs for 15L combinations. 8L/10L described as "set" without plan IDs, product composition, or charge structure clarified.

### Estimation Option A — Separate Coaching + App Charge

If existing monthly-count lesson contract remains unchanged and Coaching + App is a separate charge, CAP allocates only the Coaching charge. Existing ASC ticket-consumption recognition for lesson remains unchanged. **This is the base scope.**

### Estimation Option B — Combined Lesson + Coaching + App Plan/Charge

If 8L/10L set creates one combined Lesson + Coaching + App plan/charge, lesson amount may also need allocation. Requires additional design for ticket consumption, partial-month recognition, suspension, refund, plan change, contract-type change. **Potentially comparable to ASCH-style monthly-count complexity.**

**Required answer:** For 15L, 8L, and 10L — provide CAP plan_id, product composition, charge structure, and key linking CAP Coaching/App records to underlying monthly-count lesson recognition record.

---

## 8. CAP Data Model and Outputs

Use CAP-specific tables. Exact names to be proposed by engineering:

| Logical Record | Purpose |
|---|---|
| CAP calculation run | Preview/final/revision metadata, target month, status, audit trail |
| CAP source snapshot | Immutable snapshot of inputs used for a run |
| CAP allocation detail | Per charge/component/month: N, reference prices, allocated amounts, adjustment, rounding, source IDs |
| CAP Freee summary | Aggregation at existing CalculationSummary grain |
| CAP summary-to-detail trace | Audit from summary to detail rows |

**Outputs (preview and final):**
- CAP allocation detail CSV (source charge ID, plan ID, month, N, allocated amounts, negative = refund)
- CAP Freee summary CSV (existing aggregation grain)
- Final-run: Freee adjustment journals only

---

## 9. Freee Integration

- Determine: generalize existing sender vs dedicated adapter (D-2)
- CAP summary must NOT be inserted into or confused with ASCH tables
- App uses product_id=10012 mapping; confirm production Freee dimensions (D-3)
- Preview: generate outputs, no journals. Final: generate + send approved adjustments.
- Revisions: preserve earlier calculations, send only new delta.

---

## 10. Acceptance Scenarios

Required automated tests and accounting-reviewed fixtures:

1. B2C CAP purchase: Coaching 15 minutes and 30 minutes
2. B2B manual App registration and B2E CAP purchase
3. Normal monthly renewal with new zero-yen App charge
4. Legacy Coaching renewal: no CAP allocation
5. Student with both CAP App and App Store / independently purchased App
6. Plan change from Coaching 15 minutes to 30 minutes in same accounting month
7. B2C/B2E contract-type change and resulting Freee dimensions
8. Suspension, cancellation, cooling-off refund (before and after allocation booked)
9. Preview, final, failed validation, revision delta processing
10. Monthly-count plans: Option A base case, plus Option B if combined-charge confirmed
11. CSV aggregation, rounding/remainder handling, Freee adjustment totals

---

## 11. Open Dependencies

| ID | Dependency | Requested treatment |
|---|---|---|
| D-1 | 15L/8L/10L CAP plan IDs, product composition, charges, recognition join key | Provide Option A and Option B estimates until confirmed |
| D-2 | CAP-specific Freee sender approach | State chosen approach, repos, assumptions |
| D-3 | Production App Freee mapping and accounting dimensions | Include config/data setup + accounting confirmation task |

---

## 12. Requested Estimation Format

Provide:
- Effort by workstream (CAP batch/data model, Freee/CSV integration, testing/UAT support)
- Impacted repositories and major components
- Option A base estimate AND Option B monthly-count combined-charge estimate
- Assumptions, exclusions, and risks
- Earliest feasible delivery schedule and required external dependencies
