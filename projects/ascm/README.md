# ascm

Project working directory for AI-assisted development on the ASC Monthly Plans project (accounting_related_system_for_freee).

## Directory Structure

```
ascm/
├── project-context.md          ← Load this at session start
├── knowledge-base/             ← Engineering lessons learned
├── testcases/                  ← Structured test cases (tc-001 through tc-035)
├── technical-notes/
│   ├── jira/
│   │   ├── tickets/            ← JIRA ticket specs
│   │   ├── epics/              ← Epic definitions
│   │   └── proposals/          ← Design proposals
│   └── investigation/          ← Investigation reports
├── documentation/              ← Project-specific reference docs
│   └── diagrams/               ← Architecture diagrams (.puml, .md)
├── generated-files/            ← Batch output CSVs (gitignored)
└── .kiro-draft/                ← Suggested steering for ASC's .kiro/
    ├── steering/
    ├── hooks/
    ├── skills/
    └── settings/
```

## Getting Started

1. Open workspace with ASC repos + `agentic-notes/` + `agentic-toolkit/`
2. At session start: "Read `agentic-notes/projects/ascm/project-context.md`"
3. All project rules and context are in that file

## Related Repos

| Repo | Role |
|------|------|
| `accounting_related_system_for_freee` | Main ASC codebase (Laravel batch) |
| `bizmates.jp` | Admin Portal (upstream — writes charges) |
| `MBTI_backend` | Student Portal (upstream — writes charges) |
| `ls-database-migrations` | Database schema source of truth |
