# bizmates-dev-context

AI-assisted development workspace for Bizmates projects.

## Structure

```
bizmates-dev-context/
├── domain-knowledge/       ← General system concepts (plans, campaigns, account types)
├── research/               ← Upstream/external project research (CAP, CIP, CDB, HCR)
├── docs/                   ← Cross-project timelines and historical estimates
├── projects/               ← Project artifacts (one directory per JIRA project)
│   ├── ascm/              ← ASC Monthly (completed)
│   ├── asch/              ← ASC Honki Set (cancelled)
│   ├── asca/              ← ASC for CAP (active)
│   └── asci/              ← ASC for CIP (active)
└── scripts/                ← Utility scripts
```

## Quick Start

1. Load project context: read `projects/{code}/project-context.md`
2. For system concepts: check `domain-knowledge/`
3. For upstream project info: check `research/`
4. For cross-project timelines: check `docs/`

## Placement Rules

| What you're documenting | Where it goes |
|---|---|
| About YOUR project (decisions, tickets, tests) | `projects/{code}/` |
| About an UPSTREAM project (their spec, their pricing) | `research/{upstream_code}/` |
| General system concept (entities, plans, campaigns) | `domain-knowledge/` |
| Cross-project plans/timelines | `docs/` |

## JIRA Projects

| Code | Name | Board |
|---|---|---|
| ASC | Accounting System Changes (Monthly) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/summary) |
| ASCH | ASC Honki Set | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCH/summary) |
| ASCA | ASC for CAP | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/summary) |
| ASCI | ASC for CIP | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) |
