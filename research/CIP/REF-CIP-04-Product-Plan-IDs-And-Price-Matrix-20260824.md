# CIP — Product/Plan IDs + Price Matrix (Updated)

## Document Info

| | |
|---|---|
| **Document type** | Upstream Research (CIP reference) |
| **Date** | 2026-08-28 (Filed) |
| **Source** | CIP Confluence — "Product ID and Plan ID" (updated 2026-08-19) + "Price Matrix" (updated 2026-08-24), both by Jefferson Gernale · product_id change confirmed FINAL by Go-san (Soli-san, CIP Slack, 2026-08-19) |
| **Filed by** | Noel Palo |
| **Assisted by** | Kiro |
| **Status** | Active — supersedes product_id and price figures in REF-CIP-03 |
| **Audience** | Dev team (ASCA/ASCI), Kuroda-san (PM), Patrick-san (SDM) |
| **Supersedes** | REF-CIP-03 (product_id 10022, price ¥88,000) |
| **Open items raised** | O-5 (L_coaching reopened), O-7 (product_id change — confirmed), O-8 (2-way vs 3-way split) — pending Kuroda-san/Accounting |

---

## ⚠️ Two changes that affect ASCI implementation

1. **Coaching Intensive product_id changed: 10022 → 10025** (business decision, Aug 19, 2026 — described by Jefferson as "final changes with this requirement")
2. **Price is lower than previously documented:** Solo plan (1028) is **¥75,900 tax-incl** (¥69,000 pre-tax), NOT the ¥88,000 recorded in REF-CIP-03. And the ¥69,000 base bundles **Coaching Intensive + App together**.

Both invalidate figures our ASCA/ASCI technical design currently uses. See "Impact on Our Docs" below.

---

## Product IDs (mst_product)

| product_id | product | Notes |
|---|---|---|
| ~~10022~~ → **10025** | Bizmates Coaching 30分 短期集中プラン | Changed from 10022 to 10025 per business side (Aug 19, 2026). Final. |

## Plan IDs (mst_plan)

| plan_id | plan |
|---|---|
| 1028 | Bizmates Coaching 30分 短期集中プラン (Solo) |
| 1029 | 1L + FVP + Bizmates Coaching 30分 短期集中プラン |
| 1030 | 2L + FVP + Bizmates Coaching 30分 短期集中プラン |
| 1031 | 3L + FVP + Bizmates Coaching 30分 短期集中プラン |
| 1032 | 4L + FVP + Bizmates Coaching 30分 短期集中プラン |

(Plan IDs unchanged from REF-CIP-03.)

## Price Matrix

**Formula (per Jefferson):** `69000 (Coaching Intensive & App) + Online Lesson (1L, 2L, 3L, 4L)`
**Reference sheet:** コーチング短期集中プラン・要件一覧【CIP】

| plan_id | plan name | Full pre-tax | Full w/ tax | Half pre-tax | Half w/ tax |
|---|---|---|---|---|---|
| 1028 | Coaching 30分 短期集中 (Solo) | 69,000 | **75,900** | 34,500 | 37,950 |
| 1029 | 1L + FVP + Coaching Intensive | 82,500 | 90,750 | 41,250 | 45,375 |
| 1030 | 2L + FVP + Coaching Intensive | 88,500 | 97,350 | 44,250 | 48,675 |
| 1031 | 3L + FVP + Coaching Intensive | 97,500 | 107,250 | 48,750 | 53,625 |
| 1032 | 4L + FVP + Coaching Intensive | 106,500 | 117,150 | 53,250 | 58,575 |

**Key reading of the formula:** the ¥69,000 pre-tax (¥75,900 w/ tax) base is **Coaching Intensive + App combined**. Plans 1029–1032 add Online Lesson (1L–4L) on top of that base. The "Half Price" columns suggest a first-period half-price mechanic (needs confirmation — could be a campaign discount like Honki Set's month-6).

---

## Impact on Our Docs (to reconcile — DO NOT silently edit)

Our current ASCA/ASCI technical design + timeline + glossary state:

| Item | Our docs currently say | Jefferson's update says | Status |
|---|---|---|---|
| CIP coaching product_id | `10022` | **`10025`** | ❌ Our docs stale |
| CIP plan price | ¥88,000 tax-incl | **¥75,900** tax-incl (Solo 1028) | ❌ Our docs stale |
| CIP L_coaching | ¥84,020 (= 88,000 − 3,980) | **TBD** — if base ¥75,900 bundles Coaching+App, then L_coaching = 75,900 − 3,980 = **¥71,920** (needs confirmation) | ❌ Reopens O-5 |

### O-5 reopens

O-5 (CIP coaching reference price) was marked "✅ Resolved — ¥84,020 (2026-08-17)". Jefferson's Aug 24 price matrix contradicts the ¥88,000 basis that ¥84,020 was derived from. **O-5 should be reopened** until Accounting confirms the correct L_coaching against the ¥75,900 (or per-plan) pricing.

### Detection whereIn

The detection query in the technical design (§9) uses:
```php
->whereIn('c.product_id', [10005, 10015, 10022, 10021])
```
Must change `10022` → `10025` once confirmed. Also, plans 1029–1032 bundle Online Lesson (1L–4L) — the bundle now has MORE than 2 products (Lesson + Coaching Intensive + App), which may change the allocation split from 2-way to 3-way for those plans. **This needs analysis** — CAP is strictly 2-way (Coaching + App); CIP plans 1029–1032 appear to be 3-way.

---

## Open Questions for Kuroda-san / Jefferson-san

1. **L_coaching for CIP:** Is it ¥71,920 (¥75,900 − ¥3,980 App)? Or does Accounting define it differently? (reopens O-5)
2. **App price in CIP:** Still ¥3,980 tax-incl, same as CAP? The formula lumps "Coaching Intensive & App" — need the App portion isolated.
3. **3-way split for 1029–1032:** Plans with Online Lesson (1L–4L) bundle 3 products. Does ASCI allocate across all 3, or is Lesson recognized separately (leaving Coaching + App as the 2-way split)?
4. **Half Price columns:** What triggers half price? Is it a first-period discount (like Honki Set month-6), and does it affect the allocation basis?
5. **product_id 10025 confirmation:** Confirm the whereIn detection update and any Freee mapping (mst_code_change / mst_rule_for_journals) for the new product_id.

---

## Cross-Reference

| Document | Relevance |
|---|---|
| `research/CIP/REF-CIP-03-Project-Spec-20260812.md` | Superseded product_id (10022) and price (¥88,000) |
| `projects/asca/documentation/asc-allocation-framework-technical-design.md` | §7 detection, §9 whereIn, §6 reference prices — all reference 10022 / ¥84,020 |
| `docs/asc-projects-master-timeline.md` | Confirmed Data table + ASCI phase reference ¥84,020 / plans 1028–1032 |
| `domain-knowledge/plans-and-products.md` | CIP detection row |
