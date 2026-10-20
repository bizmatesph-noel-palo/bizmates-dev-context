# Freee Journal Handling of Allocated & Negative Amounts (Code-Grounded)

## Document Info

| | |
|---|---|
| **Document type** | Technical Design |
| **Date** | 2026-10-16 (Created) |
| **Author** | Noel Palo, Lead |
| **Assisted by** | Kiro (code analysis) |
| **Status** | Active |
| **Audience** | Dev team (ASCA/ASCI), SDM |
| **JIRA** | ASCA-47 (Spec 02b review) |

---

## 1. Summary

This note records — **grounded in the actual sender code**, not the design's assumptions — how the existing Freee journal path and the PayPal payment-sum builders handle the amounts ASCA allocation produces, including the **negative** App row that Spec 02b (refunds) introduces.

**Finding:** the existing code already handles negative amounts correctly (gate → sign-flip → `abs()` → balance guard). The 02b negative App row is a new *instance* of an amount shape the sender already supports — not a new code path. The one genuine open item is a **data** check (App `product_type = 100` Freee mapping rows exist), not a code risk.

Verified against `accounting_related_system_for_freee` @ `feature/ASCA/ASCA-47-spec-02b-coding`, 2026-10-16.

---

## 2. Why ASCA sends no journals of its own

ASCA uses **Scenario D (injection) + Option 1 (Overwrite)**: it overwrites the daily-rate log `paid_price` (N → P) in place. It never calls the Freee API. Because the App log row is raised from ¥0 to `P_app`, it then flows through the **existing** `SendJournalsDataLogic::sendFreeeJournals2()` path automatically. So "how ASCA reaches Freee" is entirely "how the existing sender treats the overwritten amount."

---

## 3. Freee sender — negative-amount handling (code trace)

Source: `app/Libs/SendJournalsDataLogic.php::sendFreeeJournals2()`.

| Step | Line (approx) | Behavior |
|---|---|---|
| **Emit gate** | 256 | `if ($sumList->paid_price != 0)` — a **non-zero** summed amount emits a journal. A ¥0 App companion is skipped; a non-zero `P_app` (positive or negative) passes. |
| **Sign → entry side** | 284–290 | `paid_price > 0` → record_one `debit` / record_two `credit`; else (negative) the sides **flip** (`credit` / `debit`). Correct refund accounting. |
| **Amount** | 343 | `'amount' => abs(...)` — the absolute value is sent; the sign is carried by `entry_side`, per the Freee API contract. |
| **Balance guard** | 579–590 | Each batch asserts `debit == credit`; an unbalanced batch throws `Unbalanced accounting entry detected`. |

**Implication for 02b:** the refund's negative App row (`P_app < 0`) passes the gate, flips to the correct entry side, and is sent as `abs(P_app)`. This is the same mechanism the system already uses for other negative (refund) amounts — not new logic.

---

## 4. PayPal payment sums — balance behavior

Source: `app/Libs/CommonUtil.php::createPaypalPaymentFile()` / `createPaypalPaymentSumFile()`.

These compute each month's `uriage` as `SUM(paid_price) ... WHERE target_ym = <ym>` per charge. Because an allocation split preserves the bundle total (`P_coaching + P_app = N`), the bundle's month-sum is **unchanged** by allocation — the amounts are only redistributed between the coaching and App rows. The 02b feature test `tests/Feature/RevenueAllocation/RefundNewAppRowDownstreamTest.php` asserts exactly this (the bundle PayPal total still equals N after the new App row is inserted).

---

## 5. The one real open item (data, not code) — O-A

The sender resolves a journal's account / tax / segment from `mst_rule_for_journals` and `mst_code_change`, keyed by `product_type`. The new CAP App product (10022) is `product_type = 100`.

**O-A go-live data check:** confirm `mst_rule_for_journals` / `mst_code_change` carry the rows for App `product_type = 100` so a (negative or positive) App journal resolves an account and tax side. This is a one-time master-data verification on DEV04 / production — it is **not** a code change and is shared with Spec 02a (the positive App row needs the same mapping).

---

## 6. Cross-Reference

| Document | Relevance |
|---|---|
| `accounting_related_system_for_freee/.kiro/specs/asca-spec-02b-refund-allocation/design.md` | §"impact assessment of the new App row" — this note is the code-grounded confirmation of that table |
| `accounting_related_system_for_freee/tests/Feature/RevenueAllocation/RefundNewAppRowDownstreamTest.php` | Asserts the Freee gate + PayPal sum behavior described here |
| `accounting_related_system_for_freee/.kiro/steering/glossary.md` | "ASCA & Freee" — ASCA sends no journals of its own (overwrite → existing gate) |
| `accounting_related_system_for_freee/.kiro/steering/batch-execution-flow.md` | Where allocation injects relative to the sum/Freee steps |
