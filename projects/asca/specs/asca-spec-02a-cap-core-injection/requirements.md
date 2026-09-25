# Requirements Document

**ASCA Spec 02a — CAP Core Injection**

> **Staging note:** This is a **dev-context draft** pending PM sign-off (Kuroda-san, G1). On approval it is promoted to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02a-cap-core-injection/requirements.md` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do not begin design/tasks from this draft.

## Introduction

This spec wires the ASCA allocation engine (built in Spec 01 Foundation) into the live accounting batch for **CAP plans only**. It is the **first of four Spec 02 sub-specs** (02a Core Injection → 02b Refund → 02c AllocationDetail CSV → 02d DataCorrection) and is the prerequisite spine the other three build on.

Scope is the single injection into `CommonUtil::createDailyRateCalculation()`: after the existing step that writes the un-allocated amount **N** to the daily-rate log, call `RevenueAllocationService::allocate()` to detect CAP bundles, compute the split, and overwrite the log rows in place with the allocated amounts **P**, so that everything downstream (sum aggregation, Freee journals, CSVs, balance transition) inherits P with no further change. This is **Scenario D (injection) + Option 1 (Overwrite)**.

This sub-spec delivers a working, testable CAP injection for the Pre (速報) and Final batches. It deliberately excludes refund handling, the AllocationDetail CSV, and the DataCorrection injection — each is its own sub-spec.

### Design decisions (confirmed — carried from the technical design)

- **Scenario D + Option 1 (Overwrite).** The engine overwrites N→P in `log_daily_rate_calculation` (and `_pre`); no adjustment journals, no second Freee call. (Decisions log #1, #2.)
- **Single injection point** for Pre + Final: `CommonUtil::createDailyRateCalculation()`, between the existing "write N" step and the existing "build sum from log" step. (Decision #3; technical design §8.)
- **N = Σ(paid_price) across the bundle** (coaching + app), which makes allocation idempotent — N is invariant across re-runs. (Idempotency design, Kuroda-san 2026-08-14.)
- **CAP-only.** Detection is CAP plans **1016–1027** via `CoachingAndAppPlanEnum`. CIP (1028–1032) is out of the engine entirely (REF-CIP-05) and is skipped defensively (V-3). Zipan is untouched (CAP/CIP are Bizmates-only).
- **Failure isolation.** The allocation call is wrapped so that if it throws, the batch produces exactly today's behaviour (the log still holds N), the run is recorded as failed, and the batch continues. No revenue is lost and no manual intervention is needed to keep the batch running. (Technical design §8.)
- **Product ids:** App `10022`; CAP coaching `10005` (15min) / `10015` (30min).
- **Bizmates connection** (`mysql`).

### Dependencies

- **Spec 01 Foundation must be merged** (both halves): the engine (`RevenueAllocationService::allocate(string $targetYm, bool $preFlg)`), the `log_alloc_*` / `mst_alloc_*` tables, the plan-detection enums, the run-lifecycle service, and the reference-price seeder. This sub-spec only **calls** that engine — it adds no engine logic.
- **DEVOPS updates (6415 + 6596) present in the ASCA base.** Not required to author these requirements (behaviour only), but the design/tasks phase needs the ASCM-refactored files (`CommonUtil` is unaffected by the refactor, but the surrounding batch classes are). Pull from `main` once 6415/6596 are released there.

### Out of scope (explicit — belongs to sibling sub-specs)

- **Refund / negative-N allocation** → Spec 02b (REF-CAP-09).
- **AllocationDetail CSV** (config entry + `RevenueAllocationCsvService` + adding the file to the email zip) → Spec 02c.
- **DataCorrectionLogic injection** (`allocateForCharge()` after the addDaily INSERT) → Spec 02d.
- **CIP** anything → out of the engine entirely (REF-CIP-05); only the defensive skip is in scope here.
- **Freee-mapping data** for the App product_type (the `mst_code_change` / `mst_rule_for_journals` rows) — a data/verification item, not code in this sub-spec (tracked as an Open Item).

**Reference:** technical design §7 (detection), §8 (injection point + failure isolation), §9 (detect → compute → overwrite); Spec 01 requirements (engine contract); `asc-alloc-db-schema.md`.

## Glossary

- **N** — the un-allocated amount existing ASC writes to the daily-rate log for a charge in the target month (coaching row = daily-prorated amount, app row = 0). For a bundle, **N = Σ(paid_price)** of the coaching + app rows.
- **P** — the allocated amount written back to the daily-rate log (P_coaching, P_app), with `P_coaching + P_app = N`.
- **Injection point** — `CommonUtil::createDailyRateCalculation(string $targetYm, string $targetStartDate, string $targetEndDate, bool $preFlg = false)`.
- **Pre / Final** — Pre (速報) runs via `DailyRateCalculationPreCommand` (writes `_pre` tables); Final via `SendJournalsDataCommand` (writes the live tables). Both call the injection point.
- **RevenueAllocationService::allocate(targetYm, preFlg)** — the Spec 01 engine entry point this sub-spec invokes.

---

## Requirements

### Requirement 1: Inject the allocation call into `CommonUtil::createDailyRateCalculation()`

**User Story:** As the accounting batch, I need the allocation engine invoked after the daily-rate log is populated so that CAP bundle revenue is split before the sum is built.

#### Acceptance Criteria

1. THE system SHALL call `RevenueAllocationService::allocate($targetYm, $preFlg)` inside `CommonUtil::createDailyRateCalculation()`, positioned **after** the existing loop that writes N to the daily-rate log AND **before** the existing step that builds the sum from the log (`getPaidPriceSumList()`).
2. THE system SHALL resolve `RevenueAllocationService` through the Laravel container (`app(RevenueAllocationService::class)`) so it is swappable in tests.
3. THE system SHALL pass the same `$preFlg` the function received, so a Pre run allocates the `_pre` table and a Final run allocates the live table.
4. THE injected call SHALL be the only change to this function's control flow; the existing "write N" and "build sum" steps SHALL remain unchanged.
5. WHERE `$preFlg` is true, THE allocation SHALL target `log_daily_rate_calculation_pre`; WHERE false, `log_daily_rate_calculation`.

### Requirement 2: CAP-only detection scope

**User Story:** As the allocation engine caller, I need injection to act on CAP plans only so that non-CAP charges and other tenants are unaffected.

#### Acceptance Criteria

1. THE allocation invoked here SHALL process only CAP plans (`plan_id` 1016–1027, via `CoachingAndAppPlanEnum`) with coaching `product_id` in {10005, 10015} and app `product_id` 10022. (Detection logic itself is Spec 01; this sub-spec asserts injection does not widen that scope.)
2. IF a CIP plan (1028–1032) or any plan with no registered allocation formula is encountered, THEN the run SHALL skip it with a warning (V-3) and SHALL NOT fail. (CIP uses no engine — REF-CIP-05.)
3. THE injection SHALL NOT alter the Zipan path in any way (CAP/CIP are Bizmates-only; `ZipanUtil` is untouched).
4. WHERE no CAP bundles exist for the target month, THE allocation SHALL complete as a no-op (run recorded, zero records) and the batch SHALL proceed unchanged.

### Requirement 3: Overwrite semantics (Option 1) and idempotency

**User Story:** As accounting, I need the log rows to carry the allocated amounts after injection so that all downstream outputs reflect the split without further code.

#### Acceptance Criteria

1. WHEN allocation runs, THE system SHALL overwrite the coaching row's `paid_price` with `P_coaching` and the app row's `paid_price` with `P_app` in the daily-rate log, in place.
2. THE system SHALL define `N = Σ(paid_price)` across the bundle (coaching + app) so that re-running the batch for the same month produces identical P values (idempotent).
3. WHEN the batch (Pre or Final) is re-run for the same `target_ym`, THE resulting P values SHALL be identical to the first run.
4. THE system SHALL guarantee `P_coaching + P_app = N` for every bundle after overwrite.
5. THE step that builds the sum SHALL read the overwritten (P) values, so `log_sum_calculation` (or `_pre`), Freee journals, CSVs, and balance transition inherit P with no change to those code paths.

### Requirement 4: Failure isolation

**User Story:** As an operator, I need an allocation failure to never break the existing batch so that accounting output is at worst today's un-allocated behaviour.

#### Acceptance Criteria

1. THE allocation call SHALL be wrapped in try/catch at the injection point.
2. IF the allocation throws, THEN THE system SHALL log the failure with a stable, greppable tag (`[REVENUE_ALLOCATION] EXECUTION FAILED!`) including the exception message and trace, and THE batch SHALL continue to the sum-building step.
3. WHEN allocation has failed, THE daily-rate log SHALL still contain N (the pre-allocation values), so the batch produces exactly today's un-allocated output.
4. THE failure SHALL be recorded in the run lifecycle (`log_alloc_calculation_runs` status = Failed) so it is visible to accounting without inspecting logs. (Run-lifecycle write is Spec 01; this sub-spec asserts a failure surfaces there.)
5. THE system SHALL NOT require manual intervention to keep the batch running after an allocation failure.

### Requirement 5: Batch coverage (Pre + Final via the single point)

**User Story:** As the accounting team, I need both the Pre and Final batches to allocate consistently so that the preliminary and final figures agree.

#### Acceptance Criteria

1. THE injection SHALL cause `DailyRateCalculationPreCommand` (Pre) to allocate the `_pre` tables via the shared `CommonUtil` call.
2. THE injection SHALL cause `SendJournalsDataCommand` (Final) to allocate the live tables via the same call.
3. THE system SHALL NOT add a separate injection for Pre vs Final — both are covered by the single `CommonUtil::createDailyRateCalculation()` change.
4. THE `DataCorrectionCommand` path is explicitly NOT covered here (it has its own private daily-rate creation) — it is Spec 02d.

### Requirement 6: No regression to existing (non-CAP) output

**User Story:** As accounting, I need existing monthly/daily figures for non-CAP charges to be unchanged so that injection is safe to deploy.

#### Acceptance Criteria

1. WHEN the batch runs on a month with no CAP charges, THE generated log, sum, journals, and CSVs SHALL be identical to pre-injection output.
2. THE system SHALL NOT change how existing ASC determines whether or when any charge is recognized; it only splits an already-recognized CAP amount.
3. THE ¥0 App companion charge SHALL continue to be written by the existing "write N" step (paid_price 0); the overwrite then raises it to `P_app`, which then passes the existing `paid_price != 0` gate in the Freee sender with no change to that sender.
4. A smoke run of Pre and Final on DEV04 SHALL complete with `DATA CREATION COMPLETED SUCCESSFULLY!` and no new errors.

## Confirmed Decisions (settled — for the approver's reference, not to re-open)

| # | Decision | Source |
|---|---|---|
| Architecture | Scenario D (injection) | Decisions log #1 |
| Timing | Option 1 (Overwrite N→P) | Decisions log #2 |
| Injection point | `CommonUtil::createDailyRateCalculation()` covers Pre + Final | Decisions log #3; §8 |
| N definition | Σ(paid_price) across bundle (idempotent) | Kuroda-san 2026-08-14 |
| Scope | CAP-only (1016–1027); CIP out of engine | REF-CIP-05 |
| Failure mode | try/catch → today's behaviour, run marked Failed | §8 |
| Tenant | Bizmates only; Zipan untouched | Decisions log #8 |

## Open Items (for the approver)

| # | Item | Status / ask |
|---|---|---|
| O-A | App Freee-mapping rows (`mst_code_change` code→freee_code, `mst_rule_for_journals` for the App product_type 100) must exist for App journals to route correctly once `P_app > 0`. | Data verification, not code in 02a. Confirm the rows exist on the target environment before go-live (may need an ls-db seeder). Does Accounting confirm the App routes on the Bizmates contract-type path? |
| O-B | Exact placement relative to any ASCM-refactor changes inside/around `CommonUtil::createDailyRateCalculation()`. | Design-phase detail; requires the DEVOPS-refactored base checked out. Non-blocking for requirements sign-off. |
