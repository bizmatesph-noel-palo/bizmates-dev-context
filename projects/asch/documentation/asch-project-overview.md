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
| `ls-database-migrations` | Schema source of truth — all 10 ASCH table migrations | Feature branches → `feature/ASCH/ASCH-master` → main |
| `MBTI_backend` | Source of Honki Set data (read-only reference) — `mst_honki_set`, eligibility logic | N/A (read-only reference) |
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
| Schema (10 tables) | `asch_*` tables for run management, enrollments, components, prorations, summaries |
| Honki Set Eligibility | Service to identify eligible Honki Set members from `mst_honki_set` + student data |
| Proration Calculation (Pattern 1) | O allocation + P proration for simultaneous start at month-start |
| N-Value Reading & Adjustment | Read existing daily/monthly rate output, calculate P − N |
| Freee Journal Submission | Submit aggregated adjustment journals to Freee API via existing patterns |
| CSV Report Generation | `AschComponentDetail` (detail) + `AschCalculationSummary` (Freee-level) |

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
| Research & Specification | 🔄 In Progress | Full spec received from Kuroda-san |
| Project Scaffolding | 🔄 In Progress | Steering files, spec folders, branch created |
| **Phase 1 — Core Engine** | | |
| Spec 01: Foundation (schema, commands, models) | 🔲 Not Started | Requirements defined |
| Spec 02: Honki Set Eligibility (member identification) | 🔲 Not Started | Requirements defined |
| Spec 03: Pattern 1 Calculation (core O/P engine) | 🔲 Not Started | Requirements defined |
| Spec 04: Freee Journal Adjustment (N-value reading, P−N, Freee submission) | 🔲 Not Started | Requirements defined |
| Spec 05: CSV Report Generation (detail + summary reports) | 🔲 Not Started | Requirements defined |
| **Phase 2 — Pattern Extensions** | | |
| Spec 06: Patterns 2+3+9 (cross-month splitting, discount priority) | 🔲 Not Started | Requirements not yet detailed |
| Spec 07: Patterns 4+6 (plan changes, I/J switching) | 🔲 Not Started | Requirements not yet detailed |
| Spec 08: Patterns 5+7 (enrollment termination, negative M) | 🔲 Not Started | Requirements not yet detailed |
| Spec 09: Pattern 8 (cooling-off) | 🔲 Not Started | Requirements not yet detailed |
| **Deployment** | | |
| Add ASCH commands to `pre.sh` / `send.sh` cron scripts | 🔲 Not Started | After existing monthly rate command |
| QA Testing | 🔲 Not Started | |
| DEV04 Deployment | 🔲 Not Started | |
| Production Release | 🔲 Not Started | |

## Key Business Rules

| Rule | Detail |
|------|--------|
| **Honki Set definition** | Online Lesson + Bizmates Coaching 30分 + Bizmates App purchased during a campaign period |
| **Campaign period (current)** | 2026/7/1 – 2026/7/26 (application window). Repeats quarterly. |
| **Benefit period** | 6 months from application date |
| **Products in bundle** | Lesson (Daily 1, Daily 2, or Monthly 15) + Coaching (30-min only) + App (free companion) |
| **App treatment** | ¥0 to student, but carries allocated revenue via proration. Does not appear in `trn_charge`. |
| **Exclusions** | B2B students (contract_type=1), non-Japan students (country_id≠86) |
| **O carry-over** | Once calculated, O is not recalculated in subsequent months |
| **Validation invariant** | ΣO = ΣM must always hold within a proration group |
| **Lifetime invariant** | ΣP = O over the full charge lifetime per product |

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
| 1 | Run management model — `run_id` vs `_pre`/final two-table pattern | Dev | 🔲 Unresolved | Awaiting dev team opinion |
| 2 | App list price — ¥3,600 (requirement) vs ¥2,500 (`mst_product_price`) | Accounting | 🔄 Decided, awaiting confirmation | Use ¥3,600 via `asch_app_price_master` until final confirmation |
| 3 | Freee mapping for App — `product_type=100` not in `config/code.php` | Accounting | 🔲 Unresolved | Accounting needs to decide the Freee item/account mapping |
| 4 | Honki Set member identification — build on `mst_honki_set` + `HonkiSetService` waterfall? | Dev | 🔲 Unresolved | Highest-priority dev investigation |
| 5 | Confirm Honki Set charges flow through existing pipelines (precondition for adjustment approach) | Dev | 🔲 Unresolved | Must verify before implementation begins |
| 6 | Retroactive correction for Jan/Apr 2026 | Accounting | ✅ Decided | Forward-looking by default. Revision run can handle later if needed. |
| 7 | DDL location — `document/sql` vs `ls-database-migrations` | Dev | ✅ Resolved | Migrations go to `ls-database-migrations` |

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
| Research & Specification | June 2026 | 🔄 In Progress |
| Open Items Resolution | July 2026 | 🔄 In Progress |
| **Phase 1 — Core Engine** | | |
| Spec 01: Foundation | TBD | 🔲 Pending |
| Spec 02: Honki Set Eligibility | TBD | 🔲 Pending |
| Spec 03: Pattern 1 Calculation | TBD | 🔲 Pending |
| Spec 04: Freee Journal Adjustment | TBD | 🔲 Pending |
| Spec 05: CSV Report Generation | TBD | 🔲 Pending |
| **Phase 2 — Pattern Extensions** | | |
| Specs 06-09: Patterns 2-9 (4 grouped specs) | TBD | 🔲 Pending |
| **Deployment** | | |
| QA Testing | TBD | 🔲 Pending |
| DEV04 Deployment | TBD | 🔲 Pending |
| Production Release | TBD | 🔲 Pending |
