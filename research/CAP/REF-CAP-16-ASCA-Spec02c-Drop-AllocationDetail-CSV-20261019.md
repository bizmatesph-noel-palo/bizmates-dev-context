# REF-CAP-16 — Spec 02c Direction Change: Drop AllocationDetail CSV (Kuroda-san, 2026-10-19)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-19 (Received — Slack, 11:23 AM) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative. Drops Spec 02c (AllocationDetail CSV) from scope. Supersedes REF-CAP-14 / REF-CAP-15 (02c review + sign-off) for the CSV deliverable. |
| **Audience** | Dev team (ASCA/ASCI), Accounting |
| **Supersedes** | REF-CAP-15 (02c sign-off); the AllocationDetail CSV deliverable in REF-CAP-14 and the 02c requirements |

> Verbatim source document. Kuroda-san's Slack message preserved in full. Do not alter. Our interpretation / impact analysis lives in `projects/asca/` — NOT here.

---

## Kuroda-san — Slack, 2026-10-19 11:23 AM

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

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

| Item | Decision |
|---|---|
| Spec 02c AllocationDetail CSV | DROPPED — replaced by a Metabase table on ASCA-8. The existing DailyRateCalculation CSV already carries CAP allocated amounts (Option 1 overwrite) + CIP residual/App via existing proration. |
| `log_alloc_bundle_outcomes` (ASCA-66) | KEEP — 02a writes skip/fail outcome rows to it independent of the CSV. |
| Run-status extension (ASCA-68: COMPLETED_WITH_ERRORS + view/V-5/supersede) | KEEP as-is — needed so Metabase shows allocated rows for a completed-with-errors Final. |
| Allocation-basis-amount column | Removed — handled in the ASCA-8 Metabase ticket, not in the ASCA repo. |

### Note on CIP figures (per the message)
- CIP coaching residual booking price: 71,920 tax-incl (consistent with REF-CIP-05 price_flag 3).
- CIP App: 3,980 tax-incl. Both flow through existing daily proration — no allocation engine step for CIP.

### Impact note
02c (ASCA-55 Coding) was already MERGED to ASCA-master (PR #312) before this feedback. Dropping it is therefore a REMOVAL of merged code, handled as a change-request under the 02c coding story — not a new spec. See the ADR and CR for the ASCA-side decision + removal scope.
