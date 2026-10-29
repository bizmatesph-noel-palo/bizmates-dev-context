# ASCA-8 — Metabase Allocation-Breakdown Base SQL (Code Investigation, 20261015)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report |
| **Status** | Active |
| **Date** | 2026-10-15 (Reported) · 2026-10-15 (Investigated) |
| **Author / Reporter / Investigator** | Throy Embudo, Developer |
| **Assisted by** | Kiro (code analysis) |
| **Audience** | Dev team, Lead (Noel), Accounting (via Kuroda-san) |
| **Environment** | Code trace — `accounting_related_system_for_freee`, `ls-database-migrations` (read-only) |
| **JIRA** | [ASCA-8](https://bizmates.atlassian.net/browse/ASCA-8) (Metabase breakdown) · [ASCA Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) |

---

## What ASCA-8 is

ASCA-8 is the **Metabase allocation-breakdown** deliverable for Accounting — the resolution of
open question **O-6** ("Allocation breakdown for Accounting", resolved 2026-08-17: *CSV in zip +
Metabase*). It is an ad-hoc Metabase saved query that shows Accounting **how** the allocation was
computed: the reference List Price (L), the ratio, the original bundle amount (N), and the
allocated amount (P) per bundle × product × month.

It is listed in `projects/asca/project-context.md` as a pre-existing board item:
> ASCA-1–6 (time-logging buckets), ASCA-7 (Pre-Phase/ASCM link, DEVOPS-6415), **ASCA-8 (Metabase breakdown)**. All unassigned unless noted.

The ASCA-8 breakdown must reconcile **exactly** with the existing `DailyRateCalculation.csv`
(Spec 01 Req 11), never diverging by ¥1 from what the engine wrote back.

---

## Trigger for this investigation

Hypothesis under test: *"the base SQL for the ASCA-8 breakdown is being used in
`accounting_related_system_for_freee`, probably in the SendJournals query."*

**Result: the hypothesis is only partially right.** The SendJournals flow produces the data the
breakdown reconciles against, but it contains **no List-Price (`mst_new_price_listing`) query** —
the ASCA-8 breakdown's List-Price side is a separate Metabase artifact, not application code.

---

## Evidence

Confidence marks: ✅ confirmed in code / 🟡 representable but unverified / 🔴 not found in code.

### 1 — SendJournals is a data *producer*, not the breakdown SQL ✅

`SendJournalsDataLogic::execute()` (the Final batch) calls, in order:
`CommonUtil::createDailyRateCalculation()` → `ZipanUtil::createDailyRateCalculation()` →
Freee journaling → balance transition → `createSendMailAttacheFile()` (CSV + zip + email).

The daily-rate / sum data (the CSV source) is built in
`CommonUtil::createDailyRateCalculation($targetYm, $targetStartDate, $targetEndDate, $preFlg)`:

- Reads charges via `TrnCharge::getTrnChargeList($targetStartDate, $targetEndDate)` — this gives
  **N** (`trn_charge.paid_price`) and `MstProduct` for `product_type`.
- Prorates and writes `log_daily_rate_calculation` (or `_pre` when `$preFlg`).
- **ASCA 02a injection** overwrites N→P in-place for CAP bundles via
  `app(AllocationInjector::class)->allocate($targetYm, $preFlg)` — positioned after the write-N
  loop and before the sum build, so `log_sum_calculation` reads the overwritten P.
- Builds `log_sum_calculation` + `log_sum_calculation_history`.

**No `mst_new_price_listing` read occurs anywhere in this path.** The app never reads List Price L
to produce journals or the CSV — it only works with N (then P after injection).

### 2 — The only `mst_new_price_listing` touch in the accounting repo is the seeder ✅

Repo-wide search for `mst_new_price_listing` in `accounting_related_system_for_freee` hits exactly
one place: `database/seeders/ReferencePriceSeeder.php::resolveAppReferencePrice()`.

- It reads `price` where `product_id = 10022` and `price_flag = 2` purely to **seed**
  `mst_alloc_reference_prices` (the engine's L source).
- Purpose is parity: the seeded `reference_price` equals `mst_new_price_listing.price` so the
  engine's floored P matches what the ASCA-8 breakdown (which reads L from `mst_new_price_listing`)
  recomputes — no ¥1 divergence (Spec 01 Req 4.3, 4.4).
- Coaching 15min (10005) ¥18,000 and 30min (10015) ¥36,000 are seeded from confirmed constants
  (single listing row, no `price_flag` to disambiguate).

### 3 — Where the ASCA-8 breakdown's data actually comes from 🟡

The breakdown is a Metabase query over the Bizmates DB, joining:

| Breakdown column | Source |
|---|---|
| 参照価格 (L / List Price) | `mst_new_price_listing.price` (resolved on the **last calendar day of `target_ym`**) |
| 配分比率 (ratio) / 配分後金額 (P) / 元金額 (N) | `log_alloc_prorations` (engine write-back) — or `v_alloc_prorations_active` for the active Final run |
| Paid Amount / contract dates / days-in-month | `log_daily_rate_calculation` + `trn_charge`, joined at report time |
| Reconciliation target | existing `DailyRateCalculation.csv` (from `log_daily_rate_calculation` / `log_sum_calculation`) |

The List-Price resolution date is the single deterministic definition fixed during G1
(REF-CAP-10): the "target date" is the **last calendar day of `target_ym`**, and it must match
how the engine's reference-price resolution picks its row.

### 4 — The in-zip AllocationDetail CSV is a *different* deliverable (Spec 02c) 🟡

Not to be confused with ASCA-8:

- **ASCA-8** = the Metabase saved query (ad-hoc checks, post-deployment).
- **Spec 02c** = `RevenueAllocationCsvService::createAllocationDetailFile()` adds
  `{YYYYMM}_10_AllocationDetail({execDate}).csv` to the existing zip via the extracted
  `ArchiverService` / `MailerService`. Config entry `allocationDetailFile` in `config/const.php`.
- Both read `log_alloc_prorations` / `v_alloc_prorations_active` and share the same columns, but
  one rides the email zip and the other lives in Metabase. O-6 was resolved with **both** channels.

---

## Conclusion

| Question | Answer |
|---|---|
| Is ASCA-8's base SQL in `accounting_related_system_for_freee`? | **No** — it is a Metabase artifact. The repo only produces the reconciliation inputs. |
| Is it in the SendJournals query? | **No** — SendJournals produces N/P and the CSV, but reads no List Price. |
| Does the repo read `mst_new_price_listing`? | **Only** in `ReferencePriceSeeder` (to seed engine L for parity), never in the journaling/CSV path. |
| Where does the breakdown's L come from? | `mst_new_price_listing.price`, resolved on the last calendar day of `target_ym`. |
| Where do ratio / N / P come from? | `log_alloc_prorations` (or `v_alloc_prorations_active`), engine write-back. |

**Status: superseded by direct ticket investigation.** The paragraphs above were written
BEFORE the actual ASCA-8 ticket and its sample attachment were read, from secondary
spec/design-doc references. They turned out to describe a plausible but NOT-exactly-right
shape (extra columns, English-leaning framing, wrong List-Price resolution date applied to
the wrong table). **See `version-history.md` in this folder for the real, ticket-verified
story** — four iterations (v1→v4), each one driven by a concrete new piece of evidence
(the real ticket text, the real sample Excel, a schema check against the Spec 02b refund
design). The current query is `asca8-allocation-breakdown-v4.sql`.

Short version of what changed since this report's "Deliverable" section below (which is
kept only for history and should NOT be used to understand the current query):

- The real ticket (read directly via Jira REST API) specifies exactly 12 columns —
  Target Month, Student ID, Order No, Product Name, Charge ID, Contract Start/End Date,
  Contract Days, Days, List Price, Paid Amount, Recognized Revenue Amount — not the
  reconciliation-diff shape drafted below.
- The real sample attachment (`asca_metabase_allocation_sample_CAP_2026-10-15.xlsx`, saved
  in this folder) uses Japanese headers and confirms Product Name is bundle-derived (the
  App row borrows its paired coaching's minute suffix).
- The real sample's refund scenarios proved the daily-rate-log join must use
  `log_alloc_prorations.asc_source_id` (the exact source row id), not a compound business
  key — a refund inserts a second daily-rate-log row that shares `(charge_id, target_ym,
  product_id)` with the original row it refunds.

---

## Deliverable (HISTORICAL — v1 draft, see version-history.md for the current query)

Built from the house precedent **ASC-271** (flat `SELECT` mirroring a CSV's columns, `コンテンツ`
label column, keyed on `target_ym`) and verified against the real schema:

- `log_alloc_prorations` + `log_alloc_calculation_runs` + `v_alloc_prorations_active` (migrations
  `2026_06_25_1000*`, view SQL in `database/migrations/sql/view-table-migration.sql`)
- `mst_alloc_reference_prices` (effective-dated L), `mst_new_price_listing` (NOT effective-dated:
  keyed `country_id/product_id/price_flag/tier`, `status` flag, `price`)
- `trn_charge.student_id` / `trn_charge.plan_id`, `log_daily_rate_calculation.student_id`

Key design decisions baked into the query:

1. **Reads the view, does not re-implement run selection.** `v_alloc_prorations_active` already
   resolves the active Final run (`status IN (2,4)`, `run_type = 2`, `superseded_by_run_id IS NULL`,
   MAX(id) per month — ASCA-34 / ASCA-68). The query just decorates it with labels + context.
2. **The reconciliation column is the point.** `参照価格(L_engine)` (`v.reference_price`, the seeded
   weight the engine used) sits next to `参照価格(L_listing)` (`mst_new_price_listing.price`, the live
   list price), with `参照価格差分` = the difference. `0` across the board proves the no-¥1-divergence
   invariant Accounting cares about.
3. **Correction vs. the earlier assumption:** `mst_new_price_listing` has **no** date columns, so
   the "last calendar day of target_ym" resolution date (REF-CAP-10) applies to
   `mst_alloc_reference_prices`, not the listing table. The listing L is matched on
   `country_id = 86`, `price_flag = 2`, `tier = 1`, `status = 1`.
4. **`plan_id` is joined back from `trn_charge`** because it is dropped before the daily log (Q5 of
   the 2026-09-04 G1 investigation).
5. **CAP-only** (`bundle_type = 1`); `{{target_ym}}` is a Metabase optional text filter.

**NOTE: this v1 shape was superseded — the real ticket does not ask for these exact columns.
Do not use this section to understand the current (v4) query; read `version-history.md`.**

---

## Files examined (across the full investigation, v1 through v4)

- `accounting_related_system_for_freee/app/Libs/SendJournalsDataLogic.php`
- `accounting_related_system_for_freee/app/Console/Commands/SendJournalsDataCommand.php`
- `accounting_related_system_for_freee/app/Libs/CommonUtil.php` (`createDailyRateCalculation`,
  `getContractDateInfoList`)
- `accounting_related_system_for_freee/app/Libs/RevenueAllocation/AllocationInjector.php`
- `accounting_related_system_for_freee/database/seeders/ReferencePriceSeeder.php`
- `accounting_related_system_for_freee/.kiro/specs/asca-spec-02b-refund-allocation/design.md`
- `ls-database-migrations/database/migrations/2026_06_25_1000*_create_log_alloc_*` (prorations,
  calculation runs, reference prices)
- `ls-database-migrations/database/migrations/sql/view-table-migration.sql`
  (`v_alloc_prorations_active` definition)
- `ls-database-migrations/tests/Unit/Database/AllocProrationsActiveViewTest.php`
- `ls-database-migrations/database/migrations/2025_07_24_061619_create_mst_new_price_listing_table.php`
- `bizmates-dev-context/projects/asca/project-context.md`
- `bizmates-dev-context/projects/asca/specs/asca-spec-01-foundation/{requirements,design}.md`
- `bizmates-dev-context/docs/asc-projects-master-timeline.md`
- **Jira ASC-151, ASC-271** (house precedent for Metabase verification queries)
- **Jira ASCA-8** (the real ticket — summary, description, comment thread, attachment list),
  read directly via the Jira REST API using credentials in `.kiro/settings/mcp-jira.env`
- **The real ASCA-8 sample attachment** (`asca_metabase_allocation_sample_CAP_2026-10-15.xlsx`,
  attachment id 129138), downloaded via the Jira REST API and decoded; saved alongside this
  report for future reference
