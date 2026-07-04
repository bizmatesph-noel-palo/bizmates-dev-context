# Domain Knowledge

Shared knowledge applicable across all projects in this workspace. This is the first place to check when you need information about how the company's systems work — regardless of which project you're working on.

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
2. Once confirmed useful across projects, create a copy here
3. Reference from here in future projects

## Naming

Files use kebab-case: `topic-name.md`
