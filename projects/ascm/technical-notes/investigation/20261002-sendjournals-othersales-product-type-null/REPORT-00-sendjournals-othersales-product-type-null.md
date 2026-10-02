# Investigation — SendJournals Production Error (OtherSales, `product_type` on null)

## Document Info

| | |
|---|---|
| **Document type** | Production Incident Investigation |
| **Date** | 2026-10-02 |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Active — root cause identified (code-confirmed); one data-identification item open |
| **Severity** | High — the September **FINAL** (確定) journal run aborted; no Freee journals were submitted for the affected run |
| **Environment** | Production |
| **Command** | `SendJournalsDataCommand` (Final / 確定) |
| **Occurred** | 2026-10-02 18:00:41 JST (the rescheduled September FINAL run) |
| **Audience** | Management, Accounting, Dev team |

---

## 1. Executive summary

The September **FINAL** accounting run (`SendJournalsDataCommand`, 2026-10-02 18:00) stopped with a system error before submitting journals to Freee.

- **What broke:** while building the "OtherSales" (その他売上) journal entries, the program looked up a **journal rule** (`mst_rule_for_journals`) for one charge and **found none**. The code then tried to read a value from that missing rule and aborted.
- **Root cause (code-confirmed):** a **missing master-data row** in `mst_rule_for_journals` for the product-type / contract-type combination of an OtherSales charge in September's data. The lookup returns "nothing found", and the code does not guard against the "nothing found" case before using the result.
- **Not caused by recent project work.** This is **pre-existing code** in the OtherSales journal path. It was **not** introduced by the recent ASCM refactor (DEVOPS-6415), the Zipan price-revision change (DEVOPS-6596), or the ASCA allocation project (whose code is not active in this batch yet). Evidence in §4.
- **Impact:** the Final run did not complete; Freee journals for the affected run were not sent. The condition is **deterministic** — re-running without addressing the cause will fail again at the same point.
- **Recommended path:** (1) identify and add the missing `mst_rule_for_journals` row (data fix — likely unblocks the re-run with no code change), then (2) add a defensive guard in the code so a future missing rule produces a clear, non-fatal error instead of aborting the whole run.

---

## 2. The error (as received)

Automated error mail, 2026-10-02 18:00:41:

> 売上集計システムにて、システムエラーが発生しました。
> ErrorException: Attempt to read property "product_type" on null in `.../app/Libs/SendJournalsDataLogic.php:1134`

Call path (from the stack trace):

```
SendJournalsDataCommand->handle()
  └ SendJournalsDataLogic->execute()
     └ SendJournalsDataLogic->sendFreeeJournals2()          (line 136)
        └ SendJournalsDataLogic->getOtherSalesJournals()    (line 362)
           └ ErrorException: read property "product_type" on null   (line 1134)
```

> **Note on the line number.** The deployed code and the current working copy differ slightly in line numbering (lines have shifted since deployment), so "line 1134" does not point to the same statement in the current source. This investigation relies on the **method name** (`getOtherSalesJournals`) and the **property** (`product_type` read on a null object) from the stack trace, which are unambiguous.

---

## 3. Root cause (code-confirmed)

Inside `getOtherSalesJournals()` (OtherSales T1 journal creation), for each OtherSales charge the code resolves a journal rule and then uses it:

```php
// resolve the product type, then the Freee product type, then the journal rule
$productType       = MstProduct::getProductInfoByProductId($sumList->product_id, 'product_type');
$freeeProductType  = MstCodeChange::getChangeCodeToFreeeCode(..., $productType, $sumList->product_id);
[$freeeContractType, $contractTypeName] = CommonUtil::getContractTypeInfo($freeeProductType, $sumList->department_id, $contractType);

$mstRuleForJournals = MstRuleForJournals::getMstRuleForJournals($freeeContractType, $freeeProductType);
// ...
$tmpT1ForT3[$sumList->order_no]->item_id    = $mstRuleForJournals->product_type;   // ← null-dereference when the rule is missing
$tmpT1ForT3[$sumList->order_no]->section_id = $mstRuleForJournals->department_id;
// ... also segment1_id / segment2_id
```

The lookup method returns **null** when no matching row exists:

```php
// App\Models\MstRuleForJournals::getMstRuleForJournals($segment2Id, $productType)
return \DB::table('mst_rule_for_journals')
    ->where('segment2_id', '=', $segment2Id)
    ->where('product_type', '=', $productType)
    ->where('status', '=', 1)
    ->first();   // ← returns NULL when nothing matches
```

So the chain is:

1. An **OtherSales charge** in September's data has a `product_id` →
2. resolves to a `product_type` (from `mst_product`) and a Freee product type (via `mst_code_change`) →
3. combined with the contract type, there is **no active `mst_rule_for_journals` row** for that `(segment2_id = freee contract type, product_type = freee product type, status = 1)` combination →
4. `getMstRuleForJournals(...)` returns **null** →
5. the next line reads `->product_type` on that null → **ErrorException**, run aborts.

This is a **missing-master-data** condition combined with a **missing null-guard** in the code. The partner lookup immediately above it *does* have a fallback (`?? dummy`); the journal-rule lookup does not.

---

## 4. Not a regression from recent project work

This matters for attribution, so it was checked explicitly.

| Check | Finding |
|---|---|
| **Which code failed?** | `getOtherSalesJournals()` — part of the **existing ASC "OtherSales" journal path**, long predating the current projects. |
| **Is the ASCA allocation engine involved?** | **No.** The ASCA allocation code (Spec 01 Foundation) is merged but **not wired into the batch** — that wiring is a later phase (Spec 02), not yet merged. The allocation engine does not run in this command today. |
| **Did the ASCM refactor (DEVOPS-6415) touch this?** | **No.** The only recent commit touching `SendJournalsDataLogic.php` is the DEVOPS-6415 service-extraction commit. Its diff (6 insertions / 51 deletions) is entirely in the zip/email extraction area and does **not** touch `getOtherSalesJournals`, the `MstRuleForJournals` lookup, or any `product_type` reference. |
| **Did the ZPR change (DEVOPS-6596) touch this?** | **No.** DEVOPS-6596 added one Zipan plan to an enum (`ZipanMonthlyPlanEnum`); it does not touch the OtherSales journal path. |

**Conclusion:** this is a **pre-existing latent bug** in untouched code, surfaced by this month's OtherSales data — not introduced by the ASCM refactor, the ZPR change, or ASCA.

---

## 5. Impact

- The September **FINAL** (確定) run **aborted before submitting any Freee journals** for the affected run. (The failure happens during journal building, prior to Freee submission.)
- No partial/incorrect journals were sent from this run as a result of this specific error (the abort is before the Freee send for the OtherSales path).
- The condition is **deterministic**: the same data will fail at the same point on re-run until the cause is addressed.
- The earlier September steps are unaffected (the ZPR daily-table cleanup on 2026-09-30 and the 10/01 PRE verification were completed and are unrelated to this error).

> **To confirm (operations):** whether any journals from *earlier* T-steps in the same run were already committed before the abort, so the re-run strategy avoids double-posting. This should be verified against Freee / the send-history before re-running.

---

## 6. Open item — identifying the exact missing row

The **mechanism** is confirmed in code. The **specific offending record** has **not** yet been pinned down, because that requires inspecting production data (which this investigation did not access). To identify it:

1. From the September OtherSales charges (the set `getTrnOtherSalesChargeSumForDeliveryDate` returns for the target month), for each `product_id` resolve: `mst_product.product_type` → Freee product type (`mst_code_change`) → Freee contract type (`CommonUtil::getContractTypeInfo`).
2. For each resolved `(freee contract type, freee product type)`, check whether an **active** `mst_rule_for_journals` row exists (`segment2_id = <freee contract type>`, `product_type = <freee product type>`, `status = 1`).
3. The combination(s) with **no matching row** are the cause. Metabase or a read-only query against production is the fastest way to produce this list.

---

## 7. Recommended actions

### Immediate (unblock the FINAL re-run)
1. **Identify** the missing `(segment2_id, product_type)` combination(s) per §6.
2. **Add the missing `mst_rule_for_journals` row(s)** (Accounting to confirm the correct journal mapping — account item, department, segments — for that product/contract combination). This is a **data fix** and most likely unblocks the run with **no code change**.
3. **Verify earlier-step journals** (§5) before re-running, to avoid double-posting.
4. **Re-run** the September FINAL once the row is in place.

### Short-term (code hardening — prevent a hard abort)
5. Add a **null guard** in `getOtherSalesJournals()`: when `getMstRuleForJournals(...)` returns null, **log a clear error** (including `order_no`, `product_id`, resolved product_type and contract type) and either skip that single OtherSales entry or raise a descriptive domain error — instead of a raw null-dereference that aborts the whole run. This matches the defensive pattern already used for the partner lookup in the same method (`?? dummy`). *(Scope/approach to be agreed with the Lead; not yet implemented.)*

### Preventive (optional, to discuss)
6. Consider a **pre-run validation** that checks every in-scope OtherSales product/contract combination has an active journal rule before the batch starts, so a missing mapping is reported up front rather than mid-run.

---

## 8. What is confirmed vs. still to verify

**Confirmed (by reading the code + git history):**
- The crash is a null-dereference of a missing `mst_rule_for_journals` lookup in `getOtherSalesJournals()`.
- The lookup returns null when no active matching row exists, and the caller has no null guard.
- The failing code is pre-existing and was not changed by DEVOPS-6415, DEVOPS-6596, or ASCA.

**Still to verify (needs production data / operations):**
- The exact offending OtherSales charge / product / contract combination (§6).
- Whether any journals from earlier steps of the same run were committed before the abort (§5).
- The correct journal-rule mapping values for the missing row (Accounting decision).

---

## 9. References

- `app/Libs/SendJournalsDataLogic.php` — `getOtherSalesJournals()` (OtherSales T1 journal creation).
- `app/Models/MstRuleForJournals.php` — `getMstRuleForJournals()` (returns null on no match).
- Git: commit `6bfedd2c` (DEVOPS-6415) is the latest change to `SendJournalsDataLogic.php`; its diff does not touch the failing method.
- Related schedule context: `docs/asc-projects-master-timeline.md` (the 2026-10-02 18:00 FINAL run); `projects/asca/technical-notes/investigation/20260928-zpr-daily-table-cleanup/REPORT-00-zpr-daily-table-cleanup.md` (unrelated prior September step).
