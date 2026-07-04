# bizmates-dev-context

AI-assisted development workspace. Contains project-specific knowledge, artifacts, and context organized by project.

## Structure

```
bizmates-dev-context/
├── .kiro/
│   └── steering/
│       └── workspace-identity.md   # What this workspace is, project routing
├── domain-knowledge/               # Shared knowledge across all projects
├── projects/
│   ├── project-a/                  # First project
│   └── project-b/                  # Next project
├── scripts/
│   ├── bootstrap-project.sh        # Scaffold new projects
│   └── link-project.sh             # Scan repo and generate .detected-stack.md
├── Makefile                         # Project management commands
└── README.md
```

## Quick Start

### Start a session

1. Open workspace with project repo(s) + this repo + agentic-toolkit
2. Load project context: "Read `projects/{name}/project-context.md`"
3. Work normally — artifacts land in the project's directory

### Add a new project

```bash
make new-project name=project-code
make link-project name=project-code repo=/path/to/code
```

Then in a session: "Read `projects/project-code/.detected-stack.md` and help me fill in `project-context.md`"

## What Can I Do?

Once project-context.md is filled, you can use any of these toolkit workflows:

| Say... | What happens |
|---|---|
| "Investigate this issue" | Full investigation workflow → report in `technical-notes/investigation/` |
| "Fix this bug" | Bug-fix workflow → code changes in project repo |
| "Start a new feature" | Spec-driven development → requirements → design → tasks → code |
| "Create a PR" | PR workflow → branch → commit → push → PR |
| "Write a ticket" | JIRA template → ticket in `technical-notes/jira/tickets/` |

See `agentic-toolkit/knowledge/getting-started.md` for the full lifecycle.

## Projects

| Project | Directory | Code Repo | Status |
|---------|-----------|-----------|--------|
| — | — | — | — |

## Commands

```bash
make help           # Show available commands
make new-project    # Scaffold a new project (name= required)
make link-project   # Scan a repo and pre-fill context (name= repo= required)
make list-projects  # List all project directories
```
