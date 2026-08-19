# ASCH Requirement Update — Unified Accounting CSV Delivery for ASCH / CAP / CIP

**Source:** Kuroda-san (Confluence: "Requirement Update: Unified Accounting CSV Delivery for ASCH / CAP / CIP")  
**Status:** AUTHORITATIVE — new cross-project delivery requirement  
**Date received:** 2026-08-05  
**Scope:** Email delivery unification, failure isolation constraints, phasing plan

---

## 1. Background

ASCH, CAP, and CIP each produce their own allocation CSVs (detail + summary) on the same monthly cycle as the existing ASC batch — preview on the 1st, final on the 3rd. If each project sends its own email, Accounting would receive three or four separate monthly emails in addition to the existing ASC delivery.

Accounting has already indicated during ASCH discussion that they do not want the number of monthly emails to increase. This requirement addresses that.

---

## 2. Requirement

Deliver all accounting CSVs for a given run cycle in a **single email** to Accounting.

- ASCH releases first and delivers its CSVs by the existing ASCH email.
- When CAP and CIP are completed, their CSVs are **added to that same email** rather than sent separately.
- The email covers both the preview (1st) and final (3rd) cycles, consistent with the existing schedule.

---

## 3. Mandatory Design Constraint: Failure Isolation

This is the condition under which the unified email is acceptable.

**An error in one project's allocation processing must not affect the CSV generation or the email delivery of any other project.**

Specifically:

1. Each project's allocation batch generates its CSVs independently. A failure in CAP must not prevent ASCH or CIP CSVs from being generated.
2. Email delivery must not be blocked by a partial failure. If one project did not complete, the email is still sent with the CSVs that are available.
3. The email body must state, per project, whether the CSVs are included and the run status (succeeded / failed / not executed), so Accounting can immediately see what is missing and does not mistake an absent file for a zero result.
4. Freee journal sending remains per project. A failure or a revision in one project must not block or alter another project's journal delivery.

---

## 4. Suggested Implementation Direction

(For engineering to confirm)

- Separate the email delivery step from each allocation batch, so that delivery is driven by a step that **collects whatever CSVs are present** for the target month, rather than by any single project's batch.
- Keep this in mind when finalizing the ASCH design, so that CAP and CIP can be added later without reworking ASCH's delivery path.
- Do not modify the existing ASC batch. The existing ASC principle — the existing recognition pipeline is not changed — still applies. The unified delivery is an additional downstream step.

---

## 5. Email Body Content

To keep a single email with many attachments usable, the body should include a per-project summary table:

| Project | Run status | Records | Total adjustment amount | Validation result |
|---------|-----------|---------|------------------------|-------------------|
| ASCH | succeeded | 150 | -45,000 | OK |
| CAP | failed | — | — | — |
| CIP | not executed | — | — | — |

Validation result reuses the values the batch already stores (for example ASCH's `validation_status` / `is_balanced`).

---

## 6. Phasing

| Phase | Timing | Content |
|-------|--------|---------|
| 1 | ASCH release | ASCH CSVs delivered by the ASCH email |
| 2 | CAP release | CAP CSVs added to the same email |
| 3 | CIP release | CIP CSVs added to the same email |

Between phases, the email simply carries fewer attachments. No change to Accounting's operation is required at each step.

---

## 7. Related Decisions (Out of Scope of This Page)

- The Freee sending approach for per-project allocation summaries is being decided separately (see REF-ASCH-08).
- This page assumes only that journal sending stays independent per project, as stated in constraint 4.

---

## 8. Impact on ASCH Spec

| Spec | Impact |
|------|--------|
| Spec 01 (Foundation) | Pipeline steps split: Step 11 = CSV generation (per-project), Step 12 = email delivery (unified downstream) |
| Spec 04 (Freee) | Freee sending remains independent per project — no coupling to email delivery |
| Spec 05 (CSV + Email) | Must design CSV generation as standalone callable step; email delivery as separate orchestrator that collects CSVs from all projects |

### Design Implications for ASCH (Phase 1)

- CSV generation class returns file paths, does not send email directly.
- Email delivery is a separate artisan command or service method, callable after all project batches complete.
- In Phase 1 (ASCH only), the email orchestrator only has ASCH CSVs. CAP/CIP slots are "not executed."
- The orchestrator should be designed with a project registry pattern so new projects plug in without modifying existing code.

---

*Received: 2026-08-05*  
*Filed by: Noel Palo*
