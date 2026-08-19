# ASCH Pattern 4 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel v3
**Pattern:** 4 — Plan change Daily 1 → Daily 2 mid-campaign
**Scenario:** B2C new student, Lesson started before campaign period, plan change occurs, Loyal discount applies

## Key Characteristics

- Lesson (Daily 1) starts on 9/28 — BEFORE campaign period
- Coaching 30-min starts on 10/3 — during campaign period
- App starts with Coaching on 10/3
- **Plan change: Lesson Daily 1 → Daily 2 on 12/10** (mid-month, mid-campaign)
- First Month 50% applies to Coaching ONLY (Lesson was already active)
- Month-6 discount applies to the plan ACTIVE at that time:
  - Coaching month-6 = 2027/3/3 charge (50% on Coaching)
  - Lesson month-6 = 2027/3/10 charge (50% on Daily 2 — NOT Daily 1)
- Loyal discount (5%) applies from month 7 onwards (on the new plan: Daily 2)

## Key Differences from Pattern 3

- Same as Pattern 3 UNTIL month 3 (2026/12) when plan change occurs
- After plan change: O is recalculated with Daily 2 pricing (¥19,500 instead of ¥13,500)
- New proration group formed for the Daily 2 charges
- Month-6 discount applies to Daily 2 (the active plan), not Daily 1

## Pre-Campaign Period (2026/9)

| Product | Contract | Period | Days | Paid Price | Notes |
|---|---|---|---|---|---|
| Lesson - Daily 1 | 9/28 – 10/27 | 9/28 – 9/30 | 3/30 | 13,500 | 1,350 consumed (regular daily rate) |

## Month 1 (2026/10) — Honki Set Starts

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 9/28 – 10/27 | 10/1 – 10/27 | 27/30 | | 13,500 | | 12,150 | |
| Lesson - Daily 1 | 10/28 – 11/27 | 10/28 – 10/31 | 4/31 | | 13,500 | 8,008 | 1,033 | |
| | | | | | | | **13,183** | -709 |
| Coaching - 30 Min | 10/3 – 11/2 | 10/3 – 10/31 | 29/31 | 50% | 18,000 | 21,356 | 19,978 | 3,139 |
| App | 10/3 – 11/2 | 10/3 – 10/31 | 29/31 | | 0 | 2,136 | 1,998 | 1,998 |
| **Totals** | | | | | 31,500 | | 35,159 | |

## Month 2 (2026/11)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 10/28 – 11/27 | 11/1 – 11/27 | 27/31 | | | 8,008 | 6,975 | |
| Lesson - Daily 1 | 11/28 – 12/27 | 11/28 – 11/30 | 3/30 | | 13,500 | 12,585 | 1,258 | |
| | | | | | | | **8,234** | -4,874 |
| Coaching - 30 Min | 10/3 – 11/2 | 11/1 – 11/2 | 2/31 | 50% | | 21,356 | 1,378 | |
| Coaching - 30 Min | 11/3 – 12/2 | 11/3 – 11/30 | 28/30 | | 36,000 | 33,559 | 31,322 | |
| | | | | | | | **32,700** | -2,061 |
| App | 10/3 – 11/2 | 11/1 – 11/2 | 2/31 | | 0 | 2,136 | 138 | |
| App | 11/3 – 12/2 | 11/3 – 11/30 | 28/30 | | 0 | 3,356 | 3,132 | |
| | | | | | | | **3,270** | 3,270 |
| **Totals** | | | | | 49,500 | | 44,203 | |

## Month 3 (2026/12) — PLAN CHANGE: Daily 1 → Daily 2 on 12/10

| Product | Contract | Period in Month | Days | Paid Price | O | P | Notes |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 11/28 – 12/9 | 12/1 – 12/9 | 9/29(?) | | 12,585 | 11,326 | Last Daily 1 charge (shortened to 12/9) |
| **Lesson - Daily 2** | 12/10 – 1/9 | 12/10 – 12/31 | 22/31 | 19,500(?) | **15,640** | 11,099 | NEW PLAN — new O calculated |
| Coaching - 30 Min | 11/3 – 12/2 | 12/1 – 12/2 | 2/30 | | 33,559 | 2,237 | |
| Coaching - 30 Min | 12/3 – 1/2 | 12/3 – 12/31 | 29/31 | 36,000 | 28,873 | 27,010 | |
| App | 11/3 – 12/2 | 12/1 – 12/2 | 2/30 | | 3,356 | 224 | |
| App | 12/3 – 1/2 | 12/3 – 12/31 | 29/31 | | 2,887 | 2,701 | |
| **Totals** | | | | 47,400(?) | | 54,598 | |

## Month 4 (2027/1)

| Product | Contract | Period in Month | Days | Paid Price | O | P |
|---|---|---|---|---|---|---|
| Lesson - Daily 2 | 12/10 – 1/9 | 1/1 – 1/9 | 9/31 | | 15,640 | 4,541 |
| Lesson - Daily 2 | 1/10 – 2/9 | 1/10 – 1/31 | 22/31 | 19,500 | 18,312 | 12,996 |
| Coaching - 30 Min | 12/3 – 1/2 | 1/1 – 1/2 | 2/31 | | 28,873 | 1,863 |
| Coaching - 30 Min | 1/3 – 2/2 | 1/3 – 1/31 | 29/31 | 36,000 | 33,807 | 31,626 |
| App | 12/3 – 1/2 | 1/1 – 1/2 | 2/31 | | 2,887 | 186 |
| App | 1/3 – 2/2 | 1/3 – 1/31 | 29/31 | | 3,381 | 3,163 |
| **Totals** | | | | 55,500 | | 54,374 |

## Month 5 (2027/2)

| Product | Contract | Period in Month | Days | Paid Price | O | P |
|---|---|---|---|---|---|---|
| Lesson - Daily 2 | 1/10 – 2/9 | 2/1 – 2/9 | 9/31 | | 18,312 | 5,316 |
| Lesson - Daily 2 | 2/10 – 3/9 | 2/10 – 2/28 | 19/28 | 19,500 | 18,312 | 12,426 |
| Coaching - 30 Min | 1/3 – 2/2 | 2/1 – 2/2 | 2/31 | | 33,807 | 2,181 |
| Coaching - 30 Min | 2/3 – 3/2 | 2/3 – 2/28 | 26/28 | 36,000 | 33,807 | 31,392 |
| App | 1/3 – 2/2 | 2/1 – 2/2 | 2/31 | | 3,381 | 218 |
| App | 2/3 – 3/2 | 2/3 – 2/28 | 26/28 | | 3,381 | 3,139 |
| **Totals** | | | | 55,500 | | 54,673 |

## Month 6 (2027/3) — 50% Discount Month

- Coaching month-6: counted from 10/3 → 6th charge starts 2027/3/3 → 50% on 3/3 – 4/2 charge
- Lesson month-6: counted from plan change (12/10)? → 6th Daily 2 charge starts 2027/3/10 → 50% on 3/10 – 4/9 charge (counted from the original start per product, not plan change date — **TBD confirm with Kuroda-san**)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 2 | 2/10 – 3/9 | 3/1 – 3/9 | 9/28 | | | 18,312 | 5,886 | |
| Lesson - Daily 2 | 3/10 – 4/9 | 3/10 – 3/31 | 22/31 | 50% | 9,750 | 9,156 | 6,498 | |
| | | | | | | | **12,384** | -803 |
| Coaching - 30 Min | 2/3 – 3/2 | 3/1 – 3/2 | 2/28 | | | 33,807 | 2,415 | |
| Coaching - 30 Min | 3/3 – 4/2 | 3/3 – 3/31 | 29/31 | 50% | 18,000 | 16,904 | 15,813 | |
| | | | | | | | **18,228** | -1,182 |
| App | 2/3 – 3/2 | 3/1 – 3/2 | 2/28 | | 0 | 3,381 | 241 | |
| App | 3/3 – 4/2 | 3/3 – 3/31 | 29/31 | | 0 | 1,690 | 1,581 | |
| | | | | | | | **1,823** | 1,823 |
| **Totals** | | | | 27,750 | | 32,435 | |

## Month 7 (2027/4) — Post-Honki Set (Loyal Discount)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 2 | 3/10 – 4/9 | 4/1 – 4/9 | 9/31 | 50% | | 9,156 | 2,658 | |
| Lesson - Daily 2 | 4/10 – 5/9 | 4/10 – 4/30 | 21/30 | 5% | 18,525 | 18,525 | 12,968 | |
| | | | | | | | **15,626** | -172 |
| Coaching - 30 Min | 3/3 – 4/2 | 4/1 – 4/2 | 2/31 | 50% | | 16,904 | 1,091 | |
| App | 3/3 – 4/2 | 4/1 – 4/2 | 2/31 | | 0 | 1,690 | 109 | |
| **Totals** | | | | 18,525 | | 16,825 | |

## Post-Campaign (2027/5)

| Product | Contract | Period | Days | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 2 | 4/10 – 5/9 | 5/1 – 5/9 | 9/30 | 5% | | 18,525 | 5,558 |

## Validation

- Grand total Paid Price: ¥299,175
- Grand total P: ¥299,175
- ΣP = ΣPaid (lifetime invariant holds) ✓

## Implications for Design (Pattern 4 specific)

1. **Plan change creates a new component revision** — Daily 1 → Daily 2. The bundle component table must track this with effective_from/effective_to dates and revision numbers.
2. **New O value after plan change** — Daily 2 charge (¥19,500) gets its own O calculation. The old Daily 1 O (¥8,008 / ¥12,585) does NOT carry into Daily 2 charges.
3. **New proration group after plan change** — the new plan's first charge starts a new group with new ΣM including the higher Lesson price.
4. **Month-6 discount applies to the ACTIVE plan** — 50% on Daily 2 (¥9,750), not on the old Daily 1 price. Confirmed by the data.
5. **Coaching month-6 vs Lesson month-6** — Coaching's 6th charge is 3/3, Lesson's equivalent (after plan change) is 3/10. Different dates within the same month. Both get 50% but on different contracts.
6. **O for Coaching/App also changes after plan change** — because ΣM changes when Lesson price changes (¥13,500 → ¥19,500), the entire group recalculates. Coaching O goes from 33,559 to 33,807 and App from 3,356 to 3,381.
7. **Loyal discount (month 7)** — applies to Daily 2 at 5% (¥18,525). Since it's a non-Honki discount, basis = M. O = M = ¥18,525 (no allocation needed — Lesson gets exactly what was paid).
