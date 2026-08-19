---
inclusion: auto
---

# Workspace Identity

## What This Workspace Is

This is an AI-assisted development workspace for All Bizmates' Projects.

It contains project-specific knowledge, test cases, investigation reports, JIRA tickets, and documentation produced during development — organized by project.

## Active Projects

| Project Code | JIRA | Code Repo(s) | Artifacts Directory | Status | Deadline |
|---|---|---|---|---|---|
| ASC | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/boards/1186/backlog) | `accounting_related_system_for_freee` | `projects/ascm/` | ✅ Deployed (Jun 2026) | — |
| ASCH | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/boards/1753/backlog) | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asch/` | ❌ Cancelled (2026-08-07) | — |
| ASCA | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog) | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asca/` | Active — builds shared foundation | 2026/12/17 |
| ASCI | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog) | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asci/` | Active — reuses ASCA foundation | 2026/12/17 |
| CDB | — | `MBTI_backend` | — | Active (upstream, Patrick-san's team) | — |

**Note:** ASC is the JIRA code for ASCM (the original project was just "ASC" before subsequent projects were created).

## Cross-Project Resource Plan (from meeting 2026-07-28, updated 2026-08-12)

**Management Partners (JP ↔ PH):**
- Kuroda-san (PM) ↔ Patrick-san (SDM) — handles ASC / Accounting projects
- Soli-san (PM) ↔ Jasser-san (SDM) — handles CAP / CIP upstream projects

| Project | Lead | Sub-Lead | Developer(s) | Status |
|---|---|---|---|---|
| ASCH | Noel Palo | — | Throy Embudo, Cristoff Danganan | ❌ Cancelled (2026-08-07) |
| ASCA (ASC for CAP) | Noel Palo | — | Throy Embudo | ✅ Active (builds foundation) |
| ASCI (ASC for CIP) | Noel Palo (overall) | Orlino Monares | Cristoff Danganan | Active (reuses ASCA foundation) |
| CDB (upstream) | Paolo | — | Efren | ✅ Active |
| CAP (upstream) | Keith Manuntag | — | Terry Balahadia | Active (Jasser-san's team) |
| CIP (upstream) | Jefferson Gernale | — | Haggai Rei Cacacho | Active (Jasser-san's team) |

**Planned timeline:**
- ASCH: ❌ Cancelled (2026-08-07)
- ASCA (ASC for CAP): starts ~September, deadline Dec 17 (builds shared foundation)
- ASCI (ASC for CIP): starts after ASCA, deadline Dec 17 (reuses foundation)
- CAP/CIP upstream (Jasser-san's teams): production late Nov / early Dec

## Routing Rules

When producing artifacts (reports, test cases, tickets, KB articles, guides, documentation), place them in the correct project subdirectory based on the File Placement table below.

**CRITICAL: Never place files directly in the project root (`projects/{name}/`).** Every artifact has a designated subdirectory. Before creating any file, match its content type to the File Placement table and use that path. If the content type doesn't clearly match any row, default to `documentation/`.

**How to determine the active project:**
1. Check which project context was loaded at session start
2. Check which code repo the user is actively working in
3. If ambiguous, ask: "Which project should this go under?"

## File Placement (Universal)

Every project directory follows this structure:

| Content type | Path within project |
|---|---|
| Project context | `project-context.md` |
| JIRA ticket docs | `technical-notes/jira/tickets/` |
| Epic docs | `technical-notes/jira/epics/` |
| Design proposals | `technical-notes/jira/proposals/` |
| Investigation reports | `technical-notes/investigation/YYYYMMDD-name/` |
| Test cases | `testcases/` |
| Project-specific docs & diagrams | `documentation/` (diagrams in `documentation/diagrams/`) |
| Knowledge base (project lessons) | `knowledge-base/` |
| Generated output | `generated-files/` (gitignored) |
| Draft steering | `.kiro-draft/steering/` |
| Draft hooks | `.kiro-draft/hooks/` |

### Shared Knowledge (cross-project)

| Content type | Path |
|---|---|
| Domain knowledge (general concepts, entities, system-wide) | `domain-knowledge/` (at repo root) |
| Upstream/external project research (shared reference) | `research/` (at repo root) |

**`domain-knowledge/`** — General system concepts that apply regardless of which project you're working on. Entity definitions, plan/product maps, campaigns, account types. Curated, verified, maintained.

**`research/`** — Research and reference documents about OTHER teams' projects (upstream, external). Organized by project code (e.g., `research/CAP/`, `research/CIP/`, `research/CDB/`, `research/HCR/`). These describe how external systems work, their specs, pricing decisions, and technical details our projects depend on. Any project in the workspace can reference them.

### Placement Rules

| What you're documenting | Where it goes | Example |
|---|---|---|
| How OUR project works (design, decisions, internal) | `projects/{code}/technical-notes/` | O-3 table prefix proposal, discussion notes |
| How an UPSTREAM project works (their spec, their pricing) | `research/{upstream_code}/` | REF-CAP-05 pricing thread, REF-CIP-03 project spec |
| General system concept (useful to ANY project, permanent) | `domain-knowledge/` | plans-and-products.md, account-types.md |
| Cross-project plan/timeline (not owned by one project) | `docs/` | master timeline, technical design |

**The rule:** If you're writing about someone ELSE's project, it goes in `research/`. If you're writing about YOUR project's decisions, it goes in `projects/{code}/`. If it's a general concept everyone needs, it goes in `domain-knowledge/`.

## Naming Conventions

- All files: kebab-case, lowercase
- Exceptions: JIRA project codes stay uppercase (e.g., `PROJ-001-fix-name.md`)
- Exceptions: Test cases use `TCNNN.md` / `TCNNN-A.md` format
- Exceptions: `README.md`
- Numbered prefixes: `NN-` for ordered sequences (e.g., `01-system-overview.md`)

## Dependencies

Full methodology rules (knowledge resolution, git safety, report standards, documentation standards) auto-load from `agentic-toolkit/.kiro/steering/` when the toolkit repo is included in the workspace. If the toolkit is not present, this workspace is still functional but behavioral enforcement is reduced — only the conventions documented inline (READMEs, project-context files) apply.

## What Does NOT Go Here

- Source code (goes in project repos)
- Generic methodology (goes in the toolkit repo)
- Personal notes unrelated to a project
- Credentials or secrets
