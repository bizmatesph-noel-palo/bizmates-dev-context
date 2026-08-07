# ASC Projects — Master Timeline

**Last updated:** 2026-08-08  
**Status:** REVISED — ASCH cancelled (2026-08-07). CAP + CIP pending updated requirements.  
**Overall Lead:** Noel Palo  
**Deadline:** CAP + CIP = 12/17

---

## Overview

~~Three~~ Two ASC (Accounting System Changes) projects, to be built on a shared allocation framework:

```
ASCH (Honki Set):     Jul 30 ═══ Aug 7 ╳ CANCELLED
ASC for CAP + CIP:    TBD (pending requirements) ══════════════ Dec 17
```

**What changed (2026-08-07):** Business decided to cancel ASCH (Honki Set proration). The App will be bundled directly into the Coaching Plan via CAP and CIP — no separate Honki Set proration needed. CAP and CIP proceed with the same Dec 17 deadline.

**Current state:** Awaiting updated requirements from Kuroda-san. Previous CAP/CIP estimates assumed ASCH as a prerequisite — those assumptions may no longer hold. No design or timeline is finalized until requirements are confirmed.

---

## Rough Estimate (Tentative — Pending Requirements)

| Metric | Value | Confidence |
|---|---|---|
| Dev Effort | 8–11 weeks (Lead + 2 devs) | Low — requirements not confirmed |
| QA Effort | 5–7 weeks (overlapping with dev) | Low — scenarios not confirmed |
| End-to-end | 10–13 weeks | Low |
| Latest start to fit Dec 17 | ~Mid-September | Medium |
| Recommended approach | Combined ASC Allocation Framework | Medium — pending scope confirmation |

**⚠️ These numbers are rough.** They're based on previous CAP/CIP research (July 2026) which assumed ASCH exists as a prerequisite. With ASCH cancelled, scope may change.

---

## What's Blocking Finalization

| # | Blocker | Owner | Impact |
|---|---|---|---|
| 1 | Updated requirements for CAP/CIP without ASCH context | Kuroda-san | Cannot confirm scope or architecture |
| 2 | Confirmation: does the allocation formula stay the same? | Kuroda-san | Affects complexity estimate |
| 3 | Confirmation: how is App bundled in CAP/CIP now? | Kuroda-san / Business | May change accounting treatment entirely |
| 4 | Design updates from Kuroda-san | Kuroda-san | No design = no specs = no implementation plan |
| 5 | Start date decision | Kuroda-san / Patrick-san | Team availability |

---

## Team Assignments (Tentative)

| Project | Lead | Developer(s) | QA | UAT |
|---|---|---|---|---|
| ~~**ASCH**~~ | ~~Noel Palo~~ | ~~Throy, Cristoff~~ | ~~Alvin, Jaymiriz~~ | ~~—~~ |
| **ASC Allocation Framework + CAP + CIP** | Noel Palo | Throy Embudo, Cristoff Danganan | TBD | Business / Miyachi-san |

---

## Recommended Approach (Subject to Confirmation)

Build a shared ASC Allocation Framework that both CAP and CIP are configurations of:
- Same formula: `App_alloc = N × App_ref / (Coaching_ref + App_ref)`
- Different config: reference prices, plan_id detection
- Same operational model: run management, Freee sending, CSV, unified email

This saves 4–5 weeks vs building them as separate projects. But this recommendation depends on the formula/approach staying the same post-ASCH cancellation.

---

## What's Salvaged from ASCH

| ASCH Artifact | Reusable? | Notes |
|---|---|---|
| Run management (3-transaction lifecycle) | ✅ | Becomes shared foundation |
| Engineering standards (patterns, DTOs, enums) | ✅ | Same standards apply |
| Unified email delivery (REF-07) | ✅ | Same requirement |
| Freee sender analysis (REF-08) | ✅ | Same decision needed |
| DB table design (calculation_runs, source_docs, sum_calc) | ✅ | Rename to generic prefix |
| Requirements specs (signed off) | Partial | Run management + Freee + CSV sections reusable |
| Honki Set proration logic | ❌ | Dropped — ASCH-specific |
| 9 calculation patterns | ❌ | Dropped |
| CDB integration | ❌ | Dropped |

---

## Key Dates

| Date | Event |
|---|---|
| 2026/08/07 | ASCH project cancelled |
| TBD | Updated requirements from Kuroda-san |
| TBD | Design finalization |
| TBD | Development start |
| **2026/12/17** | **CAP + CIP production deadline** |

---

## Next Steps

1. **Kuroda-san:** Provide updated requirements for CAP/CIP accounting in the new context (without Honki Set proration)
2. **Kuroda-san:** Confirm whether the allocation formula/approach stays the same or changes
3. **Dev (Noel):** Once requirements received, refine estimate into a proper plan with Gantt timeline
4. **All:** Confirm start date and team allocation

---

## Source

- Original timeline: Kuroda-san's combined schedule (2026-07-30)
- ASCH cancellation: Emergency meeting 2026-08-07 (Kuroda-san)
- Rough estimate: `docs/asc-cap-cip-combined-estimate-20260808.md` (tentative, pending requirements)

