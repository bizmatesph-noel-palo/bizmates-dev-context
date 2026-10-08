# Requirements Document

**ASCA Spec 02a — CAP Core Injection**

> **Staging note:** Dev-context draft, **Round-3 — submitted for PM sign-off (Kuroda-san)**. Round-1 (REF-CAP-12) and Round-2 (REF-CAP-13) feedback are folded in; Kuroda-san's Round-2 note said 02a is "good to go once the minor cleanups are done" — those cleanups (Dependencies updated to merged state, V-7 premise into Dependencies, O-A as a data check) are applied here. On sign-off it is promoted to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02a-cap-core-injection/requirements.md` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do not begin design/tasks until sign-off.

## Introduction

This spec wires the ASCA allocation engine (built in Spec 01 Foundation) into the live accounting batch for **CAP plans only**. It is the **first of four Spec 02 sub-specs** (02a Core Injection → 02b Refund → 02c AllocationDetail CSV → 02d DataCorrection) and is the prerequisite spine 02b and 02c build on. (02d was **repurposed on 2026-10-05** from "inject allocation into DataCorrectionLogic" to "**decommission `DataCorrectionCommand`**" — the command is confirmed unused, Wu-san 08-28 + Harvey-san 10-05; see the 02d spec + `ASCA-ADR-20261005-datacorrection-decommission.md`. 02d no longer depends on 02a.)

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

- **Spec 01 Foundation must be merged** (both halves): the engine (`RevenueAllocationService::allocate(string $targetYm, bool $preFlg)`), the `log_alloc_*` / `mst_alloc_*` tables, the plan-detection enums, the run-lifecycle service, and the reference-price seeder. This sub-spec only **calls** that engine — it adds no engine logic. ✅ Merged (ASCA-16 + ASCA-17) to `feature/ASCA/ASCA-master`.
- **DEVOPS updates (6415 + 6596) present in the ASCA base.** ✅ Released to production 2026-09-28 and merged `main` → `feature/ASCA/ASCA-master` on 2026-10-01, so the ASCM-refactored files are already in the ASCA base — no "pull from main" step remains for the design/tasks phase. (`CommonUtil` itself is unaffected by the refactor; the surrounding batch classes carry the ArchiverService/MailerService extraction.)
- **V-7 premise — App (`10022`) `paid_price = 0` confirmed on real data.** The overwrite path assumes the App companion charge is written with `paid_price = 0` (so V-7's "App ≠ 0 ⇒ skip" is the exception, not the norm). This must be verified against production data before go-live. (Was O-D; folded into Dependencies per REF-CAP-13 §3.)

### Out of scope (explicit — belongs to sibling sub-specs)

- **Refund / negative-N allocation** → Spec 02b (REF-CAP-09).
- **AllocationDetail CSV** (config entry + `RevenueAllocationCsvService` + adding the file to the email zip) → Spec 02c.
- **DataCorrection** → Spec 02d, now scoped to **decommissioning `DataCorrectionCommand`** (disable + deprecate), not injecting allocation into it. The original `allocateForCharge()` injection is dropped — the command is confirmed unused (Wu-san 08-28, Harvey-san 10-05).
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
5. **(V-3 skip visibility — REF-CAP-13 §3)** WHEN a bundle is skipped (V-3: ambiguous/incomplete pairing, non-zero App, CIP, no formula, or no reference price), THE system SHALL record the **skipped-bundle count and the skip reason** on the run (`log_alloc_calculation_runs` or an associated record), so Accounting can see what was skipped and why without reading the application logs.
6. **(No reference-price row — REF-CAP-13 §3)** WHERE a month has no applicable `mst_alloc_reference_prices` row (price resolved on the last day of `target_ym` finds nothing), THE system SHALL skip every bundle with the reason "no reference price" as a **no-op** (run completes, nothing overwritten) — it SHALL NOT be treated as a failure. (This is the behaviour before the `effective_from` price window opens; see Req 6.)
7. **(Standalone App exclusion — REF-CAP-13 §3)** THE allocation SHALL exclude a standalone App charge (`product_id 10012`) that is not part of a CAP bundle; there SHALL be an acceptance test asserting a standalone App charge is not allocated.

### Requirement 3: Overwrite semantics (Option 1) and idempotency

**User Story:** As accounting, I need the log rows to carry the allocated amounts after injection so that all downstream outputs reflect the split without further code.

#### Acceptance Criteria

1. WHEN allocation runs, THE system SHALL overwrite the coaching row's `paid_price` with `P_coaching` and the app row's `paid_price` with `P_app` in the daily-rate log, in place.
2. THE system SHALL define `N = Σ(paid_price)` across the bundle (coaching + app) so that re-running the batch for the same month produces identical P values (idempotent).
3. WHEN the batch (Pre or Final) is re-run for the same `target_ym`, THE resulting P values SHALL be identical to the first run.
4. **(Re-run vs V-7 — REF-CAP-13 #3)** WHEN re-running an already-allocated month, THE system SHALL first restore N for each bundle from `log_alloc_prorations.original_paid_price` (the pre-allocation snapshot) before recomputing, AND SHALL apply the V-7 "App `paid_price` ≠ 0 ⇒ skip" check to that restored (pre-allocation) value only — NOT to the already-overwritten P value in the log. This makes a re-run reproduce the first run's P instead of skipping already-allocated bundles.
5. THE system SHALL guarantee `P_coaching + P_app = N` for every bundle after overwrite.
6. THE step that builds the sum SHALL read the overwritten (P) values, so `log_sum_calculation` (or `_pre`), Freee journals, CSVs, and balance transition inherit P with no change to those code paths.
7. THERE SHALL be an acceptance test that re-runs an already-allocated month and asserts the P values are identical to the first run (the snapshot-restore path above is exercised, not the V-7 skip).

### Requirement 4: Failure isolation

**User Story:** As an operator, I need an allocation failure to never break the existing batch so that accounting output is at worst today's un-allocated behaviour.

#### Acceptance Criteria

> **Mid-run failure model (REF-CAP-13 #2 — option b, confirmed by Kuroda-san 2026-10-05):** each bundle pair is written **atomically**; a failed pair keeps its N; the run finishes as **completed-with-errors** carrying a list of the failed pairs. There is NO whole-run rollback. This matches 02b Req 6 ("SHALL NOT block unrelated CAP records").

1. THE allocation call SHALL be wrapped in try/catch at the injection point.
2. THE system SHALL write each bundle pair (coaching + app) atomically — a mid-way failure on one pair SHALL NOT leave one side overwritten and the other not; that pair rolls back to its N.
3. WHEN a bundle pair fails, THE daily-rate log SHALL still contain **N for that pair** (the pre-allocation values), so the failed pair produces today's un-allocated output while successfully-allocated pairs keep their P. (This supersedes the earlier "whole log keeps N" wording — only the failed pairs keep N.)
4. IF one or more pairs fail, THEN THE system SHALL log each failure with a stable, greppable tag (`[REVENUE_ALLOCATION] EXECUTION FAILED!`) including the exception message and the failing `charge_id` / `order_no`, AND THE batch SHALL continue to the sum-building step.
5. THE run SHALL be recorded in the run lifecycle (`log_alloc_calculation_runs`) as **completed-with-errors** (not a blanket Failed) with the list of failed pairs attached, so it is visible to accounting without inspecting logs. A run with zero failures is recorded as completed. (Run-lifecycle write is Spec 01; this sub-spec asserts the completed-with-errors state + failed-pair list surface there.)
6. THE system SHALL NOT require manual intervention to keep the batch running after a pair-level allocation failure.

### Requirement 5: Batch coverage (Pre + Final via the single point)

**User Story:** As the accounting team, I need both the Pre and Final batches to allocate consistently so that the preliminary and final figures agree.

#### Acceptance Criteria

1. THE injection SHALL cause `DailyRateCalculationPreCommand` (Pre) to allocate the `_pre` tables via the shared `CommonUtil` call.
2. THE injection SHALL cause `SendJournalsDataCommand` (Final) to allocate the live tables via the same call.
3. THE system SHALL NOT add a separate injection for Pre vs Final — both are covered by the single `CommonUtil::createDailyRateCalculation()` change.
4. THE `DataCorrectionCommand` path is explicitly NOT covered here (it has its own private daily-rate creation) — it is Spec 02d. (02d: Kuroda-san asked to drop it at Round 2 (REF-CAP-13 §4 — `DataCorrectionCommand` already unused per Wu-san 08-28); **Lead is holding the retain pending clarification with Kuroda-san** — 02d scope unchanged for now.)

### Requirement 6: No regression to existing (non-CAP) output

**User Story:** As accounting, I need existing monthly/daily figures for non-CAP charges to be unchanged so that injection is safe to deploy.

#### Acceptance Criteria

1. WHEN the batch runs on a month with no CAP charges, THE generated log, sum, journals, and CSVs SHALL be identical to pre-injection output.
2. THE system SHALL NOT change how existing ASC determines whether or when any charge is recognized; it only splits an already-recognized CAP amount.
3. THE ¥0 App companion charge SHALL continue to be written by the existing "write N" step (paid_price 0); the overwrite then raises it to `P_app`, which then passes the existing `paid_price != 0` gate in the Freee sender with no change to that sender.
4. A smoke run of Pre and Final on DEV04 SHALL complete with `DATA CREATION COMPLETED SUCCESSFULLY!` and no new errors. **(REF-CAP-13 §3)** Reference prices for the test month MUST be seeded on DEV04 so the smoke run actually allocates (not a no-op).

### Requirement 7: Reference-price window and source of truth (REF-CAP-13 §3)

**User Story:** As accounting, I need CAP allocation to start from the beta release month and I need a clear statement of which run is authoritative, so that December beta revenue is split and reporting reads the right run.

#### Acceptance Criteria

1. THE initial `mst_alloc_reference_prices` rows for CAP SHALL use `effective_from = 2026-12-01` (NOT 2027-01-01). CAP beta release is 2026-12-01 (general release 12/8–10); the first close after release is `target_ym = 2026-12` (run in early January) and the price is resolved on the **last day of `target_ym`**. With `effective_from = 2027-01-01`, that resolution finds no row and December CAP revenue would stay 100% on Coaching. Beta purchases are booked as normal revenue, so the earlier date is correct (and harmless if the schedule slips — no CAP charges can exist before the beta).
2. THE seeder and the Spec 01 references that currently state `2027-01-01` SHALL be updated to `2026-12-01`. (Cross-repo: ls-db CAP reference-price seeder + Spec 01 requirements/design references.)
3. **Source of truth:** the **active Final run is authoritative** for a given `target_ym`; the Pre (速報) run is **preliminary**. Downstream reads (e.g. `v_alloc_prorations_active`, the AllocationDetail CSV) reflect the active Final run.

## Confirmed Decisions (settled — for the approver's reference, not to re-open)

| # | Decision | Source |
|---|---|---|
| Architecture | Scenario D (injection) | Decisions log #1 |
| Timing | Option 1 (Overwrite N→P) | Decisions log #2 |
| Injection point | `CommonUtil::createDailyRateCalculation()` covers Pre + Final | Decisions log #3; §8 |
| N definition | Σ(paid_price) across bundle (idempotent) | Kuroda-san 2026-08-14 |
| Scope | CAP-only (1016–1027); CIP out of engine | REF-CIP-05 |
| Failure mode | Per-pair atomic; failed pairs keep N; run = completed-with-errors + failed-pair list (NOT whole-run rollback) | REF-CAP-13 #2 (option b) |
| Re-run vs V-7 | Restore N from `original_paid_price` snapshot; apply V-7 to restored value only | REF-CAP-13 #3 |
| Reference-price start | `effective_from = 2026-12-01` (CAP beta release), not 2027-01-01 | REF-CAP-13 §3 |
| Source of truth | Active Final run authoritative; Pre preliminary | REF-CAP-13 §3 |
| Tenant | Bizmates only; Zipan untouched | Decisions log #8 |

## Open Items (for the approver)

| # | Item | Status / ask |
|---|---|---|
| O-A | App Freee-mapping rows (`mst_code_change` code→freee_code, `mst_rule_for_journals` for the App product_type 100) must exist for App journals to route correctly once `P_app > 0`. | **Data check only** (REF-CAP-13 §3 — no Accounting sign-off needed). Confirm the App Freee-mapping rows exist on the target environment before go-live (may need an ls-db seeder). Not code in 02a. |
| O-B | Exact placement relative to the ASCM-refactor changes inside/around `CommonUtil::createDailyRateCalculation()`. | Design-phase detail. The refactored base is already in `feature/ASCA/ASCA-master` (6415/6596 merged 10-01). Non-blocking for requirements sign-off. |
| ~~O-G1-2~~ ✅ | **RESOLVED (REF-CAP-13 #2) — option (b).** Mid-run failure now specified in Req 4: per-pair atomic, failed pairs keep N, run = completed-with-errors + failed-pair list. No whole-run rollback. |
| ~~O-G1-3~~ ✅ | **RESOLVED (REF-CAP-13 #3).** Re-run restores N from `log_alloc_prorations.original_paid_price` and applies V-7 to the restored value only (Req 3.4); re-run acceptance test added (Req 3.7). |
| ~~O-D~~ ✅ | **RESOLVED (REF-CAP-13 §3).** V-7 premise ("App 10022 `paid_price = 0` confirmed on real data") moved into Dependencies as a pre-go-live data check. |
