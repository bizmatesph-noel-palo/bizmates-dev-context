---
inclusion: auto
---

# Workspace Identity

## What This Workspace Is

This is an AI-assisted development workspace for All Bizmates' Projects.

It contains project-specific knowledge, test cases, investigation reports, JIRA tickets, and documentation produced during development — organized by project.

## Active Projects

| Project Code | Code Repo(s) | Artifacts Directory | Status | Deadline |
|---|---|---|---|---|
| ASCM | `accounting_related_system_for_freee` | `projects/ascm/` | ✅ Deployed (Jun 2026) | — |
| ASCH | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asch/` | ❌ Cancelled (2026-08-07) — pivoted to ASC-CAP/CIP | — |
| ASC for CAP | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asch/technical-notes/research/CAP/` | Active — Scenario D proposed | 2026/12/17 |
| ASC for CIP | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asch/technical-notes/research/CIP/` | Active — reuses ASC-CAP foundation | 2026/12/17 |
| CDB | `MBTI_backend` | `projects/asch/technical-notes/research/CDB/` | Active (separate team) | Before ASCH 10/1 |

## Cross-Project Resource Plan (from meeting 2026-07-28, updated 2026-08-12)

**Management Partners (JP ↔ PH):**
- Kuroda-san (PM) ↔ Patrick-san (SDM) — handles ASC / Accounting projects
- Soli-san (PM) ↔ Jasser-san (SDM) — handles CAP / CIP upstream projects

| Project | Lead | Sub-Lead | Developer(s) | Status |
|---|---|---|---|---|
| ASCH | Noel Palo | — | Throy Embudo, Cristoff Danganan | ❌ Cancelled (2026-08-07) |
| ASC for CAP | Noel Palo | — | Throy Embudo | ✅ Active (builds foundation) |
| ASC for CIP | Noel Palo (overall) | Orlino Monares | Cristoff Danganan | Active (reuses CAP foundation) |
| CDB (upstream) | Paolo | — | Efren | ✅ Active — originally needed by ASCH; continues independently |
| CAP (upstream) | Keith Manuntag | — | Terry Balahadia | Active (Jasser-san's team) |
| CIP (upstream) | Jefferson Gernale | — | Haggai Rei Cacacho | Active (Jasser-san's team) |

**Planned timeline:**
- ASCH: ❌ Cancelled (2026-08-07)
- ASC for CAP: starts ~September, deadline Dec 17 (builds shared foundation)
- ASC for CIP: starts after ASC-CAP, deadline Dec 17 (reuses foundation)
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
| Domain knowledge (applicable to ALL projects) | `domain-knowledge/` (at repo root) |

Place information here when it applies regardless of which project you're working on (e.g., entity definitions, system-wide integrations, cross-cutting concepts).

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
