# REF-CAP-09 — CAP / CIP Refund Allocation Requirements (Kuroda-san, 2026-09-08)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-09-08 (Received) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative source for CAP/CIP refund allocation |
| **Audience** | Dev team (ASCA/ASCI), Accounting |
| **Companion** | `ASC_ALLOC_CAP_CIP_CASE_LIST_EN.xlsx` (illustrative worked cases) |

> ⚠️ **Verbatim source document.** This is Kuroda-san's requirement as delivered, preserved in full. Our interpretation/impact analysis lives separately in `projects/asca/` — do not edit this content; it is the source of truth.

---

## CAP / CIP Refund Allocation Requirements

By Hayato Kuroda
Date: 2026-09-08
Scope: CAP (Coaching + auto-bundled App) and CIP (Coaching Intensive) refund allocation

This document defines the refund behaviour required of the CAP/CIP allocation layer. It is read together with ASC_ALLOC_CAP_CIP_CASE_LIST_EN.xlsx, which supplies the worked numerical cases. The spreadsheet is illustrative; these requirements are normative.

### 1. Scope and non-goals

The allocation layer SHALL process every CAP/CIP bundle charge selected by the existing ASC monthly flow, including negative refund charges.

The allocation layer SHALL split an in-scope amount between Coaching and the auto-bundled App. It SHALL NOT change how existing ASC determines whether, or when, a charge is recognized.

Existing real-sales App charges are out of scope. In particular, a paid B2B standalone/store App charge SHALL remain on the existing ASC path and SHALL NOT be included in the bundled-App allocation.

Lesson-included CIP plans (plan IDs 1029–1032) use three-way allocation (Lesson / Coaching / App), decided 2026-09-08 — see R-16 and section 10.

CAP/CIP allocation / refund samples
CAP/CIP Calc samples

### 2. Definitions

| Term | Definition |
|---|---|
| N | Amount that existing ASC recognizes for one in-scope charge in the target month. N is negative for a refund charge. |
| L_coaching, L_app | Tax-exclusive list prices used solely as allocation weights. |
| Execution month | The calendar month containing the refund charge's paid_at date. |
| Fixed/capped refund | A full refund, cooling-off refund, consumption-tax exemption, or shareholder-benefit cashback. Its amount is fixed or capped before allocation. |
| Overlap refund | A refund whose amount is calculated from the days of overlap when a B2C (or B2E) contract and a B2B contract cover the same period. |
| Auto-bundled App | The zero-settlement-price App component bundled with CAP or CIP. |

### 3. Common allocation rules

**R-01 — Same algorithm for positive and negative amounts**

The system SHALL use the same allocation algorithm for normal and refund charges. A refund MUST NOT use a separate allocation formula or a separate allocation pipeline.

For a two-product bundle, the system SHALL calculate:

```
P_app       = floor(N × L_app / (L_coaching + L_app))
P_coaching  = N − P_app
```

The App amount SHALL be rounded with a mathematical floor operation. The Coaching amount SHALL absorb the residual so that P_app + P_coaching = N exactly in integer yen.

For negative values, floor SHALL mean a true floor toward negative infinity. For example, floor(-3.2) = -4. The implementation MUST NOT truncate toward zero using intval() or an integer cast.

Allocation SHALL be performed per charge. When more than one charge exists in the same month, each charge SHALL use its own product price and result; monthly totals are the sum of those charge-level results.

**R-02 — Allocation weights**

The auto-bundled App charge amount SHALL be zero. Its list price is an allocation weight only and MUST NOT be treated as paid revenue.

CAP detection SHALL use the auto-bundled App product. CIP detection SHALL use a CIP plan (1028–1032) or the dedicated Coaching Intensive product, subject to the open lesson-plan decision in section 10.

**R-03 — Recognition month**

The allocation layer SHALL allocate the amount already recognized by existing ASC in the target month.

A negative refund charge SHALL be recognized in its execution month as one negative amount. It SHALL NOT be day-prorated by the allocation layer and SHALL NOT be spread back to the original contract months.

The contract may have started mid-month; this does not change the execution-month rule for fixed/capped refunds.

### 4. Refund amount determination

**R-04 — Fixed and capped refunds**

Full refunds, full cooling-off refunds, cooling-off 10% refunds, consumption-tax exemptions, and shareholder-benefit cashbacks SHALL use the negative charge amount delivered by the existing refund process.

The allocation layer SHALL NOT calculate a further day-proration for those fixed/capped amounts.

A cooling-off 10% refund SHALL be represented as a negative amount equal to 10% of the applicable paid amount.

A consumption-tax-exemption refund SHALL be represented as a negative amount equal to the amount created by the existing Admin Refund flow. The currently expected calculation is paid amount including tax × 10 / 110; confirmation of the controller path and calculation remains required.

**R-05 — Contract-overlap refunds**

When a B2C (or B2E) contract and a B2B contract cover the same period (B2C/B2E → B2B), the individual contract charge SHALL continue to be recognized in full for the month by existing ASC. The overlap refund is a separate negative charge, not a reduction of that recognition.

The refund amount SHALL be determined from the overlapping days under the existing prorated-refund flow.

Both the full positive charge and the negative refund charge SHALL be allocated independently using R-01 in their respective months; the bundle's net for the month is their sum.

The allocation layer SHALL NOT re-prorate the negative charge after receiving it. The distinction is that overlap days determine the refund amount, while the recognized negative amount is posted in the execution month.

### 5. Required refund scenarios

| ID | Scenario | Requirement |
|---|---|---|
| R-06 | Full refund / full cooling-off | Allocate the full negative amount with R-01 in the execution month. |
| R-07 | Later-month / cross-month execution | Post the whole negative as one lump in the execution month and allocate it there with R-01 (Coaching / App split still applies). Do not split the negative back into the months where the original revenue was recognized, even when the original charge spanned several months. The month-by-month distribution differs from the ASCH "prorate with the original ratio" behaviour; the contract-lifetime total is unchanged. |
| R-08 | Cooling-off 10% | Allocate the negative 10% refund with R-01. |
| R-09 | Consumption-tax exemption | Allocate the negative tax-exemption refund with R-01; do not day-prorate it. |
| R-10 | Shareholder-benefit cashback | Process the cloned negative Coaching charge with R-01. |
| R-11 | Contract overlap | Allocate the negative, overlap-prorated charge with R-01 in the execution month. |
| R-12 | Mid-month plan change | Allocate each charge independently. A single monthly allocation ratio is prohibited. |
| R-13 | Contract-type change | Keep allocation amounts unchanged; ensure the reporting/summary key includes the applicable contract type so the correct Freee partner and department are used. |

### 6. Shareholder-benefit cashback

**R-14 — Source and eligibility**

The shareholder-benefit bulk CSV process creates a negative trn_charge cloned from the original charge. The allocation layer SHALL consume that negative charge directly and SHALL NOT parse the CSV as an allocation input. CSV upload page: https://dev05.dev.bizmates.jp/MyBizmates/admin/shareholderrefund/index U can visit from this page.

Only the Bizmates Coaching shareholder-benefit line is in scope for CAP/CIP allocation. The bundled App has a zero charge amount and does not create a separate shareholder-benefit App refund line.

The Coaching cashback amount is capped at ¥19,800 under the current business rule.

**R-15 — Split CSV transactions**

A single transaction_id may occur in multiple CSV rows because it contains separate lesson and Coaching portions.

The system SHALL resolve each CSV row to its own original charge. It MUST NOT sum rows solely because they share a transaction_id.

Only the Coaching portion SHALL enter CAP/CIP allocation. The lesson portion SHALL remain on the existing ASC path.

**R-16 — Lesson-included CIP plans (1029–1032)**

For a lesson-included CIP plan, the allocation SHALL be three-way: Lesson, Coaching, and App.

The system SHALL split the amount recognized by existing ASC for the plan in the target month by the tax-exclusive unit-price weights: Lesson 13,500, Coaching 66,500, App 3,618.

P_app and P_lesson SHALL be rounded with floor; P_coaching SHALL absorb the residual so that P_lesson + P_coaching + P_app = N exactly.

This applies to normal months and to refund months (a refund makes N negative; the three-way split is unchanged).

### 7. Processing and integrity requirements

Negative refund charges SHALL enter the same allocation entry point as positive charges, distinguished by the record kind or equivalent explicit attribute.

The system SHALL write the Coaching and App allocation results as one atomic unit. It MUST NOT leave one side updated when the other side fails.

A failed allocation SHALL not block unrelated CAP/CIP records from being processed, but the failed charge pair SHALL be reported and retriable.

The output/audit record SHALL retain the target month, charge identifier, product identifier, contract type where available, original recognized amount N, applied weights, and the allocated values (P_app, P_coaching, and P_lesson for lesson-included plans).

### 8. Acceptance criteria

For every two-product bundle, P_app + P_coaching equals N exactly.

A negative amount with a fractional App allocation demonstrates true floor behaviour; for example, CIP full refund N = -75,900 produces P_app = -3,917 and P_coaching = -71,983.

Fixed/capped refunds produce their full negative amount in the execution month even when the contract began mid-month, and that negative is still split into Coaching and App in the execution month.

For a cross-month cooling-off (original charge spans two months, refund executed in a later month), the whole negative is posted once in the execution month — not split back across the recognition months — and the contract-lifetime net equals the retained amount. Example: 90% refund of a 22,550 payment → contract-lifetime net ≈ 2,254 (≈ 10%), even though one month shows a net negative.

The CIP overlap example recognizes a -75,900 negative charge over 16 of 30 days as N = -40,480, then allocates it to App -2,089 and Coaching -38,391.

A month containing two plan-change charges produces the same result as allocating each charge separately; it does not use one combined monthly ratio.

A split shareholder CSV transaction allocates the Coaching row only and does not aggregate the lesson row.

A paid standalone/store App charge is excluded from CAP/CIP bundled allocation.

A lesson-included CIP plan splits N three ways so that P_lesson + P_coaching + P_app = N exactly.

### 9. Reference implementation behaviour

The existing ASC refund path is the source of the execution-month negative charge. In particular, the current CommonUtil::getContractDateInfoList() negative-price branch recognizes negative charges in the paid_at month without day-proration. The allocation layer depends on that behaviour and adds only the Coaching/App split.

### 10. Decisions and open items

**Decided**

- Lesson-included CIP plans (1029–1032): Plan A (three-way Lesson / Coaching / App allocation). Plans that include lessons SHALL have the lesson amount included in the allocation, split by unit-price weight (Lesson : Coaching : App = 13,500 : 66,500 : 3,618, tax-exclusive). Plan B (lesson left on existing ASC) is not adopted.
- Individual-to-corporate (B2C/B2E → B2B) contract overlap refund: the refund amount is prorated by the overlapping days (same as the Honki-Set treatment). The negative charge is then recognized as a lump in the execution month.
- Shareholder-benefit cashback applies to CAP / CIP. Only the "Bizmates Coaching" benefit line is in scope; the coaching cashback cap is ¥19,800 for now (see open item below).
- Cross-month cooling-off / later-month refund: keep the "lump in the execution month" behaviour (R-07). Accounting has signed off. The negative is still allocated Coaching / App in the execution month; it is not split back into the original recognition months, so the ASCH "prorate with the original ratio" cross-month rule is not adopted. The month-by-month figures differ from ASCH, but the contract-lifetime total is the same and equals the retained amount (e.g. a 90% refund leaves ≈ 10% of the paid amount recognized). Existing ASC keeping the original positive charge alive after the refund is what makes the total reconcile; this is accepted as non-blocking (see open item 2).

**Open**

- Shareholder-benefit caps for CAP / CIP: new CAP/CIP-specific cap amounts are under executive discussion. Until decided, proceed with the existing ¥19,800 coaching cap. To be confirmed by @Hayato Kuroda
- Post-refund recognition of the original positive charge (non-blocking): the samples assume existing ASC keeps recognizing the original positive charge's remaining days after a cooling-off refund (so the refund-month net negative self-corrects in later months and the contract total equals the retained amount). Accounting has accepted proceeding on this basis. Engineering to confirm existing ASC does not truncate the positive charge on cooling-off. Owner: Engineering / Miyaji-san.

(The former "double-App termination" / CAP F-15 item is dropped: the auto-bundled App cannot be terminated independently of the Coaching contract, so the scenario does not occur.)
