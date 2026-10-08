# Requirements Document

**ASCA Spec 02d — DataCorrection Command Decommission**

> **Staging note:** Dev-context draft pending PM sign-off (Kuroda-san, G1). On approval it is promoted to `accounting_related_system_for_freee/.kiro/specs/asca-spec-02d-datacorrection-integration/requirements.md` (with a valid `.config.kiro`), which unlocks the spec UI's "Continue to Design". Do not begin design/tasks from this draft.
>
> **Scope change (2026-10-05, confirmed by Kuroda-san 2026-10-05 PM):** 02d was originally scoped as "inject allocation into `DataCorrectionLogic`". It has been **repurposed** to **disable `DataCorrectionCommand`** (fail fast with a deprecated message) instead. Kuroda-san confirmed in-thread: "02d becomes 'disable DataCorrectionCommand' only … the `allocateForCharge()` injection in DataCorrectionLogic is no longer needed." **Low priority.** Rationale and decision trail in the Introduction. The original allocation-injection scope is **dropped** (recorded in "Superseded original scope" below so the history is traceable).

## Introduction

This spec **decommissions the manual correction batch** (`DataCorrectionCommand` → `DataCorrectionLogic`) so that the one accounting path that would bypass CAP allocation can no longer run. It is the **last of the four Spec 02 sub-specs** (02a Core Injection → 02b Refund → 02c CSV → **02d DataCorrection Decommission**).

### Why this changed from "inject" to "disable"

`DataCorrectionLogic` has its **own private copy** of the daily-rate creation logic (`addDaily` → private `createDailyRateCalculation()`) that writes the un-allocated amount **N** directly to `log_daily_rate_calculation`, bypassing `CommonUtil::createDailyRateCalculation()` and therefore 02a's injection. The original 02d plan was to add a scoped `allocateForCharge()` call there so a corrected-in CAP charge would still be split.

That plan assumed the command is in use. It is not:

- **Wu-san (2026-08-28):** `DataCorrectionCommand` is no longer used in operation. Accounting correction requests (via Redmine) are handled by DevOps running SQL directly on the DB, ~once a month.
- **Harvey-san (2026-10-05, verbatim, confirming for Kuroda-san):**
  - "No, this command hasn't been used for months." Corrections now follow a Confluence runbook: Accounting sends a CSV, DevOps generates INSERT/UPDATE/DELETE SQL from it. (Sample ticket: DEVOPS-6706.)
  - "We only use direct SQL Execution."
  - "I don't think the command for data correction is needed in the future since this is outdated and needs a constant update every time there's a structure change in a table."

Because DevOps corrections run **direct SQL with post-allocation amounts**, there is no un-allocated-N path to protect there either. So:

- **Injecting allocation** would maintain a dead code path forever (and, per Harvey-san, one that needs re-work on every table-structure change) — pure liability.
- **Leaving the command runnable but un-injected** would keep exactly the drift risk the Lead originally wanted to avoid (someone runs it, a CAP charge is written un-split).
- **Disabling the command** removes the risk permanently at near-zero maintenance cost — the path cannot bypass allocation because it cannot execute.

Kuroda-san's standing guidance (REF-CAP-12 §0, REF-CAP-13 §4): *"If the concern is someone running the command by accident, disabling it or marking it deprecated in code would be enough."*

### Decision trail

| Date | Position |
|---|---|
| 2026-09-28 (REF-CAP-12 §0) | Kuroda-san: drop 02d — DataCorrection batch is outdated. |
| 2026-10-01 | Lead: **retain** 02d — DEVOPS-6415-style drift risk if the path runs un-injected. |
| 2026-10-05 (REF-CAP-13 §4) | Kuroda-san: command already unused (Wu-san 08-28); keep 02d out of scope, or disable/deprecate if the concern is accidental execution. |
| 2026-10-05 (Harvey-san, in-thread) | DevOps confirms: unused for months, direct SQL only, no future need. |
| 2026-10-05 (Lead) | **Repurpose 02d: decommission the command** (disable + deprecate) rather than inject allocation or silently drop. Keeps the drift risk closed and the audit trail intact. |

### Design decisions (confirmed)

- **Disable execution.** `DataCorrectionCommand` SHALL NOT run its correction logic. The chosen mechanism (early guarded exit in `handle()` with a clear deprecation message, and/or removal from any schedule/registration) is a design-phase detail — the requirement is that invoking it performs no data write and clearly states it is decommissioned.
- **Deprecate in code.** `DataCorrectionCommand` and `DataCorrectionLogic` SHALL be marked deprecated (docblock + a one-line log on invocation) pointing to the current DevOps direct-SQL correction process (Confluence runbook; e.g. DEVOPS-6706).
- **No allocation injection.** The original `allocateForCharge()` injection into `DataCorrectionLogic` is **NOT** implemented — the path is being removed, not maintained.
- **No schema change, no Zipan change, no change to the normal Pre/Final batches.**

### Dependencies

- **None blocking.** This sub-spec removes a path; it does not depend on the allocation engine. (It is grouped under Spec 02 because it closes the last DataCorrection-related allocation concern.)
- Informational: the current DevOps correction process is the Confluence runbook referenced by Harvey-san (CSV → generated SQL), with DEVOPS-6706 as a representative ticket.

### Out of scope (explicit)

- **Injecting allocation into `DataCorrectionLogic`** — the original 02d scope, now dropped (see "Superseded original scope").
- **Deleting the command's source files** — deprecation + disabling execution is sufficient; a later cleanup can remove the files if desired. (Design may choose removal, but it is not required.)
- **The DevOps direct-SQL correction process** — owned by DevOps; this spec does not change it.
- **The normal Pre / Final batches and 02a's injection** — unaffected.
- **Zipan** — untouched.

**Reference:** current `app/Libs/DataCorrectionLogic.php` + `app/Console/Commands/DataCorrectionCommand.php`; REF-CAP-12 §0, REF-CAP-13 §4 (Kuroda-san); Harvey-san's 2026-10-05 confirmation; DevOps correction runbook (Confluence) + DEVOPS-6706.

## Glossary

- **`DataCorrectionCommand`** — the artisan command that imports a `correction_{YYYYMM}.csv` and applies manual corrections via `DataCorrectionLogic`. Being decommissioned by this spec.
- **Decommission** — disable execution + mark deprecated in code, so the command cannot run and its status is clear to future developers. (Not necessarily source-file deletion.)
- **DevOps direct-SQL correction** — the current process that replaced the command: Accounting sends a CSV, DevOps generates and runs INSERT/UPDATE/DELETE SQL (Confluence runbook), using post-allocation amounts.

---

## Requirements

### Requirement 1: Disable execution of `DataCorrectionCommand`

**User Story:** As the accounting system owner, I need the unused manual-correction command to be unable to write data, so that no one can bypass CAP allocation by running it.

#### Acceptance Criteria

1. WHEN `DataCorrectionCommand` is invoked, THE system SHALL NOT execute the correction logic (no `addDaily`/`daily`/balance writes, no `log_daily_rate_calculation` writes).
2. WHEN `DataCorrectionCommand` is invoked, THE system SHALL emit a clear message stating the command is decommissioned and pointing to the current DevOps direct-SQL correction process, AND SHALL exit without error-ing the surrounding tooling (a controlled no-op exit, not a fatal crash).
3. THE command SHALL be removed from any automated schedule/registration that could trigger it (if such a registration exists), so it is not run unattended.
4. THE normal Pre and Final batches and 02a's injection SHALL be entirely unaffected by this change.

### Requirement 2: Deprecate `DataCorrectionCommand` / `DataCorrectionLogic` in code

**User Story:** As a future developer, I need the correction command clearly marked as deprecated so that I don't revive or extend a dead path by mistake.

#### Acceptance Criteria

1. THE `DataCorrectionCommand` and `DataCorrectionLogic` classes SHALL carry a deprecation docblock noting: decommissioned on CAP allocation work (ASCA, 2026-10), unused since ≥2026-08 (Wu-san) and confirmed 2026-10-05 (Harvey-san), replaced by the DevOps direct-SQL correction process.
2. THE deprecation note SHALL reference the current process (Confluence runbook; representative ticket DEVOPS-6706).
3. A one-line log entry SHALL be written if the command is invoked, so any attempted use is visible.

### Requirement 3: No allocation injection, no schema or Zipan change

**User Story:** As accounting, I need this change to remove a path only, not alter allocation or other tenants, so that it is safe and minimal.

#### Acceptance Criteria

1. THE system SHALL NOT add an `allocateForCharge()` (or any allocation) call into `DataCorrectionLogic` — the original 02d injection scope is dropped.
2. THE system SHALL NOT change any database schema.
3. THE system SHALL NOT change the Zipan correction branch or any Zipan behaviour.
4. THE system SHALL NOT change `CommonUtil::createDailyRateCalculation()` or any 02a-touched code.

### Requirement 4: Reversibility note (if the command is ever revived)

**User Story:** As a maintainer, I need a recorded condition for revival so that if DataCorrection is ever needed again, the allocation gap is reconsidered.

#### Acceptance Criteria

1. THE deprecation note SHALL state that IF `DataCorrectionCommand` is ever re-enabled, the CAP-allocation injection (the original 02d scope: scoped `allocateForCharge()` on the `addDaily` path) MUST be reconsidered before it is used, so a revived command does not reintroduce the un-allocated-N drift.

## Confirmed Decisions (settled — for the approver's reference)

| # | Decision | Source |
|---|---|---|
| Scope | **Decommission** (disable + deprecate) `DataCorrectionCommand`, NOT inject allocation | Lead 2026-10-05, on Kuroda-san's option (REF-CAP-13 §4) |
| Command unused | Confirmed unused for months; corrections via DevOps direct SQL | Wu-san 2026-08-28; Harvey-san 2026-10-05 |
| Replacement process | Accounting CSV → DevOps generated INSERT/UPDATE/DELETE SQL (Confluence runbook) | Harvey-san 2026-10-05 (DEVOPS-6706) |
| Mechanism | Guarded no-op exit + deprecation docblock/log; schedule removal if any | Design-phase detail |
| No injection | Original `allocateForCharge()` scope dropped | Lead 2026-10-05 |
| Blast radius | Pre/Final batches, 02a injection, schema, Zipan all untouched | This spec |

## Superseded original scope (recorded for traceability — NOT to implement)

The original 02d ("DataCorrection Integration") would have added a scoped `RevenueAllocationService::allocateForCharge($chargeId, $targetYm)` call after the `addDaily` INSERT loop in the private `DataCorrectionLogic::createDailyRateCalculation()`, CAP-only, non-Zipan, with `[REVENUE_ALLOCATION] EXECUTION FAILED! (DataCorrection)` failure isolation. That approach is **not implemented** — the command is being decommissioned instead. If the command is ever revived, this is the injection to reconsider (Req 4).

## Open Items (for the approver)

| # | Item | Status / ask |
|---|---|---|
| O-D1 | **Disable mechanism** — guarded no-op exit in `handle()` vs. unregistering the command vs. both. | Design-phase detail. Confirm the preferred mechanism; the requirement is only that it cannot write data and states it is decommissioned. |
| O-D2 | **Source-file removal vs. deprecate-in-place.** This spec requires deprecate + disable; full file deletion is optional. | Confirm whether Accounting/DevOps want the files removed now or left deprecated for one release first. |
| ~~O-D3~~ ✅ | **RESOLVED (2026-10-05).** Kuroda-san gave explicit in-thread go-ahead: "Reusing 02d to disable the command at low priority sounds good … 02d becomes 'disable DataCorrectionCommand' only." The usage check is closed (Harvey-san). The 02d epic may now be created (low priority). He also requested the cross-ref cleanups (02a Req 5.4, 02b out-of-scope, README, technical design §1d) — all applied 2026-10-08. |
