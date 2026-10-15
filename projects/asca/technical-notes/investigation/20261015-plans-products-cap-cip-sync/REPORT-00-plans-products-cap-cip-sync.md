# Plans & Products Doc — CAP/CIP Sync Reconciliation (20261015)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report |
| **Status** | Active |
| **Date** | 2026-10-15 (Reported) · 2026-10-15 (Investigated) |
| **Author / Reporter / Investigator** | Noel Palo, Lead |
| **Assisted by** | Kiro (code/spec analysis and document reconciliation) |
| **Audience** | Dev team (ASCA/ASCI), PM (Kuroda-san), SDM (Patrick-san) |
| **Environment** | `ls-database-migrations` @ `deployment/dev04` (CAP/CIP master-data seeders) + `research/CAP`, `research/CIP` |
| **JIRA** | TBA |

---

## 1. Summary

`domain-knowledge/plans-and-products.md` was stale against the **actual** CAP/CIP master-data seeders now on `deployment/dev04`. Five fact-level discrepancies and one superseded design statement were found. The dev04 seeders + the research library (REF-CIP-04, REF-CIP-05) are treated as source of truth; the doc was updated to match.

**Confidence:** confirmed against the dev04 seeder source and the verbatim research docs (not data-queried against a live DB).

**Headline:** the stale rows were about *values and framing*, not about ASCA/CAP implementation. The CAP engine design in our steering/specs remains consistent with the research. CIP's "no allocation engine" change is correctly ASCI scope and does not touch ASCA.

---

## 2. Evidence

### 2.1 Sources read

| Source | What it establishes |
|---|---|
| `ls-db/.kiro/specs/coaching-app-plans-db/requirements.md` + `CapCoachingAppPlansSeeder.php` | CAP products/plans/prices + price_flag mechanics |
| `ls-db/.kiro/specs/coaching-intensive-plan-seeder/requirements.md` | CIP product 10025, plans 1028–1032, prices |
| `ls-db/.kiro/specs/coaching-intensive-banner-seeder/requirements.md` | CIP payment-complete banners (tier1/tier2) |
| `ls-db/.kiro/specs/coaching-intensive-honki-banner/requirements.md` | CIP honki-group banner |
| `research/CIP/REF-CIP-05-...` | CIP drops the allocation engine (residual-value pricing) |
| `research/CIP/REF-CIP-04-...` | product_id 10025, price ¥75,900; supersession chain |

### 2.2 Discrepancies (doc = stale; dev04/research = truth)

| # | Field | Doc said (stale) | Actual (dev04/research) | Source |
|---|---|---|---|---|
| 1 | App 10022 `product_type` | "618 or 100 ⚠️ UNRESOLVED (O-10)" | **100** (clone of 10012) | coaching-app-plans-db Req 8.2 |
| 2 | CIP 10025 `product_type` | "469 or 9 ⚠️ UNRESOLVED (O-10)" | **9** | coaching-intensive-plan-seeder Req 1.1 |
| 3 | App reference price (L) | ¥3,980 tax-incl | **¥3,618 tax-excl** (`mst_new_price_listing` price_flag 2) | coaching-app-plans-db (App pricing) |
| 4 | CAP coaching L | 10005 ¥19,800 / 10015 ¥39,600 (tax-incl) | allocation L **¥18,000 / ¥36,000 tax-excl**; bundle price_flag 4 = 10005 ¥20,500/¥10,250, 10015 ¥38,500/¥19,250 | coaching-app-plans-db + REF-CIP-05 §4 |
| 5 | CIP coaching L | "¥84,020 STALE" | residual price_flag 3 = **¥65,382 tax-excl / ¥71,920 tax-incl**; not an allocation weight | REF-CIP-05 §3 |
| 6 | CIP allocation | "allocation required / 2-way / O-8 resolved" | **No allocation engine** — residual-value pricing (separate charges) | REF-CIP-05 |

### 2.3 price_flag mechanics (newly documented — load-bearing for the reference-price seeder)

| price_flag | Meaning | Example |
|---|---|---|
| 2 | Standalone list price (ex-tax) — accounting reference, NOT billed in-bundle | App 10022 = ¥3,618 |
| 3 | Post-VPP / bundled companion | App 10022 = ¥0; CIP 10025 residual = ¥65,382 ex-tax |
| 4 | CAP bundle price (App fee folded into coaching) | 10005 ¥20,500/¥10,250; 10015 ¥38,500/¥19,250 |

---

## 3. Analysis — why the CIP framing was wrong

The doc carried the **2026-09-03 P-4 baseline** (CIP split by the engine, 2-way). That was reversed twice upstream:

1. **REF-CIP-04 (2026-08-24)** recorded O-8 = 2-way.
2. **R-16 (REF-CAP-09, 2026-09-08)** reversed it: CIP 1029–1032 = 3-way.
3. **REF-CIP-05 (2026-09-17)** superseded both: CIP uses **no engine at all**.

Under REF-CIP-05, CIP issues separate, already-priced charges (App ¥3,980; Coaching Intensive ¥71,920 via a new price_flag 3 record; Lesson at its own price) that flow through the **existing daily pro-ration**. Nothing to split → no formula, no reference-price lookup, no run/anchor tracking. The doc never caught up past step 1.

**CAP is explicitly unaffected (REF-CIP-05 §4):** one bundled charge, App ¥0, 2-way engine split, weights 18,000:3,618 / 36,000:3,618 tax-excl. This matches the accounting-repo steering.

---

## 4. Scope Assessment

- **Severity:** Medium (library/reference accuracy). No code impact for ASCA/CAP.
- **ASCA/CAP:** doc values corrected; design framing was already correct in steering/specs.
- **ASCI/CIP:** the "no engine" fact is ASCI scope; ASCA Foundation + Spec 02a–02d unaffected.
- **Not verified here:** a line-by-line audit that Spec 01/02a–02d code matches these values end-to-end. The `ReferencePriceSeeder` (accounting repo) was spot-checked and uses ¥3,618 / ¥18,000 / ¥36,000 tax-excl — consistent. Full per-spec audit is a separate task.

---

## 5. Next Steps

1. Update `domain-knowledge/plans-and-products.md` (6 fixes + price_flag table + Document Info header). — paired with this report.
2. (Optional, separate) Per-spec implementation audit: confirm Spec 01/02a–02d code matches these corrected values against the CAP/CIP docs.
3. (Open, pre-existing) O-5 CIP L_coaching reconciliation remains an ASCI concern, not ASCA.

---

## 6. Cross-Reference

| Document | Relevance |
|---|---|
| `domain-knowledge/plans-and-products.md` | The reconciled library file |
| `research/CIP/REF-CIP-05-Residual-Value-Pricing-Replaces-Allocation-20260917.md` | CIP no-engine decision (normative) |
| `research/CIP/REF-CIP-04-Product-Plan-IDs-And-Price-Matrix-20260824.md` | product_id 10025, price ¥75,900, supersession chain |
| `ls-database-migrations/.kiro/specs/coaching-app-plans-db/requirements.md` | CAP master-data truth |
| `ls-database-migrations/.kiro/specs/coaching-intensive-plan-seeder/requirements.md` | CIP master-data truth |
| `research/CAP/REF-CAP-11-ASCA-Spec01-Review-Round3-20260910.md` | CAP Foundation sign-off (engine retained) |
