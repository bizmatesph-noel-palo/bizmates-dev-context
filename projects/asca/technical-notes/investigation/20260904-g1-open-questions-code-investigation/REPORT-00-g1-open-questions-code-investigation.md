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
| 2 | product_type values | 🟡 Existing confirmed (Coaching=9, App 10012=100). ⚠️ **New products conflict (O-10): CAP says 10022=618/10025=469; CIP DB says 10022=100/10025=9.** Final migration decides. |
| 3 | order_no structure & grouping | ⚠️ order_no nullable/non-unique; key needs `plan_id`. **B2B product-sets have no plan_id** (plan_id=0) — flag for B2B detection |
| 4 | bundle composition | ✅ **Confirmed (CAP+CIP data)** — bundle is **2–4 products**, not always 2. App 10022 in every plan (¥0). Split: **CAP 2-way; CIP 1029–1032 3-way per R-16** (2026-09-08, supersedes O-8) — detection must pick Coaching+App (and Lesson for CIP 1029–1032) |
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

### Q2 — product_type 9 / 100 🟡 PARTIALLY CONFIRMED (DB)

- `mst_product.product_type` is a plain `integer` column. Migration comment only documents `1=Skype, 2=Video`. Code special-cases `8` (Bizmates Test).
- No constant/enum for `9` (Coaching) or `100` (App) anywhere in either repo — they are **data facts in `mst_product` rows**, not code constants.
- freee-facing types are separate master IDs in `config/code.php` (`bizmatesCoaching=191155067`, `BizmatesApp=236270504`) — NOT the internal product_type ints.

**DB check (local, 2026-09-08 — CAP/CIP migrations & seeders NOT yet run):**

```sql
SELECT product_id, product_type FROM mst_product WHERE product_id IN (10005,10015,10025,10022);
```

| product_id | product_type | Source | Status |
|---|---|---|---|
| 10005 (Coaching 15min) | 9 | our local DB | ✅ Confirmed |
| 10015 (Coaching 30min) | 9 | our local DB | ✅ Confirmed |
| 10012 (App, existing) | 100 | prod logs (DEVOPS-6287) | ✅ Confirmed |
| 10022 (App, new) | **618** | CAP proposal (Terry-san) | ⚠️ conflicts with CIP |
| 10022 (App, new) | **100** | CIP local DB (Jefferson-san) | ⚠️ conflicts with CAP |
| 10025 (CIP coaching, new) | **469** | CAP proposal (Terry-san) | ⚠️ conflicts with CIP |
| 10025 (CIP coaching, new) | **9** | CIP local DB (Jefferson-san) | ⚠️ conflicts with CAP |

**⚠️ OPEN CONFLICT (O-10) — CAP and CIP disagree on the new product_types:**

| product | CAP (Terry-san, proposal) | CIP (Jefferson-san, actual local DB) |
|---|---|---|
| 10022 (new App) | 618 | 100 |
| 10025 (CIP coaching) | 469 | 9 |

Same product_id cannot hold two product_types. This is **data, not a code blocker** — the value that ships in the **final CAP/CIP migration** is authoritative, and if the upstream teams reconcile it, it reflects there. ASC allocation reads `product_type` from `mst_product` at runtime, so it adapts to whatever the final data is. **Action:** confirm the reconciled values with Terry/Jefferson; re-verify on DEV04 after the final migrations land.

**Existing vs new.** Existing products are unchanged: Coaching 10005/10015 = 9, existing App 10012 = 100. The *new* CAP/CIP products (10022, 10025) have the conflicting values above pending reconciliation.

### Q3 — order_no ⚠️ KEY FINDING (drives (2)-8)

Schema: `order_no bigInteger NULLABLE`, single index `idx_orderno`, comment "発注番号（B2B/B2B2Cのみ)". **No unique constraint.** Comment says order_no is **only for B2B/B2B2C** — i.e. B2C charges have NULL order_no.

Existing code groups by **order_no alone**, and is explicitly built to handle multiple charges/products under one order_no:
- `TrnCharge::getTrnChargeForOrderNo()` → `SUM(paid_price) ... GROUP BY order_no`
- `getPaidPriceSumList()` groups by `target_ym, order_no, product_type, contract_type, ...` (product_type included → different products under one order_no become separate rows)
- `SendJournalsDataLogic` accumulates journals keyed by order_no and has explicit "same order_no gets overwritten/added" handling (T3 wash logic)

**Implications:**
- **`(student_id, order_no)` is too loose** — confirmed. For B2C, `order_no` is NULL, so the key `student_id|null` breaks if a B2C student has two contracts in a month.
- The existing system treats one order_no as potentially spanning multiple products/charges — so "two different plans under one order_no" would mis-pair.
- **Detection needs `plan_id` in the key** — not order_no alone.
- **B2B product-sets have NO plan_id** (CAP data, Terry-san): the 8L/10L B2B-only sets have `plan_id = 0`. Detection keyed on plan_id would miss these — flag for B2B handling (may need product-set detection). Their arity is still Coaching + App for the split.

### Q4 — bundle composition ✅ CONFIRMED (CAP + CIP `mst_plan_content`)

Confirmed against real `mst_plan_content` data (Terry-san CAP, Jefferson-san CIP). **A bundle is NOT always 2 products** — it ranges 2–4:

| Plan(s) | Products | Count |
|---|---|---|
| CAP 1016, 1017 | Coaching + App (10005/10015 + 10022) | 2 |
| CAP 1018–1027 | Lesson + FVP + Coaching + App (1–4 + 10011 + 10005/10015 + 10022) | 3–4 |
| CIP 1028 | Coaching + App (10025 + 10022) | 2 |
| CIP 1029–1032 | Lesson + FVP + Coaching + App (1–4 + 10011 + 10025 + 10022) | 4 |

- **App 10022 present in every CAP and CIP plan** ✅ — good detection anchor.
- App charges at **¥0** (companion) — the ¥0-App assumption holds ✅.
- ~~**Split stays 2-way** (Coaching + App) per O-8. Lesson (product_type 1) and FVP (10011) are NOT part of the allocation split — the existing daily-rate logic handles them.~~
- **⚠️ Superseded by R-16 (2026-09-08, REF-CAP-09):** split arity is now **CAP (all) + CIP 1028 = 2-way (Coaching + App)**, but **CIP 1029–1032 = 3-way (Lesson : Coaching : App**, tax-excl weights 13,500 : 66,500 : 3,618). For CIP 1029–1032, Lesson IS part of the split. FVP (10011) remains outside the split. This reverses the 2-way-only conclusion recorded here on 2026-09-04.

**Conclusion:** the design's "always exactly 2 `trn_charge` rows" assumption is **wrong**. Detection must pick the split rows out of a 2–4 product bundle: **Coaching + App for CAP and CIP 1028; Lesson + Coaching + App for CIP 1029–1032 (R-16)** — not assume a 2-row pair.

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
