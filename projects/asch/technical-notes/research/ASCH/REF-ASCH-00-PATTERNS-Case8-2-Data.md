# ASCH Pattern 8-2 — Cross-Month Cooling-Off / Refund Prorating

**Source:** Kuroda-san's specification Excel — added 2026-07-15
**Pattern:** 8-2 — Cooling-off cancellation in a DIFFERENT month from payment (refund IS prorated)
**Scenario:** B2C new student, joins Honki Set 7/27, batch runs 8/1, cooling-off on 8/2

## Key Rule (Kuroda-san 2026-07-15)

> "If the payment and the cooling-off are in different months, since the payment IS prorated, the refund IS also prorated."

**Principle:**
- Payment made in July (7/27)
- Batch runs on August 1st → July payment is prorated at that point
- Cooling-off completed on August 2nd → refund happens AFTER proration was already applied
- Therefore: refund must be prorated using the **same ratio as the original payment** (based on list prices)

## Scenario Details

- B2C new student
- Joins Honki Set on **7/27** (Lesson and Coaching start same day, campaign conditions met)
- Batch runs on **8/1** (processes July as target month)
- Cooling-off cancellation completed on **8/2** (90% refund)
- App: ¥0 paid but carries allocated revenue (and negative allocated revenue on refund)

## Applied Rules

1. **For a refund of a payment that was already prorated:** Prorate the refund using the same ratio as the original payment (based on regular/list prices)
2. **For a refund of a payment that was NOT prorated:** Do not prorate — directly recognize actual refund amount (same as existing Pattern 8-1)

## Month 1 (2026/7) — Honki Set Starts (Payment Month)

| Product | Contract | Period in Month | Days (I) | Sessions (J) | Discount | List Price (L) | Paid (M) | O | P | Adj |
|---|---|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 7/27 – 8/26 | 7/27 – 7/31 | 31 | 5 | 50% | ¥13,500 | ¥6,750 | ¥3,604 | ¥581 | -¥507 |
| Coaching - 30 Min | 7/27 – 8/26 | 7/27 – 7/31 | 31 | 5 | 50% | ¥36,000 | ¥18,000 | ¥19,223 | ¥3,101 | +¥197 |
| App | 7/27 – 8/26 | 7/27 – 7/31 | 31 | 5 | — | ¥3,600 | ¥0 | ¥1,922 | ¥310 | +¥310 |
| **Total** | | | | | | | **¥24,750** | **¥24,750** | **¥3,992** | |

**Note:** Payment is made in July. Batch runs 8/1 processing July → these values are prorated (P ≠ M because only 5/31 days consumed).

## Month 2 (2026/8) — Cooling-Off (Refund Month)

The cooling-off is completed on 8/2. Since the original July payment WAS prorated (batch ran 8/1), the refund IS prorated using the same ratio.

| Product | Contract | Period in Month | Days (I) | Sessions (J) | Discount | List Price (L) | Paid (M) | O | P | Adj |
|---|---|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 7/27 – 8/2 | 8/1 – 8/2 | 7 | 2 | | | | ¥3,604 | ¥3,023 | |
| **Lesson REFUND** | 7/27 – 8/2 | — | — | — | | ¥13,500 | -¥6,075 | **-¥3,244** | **-¥3,244** | -¥221 |
| Coaching - 30 Min | 7/27 – 8/2 | 8/1 – 8/2 | 7 | 2 | | | | ¥19,223 | ¥16,123 | |
| **Coaching REFUND** | 7/27 – 8/2 | — | — | — | | ¥36,000 | -¥16,200 | **-¥17,301** | **-¥17,301** | -¥75 |
| App | 7/27 – 8/2 | 8/1 – 8/2 | 7 | 2 | | | | ¥1,922 | ¥1,612 | |
| **App REFUND** | 7/27 – 8/2 | — | — | — | | ¥3,600 | ¥0 | **-¥1,730** | **-¥1,730** | -¥118 |
| **Total** | | | | | | | **-¥22,275** | | **-¥1,517** | |

**Key observations:**
- Lesson refund: -¥6,075 paid → O = -¥3,244 (prorated using list price ratio: 13,500 / 53,100 × -22,275)
- Coaching refund: -¥16,200 paid → O = -¥17,301 (prorated using list price ratio: 36,000 / 53,100 × -22,275)
- App refund: ¥0 actual refund → O = -¥1,730 (prorated using list price ratio: 3,600 / 53,100 × -22,275)
- The **App gets a negative O even though the actual refund is ¥0** — because the proration allocated revenue to App originally, and that allocation must be reversed

## Grand Total Verification

| | Paid (M) | Accounting (P) |
|---|---|---|
| Month 1 | ¥24,750 | ¥3,992 |
| Month 2 | -¥22,275 | -¥1,517 |
| **Net** | **¥2,475** | **¥2,475** |

✅ ΣP = Net Paid — invariant holds.

## Differences from Pattern 8-1

| Aspect | 8-1 (Same Month) | 8-2 (Cross Month) |
|---|---|---|
| Payment month | October | July |
| Cooling-off month | October (same) | August (different) |
| Was payment prorated before refund? | No (not yet batch-processed) | Yes (batch ran 8/1) |
| Is refund prorated? | **NO** | **YES** |
| Refund O calculation | O = M (face value) | O = ΣRefund × (L_product / ΣL_all) |
| App refund O | ¥0 (no allocation) | -¥1,730 (allocated negative) |

## Implications for ASCH Implementation

1. **Must track whether original payment was prorated** — the system needs to know if the payment's batch month has already been processed. If yes → refund prorated. If no → refund at face value.

2. **Refund ratio uses LIST PRICES (L), not paid amounts** — even though the original allocation may have used M for some products (external discounts), the refund ratio is always based on list prices.

3. **App carries negative allocated revenue on refund** — even though actual App refund = ¥0, the proration reversal gives App a negative O. This is correct because App received positive allocated revenue from the original payment.

4. **The "same ratio" means the denominator (ΣL) is the same** — ¥53,100 (13,500 + 36,000 + 3,600) used for both original allocation and refund allocation.

5. **Cross-month timing matters** — ASCH must check: was the charge's target month already finalized? If the refund happens before the batch processes the payment month, it's Pattern 8-1 (no proration). If after, it's Pattern 8-2 (proration applies).
