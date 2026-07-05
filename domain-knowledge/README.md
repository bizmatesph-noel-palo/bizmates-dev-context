# Domain Knowledge

Shared knowledge applicable across all projects in this workspace. This is the **first place to check** when you need information about how the company's systems work — regardless of which project you're working on.

## How to Use (Lookup Protocol)

When you need to understand a concept, entity, or system behavior:

1. **Check here first** — quick scan. Does an entry exist for this topic?
   - If yes: read it. It tells you what the concept is, where it lives in code, and which repo owns it.
   - If it references a repo not in the workspace: ask the user to add it.
2. **Then verify in code** — use what the library told you (table names, file paths, constants) to do a targeted search in the project codebase.
3. **Then check sibling projects** — if nothing here, another project's research or KB might have it.
4. **Then ask the human** — if nothing documented anywhere, escalate.

**Why this order:** Reading one markdown file takes seconds. Blind-searching a codebase takes minutes. The library is the map — use it before exploring the territory.

**If this library entry differs from what the code shows** — do not assume either is correct. Flag the discrepancy to the user. The code might be stale, or the library might be stale. The human decides what to update and when. Never update either side without explicit permission.

## What Goes Here

- Business entity definitions (account types, contract types, lifecycle states)
- System-wide integration patterns (external APIs, billing, campaigns)
- Product/plan catalog and relationships
- Cross-cutting technical concepts (charge lifecycle, billing periods, multi-tenancy)

## What Does NOT Go Here

- Project-specific implementation details → `projects/X/documentation/`
- Lessons learned from a specific project → `projects/X/knowledge-base/`
- Source code → project repos
- Methodology/tooling → `agentic-toolkit/`

## Promotion Rule

When a project discovers knowledge that applies universally:
1. Save it in `projects/X/knowledge-base/` or `projects/X/documentation/` first
2. Once confirmed useful across projects, promote a copy here (with human approval)
3. Reference from here in future projects

## Naming

Files use kebab-case: `topic-name.md`
