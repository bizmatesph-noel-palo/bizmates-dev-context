# REF-ASCH2027-03 — Kuroda-san's questions to the CDB team (CDB Slack, 2026-11-05)

## Document Info

| | |
|---|---|
| **Document type** | Research reference (upstream thread capture + impact read) |
| **Status** | Active — waiting on Soli-san / Paolo (CDB). Lead's reply to Kuroda-san is ON HOLD until they align. |
| **Date** | 2026-11-06 (captured) · message posted 2026-11-05 14:55 |
| **Source** | Hayato Kuroda → Soli Sahukar, Paolo (CDB), cc Roi Patrick Florentino (Patrick-san), Noel — CDB Slack channel |
| **Captured by** | Noel Palo, Lead · assisted by Kiro |
| **Related** | `REF-ASCH2027-02-Requirements-20261104.md` (§8 #3 CDB catalog) · `REF-CDB-02-ASCH-Alignment-Gaps-20260727.md` (OLD ASCH dependency) |

> **Naming:** "ASCH" = the NEW 2027 ASCH. The cancelled 2026 project is "OLD ASCH".

---

## 1. The message (substance, in order)

Kuroda-san reviewed the "ASCH - CDB dependency" doc against the released CDB code (`release/prod/CDB`) and wants to align on four points **before the ASCH test design is fixed** (ASCH must be live by end of January 2027). He asks for answers **within this week** so he can estimate ASCH.

**A. Needed for ASCH 2027 (blockers)**

1. **Product IDs 10022 (shared App) and 10025 (CIP).** `HonkiSetCatalog` (both repositories) still has Coaching = [10015] and App = [10012]. He understood from HCI-11 Req 2 that the target is Coaching = [10015, 10025] and App = [10012, 10022]. Questions: when will this be reflected, and will **Store, Maintain and the Charge batch** all be updated together? Until then, how is each stage handling CIP rows/charges (not captured, forfeited, other)? He has only read the code, not run it.
2. **Half-price amounts for CAP / CIP (`price_flag = 4`).** The released charge batch reads `mst_new_price_listing` tier = 2 with `price_flag` 2 or 3 only. He expects the half-price month to bill **CAP ¥21,175 and CIP ¥37,950 (tax included)**. Asks CDB to share the charge-batch HCI requirement document when ready, so the amounts can be confirmed before testing.
3. **"Past coaching" condition for CIP.** The current check only looks at Coaching 30-min history (10015). How to handle past CIP (10025) users, and switching 30-min ⇄ CIP? His understanding: switching in either direction during the contract removes the month-6 half price. He wants to confirm that is what the code will do after the HCI change.
4. **Registering the 2027 round.** `HONKISET_CAMPAIGN_IDS` only has entries 1 and 2 (2026). For the January 2027 round: which `discount_campaign_id`, and when/how will Store be run (manual, insert-only)? Related: is the re-eligibility rule decided (can a January 2027 member qualify again in April 2027)?

## 2. Impact read for ASC (Lead's side)

| # | Question | Does it change ASC logic? | What it means for us |
|---|---|---|---|
| A1 | Product ID lists in Store / Maintain / Charge batch | **No** | If the batch still skips 10025 / 10022, CDB won't issue half-price CIP charges; ASC books whatever charges exist. This affects whether the **real** charge batch can produce our test data, not ASC code. The requirement is decided (HCI-11 Req 2), but the **released code is not updated yet** — so REF-02 §8 #3 "Product IDs: done" means decided, not implemented. |
| A2 | Half-price `price_flag = 4` amounts | **No** | His expected amounts match our test values: CAP 21,175 (half of 42,350) and CIP 37,950 (half of 75,900). The charge-batch HCI requirement is still being drafted (Paolo) — the one open ASCH-adjacent item. |
| A3 | Past-coaching / switching rule | **No** | Matches REF-02 decision log (2026-10-23) and test pattern P6: moving CIP ⇄ CAP removes month-6 half price, the full-price month 6 is booked as issued. |
| A4 | 2027 round registration + re-eligibility | **No** | Billing/CDB timing risk for the campaign itself (no Store run before 2027-01-04 means no eligibility, so no half-price charges). Not an ASC dependency. |

**Lead's read (not yet confirmed with Kuroda-san):** nothing in these four questions changes the ASC booking logic or the "testing-only" estimate. The CDB answers decide whether the real charge batch can generate the half-price charges on DEV04. Since ASC only books the charge amounts, the P5–P7 fixtures can also be built by inserting charges directly, so our test work does not have to wait on CDB. The end-to-end proof that the charge batch bills 21,175 / 37,950 is a CDB test, not ours.

## 3. Inconsistency to clarify with Kuroda-san

His message says "ASCH reads `trn_campaign_discount_eligibility` to allocate revenue". His own requirements page of 2026-11-04 (REF-02 §3) says the opposite: **ASC does not read that table**, the discount arrives already in the charge's paid amount, and Honki-charge identification is out of scope (Accounting, 2026-10-23). The sentence most likely comes from the "ASCH - CDB dependency" doc he reviewed, which is probably the OLD ASCH one (REF-CDB-02, where OLD ASCH had to read `discount_flag = 2`). I have not seen the exact doc he reviewed. Worth confirming that ASCH 2027 still does not read the table, because if it did, scope would go back to the OLD ASCH design.

## 4. Status / owners
- **Owners of the answers:** Soli-san, Paolo (CDB). Kuroda-san asked for answers this week.
- **Lead:** reply to Kuroda-san's earlier dated plan is on hold until Kuroda-san and Soli-san align (decided 2026-11-06). Lead is on leave 2026-11-11 to 2026-11-23.
- **Open ASCH-adjacent item (unchanged):** CDB half-price price flag (charge-batch HCI requirements, Paolo).
