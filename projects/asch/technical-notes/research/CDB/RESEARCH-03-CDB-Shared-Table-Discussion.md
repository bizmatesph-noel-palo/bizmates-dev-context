# CDB Shared Table — Discussion Notes (20260709)

**Triggered by:** Wu-san message (2026-07-09)
**JIRA Ticket:** TBA
**Prepared by:** Noel (Kiro-assisted)
**Date:** 2026-07-09
**Related:** ASCH project, HCR project, CDB project (Soli-san/Ankit-san/Nasu-san)

---

## What We Know

**About CDB:**
- Project name: CDB (Campaign Discount Batch)
- Initial design: daily batch in MBTI_backend worker that checks campaign eligibility and saves results to a new table
- No further detail available — we have not seen the CDB design document or table schema

**About HCR (separate project, same Confluence space):**
- The HCR project (Honki Set Customer Retention) has its own PRD and technical proposal for a `trn_honki_set_eligibility` table with a daily batch (`honki-set:check-eligibility`)
- HCR's purpose is retention warning display (UI feature)
- **Codebase check (2026-07-09):** Neither the `trn_honki_set_eligibility` table, the batch command, nor the Eloquent model exist yet in `MBTI_backend` or `ls-database-migrations`. The HCR/CDB feature is still at the design/proposal stage — nothing has been implemented.
- See: `REF-HCR-04-PRD-Honki-Set-Customer-Retention.md`, `REF-HCR-05-Honki-Set-User-Identification.md`

**Relationship between CDB and HCR:** Unknown. They may be the same initiative under different names, overlapping, or distinct. Wu-san's description of CDB matches HCR's design pattern (daily batch + eligibility table), but we cannot confirm they are the same without seeing CDB's actual deliverables.

---

## What ASCH Needs (for the meeting)

Regardless of whether CDB uses the HCR table or creates something new, ASCH's requirements for a shared eligibility source are:

| # | Data Point | Why ASCH Needs It |
|---|-----------|-------------------|
| 1 | `student_id` | Match to charges for proration calculation |
| 2 | Campaign round identifier | Determine which campaign period's rules apply |
| 3 | Coaching start date | Contract period boundary for proration (J/I calculation) |
| 4 | Lesson start date | Contract period boundary — may differ from coaching start |
| 5 | Lesson plan type (Daily1 / Daily2 / Monthly15) | Determines whether proration uses days (I=contract days) or tickets (I=lesson_volume) |
| 6 | Purchase structure (bundle vs separate) | Affects how ΣM is composed |
| 7 | Active/forfeited/completed status | Determines whether month-6 discount applies |
| 8 | When forfeiture occurred (if applicable) | Determines App removal month and month-6 eligibility cutoff |

Items 1–3 and 6–7 could plausibly come from an eligibility table. Items 4–5 and 8 likely need ASCH to query `trn_charge` / `trn_student_product` independently.

---

## What ASCH Does NOT Need from an Eligibility Table

ASCH's calculation logic (proration formula, allocation, Freee adjustments) is entirely internal. No shared table can provide:
- Paid amounts per product (M)
- List prices per product (L)
- Allocated amounts (O)
- Prorated revenue (P)
- Contract lifecycle history (plan changes, revisions)

These remain ASCH-only tables (`asch_bundle_components`, `asch_proration_groups`, `asch_monthly_prorations`, etc.).

---

## Key Takeaway for the Meeting

Wu-san's suggestion is sound: if CDB provides a table that identifies Honki Set members, ASCH should use it rather than building its own eligibility checker in the accounting system. The eligibility logic belongs in MBTI_backend where the student data lives.

ASCH's ask is: **provide enough metadata alongside the eligibility flag** so ASCH can identify the student's enrollment details without re-implementing the candidate identification queries.

---

## Cross-Reference

- HCR PRD (reference): `REF-HCR-04-PRD-Honki-Set-Customer-Retention.md`
- HCR technical proposal (reference): `REF-HCR-05-Honki-Set-User-Identification.md`
- ASCH spec (enrollment identification): `RESEARCH-02-Specification-Analysis.md` § 8.1, item #11
- ASCH project context: `projects/asch/project-context.md`
