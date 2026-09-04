# ASCA/ASCI — Development Workflow

## Document Info

| | |
|---|---|
| **Document type** | Development Workflow |
| **Date** | 2026-09-01 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Active |
| **Audience** | Dev team (Noel, Throy, Orlino, Cristoff), Patrick-san (SDM) |
| **JIRA** | [ASCA](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) · [ASCI](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) |
| **Related** | `docs/asc-projects-master-timeline.md` (schedule + gate timing) |

---

## Purpose

Defines the development mechanics for ASCA and ASCI: spec lifecycle, sign-off gates, JIRA structure, branch strategy, and multi-repo coordination. The **master timeline** owns the schedule (which week each phase/gate happens); this doc owns the **how** (how code is managed, reviewed, and merged).

---

## Spec-Driven Lifecycle

Each phase (Foundation, CAP Integration, CIP Integration) follows a spec-driven lifecycle with mandatory gates.

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│  SCAFFOLD        SPECIFY           DESIGN &            TASK        QA &       │
│  (one-time)      (per spec)        TASK GEN            EXECUTION   DEPLOY     │
│                                    (per spec)          (per spec)             │
│  Lead Dev        Lead Dev          Lead Dev            Dev + AI    Lead + QA  │
│  ────────        ────────          ────────            ──────────  ─────────  │
│  Steering files  requirements.md   design.md           Execute     DEV04 →    │
│  (one-time)      → PM sign-off    tasks.md            tasks.md    Staging →  │
│                  ═══ GATE 1 ═══    → Lead + Dev        → Lead PR   Prod      │
│                                    review              review                 │
│                                    ═══ GATE 2 ═══      ═══ GATE 3 ═══        │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Sign-Off Gates

Three mandatory gates where work cannot proceed without approval:

| # | Gate | Who Approves | What's Being Approved | Happens Between |
|---|------|-------------|----------------------|-----------------|
| **G1** | Requirements Sign-Off | PM (Kuroda-san) | Business rules, scope, allocation formula, reference prices, plan detection | Specify → Design |
| **G2** | Design & Tasks Approval | Lead Dev + Dev | Architecture is sound, task breakdown is clear and executable | Design → Task Execution |
| **G3** | Code Review | Lead Dev | Code is correct, follows steering standards, no regressions | Task Execution → Merge |

### What Happens If a Gate Fails

| Gate | If rejected | Who resolves | Timeline impact |
|------|-------------|-------------|-----------------|
| G1 | PM requests scope changes | Lead Dev revises requirements, resubmits | 1–2 days slip |
| G2 | Design has flaws or tasks unclear | Lead Dev revises design/tasks | 0.5–1 day |
| G3 | Code doesn't meet standards | Dev addresses feedback, re-requests review | 0.5 day per round |

---

## Spec Structure

| Spec | Repo(s) | What it delivers |
|---|---|---|
| **ASCA Spec 01: Foundation** | `ls-database-migrations` + `accounting_related_system_for_freee` | DB schema (10 tables + 1 view), models, enums, run lifecycle service, allocation engine, reference price seeder, test data seeder |
| **ASCA Spec 02: CAP Integration** ⚠️ | `accounting_related_system_for_freee` | CommonUtil injection, CAP detection strategy, AllocationDetail CSV, DataCorrectionLogic allocation call, refund allocation |
| **ASCI Spec 01: CIP Integration** ⚠️ | `accounting_related_system_for_freee` | CIP detection strategy (plans 1028–1032), CIP reference prices (L_coaching = ¥84,020) |

⚠️ = Preliminary scope. May split into smaller specs during requirements generation if scope exceeds 15 tasks or 3-page design threshold (per spec-driven development standards). Final boundaries determined when requirements are written (W5 for ASCA Spec 02, W9 for ASCI Spec 01).

**Probable split for ASCA Spec 02:**
- Spec 02a: CAP Core Injection (CommonUtil + detection + overwrite)
- Spec 02b: AllocationDetail CSV (reporting layer)
- Spec 02c: Refund Allocation (record_kind = 1)
- Spec 02d: DataCorrection Integration (`allocateForCharge()`)

---

## JIRA Structure

**Principle: 1 Epic = 1 Spec.** Each epic has the standard story set for time logging and PR tracking.

```
Epic: DEVOPS-6415 — ASCM Prep (refactor — did NOT run the spec workflow)
└── (all work committed directly under the epic — no per-story spec breakdown)

Epic: ASCA — Project Scaffolding (one-time — NOT a spec; excluded from the Spec story template)
├── Story: Steering files (ASCA — adapted from ASCH)   → Lead (Noel)
└── Story: Branch setup                                → Lead (Noel)

Epic: ASCA Spec 01 — Foundation (8 stories — Coding spans 2 repos)
├── Story: Requirements + Sign-off             → PM (Kuroda-san)
├── Story: Architecture (Design + Tasks)       → Lead (Noel)
├── Story: Coding (ls-db migrations)           → Dev (Throy)
├── Story: Coding (accounting application)     → Dev (Throy)
├── Story: Code Review                         → Lead (Noel)
├── Story: Dev/Manual Testing                  → Lead (Noel)
└── Story: QA Testing                          → QA (Miko)

Epic: ASCA Spec 02 — CAP Integration (7 stories — single repo)
├── Story: Requirements + Sign-off             → PM (Kuroda-san)
├── Story: Architecture (Design + Tasks)       → Lead (Noel)
├── Story: Coding                              → Dev (Throy)
├── Story: Code Review                         → Lead (Noel)
├── Story: Dev/Manual Testing                  → Lead (Noel)
└── Story: QA Testing                          → QA (Miko)

Epic: ASCI Spec 01 — CIP Integration (7 stories — single repo)
├── Story: Requirements + Sign-off             → PM (Kuroda-san)
├── Story: Architecture (Design + Tasks)       → Lead (Noel)
├── Story: Coding                              → Dev (Orlino or Cristoff)
├── Story: Code Review                         → Lead (Noel)
├── Story: Dev/Manual Testing                  → Lead (Noel)
└── Story: QA Testing                          → QA (Glenn)
```

**Note on Scaffolding:** This epic intentionally carries only 1–2 stories and does not follow the full Spec story set (Requirements → Architecture → Coding → Review → Testing → QA). Steering-file and branch setup are project setup, not spec dev work. Confirmed with Patrick-san (SDM) — the dev-KPI tool aggregates by story type, so a slim non-spec epic is expected and does not distort measurement.

**Note on ASCM Prep (DEVOPS-6415):** The refactor (ArchiverService/MailerService extraction + DataCorrectionLogic drift fix) is billed under [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415), not ASCA. It was **originally scoped with the same story set as Spec 01 — Foundation**, but in practice it did **not** run the spec-driven workflow — all work was committed directly under the epic without the per-story (Requirements → Architecture → Coding → Review → Testing → QA) breakdown. Recorded here so the KPI/history reflects what actually happened. See its own epic doc.

---

## Branch Strategy

**`accounting_related_system_for_freee`:**
```
main
└── feature/ASCA/ASCA-master                              (long-lived — PRs target this)
    ├── feature/ASCA/ASCA-{t}-scaffolding                 (steering files — merge FIRST)
    ├── feature/ASCA/ASCA-{t}-spec01-foundation           (models, enums, engine, seeders)
    ├── feature/ASCA/ASCA-{t}-spec02-cap-integration      (injection, CSV, refund)
    ├── feature/ASCI/ASCI-{t}-spec01-cip-integration      (CIP detection + config)
    ├── release/ASCA/dev04                                (deploy for QA)
    └── release/ASCA/prod                                 (production release)
```

**`ls-database-migrations`:**
```
main
└── feature/ASCA/ASCA-master                              (long-lived)
    └── feature/ASCA/ASCA-{t}-spec01-migrations           (10 tables + 1 view + structure tests)
```

`{t}` = the JIRA story number the branch's work is logged against.

### Merge Order

```
1. Scaffolding (steering) → PR → ASCA-master             ← merge FIRST (all specs inherit steering)

2. DEVOPS-6415 → main → merge main into ASCA-master       ← pull in the refactor after QA passes
                                                             (needed by Spec 02, NOT Foundation)

3. Foundation:
   ls-db:  ASCA-{t}-spec01-migrations → PR → ls-db ASCA-master   ← migrations merge + run FIRST
   app:    ASCA-{t}-spec01-foundation → PR → app ASCA-master     ← models tested against real tables

4. CAP Integration:
   ASCA-{t}-spec02-cap-integration → PR → ASCA-master

5. CIP Integration:
   ASCI-{t}-spec01-cip-integration → PR → ASCA-master

6. Release:
   ASCA-master → release/ASCA/dev04 → deployment/dev04    (QA)
   ASCA-master → release/ASCA/prod → main                 (production)
```

### Key Ordering Rules

1. **Scaffolding merges before any spec** — steering files must be in ASCA-master so spec branches inherit the conventions.
2. **DEVOPS-6415 pulled in via main, not directly** — do NOT merge the DEVOPS branch into ASCA-master. Wait for it to reach main (post-QA), then `git merge main`. Foundation doesn't need it; Spec 02 does (AllocationDetail CSV uses the extracted services).
3. **ls-db migrations merge before app models** — models can be *written* in parallel but can't be *integration-tested* until the tables exist.
4. **ASCI uses `feature/ASCI/` prefix** but still PRs into ASCA-master (shared foundation lives there). QA/release happens from ASCA-master for both projects.

---

## Multi-Repo Coordination (ASCA Spec 01)

ASCA Spec 01 spans two repos. Execution order matters:

```
ls-database-migrations                    accounting_related_system_for_freee
──────────────────────                    ──────────────────────────────────
1. Create migration files (10 tables)     (can write model code in parallel)
2. Run migrations on dev DB               
3. Generate structure tests               
4. PR → merge                            3. Create models, enums, services
                                          4. Integration test against real tables
                                          5. PR → merge
```

**Rule:** ls-db migrations must be merged and run BEFORE accounting repo models can be integration-tested. Model code CAN be written in parallel.

---

## Roles

| Role | Person | What they do in this workflow |
|---|---|---|
| **PM** | Kuroda-san | Reviews requirements at G1, approves scope, resolves open business items |
| **SDM** | Patrick-san | Manages JIRA epics/stories, tracks progress, presents to business |
| **Lead** | Noel | Steering files, requirements, design, tasks, PR review, deployment |
| **Dev 1** | Throy | Executes ASCA tasks with AI agent, creates PRs |
| **Dev 2** | Orlino/Cristoff | Executes ASCI tasks with AI agent, creates PRs |
| **QA (CAP)** | Miko | Tests ASCA CAP scenarios (10 cases) |
| **QA (CIP)** | Glenn | Tests ASCI CIP scenarios (11 cases) |

---

## Cross-Reference

| Document | What it covers |
|---|---|
| `docs/asc-projects-master-timeline.md` | Schedule, phases, Gantt, gate *timing* (which week) |
| `projects/asca/documentation/asc-allocation-framework-technical-design.md` | Authoritative technical design |
| `projects/asca/technical-notes/jira/epics/DEVOPS-6415/` | ASCM Prep epic (refactor) |
