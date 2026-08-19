# ASCH Pattern 9 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel — updated 2026-08-01 (calendar-month trigger correction + Loyal 10% from month 7)
**Pattern:** 9 — B2E with Loyal discount overlap
**Scenario:** B2E new student, Lesson starts month-start, Coaching starts mid-month, B2E discount + Loyal discount interaction

## Update Log

- **2026-07-15:** Re-verified against Kuroda-san's updated spreadsheet. All values match — no changes needed.
- **2026-08-01:** Major update — REF-06 §1 calendar-month trigger applied. Month-6 50% on Lesson moved from month 7 to month 6 (same month as Coaching C6). Month 7 now gets Loyal 10% (7th continuous contract). Month 8 continues with Loyal 10%.

## Key Characteristics

- **Contract type: B2E** (contract_type = 2)
- Lesson (Daily 1) starts on 10/1 (month-start)
- Coaching 30-min starts on 10/15 (mid-month)
- App starts with Coaching on 10/15
- **B2E discount (5%)** applies to Lesson from month 2 onwards (non-Honki discount → basis = M)
- **Loyal discount (10%)** applies from month 8 (after Honki Set period ends)
- First Month 50% on Lesson (month 1) — same as Pattern 2
- Honki Set 50% on Coaching (month 1)
- Month-6 50% on both Lesson and Coaching
- **Month-6 50% on both Lesson and Coaching** — fires in same calendar month as Coaching C6 (REF-06 §1)
- **Key check: When B2E discount and Loyal discount overlap, which applies?**
- **Month 6: Lesson gets 50% Honki Set month-6 discount** — overrides B2E 5% (calendar-month trigger)
- **Month 7: Lesson gets 10% Loyal discount (5% B2E + 5% Loyal = 10%)** — 7th continuous contract
- **Month 8: Loyal 10% continues** — same as month 7

## Discount Priority Rules (Confirmed by Data — updated 2026-08-01)

| Situation | Which discount applies | Basis |
|---|---|---|
| Month 1: First Month 50% + Honki Set start | 50% (First Month for Lesson, Honki Set for Coaching) | M for Lesson (non-Honki), L for Coaching (Honki) |
| Months 2-5: B2E 5% on Lesson | 5% B2E | M (non-Honki discount) |
| Month 6: Honki Set 50% on Lesson AND Coaching | 50% (overrides B2E 5% — calendar-month trigger) | L (Honki discount) |
| Month 7: Loyal 10% on Lesson (7th continuous contract) | 10% Loyal (5% B2E + 5% Loyal) | M (non-Honki discount) |
| Month 8+: Loyal 10% continues | 10% Loyal | M (non-Honki discount) |

## Month 1 (2026/10) — Honki Set Starts

Same structure as Pattern 2, Month 1. Identical O values.

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 10/1 – 10/31 | 10/1 – 10/31 | 31/31 | 50% | 6,750 | 3,604 | 3,604 | -3,146 |
| Coaching - 30 Min | 10/15 – 11/14 | 10/15 – 10/31 | 17/31 | 50% | 9,871 | 19,223 | 10,542 | 671 |
| App | 10/15 – 11/14 | 10/15 – 10/31 | 17/31 | | 0 | 1,922 | 1,054 | 1,054 |
| **Totals** | | | | | 16,621 | 24,750 | 15,200 | |

## Month 2 (2026/11) — B2E 5% on Lesson

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 11/1 – 11/30 | 11/1 – 11/30 | 30/30 | 5% | 12,825 | 11,944 | 11,944 | -881 |
| Coaching - 30 Min | 10/15 – 11/14 | 11/1 – 11/14 | 14/31 | 50% | | 19,223 | 8,681 | |
| Coaching - 30 Min | 11/15 – 12/14 | 11/15 – 11/30 | 16/30 | | 36,000 | 33,528 | 17,882 | |
| | | | | | | | **26,563** | -766 |
| App | 10/15 – 11/14 | 11/1 – 11/14 | 14/31 | | 0 | 1,922 | 868 | |
| App | 11/15 – 12/14 | 11/15 – 11/30 | 16/30 | | 0 | 3,353 | 1,788 | |
| | | | | | | | **2,656** | 2,656 |
| **Totals** | | | | | 48,825 | | 41,164 | |

**Note:** Lesson O = 11,944 (basis = M = ¥12,825, B2E 5% discount = non-Honki). Different from Pattern 2 where B2C Lesson O = 12,585 (basis = L = ¥13,500, no discount).

## Month 3 (2026/12)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 12/1 – 12/31 | 12/1 – 12/31 | 31/31 | 5% | 12,825 | 11,944 | 11,944 |
| Coaching - 30 Min | 11/15 – 12/14 | 12/1 – 12/14 | 14/30 | | | 33,528 | 15,646 |
| Coaching - 30 Min | 12/15 – 1/14 | 12/15 – 12/31 | 17/31 | | 36,000 | 33,528 | 18,386 |
| App | 11/15 – 12/14 | 12/1 – 12/14 | 14/30 | | 0 | 3,353 | 1,565 |
| App | 12/15 – 1/14 | 12/15 – 12/31 | 17/31 | | 0 | 3,353 | 1,839 |
| **Totals** | | | | | 48,825 | | 49,380 |

## Month 4 (2027/1)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 1/1 – 1/31 | 1/1 – 1/31 | 31/31 | 5% | 12,825 | 11,944 | 11,944 |
| Coaching - 30 Min | 12/15 – 1/14 | 1/1 – 1/14 | 14/31 | | | 33,528 | 15,142 |
| Coaching - 30 Min | 1/15 – 2/14 | 1/15 – 1/31 | 17/31 | | 36,000 | 33,528 | 18,386 |
| App | 12/15 – 1/14 | 1/1 – 1/14 | 14/31 | | 0 | 3,353 | 1,514 |
| App | 1/15 – 2/14 | 1/15 – 1/31 | 17/31 | | 0 | 3,353 | 1,839 |
| **Totals** | | | | | 48,825 | | 48,825 |

## Month 5 (2027/2)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 2/1 – 2/28 | 2/1 – 2/28 | 28/28 | 5% | 12,825 | 11,944 | 11,944 |
| Coaching - 30 Min | 1/15 – 2/14 | 2/1 – 2/14 | 14/31 | | | 33,528 | 15,142 |
| Coaching - 30 Min | 2/15 – 3/14 | 2/15 – 2/28 | 14/28 | | 36,000 | 33,528 | 16,764 |
| App | 1/15 – 2/14 | 2/1 – 2/14 | 14/31 | | 0 | 3,353 | 1,514 |
| App | 2/15 – 3/14 | 2/15 – 2/28 | 14/28 | | 0 | 3,353 | 1,676 |
| **Totals** | | | | | 48,825 | | 47,040 |

## Month 6 (2027/3) — Coaching C6 AND Lesson Month-6 (Calendar-Month Trigger)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 3/1 – 3/31 | 3/1 – 3/31 | 31/31 | **50%** | 6,750 | 3,604 | 3,604 | -3,146 |
| Coaching - 30 Min | 2/15 – 3/14 | 3/1 – 3/14 | 14/28 | | | 33,528 | 16,764 | |
| Coaching - 30 Min | 3/15 – 4/14 | 3/15 – 3/31 | 17/31 | 50% | 9,871 | 19,223 | 10,542 | |
| | | | | | | | **27,306** | -565 |
| App | 2/15 – 3/14 | 3/1 – 3/14 | 14/28 | | 0 | 3,353 | 1,676 | |
| App | 3/15 – 4/14 | 3/15 – 3/31 | 17/31 | | 0 | 1,922 | 1,054 | |
| | | | | | | | **2,731** | 2,731 |
| **Totals** | | | | | 24,750 | | 33,641 | |

**Key change (REF-06 §1):** Lesson now gets 50% in month 6 (same month as Coaching C6) instead of month 7. Calendar-month trigger — both discounts fire in the same accounting period regardless of payment date order within the month.

## Month 7 (2027/4) — Loyal 10% (7th Continuous Contract)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 4/1 – 4/30 | 4/1 – 4/30 | 30/30 | **10%** | 12,150 | 12,150 | 12,150 | 0 |
| Coaching - 30 Min | 3/15 – 4/14 | 4/1 – 4/14 | 14/31 | 50% | | 19,223 | 8,681 | |
| App | 3/15 – 4/14 | 4/1 – 4/14 | 14/31 | | 0 | 1,922 | 868 | |
| **Totals** | | | | | 12,150 | | 21,700 | |

**Key change (REF-06 §1):** Lesson no longer gets 50% here. Month-6 discount already fired in month 6 (calendar-month trigger). Month 7 = 7th continuous contract → Loyal benefit kicks in (5% B2E + 5% Loyal = 10%). O = M = ¥12,150 (non-Honki discount). Adjustment = 0 (P = N — single product in group).

## Month 8 (2027/5) — Loyal 10% Continues

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 5/1 – 5/31 | 5/1 – 5/31 | 31/31 | **10%** | 12,150 | 12,150 | 12,150 | 0 |
| **Totals** | | | | | 12,150 | | 12,150 | |

**Key:** Loyal 10% persists. Only Lesson remains (Coaching/App contracts ended). O = M = ¥12,150. Adjustment = 0 (P = N — ASCH can stop generating rows for this enrollment after Honki Set period expires and all products are standalone).

## Validation

- Grand total Paid Price: ¥269,100
- Grand total P: ¥269,100
- ΣP = ΣPaid (lifetime invariant holds) ✓

## Implications for Design (Pattern 9 specific — updated 2026-08-01)

1. **B2E discount is non-Honki** → basis = M (¥12,825) for Lesson in months 2-5. This differs from B2C Pattern 2 where Lesson has no discount (basis = L = ¥13,500).

2. **Calendar-month trigger (REF-06 §1):** Month-6 50% fires on Lesson in month 6 (same calendar month as Coaching C6). No sequence-based split between Pattern 2 and Pattern 9 — both apply the discount in month 6.

3. **Discount priority: 50% > 5% B2E** — when month-6 Honki Set 50% fires in month 6, it overrides the B2E 5%. The paid amount reflects 50%, not 5%.

4. **Loyal discount from 7th continuous contract:** After Honki Set month-6 discount fires, the very next Lesson payment (month 7) gets Loyal 10% (5% B2E + 5% Loyal = 10%). This is NOT 50% — the Honki Set benefit has been fully consumed.

5. **O changes when ΣM changes** — in month 6, both Lesson AND Coaching get 50% discount. This changes ΣM for the group. All products' O values in that group reflect the lower paid amounts.

6. **Post-Honki-Set adjustments = 0** — once the bundle period ends and only Lesson remains with Loyal discount, P = N (no allocation needed, single product, O = M). ASCH can stop generating rows for this enrollment.

7. **B2E detection for ASCH** — ASCH must check `contract_type = 2` to know B2E discount applies. The Loyal 10% is detected via `log_loyal_benefits_charge` (non-Honki discount → basis = M).

## Discount Overlap Summary (Updated 2026-08-01)

| Month | Lesson Discount | Rate | Basis | Why |
|---|---|---|---|---|
| 1 | First Month (non-Honki) | 50% | M (¥6,750) | First Month is non-Honki |
| 2-5 | B2E | 5% | M (¥12,825) | B2E is non-Honki |
| 6 | Month-6 Honki Set | 50% | L (¥6,750 = 50% of ¥13,500) | Calendar-month trigger — same month as Coaching C6. Overrides B2E 5%. |
| 7 | Loyal (5% B2E + 5% Loyal) | 10% | M (¥12,150) | 7th continuous contract. Non-Honki discount. |
| 8+ | Loyal | 10% | M (¥12,150) | Loyal persists after Honki Set period ends |
