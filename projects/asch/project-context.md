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
- Online Lessons (Daily 1/2/3/4, Monthly 15, legacy Daily 25/50/75/100)
- Bizmates Coaching (30-minute plan only)
- Bizmates App (free companion — ¥0 to student, but must carry allocated revenue)

**Campaign period (current round):** 2026/7/1 10:00 – 2026/7/27 23:59 JST (application window). Repeats quarterly.
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
| 3 | Start before campaign | ~~Month-6 discount dates differ per product~~ → Calendar-month trigger (REF-06 §1) simplifies this |
| 4 | Plan change Daily1 → Daily2 | New revision; discount applies to new plan's price (REF-06 §2) |
| 5 | Coaching rest | App removed from following month; month-6 lost |
| 6 | Plan change Daily1 → Monthly15 | I/J switches from days to ticket counts |
| 7 | B2E → B2B switch with refund | Contract period history; future-only reversion (REF-06 §3) |
| 8-1 | Cooling-off (same month) | Payment not prorated yet → refund not prorated |
| 8-2 | Cooling-off (cross-month) | Payment already prorated → refund prorated with same ratio |
| 9 | B2E with Loyal discount | ~~Sequence-based split with P3~~ → Calendar-month trigger eliminates this split (REF-06 §1) |

**⚠️ REF-06 §1 impact:** Patterns 3 and 9 previously required separate handling for "Lesson payment before vs after Coaching C6 payment." This sequence-based split no longer applies — month-6 discount triggers for any Lesson payment in the same calendar month as Coaching C6.

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
| `AschCalculationSummary_{YYYYMM}.csv` | Freee-submission granularity with N and P columns |
| Freee adjustment journals | `ΣP − ΣN` — T1 revenue journals only (no T2/T3). Independent per project, never blocked by other projects. |

**Batch schedule:** Same as ASC — 1st of month (preview), 3rd of month (final + Freee submission).  
**Delivery:** Unified email across ASCH/CAP/CIP (requirement update 2026-08-05). ASCH delivers first; CAP and CIP add their CSVs to the same email when released. CSV generation is per-project and failure-isolated; email delivery is a separate downstream step that collects available CSVs.

### Unified Email Delivery Constraints (from Kuroda-san, 2026-08-05)

1. **Failure isolation:** An error in one project's allocation must not prevent CSV generation or email delivery of other projects.
2. **Partial delivery:** If one project fails, email still sends with available CSVs. Body states per-project status (succeeded/failed/not executed).
3. **Email body:** Per-project summary table (project, run status, records, total adjustment amount, validation result).
4. **Freee sending stays independent per project:** A failure or revision in one project must not block/alter another project's journal delivery.
5. **Design constraint for ASCH:** Separate CSV generation step from email delivery step, so CAP/CIP can plug in later without reworking ASCH's path.
6. **Existing ASC unchanged:** Unified delivery is an additional downstream step — ASC pipeline not modified.

### Freee Sending Approach (open decision)

Two options under discussion — not yet decided:
- **(a) Generalize existing sender** — make input source pluggable (risk: touches existing ASC pipeline)
- **(b) Dedicated thin sender per project** — each project sends its own journals, reusing only mapping/lookup logic (risk: some orchestration duplication)

Constraint: whichever option, sending must remain independent per project.

---

## Key Open Items

| # | Item | Owner | Status |
|---|------|-------|--------|
| 1 | Run management model — Option A (run_id) | Dev / Kuroda-san | ✅ Decided (written 2026-07-22) |
| 2 | N source for preview/final | Dev | ✅ Decided (2026-07-24): preview→_pre, final→confirmed. Persist asc_source_table + asc_source_id per row. |
| 3 | Freee mapping for App | Dev | ✅ Partially confirmed (2026-07-31): code=100, mst_rule_for_journals has 4 rows. 3 narrower sub-items remain (see REF-06 §5). |
| 4 | MySQL version (json/utf8mb4) | Dev | Open (minor) |
| 5 | Tax handling — all tax-inclusive | Dev | ✅ Resolved. |
| 6 | April 2026 cohort (H-19) | Accounting / CDB | ✅ In scope. No retro recalc. CDB backfills April campaign_id. |
| 7 | CDB table name alignment | CDB team (Wu-san) | ⚠️ "trn_campaign_price_eligibility" (tentative in Kuroda spec) vs "trn_campaign_discount_eligibility" (CDB session). Need final confirmation. |
| 8 | ASCH email subject/body | Kuroda-san | Open — must approve before go-live. Now part of unified email (REF-07). |
| 9 | H-4 sub-item: B2C department_id differs (1652034 vs 1652032) | Accounting / Kuroda-san | ⚠️ New (2026-07-31) |
| 10 | H-4 sub-item: 2026-05-20 update context for rows 102/109 | Accounting / Kuroda-san | ⚠️ New (2026-07-31) |
| 11 | H-4 sub-item: Were rows 109–111 added specifically for ASCH? | Accounting / Kuroda-san | ⚠️ New (2026-07-31) |
| 12 | Freee sending approach — option (a) vs (b) | Dev / Kuroda-san | ⚠️ Open decision (2026-08-05). See REF-ASCH-08. |
| 13 | Rounding rule | Dev | ✅ Decided: floor() per row, remainder absorbed by largest-O row (REF-03/05). |

---

## Research Documents

All research is in `technical-notes/research/` organized by project:

**ASCH (in `research/ASCH/`):**

| File | What it is |
|------|-----------|
| `REF-ASCH-07-Unified-CSV-Delivery-20260805.md` | **Unified email delivery for ASCH/CAP/CIP. Failure isolation constraints. Phasing plan.** |
| `REF-ASCH-08-Freee-Sending-Approach-Decision.md` | **Open decision: generalize existing sender (a) vs dedicated thin sender per project (b). Awaiting dev team input.** |
| `REF-ASCH-06-Requirements-Update-20260731.md` | **Month-6 timing correction (calendar-month not sequence), plan-change pricing, eligibility-loss, target_month anchor, H-4 partial confirmation. Supersedes sequence-based month-6 descriptions.** |
| `REF-ASCH-05-Requirements-Update-20260724.md` | **AUTHORITATIVE — complete consolidated spec. Start here for full picture.** |
| `REF-ASCH-03-DB-Table-Design-Draft.md` | DB design (Option A decided) |
| `REF-ASCH-00-PRJ-Specification.md` | Original specification (superseded by REF-05) |
| `REF-ASCH-00-PATTERNS-Case{1-9}-Data.md` | Pattern calculation data from Excel |
| `RESEARCH-03-Integration-Points-Analysis.md` | Code-level integration analysis |
| `RESEARCH-04-CSV-Zip-Email-Integration.md` | CSV pipeline research (partially superseded by REF-07) |

**Related projects (in `research/{PROJECT}/`):**

| Directory | What it contains |
|---|---|
| `research/CDB/` | CDB design proposal + ASCH alignment gaps |
| `research/CAP/` | CAP scope + ASC-for-CAP estimate |
| `research/CIP/` | CIP scope + ASC-for-CIP estimate |
| `research/HCR/` | HCR (Honki Customer Retention) project references |

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
| Requirements (Kuroda-san) | ✅ Authoritative spec: REF-ASCH-05 (2026-07-24) + REF-ASCH-06 (2026-07-31) + REF-ASCH-07/08 (2026-08-05) |
| Decisions | ✅ All major decisions made (Option A, unified email, T1-only, tax-inclusive, floor rounding) |
| DB Migrations Spec | ✅ Requirements signed off by Kuroda-san (ls-database-migrations) |
| Foundation Spec | ✅ Requirements signed off by Kuroda-san (accounting repo) |
| Design & Implementation | 🔲 In progress — specs being refined with Kuroda-san feedback |
| Start date | **2026-08-03** (confirmed by Kuroda-san) |
| Deadline | **2026-10-01** (first production run) |
| JIRA project | ✅ Created — project code ASCH |
