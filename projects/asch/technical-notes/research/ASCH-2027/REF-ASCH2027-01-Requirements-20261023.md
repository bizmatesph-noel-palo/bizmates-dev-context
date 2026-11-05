# REF-ASCH2027-01 — ASCH 2027: Revenue Booking for the 2027 Honki Campaign (Requirements)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim capture) |
| **Date** | 2026-10-29 (Captured) — source last updated 2026-10-23 |
| **Author (source)** | Hayato Kuroda (PM) |
| **Captured by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — source draft. Kuroda-san's **[DRAFT]** requirements for the NEW 2027 ASCH. |
| **Source channel** | Confluence — "[DRAFT] ASCH 2027 — Revenue Booking for the 2027 Honki Campaign: Requirements" |
| **Audience** | Dev team (Noel, Throy, Cristoff), QA (Glenn), SDM (Patrick-san), Accounting |

> ⚠️ **NEW project, not the cancelled 2026 ASCH.** The name is reused; the architecture is fundamentally different (see the Cross-Reference section below). This is a **verbatim capture** of Kuroda-san's draft; our interpretation/overlap analysis lives in the clearly-marked Cross-Reference section and in `projects/`, not here.
>
> ⚠️ **Placement note (PROVISIONAL — restructure deferred, Lead 2026-10-29):** this doc currently sits under the **cancelled 2026** ASCH project tree (`projects/asch/technical-notes/research/ASCH-2027/`), which is misleading. A plain `projects/asch-2027/` is **rejected** (it would imply the 2026 ASCH shipped). Agreed approach, to execute later: **archive the obsolete 2026 ASCH docs** (pooled-proration engine, 9-table schema, adjustment-journal/CSV — all superseded) and **retain only what the 2027 ASCH needs**, then settle the structure and move this file. Tracked in `docs/asc-projects-task-tracker.md` (Cross-cutting). Until then, this path stands.

---

## Verbatim source (Kuroda-san, Confluence, last updated 2026-10-23)

### 1. Summary
The 2027 Honki Campaign gives a 50% discount in the first month and in the 6th month to customers who take Coaching 30 min (CAP) or Coaching Intensive (CIP), together with an English lesson plan.

For the revenue-booking system (ASC), almost no campaign-specific logic is needed. The discount is applied on the billing side. The charge batch issues the discounted charge, so the discount is already in the charge's paid amount.

ASC books that paid amount with logic that already exists or is being built:
- Lesson: existing booking, no allocation.
- CAP (Coaching 30 min + App): ASCA proportional allocation.
- CIP (Coaching Intensive + App): ASCI ratio split (see §4.3).

ASC does not need to know which charge is a Honki charge. The main work is: (1) making sure the CIP split and the CIP refund split work for half-price months, and (2) testing the campaign patterns.

### 2. Scope
**In scope:** customers eligible for the 2027 Honki Campaign (applications from 2027-01-04); plans Coaching 30 min with App auto-attached (CAP) and Coaching Intensive (CIP), each with an English lesson plan; months affected = first month (50% off) and 6th month (50% off); months 2–5 normal.

**Out of scope:** 2026 Honki Campaign participants (current flow); a new Honki-only plan (campaign reuses existing CAP/CIP plan_id + product_id); identifying Honki charges in the revenue data (not needed — Accounting 2026-10-23); billing-side changes (campaign mgmt, eligibility, charge batch → CDB project).

### 3. How the discount reaches ASC
1. **CDB (campaign):** eligibility stored in `trn_campaign_discount_eligibility`, one row per student × campaign × product.
2. **Charge batch:** issues first-month + 6th-month charges at the half-price tier. No manual refund by CS.
3. **ASC:** books the charge's paid amount as usual. No campaign lookup.

CDB table notes (reference only; ASC does not read it): `discount_grant_status`: -1 = not eligible, 0 = not yet eligible, 1 = eligible / not granted, 2 = 6th-month discount granted. First-month charge stored as `initial_charge_id`. The 6th-month charge ID is NOT stored in the DB (application log only).

### 4. Booking rules
**4.1 Lesson** — booked on its own, existing logic, not allocated with Coaching/App. A Lesson discount stays on the Lesson line. **This replaces the previous ASCH design, which pooled Lesson + Coaching + App and split them together.**

**4.2 CAP (Coaching 30 min + App) — ASCA allocation, no change.** Existing ASCA formula on the discounted amount:
```
N = Coaching charge's booked amount for one month (discounted paid amount, prorated by existing daily logic; formula applied to each month's N separately)
App = floor(N × 3,618 / (36,000 + 3,618))
Coaching = N − App
```
Weights = tax-excluded list prices (Coaching 30 min 36,000 : App 3,618). In a half-price month, App goes down at the same rate as Coaching (Accounting 2026-10-22).

**4.3 CIP (Coaching Intensive + App) — ratio split.** On the site the Coaching Intensive charge carries the whole Coaching+App amount (75,900 normal month) and the App charge is ¥0. The 71,920 / 3,980 split exists only in the revenue-booking batch (Accounting 2026-09-28; replaces the "two already-priced charges" description in the 2026-09-17 change note).

Price records (`mst_new_price_listing`, tax-excluded):
| Product | product_id | price_flag | Price | Used by |
|---|---|---|---|---|
| Bizmates App Premium (auto, CAP+CIP) | 10022 | 3 | 0 | Site: App charge is ¥0 |
| | 10022 | 2 | 3,618 (3,980 tax-incl) | Revenue booking: App weight/price |
| Coaching Intensive | 10025 | 4 | 69,000 (75,900 tax-incl) | Site: Coaching Intensive charge |
| | 10025 | 3 | 65,382 (71,920 tax-incl) | Revenue booking: residual price (CIP-179) |
| | 10025 | 2 | 66,500 | Legacy, not used for CIP |

Accounting (2026-10-22): treat residual price 71,920 as the Coaching Intensive list price, split the amount actually paid by 71,920 : 3,980 (Coaching and App discounted at the same rate):
```
paid     = paid amount of the Coaching Intensive charge (after discount)
App      = paid × 3,980 / 75,900
Coaching = paid − App
```
Split done **before** daily proration; each part then prorated with existing logic (`getContractDateInfoList()`). Normal month: App 3,980 / Coaching 71,920. Half-price: App 1,990 / Coaching 35,960 (contract amounts before proration). Example (CIP calc pattern 3, 1/15–2/14): Jan books Coaching 19,720 / App 1,092; Feb books Coaching 16,240 / App 898. **Ratio split, not fixed amounts — booking App at 3,980 in a half-price month is wrong.** This conversion step is being added to ASCI Spec 01 (review comment B-1, 2026-10-22); not campaign-specific — applies to any discounted month.

**4.4 Refunds (CIP)** — existing CIP refund rules (2026-09-28, ASCI Spec 01 review W-4) kept, with one generalization for discounted months. Not day-prorated; booked in the execution month.
| Refund type | Negative on CI charge | Coaching | App |
|---|---|---|---|
| Cooling-off (90%) | −68,310 | −64,728 | −3,582 |
| Consumption-tax exemption | −6,900 | −6,538 | −362 |
| Full refund | −75,900 | −71,920 | −3,980 |
| Shareholder benefit | −19,800 (interim) | −19,800 | none (current assumption, open) |
| Contract overlap (B2C/B2E → B2B) | none (Lesson charge only) | — | — |

Shareholder: ¥19,800 cap applied when the refund CSV is prepared; batch books the CSV amount as-is and does not cap. Whether App gets a share is still open. Lesson-bundled CIP (1029–1032): Lesson part of a refund goes on the Lesson charge (existing ASC); whether Lesson is also refunded for shareholder benefit is being confirmed with Accounting.

**4.5 Cancellation within 6 months** — first-month discount NOT reversed (no extra charge, no refund). Only the 6th-month discount is lost. ASC books the charges actually issued; no special handling (same as pattern 5 in the previous ASCH design).

### 5. Worked examples (tax-included, month starts on the 1st)
**5.1 Daily 1 lesson + Coaching 30 min (CAP):** Normal — Lesson 14,850 / Coaching 38,483 / App 3,867 / Total 57,200. First/6th (50%) — Lesson 7,425 / Coaching 19,242 / App 1,933 / Total 28,600. (Note: deck's billing example 54,450 uses the old coaching price before CAP; with CAP it is 57,200.)

**5.2 CIP (Coaching + App part only):** Normal — Coaching 71,920 / App 3,980 / Total 75,900. First/6th (50%) — Coaching 35,960 / App 1,990 / Total 37,950. Lesson-bundled CIP: Lesson charge separate, follows §4.1.

### 6. Expected changes to ASC
| Area | Change | Size |
|---|---|---|
| Lesson | None | — |
| CAP | None (ASCA formula already uses the discounted N) | Test only |
| CIP | Covered by ASCI: conversion step (B-1) must follow the paid amount; refund split must use App's booked amount, not a fixed 3,980 (§4.3, §4.4) | Small; part of ASCI, then test |
| Campaign lookup / Honki flag | None | — |
| CSV / Metabase output | None | — |

### 7. Test patterns (to be detailed)
1. First month 50%, starts on the 1st — CAP/CIP.
2. First month 50%, starts mid-month (spans two months) — CAP/CIP.
3. 6th month 50% — CAP/CIP.
4. Cancel within 6 months (first-month kept, no 6th-month) — CAP/CIP.
5. Lesson plan change during the 6 months (e.g. 15 lessons ↔ 2 lessons) — CAP.
6. Move between CIP and Coaching 30 min during the 6 months (both directions; loses 6th-month 50%, 6th month full price; first-month 50% kept) — CIP ⇔ CAP.
7. Already has a lesson plan, joins coaching later (first-month 50% on coaching only) — CAP/CIP.
8. Refunds in a half-price month (cooling-off, consumption-tax, shareholder cashback) — CIP.

Detailed sheet extends the existing CAP sample (P3, first month 50%) and CIP pattern 3.

### 8. Open items (source)
1. CIP: add the conversion step (75,900/0 → 71,920/3,980) to ASCI Spec 01, working for discounted months too (§4.3) — **Noel** — requested in Spec 01 review (B-1, 2026-10-22); 6th-month case added 2026-10-23; waiting for reply.
2. CIP refund split: base the App share on the App's booked amount so half-price months work (§4.4) — **Noel** — sent 2026-10-23; waiting for reply.
3. CDB catalog for 2027: add auto-attached App 10022 (CDB currently expects 10021) and CIP Coaching Intensive 10025; read the half-price tier for CAP/CIP `price_flag = 4` — **Soli-san (CDB)** — to send.
4. Shareholder benefit for CAP/CIP: does App get a share? For lesson-bundled CIP, is the Lesson also refunded? — **Accounting (Ito-san)** — confirming.
5. Update the deck's billing example (54,450 → 57,200) and fill in the application end date — **Business** — to confirm.

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

> Interpretation, overlap analysis, and impact. None of this is Kuroda-san's text.

### Headline: the 2027 ASCH is a near-no-op, architecturally unrelated to the cancelled 2026 ASCH

| Dimension | Cancelled 2026 ASCH | NEW 2027 ASCH |
|---|---|---|
| Core idea | Heavyweight **adjustment-journal engine**: read ASC output N, prorate a pooled Lesson+Coaching+App bundle, send P−N adjustment journals to Freee | **Almost no ASC logic.** Discount is already in the charge's paid amount; ASC books it with existing/ASCA/ASCI logic |
| Allocation | **Pooled 3-product** proration (ΣM × basis/Σbasis), O-carryover, L-vs-M basis rule | **No pooling.** Lesson booked alone (§4.1); CAP → ASCA 2-way; CIP → ASCI ratio split |
| New DB tables | **9** (`asch_*`) | **None** |
| New CSVs / Freee journals | AschComponentDetail + AschCalculationSummary + adjustment journals | **None** (§6: no CSV/Metabase change) |
| Honki identification in ASC | Required — read CDB `trn_campaign_discount_eligibility` (`discount_flag=2`) | **Not needed** (Accounting 2026-10-23) — ASC never looks up the campaign |
| App product_id | 10021 (old assumption) | **10022** (CAP/CIP actual) |
| CIP pricing | ¥88,000 / engine 3-way (old) | **Residual 71,920 + App 3,980, ratio split, no engine** (REF-CIP-05/09) |
| Net ASC work | Build a whole subsystem | **Test CAP; ensure CIP (ASCI) half-month conversion + refund split work; write the 8 test patterns** |

**So "overlap vs the cancelled 2026 ASCH" = almost none of the old design survives.** The 2027 ASCH does **not** resurrect the `asch_*` tables, the pooled proration, the adjustment-journal engine, or the ASC-side Honki identification. It rides CAP (ASCA, done) and CIP (ASCI, in build) which already allocate on the discounted paid amount. The §4.1 line is explicit: "This replaces the previous ASCH design, which pooled Lesson + Coaching + App and split them together."

### Reuse / dependency clarification (two lineages — do not conflate)

"Overlap vs the cancelled 2026 ASCH = almost none" refers only to the **old ASCH's own design artifacts** (the `asch_*` tables, the pooled 3-product proration, the adjustment-journal engine). That specific machinery is dead — §4.1 replaces it with "Lesson booked alone." It does NOT mean the 2027 ASCH is standalone.

On the contrary, the 2027 ASCH has **total runtime dependency on ASCA + ASCI** — it builds no engine, DB, or services of its own precisely because it reuses theirs:

| 2027 ASCH booking path | Reuses (at runtime) |
|---|---|
| CAP (Coaching 30 + App) | **ASCA allocation engine** — `log_alloc_*` tables, `mst_alloc_reference_prices`, `RevenueAllocationService` / `AllocationInjector`, `TwoWayAllocationFormula` (§4.2 = "the existing ASCA formula is applied") |
| CIP (Coaching Intensive + App) | **ASCI Spec 01** — the site→booking conversion (Req 2) + the refund split (Req 4), which themselves reuse ASCA 02b's `log_refund_history` linkage + new-App-row mechanism |
| Lesson | existing ASC daily-rate path |

And separately, a **design-heritage** lineage: ASCA/ASCI themselves reused the *research + engineering standards* from the cancelled 2026 ASCH (per the ASC allocation technical design: "the architecture research and engineering standards from ASCH are reused in this framework"). So the ASCH thinking lives on **inside ASCA/ASCI**, which the 2027 ASCH then rides.

**Precise statement:** the 2027 ASCH reuses **everything** from ASCA/ASCI (engine, DB, services) and **almost nothing** from the cancelled 2026 ASCH's own design. The two "almost none" vs "everything" claims are about different things — the old ASCH's bespoke machinery vs. the ASCA/ASCI machinery — and must not be blurred.

### The critical finding: 2027 ASCH's CIP work is ALREADY inside ASCI Spec 01

§6 + Open Items 1–2 state the only CIP changes the 2027 ASCH needs are:
- the **site→booking conversion** that follows the paid amount and works for discounted months (= ASCI Spec 01 **Req 2**, the B-1 step — already in our G1-approved requirements + design + tasks T4);
- the **refund split using the App's booked amount, not a fixed 3,980** (= ASCI Spec 01 **Req 4**, basis via `log_refund_history` — already Req 4.2 + design + tasks T6/T8).

**Both are already specified, designed, and task-planned in ASCI Spec 01** (G1-approved 2026-10-28; design + tasks generated). Kuroda-san's Open Items 1–2 say "waiting for reply" dated 2026-10-23 — but REF-CIP-09 Comment 4 (2026-10-28) already folded both in and approved G1. **So the 2027 ASCH's CIP asks are satisfied by ASCI; they are not new ASCH work.** This is the key point for the feedback to Kuroda-san.

### What IS genuinely new 2027 ASCH work (small)

1. **CAP half-price-month verification** — confirm the ASCA 2-way formula on a discounted N yields the same-rate App reduction (§4.2 / §5.1 worked example: 57,200 → 28,600). ASCA is merged; this is a **test**, not code.
2. **The 8 test patterns (§7)** — especially the campaign-transition ones ASCI doesn't cover: pattern 5 (Lesson plan change mid-campaign), pattern 6 (CIP ⇔ CAP move, loses 6th-month 50%), pattern 7 (joins coaching later). These are end-to-end campaign scenarios across CAP+CIP+Lesson, broader than ASCI Spec 01's own tests.
3. **Reconciliation of the §4.1 "Lesson booked alone" rule** — confirm no residual expectation that ASC pools Lesson with Coaching/App (it doesn't, post-ASCA/ASCI).

### CDB dependency — now concrete (resolves the tracker's provisional note)

- 2027 ASCH confirms **ASC does NOT read CDB** (§2, §3) — the discount arrives already baked into `paid_price`. So the tracker's "ASCH reads `trn_campaign_discount_eligibility`" assumption (inherited from the *cancelled* ASCH's REF-CDB-02 Gap #5) is **superseded for the 2027 ASCH** — the honki-student identification burden is gone from the ASC side.
- BUT CDB still has a 2027 gap that affects us indirectly: **Open Item 3** — CDB's catalog still expects App **10021**, must be updated to **10022**, plus CIP 10025 and the half-price `price_flag=4` tier. Owner Soli-san (CDB). If CDB issues charges against the wrong App product_id, the charges ASC books would be wrong at the source. **This is the real CDB recheck for 2027** — not a schema-read contract (we don't read it), but a charge-correctness dependency.
- `discount_grant_status` enum here (-1/0/1/2) differs in naming from REF-CDB-02's `discount_flag` (1/2). Worth confirming CDB's current column with Soli-san, but since ASC doesn't read it, it's informational for us, not blocking.

### Recommended feedback to Kuroda-san

1. **Agree with the framing** — 2027 ASCH needs almost no ASC-side logic; it rides ASCA + ASCI on the discounted paid amount. Confirm the old pooled-proration ASCH design is fully retired (§4.1).
2. **Open Items 1 + 2 are already DONE** — the CIP conversion (B-1) and the booked-amount refund basis are folded into ASCI Spec 01 and G1-approved (REF-CIP-09 Comment 4, 2026-10-28). Recommend closing them as resolved and pointing at `asci-spec-01-cip-integration`.
3. **Scope the 2027 ASCH as a test-and-verify effort** (CAP half-month test + the 8 §7 patterns), not a build — likely no new spec, or a thin verification spec. Confirm whether it even needs its own JIRA project or folds into ASCI's QA.
4. **Flag CDB Open Item 3 (App 10021→10022) as the real upstream risk** — if CDB issues charges on the wrong App product, ASC books wrong numbers. Suggest confirming with Soli-san before the 2027-01-04 application window.
5. **Shareholder-App-share (Open Item 4)** — still open in both ASCI (Req 4.4 marks it confirmed Coaching-only) and here; reconcile so the two docs agree.

### Related documents
- `projects/asci/specs/asci-spec-01-cip-integration/` — where the 2027 ASCH's CIP asks already live (Req 2 conversion, Req 4 refund split).
- `research/CIP/REF-CIP-09-...` — Kuroda-san's ASCI G1 feedback that already folded in Open Items 1–2.
- `research/CDB/REF-CDB-02-...` — the cancelled ASCH's CDB cross-check (now largely superseded for ASC: 2027 ASC does not read CDB).
- `projects/asch/project-context.md` — the CANCELLED 2026 ASCH (architecture that the 2027 version does NOT reuse).
- `domain-knowledge/campaigns.md` — Honki Set campaign shape.

---

## Slack thread (verbatim — Kuroda-san, team channel)

> Captured 2026-10-29. These messages accompanied the Confluence [DRAFT] above and define what the PM is asking the team to return. Verbatim; analysis in the next section.

**Hayato Kuroda — 2026-10-23, 10:53 AM**
> Hi @Roi Patrick Florentino san @Noel san
> For the ASCH for 2027 I put the requirement here — [DRAFT] ASCH 2027 — Revenue Booking for the 2027 Honki Campaign: Requirements.
> Some of the requirement are still not sure but kindly estimate based on this.
> BTW I used previous ASCH board so u can change if it's better.
> Thank you.

**Hayato Kuroda — 2026-10-23, 10:54 AM**
> @Noel san
> **Summary**
> - ASC needs almost no campaign-specific logic. The charge batch issues the 50% charges (first month and 6th month), and ASC books the paid amount as usual.
> - Lesson: existing booking. CAP: the ASCA allocation as is. CIP: the ASCI conversion and refund split.
> - ASC does not need to know which charges are Honki charges. Accounting confirmed this.
>
> Based on the requirement, plz let me know following Questions:
> 1. ASCI (§4.3, §4.4): the two points I sent yesterday in the Spec 01 thread (6th-month case for B-1, and the refund split based on the App's booked amount). Are they OK to include in ASCI-01?
> 2. Anything else to change in ASC? §6 lists what I expect to change. Please tell me if you see anything else, for example in CAP or in the existing proration.
> 3. Effort: could you give a rough estimate for the ASC part of the campaign? I expect it to be mostly testing (§7 test patterns), plus the CIP points above if they are not already in the ASCI estimate.
>
> No rush on 3. A rough number is enough for now. Thank you.

**Hayato Kuroda — 2026-10-28, 4:10 PM**
> BTW @Noel san
> When do u think u could estimate this new PJ?
> Kindly note to handle this after the prioritized tasks in ASCA/I, thank you.

---

## Response analysis (added by Noel — NOT Kuroda-san's text)

> Draft answers to the three questions + the estimate-timing follow-up. For the Lead to review before replying on Slack/Confluence.

### Q1 — ASCI §4.3 / §4.4: are the 6th-month B-1 case + booked-amount refund basis OK to include in ASCI-01?

**Answer: Yes — and they are already in ASCI-01, G1-approved.** Both points landed in REF-CIP-09 Comment 2 (2026-10-23) and were folded into the ASCI Spec 01 requirements, which Kuroda-san **G1-approved on 2026-10-28** (REF-CIP-09 Comment 4). Specifically:
- **6th-month B-1 conversion** → ASCI Req 2 is campaign-agnostic (derives the split from the month's paid amount; §4.4 "first and sixth month" are test scenarios, Req 5, not branches). Already in design + tasks (T4).
- **Refund split on the App's booked amount** → ASCI Req 4.2 (basis = original charge's booking amount before day-proration, via `log_refund_history`; 1,990/37,950 for a half-price month, not a fixed 3,980). Already in design + tasks (T6/T8).

So Q1 is a **close-the-loop**: the two Slack points (dated 2026-10-23, "waiting for reply") have since been answered and approved inside ASCI-01. Point Kuroda-san at `asci-spec-01-cip-integration` and REF-CIP-09 Comment 4.

### Q2 — Anything else to change in ASC beyond §6?

**Answer: §6 is essentially complete. Three small observations, none of them new code:**
1. **CAP needs a half-price-month verification, not a change.** §4.2 is correct that the ASCA formula already operates on the discounted N — but confirm via test that a half-price N yields the same-rate App reduction (§5.1: 57,200 → 28,600). ASCA is merged; this is a QA item.
2. **The §4.1 "Lesson booked alone" rule should be verified against the current pipeline** — confirm no residual expectation that ASC pools Lesson with Coaching/App (it doesn't, post-ASCA/ASCI). Reconciliation, not code.
3. **No existing-proration change** — the CEIL day-proration (REF-CAP-17, last month = remainder) already handles the discounted amounts; the discount is just a smaller paid_price flowing through unchanged.

Nothing in CAP or the existing proration needs new logic. The one genuine upstream risk is **not in ASC**: CDB Open Item 3 (CDB catalog still expects App 10021, must be 10022) — flag it to Soli-san, since wrong charges at the source would make ASC book wrong numbers.

### Q3 — Rough estimate for the ASC part

**Answer (rough, as requested): ~3–5 dev-days, almost entirely testing — assuming ASCI-01 ships as planned.**
- **CIP conversion + refund (§4.3/§4.4):** already in the ASCI-01 estimate — **0 incremental** for the 2027 ASCH.
- **CAP:** no code — **test only.**
- **The 8 §7 test patterns:** the bulk of the effort. Patterns 1–4, 8 are largely covered by ASCI-01's own tests + a CAP half-month case. Patterns **5 (Lesson plan change), 6 (CIP⇔CAP move), 7 (joins coaching later)** are campaign-transition scenarios broader than ASCI's unit scope → these are the net-new verification work (~2–4 days to build fixtures + run on DEV04 + reconcile).
- **No new build** — no spec, no tables, no services. Likely folds into ASCI's QA story rather than a standalone build.

Caveat: this assumes the still-open items don't expand scope — shareholder-App-share (Open Item 4) and the CDB catalog fix (Open Item 3) are the variables. If shareholder handling changes, add a small amount.

### Q (follow-up 2026-10-28) — When can you estimate this new project?

**Answer: the rough estimate above can go to Kuroda-san now** (it's what he asked for — "a rough number is enough"). A **firmer** estimate waits until after the prioritized ASCA/I tasks, per his own instruction ("handle this after the prioritized tasks in ASCA/I"). Concretely: deliver the rough number this week; firm it up once ASCI-11 Coding is underway (so the §7 test-pattern effort is grounded in the real code), targeting **before the Nov 11 leave** so Kuroda-san has it in hand during the absence.

### Board question (10:53 message)
Kuroda-san used the **previous ASCH JIRA board** and invited a change. Recommendation ties to the deferred doc-structure decision: since the 2027 ASCH is a distinct project, decide board reuse-vs-new together with the `projects/` restructure (archive old 2026 ASCH, retain what 2027 needs). Low priority; note it, decide later.
