# REF-CIP-08 — Lesson-Bundled CIP (1029–1032) Refund Clarification (Glenn-san Q + Kuroda-san A, 2026-10-20)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-20 (Received — Slack) |
| **Author (source)** | Glenn (question) · Hayato Kuroda, PM (answer) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative. Closes the lesson-bundled CIP refund gap left open in REF-CIP-07 / REF-CIP-06. |
| **Audience** | Dev team (ASCA/ASCI), Accounting, QA |
| **Refines** | REF-CIP-05 (CIP = separate already-priced charges), REF-CIP-06 (refund patterns), REF-CIP-07 (CIP refund-type identification) |

> Verbatim source document. Glenn-san's question and Kuroda-san's answer preserved in full. Do not alter. Our interpretation / impact analysis lives in `projects/asci/` — NOT here.

---

## Glenn-san — Slack, 2026-10-20 2:12 PM

> Hi @Hayato Kuroda san @Noel san cc @Roi Patrick Florentino san @Mitch Doblada san. CIP related question: Regarding the Refund on lesson-bundled CIP (1029–1032) is underspecified — the cooling-off rule is stated for the Solo plan total (75,900), but for a bundled plan the "plan total" includes the Lesson. Does cooling-off refund the Lesson too, and on which charge does the negative land?

## Kuroda-san — Slack, 2026-10-20 5:14 PM

> Hi @Glenn san cc: @Roi Patrick Florentino @Mitch Doblada @Noel
> Thanks for catching this. I confirmed:
>
> **1. Charges for lesson-bundled CIP (1029–1032)**
> The Lesson is issued as its own charge, separate from Coaching Intensive and App.
> So a refund never puts the Lesson amount on the Coaching Intensive charge.
>
> **2. Cooling-off**
> Yes, the Lesson is refunded too. Each portion is refunded on its own charge:
> • Lesson → a negative on the Lesson charge. Existing ASC handles it, the same way as a standalone lesson plan. The CIP split does not touch it.
> • Coaching + App → a negative on the Coaching Intensive charge, then split to App with the existing rule.
>
> The 75,900 in the cooling-off rule is the Coaching + App portion, not the full plan total. It is the same for Solo and for lesson-bundled plans.
>
> Example (1029, 90% refund):
> • Lesson: −13,365 (= 14,850 × 90%) on the Lesson charge
> • Coaching Intensive: −68,310 (= 75,900 × 90%) → Coaching −64,728 / App −3,582
> • Total: −81,675
>
> **3. Other refund types**
> • Consumption-tax exemption: same idea. Lesson −1,350 (= 14,850 − 13,500) on the Lesson charge. Coaching Intensive −6,900 → Coaching −6,538 / App −362.
> • Contract overlap (B2C/B2E → B2B): only the Lesson is refunded, on the Lesson charge. Coaching and App get no refund, same as today.
> • Shareholder benefit: already handled per charge. The lesson row goes to the Lesson charge (existing ASC). The coaching row stays Coaching only (−19,800, no App split).
>
> Let me know if any test case needs more detail.
> Thanks

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

### What this resolves
Closes the "lesson-bundled CIP cooling-off / refund underspecified" gap. Confirms CIP (1029–1032) refunds are **per-charge**, mirroring the normal-charge design (REF-CIP-05): Lesson, Coaching Intensive, and App are independent charges, so refunds land on their own charges.

### Key rules (grounded in the answer)
| Refund type | Lesson charge | Coaching Intensive charge | App |
|---|---|---|---|
| Cooling-off (e.g. 90%) | negative on Lesson (existing ASC, untouched by CIP split) | negative on Coaching Intensive = (Coaching+App portion) × % | split from the Coaching Intensive negative by the existing rule |
| Consumption-tax exemption | negative on Lesson (14,850 − 13,500 = 1,350) | −6,900 | Coaching −6,538 / App −362 |
| Contract overlap (B2C/B2E → B2B) | Lesson refunded only | NO refund (same as today) | NO refund |
| Shareholder benefit | Lesson row → Lesson charge (existing ASC) | Coaching only, −19,800 | NO App split (per REF-CIP-07) |

- **The "75,900" in the cooling-off rule is the Coaching+App portion, NOT the full plan total** — identical for Solo (1028) and lesson-bundled (1029–1032). This is the key clarification.
- The Lesson portion is **always** handled by existing ASC on the Lesson charge — the CIP/allocation layer never touches it. Consistent with REF-CIP-05 (Lesson is a separate standalone-priced charge).
- Worked example (1029, 90%): Lesson −13,365, Coaching −64,728, App −3,582, total −81,675. (Arithmetic to re-verify when writing ASCI test cases.)

### Impact / where this lands
- **ASCI requirements (refund handling):** this is a core input. It confirms CIP refunds are per-charge and defines the per-type behavior — directly shapes the ASCI refund spec/section.
- **Still open (Lead/PM decision, from REF-CIP-07):** the *home* for CIP-refund handling — extend 02b (CAP refund) / new sub-spec / inside ASCI. This answer removes the last *specification* ambiguity but does not decide the home.
- Note: the App-split figures here (App weight 3,980 tax-incl, divisor 75,900) match REF-CIP-07's CIP fixed ratio, distinct from the CAP ratio.
