# 00 — Design Context: How the Legacy Architecture Shaped ASC's Problems

> **TL;DR:** The ASC project's goal was to add a monthly rate report (revenue by lesson consumption). During development, the team discovered the daily commands already processed monthly-plan charges, forcing a cascade of exclusions and merges. Combined with upstream ticket data that lacks business context (see Topic 01), the monthly commands became the most complex part of the system — computing at runtime what should have been stored upstream.

---

## The ASC Project's Original Goal

The ASC project started with a clear ask from the accounting team: **add a new monthly rate calculation report** based on lesson consumption (tickets used/expired/remaining per charge per month). The existing system only had daily rate calculations (pro-rata by calendar days).

What seemed like "add a report" cascaded into restructuring the entire pipeline:

1. **Discovery:** The existing daily commands already processed monthly-plan charges using the daily formula
2. **Exclusion:** Monthly plans had to be removed from the daily path to avoid double-counting once the new monthly commands existed
3. **Gap:** Excluding monthly plans from daily broke the shared summary report (CalculationSummary)
4. **Merge:** Monthly results had to be merged back into the summary so totals still balanced
5. **Divergence:** Daily formula (`paid_price × days_used / days_in_month`) and monthly formula (`paid_price × tickets_consumed / total_tickets`) produce different numbers — the final report totals intentionally changed

This cascade — not the original goal — is what generated most of the complexity and bugs documented in this knowledge base.

---

## The Three-System Problem

The Bizmates accounting pipeline spans three independently-developed codebases:

| System | Built In | Responsibility | Outputs |
|--------|----------|---------------|---------|
| **bizmates.jp** (Admin Portal) | FuelPHP, ~2014 | Enrollment, contract changes, refunds, charge batch (auto-renewal + PayPal billing) | Writes `trn_charge`, `trn_ticket`, `trn_student_product` |
| **MBTI_backend** (Student Portal) | Laravel, ~2019 | Plan purchases, lesson booking, rest/refund requests | Writes `trn_charge`, `trn_ticket` |
| **accounting_related_system_for_freee** (ASC) | Laravel, ~2021 | Revenue recognition, CSV reports, Freee journal sync | Reads all of the above, writes `log_*` tables |

ASC sits downstream. It **reads** what the other two systems **wrote**, but has no control over how or when they write it.

---

## Design Decisions That Became Constraints

### 1. No Event Stream — Only Snapshots

When a student purchases a plan, the admin portal inserts a charge and tickets directly. There's no event published. ASC discovers new charges by **querying the database at batch time**.

**Impact:** If a charge appears after the batch runs, it's invisible until next month (Topics 05, 08, 18).

### 2. Tickets as the Unit of Truth (with Generic Metadata)

The original system was designed around lesson tickets. Revenue recognition was an afterthought. The CTE pipeline was built to walk *tickets* month-by-month, not *charges*.

Worse, all tickets are created with a uniform 2-month (60-day) validity window regardless of contract type (Topic 01). The accounting system must *recompute* the real expiry based on business rules.

**Impact:** The pipeline's entry point is `trn_ticket`, making any charge without tickets invisible (Topic 09). The 60-day generic window forces the CTE to include complex boundary logic (Topics 06, 07).

### 3. Daily Commands Already Handled Monthly Plans

Before ASC, the daily rate commands processed *all* charges using a simple pro-rata formula. When the ASC project added a separate monthly calculation, monthly plans had to be **excluded from daily** and **handled separately by the new monthly commands**.

But both feed into the same summary report. So the monthly results must be **merged back**. And because the formulas differ, the totals are intentionally different.

**Impact:** The Pre/Final duplication (Topic 14) and unsafe delete scope (Topic 15) exist because the daily and monthly commands manage their own lifecycles independently. The summary merge creates coupling between commands (Topic 12).

### 4. CSV Generation Did Double Duty

Originally, the monthly CSV generation step was also the *calculation* step. Refund adjustments were computed on-the-fly at report time.

**Impact:** Late refunds were invisible (Topic 08). Moving computation to storage time (ASC-276) was the single biggest architectural correction.

### 5. Zipan Was Cloned, Not Abstracted

When Zipan was added, the entire pipeline was duplicated. The differences are tiny (different product IDs, different DB connection), but the implementation is a full copy.

**Impact:** Every fix requires applying to both tenants (Topic 13). The duplication across Pre/Final × Bizmates/Zipan means a single CTE fix must be applied in up to 4 places (Topic 14).

### 6. No Batch Orchestration

There's no workflow engine coordinating the batch sequence. Each command is a standalone artisan command triggered by cron.

**Impact:** Skipped months produce gaps (Topic 18). Concurrent runs corrupt data (Topic 17). Re-runs can wipe other months (Topic 15).

### 7. Preventive Code Added Without Data Validation

Under time pressure (8 working days to deadline), the team relied on AI-assisted edge case analysis to add preventive measures to the CTE. The lookahead expiry condition (ASC-256) was added to guard against a theoretical scenario — a charge where `ticket.end_datetime` ends exactly at midnight on the 1st of the next month, meaning no next-month CTE row would be generated.

This scenario has **never existed in production data**. The condition actively caused double revenue recognition for all contract types (Topic 20, ASC-301). It passed all test cases because none exercised the specific path.

**Impact:** Theoretical safeguards added to an already-complex CTE introduce latent defects that are invisible until a specific real-world combination triggers them. The 700-line CTE is too complex to reason about safely without automated validation — yet too complex to unit test with standard PHP mocks.

### 8. Inconsistent Table Naming Across Tenants

Zipan daily rate tables use a `_zipan` suffix (`log_daily_rate_calculation_zipan`), but Zipan monthly rate tables use the same name as Bizmates (`log_monthly_rate_calculation`) — only the DB connection differs. This inconsistency exists because the daily tables predate the ASC project (legacy naming), while the monthly tables were created by ASC using consistent names across both databases.

**Impact:** Any code change that references Zipan tables by pattern-matching the daily naming convention (`_zipan` suffix) will fail for monthly tables. This is a silent error — the query runs but returns empty results because the table doesn't exist (ASC-304 incident).

**Prevention:** Always verify table names from the model's `protected $table` property. Never assume naming patterns.

---

## How This Manifested in the Monthly Commands

The monthly rate commands were new code, but they had to fit into an existing ecosystem that wasn't designed to accommodate them:

```
Legacy Design Decision              → Problem in Monthly Commands
────────────────────────────────    ─────────────────────────────────────
No event stream                     → Late charges/refunds invisible
Tickets as entry point              → Orphaned charges (deleted tickets)
60-day generic ticket validity      → 700-line CTE to recompute real expiry
Daily commands already had monthly  → Exclude → merge-back → formula divergence
No unified pipeline                 → Pre/Final logic duplicated
CSV = calculation                   → Refunds only visible at report time
Clone for multi-tenant              → Every fix applied 4x
No orchestration                    → Gaps, corruption, stale data
Global mutable state (CommonUtil)   → Date leaks between iterations
No automated validation             → Theoretical safeguards untested, cause latent defects
Inconsistent table naming           → Silent query failures when pattern-matching names
```

---

## What Mature Systems Do Differently

| Constraint We Inherited | What Stripe/Xero/NetSuite Do Instead |
|---|---|
| Discover charges by querying | Every charge publishes an event; downstream subscribes |
| Pipeline starts from tickets | Pipeline starts from the authoritative financial record (charge/invoice) |
| Separate daily/monthly programs | Single recognition engine with configurable output |
| CSV generation = calculation | Ledger writes at transaction time; reports are read-only views |
| Clone for new tenant | Tenant = configuration row, not code branch |
| Standalone cron commands | DAG-based orchestration with dependency tracking |
| Add preventive code without data validation | Property-based tests and integration tests verify every condition against real data before merge |
| Inconsistent naming across tenants | Convention-over-configuration: same schema, same names, tenant isolation via connection only |

---

## Why We Couldn't Just Rewrite

The ASC system processes real money. A rewrite would require parallel running, reconciliation, and regulatory sign-off.

The pragmatic path (what we did) was:
- Build the monthly commands to work with existing data structures (accept the CTE complexity)
- Exclude monthly plans from daily commands and merge back for summary
- Fix bugs as they surfaced (ASC-254 through ASC-280)
- Move the biggest architectural mistake (refund at report time → storage time)
- Document the target architecture (this knowledge base + proposals)
- Refactor incrementally (Phase 2/3 in the architecture doc)

---

## Takeaway for New Projects

1. **Events over queries.** Publish events when charges are created.
2. **Start from the money.** Pipeline entry = financial record (charge, invoice), not a downstream artifact (tickets).
3. **One pipeline, many outputs.** Daily/monthly/summary = different output formats from one calculation engine.
4. **Immutable log, read-only reports.** Write computed data at processing time. Reports SELECT from the log.
5. **Tenant = config, not code.** Adding a second tenant = adding a config block, not duplicating files.
6. **Orchestrate, don't hope.** Use a DAG runner to enforce execution order.
7. **Validate before adding.** Before adding a preventive condition for a theoretical edge case, verify the scenario exists in production data. Untested code paths are liabilities, not safety nets.
8. **Naming conventions are contracts.** If tenants share a schema, use the same table names everywhere. If legacy forced different naming, document the mapping explicitly and verify from source (model `$table` property), never from pattern-matching.