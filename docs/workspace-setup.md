# Workspace Setup Guide

**Audience:** Any developer joining a Bizmates project using this AI-assisted development workspace.  
**Purpose:** How to set up the multi-root workspace so Kiro's features (steering, specs, artifacts) work correctly.

---

## TL;DR

Three layers work together. Clone all three, open in Kiro as a multi-root workspace, run one prompt.

```
┌───────────────────────────────────────────────────────────┐
│  [code-repo]/.kiro/steering/      WHAT you're working with│
│                                   Codebase conventions    │
├───────────────────────────────────────────────────────────┤
│  bizmates-dev-context/            WHERE artifacts live    │
│                                   Reports, knowledge,     │
│                                   domain docs, projects   │
├───────────────────────────────────────────────────────────┤
│  agentic-toolkit/                 HOW to work             │
│                                   Rules, workflows,       │
│                                   templates, methodology  │
└───────────────────────────────────────────────────────────┘
```

---

## Directory Structure Explained

### Are these directory paths required?

**No.** The paths `~/ai-workflow/` and `~/dev/` shown in this guide are conventions, not requirements. You can put repos anywhere on your filesystem. What matters is:

1. `agentic-toolkit` and `bizmates-dev-context` are siblings in the same parent directory (bootstrap scripts expect this)
2. All repos are accessible to Kiro when added to the multi-root workspace
3. You can find them when you need to

**Examples that all work:**

```bash
# Convention used in this guide:
~/ai-workflow/agentic-toolkit/
~/ai-workflow/bizmates-dev-context/
~/dev/accounting_related_system_for_freee/

# Everything in one directory (also fine):
~/projects/agentic-toolkit/
~/projects/bizmates-dev-context/
~/projects/accounting_related_system_for_freee/

# Your own structure (also fine):
~/work/tools/agentic-toolkit/
~/work/tools/bizmates-dev-context/
~/work/code/accounting_related_system_for_freee/
```

**The one rule:** `agentic-toolkit` and `bizmates-dev-context` must be in the same parent folder (siblings). This is because bootstrap scripts use `../agentic-toolkit` to find the toolkit. Everything else is flexible.

### Why this guide uses `~/ai-workflow/` and `~/dev/`

We separate them to make the mental model clear:

| Directory | Contains | You modify it? |
|---|---|---|
| `~/ai-workflow/` | AI infrastructure (toolkit + dev-context) | Rarely — mostly Kiro reads from here |
| `~/dev/` | Actual code repos | Yes — this is where you code |

This separation makes it obvious which repos are "support" (AI context) vs "work" (code). But it's a preference, not a requirement. If you prefer everything in one directory, that works too — just keep the two AI repos as siblings.

### What IS required

| Requirement | Why |
|---|---|
| `agentic-toolkit` and `bizmates-dev-context` in same parent dir | Bootstrap scripts use relative path `../agentic-toolkit` |
| All repos added to Kiro multi-root workspace | Kiro needs visibility to all layers |
| Primary code repo as first folder in workspace | Specs anchor to the first folder |

### What is NOT required

| Not required | Why it's optional |
|---|---|
| Using `~/ai-workflow/` as the path | Any path works |
| Using `~/dev/` for code repos | Any path works |
| Having code repos in a separate directory from AI repos | All in one dir is fine |
| Cloning all 6 repos | Only clone what your project needs |

---

## Step 1: Clone Repos

### AI infrastructure (one-time setup)

```bash
mkdir -p ~/ai-workflow
cd ~/ai-workflow
git clone https://github.com/nspalo/agentic-toolkit.git
git clone https://github.com/bizmatesph-noel-palo/bizmates-dev-context.git
```

### Code repos (clone what your project needs)

```bash
mkdir -p ~/dev
cd ~/dev
git clone <accounting-system-repo> accounting_related_system_for_freee
git clone <ls-database-migrations-repo> ls-database-migrations
git clone <mbti-backend-repo> MBTI_backend
git clone <bizmates-jp-repo> bizmates.jp
```

> Note: Replace `<repo-url>` with your actual Bitbucket/GitHub URLs for the code repos. Ask your lead for access if needed.

---

## Step 2: Open Multi-Root Workspace in Kiro

Add folders in this order (**order matters**):

```
1. ~/dev/accounting_related_system_for_freee       ← specs anchor here (first position)
2. ~/ai-workflow/bizmates-dev-context              ← artifacts + domain knowledge
3. ~/ai-workflow/agentic-toolkit                   ← methodology + templates
4. ~/dev/ls-database-migrations                    ← schema source of truth
5. ~/dev/MBTI_backend                              ← reference (read-only)
6. ~/dev/bizmates.jp                               ← reference (read-only)
```

Save as a `.code-workspace` file for easy reopening.

### Why order matters

| Position | Behavior |
|----------|----------|
| **First folder** | Specs (requirements.md, design.md, tasks.md) anchor here under `.kiro/specs/` |
| **All folders** | `.kiro/steering/` files auto-load into every session |
| **Later folders** | Override earlier folders when merged settings conflict |

The primary code repo goes first because that's where specs and code changes live. The AI infrastructure repos provide context without being the "active" workspace.

---

## Step 3: Load Context (One Prompt)

After opening the workspace, paste this single prompt to fully load Kiro:

```
Learn the agentic-toolkit and bizmates-dev-context, then read projects/asch/project-context.md, then learn the related repos: accounting_related_system_for_freee, ls-database-migrations, bizmates.jp, MBTI_backend
```

After this one prompt, Kiro has:
- Methodology and workflow knowledge (from toolkit)
- Domain knowledge and project context (from dev-context)
- System architecture, coding patterns, conventions (from code repo steering files)
- Codebase awareness (from scanning the repos)

**You're ready to work.**

> For other projects, replace the `project-context.md` path:
> - ASCM: `projects/ascm/project-context.md`
> - ASCH: `projects/asch/project-context.md`

---

## Step 4: Work

Kiro now has all context loaded. Use any workflow:

| Say... | What happens |
|---|---|
| "Start a new feature" | Spec-driven development |
| "Investigate this issue" | Investigation workflow → report |
| "Fix this bug" | Bug-fix workflow → code changes |
| "Create a PR" | PR workflow → branch → commit → push |

---

## Step 5: Resuming Work Across Sessions (Spec Continuity)

Specs span multiple sessions. Each phase (requirements → design → tasks → implement) may happen in a different session. Here's how to resume:

### Starting a new session to continue a spec

1. **Open a new Kiro session** (new chat)

2. **Load full context** — paste the standard prompt:
   ```
   Learn the agentic-toolkit and bizmates-dev-context, then read projects/asch/project-context.md, then learn the related repos: accounting_related_system_for_freee, ls-database-migrations, bizmates.jp, MBTI_backend
   ```

3. **Load supplementary context (design phase only)** — if you're about to generate design.md, load architecture docs that inform design decisions:
   ```
   Also read these for design context:
   - projects/asch/documentation/asch-engineering-standards.md
   - projects/asch/knowledge-base/01-architecture-patterns-note.md
   - projects/asch/knowledge-base/02-calc-rule-code-convention.md
   ```
   > Skip this step for tasks or implementation phases — design.md already encodes these decisions.

4. **Open the spec file in the editor and use the spec UI to advance:**
   - Open the current phase's file in the editor (e.g. `requirements.md` for design generation)
   - Click **"Continue to Design"** (or the equivalent next-phase button) in Kiro's spec panel
   - Kiro generates the next phase file in the same spec folder

   > **Do NOT** ask Kiro in chat to "generate the design.md" — that produces a freeform response, not the structured spec format. Always use the spec UI button.

### Phase-by-phase guide

| Current phase | Step 3 needed? | Open this file in editor | Then click |
|---|---|---|---|
| Requirements → Design | ✅ Yes | `.kiro/specs/{name}/requirements.md` | "Continue to Design" |
| Design → Tasks | ❌ Skip step 3 | `.kiro/specs/{name}/design.md` | "Continue to Tasks" |
| Tasks → Implement | ❌ Skip step 3 | `.kiro/specs/{name}/tasks.md` | Start task execution |
| Resume mid-implementation | ❌ Skip step 3 | `.kiro/specs/{name}/tasks.md` | Continue from uncompleted task |

### Supplementary files by spec domain (for Step 3)

| Spec domain | Files to load |
|---|---|
| DB schema / migrations | Engineering standards, architecture patterns, relevant knowledge-base articles |
| Application foundation | Engineering standards, architecture patterns, relevant knowledge-base articles |
| Calculation logic | Engineering standards, architecture patterns, pattern case data |
| Freee/CSV delivery | Engineering standards, ADR-001, REF-ASCH-07, REF-ASCH-08 |

**ASCH — DB migrations or foundation specs:**
```
Also read these for design context:
- projects/asch/documentation/asch-engineering-standards.md
- projects/asch/knowledge-base/01-architecture-patterns-note.md
- projects/asch/knowledge-base/02-calc-rule-code-convention.md
```

**ASCH — Freee/CSV delivery specs (Spec 04/05):**
```
Also read these for design context:
- projects/asch/documentation/asch-engineering-standards.md
- projects/asch/documentation/ADR-001-csv-delivery-method.md
- projects/asch/technical-notes/research/ASCH/REF-ASCH-07-Unified-CSV-Delivery-20260805.md
- projects/asch/technical-notes/research/ASCH/REF-ASCH-08-Freee-Sending-Approach-Decision.md
```

### Full example (ASCH — design phase for DB migrations spec)

```
# Step 1: Open a new Kiro session (new chat)
#   - If a bad design.md was generated via chat previously, delete it first

# Step 2: Paste context load prompt, wait for Kiro to finish loading
Learn the agentic-toolkit and bizmates-dev-context, then read projects/asch/project-context.md, then learn the related repos: accounting_related_system_for_freee, ls-database-migrations, bizmates.jp, MBTI_backend

# Step 3: Paste supplementary design context, wait for Kiro to finish loading
Also read these for design context:
- projects/asch/documentation/asch-engineering-standards.md
- projects/asch/knowledge-base/01-architecture-patterns-note.md
- projects/asch/knowledge-base/02-calc-rule-code-convention.md

# Step 4: Open requirements.md in editor, then use the spec UI
#   - Open: ls-database-migrations/.kiro/specs/asch-database-migrations/requirements.md
#   - Click "Continue to Design" button in Kiro's spec panel
#   - Kiro generates design.md in the same spec folder
#
#   ⚠️ Do NOT type "generate design.md" in chat — use the spec panel button only
```

### Why new sessions for each phase?

- **Context budget** — design generation produces substantial content; a fresh window gives maximum room
- **No information loss** — all decisions are persisted in files (requirements.md, project-context.md, knowledge-base, REF docs)
- **Reload is cheap** — one prompt, one turn, full context restored
- **Clean boundaries** — each phase gets a focused session without accumulated noise from prior discussions

### Why new sessions for each phase?

- **Context budget** — design generation produces substantial content; a fresh window gives maximum room
- **No information loss** — all decisions are persisted in files (requirements.md, project-context.md, knowledge-base, REF docs)
- **Reload is cheap** — one prompt, one turn, full context restored
- **Clean boundaries** — each phase gets a focused session without accumulated noise from prior discussions

---

## Workspace Ordering by Project

### Accounting System Projects (ASCH, ASC for CAP, ASC for CIP)

```
1. ~/dev/accounting_related_system_for_freee   ← primary (specs + code)
2. ~/ai-workflow/bizmates-dev-context          ← artifacts + domain knowledge
3. ~/ai-workflow/agentic-toolkit               ← methodology
4. ~/dev/ls-database-migrations                ← schema source of truth
5. ~/dev/MBTI_backend                          ← reference (read-only)
6. ~/dev/bizmates.jp                           ← reference (read-only)
```

### MBTI Backend Projects (GraphQL features, student portal)

```
1. ~/dev/MBTI_backend                          ← primary (specs + code)
2. ~/ai-workflow/bizmates-dev-context          ← artifacts + domain knowledge
3. ~/ai-workflow/agentic-toolkit               ← methodology
4. ~/dev/ls-database-migrations                ← schema reference
5. ~/dev/bizmates.jp                           ← reference (read-only)
```

---

## What Goes Where

| Output | Destination |
|---|---|
| Code changes | Primary code repo (`~/dev/...`) |
| Specs (requirements, design, tasks) | Primary code repo under `.kiro/specs/` |
| Reports, tickets, test cases | `~/ai-workflow/bizmates-dev-context/projects/{name}/` |
| Domain knowledge (cross-project) | `~/ai-workflow/bizmates-dev-context/domain-knowledge/` |
| Methodology improvements | `~/ai-workflow/agentic-toolkit/` |

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
| Steering not loading | Verify `.kiro/steering/` exists in the folder and file has `inclusion: auto` frontmatter |
| Kiro doesn't know the project | Run the full context prompt from Step 3 |
| Artifacts landing in wrong project | Check `workspace-identity.md` routing rules |
| "Permission denied" on clone | Request repo access from your lead |

---

## Reference

### Repos

| Repo | URL | Purpose |
|---|---|---|
| agentic-toolkit | https://github.com/nspalo/agentic-toolkit | Methodology, templates, workflows |
| bizmates-dev-context | https://github.com/bizmatesph-noel-palo/bizmates-dev-context | Domain knowledge, project artifacts |
| accounting_related_system_for_freee | https://github.com/bizmatesinc/accounting_related_system_for_freee | Main ASC/ASCH batch system |
| ls-database-migrations | https://github.com/bizmatesinc/ls-database-migrations | Schema source of truth |
| MBTI_backend | https://github.com/bizmatesinc/MBTI_backend | Student portal backend |
| bizmates.jp | https://github.com/bizmatesinc/bizmates.jp | Admin portal |

### Key Files

| File | Path | What it is |
|---|---|---|
| Workspace identity | `~/ai-workflow/bizmates-dev-context/.kiro/steering/workspace-identity.md` | Active projects, team assignments, routing |
| ASCH project context | `~/ai-workflow/bizmates-dev-context/projects/asch/project-context.md` | ASCH-specific context (load at session start) |
| ASCM project context | `~/ai-workflow/bizmates-dev-context/projects/ascm/project-context.md` | Base accounting system context |
| Toolkit getting started | `~/ai-workflow/agentic-toolkit/knowledge/getting-started.md` | Full lifecycle guide |
| Workspace README | `~/ai-workflow/bizmates-dev-context/README.md` | Quick start, commands |
| Toolkit README | `~/ai-workflow/agentic-toolkit/README.md` | Architecture, full setup details |
