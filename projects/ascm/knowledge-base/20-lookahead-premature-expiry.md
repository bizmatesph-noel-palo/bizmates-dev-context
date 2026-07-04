# 20 — Lookahead Premature Expiry (2-Day Window Fires Too Early)

> **TL;DR:** The Grouped CTE's lookahead condition expires charges in the current month when `end_date` falls within 2 days past month-end. This causes double revenue recognition for ALL contract types (B2B, B2C, B2B2C) when no successor exists. The scenario the lookahead was designed to guard against has never existed in production data.

---

## Problem Pattern

A boundary lookahead designed to catch terminal charges at month-end fires for charges that still have valid time remaining. The charge appears expired in the current month AND the following month — double revenue recognition.

**Affects all contract types:**

| Contract Type | Double-count confirmed? | Evidence |
|---|:---:|---|
| B2B (has `order_no`) | Yes | Zipan charges 12480, 12501 |
| B2C / FLP (no `order_no`) | Yes | ASC-301: charge 3001753 |
| B2B2C (no `order_no`) | Possible | Not yet observed (993 charges in Zipan) |

---

## How We Encountered It

After deploying ASC-296 (which correctly fixed April expiry for charges ending ON the last day), Wu-san reported charges where `paid_price` across April + May exceeded the charge total. Investigation revealed the lookahead condition (introduced in ASC-256) was firing in April for charges with `end_date` on May 1st or 2nd.

Student 121073 (FLP 15/month, charge 3001753):
- Contract period: 2026-04-03 ~ 2026-05-02
- Student requested REST (no successor charge)
- Expected: April remaining=15 (tickets valid until May 2nd), May expired=15
- Actual: April expired=15 (lookahead fires), May expired=15 (ticket validity check fires)

**JIRA:** ASC-301

---

## Root Cause

The lookahead in the Grouped CTE:

```sql
OR (
    om.end_date > LAST_DAY(om.month_start)
    AND om.end_date <= DATE_ADD(LAST_DAY(om.month_start), INTERVAL 2 DAY)
    AND NOT EXISTS (same-order successor)
)
```

For April (`month_start = 2026-04-01`):
- `end_date (May 2nd) > LAST_DAY(April) (April 30th)` = TRUE
- `end_date (May 2nd) <= April 30 + 2 days (May 2nd)` = TRUE
- No successor exists = TRUE
- **Fires in April** — but tickets are valid until May 2nd

The CTE also generates a next-month row (May) where expiry fires via the ticket validity check or `is_last_charge_in_order`. Both months get expiry → double revenue recognition.

---

## Origin

**Introduced in:** ASC-256 (commit `ad8e1022`, 2026-05-25) — 3 work days after Kiro adoption, 4 work days before the hard deadline.

The lookahead was added as a preventive measure for a theoretical scenario: a charge where `ticket.end_datetime` ends exactly at midnight on the 1st of the next month, meaning no next-month CTE row would be generated.

**This scenario has never existed in production data** — verified via Metabase queries against both Bizmates and Zipan. For every charge with `end_date` on day 1-2 of the next month, `max(ticket.end_datetime)` always extends past the 1st, and the CTE always generates a next-month row.

The lookahead was faulty from the start: it guards against a non-existent scenario while actively causing double revenue for real charges.

See: `Technical_Notes/Issue_Investigation/20260623_check_lookahead_condition/REPORT_00_Lookahead_Condition_Investigation.md` for full analysis.

---

## What We Did

Gate the lookahead on `om.rn = om.total_rows` — only fires on the last row for the charge. If a next-month row exists, expiry fires there via the ticket validity check instead.

```sql
OR (
    om.rn = om.total_rows  -- FIX ASC-301: Only fire on the last row.
    AND om.end_date > LAST_DAY(om.month_start)
    AND om.end_date <= DATE_ADD(LAST_DAY(om.month_start), INTERVAL 2 DAY)
    AND NOT EXISTS (same-order successor)
)
```

**Business rule confirmed by Kuroda-san:** Expiry should always appear in the month where `end_date` falls. This was the original intent from the ASC-157 spec.

**Status:** Fix merged to ASC-master, deployed to DEV04. QA passed. Awaiting Kuroda-san's decision on final approach:

- **Option A (current fix):** Keep lookahead with `rn = total_rows` gate — conservative, preserves theoretical safety net
- **Option B (cleaner):** Remove the lookahead condition entirely — simpler code, the scenario it guards against does not exist in production

---

## Why the Gate Is Safe

- If the charge only has ONE row (no next-month expansion), `rn = total_rows` = TRUE → lookahead still fires as before
- If the charge has multiple rows, the last row handles expiry via the first path (ticket validity: `max_ticket_end_datetime < LAST_DAY(month_start) + INTERVAL 2 DAY`)
- The lookahead is redundant when a next-month row exists — gating it prevents premature firing without losing coverage

---

## Why It Was Never Caught

- The lookahead was added in ASC-256 and **never intentionally tested** by any test case
- TC013 (ASC-157, B2B REST) accidentally triggers the lookahead due to an ASC-247 date rewrite — but `is_last_charge_in_order` also fires, masking the double-count from a single-month perspective
- TC035 (ASC-301) was the first test case to combine: FLP + no successor + day 1-2 end_date + no `order_no` — making the double-fire visible
- The Zipan B2B double-count (charges 12480, 12501) was only discovered when specifically queried during the ASC-301 investigation

---

## Prevention Checklist

- [ ] When adding lookahead/early-fire logic, verify it doesn't fire for charges that still have valid rows in subsequent months
- [ ] Lookahead conditions should be gated on "this is the last row" (`rn = total_rows`) to avoid premature firing
- [ ] Test with charges whose `end_date` falls on day 1-2 of the next month — both with and without successors
- [ ] Verify the fix produces correct output for BOTH the current month (remaining) and the next month (expired)
- [ ] Before adding a preventive condition for a theoretical edge case, verify the scenario actually exists in production data
- [ ] When a condition fires alongside another trigger for the same result, validate that both months don't independently produce revenue (cross-month check)

---

## See Also

- **Topic 06** (Complex CTE Boundary Logic) — the broader pattern of CTE boundary bugs
- **Topic 19** (INTERVAL Offset vs DATETIME) — related boundary issue with `INTERVAL 2 DAY` in FinalResult
- **Full investigation:** `Technical_Notes/Issue_Investigation/20260623_check_lookahead_condition/REPORT_00_Lookahead_Condition_Investigation.md`
