# ASCA Spec 01 — Code Investigation for G1 Open Questions (20260904)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report |
| **Status** | Active |
| **Date** | 2026-09-04 (Reported) · 2026-09-04 (Investigated) |
| **Author / Reporter / Investigator** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro (code analysis) |
| **Audience** | Kuroda-san (PM), Dev team (Throy) |
| **Environment** | Code trace — `accounting_related_system_for_freee`, `ls-database-migrations` (read-only) |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) |

---

## Summary

Answers Kuroda-san's G1 open items (2)-7 (product_type) and (2)-8 (bundle pairing) from the code. Key finding: the interim `(student_id, order_no)` bundle key is too loose — `plan_id` must be in the key.

| # | Question | Result |

| # | Question | Result |
|---|---|---|
| 1 | contract_type code values | ✅ **Confirmed** from `config/const.php` |
| 2 | product_type Coaching=9 / App=100 | 🔴 **Unconfirmed in code** — not an enum; lives in `mst_product` DB rows / spec, not code |
| 3 | order_no structure & grouping | ⚠️ **Important finding** — order_no is nullable, non-unique; existing code groups by **order_no alone** and explicitly handles multiple charges sharing one order_no |
| 4 | App ¥0 companion charge pattern | 🟡 Schema supports it; **not enforced in code** — needs data/spec confirmation |
| 5 | plan_id availability in pipeline | ✅ **Confirmed** — `plan_id` is on `trn_charge` and fetched, but **dropped before `log_daily_rate_calculation`** |

**Two decisions this drives:**
1. **Detection must NOT group by `(student_id, order_no)` alone** — see Q3. That grouping is too loose and contradicts how the existing system already treats order_no (it aggregates *across* products/charges sharing one order_no). This validates Kuroda-san's (2)-8 concern with concrete evidence.
2. **`plan_id` is dropped before the daily log** (Q5) — so allocation's detection query MUST join back to `trn_charge` for plan_id (already in the design), and the bundle key should incorporate `plan_id` and likely `charge`-level linkage, not order_no alone.

---

## Evidence

Per-question findings from the code trace. Each marks confidence (✅ confirmed in code / 🔴 unconfirmed in code / 🟡 representable but unverified).

### Q1 — contract_type values ✅ CONFIRMED

`config/const.php` → `contractType`:

| Value | Label | Notes |
|---|---|---|
| 0 | B2C | stored on `trn_charge.contract_type` |
| 1 | B2B | stored |
| 2 | B2B2C | stored |
| 3 | Partner | **derived**, not stored — `getSegment2Id()` returns 3 when `department_id` ∈ Partner depts (21/22/23) |
| 4 | B2B_App | **derived**, not stored — special segment-2 tag (DEVOPS-6287), only when B2B + Bizmates App |

- The DB column `trn_charge.contract_type` only ever stores **0/1/2** (migration comment `0=B2C/1=B2B/2=B2B2C`, default 0).
- 3 and 4 are computed at journal time. **Implication for the spec:** our `contract_type` column on alloc tables holds 0/1/2 as read from the charge; Partner/B2B_App are Freee-mapping-time derivations (Spec 02), not stored values. TINYINT is fine.

### Q2 — product_type 9 / 100 🔴 UNCONFIRMED IN CODE

- `mst_product.product_type` is a plain `integer` column. Migration comment only documents `1=Skype, 2=Video`. Code special-cases `8` (Bizmates Test).
- No constant/enum for `9` (Coaching) or `100` (App) anywhere in either repo. No grep hit for `10021`/`10022`/`Coaching`/`App` as product_type values.
- freee-facing types are separate master IDs in `config/code.php` (`bizmatesCoaching=191155067`, `BizmatesApp=236270504`) — NOT the internal product_type ints.

**Conclusion:** Coaching=9 / App=100 are **data facts in `mst_product` rows** (or an upstream spec), not code constants. To confirm, query `mst_product` for the CAP/CIP product_ids (10005/10015/10025/10022) and read their `product_type`. **This is what to verify with the DB / CAP team for (2)-7** — the codebase can't answer it.

### Q3 — order_no ⚠️ KEY FINDING (drives (2)-8)

Schema: `order_no bigInteger NULLABLE`, single index `idx_orderno`, comment "発注番号（B2B/B2B2Cのみ)". **No unique constraint.** Comment says order_no is **only for B2B/B2B2C** — i.e. B2C charges have NULL order_no.

Existing code groups by **order_no alone**, and is explicitly built to handle multiple charges/products under one order_no:
- `TrnCharge::getTrnChargeForOrderNo()` → `SUM(paid_price) ... GROUP BY order_no`
- `getPaidPriceSumList()` groups by `target_ym, order_no, product_type, contract_type, ...` (product_type included → different products under one order_no become separate rows)
- `SendJournalsDataLogic` accumulates journals keyed by order_no and has explicit "same order_no gets overwritten/added" handling (T3 wash logic)

**Implications:**
- **`(student_id, order_no)` is too loose** — confirmed. For B2C, `order_no` is NULL (so grouping collapses many B2C students'... no — grouped with student_id, but order_no NULL means the key is `student_id|null`, which is fine for a single B2C contract but breaks if a B2C student has two contracts in a month).
- More importantly, the existing system's own vocabulary treats one order_no as potentially spanning multiple products/charges — so a CAP bundle under one order_no is plausible, but so is "two different plans under one order_no," which would mis-pair.
- **Detection needs `plan_id` in the key** (and possibly charge-level linkage / contract period) — not order_no alone.

### Q4 — App ¥0 companion pattern 🟡 SCHEMA-SUPPORTED, NOT ENFORCED

- No code encodes "coaching paid + companion App ¥0." No 10021/10022 references.
- `mst_plan_content` (plan_id → product_id, one-to-many) makes a plan bundling coaching + App structurally possible; a bundle appears as **multiple `trn_charge` rows** (same student, same `plan_id`, per-product, each with own `paid_price`; App row can be 0 since default is 0).
- `getTrnChargeList` fetches all rows with `trn_charge.*` (plan_id present) but does **not** pair coaching+App.

**Conclusion:** the ¥0-App-companion assumption is **representable but unverified**. Confirm against `mst_plan_content` for CAP plans (1016–1027) + sample `trn_charge` data, or with the CAP team.

### Q5 — plan_id in the pipeline ✅ CONFIRMED (schema gap)

- `getTrnChargeList` selects `trn_charge.*` → `plan_id` **is** available per fetched row.
- `createDailyRateCalculation` inserts into `log_daily_rate_calculation` **without plan_id** — the log has no plan_id column.

**Implication:** allocation detection must join the daily log back to `trn_charge` on `charge_id` to recover `plan_id` (the design already does this — confirmed correct). Bundle detection cannot rely on the log alone.

---

---

## Analysis

- **The bundle key was the material risk.** The interim design keyed bundles on `(student_id, order_no)`. Q3 shows `order_no` is nullable (NULL for B2C), non-unique, and already used by the existing system to aggregate *across* products — so it can't safely identify a single Coaching+App pair on its own.
- **The log-table plan_id gap is structural, not incidental.** Q5 confirms `plan_id` never reaches `log_daily_rate_calculation`, so any detection reading the log alone is blind to which plan a row belongs to. Detection must join back to `trn_charge`.
- **Two items can't be answered from code at all** (Q2 product_type, Q4 ¥0-App pattern) — they are data/spec facts, so the honest status is "unconfirmed here," to be verified against the DB or upstream, not asserted.

## Expected Fix

- **Bundle key:** use `student_id + order_no + plan_id`, and skip ambiguous groups (>1 coaching candidate). *(Adopted since this investigation — reflected in the technical design §9 and the accounting-repo steering. Final key still pending the CAP-team/O-8 answer on multi-plan order_no and B2C keying.)*
- **Detection:** join the daily log back to `trn_charge` on `charge_id` to recover `plan_id` (already in the design).

## Scope Assessment

| Axis | Assessment |
|---|---|
| Severity | High for correctness — a too-loose bundle key mis-pairs charges and produces wrong allocations |
| Data loss | None — read-only investigation |
| Tenants affected | Bizmates only (ASCA/ASCI scope) |
| Blocks | ASCA Foundation bundle-detection design; feeds G1 sign-off |

## Next Steps

**Verify against DB (owned by us — not a CAP/CIP dependency):**
- `SELECT product_id, product_type FROM mst_product WHERE product_id IN (10005,10015,10025,10022)` → confirm product_type 9/100 (Q2).
- `SELECT * FROM mst_plan_content WHERE plan_id BETWEEN 1016 AND 1027` → confirm coaching+App composition and the ¥0-App assumption (Q4).

**Confirm with CAP team (upstream design intent):**
1. One `order_no` per bundle, or can it hold multiple plans? How to key B2C (NULL order_no)?
2. Always exactly two `trn_charge` rows (coaching + App, same `plan_id`), App at `paid_price = 0`?
3. Is `plan_id` reliably set for CAP/CIP charges?

## Cross-Reference

| Document | Relevance |
|---|---|
| `projects/asca/documentation/asc-allocation-framework-technical-design.md` §9 | Bundle detection + grouping key (updated per this report) |
| `accounting_related_system_for_freee/.kiro/steering/backend-patterns.md`, `glossary.md`, `product.md` | Bundle key rule (updated per this report) |
| `projects/asca/documentation/asc-alloc-db-schema.md` | contract_type / product_type columns |
