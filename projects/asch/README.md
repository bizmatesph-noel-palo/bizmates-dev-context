# asch

Project working directory for AI-assisted development on the ASCH (ASC Honki Set) project.

ASCH extends the ASC accounting batch system (`accounting_related_system_for_freee`) to handle revenue allocation for the Honki Set bundled discount campaign.

## Directory Structure

```
asch/
├── project-context.md          ← Load this at session start
├── knowledge-base/             ← Engineering lessons learned
├── testcases/                  ← Structured test cases
├── technical-notes/
│   ├── jira/
│   │   ├── tickets/            ← JIRA ticket specs
│   │   ├── epics/              ← Epic definitions
│   │   └── proposals/          ← Design proposals
│   ├── investigation/          ← Investigation reports
│   └── research/
│       └── ASCH/               ← Pre-design research docs
├── documentation/              ← System docs, diagrams
│   └── diagrams/
├── generated-files/            ← Batch output CSVs (gitignored)
└── .kiro-draft/                ← Draft steering files
    ├── steering/
    ├── hooks/
    └── skills/
```

## Getting Started

1. At session start: "Read `projects/asch/project-context.md`"
2. For base system context: "Read `projects/ascm/project-context.md`"
3. For general Bizmates knowledge: see `domain-knowledge/`

## Related Repos

| Repo | Role |
|------|------|
| `accounting_related_system_for_freee` | Main codebase — ASCH extends this |
| `MBTI_backend` | Source of Honki Set campaign data and charges |
| `ls-database-migrations` | New ASCH table migrations go here |
| `bizmates.jp` | Admin portal — upstream charge writer |

## Parent Project

ASCH is built on top of ASCM. For base system context (batch commands, CTE pipeline, table mapping, multi-tenancy), see `projects/ascm/project-context.md`.
