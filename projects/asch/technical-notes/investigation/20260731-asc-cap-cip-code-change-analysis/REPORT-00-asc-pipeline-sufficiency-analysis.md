# ASC Pipeline Sufficiency Analysis — CAP & CIP Code Change Assessment (20260731)

**Reported by:** Noel  
**JIRA Ticket:** TBA  
**Investigated by:** Noel (AI-assisted)  
**Date:** 2026-07-31  
**Environment:** accounting_related_system_for_freee (local dev, code analysis)  
**Scope:** Both ASC for CAP and ASC for CIP

---

## Executive Summary

**Claim under review:** Soli-san's assessment (via DevinAI) that the `accounting_related_system_for_freee` codebase needs no source-code changes for new Coaching products.

**Verdict:** The claim is **correct for the standard ASC pipeline** (daily rate calculation → sum → Freee journals). A new Coaching product with `product_type = 9` flows through the existing system without modification. However, the CAP/CIP **accounting requirement** goes beyond standard processing — it requires post-recognition revenue allocation that the existing commands cannot provide without extension.

**Key distinction:** "No code changes to process the charge" ≠ "No new code needed for the project." The existing pipeline correctly recognizes and books Coaching revenue. CAP/CIP additionally need to **split** that recognized amount between Coaching and App — a step that doesn't exist today.

---

## 1. What the Existing ASC Pipeline Does (Confirmed by Code Trace)

### Daily Rate Calculation Path

```
TrnCharge::getTrnChargeList()     ← ALL paid+active charges in period
  → Skip if BizmatesMonthlyPlanEnum::exists($product_id)   ← hardcoded product_ids 16-23, 27-29
  → Skip if product_type in NotDailyCalculationProductType  ← only [8] (Bizmates Test)
  → getContractDateInfoList()     ← prorate by calendar days per month
  → log_daily_rate_calculation    ← one row per charge per month
  → LogSumCalculation             ← aggregated by order_no + product_type + contract_type
```

### Journal Sending Path

```
LogSumCalculation (for target_ym)
  → MstCodeChange::getChangeCodeToFreeeCode(masterDataType=1, product_type)
    → product_type=9 resolves to freee_code=191155067 (bizmatesCoaching)
  → CommonUtil::getContractTypeInfo() routes to masterDataType=4 (contractTypeCoaching)
    → segment2_id resolved by contract_type + department_id
  → MstRuleForJournals::getMstRuleForJournals(segment2_id, freeeProductType)
    → returns department_id, segment1_id, segment2_id for the journal
  → T1 journal entry created
  → paid_price != 0 check → ¥0 charges SKIPPED (no journal)
```

### Monthly Rate CTE Path (NOT Relevant to CAP/CIP)

```
ProductVolume CTE: WHERE lesson_type = 2 AND product_id NOT IN (61,62,63,64)
  → Only captures ticket-based lesson products
  → Coaching (product_type=9) does NOT enter this path
  → Correctly goes through daily rate instead
```

---

## 2. Why New Coaching Products Work Without Code Changes

| Check | Result | Evidence |
|---|---|---|
| `BizmatesMonthlyPlanEnum` exclusion | ✅ Not affected — only product_ids 16–23, 27–29 are excluded | `app/Enums/BizmatesMonthlyPlanEnum.php` |
| `NotDailyCalculationProductType` | ✅ Not affected — only product_type=8 excluded | `config/const.php` line 6 |
| `MstCodeChange` mapping for product_type=9 | ✅ Already exists → freee_code=191155067 | `config/code.php` → `freeeProductType.bizmatesCoaching` |
| Contract type routing | ✅ Coaching already a first-class case | `CommonUtil::getContractTypeInfo()` line 705 |
| `MstRuleForJournals` rows | ✅ Exist for all 4 contract types (C_B2C/C_B2B/C_B2B2C/C_Partner) | Coaching segment2_id config: 261934–261937 |
| ¥0 App charges | ✅ Produce ¥0 sum rows → skipped by `paid_price != 0` check | `SendJournalsDataLogic.php` ~line 248 |
| Monthly CTE | ✅ Won't interfere — Coaching has no `lesson_type=2` | `MonthlyRateCalculationLogic.php` line 236 |

**Conclusion: Devin's analysis is technically correct.** The standard pipeline processes new product_type=9 charges identically to existing Coaching. Only `mst_product` data (in `ls-database-migrations`) needs to have the new product row.

---

## 3. What CAP/CIP Actually Need Beyond Standard Processing

The accounting requirement for CAP/CIP is NOT "process a Coaching charge through ASC." That already works. The requirement is:

> **Split the recognized Coaching amount (N) between Coaching and App according to reference-price ratios, then send the difference as an adjustment journal to Freee.**

This is a **post-recognition allocation layer** — identical in concept to what ASCH does for Honki Set bundles.

### The Formula

```
For CAP:
  P_app      = N × (App_ref / (Coaching_ref + App_ref))
  P_coaching = N − P_app
  Adjustment_app      = P_app − 0 (App currently recognized as ¥0)
  Adjustment_coaching = P_coaching − N (reduce Coaching by the App allocation)

Where:
  N = existing ASC daily-rate recognition for the Coaching charge
  App_ref = ¥3,980 (CAP confirmed flat; CIP TBD)
  Coaching_ref = applicable Coaching list price
```

### What This Requires That Doesn't Exist Today

| Capability | Exists in ASC? | Why it's needed |
|---|---|---|
| Identify CAP/CIP bundle targets | ❌ No | Must know WHICH Coaching charges need splitting. CAP: by new product_id. CIP: by plan_id. |
| Read N from existing recognition | ✅ Yes (log_daily_rate_calculation) | Already computed by standard pipeline |
| Compute allocation split | ❌ No | Formula logic doesn't exist anywhere in current code |
| Send adjustment journals to Freee | ⚠️ Partially — sender exists but reads from LogSumCalculation | Adjustments aren't stored in LogSumCalculation |
| Store allocation results for audit | ❌ No | No existing table holds "we split X into Y + Z" |
| Preview/Final separation | ⚠️ Partially — pattern exists in Pre vs Final commands | CAP/CIP need their own preview/final cycle |
| CSV output for accounting review | ❌ No | CAP/CIP need specific detail + summary CSVs |
| Revision/re-run | ❌ No | If past allocation was wrong, need to supersede |

---

## 4. Architecture Options

### Option A: No New Tables — Inline Extension of Existing Commands

**Concept:** Add CAP/CIP allocation logic inside `SendJournalsDataLogic::execute()` after daily rate sum is computed. Compute on-the-fly, append to `$detailList`, include in same journal send and same email.

| Pros | Cons |
|---|---|
| No new commands or tables | No audit trail — can't inspect/re-run past allocations |
| Minimal file changes | Couples CAP/CIP with ASC lifecycle (one failure = all fail) |
| | No independent preview/final for CAP/CIP |
| | Violates Kuroda-san's explicit requirement: "`cap_*` / `cip_*` namespace" |
| | No revision/supersession support |
| | Accounting can't review CAP/CIP allocations independently |
| | Impossible to validate ΣP = N invariant post-hoc |

**Verdict: NOT viable** for production. Accounting compliance (JSOC) requires audit trail, independent review, and correction capability.

### Option B: Separate Command + Minimal Tables (Kuroda's Spec)

**Concept:** New artisan command reads N from existing daily rate tables, computes allocation, stores in `cap_*` / `cip_*` tables, sends adjustment journals, produces CSVs + email.

| Component | What it does | Reuses from ASC |
|---|---|---|
| Command (`cap:calculate`) | Orchestrates the run | Pattern from existing commands |
| Calculation run table | Preview/final/revision tracking | ASCH structural template |
| Allocation detail table | Per-charge allocation results | New (simple: ~8 columns) |
| Summary table | Freee-level aggregation | Pattern from LogSumCalculation |
| Freee sender | T1 adjustment journals | Reuses `MstRuleForJournals` + `MstCodeChange` lookup logic |
| CSV generation | Detail + summary files | Reuses `CommonUtil::createCsvFile()` pattern |
| Email | Zip + send | Reuses `CommonUtil::sendMail()` |

**Effort:** Significantly lighter than ASCH (no proration formula, no 9 patterns, no monthly CTE, no multi-product groups). CAP/CIP is essentially:
1. Query for targets (1 query)
2. Apply ratio (1 formula, 2 values per target)
3. Store results (INSERT)
4. Send journals (reuse existing sender pattern)
5. Generate CSVs (reuse existing CSV pattern)

**Verdict: This is the correct approach.** Separate namespace, independent lifecycle, full audit trail.

### Option C: Shared "Bundle Allocation" Framework (Future Optimization)

**Concept:** Since ASCH, CAP, and CIP all follow the same meta-pattern (read N → apply formula → send P−N), build a shared allocation framework with project-specific config.

| Shared | Project-Specific |
|---|---|
| Run management (preview/final/revision) | Eligibility query |
| Source snapshot pattern | Allocation formula |
| CSV generation framework | Reference prices |
| Freee sender adapter | Table namespace |
| Email delivery | Acceptance scenarios |

**Verdict: Premature now.** Build CAP first, then extract common patterns into a framework if CIP truly mirrors it. Over-abstracting before we have two working implementations creates risk.

---

## 5. What's Actually Reusable From Existing ASC (No New Code)

These components work as-is for CAP/CIP Coaching charges:

| Component | What it provides | No changes needed |
|---|---|---|
| `TrnCharge::getTrnChargeList()` | Fetches all paid charges for the period | ✅ |
| `CommonUtil::createDailyRateCalculation()` | Prorates Coaching charge by calendar days | ✅ |
| `BizmatesMonthlyPlanEnum` filter | Correctly passes Coaching through to daily rate | ✅ |
| `NotDailyCalculationProductType` filter | Doesn't exclude product_type=9 | ✅ |
| `MstCodeChange` (masterDataType=1, code=9) | Maps to freee_code=191155067 | ✅ (data exists) |
| `CommonUtil::getContractTypeInfo()` | Routes Coaching to masterDataType=4 | ✅ |
| `MstRuleForJournals` (Coaching) | Provides department_id, segment1_id, segment2_id | ✅ (rows exist) |
| `MstRuleForJournals` (App, product_type=236270504) | Provides App accounting dimensions | ✅ (4 rows confirmed in REF-ASCH-06) |
| ¥0 charge handling | Skipped in journal send (no spurious entries) | ✅ |
| `CommonUtil::sendMail()` | Email delivery pattern | ✅ (reusable) |
| `CommonUtil::createCsvFile()` | CSV generation pattern | ✅ (reusable) |
| Freee API integration (`CommonApiUtil`) | OAuth + journal send | ✅ (reusable) |

---

## 6. What Must Be Built New

### For CAP (Minimum Viable)

| Item | Scope | Notes |
|---|---|---|
| `cap:calculate` command | 1 artisan command | Orchestrates eligibility → allocation → storage → CSV → journals → email |
| `cap_calculation_runs` table | Run management | preview/final/revision status |
| `cap_allocation_details` table | Core results | charge_id, N, P_coaching, P_app, adjustment, source_table, source_id |
| `cap_sum_calculation` table | Freee aggregation | Same grain as LogSumCalculation |
| Eligibility query | 1 query | Find Coaching charges with linked CAP-product_id App charge |
| Allocation formula | ~5 lines | `P_app = floor(N × 3980 / (coaching_ref + 3980))` |
| CSV generation | 2 files | Detail + Summary (reuse patterns) |
| Freee adjustment send | Reuse pattern | T1 only, App + Coaching adjustment entries |

### For CIP (Same Pattern)

| Item | Scope | Notes |
|---|---|---|
| `cip:calculate` command | 1 artisan command | Near-identical to CAP command |
| `cip_calculation_runs` table | Run management | Same structure as CAP |
| `cip_allocation_details` table | Core results | Same structure as CAP |
| `cip_sum_calculation` table | Freee aggregation | Same structure as CAP |
| Eligibility query | 1 query | Find CIP-plan Coaching charges (plan_id discriminator) |
| Allocation formula | ~5 lines | Same structure, different reference prices |

---

## 7. Effort Comparison

| Project | Tables | Commands | Formula Complexity | Patterns | Estimated Effort |
|---|---|---|---|---|---|
| **ASCH** | 9 | 1 (+ CSV sub-command) | High (3-step allocation, 9 patterns, monthly CTE) | 9 + edge cases | ~8 weeks |
| **ASC for CAP** | 3–4 | 1 | Low (single ratio, 1 formula) | ~4 (purchase, refund, plan-change, contract-change) | ~2–3 weeks |
| **ASC for CIP** | 3–4 | 1 | Low (identical to CAP) | ~4 (same as CAP) | ~1.5–2 weeks (if built after CAP — pattern is proven) |

---

## 8. Conclusion and Recommendation

### For Patrick-san and Kuroda-san

1. **Soli-san / DevinAI's claim is correct** about the existing ASC pipeline — no code changes are needed for the standard daily rate → sum → journal flow to process new Coaching products.

2. **However, "no ASC code change" does NOT mean "no new code needed for the project."** The accounting requirement (revenue allocation between Coaching and App) is a separate concern that requires:
   - New artisan command(s)
   - New `cap_*` / `cip_*` tables (3–4 each, much lighter than ASCH's 9)
   - Eligibility detection + allocation formula
   - CSV output + Freee adjustment journals

3. **The good news:** CAP/CIP allocation is dramatically simpler than ASCH:
   - Single ratio formula (not multi-product proration groups)
   - No monthly CTE interaction (daily rate only)
   - No complex patterns (no plan-change group recalculation, no multi-product basis determination)
   - Estimated at 2–3 weeks each (vs 8+ weeks for ASCH)

4. **Reusable infrastructure:** ~70% of the work is structural scaffolding (run management, CSV, Freee sender, email) that's identical across CAP/CIP/ASCH. Building CAP first creates a proven template for CIP.

5. **What requires NO code or tables at all:**
   - Daily rate calculation for new Coaching products → existing pipeline handles it
   - ¥0 App charges → existing pipeline handles it (skipped in journals)
   - Product_type → Freee code mapping → existing `mst_code_change` handles it
   - Accounting dimensions → existing `mst_rule_for_journals` handles it

### Decision Points

| Question | Recommendation |
|---|---|
| Do we need new commands? | **Yes** — 1 command per project (CAP and CIP) |
| Do we need new tables? | **Yes** — 3–4 tables per project (audit/compliance requirement) |
| Can we skip tables and compute on-the-fly? | **No** — JSOC compliance requires audit trail, preview/review/final workflow, and revision capability |
| Can CAP and CIP share tables? | **No** — Kuroda-san explicitly decided separate namespaces (REF-CAP-01 §2, REF-CIP-00 §3) |
| Should we build a shared framework? | **Not yet** — build CAP first, extract patterns for CIP after |

---

## Cross-References

| Document | Relevance |
|---|---|
| `research/CAP/REF-CAP-01-ASC-Scope-20260724.md` | Full CAP accounting scope |
| `research/CAP/REF-CAP-02-Open-Items-Update-20260728.md` | CAP eligibility decision (new product_id) |
| `research/CAP/REF-CAP-03-Proration-Target-Detection-20260730.md` | ¥0 detection discussion + FVP evidence |
| `research/CIP/REF-CIP-00-ASC-Scope-20260727.md` | Full CIP accounting scope |
| `research/ASCH/REF-ASCH-06-Requirements-Update-20260731.md` | H-4 confirmation (mst_rule_for_journals for App) |
| ASC code: `app/Libs/SendJournalsDataLogic.php` | Journal creation flow |
| ASC code: `app/Libs/CommonUtil.php` | Daily rate calculation + Freee mapping |
| ASC code: `config/code.php` | Product type → Freee code mapping |
| ASC code: `config/const.php` | NotDailyCalculationProductType = [8] |
