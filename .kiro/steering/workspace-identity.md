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
| OLD ASCH | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/boards/1753/backlog) | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asch/` (legacy) | ❌ Cancelled (2026-08-07) | — |
| ASCH (NEW 2027) | — (home TBD) | rides ASCA + ASCI | `projects/asch/technical-notes/research/ASCH-2027/` (provisional) | Active — assessment/estimate phase | 2027 campaign |
| ASCA | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog) | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asca/` | Active — builds shared foundation | 2026/12/17 |
| ASCI | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog) | `accounting_related_system_for_freee`, `ls-database-migrations` | `projects/asci/` | Active — reuses ASCA foundation | 2026/12/17 |
| CDB | — | `MBTI_backend` | — | Active (upstream, Patrick-san's team) | — |

> **Naming convention — ASCH:** Unqualified **"ASCH" always means the NEW 2027 ASCH** (active, rides the finished CAP/ASCA + in-build CIP/ASCI work on the discounted paid amount). The cancelled 2026 project is **"OLD ASCH"** — only ever referenced with that explicit label. The two are different projects that reused the name; never conflate them. (OLD ASCH artifacts currently sit under `projects/asch/`; the NEW ASCH home is still provisional — see the deferred doc-structure item in the task tracker.)

**Note:** ASC is the JIRA code for ASCM (the original project was just "ASC" before subsequent projects were created).

## Cross-Project Resource Plan (from meeting 2026-07-28, updated 2026-08-12)

**Management Partners (JP ↔ PH):**
- Kuroda-san (PM) ↔ Patrick-san (SDM) — handles ASC / Accounting projects
- Soli-san (PM) ↔ Jasser-san (SDM) — handles CAP / CIP upstream projects

| Project | Lead | Sub-Lead | Developer(s) | Status |
|---|---|---|---|---|
| ASCH | Noel Palo | — | Throy Embudo, Cristoff Danganan | ❌ Cancelled (2026-08-07) |
| ASCA (ASC for CAP) | Noel Palo | — | Throy Embudo, Cristoff Danganan | ✅ Active (builds foundation) |
| ASCI (ASC for CIP) | Noel Palo | — | Throy Embudo, Cristoff Danganan | Active (reuses ASCA foundation) |
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

## Daily Sync (SOD / EOD)

This workspace uses the toolkit's **Daily Sync** workflow (`agentic-toolkit/workflows/daily-sync.md`) for start-of-day and end-of-day tracking. Manual invocation:

- **`SOD: resume my day`** (optionally `— today is YYYY-MM-DD`) → read-only resume report: since-last-entry, unverified items (asked back), today's priorities. No doc edits until the user confirms.
- **`EOD: wrap my day`** + what got done → tick the tracker's Remaining, append a dated daily-log entry, refresh the priority banner, add a timeline snapshot only if something material changed.
- **`ST: status`** (optionally `— ASCA` / `— ASCI + ASCH`) → read-only tracker pulse: open / in-progress / unverified per project. No priorities, no edits.
- **`LOG: <update>`** → record one scoped update to the tracker (tick/reword the affected Remaining item + append to today's log). **Tracker-only** — never writes the timeline; flags material updates as "run SYNC when ready."
- **`SYNC: reconcile docs`** (optionally `— timeline only`) → reconcile the master timeline + other project docs against the tracker, figuring out the drift itself. Trivial tracker-internal fixes auto-apply; anything touching the timeline is shown for confirmation before writing. Never syncs an unverified item in as done.
- **`PU: project update`** (optionally `— for <name>, ASCA + ASCI`) → stakeholder highlight/lowlight update from the tracker + timeline (toolkit `workflows/project-update.md`). Read-only, paste-ready. Default audience: Patrick-san (SDM); per project (ASCA, ASCI). Done-but-unverified items are never shown as highlights.

**Tracking documents (ASC projects):**

| Role | Path |
|---|---|
| Tracker (daily log + Remaining checklist) | `docs/asc-projects-task-tracker.md` |
| Timeline (authoritative baseline + snapshots) | `docs/asc-projects-master-timeline.md` |

**Project rules the daily sync must honor:**
- **Verify before claiming.** Never record a deploy result, review gate (G3), or external-team status as done without confirmation — list it as unverified and ask.
- **Unit-test / DB-safety scope:** ASCA + ASCI tests only. Leave old unrelated tests alone unless a project change actually broke them (missing field, expected-vs-actual drift). Flag out-of-scope findings as note-only.
- **Working calendar:** Mon–Fri. PH and JP holiday calendars are independent — each team works through the other's holiday unless the date is a holiday in both (they do not stack).
- Keep the tracker (day-to-day) and the master timeline (baseline) consistent with each other; the daily log is append-only.

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

### The three "knowledge" buckets — do not confuse them

"Knowledge" is used in three places for three *different* genres. They have distinct names, homes, and contents. Match the genre, use the canonical name — never improvise a variant (e.g. a project `knowledge/` singular).

| Genre | What it is | Canonical home | Format |
|---|---|---|---|
| **Domain facts** | What the business/system *is* — entities, products, integrations. Cross-project, permanent. | `domain-knowledge/` (repo root) | Reference entry (what it is, where it lives, which repo owns it) |
| **Project lessons** | Failure patterns learned on a project — a concrete problem and how to avoid it. Project-scoped. | `projects/{code}/knowledge-base/` | Problem → Root Cause → Fix → Prevention (KB-article template) |
| **Methodology / agent-behavior lessons** | How to *work* — process discipline, tooling, agent-behavior retrospectives. Project-agnostic. | `agentic-toolkit/knowledge/` (toolkit repo only) | Portable lesson (failure → root cause → guardrail → one-line test) |

Disambiguation rules:

- **`knowledge-base/` (plural, "-base") is the project-level folder** for failure-pattern lessons. It lives under `projects/{code}/`. ASCM's `projects/ascm/knowledge-base/` is the canonical example. **Never name a project folder just `knowledge/`** — that collides with the toolkit's meaning.
- **`knowledge/` (singular) is the toolkit folder** for methodology and agent-behavior lessons. It never appears inside a project.
- **`domain-knowledge/` is domain facts only** — not lessons, not decisions. If it's "here's a mistake and how to avoid it," it's a lesson (`knowledge-base/`), not a domain fact.
- **A decision explainer / design rationale is NOT a `knowledge-base/` lesson.** "Why we chose X" (narrative, no Problem→Prevention shape) goes in `projects/{code}/documentation/`, alongside ADRs and design docs. `knowledge-base/` is reserved for the failure-pattern genre.
- **Promotion path:** a project lesson that proves useful across 2+ projects can be generalized and promoted to the toolkit's `knowledge/` (methodology) or, if it's a domain fact, to `domain-knowledge/` — with human approval (see `knowledge-resolution.md` feedback loop).

## Naming Conventions

- All files: kebab-case, lowercase
- Exceptions: JIRA project codes stay uppercase (e.g., `PROJ-001-fix-name.md`)
- Exceptions: Test cases use `TCNNN.md` / `TCNNN-A.md` format
- Exceptions: `README.md`
- Numbered prefixes: `NN-` for ordered sequences (e.g., `01-system-overview.md`)

## JIRA (Atlassian MCP)

This workspace connects to JIRA via the `mcp-atlassian` MCP server (Jira + Confluence share this one server).

- **Config:** `.kiro/settings/mcp.json` (gitignored). Launches via `wsl.exe -d Ubuntu-20.04 -- /home/bizdev/.local/bin/uvx mcp-atlassian --env-file .../mcp-jira.env` (Windows Kiro → WSL binary).
- **Secrets:** `.kiro/settings/mcp-jira.env` (gitignored — `*.env`). Holds `JIRA_*` creds, commented `CONFLUENCE_*` placeholders, and `READ_ONLY_MODE`.
- **Safety default:** keep `READ_ONLY_MODE=true`; flip to `false` only when creating/updating tickets, then reconnect the server. `autoApprove` only skips prompts — it does not enforce read-only.
- **Setup/troubleshooting:** see `agentic-toolkit/knowledge/tooling-setup.md` → MCP Server Setup (Windows+WSL launch, `--env-file`, read-only, reconnect gotchas).

Verified working 2026-09-07 (created ASCA-9 as the first MCP-created ticket).

## Dependencies

Full methodology rules (knowledge resolution, git safety, report standards, documentation standards) auto-load from `agentic-toolkit/.kiro/steering/` when the toolkit repo is included in the workspace. If the toolkit is not present, this workspace is still functional but behavioral enforcement is reduced — only the conventions documented inline (READMEs, project-context files) apply.

## What Does NOT Go Here

- Source code (goes in project repos)
- Generic methodology (goes in the toolkit repo)
- Personal notes unrelated to a project
- Credentials or secrets
