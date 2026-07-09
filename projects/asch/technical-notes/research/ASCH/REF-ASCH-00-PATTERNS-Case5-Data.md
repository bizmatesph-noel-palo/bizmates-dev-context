# ASCH Pattern 5 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel v3
**Pattern:** 5 — Coaching rest (cancellation within 6 months)
**Scenario:** B2C new student, Coaching cancelled mid-campaign, App also removed

## Key Characteristics

- Lesson (Daily 1) starts on 10/1 (month-start)
- Coaching 30-min starts on 10/15 (mid-month)
- App starts with Coaching on 10/15
- **Coaching rest requested on 12/5** — student cancels Coaching within 6 months
- **App also stops** — when Coaching is cancelled, App membership is removed from the following month
- Months 1-2 are identical to Pattern 2
- **Month-6 50% discount is LOST** — cancelled mid-way, benefit forfeited permanently
- Proration only runs for 3 months (until Coaching/App end)

## Business Rules Confirmed

1. When Coaching is cancelled, App must also be cancelled (App follows Coaching lifecycle)
2. Month-6 discount is permanently lost — even re-subscribing doesn't restore it
3. After Coaching/App end, Lesson continues but is no longer part of the Honki Set bundle
4. Proration stops for the bundle when Coaching ends — Lesson reverts to normal (non-bundled) accounting

## Month 1 (2026/10) — Honki Set Starts

Same as Pattern 2, Month 1.

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 10/1 – 10/31 | 10/1 – 10/31 | 31/31 | 50% | 6,750 | 3,604 | 3,604 | -3,146 |
| Coaching - 30 Min | 10/15 – 11/14 | 10/15 – 10/31 | 17/31 | 50% | 9,871 | 19,223 | 10,542 | 671 |
| App | 10/15 – 11/14 | 10/15 – 10/31 | 17/31 | | 0 | 1,922 | 1,054 | 1,054 |
| **Totals** | | | | | 16,621 | 24,750 | 15,200 | |

## Month 2 (2026/11) — Normal Operation

Same as Pattern 2, Month 2. Months 3-5 would follow this same structure if no cancellation.

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 11/1 – 11/30 | 11/1 – 11/30 | 30/30 | | 13,500 | 12,585 | 12,585 | -915 |
| Coaching - 30 Min | 10/15 – 11/14 | 11/1 – 11/14 | 14/31 | 50% | | 19,223 | 8,681 | |
| Coaching - 30 Min | 11/15 – 12/14 | 11/15 – 11/30 | 16/30 | | 36,000 | 33,559 | 17,898 | |
| | | | | | | | **26,580** | -749 |
| App | 10/15 – 11/14 | 11/1 – 11/14 | 14/31 | | 0 | 1,922 | 868 | |
| App | 11/15 – 12/14 | 11/15 – 11/30 | 16/30 | | 0 | 3,356 | 1,790 | |
| | | | | | | | **2,658** | 2,658 |
| **Totals** | | | | | 40,829 | | 41,823 | |

## Month 3 (2026/12) — Coaching Rest Requested on 12/5

Coaching contract 11/15 – 12/14 continues its tail into December (until 12/14).
**After 12/14: no new Coaching charge is created.** Student enters REST for Coaching.
App also stops after 12/14.

Lesson continues as normal (non-bundled from next month onwards).

| Product | Contract | Period in Month | Days | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 12/1 – 12/31 | 12/1 – 12/31 | 31/31 | 13,500 | 13,500 | 13,500 | 0 |
| Coaching - 30 Min | 11/15 – 12/14 | 12/1 – 12/14 | 14/30 | | 33,559 | 15,661 | |
| App | 11/15 – 12/14 | 12/1 – 12/14 | 14/30 | | 3,356 | 1,566 | |
| **Totals** | | | | 13,500 | | 30,727 | |

**Note on Lesson in Month 3:** O = 13,500 and P = 13,500 (full month, no split). The adjustment is 0 because after Coaching ends, Lesson is no longer part of the bundle — it reverts to normal accounting where P = N = paid_price.

## Summary — Total Proration Period

| Month | Lesson P | Coaching P | App P | Total P |
|---|---|---|---|---|
| 1 (Oct) | 3,604 | 10,542 | 1,054 | 15,200 |
| 2 (Nov) | 12,585 | 26,580 | 2,658 | 41,823 |
| 3 (Dec) | 13,500 | 15,661 | 1,566 | 30,727 |
| **Total** | **29,689** | **52,783** | **5,278** | **87,750** |

## Validation

- Grand total Paid Price across proration period: ¥87,750
- Grand total P across proration period: ¥87,750
- ΣP = ΣPaid (lifetime invariant holds) ✓

## Implications for Design (Pattern 5 specific)

1. **Coaching cancellation triggers end of bundle** — when Coaching enters REST, ASCH must detect this and stop proration for all three products.
2. **App follows Coaching lifecycle** — App removal is mandatory when Coaching is cancelled. ASCH needs to know the App's fate depends on Coaching's status.
3. **Lesson reverts to non-bundled** — after Coaching cancellation, Lesson's P = N (adjustment = 0). ASCH stops generating proration rows for Lesson from the next month.
4. **Month-6 discount permanently lost** — no need to track future discount eligibility after cancellation. The enrollment is effectively closed.
5. **Partial-month final Coaching/App** — the last Coaching/App contract still gets prorated for its remaining days (12/1 – 12/14 in this case). O carries over from the previous group for this tail period.
6. **Detection mechanism** — ASCH needs to detect that no new Coaching charge was created after the current one ends. This signals the bundle has ended. Check `trn_student_rest_history` or absence of next-period Coaching charge.
7. **Enrollment status** — `asch_bundle_enrollments` should have a status field (active/terminated) and a termination_date. Set when Coaching cancellation is detected.
