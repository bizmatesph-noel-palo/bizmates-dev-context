# ASCH — Database Table Design (Draft, dual-option for estimation)

**Source:** Kuroda-san (Confluence)  
**Status:** PROVISIONAL — draft for review & estimation  
**Date received:** 2026-07-16  
**Key decision pending:** H-9 (run_id model vs _pre/final model) — dev team asked to estimate BOTH

---

## 1. Purpose and Scope

ASCH computes prorated revenue recognition for Honki Set (Lesson + Coaching + App bundle) and sends the difference against existing ASC output to Freee as adjustment journals.

**Core approach (fixed, both options):**
- Existing ASC batch is NOT modified. Its output tables are read-only inputs.
- ASCH runs after ASC, computes P, reads N from ASC log tables, books adjustment = P − N (T1 revenue journals only; no T2/T3).
- Target: B2C and B2E only. B2B, partner-company, non-Japan excluded.
- First production run: 2026-10-01.
- Cadence: preview on 1st, final + Freee on 3rd.

---

## 2. Design Principles (Common to Both Options)

| Item | Decision |
|---|---|
| Database | Bizmates side only (`bizmates_mysql` connection) |
| DDL source | Laravel migrations in `ls-database-migrations` |
| Naming | `asch_` prefix (outside mst_/trn_/log_ convention) |
| Foreign keys | Physical FKs between ASCH tables; logical FKs to existing tables |
| Charset/engine | utf8mb4 / utf8mb4_unicode_ci, InnoDB |
| Money types | M and L: `int` (yen). N/P/adjustment: `decimal(12,2)`. O: `decimal(14,4)` |
| Audit | One Excel row = one `asch_monthly_prorations` row. Full traceability. |

---

## 3. Option A — run_id Generation Model (9 tables)

One `asch_calculation_runs` row per batch execution; every result row carries `run_id`. Finalize/supersede in single transaction; retroactive recalculations preserved as generations.

**Tables:**

| # | Table | Role |
|---|---|---|
| 1 | `asch_calculation_runs` | One row per execution (preview/final/revision). Generation management. |
| 2 | `asch_source_documents` | Snapshot of input rows at run start (incl. CDB eligibility). Source of truth for past runs. |
| 3 | `asch_bundle_enrollments` | One row per Honki Set participation. ASCH↔CDB mapping. |
| 4 | `asch_enrollment_contract_periods` | Contract-type validity periods per enrollment (B2E→B2B Pattern 7). |
| 5 | `asch_bundle_components` | Product components (lesson/coaching/app) with plan variant, list price, CDB references. |
| 6 | `asch_proration_groups` | One row per proration group. Stores paid_total and ΣO=ΣM verification. |
| 7 | `asch_monthly_prorations` | **Core ledger.** All Excel columns (E–P) + N, P, adjustment, basis, inheritance/refund linkage. |
| 8 | `asch_sum_calculation` | Aggregation at log_sum_calculation granularity. Holds ΣM/ΣN/ΣP and integer-yen adjustment. |
| 9 | `asch_sum_calculation_history` | Which proration rows → which summary row (audit trace). |

**"Currently valid final data"** = `is_finalized=1 AND superseded_by_run_id IS NULL AND status=1`

**Retroactive recalculation:** Revision run (run_type=2) → on finalize, old run gets `superseded_by_run_id` set. All generations remain queryable. Delta vs previous run sent to Freee as additional adjustment.

---

## 4. Option B — Existing _pre/final Model (12–13 tables)

Preview batch rewrites `_pre` tables (DELETE→INSERT per target_ym). Final batch writes final tables + submits to Freee. No run-generation concept.

**Mapping from Option A:**

| Option A | Option B | Notes |
|---|---|---|
| `asch_calculation_runs` | **dropped** | Idempotency = DELETE→INSERT by target_ym |
| `asch_source_documents` | single (unchanged) | Immutable append-only; `run_id` → fetch timestamp + target_ym |
| `asch_bundle_enrollments` | single (unchanged) | Persistent mapping, not a calculation result |
| `asch_enrollment_contract_periods` | single, rebuilt per batch | DELETE→INSERT |
| `asch_bundle_components` | single, rebuilt per batch | DELETE→INSERT |
| `asch_proration_groups` | `_pre` + final pair | |
| `asch_monthly_prorations` | `_pre` + final pair | |
| `asch_sum_calculation` | `_pre` + final pair | |
| `asch_sum_calculation_history` | `_pre` + final pair | |

**Key differences vs Option A:**

| Item | Option B handling |
|---|---|
| `run_id` column | Removed from all tables. Uniqueness keys drop run_id. |
| `calc_version` | Moves onto each result row (was on run row in A) |
| Validation gate | No run-level status; enforced by batch process control + `is_balanced` flag |
| Retroactive recalc | DELETE→INSERT of target_ym in final tables. Pre-correction values not retained in DB. |
| Prior-month O inheritance | Points at prior month's final-table row (simpler). Retroactive re-run must cascade forward. |
| N source for preview | Auto-resolved: preview reads `log_*_pre`, final reads `log_*` |

---

## 5. Common Data Flow (Both Options)

**Inputs (read-only, existing):**
- `trn_charge` / `trn_student_product` / `mst_product` — contracts & payments
- `mst_new_price_listing` — App list price (¥3,980 tax-incl)
- `log_daily_rate_calculation(_pre)` — N for daily/coaching
- `log_monthly_rate_calculation(_pre)` — N for monthly-ticket plans
- `trn_prorated_application` / `trn_prorated_refund` — Pattern 7/8 events
- `log_first_month_enrollment_discount_apply` / `log_loyal_benefits_charge` — basis decision
- `trn/log/mst_campaign_discount_eligibility` (CDB) — eligibility source

**ASCH batch flow:**
```
snapshot sources → build enrollments/periods/components
→ proration (O → P, reconcile N) → validate (ΣO=ΣM, ΣP=O)
→ aggregate into asch_sum_calculation (+history)
[Option A: wrapped in run lifecycle]
[Option B: preview writes _pre, final writes final]
```

**Outputs:**
- `AschComponentDetail_{YYYYMM}.csv` — per-proration-row detail
- `AschCalculationSummary_{YYYYMM}.csv` — same layout as existing CalculationSummary + N/P/adjustment
- Freee API — adjustment journals (ΣP − ΣN, integer yen), final only

---

## 6. Estimation Request (What Dev Team Must Provide)

Separate estimates for Option A and Option B:

1. **Migrations** — table creation (9 vs 12–13), FK migrations, structure-test regeneration
2. **Batch implementation** — Option A: run lifecycle (create/finalize/supersede), "active run" view, revision flow. Option B: preview/final two-path, DELETE→INSERT idempotency
3. **Retroactive recalculation** — Option A: revision run + delta journal. Option B: DELETE→INSERT + forward cascade + evidence retention
4. **CSV + Freee submission** — identical in both (AschSendJournalsLogic, T1 only); confirm no difference
5. **Testing** — unit + pattern walkthroughs (1–9) + structure tests
6. **Risks/concerns** — e.g., would Option B inherit the 1400-line Pre/Final clone issue?

**Decision inputs:** H-19 (whether April 2026 cohort must be prorated) + the two estimates.

---

## 7. Amount-Consistency Invariants (Both Options)

| Invariant | Rule |
|---|---|
| Per proration group | ΣO = ΣM (exact distribution of customer's total payment) |
| Per charge lifetime | ΣP = O (lifetime recognized revenue = allocated base) |
| Monthly ΣP = ΣM | ❌ NOT an invariant (mid-month starts are day-prorated) |

**Rounding:** Floor per row. Monthly remainder absorbed by row with largest O. Forced match to O in charge's final month.

---

## 8. Open Items Affecting Schema

| # | Item | State |
|---|---|---|
| H-4 | Freee item/section mapping for App (code=100) | Partially resolved; re-investigation requested |
| H-7 | Cross-month refund booking details | Principle fixed; edge details with accounting |
| H-8 | N source for preview runs | Open in Option A; auto-resolved in Option B |
| H-9 | run_id vs _pre execution model | **Open — subject of this estimation** |
| H-11 | Retroactive proration for 2026-01 | Out of scope (agreed) |
| H-19 | 2026-04 cohort handling | Open (accounting confirmation in progress) |
| H-12/13 | CDB = persistent registry / ASCH = snapshot | Direction agreed, final pending |
| H-14 | Zero-yen App rows in existing ASC | Confirmed on dev04 (N=0 rows exist) |
| H-15 | MySQL version (JSON/CHECK support) | Open (minor) |
| H-16 | App price tax-exclusive conversion | Open; using ¥3,980 tax-incl until resolved |
| H-17 | CDB integration prerequisites | Open; fallback = self-detection |

**Columns flagged for removal (2026-07-16 review):**
- `source_system` and `payload_hash` on `asch_source_documents`
- `app_free_end_date` (derivable from 6th-month App charge end date)
- `status`/`status_reason` on enrollments (if equivalent to CDB `discount_flag`)

---

## 9. Key Implications for ASCH Project

### What's NEW in this document (vs REF-ASCH-02):

1. **Money types formalized:** M/L = int, N/P/adjustment = decimal(12,2), O = decimal(14,4)
2. **Option B fully specified** — now a concrete alternative, not just "the existing pattern"
3. **H-14 CONFIRMED:** Zero-yen App rows DO exist in ASC output on dev04 (product_type=100, N=0)
4. **H-19 NEW:** April 2026 cohort is a separate decision (Jan = out of scope, Apr = pending)
5. **No T2/T3 in ASCH** — confirmed: only T1 revenue journals. No advance payment or wash logic.
6. **Physical FKs between ASCH tables** — differs from existing convention (existing tables have no FKs)
7. **Column removals proposed** — simplification pending final confirmation

### Impact on Previous Research:

| Previous Assumption | Updated Reality |
|---|---|
| ASCH might need T2/T3 journal logic | **No** — T1 only. Simpler than `SendJournalsDataLogic`. |
| O stored as int | **No** — O is `decimal(14,4)` for precision. N/P/adjustment are `decimal(12,2)`. |
| Option B = "just like existing ASCM" | **Partially** — enrollment layer uses DELETE→INSERT (not paired), only result tables are paired. 12–13 tables, not 18. |
| App price stored in ASCH table | **No** — read from `mst_new_price_listing`. No ASCH master table. |
| Retroactive recalc in Option B = impossible | **Possible** but with forward-cascade requirement and no DB-level evidence retention. |
