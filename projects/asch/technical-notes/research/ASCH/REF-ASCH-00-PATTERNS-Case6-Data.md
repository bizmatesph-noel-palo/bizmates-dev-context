# ASCH Pattern 6 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel v3
**Pattern:** 6 — Plan change Daily 1 → Monthly 15 mid-campaign
**Scenario:** B2C new student, Lesson started before campaign, plan changes from daily to ticket-based, Loyal discount applies

## Key Characteristics

- Lesson (Daily 1) starts on 9/28 — BEFORE campaign period
- Coaching 30-min starts on 10/3 — during campaign period
- App starts with Coaching on 10/3
- **Plan change: Lesson Daily 1 → Monthly 15 on 12/28** (mid-campaign)
- After plan change: **I/J switches from calendar days to ticket counts**
- Monthly-15 proration: P = O × (tickets_consumed / total_tickets)
- Monthly-15 P can **exceed list price** in a month when consumption is skewed (e.g., all 15 tickets used in one month)
- Month-6 50% discount applies to Monthly 15 plan (active plan at month-6)
- Loyal discount (5%) applies from month 7 onwards

## Critical Observation: P Exceeding List Price

In Month 5 (2027/2):
- Lesson Monthly-15 charge (1/28 – 2/27): O = ¥12,585, tickets consumed = 15/15 → P = ¥12,585
- Lesson Monthly-15 charge (2/28 – 3/27): O = ¥12,585, tickets consumed = 15/15(!) → P = ¥12,585
- Monthly total P for Lesson = ¥25,169 — **exceeds the ¥13,500 list price**

This is expected behavior per Kuroda-san's spec: "Monthly ΣP ≠ ΣM — expected for consumption skew, do NOT validate monthly totals."

## Pre-Campaign Period (2026/9)

| Product | Contract | Period | Days | Paid Price | Notes |
|---|---|---|---|---|---|
| Lesson - Daily 1 | 9/28 – 10/27 | 9/28 – 9/30 | 3/30 | 13,500 | 1,350 consumed (regular daily rate) |

## Month 1 (2026/10) — Honki Set Starts

Same as Pattern 3/4, Month 1.

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 9/28 – 10/27 | 10/1 – 10/27 | 27/30 | | 13,500 | | 12,150 | |
| Lesson - Daily 1 | 10/28 – 11/27 | 10/28 – 10/31 | 4/31 | | 13,500 | 8,008 | 1,033 | |
| | | | | | | | **13,183** | -709 |
| Coaching - 30 Min | 10/3 – 11/2 | 10/3 – 10/31 | 29/31 | 50% | 18,000 | 21,356 | 19,978 | 3,139 |
| App | 10/3 – 11/2 | 10/3 – 10/31 | 29/31 | | 0 | 2,136 | 1,998 | 1,998 |
| **Totals** | | | | | 31,500 | | 35,159 | |

## Month 2 (2026/11)

Same as Pattern 3/4, Month 2.

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

## Month 3 (2026/12) — PLAN CHANGE: Daily 1 → Monthly 15 on 12/28

| Product | Contract | Period in Month | I/J Type | Consumed | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 11/28 – 12/27 | 12/1 – 12/27 | days: 27/30 | | | 12,585 | 11,326 | |
| **Lesson - Monthly 15** | 12/28 – 1/27 | 12/28 – 12/31 | **tickets: 3/15** | 3 tickets | 13,500 | 12,585 | 2,517 | |
| | | | | | | | **13,843** | -1,007 |
| Coaching - 30 Min | 11/3 – 12/2 | 12/1 – 12/2 | days: 2/30 | | | 33,559 | 2,237 | |
| Coaching - 30 Min | 12/3 – 1/2 | 12/3 – 12/31 | days: 29/31 | | 36,000 | 33,559 | 31,394 | |
| | | | | | | | **33,631** | -2,446 |
| App | 11/3 – 12/2 | 12/1 – 12/2 | days: 2/30 | | 0 | 3,356 | 224 | |
| App | 12/3 – 1/2 | 12/3 – 12/31 | days: 29/31 | | 0 | 3,356 | 3,139 | |
| | | | | | | | **3,363** | 3,363 |
| **Totals** | | | | | 49,500 | | 50,838 | |

**Note:** Monthly-15 uses ticket counts for J/I: P = O × (3/15) = 12,585 × 0.2 = 2,517

## Month 4 (2027/1)

| Product | Contract | Period in Month | I/J Type | Consumed | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Monthly 15 | 12/28 – 1/27 | 1/1 – 1/27 | tickets: 12/15 | 12 tickets | | 12,585 | 10,068 | |
| Lesson - Monthly 15 | 1/28 – 2/27 | 1/28 – 1/31 | tickets: 0/15 | 0 tickets | 13,500 | 12,585 | 0 | |
| | | | | | | | **10,068** | -732 |
| Coaching - 30 Min | 12/3 – 1/2 | 1/1 – 1/2 | days: 2/31 | | | 33,559 | 2,165 | |
| Coaching - 30 Min | 1/3 – 2/2 | 1/3 – 1/31 | days: 29/31 | | 36,000 | 33,559 | 31,394 | |
| | | | | | | | **33,559** | -2,441 |
| App | 12/3 – 1/2 | 1/1 – 1/2 | days: 2/31 | | 0 | 3,356 | 217 | |
| App | 1/3 – 2/2 | 1/3 – 1/31 | days: 29/31 | | 0 | 3,356 | 3,139 | |
| | | | | | | | **3,356** | 3,356 |
| **Totals** | | | | | 49,500 | | 46,983 | |

**Note:** Lesson 1/28 – 2/27 has 0 tickets consumed in January → P = 0 for that period. All 15 tickets consumed later.

## Month 5 (2027/2) — Consumption Skew (P exceeds list price)

| Product | Contract | Period in Month | I/J Type | Consumed | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Monthly 15 | 1/28 – 2/27 | 2/1 – 2/27 | tickets: 15/15 | 15 tickets | | 12,585 | 12,585 | |
| Lesson - Monthly 15 | 2/28 – 3/27 | 2/28 – 2/28 | tickets: 15/15(!) | 15 tickets | 13,500 | 12,585 | 12,585 | |
| | | | | | | | **25,169** | -1,831 |
| Coaching - 30 Min | 1/3 – 2/2 | 2/1 – 2/2 | days: 2/31 | | | 33,559 | 2,165 | |
| Coaching - 30 Min | 2/3 – 3/2 | 2/3 – 2/28 | days: 26/28 | | 36,000 | 33,559 | 31,162 | |
| | | | | | | | **33,327** | -2,424 |
| App | 1/3 – 2/2 | 2/1 – 2/2 | days: 2/31 | | 0 | 3,356 | 217 | |
| App | 2/3 – 3/2 | 2/3 – 2/28 | days: 26/28 | | 0 | 3,356 | 3,116 | |
| | | | | | | | **3,333** | 3,333 |
| **Totals** | | | | | 62,751 | | 61,830 | |

**⚠️ Monthly Lesson P = ¥25,169 exceeds list price ¥13,500.** This is expected — all 15 tickets consumed in both contracts within February. The lifetime invariant ΣP = O still holds.

## Month 6 (2027/3) — 50% Discount Month (Zero Consumption)

| Product | Contract | Period in Month | I/J Type | Consumed | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|---|
| Lesson - Monthly 15 | 2/28 – 3/27 | 3/1 – 3/27 | tickets: 0/15 | 0 | | | 12,585 | 0 | |
| Lesson - Monthly 15 | 3/28 – 4/27 | 3/28 – 3/31 | tickets: 0/15 | 0 | 50% | 6,750 | 6,292 | 0 | |
| | | | | | | | | **0** | 0 |
| Coaching - 30 Min | 2/3 – 3/2 | 3/1 – 3/2 | days: 2/28 | | | | 33,559 | 2,397 | |
| Coaching - 30 Min | 3/3 – 4/2 | 3/3 – 3/31 | days: 29/31 | | 50% | 18,000 | 16,780 | 15,697 | |
| | | | | | | | | **18,094** | -1,316 |
| App | 2/3 – 3/2 | 3/1 – 3/2 | days: 2/28 | | | 0 | 3,356 | 240 | |
| App | 3/3 – 4/2 | 3/3 – 3/31 | days: 29/31 | | | 0 | 1,678 | 1,570 | |
| | | | | | | | | **1,809** | 1,809 |
| **Totals** | | | | | | 24,750 | | 19,904 | |

**Note:** Lesson P = 0 in March because 0 tickets consumed. Revenue deferred to when tickets are actually used.

## Month 7 (2027/4) — Post-Honki Set (Mixed)

| Product | Contract | Period in Month | I/J Type | Consumed | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|---|
| Lesson - Monthly 15 | 3/28 – 4/27 | 4/1 – 4/27 | tickets: 15/15 | 15 | 50% | | 6,292 | 6,292 | |
| Lesson - Monthly 15 | 4/28 – 5/27 | 4/28 – 4/30 | tickets: 10/15 | 10 | 5% | 12,825 | 12,825 | 8,550 | |
| | | | | | | | | **14,842** | -458 |
| Coaching - 30 Min | 3/3 – 4/2 | 4/1 – 4/2 | days: 2/31 | | 50% | | 16,780 | 1,083 | |
| App | 3/3 – 4/2 | 4/1 – 4/2 | days: 2/31 | | | 0 | 1,678 | 108 | |
| **Totals** | | | | | 12,825 | | 16,033 | |

## Post-Campaign (2027/5)

| Product | Contract | Period | I/J | Consumed | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|---|
| Lesson - Monthly 15 | 4/28 – 5/27 | 5/1 – 5/31 | tickets: 5/15 | 5 remaining | 5% | | 12,825 | 4,275 |

## Validation

- Grand total Paid Price: ¥280,575
- Grand total P: ¥280,575
- ΣP = ΣPaid (lifetime invariant holds) ✓

## Implications for Design (Pattern 6 specific)

1. **I/J type switches mid-enrollment** — Daily 1 uses calendar days (J=days_in_month, I=contract_days). Monthly 15 uses ticket counts (J=tickets_consumed, I=total_tickets=15). The system must know which formula to apply based on the product/plan type active for each charge.

2. **P can be 0 in a month** — If no tickets consumed (Month 6), P = O × (0/15) = 0. This is valid. Revenue is recognized when tickets are actually used, not when the contract is active.

3. **P can exceed list price in a single month** — If consumption is front-loaded (all 15 tickets used early), P for that month can exceed the charge's paid_price. The lifetime invariant (ΣP = O over all months) still holds. ASCH must NOT validate monthly P ≤ list_price.

4. **Monthly-15 J comes from existing ASC data** — `log_monthly_rate_calculation.number_of_lessons_taken + number_of_expired_lessons` = tickets consumed. ASCH reads this directly.

5. **O unchanged after plan change** — O for Monthly 15 = ¥12,585 (same as Daily 1 O was). The plan change doesn't recalculate O because the paid_price hasn't changed (¥13,500 for both Daily 1 and Monthly 15). O only changes when ΣM changes.

   **Wait — this contradicts Pattern 4** where Daily 1 → Daily 2 DID change O (because price changed ¥13,500 → ¥19,500). Here Daily 1 → Monthly 15 keeps same price (¥13,500) so O stays the same. The rule is: **O changes only if the new plan has a different paid_price.**

6. **N-value source switches** — Before plan change: N from `log_daily_rate_calculation`. After plan change: N from `log_monthly_rate_calculation`. ASCH must read from the correct source based on which plan was active during each period.
