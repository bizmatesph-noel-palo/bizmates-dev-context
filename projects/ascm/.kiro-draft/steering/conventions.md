---
inclusion: auto
---

# Conventions

## Naming

- JIRA tickets: `ASC-XXX`
- Branches: `feature/ASC/ASC-{number}` (from ASC-master)
- Test cases: `ASC-XXX_TestCase{NNN}.md` (ASC-XXX is project namespace, JIRA ID goes inside file header)
- Test case overrides: `ASC-XXX_TestCase{NNN}-A.md` — the `-A` is the active test case; non-A is historical, skipped during simulation
- Technical notes: `ASC-{id}_{Type}_{name}.md`
- Investigation directories: `YYYYMMDD_some_name/`
- Investigation reports: `REPORT_XX_Short_Name.md` (00 = initial, 01+ = subsequent)

## File Placement (asc-kiro)

| Content type | Path |
|---|---|
| JIRA ticket docs | `Technical_Notes/Tickets/` |
| Epic docs | `Technical_Notes/Epics/` |
| Design proposals | `Technical_Notes/Proposals/` |
| Investigation reports | `Technical_Notes/Issue_Investigation/YYYYMMDD_name/` |
| Test cases | `Testcases/` |
| System diagrams | `System_Diagrams/` |
| Knowledge base | `Knowledge_Base/` |
| Generated CSVs | `DEV04_Generated_Files/` (gitignored) |

## Documentation Content Structure

When creating methodology/process documentation, follow:
```
What is it → How we do it → Does it work → Is it credible
```
Summary → Concept → How It Works → Why It Works → Strengths → Limitations → Conclusion → Appendix

## Cross-References

Always prefix paths with repo shorthand in multi-repo context:
- `[ASC]` = `accounting_related_system_for_freee`
- `[MBTI]` = `MBTI_backend`
- `[Admin]` = `bizmates.jp`
- `[Migrations]` = `ls-database-migrations`
- `[asc-kiro]` = `asc-kiro`

Within documents, use markdown anchor links for internal references:
```markdown
[See detailed analysis](#section-heading-as-anchor)
```
