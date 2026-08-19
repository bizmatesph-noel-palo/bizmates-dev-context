# CAP Upstream Pricing Discussion — Slack Thread Summary

**Source:** CAP project Slack channel  
**Date:** 2026-08-12 (thread spans multiple days)  
**Participants:** Terry B. (CAP dev), Hayato Kuroda (PM/Accounting), Keith (CAP dev), Soli Sahukar, Jaysser, Jefferson Gernale  
**Filed by:** Noel Palo  
**Assisted by:** Kiro

---

## Executive Summary

The CAP upstream team registers the App charge at **¥0** (companion pattern). The actual App revenue (¥2,500 or ¥3,618 depending on interpretation) is folded into the Coaching charge line. The ASC allocation batch must split the single coaching charge into Coaching revenue + App revenue.

**Current status:** Decision pending (Kuroda-san confirming with business team next Monday). Likely outcome: **¥0 companion approach stays**. ASC allocation batch IS needed.

---

## Key Facts Confirmed

### Charge Structure (from upstream)

```
Plan 1018 (Lesson 25 + FVP + Coaching 15 + App):

| product_id | product          | paid_price | sales_price |
|------------|------------------|------------|-------------|
| 1          | Online Lesson 25 | ¥14,850    | ¥13,500     |
| 10011      | Full Video Pack  | ¥0         | ¥0          |
| 10021      | Bizmates App     | ¥0         | ¥0          |
| 10005      | Coaching 15min   | ¥22,550    | ¥20,500     |
```

- **App product_id for CAP: 10021** (clone of 10012, created for CAP bundles)
- **App product_id for CIP: also 10021** (confirmed by Kuroda-san)
- **App charge is always ¥0** in `trn_charge` (companion pattern)
- Revenue is collected through the Coaching charge line
- `price_flag = 4` in `mst_new_price_listing` stores COMBINED price (Coaching + App)

### Pricing Data (mst_new_price_listing, price_flag = 4)

| product_id | plan | tier | combined_price | coaching_standalone | app_implied |
|---|---|---|---|---|---|
| 10005 | Coaching 15min | 1 (full) | ¥20,500 | ¥18,000 | ¥2,500 |
| 10005 | Coaching 15min | 2 (half) | ¥10,250 | ¥9,000 | ¥1,250 |
| 10015 | Coaching 30min | 1 (full) | ¥38,500 | ¥36,000 | ¥2,500 |
| 10015 | Coaching 30min | 2 (half) | ¥19,250 | ¥18,000 | ¥1,250 |

### Three Allocation Options Discussed

| Option | App price | Coaching price (15min) | Who absorbs bundle discount |
|---|---|---|---|
| **(A)** Current impl | ¥2,500 | ¥18,000 | App absorbs all (¥1,118 discount) |
| **(B)** Simple split | ¥3,618 | ¥16,882 | Coaching absorbs all |
| **(C)** Proportional ✅ | Varies by N | Remainder | Split proportionally by standalone prices |

**Kuroda-san recommends (C)** — proportional allocation. Revenue recognition standards require transaction price allocated in proportion to standalone selling prices.

### Option (C) Formula (confirmed by Kuroda-san)

```
Standalone prices (allocation weights):
  App:      ¥3,618 (tax-excl) / ¥3,980 (tax-incl)
  Coaching: ¥18,000 (15min) / ¥36,000 (30min)

Allocation (ASC batch calculates monthly):
  N = coaching charge paid_price (from log_daily_rate_calculation)
  
  15min:
    App      = floor(N × 3,980 / (18,000×1.1 + 3,980))  = floor(N × 3,980 / 23,780)
    Coaching = N - App
  
  30min:
    App      = floor(N × 3,980 / (36,000×1.1 + 3,980))  = floor(N × 43,580)
    Coaching = N - App

  Total always = N (remainder absorption guarantees this)
```

### Tier 2 (Half-Price Campaign) — Confirmed Working

```
15min tier 2: N = 11,275 (= 10,250 × 1.1)
  App      = floor(11,275 × 3,980 / 23,780) = 1,886
  Coaching = 11,275 - 1,886                  = 9,389

30min tier 2: N = 21,175 (= 19,250 × 1.1)
  App      = floor(21,175 × 3,980 / 43,580) = 1,934
  Coaching = 21,175 - 1,934                  = 19,241
```

No flag-4 tier-2 rows need to change regardless of which option is chosen.
