---
inclusion: manual
---

# Investigation Workflow

## Report Format

All investigation reports MUST follow this header:

```markdown
# [Title] — [Short Description] (YYYYMMDD)

**Reported by:** [Name]
**JIRA Ticket:** [ASC-XXX](https://bizmates.atlassian.net/browse/ASC-XXX) or TBA
**Investigated by:** [Name]
**Date:** [Date issue was REPORTED — not when report was written]
**Environment:** [Where data was pulled from]
**Batch run analyzed:** [Month(s) and date ranges, if applicable]
```

## Report Structure (single-issue)

1. **Summary** — what was reported, root cause in 1-2 sentences, confidence level
2. **Evidence** — affected data, code trace, observed behavior
3. **Analysis** — why the gap exists, historical context
4. **Expected Fix** — brief direction (2-3 sentences). Full detail in ticket file.
5. **Scope Assessment** — table: Is this ASC scope? Severity? Data loss? Tenants?
6. **Next Steps** — what's pending
7. **Cross-Reference** — links to related docs, code, tickets

## Confidence Markers

Always state what is confirmed vs inferred:
- "Root cause (code trace, not yet verified with data)"
- "Confirmed via Metabase query (see Appendix)"
- "Inferred from code — needs data verification"

## Report ↔ Ticket Relationship

- Report: describes what happened and what we think will fix it
- Ticket: describes exactly what to implement (before/after code, locations, ACs)
- Locally: reference each other by relative path
- On Confluence: ticket becomes sub-page of report

## File Naming

```
Technical_Notes/Issue_Investigation/YYYYMMDD_short_name/
├── REPORT_00_Initial_Investigation.md
├── REPORT_01_Deeper_Analysis.md
├── METABASE_Q1_description.csv
└── Generated_Files/     (gitignored — local CSV output)
```
