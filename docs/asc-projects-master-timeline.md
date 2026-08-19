# ASC Projects — Master Timeline

**Date:** 2026-08-10 (Created) · 2026-08-17 (JIRA codes confirmed, synced with Scenario D)  
**Status:** ACTIVE — Technical design agreed with Kuroda-san. JIRA projects created (ASCA, ASCI). Ready to start once O-3 decided.  
**Overall Lead:** Noel Palo  
**Assisted by:** Kiro  
**Deadline:** ASCA + ASCI = 2026/12/17

### JIRA Projects

| Code | Project | Board | Backlog |
|---|---|---|---|
| ASC | ASCM (Accounting System Changes — Monthly) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASC/boards/1186/backlog) |
| ASCH | ASC Honki Set (cancelled) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/boards/1753/backlog) |
| **ASCA** | **ASC for CAP** (active — builds foundation) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog) |
| **ASCI** | **ASC for CIP** (active — reuses foundation) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) | [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog) |

**Note:** "ASC" is the JIRA code for ASCM. The original project was named just "ASC" before subsequent projects (ASCH, ASCA, ASCI) were created.

---

## Overview

```
ASCH (Honki Set):                    Jul 30 ═══ Aug 7 ╳ CANCELLED
ASCA + ASCI (Allocation):            Sep 2026 ══════════════════════ Dec 17
Upstream CAP (Keith's team):         In progress ════════════════════ Late Nov / Early Dec
Upstream CIP (Jefferson's team):     In progress ════════════════════ Late Nov / Early Dec
```

**What we're building:** A shared allocation framework that splits Coaching charge revenue between Coaching and App products, injected into the existing accounting batch commands.

**Architecture:** Scenario D (injection into existing commands) + Option 1 (Overwrite N→P). Single injection point in `CommonUtil::createDailyRateCalculation()`. Shared `asc_alloc_*` tables with `project_code` column.

**Technical design:** `docs/asc-allocation-framework-technical-design.md` (authoritative)

---

## Terminology

| Term | Full Name | What it is | Owner |
|---|---|---|---|
| **CAP** | Coaching and App Plan | Upstream project — creates new plans 1016–1027 in MBTI_backend | CAP team (Keith, Terry) |
| **CIP** | Coaching Intensive Plan | Upstream project — creates new product 10022 with plans 1028–1032 in MBTI_backend | CIP team (Jefferson) |
| **ASCA** | ASC for CAP | Our project — allocates CAP coaching charge revenue | Noel's team |
| **ASCI** | ASC for CIP | Our project — allocates CIP coaching charge revenue | Noel's team |

**The upstream projects create the charges. Our projects allocate the revenue.**

---

## People & Roles

**Management Partners (JP ↔ PH):**

| Japan (JP) | Philippines (PH) | Scope |
|---|---|---|
| Hayato Kuroda (PM) | Roi Patrick Florentino (SDM) | ASC / Accounting projects |
| Soli Sahukar (PM) | Jasser Balido (SDM) | CAP / CIP upstream projects |

**Development Teams:**

| Project | Lead | Sub-Lead | Developer(s) | SDM |
|---|---|---|---|---|
| **CAP** (upstream) | Keith Manuntag | — | Terry Balahadia | Jasser-san |
| **CIP** (upstream) | Jefferson Gernale | — | Haggai Rei Cacacho | Jasser-san |
| **ASCA** (first) | Noel Palo | — | Throy Embudo | Patrick-san |
| **ASCI** (second) | Noel Palo | Orlino Monares | Cristoff Danganan | Patrick-san |
| **CDB** (upstream) | Paolo | — | Efren | Patrick-san |
| **ASCM** (completed) | Noel Palo | — | Team (deployed Jun 2026) | Patrick-san |
| **ASCH** (cancelled) | Noel Palo | — | — | Patrick-san |

---

## Current Approach (Scenario D + Option 1)

| Decision | Chosen | Why |
|---|---|---|
| Architecture | Scenario D — inject into existing commands | Saves ~3 weeks vs standalone. Proven pattern (monthly rate). Same email/zip. |
| Timing | Option 1 — Overwrite N→P inside CommonUtil | 1 Freee API call. Zero downstream changes. Idempotent. |
| Injection point | `CommonUtil::createDailyRateCalculation()` | Covers Pre, Final, and DataCorrection batches. |
| N definition | Σ(paid_price) across bundle (coaching + app) | Idempotent by construction — safe on re-runs. |
| Bundle grouping | student_id + order_no | Handles cancel+repurchase, simultaneous plans. |
| Detection | product_id 10021 (App) + plan_id enums | Stable anchor. Works for both CAP and CIP. |
| Execution order | ASC-CAP first → ASC-CIP second | CAP requirements more concrete. CIP reuses foundation. |

---

## Estimate (Scenario D)

| Metric | Value | Confidence |
|---|---|---|
| **ASCM Prep** | 5–7 days | High — no blockers, can start immediately |
| **ASC-CAP Dev (incl. shared foundation)** | 4–5 weeks (Noel + Throy) | Medium-High |
| **ASC-CIP Dev (reuses foundation)** | 1–1.5 weeks | High — configuration only |
| **Total Dev** | 5.5–6.5 weeks | Medium-High |
| **QA** | 4–5 weeks (overlapping with dev) | Medium |
| **End-to-end** | 7–9 weeks | Medium |
| **Deadline** | 2026/12/17 | Fixed |
| **Latest start (comfortable)** | Mid-September | Gives 1 week buffer |
| **Latest start (tight)** | Early October | 3 days buffer ⚠️ |
| **First production batch** | 2027/01/01 | Fixed |

**Full Gantt:** `docs/asc-alloc-scenario-d-injection-timeline-20260811.md`

---

## Confirmed Data

| Item | CAP | CIP |
|---|---|---|
| Plan IDs | 1016–1027 (12 plans) | 1028–1032 (5 plans) |
| Coaching product_id | 10005 (15min) / 10015 (30min) | 10022 (Intensive) |
| App product_id | 10021 | 10021 |
| L_coaching (reference) | ¥19,800 (15min) / ¥39,600 (30min) | ¥84,020 (= plan ¥88,000 − L_app) |
| L_app (reference) | ¥3,980 | ¥3,980 |
| App charge in trn_charge | ¥0 (companion) | ¥0 (companion) |
| Date filter needed? | No (new plans) | No (new plans) |
| Upstream prod date | Late Nov / early Dec | Late Nov / early Dec |

---

## Implementation Phases

### Phase 0: ASCM Prep (Pre-W0, 5–7 days — no blockers)

| Task | Effort |
|---|---|
| Extract BatchReportDeliveryService from DailyRateCalcPre + SendJournals | 1–2 days |
| Fix DataCorrectionLogic drift: add BizmatesMonthlyPlanEnum skip + missing fields | 0.5–1 day |
| Unit test + smoke test all 3 batches on DEV04 (baseline) | 1 day |
| Document baseline CSV file list | 0.5 days |
| Create test data seeder for CAP/CIP charges | 1 day |
| Review DB design, prepare migration plan | 0.5 days |

### Phase 1: Shared Foundation (W0–W3)

| Step | What | Blocked by |
|---|---|---|
| 1 | 10 migrations + 1 view + structure tests | **O-3 (prefix)** |
| 2 | Models, enums, run lifecycle service | None |
| 3 | Reference-price master + price resolution | None |
| 4 | Detection strategy + bundle generation | None (O-1 resolved) |
| 5 | Allocation engine + ΣN computation + validations | None |

### Phase 2: ASC-CAP (W3–W6)

| Step | What |
|---|---|
| 6 | Injection into CommonUtil (Option 1 Overwrite) |
| 7 | AllocationDetail CSV generation + config |
| 8 | DataCorrectionLogic: add `allocateForCharge()` call |
| 9 | Refund allocation (record_kind = 1) |
| 10 | DEV04 full pipeline testing (Pre + Final) |

### Phase 3: ASC-CIP (W6–W7)

| Step | What |
|---|---|
| 11 | CIP detection strategy (CoachingIntensivePlanEnum: 1028–1032) |
| 12 | CIP reference price config (L_coaching = ¥84,020) |
| 13 | DEV04 testing for CIP plans |

### Phase 4: Post-Release (W8+)

| Step | What |
|---|---|
| 14 | Reversal (record_kind = 2) — ships after first prod run |
| 15 | Metabase saved query for Accounting (allocation breakdown) |

---

## Blockers & Open Items

| ID | Item | Owner | Status | Blocks |
|---|---|---|---|---|
| **O-3** | **Table prefix (`asc_alloc_*`)** | **Engineering team** | **⚠️ OPEN** | **Step 1 (migrations)** |
| O-1 | CAP App product_id | CAP team | ✅ Resolved — 10021 (2026-08-12) | — |
| O-2 | Asymmetric discount (CIP RA-04) | Accounting | Low risk — if rejected, proration_basis returns | — |
| O-4 | B2B App reversal logic | Accounting + CAP | Post-release (Step 14) | — |
| O-5 | CIP coaching reference price | Accounting | ✅ Resolved — ¥84,020 (2026-08-17) | — |
| O-6 | Allocation breakdown for Accounting | Accounting | ✅ Resolved — CSV in zip + Metabase (2026-08-17) | — |
| P-3 | CAP new coaching product_id | CAP team | ⚠️ Non-blocking — detection uses product 10021 + plan_id. Config update if confirmed. | — |

**Only O-3 blocks development start.**

---

## Key Dates

| Date | Event |
|---|---|
| 2026/08/07 | ASCH cancelled |
| 2026/08/10 | DB design received from Kuroda-san |
| 2026/08/11 | Scenario D proposed |
| 2026/08/12 | CAP pricing + plan_ids confirmed (REF-CAP-05/06/08) |
| 2026/08/13 | CIP project spec received — new product 10022, plans 1028–1032 (REF-CIP-03) |
| 2026/08/14 | Option 1 (Overwrite) proposed by Kuroda-san. Idempotency design (ΣN). |
| 2026/08/17 | CIP price corrected to ¥84,020. Bundle grouping (order_no). O-5/O-6 resolved. |
| TBD | **O-3 decided → ASCM Prep starts** |
| TBD + 1 week | **Foundation starts (Step 1)** |
| ~W6 after start | **ASC-CAP dev complete** |
| ~W7 after start | **ASC-CIP dev complete** |
| Late Nov | Upstream CAP/CIP go to production |
| ~W11 after start | QA sign-off |
| **2026/12/17** | **Production deadline** |
| **2027/01/01** | **First real batch run** |

---

## Next Steps (as of 2026-08-17)

1. **Noel:** Decide O-3 (table prefix) — recommend `asc_alloc_*` as proposed. Communicate to Kuroda-san.
2. **Noel:** Confirm P-3 with CAP team (Keith/Terry) — will coaching product_id change?
3. **Patrick-san:** Confirm start date and team availability.
4. **Noel:** Begin ASCM Prep (no blockers — can start before O-3 is decided).
5. **Once O-3 decided:** Step 1 — migrations + structure tests.

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

## Source Documents

| Document | What it covers |
|---|---|
| `docs/asc-allocation-framework-technical-design.md` | **Authoritative technical design** — formula, data flow, code, injection |
| `docs/asc-alloc-scenario-d-injection-timeline-20260811.md` | Full Gantt, calendar mapping, QA timeline |
| `docs/asc-cap-cip-combined-estimate-20260808.md` | Historical — Scenario C estimate (superseded) |
| `projects/asch/documentation/asc-alloc-integration-discussion-notes-20260811.md` | Design session notes |
| `projects/asch/technical-notes/research/CAP/REF-CAP-04` | Kuroda-san DB design |
| `projects/asch/technical-notes/research/CAP/REF-CAP-05` | Confirmed pricing (Slack thread) |
| `projects/asch/technical-notes/research/CAP/REF-CAP-06` | CAP price mechanism (Confluence) |
| `projects/asch/technical-notes/research/CAP/REF-CAP-07` | Option 1 Overwrite (Confluence + verified) |
| `projects/asch/technical-notes/research/CAP/REF-CAP-08` | CAP requirements decision log |
| `projects/asch/technical-notes/research/CIP/REF-CIP-03` | CIP project spec (Jefferson) |
| `domain-knowledge/plans-and-products.md` | Full plan/product reference |
