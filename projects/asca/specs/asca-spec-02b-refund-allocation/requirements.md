# Requirements Document

**ASCA Spec 02b — Refund Allocation**

> **Staging note:** Dev-context draft pending PM sign-off (Kuroda-san, G1). On approval it is promoted to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02b-refund-allocation/requirements.md` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do not begin design/tasks from this draft.
>
> **Reviewer note:** This is the risk-carrying sub-spec — REF-CAP-09 is the normative source and still has one open item (the CAP/CIP-specific shareholder cap, under executive discussion). Please confirm the Open Items table.

## Introduction

This spec extends CAP allocation to **refund (negative-amount) charges**. It is the **second of four Spec 02 sub-specs** (02a Core Injection → **02b Refund** → 02c AllocationDetail CSV → 02d DataCorrection) and builds directly on 02a's injected path.

The rule, per REF-CAP-09, is deliberately simple: a refund is **the same allocation, with a negative N**. There is no separate refund formula and no separate pipeline — the negative charge enters the same entry point as a positive charge, is split by the same weight ratio, and is written back the same way. The only behaviours that need explicit statement are the ones unique to negatives: a true mathematical floor toward −∞, recognition as a single lump in the refund's execution month (never spread back to the original recognition months), and correct handling of the specific refund scenarios accounting issues.

**Scope: CAP only.** Per REF-CIP-05, CIP does not use the allocation engine (it books separate, already-priced charges), so CIP refunds are out of scope here — a CIP refund is simply a negative charge on an already-priced CIP line, pro-rated by the existing logic, with no split. The earlier REF-CAP-09 §10/R-16 "CIP 3-way refund" is therefore not implemented.

### Design decisions (confirmed — from REF-CAP-09, normative)

- **R-01 — one algorithm for +/−.** `P_app = floor(N × L_app / (L_coaching + L_app))`, `P_coaching = N − P_app`. Same formula, same pipeline as positive charges. App rounded with floor; Coaching absorbs the residual so `P_app + P_coaching = N` exactly in integer yen.
- **True floor toward −∞** for negatives (e.g. `floor(-3.2) = -4`). MUST NOT truncate toward zero via `intval()` / `(int)` cast. (Same floor semantics fixed in Spec 01's `TwoWayAllocationFormula`; 02b exercises them on negative N.)
- **Per-charge allocation (R-01, R-12).** Each charge uses its own product price and result; monthly totals are the sum of charge-level results. A month with more than one charge NEVER uses one combined monthly ratio.
- **R-03 / R-07 — execution-month lump.** A negative refund charge is recognized in **its execution month** (the calendar month of its `paid_at`) as one negative amount. It is NOT day-prorated by the allocation layer and is NOT spread back to the months where the original revenue was recognized — even when the original charge spanned several months. (This differs from the old ASCH "prorate with the original ratio" cross-month rule; the contract-lifetime total is unchanged.)
- **R-04 — fixed/capped refunds.** Full refund, full cooling-off, cooling-off 10%, consumption-tax exemption, and shareholder-benefit cashback use the negative charge amount as delivered by the existing refund process — the allocation layer applies no further day-proration.
- **R-05 / R-11 — contract-overlap refunds.** When a B2C/B2E contract and a B2B contract overlap, the individual charge is still recognized in full for the month by existing ASC; the overlap refund is a **separate** negative charge whose amount is determined by the overlapping days under the existing prorated-refund flow. The allocation layer allocates that negative independently in its execution month and does NOT re-prorate it.
- **R-14 / R-15 — shareholder cashback.** The bulk-CSV process creates a negative `trn_charge` cloned from the original; the allocation layer consumes that negative charge directly and does NOT parse the CSV. Only the Bizmates Coaching cashback line is in scope (the ¥0 App has no separate shareholder refund line). Coaching cashback is capped at **¥19,800** (against `product_type = 9`). A single `transaction_id` may span multiple CSV rows (lesson + coaching) — each row resolves to its own original charge; rows are NOT summed by shared `transaction_id`; only the Coaching portion enters allocation (the lesson portion stays on the existing ASC path).
- **R-07 — write atomicity.** The Coaching and App results are written as one unit; a mid-way failure must not leave one side updated and the other not. A failed pair is reported and retriable but does not block unrelated CAP records.
- **R-13 — contract-type change.** Allocation amounts are unchanged; the reporting/summary key must carry the applicable contract type so the correct Freee partner and department are used.

### Dependencies

- **02a (CAP Core Injection) merged** — 02b allocates negatives through the same injected path; it does not add a second injection.
- **Spec 01 Foundation merged** — the engine, `TwoWayAllocationFormula` (true floor), reference prices, run lifecycle, and audit tables. 02b adds negative-N behaviour and scenario handling at the requirements level; the split math already exists.
- **Existing ASC refund path** produces the execution-month negative charge (R-09): `CommonUtil::getContractDateInfoList()`'s negative-price branch recognizes negatives in the `paid_at` month without day-proration. 02b depends on that and only adds the Coaching/App split.

### Out of scope (explicit)

- **CIP refunds** — CIP uses no engine (REF-CIP-05); a CIP refund is a negative on an already-priced line, handled by existing pro-ration. No 3-way refund.
- **The AllocationDetail CSV** (which will surface refund rows) → Spec 02c.
- **DataCorrection-driven refunds** → Spec 02d (scoped `allocateForCharge()`).
- **Reversal (record_kind = 2)** — a post-release Phase 4 item, not 02b.
- **Changing how existing ASC decides whether/when a charge is recognized** — only the split of an already-recognized amount is in scope.

**Reference:** `research/CAP/REF-CAP-09-Refund-Allocation-Requirements-20260908.md` (normative, verbatim); technical design §4 (formula, negatives); Spec 01 `TwoWayAllocationFormula` (floor semantics).

## Glossary

- **N (refund month)** — the amount existing ASC recognizes for one in-scope charge in the target month; **negative** for a refund charge.
- **Execution month** — the calendar month containing the refund charge's `paid_at`.
- **Fixed/capped refund** — full, cooling-off, cooling-off 10%, tax-exemption, or shareholder cashback; amount fixed/capped before allocation.
- **Overlap refund** — a refund whose amount comes from the overlapping days when a B2C/B2E and a B2B contract cover the same period.
- **Shareholder cashback** — a cloned negative Coaching charge from the bulk-CSV process; Coaching-only, capped at ¥19,800.

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

1. WHEN the refund is a full refund, full cooling-off, cooling-off 10%, consumption-tax exemption, or shareholder-benefit cashback, THE system SHALL use the negative charge amount delivered by the existing refund process.
2. THE system SHALL NOT calculate any further day-proration for those fixed/capped amounts.
3. THE cooling-off 10% refund SHALL be represented as a negative equal to 10% of the applicable paid amount (as delivered), then split by R-01.
4. THE consumption-tax-exemption refund SHALL be taken as the negative delivered by the existing Admin Refund flow, then split by R-01 (no allocation-layer recomputation).

### Requirement 4: Contract-overlap refunds (B2C/B2E → B2B)

**User Story:** As accounting, I need overlap refunds allocated independently in their execution month so that the individual and corporate recognitions net correctly.

#### Acceptance Criteria

1. THE system SHALL treat the overlap refund as a separate negative charge, NOT as a reduction of the in-month recognition of the individual charge.
2. THE overlap refund amount SHALL be the one determined by the existing prorated-refund flow (overlapping days); the allocation layer SHALL NOT re-prorate it.
3. THE system SHALL allocate both the full positive charge and the negative refund charge independently by R-01, each in its respective month; the bundle's net for the month SHALL be their sum.

### Requirement 5: Shareholder-benefit cashback

**User Story:** As accounting, I need shareholder cashbacks split on the Coaching line only, capped, and resolved per original charge so that the numbers match the benefit rules.

#### Acceptance Criteria

1. THE system SHALL consume the cloned negative `trn_charge` created by the shareholder-benefit bulk-CSV process directly, and SHALL NOT parse the CSV as an allocation input.
2. THE system SHALL include only the Bizmates Coaching cashback line in CAP allocation; the ¥0 App companion SHALL NOT create a separate shareholder-benefit App refund line.
3. THE Coaching cashback SHALL be capped at ¥19,800 (applied against `product_type = 9`), regardless of which price record the coaching charge's amount came from.
4. WHERE a single `transaction_id` appears in multiple CSV rows, THE system SHALL resolve each row to its own original charge and SHALL NOT sum rows solely because they share a `transaction_id`.
5. THE system SHALL route only the Coaching portion into CAP allocation; the lesson portion SHALL remain on the existing ASC path.

### Requirement 6: Write atomicity and failure isolation for refund pairs

**User Story:** As an operator, I need refund writes to be all-or-nothing per pair so that a partial write can't corrupt the split.

#### Acceptance Criteria

1. THE system SHALL write the Coaching and App allocation results for a refund as one atomic unit; a mid-way failure SHALL NOT leave one side updated and the other not (roll back or complete both).
2. IF one charge pair fails, THEN THE failure SHALL be reported and the pair SHALL be retriable, AND it SHALL NOT block unrelated CAP records from processing.
3. THE negative refund charge SHALL enter the same allocation entry point as positive charges, distinguished by an explicit record attribute (record kind / equivalent), not by a separate code path.

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

## Confirmed Decisions (settled — for the approver's reference)

| # | Decision | Source |
|---|---|---|
| R-01 | Same formula + pipeline for +/−; true floor toward −∞; `ΣP = N` | REF-CAP-09 |
| R-03/R-07 | Execution-month lump; no spread-back; no re-proration | REF-CAP-09; Accounting signed off |
| R-04 | Fixed/capped refunds taken as delivered | REF-CAP-09 |
| R-05/R-11 | Overlap refund = separate negative, allocated independently | REF-CAP-09 |
| R-12 | Per-charge, never one combined monthly ratio | REF-CAP-09 |
| R-14/R-15 | Cashback: consume cloned negative, Coaching-only, resolve per charge | REF-CAP-09 |
| Scope | CAP only; CIP refunds use no engine | REF-CIP-05 |

## Open Items (for the approver)

| # | Item | Status / ask |
|---|---|---|
| O-R1 | **Shareholder cashback cap for CAP/CIP** — new CAP/CIP-specific cap amounts are under executive discussion; until decided, proceed with the existing **¥19,800** coaching cap. | Confirm we implement against ¥19,800 for now (REF-CAP-09 open item, owner Kuroda-san). |
| O-R2 | **Post-refund recognition of the original positive charge** (non-blocking) — the reconciliation assumes existing ASC keeps recognizing the original positive charge's remaining days after a cooling-off refund, so the refund-month net self-corrects later. | Engineering to confirm existing ASC does not truncate the positive charge on cooling-off (owner: Engineering / Miyaji-san). Accounting accepted proceeding on this basis. |
| O-R3 | **Consumption-tax-exemption calculation path** — expected `paid amount incl. tax × 10/110`, but the controller path/calculation is not yet fully confirmed. | Confirm the Admin Refund flow's exact calculation so 02b consumes the correct negative (REF-CAP-09 R-04). |
| O-R4 | **Record-kind / attribute** used to mark a negative refund charge at the entry point. | Design-phase detail; confirm the explicit attribute exists on `trn_charge` (or equivalent) so positives/negatives share one path. Non-blocking for sign-off. |
