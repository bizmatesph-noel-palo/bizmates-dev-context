# ASCH — JIRA Epic Definitions

Each epic follows the 7-story structure: Requirements → Architecture → Coding → Code Review → Dev/Manual Testing → Automated Testing → Deployment.

---

## Phase 1 — Core Engine

---

### Epic: Spec 01 — Foundation

**Summary:** ASCH Foundation (Schema, Commands, Models)

**Description:**

Establish the ASCH subsystem infrastructure within `accounting_related_system_for_freee` and `ls-database-migrations`.

**Scope:**
- 10 new `asch_*` database table migrations (using `bizmates_mysql` connection)
- Eloquent models with relationships in `app/Models/Asch/`
- Artisan command skeletons (preview + final) with shared logic class
- Calculation run management (preview/final/revision tracking via `run_id`)
- Source data audit trail (JSON snapshots, deduped by hash)
- Data isolation guarantees (read-only access to existing tables)
- Re-run/idempotency behavior (preview overwrites, final creates revision)

**Dependencies:** None — this is the first spec.

**Acceptance:** All 10 tables exist, models are functional, commands are callable and produce run records.

---

### Epic: Spec 02 — Honki Set Eligibility

**Summary:** Honki Set Member Identification Service

**Description:**

Build the service that determines which students are eligible for Honki Set proration each batch run and persists enrollment records.

**Scope:**
- Query `mst_honki_set` + student product data to identify eligible members
- Persist results to `asch_bundle_enrollments`
- Track bundle components (Lesson, Coaching, App) with revision history
- Track contract type history (B2E → B2B transitions)
- Exclusion rules: B2B (contract_type=1), non-Japan (country_id≠86)
- Eligibility rules: new Coaching 30-min subscriber + active Lesson (Daily 1/2/Monthly 15)
- Handle: cancellation resets, Coaching 15-min upgrades, REST student simultaneous start

**Dependencies:** Spec 01 (tables and models must exist)

**Acceptance:** Given a target month, the service correctly identifies all eligible students and populates enrollment/component/contract-period tables.

---

### Epic: Spec 03 — Pattern 1 Calculation

**Summary:** Core Proration Engine (O Allocation + P Proration)

**Description:**

Implement the core proration calculation for Pattern 1 (simultaneous start at month-start). This builds the engine that all subsequent patterns extend.

**Scope:**
- Proration group construction (ΣM per enrollment per month)
- Allocation basis determination (M for non-Honki discount, L for Honki Set/no discount)
- Discount detection from source tables (`log_first_month_enrollment_discount_apply`, loyal benefits)
- O calculation: O = ΣM × (basis / Σbasis)
- P calculation: P = O × (J / I) with daily plan formula (calendar days)
- Validation invariants: ΣO = ΣM, lifetime ΣP = O
- Rounding strategy (half-up, remainder to largest component)
- Sequential month processing (O carry-over, gap detection)

**Dependencies:** Spec 01 + Spec 02 (tables, models, enrollments populated)

**Acceptance:** Given Pattern 1 test data, the system produces correct O and P values matching Kuroda-san's Excel Case 1.

---

### Epic: Spec 04 — Freee Journal Adjustment

**Summary:** N-Value Reading, Adjustment Calculation, and Freee API Submission

**Description:**

Read existing system output (N-values), calculate the adjustment (P − N), aggregate to Freee journal granularity, and submit adjustment journals to the Freee API.

**Scope:**
- Read N from `log_daily_rate_calculation[_pre]` for daily plans (Lesson, Coaching)
- Read N from `log_monthly_rate_calculation[_pre]` for Monthly-15
- Calculate adjustment: P − N per product-month
- App always has N = 0 (synthesized)
- Aggregate by product_type + contract_type + target_ym → `asch_sum_calculation`
- Persist proration-to-summary linkage in `asch_sum_calculation_history`
- Submit to Freee API using existing `SendJournalsDataLogic` patterns (T1/T2/T3)
- Map App (product_type=100) to new Freee account code
- Only submit on final runs; skip if total adjustment = 0

**Dependencies:** Spec 01 + Spec 03 (P-values must exist in `asch_monthly_prorations`)

**Acceptance:** Given Pattern 1 data with known N-values, the system calculates correct adjustments and submits valid journal entries to Freee.

---

### Epic: Spec 05 — CSV Report Generation

**Summary:** ASCH Component Detail and Calculation Summary CSV Reports

**Description:**

Generate two new CSV report files per batch run for the accounting team to review proration results.

**Scope:**
- `AschComponentDetail_{YYYYMM}_{type}.csv` — one row per proration (enrollment × product × month)
- `AschCalculationSummary_{YYYYMM}_{type}.csv` — aggregated at Freee-submission granularity
- Dedicated CSV utility class (not CommonUtil.php)
- Register in `config/const.php` following existing file naming pattern
- UTF-8 with BOM, CRLF line endings
- Run type (preview/final) in filename
- Called from both preview and final commands after calculation

**Dependencies:** Spec 01 + Spec 04 (populated `asch_monthly_prorations` + `asch_sum_calculation`)

**Acceptance:** CSVs are generated with correct content, headers match config definition, files are stored in the expected location.

---

## Phase 2 — Pattern Extensions

---

### Epic: Spec 06 — Patterns 2+3+9

**Summary:** Cross-Month Splitting, Independent Month-6 Counting, Discount Priority

**Description:**

Extend the proration engine to handle staggered contract start dates and overlapping discount types.

**Scope:**
- Cross-month contract splitting (one accounting month contains two contract periods per product)
- Multiple proration groups per month (new group when new contract starts mid-month)
- Independent month-6 discount counting per product (based on each product's own start date)
- Discount priority resolution: 50% Honki Set > 10% Loyal > 5% B2E > no discount
- B2E discount as non-Honki (basis = M)
- Pre-campaign Lesson charges (Lesson active before Honki Set, proration starts later)

**Patterns covered:** 2 (different start dates), 3 (Lesson before campaign), 9 (B2E + Loyal overlap)

**Dependencies:** Spec 03 (core engine must exist)

**Acceptance:** System produces correct values matching Kuroda-san's Excel Cases 2, 3, and 9.

---

### Epic: Spec 07 — Patterns 4+6

**Summary:** Plan Changes (Component Revisions, I/J Type Switching)

**Description:**

Extend the proration engine to handle mid-campaign plan changes and the resulting O recalculation.

**Scope:**
- Component revision detection (plan change creates new revision, not update)
- O recalculation when paid_price changes (new plan price → new ΣM → all O values shift)
- O unchanged when paid_price stays same (Daily 1 → Monthly 15 at same price)
- I/J type switching: DailyProrator (calendar days) vs TicketProrator (ticket counts)
- P = 0 valid (no tickets consumed in a month)
- P > list price valid (consumption skew — all tickets used early)
- N-value source switching (daily → monthly log table after plan change)
- Month-6 discount applies to active plan at month-6 date

**Patterns covered:** 4 (Daily 1 → Daily 2), 6 (Daily 1 → Monthly 15)

**Dependencies:** Spec 03 (core engine must exist)

**Acceptance:** System produces correct values matching Kuroda-san's Excel Cases 4 and 6.

---

### Epic: Spec 08 — Patterns 5+7

**Summary:** Enrollment Termination (Coaching Rest, B2E→B2B Exit, Negative M)

**Description:**

Extend the proration engine to handle early bundle termination and contract type changes.

**Scope:**
- Coaching rest detection (no new Coaching charge after current one ends)
- App removal when Coaching cancelled (App follows Coaching lifecycle)
- Lesson reverts to non-bundled after termination (P = N, adjustment = 0)
- Month-6 discount permanently lost on cancellation
- B2E → B2B contract type switch detection
- Prorated refund handling (negative M values in proration group)
- Partial bundle exit (one product leaves, others may continue)
- Enrollment status tracking (active → terminated, with termination date)

**Patterns covered:** 5 (Coaching rest), 7 (B2E → B2B switch with refund)

**Dependencies:** Spec 03 (core engine) + Spec 02 (enrollment/contract period tracking)

**Acceptance:** System produces correct values matching Kuroda-san's Excel Cases 5 and 7.

---

### Epic: Spec 09 — Pattern 8

**Summary:** Cooling-Off Refund (Within 8 Days)

**Description:**

Extend the proration engine to handle cooling-off cancellations where the bundle starts and dies within the same month.

**Scope:**
- Cooling-off detection (full/near-full refund within 8 days of contract start)
- Same-month charge + refund processing
- Negative M for both Lesson and Coaching refund charges
- Near-zero net proration (only days of service rendered before cancellation)
- Correct basis determination for refund rows

**Patterns covered:** 8 (Cooling-off refund)

**Dependencies:** Spec 03 (core engine)

**Acceptance:** System produces correct values matching Kuroda-san's Excel Case 8.
