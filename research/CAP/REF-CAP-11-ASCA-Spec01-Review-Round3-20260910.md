# REF-CAP-11 — ASCA Spec 01 Review Feedback, Round 3 (Kuroda-san, 2026-09-10)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-09-10 (Received — Confluence comment) |
| **Author (source)** | Hayato Kuroda (PM); cc: Patrick Florentino, Glenn Flamiano |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative G1 round-3 review. **Spec 01 (Foundation) approved to proceed.** |
| **Audience** | Dev team (ASCA), Accounting |
| **Applies to** | Doc A = `accounting_related_system_for_freee/.kiro/specs/asca-spec-01-foundation/requirements.md`; Doc B = `ls-database-migrations/.kiro/specs/asca-spec-01-database-migration/requirements.md` |

> ⚠️ **Verbatim source document.** Preserved in full. Do not alter.

---

hi @Noel Palo san cc: @Patrick Florentino @Glenn Flamiano

Thank you. Bottom line: Spec 01 (Foundation) is good to proceed, we can start it know I think.

Only the 2 points below (A: pairing key, B: V-5 anchor) just need to be written into the spec before the migrations and the finalize logic are locked; everything else is minor or tracked on our side.

**What you can start now**

Models, enums, AllocationFormulaInterface + TwoWayAllocationFormula skeleton, and the DEV04 seeder skeleton — go ahead.

Please fold in A and B below before finalizing the migrations (especially log_alloc_run_anchors) and the run-lifecycle finalize logic.

**A. Bundle pairing key — Doc A Req 5 / Doc B Req 3 + Glossary**

Sorry for my missing but I checked trn_charge. It has student_id, plan_id, product_id, start_date, end_date, and order_no (populated only for B2B / B2B2C, NULL otherwise). There is no contract-instance FK column.

Confirmed facts on our side:
- For the same student + same plan, contract periods never overlap.
- A mid-month renewal or cancel-and-rebuy does create extra charges for the same plan/product in the same month. Each charge gets a new charge_id.
- The coaching charge and the app charge from the same contract share the same start_date and end_date. These dates are always set at charge creation.

So, when order_no is NULL, the fallback pairing key is (student_id, plan_id, start_date, end_date): pair the coaching charge (product_id 10005/10015) with the app charge (product_id 10022) that have the same start_date and end_date.

Please:
- Replace the vague "charge/contract-level identifier" wording in Req 5 with this explicit key, and add the same key to the Bundle glossary in Doc B.
- If the coaching and app charges in a group don't have matching dates, don't guess — skip and flag (V-3).
- Keep the "exactly 1 coaching + 1 app" cardinality check as the safety net.
- Add a test: a mid-month renewal / cancel-and-rebuy that produces two pairs in one month must split into two separate bundles.

This resolves the pairing rule. We'll still verify against real data that the dates line up with no exceptions.

**B. V-5 concurrency — Doc A Req 4 / Doc B Req 13 & 13a**

For context: in ASCA, the pre batch runs the Preview and the sendjournal batch runs the Final. Each is a single scheduled invocation, once a month, so two Final runs don't run concurrently in normal operation.

However, manual re-runs (an operator re-running sendjournal within the month if the 3rd-business-day result was wrong), double-triggering, and crash recovery are paths we can't fully rule out — so keep the anchor-row lock. Please finalize it like this:
- Keep log_alloc_run_anchors as a lock-only row (one per month, UNIQUE (bundle_type, target_ym)). The finalizer takes SELECT … FOR UPDATE on it before switching the active pointer.
- Drop the active_run_id column. The single source of truth for "which Final is active" is superseded_by_run_id IS NULL on the runs table (the condition v_alloc_prorations_active already uses).
- Make the anchor-row creation race-safe: INSERT … ON DUPLICATE KEY (or INSERT IGNORE) then SELECT … FOR UPDATE, so a run that loses the insert still ends up holding the lock rather than erroring. Please add one sentence for this.
- Keep the retain-history logic: when a new Completed Final supersedes the existing active Final for the same (bundle_type, target_ym), set the old run's superseded_by_run_id and make the new run active, in one transaction.
- Since active_run_id is gone, state whether LogAllocRunAnchor gets a model (add it to Doc A Req 1) or is accessed via the query builder.
- The log_alloc_source_documents UNIQUE (run_id, charge_id, target_ym) in Req 13 is unrelated to the anchor — keep it.

**C. product_type — Doc B Req 6 / Doc A Req 8 (V-6) — resolved**

product_type is per product. Use the same values as the existing equivalent products:
- Foundation (CAP) value: App 10022 = 100 (same as the existing App, 10012). This fixes V-6's expected value.
- CIP Coaching Intensive 10025 = 9 (same as existing Coaching) — recorded for ASCI, out of Foundation scope.

No accounting sign-off needed.

**D. Minor spec-text fixes**

- Doc B's Introduction still says the CIP 10025 reference price is "unconfirmed (O-5)", while Doc A says 66,500 is confirmed. Please make them consistent. (CIP is out of Foundation scope, so no impact on Foundation work.)
- The "snapshot the full input" wording in Req 7 / Doc B Req 2 doesn't match the actual columns (original_paid_price + applied_reference_price + applied_reference_price_id). Please soften it to "snapshot the inputs needed to reproduce the allocation."

**E. Being confirmed on my side (not blocking your start, tracking explicitly)**

- Idempotency: write-back atomicity and the DataCorrectionLogic injection are Spec 02. But Doc A Req 7 requires "a re-run produces the same P" within Foundation, and re-reading current values alone doesn't guarantee that after a mid-run failure or a direct-SQL fix. We're tracking this as a Spec 02 release condition.
- V-7 (app charge paid_price = 0 assumption): we're treating this as a pre-go-live blocker. We'll work out the real-data distribution, tolerable skip count, and alerting. Implement V-7 as specified.
- Whether "first ASCA target month = 2027-01" is right for the fixed effective_from seed date (I'll confirm the go-live month).
- Coaching 15min / 30min reference price = ¥18,000 / ¥36,000 tax-exclusive — I'll reconcile against the final mst_new_price_listing rows before the seeder runs.
