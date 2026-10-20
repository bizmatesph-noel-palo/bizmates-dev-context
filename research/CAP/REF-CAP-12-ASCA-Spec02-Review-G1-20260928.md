# REF-CAP-12 — ASCA Spec 02 Review Feedback, G1 (Kuroda-san + Patrick-san, 2026-09-28)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-09-28 (Received — Slack thread) |
| **Author (source)** | Hayato Kuroda (PM); Roi Patrick Florentino (SDM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative G1 review feedback for ASCA Spec 02 (sub-specs 02a–02c) |
| **Audience** | Dev team (ASCA), Accounting |
| **Reviewed** | Spec 02 drafts (commit 5989538, 09-25): `asca-spec-02a-cap-core-injection`, `asca-spec-02b-refund-allocation`, `asca-spec-02c-allocation-detail-csv` (02d dropped — see §0) |
| **Companion** | `research/CIP/REF-CIP-06-CAP-CIP-Refund-Patterns-Overview-20260928.md` (the refund-patterns source the CIP-refund carve-out comes from) |

> ⚠️ **Verbatim source document.** Kuroda-san's and Patrick-san's Spec 02 G1 review, preserved in full. Do not alter this content; our resolution/impact tracking lives in `projects/asca/`. Cross-reference notes (mine, not part of the source) are at the very bottom, clearly marked.

---

## 0. Kuroda-san — earlier note on 02d (10:34 AM)

Hi @Noel san
I quickly ran through your spec02 md files.
For the 02d since this fix batch has been outdated I think we don't need to handle this.
https://github.com/bizmatesph-noel-palo/bizmates-dev-context/blob/projects/asca/projects/asca/specs/asca-spec-02d-datacorrection-integration/requirements.md
If you're fine plz skip it and Requirement 5.4 in 02a which refers this 02d file.
Thank you.

---

## 1. Kuroda-san — main G1 feedback (12:40 PM)

Hi @Noel san, thanks for the Spec 02 drafts. I've reviewed 02a–02c (commit 5989538, 09-25) against REF-CAP-09, the G1 decisions in the technical design, and the existing ASC code. Four items need to be resolved before G1. Quotes are verbatim from the specs.

**1. [02b] Refund charges won't pair with the App row, so refunds are never allocated (blocker)**
02b says refunds go through the same path as positive charges:
L63: "THE system SHALL allocate a negative-N charge using the same formula and the same pipeline as a positive charge"
L122: "THE negative refund charge SHALL enter the same allocation entry point as positive charges … not by a separate code path."

But the pairing rule from the technical design (§1b, L54) is:
"pair the coaching charge (10005/10015) with the app charge (10022) that share the *same `start_date` AND `end_date`*. Mismatched dates ⇒ do not guess: mark incomplete (V-3) and skip. Keep the "exactly 1 coaching + 1 app" cardinality safety net."

A refund charge is a clone of the original coaching charge. It keeps `start_date`/`end_date`/`order_no`/`plan_id`; only `paid_price`, `paid_at` and `transaction_id` change (`libs/prorated.php:186`, `shareholderrefund/addbycsv.php:269`). Existing ASC writes it as a single row in the `paid_at` month (`CommonUtil.php:606`). In the execution month:
• *(i) The original contract still covers the execution month* (e.g. same-month cooling-off): the rows written earlier for that month are still there, because the delete is by `created_at` and the sum filters only on `target_ym`. The month then has 2 coaching rows (+/−) and 1 App row. That fails the 1+1 check, so the whole bundle is skipped, *including that month's normal allocation*.
• *(ii) The execution month is after the contract period* (shareholder cashback ~3 months later, later-month cooling-off): there is no App row in that month, so pairing fails. Under Option 1 (overwrite) there is also no row to write P_app into.
In both cases the refund stays 100% on Coaching. L109 ("the ¥0 App companion SHALL NOT create a separate shareholder-benefit App refund line") is also a separate question from *which row receives P_app in the refund month*.
How should we handle this? I think the spec needs to define: ① how a refund is linked to its original bundle (e.g. via `log_refund_history` original/refund charge IDs), ② how that interacts with the 1+1 check, ③ where the negative P_app is written (a new App log row? if so, the impact on the existing CSVs / Freee / PayPal sums / 02c), ④ N per charge, with +/− never netted (R-12). Please also add acceptance tests for both (i) and (ii).

**2. [02a] State of the log after a mid-run failure**
L95: "WHEN allocation has failed, THE daily-rate log SHALL still contain N (the pre-allocation values)"

Nothing requires a rollback. If `allocate()` throws after overwriting some bundles, the log holds a mix of N and P, the run is Failed, and 02c then omits the breakdown CSV. This also needs to line up with 02b L121 ("SHALL NOT block unrelated CAP records"). Could you specify one of these?
(a) The whole run is one transaction, so the log rolls back to N.
(b) Each pair is written atomically, failed pairs keep N, and the run is recorded as completed-with-errors with a list of the failed pairs.

**3. [02a] Re-run idempotency conflicts with V-7**
L83: "WHEN the batch (Pre or Final) is re-run for the same `target_ym`, THE resulting P values SHALL be identical to the first run."
Technical design L42 (V-7): "If an App row has non-zero `paid_price`, mark the bundle incomplete (V-3) and skip"

Rows for the target month that were written in earlier months' batches are not deleted on re-run (the delete is by `created_at`). Their App rows still hold P_app ≠ 0 from the first run, so V-7 skips those bundles on the second run. How should a re-run recognise already-allocated rows? For example, restore N from `log_alloc_prorations.original_paid_price` before recomputing, or apply V-7 only to pre-allocation values. Please add a "re-run an already-allocated month" acceptance test.

**4. [02c] No column links the coaching and App rows of a bundle**
L60: the 15 columns (… 生徒ID, 部署ID, 発注番号, プランID, プロダクトID, … 参照価格, 配分比率, 元金額(N), 配分後金額(P), ステータス)
L98: "THE 参照価格 (L), 配分比率 (ratio), and 元金額(N) columns SHALL be sufficient to recompute 配分後金額(P)"

Most CAP bundles have `order_no` = NULL and are paired by start/end date, and a student can have more than one bundle in a month. With these 15 columns you can't tell which coaching row goes with which App row, and there is no `charge_id` to match rows against DailyRateCalculation.csv. That means L98 can't be met. Please add `charge_id`, a bundle/group ID, and a row kind (normal / refund).

I'll send the smaller items separately: Pre/Final-specific CSV guard, per-row status including skipped bundles, V-7 data check as a dependency, tax labels in the CSV headers, and removing the 02d references. Happy to jump on a quick call if that's easier for #1.

---

## 2. Patrick-san — review & clarifications (4:20 PM)

Hi @Hayato Kuroda san, @Noelsan,
Thank you for preparing this detailed document.
To make sure I am fully aligned before proceeding with Step 6 implementation, here is my understanding of the core refund mechanics, followed by a few specific points I would like to clarify:

**1. My Understanding of the Flow**

• Recognition Timing & Lump Sum:
When a refund happens, existing ASC simply treats the recognized charge amount in that month as a negative value (N < 0).
The negative amount is recognized in full in the execution month (paid_at month), without day-proration and without rolling back to previous months.

• Formula & Pipeline:
The allocation engine will use the exact same calculation formula and entry point for both normal charges and negative refund charges, with no separate refund pipeline.

• CAP vs. CIP Refund Behavior:
 • CAP: Follows the standard negative N calculation using the existing allocation weights (18,000 / 36,000 / 3,618).
 • CIP: Since the bundled App is charged at ¥0 and cannot be refunded directly in Admin, the full refund is initially booked as a negative charge against the Coaching Intensive charge, and the revenue-booking layer redistributes the App portion:
  Cooling-off (90%): Total plan refund of -¥68,310 → split into App (-¥3,582) and Coaching (-¥64,728).
  Tax Exemption: Total refund of -¥6,900 → split into App (-¥362) and Coaching (-¥6,538).
  Shareholder Cashback: Retained 100% on Coaching (capped at ¥19,800), with zero distribution to App.

• Other Cases:
Overlaps (Individual → Corporate) do not produce a refund/negative charge.
Multi-row Shareholder CSV lines under the same transaction_id are processed individually and never summed.

**2. Clarifications & Challenges**

To help ensure the implementation is clean and handles edge cases properly, could you please clarify the following points?

1. How should the allocation engine identify CIP Shareholder refunds vs. Cooling-off/Tax Exemption?
Since all negative charges flow through the same pipeline (§2.6), how will the engine determine whether a CIP negative charge is a Shareholder Cashback (which stays 100% Coaching) or Cooling-off/Tax Exemption (which requires splitting to App)?
Is there a specific record_kind, transaction ID prefix (e.g., ADMIN_REFUND_), or database column I should check to control this distribution behavior?

2. Calculation description consistency for CIP Tax Exemption (§3 Row 3.4 vs §3 Note):
Table 3.4 describes the CIP tax exemption amount as 75,900 - 69,000 = -6,900.
Meanwhile, the note below splits it by product tax portions: App -(3,980 - 3,618) = -362 and Coaching -(71,920 - 65,382) = -6,538.
Both arrive at -¥6,900, but can we align Table 3.4 to describe it using the product tax breakdown so the table and notes are fully consistent?

3. Minor Typo in §3 Note:
In the note under §3, the App tax exemption formula is written as App (3,980 3,618) = -362. I assume this was intended as -(3,980 - 3,618) = -362.

4. Duplicate Protection on Shareholder CSV Uploads (§2.5):
The upload script looks up the original charge using student_id + transaction_id + charge_price.
Does the script also check log_refund_history to prevent duplicate negative charges if an admin accidentally uploads the same CSV record more than once?

Please let me know if my understanding is correct or if anything needs further adjustment. Thank you!

---

## 3. Kuroda-san — reply to Patrick-san (4:51 PM)

@Roi Patrick Florentino san
Thank you for the review. Your understanding is correct, with one correction below.

**Correction on "same formula / no separate refund pipeline"**
This holds for CAP. For CIP, regular charges are not allocated at all; only refunds are split, by a fixed rule per refund type (App share = 3,980 × 90% for cooling-off, 3,980 - 3,618 for tax exemption, none for shareholder cashback). I have updated §2.1 and §2.6 to make this explicit.

**1. Identifying the CIP refund type**
Good point. I'm checking this on our side and will get back to you. Please hold the CIP refund-split part until then.

**2. Table 3.4 vs. the note**
Agreed. Table 3.4 now describes the CIP amount by the per-product breakdown: Coaching -(71,920 - 65,382) = -6,538 + App -(3,980 - 3,618) = -362 = -6,900.
I fixed the doc.

**3. Typo**
Yes, it is -(3,980 - 3,618) = -362. The minus signs were lost when pasting into Confluence. Fixed too.

**4. Duplicate shareholder CSV uploads**
The script checks log_refund_history, but only shows a warning, because multiple refunds on the same charge are allowed. It blocks the upload only if the total refunds would exceed the original paid amount (addbycsv.php L245–258). This is existing behaviour, and ASCA/I simply processes the negative charges that exist, so it is out of scope for Step 6.

Thank you
cc: @Noel

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

| Item | Where it lands |
|---|---|
| **02d dropped** (§0) | Remove `asca-spec-02d-datacorrection-integration` + its epic; remove 02a Req 5.4 reference; re-scope Spec 02 to 3 sub-specs (02a/b/c) in timeline, dev-workflow, specs README, JIRA ticket draft. |
| **CAP refund→bundle pairing (§1 #1, blocker)** | `asca-spec-02b` — needs: refund↔original linkage (`log_refund_history` / `trn_prorated_refund_charge.refund_charge_id`), 1+1 interaction, where negative P_app is written, R-12 netting, acceptance tests (i)+(ii). Design decision ③ (where P_app lands) is open. |
| **Mid-run failure state (§1 #2)** | `asca-spec-02a` — choose (a) whole-run transaction rollback, or (b) per-pair atomic + completed-with-errors + failed-pair list. |
| **Re-run vs V-7 (§1 #3)** | `asca-spec-02a` — restore N from `log_alloc_prorations.original_paid_price` before recompute, or apply V-7 to pre-allocation values; add re-run acceptance test. |
| **02c linking columns (§1 #4)** | `asca-spec-02c` — add `charge_id`, bundle/group ID, row kind (normal/refund). |
| **CIP refunds ARE split by fixed rule** (§3 Kuroda correction; REF-CIP-06 §2.1/§2.6/§3) | Scope decision: where does CIP-refund handling live — extend 02b beyond CAP-only, a new sub-spec, or ASCI? **On hold** pending Kuroda-san's CIP refund-type identification answer. |
| **Patrick Q4 (CSV dedup)** | Resolved by Kuroda-san — existing behaviour (warns, blocks only if total > original), **out of Step-6 scope**. |
| Refund patterns source | `research/CIP/REF-CIP-06-CAP-CIP-Refund-Patterns-Overview-20260928.md` |

> These are pending resolutions, not yet applied to the spec drafts. No spec files were edited when creating this record.
