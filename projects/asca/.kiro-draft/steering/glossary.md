---
inclusion: auto
---

# Glossary

> **Scope:** Vocabulary for the **ASC Allocation Framework** (ASCA / ASCI). Where a term differs from the older ASCH design, this glossary uses the ASCA meaning — ASCH was cancelled and its two-stage proration model does NOT apply here.

## Project Codes

| Code | Full Name | What it is |
|---|---|---|
| ASC | Accounting System Changes | Umbrella JIRA project for changes to this system. "ASC" is also the JIRA code for ASCM (the original project). |
| ASCM | ASC — Monthly plans | Added monthly rate calculation (recursive CTE). Deployed June 2026. |
| ASCH | ASC — Honki Set | **Cancelled 2026-08-07.** Would have prorated Honki Set bundles 3 ways. Research/engineering standards reused; its allocation formula is NOT used. |
| **ASCA** | **ASC for CAP** | **Our project.** Allocates CAP coaching-charge revenue between Coaching and App. Builds the shared allocation framework. Bizmates-only. Deadline 2026/12/17, first prod run 2027/01/01. |
| **ASCI** | **ASC for CIP** | **Our project.** Allocates CIP coaching-charge revenue. Reuses ASCA's foundation (config/enum addition, no engine change). |
| CAP | Coaching and App Plan | **Upstream project** (MBTI_backend, Keith's team). Creates new bundled plans **1016–1027** (Coaching + App). |
| CIP | Coaching Intensive Plan | **Upstream project** (MBTI_backend, Jefferson's team). Creates Coaching Intensive product **10025** with plans **1028–1032**. |

**The upstream projects (CAP, CIP) create the charges. Our projects (ASCA, ASCI) allocate the revenue.**

## System Terms

| Term | Meaning |
|---|---|
| Pre (速報) | Preview/preliminary run — draft calculations for review. Writes `_pre` log tables. |
| Final (確定) | Confirmed run — authoritative calculations sent to Freee. |
| Daily rate | Revenue recognition pro-rated by calendar days (original system). Allocation injects here. |
| Monthly rate | Revenue recognition by lesson ticket consumption (added by ASCM). Not touched by allocation. |
| CTE | Common Table Expression — the recursive SQL pipeline for monthly rate calculation (ASCM). |
| exeDate | Execution date parameter — system processes the PREVIOUS month relative to this. |
| Injection point | Where allocation hooks into existing code: `CommonUtil::createDailyRateCalculation()` (full month) and `DataCorrectionLogic::createDailyRateCalculation()` (single charge). |
| Overwrite (Option 1) | Allocation UPDATEs the log-table `paid_price` in place (N → P). No separate journal/delta is sent — downstream reads the overwritten value. |
| Injection (Scenario D) | Allocation rides inside existing batch commands rather than running as its own command. |

## Allocation Terms (ASCA / ASCI)

The ASCA formula is **single-stage** — split N between Coaching and App by reference-price weight (no O-then-P proration chain and no adjustment delta; those were ASCH concepts and do not apply). Formula, worked examples, and idempotency proof (§4): `projects/asca/documentation/asc-allocation-framework-technical-design.md`

| Term | Meaning |
|---|---|
| N | Bundle group total = Σ(paid_price) across the bundle (coaching row + app row) for a target_ym. Using the group total (not the coaching row alone) makes allocation **idempotent** — N is invariant across re-runs. |
| L_app | App reference price (allocation weight) = ¥3,980 tax-incl. From `mst_alloc_reference_prices`. |
| L_coaching | Coaching reference price = ¥19,800 (15min) / ¥39,600 (30min) / CIP Intensive 🔴 pending (O-5, plan repriced ¥88,000→¥75,900). |
| P_app | Allocated App amount = `floor(N × L_app / (L_coaching + L_app))`. Overwrites the App log row (was ¥0). |
| P_coaching | Allocated Coaching amount = `N − P_app`. Overwrites the Coaching log row. Absorbs the rounding remainder so `P_coaching + P_app = N` always holds. |
| Bundle | One detected Coaching + App pair for a contract. Both CAP and CIP split **2-way**. |
| Bundle grouping key | `student_id + order_no` — isolates each contract (handles cancel+repurchase, simultaneous CAP+CIP, multiple billing cycles). |
| Detection anchor | App `product_id` **10022** (changed from 10021 on 2026-08-19) + plan_id enums. |
| Idempotency | Re-running produces the same result because N = ΣN is invariant and `snapshotSourceData()` skips already-snapshotted (charge_id, target_ym). |
| Run | One allocation execution (`log_alloc_calculation_runs`). Persists even on failure so it's auditable. |
| Run lifecycle | createRun (own commit) → finalizeRun / markFailed. See `coding-standards.md` → Error Handling. |
| `bundle_type` | CAP/CIP discriminator column. Int-backed enum `BundleType` (1=CAP, 2=CIP), `label()` → `'cap'`/`'cip'`. ⚠️ Name+type pending Kuroda-san (was `project_code` VARCHAR — O-9). |
| `allocate()` | Full-month allocation — all CAP/CIP bundles for a target_ym. Called from CommonUtil. |
| `allocateForCharge()` | Scoped allocation — only the bundle containing one corrected charge. Called from DataCorrectionLogic. Not a full-month rebuild. |
| Failure isolation | Allocation is wrapped in try/catch. On failure the log keeps N (today's behavior) — no revenue lost, batch continues, run marked Failed. |
| V-1 | Validation: ΣP == ΣN per bundle group (`is_balanced`). Unbalanced blocks finalize. |
| V-4 | Validation: applied reference-price rows must be effective for the target date. |
| V-5 | Validation: only one active final run per (`bundle_type`, `target_ym`). |

## Product & Plan Terms

| Term | Meaning |
|---|---|
| CAP plans | `plan_id` **1016–1027** — Coaching + App bundles. Detected via `CoachingAndAppPlanEnum`. |
| CIP plans | `plan_id` **1028–1032** — Coaching Intensive + App bundles. Detected via `CoachingIntensivePlanEnum`. |
| Coaching 15min | product_id **10005** — L = ¥19,800. |
| Coaching 30min | product_id **10015** — L = ¥39,600. |
| Coaching Intensive | product_id **10025** (changed from 10022 on 2026-08-19) — CIP coaching, L 🔴 pending (O-5). |
| App | product_id **10022** (changed from 10021 on 2026-08-19). ¥0 to the student; carries allocated revenue after overwrite. product_type = 100. |
| product_type | Coaching-side vs App (100) — used for Freee mapping and CSV. |
| B2C | Individual student (contract_type = 0). |
| B2B | Corporate-sponsored (contract_type = 1). |
| B2B2C | Individual pays, linked to company (contract_type = 2). |
| Partner | Partner channel (contract_type = 3). |
| order_no | Order number — part of the bundle grouping key. Nullable for some B2C. |

## Freee Terms

| Term | Meaning |
|---|---|
| Journal entry | Accounting record (debit + credit) submitted to the Freee API. |
| ASCA & Freee | ASCA sends **no journals of its own**. Because the App log row is overwritten from ¥0 to P_app, it passes the existing `paid_price != 0` gate in `sendFreeeJournals2()` and flows through the normal journal path automatically. |
| Account / segment mapping | Freee dimensions resolved via `mst_code_change` (product_type → freee_code) and `mst_rule_for_journals`. App (product_type 100) mappings must exist before go-live (data check, not code). |