# Requirements Document

**ASCA Spec 02b — Refund Allocation**

> **Staging note:** Dev-context draft, **Round-3 — submitted for PM sign-off (Kuroda-san)**. Round-1 (REF-CAP-12) and Round-2 (REF-CAP-13) feedback are folded in; Kuroda-san's Round-2 note said 02b is "good to go once the minor cleanups are done" — those cleanups are applied here. On sign-off it is promoted to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02b-refund-allocation/requirements.md` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do not begin design/tasks until sign-off.
>
> **Reviewer note:** The G1 blocker (refund→bundle pairing) is resolved in Req 9 (REF-CAP-13 #1). Remaining open items are the interim shareholder cap (¥19,800, O-R1) and a couple of design-phase confirmations — none blocking sign-off. The CIP refund split is out of scope here (on hold, see Scope).

## Introduction

This spec extends CAP allocation to **refund (negative-amount) charges**. It is the **second of four Spec 02 sub-specs** (02a Core Injection → **02b Refund** → 02c AllocationDetail CSV → 02d DataCorrection) and builds directly on 02a's injected path.

The rule, per REF-CAP-09, is deliberately simple: a refund is **the same allocation, with a negative N**. There is no separate refund formula and no separate pipeline — the negative charge enters the same entry point as a positive charge, is split by the same weight ratio, and is written back the same way. The only behaviours that need explicit statement are the ones unique to negatives: a true mathematical floor toward −∞, recognition as a single lump in the refund's execution month (never spread back to the original recognition months), and correct handling of the specific refund scenarios accounting issues.

**Scope: CAP only.** Per REF-CIP-05, CIP regular charges do not use the allocation engine. **CIP _refunds_, however, ARE split by a fixed per-type rule (REF-CIP-06 / REF-CIP-07) — the CIP refund split is handled separately and is on hold pending its home decision; it is out of scope here.** This sub-spec is CAP-only. The earlier REF-CAP-09 §10/R-16 "CIP 3-way refund" is not implemented (superseded by REF-CIP-05/06).

### Design decisions (confirmed — from REF-CAP-09, normative)

- **R-01 — one algorithm for +/−.** `P_app = floor(N × L_app / (L_coaching + L_app))`, `P_coaching = N − P_app`. Same formula, same pipeline as positive charges. App rounded with floor; Coaching absorbs the residual so `P_app + P_coaching = N` exactly in integer yen.
- **True floor toward −∞** for negatives (e.g. `floor(-3.2) = -4`). MUST NOT truncate toward zero via `intval()` / `(int)` cast. (Same floor semantics fixed in Spec 01's `TwoWayAllocationFormula`; 02b exercises them on negative N.)
- **Per-charge allocation (R-01, R-12).** Each charge uses its own product price and result; monthly totals are the sum of charge-level results. A month with more than one charge NEVER uses one combined monthly ratio.
- **R-03 / R-07 — execution-month lump.** A negative refund charge is recognized in **its execution month** (the calendar month of its `paid_at`) as one negative amount. It is NOT day-prorated by the allocation layer and is NOT spread back to the months where the original revenue was recognized — even when the original charge spanned several months. (This differs from the old ASCH "prorate with the original ratio" cross-month rule; the contract-lifetime total is unchanged.)
- **R-04 — fixed/capped refunds.** Full refund, **cooling-off (90% refund — a 10% fee is retained)**, consumption-tax exemption, and shareholder-benefit cashback use the negative charge amount as delivered by the existing refund process — the allocation layer applies no further day-proration. (Corrected per REF-CAP-13 §2 / REF-CIP-06 §3.3: there is no separate "cooling-off 10%" refund; cooling-off is a 90% refund.)
- **R-14 / R-15 — shareholder cashback.** The bulk-CSV process creates a negative `trn_charge` cloned from the original; the allocation layer consumes that negative charge directly and does NOT parse the CSV. For **CAP**, the cashback negative is split Coaching/App by the formula like any other negative. Only the Bizmates Coaching cashback line is in scope (the ¥0 App has no separate shareholder refund line). The ¥19,800 cap is **applied upstream** by Accounting (see Req 5.3); the allocation layer takes the delivered negative as-is. A single `transaction_id` may span multiple CSV rows (lesson + coaching) — each row resolves to its own original charge; rows are NOT summed by shared `transaction_id`; only the Coaching portion enters allocation (the lesson portion stays on the existing ASC path). (CIP shareholder cashback is Coaching-only — REF-CIP-06 §3.5 — noted for when CIP refunds are added; out of scope here.)
- **R-07 — write atomicity.** The Coaching and App results are written as one unit; a mid-way failure must not leave one side updated and the other not. A failed pair is reported and retriable but does not block unrelated CAP records.
- **R-13 — contract-type change.** Allocation amounts are unchanged; the reporting/summary key must carry the applicable contract type so the correct Freee partner and department are used.

### Dependencies

- **02a (CAP Core Injection) merged** — 02b allocates negatives through the same injected path; it does not add a second injection.
- **Spec 01 Foundation merged** — the engine, `TwoWayAllocationFormula` (true floor), reference prices, run lifecycle, and audit tables. 02b adds negative-N behaviour and scenario handling at the requirements level; the split math already exists.
- **Existing ASC refund path** produces the execution-month negative charge (R-09): `CommonUtil::getContractDateInfoList()`'s negative-price branch recognizes negatives in the `paid_at` month without day-proration. 02b depends on that and only adds the Coaching/App split.

### Out of scope (explicit)

- **CIP refunds** — the CIP refund split (fixed per-type rule, REF-CIP-06 / REF-CIP-07) is **handled separately and is on hold** pending its home decision (extend 02b / new sub-spec / ASCI). Out of scope here. (This is CAP-only; CIP regular charges use no engine per REF-CIP-05, but CIP refunds ARE split — not "no split".)
- **The AllocationDetail CSV** (which will surface refund rows) → Spec 02c.
- **DataCorrection-driven refunds** → not applicable: 02d is now a **decommission** of `DataCorrectionCommand` (the command is confirmed unused), not an allocation injection. No refund handling is added there.
- **Reversal (record_kind = 2)** — a post-release Phase 4 item, not 02b.
- **Changing how existing ASC decides whether/when a charge is recognized** — only the split of an already-recognized amount is in scope.

**Reference:** `research/CAP/REF-CAP-09-Refund-Allocation-Requirements-20260908.md` (normative, verbatim); technical design §4 (formula, negatives); Spec 01 `TwoWayAllocationFormula` (floor semantics).

## Glossary

- **N (refund month)** — the amount existing ASC recognizes for one in-scope charge in the target month; **negative** for a refund charge.
- **Execution month** — the calendar month containing the refund charge's `paid_at`.
- **Fixed/capped refund** — full, cooling-off (90% refund, 10% fee retained), tax-exemption, or shareholder cashback; amount fixed/capped before allocation.
_(The "Overlap refund" entry was removed per REF-CAP-13 §2 / REF-CIP-06 §2.4/§3.8: a contract overlap does not produce a refund.)_
- **Shareholder cashback** — a cloned negative Coaching charge from the bulk-CSV process. Only the **Coaching cashback line** enters CAP allocation (and for CAP it is split Coaching/App by the formula); the cap (¥19,800) is applied upstream by Accounting. (REF-CAP-13 §3 — "Coaching cashback line only", not "Coaching-only"; CIP shareholder is Coaching-only but that is out of scope here.)

---

## Requirements

### Requirement 1: One algorithm for positive and negative amounts

**User Story:** As accounting, I need refunds split by the same rule as normal charges so that revenue apportionment is consistent and reconciles over a contract's life.

#### Acceptance Criteria

1. THE system SHALL allocate a negative-N charge using the same formula and the same pipeline as a positive charge: `P_app = floor(N × L_app / (L_coaching + L_app))`, `P_coaching = N − P_app`.
2. THE system SHALL NOT use a separate refund formula or a separate allocation pipeline.
3. THE `floor()` SHALL be a true mathematical floor toward −∞ (e.g. `floor(-3.2) = -4`) and SHALL NOT truncate toward zero via `intval()` / `(int)` cast.
4. THE system SHALL guarantee `P_app + P_coaching = N` exactly in integer yen for negative N (Coaching absorbs the residual), just as for positive N.
5. THE system SHALL allocate per charge; WHEN more than one charge exists in a month, each SHALL use its own product price and result, and the monthly total SHALL be the sum of the charge-level results (never one combined monthly ratio).

### Requirement 2: Execution-month recognition (no spread-back, no re-proration)

**User Story:** As accounting, I need a refund booked once in the month it was executed so that the ledger matches the refund process and the contract-lifetime total stays correct.

#### Acceptance Criteria

1. THE system SHALL recognize a negative refund charge in its **execution month** (the `paid_at` month) as one negative amount.
2. THE system SHALL NOT day-prorate the negative refund charge in the allocation layer.
3. THE system SHALL NOT spread the negative back into the months where the original revenue was recognized, EVEN IF the original charge spanned several months.
4. WHERE a contract started mid-month, THIS SHALL NOT change the execution-month rule for a fixed/capped refund.
5. WHEN a cross-month cooling-off refund is executed in a later month, THE whole negative SHALL be posted once in the execution month and split Coaching/App there; the contract-lifetime net SHALL equal the retained amount (a month may show a net negative).

### Requirement 3: Fixed and capped refunds

**User Story:** As accounting, I need fixed/capped refund amounts taken as delivered so that the allocation layer does not double-adjust them.

#### Acceptance Criteria

1. WHEN the refund is a full refund, **cooling-off (90% refund — 10% fee retained)**, consumption-tax exemption, or shareholder-benefit cashback, THE system SHALL use the negative charge amount delivered by the existing refund process. (Corrected per REF-CAP-13 §2: there is no "cooling-off 10%" refund type.)
2. THE system SHALL NOT calculate any further day-proration for those fixed/capped amounts.
3. THE cooling-off refund SHALL be a **90% refund** (the customer is refunded 90% of the applicable paid amount; a 10% fee is retained), represented as the negative delivered by the existing refund process, then split by R-01.
4. THE consumption-tax-exemption refund SHALL be taken as the negative delivered by the existing Admin Refund flow, then split by R-01 (no allocation-layer recomputation).

### ~~Requirement 4: Contract-overlap refunds (B2C/B2E → B2B)~~ — REMOVED (REF-CAP-13 §2)

> **Removed per REF-CAP-13 §2 / REF-CIP-06 §2.4/§3.8 (corrected 2026-09-28):** a contract overlap (B2C/B2E → B2B) does **not** produce a refund or negative charge. There is therefore no "overlap refund" for the allocation layer to handle. The former Req 4, the R-05/R-11 Confirmed Decision, and the "Overlap refund" glossary entry have been removed. (Requirement number retained as a tombstone to avoid renumbering the later requirements and their cross-references.)

### Requirement 5: Shareholder-benefit cashback

**User Story:** As accounting, I need shareholder cashbacks split on the Coaching line only, capped, and resolved per original charge so that the numbers match the benefit rules.

#### Acceptance Criteria

1. THE system SHALL consume the cloned negative `trn_charge` created by the shareholder-benefit bulk-CSV process directly, and SHALL NOT parse the CSV as an allocation input.
2. THE system SHALL include only the Bizmates Coaching cashback line in CAP allocation; the ¥0 App companion SHALL NOT create a separate shareholder-benefit App refund line.
3. THE ¥19,800 cashback cap SHALL be **applied upstream** by Accounting — Accounting sets `refund_price` in the shareholder CSV under the benefit rule, and the upload itself only blocks totals above the original paid amount (`addbycsv.php` L245–258). THE allocation layer SHALL use the delivered negative **as-is** and SHALL NOT re-apply the cap (a warning log at most if a value looks out of range). (Clarified per REF-CAP-13 §3.)
4. WHERE a single `transaction_id` appears in multiple CSV rows, THE system SHALL resolve each row to its own original charge and SHALL NOT sum rows solely because they share a `transaction_id`.
5. THE system SHALL route only the Coaching portion into CAP allocation; the lesson portion SHALL remain on the existing ASC path.

### Requirement 6: Write atomicity and failure isolation for refund pairs

**User Story:** As an operator, I need refund writes to be all-or-nothing per pair so that a partial write can't corrupt the split.

#### Acceptance Criteria

1. THE system SHALL write the Coaching and App allocation results for a refund as one atomic unit; a mid-way failure SHALL NOT leave one side updated and the other not (roll back or complete both).
2. IF one charge pair fails, THEN THE failure SHALL be reported and the pair SHALL be retriable, AND it SHALL NOT block unrelated CAP records from processing.
3. THE negative refund charge SHALL enter the same allocation entry point as positive charges, distinguished by an explicit record attribute (record kind / equivalent), not by a separate code path. **IF a `record_kind` value is used to mark refunds, it SHALL NOT use the value `2`** — that value is reserved for reversal (a post-release Phase 4 item). (Per REF-CAP-13 §3.)

### Requirement 7: Contract-type change and reporting key

**User Story:** As accounting, I need contract-type changes to keep amounts but route to the right Freee dimensions so that partner/department reporting is correct.

#### Acceptance Criteria

1. WHEN a contract-type change occurs, THE allocation amounts SHALL be unchanged.
2. THE reporting/summary key SHALL include the applicable contract type so the correct Freee partner and department are used.

### Requirement 8: Audit and reproducibility for negatives

**User Story:** As an auditor, I need refund allocations captured with the same audit trail as positive allocations so that a refund month is reproducible.

#### Acceptance Criteria

1. THE audit record SHALL retain, for each in-scope refund charge: target month, charge identifier, product identifier, contract type where available, original recognized N (negative), applied weights, and allocated P_app / P_coaching. (Persistence tables are Spec 01; 02b asserts negatives are captured the same way.)
2. WHEN a refund month is re-run, THE system SHALL produce identical P values (N invariant), consistent with the idempotency guarantee in 02a.

### Requirement 9: Refund charge → bundle pairing (was G1 blocker — RESOLVED, REF-CAP-13 #1)

**User Story:** As the allocation engine, I need to know which original bundle a refund charge belongs to so that I can find the App companion and write P_app correctly.

> ✅ **Resolved by Kuroda-san (REF-CAP-13 #1, 2026-10-05).** The direction below is confirmed. This was the Round-1 G1 blocker.

#### Background (the two failing cases)

A refund charge is a clone of the original coaching charge — it keeps `start_date`/`end_date`/`order_no`/`plan_id`; only `paid_price`, `paid_at`, and `transaction_id` change. The standard pairing rule (match coaching + app by `start_date` AND `end_date`) fails for refunds in two cases:

- **(i) Same-month refund:** the original contract still covers the execution month — existing coaching (+) and app (+) rows are already there. Naively, the execution month then has 2 coaching rows (+/−) and 1 App row, failing the 1+1 check and skipping the whole bundle including that month's normal allocation.
- **(ii) Later-month refund:** the contract period has ended — no App row exists in the execution month, so pairing fails and there is no log row to write P_app into.

#### Confirmed direction (REF-CAP-13 #1)

- **① Linkage — `log_refund_history`.** A refund charge is linked to its original via `log_refund_history` (`refunded_charge_id` → `refund_charge_id`). Every refund path writes this row: `libs/prorated.php:243`, `shareholderrefund/addbycsv.php:294`, `controller/api/student.php`. The engine resolves the refund's original coaching charge (and thus its bundle) through this table, NOT through date/`order_no` matching.
- **② 1+1 interaction — refunds are excluded from normal grouping.** Refund (negative) charges are excluded from the normal bundle-grouping/1+1 cardinality check and are allocated on their own via the linkage. Therefore the normal (positive) allocation for the execution month is **never skipped** by the presence of a refund (fixes case i).
- **③ Where negative P_app is written — a new App log row in the execution month.** For both cases, THE system SHALL **insert a new App log row** in the execution month carrying the negative `P_app`. (This is required for case ii where no App row exists, and is used in case i as well for consistency.)
- **④ R-12 — never net.** A positive and a negative charge are NEVER netted; each is allocated independently.
- **CIP reuse:** the CIP refund split (REF-CIP-06) also needs an App-side row in the execution month, so this new-App-row mechanism SHALL be designed so CIP refunds can reuse it later.

#### Acceptance Criteria

1. THE system SHALL link a refund charge to its original bundle via `log_refund_history` (`refunded_charge_id` → `refund_charge_id`), not via date/`order_no` matching.
2. THE system SHALL exclude refund (negative) charges from the normal bundle-grouping / 1+1 cardinality check, so a refund never causes the execution month's normal (positive) allocation to be skipped (case i).
3. THE system SHALL insert a **new App log row** in the refund's execution month to carry the negative `P_app`, in both case (i) and case (ii), so that `P_coaching + P_app = N` (negative N) holds even when no App row previously existed in that month.
4. THE system SHALL NOT net a positive and negative charge for the same bundle; each SHALL be allocated independently (R-12).
5. THE new-App-row mechanism SHALL be designed so a CIP refund (REF-CIP-06), which also needs an execution-month App-side row, can reuse it later.
6. THE system SHALL include acceptance tests for both the same-month refund case (i) and the later-month refund case (ii).

#### Impact of the new App log row (to assess in design — REF-CAP-13 #1 ③)

Inserting a new App row in the execution month is a new row the existing pipeline hasn't seen before. Design MUST assess and document the impact on:

- **Existing CSVs** (DailyRateCalculation, CalculationSummary) — a new App line appears in the refund month.
- **Freee sender** — the negative App row must route to the correct App journal (the `paid_price != 0` gate now sees a negative, not zero).
- **PayPal payment sums** — confirm the new row does not distort `createPaypalPaymentFile` / `...SumFile` aggregates.
- **02c AllocationDetail CSV** — the refund App row surfaces as a `row_kind = refund` line.

### Requirement 10: Numeric acceptance cases (CAP 15min — REF-CAP-13 §3)

**User Story:** As a reviewer, I need concrete worked examples so that the refund split is testable against exact expected yen values.

#### Acceptance Criteria

For CAP 15-minute coaching (reference weights **L_coaching = 18,000 : L_app = 3,618**), the engine SHALL produce these exact splits (App = `floor(N × 3,618 / 21,618)`, Coaching = `N − P_app`):

| Case | N (negative) | Expected P_app | Expected P_coaching |
|---|---|---|---|
| Cooling-off (90% of 22,550) | −20,295 | **−3,397** | **−16,898** |
| Tax exemption (22,550 × 10/110) | −2,050 | **−344** | **−1,706** |
| Shareholder cashback | −19,800 | **−3,314** | **−16,486** |

1. THERE SHALL be acceptance tests asserting each of the three rows above (exact integer yen, true floor toward −∞).
2. Each case SHALL confirm `P_app + P_coaching = N`.

## Confirmed Decisions (settled — for the approver's reference)

| # | Decision | Source |
|---|---|---|
| R-01 | Same formula + pipeline for +/−; true floor toward −∞; `ΣP = N` | REF-CAP-09 |
| R-03/R-07 | Execution-month lump; no spread-back; no re-proration | REF-CAP-09; Accounting signed off |
| R-04 | Fixed/capped refunds taken as delivered; cooling-off = 90% refund (10% fee) — no "cooling-off 10%" type | REF-CAP-09; corrected REF-CAP-13 §2 |
| ~~R-05/R-11~~ | ~~Overlap refund~~ — **REMOVED**: a contract overlap produces no refund | REF-CAP-13 §2 / REF-CIP-06 §2.4/§3.8 |
| R-12 | Per-charge, never one combined monthly ratio; never net +/− | REF-CAP-09 |
| R-14/R-15 | Cashback: consume cloned negative; CAP split Coaching/App; cap applied upstream (not re-capped) | REF-CAP-09; REF-CAP-13 §3 |
| Refund pairing | Link via `log_refund_history`; exclude from normal grouping; new App row in execution month | REF-CAP-13 #1 |
| Scope | CAP only; CIP refunds use no engine for regular charges (refund split on hold) | REF-CIP-05; REF-CIP-06 |

## Open Items (for the approver)

| # | Item | Status / ask |
|---|---|---|
| ~~O-G1-1~~ ✅ | **RESOLVED (REF-CAP-13 #1).** Refund→bundle pairing is now specified in Req 9: link via `log_refund_history`, exclude refunds from normal grouping, insert a new App log row in the execution month for negative P_app, R-12 no-netting, tests for (i)+(ii), designed for CIP reuse. Design must assess the new-App-row impact on CSVs / Freee / PayPal sums / 02c. |
| O-R1 | **Shareholder cashback cap for CAP/CIP** — new CAP/CIP-specific cap amounts are under executive discussion; until decided, proceed with the existing **¥19,800** coaching cap. | Confirm we implement against ¥19,800 for now (REF-CAP-09 open item, owner Kuroda-san). |
| O-R2 | **Post-refund recognition of the original positive charge** (non-blocking) — the reconciliation assumes existing ASC keeps recognizing the original positive charge's remaining days after a cooling-off refund, so the refund-month net self-corrects later. | Engineering to confirm existing ASC does not truncate the positive charge on cooling-off (owner: Engineering / Miyaji-san). Accounting accepted proceeding on this basis. |
| ~~O-R3~~ ✅ | **CLOSED (REF-CAP-13 §3).** Req 3.4 already states the Admin Refund negative is used as delivered — no allocation-layer recomputation of the tax-exemption amount is needed. |
| O-R4 | **Record-kind / attribute** used to mark a negative refund charge at the entry point. | Design-phase detail; confirm the explicit attribute exists on `trn_charge` (or equivalent) so positives/negatives share one path. Non-blocking for sign-off. |
