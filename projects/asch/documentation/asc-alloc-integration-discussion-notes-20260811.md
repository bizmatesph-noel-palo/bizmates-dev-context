# ASC-CAP/CIP Integration — Discussion Notes

**Date:** 2026-08-11  
**Participants:** Noel Palo (Lead Dev)  
**Assisted by:** Kiro (AI-assisted code analysis and document generation)  
**Context:** Post-ASCH cancellation. Exploring injection approach for CAP/CIP into existing commands.  
**Status:** Internal design session — pending review with Patrick-san and Kuroda-san

---

## Background

- ASCH (Honki Set proration) was cancelled on 2026-08-07
- CAP and CIP proceed as a unified "ASC Allocation Framework"
- **ASCH is no longer the base structure** — the shared framework must be built from scratch as part of CAP (first project)
- Kuroda-san delivered DB design (REF-CAP-04) on 2026-08-10 with 10 tables + 1 view
- Original plan: standalone commands with separate email delivery (inherited from ASCH design)
- **New proposal:** Inject allocation logic into existing commands (no ASCH predecessor needed)
- Execution order: **CAP first** (builds foundation), **CIP second** (reuses it)

---

## Key Decision: Injection vs Standalone Commands

### Proposed Approach (Injection)

Inject ASC-CAP and ASC-CIP allocation logic into the existing:
- `DailyRateCalculationPreLogic` (Pre/速報)
- `SendJournalsDataLogic` (Final/確定 + Freee send)

Same pattern as how MonthlyRateCalculation was added to the existing pipeline.

### Rationale

1. **Proven pattern** — Monthly rate commands were injected the same way. It works.
2. **Single operational flow** — Same cron, same commands, no new scheduling.
3. **Single email/zip** — Accounting team receives one deliverable (not two).
4. **N value dependency is solved** — Allocation runs AFTER daily calc in the same command, guaranteeing N exists.
5. **Timeline savings** — ~1.5–2 weeks not spent building email/zip infrastructure that ASCH would have provided (now cancelled).
6. **No ASCH prerequisite** — With ASCH gone, injection lets us skip building standalone infrastructure entirely. The existing commands ARE the infrastructure.

### What Changes in Existing Code

| File | Change | Risk |
|---|---|---|
| `DailyRateCalculationPreLogic.php` | +12 lines: service call + CSV merge + delete scope | LOW |
| `SendJournalsDataLogic.php` | +18 lines: service call + 2nd Freee send + CSV merge | LOW |
| `config/const.php` | +30 lines: CSV header definitions | ZERO |
| `config/code.php` | +5 lines: App product_type mapping | ZERO |

**All new logic is isolated in `app/Libs/AscAllocation/`** — clean namespace, testable, doesn't touch existing calculation code.

---

## Decisions Made

| # | Decision | Rationale |
|---|---|---|
| 1 | **Inject into existing commands** (not standalone) | Follows Monthly Rate pattern. Less operational overhead. |
| 2 | **Second Freee API call** (not merged into existing $detailList) | Failure isolation. If allocation send fails, existing journals are safe. |
| 3 | **Same ZIP, same email** (not separate delivery) | Simpler for accounting team. No REF-07 orchestrator needed. |
| 4 | **Extract BatchReportDeliveryService** (zip+email) | 1–2 day effort. Enables conditional CSV inclusion. Eliminates one duplication between Pre/Final. |
| 5 | **Skip broad refactoring** of existing Logic classes | Too risky (financial code, tested in production). Injection is additive. |
| 6 | **Single AscAllocationService with $preFlg parameter** | Avoids Pre/Final duplication (KB #14). One implementation, two modes. |
| 7 | **Bizmates-only** (no Zipan) | CAP/CIP products don't exist on Zipan. Avoids tenant duplication (KB #13). |
| 8 | **Delete by target_ym + project_code** (not created_at) | Follows KB #15 lesson. Safe re-runs. |

---

## Scope Assessment

### New Code Required

| Component | Files | Effort |
|---|---|---|
| Eloquent models (10 tables) | 8–10 files | 2 days |
| Enums (ProjectCode, RunType, RecordKind) | 4 files | 0.5 days |
| AscAllocationService (orchestrator) | 1 file | 3 days |
| Detection strategies (CAP + CIP) | 3 files | 1 day |
| AllocationEngine (formula) | 1 file | 1 day |
| JournalEntryBuilder (Freee arrays) | 1 file | 1 day |
| CsvGenerator | 1 file | 1 day |
| RunLifecycleService (3-txn model) | 1 file | 1 day |
| ReferencePriceService | 1 file | 0.5 days |
| BatchReportDeliveryService (extracted) | 1 file | 1 day |
| Config entries | 2 files | 0.5 days |
| **TOTAL NEW CODE** | **~24 files** | **~12.5 days** |

### Database (ls-database-migrations)

| Item | Count | Effort |
|---|---|---|
| Migration files (10 tables + 1 view) | 11 files | 2 days |
| Structure tests | 10 files | auto-generated |
| Reference price seeder | 1 file | 0.5 days |
| **TOTAL DB** | **~22 files** | **~2.5 days** |

### Testing

| Type | Effort |
|---|---|
| Unit tests (engine, strategies, builder) | 3–4 days |
| Integration test (full pipeline) | 2–3 days |
| **TOTAL TESTING** | **~5–7 days** |

### Grand Total

| Phase | Effort | Notes |
|---|---|---|
| ASCM Prep (Pre-W0) | 3–5 days | Extract delivery service, baseline verification, test data seeder. No blockers — can start immediately. |
| CAP (first — builds shared foundation + CAP-specific) | 4–5 weeks | Noel + Throy. Foundation is built here since ASCH is cancelled. |
| CIP (second — reuses foundation, adds CIP detection + prices) | 1–1.5 weeks | Reuses everything from CAP. Only adds CIP-specific strategy + config. |
| **Combined dev** | **5.5–6.5 weeks** | Excludes ASCM prep (runs before/parallel) |
| **End-to-end (dev + QA)** | **7–9 weeks** | See full timeline: `docs/asc-alloc-scenario-d-injection-timeline-20260811.md` |

**Execution order rationale:** With ASCH cancelled, there is no pre-existing base structure to inherit. The shared allocation framework (migrations, models, enums, run lifecycle, allocation engine, Freee sender, CSV/email delivery) must be built from scratch as part of the first project. CAP is chosen as first because its requirements are more concrete (reference prices partially known, App product_id being decided). CIP follows and only needs its own detection strategy + reference prices plugged into the already-working framework.

**What ASCH cancellation means for scope:** The shared allocation framework (migrations, models, enums, run lifecycle, allocation engine, Freee sender, CSV/email delivery) must be built from scratch as part of CAP (first project). Whichever project goes first carries the full infrastructure cost (~12.5 days). The second project (CIP) is a configuration exercise (~3–5 days). The total remains the same regardless of order — the question is which project's requirements are ready first. CAP's are more concrete today.


---

## Refactoring Discussion

### What was considered

| Refactoring | Effort | Risk | Decision |
|---|---|---|---|
| Pre/Final Logic unification (MonthlyRateCalcPre → single class) | 3–5 days | HIGH — 700-line CTE | **SKIP** — not needed for CAP/CIP |
| CommonUtil extraction (2400-line god class) | 2–3 weeks | HIGH — everything depends on it | **SKIP** — too broad |
| DailyRateCalcPre + SendJournalsData unification | 1–2 weeks | MEDIUM | **SKIP** — injection is additive |
| Global state removal (CommonUtil::setSystemDate) | 3 days | LOW | **SKIP** — new code passes dates explicitly |
| **CSV/ZIP/Email extraction** (BatchReportDeliveryService) | **1–2 days** | **LOW** | **DO IT** — enables conditional CSV, reduces duplication |

### Why extract only the delivery service

1. **Minimal effort** (1–2 days) for high payoff
2. **Enables conditional CSV inclusion** — if allocation fails, CSVs not in zip
3. **Eliminates one duplication** between Pre and Final (same zip+email logic)
4. **Makes injection cleaner** — Logic files call `deliver($fileNameList)` instead of inline zip code
5. **No risk to existing calculation logic** — it's purely the packaging/delivery step

### What we explicitly DON'T refactor

- The CTE pipeline (MonthlyRateCalculation) — works, don't touch it
- The daily rate calculation (CommonUtil::createDailyRateCalculation) — works
- The Freee journal building (sendFreeeJournals2 T1/T2/T3) — works
- The balance transition logic — works
- Any existing model or query — works

---

## Advantages vs Previous Approach (Standalone Commands)

> **Context:** The "previous approach" refers to Scenario C — standalone commands + a separate unified email orchestrator (REF-07). That design assumed ASCH would be built first as the foundation, with CAP/CIP inheriting its infrastructure. Since ASCH is cancelled, the standalone approach would require building that infrastructure from scratch — making it significantly more expensive than originally estimated. This proposal (Scenario D) is an alternative integration strategy within the same combined framework.

| Dimension | Injection (our approach) | Standalone (previous ASCH plan) |
|---|---|---|
| Operational complexity | Same cron, same commands | New cron entries, new commands to monitor |
| Email delivery | Same email, same zip | Separate email OR complex orchestrator (REF-07) |
| N value dependency | Guaranteed (runs after daily calc) | Scheduling dependency (must ensure order) |
| Failure isolation | Try/catch in pipeline + 2nd Freee call | Complete isolation (separate process) |
| Re-runs | Re-run entire command (includes daily recalc) | Can re-run allocation alone |
| Dev effort | ~12.5 days new code + 1 day injection | ~12.5 days new code + 10 days infrastructure (no ASCH to inherit from) |
| Timeline to deadline | ✅ Fits Dec 17 with buffer | ⚠️ Tighter (no ASCH foundation + infrastructure adds 1.5–2 weeks) |
| Code maintainability | New code isolated in namespace. Existing files +25 lines. | Fully separate but duplicates zip/email |
| Testing | Unit test service. E2E = run existing command. | Unit test + must test new command separately |
| Accounting team impact | Zero change — same email format | Must check two emails or learn new format |

### Disadvantage we accept

| Disadvantage | Mitigation |
|---|---|
| Can't re-run allocation alone (full command re-runs daily too) | Add thin `AscAllocationDebugCommand` for dev/testing that calls service directly |
| If allocation throws unexpectedly past try/catch, kills parent | Defensive: catch `\Throwable`, never let it escape |
| Logs are interleaved with existing flow | Clear `[ASC_ALLOC]` prefix on all allocation log entries |
| `SendJournalsDataCommand` grows in responsibility | All new logic in service class — Logic file is just the orchestrator |

---

## Open Items for Patrick-san / Kuroda-san

| # | Item | Question |
|---|---|---|
| 1 | Table prefix | We agree with `asc_alloc_*` — confirm with engineering team (O-3) |
| 2 | Single email approach | Does accounting team agree? Same zip, 2 extra CSVs inside |
| 3 | Second Freee API call | OK to send allocation journals as a separate API call? (Same issue_date, same period) |
| 4 | Start date | When can we begin? Steps 1–5 are unblocked once O-3 decided |
| 5 | Delivery service extraction | 1–2 day investment before injection — acceptable? |
| 6 | ~~App product_id (O-1)~~ | ✅ **RESOLVED (2026-08-12):** product_id 10021 for both CAP and CIP. See REF-CAP-05. |

---

## Next Steps

1. Share process flow diagram with Patrick-san and Kuroda-san
2. Get confirmation on single email / 2nd Freee call approach
3. Decide O-3 (table prefix) → unblocks migrations
4. Begin Step 1: migrations + structure tests
5. Extract BatchReportDeliveryService (parallel with Step 1)

---

## Updates (2026-08-12)

From `REF-CAP-05-Upstream-Pricing-Discussion-20260812.md` (CAP Slack thread, confirmed by Kuroda-san):

| Item | Confirmed Value |
|---|---|
| App product_id (O-1) | **10021** — applies to both CAP and CIP |
| App reference price | **¥3,980** (tax-inclusive) / ¥3,618 (tax-exclusive) |
| Coaching 15min reference price | **¥19,800** (tax-inclusive) = ¥18,000 × 1.1 |
| Coaching 30min reference price | **¥39,600** (tax-inclusive) = ¥36,000 × 1.1 |
| Allocation method | **Option (C) proportional:** `P_app = floor(N × 3980 / (L_coaching + 3980))` |
| App charge in trn_charge | **¥0** (companion approach — pending final Monday confirmation, "likely") |
| ASC allocation batch | **IS needed** (confirmed — consequence of ¥0 companion approach) |
| Coaching product_ids | **Existing 10005 (15min) / 10015 (30min)** — no new product_id needed |
| ASCH status | **Cancelled (2026-08-07)** — "ASCH provides the foundation" assumption no longer valid |
| Execution order | **CAP first** (builds foundation), **CIP second** (reuses it) |

**Impact on this design:** Step 4 (CAP Detection) is now unblocked — product_id 10021 confirmed. Reference prices can be seeded immediately (Step 3). The injection approach remains valid.

---

## Reference Documents

| Document | Location |
|---|---|
| **Scenario D timeline (full Gantt)** | **`docs/asc-alloc-scenario-d-injection-timeline-20260811.md`** |
| Process flow diagram | `documentation/diagrams/asc-alloc-injection-process-flow.md` |
| Kuroda-san DB design | `technical-notes/research/CAP/REF-CAP-04-ASC-Alloc-Framework-DB-Design-20260810.md` |
| Master timeline (Scenario C) | `docs/asc-projects-master-timeline.md` |
| Combined estimate (Scenario C) | `docs/asc-cap-cip-combined-estimate-20260808.md` |
| ASCH engineering standards (reusable) | `documentation/asch-engineering-standards.md` |
| ASCM knowledge base (lessons learned) | `projects/ascm/knowledge-base/` |
