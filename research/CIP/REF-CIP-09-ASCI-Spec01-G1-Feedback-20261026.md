# REF-CIP-09 — ASCI Spec 01 G1 Review Feedback (Kuroda-san, 2026-10-22 → 2026-10-23)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-26 (Saved) — source comments posted 2026-10-22 9:24 PM, 2026-10-23 9:22 AM, 2026-10-23 5:08 PM |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative. Kuroda-san's G1 review of ASCI Spec 01 requirements. Resolves the G1 refund-home decision; adds one blocker (B-1) + five wording fixes (W-1..W-5) + two add-ons; W-3/W-5 later confirmed. |
| **Audience** | Dev team (ASCA/ASCI — Throy, Cristoff), SDM (Patrick-san), QA (Glenn), Accounting |
| **Source channel** | Confluence — posted as comments on the published ASCI `requirements.md` doc |
| **Reviews** | `projects/asci/specs/asci-spec-01-cip-integration/requirements.md` (ASCI-01 G1 draft) |
| **Refines** | REF-CIP-05 (residual pricing), REF-CIP-06 (refund patterns), REF-CIP-07 (refund-type ID), REF-CIP-08 (lesson-bundled refund) |

> ⚠️ **Verbatim source document.** These are Kuroda-san's three Confluence review comments on the ASCI Spec 01 requirements, preserved in full. Do not alter this content; our interpretation / classification / impact analysis lives below in the clearly-marked "Cross-Reference" section and in `projects/asci/`.

---

## Comment 1 — Hayato Kuroda (2026-10-22, 9:24 PM)

> Hi Noel Palo san cc: Patrick Florentino ,
> thank you for this, I reviewed them. The worked example figures are all correct, and the overall direction is good.
> There is one blocker to resolve before G1 sign-off, plus a few wording fixes.
>
> **G1 decision (CIP refund home):**
> Agreed. Please specify and implement the CIP refund split inside ASCI-01.
>
> ### Blocker
>
> **B-1. The step that converts site amounts to booking amounts is missing (Introduction, Req 2.1, Req 2.3)**
>
> The Introduction and Req 2.1 say CIP charges are "already-priced" and flow through the existing daily pro-ration "unchanged".
>
> However, as agreed with Accounting (Wada-san, 2026-09-28), on the site the CIP App charge stays at paid_price = 0 and the Coaching Intensive charge carries the Coaching+App amount (¥75,900 for a standard month).
>
> The Glossary also says the App is "settled at ¥0 on site". The 71,920 / 3,980 split exists only in the accounting batch.
>
> If the existing pro-ration runs unchanged, it books 75,900 / 0, not 71,920 / 3,980. The spec does not yet have a requirement for the step that converts the site amounts into the booking amounts.
>
> Keeping "no ASCA allocation engine" is fine. A small CIP-specific conversion is enough. Please add a requirement that covers:
>
> - The actual trn_charge.paid_price of the Coaching Intensive (10025) and App (10022) charges on the site.
> - Where and how the batch converts them into Coaching 71,920 / App 3,980 before day-proration.
> - Discounted months: Coaching and App are discounted at the same rate. For example, with the first-month 50% campaign, Coaching is 35,960 and App is 1,990, then day-prorated as usual (CIP Calc Patterns, Pattern 3).
>
> Req 2.3 currently says the discount "lowers each charge's paid_price via the existing mechanism". The App charge is 0 on the site, though, so this result depends on the conversion step above.
>
> Please align the Req 2.2 / "No-engine invariant" wording with this conversion step.
>
> ### Wording fixes
>
> **W-1. Req 1.1 / 1.4: the price_flag = 3 record already exists.**
> The product 10025 / price_flag = 3 record (¥65,382 tax-excl) was already added through CIP-179 (Jefferson, approved 2026-09-25; tier2 = 32,691 is the table's standard 50% field). Please reference CIP-179 and change the requirement to "the record exists" instead of adding a new seeder. The user story "so that Coaching Intensive books as a real, non-zero charge" is misleading, because the Coaching Intensive charge is already non-zero on the site. Please rephrase it, for example: "...books at its residual price (¥71,920)".
>
> **W-2. Req 1.2: describe price_flag = 2 (¥66,500) as legacy.**
> For CIP, price_flag = 2 (¥66,500) was superseded by price_flag = 3 (agreed 2026-09-25). The record stays, but CIP does not use it. Please don't describe it as "the coaching reference/shareholder-refund weight".
>
> **W-3. Req 3.4: do not cap shareholder refunds in the batch.**
> The ¥19,800 cap applies when the shareholder refund CSV is prepared, before it reaches the batch. The batch should book the negative amount as it is and should not cap or truncate it. Also, "Coaching only, no App split" is the current assumption. Whether the App category applies to CAP/CIP shareholder refunds is still open, so please mark it as an open item rather than a confirmed rule.
>
> **W-4. Req 3.1: replace "any other Admin refund" with an explicit list.**
> For the CIP Coaching Intensive charge, the refund types are:
>
> | Refund type | Negative on Coaching Intensive charge | Split to App |
> |---|---|---|
> | Cooling-off (90%) | −68,310 | Yes → Coaching −64,728 / App −3,582 |
> | Consumption-tax exemption | −6,900 | Yes → Coaching −6,538 / App −362 |
> | Full refund | −75,900 | Yes → Coaching −71,920 / App −3,980 |
> | Shareholder benefit | −19,800 (interim) | No (Coaching only) |
> | Contract overlap (B2C/B2E → B2B) | None (Lesson charge only) | N/A |
>
> Please list cooling-off / consumption-tax exemption / full refund explicitly in Req 3.1, and keep it consistent with Req 3.7 (contract overlap creates no negative on the Coaching Intensive charge).
>
> **W-5. Shareholder benefit for lesson-bundled plans (1029–1032): I'm still confirming this.**
> The worked example table shows "Lesson row → Lesson charge (existing ASC)" for shareholder refunds. It's true that the system processes each CSV row on its own charge. However, whether the Lesson portion is also refunded for lesson-bundled CIP plans (and not only Coaching) is not decided yet. I'm confirming it with Accounting. Until then, please mark the Lesson part of the shareholder row as "TBD (PM confirming with Accounting)" instead of a confirmed behavior. The Coaching side (Coaching only, no App split, amount as given in the CSV) stays as in W-3.
>
> ### Confirmed as correct
>
> - All worked examples (cooling-off 1029 grand total −81,675; tax-exemption Lesson −1,350; −362 / −6,538)
> - Lesson isolation; refund booked as a lump sum in the paid_at month
> - CEIL day-proration (last month takes the remainder); PHP floor toward −∞ for negatives
> - Recording the trn_receipt_locked_charge dependency as a risk
>
> Once B-1 is reflected, I'm happy to sign off G1.
>
> Thank you.

---

## Comment 2 — Hayato Kuroda (2026-10-23, 9:22 AM)

> Hi Noel Palo san, cc: Patrick Florentino
>
> two add-ons to my ASCI Spec 01 review. Both come from the 2027 Honki Campaign, which gives CIP 50% off in the first month and the 6th month.
>
> Accounting team confirmed both points.
>
> **1. B-1: the 6th month too**
> The conversion in B-1 also applies to the 6th-month discount, not only the first month. Before proration, a half-price month splits into Coaching 35,960 / App 1,990, and each part is then prorated as usual.
>
> Could you add a 6th-month case to the tests?
>
> **2. W-4: refunds on a discounted month**
> The refund amounts in W-4 assume a normal 75,900 month. The rule behind them is: App refund = the App's booked amount × refund rate, and Coaching takes the rest.
>
> For a half-price month, the App's booked amount is 1,990, not 3,980. So please base the App share on the App's booked amount, not on the fixed 3,980. The App's booked amount comes from the original charge's paid amount (paid × 3,980 / 75,900).
>
> The original charge can be found through log_refund_history, the same way as agreed for 02b.
>
> Example: half-price month (paid 37,950 → Coaching 35,960 / App 1,990)
> - Cooling-off (90%): refund −34,155 → App −1,791 (= 1,990 × 90%) / Coaching −32,364
> - Consumption-tax exemption: refund −3,450 → App −181 (= 1,990 − 1,809 tax-excl) / Coaching −3,269
> - Full refund: −37,950 → App −1,990 / Coaching −35,960
>
> For a normal month the results stay the same as in W-4 (−3,582 / −362 / −3,980). Shareholder benefit is unchanged: Coaching only, still open (W-3).
>
> Nothing else is campaign-specific. The batch does not need to know which charges are Honki charges. Accounting confirmed it doesn't need that either.
>
> Thank you

---

## Comment 3 — Hayato Kuroda (2026-10-23, 5:08 PM)

> Hi Noel Palo san cc: Patrick Florentino
>
> Update on W-3 and W-5 (both now confirmed):
>
> **W-5:** Accounting confirmed that for lesson-bundled CIP plans (1029–1032), the Lesson portion is also eligible for the shareholder benefit cashback, because the student pays for the lessons too. The current table is correct: the Lesson row goes to the Lesson charge (existing ASC). Please remove the TBD.
>
> **W-3:** The App is not eligible, because the App is treated as paid together with Coaching (the App charge is ¥0 on the site). So "Coaching only, no App split" for shareholder refunds is now a confirmed rule, not an open item. The only remaining W-3 point is that the batch books the CSV amount as it is, without applying the ¥19,800 cap itself.
>
> Plz let me know if u have any questions.
>
> Thank you.

---

## Comment 4 — Hayato Kuroda (2026-10-28, 2:01 PM) — Round 2 / G1 confirmation

> Hi @Noel san
> cc: @Roi Patrick Florentino
>
> Thank you for the quick update.
> I checked the requirements and all of what I requested are reflected.
> The worked examples (standard and half-price months) are all correct too.
>
> **[Your two questions]**
>
> **Refund basis = the original charge's booked amount:**
> Agreed. It gives the same results for standard and half-price months. It is also more accurate when the amount is not evenly divisible. For example, for a full refund of a ¥50,000 site amount, the booked App is 2,621. The fixed ratio would reverse −2,622 (¥1 too much), while the booked basis reverses exactly −2,621.
> One wording request: "the refunded month's booked App amount" can be read as the day-prorated amount for a target month. Please define it as the original charge's booking amount before day-proration (and the same for original_site_amount).
>
> **price_flag = 2:**
> Please follow CIP-179 (the 10025 flag-2 rows are removed). My W-2 comment that it "stays" was wrong. ASCI does not depend on it, so the Req 1.2 open item can be closed.
>
> **[Two small additions (G1 condition)]**
> **A. Req 2 — which App row receives the converted amount.** The conversion writes the App booking amount (3,980) onto the paired App (10022) charge. Please state how the Coaching Intensive charge is paired with its App charge.
>
> I'd like to reuse the CAP rule (Spec 01 G1 1-5): group by student_id + order_no + plan_id, and match by contract period (start/end date) when order_no is NULL. Convert only when exactly 1 Coaching Intensive + 1 App is found. Otherwise skip without guessing (V-3), and record the reason on the run.
> Plz also state what is booked for a skipped pair (e.g. the site amounts 75,900 / 0 stay as they are).
>
> **B. Req 4 — where the App part of a refund is written.** The site creates a negative only on the Coaching Intensive charge, so there is no App row for the App portion.
> When the refund is executed after the contract has ended (e.g. a consumption-tax exemption or a shareholder refund months later), there is no App row in that month at all. Please state that CIP reuses the ASCA 02b Req 9 mechanism: insert a new App row in the refund's execution month carrying the negative App amount.
>
> **[For the design phase (no need to add to the requirements now)]**
>
> What happens if the original charge cannot be found via log_refund_history
> Multiple refunds on the same charge: the total App refund should not exceed the original App booking amount
> Add a test with a non-divisible amount (e.g. a ¥50,000 full refund) so the booked-basis behavior is actually covered
>
> Once A and B are added, G1 is approved from my side.
> Thank you

---

## Comment 5 — Hayato Kuroda (2026-10-28, 10:51 AM) — G1 approved + one design-phase point

> Thanks @Noel san, I confirmed all of them have been reflected, G1 approved.
>
> One small point for the design phase: Addition A says the skip reason is recorded "on the run", but CIP doesn't use the allocation run tables (No-engine invariant). Please decide in design where CIP skip reasons are recorded.
>
> Thank you

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

> Interpretation, classification, and impact analysis. None of this is Kuroda-san's text. The verbatim source ends above.

### What this resolves / changes

| Topic | Before (ASCI-01 draft) | After this feedback |
|---|---|---|
| **G1 refund-home decision** | Proposed: refund split inside ASCI-01 (G1 question) | ✅ **Confirmed** — "Agreed. Please specify and implement the CIP refund split inside ASCI-01." |
| **Site → booking conversion** | Absent — draft said charges are "already-priced" and prorated "unchanged" | ❗ **New requirement needed (B-1):** on the site App = ¥0 and Coaching Intensive = ¥75,900 (Coaching+App); the batch must convert to Coaching 71,920 / App 3,980 **before** day-proration. |
| **price_flag = 3 record** | Draft: "added via a seeder" (Req 1.1/1.4) | **Created by CIP-179** — verified in Jira: Task "Add price_flag for product_id 10025" (Jefferson; created 2026-09-25; status **QA Passed** as of 2026-10-12; tier1 65,382 / tier2 32,691 tax-excl). Requirement becomes "the record exists; confirm it shipped to the target env," reference CIP-179; no new seeder. (Status is QA-passed, **not** closed — "already exists" is softened accordingly.) |
| **Req 1 user story** | "so that Coaching Intensive books as a real, non-zero charge" | Misleading (CI is already non-zero on site). Rephrase → "books at its residual price (¥71,920)." |
| **price_flag = 2 (10025, ¥66,500)** | Draft (post-SF-1 fix): "the coaching reference weight" | For CIP it is **superseded by flag 3** (W-2). ⚠️ **Contradiction found in Jira:** W-2 says the flag-2 row "stays," but **CIP-179's acceptance criteria REMOVE the two 10025 flag-2 rows (66,500 tier1 / 33,250 tier2)**. ASCI must not depend on the flag-2 row existing; "stays vs removed" is an **open item** to confirm with Kuroda-san. |
| **Shareholder cap (¥19,800)** | Draft: book "capped at the interim ¥19,800"; cap is interim | Batch must **not** cap — it books the CSV amount as-is; the cap is applied upstream when the CSV is prepared. |
| **Shareholder App eligibility** | Draft: "Coaching only, no App split" stated as the rule | Comment 1 asked to mark it **open**; Comment 3 **confirmed** it: Coaching only, no App split is a **confirmed rule**. |
| **Refund-split basis (App numerator)** | Draft: fixed `FLOOR(refund × 3,980 / 75,900)` | **Changed (Comment 2):** base the App share on the **App's booked amount for that month** (from the original charge via `log_refund_history`), not the fixed 3,980. Normal month = 3,980 (unchanged results); half-price month = 1,990. |
| **Discounts** | Draft: generic "lowers each charge's paid_price via existing mechanism" | The conversion splits Coaching/App at the **same ratio** regardless of the month's paid amount (full ¥75,900 or discounted ¥37,950) — it is **campaign-agnostic**: the batch reads the month's paid amount and does **not** detect Honki / first-month / 6th-month (Comment 2, Accounting-confirmed). "First month + 6th month" is the **2027 Honki Campaign** shape (campaigns.md: Honki = month-1 + month-6, 50%), captured as **Req 4 test scenarios**, not as a branch in the conversion requirement. |
| **W-4 refund types** | Draft Req 3.1: "cooling-off, tax-exemption, or any other Admin refund" | Replace vague "any other Admin refund" with explicit list: cooling-off / consumption-tax exemption / **full refund** (−75,900 → Coaching −71,920 / App −3,980). |

### Verification (arithmetic re-checked against the source + REF-CIP-05/07)

Re-computed with PHP floor toward −∞, App numerator = the month's booked App amount:

| Case | Month basis | Refund | App share | Coaching share | Check |
|---|---|---|---|---|---|
| Cooling-off 90% (normal) | App 3,980 | −68,310 | FLOOR(−68,310 × 3,980 / 75,900) = −3,582 | −64,728 | ✓ (matches W-4 + REF-CIP-07) |
| Tax exemption (normal) | App 3,980 | −6,900 | FLOOR(−6,900 × 3,980 / 75,900) = −362 | −6,538 | ✓ |
| Full refund (normal) | App 3,980 | −75,900 | −3,980 | −71,920 | ✓ (new in W-4) |
| Cooling-off 90% (half-price) | App 1,990 | −34,155 | −1,791 (= 1,990 × 90%) | −32,364 | ✓ (Comment 2) |
| Tax exemption (half-price) | App 1,990 | −3,450 | −181 (= 1,990 − 1,809 tax-excl) | −3,269 | ✓ (Comment 2) |
| Full refund (half-price) | App 1,990 | −37,950 | −1,990 | −35,960 | ✓ (Comment 2) |
| Half-price month booking | — | paid 37,950 | App 1,990 | Coaching 35,960 | ✓ (= 71,920/2 ≈ 35,960; 3,980/2 = 1,990) |

> Note: the half-price booking splits 75,900 × 50% = 37,950 into 35,960 / 1,990. 35,960 + 1,990 = 37,950 ✓. The normal-month figure 35,960 = 71,920 / 2; 1,990 = 3,980 / 2 — the "same rate" rule, confirmed.
>
> The "App's booked amount comes from the original charge's paid amount (paid × 3,980 / 75,900)" is the **general rule** the fixed-3,980 figure was a normal-month special case of. For paid = 75,900 → App 3,980; for paid = 37,950 → App 1,990.

### Impact on the ASCI-01 requirements (proposal — NOT yet applied)

Classification and proposed edits are in `projects/asci/` for the Lead's review. In summary this feedback requires:

1. A **new requirement** for the site→booking conversion step (B-1) — the substantive addition. It must be written **campaign-agnostic**: the batch derives the Coaching/App split from the month's paid amount alone, at a fixed ratio, with **no** detection of Honki / first-month / 6th-month / any campaign (Comment 2; Accounting-confirmed "the batch does not need to know which charges are Honki charges"). Full month → 71,920 / 3,980; any half-price month → 35,960 / 1,990, via the same ratio. This is a per-month arithmetic transform, **not** the ASCA allocation engine, so the no-engine invariant still holds.
2. **Req 1** rewording (record exists / CIP-179 / residual-price user story).
3. **Req 3.1** explicit refund-type list incl. full refund; refund basis changed to the month's booked App amount (resolved via `log_refund_history`).
4. **Req 3.4** shareholder: remove in-batch cap; Coaching-only now a confirmed rule.
5. **Req 4** add discounted-month verification scenarios — both **first month** and **6th month** (the 2027 Honki Campaign shape: 50% off in those two months per campaigns.md), plus the matching refund-on-discounted-month cases (W-4 add-on). These are **test inputs** that exercise the generic conversion rule — the campaign months are not encoded in the requirement itself (see item 1).
6. Align Req 2.2 / "No-engine invariant" / glossary with the conversion step (the conversion is CIP-specific and still not the ASCA allocation engine).

### Related documents

| Document | Relationship |
|---|---|
| `projects/asci/specs/asci-spec-01-cip-integration/requirements.md` | The doc under review; to be revised per this feedback (gated — Lead to approve). |
| `research/CIP/REF-CIP-05-...` | B-1's site-amount reality (App ¥0, CI carries Coaching+App) refines REF-CIP-05 §2.2's "two separate already-priced charges" framing: the split is a batch step, not a site state. |
| `research/CIP/REF-CIP-06-...` | §2.3 confirms App 10022 on the site = paid_price 0; this feedback makes the conversion step explicit. |
| `research/CIP/REF-CIP-07-...` | Refund fixed-ratio — now generalized to "App's booked amount × rate" (normal month identical). |
| `research/CIP/REF-CIP-08-...` | Lesson-bundled per-charge refunds; W-5 confirms the Lesson shareholder row. |
| CIP-179 (Jefferson) | The ticket that creates the 10025 price_flag=3 record — referenced by W-1. **Verified in Jira (2026-10-26):** Task "Add price_flag for product_id 10025", created 2026-09-25, status **QA Passed** (as of 2026-10-12), tier1 65,382 / tier2 32,691 tax-excl. Its ACs **also remove** the 10025 price_flag=2 rows (66,500 / 33,250) — the source of the W-2 "stays vs removed" open item. No seeder for this record exists in any of the four code repos (`ReferencePriceSeeder` explicitly disclaims it: "CAP-only; no CIP (10025) row"). |
| CIP Calc Patterns (Google Sheets) | Pattern 3 (half-price conversion) cited in B-1 / Comment 2. |
| `domain-knowledge/campaigns.md` → Honki Set | Authoritative source for the Honki Set shape used only as a **durable campaign fact** (month-1 + month-6, 50%, App ¥0). Its ASCH proration mechanics (List-Price-basis) are **NOT** used — they predate CIP residual pricing and do not apply to CIP. |

### Round 2 (Comment 4, 2026-10-28) — G1 approved pending A + B

**Verdict:** approved-with-two-additions. "Once A and B are added, G1 is approved from my side." All round-1 changes and both worked-example tables confirmed correct.

| Item | Classification | Action |
|---|---|---|
| Refund basis = original charge's booked amount | ✅ Confirmed (with the ¥50,000 → −2,621 vs −2,622 non-divisible rationale) | None — already folded |
| Wording: define "booked amount" precisely | **Req change** | Req 4.1/4.2: define as the **original charge's booking amount BEFORE day-proration** (same for `original_site_amount`); drop the "refunded month's" phrasing |
| price_flag = 2 "stays" was wrong | ✅ Open item CLOSED | Req 1.2: follow CIP-179 (flag-2 rows removed); remove the "stays vs removed / open item" framing |
| **A — Req 2 App-charge pairing** | **Req change (G1 condition)** | Add AC: pair Coaching Intensive ↔ App via the CAP rule (Spec 01 G1 1-5) — group by `student_id + order_no + plan_id`, match by contract period when `order_no` NULL; convert only when exactly 1 CI + 1 App; else skip (V-3), record reason on the run; a skipped pair keeps its site amounts (75,900 / 0) |
| **B — Req 4 App refund row home** | **Req change (G1 condition)** | Add AC: reuse the **ASCA 02b Req 9** mechanism — insert a new App row in the refund's execution month carrying the negative App amount (site makes a negative only on the CI charge; after contract-end there is no App row that month) |
| 3 design-phase notes | Parked (he says NOT in requirements) | missing `log_refund_history` link handling; multi-refund cap (Σ App refund ≤ original App booking); add a non-divisible (¥50,000) test |

**Status:** fold the 3 req changes (wording + A + B) and close the flag-2 item → that meets the G1 condition → then promote to the code-repo `.kiro/specs/` + create the ASCI epic/stories. Design-phase notes recorded here for the G2 phase.

**Comment 5 (2026-10-28, 10:51 AM) — G1 confirmed reflected + one design-phase point.** Kuroda-san confirmed all folded changes and **approved G1**. He flagged a self-consistency point: Addition A (Req 2.8) says the skip reason is recorded "on the run", but CIP has no allocation run tables (no-engine invariant), so it cannot reuse CAP's on-the-run recording. **Not a G1 change** — captured as **design-phase note #4** (decide where CIP records conversion skip reasons) and the Req 2.8 wording softened to drop the "on the run" assumption. Carried into the G2 story (ASCI-10).

> Compliance note: the verbatim section reproduces Kuroda-san's own review comments in full (internal source document, preserved by request). All analysis in this Cross-Reference section is paraphrased interpretation.
