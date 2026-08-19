# calc_rule_code Convention

**Decided:** 2026-08-05 (Kuroda-san, Slack)  
**Column:** `asch_monthly_prorations.calc_rule_code` VARCHAR(30) NOT NULL

---

## What It Represents

`calc_rule_code` records **which code path actually ran** to produce the row — not which pattern the enrollment belongs to.

It answers: "what calculation function generated this specific row?"

## Naming Convention: Option (b) — Prefix only pattern-specific logic

| Code | Type | Meaning |
|------|------|---------|
| `p1_fullmonth` | Pattern-specific | Full-month proration, all products aligned (Pattern 1 logic) |
| `p2_midmonth_new` | Pattern-specific | New proration for mid-month start (Pattern 2 logic) |
| `p6_ticket` | Pattern-specific | Ticket-based proration (Pattern 6, Monthly 15 plan) |
| `p7_b2e_refund` | Pattern-specific | B2E→B2B switch refund (Pattern 7 logic) |
| `p8_cooling_off_refund` | Pattern-specific | Cooling-off refund (Pattern 8 logic) |
| `carryover` | Shared | O inherited from previous month, P = O × days/total_days |

*More codes will be added as patterns 3, 4, 5, 9 are implemented.*

## Rules

1. **Prefix (`pX_`) = pattern-specific logic actually ran.** The function that produced this row is unique to that pattern.
2. **No prefix = shared code path.** The same function runs regardless of which pattern the enrollment belongs to.
3. **Carryover traceability:** To find the original pattern for a carryover row, follow `inherited_from_proration_id` back to the source row — its `calc_rule_code` will be the pattern-specific code.

## Why Not Option (a) or (c)?

- **(a) rejected** — `px_carryover` implies there's a distinct carryover implementation per pattern. There isn't — all patterns share the same carryover function.
- **(c) rejected** — Removing pattern prefixes entirely loses traceability from the code to the test scenarios. The `pX_` prefix makes it immediately clear which Excel walkthrough validates this row.

## Relationship to Other Columns

| Column | What it tracks |
|--------|---------------|
| `calc_rule_code` | Which code path ran (the "why this row exists" logic tag) |
| `is_inherited` | Boolean: was O carried forward? |
| `inherited_from_proration_id` | FK to self: which row the O came from |
| `record_kind` | Row classification: 0=proration, 1=standalone, 2=refund |

These are complementary. A row can be `record_kind=0` (proration) + `calc_rule_code=carryover` + `is_inherited=true`.

## Future Codes (to be defined in Spec 03)

Patterns 3, 4, 5, 9 need their own codes. Expected additions:
- `p3_pre_campaign_start` — Lesson started before campaign period
- `p4_plan_change` — New group after plan change (Daily1→Daily2)
- `p5_rest_termination` — Final row before coaching rest terminates bundle
- `p9_b2e_loyal` — B2E with Loyal discount overlap

These are tentative — final naming will be decided during Spec 03 implementation.

---

*Source: Kuroda-san, Slack 2026-08-05*  
*Thread: https://bizmatesinc.slack.com/archives/C0BF8ABV74N/p1785925733060839?thread_ts=1785739773.077669&cid=C0BF8ABV74N*
