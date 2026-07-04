# Engineering Knowledge Base — The ASC Project Journey

This knowledge base documents real engineering problems encountered during the Bizmates ASC (Accounting System Changes) project. It's structured as a story: what we walked into, what broke while building, and what systemic issues remain.

---

## How to Use This Document

- **Reading as a story:** Start with Act 1, then follow numbering — it mirrors the team's discovery journey.
- **For a new project:** Browse Act 3 first. If your system has batch processing, multi-tenant, or financial data, these are the traps to avoid.
- **For code review:** Use the Prevention Checklist at the bottom of each topic.
- **For incident investigation:** Match symptoms to a TL;DR to find root cause quickly.

---

## Act 1 — What We Walked Into

The ASC project's goal was to add a monthly rate report. This section covers the upstream design constraint that made everything harder.

### Topic 01: Uniform Ticket Validity Window (The 60-Day Problem)

**JIRA:** ASC-254, 258, 264, 266, 267

All monthly plan tickets are created with a fixed 2-month (60-day) validity regardless of contract type, plan type, or service. The accounting CTE must *compute* when tickets actually expire based on business rules — rather than simply reading a pre-determined expiry date. This single upstream design decision is the root cause of most CTE boundary complexity.

**Impact:** A 700-line recursive CTE exists because tickets don't carry their actual accounting expiry. What should be a simple `WHERE expiry_month = target_month` requires runtime computation of 4 different expiry triggers.

**Prevention:** When creating records consumed by downstream systems, include all context the downstream will need. Don't force consumers to re-derive it.

---

## Act 2 — What We Built and What Broke

Bugs discovered while building the monthly commands — ordered by discovery sequence.

### Topic 02: Fan-Out Join Doubling Values

**JIRA:** ASC-236

A 1:N JOIN between charges and tickets inflated `SUM(paid_price)` by the ticket count. ¥12,980 became ¥389,400.

**Fix:** Pre-aggregate the N-side in a subquery before joining.

**Prevention:** Before JOIN + GROUP BY, state expected cardinality. If they don't match, pre-aggregate the N-side.

---

### Topic 03: Wrong Identity on Derived Rows

**JIRA:** ASC-244

Refund log rows were inserted with the original charge's ID instead of the refund's own ID.

**Fix:** Every derived record carries its own identity; link to source via a separate FK field.

**Prevention:** Derived records are constructed fresh (factory/builder), not cloned.

---

### Topic 04: DateTime Range Boundary

**JIRA:** ASC-277

`BETWEEN` with DATE boundaries excludes records after midnight on the last day.

**Fix:** Always use `>= start AND < next_period_start` (half-open interval).

**Prevention:** Never use BETWEEN for DATETIME columns.

---

### Topic 05: Invisible Records — No Log Entry

**JIRA:** ASC-269

Charges with deleted tickets never enter the pipeline because it starts from `trn_ticket`.

**Fix:** Standalone fallback query catches anything the main pipeline missed.

**Prevention:** Pipeline entry = authoritative source (charges), not a dependency (tickets).

---

### Topic 06: Complex CTE Boundary Logic

**JIRA:** ASC-211, 254, 258, 260, 261, 205, 234, 232

The recursive CTE fails at every boundary: first/last charge, period transitions, lookahead. Errors compound because each row depends on the previous.

**Fix:** Pre-compute boundary flags (`is_first`, `is_last`, `is_transition`) in a non-recursive CTE, then reference them in the recursion.

**Prevention:** Pre-compute boundary flags. Test cases for EVERY boundary.

---

### Topic 07: Data Leaking Across Periods

**JIRA:** ASC-267

Expired charges produce "ghost rows" (all zeros) in the next month's output because the CTE lacked explicit expulsion rules.

**Fix:** Expel by business state (charge expired, lifecycle complete), not by absence of data.

**Prevention:** Every time-partitioned pipeline has explicit expulsion rules — not just inclusion rules.

---

### Topic 08: Computation at Report Time vs Storage Time

**JIRA:** ASC-269, 276

Late refunds were invisible because the system computed values at CSV-generation time instead of storing them during batch processing.

**Fix:** Compute and store at processing time. Reports become read-only views.

**Prevention:** Reports should never compute. They should only read pre-computed results.

---

### Topic 09: Orphaned Records — Missing Dependencies

**JIRA:** ASC-280, ASC-297

Charges whose tickets were hard-deleted became invisible because the pipeline starts from tickets.

**Fix:** Orphaned charge query detects and includes them separately (end-month + start-month).

**Prevention:** Never hard-delete records in JOIN paths. Pipeline entry = authoritative table.

---

### Topic 10: Source Table Mismatch (Pre/Final)

**JIRA:** ASC-274

The Pre command silently read from the Final table. Empty reports looked like "no data."

**Fix:** Make the execution mode an explicit parameter, never inferred.

**Prevention:** Table names resolved from mode parameter, not hardcoded.

---

### Topic 11: Rounding Loss Accumulation

**JIRA:** ASC-239

`floor(14107/15) × 15 = 14100`. Missing ¥7 on full refunds.

**Fix:** Full-quantity refund uses original total directly, not multiply-back.

**Prevention:** Any time you see `floor()` followed by multiplication back, there's a gap.

---

### Topic 12: Stale Aggregation Data

**JIRA:** ASC-203

Re-runs added new summary rows without removing old ones. Aggregation doubled.

**Fix:** Delete-and-reinsert within a transaction (clear-and-rebuild).

**Prevention:** Every batch has explicit cleanup. Running N times = same result as running once.

---

### Topic 19: INTERVAL Offset vs DATETIME Boundary

**JIRA:** ASC-296

`INTERVAL 1 DAY` resolves to midnight — excludes DATETIME records with time past 00:00:00 on that day. FLP tickets at `00:59:59` on the 1st of next month were excluded.

**Fix:** Changed to `INTERVAL 2 DAY` to cover all times on the 1st.

**Prevention:** Query `MAX(TIME(column))` before choosing the INTERVAL value. Don't assume midnight.

---

### Topic 20: Lookahead Premature Expiry

**JIRA:** ASC-301

The Grouped CTE's 2-day lookahead condition (introduced in ASC-256, 2026-05-25) fires for charges with `end_date` within 2 days past month-end and no successor. This causes double revenue recognition for **all contract types** (B2B, B2C, B2B2C) — not just FLP. The scenario the lookahead was designed to guard against (ticket ending exactly at midnight on day 1 of next month) has never existed in production data (verified: empty results for both Bizmates and Zipan).

The lookahead was likely a Kiro-suggested theoretical edge case fix added under extreme time pressure (3 work days after Kiro adoption, 4 work days before deadline). No test case intentionally exercised it. TC013's accidental triggering (via ASC-247 date rewrite) was masked by `is_last_charge_in_order` firing in the same month. B2B double-count confirmed in Zipan (charges 12480, 12501).

**Fix:** Gate the lookahead on `om.rn = om.total_rows` — only fire on the last row. If a next-month row exists, expiry fires there via the ticket validity check instead. Business rule confirmed by Kuroda-san: expiry belongs in the month where `end_date` falls. Alternative: remove the lookahead entirely (awaiting decision).

**Prevention:** Before adding a preventive condition for a theoretical edge case, verify the scenario exists in production data. Lookahead conditions should be gated on "this is the last row" to avoid firing when subsequent rows handle the same logic.

**Full analysis:** `Technical_Notes/Issue_Investigation/20260623_check_lookahead_condition/REPORT_00_Lookahead_Condition_Investigation.md`

---

### Topic 21: Downstream Reports Not Updated After Pipeline Split

**JIRA:** ASC-304

When the ASC project separated monthly-plan charges from `log_daily_rate_calculation` into `log_monthly_rate_calculation`, the PaypalPaymentSum and PaypalPayment CSV generation functions were not updated. They continued to query only `log_daily_rate_calculation` for the revenue breakdown, causing monthly-plan charges to show `uriage = 0` — a discrepancy against `trn_charge.paid_price`.

This is the same class of issue that affected CalculationSummary (already fixed). Any downstream report that reads from the daily log table and was written before the monthly/daily split is potentially affected.

**Fix:** Add `UNION ALL` with `log_monthly_rate_calculation` to the uriage subquery in both `createPaypalPaymentFile` and `createPaypalPaymentSumFile` (CommonUtil + ZipanUtil = 4 locations).

**Prevention:** When splitting a data source into multiple tables, audit all downstream consumers. Grep for the original table name across the codebase to find reports/queries that need updating.

---

## Act 3 — Systemic Issues (Tech Debt)

Design debt documented during the project. These are structural problems requiring larger refactoring.

### Topic 13: Tenant Code Duplication

**Status:** Mitigated (review process)

Every fix applied to Bizmates must be manually repeated for Zipan. Tenant differences are just product IDs and DB connection, but implemented as separate code paths.

---

### Topic 14: Pre/Final Logic Duplication

**Status:** Mitigated (review checklist)

Pre and Final calculations share 95% identical logic but exist as separate classes — 2,500 lines duplicated. Every bug fix must be applied twice.

---

### Topic 15: Unsafe Delete Scope for Re-Runs

**Status:** Mitigated (process discipline)

Re-running March's batch can wipe April's data because DELETE scope was based on timestamps, not business keys.

---

### Topic 16: Global Mutable State

**Status:** Low risk (single-month ops)

Target month stored as mutable class property. Sequential processing leaks state between iterations.

---

### Topic 17: No Concurrency Protection

**Status:** Low risk (cron spacing)

Two instances of the same batch can run simultaneously, causing duplicates or data loss.

---

### Topic 18: Batch Sequencing Dependency

**Status:** Mitigated (scheduling discipline)

The batch only processes the target month's window. Skipped runs lose data permanently because the next run only looks at its own window.
