---
inclusion: auto
---

# Product Overview

The **Accounting Related System for Freee** (`accounting_related_system_for_freee`) is a Laravel-based batch processing system that handles revenue recognition for Bizmates and Zipan online English lesson services.

## Who Uses This

- **Accounting team** — reviews CSVs, approves Freee submission
- **External auditors** — reference source documents and journals
- **System operators** — schedule and monitor batch runs

## What It Produces

- Revenue recognition calculations (daily rate + monthly rate)
- CSV reports (MonthlyRateCalculation, CalculationSummary, PaypalPayment, BalanceTransition, etc.)
- Journal entries submitted to Freee (external accounting system)
- Balance transition files for financial reconciliation

## Business Constraints

- Output directly feeds the company's official accounting ledger
- Results must be auditable and reproducible
- Pre (速報) runs give the team a preview; Final (確定) runs are authoritative
- Freee journals are irreversible once submitted — errors require correction journals
- Bizmates and Zipan are separate legal entities with separate accounting

## Subsystems

### Daily Rate Calculation (Original)

Revenue recognition via daily pro-rata formula for all non-monthly-plan charges. Applies to both Bizmates and Zipan. This existed before any ASC project work.

### Monthly Rate Calculation (Added by ASCM)

Consumption-based revenue recognition for monthly lesson plans (8/12/15/16/20-lesson plans). Uses a recursive CTE pipeline to track ticket carry-over, expiry, and consumption across months. Added by the ASCM (Accounting System Changes — Monthly plans) project. Deployed June 2026.

### ASC Allocation Framework (ASCA / ASCI — implementation starting Sep 2026)

Revenue **allocation** for bundled Coaching + App plans. Splits the Coaching charge revenue between the Coaching product and the App product so Freee journals reflect the correct per-product revenue.

- **Status:** Implementation starting Sep 2026 (W2 Foundation). All major decisions confirmed.
- **Deadline:** 2026/12/17 · **First production run:** 2027/01/01
- **Scope:** Bizmates only (`mysql` connection)
- **Two projects share one framework:**
  - **ASCA (ASC for CAP)** — Coaching and App Plan bundles (plans 1016–1027). Builds the shared foundation.
  - **ASCI (ASC for CIP)** — Coaching Intensive Plan bundles (plans 1028–1032). Reuses ASCA's foundation.
- **Approach:** **Scenario D (injection) + Option 1 (Overwrite).** Allocation is injected into the existing batch — it does NOT run as a separate command and does NOT send its own journals.
- **Injection point:** `CommonUtil::createDailyRateCalculation()` — between writing N to the log table and building the sum. Also `DataCorrectionLogic::createDailyRateCalculation()` for the correction path.
- **What it does:** After the existing code writes N (coaching = full amount, app = ¥0) to `log_daily_rate_calculation`, the allocation service overwrites those rows with P values (coaching reduced, app allocated). Everything downstream (sum, Freee, CSVs, balance) inherits P automatically.
- **Formula:** `P_app = floor(N × L_app / (L_coaching + L_app))`, `P_coaching = N − P_app`
  - `N` = Σ(paid_price) across the bundle (coaching + app) — makes allocation idempotent
  - `L_app` = ¥3,980; `L_coaching` = ¥19,800 (CAP 15min) / ¥39,600 (CAP 30min) / CIP pending (O-5 reopened — plan repriced ¥88,000→¥75,900)
- **Bundle grouping:** `student_id + order_no` — handles cancel+repurchase and simultaneous plans
- **Detection:** plan_id enums (`CoachingAndAppPlanEnum` for CAP, `CoachingIntensivePlanEnum` for CIP) + App product_id 10022 (changed from 10021 on 2026-08-19). CIP coaching product_id is 10025 (changed from 10022). Both CAP and CIP split **2-way** (Coaching + App).
- **Failure isolation:** allocation is wrapped in try/catch. If it fails, the log table keeps N (today's behavior) — no revenue lost, batch continues.
- **Audit:** new `log_alloc_*` tables (batch-generated) + `mst_alloc_reference_prices` (master data) record the run lifecycle, source snapshots, and per-product allocation detail.
- **New output:** one AllocationDetail CSV added to the existing zip (not a separate email).

**What the allocation framework does NOT do:**
- Does NOT add a new artisan command (rides on existing batch commands)
- Does NOT send its own Freee journals (existing `sendFreeeJournals2()` handles the now-non-zero App row)
- Does NOT modify existing calculation logic beyond the injection points
- Does NOT touch Zipan (CAP/CIP is Bizmates-only)
