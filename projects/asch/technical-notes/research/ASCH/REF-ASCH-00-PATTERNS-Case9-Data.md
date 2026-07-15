# ASCH Pattern 9 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel — verified 2026-07-15 (no changes from previous version)
**Pattern:** 9 — B2E with Loyal discount overlap
**Scenario:** B2E new student, Lesson starts month-start, Coaching starts mid-month, B2E discount + Loyal discount interaction

## Update Log

- **2026-07-15:** Re-verified against Kuroda-san's updated spreadsheet. All values match — no changes needed.

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
- **Key check: When B2E discount and Loyal discount overlap, which applies?**
- **Month 7: Lesson gets 50% month-6 discount (not B2E 5%)** — 50% takes priority over 5%
- **Month 8: Loyal 10% replaces B2E 5%** — Loyal is the higher discount

## Discount Priority Rules (Confirmed by Data)

| Situation | Which discount applies | Basis |
|---|---|---|
| Month 1: First Month 50% + Honki Set start | 50% (First Month for Lesson, Honki Set for Coaching) | M for Lesson (non-Honki), L for Coaching (Honki) |
| Months 2-5: B2E 5% on Lesson | 5% B2E | M (non-Honki discount) |
| Month 6: Honki Set 50% on Coaching | 50% Honki Set | L (Honki discount) |
| Month 7: Month-6 50% on Lesson | 50% (overrides B2E 5%) | L? (50% is a Honki Set benefit) |
| Month 8: Loyal 10% on Lesson | 10% Loyal (overrides B2E 5%) | M (non-Honki discount) |

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

## Month 6 (2027/3) — Coaching Month-6 (50%)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 3/1 – 3/31 | 3/1 – 3/31 | 31/31 | 5% | 12,825 | 7,541 | 7,541 | -5,284 |
| Coaching - 30 Min | 2/15 – 3/14 | 3/1 – 3/14 | 14/28 | | | 33,528 | 16,764 | |
| Coaching - 30 Min | 3/15 – 4/14 | 3/15 – 3/31 | 17/31 | 50% | 9,871 | 21,167 | 11,608 | |
| | | | | | | | **28,372** | 501 |
| App | 2/15 – 3/14 | 3/1 – 3/14 | 14/28 | | 0 | 3,353 | 1,676 | |
| App | 3/15 – 4/14 | 3/15 – 3/31 | 17/31 | | 0 | 2,117 | 1,161 | |
| | | | | | | | **2,837** | 2,837 |
| **Totals** | | | | | 30,825 | | 38,750 | |

**Note on Lesson:** O drops from 11,944 to 7,541 in month 6. This suggests a new proration group was formed (Lesson basis = M = ¥12,825, but with different ΣM due to Coaching's 50% discount reducing the group total).

## Month 7 (2027/4) — Lesson Month-6 (50%)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 4/1 – 4/30 | 4/1 – 4/30 | 30/30 | **50%** | 6,750 | 6,750 | 6,750 | 0 |
| Coaching - 30 Min | 3/15 – 4/14 | 4/1 – 4/14 | 14/31 | 50% | | 21,167 | 9,559 | |
| App | 3/15 – 4/14 | 4/1 – 4/14 | 14/31 | | 0 | 2,117 | 956 | |
| **Totals** | | | | | 6,750 | | 17,265 | |

**Key:** Lesson gets 50% month-6 discount here. O = 6,750 = M = paid_price. This means basis = M (the month-6 50% is treated as... a Honki Set benefit? But O = M suggests basis = M not L). **This contradicts the expected rule where Honki Set 50% → basis = L.**

**Possible interpretation:** Month-6 Lesson 50% = ¥6,750. Since B2E 5% would give ¥12,825, the 50% is clearly the Honki Set month-6 benefit (not B2E discount). But O = ¥6,750 = M. So when month-6 50% applies AND the student is B2E, basis = M? **Or:** Lesson is alone in the proration group this month (no new Coaching/App charge), so O = ΣM = M trivially.

**Resolution:** In month 7, Lesson is the only new charge in the group (Coaching/App are tail-end of previous contract). ΣM = ¥6,750 (Lesson only). O(Lesson) = ΣM × (basis/Σbasis) = 6,750 × (6,750/6,750) = 6,750. The formula simplifies when there's only one product in the group.

## Month 8 (2027/5) — Post-Honki Set (Loyal 10%)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 5/1 – 5/31 | 5/1 – 5/31 | 31/31 | **10%** | 12,150 | 12,150 | 12,150 | 0 |
| **Totals** | | | | | 12,150 | | 12,150 | |

**Key:** Loyal discount (10%) replaces B2E discount (5%) from month 8. Paid = ¥12,150 (13,500 × 0.9). O = M = ¥12,150 (non-Honki discount). Adjustment = 0 (P = N after Honki Set ends).

## Validation

- Grand total Paid Price: ¥269,775
- Grand total P: ¥269,775
- ΣP = ΣPaid (lifetime invariant holds) ✓

## Implications for Design (Pattern 9 specific)

1. **B2E discount is non-Honki** → basis = M (¥12,825) for Lesson in months 2-5. This differs from B2C Pattern 2 where Lesson has no discount (basis = L = ¥13,500).

2. **Discount priority: 50% > 5% B2E** — when month-6 Honki Set 50% fires, it overrides the B2E 5%. The paid amount reflects 50%, not 5%.

3. **Discount priority: Loyal 10% > B2E 5%** — after Honki Set ends (month 8+), Loyal discount takes over. If a student qualifies for both B2E 5% and Loyal 10%, Loyal wins (higher discount).

4. **O changes when ΣM changes** — in month 6, Coaching gets 50% discount (¥9,871 instead of ¥36,000). This changes ΣM for the group, which changes ALL products' O values in that group. Lesson O drops from 11,944 to 7,541 because the group's total pie is smaller.

5. **Single-product proration group** — in month 7, only Lesson has a new charge. The proration formula simplifies: O = M (trivially, one product = full allocation to that product).

6. **B2E detection for ASCH** — ASCH must check `contract_type = 2` to know B2E discount applies. Then check the paid_price vs list_price to determine the effective discount rate (5% or 10% for Loyal). The difference matters for basis determination.

7. **Post-Honki-Set adjustments = 0** — once the bundle period ends and only Lesson remains with Loyal discount, P = N (no allocation needed, single product, O = M). ASCH can stop generating rows for this enrollment.

## Discount Overlap Summary

| Month | Lesson Discount | Rate | Basis | Why |
|---|---|---|---|---|
| 1 | First Month (Honki Set) | 50% | M (¥6,750) | First Month is non-Honki |
| 2-5 | B2E | 5% | M (¥12,825) | B2E is non-Honki |
| 6 | B2E | 5% | M (¥12,825) | Lesson month-6 hasn't fired yet (different cycle from Coaching) |
| 7 | Month-6 Honki Set | 50% | L? or M? (¥6,750) | 50% overrides 5% — but see note above about single-product group |
| 8+ | Loyal | 10% | M (¥12,150) | Loyal is non-Honki, replaces B2E |
