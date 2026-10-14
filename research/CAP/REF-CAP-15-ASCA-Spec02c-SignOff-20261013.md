# REF-CAP-15 — ASCA Spec 02c Sign-Off + Follow-ups (Kuroda-san, 2026-10-13)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-13 (Received — Slack thread, 4:33 PM) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — **02c G1 sign-off** + two non-blocking follow-ups + one 02c design-phase note |
| **Audience** | Dev team (ASCA), Accounting |
| **Companion** | `research/CAP/REF-CAP-14-ASCA-Spec02c-Review-Round3-20261013.md` (Round-3 review this signs off) |

> ⚠️ **Verbatim source document.** Kuroda-san's 02c sign-off, preserved in full. Do not alter this content; resolution/impact tracking lives in `projects/asca/`. Cross-reference notes (mine, not part of the source) are at the very bottom, clearly marked.

---

## Kuroda-san — 02c sign-off (2026-10-13, 4:33 PM)

> @Noel san thank you for the quick update. All three Round-3 points are reflected in 02c, and thanks for checking BundleDetectionService for the CIP question.
> 02c is signed off from my side. Please go ahead and promote it.
> 2 follow-ups so they don't get lost (neither blocks the sign-off):
>
> **Ticket for the run-status / view change**
> ASCA-66 (outcomes table) and ASCA-67 (effective_from) are raised, but the COMPLETED_WITH_ERRORS status and the view / V-5 / supersede change don't have a home yet. 02c depends on it, and ASCA-34 is already merged, so could you raise a separate ticket for it (or add it explicitly to the 02a Coding story) before 02a coding starts?
>
> **02a Req 2.5 wording**
> 02c says 02a Req 2.5 was corrected, but the 02a file still lists CIP among the V-3 skips that write an outcome row. Please update it, including the promoted copy in the code repo.
>
> One note for the 02c design phase: when a refund is skipped or fails, please emit an exception row for the refund charge only. If the outcome row also carries the original coaching / app charge ids, Req 2.3 would list those charges again as exception rows, even though they already appear as allocated rows in the same month.
>
> Thank you

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

| Item | Status / action |
|---|---|
| **02c G1 sign-off** | ✅ Signed off 2026-10-13. Promote 02c `requirements.md` to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02c-allocation-detail-csv/` with a valid `.config.kiro`. |
| **Follow-up 1 — run-status/view ticket** | ✅ **Already raised: [ASCA-68](https://bizmates.atlassian.net/browse/ASCA-68)** (COMPLETED_WITH_ERRORS + `v_alloc_prorations_active`/V-5/supersede treats it as active Final; overlaps ASCA-34). Created before this message arrived — no new ticket needed. |
| **Follow-up 2 — 02a Req 2.5 wording** | ⏳ **To fix:** 02a `requirements.md` still lists CIP among the V-3 skips that write an outcome row. Correct it to say CIP is filtered before bundle formation (no outcome row, never in CSV) — in BOTH the dev-context 02a spec and the promoted code-repo copy. |
| **02c design-phase note — refund exception rows** | ⏳ **Fold into 02c requirements (Req 2.12 / 2.3):** when a refund is skipped/failed, the exception row is emitted for the **refund charge only** — NOT the original coaching/app charge ids. Otherwise Req 2.3 would re-list the original charges as exception rows even though they already appear as allocated rows the same month. Adjust the 02c one-row-per-known-charge rule so a refund outcome row expands to the refund charge only. |

> **Status:** 02c signed off; promotion + the two follow-ups (02a Req 2.5 wording, 02c refund-exception-row note) in progress. Follow-up 1 was already satisfied by ASCA-68. No code changed when creating this record.
