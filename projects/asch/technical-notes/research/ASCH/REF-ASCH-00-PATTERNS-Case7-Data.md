# ASCH Pattern 7 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel — updated 2026-07-15
**Pattern:** 7 — B2E → B2B switch with refund mid-campaign
**Scenario:** B2E student, Lesson started before campaign, contract type changes to B2B mid-campaign with prorated refund

## Update Log

- **2026-07-15:** Updated by Kuroda-san. Key clarification: "On the 6th month, the refund amount for changing contracts should be prorated since the based payment (= Daily 1 B2E lesson b/w 2/28~3/27) was already prorated." This confirms the refund proration rule applies here because the original payment was already prorated in a prior month.

## Key Characteristics

- **Contract type: B2E** (contract_type = 2) — student pays individually but linked to company
- Lesson (Daily 1) starts on 9/28 — BEFORE campaign period
- Coaching 30-min starts on 10/3 — during campaign period
- App starts with Coaching on 10/3
- **B2E discount (5%)** applies throughout (non-Honki discount → basis = M)
- **B2E → B2B switch on 3/20** — student moves to corporate-sponsored contract
- **Prorated refund IS prorated** because the original payment (2/28–3/27) was already prorated in a prior month
- New B2B charge starts 3/20 at full price (no B2E discount)
- **⚠️ #REF! errors in Excel** for Coaching/App month-7 adjustment — needs clarification

## Refund Proration Rule (Clarified by Kuroda-san 2026-07-15)

> "The refund amount for changing contracts should be prorated since the based payment (= Daily 1 B2E lesson b/w 2/28~3/27) was already prorated."

This means:
- The Lesson charge for 2/28–3/27 was paid in a prior month and already allocated via proration
- When the B2E→B2B switch happens on 3/20, the refund for the remaining days (3/20–3/27) must use the **same proration ratio** as the original payment
- The Coaching and App refund rows follow the same principle

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

**Critical month:** Contract type changes mid-month. B2E Lesson charge is refunded for remaining days. New B2B charge starts. **Refund IS prorated** because the original payment was already prorated.

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Notes |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2E | 2/28 – 3/19 | 3/1 – 3/19 | 19/20 | 5% | 0 | 11,944 | 11,518 | B2E charge truncated at switch date |
| Lesson - Daily 1 B2B | 3/20 – 4/19 | 3/20 – 3/31 | 12/31 | | 13,500 | 5,226 | 2,023 | New B2B charge |
| Lesson - Daily 1 B2E REFUND | 3/20 – 3/27 | 3/20 – 3/27 | 8/8 | | -3,664 | -932 | -932 | **Prorated refund** — same ratio as original |
| Coaching - 30 Min REFUND | 3/20 – 3/27 | 3/20 – 3/27 | | | | -2,484 | -2,484 | Prorated refund |
| App REFUND | 3/20 – 3/27 | 3/20 – 3/27 | | | | -248 | -248 | Prorated refund |
| Coaching - 30 Min | 2/3 – 3/2 | 3/1 – 3/2 | 2/28 | | 0 | 33,528 | 2,395 | Carry-over from prior charge |
| Coaching - 30 Min | 3/3 – 4/2 | 3/3 – 3/31 | 29/31 | 50% | 18,000 | 16,364 | 15,308 | Month-6 discount |
| App | 2/3 – 3/2 | 3/1 – 3/2 | 2/28 | | 0 | 3,353 | 239 | |
| App | 3/3 – 4/2 | 3/3 – 3/31 | 29/31 | | 0 | 1,636 | 1,531 | |
| **Totals** | | | | | 27,836 | | 29,349 | |

**Key observations:**
- Lesson B2E REFUND -¥3,664 → O = -¥932 (prorated using same ratio as original allocation)
- Coaching REFUND → -¥2,484 (prorated)
- App REFUND → -¥248 (prorated)
- The refund amounts are prorated because the **original payment (2/28–3/27) was already prorated in month 5**

## Month 7 (2027/4) — Post-Switch

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Adj |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 B2B | 3/20 – 4/19 | 4/1 – 4/19 | 19/31 | | 0 | 5,226 | 3,203 | -5,071 |
| Coaching - 30 Min | 3/3 – 4/2 | 4/1 – 4/2 | 2/31 | 50% | 0 | 16,364 | 1,056 | #REF! |
| App | 3/3 – 4/2 | 4/1 – 4/2 | 2/31 | | 0 | 1,636 | 106 | #REF! |
| **Totals** | | | | | 0 | | 4,364 | |

**⚠️ #REF! errors:** The Excel has broken references for Coaching and App adjustments in month 7. These need verification with Kuroda-san.

## Validation

- Grand total Paid Price: ¥266,786
- Grand total P: reported as ¥258,512 (due to #REF! errors, not fully verified)
- Source shows: 266,786 | 250,686 | 520,687 | 258,512
- **Note:** #REF! errors in month 7 prevent full validation

## Implications for Design (Pattern 7 specific)

1. **Contract type change mid-enrollment** — `asch_enrollment_contract_periods` must record: B2E from start, B2B from 3/20.

2. **Refund proration rule (confirmed 2026-07-15):** The B2E refund IS prorated because the original payment was already prorated in a prior month. The refund uses the same ratio as the original allocation.

3. **Prorated refund = negative M with allocated O** — the refund charge creates a negative O value using the same ratio as the original payment's allocation. This differs from Case 8-1 where refund is NOT prorated.

4. **B2B charge after switch** — B2B Lesson charge starts 3/20. Its O value (5,226) suggests it still participates in allocation but the post-switch handling needs confirmation re: Honki Set eligibility.

5. **Coaching continues after Lesson switches** — Coaching still gets month-6 50% discount. The B2E→B2B switch only affects Lesson's contract type.

6. **Month-6 Coaching O value changes** — Notice O = 16,364 (not 21,356 from earlier months) because month-6 uses the 50% discount list price for the Honki Set discount.

7. **#REF! errors still need resolution** — Month 7 adjustments for Coaching and App are broken.

## Open Questions for Kuroda-san

1. ~~After B2E→B2B switch, does the B2B Lesson charge still participate in the bundle allocation?~~ Partially answered: the data shows O = 5,226 for B2B Lesson, suggesting it does participate. But the P value (-5,071 adjustment) needs clarification.
2. Does App continue after the switch? The data shows App has O values after the switch (1,636), suggesting yes.
3. The #REF! errors in month 7 — what should the correct adjustment values be?
4. ~~Is the B2E refund prorated?~~ **ANSWERED (2026-07-15): YES** — because the original payment was already prorated.
