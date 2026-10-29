# 01 — Promoted requirements.md must match the Kiro spec-format validator

## Document Info

| | |
|---|---|
| **Document type** | Knowledge Base Article |
| **Date** | 2026-10-28 (Created) |
| **Author** | Noel Palo, Lead (Kiro-assisted) |
| **Assisted by** | Kiro |
| **Status** | Active |
| **JIRA** | [ASCI-10](https://bizmates.atlassian.net/browse/ASCI-10) (G2 — surfaced during promotion) |

> **TL;DR:** The Kiro spec UI validates `requirements.md` and blocks "Continue to Design" unless the file uses the exact Kiro format (`# Requirements Document` H1, a `## Requirements` section, a `## Glossary` section). A dev-context/PM draft doesn't use that format, so it must be **converted on promotion**, not copied verbatim.

---

## Problem Pattern

A requirements document authored for human/stakeholder review (descriptive title, prose structure) is promoted verbatim into a repo's `.kiro/specs/{feature}/` folder. The spec UI's linter then rejects it and refuses to unlock "Continue to Design" (the spec-UI button that generates `design.md`). The content is correct; only the heading structure is wrong.

---

## How We Encountered It

Promoting the G1-approved ASCI Spec 01 `requirements.md` from the dev-context source of record into `accounting_related_system_for_freee/.kiro/specs/asci-spec-01-cip-integration/`. The file was copied as-is. The spec UI reported three errors:

- `Missing required heading: # Requirements Document` (requirements/missing-title)
- `Missing recommended section: ## Glossary` (requirements/missing-glossary)
- `Missing required section: ## Requirements` (requirements/missing-requirements-section)

**JIRA:** ASCI-10 (G2 Architecture story)

---

## Root Cause

The dev-context draft was written for Kuroda-san's Confluence review, so it used a reader-friendly shape:

| Draft (invalid for the UI) | Kiro validator wants |
|---|---|
| `# ASCI Spec 01 — CIP Integration — Requirements (G1 APPROVED)` | `# Requirements Document` (exact), spec name in a bold line below |
| `### Glossary (CIP-specific ...)` nested under Introduction | top-level `## Glossary` |
| top-level `## Requirement 1`, `## Requirement 2`, ... | a `## Requirements` wrapper, then `### Requirement N:` each with `#### Acceptance Criteria` |

The promotion workflow said "mirror existing specs" but didn't name these hard rules, so the mismatch wasn't caught before the copy. The sibling ASCA specs (`asca-spec-01-foundation`, `asca-spec-02a-cap-core-injection`) already followed the valid format — diffing against them up front would have caught it.

---

## What We Did

Restructured the promoted file in place (content preserved verbatim):

- H1 → `# Requirements Document`, with `**ASCI Spec 01 — CIP Integration**` as the bold line under it (status moved to the Document Info table).
- Promoted `### Glossary` → top-level `## Glossary`; moved "Out of scope" to stay as `###` under Introduction.
- Added a `## Requirements` wrapper and demoted each `## Requirement N` → `### Requirement N:` (the `#### Acceptance Criteria` sub-headings were already correct).

Verified with `grep -nE '^#{1,4} '` against the ASCA specs' heading tree.

To prevent recurrence, added to the toolkit: a canonical skeleton (`templates/spec/requirements.md`) and a "Kiro Spec-Format Validator Rules (promotion checklist)" subsection in `workflows/spec-driven-development.md`.

---

## Industry Standard / Best Practice

Spec-driven tooling (Kiro, GitHub Spec Kit) defines a fixed document schema that downstream automation parses — the design/tasks generation reads the structured headings, not freeform prose. Treat the promoted artifact as a machine-validated file with a required schema, not just a readable document; keep the stakeholder-facing version and the repo version in sync in content but allow their *format* to differ (reader-friendly draft vs validator-conformant spec).

---

## Prevention Checklist

- [ ] Before promoting, open an existing valid spec in the same repo and note its heading tree.
- [ ] Start from `templates/spec/requirements.md` (toolkit) rather than copying the draft verbatim.
- [ ] Ensure H1 is exactly `# Requirements Document`; move the spec name to a bold line / Document Info table.
- [ ] Ensure a top-level `## Requirements` section exists, with `### Requirement N:` + `#### Acceptance Criteria`.
- [ ] Ensure a top-level `## Glossary` section exists.
- [ ] Run `grep -nE '^#{1,4} ' {repo}/.kiro/specs/{feature}/requirements.md` and diff the heading tree against a known-valid spec.
- [ ] Confirm `.config.kiro` exists with a unique `specId` before expecting "Continue to Design" to unlock.
