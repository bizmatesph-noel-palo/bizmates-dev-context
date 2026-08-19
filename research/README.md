# Research — Upstream & External Project Reference

This directory contains reference documents about OTHER teams' projects — their specs, pricing decisions, architecture, and technical details that our projects depend on.

**Organized by upstream project code.** Any project in this workspace can reference these docs.

## Directories

| Directory | Upstream Project | What it contains |
|---|---|---|
| `CAP/` | Coaching and App Plan (Keith's team) | Pricing mechanism, plan_ids, requirements decisions, overwrite proposal |
| `CIP/` | Coaching Intensive Plan (Jefferson's team) | Project spec, coaching campaigns, plan_ids |
| `CDB/` | Campaign Discount Batch (Paolo's team) | Design proposal, ASCH alignment gaps |
| `HCR/` | Honki Customer Retention | HCR project references |

## Placement Rule

- **About someone ELSE's project** (their spec, their pricing, their decisions) → put it here
- **About OUR project's decisions** (how we use their data) → put in `projects/{code}/technical-notes/`
- **General system concept** (not project-specific) → put in `domain-knowledge/`

## File Naming

Research documents use the `REF-` prefix:
- `REF-{PROJECT}-NN-Short-Description-YYYYMMDD.md`
- Example: `REF-CAP-05-Upstream-Pricing-Discussion-20260812.md`

The prefix signals "this is a reference — source of truth from an external team, not our analysis."
