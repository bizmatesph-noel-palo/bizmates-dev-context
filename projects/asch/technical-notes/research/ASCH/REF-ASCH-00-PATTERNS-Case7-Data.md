# ASCH Pattern 7 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel v3
**Pattern:** 7 — B2E → B2B switch with refund mid-campaign
**Scenario:** B2E student, Lesson started before campaign, contract type changes to B2B mid-campaign with prorated refund

## Key Characteristics

- **Contract type: B2E** (contract_type = 2) — student pays individually but linked to company
- Lesson (Daily 1) starts on 9/28 — BEFORE campaign period
- Coaching 30-min starts on 10/3 — during campaign period
- App starts with Coaching on 10/3
- **B2E discount (5%)** applies throughout (non-Honki discount → basis = M)
- **B2E → B2B switch on 3/20** — student moves to corporate-sponsored contract
- **Prorated refund** issued for the remaining days of the B2E charge (3/20 – 3/27 = -¥3,664)
- New B2B charge starts 3/20 at full price (no B2E discount)
- **⚠️ #REF! errors in Excel** — some month-7 values broken in source spreadsheet

## Critical Business Rules

1. **B2E discount = non-Honki discount** → basis = M (paid amount including 5% discount)
2. **B2B is excluded from Honki Set** — after switch to B2B, proration stops for that product
3. **Prorated refund** — negative M value for the partial-month refund of the B2E charge
4. **Contract period history** — `asch_enrollment_contract_periods` must track: B2E (start) → B2B (from 3/20)
5. **App exclusion after B2B switch** — Open Item from project-context: "App possibly excluded after switch"

## Pre-Campaign Period (2026/9)

| Product | Contract | Period | Days | Discount | Paid Price | Notes |
|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 9/28 – 10/27 | 9/28 – 9/30 | 3/30 | 5% | 12,825 | 1,283 consumed (B2E discounted rate) |

## Month 1 (2026/10) — Honki Set Starts

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 9/28 – 10/27 | 10/1 – 10/27 | 27/30 | 5% | 12,825 | | 11,543 | |
| Lesson - Daily 1 B2E | 10/28 – 11/27 | 10/28 – 10/31 | 4/31 | 5% | 12,825 | 7,541 | 973 | |
| | | | | | | | **12,516** | -682 |
| Coaching - 30 Min | 10/3 – 11/2 | 10/3 – 10/31 | 29/31 | 50% | 18,000 | 21,167 | 19,802 | 2,963 |
| App | 10/3 – 11/2 | 10/3 – 10/31 | 29/31 | | 0 | 2,117 | 1,980 | 1,980 |
| **Totals** | | | | | 30,825 | | 34,297 | |

**Note:** Lesson basis = M = ¥12,825 (B2E 5% discount is a non-Honki discount). Coaching basis = L = ¥36,000 (Honki Set 50% discount).

## Month 2 (2026/11)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 10/28 – 11/27 | 11/1 – 11/27 | 27/31 | 5% | | 7,541 | 6,568 | |
| Lesson - Daily 1 B2E | 11/28 – 12/27 | 11/28 – 11/30 | 3/30 | 5% | 12,825 | 11,944 | 1,194 | |
| | | | | | | | **7,762** | -4,690 |
| Coaching - 30 Min | 10/3 – 11/2 | 11/1 – 11/2 | 2/31 | 50% | | 21,167 | 1,366 | |
| Coaching - 30 Min | 11/3 – 12/2 | 11/3 – 11/30 | 28/30 | | 36,000 | 33,528 | 31,293 | |
| | | | | | | | **32,658** | -2,103 |
| App | 10/3 – 11/2 | 11/1 – 11/2 | 2/31 | | 0 | 2,117 | 137 | |
| App | 11/3 – 12/2 | 11/3 – 11/30 | 28/30 | | 0 | 3,353 | 3,129 | |
| | | | | | | | **3,266** | 3,266 |
| **Totals** | | | | | 48,825 | | 43,686 | |

## Month 3 (2026/12)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 11/28 – 12/27 | 12/1 – 12/27 | 27/30 | 5% | | 11,944 | 10,750 |
| Lesson - Daily 1 B2E | 12/28 – 1/27 | 12/28 – 12/31 | 4/31 | 5% | 12,825 | 11,944 | 1,541 |
| Coaching - 30 Min | 11/3 – 12/2 | 12/1 – 12/2 | 2/30 | | | 33,528 | 2,235 |
| Coaching - 30 Min | 12/3 – 1/2 | 12/3 – 12/31 | 29/31 | | 36,000 | 33,528 | 31,365 |
| App | 11/3 – 12/2 | 12/1 – 12/2 | 2/30 | | 0 | 3,353 | 224 |
| App | 12/3 – 1/2 | 12/3 – 12/31 | 29/31 | | 0 | 3,353 | 3,136 |
| **Totals** | | | | | 48,825 | | 49,251 |

## Month 4 (2027/1)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 12/28 – 1/27 | 1/1 – 1/27 | 27/31 | 5% | | 11,944 | 10,403 |
| Lesson - Daily 1 B2E | 1/28 – 2/27 | 1/28 – 1/31 | 4/31 | 5% | 12,825 | 11,944 | 1,541 |
| Coaching - 30 Min | 12/3 – 1/2 | 1/1 – 1/2 | 2/31 | | | 33,528 | 2,163 |
| Coaching - 30 Min | 1/3 – 2/2 | 1/3 – 1/31 | 29/31 | | 36,000 | 33,528 | 31,365 |
| App | 12/3 – 1/2 | 1/1 – 1/2 | 2/31 | | 0 | 3,353 | 216 |
| App | 1/3 – 2/2 | 1/3 – 1/31 | 29/31 | | 0 | 3,353 | 3,136 |
| **Totals** | | | | | 48,825 | | 48,825 |

## Month 5 (2027/2)

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P |
|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 1/28 – 2/27 | 2/1 – 2/27 | 27/31 | 5% | | 11,944 | 10,403 |
| Lesson - Daily 1 B2E | 2/28 – 3/27 | 2/28 – 2/28 | 1/28 | 5% | 12,825 | 11,944 | 427 |
| Coaching - 30 Min | 1/3 – 2/2 | 2/1 – 2/2 | 2/31 | | | 33,528 | 2,163 |
| Coaching - 30 Min | 2/3 – 3/2 | 2/3 – 2/28 | 26/28 | | 36,000 | 33,528 | 31,133 |
| App | 1/3 – 2/2 | 2/1 – 2/2 | 2/31 | | 0 | 3,353 | 216 |
| App | 2/3 – 3/2 | 2/3 – 2/28 | 26/28 | | 0 | 3,353 | 3,113 |
| **Totals** | | | | | 48,825 | | 47,455 |

## Month 6 (2027/3) — B2E → B2B Switch on 3/20

**Critical month:** Contract type changes mid-month. B2E Lesson charge is refunded for remaining days. New B2B charge starts.

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Notes |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 2/28 – 3/19 | 3/1 – 3/19 | 19/20(?) | 5% | 0(?) | 11,944 | 11,518 | B2E charge truncated at switch date |
| **Lesson - Daily 1 B2B** | 3/20 – 4/19 | 3/20 – 3/31 | 12/31 | | 13,500 | 8,008 | 3,100 | New B2B charge — **B2B excluded from Honki Set** |
| **Lesson - Daily 1 B2E REFUND** | 3/20 – 3/27 | 3/20 – 3/27 | 8/8 | | **-3,664** | -3,664 | -3,664 | Prorated refund for unused B2E days |
| Coaching - 30 Min | 2/3 – 3/2 | 3/1 – 3/2 | 2/28 | | | 33,528 | 2,395 | |
| Coaching - 30 Min | 3/3 – 4/2 | 3/3 – 3/31 | 29/31 | 50% | 18,000 | 21,356 | 19,978 | |
| | | | | | | | **22,373** | 5,534 |
| App | 2/3 – 3/2 | 3/1 – 3/2 | 2/28 | | 0 | 3,353 | 239 | |
| App | 3/3 – 4/2 | 3/3 – 3/31 | 29/31 | | 0 | 2,136 | 1,998 | |
| | | | | | | | **2,237** | 2,237 |
| **Totals** | | | | | 27,836 | | 35,564 | |

**⚠️ Notes on Month 6:**
- B2E Lesson charge is truncated when B2B starts (contract shortened to end on 3/19)
- Prorated refund = negative M (¥-3,664) for the 8 days remaining on the old B2E contract
- New B2B Lesson charge starts 3/20 — but B2B is excluded from Honki Set proration
- Coaching still gets month-6 50% discount (Coaching isn't affected by Lesson's contract type change)
- **#REF! errors in original Excel** for some adjustment calculations — data may need verification

## Month 7 (2027/4) — Post-Switch

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2B | 3/20 – 4/19 | 4/1 – 4/19 | 19/31 | | | 8,008 | 4,908 | -3,366 |
| Coaching - 30 Min | 3/3 – 4/2 | 4/1 – 4/2 | 2/31 | 50% | | 21,356 | 1,378 | #REF! |
| App | 3/3 – 4/2 | 4/1 – 4/2 | 2/31 | | 0 | 2,136 | 138 | #REF! |
| **Totals** | | | | | 8,274 | | 6,424 | |

**⚠️ #REF! errors:** The Excel has broken references for Coaching and App adjustments in month 7. These need verification with Kuroda-san.

## Validation

- Grand total Paid Price: ¥266,786 (Note: differs from Patterns 2-6 due to B2E pricing + refund)
- Grand total P: ¥266,786 (reported as matching, but #REF! errors suggest verification needed)
- Source shows: 266,786 | 250,686 | 537,236 | 266,786 — the 250,686 column may be gross_amount

## Implications for Design (Pattern 7 specific)

1. **Contract type change mid-enrollment** — `asch_enrollment_contract_periods` must record: B2E from start, B2B from 3/20. The period boundary affects which products remain in the bundle.

2. **B2B exclusion is per-product** — when Lesson switches to B2B, only Lesson exits the bundle. Coaching and App may continue (they're still paid individually). But this needs confirmation — the data shows Coaching continuing with 50% month-6 discount even after Lesson switches to B2B.

3. **Prorated refund = negative M** — the refund charge creates a negative M_Value row. This is similar to Pattern 8 (cooling-off) but triggered by contract type change.

4. **Basis for refund row** — the refund uses M as basis (since B2E discount is non-Honki). O for the refund = the refund amount directly (negative).

5. **New B2B charge gets its own O** — the B2B Lesson charge (¥13,500, no discount) starts a new allocation. But since B2B is excluded from Honki Set, this O = N = paid_price (no adjustment needed? Or does the B2B charge still participate in the bundle allocation?). **Needs clarification.**

6. **Month-6 timing** — Coaching still gets month-6 discount (3/3 – 4/2 charge). The B2E→B2B switch doesn't affect Coaching's month-6 eligibility. Only Lesson is affected by the contract type change.

7. **#REF! errors need resolution** — Month 7 adjustments for Coaching and App are broken in the Excel. This is an Open Item for Kuroda-san.

## Open Questions for Kuroda-san

1. After B2E→B2B switch, does the B2B Lesson charge still participate in the bundle allocation? Or does it exit completely (P = N, adjustment = 0)?
2. Does App continue after the switch? (Project-context says "App possibly excluded after switch")
3. The #REF! errors in month 7 — what should the correct adjustment values be?
4. Is the B2E refund (¥-3,664) included in ΣM for the proration group that month? Or handled separately?
