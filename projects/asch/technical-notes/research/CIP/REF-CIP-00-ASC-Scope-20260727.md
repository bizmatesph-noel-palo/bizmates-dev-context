# ASC for CIP — Engineering Scope for Development Estimation

**Source:** Kuroda-san (Confluence: "CIP - Engineering Scope for Development Estimation")  
**Date:** 2026-07-27  
**Last updated:** 2026-07-31 (addendum: ASC pipeline sufficiency analysis)  
**Status:** Draft for engineering estimation  
**Deadline:** December 2026 (first batch run: 2027/01/01)

---

## 1. Objective

### 1.1 What CIP Is

CIP (Coaching Intensive Plan / コーチング短期集中プラン) is a new top-tier Coaching offering combining:
- A selected (higher-tier) coach, assigned by operations after purchase (B2C/B2E) or manually in BCO Admin (B2B)
- Daily progress management and dedicated curriculum (180 min/day: 60 min lesson, 120 min guided study)
- Automatic Bizmates App attachment (same mechanism as CAP)

**Target customers:** B2C, B2E, and B2B (Taiwan excluded).  
**Contract unit:** 1-month subscription (expected 3 months, but each month billed/recognized independently).  
**Pricing:** ¥80,000/month, ¥240,000 for 3 months (tax-exclusive, subject to confirmation) for Coaching + App only.  
**Lessons:** NOT bundled into CIP price (confirmed 2026-07-27, RA-02). Customer purchases lessons separately.

### 1.2 Why This Estimate Is Needed

For accounting, the received CIP amount must be allocated between Coaching and App:

```
Existing Coaching / ASC recognition (unchanged) → recognized Coaching amount N
CIP allocation batch                            → final Coaching and App amounts P
Freee adjustment                                → P − N
```

---

## 2. Delivery Timeline (Critical Constraint)

- Application-side team targets **December 2026 release**
- Revenue aggregation needs CIP data starting from **January 1, 2027 batch run**
- Therefore accounting-system must also target **December 2026 release**
- Cannot trail the application-side release

**Estimation must explicitly state:** whether December delivery is feasible, and if not, earliest realistic date.

---

## 3. Scope Boundaries

### In Scope
- CIP-eligible Coaching/App charges and their existing-recognition records
- Monthly accounting processing (refund, plan-change, contract-type-change effects)
- CIP revenue allocation, audit/detail output, summary output, Freee adjustment journals

### Out of Scope (Non-negotiable)
- Do not modify existing ASC calculation logic or overwrite existing ASC journals
- Lessons excluded from allocation (separate existing-plan charges, processed by existing pipeline)
- Do not allocate for legacy Coaching plans or CAP plans
- LMS display unchanged
- **New CIP tables must use `cip_*` namespace. Do not reuse `asch_*` or `cap_*` tables (decided, RA-09).** Based on CAP's precedent of rejecting ASCH-table reuse (reference-price and eligibility-key collisions). ASCH four-layer design reused as structural template only, not shared tables.
- All application-side work (purchase flows, plan/master setup, coach matching, Admin Portal, LP/terms, email, BCO fee) = separate team, out of scope

---

## 4. Application-Side Boundary

CIP's purchase, plan/master setup, coaching operations, and App auto-attachment are owned by a separate team. This estimate covers only downstream accounting/revenue-allocation processing.

Source of truth for application boundary: `requirements/01_CIP_REQUIREMENTS.md` and `requirements/03_CONFIRMATION_GUIDE.md`

---

## 5. Confirmed Functional and Data Assumptions

| Topic | Assumption |
|---|---|
| CIP composition | Coaching-only plan (30-minute, 1-month contract). Lessons never bundled into CIP price (confirmed 2026-07-27). |
| App contract creation | CIP purchase creates separate App contract/charge for product_id=10012, synchronized with Coaching period, mirroring CAP pattern. Working assumption — verify against real sample data (RA-01 remaining). |
| App amount | paid_price=0 and sales_price=0, same as CAP. Working assumption (confirmed 2026-07-27). |
| Coaching amount | Contains customer-paid, App-inclusive CIP amount. Without CIP adjustment, existing recognition books entirely as Coaching. |
| CIP eligibility | CIP-specific plan_id is primary key. Must maintain explicit mapping distinct from legacy Coaching and CAP plan IDs. |
| Allocation basis | **List price ("定価") ratio** of Coaching and App (confirmed 2026-07-27). Same method as ASCH for bundle-specific discounts (proration_basis = list_price). NOT paid-price ratio. |
| Reference price values | **Not yet confirmed (D-1).** Do not reuse ASCH's ¥3,980 or CAP's ¥3,980 without explicit CIP confirmation. |
| Store App subscription | Represented by subscription status (trn_student_app_info.has_app_subscription). NOT a CIP allocation target. |
| Rounding | Existing ASC rounding/remainder-absorption behavior, pending confirmation. |
| Freee | Required. Sends adjustment journals only. Sender approach open (D-3). |
| Architecture | CIP-specific `cip_*` tables and batch (decided, RA-09). |

---

## 6. Revenue Allocation Design

### 6.1 Eligibility and Source Records

For each accounting month, select CIP Coaching charges using plan_id mapping:
- Read existing recognized amount for Coaching charge
- Verify related zero-yen App contract/charge (product_id=10012, synchronized period)
- Exclude legacy Coaching, CAP plans, and independently purchased App
- Preserve source charge IDs, plan ID, product IDs, contract type, partner/department, source-recognition record ID

**plan_id is mandatory discriminator.** Real App purchase, CAP-attached App, or independent lesson charge must never become CIP allocation target.

### 6.2 Amount Formula

```
App allocation       = N × App list price / (Coaching list price + App list price)
Coaching allocation  = N − App allocation
```

- All tax-inclusive JPY (pending D-1 tax basis confirmation)
- Both reference prices are **list prices** (confirmed), not paid/discounted prices
- Apply existing ASC rounding/remainder rule (App + Coaching always = N)
- Freee adjustment = final allocated amount − existing recognized amount

### 6.3 Refunds and Changes

- Refund of already-allocated amount: allocate using same original ratio, negative values
- Refund before booking: must not produce duplicate allocation
- **Coaching and App start, suspend, and end simultaneously (RA-06).** Plan change, suspension, cooling-off, cancellation applies to both together. Stop dates and refund-charge linkage need verification against real data.
- Contract-type changes: preserve effective contract_type, partner, department for accounting period (RA-07: charge values still open)
- Plan change: processed charge by charge (month can have >1 CIP allocation record)

---

## 7. Existing-Recognition Inputs

| Underlying plan type | Recognition input | CIP responsibility |
|---|---|---|
| Coaching (30-min, daily-rate) | `log_daily_rate_calculation` (or `_pre`) | Allocate CIP Coaching amount between Coaching and App |

No monthly-count/ticket dependency (unlike CAP's Option B). Lessons alongside CIP are untouched.

Must store specific source table and join key per CIP allocation detail row. Support preview and final source records consistently.

---

## 8. CIP Data Model and Outputs

Use `cip_*` namespace (per RA-09). Structurally modeled on ASCH's four-layer design but physically independent:

| Logical Record | Purpose |
|---|---|
| CIP calculation run | Preview/final/revision metadata, target month, status, audit trail |
| CIP source snapshot | Immutable snapshot of inputs used for a run |
| CIP allocation detail | Per charge/month: N, reference prices, allocated amounts, adjustment, rounding, source IDs |
| CIP Freee summary | Aggregation at existing CalculationSummary grain |
| CIP summary-to-detail trace | Audit from summary to detail rows |

**Outputs (preview and final):**
- CIP allocation detail CSV (source charge ID, plan ID, month, N, allocated amounts, negative = refund)
- CIP Freee summary CSV (existing aggregation grain)
- Final-run: Freee adjustment journals only

---

## 9. Freee Integration

- Determine: generalize existing sender vs dedicated adapter (D-3)
- CIP summary must NOT be inserted into ASCH or CAP tables
- App uses product_id=10012 mapping; confirm production Freee dimensions (D-4)
- Preview: generate outputs, no journals. Final: generate + send approved adjustments.
- Revisions: preserve earlier calculations, send only new delta (D-6)

---

## 10. Acceptance Scenarios

Required automated tests and accounting-reviewed fixtures:

1. B2C, B2E, and B2B CIP purchase (all in scope from start)
2. Normal monthly renewal with new zero-yen App charge
3. CIP + separate lesson plan in same transaction (lesson untouched)
4. Student with CIP App AND independent App subscription (App Store/B2B)
5. Plan change from existing Coaching to CIP, and CIP to another Coaching, mid-month
6. B2C/B2E/B2B contract-type change and resulting Freee dimensions
7. Suspension, cancellation, cooling-off (before and after allocation booked) — Coaching + App stopped together (RA-06)
8. Preview, final, failed validation, revision delta processing
9. Post-release correction: refund/price correction in later month (no duplicate journal, correct target month)
10. CSV aggregation, rounding/remainder handling, Freee adjustment totals

---

## 11. Open Dependencies

| ID | Dependency | Requested treatment |
|---|---|---|
| D-1 | Coaching and App list prices (JPY, tax basis, per contract type) — RA-03 remaining, CIP-RQ-02 | Estimate with placeholder prices; flag that ratio changes constants only, not design |
| D-2 | App charge mechanism (working assumption: zero-yen independent charge, CAP-style) — RA-01 remaining | Estimate on assumption; flag risk if sample data differs |
| D-3 | CIP Freee sender: generalize existing vs dedicated adapter — RA-05 | State chosen approach, repos, assumptions |
| D-4 | Production Freee mapping and dimensions for CIP App — RA-05 | Include config/data setup + accounting confirmation task |
| D-5 | Contract-type/dept/order_no on new charge at plan/contract change — RA-07 remaining | Estimate assuming charge-time attributes usable; flag risk |
| D-6 | Post-release correction process: which month, which channel — RA-10 | Assume ASCH-style revision run; confirm with Accounting |

---

## 12. Requested Estimation Format

Provide:
- Effort by workstream (CIP batch/data model, Freee/CSV integration, testing/UAT support)
- Impacted repositories and major components
- Base estimate with deltas for D-1/D-2/D-3 if resolved differently
- Assumptions, exclusions, and risks
- Whether December 2026 delivery is feasible; if not, earliest realistic date and what needs to change

---

## Reference Decisions (from Kuroda-san's RA document)

| ID | Decision | Confirmed |
|---|---|---|
| RA-01 | App created as synchronized zero-yen charge (CAP-style) | Working assumption (2026-07-27) |
| RA-02 | CIP = Coaching + App only, lessons NOT bundled | Confirmed (2026-07-27) |
| RA-03 | Reference prices (Coaching list price, App list price) | Open (D-1) |
| RA-05 | Freee sender approach | Open (D-3) |
| RA-06 | Coaching and App start/suspend/end simultaneously | Confirmed (2026-07-27) |
| RA-07 | Contract-type/dept/order_no on new charges | Open (D-5) |
| RA-09 | CIP uses `cip_*` namespace (no ASCH/CAP table reuse) | Decided |
| RA-10 | Post-release correction process | Open (D-6) |


---

## Addendum: ASC Pipeline Sufficiency Analysis (2026-07-31)

Code-trace investigation confirmed that the existing ASC daily rate calculation and Freee journal pipeline handles new Coaching products (product_type=9) without code changes. However, the CIP-specific revenue allocation (splitting N between Coaching and App) still requires:
- 1 new artisan command (`cip:calculate`)
- 3–4 `cip_*` tables (run management, allocation detail, summary)
- Eligibility query, formula, CSV generation, and Freee adjustment sender

The standard pipeline provides N (input). The allocation and adjustment are separate new logic.

**Full analysis:** `technical-notes/investigation/20260731-asc-cap-cip-code-change-analysis/REPORT-00-asc-pipeline-sufficiency-analysis.md`
