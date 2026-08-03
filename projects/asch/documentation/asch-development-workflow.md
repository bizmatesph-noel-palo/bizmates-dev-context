# ASCH — Spec-Driven Development Workflow

## Purpose

This document defines the development lifecycle for the ASCH project using Spec-Driven Development (SDD). It clarifies who does what, when sign-offs happen, and how JIRA tickets map to the spec workflow.

---

## Roles

| Role | Person | Responsibility |
|------|--------|---------------|
| PM (Project Manager) | Kuroda-san | Business decisions, requirements sign-off, open item resolution |
| SDM (Software Delivery Manager) | Patrick-san | Sprint coordination, JIRA management, blocker escalation |
| Lead Dev | Noel Palo | Scaffolding, requirements, design, task review, code review |
| Developer | Throy Embudo | Task execution (with AI agent), PR creation |
| Developer | Cristoff Danganan | Task execution (with AI agent), PR creation |
| QA | Alvin Glenn G. Flamiano | Testing after development |
| QA | Jaymiriz Liwanag | Testing after development |

---

## The Spec Lifecycle

Each feature (spec) follows this cycle from start to finish:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│   SCAFFOLD          SPECIFY         DESIGN &          TASK              │
│   (one-time)        (per spec)      TASK GEN          EXECUTION         │
│                                     (per spec)        (per spec)        │
│                                                                         │
│   Lead Dev          Lead Dev        Lead Dev          Dev + AI Agent    │
│   ────────          ────────        ────────          ──────────────    │
│   Steering files    requirements.md  design.md        Execute tasks.md  │
│   product.md        → PM sign-off    tasks.md         → Lead PR review  │
│   Spec folders                       → Lead + Dev                       │
│                                        review                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Flow

### Phase 0: Project Scaffolding (One-Time)

**Who:** Lead Dev
**When:** Before any spec work begins
**Output:** Project infrastructure ready for all specs

| Step | Action | Output |
|------|--------|--------|
| 0.1 | Create feature branch | `feature/ASCH/ASCH-master` |
| 0.2 | Create steering files | `.kiro/steering/*.md` (coding standards, system overview, conventions, etc.) |
| 0.3 | Create product.md | `.kiro/steering/product.md` (business context for AI) |
| 0.4 | Create spec folder structure | `.kiro/specs/asch-{name}/` per spec |
| 0.5 | Create project overview | Confluence page for team visibility |

---

### Phase 1: Requirements (per spec)

**Who:** Lead Dev generates → PM signs off
**When:** Before design begins
**Gate:** PM approval required before proceeding

| Step | Action | Who | Output |
|------|--------|-----|--------|
| 1.1 | Generate requirements.md | Lead Dev + AI | `.kiro/specs/{name}/requirements.md` (per repo — split specs get one per repo) |
| 1.2 | Review and refine | Lead Dev | Corrected requirements |
| 1.3 | Share with PM for sign-off | Lead Dev → SDM → PM | Confluence notification |
| 1.4 | PM approves | PM (Kuroda-san) | Go signal to proceed |

**Split-spec rule:** When a spec spans multiple repos (e.g., Spec 01 spans `ls-database-migrations` + `accounting_related_system_for_freee`), each repo gets its own self-contained `requirements.md`. PM sign-off covers both as one logical unit. Design and tasks are generated per repo.

**If blocked:** Lead Dev escalates to SDM. SDM routes to PM or resolves.

**JIRA:** Lead logs time on "Requirements + Sign-off" dev task. Story stays in TO DO.

---

### Phase 2: Design & Task Generation (per spec)

**Who:** Lead Dev generates and reviews
**When:** After PM signs off requirements
**Gate:** Lead Dev approval required before proceeding

| Step | Action | Who | Output |
|------|--------|-----|--------|
| 2.1 | Generate design.md | Lead Dev + AI | `.kiro/specs/{name}/design.md` |
| 2.2 | Review architecture decisions | Lead Dev | Approved design |
| 2.3 | Generate tasks.md | AI (from design) | `.kiro/specs/{name}/tasks.md` |
| 2.4 | Review tasks with Dev | Lead Dev + Dev | Task list confirmed, Dev understands scope |

**JIRA:** Lead logs time on "Design" dev task. Story stays in TO DO until Dev starts implementation.

---

### Phase 3: Task Execution (per spec)

**Who:** Dev executes with AI agent
**When:** After Lead Dev approves tasks.md
**Gate:** Lead Dev PR review at the end

| Step | Action | Who | Output |
|------|--------|-----|--------|
| 3.1 | Create spec branch | Dev | `feature/ASCH/{spec-name}` from ASCH-master |
| 3.2 | Execute tasks (AI agent) | Dev + AI | Code changes, one commit per task |
| 3.3 | Dev reviews each task output | Dev | Quality check per task |
| 3.4 | Create PR | Dev | PR → ASCH-master |
| 3.5 | Lead Dev reviews PR | Lead Dev | Approve / request changes |
| 3.6 | Merge | Lead Dev | Code in ASCH-master |

**JIRA:** Story moves TO DO → IN PROGRESS when Dev starts. Dev logs implementation time on the Story. Moves to IN REVIEW when PR created. DONE when merged.

---

### Phase 4: QA & Deployment

**Who:** Lead deploys, QA tests at each environment
**When:** After all Phase 1 specs are merged to ASCH-master

| Step | Action | Who | Environment |
|------|--------|-----|-------------|
| 4.1 | Deploy to DEV04 | Lead Dev | `release/ASCH/dev04` → `deployment/dev04` |
| 4.2 | Command run & report collection | Lead Dev | DEV04 |
| 4.3 | QA testing | QA team | DEV04 |
| 4.4 | Bug fixes (if any) | Dev + Lead Dev | feature branches → ASCH-master → redeploy |
| 4.5 | Deploy to staging | Lead Dev | `release/ASCH/prod` → `deployment/prod` |
| 4.6 | QA testing | QA team | Staging |
| 4.7 | Production release | Lead Dev | `deployment/prod` → `main` |

---

## Sign-Off Checkpoints

There are 3 mandatory gates where work cannot proceed without approval:

| # | Gate | Who Approves | What's Being Approved | Happens Between |
|---|------|-------------|----------------------|-----------------|
| 1 | Requirements Sign-Off | PM (Kuroda-san) | Business rules, scope, and acceptance criteria are correct | Phase 1 → Phase 2 |
| 2 | Design & Tasks Approval | Lead Dev + Dev | Architecture is sound, task breakdown is clear and executable | Phase 2 → Phase 3 |
| 3 | Code Review | Lead Dev | Code is correct, follows standards, no regressions | Phase 3 → Done (merge) |

### What happens if a gate fails?

| Gate | If rejected | Who resolves |
|------|-------------|-------------|
| Gate 1 | PM requests changes to scope/rules | Lead Dev revises requirements, resubmits |
| Gate 2 | Design has flaws or tasks are unclear | Lead Dev revises design/tasks |
| Gate 3 | Code doesn't meet standards or has bugs | Dev addresses feedback, re-requests review |

---

## JIRA Ticket Structure

### Principle: 1 Epic = 1 Spec

Each spec gets its own Epic with 7 stories following the standard phase structure. PRs link to the relevant story within the epic. Assignee reflects who is responsible/accountable for that phase.

### Structure

```
Phase 1 — Core Engine:

Epic: Spec 01: Foundation
├── Story: Requirements              → Assigned: PM (Kuroda-san) → PR: requirements.md (both repos)
├── Story: Architecture              → Assigned: Lead (Noel) → PR: design.md + tasks.md (both repos)
├── Story: Coding (ls-db migrations) → Assigned: Dev (Throy or Cristoff) → PR: migrations + structure tests
├── Story: Coding (application)      → Assigned: Dev (Throy or Cristoff) → PR: models, enums, services, command
├── Story: Code Review               → Assigned: Lead (Noel)
├── Story: Dev/Manual Testing        → Assigned: Lead (Noel)
├── Story: Automated Testing         → Assigned: QA (Alvin or Jaymiriz)
└── Story: Deployment                → Assigned: Lead (Noel)

Epic: Spec 02: Honki Set Eligibility
├── (same 7-story structure — single repo)

Epic: Spec 03: Pattern 1 Calculation
├── (same 7-story structure — single repo)

Epic: Spec 04: Freee Journal Adjustment
├── (same 7-story structure — single repo)

Epic: Spec 05: CSV Report Generation
├── (same 7-story structure — single repo)

Phase 2 — Pattern Extensions:

Epic: Spec 06: Patterns 2+3+9 (cross-month splitting, discount priority)
├── (same 7-story structure)

Epic: Spec 07: Patterns 4+6 (plan changes, I/J switching)
├── (same 7-story structure)

Epic: Spec 08: Patterns 5+7 (enrollment termination, negative M)
├── (same 7-story structure)

Epic: Spec 09: Pattern 8 (cooling-off)
├── (same 7-story structure)
```

**Note on Spec 01:** This epic has 8 stories instead of the standard 7 because the Coding phase spans two repos (ls-db migrations + accounting application code). Each gets its own story for accurate time logging and PR tracking. Alternatively, a single "Coding" story can track both PRs if the team prefers — this is a JIRA housekeeping decision, not a process change.

### How It Works

| Item | Rule |
|---|---|
| **Epic** | 1 per spec. Tracks the full lifecycle of one deliverable. |
| **Stories (1-7)** | Fixed phase structure per metrics system template. |
| **Assignee** | The person responsible/accountable for that phase (does not need to code — can be the approver). |
| **PRs** | Link to the relevant story: requirements PR → Requirements story, code PR → Coding story. |
| **Time logging** | Each person logs hours on the story they're assigned to. |

### Story-to-Phase Mapping

| Story | Phase | Who works on it | PR contains |
|---|---|---|---|
| Requirements | Phase 1 | Lead generates, PM approves | `requirements.md` |
| Architecture | Phase 2 | Lead generates and reviews | `design.md` + `tasks.md` |
| Coding | Phase 3 | Dev executes tasks with AI | Implementation code |
| Code Review | Phase 3 | Lead reviews PR | (no PR — review happens on Coding PR) |
| Dev/Manual Testing | Phase 4 | Lead runs commands on DEV04 | Test results |
| Automated Testing | Phase 4 | QA executes test cases | Test results |
| Deployment | Phase 4 | Lead deploys | Release notes |

### Epic Workflow

Each epic progresses sequentially through its stories:

```
Requirements → Architecture → Coding → Code Review → Testing → Deployment
(PM sign-off)  (Lead approval) (Dev + AI)  (Lead review)  (QA)     (Lead)
```

### Why This Works

- Metrics system reads 7 stories per epic as designed
- Each spec is independently trackable (which spec is in which phase)
- PRs are small and reviewable (one spec's code per Coding story)
- Time logging is per-spec per-phase (accurate for reporting)
- Assignee shows accountability at a glance

---

## Branch Strategy

```
main
└── feature/ASCH/ASCH-master (long-lived feature branch)
    │
    ├── feature/ASCH/asch-foundation         (Spec 01b → PR to ASCH-master)
    ├── feature/ASCH/asch-honki-set-eligibility (Spec 02 → PR to ASCH-master)
    ├── feature/ASCH/asch-pattern1-calculation  (Spec 03 → PR to ASCH-master)
    ├── feature/ASCH/asch-freee-journal-adjustment (Spec 04 → PR to ASCH-master)
    └── feature/ASCH/asch-csv-report-generation (Spec 05 → PR to ASCH-master)
    │
    ├── release/ASCH/dev04                   (deploy to DEV04 for QA)
    │   └── → deployment/dev04
    │
    └── release/ASCH/prod                    (deploy to production after QA pass)
        └── → deployment/prod → main

ls-database-migrations:
main
└── feature/ASCH/ASCH-master (long-lived feature branch)
    │
    └── feature/ASCH/asch-database-migrations (Spec 01a → PR to ASCH-master)
```

### Branch Flow

```
1. Development (accounting_related_system_for_freee):
   feature/ASCH/ASCH-master → feature/ASCH/{spec-name}
   feature/ASCH/{spec-name} → PR → feature/ASCH/ASCH-master

2. Development (ls-database-migrations):
   feature/ASCH/ASCH-master → feature/ASCH/asch-database-migrations
   feature/ASCH/asch-database-migrations → PR → feature/ASCH/ASCH-master

3. QA (DEV04):
   Both repos: feature/ASCH/ASCH-master → release/ASCH/dev04
   release/ASCH/dev04 → deployment/dev04

4. QA (Staging):
   Both repos: feature/ASCH/ASCH-master → release/ASCH/prod
   release/ASCH/prod → deployment/prod

5. Production:
   deployment/prod → main
```

### Multi-Repo Coordination for Spec 01

Spec 01 spans two repos. Execution order matters:

```
ls-database-migrations (Spec 01a)     accounting_related_system_for_freee (Spec 01b)
─────────────────────────────────     ──────────────────────────────────────────────
1. Create migration files              (blocked — tables must exist first)
2. Run migrations on dev DB            
3. Generate structure tests            
4. PR → merge                         3. Create models, enums, services, command
                                       4. PR → merge
```

**Rule:** ls-db migrations must be merged and run BEFORE the accounting repo's models can be tested against real tables. However, model code can be written in parallel (it just can't be integration-tested until tables exist).

---

## ASCH Spec Execution Order

Specs must be executed in dependency order:

```
Phase 1 — Core Engine:

Spec 01a: Database Migrations (ls-db) ───────┐
                                             │ (tables must exist before models)
Spec 01b: Foundation (accounting repo) ──────┤
                                             │
Spec 02: Honki Set Eligibility ──────────────┤ (depends on 01b: models + run lifecycle)
                                             │
Spec 03: Pattern 1 Calculation ──────────────┤ (depends on 01b + 02: enrollments + proration engine)
                                             │
Phase 2 — Pattern Extensions:                │
                                             │
Specs 06–09: Patterns 2–9 ───────────────────┤ (depends on 03: core engine working)
                                             │
Phase 3 — Output & Delivery:                 │
                                             │
Spec 04: Freee Journal Adjustment ───────────┤ (depends on 03 + 06–09: P values for all patterns)
                                             │
Spec 05: CSV Report Generation ──────────────┘ (depends on 04: aggregated results exist)
```

**Multi-repo note for Spec 01:**
- Spec 01a (ls-database-migrations): migrations + FK constraints + structure tests
- Spec 01b (accounting_related_system_for_freee): models + enums + run lifecycle + command + logic skeleton
- Execution: 01a runs first (or in parallel with 01b code writing, but 01a must merge first for integration testing)
- Two separate PRs in two repos, but logically one "Foundation" delivery

**Why this order (not 01→02→03→04→05 sequentially):**
- Patterns 2–9 (Specs 06–09) extend the core calculation engine (Spec 03) — they add edge cases to the same pipeline
- Freee submission (Spec 04) needs P values from ALL patterns to be meaningful for integration testing
- CSV (Spec 05) reads from `asch_sum_calculation` which is populated by Spec 04's aggregation

**Parallelization opportunities:**
- Spec 01a and 01b can be worked in parallel (model code doesn't need real tables until testing)
- Spec 02 can start as soon as Spec 01b's run lifecycle service is merged
- Specs 06–09 (patterns) can be split across developers if available
- Spec 05 (CSV) is mechanically simple and could overlap with Spec 04 if the table schema is stable

---

## Summary for Each Role

### PM (Kuroda-san)

1. Review project overview
2. Sign off on requirements (Checkpoint 1)
3. Resolve open items (business decisions)
4. Final acceptance of delivered features

### SDM (Patrick-san)

1. Manage JIRA tickets (1 epic per spec, 7 stories per epic)
2. Track sprint progress
3. Route blockers (Lead → PM when business decisions needed)
4. Coordinate QA and deployment timing

### Lead Dev (Noel)

1. Scaffold the project
2. Generate requirements.md for each spec
3. Get PM sign-off
4. Generate design.md + tasks.md
5. Review tasks with Dev
6. Review PRs after Dev completes
7. Deploy

### Dev (Throy + Cristoff)

1. Review tasks.md with Lead
2. Create spec branch from ASCH-master
3. Execute tasks using AI agent (Kiro autopilot)
4. Review AI output per task
5. Create PR when all tasks done
6. Address review feedback from Lead

### QA (Alvin + Jaymiriz)

1. Review requirements.md for testability (optional — if QA wants early involvement)
2. Prepare test cases from requirements + design (can start during Phase 3)
3. Execute test cases on DEV04 after deployment
4. Report bugs → Dev fixes → retest
5. Sign off on QA pass
