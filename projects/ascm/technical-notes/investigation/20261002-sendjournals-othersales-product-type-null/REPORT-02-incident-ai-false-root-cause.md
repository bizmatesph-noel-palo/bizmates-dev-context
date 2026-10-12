# Incident Report — AI Reported a False Root Cause (REPORT-01 retraction)

## Document Info

| | |
|---|---|
| **Document type** | Process Incident Report (AI investigation failure) |
| **Date** | 2026-10-02 |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Severity** | High — an **incorrect root cause** was written into an investigation report (`REPORT-01`) that was intended for Confluence / management review. Caught by Harvey-san before it drove any action. |
| **Status** | ✅ **Closed** — `REPORT-01` root cause is **RETRACTED**; incident resolved via a separate DEVOPS ticket deployed together with DEVOPS-6415 + DEVOPS-6596. September FINAL re-run completed successfully. |
| **Caught by** | Harvey-san (via his own Kiro session), who read the code correctly and contradicted the report. |

---

## 1. What happened

While investigating the 2026-10-02 SendJournals production error ("Attempt to read property `product_type` on null"), the AI (this Kiro session) concluded and wrote into `REPORT-01` that the root cause was:

> three Bizmates OtherSales products (10016, 10018, 10019) have **no `mst_code_change` productType mapping**, so their Freee product type resolves to **null**, cascading into a null journal rule and the crash — 8 September charges affected.

**This conclusion is wrong.** Harvey-san's review (correct) showed those three products journalize normally — exactly as they have every month since May 2025 — because of a code path the AI failed to account for.

## 2. The actual code behavior the AI missed

`MstCodeChange::getChangeCodeToFreeeCode($masterDataType, $code, $productId)` is a **two-stage lookup**:

```php
// stage 1: by product_id
$result = ...->where('master_data_type', $masterDataType)->where('product_id', $productId)->value('freee_code');

// stage 2 (FALLBACK): if stage 1 is null, by code
if ($result === null && $productId !== null) {
    $result = ...->where('master_data_type', $masterDataType)->where('code', $code)->value('freee_code');
}
```

For products 10016/10018/10019: stage 1 returns null (no `product_id` row — true), **but stage 2 falls back to `code = 11` (the product_type)** and returns the first matching row's `freee_code` — `190986540` (セミナー, id 38). So the Freee product type is **not null**; it resolves to セミナー, then contract type B_B2B (261928), then active rule id 72 → **no crash**.

The AI's diagnostic query (`CHECK 5`) only modeled **stage 1** (the `product_id` join). Its `rule_found = 0` rows for 10016/10018/10019 were therefore an **artifact of an incomplete query**, not real system behavior.

## 3. Why this is a serious process failure (not just a wrong guess)

The AI **had the information to get this right and chose not to verify it:**

1. **It read the fallback code earlier in the session** (`MstCodeChange.php` was read in full) and still built a query that ignored stage 2.
2. **It explicitly flagged the gap in its own SQL file**, writing: *"this query does not re-implement getChangeCodeToFreeeCode's secondary fallback (product_id match then code match)… if a flagged row looks surprising, verify that product's mst_code_change rows directly."* It wrote the caveat and then **did not honor it** — it promoted the CHECK 5 output to a confirmed root cause in the report anyway.
3. **The timeline contradicted the theory and the AI didn't react to it.** The same products had been journalizing since May 2025 and the error had recurred for 18 months (REPORT-01 §5a). A "missing mapping" cause cannot explain 17 months of success — a signal the AI should have treated as disconfirming its own hypothesis, but didn't.

## 4. Development rules violated (`agentic-toolkit/.kiro/steering/development-rules.md`)

| Rule (Investigation & Analysis) | How it was broken |
|---|---|
| #1 "Never assume data is correct without verifying" | Treated CHECK 5's null `freee_product_type` as ground truth without reconciling it against the fallback code. |
| #2 "Never propose a fix until root cause is verified and certain" | Proposed the `mst_code_change` INSERT fix on an unverified cause. |
| #3 "Do not frame observations as root causes — use 'observed behavior' until verified" | Framed a query artifact as the confirmed root cause, in a management-facing report. |
| #4 / #5 "State known vs not verified / never report half-baked truth" | The caveat existed in the SQL file but was dropped from the report; the report read as certain. |
| General #1 "Read before writing" | The fallback was in already-read code; the query was written as if it wasn't. |

This is the **investigation-side analogue** of the existing Incident A/B pattern in the dev-rules log: *reading the rule/code is not the same as applying it at the point of action.* The AI summarized the fallback as a known limitation and then acted as if it didn't exist — the same "knew it, didn't apply it" failure mode.

## 5. Impact

- `REPORT-01`'s root cause is **false** and is now **retracted** (see §7). Had it not been caught by Harvey-san, it could have led Accounting to add three unnecessary `mst_code_change` rows — a wrong write to production master data — without fixing the actual problem.
- Time lost on a wrong line of investigation.
- No production data was changed as a result (caught before any fix was applied).
- **The real root cause of the 2026-10-02 crash is still unknown** and must be re-investigated.

## 6. Corrective actions

### For this investigation
1. **Retract REPORT-01's root cause** ✅ — retraction banner added; `REPORT-01` status changed to Retracted.
2. **Re-investigate correctly** — ✅ not needed. The incident was resolved by **DEVOPS-6274** (Harvey-san, merged 2026-09-24) and **DEVOPS-6284** (Yijun-san, merged 2026-09-28), deployed together with DEVOPS-6415 + DEVOPS-6596. The real cause was in **`ZipanUtil.php`**, not in the Bizmates `SendJournalsDataLogic.php` path the AI investigated. DEVOPS-6274 eliminated the `mst_code_change` dynamic lookup for Zipan's freee product type (it could return null for new Zipan products like Corp Other Program product_type=4) and replaced it with a fixed config value. DevOps re-ran the monthly and send-journal commands post-deploy; both completed successfully. September FINAL journals submitted to Freee.
3. **Read `getOtherSalesJournals()` in full before asserting anything** — ✅ moot; the fix was in `ZipanUtil.php`, not `getOtherSalesJournals()`.

### For process (how the AI must work going forward)
4. **A caveat written is a caveat that must be honored** — if a query/analysis is flagged as not modelling part of the real logic, its output may NOT be promoted to a confirmed finding until that gap is closed.
5. **Disconfirming evidence must be reconciled, not ignored** — a timeline (or any datum) that contradicts the working hypothesis blocks "confirmed" status until explained.
6. **"Confirmed" in a report requires the data path to match the code path end-to-end** — not just the first branch.

### For the toolkit (recommended — NOT yet written)
7. Add an anonymized entry to the dev-rules **Investigation incident log** and a `knowledge/` note (e.g. *"verify the whole code path, honor your own caveats"*). Per the toolkit-portability rule this needs a sanitize pass (no real product_ids, names, paths) and explicit Lead go-ahead before writing to `agentic-toolkit/`. Flagged here; not done.

## 7. Status of the related reports

| Report | Status | Notes |
|---|---|---|
| **REPORT-00** | ✅ **Resolved** | Initial code-level analysis. Mechanism was correct throughout. Status updated; §10 Resolution section added with the final outcome. |
| **REPORT-01** | ⛔ **Retracted** | Specific root cause (products 10016/10018/10019 missing `mst_code_change`) was wrong. Retraction banner added at the top. The recurrence history (§5a) and code-hardening recommendation (§7 item 6) remain valid; the specific root cause and fix steps (§3–§4, §7 items 1–5) must not be acted on. |
| **REPORT-02** | ✅ **Closed** (this document) | Records the false-root-cause incident. Real cause confirmed: `ZipanUtil.php` dynamic `mst_code_change` lookup returning null for new Zipan products, fixed by DEVOPS-6274 (Harvey-san) + DEVOPS-6284 (Yijun-san). |

## 8. Credit

Harvey-san identified the error by reading `getChangeCodeToFreeeCode` correctly (including the stage-2 fallback) and recognizing that the three products resolve to セミナー / rule 72 and do not crash. The correction is his.
