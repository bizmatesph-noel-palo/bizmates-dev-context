# ~~Investigation (Follow-up) — SendJournals OtherSales Error: Root Cause Confirmed~~

> ## ⛔ RETRACTED
>
> **This report's root cause is WRONG and must not be acted on.**
>
> The specific root cause stated here — that products 10016, 10018, and 10019 are missing `mst_code_change` mappings — was **disproven** by Harvey-san after this report was drafted. `MstCodeChange::getChangeCodeToFreeeCode()` has a two-stage lookup; stage 2 falls back on `code` and successfully resolves those products. The "null freee_product_type" readings in CHECK 5 were an artifact of a query that only modelled stage 1.
>
> The incident was ultimately resolved by **DEVOPS-6274** (Harvey-san — fixed `ZipanUtil.php` to use a fixed Freee product type config value instead of the dynamic `mst_code_change` lookup that could return null) and **DEVOPS-6284** (Yijun-san — added the Zipan Freee code to `config/code.php`), deployed together with DEVOPS-6415 + DEVOPS-6596. The September FINAL was re-run by DevOps after that deploy and completed successfully.
>
> **See instead:**
> - `REPORT-02-incident-ai-false-root-cause.md` — documents the false root cause and how it was caught
> - `REPORT-00-sendjournals-othersales-product-type-null.md` — the original analysis (mechanism correct; resolution updated with the final outcome)
>
> The rest of this document is preserved as a record. The **recurrence history (§5a)** and the **code-hardening recommendation (§7, item 6)** remain valid. Everything in **§3–§4 (specific root cause and diagnostics) and §7 items 1–5 (the `mst_code_change` fix steps)** is **incorrect and retracted**.

---

# Investigation (Follow-up) — SendJournals OtherSales Error: ~~Root Cause Confirmed~~ [RETRACTED]

## Document Info

| | |
|---|---|
| **Document type** | Production Incident Investigation — follow-up (**RETRACTED** — root cause was incorrect) |
| **Date** | 2026-10-02 |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | ⛔ **RETRACTED** — root cause in this report is wrong; superseded by `REPORT-02-incident-ai-false-root-cause.md`. Incident resolved via a separate DEVOPS ticket. |
| **Severity** | High — the September **FINAL** (確定) journal run aborted; no Freee journals submitted for the affected run |
| **Environment** | Production |
| **Command** | `SendJournalsDataCommand` (Final / 確定), 2026-10-02 18:00:41 JST |
| **Audience** | Management, Accounting, Dev team |
| **Supersedes** | `REPORT-00` (initial code-level analysis). REPORT-00's mechanism was correct; this report corrects the precise root cause one step earlier and names the offending records, using production data. |

---

## 1. Executive summary

The September **FINAL** accounting run (`SendJournalsDataCommand`, 2026-10-02 18:00) stopped with a system error while building the "OtherSales" (その他売上) journal entries, before anything was submitted to Freee.

- **Confirmed root cause (production data, 2026-10-02):** three Bizmates OtherSales products in September's data — **`product_id` 10016 (ロールプレイテスト（Bizmates）), 10018 (集合研修), 10019 (個別研修)** — have **no "product type" mapping row** in the code-conversion master table (`mst_code_change`, `master_data_type = 1`). Because the system cannot resolve a **Freee product type** for them, the downstream **journal-rule** lookup (`mst_rule_for_journals`) returns nothing, and the code — which does not guard against the "nothing found" case — aborts. **8 OtherSales charges** across those three products are affected. This is a **per-product master-data omission on Bizmates products** (verified not a Zipan-tenant issue — §3, §4).
- **This is a missing master-data (configuration) issue, not a code defect introduced by recent work.** The failing code is pre-existing in the OtherSales journal path. It was **not** introduced by the ASCM refactor (DEVOPS-6415), the Zipan price-revision change (DEVOPS-6596), or the ASCA allocation project (whose code does not run in this batch yet). Evidence in §5.
- **The DEVOPS-6287 "B2B Bizmates-App" setup is correctly configured in production and is NOT involved** — explicitly ruled out by the diagnostics (§4).
- **Impact:** the Final run did not complete; no journals were sent for the affected run. The condition is **deterministic** — re-running without adding the missing mappings fails again at the same point.
- **Fix (data, no code change required to unblock):** Accounting confirms the correct Freee product type for products 10016 / 10018 / 10019; add the three `mst_code_change` mappings (and confirm the matching journal rule); verify no earlier-step journals were already posted; re-run. Separately, harden the code with a null guard so a future missing mapping fails gracefully.

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

> **Note on the line number.** The deployed code and the current working copy differ slightly in line numbering, so "line 1134" does not point to the same statement in the current source. This investigation relies on the **method** (`getOtherSalesJournals`) and the **property** (`product_type` read on a null object), which are unambiguous.

---

## 3. Root cause (confirmed with production data)

### 3.1 The code path

For each September OtherSales charge, `getOtherSalesJournals()` resolves, in order:

1. `product_id` → **Freee product type** via `MstCodeChange::getChangeCodeToFreeeCode(master_data_type = 1, …, product_id)`. **This returns null if the product has no `master_data_type = 1` row.**
2. (with the contract type) → the **journal rule** via `MstRuleForJournals::getMstRuleForJournals(segment2_id, product_type)`, which does `->first()` and **returns null when nothing matches** (`segment2_id`, `product_type`, `status = 1`).
3. The code then reads `$mstRuleForJournals->product_type` (and `->department_id`, `->segment1_id`, `->segment2_id`) **with no null guard** → ErrorException.

The partner lookup in the same method has a fallback (`?? dummy`); the Freee-product-type resolution and the journal-rule lookup do not.

### 3.2 Where it actually breaks (one step earlier than a missing rule)

Production diagnostics (§4) show the break is at **step 1**, not step 2: the three products resolve to a **null Freee product type**, which then guarantees a null journal rule. So the true root cause is the **missing `mst_code_change` productType mapping**, which cascades into the null-rule crash.

### 3.3 The offending records

8 September OtherSales charges across 3 products, all with the identical signature — `mst_product_type = 11`, **`freee_product_type` empty/null**, no matching rule:

| product_id | product name | mst_product_type | Freee product type | # Sept charges | order_no(s) |
|---|---|---|---|---|---|
| **10016** | ロールプレイテスト（Bizmates）(Roleplay Test – Bizmates) | 11 | **missing** | 1 | 10029260 |
| **10018** | 集合研修 (Group training) | 11 | **missing** | 6 | 10026308, 10029243, 10030236, 10030415, 10030794, 10031082 |
| **10019** | 個別研修 (Individual training) | 11 | **missing** | 1 | 10030982 |

For contrast, product_type-11 OtherSales products that resolved correctly in the same run **do** have a Freee product-type mapping — e.g. **10007** セミナー → `190986540`; **10017** ロールプレイテスト（Zipan）→ `191155084`. The only difference for 10016 / 10018 / 10019 is the **missing `mst_code_change` (`master_data_type = 1`) productType row**.

**These are Bizmates OtherSales products — not a Zipan issue (verified).** CHECK 6 established: (a) all three are Bizmates-side products (10016 is literally "ロールプレイテスト（**Bizmates**）"; 10018/10019 are generic training products); (b) they do **not** exist in the Zipan `mst_product` table (CHECK 6b empty); and (c) the existing `mst_code_change` productType mappings for the product_type-11 family cover 10007/10008/10009/10017/10020 but **omit 10016/10018/10019** (CHECK 6c). Notably, product **10017 "ロールプレイテスト（Zipan）" IS mapped while its Bizmates twin 10016 "ロールプレイテスト（Bizmates）" is NOT** — a clear per-product omission. (The earlier thought that the Zipan code list `freeeZipanCodes` might explain the gap was checked and ruled out — 10017 simply happens to be the Zipan roleplay product; the gap is on the Bizmates products.) So this is a **per-product master-data omission on Bizmates OtherSales products**, and the Bizmates B2B journal path (`segment2_id = 261928`) applies to the fix.

---

## 4. Evidence (read-only Metabase diagnostics, 2026-10-02)

Queries saved as `METABASE-diagnostic-queries.sql`; results as `CHECK_*_query_result_*.csv` in this folder.

| Check | Result | What it establishes |
|---|---|---|
| **CHECK 1 / 1b** | B2B_App row present (`master_data_type = 2`, `code = 4`, `freee_code = 1622735`); 5 segment2 rows total | DEVOPS-6287 master data **is applied**. |
| **CHECK 2 / 3** | `mst_rule_for_journals.id = 102` = `segment2_id 1622735`, `product_type 236270504`, `status 1` | The B2B-App journal rule **is correct**. |
| **CHECK 4** | **Empty** | **No** September OtherSales charge was on the Bizmates-App path → the B2B-App case is **not** the cause. |
| **CHECK 5** | **8 rows `rule_found = 0`** (products 10016/10018/10019), each with **null `freee_product_type`** | **The root cause:** missing productType mapping → null Freee type → null rule → crash. |
| **CHECK 4b** | 10016/10018/10019 show blank `freee_product_type`; 10007/10017 resolve | Corroborates CHECK 5. |
| **CHECK 6a** | 10016 = ロールプレイテスト（Bizmates）, 10018 = 集合研修, 10019 = 個別研修 — all Bizmates OtherSales products (product_type 11) | The unmapped products are **Bizmates** products, not Zipan. |
| **CHECK 6b** | **Empty** (product_ids not in the Zipan `mst_product`) | Rules out "these are Zipan products." |
| **CHECK 6c** | productType mappings exist for 10007/10008/10009/10017/10020 but **not** 10016/10018/10019 | A **per-product omission**; 10017 (Zipan twin) is mapped while 10016 (Bizmates twin) is not. |

**Conclusion from evidence:** the cause is the missing `mst_code_change` productType mapping for the **Bizmates** OtherSales products 10016/10018/10019 — a per-product master-data omission. The DEVOPS-6287 B2B-App path is fully configured and unrelated; the `freeeZipanCodes` angle was checked and ruled out.

---

## 5. Not a regression from recent project work

| Check | Finding |
|---|---|
| **Which code failed?** | `getOtherSalesJournals()` — part of the **existing ASC "OtherSales" journal path**, long predating the current projects. |
| **Is the ASCA allocation engine involved?** | **No.** ASCA Spec 01 (Foundation) is merged but **not wired into the batch** (that is Spec 02, not yet merged). The allocation engine does not run in this command today. |
| **Did the ASCM refactor (DEVOPS-6415) touch this?** | **No.** The only recent commit touching `SendJournalsDataLogic.php` (commit `6bfedd2c`, DEVOPS-6415) is the zip/email service-extraction (6 insertions / 51 deletions); its diff does **not** touch `getOtherSalesJournals`, the `MstRuleForJournals` lookup, or any `product_type` reference. |
| **Did the ZPR change (DEVOPS-6596) touch this?** | **No.** It added one Zipan plan to an enum; it does not touch the OtherSales journal path. |
| **Is this the DEVOPS-6287 (B2B-App) area?** | **No.** That master data is correctly in place and no App-path charge ran this month (§4, CHECK 1–4). |

**Conclusion:** a **missing-master-data** condition in untouched, pre-existing code, surfaced by this month's OtherSales data for three products — not introduced by any recent project.

---

## 5a. Recurrence history (production log)

The production error log (`grep ERROR` on `storage/logs/laravel.log`, saved in this folder) shows the **same "product_type on null" failure has recurred over 18+ months**, long before any of the recent projects:

| Date | Code location | Note |
|---|---|---|
| 2025-04-03 00:33 | `SendJournalsDataLogic.php:226` | same error, earlier call site |
| 2025-06-04 00:54 | `SendJournalsDataLogic.php:226` | recurrence |
| 2026-05-08 00:53 | `SendJournalsDataLogic.php:280` | same error, different call site |
| **2026-10-02 19:09** | `SendJournalsDataLogic.php:1134` | **this incident** (`getOtherSalesJournals`) |

Two things this establishes:

1. **The fragility is long-standing and pre-dates the ASCM refactor / ZPR / ASCA entirely** — the earliest occurrence is 2025-04, over a year before this work. This is independent corroboration of §5 (not a regression).
2. **The same root mechanism recurs at *different* line numbers** (226 → 280 → 1134), i.e. at **more than one lookup site** in the file. Each time, a product/charge resolves to a null product type (or an otherwise unresolvable journal rule) and the unguarded dereference aborts the whole run. Because no null-guard was ever added, the identical bug keeps resurfacing wherever the next unmapped product happens to flow through.

This is the core argument for the **code-hardening** action in §7: the data fix clears *this* run, but only a guard at these lookup sites stops the pattern from recurring the next time a new OtherSales product is onboarded without its mapping.

---

## 6. Impact

- The September **FINAL** (確定) run **aborted during journal building, before any Freee submission** for the affected run.
- No partial/incorrect journals were sent **as a result of this specific error** (the abort precedes the Freee send for the OtherSales path).
- The condition is **deterministic**: the same data fails at the same point on re-run until the missing mappings are added.
- Earlier September steps are unaffected and unrelated (the ZPR daily-table cleanup on 2026-09-30 and the 10/01 PRE verification).

> **To confirm (operations) before re-running:** whether any journals from *earlier* T-steps of the same run were already committed before the abort, so the re-run avoids double-posting. Verify against Freee / the send-history.

---

## 7. Recommended actions

### Immediate (unblock the FINAL re-run) — data fix, no code change
1. **Accounting confirms the correct Freee product type** for products **10016 (ロールプレイテスト（Bizmates）), 10018 (集合研修), 10019 (個別研修)** (all `mst_product_type = 11`), referencing how comparable OtherSales products are mapped (e.g. 10007 セミナー → 190986540; the Zipan twin 10017 ロールプレイテスト（Zipan）→ 191155084 — 10016 is its Bizmates counterpart).
2. **Add the three `mst_code_change` rows** (`master_data_type = 1`, `product_id`, `freee_code = <confirmed Freee product type>`), in a **write-capable MySQL client (not Metabase)**, inside a transaction (same pattern as the prior Wu-san script).
3. **Confirm a matching active journal rule** exists in `mst_rule_for_journals` for each resulting `(segment2_id = 261928 [B2B], product_type = <new Freee type>, status = 1)`; add it if missing (Accounting mapping decision — account item / department / segments).
4. **Verify earlier-step journals** (§6) before re-running.
5. **Re-run** the September FINAL once the mappings are in place.

### Short-term (code hardening — prevent a hard abort) — recommended given the recurrence (§5a)
6. Add **guards** at the product-type / journal-rule lookup sites in `SendJournalsDataLogic.php` — not only `getOtherSalesJournals()` (line ~1134) but also the other sites this error has hit historically (lines ~226 / ~280, §5a). When the Freee product type resolves to null, or `getMstRuleForJournals(...)` returns null, **log a clear error** (with `order_no`, `product_id`, resolved product_type / contract type) and either skip that single entry or raise a descriptive domain error — instead of a raw null-dereference that aborts the whole run. Mirrors the partner-lookup fallback already in the method. The recurrence history (§5a: 2025-04, 2025-06, 2026-05, 2026-10) shows the data gap *will* happen again as new OtherSales products are onboarded, so the guard is the durable fix. *(Approach to be agreed with the Lead; not yet implemented.)*

### Preventive (optional)
7. A **pre-run validation** that every in-scope OtherSales product has a Freee product-type mapping and a matching journal rule before the batch starts, so a missing mapping is reported up front rather than mid-run.

---

## 8. Confirmed vs. still to verify

**Confirmed (code + git history + production data):**
- The crash is a null-dereference in `getOtherSalesJournals()`, caused by a null Freee product type (step 1) that produces a null journal rule.
- Pinned to **products 10016 / 10018 / 10019 missing their `mst_code_change` (`master_data_type = 1`) productType mapping** — 8 September OtherSales charges (§3, §4).
- DEVOPS-6287 B2B-App master data is correct and uninvolved; failing code is pre-existing and untouched by DEVOPS-6415 / DEVOPS-6596 / ASCA.

**Still to verify (Accounting / operations):**
- The **correct Freee product-type value** to map for 10016 / 10018 / 10019 (Accounting decision).
- Whether an active `mst_rule_for_journals` row already exists for each resulting `(261928, <new Freee type>)` pair or must also be added.
- Whether any earlier-step journals were committed before the abort (§6), before re-running.

---

## 9. References

- `app/Libs/SendJournalsDataLogic.php` — `getOtherSalesJournals()` (OtherSales T1 journal creation; the null-dereference site).
- `app/Models/MstCodeChange.php` — `getChangeCodeToFreeeCode()` (returns null when a product has no `master_data_type = 1` row — the step-1 break).
- `app/Models/MstRuleForJournals.php` — `getMstRuleForJournals()` (returns null on no match — step 2).
- `app/Libs/CommonUtil.php` — `getContractTypeInfo()` / `getSegment2Id()` (segment2 / contract-type resolution; B2B path for OtherSales).
- Git: commit `6bfedd2c` (DEVOPS-6415) — latest change to `SendJournalsDataLogic.php`; diff does not touch the failing method.
- **Diagnostics (this folder):** `METABASE-diagnostic-queries.sql` + `CHECK_{1,1b,2,3,4b,5,6a,6c}_query_result_*.csv`. CHECK 5 is the decisive evidence; CHECK 6 classifies the products as Bizmates (not Zipan) and shows the per-product mapping omission.
- **Production error log (this folder):** `(production)[root@manage accounting error log 20261002.txt` — `grep ERROR` of `storage/logs/laravel.log`; confirms the 2026-10-02 19:09 incident at line 1134 and the recurrence history (§5a).
- `REPORT-00-sendjournals-othersales-product-type-null.md` — initial analysis (this report supersedes its root-cause section with production-data confirmation).
- Related schedule context: `docs/asc-projects-master-timeline.md` (the 2026-10-02 18:00 FINAL run).
