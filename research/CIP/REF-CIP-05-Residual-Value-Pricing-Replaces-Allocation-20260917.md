# REF-CIP-05 — Residual-Value Pricing Replaces Proportional Allocation for CIP (Kuroda-san, 2026-09-17)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-09-17 (Received — Confluence doc) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative. **Scope reduction for Phase 3 (ASCI). CAP / ASCA Foundation unaffected.** |
| **Audience** | Dev team (ASCA/ASCI), Accounting |
| **Supersedes** | REF-CAP-09 §10 / R-16 (CIP 3-way proportional allocation) and the 2026-09-03 P-4 CIP allocation baseline — for CIP only |
| **Applies to** | ASCI (Phase 3, plan_id 1028–1032). Does NOT change ASCA Foundation Spec 01 or CAP (1016–1027). |

> ⚠️ **Verbatim source document.** Preserved in full. Do not alter. Our interpretation/impact analysis lives in `projects/asca/` and the master timeline — not here.

---

## Requirement Update — Residual-Value Pricing Replaces Proportional Allocation

By Hayato Kuroda

### 1. Summary

CIP (Coaching Intensive + App, plan_id 1028–1032) no longer needs the proportional allocation engine. Effective immediately, CIP revenue is split by adding one new master price record for Coaching Intensive and booking App at its existing list price. Both amounts then go through the existing daily pro-ration logic unchanged — there is no new formula, no reference-price-with-effective-date lookup, and no allocation run/anchor tracking for CIP.

This is a scope reduction for Phase 3 (ASCI), not an extension. CAP (plan_id 1016–1027) is unaffected and keeps the proportional allocation formula as designed.

### 2. Before / After

#### 2.1 Before (2026-09-03 P-4 decision, current design baseline)

One bundled charge carries the full paid amount for Coaching Intensive; the App charge is issued at paid_price = 0.

After existing daily pro-ration produces the per-month amount N, the allocation engine splits it:
P_app = floor(N × L_app / (L_coaching + L_app)), P_coaching = N − P_app
using reference weights L_coaching : L_app = 66,500 : 3,618 (tax-excl, mst_new_price_listing price_flag=2).

Full-month example (CIP Solo, plan_id 1028, N=75,900 tax-incl): P_coaching = 71,984 / P_app = 3,916.

Requires: mst_alloc_reference_prices (effective-dated reference price table), the allocation formula/engine, run/anchor bookkeeping, and the Metabase allocation-visualization columns (allocation base amount, etc.).

#### 2.2 After (this change, 2026-09-17)

Two separate, already-priced charges are issued directly — no bundled charge and no post-hoc split:

- App charge: paid_price = 3,980 (tax-incl), its real list price.
- Coaching Intensive charge: paid_price = 71,920 (tax-incl), from a new master price record (see §3).

Each charge is pro-rated independently by the existing daily pro-ration logic (CommonUtil::getContractDateInfoList() / equivalent), exactly as any other multi-line-item plan already is. No new formula is introduced.

First-month discounts (e.g. 50% off) apply the normal way to each charge — no special-casing versus any other plan.

Applies to CIP Solo (1028) and to lesson-bundled CIP (1029–1032) (confirmed by Kuroda-san, 2026-09-17 — see §5):

- Online Lesson (1L–4L): its own existing standalone lesson price, charged and pro-rated as an independent line — unaffected by this change.
- App: 3,980, pro-rated as-is.
- Coaching Intensive: (that plan's Coaching+App sub-price) − 3,980. For every 1029–1032 SKU the Coaching+App sub-price is the same CIP Solo bundle (75,900), so in practice this residual is 71,920 across all four lesson-bundled plans too — but it is derived from the plan's Coaching+App portion specifically, not from the plan's full price (Lesson + Coaching + App combined).

### 3. New master price record

Source: shared spreadsheet 1jqBTmusr..., tab "自動付帯・短期集中プランプロダクト単価内訳", row 17.

| Field | Value |
|---|---|
| Name | コーチング短期集中（売上計上用） / "Coaching Intensive (revenue booking)" |
| product_id | 10025 (same product as the existing Coaching Intensive records) |
| price_flag | 3 (new value for this product; distinguishes it from the existing price_flag=2 reference-price row and price_flag=4 "app-inclusive" row) |
| Tax-excl price | 65,382 |
| Tax-incl price | 71,920 |
| Formula | 71,920 = 75,900 (CIP Solo plan price, tax-incl) − 3,980 (App unit price, tax-incl) |
| Sold standalone? | No — sheet marks it "※単独販売しない" (booking-only record, not customer-facing) |

This record is additive: it does not replace or invalidate the existing price_flag=2 (66,500/3,618, allocation/shareholder-refund reference) or price_flag=4 (69,000/75,900, app-inclusive plan-pricing) rows for product 10025. Those may still be needed elsewhere (see §5, open item 3).

### 4. What does NOT change (CAP)

CAP (Coaching+App auto-bundle, plan_id 1016–1027) keeps the current design exactly as-is:

- App charge remains paid_price = 0.
- The proportional allocation formula (P_app = floor(N × L_app / (L_coaching + L_app)), P_coaching = N − P_app) still applies, using the existing L_coaching : L_app reference weights (18,000:3,618 for 15-min, 36,000:3,618 for 30-min, tax-excl).
- The allocation engine, mst_alloc_reference_prices, run/anchor tracking, and the Metabase allocation-visualization columns are still required — but CAP-only in scope. Any Spec 01 work already in progress for CAP is unaffected by this change.

The reason for the asymmetry (confirmed by Kuroda-san, 2026-09-17): CAP's auto-attach Coaching product already had an independent, standalone selling price before this change (price_flag=3: Coaching 15-min single = 19,800, Coaching 30-min single = 39,600 — pre-existing rows, not newly created). CIP's Coaching Intensive product never had one — per the original accounting question this change is based on, Lesson and App each already had independent list prices, but the "Coaching + LINE support + original materials" bundle did not. That's why a brand-new price_flag=3 record had to be created for CIP specifically (§3).

Having an independent price does not, by itself, remove the need for CAP's allocation formula: CAP still issues one bundled charge for the whole plan, and its independent Coaching/App prices are used as ratio weights to split that single charge (L_coaching : L_app), not as the real charge amounts. CIP's new record is different in kind — it is the real charge amount, because CIP now issues separate, already-priced charges per product instead of one bundled charge. Confirmed with Kuroda-san (2026-09-17): CAP keeps the allocation engine exactly as designed; this change does not extend to CAP.

### 5. Impact on existing design items — please confirm

1. Formula interface scope (Spec 01 Req 2a AllocationFormulaInterface) — the 2-way (CAP) vs 3-way (previously assumed for lesson-bundled CIP, ASCI) split. With this change, lesson-bundled CIP no longer needs a 3-way allocation formula (Lesson/App/Coaching are three independently priced, independently pro-rated charges, not one amount split three ways). Please confirm whether the 3-way AllocationFormulaInterface needs to be removed from scope, and if so, roughly how much effort that removal involves (e.g. if design/code has already been written against it).

2. Lesson-bundled CIP (1029–1032) — confirmed shape. Each of these plans books three independent, independently pro-rated charges: Lesson at its own existing price, App at 3,980, and Coaching Intensive at (Coaching+App sub-price) − 3,980 (71,920 in practice — see §2.2). No proportional split of any kind is involved.

3. App charge price source — resolved. Confirmed by Kuroda-san (2026-09-17): the real, non-zero CIP App charge reuses the existing price_flag=2 row (3,980 tax-incl) directly. No new price record is created for App — only Coaching Intensive gets a new price_flag=3 row (§3).

4. Metabase allocation-visualization table (ASCA-8) — this table's columns (List Price / Allocation Base Amount / Recognized Revenue Amount) were designed for charges that go through the allocation engine, which CIP charges no longer do. No change to ASCA-8 for now — keep it as designed. We'll confirm separately with the team whether CIP should be excluded from it once the CAP-only engine work is further along; this is not blocking.

5. Shareholder refund cap (¥19,800 coaching-only cap, product_type=9) — confirmed no change needed: the cap applies against product_type=9 regardless of which specific price record (price_flag 2 vs 3) the coaching charge's paid_price came from.

6. Schedule impact — if confirmed, Phase 3 (ASCI, W10–W11, 11/2–11/13) scope shrinks from "stand up the allocation engine for CIP" to "add the new master price record(s) + verify existing pro-ration/discount logic produces the expected two (or three) independent charges correctly." Please flag if this changes the Phase 3 estimate.

---

## Cross-Reference (added by Noel — not part of the verbatim source)

| Document | Relationship |
|---|---|
| `research/CAP/REF-CAP-09-...` §10 / R-16 | **Superseded for CIP** — R-16's 3-way proportional split is withdrawn; CIP now uses residual-value pricing (separate charges). |
| `research/CAP/REF-CAP-11-...` (Round-3) | Foundation/CAP sign-off — unchanged; CAP keeps the engine. |
| `projects/asca/documentation/asc-allocation-framework-technical-design.md` §1c | Interpretation/impact of this change. |
| `projects/asca/documentation/asc-alloc-db-schema.md` | R-16 3-way schema notes superseded (product_role lesson, CIP lesson weight). |
| `docs/asc-projects-master-timeline.md` | Phase 3 (ASCI) scope reduction. |
