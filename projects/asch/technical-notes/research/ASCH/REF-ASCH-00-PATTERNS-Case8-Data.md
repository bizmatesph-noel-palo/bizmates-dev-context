# ASCH Pattern 8 — Case Data (from Kuroda-san's Excel)

**Source:** Kuroda-san's specification Excel v3
**Pattern:** 8 — Cooling-off refund within 8 days
**Scenario:** B2C new student, Lesson started before campaign, Coaching starts during campaign, cooling-off exercised within 8 days

## Key Characteristics

- Lesson (Daily 1) starts on 9/28 — BEFORE campaign period
- Coaching 30-min starts on 10/3 — during campaign period
- **Cooling-off exercised on 10/5** (within 8 days of Coaching start 10/3)
- Lesson also cancelled as part of cooling-off (contract shortened to 10/5)
- **Full refund for Coaching** (negative paid_price = -¥16,200)
- **Prorated refund for Lesson** (negative paid_price = -¥12,150 for 10/1 – 10/5 period)
- App: ¥0 — no refund needed (was free)
- Bundle effectively terminated on day 3

## Business Rules (Cooling-Off)

1. Consumer right to cancel within 8 days of purchase
2. Full refund for Coaching (charged amount returned)
3. Prorated refund for Lesson (days not used after cancellation)
4. App was free — no refund, but membership stops
5. The negative M values (refund charges) still get proration treatment
6. **Cooling-off refund revenue is recognized in the same month** (no cross-month attribution — to be confirmed)

## Pre-Campaign Period (2026/9)

| Product | Contract | Period | Days | Paid Price | Notes |
|---|---|---|---|---|---|
| Lesson - Daily 1 | 9/28 – 10/27 | 9/28 – 9/30 | 3/30 | 13,500 | 1,350 consumed (regular daily rate before Honki Set) |

## Month 2 (2026/10) — Cooling-Off Exercised on 10/5

The entire Honki Set bundle starts and ends in this month.

| Product | Contract | Period in Month | Days | Discount | Paid Price | O | P | Notes |
|---|---|---|---|---|---|---|---|---|
| Lesson - Daily 1 | 9/28 – 10/5 | 10/1 – 10/5 | 5/8 | | 0(?) | 13,500 | 12,150 | Original charge — shortened to 10/5 |
| **Lesson - Daily 1 REFUND** | 9/28 – 10/5 | 10/1 – 10/5 | 5/8(?) | | **-12,150** | -12,150 | -12,150 | Refund for remaining period |
| | | | | | | | **0** | Net zero for Lesson |
| Coaching - 30 Min | 10/3 – 10/5 | 10/3 – 10/5 | 3/3 | 50% | 18,000 | 18,000 | 18,000 | Original charge — full period (3 days only) |
| **Coaching - 30 Min REFUND** | 10/3 – 10/5 | 10/3 – 10/5 | 3/3 | 50% | **-16,200** | -16,200 | -16,200 | Cooling-off refund (most of the charged amount) |
| | | | | | | | **1,800** | Net ¥1,800 for Coaching (partial retention?) |
| App | 10/3 – 11/2 | 10/3 – 10/31 | 29/31 | | 0 | 0 | 0 | App was free — no financial impact |
| **Totals** | | | | | -10,350 | | 1,800 | |

## Summary

| Item | Value |
|---|---|
| Total charges paid | ¥13,500 (Lesson Sept) + ¥0 (Lesson Oct cancelled) + ¥18,000 (Coaching) = ¥31,500 |
| Total refunds | -¥12,150 (Lesson) + -¥16,200 (Coaching) = -¥28,350 |
| Net paid | ¥31,500 - ¥28,350 = ¥3,150 |
| Total P (lifetime) | ¥1,350 (Sept Lesson) + ¥1,800 (Oct net Coaching) = ¥3,150 |
| ΣP = net paid | ✓ |

## Validation

- Net paid amount: ¥3,150
- Total P across all months: ¥3,150
- ΣP = ΣNet Paid (lifetime invariant holds) ✓

## Implications for Design (Pattern 8 specific)

1. **Negative M values in proration** — refund charges create rows with negative paid_price. The proration formula still applies: O = ΣM × (basis/Σbasis), but M is negative, so O is negative.

2. **Same-month cancellation** — the entire bundle lifecycle is < 8 days. ASCH must handle the case where start and end happen in the same accounting month.

3. **Basis for refund rows** — when cooling-off applies, the refund charge carries the Honki Set discount context. Coaching refund basis = L (list price, since Honki Set discount applied to the original charge). Or does basis = M (the refund amount)? **Needs clarification** — the data suggests O = paid_price directly for refund rows.

4. **Net effect can be near-zero** — after cooling-off, the total P for the bundle is minimal (only the few days before cancellation). The adjustment sent to Freee would be small.

5. **Lesson refund attribution** — the refund for Lesson covers 10/1 – 10/5 period. Since the existing system (daily rate) also processes this refund, N would include the negative. ASCH adjustment = P(refund) - N(refund). If both are -¥12,150, adjustment = 0.

6. **Coaching partial retention** — net Coaching P = ¥1,800. This suggests 3 days of Coaching at prorated rate are retained despite cooling-off. The refund is -¥16,200 but the charge was ¥18,000 → ¥1,800 retained for services rendered.

7. **Cooling-off detection** — ASCH needs to detect cooling-off scenarios. Likely via `trn_prorated_refund_charge` where a full/near-full refund is issued within 8 days of contract start.

8. **Simplest pattern in execution** — despite being an "edge case," this is actually simple for ASCH because the bundle barely lived. Only 1 month of proration data. But the negative M handling must be correct.

## Open Questions for Kuroda-san

1. Are cooling-off refunds always recognized in the same month as the original charge? (The data shows both charge and refund in October)
2. For the Coaching refund of -¥16,200: is basis = L (¥36,000 list) or basis = M (-¥16,200 paid)?
3. The ¥1,800 retained for Coaching — is this intentional (3 days of service rendered)?
