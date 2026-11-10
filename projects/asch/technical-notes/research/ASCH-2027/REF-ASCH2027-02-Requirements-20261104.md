# REF-ASCH2027-02 — NEW ASCH (2027) Requirements, Kuroda-san's re-created Confluence page (2026-11-04)

## Document Info

| | |
|---|---|
| **Document type** | Research reference (upstream requirements capture) |
| **Status** | Active — supersedes REF-ASCH2027-01 as the current requirements source |
| **Date** | 2026-11-05 (captured) · source page last updated 2026-11-04 10:51 |
| **Source** | Hayato Kuroda (PdM), Confluence "ASCH 2027 — Revenue Booking for the 2027 Honki Campaign: Requirements" + his Slack comment |
| **Captured by** | Noel Palo, Lead · assisted by Kiro |
| **Supersedes** | `REF-ASCH2027-01-Requirements-20261023.md` (prior page; several open items now closed — see §Diff) |

> **Naming:** "ASCH" here = the **NEW 2027 ASCH**. The cancelled 2026 project is "OLD ASCH".

---

## 1. Why this capture exists

Kuroda-san re-created the ASCH 2027 requirements page with the latest version and asked us to use the new page. He also accepted our estimate ("testing only, 3–5 dev-days / ~2–2.5 weeks with buffer"). This doc captures the new page verbatim-in-substance + his Slack comment, and records what changed vs REF-ASCH2027-01.

## 2. Verbatim-in-substance capture of the new page

### Summary
2027 Honki Campaign: 50% off in month 1 and month 6 for customers taking Coaching 30 min (CAP) or Coaching Intensive (CIP) together with an English lesson plan. For ASC, almost no campaign-specific logic. Discount is applied billing-side; the charge batch issues the discounted charge, so the discount is already in the paid amount. ASC books the paid amount: Lesson (existing, no allocation), CAP (ASCA proportional allocation), CIP (ASCI ratio split). ASC does not need to know which charge is a Honki charge. Main work = testing the §7 patterns. CIP half-price points already in ASCI Spec 01 (G1 approved 2026-10-28); ASCH depends on ASCI shipping.

### Scope
- **In:** 2027 Honki-eligible customers (applications from 2027-01-04); CAP (Coaching 30 min + auto App) and CIP (Coaching Intensive) each with an English lesson plan; months 1 and 6 are 50% off, months 2–5 normal.
- **Deadline (NEW):** first Honki charges issued from 2027-01-04 → first close booking them = January 2027 (batch early Feb). **ASC must be in production with CAP+CIP by end of January 2027.** ASCI (CIP) keeps its own 2026-12-17 deadline.
- **Out:** OLD-ASCH (2026) participants; a Honki-only plan; identifying Honki charges in revenue data; billing-side changes (CDB).

### 3. How the discount reaches ASC
CDB stores eligibility (`trn_campaign_discount_eligibility`, one row per student×campaign×product) → charge batch issues month-1 and month-6 charges at the half-price tier (no manual CS refund) → ASC books the paid amount as usual, no campaign lookup. CDB `discount_grant_status`: -1 not eligible, 0 not yet, 1 eligible/not granted, 2 6th-month granted. Month-1 charge = `initial_charge_id`; 6th-month charge ID not in DB (app log only). **ASC does not read this table.**

### 4. Booking rules
- **4.1 Lesson:** booked alone, existing logic; a Lesson discount stays on the Lesson line. (Replaces OLD-ASCH's pooled Lesson+Coaching+App split.)
- **4.2 CAP (Coaching 30 + App) — ASCA, no change:** `N` = Coaching charge's booked amount for the month (discounted paid amount, prorated by existing daily logic, per month separately); `App = floor(N × 3,618 / (36,000 + 3,618))`; `Coaching = N − App`. Half-price month: App goes down at the same rate (Accounting 2026-10-22).
- **4.3 CIP (Coaching Intensive + App) — ratio split:** site Coaching Intensive charge carries the whole amount (75,900 normal); App charge ¥0. The 71,920/3,980 split exists only in the revenue batch. Prices (tax-excl, `mst_new_price_listing`): App 10022 `price_flag=3` → 0 (site), `price_flag=2` → 3,618 (revenue booking); Coaching Intensive 10025 `price_flag=4` → 69,000 (site), `price_flag=3` → 65,382 residual = 71,920 tax-incl (revenue booking, CIP-179), `price_flag=2` → 66,500 legacy/unused. Rule: treat residual 71,920 as list price; `App = paid × 3,980 / 75,900`, `Coaching = paid − App`; split BEFORE daily proration, then prorate each with `getContractDateInfoList()`. Normal: App 3,980/Coaching 71,920; half-price: App 1,990/Coaching 35,960 (contract amounts before proration). **Ratio split, not fixed amounts** (booking App at 3,980 in a half-price month is wrong). In ASCI Spec 01 Req 2 (G1 approved 2026-10-28); not campaign-specific.
- **4.4 Refunds (CIP):** existing CIP refund rules kept (not day-prorated, booked in execution month). Cooling-off 90%: −68,310 → Coaching −64,728 / App −3,582. Consumption-tax exemption: −6,900 → −6,538 / −362. Full: −75,900 → −71,920 / −3,980. Shareholder benefit: −19,800 interim → Coaching −19,800 / App none. Contract overlap (B2C/B2E→B2B): Lesson charge only. Shareholder: Coaching only, App no share; ¥19,800 cap applied at CSV prep, batch books CSV as-is. Lesson-bundled CIP (1029–1032): Lesson part on the Lesson charge, Lesson also eligible for shareholder benefit. All in ASCI Spec 01 Req 4 (G1 approved 2026-10-28). **ASCH adds no CIP logic.**
- **4.4b Refunds (CAP) — ASCA, no change (NEW section):** one negative on the Coaching charge (App ¥0 on site); split with the same ASCA formula (`N` = refund amount, negative), not day-prorated, booked in execution month. `App = floor(N × 3,618 / (36,000 + 3,618))` (floor toward −∞); `Coaching = N − App`. Coaching 30 CAP Coaching charge: normal 42,350 / half 21,175 (tax-incl). Refund from Admin (Student search → refund modal): cooling-off = ceil(paid × 0.9); consumption-tax exemption = intdiv(paid, 11). Half-price examples: cooling-off −19,058 → −17,317/−1,741; tax-exempt −1,925 → −1,749/−176; full −21,175 → −19,241/−1,934. Full-refund 1-yen gap (App refund 1 yen more than booked) is the agreed ASCA floor rule (02b R-01), accepted. No change.
- **4.5 Cancellation within 6 months:** month-1 discount not reversed; only month-6 discount lost; ASC books what was issued, no special handling (same as OLD-ASCH pattern 5).

### 5. Worked examples (tax-incl, month from the 1st)
- **5.1 CAP (Daily 1 lesson + Coaching 30):** normal Lesson 14,850 / Coaching 38,483 / App 3,867 / total 57,200; half 7,425 / 19,242 / 1,933 / 28,600. (Deck's 54,450 used old coaching price; with CAP it's 57,200.)
- **5.2 CIP (Coaching+App part):** normal Coaching 71,920 / App 3,980 / total 75,900; half 35,960 / 1,990 / 37,950. Lesson-bundled CIP: Lesson charge separate per §4.1.

### 6. Expected ASC changes
Lesson none; CAP none (ASCA uses discounted N) — test only; CIP none in ASCH (covered by ASCI Spec 01 Req 2 + Req 4) — part of ASCI then test; campaign lookup/Honki flag none; CSV/Metabase none.

### 7. Test patterns
1 first month 50% starts on 1st (CAP/CIP); 2 first month 50% mid-month spans two months (CAP/CIP); 3 6th month 50% (CAP/CIP); 4 cancel within 6 months (CAP/CIP); 5 Lesson plan change during the 6 months — CAP plan_id includes the lesson amount (1022 L25+C30+App → 1023 L50+C30+App) so Coaching/App charges re-issue too; changes take effect on renewal date so no overlap (CAP); 6 CIP⇔CAP move both directions — loses 6th-month 50%, 6th month full price, month-1 kept, takes effect on renewal date no overlap (CIP⇔CAP); 7 already has a lesson plan, joins coaching later — first-month 50% on coaching only (CAP/CIP); 8 refunds in a half-price month (cooling-off, consumption-tax, full, shareholder) — expected §4.4 (CIP) / §4.4b (CAP) (CAP/CIP). Detailed sheet extends the existing CAP sample (P3, first month 50%) and CIP pattern 3.

### 8. Open items (new page)
1. CIP conversion step for discounted months — **Done** (ASCI Spec 01 Req 2, G1 10-28).
2. CIP refund split on booked App amount — **Done** (ASCI Spec 01 Req 4, G1 10-28).
3. **CDB catalog for 2027** — product IDs **done** (HCI-11 Req 2: Coaching [10015, 10025], App [10012, 10022]; 10005 excluded; Paolo 2026-10-30). **Half-price price still OPEN** — charge-batch HCI requirements (bizmates.jp) being drafted; Paolo to include new price flags.
4. Shareholder-benefit App share / lesson-bundled CIP Lesson — **Closed 2026-10-23** (App no share; Lesson eligible).
5. Deck billing example 54,450 → 57,200 + application end date — Business, to confirm.
6. CAP full-refund 1-yen App gap — **Closed 2026-10-30** (keep floor rule).
7. CAP cooling-off half-price rounding — **Closed 2026-10-30** (ceil → 19,058).

### Kuroda-san's Slack comment (2026-11-04, cc Patrick / Glenn)
Accepted the estimate ("testing only, 3–5 dev-days / ~2–2.5 weeks with buffer works for me"). Re-created the page; use the new one. Changes: (1) shareholder benefit closed — drop the risk; (2) Open Items 1+2 done (ASCI Spec 01); (3) new §4.4b CAP refunds with half-price examples, Pattern 8 now covers CAP too; (4) P5/P6 plan changes take effect on renewal date (CAP team 08-03), no overlap — for P5 note the CAP plan_id includes the lesson amount so Coaching/App re-issue too, build test data that way; (5) **deadline: in production by end of January 2027**; (6) half-price tax-exemption figure (−181) already Accounting-approved 10-23, no further approval; (7) CDB product IDs confirmed (HCI-11 Req 2), half-price price still open (Paolo).

**Kuroda-san's rough plan (asks us to adjust dates):**
- Before 11/10: firm up estimate, design test data for P5–P7
- Early Dec: ASCI CIP testable on DEV04
- ~12/11: run P5–P7 first; if a logic gap, Scenario B (4–5 wk) still fits before end of Jan
- 12/17: ASCI release (unchanged)
- Late Dec–mid Jan: patterns 1–4, 8, QA, Accounting check
- End of Jan: verification done

---

## Diff vs REF-ASCH2027-01 (what changed)

| Area | REF-01 (2026-10-23 page) | REF-02 (2026-11-04 page) | Impact for us |
|---|---|---|---|
| Shareholder-App-share (our Open Item 4 / their #4) | OPEN ("being confirmed with Accounting") | **CLOSED 2026-10-23** — App no share, Lesson eligible | Our REF-01 §Recommendation #5 ("reconcile shareholder-App-share") is **resolved**. ASCI Req 4.4 already matched. Drop the risk. |
| Open Items 1+2 (CIP conversion + refund basis) | Shown as "waiting for reply (2026-10-23)" on their page; we'd already flagged them done | **Explicitly marked Done** (ASCI Spec 01 Req 2/4) | Agrees with our REF-01 finding. No action. |
| CAP refunds | Not on their page (CIP refunds only) | **NEW §4.4b** with half-price worked values + Pattern 8 extended to CAP | New expected-value reference for our CAP half-price refund testing. The −1,934/−3,868 App-refund values match our ASCA-81 arithmetic. |
| App product_id | REF-01 flagged 10021→10022 as the real CDB risk | **Confirmed: App [10012, 10022]**, 10021 not used (HCI-11 Req 2, Paolo 2026-10-30) | Our Open Item 3 "App 10021→10022" **product-ID half is CLOSED**. Only the half-price price flag remains open. |
| CDB half-price price | Part of the open CDB catalog item | **Still OPEN** — charge-batch HCI reqs being drafted (Paolo) | The one remaining upstream dependency. Track it. |
| Deadline | Shared ASC 12-17 / first run 2027-01-01 | **NEW explicit: ASC in production by end of January 2027** (first Honki close = Jan, run early Feb) | More breathing room than "2027-01-01 first run". Our estimate's "fits before 12-17/01-01" still holds and is now less tight. |
| −181 tax-exemption figure | Pending Wada-san/Accounting | **Already approved 2026-10-23** | Our pending-human-check "Wada-san blesses −181" is **resolved**. |
| Timeline | Our estimate: Scenario A ~2–2.5 wk, after ASCI-11 | Kuroda-san proposes a dated plan (P5–P7 first ~12/11; Scenario B still fits to end-Jan) | He's adopted our Scenario A/B framing. Asks us to adjust dates. |

## What this changes for us (actions)

1. **Several of our open risks are now closed** by this page: shareholder-App-share, the App product-ID (10021→10022), and the −181 Accounting approval. Update the tracker accordingly.
2. **One upstream dependency remains:** the CDB **half-price price flag** (charge-batch HCI requirements, Paolo). This is now the single open ASCH-adjacent item. Track under Open Item 3.
3. **Estimate stays valid** (Scenario A ~2–2.5 wk, Scenario B contingency). The deadline is now "end of January 2027", slightly looser than our assumption. Kuroda-san asks us to confirm/adjust his dated plan before 11/10 — a Lead response is owed.
4. **New test-data note for P5:** CAP plan_id includes the lesson amount (1022→1023), so Coaching/App charges re-issue on a Lesson plan change — build fixtures that way. Our estimate's P5 analysis assumed only the Lesson charge changed; **this refines it** (the CAP pair is re-issued, not untouched). Worth a small note in the estimate doc.
5. **New CAP half-price refund expected values (§4.4b)** are now an authoritative reference for Pattern 8 CAP testing — fold into the test-pattern sheet when built.
