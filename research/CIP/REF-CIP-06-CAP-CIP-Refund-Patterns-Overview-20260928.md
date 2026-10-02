# REF-CIP-06 — CAP / CIP Refund Patterns Overview (Kuroda-san, 2026-09-28)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-09-28 (Received — Confluence doc) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative source for CAP/CIP refund allocation (Step 6). Refines REF-CAP-09 and REF-CIP-05. |
| **Audience** | Dev team (ASCA/ASCI), Accounting |
| **Supersedes / refines** | REF-CAP-09 (refund requirements) and REF-CIP-05 (§1c) — CIP **refunds** ARE split by a fixed per-type rule (CIP normal charges remain un-allocated per REF-CIP-05); §3.8 contract overlap now produces **no refund** (corrected 2026-09-28) |
| **Companion** | CAP / CIP Calc Patterns (Google Sheets) — the per-pattern worked figures |

> ⚠️ **Verbatim source document.** This is Kuroda-san's Refund Patterns doc, preserved in full. Do not edit this content; our interpretation/impact analysis lives in `projects/asca/`. Cross-reference notes (mine, not part of the source) are at the very bottom, clearly marked.

---

## CAP / CIP Refund Patterns — Overview

By Hayato Kuroda
2026-09-28

### 1. Purpose & Scope

Share how CAP / CIP refunds are split between Coaching and App and recognized, so it can be used as input for implementation step 6 (Refund allocation).

In scope: every refund flow that touches a CAP / CIP bundle — cancellation / cooling-off (90% refund), consumption-tax exemption, shareholder-benefit cashback, contract-type change, individual↔corporate contract overlap (no refund — see 3.8), mid-month plan change.

Out of scope: the ASCA/I allocation engine itself (separate spec).

Assumes you already know how existing ASC handles cooling-off, contract changes, and prorated refunds. This doc only describes the CAP / CIP allocation layer that sits on top of that.

### 2. How the CAP / CIP allocation layer behaves on refunds

#### 2.1 A refund month only makes N negative

In a refund month, the amount existing ASC recognizes for the charge in that month (N) simply becomes negative. For CAP, the allocation formula is identical to a normal month — there is no separate refund formula. For CIP, regular charges are not allocated at all; only refunds are split, by a fixed rule per refund type (see the note under §3). See §5 for the code.

#### 2.2 The negative is recognized in one lump, in the execution month

The negative amount is recognized in the paid_at month, in a single lump. It is not day-prorated, and it is not spread back to the months where the original revenue was recognized. This is the existing behaviour of CommonUtil::getContractDateInfoList() (see §5), and the allocation layer inherits it.

#### 2.3 Bundle detection and allocation weights

Product IDs and prices:

| Product | product_id | price_flag | mst_new_price_listing.price (tax-excl.) | Note |
|---|---|---|---|---|
| Existing Bizmates App product | 10012 | 3 | 2,500 | Real-sales app. 2,500 → 3,980? under investigation. Out of allocation scope. |
| New Bizmates App product (auto-bundled) | 10022 | 3 | 0 | Settlement / charge amount = 0 |
| New Bizmates App product (auto-bundled) | 10022 | 2 | 3,618 | Allocation weight L_app (≈ tax-incl. 3,980) |
| New Coaching Intensive product | 10025 | 4 | 69,000 | Settlement price |
| New Coaching Intensive product | 10025 | 2 | 66,500 | Allocation weight for CIP — no longer used for CIP allocation (2026-09-17) |
| New Coaching Intensive product | 10025 | 3 (new) | 65,382 (tax-incl. 71,920) | Residual price used by revenue booking for CIP (= 75,900 - 3,980) |

CAP bundle detection: presence of the auto-bundled App product_id.

CIP bundle detection: CIP plan_id (1028–1032), or the dedicated Coaching Intensive product_id 10025.

The auto-bundled App is the same product for CAP and CIP (product_id 10022).

CAP allocation weight L comes from mst_new_price_listing price_flag = 2: Coaching 18,000 (15 min) / 36,000 (30 min), App 3,618 (tax-excl.).

CIP (since 2026-09-17): no allocation weight. Revenue booking uses independent unit prices — Coaching Intensive 71,920 (new price_flag = 3) and App 3,980 (price_flag = 2, tax-incl.) — each day-prorated by the existing logic. On the site, the App charge is still settled at ¥0. Refunds are the only case that needs a split (see the note under §3).

The bundled App charge amount (trn_charge.paid_price) is price_flag = 3 = 0. For CAP, the App side of N is always 0 and ΣN = N_coaching.

Coaching charges are identified by mst_product.product_type = 9 (PRODUCT_TYPE_BIZMATES_COACHING).

#### 2.4 How the refund amount is decided

| Type | Cases | Refund amount |
|---|---|---|
| Fixed / capped | Shareholder-benefit cashback, consumption-tax exemption, cooling-off (90% refund) | Not day-prorated. A fixed / capped figure. |
| Overlap-period | Individual ↔ corporate contract overlap | No refund is issued (corrected 2026-09-28, see 3.8). |

The resulting negative is recognized as a lump in the execution month (§2.2).

#### 2.5 Shareholder-benefit cashback — current process, page, code

Process (confirmed 2026-09-06):

1. Shareholder submits the IR benefit application form (selects the service: "Bizmates" / "Bizmates Coaching" / "Bizmates App" / video lessons).
2. Zapier appends the submission to a spreadsheet.
3. Roughly three months after the application month, Accounting pays the cashback by bank transfer (end of month).
4. Accounting records it by bulk CSV upload on the Admin "Shareholder Charge" screen:
   <https://dev05.dev.bizmates.jp/MyBizmates/admin/shareholderrefund/index>

What the upload does (code): for each CSV row it looks up the original charge, then inserts a negative trn_charge cloned from that original charge — only paid_price (= -refund_price), paid_at, and transaction_id (= ADMIN_REFUND_<orig>) are overwritten. It also writes log_refund_history (refunded_charge_id → refund_charge_id) and a receipt-lock row. It does not write trn_prorated_refund*.
bizmates.jp/fuel/app/classes/controller/api/admin/shareholderrefund/addbycsv.php (~L214–320) · original-charge lookup chargeModel.php::getChargeByStudentIdAndTransactionIdAndPaidPrice() (~L3909–3921, key = student_id + transaction_id + charge_price) · log_refund_history insert chargeModel.php (~L2297–2314).

Consequences for allocation:

- The allocation layer consumes that negative charge like any other negative charge. It does not parse the CSV.
- Only the "Bizmates Coaching" benefit line is in scope for CAP / CIP. The coaching cashback is capped at ¥19,800 (per the IR benefit page). The "Bizmates App" benefit line does not apply to the bundled ¥0 App.
- CSV columns: student_id, transaction_id, refund_price, charge_price, paid_at (see the attached sample).
- When one transaction_id appears on two rows (a lesson-plan portion + a coaching portion — e.g. 7,425 + 9,900), do not sum them. Each row resolves to its own original charge. Only the coaching-portion row is allocated; the lesson-portion row is left to existing ASC.

#### 2.6 Implementation note

Negative refund charges must flow through the same allocation entry point as positive charges, identified by record_kind. There is no separate refund pipeline. For CAP, the same allocation formula applies. For CIP, a negative Coaching Intensive charge is split into Coaching and App by the fixed rule for its refund type (see the note under §3); how the refund type is identified is an open item and will be confirmed separately.

### 3. Refund cases

| # | Case | Existing ASC path it rides on | Refund amount | Allocation-layer treatment | Sheet ref | Status |
|---|---|---|---|---|---|---|
| 3.1 | Cooling-off (90% refund, same month) | Standard refund → negative charge | paid × 90% (10% fee retained). CIP: plan total 75,900 × 90% = -68,310 on the Coaching charge | CAP: N negative, same formula. CIP: split Coaching / App by fixed rule (see note below) | CAP Pattern 4a / CIP Pattern 5a | Decided |
| 3.2 | Cooling-off refund executed in a later month | Standard refund | Same as 3.1 | Negative lands in the execution month, not the contract month | CAP Pattern 4b / CIP Pattern 5b | Decided |
| 3.3 | Cooling-off 10% (partial) | — | — | Merged into 3.1 (the rule is a 90% refund, i.e. a 10% fee) | — | Removed |
| 3.4 | Consumption-tax exemption (overseas learners) | Admin Refund → "tax exemption" | CAP: paid_incl_tax × 10 / 110. CIP: the sum of each product's tax-incl. - tax-excl. price: Coaching -(71,920 - 65,382) = -6,538 + App -(3,980 - 3,618) = -362 = -6,900, booked as one entry on the Coaching charge | CAP: N negative, same formula. CIP: split into the per-product amounts above (see note below) | CAP Pattern 8 / CIP Pattern 6 | Decided |
| 3.5 | Shareholder-benefit cashback | Admin "Shareholder Charge" bulk CSV → cloned negative charge | Capped figure (Coaching cap ¥19,800); executed about 3 months later | CAP: split Coaching / App. CIP: Coaching only (no App distribution). A new cap for this plan is expected to be decided around Nov–Dec and is out of scope through December | CAP Pattern 9 / CIP Pattern 7 | Decided |
| 3.6 | Shareholder CSV, one transaction_id split across rows | Same as 3.5 | Per-row refund_price | Do not sum rows; allocate only the coaching-portion row | (not in sheet) | Decided |
| 3.7 | Contract-type change (B2C / B2E → B2B) | Existing contract-type change | n/a (no refund) | Allocation amounts unchanged; only the Freee journal target (partner / department) changes; summary key must include contract type | CAP Pattern 6 / CIP Pattern 4 | Decided |
| 3.8 | Individual ↔ corporate contract overlap | No refund (corrected 2026-09-28; issue list No. 22 "no coaching refund occurs") | n/a | Individual charge recognized in full through its original end date; B2B charge recognized from its start date. No negative charge is created. | CAP Pattern 6 / CIP Pattern 4 | Decided |
| 3.9 | Plan change with mid-month renewal | Two charges in the same month | n/a | Loop per charge; each charge uses its own weight; sum within the month. A single monthly ratio is not valid. | CAP Pattern 5 | Decided |
| 3.10 | Lesson-included CIP plans (1029–1032) | — | Each charge day-prorated at its own unit price | No allocation (superseded 2026-09-17): Lesson at its existing price, Coaching Intensive at the residual 71,920, App at 3,980 — three independent charges | CIP Pattern 8 | Decided |

**CIP refunds (added 2026-09-28, accounting-confirmed).** Admin cannot refund a ¥0 charge, so a CIP refund is booked as one negative charge on the Coaching Intensive charge for the plan total (cooling-off 90%: -68,310; consumption-tax exemption: -6,900). The revenue-booking layer then distributes it to App — cooling-off: App -(3,980 × 90%) = -3,582, Coaching -64,728; tax exemption: App -(3,980 - 3,618) = -362, Coaching -6,538. No rounding difference; not day-prorated; execution month. Shareholder cashback is not distributed (Coaching only). Details: requirements R-05a. Cooling-off will be removed from the terms at the end of October, but the function remains, so the case stays in scope as an exception.

### 4. The calculation-pattern spreadsheet

Link: CAP / CIP Calc Patterns (Google Sheets)

Tabs: CAP Calc Patterns (Coaching + App auto-bundle, plan_id 1016–1027) and CIP Calc Patterns (Coaching Intensive, plan_id 1028–1032). Both tabs use the same layout; each pattern shows the regular monthly charges alongside the refund rows, with a subtotal per month.

How to read the columns:

- Accounting Month — the month the row is recognized in (merged across that month's rows).
- Contract Start / End — the charge period. When a contract ends early (e.g. cooling-off), the end date is changed to the actual end date and shown in bold.
- Period in Month Start / End, Contract Days (I) — the day-proration inputs: FLOOR(Paid Amount × (End - Start + 1) / Contract Days, 1).
- Amount in current accounting system — what existing ASC recognizes for that charge in that month (negative in a refund month). Refunds are not day-prorated.
- Amount after ASCA/I — the figure after ASCA (CAP: list-price allocation) or ASCI (CIP: refund distribution to App). For CIP it equals the current amount except on refund rows.
- List Price — CAP: tax-excluded allocation weight (18,000 / 36,000 / 3,618). CIP: tax-included unit price (71,920 / 3,980).

### 5. Reference — existing code paths

| Behaviour | Code |
|---|---|
| Negative charge → recognized in the paid_at month, no day-proration | accounting_related_system_for_freee/app/Libs/CommonUtil.php — getContractDateInfoList(), the if ($paidPrice < 0) branch (~L606–616) |
| Monthly batch charge selection (paid = 1 AND status = 1 AND paid_at in month) | accounting_related_system_for_freee/app/Models/TrnCharge.php — getTrnChargeList() (~L41–52) |
| Daily-rate write-back | accounting_related_system_for_freee/app/Libs/CommonUtil.php — createDailyRateCalculation() (~L386–458) |
| Shareholder CSV → cloned negative trn_charge (+ log_refund_history, receipt lock) | bizmates.jp/fuel/app/classes/controller/api/admin/shareholderrefund/addbycsv.php (~L214–320) |
| Original-charge lookup key = student_id + transaction_id + charge_price | bizmates.jp/fuel/app/classes/model/chargeModel.php — getChargeByStudentIdAndTransactionIdAndPaidPrice() (~L3909–3921) |
| Original ↔ refund link | log_refund_history (refunded_charge_id / refund_charge_id); insert at chargeModel.php (~L2297–2314) |
| Admin prorated refund — also clones a negative charge, execution-month paid_at | bizmates.jp/fuel/app/classes/libs/prorated.php (~L181–246) |
| Coaching detection: product_type = 9 | bizmates.jp/fuel/app/classes/model/planModel.php — PRODUCT_TYPE_BIZMATES_COACHING = 9 (~L153) |
| Zero-price bundled product precedent (Full Video Package) | bizmates.jp/fuel/app/classes/libs/charge.php — createChargeForFullVideoPackage() (~L153–166) |
| price_flag values (1 = old PayPal, 2 = pre-VPP, 3 = post-VPP) | bizmates.jp/fuel/app/classes/model/mstnewpricelisting.php (constants ~L12–14) |
| Price listing table (no effective-date columns) | ls-database-migrations/database/migrations/2025_07_24_061619_create_mst_new_price_listing_table.php |

### 6. What's decided

- Refund recognition month = the execution month; recognized as a single lump (no spreading back).
- Fixed / capped refunds are not day-prorated. A contract overlap produces no refund (corrected 2026-09-28).
- The allocation formula in a refund month is the same as a normal month; N is just negative.
- Shareholder-benefit cashback applies to CAP / CIP; only the "Bizmates Coaching" line is in scope; coaching cashback is capped at ¥19,800; it is registered as a cloned negative trn_charge.
- A CSV transaction_id split across rows is never summed.
- The auto-bundled App is the same product (product_id 10022) for CAP and CIP; its charge amount is 0; its allocation weight is price_flag = 2 = 3,618.
- Negative refund charges go through the same allocation entry point as positive charges.

### 7. Open items

| Item | Owner | Impact |
|---|---|---|
| Whether to add the shareholder-benefit cap-limit cases (¥19,800 coaching, ¥14,850 / ¥13,200 lesson, ¥3,980 App) as explicit rows in the sheet | Kuroda | Sheet completeness only |

### 8. Next steps

- Engineering: fold in §2.6 (negative refund charges use the same allocation entry point) when building step 6.
- Kuroda: confirm the new shareholder-benefit cap amounts with the executives (interim ¥19,800).
- Once decided, the cases are added to the sheet and this document is updated.

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

| Document | Relationship |
|---|---|
| `research/CAP/REF-CAP-09-Refund-Allocation-Requirements-20260908.md` | Earlier refund requirements — this doc refines them (CIP refund split made explicit; §3.8 overlap = no refund). |
| `research/CIP/REF-CIP-05-Residual-Value-Pricing-Replaces-Allocation-20260917.md` | REF-CIP-05 removed CIP from the allocation engine for **normal** charges — this doc adds the exception: **CIP refunds ARE split** by a fixed per-type rule. |
| `research/CAP/REF-CAP-12-ASCA-Spec02-Review-G1-20260928.md` | The Spec 02 G1 review thread (Kuroda-san + Patrick-san) that references this doc. |
| `projects/asca/specs/asca-spec-02b-refund-allocation/requirements.md` | Our 02b spec — must be revised to reflect: CIP-refund fixed-rule split (in scope), CAP refund→bundle pairing (Kuroda-san G1 #1), §3.8 overlap = no refund. |
| `projects/asca/documentation/asc-allocation-framework-technical-design.md` §1c | §1c (REF-CIP-05 note) needs a follow-up: CIP refunds are the exception to "CIP uses no engine." Not yet edited. |

> **Open item still blocking CIP-refund detail (from §2.6):** how the engine identifies a CIP refund's type (shareholder vs cooling-off vs tax-exemption) is unresolved — Kuroda-san is confirming and asked to hold the CIP refund-split part until then.
