# REPORT-00 — ASCI Spec 01 Requirements vs. ASCA Implementation & Kuroda-san Change Requests (Cross-check)

| | |
|---|---|
| **Document type** | Read-only investigation / findings report |
| **Date** | 2026-10-22 |
| **Author** | Kiro (investigation agent), for Noel Palo (Lead) |
| **Scope** | Validate internal correctness & consistency of the ASCI-01 requirements draft against (a) Kuroda-san change requests, (b) merged ASCA code, (c) reference/domain docs. No files edited except this report. |
| **Document under review** | `projects/asci/specs/asci-spec-01-cip-integration/requirements.md` (ASCI-01 G1 draft) |
| **ASCA repo** | `/home/bizdev/dev/accounting_related_system_for_freee` — branch **`feature/ASCA/ASCA-master-with-CAP-CIP`** (note: the brief said `feature/ASCA/ASCA-master`; the checked-out branch is the `-with-CAP-CIP` variant) |

---

## 1. Summary verdict

**Ready for G1 with two small fixes (both SHOULD-FIX, neither blocking the refund design).**

The ASCI-01 requirements draft is **substantively correct and consistent** with the authoritative sources and with how ASCA actually built the shared pieces. The refund method now reads as **one fixed ratio + one shareholder exception** (matching REF-CIP-07), every refund worked-example number re-computes exactly, the divisor is 75,900 for both Solo and lesson-bundled, day-proration is correctly described as CEIL (REF-CAP-17) while the ratio split is floor, there is no CIP AllocationDetail CSV, and the "CIP does not touch the allocation engine" claim is **verified against the actual `BundleDetectionService` / refund-path code** — a CIP charge cannot be pulled into allocation.

No **BLOCKER** was found. The two SHOULD-FIX items are documentation-accuracy nits in the price-record requirement (a mis-paired price number copied faithfully from REF-CIP-05, and a tax-incl/tax-excl label) plus a handful of NICE-TO-HAVE gaps a PM might query (contract-type/campaign interaction, the `CoachingIntensivePlanEnum` already shipped in ASCA, the "ASCA foundation complete" dependency wording given 02c is still in the branch).

Answers to the seven questions are in §4; the severity-ranked findings are in §3; the numbers that checked out are in §5.

---

## 2. What was read / verified

- **Doc under review:** ASCI-01 requirements (full).
- **Domain:** `account-types.md`, `campaigns.md`, `plans-and-products.md`.
- **Research:** REF-CIP-05, -06, -07, -08; REF-CAP-16, -17.
- **ASCA docs:** ADR-20261005 (datacorrection decommission), ADR-20261020 (drop 02c CSV), PROPOSAL-20261008 (skipped/failed bundle recording).
- **ASCA code (read):**
  - `app/Libs/RevenueAllocation/BundleDetectionService.php`
  - `app/Libs/RevenueAllocation/Formula/TwoWayAllocationFormula.php`
  - `app/Libs/RevenueAllocation/Refund/{RefundChargeDetector,RefundLinkageResolver,RefundAppRowWriter,OriginalBundleData}.php`
  - `app/Enums/RevenueAllocation/{CoachingAndAppPlanEnum,CoachingIntensivePlanEnum}.php`
  - `app/Libs/CommonUtil.php` → `getContractDateInfoList()` (day-proration) + negative branch
  - `config/const.php` → `allocationDetailFile`
  - grep for `RevenueAllocationCsvService`, `CoachingIntensivePlanEnum` usage.
- **Arithmetic:** all refund-split and residual-price figures re-computed with floor toward −∞.

---

## 3. Findings by severity

### BLOCKER
**None.**

### SHOULD-FIX

#### SF-1 — Req 1.2 mis-pairs the price_flag=2 value with the App weight "3,618"
- **Location:** Requirement 1, Acceptance Criterion 2: *"THE record SHALL NOT replace or invalidate the existing 10025 `price_flag = 2` (66,500/3,618) or `price_flag = 4` (69,000/75,900) rows."*
- **Issue:** For **product 10025**, `price_flag = 2` is **66,500 tax-excl** (per REF-CIP-06 §2.3 and plans-and-products.md). `price_flag = 4` is **69,000 tax-excl**, whose tax-incl is exactly **75,900** (69,000 × 1.1 = 75,900 — verified). So the flag-4 pair "(69,000 / 75,900)" is a coherent *tax-excl / tax-incl* pair. But the flag-2 pair "(66,500 / 3,618)" is **not** a tax-excl/tax-incl pair of one row: 66,500 tax-excl → 73,150 tax-incl, not 3,618. **3,618 is the App (10022) price_flag=2 tax-excl weight**, a different product entirely.
- **Authoritative source:** REF-CIP-06 §2.3 product table (10025 flag 2 = 66,500; 10022 flag 2 = 3,618); plans-and-products.md "ASC Allocation Reference Prices" + price_flag table.
- **Nuance (not a contradiction):** The identical "(66,500/3,618)" phrasing appears verbatim in **REF-CIP-05 §3**, where it is shorthand for "the flag-2 allocation/shareholder-refund reference row (which pairs the 66,500 coaching weight with the 3,618 app weight)." So the ASCI doc faithfully copied its source — it does not contradict REF-CIP-05. It is still confusing in a *requirements* document, because a seeder implementer reading Req 1.2 would reasonably infer that the 10025 flag-2 row holds "66,500/3,618", which it does not.
- **Recommended change:** Make the flag-2 parenthetical a single-product value and drop the App number, e.g. *"…the existing 10025 `price_flag = 2` (66,500 tax-excl, the coaching reference weight) or `price_flag = 4` (69,000 tax-excl / 75,900 tax-incl) rows."* Optionally add: "(the 3,618 App weight lives on product 10022's `price_flag = 2` row, untouched)."

#### SF-2 — Req 1.3 / glossary label "price_flag = 2 = ¥3,980" is tax-incl shorthand over a tax-excl row
- **Location:** Req 1 AC 3 (*"THE App charge SHALL use the existing `price_flag = 2` = ¥3,980 record"*) and the glossary line (*"App … ¥3,980 tax-incl (existing `price_flag = 2`)"*).
- **Issue:** The `mst_new_price_listing` App (10022) `price_flag = 2` row actually stores **3,618 tax-excl** (≈3,980 tax-incl). The booked CIP App charge amount is **3,980 tax-incl** (REF-CIP-05 §2.2). Calling the *record* "= ¥3,980" risks a reader expecting the stored column value to be 3,980.
- **Authoritative source:** REF-CIP-05 §2.2 / §4; REF-CIP-06 §2.3; plans-and-products.md reference-price table (App 10022 flag 2 = ¥3,618 tax-excl).
- **Recommended change:** State both explicitly, e.g. *"…the existing App (10022) `price_flag = 2` row (¥3,618 tax-excl ≈ ¥3,980 tax-incl); the CIP App charge books at ¥3,980 tax-incl."* This also removes any confusion between the CAP allocation weight (3,618 tax-excl) and the CIP booked amount (3,980 tax-incl).

### NICE-TO-HAVE

#### NTH-1 — "Dependencies §1: ASCA foundation complete" is optimistic given 02c is still in the branch
- **Location:** Dependencies §1 and the Introduction ("Depends on the ASCA foundation + DEV04 env").
- **Observation (code state):** The 02c **AllocationDetail CSV is still present and wired** on the checked-out branch: `RevenueAllocationCsvService.php` exists, `config/const.php` still carries `allocationDetailFile` (`{YYYYMM}_10_AllocationDetail(...).csv`), and it is still invoked from both `DailyRateCalculationPreLogic.php` (Pre) and `SendJournalsDataLogic.php` (Final). The drop decided in REF-CAP-16 / ADR-20261020 is **not yet applied to code** — consistent with the DEV04-first batching the Lead and Kuroda-san agreed. This is an **ASCA-side pending state, not an ASCI defect**; ASCI-01 is right to reference REF-CAP-16's direction. Worth a one-line note that "ASCA foundation" here means the merged engine + daily-rate path, and that the 02c CSV removal is a separate in-flight ASCA CR that does not gate ASCI.

#### NTH-2 — `CoachingIntensivePlanEnum` already exists in the ASCA repo; Req wording implies ASCI must create CIP scaffolding
- **Observation:** `app/Enums/RevenueAllocation/CoachingIntensivePlanEnum.php` (1028–1032) already ships on the branch, and the refund path already *excludes* CIP via it (`RefundLinkageResolver`: `if (CoachingIntensivePlanEnum::exists($planId) …) return null;`). ASCI can reuse this enum rather than introduce one. Not a requirements error, but a design-phase note worth capturing so ASCI doesn't duplicate it.

#### NTH-3 — Contract-type (B2B/B2E/B2B2C) handling is implicit in the refund section
- **Location:** Req 3.7 (contract overlap → no CIP refund) is present and correct, but the broader contract-type routing (REF-CIP-06 §3.7 / account-types.md: a contract-type change changes only the Freee journal target — partner/department — not the allocation amounts; summary key must include contract type) is not stated for CIP normal charges.
- **Impact:** Low for refund correctness, but a PM may ask "does a B2E/B2E-Partner CIP contract book the three charges the same way, and does the department_id/partner journal routing still apply?" A one-line statement that CIP normal charges inherit existing per-charge `contract_type`/`department_id` journal routing unchanged (no CIP special-casing) would pre-empt the question.

#### NTH-4 — First-month / campaign discount interaction stated only generically
- **Location:** Req 2.3 ("WHERE a first-month (or other) discount applies, THE discount SHALL apply per charge via the existing mechanism, with no CIP special-casing").
- **Observation:** campaigns.md documents a 50% First-Month discount (B2C **and** B2E — the "B2C only" phrasing is called out as incomplete) and other discounts that change the *paid amount* (M) vs. list-price-basis (L) treatment. Because CIP uses **no allocation engine** (books already-priced charges, each day-prorated), the L-vs-M basis distinction that matters for CAP/ASCH **does not apply to CIP** — the discount simply lowers each charge's paid_price and proration follows. Req 2.3 is therefore *correct*, but a PM reviewing against campaigns.md might want an explicit "the L-vs-M proration-basis rule is a CAP/ASCH concern and does not apply to CIP" sentence so the omission reads as deliberate, not missed.

#### NTH-5 — Shareholder refund: Req 3.4 says "capped at ¥19,800" but the cap is applied by existing admin flow, not by ASCI
- **Location:** Req 3.4 + worked-examples row ("−19,800 (interim cap)").
- **Observation:** Per REF-CIP-06 §2.5 and REF-CIP-07, the ¥19,800 cap is enforced upstream (the IR benefit page / shareholder CSV produces the already-capped negative charge); the ASCI layer just books the negative to Coaching-only without splitting. The doc already marks the cap "interim" and says not to hard-code it — good. A small clarification that ASCI **consumes** an already-capped figure (does not itself compute/apply the cap) would prevent an implementer from adding cap logic in ASCI. The "interim, final decided Nov–Dec, out of scope through December" framing matches REF-CIP-06 §3.5 and ground-truth fact #6. ✓

---

## 4. Answers to the brief's questions

### A. Do all numeric figures match the authoritative sources exactly?
**Yes, except the SF-1 price-pairing label.** Every refund figure, divisor, residual price, and worked-example total re-computes exactly (see §5). The only numeric mismatch is Req 1.2's "price_flag = 2 (66,500/**3,618**)", where 3,618 is the App weight, not part of the 10025 flag-2 row (SF-1). Note this mis-pairing is copied verbatim from REF-CIP-05 §3, so the ASCI doc is faithful to its source but still misleading in a requirements context.

### B. Does the refund-method description now match REF-CIP-07 (one fixed ratio + shareholder exception)?
**Yes — precisely.** Req 3.1, 3.5, 3.6, the "One rule, one exception" worked-examples preamble, and the Correctness-properties section all state: every non-shareholder refund (cooling-off, tax-exemption, any other Admin refund) uses App = `FLOOR(refund × 3,980 / 75,900)`, Coaching = refund − App, PHP floor toward −∞; shareholder (detected via `trn_receipt_locked_charge`) is the sole exception (Coaching only). **No residual "per-type method" language and no stray "−361" remain** — the tax-exemption case is correctly computed as `FLOOR(−361.8…) = −362` and the doc explicitly reconciles it with REF-CIP-06's per-product derivation (App −362 / Coaching −6,538). This is the corrected, authoritative shape. ✓

### C. Are product/plan IDs and price_flags consistent?
**Yes.** 10025 (Coaching Intensive), 10022 (App), 1028 (Solo), 1029–1032 (lesson-bundled) all match plans-and-products.md and REF-CIP-05 §3. price_flag usage: **2** = standalone/reference, **3** = new CIP residual booking record (65,382 tax-excl / 71,920 tax-incl), **4** = existing app-inclusive row — all consistent with plans-and-products.md's price_flag table and REF-CIP-05 §3. The one blemish is the *labeling* in SF-1, not the IDs/flags themselves.

### D. Does ASCI correctly rely on the shared ASCA pieces, and is "CIP does not touch the engine" true in code?
**Yes, verified in code — a CIP charge cannot be pulled into allocation.**
- **Positive path:** `BundleDetectionService::fetchCandidateRows()` filters candidates with `whereIn('c.plan_id', CoachingAndAppPlanEnum::toArray())` (**1016–1027 only**) and re-asserts membership in PHP via `CoachingAndAppPlanEnum::exists()` (defensive Req 2.6 guard). A CIP App charge carries the shared `product_id = 10022` **but** a CIP `plan_id` (1028–1032), which is **not** in the enum — so it is filtered out at SQL and again in PHP and **never reaches grouping or `TwoWayAllocationFormula`**. The shared App `product_id` does **not** cause accidental CIP pickup, because detection keys on `plan_id`, not on the App product id alone. This matches REF-CAP-14's requirement that CIP produce no outcome row and never appear in the CSV.
- **Refund path:** `RefundChargeDetector` only selects coaching products **10005 / 10015** (never 10025), and `RefundLinkageResolver::resolveOriginalBundle()` explicitly returns null for CIP originals: `if (CoachingIntensivePlanEnum::exists($planId) || ! CoachingAndAppPlanEnum::exists($planId)) return null;` with the comment "CIP refunds are handled separately, on hold." So the **ASCA 02b refund split does not cover CIP** — the CIP refund split is genuinely unimplemented in shared code and correctly owned by ASCI-01 (supports the Decision-1 request).
- **Shared pieces ASCI leans on that DO exist:** the existing day-proration entry point `CommonUtil::getContractDateInfoList()` / `createDailyRateCalculation()`; the negative-charge single-lump-in-paid_at-month branch; and the existing DailyRateCalculation CSV. All present and behave as the doc assumes.
- **Caveat for the design phase (not a requirements defect):** ASCI's refund split is **net-new code**; it reuses the *pattern* and the `log_refund_history`/`RefundAppRowWriter` *style* of 02b but not its CAP-scoped detector (which hard-excludes CIP). The doc's Dependencies §1 phrase "the CAP refund design (02b) only *parallels* the rule, it does not own it" is accurate.

### E. Any requirement contradicting the latest Kuroda-san change requests?
**No contradictions.**
- **REF-CAP-16 (drop AllocationDetail CSV):** ASCI-01 references no CIP AllocationDetail CSV and states CIP amounts appear in the existing DailyRateCalculation CSV (Req 2.4). ✓ (The ASCA code still *contains* the CSV, but that is the pending ASCA removal CR — see NTH-1 — not an ASCI contradiction.)
- **REF-CIP-07 / -08 (refund rules):** fully reflected (see B). Divisor 75,900 for Solo and bundled; Lesson always separate on its own charge; shareholder Coaching-only. ✓
- **REF-CAP-17 (CEIL proration):** Req 2.1 states CEIL on every month except the last (remainder), explicitly "NOT floor," and keeps the ratio split on floor. Verified against `CommonUtil::getContractDateInfoList()` (`ceil($paidPrice / $totalContractDay * $contractDay)`; last month = `$paidPrice - $tempPaidPrice`). The doc does **not** confuse the CEIL (proration) and floor (ratio) rules. ✓

### F. Any account-type / campaign interaction missed?
**Minor, non-blocking (NTH-3, NTH-4).** The refund section correctly handles the contract-overlap "no refund" case (Req 3.7, REF-CIP-06 §3.7/§3.8). What is only implicit: (1) that CIP normal-charge journal routing for B2B/B2E/B2E-Partner follows existing per-charge `contract_type`/`department_id` with no CIP special-casing; (2) that the campaign L-vs-M proration-basis rule (campaigns.md Honki Set / ASCH) is a CAP/ASCH concern that does **not** apply to CIP because CIP books already-priced charges with no allocation basis. Both are arguably correct-by-omission, but stating them removes predictable PM questions.

### G. Gaps/ambiguities a PM would reasonably reject at G1?
Unlikely to reject, but likely to **comment on**: SF-1 (the "66,500/3,618" pairing will read as an error to a careful reviewer), SF-2 (the "= ¥3,980" over a 3,618 tax-excl row), and the implicit contract-type/campaign statements (NTH-3/4). None of these block the refund design, which is the substantive core and is correct. Recommend fixing SF-1 and SF-2 before submission and adding one sentence each for NTH-3/NTH-4; the rest can be design-phase notes.

---

## 5. Numbers verified correct (checked and passed)

Re-computed with floor toward −∞ (PHP `floor` semantics) and tax factor 1.1:

| Item | Doc value | Re-computed | Result |
|---|---|---|---|
| Residual CI booking (tax-incl) | 71,920 = 75,900 − 3,980 | 71,920 | ✓ |
| Residual CI booking (tax-excl) | 65,382 | 71,920 / 1.1 = 65,381.8 ≈ 65,382; 65,382 × 1.1 = 71,920.2 | ✓ |
| App weight tax-excl ↔ tax-incl | 3,618 ≈ 3,980 | 3,618 × 1.1 = 3,979.8; 3,980 / 1.1 = 3,618.2 | ✓ |
| 10025 price_flag 4 tax-excl ↔ incl | 69,000 / 75,900 | 69,000 × 1.1 = 75,900.0 | ✓ |
| Cooling-off CI negative | −68,310 = 75,900 × 90% | 68,310.0 | ✓ |
| Cooling-off → App | −3,582 | FLOOR(−68,310 × 3,980 / 75,900) = FLOOR(−3,582.0) = −3,582 | ✓ |
| Cooling-off → Coaching | −64,728 | −68,310 − (−3,582) = −64,728 | ✓ |
| Tax-exemption CI negative | −6,900 | −6,900 | ✓ |
| Tax-exemption → App | −362 | FLOOR(−6,900 × 3,980 / 75,900) = FLOOR(−361.818) = −362 | ✓ |
| Tax-exemption → Coaching | −6,538 | −6,900 − (−362) = −6,538 | ✓ |
| Tax-exemption per-product cross-check | App 362 / Coaching 6,538 | 3,980 − 3,618 = 362; 71,920 − 65,382 = 6,538 | ✓ (agrees with ratio) |
| 1029 Lesson cooling-off | −13,365 = 14,850 × 90% | 13,365.0 | ✓ |
| 1029 cooling-off grand total | −81,675 | −13,365 + −68,310 = −81,675 | ✓ |
| 1029 Lesson tax-exemption | −1,350 = 14,850 − 13,500 | 1,350 | ✓ |
| Shareholder | −19,800 Coaching only, App 0 | per REF-CIP-07 | ✓ |
| Divisor invariance (Solo & bundled) | 75,900 | REF-CIP-08 (Coaching+App portion) | ✓ |

**Rule shapes verified:** one fixed ratio + shareholder exception (REF-CIP-07) ✓; day-proration CEIL vs ratio floor not confused (REF-CAP-17 + `CommonUtil`) ✓; no CIP AllocationDetail CSV (REF-CAP-16) ✓; CIP excluded from the allocation engine in code (`BundleDetectionService`, `RefundLinkageResolver`) ✓; price_flag 3 record additive, does not replace flag 2/4 (REF-CIP-05 §3) ✓.

> Compliance note: quoted doc/code fragments are short identifiers and ≤ a few words; all substantive content is paraphrased.

---

## 6. Recommendations (implement nothing — for the Lead/PM to action)

1. **Fix SF-1** in Req 1.2: make the `price_flag = 2` parenthetical a single-product value (66,500 tax-excl) and move/footnote the 3,618 as the *App* (10022) weight. (Consider flagging the same phrasing in REF-CIP-05 §3 as a source clarification, though that file is a verbatim source and should not be edited.)
2. **Fix SF-2** in Req 1.3 / glossary: label the App `price_flag = 2` row as 3,618 tax-excl ≈ 3,980 tax-incl, and state the booked CIP App charge = 3,980 tax-incl.
3. Add one sentence each for **NTH-3** (CIP contract-type journal routing unchanged) and **NTH-4** (L-vs-M basis is CAP/ASCH-only, N/A to CIP) to pre-empt PM questions.
4. Note in Dependencies (**NTH-1**) that the ASCA 02c CSV removal is a separate in-flight ASCA CR and does not gate ASCI; and (**NTH-2**) that `CoachingIntensivePlanEnum` already exists in the ASCA repo for reuse in design.
5. Leave the price_flag=3 seeder repo placement as the stated G2/design decision (ground-truth fact #7 — correct as-is, do not treat as a gap).

**Bottom line:** the ASCI-01 refund logic — the risky, previously-churned part — is now correct and internally consistent, verified both arithmetically and against the live ASCA code that proves CIP never enters the allocation engine. Fix the two price-label nits and it is G1-ready.
