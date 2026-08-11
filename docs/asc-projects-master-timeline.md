# ASC Projects — Master Timeline

**Last updated:** 2026-08-10  
**Status:** ACTIVE — DB design received from Kuroda-san. Steps 1–5 unblocked. Pending O-3 (prefix) decision before migrations start.  
**Overall Lead:** Noel Palo  
**Deadline:** CAP + CIP = 12/17

---

## Overview

Two ASC projects built on a shared allocation framework (Scenario C — confirmed):

```
ASCH (Honki Set):     Jul 30 ═══ Aug 7 ╳ CANCELLED
ASC Allocation Framework (CAP + CIP):  Aug 2026 ══════════════════ Dec 17
```

**Architecture:** Single `asc_alloc_*` table set shared by both CAP and CIP. 10 tables + 1 view. Projects distinguished by `project_code` column. Sequential execution: CIP first (builds foundation), CAP second (reuses it).

**Design source:** `REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md` (Kuroda-san, Confluence)

---

## Estimate

| Metric | Value | Confidence |
|---|---|---|
| **CIP Dev Effort (incl. shared foundation)** | 6–8 weeks (Noel + Throy) | Medium — design received, steps 1–5 unblocked |
| **CAP Dev Effort (reuses foundation)** | 3–4 weeks (Orlino + Cristoff, Noel oversees) | Medium |
| **Total Dev Effort (sequential)** | 9–12 weeks | Medium |
| **QA Effort** | 5–7 weeks (overlapping with dev) | Low — scenarios pending |
| **End-to-end** | 10–13 weeks | Medium |
| **Deadline** | 2026/12/17 | Fixed |
| **Latest start to fit deadline** | ~Mid-September | Medium |
| **First production run** | 2027/01/01 | Fixed |
| **Execution model** | Sequential: CIP first (builds foundation), CAP second | Confirmed |

---

## What's Blocking

| # | Blocker | Owner | Status | Impact |
|---|---|---|---|---|
| 1 | ~~Updated requirements~~ | ~~Kuroda-san~~ | ✅ **Received** (2026-08-10 DB design) | Unblocked |
| 2 | ~~Formula confirmation~~ | ~~Kuroda-san~~ | ✅ **Confirmed** (same formula, Section 6) | Unblocked |
| 3 | ~~How App is bundled~~ | ~~Kuroda-san~~ | ✅ **Confirmed** (normalized bundle layer, Section 8) | Unblocked |
| 4 | ~~Design updates~~ | ~~Kuroda-san~~ | ✅ **Received** (full DB design, 10 tables) | Unblocked |
| 5 | **O-3: Table prefix decision** | Engineering team | ⚠️ **OPEN** — blocks Step 1 (migrations) | Blocks start |
| 6 | Start date decision | Patrick-san / Kuroda-san | ⚠️ **Pending** | Blocks timeline |
| 7 | O-1: CAP dedicated App product_id | CAP app team | ⚠️ Open — blocks CAP detection only (Step 4) | Does not block start |
| 8 | O-5: CIP reference prices | Business + Accounting | ⚠️ Open — blocks CIP finalize + QA only | Does not block start |

**Key insight from Kuroda-san:** Steps 1–5 (migrations, models, run lifecycle, reference prices, allocation engine) do NOT depend on any open item. Work can start once O-3 (prefix) is decided.

---

## Team Assignments

| Project | Lead | Sub-Lead | Developer | QA | UAT |
|---|---|---|---|---|---|
| **CIP** (first — builds shared foundation) | Noel Palo | — | Throy Embudo | Miko | Business / Miyachi-san |
| **CAP** (second — reuses foundation) | Noel Palo (oversees) | Orlino | Cristoff Danganan | Glenn | Business / Miyachi-san |

**Sequential execution:** CIP builds the shared framework + CIP-specific logic. CAP plugs in after.

---

## Implementation Order (from Kuroda-san's design, Section 11)

| # | Step | Blocked by | Est. duration |
|---|---|---|---|
| 1 | Naming decision + 10 migrations + structure tests | O-3 (prefix) | 2 wk |
| 2 | Models, resources, enums, run lifecycle service | None | 1 wk |
| 3 | Reference-price master + price resolution service | None | 0.5 wk |
| 4 | Detection Strategy + bundle generation | O-1 (CAP only) | 1 wk |
| 5 | Allocation engine + validations V-1 to V-5 | None | 1.5 wk |
| 6 | Refund allocation (record_kind = 1) | None | 1 wk |
| 7 | Summary aggregation + Freee thin sender + deliveries | CIP RA-05 | 1.5 wk |
| 8 | CSV generation + unified email orchestrator | CIP RA-13 (email approval) | 1 wk |
| 9 | Reversal (record_kind = 2) | O-4 | 1 wk (post-release OK) |

**Steps 1–5 are unblocked now.** Steps 6–8 have minor dependencies. Step 9 can ship after release.

---

## DB Schema (10 tables + 1 view)

| # | Table | Role |
|---|---|---|
| 1 | `asc_alloc_calculation_runs` | Run management (+ project_code) |
| 2 | `asc_alloc_source_documents` | Immutable input snapshots |
| 3 | `asc_alloc_bundles` | Bundle header (primary_charge_id, match_rule) |
| 4 | `asc_alloc_bundle_charges` | Products per bundle (always 2 today) |
| 5 | `asc_alloc_groups` | One bundle × one month (ΣN, ΣP, is_balanced) |
| 6 | `asc_alloc_prorations` | Core: one row per product per group |
| 7 | `asc_alloc_reference_prices` | Allocation weights (effective-dated) |
| 8 | `asc_alloc_sum_calculation` | Freee aggregation |
| 9 | `asc_alloc_sum_calculation_history` | Trace: summary → allocation rows |
| 10 | `asc_alloc_deliveries` | Freee/CSV/email attempt tracking |
| 11 | `v_asc_alloc_prorations_active` | View for active-run queries |

---

## Key Dates

| Date | Event |
|---|---|
| 2026/08/07 | ASCH project cancelled |
| 2026/08/10 | DB design received from Kuroda-san |
| TBD (pending O-3) | Development start (Step 1: migrations) |
| ~W5 after start | Allocation engine complete (Steps 1–5 done) |
| ~W8 after start | Dev complete (all steps) |
| ~W10–12 after start | QA regression + sign-off |
| **2026/12/17** | **CAP + CIP production deadline** |
| **2027/01/01** | **First production batch run** |

---

## Open Items (from Kuroda-san's design)

| ID | Item | Owner | Blocks |
|---|---|---|---|
| O-1 | CAP dedicated App product_id | CAP app team | CAP detection (Step 4) only |
| O-2 | Asymmetric discount assumption (CIP RA-04) | Accounting | If rejected, proration_basis comes back |
| O-3 | `asc_alloc_*` prefix naming convention | Engineering team | **Step 1 (migrations)** |
| O-4 | B2B App reversal logic (CAP F-15) | Accounting + CAP app | Step 9 (post-release OK) |
| O-5 | CIP reference prices | Business + Accounting | CIP finalize + QA only |
| O-6 | Unified email subject/body format | Accounting | Step 8 |

---

## Next Steps

1. **Engineering (Noel):** Decide O-3 (table prefix) — recommend `asc_alloc_*` as proposed
2. **Engineering (Noel):** Review and respond to Kuroda-san's design (4 questions in Section 13)
3. **Patrick-san:** Confirm start date and team availability
4. **Dev:** Once O-3 decided → begin Step 1 (migrations + structure tests)

---

## Source

- Original timeline: Kuroda-san's combined schedule (2026-07-30)
- ASCH cancellation: Emergency meeting 2026-08-07 (Kuroda-san)
- DB design: `REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md` (Kuroda-san, Confluence)
- Estimate: `docs/asc-cap-cip-combined-estimate-20260808.md` (tentative)
