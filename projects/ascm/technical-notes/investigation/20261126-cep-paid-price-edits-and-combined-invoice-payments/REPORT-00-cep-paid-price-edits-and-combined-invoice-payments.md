# CEP monthly paid_price edits + combined invoices with split payments — code check of Kuroda-san's two items

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report (code check, answer to a stakeholder question) |
| **Status** | Code check done and re-verified (grounding check §6, 2026-11-26); **published to Confluence by the Lead (2026-11-26)**; not reproduced with data |
| **Date** | 2026-11-26 |
| **Author** | Noel Palo, Lead |
| **Assisted by** | **Kiro — the code check (reading `origin/main` of `accounting_related_system_for_freee`) was done by Kiro**; findings reviewed by the Lead |
| **Mode** | READ-ONLY. Code reading only on `origin/main`, fetched 2026-11-26 15:14 — tip still `06d44a09` (2026-10-22, PR #301). Nothing run on DEV04, no production data read, no code changed. |
| **Requested by** | Hayato Kuroda (PdM), Slack 2026-11-26 12:06, cc Patrick-san |
| **Related** | E003 invoice check; DataCorrection decommission (ASCA Spec 02d, ASCA-61; replaced by DevOps direct SQL, DEVOPS-6706) |

---

## 1. Summary (verdict first)

Both of Kuroda-san's concerns are **confirmed by the code**.

1. **CEP monthly `paid_price` edits do not flow into revenue as planned.**
   - **Coaching / App (daily-rate path):** revenue for every month of the contract is fixed by the first batch that picks the charge up (the batch of its `paid_at` month). Later edits to `paid_price` are not re-read.
   - **Lesson (Monthly 12, ticket path):** `paid_price` is re-read every run, but the monthly revenue is `paid_price / 12 × (taken + expired)`, so an edit to "sessions × 4,800" does not give "sessions × 4,800" of revenue unless 12 lessons are used or expired.
   - **Extra finding:** lowering the charges in months 1–2 makes the E003 invoice check fail, because the Freee invoice is the full amount up front.
2. **Combined invoices with split payments are double counted.** The combined-billing branch of `createLogFreeeInvoices()` saves one row per payment with the **full line amount**. With 2 payments the line is counted twice (495,000 → 990,000), which causes E003 and inflates the payment-date sums. Normal invoices use the payment amount and are not affected.

Not answerable from the code: whether production already has combined invoices with multiple payments (needs production data / past E003 reports).

---

## 2. Background (from Kuroda-san's message)

- **CEP (Coaching Executive Plan):** B2B, 3 months (e.g. ¥600,000 excl. tax). One Freee **combined invoice** up front, one order number per item with a branch suffix (e.g. 1316226100931, 1316226100932).
- Admin charges per item: Lesson (Monthly 12 plan, custom price), Coaching (Bizmates Coaching plan, custom price), App (Premium), and 2 Other Sales charges.
- At each month end, Sales Support edits each charge's `paid_price` to the sessions actually done (lessons × 4,800 / coaching × 16,625). In month 3 the unused sessions are added so the total reaches the full amount.

---

## 3. Item 1 — CEP monthly paid_price edits

### 3.1 Coaching and App (daily-rate path)

| Step | Code (`origin/main`) | Effect |
|---|---|---|
| Pick-up | `TrnCharge::getTrnChargeList()` — `app/Models/TrnCharge.php:39–54`, filter `whereBetween('paid_at', …)` (line 49) | A charge is read only by the batch whose month contains its `paid_at`. |
| Split by month | `CommonUtil::getContractDateInfoList()` — `app/Libs/CommonUtil.php:576–666`; `ceil($paidPrice / $totalContractDay * $contractDay)` (line 638), last month takes the remainder | Builds a row for **every** month of the contract, from the `paid_price` at that moment. |
| Write | `CommonUtil::createDailyRateCalculation()` — `CommonUtil.php:386–` (loop from line 399) | All months' rows are inserted into `log_daily_rate_calculation` in that one run. |
| Later months | `LogDailyRateCalculation::getPaidPriceSumList()` — `app/Models/LogDailyRateCalculation.php:72–` (filter `target_ym`) | Later batches only **sum existing rows** for their month; they do not re-read `trn_charge`. |

**Answers:** (a) Each month = the original `paid_price` prorated by contract days. (b) Fixed when the charge is first picked up; a month-end edit is not reflected.

**Deletes checked:** the Final batch (`SendJournalsDataLogic.php:109`) only inserts. The Pre batch's rerun cleanup (`DailyRateCalculationPreLogic::deleteTargetYMData()`, lines 157–200, called at line 53) deletes rows in the daily-rate / sum tables **created since the 1st of the run month**; it does not touch rows created by earlier months' batches. The manual command `logs:clear-calculations {date}` (`ClearCalculationLogsCommand.php`) deletes rows created on or after a date; it is not scheduled. Only a manual clear + rerun from the charge's `paid_at` month would rebuild the rows, and then it would use the current `paid_price` for **all** months — a correction by rerun, not a monthly flow.

### 3.2 Lesson (Monthly 12, ticket-consumption path)

| Step | Code (`origin/main`) | Effect |
|---|---|---|
| Skip in daily rate | `CommonUtil.php:401` (`BizmatesMonthlyPlanEnum::exists`) | Monthly-plan charges are handled by `MonthlyRateCalculationLogic`. |
| Charge amount | `app/Libs/MonthlyRateCalculationLogic.php` `ChargeData` CTE (reads `t.paid_price` from `trn_charge`, lines 332–361) | `paid_price` is read **live on every run**. |
| Volume | `ProductVolume` CTE (`mst_product.lesson_volume`, line 307); `g.lesson_volume AS total` (line 764) | The divisor is the **product's** lesson volume (12 for Monthly 12), not the real 8 / 12 / 16. |
| Monthly revenue | `ROUND(paid_price / lesson_volume × (taken + expired))` (lines 808–831); exception: a charge with an available prorated refund and no new contract books `taken` only | Revenue per month depends on lessons taken / expired from `trn_ticket` and the evaluations. For the last charge of a B2B order (`is_last_charge_in_order = 1`, line 781) all remaining lessons expire in that month, so their revenue is recognized then. |

**Answers:** (a) Monthly revenue = `ROUND(current paid_price / 12 × (taken + expired))`. (b) An edit takes effect from the next run of that month; months already sent are not restated. Taken / remaining / expired come from the tickets and are **not** changed by a `paid_price` edit.

**Example:** month 1 edited to 8 × 4,800 = 38,400 with 8 lessons taken → 38,400 / 12 × 8 = **25,600**, not 38,400.

**Not checked:** how many tickets the Monthly 12 product issues per month (whether 16 lessons can be taken), and whether the Lesson charge covers one month or all 3.

### 3.3 Extra finding — E003 during months 1–2

- `CommonUtil::checkFreeeAdminInfo()` — `CommonUtil.php:249–`, run by both the Pre and the Final batch: for Freee invoices issued between 2 months before and 2 months after the target month (lines 256–260), for each invoice number it compares `SUM(log_freee_invoices.total_amount)` (`LogFreeeInvoices::getPartnerListsForSumInvoiceNumber`, `app/Models/LogFreeeInvoices.php:113–120`) with the live `SUM(trn_charge.paid_price)` for that order number (`TrnCharge::getTrnChargeForOrderNo`, `TrnCharge.php:96`). Mismatch → E003 (`CommonUtil.php:278–285`), added to the batch's error list. The `trn_charge` comparison is used when the order number exists in `trn_charge`; Other Sales and Zipan are compared only when it does not (lines 288–309).
- The CEP invoice is the full amount up front, so lowering the charges to the sessions done in months 1–2 shows **E003 for those months** until month 3 adds the unused sessions back.

### 3.4 Options (question c) — business decision with Accounting

| Option | Revenue | E003 | Notes |
|---|---|---|---|
| A. Separate charges per month (start / end and `paid_at` inside the month, `paid_price` = actual sessions) | Each month books exactly its amount | Needs a rule: the invoice is full-amount up front (e.g. register all three monthly charges up front, or accept / explain E003 until month 3) | Matches how the batch works |
| B. One charge per item, no edits | Follows contract days, not sessions | No mismatch | Simplest; not session-based |
| C. Data correction | — | — | Not an option after the 12/14–12/17 release: `DataCorrectionCommand` is decommissioned there (Spec 02d); corrections go to DevOps direct SQL (DEVOPS-6706) |

**Suggestion:** decide the flow with Accounting, then test one CEP case on DEV04 before Sales Support starts editing.

---

## 4. Item 2 — combined invoices with split payments

### 4.1 The code (`createLogFreeeInvoices()`, `CommonUtil.php:981–`)

| Branch | Lines (`origin/main`) | Amount saved per payment |
|---|---|---|
| Normal / split / plan change (new invoice API) | `isTypeNormal()` 1170; per-payment loop 1184–1196 | `$payments->getAmount()` — the **payment** amount |
| Cancel | 1221–1229 | `$payments->getAmount()` |
| **Combined billing** | `isTypeCombinedBilling()` 1243; line amount built 1267–1270; per-payment loop 1286–1297 | `$amount` — the **full line amount**, repeated for every payment |

The same code is on `feature/ASCA/ASCA-master` (around lines 1207 / 1220) and `feature/ASCI/ASCI-master` (around 1238 / 1251). Kuroda-san's line numbers (L1178–1190) do not match `main`; he likely read another branch — same logic.

### 4.2 Effect

- Example: line 1316226100931 = 495,000 (incl. tax), paid in 2 installments → 2 rows × 495,000 = **990,000** for that order number.
- **E003:** the check sums `total_amount` by invoice number (§3.3) → 990,000 vs the charge sum 495,000 → E003.
- **Deposit / balance side:** the payment-date reads are inflated too. `getLogFreeeInvoicesSumForPaymentDate()` (`LogFreeeInvoices.php:53–59`) feeds the per-partner deposit amounts of the balance transition (残高推移, `SendJournalsDataLogic::createBalanceTransition()` line 704; order-number version line 816; Zipan `ZipanUtil.php:970`). `getLogFreeeInvoicesForTheSpecifiedPaymentDate()` (`LogFreeeInvoices.php:99–104`) feeds the advance-received (前受金) T2 processing (`SendJournalsDataLogic.php:377`). The exact journal impact was not traced.

**Answer (a):** confirmed.

### 4.3 Existing production cases (question b)

Cannot be answered from the code. To check (DevOps / Accounting): `log_freee_invoices` rows with the same `invoice_number` and `total_amount` but different `payment_date`; or past E003 lines where the Freee amount is a multiple of the charge sum.

### 4.4 Fix options (question c)

| Option | E003 | Payment dates / partial payments | Verdict |
|---|---|---|---|
| **Split each payment across the lines in proportion to the line amounts** (rounding remainder on the last line so totals match) | Fixed | Kept — each installment keeps its real date and amount | **Recommended** |
| Save each line only once | Fixed | Lost — one payment date has to be chosen; installment timing on the deposit side is wrong | Not recommended |

**Rough effort (estimate, revised 2026-11-26; to be confirmed by the developer who takes it):**

| Part | Estimate | Basis |
|---|---|---|
| Code change (proportional split, rounding remainder on the last line) | about 0.5 day | One branch of `createLogFreeeInvoices()` (Kiro estimate) |
| Extract a testable helper + new unit tests | **1–2 days**, depending on the complexity of the tests | Lead's estimate. No test calls `createLogFreeeInvoices()` on `main`, `ASCA-master` or `ASCI-master` (only `tests/Models/InvoiceAttributeTest.php` for memo parsing, and `tests/Unit/Libs/ZipanUtilTest.php` seeds `LogFreeeInvoicesTableSeeder` as a fixture); the method is static, about 300 lines, and creates `new CommonApiUtil()` inline, so the split logic needs to move into a pure helper or the Freee API calls need mocking |
| Review + merge into `main`, `ASCA-master`, `ASCI-master` | about 0.5 day | Kiro estimate |
| DEV04 verification (batch commands) | **about 0.5–1 day** | Lead: each command cycle (Pre + Send) takes about 30–45 min on DEV04. ASCM range 02 → 07 = 6 cycles ≈ 3–4.5 h (about half a day); with ASCA / ASCI the range extends to 11 = 10 cycles ≈ 5–7.5 h (about a day) |
| Freee test data | **unknown** | Needs a combined invoice with split payments in the Freee test company — availability not known |
| QA | **depends on the scope** | Depends on the tests QA conducts and the scope of the test cases |

**Total (dev side): about 2.5–4 days** (development 2–3 days + DEV04 run 0.5–1 day), **plus** Freee test-data preparation (unknown) and QA (depends on the test scope). Not in the 12/14–12/17 release scope (code freeze from 12/18), so it would be a separate release.

---

## 5. Open points

1. CEP flow (option A / B) and the E003 rule — Accounting / Kuroda-san.
2. Monthly 12 ticket issuance per month (can 16 lessons be taken?) and the Lesson charge period — not checked.
3. Other Sales charges in CEP — not checked.
4. Production check for combined invoices with multiple payments — DevOps / Accounting.
5. Release slot for the item-2 fix (after 12/17; code freeze from 12/18).
6. Exact journal impact of the duplicated rows in the balance transition and the 前受金 processing — not traced.

---

## 6. Grounding check (2026-11-26, Kiro-assisted, Lead asked)

`origin/main` was fetched first (15:14; tip unchanged `06d44a09`). Every claim in §3–§4 was re-checked against the code.

| Claim | Result | Evidence |
|---|---|---|
| Charges are picked up only by the batch of their `paid_at` month | ✅ Verified | `TrnCharge.php:39–54` (line 49) |
| One run writes rows for every month of the contract from the current `paid_price` | ✅ Verified | `CommonUtil.php:576–666` (CEIL line 638), insert loop from line 399 |
| Later batches only sum existing rows | ✅ Verified | `LogDailyRateCalculation.php:72–` (`target_ym` filter) |
| The Final batch does not rebuild earlier rows | ✅ Verified, **wording corrected** | Final only inserts (`SendJournalsDataLogic.php:109`). The earlier text "only the Pre batch deletes and rebuilds its own rows" was imprecise: the Pre rerun cleanup deletes rows created since the 1st of the run month in both the Pre and Final daily / sum tables (`DailyRateCalculationPreLogic.php:157–200`). Added the manual `logs:clear-calculations` command (§3.1) |
| Monthly plans skip the daily-rate path | ✅ Verified | `CommonUtil.php:401` |
| Monthly revenue = `paid_price / lesson_volume × (taken + expired)`, `paid_price` read live, volume from `mst_product` | ✅ Verified, **exceptions added** | `MonthlyRateCalculationLogic.php` 307, 332–361, 764, 808–831; refund-case exception and last-charge-in-order expiry (line 781) added to §3.2 |
| E003 compares the Freee invoice sum with the live `trn_charge` sum per order number | ✅ Verified, **detail added** | `CommonUtil.php:249–309`; issue-date window and branch order added to §3.3 |
| Combined branch saves the full line amount per payment; normal / cancel branches save the payment amount | ✅ Verified | `CommonUtil.php:1184–1196`, `1221–1229`, `1286–1297` |
| Same code on `ASCA-master` / `ASCI-master` | ✅ Verified (grep of the `$amount` rows) | lines 1207 / 1220 and 1238 / 1251 |
| Payment-date sums are inflated | ✅ Verified, **wording corrected** | "Receivable / deposit side" made specific: balance-transition per-partner deposits (`SendJournalsDataLogic.php:704, 816`, `ZipanUtil.php:970`) and the 前受金 T2 processing (`SendJournalsDataLogic.php:377`). Journal impact not traced |
| `DataCorrectionCommand` is retired in the December release | ✅ Verified | Exists on `main`; on `ASCA-master` it is `@deprecated` and a no-op pointing to DEVOPS-6706 |
| Production has combined invoices with multiple payments | ❌ Not checkable from code | Needs production data / past E003 reports |
| Monthly 12 tickets per month; Lesson charge period; Other Sales in CEP | ❌ Not checked | Open points 2–3 |
| Fix effort | ⚠️ Estimate, **revised** | The first figure (~1 dev day) was Kiro's rough guess from the size of the code change. Revised to **about 2.5–4 days on the dev side** = code change ~0.5 day (Kiro) + helper extraction and unit tests 1–2 days, depending on the complexity of the tests (Lead) + review and 3-branch merge ~0.5 day (Kiro) + DEV04 run 0.5–1 day (Kiro's conversion of the Lead's 30–45 min per Pre + Send cycle: 6 cycles for 02 → 07, 10 cycles for 02 → 11). **Plus** Freee test data (unknown) and QA (depends on the test scope). Fact behind the test effort: no test calls `createLogFreeeInvoices()` on `main`, `ASCA-master` or `ASCI-master` — only `InvoiceAttributeTest` (memo parsing) and a `LogFreeeInvoicesTableSeeder` fixture in `ZipanUtilTest`. See §4.4 |
