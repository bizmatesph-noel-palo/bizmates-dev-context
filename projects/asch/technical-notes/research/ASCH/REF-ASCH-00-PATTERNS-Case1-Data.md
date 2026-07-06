# Pattern 1 (Case 1) — Revenue Allocation Data

**Source:** [Honki Set Allocation Google Sheet](https://docs.google.com/spreadsheets/d/1NoaaoTNX8a-enGql_qZdGke8MofQX8AHThNF6XB0Sgk/edit?gid=824143910#gid=824143910)  
**Pattern:** Case 1 — B2C新規, 開始日同じ, 月初スタート (B2C new enrollment, same start date, month-start)  
**Confirmation Point:** 割引後金額で按分 (Prorate using post-discount amounts)

---

## Scenario Description

- **Student type:** B2C new enrollment
- **Start alignment:** Lesson and Coaching start on the exact same date (月初 = 1st of month)
- **Campaign:** Honki Set — 50% discount on months 1 and 6
- **Products:** Lesson Daily 1 + Coaching 30 Min + App

---

## Column Definitions

| Column | Japanese | English | Description |
|--------|---------|---------|-------------|
| I | 契約日数 | Contract dates | Number of days in the contract period for that month |
| J | 受講回数 | Lesson/Session Counts | Number of lessons/sessions in the month |
| K | 割引 | Discount | Discount percentage applied |
| L | 価格（月額） | Sales Price / List Price | Standard undiscounted monthly price |
| M | 支払金額 | Paid Amount | Actual amount student paid (includes discount) |
| N | 現在の按分前 売上認識 | Gross Amount | Current sales recognition (before ASCH allocation) — what ASC currently calculates |
| O | 当月費消分の価格 | Consumed Price | Allocated price per product using ratio method |
| P | 按分後 売上計上 | Accounting | Final prorated amount (Column O × J/I) |

---

## Month 1 (2026/10) — 50% Discount Month

| Product | Start | End | Days (I) | Sessions (J) | Discount (K) | List Price (L) | Paid Amount (M) | Gross (N) | Consumed Price (O) | Accounting (P) | Δ vs Current |
|---------|-------|-----|----------|-------------|-------------|---------------|----------------|-----------|-------------------|---------------|-------------|
| Lesson - Daily 1 | 2026/10/1 | 2026/10/31 | 31 | 31 | 50% | ¥13,500 | ¥6,750 | ¥6,750 | ¥3,604 | ¥3,604 | -¥3,146 |
| Coaching - 30 Min | 2026/10/1 | 2026/10/31 | 31 | 31 | 50% | ¥36,000 | ¥18,000 | ¥18,000 | ¥19,223 | ¥19,223 | +¥1,223 |
| App | 2026/10/1 | 2026/10/31 | 31 | 31 | — | ¥3,600 | ¥0 | ¥0 | ¥1,922 | ¥1,922 | +¥1,922 |
| **Total** | | | | | | **¥53,100** | **¥24,750** | **¥24,750** | **¥24,750** | **¥24,750** | **¥0** |

---

## Month 2 (2026/11) — Regular Month (same as months 3–5)

| Product | Start | End | Days (I) | Sessions (J) | Discount (K) | List Price (L) | Paid Amount (M) | Gross (N) | Consumed Price (O) | Accounting (P) | Δ vs Current |
|---------|-------|-----|----------|-------------|-------------|---------------|----------------|-----------|-------------------|---------------|-------------|
| Lesson - Daily 1 | 2026/11/1 | 2026/11/30 | 30 | 30 | — | ¥13,500 | ¥13,500 | ¥13,500 | ¥12,585 | ¥12,585 | -¥915 |
| Coaching - 30 Min | 2026/11/1 | 2026/11/30 | 30 | 30 | — | ¥36,000 | ¥36,000 | ¥36,000 | ¥33,559 | ¥33,559 | -¥2,441 |
| App | 2026/11/1 | 2026/11/30 | 30 | 30 | — | ¥3,600 | ¥0 | ¥0 | ¥3,356 | ¥3,356 | +¥3,356 |
| **Total** | | | | | | **¥53,100** | **¥49,500** | **¥49,500** | **¥49,500** | **¥49,500** | **¥0** |

---

## Month 6 (2027/3) — 50% Discount Month (conditional)

| Product | Start | End | Days (I) | Sessions (J) | Discount (K) | List Price (L) | Paid Amount (M) | Gross (N) | Consumed Price (O) | Accounting (P) | Δ vs Current |
|---------|-------|-----|----------|-------------|-------------|---------------|----------------|-----------|-------------------|---------------|-------------|
| Lesson - Daily 1 | 2027/3/1 | 2027/3/31 | 31 | 31 | 50% | ¥13,500 | ¥6,750 | ¥6,750 | ¥6,292 | ¥6,292 | -¥458 |
| Coaching - 30 Min | 2027/3/1 | 2027/3/31 | 31 | 31 | 50% | ¥36,000 | ¥18,000 | ¥18,000 | ¥16,780 | ¥16,780 | -¥1,220 |
| App | 2027/3/1 | 2027/3/31 | 31 | 31 | — | ¥3,600 | ¥0 | ¥0 | ¥1,678 | ¥1,678 | +¥1,678 |
| **Total** | | | | | | **¥53,100** | **¥24,750** | **¥24,750** | **¥24,750** | **¥24,750** | **¥0** |

---

## 6-Month Total Verification

| | Current (N) | ASCH (P) |
|---|---|---|
| Total | ¥99,000 | ¥99,000 |

The total revenue over 6 months is unchanged — ASCH only redistributes between products, it does not change the total.

---

## Key Notes from Google Sheet

### Note K4 — Lesson Discount Is NOT Honki Set
> "Strictly speaking, this 50% discount on the lesson fee is not part of this Honki-set campaign. It is a lesson-specific discount that is applied only in the first month when the student starts that lesson. That's why the consumed price is calculated by the discount price. If the discount is a part of Honki-set, we prorate based on the List Price as Coaching (L5)."

**Implication:** The month-1 lesson 50% discount comes from the **First Month Enrollment Campaign** (entry cohort), NOT from Honki Set itself. This confirms the entry campaign discount is a separate mechanism. The ratio calculation uses the **paid amount (M)** for Lesson because the discount is external to Honki Set.

### Note M3 — Paid Amount
> "Actual amount students paid. It includes the discount."

### Note N3 — Gross Amount (Current ASC)
> "Current sales calculated by ASC program."

**Implication:** ASC already processes these charges today. The Gross column represents what ASC currently outputs. ASCH will replace these values with the allocated amounts.

### Note O3 — Consumed Price (Allocation Formula)
> "This price is calculated by multiplying the total Paid Amount (M) by each product's ratio to the total list price (L). Note: For the first row (O4), we use the paid amount (M) instead of the list price (L) because this discount is different campaign from the Honki-set."

**Implication:** The allocation formula uses DIFFERENT ratio bases depending on whether a product's discount is external to Honki Set:
- **Lesson (with external discount):** Uses Paid Amount (M) as the ratio numerator
- **Coaching (Honki Set discount):** Uses List Price (L) as the ratio numerator
- **App (no price):** Uses List Price (L) as the ratio numerator

### Note P3 — Accounting (Final Proration)
> "This is the prorated amount of Column O by total lesson days in this month (J/I)."

**Formula:** `Accounting (P) = Consumed Price (O) × Sessions (J) / Contract Days (I)`

In Pattern 1, J always equals I (sessions = days), so P = O. This will differ in other patterns where sessions ≠ days.

---

## Derived Formula: Allocation Calculation

Based on the data and notes, the allocation formula for Pattern 1 is:

### Step 1: Determine ratio base per product

```
For each product:
  IF product has an EXTERNAL discount (not from Honki Set):
    ratio_base = Paid Amount (M)
  ELSE:
    ratio_base = List Price (L)
```

### Step 2: Calculate allocation ratio

```
total_ratio_base = sum(ratio_base for all products)
ratio(product) = ratio_base(product) / total_ratio_base
```

### Step 3: Allocate total paid amount

```
total_paid = sum(Paid Amount for Lesson + Coaching)  // App paid = 0
consumed_price(product) = total_paid × ratio(product)
```

### Step 4: Prorate by session usage

```
accounting(product) = consumed_price(product) × sessions / contract_days
```

---

## Worked Example: Month 1

**Step 1 — Ratio bases:**
- Lesson: Paid Amount = ¥6,750 (external discount → use M)
- Coaching: List Price = ¥36,000 (Honki Set discount → use L)
- App: List Price = ¥3,600 (no discount → use L)

**Step 2 — Ratios:**
- Total ratio base = 6,750 + 36,000 + 3,600 = ¥46,350
- Lesson ratio = 6,750 / 46,350 = 0.14563
- Coaching ratio = 36,000 / 46,350 = 0.77670
- App ratio = 3,600 / 46,350 = 0.07767

**Step 3 — Allocate total paid (¥24,750):**
- Lesson consumed = 24,750 × 0.14563 = ¥3,604
- Coaching consumed = 24,750 × 0.77670 = ¥19,223
- App consumed = 24,750 × 0.07767 = ¥1,922
- **Total = ¥24,749 ≈ ¥24,750** (rounding)

**Step 4 — Prorate (31 sessions / 31 days = 1.0):**
- All values stay the same (P = O in Pattern 1 when sessions = days)

---

## Key Takeaways for ASCH Implementation

1. **ASCH does NOT change the total revenue** — it only redistributes between products. Total Paid (M) = Total Accounting (P) always.

2. **The lesson discount is from an EXTERNAL campaign (First Month Enrollment)**, not Honki Set. This answers the stacking question: the discounts are separate mechanisms.

3. **The ratio formula has a conditional:** products with external discounts use Paid Amount; products with Honki Set discounts use List Price. The system must know which discount applies to which product.

4. **App always has ¥0 paid but receives allocated revenue.** This is the core accounting requirement.

5. **In Pattern 1, Step 4 is a no-op** (sessions always = days when contract starts on day 1). Other patterns will likely have sessions ≠ days.

6. **Months 2–5 have no discount** — full list price is paid for Lesson and Coaching. The allocation still happens because App needs its share.

7. **The Δ column shows the redistribution effect:** Lesson and Coaching lose revenue to App. The total is zero-sum.


---

## Appendix: Original Excel Formulas (Source of Truth)

These are the actual formulas from Kuroda-san's Google Sheet. Row mapping:
- Rows 4–6: Month 1 (Lesson, Coaching, App)
- Row 7: Month 1 Total
- Rows 8–10: Month 2 (Lesson, Coaching, App)
- Row 11: Month 2 Total
- Rows 12–14: Month 6 (Lesson, Coaching, App)
- Row 15: Month 6 Total
- Row 16: Grand Total (6 months)

---

### Column M — Paid Amount

> Actual amount students paid. It includes the discount.

```
M4  = L4 - (L4 * K4)           // Lesson: List Price - (List Price × Discount%)
M5  = L5 - (L5 * K5)           // Coaching: List Price - (List Price × Discount%)
M7  = SUM(M4:M6)               // Month total (App M6 = 0, no formula shown)

M8  = L8 - (L8 * K8)           // Month 2 Lesson (no discount, so K8=0 → M8=L8)
M9  = L8 - (L8 * K8)           // Month 2 Coaching (note: references L8, likely typo for L9)
M10 = SUM(M8:M10)              // Month 2 total

M12 = L12 - (L12 * K12)        // Month 6 Lesson (50% discount)
M13 = L13 - (L13 * K13)        // Month 6 Coaching (50% discount)
M15 = SUM(M12:M14)             // Month 6 total

M16 = M7 + M11 + M15           // Grand total
```

**Pattern:** `Paid = List Price × (1 - Discount%)`

---

### Column N — Gross Amount (Current ASC Output)

> Current sales calculated by ASC program.

```
N4  = M4 / I4 * J4             // Lesson: Paid ÷ Contract Days × Sessions
N5  = M5 / I5 * J5             // Coaching: Paid ÷ Contract Days × Sessions
N6  = M6 / I6 * J6             // App: 0 ÷ Days × Sessions = 0
N7  = SUM(N4:N6)               // Month total

N8  = M8 / I8 * J8             // Month 2 Lesson
N9  = M9 / I9 * J9             // Month 2 Coaching
N10 = M10 / I10 * J10          // Month 2 App
N11 = SUM(N8:N10)              // Month 2 total

N12 = M12 / I12 * J12          // Month 6 Lesson
N13 = M13 / I13 * J13          // Month 6 Coaching
N14 = M14 / I14 * J14          // Month 6 App
N15 = SUM(N12:N14)             // Month 6 total

N16 = N7 + N11 + N15           // Grand total
```

**Pattern:** `Gross = Paid Amount ÷ Contract Days × Sessions`  
This is the existing ASC daily rate formula. ASCH replaces this with the allocated amount.

---

### Column O — Consumed Price (ASCH Allocation)

> This price is calculated by multiplying the total Paid Amount (M) by each product's ratio to the total list price (L).  
> Note: For the first row (O4), we use the paid amount (M) instead of the list price (L) because this discount is different campaign from the Honki-set.

**Month 1 (discount month — external Lesson discount):**
```
O4  = (M4 + M5) * (M4 / (M4 + L5 + L6))       // Lesson: uses M4 (paid) as ratio numerator
O5  = (M4 + M5) * (L5 / (M4 + L5 + L6))       // Coaching: uses L5 (list) as ratio numerator
O6  = (M4 + M5) * (L6 / (M4 + L5 + L6))       // App: uses L6 (list) as ratio numerator
O7  = SUM(O4:O6)
```

**Month 2 (no external discount — all use List Price):**
```
O8  = (M8 + M9) * (L8 / (L8 + L9 + L10))      // Lesson: uses L8 (list) as ratio numerator
O9  = (M8 + M9) * (L9 / (L8 + L9 + L10))      // Coaching: uses L9 (list) as ratio numerator
O10 = (M8 + M9) * (L10 / (L8 + L9 + L10))     // App: uses L10 (list) as ratio numerator
O11 = SUM(O8:O10)
```

**Month 6 (Honki Set discount — no external discount):**
```
O12 = (M12 + M13) * (L12 / (L12 + L13 + L14)) // Lesson: uses L12 (list) as ratio numerator
O13 = (M12 + M13) * (L13 / (L12 + L13 + L14)) // Coaching: uses L13 (list) as ratio numerator
O14 = (M12 + M13) * (L14 / (L12 + L13 + L14)) // App: uses L14 (list) as ratio numerator
O15 = SUM(O12:O14)

O16 = O7 + O11 + O15
```

**Key observation:** Month 1 uses `M4` (paid) in the ratio for Lesson because the discount is external. Months 2–6 use `L` (list price) for ALL products because either there's no discount, or the discount is from Honki Set itself.

**Generalized formula:**
```
consumed(product) = total_paid × (ratio_base(product) / sum(all_ratio_bases))

Where:
  total_paid       = sum of all non-zero Paid Amounts (Lesson + Coaching; App = 0)
  ratio_base       = Paid Amount (M) if product has external discount
                   = List Price (L) if product has Honki Set discount or no discount
```

---

### Column P — Accounting (Final Prorated Amount)

> This is the prorated amount of Column O by total lesson days in this month (J/I).

```
P4  = O4 * (J4 / I4)           // Lesson: Consumed × (Sessions / Contract Days)
P5  = O5 * (J5 / I5)           // Coaching
P6  = O6 * (J6 / I6)           // App
P7  = SUM(P4:P6)

P8  = O8 * (J8 / I8)           // Month 2 Lesson
P9  = O9 * (J9 / I9)           // Month 2 Coaching
P10 = O10 * (J10 / I10)        // Month 2 App
P11 = SUM(P8:P10)

P12 = O12 * (J12 / I12)        // Month 6 Lesson
P13 = O13 * (J13 / I13)        // Month 6 Coaching
P14 = O14 * (J14 / I14)        // Month 6 App
P15 = SUM(P12:P14)

P16 = P7 + P11 + P15
```

**Pattern:** `Accounting = Consumed Price × (Sessions / Contract Days)`

In Pattern 1, Sessions always equals Contract Days (full month, daily lessons), so P = O.  
This step becomes meaningful in other patterns where sessions ≠ days (e.g., partial months, rest mid-month).

---

### Formula Verification vs Derived Logic

| Aspect | My Derivation (above) | Excel Formula | Match? |
|--------|----------------------|---------------|--------|
| Ratio base for externally-discounted product | Paid Amount (M) | `M4` in O4 numerator | ✅ |
| Ratio base for Honki Set / no-discount product | List Price (L) | `L5`, `L6` in O5/O6 numerator | ✅ |
| Ratio denominator | sum(all ratio_bases) | `M4 + L5 + L6` | ✅ |
| Total paid (numerator) | sum(non-zero paid amounts) | `M4 + M5` (Lesson + Coaching) | ✅ |
| Proration factor | Sessions / Contract Days | `J/I` | ✅ |
| Month 2+ (no external discount) | All use List Price | `L8/(L8+L9+L10)` etc. | ✅ |
| Month 6 (Honki Set discount only) | All use List Price | `L12/(L12+L13+L14)` etc. | ✅ |

**Conclusion:** The derived 4-step formula matches the Excel formulas exactly. The implementation can use either representation.
