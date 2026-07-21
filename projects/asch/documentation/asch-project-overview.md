# ASCH — Honki Set Revenue Proration: Project Overview

## Project Summary

| | |
|---|---|
| **Project Code** | ASCH (Accounting System Changes — Honki Set) |
| **Objective** | Calculate revenue proration for Honki Set bundled payments across 3 products (Lesson, Coaching, App), then send adjustment journal entries to Freee representing the difference between the prorated amount (P) and what the existing system already booked (N). |
| **Business Impact** | Bundled campaign revenue is correctly allocated per product for accounting compliance. Each product's revenue reflects its fair share of the bundle rather than the flat amount the existing daily/monthly calculation assigns. |

## Resources

| Role | Name |
|------|------|
| Project Manager (PM) | Hayato Kuroda |
| Software Delivery Manager (SDM) | Roi Patrick Florentino |
| SCM / Lead Developer | Noel Palo |
| Developer | Throy Embudo |
| QA | Alvin Glenn G. Flamiano, Jaymiriz Liwanag |

## Repositories

| Repository | Purpose | Branch Strategy |
|------------|---------|-----------------|
| `accounting_related_system_for_freee` | Laravel batch system — ASCH commands, logic, models, CSV generation | Feature branches → `feature/ASCH/ASCH-master` → main |
| `ls-database-migrations` | Schema source of truth — ASCH table migrations (9 tables, Option A) or (12–13 tables, Option B) | Feature branches → `feature/ASCH/ASCH-master` → main |
| `MBTI_backend` | Source of Honki Set data (read-only reference) — CDB eligibility table, campaign config | N/A (read-only reference) |
| `bizmates.jp` | Admin portal — upstream charge writer (read-only reference) | N/A (read-only reference) |

## Technical Architecture

### Batch System (`accounting_related_system_for_freee`)

- **Framework:** Laravel 8 (artisan commands)
- **Pattern:** Command → Logic class (raw SQL + Eloquent hybrid)
- **Schedule:** Preview on 1st of month, Final on 3rd of month (same as existing batch)
- **Dependency:** Runs AFTER existing daily/monthly rate calculation completes (needs N-values)
- **Scope:** Bizmates only (`mysql` connection). Zipan excluded (no Coaching/App products).
- **Data Isolation:** ASCH reads existing tables but never modifies them. All output goes to `asch_*` tables.

### Core Formula

```
Step 1 — Determine basis per product:
  basis = M (paid amount)  → product has non-Honki discount (First Month, Loyal, B2E)
  basis = L (list price)   → product has Honki Set discount, or no discount

Step 2 — Allocate:
  O(product) = ΣM × ( basis(product) / Σbasis(all products) )

Step 3 — Prorate:
  P = O × (J / I)
  Where I = contract days (or total tickets), J = days in month (or tickets consumed)

Step 4 — Adjustment:
  Send (P − N) to Freee as journal entry
```

### Key Principle

ASCH does NOT modify existing calculations. It reads existing output (N), calculates the correct prorated amount (P), and sends only the difference (P − N) as an adjustment. Existing journals are never touched.

## Feature Scope

### In Scope

#### Phase 1 — Core Engine (Pattern 1 end-to-end)

| Component | Description |
|-----------|-------------|
| Schema (9 tables) | `asch_*` tables for run management, enrollments, components, prorations, summaries. App price from `mst_new_price_listing` (no dedicated master table). |
| Honki Set Eligibility | Service to identify eligible members from CDB table (`trn_campaign_discount_eligibility`) with fallback to self-detection |
| Proration Calculation (Pattern 1) | O allocation + P proration for simultaneous start at month-start |
| N-Value Reading & Adjustment | Read existing daily/monthly rate output, calculate P − N |
| Freee Journal Submission | T1 revenue journals only (no T2/T3). Aggregated adjustment journals to Freee API. |
| CSV Report Generation | `AschComponentDetail` (detail) + `AschCalculationSummary` (Freee-level). Integrated into existing zip/email pipeline via Zipan-precedent pattern. |

#### Phase 2 — Pattern Extensions

| Spec | Patterns | Shared Concern |
|------|----------|----------------|
| Spec 06 | 2 + 3 + 9 | Cross-month splitting, independent month-6 counting, discount priority |
| Spec 07 | 4 + 6 | Plan changes (component revisions, I/J type switching, O recalculation) |
| Spec 08 | 5 + 7 | Enrollment termination (coaching rest, B2E→B2B exit, negative M) |
| Spec 09 | 8 | Cooling-off (same-month charge + refund, bundle early death) |

### Out of Scope

| Item | Reason |
|------|--------|
| Modifying existing daily/monthly rate calculation | Data isolation principle — ASCH is adjustment-only |
| Zipan support | Coaching and App do not exist on Zipan |
| Admin panel changes | No UI for ASCH — batch-only system |
| New product creation | App product (product_id 10012) already exists in `mst_product` |
| Retroactive correction for Jan/Apr 2026 | Forward-looking by default (decided). Can be handled later via revision run if accounting requests it. |

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Research & Specification | ✅ Complete | Full spec + requirements update (2026-07-16) received |
| Project Scaffolding | ✅ Complete | Steering files, spec folders, engineering standards, research docs |
| Development Timeline Estimate | ✅ Complete | 9.5 weeks (either option). See `asch-development-timeline-estimate.md` |
| **Phase 1 — Core Engine** | | |
| Spec 01: Foundation (schema, commands, models) | 🔲 Blocked on H-9 | Requirements defined. Waiting for run model decision. |
| Spec 02: Honki Set Eligibility (member identification) | 🔲 Not Started | Requirements defined. CDB integration confirmed. |
| Spec 03: Pattern 1 Calculation (core O/P engine) | 🔲 Not Started | Requirements defined. All business rules decided. |
| Spec 04: Freee Journal Adjustment (N-value reading, P−N, T1 journals) | 🔲 Not Started | Requirements defined. T1-only confirmed. |
| Spec 05: CSV Report Generation (detail + summary, zip/email integration) | 🔲 Not Started | Requirements defined. Integration validated (RESEARCH-04). |
| **Phase 2 — Pattern Extensions** | | |
| Spec 06: Patterns 2+3+9 (cross-month splitting, discount priority) | 🔲 Not Started | Pattern data updated (2026-07-15) |
| Spec 07: Patterns 4+6 (plan changes, I/J switching) | 🔲 Not Started | Pattern data updated |
| Spec 08: Patterns 5+7 (enrollment termination, negative M) | 🔲 Not Started | Refund proration rule confirmed |
| Spec 09: Pattern 8 (cooling-off — split into 8-1 and 8-2) | 🔲 Not Started | Cross-month rule confirmed (2026-07-15) |
| **Deployment** | | |
| Add ASCH commands to batch schedule (after existing ASC) | 🔲 Not Started | |
| QA Testing | 🔲 Not Started | |
| DEV04 Deployment | 🔲 Not Started | |
| Production Release | 🔲 Not Started | Target: 2026/10/1 |

## Key Business Rules

| Rule | Detail |
|------|--------|
| **Honki Set definition** | Online Lesson + Bizmates Coaching 30分 + Bizmates App purchased during a campaign period |
| **Campaign period (current)** | 2026/7/1 – 2026/7/26 (application window). Repeats quarterly. |
| **Benefit period** | 6 months from application date |
| **Products in bundle** | Lesson (Daily 1–4, Monthly 15, legacy plans) + Coaching (30-min only) + App (free companion) |
| **App treatment** | ¥0 to student, but carries allocated revenue (¥3,980 tax-incl list price from `mst_new_price_listing`). 0-yen App charges exist in `trn_charge`. |
| **Exclusions** | B2B (contract_type=1), non-Japan (country_id≠86), partner-company (dept_id in {21,22,23}), any past Coaching 30-min history |
| **Proration basis rule** | Honki Set discounts → use L (list price). All other discounts → use M (paid amount). |
| **Month-6 trigger** | Coaching reaching its own month 6 (C6). Lesson discount fires on first payment after C6. |
| **Freee journals** | T1 only (revenue recognition). No T2 (advance payment) or T3 (wash). |
| **O carry-over** | Once calculated, O is not recalculated in subsequent months |
| **Validation invariant** | ΣO = ΣM must always hold within a proration group |
| **Lifetime invariant** | ΣP = O over the full charge lifetime per product |
| **Refund rule** | If original payment was prorated → refund is prorated (same ratio). If not → refund booked directly. |

## 9 Calculation Patterns

| # | Pattern | Key Complexity |
|---|---------|---------------|
| 1 | Simultaneous start, month-start | Baseline — simplest |
| 2 | Different start dates (Lesson month-start, Coaching mid-month) | Period boundary mismatch — J/I differs per product, two contracts in one month |
| 3 | Lesson started before campaign period | Month-6 discount dates differ per product, pre-campaign charges exist |
| 4 | Plan change Daily1 → Daily2 | New component revision; O recalculates for entire group; discount applies to active plan at month-6 |
| 5 | Coaching rest (cancellation within 6 months) | App removed from following month; month-6 lost permanently; bundle terminates |
| 6 | Plan change Daily1 → Monthly15 | I/J switches from days to ticket counts; P can exceed list price; P can be 0 |
| 7 | B2E → B2B switch with refund | Contract period history; negative M (prorated refund); partial bundle exit |
| 8 | Cooling-off refund (within 8 days) | Negative M values; same-month charge + refund; bundle dies in < 8 days |
| 9 | B2E with Loyal discount overlap | B2E discount (5%) + Loyal (10%) priority; discount changes shift O for entire group |

## Open Items

| # | Item | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Run management model — `run_id` (Option A, 9 tables) vs `_pre`/final (Option B, 12–13 tables) | Dev | 🔲 Pending estimate | Dev team estimating both; decision depends on this + H-19 |
| 2 | N source for preview runs (_pre vs confirmed tables) | Dev | � Open | Default: preview→_pre, final→confirmed. Auto-resolved in Option B. |
| 3 | Verify 0-yen App charges in existing ASC output | Dev | ✅ Confirmed | product_type=100, N=0 rows exist on dev04 |
| 4 | Freee mapping for App — `product_type=100` | Dev / Accounting | � Partially resolved | mst_rule_for_journals has per-contract-type rows on dev04 |
| 5 | Tax handling of App list price (¥3,980 tax-incl → tax-excl) | Dev / Accounting | 🔲 Open | Rounding must match existing ASC |
| 6 | Retroactive correction for Jan/Apr 2026 | Accounting | ✅ Decided | Jan: out of scope. Apr: separate decision (H-19) |
| 7 | CDB prerequisites (production rollout + July backfill before 10/1) | CDB team (Wu-san) | 🔲 Open | Fallback: self-detection via 3 cohort routes |
| 8 | MySQL version (json/utf8mb4 support) | Dev | 🔲 Open (minor) | |
| 9 | April 2026 cohort handling (H-19) | Accounting | 🔲 Open | Background: April proration reverted, Freee manually adjusted |

## Documentation

All spec files are maintained in the `accounting_related_system_for_freee` repository under `.kiro/specs/`:

| Spec | Path |
|------|------|
| 01: Foundation | `.kiro/specs/asch-foundation/` |
| 02: Honki Set Eligibility | `.kiro/specs/asch-honki-set-eligibility/` |
| 03: Pattern 1 Calculation | `.kiro/specs/asch-pattern1-calculation/` |
| 04: Freee Journal Adjustment | `.kiro/specs/asch-freee-journal-adjustment/` |
| 05: CSV Report Generation | `.kiro/specs/asch-csv-report-generation/` |

## Timeline & Milestones

| Milestone | Target | Status |
|-----------|--------|--------|
| Research & Specification | July 2026 | ✅ Complete |
| Requirements Update (Kuroda-san) | 2026-07-16 | ✅ Received |
| Development Timeline Estimate | 2026-07-20 | ✅ Complete |
| H-9 Decision (run model) | ASAP (blocks Week 1) | 🔲 Pending |
| **Phase 1 — Core Engine** | ~8.5 weeks from start | |
| Spec 01: Foundation | Weeks 1–2 | 🔲 Pending H-9 |
| Spec 02: Honki Set Eligibility | Week 3 | 🔲 Pending |
| Spec 03: Pattern 1 Calculation | Weeks 3–4 | 🔲 Pending |
| Spec 04: Freee Journal Adjustment | Weeks 7–8 | 🔲 Pending |
| Spec 05: CSV Report Generation | Week 7 | 🔲 Pending |
| **Phase 2 — Pattern Extensions** | Weeks 5–6 | |
| Specs 06-09: Patterns 2-9 | Weeks 5–6 | 🔲 Pending |
| **Testing & Deployment** | Weeks 9–10 | |
| Testing + Validation | Week 9 | 🔲 Pending |
| Buffer | Week 10 | |
| Production Release | 2026/10/1 | 🔲 Target |

See `asch-development-timeline-estimate.md` for full breakdown and confidence analysis.
