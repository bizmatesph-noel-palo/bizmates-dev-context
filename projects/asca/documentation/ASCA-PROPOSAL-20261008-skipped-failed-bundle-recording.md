# Proposal — Recording Skipped / Failed Bundles (schema decision for Kuroda-san)

## Document Info

| | |
|---|---|
| **Document type** | Decision Brief / Proposal (for PM sign-off) |
| **Date** | 2026-10-08 |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Proposed — awaiting Kuroda-san's decision |
| **Decision owner** | Hayato Kuroda (PM — schema owner) |
| **Audience** | Kuroda-san (decision), Patrick-san (awareness), Dev team |
| **Affects** | ASCA Spec 01 (schema), Spec 02a (recording), Spec 02c (AllocationDetail CSV) |
| **Trigger** | REF-CAP-13 Round-2 review (2026-10-05): 02c must list skipped/failed bundles per-bundle, but there is no per-bundle source for them. |

---

## 1. TL;DR

The 02c AllocationDetail CSV is required to show **every** bundle and its outcome — allocated, skipped (with reason), or failed. Today the engine only persists a row for **successful** allocations (`log_alloc_prorations`); skips and failures leave no per-bundle record (only a log line and a run-level count). So the CSV physically cannot list the exceptions.

This needs a small, additive schema decision. **We recommend adding a dedicated `log_alloc_bundle_outcomes` table (Option A)** and are asking for your sign-off because the schema is yours. The alternatives are a status column on `log_alloc_prorations` (Option B) or keeping only a run-level count and not listing exceptions per-bundle (Option C).

This does **not** block 02a/02b — they can proceed to sign-off and implementation now. It affects only 02c and the schema.

---

## 2. Why this surfaced now, and not during Spec 01 DB design

This is a fair question since the Foundation schema was designed deliberately. The honest answer is that the requirement did not exist at Spec 01 design time — it was created later, by Spec 02:

1. **Spec 01's job was "allocate," so its schema records allocations.** `log_alloc_prorations` holds successful allocation results; `log_alloc_calculation_runs` holds the run status plus a **count** of records produced. At that point, a skipped bundle was a run-level statistic — there was no requirement to enumerate skipped bundles individually. That was a reasonable and correct design for the scope Spec 01 had.

2. **The per-bundle requirement was born in Spec 02 — twice over:**
   - **02c (the AllocationDetail CSV)** introduced the need to *show* Accounting a per-bundle breakdown, including bundles that were not allocated and why.
   - **The Round-2 failure model (REF-CAP-13 #2, decided 2026-10-05)** — per-pair atomic writes with a "completed-with-errors + failed-pair list" outcome — created the concept of an individually **failed pair** that must be listed. That decision is three days old.

   Neither existed when the schema was designed.

3. **One genuine miss on our side, caught in review.** When the Round-1 G1 feedback was folded into 02c, the wording ended up self-contradictory: Req 4.4 said "skipped and failed bundles appear as rows" while Req 2.2/5.1 said "every row comes from `log_alloc_prorations`." You caught that in Round 2. It is caught **before implementation**, which is the cheap place to catch it — a schema addition pre-code is low-cost; discovering mid-build that the CSV can't source its rows would not be.

**Verified against the current engine code** (`RevenueAllocationService::processBundle`, on `feature/ASCA/ASCA-master`):
- A **V-3 skip** (non-zero App, no formula, ambiguous) does `return false` after a `Log::warning(...)` — it persists the pre-overwrite snapshot but **no proration row and no per-bundle skip record**. The reason exists only in the application log.
- A **loud failure** (V-1/V-4/V-6) throws and the run is marked Failed; the failing bundle persists **no proration row**.

So the exceptions are, by construction, absent from `log_alloc_prorations`.

---

## 3. The problem precisely

| CSV needs to show (02c) | Where it would come from today | Exists? |
|---|---|---|
| Allocated bundle (L, ratio, N, P) | `log_alloc_prorations` | ✅ |
| Skipped bundle + reason (per bundle) | — (only a log line + run-level count on `log_alloc_calculation_runs`) | ❌ |
| Failed pair (per bundle) | — (rolled back; nothing persisted) | ❌ |

02a Req 2.5 currently records only the **count + reason on the run**, which cannot be expanded into a per-bundle list for the CSV. We need a per-bundle record of non-allocated outcomes.

---

## 4. Options

### Option A — dedicated `log_alloc_bundle_outcomes` table (recommended)

A new table recording one row per bundle the engine *considered but did not allocate* (skipped or failed), with its reason. The CSV reads allocated rows from `log_alloc_prorations` and exception rows from this table.

**What it does**
- Keeps `log_alloc_prorations` as "successful allocation results only" — its meaning and every existing consumer are unchanged.
- Gives a clean, queryable per-bundle outcome trail (useful beyond the CSV: Metabase, support, reconciliation).

**Impact**
- ls-db: one new migration + model + structure test. FK to `log_alloc_calculation_runs`.
- accounting: engine writes an outcome row on V-3 skip / pair failure; `RevenueAllocationCsvService` merges two sources.
- Downstream: **none** — nothing that reads `log_alloc_prorations` changes.
- Risk: **low** — purely additive on an unreleased schema.

### Option B — status column on `log_alloc_prorations`

Add `status` (allocated / skipped / failed) + `skip_reason`, and write a row even for skipped/failed bundles (money columns null/zero).

**What it does**
- Keeps "every CSV row from one table" literally true.

**Impact**
- **Changes the meaning of the core financial table.** It becomes "results + non-results." Every consumer that `SUM`s `allocated_amount` — `v_alloc_prorations_active`, the sum-building step, Freee journals, the existing CSVs — must now filter `WHERE status = allocated`, or it silently sums skipped/failed rows.
- Requires loosening NOT NULL/type constraints on `ratio`, `reference_price`, `original_amount` to allow null for non-allocations — weakening the integrity of the money table.
- A "failed pair" that was rolled back but still writes a status row is self-contradictory with the Round-2 atomic-failure model.
- Risk: **high for a revenue system** — a single missed filter mis-states a journal. This is exactly the class of silent money bug the project is built to avoid.

### Option C — run-level only (no per-bundle exception listing)

Keep today's behaviour: skips/failures recorded only as a count + reason on the run; the CSV lists allocated bundles only.

**What it does**
- No schema change at all.

**Impact**
- The CSV cannot meet the Round-2 requirement to show skipped/failed bundles per-bundle. Accounting loses visibility of *what was not allocated and why* in the deliverable they review.
- Reconciliation gaps are investigated via logs instead of the report.
- Risk: **low technically, but it does not satisfy the stated requirement** — included only so the full trade space is visible.

---

## 5. Comparison

| | A — new table | B — status column | C — run-level only |
|---|---|---|---|
| Meets 02c per-bundle requirement | ✅ | ✅ | ❌ |
| `log_alloc_prorations` stays "money only" | ✅ | ❌ | ✅ |
| Downstream SUM/journal risk | none | **high** (filter everywhere) | none |
| Schema change | +1 table (additive) | alter core table + loosen constraints | none |
| Queryable exception audit trail | ✅ | partial | ❌ (logs only) |
| Fits the Round-2 atomic-failure model | ✅ | ✗ (rolled-back row contradiction) | n/a |
| Effort | migration + model + test + merge logic | column + migrate every consumer's filter | none |

---

## 6. Recommendation

**Option A.** The deciding factor is what `log_alloc_prorations` is: the audit-grade record of money movements that feeds Freee journals. Its one job is "these are the allocations that happened." Putting non-allocations into it turns every downstream `SUM` into a filtering liability, and in revenue recognition a missed filter is a mis-stated journal. Option B trades a small spec-wording convenience for a permanent correctness hazard on the most sensitive table in the schema.

Option A costs one additive table on an **unreleased** schema (Spec 01 is merged to the ASCA branch + DEV04, not in production), so it is cheap and low-risk — the same kind of small post-review change-request as the view fix (ASCA-34). It is consistent with every other design choice in this project (snapshot-before-overwrite, true floor, retain-history finalize): protect the money path.

---

## 7. Proposed schema (Option A) — for your review

Consistent with the existing `log_alloc_*` conventions (connection `bizmates_mysql`, `log_*` prefix for batch-generated data, FK to the run, commented columns, index on run).

**Table: `log_alloc_bundle_outcomes`**

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | BIGINT UNSIGNED PK | no | |
| `run_id` | BIGINT UNSIGNED | no | FK → `log_alloc_calculation_runs.id` |
| `bundle_type` | TINYINT | no | 1=CAP / 2=CIP (matches existing tables) |
| `target_ym` | CHAR(6) | no | YYYYMM |
| `student_id` | INT | yes | bundle grouping key part (for traceability in the CSV) |
| `plan_id` | INT | yes | bundle grouping key part |
| `order_no` | VARCHAR(64) | yes | bundle grouping key part (NULL for B2C/B2E) |
| `coaching_charge_id` | BIGINT UNSIGNED | yes | the coaching charge of the considered bundle, when known |
| `app_charge_id` | BIGINT UNSIGNED | yes | the app charge, when known |
| `outcome` | TINYINT | no | 1=skipped / 2=failed (reserve others; **not** 2=reversal — that lives elsewhere) |
| `reason_code` | VARCHAR(64) | no | e.g. `no_formula`, `non_zero_app`, `ambiguous_pairing`, `unbalanced`, `ref_price_missing`, `product_type_mismatch` |
| `reason_detail` | TEXT | yes | human-readable detail (the same text that goes to the log) |
| `created_at` / `updated_at` | DATETIME | no | existing convention |

- **Index:** `(run_id)` and `(run_id, outcome)` for the CSV's per-run read.
- **FK:** `run_id` → `log_alloc_calculation_runs.id`, `restrict`/`restrict` (matches the other alloc FKs).
- **No money columns** — this table never carries L/ratio/N/P, so it can never be mistaken for allocation results.

> Open question for you: do you want the skip/fail outcomes keyed to the **bundle** (coaching + app charge ids, as above) or to a single `charge_id`? The CSV needs enough to show the operator which bundle was skipped; the two-charge-id shape mirrors how a bundle is identified elsewhere. Happy to go either way.

---

## 8. What this changes in development

- **02a / 02b proceed now, unaffected.** They do not depend on 02c or this table. They go to sign-off and 02a to implementation on the normal W6 path.
- **This is a Spec 01 change-request, not a re-opening of Spec 01.** Additive table, new migration, no edit to any existing migration (baseline migrations are immutable), no change to the 11 existing tables, no tasks.md regeneration. Same motion as ASCA-34.
- **Cheap because unreleased.** The alloc tables exist only on `feature/ASCA/ASCA-master` + DEV04; adding a table is a forward migration, not a production alter.
- **Timeline:** 02c implements in W7 (after the W6 injection), so this table only needs to land before 02c's slot — it does not sit on the W6 critical path.

---

## 9. The ask

1. **Approve the approach** — A (recommended), B, or C.
2. If A: confirm the **bundle-keyed vs single-charge-id** shape (§7 open question), and whether the column set covers what Accounting needs to see in the CSV for a skipped/failed bundle.
3. On approval we raise a small Spec 01 change-request ticket (ls-db) for the table — like ASCA-34 — and update 02a (record per-bundle outcome) and 02c (read from both sources).

---

## 10. References

- `research/CAP/REF-CAP-13-ASCA-Spec02-Review-Round2-20261005.md` §1 #2 (failure model), §3 (02c per-row status, skipped bundles)
- `research/CAP/REF-CAP-12-ASCA-Spec02-Review-G1-20260928.md` §1 #4 (02c linking columns)
- `projects/asca/specs/asca-spec-02c-allocation-detail-csv/requirements.md` (Req 2.2 / 4.4 / 5.1 — the inconsistency)
- `projects/asca/specs/asca-spec-02a-cap-core-injection/requirements.md` (Req 2.5 — run-level count today)
- Engine: `app/Libs/RevenueAllocation/RevenueAllocationService.php` → `processBundle()` (V-3 skip = `return false` + log only; loud failures throw)
- Schema: `ls-database-migrations` `create_log_alloc_prorations_table` / `create_log_alloc_calculation_runs_table`
