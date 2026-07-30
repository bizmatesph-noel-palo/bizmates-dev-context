# ASC Projects — Master Timeline

**Last updated:** 2026-07-30  
**Status:** Draft (from Kuroda-san's combined schedule — pending dev team alignment)  
**Overall Lead:** Noel Palo  
**Deadline:** ASCH = 10/1, CAP + CIP = 12/17

---

## Overview

Three ASC (Accounting System Changes) projects run sequentially then in parallel:

```
ASCH (Honki Set):     Jul 30 ════════════ Oct 1
ASC for CAP:                               Oct 12 ══════════════════ Dec 17
ASC for CIP:                               Oct 12 ══════════════════ Dec 17
```

All three share:
- Same code repo (`accounting_related_system_for_freee`)
- Same architectural pattern (run_id model, separate command, T1 journals)
- Same schema repo (`ls-database-migrations`)
- Same overall lead (Noel)
- Different table namespaces (`asch_*`, `cap_*`, `cip_*`)

---

## Team Assignments

| Project | Lead | Developer(s) | QA | UAT |
|---|---|---|---|---|
| **ASCH** | Noel Palo | Throy Embudo, Cristoff Danganan | Alvin, Jaymiriz | — |
| **ASC for CAP** | Noel Palo | Throy, Raymark | Glenn, Aryz | Business / Miyachi-san |
| **ASC for CIP** | Noel Palo | Bricx, Orlino | Mico, Eloid | Business / Miyachi-san |

**Note:** After ASCH completes (Oct 1), Throy transitions from ASCH to CAP.

---

## Schedule

### ASCH (ASC for Honki Set)

| Milestone | Date | Duration |
|---|---|---|
| Development start | 2026/07/30 (actual) / 2026/08/03 (official) | |
| Dev complete | ~2026/09/21 | 8 weeks |
| QA + buffer | 2026/09/22 – 2026/10/01 | ~1.5 weeks |
| **Production deadline** | **2026/10/01** | |

### ASC for CAP (Coaching App Plan)

| Milestone | Date | Duration |
|---|---|---|
| Development start | 2026/10/12 | |
| Dev complete | ~2026/11/23 | 6–7 weeks |
| QA Test Planning | 2026/10/05 – 2026/10/12 | 1 week (before dev starts) |
| QA Test Case Creation / Data Prep | 2026/10/12 – 2026/11/02 | 3 weeks |
| QA Test Execution + Bug Fix/Retest | 2026/11/09 – 2026/12/07 | 4 weeks |
| Regression | 2026/12/07 – 2026/12/14 | 1 week |
| Release Sign-off | 2026/12/14 – 2026/12/17 | |
| UAT | TBD (Business / Miyachi-san) | |
| **Production deadline** | **2026/12/17** | |

### ASC for CIP (Coaching Intensive Plan)

| Milestone | Date | Duration |
|---|---|---|
| Development start | 2026/10/12 | |
| Dev complete | ~2026/11/23 | 6–7 weeks |
| QA Test Planning | 2026/10/05 – 2026/10/12 | 1 week |
| QA Test Case Creation / Data Prep | 2026/10/12 – 2026/11/02 | 3 weeks |
| QA Test Execution + Bug Fix/Retest | 2026/11/09 – 2026/12/07 | 4 weeks |
| Regression | 2026/11/30 – 2026/12/14 | |
| Release Sign-off | 2026/12/14 – 2026/12/17 | |
| UAT | TBD (Business / Miyachi-san) | |
| **Production deadline** | **2026/12/17** | |

---

## Combined View (Weekly)

| Week Start | ASCH | ASC for CAP | ASC for CIP |
|---|---|---|---|
| 07/30 | W1: Foundation | — | — |
| 08/04 | W2: Foundation | — | — |
| 08/11 | W3: Eligibility + Pattern 1 | — | — |
| 08/18 | W4: Pattern 1 | — | — |
| 08/25 | W5: Patterns 2–9 | — | — |
| 09/01 | W6: Patterns 2–9 | — | — |
| 09/08 | W7: Freee + CSV | — | — |
| 09/15 | W8: Dev testing | — | — |
| 09/22 | W9: Buffer + QA | — | — |
| 09/29 | W10: Buffer → **10/1 Production** | — | — |
| 10/05 | — | QA: Test Planning | QA: Test Planning |
| 10/12 | — | W1: Foundation | W1: Foundation |
| 10/19 | — | W2: Foundation | W2: Foundation |
| 10/26 | — | W3: Eligibility + Allocation | W3: Eligibility + Allocation |
| 11/02 | — | W4: Scenarios | W4: Scenarios |
| 11/09 | — | W5: Scenarios | W5: Scenarios |
| 11/16 | — | W6: Freee + CSV | W6: Freee + CSV |
| 11/23 | — | W7: Dev testing + buffer | W7: Dev testing + buffer |
| 11/30 | — | QA: Test Execution | QA: Test Execution |
| 12/07 | — | QA: Regression | QA: Regression |
| 12/14 | — | Release Sign-off | Release Sign-off |
| 12/17 | — | **Production** | **Production** |

---

## Dependencies Between Projects

### ASC project dependencies (what we build)

```
ASCH ──────→ CAP (ASCH code = reference template for CAP)
ASCH ──────→ CIP (ASCH code = reference template for CIP)
CAP ╌╌╌╌╌╌╌ CIP (independent — no dependency, run in parallel)
```

### Upstream project dependencies (other teams — dates TBD)

Our ASC projects read data that upstream projects produce. If the upstream project isn't live, our ASC project has nothing to calculate against in production.

| Our Project | Depends on | What they provide | Their team | Production date | Status |
|---|---|---|---|---|---|
| **ASCH** | CDB (Campaign Discount Batch) | `trn_campaign_discount_eligibility` with real student data | Paolo (lead), Efren (dev) | Before 10/1 | TBD — confirm with CDB team |
| **ASC for CAP** | CAP (app-side) | CAP Coaching + App charges in `trn_charge` | Application-side team | Before 12/17 | TBD — confirm with CAP team |
| **ASC for CIP** | CIP (app-side) | CIP Coaching + App charges in `trn_charge` | Application-side team | Before 12/17 | TBD — confirm with CIP team |

**Rule:** Our ASC development can proceed independently (using seed data). But production go-live requires the upstream project to be live and producing real charge data.

| Phase | Needs upstream? | Why |
|---|---|---|
| Dev (foundation, logic, tests) | No — we seed our own test data | |
| DEV04 integration testing | Ideally yes — real data validates end-to-end | Fallback: use seeded data |
| **Production run** | **Yes — mandatory** | No real charges = no real calculation = no journals to send |

### What to track with other teams

| Question | Ask who | When needed |
|---|---|---|
| When will CDB be live with July + April cohort data? | Paolo / Wu-san | Before ASCH 10/1 production run |
| When will CAP charges appear in production `trn_charge`? | CAP app-side team | Before ASC-for-CAP 12/17 production run |
| When will CIP charges appear in production `trn_charge`? | CIP app-side team | Before ASC-for-CIP 12/17 production run |

---

## Effort Summary

| Project | Formula | Complexity | Lead + 2 Devs | Deadline | Buffer |
|---|---|---|---|---|---|
| ASCH | 3-product, conditional basis | High (9 patterns) | 8–9 weeks | 10/1 | ~9 days |
| ASC for CAP | 2-product, fixed ratio | Low–Medium | 6–7 weeks | 12/17 | ~3 weeks |
| ASC for CIP | 2-product, fixed ratio | Low–Medium | 6–7 weeks | 12/17 | ~3 weeks |

---

## Key Dates

| Date | Event |
|---|---|
| 2026/07/30 | ASCH development starts (actual) |
| 2026/08/03 | ASCH official start date |
| 2026/10/01 | **ASCH production deadline** |
| 2026/10/05 | CAP + CIP QA test planning starts |
| 2026/10/12 | CAP + CIP development starts |
| 2026/11/23 | CAP + CIP dev complete (expected) |
| 2026/12/17 | **CAP + CIP production deadline** |
| 2027/01/01 | CIP first batch run (Jan monthly close) |

---

## Risks Across All 3 Projects

| Risk | Affects | Impact | Mitigation |
|---|---|---|---|
| ASCH delays past 10/1 | CAP + CIP (no reference template) | Start delayed | CAP/CIP can start with docs only (less efficient) |
| Lead (Noel) bandwidth | All 3 | Review bottleneck | Sub-leads for CAP/CIP handle day-to-day reviews |
| CDB not ready for production | ASCH | Fallback needed for 10/1 | Self-detection fallback already designed |
| December holidays | CAP + CIP | Reduced availability | Buffer built into schedule |
| First-time SDD friction | ASCH (first project) | Slower than estimated | Buffer + early start mitigates |
| QA finds critical issues late | All | Rework delays release | Parallel QA testing (test each spec after delivery) |

---

## Source

This timeline is based on Kuroda-san's "ASC for CAP / CIP — Combined Dev + QA Schedule (Draft, weekly)" shared 2026-07-30. Pending final alignment with dev team.
