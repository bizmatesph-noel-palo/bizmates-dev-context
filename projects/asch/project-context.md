# asch — Project Context

> Load this at the start of each ASCH session.
> Also load `projects/ascm/project-context.md` for base ASC system context.
> If context gets compacted, re-read both files before continuing.

---

## What ASCH Is

**ASCH (ASC Honki Set)** adds a revenue proration batch to the existing ASC accounting system. It calculates how to allocate bundled payments across 3 products (Lesson, Coaching, App) for students enrolled in the Honki Set campaign, then sends adjustment journal entries to Freee representing the difference between the prorated amount and what ASC already booked.

**Key principle:** ASCH does NOT modify existing ASC. It reads ASC output (N), calculates the correct prorated amount (P), and sends the difference (P − N) as an adjustment. Existing ASC journals are never touched.

**Scope:** Bizmates-only (`mysql` connection). Coaching and App do not exist on Zipan.

---

## Workspace Overview

| Directory | What it is |
|-----------|-----------|
| `accounting_related_system_for_freee` | **Main codebase.** ASCH extends this with new artisan commands. |
| `MBTI_backend` | **Source of Honki Set data.** Campaign config, eligibility logic, charges originate here. |
| `ls-database-migrations` | **Schema source of truth.** New ASCH table migrations go here. |
| `bizmates.jp` | **Admin portal.** Upstream charge writer — read reference only. |
| `bizmates-dev-context/projects/asch` | **This directory.** ASCH artifacts. |
| `bizmates-dev-context/projects/ascm` | **Parent project.** Base ASC system context. |
| `bizmates-dev-context/domain-knowledge` | **General Bizmates knowledge.** Campaigns, account types. |

---

## Honki Set Campaign

Honki Set (本気セット) is a **marketing campaign** (not a product or plan) where students purchase a discounted bundle of:
- Online Lessons (Daily 1, Daily 2, or Monthly 15)
- Bizmates Coaching (30-minute plan only)
- Bizmates App (free companion — ¥0 to student, but must carry allocated revenue)

**Campaign period (current round):** 2026/7/1 – 2026/7/26 (application window). Repeats quarterly.
**Benefit period:** 6 months from application date.
**Scope:** Bizmates only. B2B excluded. Non-Japan excluded.

### Benefits
| # | Benefit | Condition |
|---|---------|-----------|
| 1 | Month 1: Coaching 50% off | Automatic. Lesson 50% off only for new Lesson contracts (First Month campaign — external). |
| 2 | App free for 6 months | Lost from following month if Coaching cancelled. |
| 3 | Month 6: 50% off | Lost permanently if student cancels mid-way. |

---

## Architecture: How ASCH Fits

```
ASC (existing, unchanged)
  log_daily_rate_calculation   → N (daily plans)
  log_monthly_rate_calculation → N (monthly plans)
        ↓ read-only
ASCH (new)
  1. Identify Honki Set enrollments
  2. Build proration groups (ΣM per enrollment)
  3. Allocate: O = ΣM × (basis / Σbasis)
  4. Prorate:  P = O × (J / I)
  5. Adjustment: P − N → Freee journals
        ↓
  asch_monthly_prorations (core table)
  AschComponentDetail CSV
  AschCalculationSummary CSV
  Freee adjustment journals
```

**Final accounting value:** `ASC value (N) + ASCH adjustment (P − N) = P`

---

## Proration Formula

```
Step 1 — Determine basis per product:
  basis = M (paid amount)  → product has NON-Honki discount (First Month, Loyal, B2E)
  basis = L (list price)   → product has Honki Set discount, or no discount

Step 2 — Allocate:
  O(product) = ΣM × ( basis(product) / Σbasis(all products) )

Step 3 — Prorate:
  P = O × (J / I)
  Where I = contract days (or total tickets), J = days in month (or tickets consumed)
```

**Key behaviors:**
- O carries over — not recalculated in subsequent months once set
- ΣO = ΣM must always hold (validation invariant)
- ΣP = O over charge lifetime must always hold
- Monthly ΣP ≠ ΣM — expected for mid-month starts, do NOT validate

---

## 9 Calculation Patterns

| # | Pattern | Key Complexity |
|---|---------|---------------|
| 1 | Simultaneous start, month-start | Baseline — simplest |
| 2 | Different start dates | Period boundary mismatch — J/I differs per product |
| 3 | Start before campaign | Month-6 discount dates differ per product |
| 4 | Plan change Daily1 → Daily2 | New revision; discount applies to active plan at month-6 |
| 5 | Coaching rest | App removed from following month; month-6 lost |
| 6 | Plan change Daily1 → Monthly15 | I/J switches from days to ticket counts |
| 7 | B2E → B2B switch with refund | Contract period history; App possibly excluded after switch |
| 8 | Cooling-off refund / B2E + Loyal | Negative M values; basis uses M (non-Honki discount) |
| 9 | Additional combination cases | TBD |

---

## New Database Tables (9)

| # | Table | Role |
|---|-------|------|
| 1 | `asch_calculation_runs` | Run management (preview/final/revision) |
| 2 | `asch_source_documents` | Input data snapshot for audit (JSON, deduped by hash) |
| 3 | `asch_bundle_enrollments` | Honki Set member registry |
| 4 | `asch_enrollment_contract_periods` | Contract type history per enrollment |
| 5 | `asch_bundle_components` | Products per enrollment (revisions for plan changes) |
| 6 | `asch_proration_groups` | Grouping unit for ΣO = ΣM validation |
| 7 | `asch_monthly_prorations` | **Core result table** (one row = one Excel sheet row) |
| 8 | `asch_sum_calculation` | Freee aggregation (adjustment amounts) |
| 9 | `asch_sum_calculation_history` | Trace: proration → summary linkage |

**Removed:** `asch_app_price_master` — App list price ¥3,980 (tax-incl) now read from `mst_new_price_listing`.

**App product:** `mst_product` `product_id = 10012`, `product_type = 100`. 0-yen App charges exist in `trn_charge`.

---

## Outputs

| Output | Content |
|--------|---------|
| `AschComponentDetail_{YYYYMM}.csv` | One row per proration row — detail level |
| `AschCalculationSummary_{YYYYMM}.csv` | Freee-submission granularity with N, P, adjustment |
| Freee adjustment journals | `ΣP − ΣN` — reuses T1/T2/T3 logic from `SendJournalsDataLogic` |

**Batch schedule:** Same as ASC — 1st of month (preview), 3rd of month (final + Freee submission).

---

## Key Open Items

| # | Item | Owner |
|---|------|-------|
| 1 | Run management model — `run_id` vs `_pre`/final two-table | Dev |
| 2 | N source for preview runs (log_*_pre vs confirmed; default: preview→_pre, final→confirmed) | Dev |
| 3 | Verify 0-yen App charges in existing ASC output (N=0 rows for product_id=10012; Freee behavior for 0-yen journals) | Dev |
| 4 | MySQL version of target DB (json type / utf8mb4 assumptions) | Dev |
| 5 | Tax handling of App list price (¥3,980 tax-incl → ¥3,618.18 tax-excl; rounding must match existing ASC) | Dev / Accounting |
| 6 | Retroactive correction for Jan/Apr 2026 — in scope? (default: out of scope) | Accounting |
| 7 | CDB prerequisites: production rollout + July backfill before 10/1; change-log guarantees; App-row flag; month-6 trigger date alignment | CDB team (Wu-san) |

---

## Research Documents

All pre-design research is in `technical-notes/research/ASCH/`. Key files:

| File | What it is |
|------|-----------|
| `RESEARCH-02-specification-analysis.md` | Full spec analysis — most current synthesis |
| `RESEARCH-03-Integration-Points-Analysis.md` | Code-level integration points, Pre/Final analysis, ASCM improvements |
| `RESEARCH-04-CSV-Zip-Email-Integration.md` | CSV/zip/email pipeline research — validated integration approach |
| `REF-ASCH-00-PRJ-Specification.md` | Kuroda-san's full specification (original) |
| `REF-ASCH-02-Requirements-Update-20260716.md` | **Requirements update — supersedes parts of original spec** |
| `REF-ASCH-03-DB-Table-Design-Draft.md` | **DB design dual-option (run_id vs _pre/final) for estimation** |
| `REF-CAP-00-Coaching-App-Plan-Overview.md` | CAP project reference — parallel project impact assessment |
| `REF-ASCH-00-PRJ-Brief-Kuroda.md` | Kuroda-san's project brief |
| `REF-ASCH-00-PATTERNS-Case1-Data.md` | Pattern 1 formula with Excel derivation |
| `RESEARCH-01-Initial-Research-Analysis.md` | Initial research (pre-spec) |
| `RESEARCH-01-REF-Kuroda-Response.md` | Kuroda-san's answers to RESEARCH-01 |
| `REF-ASCH-01-MOM-20260702-Honkiset-Discussion.md` | Kickoff meeting minutes |
| `REF-HCR-00-Customer-Retention-Overview.md` | HCR project overview (existing MBTI feature ASCH depends on) |
| `REF-HCR-01-Campaign-Implementation.md` | Honki Set campaign implementation design |
| `REF-HCR-02-mst-honki-set-Design.md` | `mst_honki_set` table schema and service pattern |
| `REF-HCR-03-Eligibility-Checker.md` | Eligibility checker flow |

---

## Cross-References

| Shorthand | Repository |
|---|---|
| `[ASC]` | `accounting_related_system_for_freee` |
| `[MBTI]` | `MBTI_backend` |
| `[Admin]` | `bizmates.jp` |
| `[Migrations]` | `ls-database-migrations` |
| `[asch]` | `bizmates-dev-context/projects/asch` |
| `[ascm]` | `bizmates-dev-context/projects/ascm` |

---

## Schedule

**First production run: 2026/10/1** (hard deadline — quarterly closing for Jul–Sep fiscal quarter).  
Regular cadence: preview on 1st, final + Freee on 3rd (same as ASC).  
Parallel projects: CAP and CDB running concurrently — need status sync.

---

## Status

| Item | Status |
|------|--------|
| Research | ✅ Complete |
| Requirements update (Kuroda-san 2026-07-16) | ✅ Received — major decisions made |
| Design | 🔲 Not started — pending remaining open items |
| Implementation | 🔲 Not started |
| JIRA project | 🔲 TBA — project code ASCH not yet created |
