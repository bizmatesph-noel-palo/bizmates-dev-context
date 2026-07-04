# ASC-285: NULL order_no Causes Premature Expiry in Monthly Rate Calculation (Bug B)

## Type: Bug Fix
## Priority: High
## Parent: ASC-283 (Investigation)
## Branch from: ASC-master (with ASC-276/277 merged)
## Affected Files:
- `app/Libs/MonthlyRateCalculationLogic.php` (Bizmates + Zipan queries)
- `app/Libs/MonthlyRateCalculationPreLogic.php` (Bizmates + Zipan queries)

---

## Summary

Monthly-plan charges with `order_no = NULL` (individual/non-B2B enrollments) have all remaining lessons expired prematurely in their start month, instead of carrying over to the next month. This causes double-expiry and over-recognition of paid_price.

## Root Cause

The same-order successor detection uses standard SQL equality:

```sql
AND sp3.order_no = om.order_no
```

In SQL, `NULL = NULL` evaluates to `NULL` (falsy), not `TRUE`. This means `NOT EXISTS (... WHERE sp3.order_no = om.order_no ...)` always returns TRUE when `order_no IS NULL` — the system thinks no successor exists and fires the expiry logic.

## Affected Data

All Bizmates monthly-plan students (product_id 16-23, 27-29) whose charges have `order_no = NULL`. Confirmed affected: charge_id 3026692 (student 1236), 3001753 (student 121073), 3026886 (student 233228).

## Fix Instructions

### The Change

Replace every occurrence of:

```sql
AND sp3.order_no = om.order_no
```

With NULL-safe equality:

```sql
AND (sp3.order_no <=> om.order_no)
```

MySQL's `<=>` operator returns TRUE when both sides are NULL, unlike `=`.

Also replace equivalent patterns using other aliases:

```sql
-- sp5.order_no = mu.order_no → (sp5.order_no <=> mu.order_no)
-- sp3.order_no = mu.order_no → (sp3.order_no <=> mu.order_no)
```

### Locations in `MonthlyRateCalculationLogic.php`

**Bizmates query — FilteredUsage (ASC-266 same-order successor check):**
- `AND sp5.order_no = mu.order_no` (inside the ASC-266 OR condition)
- `AND sp3.order_no = mu.order_no` (inside the ASC-266 NOT expulsion block)

**Bizmates query — Grouped CTE (is_ticket_expiry_month):**
- 3 occurrences of `AND sp3.order_no = om.order_no` inside the CASE WHEN block

**Zipan query — Grouped CTE (is_ticket_expiry_month):**
- 3 occurrences of `AND sp3.order_no = om.order_no` inside the CASE WHEN block

### Locations in `MonthlyRateCalculationPreLogic.php`

**Bizmates query — FilteredUsage:**
- `AND sp5.order_no = mu.order_no`
- `AND sp3.order_no = mu.order_no`

**Bizmates query — Grouped CTE (is_ticket_expiry_month):**
- 3 occurrences of `AND sp3.order_no = om.order_no`

**Zipan query — Grouped CTE (is_ticket_expiry_month):**
- 3 occurrences of `AND sp3.order_no = om.order_no`

### Total: 16 replacements (8 per file)

### Important: Do NOT change these lines

The different-order detection (`sp2.order_no != mu.order_no`) in FilteredUsage already handles NULL correctly via its own OR conditions:

```sql
AND (sp2.order_no != mu.order_no
    OR (sp2.order_no IS NOT NULL AND mu.order_no IS NULL)
    OR (sp2.order_no IS NULL AND mu.order_no IS NOT NULL))
```

These lines are correct and should NOT be modified.

## Verification

1. Run the April batch against Bizmates
2. Check charge_id 3026692 (student 1236):
   - **Before fix:** April shows `taken=3, expired=12, remaining=0, paid_price=14107`
   - **After fix:** April shows `taken=3, expired=0, remaining=12, paid_price=2821`
3. Check that charge_id 3026692 in May shows `carried_over=12, expired=12, paid_price=11286`
4. Confirm that charges WITH a non-NULL order_no produce identical results (no regression)
5. Run existing test suite (TC014-TC030)

## Reference

See investigation report: `Technical_Notes/Issue_Investigation/20260608_data_adjustments/Notes_Data_Adjustment_Issue_20260608.md` — Bug B section.
