# REF-CAP-10 — ASCA Spec 01 Review Feedback, Round 2 (Kuroda-san, 2026-09-09)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-09-09 (Received, 5:14 PM) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative G1 review feedback for ASCA Spec 01 (both requirements docs) |
| **Audience** | Dev team (ASCA), Accounting |
| **Applies to** | `accounting_related_system_for_freee/.kiro/specs/asca-spec-01-foundation/requirements.md` (Doc A), `ls-database-migrations/.kiro/specs/asca-spec-01-database-migration/requirements.md` (Doc B) |

> ⚠️ **Verbatim source document.** Kuroda-san's round-2 review, preserved in full. Our edits to the spec docs are tracked separately. Do not alter this content.

---

## ASCA Spec 01 — Review feedback, round 2

By Hayato Kuroda — Sep 9 at 5:14 PM

### Section 1 — To pin in the spec before engine implementation

**1-1. V-5 "one active Final per month" — the empty-set race [NEEDS SPEC CHANGE]**

Doc A Req 4: "(V-5) WHEN a Final run completes, THE service SHALL, in a single locked transaction: find the prior active Completed Final for the same (bundle_type, target_ym), set that prior run's superseded_by_run_id to the new run's id, and leave the new run active (superseded_by_run_id = NULL) — so at most one Final is active per month. Failed runs are retryable (they never become active). A concurrency test SHALL cover two Final runs finalizing for the same month."

Doc B Req 13: "THE SYSTEM SHALL NOT enforce V-5 with a raw UNIQUE on (bundle_type, target_ym) — that would block Preview/Final coexistence and failed-run retries. Enforcement is at the application level: finalizing a Final run runs in a transaction that locks the prior active run, sets its superseded_by_run_id, and marks the new run active — so two Final runs cannot both end up active for the same month."

Issue: the mechanism locks the prior active run. When there is none — the first Final of a month, or two Finals finalizing concurrently that both see no prior active run — there is no row to lock and no DB constraint, so both can finish with superseded_by_run_id = NULL. "At most one active Final" is stated as the rule but is not guaranteed by the mechanism.

Please specify a mechanism that also covers the empty case, e.g. one of:
- an always-present anchor row per (bundle_type, target_ym) that finalize takes SELECT … FOR UPDATE on before switching the active pointer; or
- a generated column that equals target_ym while the Final is active and is NULL once superseded, with UNIQUE (bundle_type, that_column) — the stand-in for the partial unique index MySQL lacks.

Also define what the concurrency test must assert to pass: two Finals, same month → exactly one ends up active, the other superseded.

**1-2. CIP scope — three statements conflict [NEEDS SPEC CHANGE]**

Doc A Intro: "covering CAP (all plans) and CIP plan 1028"
Doc A Req 2: "CoachingIntensivePlanEnum (int-backed) with cases for plan_ids 1028–1032"
Doc A Req 5: "select rows whose plan_id is in the CAP (or CIP) enum and whose product_id is in {10005, 10015, 10025, 10022}" … "identify the App row by product_id = 10022 and the coaching row as the non-App product in the group"
Doc A Req 3: "IF no effective reference-price row exists for an applied product on the target date, THEN THE system SHALL fail the run (V-4)"
Doc A O-5: "CIP seed row deferred to ASCI"

Issues:
- 1029–1032 are not excluded from detection. Their Lesson product is not in {10005, 10015, 10025, 10022}, so only the 10025 + 10022 rows are picked up and processed as a complete 2-way bundle — Lesson is silently dropped and the split is wrong.
- CIP 1028 is "in Foundation" but has no seeded reference price (deferred to ASCI). Per Req 3, any CIP 1028 bundle then fails the entire run.

Please resolve to one of:
- (a) Foundation = CAP only. Detection filters bundle_type = CAP; all CIP (1028 and 1029–1032) → ASCI. Update the Intro and Req 5.
- (b) Foundation = CAP + CIP 1028. Seed 10025 now (tax-exclusive 66,500 — confirmed on the pricing sheet, price_flag = 2) and explicitly exclude 1029–1032 from detection.
- (c) Keep the scope line, but add to Req 5: detection SHALL exclude plan_ids 1029–1032 (3-way, ASCI); if one is encountered, skip it with a warning, do not fail the run — and state whether 1028 is seeded or skipped.

**1-3. Reference-price resolution — "target date" is undefined [NEEDS SPEC CHANGE]**

Doc A Req 3: "WHEN resolving a reference price for a product on a target date, THE system SHALL return the mst_alloc_reference_prices row whose effective window (effective_from .. nullable effective_to) contains that date."

Issue: "target date" is never defined — the first day of target_ym? the last day? the date of the daily-rate log row? charge.paid_at? With a single price row it is harmless today, but the acceptance criterion becomes non-deterministic the moment a second effective row exists.

Please fix it to one definition, e.g. "the last calendar day of target_ym" or "the date of the daily-rate log row being overwritten" — whichever matches how the ASCA-8 breakdown picks its List Price.

**1-4. Reference-price table — no uniqueness, no overlap guard, no initial effective_from [NEEDS SPEC CHANGE]**

Doc B Req 7: "THE system SHALL create an index on (bundle_type, product_id, effective_from)" — plus effective_from DATE NOT NULL, effective_to DATE NULLABLE, comment 'NULL = open-ended'.

Issues:
- It is a plain index, not UNIQUE — duplicate (bundle_type, product_id, effective_from) rows are allowed.
- Nothing prevents two rows for the same (bundle_type, product_id) with overlapping [effective_from, effective_to] windows.
- The first row's effective_from is undefined. If it is later than a month being (re)calculated, Req 3 fails the run for "no effective row".

Please:
- make it UNIQUE (bundle_type, product_id, effective_from);
- add an acceptance criterion that overlapping effective windows for the same (bundle_type, product_id) are rejected (a plain UNIQUE cannot express this — it needs an application-level check on insert/update, or an exclusion constraint);
- state the initial effective_from (a fixed early date, or the first ASCA target month).

**1-5. Bundle pairing when order_no is NULL [NEEDS SPEC CHANGE]**

Doc A Req 5: "THE system SHALL group detected rows by (student_id, order_no, plan_id) so each contract is isolated. (plan_id is required — order_no is nullable for B2C and non-unique; G1 2026-09-04.)" "IF a single (student_id, order_no) group resolves to more than one candidate coaching row (multiple plans on one order_no), THEN THE system SHALL NOT guess a pair — it SHALL mark the group ambiguous (incomplete, V-3), log it, and skip, pending the match-rule decision below."

Note on data: in our data, order_no is NULL for B2E as well as B2C — i.e. for essentially all CAP bundles. Please verify the NULL distribution with the CAP team, but plan for the key being effectively (student_id, NULL, plan_id) almost always.

Issues:
- The ambiguity guard is written against (student_id, order_no), but the grouping key is the 3-column (student_id, order_no, plan_id). Which one applies?
- With order_no NULL, two distinct concurrent contracts of the same plan_id for the same student in the same month (for example an overlapping personal + corporate contract — the same situation that produces refunds) collapse into one group → wrong N, wrong split.
- There is no rule for how many App / Coaching rows (or charges) are expected per group, or how multiple charges sum into N. primary_charge_id is "the coaching charge (bundle anchor)", but the selection rule when there is more than one coaching charge is not stated.

Please define:
- the grouping key, including the fallback when order_no is NULL (a charge-level or contract-level identifier);
- the expected cardinality per group (exactly 1 App + 1 Coaching? 1 App + N coaching charges of the same plan?) and how multiple charges roll up into N;
- and align the ambiguity-guard wording with the real key.

**1-6. product_type guard (O-10) [NEEDS SPEC CHANGE]**

Doc B Req 6: "product_type … INT NOT NULL, comment 'Freee product_type. Existing: 9=Coaching, 100=App(10012). New CAP/CIP products pending reconciliation (O-10): App 10022 = 618 or 100; CIP 10025 = 469 or 9. … value comes from mst_product at runtime.'"

Issue: the value flows into log_alloc_sum_calculation → Freee grouping. If mst_product holds the wrong value at run time, revenue is journaled under the wrong product_type. This is not a compile blocker, but it is a correctness blocker for any real CAP run.

Please add an acceptance criterion: the run validates each product_type against the exact expected value for that product_id (not a set of candidates — allowing {618, 100} for 10022 would let a wrong value through) and fails loudly on a mismatch. We will lock the actual mst_product values for 10022 / 10025 on our side and give them to you before that AC is finalized.

### Section 2 — Data confirmation before seeding / first real run

**2-1. Seeder source rows [DATA CONFIRMATION]**

From the pricing sheet (proposal): App 10022 price_flag = 2 → ¥3,618 (tax-free); CIP Coaching Intensive 10025 price_flag = 2 → ¥66,500 (tax-free); both marked "can use this for ASC". price_flag = 2 rows exist only for the App and the CIP coaching product — Coaching 15min (10005) / 30min (10015) have a single listing row, so no disambiguation is needed for them.

The Intro already says: "confirm the CAP coaching tax-excl figures (18,000 / 36,000) against the final mst_new_price_listing rows before seeding." Please close this before the seeder runs — confirm the exact 10005 / 10015 rows the seeder reads and that they resolve to ¥18,000 / ¥36,000 tax-exclusive.

**2-2. App charge amount = 0 [DATA CONFIRMATION]**

The pricing sheet shows App 10022 charge price = ¥0 (price_flag = 3 row = 0), which matches the spec's assumption — snapshot "app row = 0", DEV04 seeder "coaching + ¥0 app". That is fine as the normal case.

Please make the abnormal case explicit: if a non-zero App paid_price ever appears in the daily-rate log for a bundle, the engine must not silently fold it into N = Σ(paid_price). Handle it like an incomplete bundle — mark the group incomplete (V-3), log a warning, and exclude it from allocation rather than finalizing a wrong split.

### Section 3 — FYI / assumptions (no action needed)

- Reference prices are assumed not to change. We do not need an automatic sync between mst_alloc_reference_prices and mst_new_price_listing. Two things still hold: (1) the initial seed goes in with the same values as mst_new_price_listing.price (already in Req 3), so ASCA-8 and the engine agree from day one; (2) if a CAP/CIP reference price ever does change, that is a manual one-off handled outside Foundation — the engine does not need to detect or reconcile it.
- Direct-SQL data corrections after a Final. Only the DB data is changed; the Freee side is corrected manually by Accounting. Foundation / Spec 02 does not need to route these through the allocation engine. Reconciling these manual corrections (against ASCA-8 / the daily-rate log / Freee) is an operational task owned by Accounting and is outside Spec 01 / Spec 02 scope.
- ASCA-8 ↔ DailyRateCalculation.csv reconciliation (Req 10) is treated on our side as a release gate before production.
- Foundation carries no Revision / record_kind. We accept that refund and revision handling in Spec 02 / ASCI will bring their own DB migration.
