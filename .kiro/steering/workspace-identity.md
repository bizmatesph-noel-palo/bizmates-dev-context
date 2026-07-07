---
inclusion: auto
---

# Workspace Identity

## What This Workspace Is

This is an AI-assisted development workspace for All Bizmates' Projects.

It contains project-specific knowledge, test cases, investigation reports, JIRA tickets, and documentation produced during development — organized by project.

## Active Projects

| Project Code | Code Repo(s) | Artifacts Directory | Status |
|---|---|---|---|
| — | — | — | — |

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
| `ascm` | TBA | `projects/ascm/` | Active |
