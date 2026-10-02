# Projects

Each subdirectory is one JIRA project. Artifacts (tickets, test cases, documentation, knowledge base) live inside the matching project directory.

| Directory | JIRA Code | Status |
|---|---|---|
| `ascm/` | ASC | ✅ Completed (Jun 2026) |
| `asch/` | ASCH | ❌ Cancelled (Aug 2026) |
| `asca/` | ASCA | Active — ASC for CAP |
| `asci/` | ASCI | Active — ASC for CIP |

## Structure (per project)

```
projects/{code}/
├── project-context.md              ← load this at session start
├── documentation/                  ← project docs, diagrams, decisions
├── knowledge-base/                 ← engineering lessons learned
├── technical-notes/
│   ├── jira/tickets/               ← JIRA ticket specs
│   ├── jira/epics/                 ← epic definitions
│   ├── jira/proposals/             ← design proposals
│   └── investigation/              ← investigation reports
├── testcases/                      ← structured test cases
├── generated-files/                ← batch output (gitignored)
└── .kiro-draft/                    ← draft steering/hooks
```

## Rules

- One directory per JIRA project code
- Project-specific artifacts only — not upstream research (that goes in `research/`)
- Never place files directly in the project root — use subdirectories
- Load `project-context.md` at the start of each session
