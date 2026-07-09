# ASCH Pattern 2 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel v3
**Pattern:** 2 — Different start dates (Lesson month-start, Coaching mid-month)
**Scenario:** B2C new student, Loyal discount applies

## Key Characteristics

- Lesson (Daily 1) starts on 10/1 (month-start)
- Coaching 30-min starts on 10/15 (mid-month)
- App starts with Coaching on 10/15
- Different I/J periods per product due to staggered starts
- Loyal discount (5%) applies from month 7 onwards
- First Month 50% discount on Lesson in month 1
- Honki Set 50% discount on Coaching in month 1
- Month-6 50% discount applies to both Lesson and Coaching

## Data Table

| Accounting Period | Product | Contract Start | Contract End | Period Start | Period End | Contract Days | Days in Period | Discount | Sales Price | Gross Amount | Paid Price | O (Allocated) | P (Prorated) | P (Cumulative) | Adjustment (P−N) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Month 1 (2026/10)** | | | | | | | | | | | | | | | |
| | Lesson - Daily 1 | 2026/10/1 | 2026/10/31 | 2026/10/1 | 2026/10/31 | 31 | 31 | 50% | 13,500 | 6,750 | 6,750 | 3,604 | 3,604 | 3,604 | -3,146 |
| | Coaching - 30 Min | 2026/10/15 | 2026/11/14 | 2026/10/15 | 2026/10/31 | 31 | 17 | 50% | 36,000 | 18,000 | 9,871 | 19,223 | 10,542 | 10,542 | 671 |
| | App | 2026/10/15 | 2026/11/14 | 2026/10/15 | 2026/10/31 | 31 | 17 | | 3,600 | 0 | 0 | 1,922 | 1,054 | 1,054 | 1,054 |
| | **Totals** | | | | | | | | 53,100 | 24,750 | 16,621 | 24,750 | 15,200 | | |
| **Month 2 (2026/11)** | | | | | | | | | | | | | | | |
| | Lesson - Daily 1 | 2026/11/1 | 2026/11/30 | 2026/11/1 | 2026/11/30 | 30 | 30 | | 13,500 | 13,500 | 13,500 | 12,585 | 12,585 | 12,585 | -915 |
| | Coaching - 30 Min | 2026/10/15 | 2026/11/14 | 2026/11/1 | 2026/11/14 | 31 | 14 | 50% | 36,000 | | | 19,223 | 8,681 | | |
| | Coaching - 30 Min | 2026/11/15 | 2026/12/14 | 2026/11/15 | 2026/11/30 | 30 | 16 | | 36,000 | 36,000 | 19,200 | 33,559 | 17,898 | 26,580 | -749 |
| | App | 2026/10/15 | 2026/11/14 | 2026/11/1 | 2026/11/14 | 31 | 14 | | 3,600 | 0 | 0 | 1,922 | 868 | | |
| | App | 2026/11/15 | 2026/12/14 | 2026/11/15 | 2026/11/30 | 30 | 16 | | 3,600 | 0 | 0 | 3,356 | 1,790 | 2,658 | 2,658 |
| | **Totals** | | | | | | | | | 49,500 | | | 41,823 | | |
| **Month 3 (2026/12)** | | | | | | | | | | | | | | | |
| | Lesson - Daily 1 | 2026/12/1 | 2026/12/31 | 2026/12/1 | 2026/12/31 | 31 | 31 | | 13,500 | 13,500 | 13,500 | 12,585 | 12,585 | 12,585 | -915 |
| | Coaching - 30 Min | 2026/11/15 | 2026/12/14 | 2026/12/1 | 2026/12/14 | 30 | 14 | | 36,000 | 16,800 | | 33,559 | 15,661 | | |
| | Coaching - 30 Min | 2026/12/15 | 2027/1/14 | 2026/12/15 | 2026/12/31 | 31 | 17 | | 36,000 | 36,000 | 19,742 | 33,559 | 18,403 | 34,065 | -2,477 |
| | App | 2026/11/15 | 2026/12/14 | 2026/12/1 | 2026/12/14 | 30 | 14 | | 3,600 | 0 | 0 | 3,356 | 1,566 | | |
| | App | 2026/12/15 | 2027/1/14 | 2026/12/15 | 2026/12/31 | 31 | 17 | | 3,600 | 0 | 0 | 3,356 | 1,840 | 3,406 | 3,406 |
| | **Totals** | | | | | | | | | 49,500 | | | 50,056 | | |
| **Month 4 (2027/1)** | | | | | | | | | | | | | | | |
| | Lesson - Daily 1 | 2027/1/1 | 2027/1/31 | 2027/1/1 | 2027/1/31 | 31 | 31 | | 13,500 | 13,500 | 13,500 | 12,585 | 12,585 | 12,585 | -915 |
| | Coaching - 30 Min | 2026/12/15 | 2027/1/14 | 2027/1/1 | 2027/1/14 | 31 | 14 | | 36,000 | 16,258 | | 33,559 | 15,156 | | |
| | Coaching - 30 Min | 2027/1/15 | 2027/2/14 | 2027/1/15 | 2027/1/31 | 31 | 17 | | 36,000 | 36,000 | 19,742 | 33,559 | 18,403 | 33,559 | -2,441 |
| | App | 2026/12/15 | 2027/1/14 | 2027/1/1 | 2027/1/14 | 31 | 14 | | 3,600 | 0 | 0 | 3,356 | 1,516 | | |
| | App | 2027/1/15 | 2027/2/14 | 2027/1/15 | 2027/1/31 | 31 | 17 | | 3,600 | 0 | 0 | 3,356 | 1,840 | 3,356 | 3,356 |
| | **Totals** | | | | | | | | | 49,500 | | | 49,500 | | |
| **Month 5 (2027/2)** | | | | | | | | | | | | | | | |
| | Lesson - Daily 1 | 2027/2/1 | 2027/2/28 | 2027/2/1 | 2027/2/28 | 28 | 28 | | 13,500 | 13,500 | 13,500 | 12,585 | 12,585 | 12,585 | -915 |
| | Coaching - 30 Min | 2027/1/15 | 2027/2/14 | 2027/2/1 | 2027/2/14 | 31 | 14 | | 36,000 | 16,258 | | 33,559 | 15,156 | | |
| | Coaching - 30 Min | 2027/2/15 | 2027/3/14 | 2027/2/15 | 2027/2/28 | 28 | 14 | | 36,000 | 36,000 | 18,000 | 33,559 | 16,780 | 31,935 | -2,323 |
| | App | 2027/1/15 | 2027/2/14 | 2027/2/1 | 2027/2/14 | 31 | 14 | | 3,600 | 0 | 0 | 3,356 | 1,516 | | |
| | App | 2027/2/15 | 2027/3/14 | 2027/2/15 | 2027/2/28 | 28 | 14 | | 3,600 | 0 | 0 | 3,356 | 1,678 | 3,194 | 3,194 |
| | **Totals** | | | | | | | | | 49,500 | | | 47,714 | | |
| **Month 6 (2027/3)** | | | | | | | | | | | | | | | |
| | Lesson - Daily 1 | 2027/3/1 | 2027/3/31 | 2027/3/1 | 2027/3/31 | 31 | 31 | 50% | 13,500 | 6,750 | 6,750 | 6,292 | 6,292 | 6,292 | -458 |
| | Coaching - 30 Min | 2027/2/15 | 2027/3/14 | 2027/3/1 | 2027/3/14 | 28 | 14 | | 36,000 | 18,000 | | 33,559 | 16,780 | | |
| | Coaching - 30 Min | 2027/3/15 | 2027/4/14 | 2027/3/15 | 2027/3/31 | 31 | 17 | 50% | 36,000 | 18,000 | 9,871 | 16,780 | 9,202 | 25,981 | -1,890 |
| | App | 2027/2/15 | 2027/3/14 | 2027/3/1 | 2027/3/14 | 28 | 14 | | 3,600 | 0 | 0 | 3,356 | 1,678 | | |
| | App | 2027/3/15 | 2027/4/14 | 2027/3/15 | 2027/3/31 | 31 | 17 | | 3,600 | 0 | 0 | 1,678 | 920 | 2,598 | 2,598 |
| | **Totals** | | | | | | | | | 24,750 | | | 34,872 | | |
| **Month 7 (2027/4)** | | | | | | | | | | | | | | | |
| | Lesson - Daily 1 | 2027/4/1 | 2027/4/30 | 2027/4/1 | 2027/4/30 | 30 | 30 | 5% | 13,500 | 12,825 | 12,825 | 12,825 | 12,825 | 12,825 | 0 |
| | Coaching - 30 Min | 2027/3/15 | 2027/4/14 | 2027/4/1 | 2027/4/14 | 31 | 14 | 50% | 36,000 | 8,129 | | 16,780 | 7,578 | | |
| | App | 2027/3/15 | 2027/4/14 | 2027/4/1 | 2027/4/14 | 31 | 14 | | 3,600 | 0 | 0 | 1,678 | 758 | | |
| | **Totals** | | | | | | | | | 12,825 | | | 21,161 | | |

## Observations

### Key Complexity: Staggered Contract Periods

- Lesson runs calendar-month aligned (1st to end-of-month)
- Coaching runs mid-month (15th to 14th)
- App follows Coaching's schedule
- Each accounting month may contain TWO coaching/app contracts (tail-end of previous + start of new)

### O-Value Behavior

- Month 1: O is calculated once per proration group (ΣM × basis/Σbasis)
- Months 2+: Previous contract's O carries over, new contract gets new O
- Two coaching charges in one month = two different O values (one from previous group, one from new group)

### Cross-Contract Proration in Single Month

When a month contains the tail of contract A and the start of contract B:
- Contract A: P = O_A × (remaining_days / total_contract_days)
- Contract B: P = O_B × (days_in_month / total_contract_days)
- Monthly total P = P_A + P_B

### Month-6 Discount (50%)

- Applied to BOTH Lesson and Coaching in month 6
- Lesson month-6 = 2027/3 (6th charge from 2026/10)
- Coaching month-6 = 2027/3 (for the 15th-cycle coaching, 6th charge from 2026/10/15)
- When 50% applies: basis = L (list price), same as month-1 Honki Set discount

### Month 7 — Loyal Discount (5%)

- After Honki Set benefit period ends, Loyal discount kicks in
- Lesson: basis = M (paid amount with 5% discount = ¥12,825) — non-Honki discount
- O = M for Lesson (since it's a non-Honki discount)
- Coaching still in tail period from month-6 contract

### Validation

- Grand total Paid Price across all months: ¥260,325
- Grand total P across all months: ¥260,325
- ΣP = ΣPaid (lifetime invariant holds) ✓

## Implications for Phase 2 Design

1. **Multiple proration groups per month** — when a new contract starts mid-month, a new group is formed
2. **Cross-month contract splitting** — one contract's P is split across two accounting months
3. **O carries over per contract** — not per month. Each contract has its own O that persists across the months it spans
4. **Month-6 discount detection** — must count from original Honki Set start date per product independently
5. **Transition from Honki Set to Loyal** — month 7+ uses M as basis (non-Honki discount applies)
