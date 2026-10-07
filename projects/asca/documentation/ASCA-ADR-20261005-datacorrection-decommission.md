# DataCorrection Command — Decommission (ASCA 02d scope reversal)

## Document Info

| | |
|---|---|
| **Document type** | ADR (Architecture Decision Record) |
| **Date** | 2026-10-05 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro (decision analysis, drafting) |
| **Status** | Accepted (pending Kuroda-san's explicit in-thread go-ahead — see Status) |
| **Audience** | Kuroda-san (PM, decision), Patrick-san (SDM, awareness), DevOps (Harvey-san), Dev team |
| **Affects** | ASCA Spec 02d (`asca-spec-02d-datacorrection-integration`) |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) |
| **Evidence** | `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md` (Wu-san + Harvey-san confirmation, this folder) |

---

## The Question

ASCA Spec 02d was originally scoped to **inject allocation** into the manual correction batch (`DataCorrectionCommand` → `DataCorrectionLogic`), because that command has its own private daily-rate path (`addDaily`) that writes the un-allocated amount **N** directly to `log_daily_rate_calculation`, bypassing `CommonUtil::createDailyRateCalculation()` and therefore 02a's injection. Left un-injected, a correction that adds a CAP coaching charge would leave it un-split (full N on Coaching, App companion 0).

The question: given the command is reportedly unused, do we **(a)** inject allocation (original plan), **(b)** silently drop 02d, or **(c)** decommission the command?

---

## Decision

**Decommission `DataCorrectionCommand` (disable execution + deprecate in code).** Do NOT inject allocation; do NOT silently drop.

---

## Options Considered

| Option | What it does | Verdict |
|---|---|---|
| **(a) Inject allocation** (original 02d) | Add scoped `allocateForCharge()` on the `addDaily` path | ❌ Maintains a dead code path forever. Harvey-san: the command "is outdated and needs a constant update every time there's a structure change in a table." Pure liability. |
| **(b) Silently drop 02d** | Leave the command runnable but un-injected | ❌ Leaves exactly the drift risk the Lead originally flagged — if anyone runs it, a CAP charge is written un-split. The risk the retain was meant to close stays open. |
| **(c) Decommission** (chosen) | Disable execution + mark deprecated | ✅ Removes the drift risk permanently at near-zero maintenance cost — the path cannot bypass allocation because it cannot run. Matches Kuroda-san's standing guidance. |

---

## Context & Rationale

### Why the command's un-allocated path mattered

`DataCorrectionLogic` does not call the shared `CommonUtil::createDailyRateCalculation()`; it has a private copy. So 02a's single-injection-point design does not reach it. This is structurally the same "second un-allocated path" problem DEVOPS-6415 fixed for a different drift — which is why the Lead initially wanted to retain 02d and inject here too.

### Why injection is the wrong fix now

The retain rationale assumed the command is in use. It is not:

- **Wu-san (2026-08-28):** `DataCorrectionCommand` is no longer used; Accounting corrections (via Redmine) are handled by DevOps running SQL directly, ~once a month.
- **Harvey-san (2026-10-05):** confirmed unused for months; DevOps uses direct SQL only (Confluence runbook: Accounting CSV → generated INSERT/UPDATE/DELETE SQL; sample DEVOPS-6706); and sees no future need because the command is outdated and needs constant upkeep on every table-structure change.

Critically, DevOps corrections run **direct SQL with post-allocation amounts** — so there is no un-allocated-N path to protect there either. Injecting allocation would maintain dead code; dropping would leave a runnable bypass. Decommissioning removes the path.

### Alignment with PM guidance

Kuroda-san, twice (REF-CAP-12 §0, REF-CAP-13 §4): *"If the concern is someone running the command by accident, disabling it or marking it deprecated in code would be enough."* The chosen option is exactly that.

---

## Decision Trail

| Date | Position | Source |
|---|---|---|
| 2026-09-28 | Kuroda-san: drop 02d — DataCorrection batch outdated | REF-CAP-12 §0 |
| 2026-10-01 | Lead: **retain** 02d — DEVOPS-6415-style drift risk if the path runs un-injected | project-context / timeline |
| 2026-10-05 | Kuroda-san: command already unused (Wu-san 08-28); keep out of scope, or disable/deprecate if the concern is accidental execution | REF-CAP-13 §4 |
| 2026-10-05 | Harvey-san (DevOps): unused for months, direct SQL only, no future need | `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md` |
| 2026-10-05 | Lead: **repurpose 02d → decommission** (disable + deprecate), not inject, not silently drop | this ADR |

---

## Consequences

**Positive**
- The un-allocated DataCorrection path is closed permanently — no CAP charge can be written un-split via this command.
- No dead allocation code to maintain through future table-structure changes.
- 02d stays in the spec set as a tracked, auditable decision rather than vanishing.

**Negative / risk**
- If `DataCorrectionCommand` is ever revived, the allocation gap returns. Mitigation: the deprecation note and 02d Req 4 require reconsidering the allocation injection before any revival.

**Neutral**
- The original injection design is preserved in 02d's "Superseded original scope" section, so a revival knows exactly what to reconsider.
- No schema change, no Zipan change, no change to the Pre/Final batches or 02a.

---

## Status

**Accepted by the Lead (2026-10-05)**, conditional on Kuroda-san's explicit go-ahead in the Spec 02 thread. Kuroda-san's position was "if unused, disable it and keep 02d out of scope" and the "unused" condition is now confirmed by Harvey-san in the same thread — so this reads as a satisfied conditional. The 02d JIRA epic should not be created until Kuroda-san posts the explicit confirmation (tracked as 02d O-D3).

---

## Links

- Spec: `projects/asca/specs/asca-spec-02d-datacorrection-integration/requirements.md` (rewritten to the decommission scope)
- Evidence: `ASCA-NOTE-20261005-datacorrection-usage-confirmation.md` (this folder)
- Source feedback: `research/CAP/REF-CAP-12-ASCA-Spec02-Review-G1-20260928.md` §0; `research/CAP/REF-CAP-13-ASCA-Spec02-Review-Round2-20261005.md` §4
- Related: DEVOPS-6706 (representative DevOps direct-SQL correction ticket)
