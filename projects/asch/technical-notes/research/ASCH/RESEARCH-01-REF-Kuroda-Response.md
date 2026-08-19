# Kuroda-san's Response to RESEARCH_01 Open Questions

**From:** Hayato Kuroda  
**To:** Noel Palo  
**Date:** 2026-07-03 (after RESEARCH_01 was shared)  
**Context:** Response to the initial research report with answers, corrections, and action items for the dev team.

---

## Architecture Correction

> **ASCH is NOT a replacement / parallel recalculation of ASC.**

The decided approach is **additive**: existing ASC results stay exactly as they are, and ASCH books only the difference as additional Freee journals:

```
adjustment = allocated amount (P) − amount already booked by ASC (N)
```

**Background:** We want to avoid touching the existing ASC query logic to prevent unexpected regressions. ASCH should run as a command-based batch in the same way as ASC (it can run within the same batch execution), but its processing and queries must be completely separated from the ASC ones. No modification to the existing ASC queries.

**Action item for dev team:** Since N comes from `log_daily_rate_calculation` / `log_monthly_rate_calculation`, verify that Honki Set charges DO flow through the existing ASC pipelines as normal charges. This is a precondition of the adjustment approach.

---

## Answers to Open Questions

### Q1 — How to identify Honki Set charges in `trn_charge`

Agreed, this is the key remaining item. The finding matches the design assumption: since there is no campaign marker on `trn_charge`, ASCH will persist confirmed members per batch run in a snapshot table (`asch_bundle_enrollments` — Spec Section 5, table #4).

**Action item for dev team:** Can we build the identification logic on `mst_honki_set` + the `HonkiSetService` waterfall (or the HCR 5-CTE query)? What does the actual `mst_honki_set` data look like for the current campaign?

### Q2 — App product_id

App product exists as `mst_product` `product_id=10012` (`product_type=100`). It does NOT appear in `trn_charge` — the student pays ¥0, so no charge is created. ASCH synthesizes the App allocation row with N=0 (Spec Sections 3 and 5).

### Q3 — Standard (list) prices source

`mst_product` / `mst_product_price`. Known mismatch for App: `mst_product_price` has ¥2,500 while business requirement sheet says ¥3,600. Accounting is confirming which one to use (Spec Section 7, item 2).

Until confirmed, treat ¥3,600 as the proration price via `asch_app_price_master`.

### Q4 — Patterns beyond Pattern 1

The sample spreadsheet already shared with the PH team is identical to the requirement Excel v3 and contains all 9 patterns:
- Different start dates
- Start before campaign
- Plan changes
- Coaching rest
- B2E→B2B switch with refund
- Cooling-off refund
- B2E + Loyal

A summary is in Spec Section 3. Details walkthrough session to be scheduled.

### Q6 — First Month campaign vs "B2E First Month" cohort

**Clarification:** The first-month 50% discount also exists for B2E students. Excel v3 uses a B2C example, but the same case can happen with B2E, and the calculation is exactly the same.

Also note: in the existing data model, B2E is represented as B2B2C (`contract_type=2`). Exact cohort scope still being confirmed with marketing.

### Q7 — `config/code.php` entries for App

**Open** — accounting needs to decide the Freee item / account mapping for the App (Spec Section 7, item 5). `product_type=100` exists on the product side.

### Q8 — Forward-looking or historical

**Forward-looking by default.** The Jan 2026 / Apr 2026 campaign rounds were not prorated, and retroactive correction is an open item (Spec Section 7, item 10). The design can handle it later with a revision run if needed.

### Q10 — 6th-month discount mechanism

It is a **discount applied at the payment**, not a separate charge or retroactive cashback.

- If the lesson plan was changed during the 6 months, the discount applies to the plan active at the month-6 contract date.
- The 6-month count starts from the original contract date.
- The discount month can differ between Lesson and Coaching because their payment dates differ (Spec Section 2.3).
- The counting baseline is still open (Spec Section 7, item 4).

### Q11 — plan_ids [1010, 1011]

These are the coaching plans, as found. Lesson eligibility is defined by plan condition (Daily 1 / Daily 2 / Monthly 15 — Spec Section 2.1), not by `mst_honki_set.plan_ids`. To be confirmed together during DB investigation.

---

## Action Items for Dev Team (for estimate)

| # | Action | Priority |
|---|--------|----------|
| 1 | Investigate participant identification via `mst_honki_set` / `HonkiSetService` — the main design blocker | High |
| 2 | Confirm that Honki Set charges appear in the existing ASC daily/monthly results (precondition for adjustment approach) | High |
| 3 | Opinion on run management model (`run_id` generation vs existing `_pre`/final two-table pattern) — Spec Section 4 and Section 7, item 1 | Medium |
| 4 | Where new DDL should live — Kuroda-san understood raw DDL under `document/sql` in the ASC repo, but RESEARCH_01 mentions `ls-database-migrations`. Advise current practice. | Medium |

---

## Items Kuroda-san's Side is Confirming

- Campaign period discrepancy: application window 7/1–7/26 vs RESEARCH_01's "end of October" — likely application window vs benefit period, to be verified against `mst_honki_set` data
- App price (¥2,500 vs ¥3,600)
- Remaining accounting items in Spec Section 7

---

## Key Clarifications for the Team

1. **Application window ≠ benefit period.** Application window = 7/1–7/26 (when students can sign up). Benefit period = 6 months from application (how long benefits last). RESEARCH_01's "end of October" was likely referring to `mst_honki_set.end_date` which may represent the last date a student can still be receiving month-1 benefits.

2. **B2E = B2B2C in code.** Kuroda-san confirms this explicitly.

3. **First Month discount applies to B2E too.** The REF_DOC_01 (Campaigns) documentation listing it as "B2C only" is incomplete.
