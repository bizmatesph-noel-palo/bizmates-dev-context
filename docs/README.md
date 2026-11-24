# Docs

Cross-project documents that are not owned by a single project. Timelines, estimates, historical plans, and day-to-day tracking that span multiple JIRA projects.

## Contents

| File | What it is |
|---|---|
| `asc-projects-master-timeline.md` | Overall timeline for all ASC projects (ASCM, ASCH, ASCA, ASCI) — authoritative baseline + dated status snapshots |
| `asc-projects-task-tracker.md` | Day-to-day task tracker for ASCA + ASCI — live "Remaining" checklist + append-only daily log (the SOD/EOD working view; companion to the master timeline) |
| `workspace-setup.md` | Local workspace/environment setup notes |

## Rules

- Only documents that span multiple projects or don't belong to any single project (incl. cross-project day-to-day tracking like the task tracker)
- Project-specific docs go in `projects/{code}/documentation/`
- Upstream research goes in `research/`
- Superseded documents are moved to the root `archive/` (mirroring their original path), not deleted — see `archive/README.md`

## Archived

- `asc-cap-cip-combined-estimate-20260808.md` — Scenario C estimate, superseded by `asc-projects-master-timeline.md`; moved to `archive/docs/` on 2026-09-23
