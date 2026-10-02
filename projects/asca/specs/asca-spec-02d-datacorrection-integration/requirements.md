# Requirements Document

**ASCA Spec 02d — DataCorrection Integration**

> **Staging note:** Dev-context draft pending PM sign-off (Kuroda-san, G1). On approval it is promoted to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02d-datacorrection-integration/requirements.md` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do not begin design/tasks from this draft.

## Introduction

This spec extends CAP allocation to the **manual correction batch** (`DataCorrectionCommand` → `DataCorrectionLogic`). It is the **last of four Spec 02 sub-specs** (02a Core Injection → 02b Refund → 02c CSV → **02d DataCorrection**) and is the smallest — one scoped allocation call at one site.

`DataCorrectionLogic` has its **own private copy** of the daily-rate creation logic (`createDailyRateCalculation()`, the `addDaily` operation) that reads `trn_charge` and writes the un-allocated amount **N** to `log_daily_rate_calculation` directly — it does NOT call `CommonUtil::createDailyRateCalculation()`, so 02a's injection does not reach it. Without this sub-spec, a correction that **adds** a CAP coaching charge (`addDaily`) would bypass allocation entirely: the full N stays as coaching revenue and the App companion stays 0.

This sub-spec adds a **scoped** allocation call — `RevenueAllocationService::allocateForCharge($chargeId, $targetYm)` — after the `addDaily` INSERT loop, so a corrected-in charge is allocated the same way the normal batch would, but **only for that charge's bundle**, not the whole month.

### Why scoped, and why only the `addDaily` path

Verified against the current `DataCorrectionLogic` (`execute()` routing by `target_data`):

- **`daily` → `correctDailyRateCalculation()`** — reads/updates **existing** `log_daily_rate_calculation` rows. Those were already written and allocated by the normal batch → **safe as-is, no injection.**
- **`addDaily` → `createDailyRateCalculation()` (private, ~line 346)** — reads `trn_charge` and writes **raw N** to the log. This is the **only** correction path that introduces un-allocated N → **the only path needing the allocation call.**
- Balance/deposit/addBalance/balanceAmount paths do not write daily-rate rows → out of scope.

The correction batch performs **incremental** fixes to an already-completed month; it does NOT delete-and-rebuild the month (unlike `CommonUtil::createDailyRateCalculation()`). Therefore the call MUST be **scoped to the single charge** (`allocateForCharge`), never the full-month `allocate()` — a full rebuild is not the intent of a correction and would wipe the month.

### Design decisions (confirmed)

- **Injection point:** after the `foreach ($ContractDateLists ...) { LogDailyRateCalculation::create(...) }` loop in the private `DataCorrectionLogic::createDailyRateCalculation()` (`addDaily`).
- **Scoped allocation:** `app(RevenueAllocationService::class)->allocateForCharge($trnCharge->id, $targetYm)` (Spec 01 provides `allocateForCharge`; 02d only wires it in). `$targetYm` = the period just written (first key of `$ContractDateLists`).
- **CAP-only / Bizmates-only:** guard to the non-Zipan branch (`$data->containts !== 'Zipan'`). The existing Zipan branch (`LogDailyRateCalculationZipan::create`) is untouched — CAP/CIP are Bizmates-only.
- **Failure isolation:** wrap in try/catch with the stable tag `[REVENUE_ALLOCATION] EXECUTION FAILED! (DataCorrection)`; on failure the correction's N still lands and the batch continues (same posture as 02a).
- **No new command, no schema change, no Zipan change.**

### Dependencies

- **Spec 01 Foundation merged** — provides `RevenueAllocationService::allocateForCharge(int $chargeId, string $targetYm)`, the `log_alloc_*` tables, and the run lifecycle. 02d adds no engine logic — it only calls.
- **02a (CAP Core Injection) merged** — establishes the allocation pattern and the overwrite semantics 02d reuses at charge scope.
- **DEVOPS-6415 present in the ASCA base (prerequisite).** 6415 fixed a pre-existing **drift** in this private method: it lacked the `BizmatesMonthlyPlanEnum::exists()` skip and the `tax_free` / `country_id` / `gross_amount` fields that `CommonUtil` has. 02d builds on the corrected method — so the ASCM refactor must be in the base before implementation. (These requirements are authored against the pre-6415 code that is currently in the branch; the injection point and routing are unchanged by the refactor — see Open Items.)

### Out of scope (explicit)

- **The `daily` / correct path** (`correctDailyRateCalculation`) — safe as-is; no injection.
- **Balance/deposit/addBalance/balanceAmount** correction paths — no daily-rate write.
- **Zipan** corrections — untouched.
- **The 6415 drift fix itself** (monthly-plan skip + missing fields) — that is DEVOPS-6415, a prerequisite, not 02d.
- **Full-month re-allocation** — deliberately not used here (correction is incremental).
- **Refund corrections' allocation math** — the split rules live in 02b; 02d just routes an added charge through `allocateForCharge`, which applies whatever the engine computes (including negatives if the added charge is negative).

**Reference:** current `app/Libs/DataCorrectionLogic.php` (`execute()` routing; private `createDailyRateCalculation()` ~line 346); technical design §8 (second injection point) / §9 (scoped allocation); Spec 01 `allocateForCharge`.

## Glossary

- **`addDaily`** — the correction operation (`target_data`) that adds a new daily-rate row from a `trn_charge`, handled by the private `createDailyRateCalculation()`.
- **`allocateForCharge(chargeId, targetYm)`** — the Spec 01 scoped entry point: detects whether the given charge is part of a CAP bundle, finds its pair in the log, computes P, and overwrites just that pair.
- **Scoped allocation** — allocating only the bundle containing the corrected charge, leaving other bundles in the month untouched.

---

## Requirements

### Requirement 1: Inject scoped allocation into the `addDaily` correction path

**User Story:** As accounting, I need a CAP charge added via correction to be allocated like a normal batch charge so that a manual fix doesn't leave coaching revenue un-split.

#### Acceptance Criteria

1. THE system SHALL call `RevenueAllocationService::allocateForCharge($trnCharge->id, $targetYm)` in the private `DataCorrectionLogic::createDailyRateCalculation()`, positioned **after** the loop that writes the daily-rate rows (`LogDailyRateCalculation::create($condition)`).
2. THE system SHALL resolve `RevenueAllocationService` through the container (`app(RevenueAllocationService::class)`).
3. THE `$targetYm` passed SHALL be the period just written (e.g. the first key of `$ContractDateLists`).
4. THE call SHALL be scoped to the single charge (`allocateForCharge`); THE system SHALL NOT call the full-month `allocate()` here.
5. THE existing INSERT loop and all other correction operations SHALL remain unchanged.

### Requirement 2: Only the `addDaily` path is affected

**User Story:** As accounting, I need the other correction operations to behave exactly as today so that only the un-allocated-write path changes.

#### Acceptance Criteria

1. THE `daily` correction path (`correctDailyRateCalculation`) SHALL be unchanged (it updates already-allocated rows).
2. THE balance / deposit / addBalance / balanceAmount paths SHALL be unchanged (they write no daily-rate rows).
3. ONLY the `addDaily` path SHALL gain the allocation call.

### Requirement 3: CAP-only / Zipan untouched

**User Story:** As accounting, I need the change confined to the Bizmates CAP flow so that Zipan corrections are unaffected.

#### Acceptance Criteria

1. THE allocation call SHALL execute only on the non-Zipan branch (`$data->containts !== 'Zipan'`).
2. THE existing Zipan branch (`LogDailyRateCalculationZipan::create`) SHALL be unchanged, and no allocation SHALL run for Zipan corrections.
3. WHERE the added charge is not part of a CAP bundle, `allocateForCharge` SHALL be a no-op for allocation purposes (detection finds no bundle) and the correction SHALL complete normally. (Detection is Spec 01; 02d asserts a non-CAP charge is not mis-handled.)

### Requirement 4: Failure isolation

**User Story:** As an operator, I need an allocation failure during correction to never break the correction so that the fix still lands.

#### Acceptance Criteria

1. THE `allocateForCharge` call SHALL be wrapped in try/catch.
2. IF it throws, THEN THE system SHALL log `[REVENUE_ALLOCATION] EXECUTION FAILED! (DataCorrection)` with the exception message, and the correction batch SHALL continue.
3. WHEN allocation has failed, THE corrected-in row SHALL still contain N (the correction's write is preserved), i.e. today's behaviour.
4. THE failure SHALL NOT roll back the correction or abort processing of other correction rows beyond the existing error-handling in `execute()`.

### Requirement 5: Consistency with the normal batch

**User Story:** As accounting, I need a corrected-in CAP charge to end up with the same allocated figures the normal batch would have produced so that corrections and normal runs agree.

#### Acceptance Criteria

1. WHEN a CAP coaching charge is added via `addDaily`, THE resulting log rows SHALL carry the allocated P values (coaching reduced, App raised) equivalent to what the normal batch would produce for that bundle.
2. THE overwrite SHALL keep `P_coaching + P_app = N` for the corrected bundle.
3. THE correction's downstream steps (its sum/journal/CSV handling) SHALL inherit the allocated values from the overwritten log rows with no additional change.
4. WHEN the same correction is applied again, THE allocation SHALL be idempotent (N invariant), consistent with 02a.

## Confirmed Decisions (settled — for the approver's reference)

| # | Decision | Source |
|---|---|---|
| Injection site | After the `addDaily` INSERT loop in private `createDailyRateCalculation()` | Current code; §8 |
| Scoped, not full | `allocateForCharge` only — correction is incremental, never rebuild-the-month | §9 |
| Path selectivity | Only `addDaily`; `daily`/balance paths unchanged | `execute()` routing (verified) |
| Tenant | Non-Zipan branch only; Zipan untouched | Current code |
| Failure mode | try/catch → correction keeps N, batch continues | §8 |
| Drift fix | `BizmatesMonthlyPlanEnum` skip + missing fields = DEVOPS-6415 prerequisite, not 02d | §8; DEVOPS-6415 |

## Open Items (for the approver)

| # | Item | Status / ask |
|---|---|---|
| O-D1 | **Injection point vs the DEVOPS-6415-refactored `DataCorrectionLogic`.** These requirements are grounded on the pre-6415 code currently in the branch; the `addDaily` routing and injection site are unchanged by the refactor, but the exact surrounding lines (field set, monthly-plan skip) differ post-6415. | Design phase must confirm the injection line against the refactored file (pull 6415 from `main` first). Non-blocking for requirements sign-off. |
| O-D2 | **`$targetYm` derivation** — using the first key of `$ContractDateLists` assumes the added charge maps to one target month; a charge spanning months would produce multiple keys. | Confirm `allocateForCharge` should run per written period, or that addDaily charges are single-month in practice. Design-phase detail. |
| O-D3 | **DataCorrection retirement (unverified).** There is an unconfirmed suggestion the DataCorrection batch may eventually be retired (DevOps applying corrections via direct SQL). | This does NOT reduce 02d scope — we implement the injection regardless so all affected commands allocate consistently. Recorded only for awareness (per Spec 01 note (2)-6). |
