# CAP/CIP Allocation Detail — New Metabase Table Query (20260901)

**Reported by:** Accounting team (via ticket description)
**JIRA Ticket:** ASC-XXX (to be assigned)
**Investigated by:** (assign)
**Date:** 2026-09-01
**Environment:** Metabase (production, read-only queries)
**Type:** Investigation — new query, mirrors the existing ASC DailyRateCalculation query pattern

---

## Summary

The accounting team wants a new **Metabase table** that shows, step by step, how the CAP/CIP coaching charge is split into **Coaching revenue** and **App revenue** for each student. Today the `DailyRateCalculation.csv` shows only the final split amount (the recognized revenue per row). It does not show the inputs (list prices, days, allocation base) that produced that amount.

This new query surfaces the full allocation basis so accounting can audit each row. It is a **read-only reporting query** — it does not change any batch logic. It is described as "the same query as the previous ASC implementation," meaning it reuses the existing DailyRateCalculation query shape (target month, student, charge, contract dates, days, paid amount) and adds the CAP/CIP allocation columns (list price, allocation base, recognized revenue split).

**This aligns with the "AllocationDetail CSV / allocation basis" output that was already anticipated in the ASC-CAP design** (see REF-CAP-04 `asc_alloc_prorations`, REF-CAP-07 Section 11 Q4 "Does Accounting need the allocation basis in a monthly CSV?"). This ticket is the Metabase equivalent of that basis-detail output.

**One material discrepancy must be resolved before building the query** — the reference-price source described in the ticket does not match what the CAP research has confirmed. See "Open Question — Reference Price Source" below.

---

## What the Query Must Produce

Two rows per CAP/CIP bundle per target month — one **App** row and one **Coaching** row — each with the full calculation basis.

| Column | Meaning | Source / Formula |
|---|---|---|
| Target Month | Accounting month (`YYYYMM`) | `log_daily_rate_calculation.target_ym` |
| Student ID | Student | `trn_charge.student_id` |
| Order No | B2B order number; empty for B2C/B2E | `trn_charge.order_no` |
| Product Name | e.g. "CAP Coaching (30min)" / "CAP App" | `mst_product.name` (via `trn_charge.product_id`) |
| Charge ID | The charge | `trn_charge.id` |
| Contract Start Date | Charge period start | `trn_charge.start_date` |
| Contract End Date | Charge period end | `trn_charge.end_date` |
| Contract Days | Total days in the charge period | `DATEDIFF(end_date, start_date) + 1` (match existing ASC convention) |
| Days | Days of the charge that fall in the target month | Same day-count used by existing daily proration |
| List Price | Reference price used as the allocation weight | ⚠️ **see Open Question** — ticket says `mst_new_price_listing.price` (App = `price_flag = 2`); CAP research says ¥3,980 from `asc_alloc_reference_prices` / `mst_product_price` |
| Paid Amount | Amount paid this month for this charge, after daily proration | `trn_charge.paid_price` prorated = the `paid_price` already in `DailyRateCalculation.csv` (must match exactly) |
| Allocation Base Amount | `floor(Paid Amount × List Price(this product) / (List Price Coaching + List Price App))` — **App row only** | Allocation formula (Option C, proportional) |
| Recognized Revenue Amount | App row = Allocation Base Amount; Coaching row = Paid Amount − App row's Recognized Revenue | Final written-back split (P_app / P_coaching) |

### Formula (confirmed in CAP research — REF-CAP-05 §"Option (C)", REF-CAP-04 §"Formula")

```
P_app      = floor( N × L_app / (L_coaching + L_app) )
P_coaching = N − P_app          (Coaching absorbs the rounding remainder)
```

- `N` = Paid Amount for the coaching charge (the prorated `paid_price` in DailyRateCalculation)
- `L_app`, `L_coaching` = list/reference prices (allocation weights)
- Rounding is `floor()` — confirmed decision (REF-CAP-04 D-8), and the remainder is absorbed by the Coaching row so `P_app + P_coaching = N` exactly.

This exactly matches the ticket's "Allocation Base Amount" (App-only floor) and "Recognized Revenue Amount" (App = base, Coaching = paid − app) columns.

---

## Where This Sits vs the Existing ASC Query

The "previous ASC implementation" being referenced is the existing **DailyRateCalculation** query/CSV, sourced from `log_daily_rate_calculation`. The new query is that same query with allocation-basis columns added. Confirmed anchors:

- `Paid Amount` column **must equal** the `paid_price` already present in `DailyRateCalculation.csv` for the same charge and month. The design writes the *allocated* P values back into `log_daily_rate_calculation` (Option 1 / Overwrite — REF-CAP-07), so:
  - After allocation runs, `log_daily_rate_calculation.paid_price` for the Coaching row holds **P_coaching**, and for the App row holds **P_app**.
  - The **original N** (pre-split coaching amount) is preserved in `asc_alloc_source_documents` / `asc_alloc_prorations` (REF-CAP-04, REF-CAP-07).
- Therefore the Metabase query needs the **basis inputs** (`N`, `L_app`, `L_coaching`, `Allocation Base`) which live in the `asc_alloc_*` audit tables, joined to `trn_charge` / `mst_product` for the display columns.

**Implication:** this query depends on the ASC-CAP allocation batch having run and populated the `asc_alloc_*` tables. It is not a pure `log_daily_rate_calculation` query — it must join the allocation audit rows to recover `N` and the list prices. If accounting wants it to work purely off the log table before the `asc_alloc_*` tables exist, that changes scope (would require recomputing the split inline in SQL from a hardcoded reference-price table).

---

## Bundle / Detection Basis (confirmed)

- CAP App product: **10021** (¥0 in `trn_charge`, companion pattern) — REF-CAP-05, REF-CAP-08
- CAP plan_ids: **1016–1027** (12 plans) — REF-CAP-08
- CIP coaching product: **10022**, CIP plan_ids **1028–1032**, App also **10021** — REF-CIP-03
- Coaching products for CAP: **10005** (15min) / **10015** (30min) — REF-CAP-06/08
- Detection: `product_id = 10021` (App) as primary, `plan_id` enum as project discriminator (CAP vs CIP) — REF-CAP-07 Lead Dev Assessment, REF-CAP-08 §3
- Reference prices (tax-inclusive) confirmed:
  - App (10021): **¥3,980**
  - Coaching 15min (10005): **¥19,800** (¥18,000 ex-tax)
  - Coaching 30min (10015): **¥39,600** (¥36,000 ex-tax)
  - CIP coaching (10022): **¥88,000** — REF-CIP-03

---

## Open Question — Reference Price Source (MUST RESOLVE BEFORE BUILDING)

The ticket says:

> "List Price — The reference price used for allocation. Comes from `mst_new_price_listing.price`. For App, use the record where `price_flag = 2`."

This **conflicts** with the confirmed CAP research:

| Aspect | Ticket description | CAP research (REF-CAP-04/05/06/08) |
|---|---|---|
| App reference price value | Row where `price_flag = 2` in `mst_new_price_listing` | **¥3,980 tax-incl** (standalone selling price) |
| Source table | `mst_new_price_listing.price` | `asc_alloc_reference_prices` (effective-dated master) — REF-CAP-04 D-2; App value originates from `mst_product_price` |
| What `price_flag = 2` actually is | (implied App list price) | **Half-price campaign tier** for the *combined* price — REF-CAP-05 §"Pricing Data". `price_flag = 4` is the CAP combined price; `price_flag = 2` is a campaign tier, **not** the App standalone reference price |

**Risk:** REF-CAP-05 explicitly states `¥2,500` (the `price_flag = 3/4` App-implied contribution) "is irrelevant to us — it's a display/package_price reconciliation value only," and that the allocation weight is **¥3,980**. If the query reads `mst_new_price_listing` with `price_flag = 2`, it will pull a **campaign-tier combined price**, not the App standalone reference price, and the split will be wrong.

**Action:** Confirm with Kuroda-san / accounting which is authoritative for the Metabase column:
1. Is "List Price" meant to be the **allocation weight** the batch actually used (¥3,980 App / ¥19,800 / ¥39,600 / ¥88,000 coaching, from `asc_alloc_reference_prices`)? — this is what makes the recognized-revenue math reconcile.
2. Or does accounting specifically want to *display* a `mst_new_price_listing` value for reference, even though it is not the weight used in the formula?

If (1): read from `asc_alloc_reference_prices` (or `asc_alloc_prorations.reference_price`, which stores the weight actually applied per row). If (2): the "Allocation Base Amount" column will not reconcile against the displayed List Price and that must be called out to accounting.

---

## Proposed Query Shape (pending reference-price decision)

```sql
-- CAP/CIP Allocation Detail (Metabase)
-- One App row + one Coaching row per bundle per target month.
-- Depends on asc_alloc_* tables populated by the ASC-CAP allocation batch.

SELECT
    p.target_ym                          AS `Target Month`,
    c.student_id                         AS `Student ID`,
    c.order_no                           AS `Order No`,
    mp.name                              AS `Product Name`,
    c.id                                 AS `Charge ID`,
    c.start_date                         AS `Contract Start Date`,
    c.end_date                           AS `Contract End Date`,
    (DATEDIFF(c.end_date, c.start_date) + 1) AS `Contract Days`,
    p.days                               AS `Days`,
    p.reference_price                    AS `List Price`,     -- weight actually applied (see Open Question)
    p.n_amount                           AS `Paid Amount`,    -- = log_daily_rate_calculation paid_price basis (N)
    CASE WHEN c.product_id = 10021 THEN p.allocation_base END AS `Allocation Base Amount`,
    p.p_amount                           AS `Recognized Revenue Amount`  -- P_app / P_coaching
FROM asc_alloc_prorations p
JOIN trn_charge  c  ON c.id = p.charge_id
JOIN mst_product mp ON mp.id = c.product_id
JOIN asc_alloc_groups g ON g.id = p.group_id
WHERE g.target_ym = {{target_month}}
ORDER BY c.student_id, c.order_no, (c.product_id = 10021) DESC;  -- coaching first, app second
```

> Column names (`reference_price`, `n_amount`, `p_amount`, `allocation_base`, `days`) are **placeholders** — must be confirmed against the final `asc_alloc_prorations` migration in `ls-database-migrations` once the `asc_alloc_*` tables are created (REF-CAP-04 Step 1, blocked on O-3 naming). The `mst_new_price_listing` path in the ticket is intentionally **not** used here pending the Open Question resolution.

---

## Dependencies & Blockers

| ID | Dependency | Status | Blocks |
|---|---|---|---|
| B-1 | `asc_alloc_*` tables created + populated (esp. `asc_alloc_prorations`) | ⚠️ Not built yet — REF-CAP-04 Step 1, blocked on O-3 naming (`asc_alloc_` prefix agreement) | Query cannot join basis columns |
| B-2 | Reference-price source for "List Price" column | ⚠️ **OPEN** — ticket says `mst_new_price_listing` flag 2; research says ¥3,980 / `asc_alloc_reference_prices` | Correct List Price + reconciling Allocation Base |
| B-3 | Final `asc_alloc_prorations` column names | ⚠️ Pending migration | Exact SELECT columns |
| B-4 | Day-count convention for `Days` / `Contract Days` | Reuse existing ASC `getContractDateInfoList()` day logic — REF-CAP-05 §N-3 | Match DailyRateCalculation exactly |
| B-5 | Does accounting want Pre, Final, or both? | Open | Which table (`log_daily_rate_calculation` vs `_pre`) the basis aligns to |

---

## Scope Assessment

| Aspect | Assessment |
|---|---|
| Is this a code change to the batch? | **No** — it is a Metabase reporting query only. |
| Is this net-new? | Partly — reuses the DailyRateCalculation query shape; adds allocation-basis columns from `asc_alloc_*`. |
| Does it depend on ASC-CAP allocation being implemented? | **Yes** — the `asc_alloc_*` tables must exist and be populated. Cannot ship before that. |
| Reference-price discrepancy | **Must resolve (B-2)** before the numbers will reconcile. |
| Multi-tenancy | Bizmates-only. CAP/CIP do not exist on Zipan (REF-CAP-07 N-2). |

---

## Next Steps

- [ ] Assign JIRA number (ASC-XXX) and link under the ASC-CAP epic.
- [ ] **Resolve B-2 with Kuroda-san:** is "List Price" the allocation weight (`asc_alloc_reference_prices`, ¥3,980 App) or a literal `mst_new_price_listing` display value? Flag that `price_flag = 2` is a campaign tier, not the App standalone price.
- [ ] Confirm whether this Metabase table is the same deliverable as REF-CAP-07 Q4 "allocation basis CSV" (Nemoto-san). If yes, align columns so CSV and Metabase match.
- [ ] Confirm Pre vs Final (B-5).
- [ ] Once `asc_alloc_*` migrations land, finalize the SELECT column names against the real schema (B-1/B-3).
- [ ] Validate: for a sample CAP charge, `Paid Amount` in the new query == `paid_price` in `DailyRateCalculation.csv`; `App Recognized + Coaching Recognized == Paid Amount`.

---

## Cross-Reference

- Formula & options: `[bizmates-dev-context] research/CAP/REF-CAP-05-Upstream-Pricing-Discussion-20260812.md` (Option C)
- DB design (`asc_alloc_*`, `asc_alloc_prorations`, reference prices): `[bizmates-dev-context] research/CAP/REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md`
- Overwrite flow / where allocation is written back into `log_daily_rate_calculation`: `[bizmates-dev-context] research/CAP/REF-CAP-07-Overwrite-Process-Flow-20260812.md`
- Plan_ids / product_ids / reference prices: `[bizmates-dev-context] research/CAP/REF-CAP-08-Requirements-Decision-Log-20260810.md`
- CIP parity (product 10022, plans 1028–1032, ¥88,000): `[bizmates-dev-context] research/CIP/REF-CIP-03-Project-Spec-20260812.md`
- Scope (do not modify existing ASC logic; allocation detail output): `[bizmates-dev-context] research/CAP/REF-CAP-01-ASC-Scope-20260724.md`
- Existing query pattern being mirrored: DailyRateCalculation CSV ← `log_daily_rate_calculation` (see `documentation/01-system-overview.md`)

---

## Data Verification (2026-09-01)

Ran diagnostic queries against the Bizmates DB to confirm what data actually exists. **Finding: this database is in the pre-CAP state — none of the CAP/CIP upstream data is present.**

### What exists

**`mst_product` (product_type = 100 / App):** only the legacy App product.

| product_id | name | product_type |
|---|---|---|
| 10012 | Bizmates Appプレミアムプラン | 100 |

No `10021` (CAP App), no `10022` (CIP coaching). Coaching products present: `10005` (Bizmates Coaching 15分), `10015` (Bizmates Coaching 30分).

**`mst_new_price_listing` (products 10005 / 10012 / 10015):**

| product_id | price_flag | tier | price |
|---|---|---|---|
| 10012 (App) | 2 | 1 | 2,500 |
| 10012 (App) | 3 | 1 | 2,500 |
| 10012 (App) | 3 | 2 | 2,500 |
| 10005 (Coaching 15) | 2 | 1 | 18,000 |
| 10005 (Coaching 15) | 2 | 2 | 9,000 |
| 10005 (Coaching 15) | 3 | 1 | 18,000 |
| 10005 (Coaching 15) | 3 | 2 | 9,000 |
| 10015 (Coaching 30) | 2 | 1 | 36,000 |
| 10015 (Coaching 30) | 2 | 2 | 18,000 |
| 10015 (Coaching 30) | 3 | 1 | 36,000 |
| 10015 (Coaching 30) | 3 | 2 | 18,000 |

`price_flag` per schema: **1 = PayPal OLD, 2 = pre-VPP, 3 = post-VPP**. `tier`: **1 = full, 2 = half**. There is **no `price_flag = 4`** (the "CAP combined price" referenced in REF-CAP-05/06 does not exist in this schema).

### What does NOT exist (all returned empty)

- Product `10021` / `10022` — not in `mst_product`.
- `mst_product_price` for `10021` — empty (the ¥3,980 App reference price from REF-CAP research is NOT in this DB).
- Plans `1016–1032` — not in `mst_plan_content` or `mst_plan`.
- Any `trn_charge` for plans `1016–1032`.
- Any `asc_alloc*` / `%alloc%` tables — the allocation audit tables are not built.

### Implications

1. **No data to report on.** CAP/CIP products, plans, and charges do not exist in this database. The requested Metabase table would return zero rows. Either CAP/CIP is not deployed to this environment, or it was seeded under different IDs than the research states — needs confirmation (which environment this DB is).

2. **No `asc_alloc_*` source.** The step-by-step basis (original N, list price applied, allocation base) has no source table. The allocation batch (REF-CAP-04 Step 1, blocked on O-3) is not implemented here. A basis-detail query cannot read values the batch has not produced.

3. **Reference-price ambiguity is now three-way and material.** The ticket, the CAP research, and this DB disagree:

   | Source | App product | App reference price | From |
   |---|---|---|---|
   | Ticket description | (implied) `price_flag = 2` | resolves to **¥2,500** | `mst_new_price_listing` |
   | CAP research (REF-CAP-04/05/06) | 10021 | **¥3,980** | `mst_product_price` / `asc_alloc_reference_prices` |
   | This DB | only 10012 exists | **¥2,500** (10012, flag 2) | `mst_new_price_listing` |

   The choice changes every App allocation amount. Worked example, Coaching 30min, N = ¥38,500:
   - Ticket ¥2,500: `floor(38,500 × 2,500 / (36,000 + 2,500))` = **¥2,500**
   - Research ¥3,980: `floor(38,500 × 3,980 / (36,000 + 3,980))` = **¥3,832**

   Note the ticket's instruction ("List Price from `mst_new_price_listing`, App = flag 2") is **internally consistent with this DB** (¥2,500 / 10012; coaching ¥18,000 / ¥36,000). This suggests accounting may intend the ¥2,500 legacy-App basis on product 10012 — NOT the ¥3,980 CAP basis on 10021. This contradicts the CAP design docs and must be reconciled with Kuroda-san.

### Verdict on "can the query be built now"

**No — not a correct, runnable production query.** Blocked by, in priority order:
1. Reference-price decision (B-2) — three conflicting sources; changes every number.
2. Source data absent — no CAP/CIP products, plans, or charges in this DB.
3. `asc_alloc_*` tables absent — no basis columns to read (B-1/B-3).

A hardcoded-reference-price draft that recomputes the split inline could be written, but it would return zero rows against this database and would bake in a reference price that is exactly the open question. Not worth locking in until B-2 is answered and CAP/CIP data exists.

### Follow-up questions for accounting / Kuroda-san

- [ ] Which environment/DB should this report target, and is CAP/CIP seeded there? (Here it is not.)
- [ ] **Authoritative App reference price: ¥2,500 (legacy App 10012, `mst_new_price_listing` flag 2) or ¥3,980 (CAP App 10021)?** The ticket implies the former; the CAP design says the latter.
- [ ] Should "List Price" display the value actually used as the allocation weight, or a `mst_new_price_listing` value for reference even if it differs from the weight?
- [ ] Is this Metabase table the same deliverable as the REF-CAP-07 Q4 "allocation basis CSV" (Nemoto-san)? If so, align columns.

---

## Initial Draft Query (2026-09-01)

A first runnable draft is saved alongside this report: **`cap_cip_allocation_detail_query.sql`**.

It computes the split directly from `trn_charge` + `mst_new_price_listing` + `log_daily_rate_calculation`, following the ticket's column definitions (List Price from `mst_new_price_listing` flag 2; Paid Amount read from the daily log so it matches DailyRateCalculation.csv). It does **not** depend on the unbuilt `asc_alloc_*` tables, so it can run before that framework exists.

### Dynamic vs. static behaviour

| Aspect | Behaviour |
|---|---|
| CAP/CIP data absent today | Runs safely, returns **0 rows** (filters on plan_id 1016–1032). |
| CAP/CIP data seeded later | **Self-activates** — same query returns rows, no edit needed. |
| Reference-price decision (¥2,500/10012 vs ¥3,980/10021) | **NOT dynamic** — hardcoded to flag 2 / 10012 remap ([DECISION-1], [FIX-A]). Must be changed by hand if accounting confirms ¥3,980/10021. |
| App list-price source | **NOT dynamic** — remapped to 10012 because 10021 has no price row yet ([FIX-A]). Remove remap once 10021 is priced. |

**Summary:** the query is forward-compatible on data presence (it waits for CAP/CIP automatically), but it does not resolve the missing information — the reference-price choice and the 10021 price-row remap are explicit `[DECISION-1]` / `[FIX-A]` / `[FIX-B]` markers in the SQL that a human must confirm before the amounts are trusted.

### Worked check (Coaching 30min, flag-2 full price)

Paid Amount ¥38,500, App list ¥2,500, Coaching list ¥36,000:
- App Allocation Base = `floor(38,500 × 2,500 / (36,000 + 2,500))` = **¥2,500**
- Coaching Recognized = 38,500 − 2,500 = **¥36,000** → App + Coaching = 38,500 ✅

### Assumptions to confirm

1. Bundle key = `student_id` + `order_no` (NULL-safe) + `target_ym`. If a B2C student can hold two CAP bundles in one month with NULL order_no, this key merges them — would need `plan_id`/App-charge linkage instead.
2. `log_daily_rate_calculation` exposes a `days` column — confirm the exact name against the live schema.
3. `price_flag = 2`, `tier = 1`. Half-price campaign months (tier 2) would need a tier rule.

---

## Sample File Verification (2026-09-01)

Source: `[bizmates-dev-context] sample_csv/asca_metabase_allocation_sample.xlsx` (sheet "ASCA按分明細サンプル" + notes sheet "注記"). This is hand-authored **expected output**, not live data.

### Sample rows (target 202608)

| 生徒ID | 発注番号 | プロダクト名 | チャージID | 契約日数 | 日数 | 定価 | 支払金額(N) | 按分基準額 | 売上計上額 |
|---|---|---|---|---|---|---|---|---|---|
| 100001 | — | CAP Coaching (15分) | 720001 | 31 | 31 | 18000 | 22550 | 18776 | 18777 |
| 100001 | — | CAP App (15分) | 720002 | 31 | 31 | 3618 | 0 | 3773 | 3773 |
| 100456 | 550089 | CAP Coaching (30分) | 731124 | 31 | 27 | 36000 | 36885 | 33516 | 33517 |
| 100456 | 550089 | CAP App (30分) | 731125 | 31 | 27 | 3618 | 0 | 3368 | 3368 |
| 100789 | — | CIP Coaching | 742210 | 31 | 31 | 84020 | 88000 | 84020 | 84020 |
| 100789 | — | CIP App | 742211 | 31 | 31 | 3980 | 0 | 3980 | 3980 |

### Confirmed formula (verified arithmetically against all 3 bundles)

```
S        = L_coaching + L_app
App base      = floor(N × L_app      / S)      -- App 売上計上額 = this
Coaching base = floor(N × L_coaching / S)      -- shown in 按分基準額 for coaching row
Coaching 売上計上額 = N − App base             -- absorbs +1 remainder
```

Results reproduce the sample exactly:
- CAP15: N=22550, S=21618 → App 3773, Coaching base 18776, Coaching recognized 18777 ✓
- CAP30: N=36885, S=39618 → App 3368, Coaching base 33516, Coaching recognized 33517 ✓
- CIP:   N=88000, S=88000 → App 3980, Coaching base 84020, Coaching recognized 84020 ✓

### Corrections to earlier assumptions

1. **Reference prices are EX-TAX and per-project**, and they do **not** match the `mst_new_price_listing` flag-2 rows pulled earlier:
   - CAP App = **3,618** (not 2,500, not 3,980)
   - CAP Coaching 15/30 = **18,000 / 36,000**
   - CIP App = **3,980**, CIP Coaching = **84,020**
   - ⚠️ **Source of these values is still unconfirmed** — 3,618 and 84,020 are absent from the `mst_new_price_listing` rows in the DB. Likely `asc_alloc_reference_prices` master or a config constant. **This is now the key open item** (supersedes the earlier ¥2,500-vs-¥3,980 framing — the real answer is ¥3,618 ex-tax for CAP App).
2. **App list price differs by project** (CAP 3,618 vs CIP 3,980), so it must be resolved from the bundle's coaching product, not from product 10021 alone.
3. **Allocation Base (按分基準額) is populated on BOTH rows** in the sample, not App-only as the ticket text implied.
4. **Paid Amount is the already-daily-prorated N** — confirmed by CAP30 crossing months (contract ¥42,350 → August portion ¥36,885 over 27/31 days).

### Query update

`cap_cip_allocation_detail_query.sql` now contains **two queries**:
- **Query A (before CSV / N state):** `log_daily_rate_calculation` as-is — Coaching = N, App = 0.
- **Query B (after CSV / P state):** the allocation, reproducing the sample above exactly (verified). Reference prices hardcoded per the sample with a clear header note to swap for the authoritative master once located.

### Remaining gaps (updated)

- **Authoritative source of the ex-tax reference prices** (3,618 / 18,000 / 36,000 / 3,980 / 84,020) — not in `mst_new_price_listing`. Blocks moving off hardcoded values.
- **Live CAP/CIP data** — products 10021/10022, plans, charges still absent from the DB.
- **Confirm** Allocation Base should show on the coaching row too (sample = yes; ticket text = App-only).

---

## Provenance of the CAP/CIP product & plan IDs

The IDs hardcoded in the query (`10021`, `10022`, `10005`, `10015`, plans `1016–1032`) come from the CAP/CIP research references in this workspace — **not** from the current database (they are absent there, see Data Verification). Sources:

### Product IDs

| Product ID | Meaning | Where it comes from |
|---|---|---|
| 10021 | CAP/CIP **App** (Bizmatesアプリプレミアム); ¥0 companion charge | `research/CAP/REF-CAP-05-Upstream-Pricing-Discussion-20260812.md` ("App product_id for CAP: 10021 … for CIP: also 10021"); `research/CAP/REF-CAP-06` §"Two-Price Model"; `research/CAP/REF-CAP-08` §2 |
| 10022 | **CIP Coaching** (Coaching Intensive, product_type 9); ¥88,000 | `research/CIP/REF-CIP-03-Project-Spec-20260812.md` §"What CIP Actually Is" (product_id 10022, plans 1028–1032) |
| 10005 | CAP **Coaching 15分** (product_type 9) | `research/CAP/REF-CAP-06` plan table + `research/CAP/REF-CAP-08` §1; confirmed present in DB (`mst_product`) |
| 10015 | CAP **Coaching 30分** (product_type 9) | same as above; confirmed present in DB |
| 10012 | **Legacy** App (product_type 100) — retained, NOT a CAP/CIP target | `research/CAP/REF-CAP-08` §2 ("Legacy 10012 retained untouched"); the only product_type=100 row in the DB today |

### Plan IDs

| Plan range | Meaning | Where it comes from |
|---|---|---|
| 1016–1027 | 12 **CAP** bundle plans (Coaching + App, some with Lesson/FVP) | `research/CAP/REF-CAP-08-Requirements-Decision-Log-20260810.md` §1 "Plan Table — Final" (full product breakdown per plan, PO-confirmed 2026-07-31); also `research/CAP/REF-CAP-06` §"Confirmed CAP Plan IDs" |
| 1028–1032 | 5 **CIP** bundle plans (Coaching Intensive + App) | `research/CIP/REF-CIP-03-Project-Spec-20260812.md` §"CIP Plans (1028–1032)" |

### Reference prices used in the query

| Value | Applies to | Where it comes from |
|---|---|---|
| 18,000 / 36,000 (ex-tax) | CAP Coaching 15 / 30 | Sample xlsx `定価` column; matches `mst_new_price_listing` flag-2 for 10005/10015 in DB |
| 3,618 (ex-tax) | CAP App | **Sample xlsx only** — ⚠️ not found in `mst_new_price_listing` (which has 2,500 for legacy 10012). Authoritative source unconfirmed. |
| 3,980 (ex-tax) | CIP App | Sample xlsx; matches `research/CIP/REF-CIP-03` ("App ¥3,980") |
| 84,020 (ex-tax) | CIP Coaching | **Sample xlsx only** — ⚠️ not in DB. (Note: REF-CIP-03 states ¥88,000 *tax-inclusive*; 84,020 is the ex-tax figure. 84,020 × 1.1 ≈ 92,422 ≠ 88,000, so the relationship needs confirming.) |

### Caveats on provenance

1. **These IDs are from research docs, not verified against production data** — the CAP/CIP rows do not exist in the DB checked on 2026-09-01. If upstream seeded different IDs, the query filters would silently return nothing (or the wrong set).
2. **Detection basis:** the research (REF-CAP-07 Lead Dev Assessment, REF-CAP-08 §3) recommends detecting bundles by `product_id = 10021` (App) + `plan_id` enum for CAP-vs-CIP. The query uses the `plan_id BETWEEN 1016 AND 1032` range as a simple proxy — before production use this should be replaced with the explicit plan-id enums (`CoachingAndAppPlanEnum` 1016–1027 / `CoachingIntensivePlanEnum` 1028–1032) so a stray plan_id in that numeric range can't leak in.
3. **¥84,020 vs ¥88,000 discrepancy** (ex-tax vs tax-incl) between the sample and REF-CIP-03 should be reconciled with the reference-price source (open item #5).
