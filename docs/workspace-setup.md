# Workspace Setup Guide

**Audience:** Any developer joining a Bizmates project using this AI-assisted development workspace.  
**Purpose:** How to set up the multi-root workspace so Kiro's features (steering, specs, artifacts) work correctly.

---

## TL;DR

Three layers work together. Clone all three, open in Kiro as a multi-root workspace, load your project context.

```
┌──────────────────────────────────────────────────────────┐
│  [code-repo]/.kiro/steering/      WHAT you're working with│
│                                   Codebase conventions    │
├──────────────────────────────────────────────────────────┤
│  bizmates-dev-context/            WHERE artifacts live     │
│                                   Reports, knowledge,     │
│                                   domain docs, projects   │
├──────────────────────────────────────────────────────────┤
│  agentic-toolkit/                 HOW to work             │
│                                   Rules, workflows,       │
│                                   templates, methodology  │
└──────────────────────────────────────────────────────────┘
```

---

## Step 1: Clone Repos

```bash
# Shared infrastructure (same for everyone)
mkdir -p ~/ai-workflow
git clone <agentic-toolkit-repo> ~/ai-workflow/agentic-toolkit
git clone <bizmates-dev-context-repo> ~/ai-workflow/bizmates-dev-context

# Code repos (clone what your project needs)
git clone <accounting-system-repo> ~/dev/accounting_related_system_for_freee
git clone <ls-database-migrations-repo> ~/dev/ls-database-migrations
git clone <mbti-backend-repo> ~/dev/MBTI_backend
git clone <bizmates-jp-repo> ~/dev/bizmates.jp
```

You only need the code repos relevant to your project. Check your project's `project-context.md` for which repos to clone.

---

## Step 2: Open Multi-Root Workspace

In Kiro, add folders in this order (**order matters**):

```
1. [primary-code-repo]              ← specs anchor here (first position)
2. ~/ai-workflow/bizmates-dev-context ← artifacts + domain knowledge
3. ~/ai-workflow/agentic-toolkit     ← methodology + templates
4. [additional code repos...]        ← reference repos
```

Save as a `.code-workspace` file for easy reopening.

### Why order matters

| Position | Behavior |
|----------|----------|
| **First folder** | Specs (requirements.md, design.md, tasks.md) anchor here under `.kiro/specs/` |
| **All folders** | `.kiro/steering/` files auto-load into every session |
| **Later folders** | Override earlier folders when merged settings conflict |

---

## Step 3: Load Project Context

At the start of each session:

> "Read `projects/{your-project}/project-context.md`"

This gives Kiro your project's full context — what it does, key tables, open items, team, references.

---

## Step 4: Work

Kiro now has:
- **Project steering** (from code repo's `.kiro/steering/`) — coding standards, conventions
- **Domain knowledge** (from dev-context) — business rules, entity definitions
- **Methodology** (from toolkit) — workflows, safety rules, documentation standards

Use any workflow:

| Say... | What happens |
|---|---|
| "Start a new feature" | Spec-driven development |
| "Investigate this issue" | Investigation workflow → report |
| "Fix this bug" | Bug-fix workflow → code changes |
| "Create a PR" | PR workflow → branch → commit → push |

---

## Workspace Ordering by Project

### Accounting System Projects (ASCH, ASC for CAP, ASC for CIP)

```
1. accounting_related_system_for_freee   ← primary (specs + code)
2. bizmates-dev-context                  ← artifacts + domain knowledge
3. agentic-toolkit                       ← methodology
4. ls-database-migrations                ← schema source of truth
5. MBTI_backend                          ← reference (read-only)
6. bizmates.jp                           ← reference (read-only)
```

### MBTI Backend Projects (GraphQL features, student portal)

```
1. MBTI_backend                          ← primary (specs + code)
2. bizmates-dev-context                  ← artifacts + domain knowledge
3. agentic-toolkit                       ← methodology
4. ls-database-migrations                ← schema reference
5. bizmates.jp                           ← reference (read-only)
```

---

## What Goes Where

| Output | Destination |
|---|---|
| Code changes | Primary code repo |
| Specs (requirements, design, tasks) | Primary code repo under `.kiro/specs/` |
| Reports, tickets, test cases | `bizmates-dev-context/projects/{name}/` |
| Domain knowledge (cross-project) | `bizmates-dev-context/domain-knowledge/` |
| Methodology improvements | `agentic-toolkit/` (via extract-to-toolkit) |

---

## How Steering Files Layer

All `.kiro/steering/` files from every folder auto-load. They stack:

| Source | What it provides | Example |
|---|---|---|
| Code repo `.kiro/steering/` | Project-specific conventions | `backend-patterns.md`, `database-standards.md` |
| `bizmates-dev-context/.kiro/steering/` | Workspace identity, project routing | `workspace-identity.md` |
| `agentic-toolkit/.kiro/steering/` | Methodology rules | Git safety, documentation format |

On conflict: later folders override earlier ones.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Specs created in wrong repo | Check folder order — primary repo must be first |
| Steering not loading | Verify `.kiro/steering/` exists in the folder and has `inclusion: auto` frontmatter |
| Kiro doesn't know the project | Load context: "Read projects/{name}/project-context.md" |
| Artifacts landing in wrong project | Check `workspace-identity.md` routing rules |

---

## Reference

- Full toolkit docs: `agentic-toolkit/README.md`
- Workspace structure: `bizmates-dev-context/README.md`
- Toolkit getting started: `agentic-toolkit/knowledge/getting-started.md`
