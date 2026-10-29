# ASCA-8 Metabase breakdown query — version history

Tracks each revision of the ASCA-8 CAP allocation-breakdown SQL so we keep a trail
of what changed and why. Newest first. The **CURRENT** version is the one to ship;
older versions are kept for history and must not be deployed.

| Version | File | Date | Status | Summary |
|---|---|---|---|---|
| v4 | `asca8-allocation-breakdown-v4.sql` | 2026-10-15 | **CURRENT** | Fixed daily-rate join to use `asc_source_id` (not a compound key) after the real sample's refund rows proved it ambiguous. Verified formula + Product Name against real sample numbers. |
| v3 | `asca8-allocation-breakdown-v3.sql` | 2026-10-15 | Superseded | Japanese headers + bundle-aware Product Name, but reconciled against the OLD (Sep-3) sample, and used a compound-key join that breaks on refunds. |
| v2 | `asca8-allocation-breakdown-v2.sql` | 2026-10-15 | Superseded | Ticket column list, but English headers + flat Product Name map. |
| v1 | `asca8-allocation-breakdown.sql` | 2026-10-15 | Superseded | First draft from secondary docs; wrong columns. |

---

## v4 — 2026-10-15 — CURRENT

**Trigger:** a deep-dive re-check. Downloaded the REAL current ticket attachment
directly via the Jira REST API (`GET /rest/api/3/attachment/content/129138`,
`asca_metabase_allocation_sample_CAP_2026-10-15.xlsx`) and decoded it — the earlier
pasted copy had arrived as corrupted binary and v3 was reconciled against the stale
Sep-3 file in `sample_csv/` instead. The real file is now saved alongside this
report as `asca_metabase_allocation_sample_CAP_2026-10-15.xlsx`.

**The real sample has 47 data rows across 9 scenario patterns (P1–P9): standard
full-month, cross-month spanning, first-month 50% discount, cooling-off refund
(same-month and next-month), plan change (15min→30min), contract-type change,
consumption-tax refund, and shareholder-cashback refund.**

**Bug found and fixed — the join key:**

v3 joined `log_daily_rate_calculation` on `(charge_id, target_ym, product_id)`. The
sample's refund rows (e.g. student 900004, pattern P4a) show this key is NOT unique:
a regular App proration row and a new refund-engine App row share the exact same
`charge_id` + `target_ym` + `product_id` in the execution month (confirmed against
the Spec 02b design: `RefundAppRowWriter` **inserts a second daily-rate-log row**
reusing the original App charge's identity, rather than creating a new charge). A
compound-key join either fans out or joins to the wrong row for every refund month.

**Fix:** join on `log_alloc_prorations.asc_source_id` — the literal primary key of
the daily-rate-log row the proration was derived from, which is unambiguous by
construction. `asc_source_table` is also checked to scope the join to the Final
table (this query is Final-only via `v_alloc_prorations_active`).

**Confirmed (not just assumed) against real sample numbers:**

- The App-only-floor formula: `floor(22550 × 3618/21618) = 3773`, Coaching = N − App,
  matches sample rows exactly, including the negative-floor direction on refunds
  (`floor(-20295 × 3618/21618) = -3397`).
- Bundle-aware Product Name: the P5 plan-change scenario (same App product_id,
  "(15分)" before the change, "(30分)" after) proves the suffix must be bundle-derived,
  not a flat per-product map — confirming v3's `group_id` approach was structurally
  right, only the daily-rate join needed fixing.
- Refund rows are recognized in full in the execution month (契約日数 = 日数), not
  day-prorated — read directly off the (now correctly joined) daily-rate columns.

**Still open:** confirm the App-row suffix wording with Kuroda-san (one-line check,
not a structural risk); confirm Spec 02b is deployed (new App row insert) before
relying on refund output; still BLOCKED in dev (CAP ids/plans/charges not seeded per
the ticket's own comment thread) so the query returns empty until that data exists.

---

## v3 — 2026-10-15 — Superseded

**Trigger:** reconciled v2 against the sample Excel
(`sample_csv/asca_metabase_allocation_sample.xlsx`, the Sep-3 version — later found
to be STALE; the real 2026-10-15 sample was not actually read until v4), applying
the ticket's documented "changes" (CAP-only, drop 按分基準額, Contract Days/Days
order, Paid Amount = N).

**Two changes vs v2 — one cosmetic, one logic:**

1. **Headers → Japanese** (cosmetic): `対象年月, 生徒ID, 発注番号, プロダクト名, チャージID,
   契約開始日, 契約終了日, 契約日数, 日数, 定価, 支払金額, 売上計上額` — matching the sample's row 1
   exactly. v2 used English aliases.
2. **Product Name → bundle-aware** (logic): the sample shows the App row as
   `CAPアプリ(15分)` / `CAPアプリ(30分)` — the same App product_id (10022) with a minute
   suffix that depends on the paired coaching. v2's flat `product_id → name` map
   could not express this. v3 adds a `group_id` subquery (`coaching_in_group`) to find
   the coaching product in the App row's bundle and borrow its suffix. (So the ticket's
   "CAP App (15min)" was NOT a typo.)

**Why superseded:** correct in column shape and Product Name approach, but (a) was
reconciled against the stale Sep-3 sample instead of the real one, and (b) its daily-
rate-log join on `(charge_id, target_ym, product_id)` is ambiguous for refund months
— see v4 for the fix and the evidence. Kept for history; do not ship.

---

## v2 — 2026-10-15 — Superseded

**Trigger:** read the real ASCA-8 ticket from Jira (summary "New Metabase table –
CAP allocation breakdown", description updated 2026-10-15 by Kuroda-san). v1 did not
match the ticket's required columns.

**Produces exactly the ticket's 12 columns, in order:**
Target Month, Student ID, Order No, Product Name, Charge ID, Contract Start Date,
Contract End Date, Contract Days (契約日数), Days (日数), List Price,
Paid Amount (N, before allocation), Recognized Revenue Amount (P, after allocation).

**Key corrections over v1:**

- Added the four daily-proration columns (Contract Start/End Date, Contract Days,
  Days) sourced from `log_daily_rate_calculation` — v1 dropped these entirely.
- `Product Name` as a human string via a product_id → name CASE map — v1 emitted
  product_id + a cap/cip type label instead.
- `Paid Amount` = `log_alloc_prorations.original_amount` (pre-allocation N). Confirmed
  via `AllocationInjector::overwriteDailyRateRows()` that the daily-rate log's
  `paid_price` is overwritten N→P on a Final run, so the log cannot be the N source.
- Dropped v1's invented columns (プロジェクト, run_id, ステータス, L_engine vs L_listing
  diff, ratio, asc_source_*, timestamps). The ticket's column list is tighter and
  asks for a single `List Price` from `mst_new_price_listing`.
- Documented the refund behaviour (negative App row, Spec 02b Req 9) — surfaced with
  no special-casing, contingent on Spec 02b being deployed.

**Still open (see the OPEN ITEMS block at the bottom of the v2 SQL):** the attached
sample Excel (authoritative, updated 2026-10-15) has not been seen; Product Name
wording, the daily-rate join cardinality, and Spec 02b refund rows need confirming.
The ticket is also BLOCKED in dev (CAP ids / plans / charges not seeded), so the
query returns empty until that data lands — expected.

---

## v1 — 2026-10-15 — Superseded

**Context:** drafted BEFORE the ASCA-8 ticket was read, from the Spec 01 Req 11
references, the `asc-allocation-framework-technical-design.md`, and the
`csv-generation.md` steering. Verified against real schema (migrations, the
`v_alloc_prorations_active` view, `mst_new_price_listing`), so it is structurally
sound — it just answers a slightly different question than the ticket asks.

**Why superseded:** compared against the ticket it (a) was missing Contract Start/End
Date, Contract Days, Days; (b) output product_id/type instead of a Product Name
string; (c) added columns the ticket does not request; (d) framed List Price as an
engine-vs-listing reconciliation diff rather than the single `List Price` column the
ticket defines. Kept as history; do not ship.
