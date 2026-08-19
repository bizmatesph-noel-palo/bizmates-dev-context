# ASCH Requirement Updates — 2026-07-22

**Source:** Kuroda-san (Confluence: "Requirement Updates as of 260722")  
**Status:** Supersedes REF-ASCH-02 on the 3 newly decided items below. All other content (table design, invariants, remaining open items) unchanged from v1.5.

---

## 3 New Decisions (2026-07-22)

### (1) Execution-Management Model: OPTION A (run_id) — DECIDED ✅

Option A adopted. Option B dropped from implementation scope.
Reason: post-implementation maintainability, and estimated effort difference is negligible.

### (2) CSV Delivery: SEPARATE ASCH-ONLY BATCH — DECIDED ✅

**ASCH CSVs are NOT merged into the existing ASC batch.**

Key changes:
- ASCH CSV output produced by a **new, dedicated command** (not hooked into `SendJournalsDataLogic`)
- Accounting notification email is a **separate, third email** (not folded into existing 速報版 or 確定版 emails)
- Subject line and body content TBD (Kuroda-san to confirm)

**Reason:** Merging into existing batch risks regressions and increases implementation effort.

**Impact on RESEARCH-04:** The Zipan-precedent approach (hooking into `createSendMailAttacheFile()`) is NO LONGER the plan. ASCH runs independently.

### (3) Proration Rounding Remainder: ACCEPT AS-IS — DECIDED ✅

The small mismatch between floor-rounded proration and actual paid amount is accepted. Existing ASC doesn't reconcile this either. No additional handling beyond the existing invariant checks (ΣO=ΣM, ΣP=O).

---

## Additional Details from CSV Samples (Sections 1–6)

### Layout Changes (2026-07-17, reviewed by Accounting)

- **`paid_at` column added** to detail CSV (after charge_id). Will be added to `asch_monthly_prorations` table in v1.6 DDL.
- **Adjustment column (P−N) REMOVED from CSVs.** Derivable as P minus N. The DB column `adjustment_amount` and Freee journal amount (ΣP−ΣN) are unchanged — only CSV output drops it.
- **Refund rows:** identified by negative M/N/P sign (no `record_kind` column needed in CSV).
- **Standalone rows:** identified by contract start date in prior month + N=P.

### Tax-Inclusive Amounts (Confirmed)

All amounts are tax-included (confirmed against production data 2026-07-17):
- List prices: Lesson Daily 1 = **¥14,850**, Coaching 30min = **¥39,600**, App = **¥3,980**
- Half-price: Lesson = ¥7,425, Coaching = ¥19,800

> ⚠️ **Price update:** Previous docs had Lesson = ¥13,500, Coaching = ¥36,000. Those were tax-EXCLUSIVE. Confirmed values are tax-INCLUSIVE. The difference is the 10% consumption tax.

### Proration Rounding Detail

- O = (Σpaid in group) × numerator ÷ denominator, **truncated to 4 decimal places**
- P = **floor(O)** per row
- Monthly remainder absorbed by row with **largest O**
- Which row absorbs residual to be finalized against ASC `CommonUtil` implementation (H-2)

### Campaign Application Window

Official July window: **2026-07-01 (Wed) 10:00 — 2026-07-27 (Mon) 23:59 JST**

`mst_first_month_enrollment_discount_schedule` id=334 starts at 00:00 (10 hours wider). Extraction must apply `paid_at >= 2026-07-01 10:00:00` boundary separately.

### Summary CSV Codes

- product_type: 1=Lesson, 9=Coaching, 100=App
- contract_type: 0=B2C, 2=B2B2C(B2E) only (no B2B in Honki Set)
- B2C partner: 38998715 "Unknown(B2C)"
- B2E partner: "Unknown(B2B2C)"
- order_no / department: always empty (B2B-only fields)

---

## Impact on Previous ASCH Docs

| Item | Change Needed |
|---|---|
| RESEARCH-04 (CSV/Zip/Email Integration) | **SUPERSEDED** — ASCH no longer hooks into existing pipeline. Separate command + separate email. |
| csv-generation.md steering file | Must reflect separate command, not Zipan-precedent |
| batch-execution-flow.md | ASCH batch is independent command, separate email |
| engineering-standards.md (§2.9) | Facade/Zipan-precedent section no longer applies |
| Timeline estimate | Phase 6 (CSV) is simpler — no integration hook needed. May slightly reduce effort. |
| List prices | ¥13,500/¥36,000 → ¥14,850/¥39,600 (tax-inclusive). Pattern case files need updating. |
| `asch_monthly_prorations` table | New column: `paid_at` |
