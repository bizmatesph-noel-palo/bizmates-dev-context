# REF-CAP-16 — Spec 02c Direction Change: Drop AllocationDetail CSV (Slack thread, 2026-10-19)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-19 (Received — Slack, 11:23 AM / 2:46 PM / 3:01 PM — one thread) |
| **Author (source)** | Hayato Kuroda (PM) · Noel Palo (Lead) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative. Drops Spec 02c (AllocationDetail CSV) from scope; sets the DEV04-first sequencing, the Dec-1 removal deadline, and the QA-exclude instruction. Supersedes REF-CAP-14 / REF-CAP-15 (02c review + sign-off) for the CSV deliverable. |
| **Audience** | Dev team (ASCA/ASCI), Accounting, PM, SDM, QA |
| **Supersedes** | REF-CAP-15 (02c sign-off); the AllocationDetail CSV deliverable in REF-CAP-14 and the 02c requirements |

> Verbatim source document. The full Slack thread (three messages) is preserved below. Do not alter. Our interpretation / impact analysis lives in `projects/asca/` — NOT here.

---

## Kuroda-san (PM) — Slack, 2026-10-19 11:23 AM

> Hi @Noel sna cc: @Glenn @Roi Patrick Florentino @here
> Sorry for the late change on this one — I need to update the direction for Spec 02c (AllocationDetail CSV).
> Originally we planned to output the allocation breakdown as a separate CSV, but after further discussion with Accounting, the decision is:
>
> The revenue of the new plans is output in the existing DailyRateCalculation CSV — no format change.
> CAP: the allocated amounts (Option 1 overwrite).
> CIP: the residual-value price (71,920 tax-incl.) for coaching and the App price (3,980), each processed by the existing daily proration. No allocation step, so nothing extra is needed for CIP.
>
> Since the existing format alone doesn't show how the CAP amounts were allocated, a dedicated table will be added to Metabase for verification (ASCA-8). This replaces the AllocationDetail CSV. The column changes (incl. removing the allocation-basis-amount column) are already in the ASCA-8 ticket.
>
> So we will not create the new AllocationDetail CSV. Please drop 02c (ASCA-52) from scope. Sorry for the rework after the review rounds.
>
> A couple of things I'd like to confirm:
>
> log_alloc_bundle_outcomes (ASCA-66): 02a also writes skip/fail records to it, so I think we should keep it even without the CSV.
> The run-status extension (COMPLETED_WITH_ERRORS + v_alloc_prorations_active / V-5 / supersede treating it as an active Final) is still needed, so that Metabase shows the allocated rows correctly. Let's keep that change-request as is.
>
> Let me know if this affects anything else on your side.
> Thank you.

## Noel (Lead) — Slack, 2026-10-19 2:46 PM

> Good afternoon @Hayato Kuroda san
> cc: @Roi Patrick Florentino san
>
> Regarding Spec 02c and Spec 02d, both have already been merged into ASCA-master.
> We have not yet applied the latest requirement change and decided to proceed with what is currently generated.
>
> We will apply the fix at a later time; for now, we will first deploy to DEV04 to assess if any fixes are needed, and then include those along with the requirement adjustments.
> I think the most critical priority for now is to verify that the commands work as intended, and then add any necessary changes or adjustments once their functionality is confirmed.
>
> Thank you 🙇

## Kuroda-san (PM) — Slack, 2026-10-19 3:01 PM

> Hi @Noel san cc: @Roi Patrick Florentino
> Thanks for the update, I agreed to deploy to DEV04 first and confirm the commands work as intended, then plz apply the adjustments.
>
> Just 2 points on 02c:
>
> Please make sure the AllocationDetail CSV is removed (generation + adding it to the zip/email) before the CAP beta release on 12/1. Could you create a ticket for it so it doesn't get missed?
> On DEV04, I think it's fine to keep using the CSV as a temporary aid to check the allocation results, since the metabase table (ASCA-8) isn't ready yet. But please don't include it in the QA scope, as it will be removed.
> Thank you

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

### The 02c decision (Kuroda 11:23 AM)

| Item | Decision |
|---|---|
| Spec 02c AllocationDetail CSV | DROPPED — replaced by a Metabase table on ASCA-8. The existing DailyRateCalculation CSV already carries CAP allocated amounts (Option 1 overwrite) + CIP residual/App via existing proration. |
| `log_alloc_bundle_outcomes` (ASCA-66) | KEEP — 02a writes skip/fail outcome rows to it independent of the CSV. |
| Run-status extension (ASCA-68: COMPLETED_WITH_ERRORS + view/V-5/supersede) | KEEP as-is — needed so Metabase shows allocated rows for a completed-with-errors Final. |
| Allocation-basis-amount column | Removed — handled in the ASCA-8 Metabase ticket, not in the ASCA repo. |

### The operational follow-up (Noel 2:46 PM → Kuroda 3:01 PM)

| Point | Decision / action |
|---|---|
| Sequencing | **DEV04 deploy + command verification FIRST**, then apply the requirement adjustments (02c removal + any DEV04 fixes) together. Agreed by both. |
| **02c removal deadline** | **Hard: before the CAP beta release on 2026-12-01.** The AllocationDetail CSV (generation + zip/email inclusion) MUST be removed by then. |
| Ticket | Kuroda-san asked for a dedicated ticket so it is not missed → the 02c removal CR (draft `ASCA-XXX-remove-02c-allocationdetail-csv.md`, to be created under ASCA-55). Add the Dec-1 deadline to it. |
| DEV04 usage | The CSV MAY stay on DEV04 as a **temporary verification aid** while the Metabase table (ASCA-8) isn't ready. |
| **QA scope** | **Exclude the AllocationDetail CSV from QA scope** — it is being removed, so QA should not test it. Flag to QA (Miko) and in the QA plan. |

### Note on CIP figures (per the message)
- CIP coaching residual booking price: 71,920 tax-incl (consistent with REF-CIP-05 price_flag 3).
- CIP App: 3,980 tax-incl. Both flow through existing daily proration — no allocation engine step for CIP.

### Impact note
- 02c (ASCA-55 Coding) was already MERGED to ASCA-master (PR #312) before this feedback. Dropping it is therefore a REMOVAL of merged code, handled as a change-request under the 02c coding story — not a new spec. See the ADR and CR for the ASCA-side decision + removal scope.
- The 02c removal impact report + CR draft carry the **Dec-1 hard deadline** and the **QA-exclude** note (both from the 3:01 PM confirmation).
- Timeline: the 02c removal now has a concrete deadline (Dec 1), earlier than the Dec 17 project deadline.
