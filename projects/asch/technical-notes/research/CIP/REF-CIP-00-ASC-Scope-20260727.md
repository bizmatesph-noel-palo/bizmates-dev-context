# ASC for CIP — Development Scope (from Kuroda-san, 2026-07-27)

**Source:** Confluence — "CIP - Engineering Scope for Development Estimation (as of 260727)"  
**Status:** Draft for engineering estimation  
**Deadline:** December 2026 release (first batch run: 2027/01/01)

---

## Quick Comparison: CIP vs CAP vs ASCH

| Dimension | ASCH | CAP (Option A) | CIP |
|---|---|---|---|
| Products in bundle | 3 (Lesson + Coaching + App) | 2 (Coaching + App) | 2 (Coaching + App) |
| Lesson included? | Yes (complex) | No (base) / Yes (Option B) | **No** (confirmed — lessons are separate) |
| Formula | Complex (basis = L or M) | Simple ratio | Simple ratio (same as CAP) |
| Eligibility key | CDB campaign | plan_id | plan_id |
| Reference prices | ¥14,850/¥39,600/¥3,980 | Coaching ref + ¥3,980 | Coaching ref + App ref (TBD) |
| Target population | B2C + B2E only | B2C + B2E + B2B | **B2C + B2E + B2B** (Taiwan excluded) |
| Contract duration | 6-month campaign | Permanent | **1-month subscription** (expected 3 months) |
| Monthly-count dependency | Monthly 15 tickets | Option B only | **None** (daily-rate only) |
| Table namespace | `asch_*` | `cap_*` | `cip_*` |
| Deadline | 2026/10/01 | TBD | **December 2026** |

**Key insight:** CIP is nearly identical to CAP Option A in accounting scope. Same formula, same 2-product split, same plan_id discriminator. The only differences are:
- Different plan_ids and reference prices
- B2B is in scope from day 1 (CAP stages B2B later)
- 1-month contract (vs ongoing for CAP)
- Taiwan excluded
- Different table namespace (`cip_*` vs `cap_*`)

---

## What Makes CIP Simpler Than ASCH

- No lesson allocation (confirmed — lessons purchased separately)
- No discount-type branching (always uses list price ratio)
- No CDB dependency (plan_id is deterministic)
- No campaign lifecycle (no 6-month window, no month-6 trigger)
- No ticket consumption (daily-rate charges only — no Monthly-15)
- Coaching + App confirmed to start/suspend/end simultaneously (RA-06)
