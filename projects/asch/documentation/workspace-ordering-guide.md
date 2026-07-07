# ASCH Workspace Ordering Guide

**Audience:** Developers using the ASCH (Agentic Shared Context Hub) workspace configuration for AI-assisted development.
**Purpose:** Explains how to order repos in the multi-root workspace so that Kiro's features (specs, steering, artifacts) work correctly.

---

## TL;DR

Put the main code repo first (specs anchor there), dev-context second (artifacts go there), toolkit third (methodology auto-loads), remaining repos after.

```
1. accounting_related_system_for_freee   ← specs + code (primary)
2. bizmates-dev-context                  ← artifacts (reports, tickets, investigations)
3. agentic-toolkit                       ← methodology (workflows, templates, rules)
4. ls-database-migrations
5. bizmates.jp
6. MBTI_backend
```

---

## Context

In a Kiro multi-root workspace, the first folder has a special role — specs anchor there and it acts as the default workspace root. All folders' steering files auto-load regardless of position, but later folders override earlier ones on conflicts. Getting the order wrong means specs end up in the wrong repo or steering doesn't apply as expected.

---

## How It Works

### Position mechanics

| Position | Behavior |
|----------|----------|
| **First folder** | Specs (requirements.md, design.md, tasks.md) anchor here under `.kiro/specs/`. Acts as the default workspace root. |
| **All folders** | `.kiro/steering/` files auto-load into every session regardless of position. |
| **Later folders** | Override earlier folders when merged settings conflict. |

### Role of each repo

**Slot 1 — `accounting_related_system_for_freee`**

The primary code repo where implementation happens. First position because:

- Specs (requirements.md, design.md, tasks.md) live in this repo's `.kiro/specs/` — following existing team convention
- Its `.kiro/steering/` provides project-specific conventions (architecture, tech stack, coding standards)
- Code changes from the spec workflow land here

**Slot 2 — `bizmates-dev-context`**

The artifact store. Its `workspace-identity.md` steering tells the agent how to route non-code outputs:

- Investigation reports → `projects/asch/technical-notes/investigation/`
- JIRA tickets → `projects/asch/technical-notes/jira/tickets/`
- Project knowledge → `projects/asch/`

Does not need first position because it doesn't own specs — it stores artifacts produced alongside the spec workflow.

**Slot 3 — `agentic-toolkit`**

Read-only methodology layer. Provides:

- Workflows (how to investigate, fix bugs, create PRs, run spec-driven development)
- Templates (tickets, reports, steering skeletons)
- Auto-loaded steering (git safety, naming conventions, report standards)

Never modified during normal work. Consulted on demand when you trigger a workflow.

**Slots 4–6 — Supporting repos**

Available for cross-repo reference when a feature touches multiple codebases. Order among these doesn't matter unless their `.kiro/steering/` files conflict (later wins).

### ASCH vs ASCM

| | ASCH | ASCM |
|---|---|---|
| **Primary repo** | `accounting_related_system_for_freee` | `accounting_related_system_for_freee` |
| **Work style** | Full agentic: spec → design → tasks → execute → PR | Targeted: `tc.md`-driven, known-scope fixes |
| **Methodology** | `agentic-toolkit` workflows guide the process | Minimal — direct implementation |
| **Artifacts** | Specs, reports, tickets produced alongside code | Mostly code changes only |
| **When to use** | New features, investigations, design-required work | Scoped fixes, known-target changes |

Same primary repo, different operating mode. ASCH adds the methodology and artifact layers for work that needs discovery and design.

---

## Step-by-Step

1. Open Kiro and create a multi-root workspace with the order above.
2. Load the project context:
   > "Read `projects/asch/project-context.md`"
3. Use a workflow trigger:
   > "Start a new feature" / "Investigate this issue" / "Fix this bug" / "Create a PR"

The agent uses: project context (from dev-context) + toolkit workflows + code repo steering to work across all three layers.

---

## Reference

| Question | Answer |
|----------|--------|
| Where do specs go? | `accounting_related_system_for_freee/.kiro/specs/` |
| Where do investigation reports go? | `bizmates-dev-context/projects/asch/technical-notes/investigation/` |
| Where do tickets go? | `bizmates-dev-context/projects/asch/technical-notes/jira/tickets/` |
| Where does code go? | `accounting_related_system_for_freee` |
| Where does methodology live? | `agentic-toolkit/` (read-only reference) |
| Which steering files load? | All `.kiro/steering/` from every folder |
| What wins on conflict? | Later folders override earlier ones |

---

*Last updated: July 2026*
