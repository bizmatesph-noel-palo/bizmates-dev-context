# REF-CAP-14 — ASCA Spec 02c Review Feedback, Round 3 (Kuroda-san, 2026-10-13)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-13 (Received — Slack thread) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative Round-3 review feedback for ASCA Spec 02c |
| **Audience** | Dev team (ASCA), Accounting |
| **Reviewed** | 02c requirements after Round-2 (REF-CAP-13 §3 + the 02c schema-decision thread) was folded in |
| **Companion** | `research/CAP/REF-CAP-13-ASCA-Spec02-Review-Round2-20261005.md` (Round-2), `projects/asca/documentation/ASCA-PROPOSAL-20261008-skipped-failed-bundle-recording.md` |

> ⚠️ **Verbatim source document.** Kuroda-san's Round-3 02c review, preserved in full. Do not alter this content; our resolution/impact tracking lives in `projects/asca/`. Cross-reference notes (mine, not part of the source) are at the very bottom, clearly marked.

---

## Kuroda-san — Round-3 feedback (2026-10-13, 11:09 AM)

> Hi @Noel san, thank you for the update and sorry for late.
> I confirmed and 3 things came out of this round before I can sign off 02c:
>
> **1. Completed-with-errors runs are not "active" in the Spec 01 view (needs a fix)**
> `v_alloc_prorations_active` and the V-5 active-Final rule only accept status = 1 (Completed). RunStatus has no completed-with-errors value today, so once we add it, a Final run that finishes completed-with-errors drops out of the view. 02c Req 2.2 reads allocated rows from that view, so:
> - first Final of the month finishes completed-with-errors → the CSV shows the exception rows but no allocated rows (same for Metabase)
> - an earlier Final was Completed and a re-run finishes completed-with-errors → the view can return the older run's rows
> Please make the view, the V-5 rule and the supersede step treat completed-with-errors as an active Final, as part of the run-status extension to Spec 01, and state it in 02a/02c. ASCA-34 touches the same view, so it may be convenient to handle them together.
>
> **2. CIP bundles in the outcome table (question)**
> 02a Req 2.5 lists CIP among the V-3 skips that write a per-bundle outcome row, and 02c lists every outcome row in the CSV. Read literally, every CIP subscriber would appear as a skipped row every month, which would bury the real exceptions. Does the engine actually pick up CIP rows (e.g. through the shared App product 10022), or are CIP plans filtered out before bundles are formed? Either way, CIP is out of the engine by design, so my preference is that it writes no outcome row and never appears in the CSV. Could you confirm and adjust Req 2.5?
>
> **3. 02c Req 2.12: exception-row columns can be filled (minor)**
> プロダクトタイプ (product type) is blank, プロダクトID (product id) / 部署ID (DID) are "where available", and 契約種類 (contract type) isn't mentioned for exception rows. Daily-rate log row we already read for 元金額 carries department_id, product_id, product_type and contract_type, so please fill those four columns from that same row.
>
> Minor: the 02c staging note and Dependencies still say "approved 2026-10-05" (it was 10-08).
>
> **4. Spec 01 extensions for 02a**
> I saw the three items in project-context. All three follow from decisions we already made, so they are fine from my side: the completed-with-errors run status (with point 1 above), the log_alloc_bundle_outcomes table, and effective_from = 2026-12-01. Please go ahead with the change-request.
>
> Once 1–3 are in, 02c is good from my side.
> Thank you

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

| Item | Decision / finding | Where it lands |
|---|---|---|
| **#1 Completed-with-errors active in view** | The view, V-5 active-Final rule, and supersede step must treat `COMPLETED_WITH_ERRORS` as an active Final (same as `COMPLETED`). Owned by the **Spec 01 run-status extension**; overlaps **ASCA-34** (same view) — handle together. | 02c Req 2.2 (reference) + Dependencies; 02a Req 4 (to state); Spec 01 run-status CR |
| **#2 CIP no outcome row** | ✅ **Verified in code:** `BundleDetectionService::fetchCandidateRows()` filters candidates by `CoachingAndAppPlanEnum` (CAP 1016–1027) on `plan_id` **before** grouping, with a defensive `exists()` guard. A CIP charge (even one carrying the shared App 10022) never becomes a candidate, so no CIP bundle is formed, no V-3 skip, no outcome row. Kuroda-san's preferred behaviour already holds — fix is wording in 02a Req 2.5, not code. | 02a Req 2.5 (correct wording); 02c Req 2.2 + 5.1 (CIP never appears) |
| **#3 Exception-row columns** | Fill 部署ID / プロダクトID / プロダクトタイプ / 契約種類 from the same daily-rate log row already read for 元金額. | 02c Req 2.12 |
| **Minor date fix** | "approved 2026-10-05" → **2026-10-08** (the outcomes-table approval date). | 02c staging note + Dependencies |
| **#4 Spec 01 extensions approved** | All three approved (run status incl. #1, `log_alloc_bundle_outcomes` table, `effective_from = 2026-12-01`). Go ahead with the change-request. | Tickets [ASCA-66](https://bizmates.atlassian.net/browse/ASCA-66) (table, ls-db) + [ASCA-67](https://bizmates.atlassian.net/browse/ASCA-67) (effective_from, accounting repo) raised under ASCA-18 |

> **Status:** Round-3 items 1–3 folded into the 02c requirements (2026-10-13). Item 2 confirmed against `BundleDetectionService` (CIP filtered before bundle formation). Spec 01 CR tickets ASCA-66/67 created. **02c awaits Kuroda-san's final sign-off** ("once 1–3 are in, 02c is good"), then promotion to the code repo. No code was changed when creating this record.
