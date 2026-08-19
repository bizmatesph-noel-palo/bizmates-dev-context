# CAP/CIP Absorption Feasibility — Response to Soli-san's Proposal (20260731)

**Reported by:** Noel  
**JIRA Ticket:** TBA  
**Investigated by:** Noel (AI-assisted code trace + document analysis)  
**Date:** 2026-07-31  
**Context:** Kuroda-san requested urgent verification of Soli-san's proposal to absorb ASC-CIP into ASC-CAP with a smaller team.

---

## The Proposal

Soli-san proposes: if both assumptions below are true, ASC-CIP can be absorbed into ASC-CAP with a reduced team (Lead + max 2 devs + QA 2–3, instead of Lead + 4 devs).

**Assumption 1:** CIP's distribution/plan-granting logic is covered by CAP's implementation (no separate logic needed for CIP).

**Assumption 2:** CIP reuses `product_type = 9`, same as existing 15-min/30-min Bizmates Coaching.

---

## Verification

### Assumption 1: Is CIP's Distribution Logic Covered by CAP?

**Partially true, but misleading in context.**

What's true:
- Both CAP and CIP follow the SAME accounting formula: `P_app = N × (App_ref / (Coaching_ref + App_ref))`
- Both read N from the same ASC source (`log_daily_rate_calculation`)
- Both produce the same type of output (adjustment journals, detail CSV, summary CSV)
- Both use the same Freee mapping for App (freee_code=236270504)
- The structural scaffolding (run management, CSV generation, Freee sender, email) is identical

What's NOT true:
- **Eligibility detection differs:** CAP uses a new dedicated App product_id (decided 2026-07-28). CIP uses plan_id as discriminator (REF-CIP-00 §6.1). These are different queries.
- **Reference prices differ:** CAP App_ref = ¥3,980. CIP App_ref = TBD. CIP Coaching_ref = likely derived from ¥80,000/month. These are different constants.
- **Target audience differs:** CAP = B2C + B2E (B2B staged). CIP = B2C + B2E + B2B from day 1. Taiwan excluded for CIP.
- **Tables must be separate:** Kuroda-san explicitly decided `cap_*` vs `cip_*` namespaces (RA-09 in REF-CIP-00 §3). This is NOT an engineering preference — it's a confirmed business decision based on auditing requirements.
- **Acceptance scenarios differ:** CIP has post-release correction handling, simultaneous start/stop of Coaching+App (RA-06), and different contract-type coverage.

**Verdict on Assumption 1:** The *accounting logic pattern* is the same. The *implementation* still requires separate: eligibility queries, configuration, tables, test scenarios, and command entry points. "Covered by CAP's implementation" overstates it — "follows the same pattern as CAP" is accurate.

---

### Assumption 2: Does CIP Reuse product_type = 9?

**Yes — confirmed.**

From REF-CIP-00 §1.1: CIP is a "Coaching-only plan (30-minute, 1-month contract)." The Coaching component of CIP uses `product_type = 9` (same as existing Bizmates Coaching 15-min and 30-min).

What this means for the ASC pipeline:
- ✅ The existing daily rate calculation processes CIP Coaching charges automatically (no code change)
- ✅ The existing Freee journal mapping (product_type=9 → freee_code=191155067) works
- ✅ The existing `mst_rule_for_journals` rows for Coaching apply
- ✅ No exclusion filters block it

**Verdict on Assumption 2:** Correct. CIP Coaching charges flow through the existing ASC pipeline identically to existing Coaching products.

---

## Does This Change the ASC-CIP Estimate?

**No. Here's why.**

The current 6–7 week estimate for ASC-CIP was ALREADY based on the understanding that:
- CIP uses the same formula as CAP
- CIP reuses product_type=9 (standard Coaching)
- The existing ASC pipeline handles the charge without modification
- The new work is the allocation layer (command + tables + CSVs + Freee adjustment)

Soli-san's investigation confirms what we already knew about the standard pipeline. It doesn't eliminate the allocation layer that both projects require.

---

## Can ASC-CIP Be "Absorbed" Into ASC-CAP?

**Yes, with the correct interpretation of "absorbed."**

### What "Absorption" Actually Means Here

It does NOT mean CIP runs inside CAP's code path or shares CAP's tables. It means:

1. **Same team builds both** — Lead + 2 devs build CAP first, then CIP second (sequentially within the same engagement)
2. **CIP is faster because CAP was built first** — proven patterns, copy-paste with modifications, known unknowns
3. **Total effort is less than sum of parts** — architectural design done once, patterns proven once, Freee integration proven once

### Revised Combined Estimate

| Approach | CAP | CIP (after CAP) | Combined | Team |
|---|---|---|---|---|
| **Sequential (same team)** | 6 weeks | 3–4 weeks | **9–10 weeks** | Lead + 2 devs |
| **Parallel (separate teams)** | 6 weeks | 6–7 weeks | **6–7 weeks** (calendar) | Lead + 4 devs |

**Why CIP drops to 3–4 weeks after CAP:**
- Foundation (Week 1) becomes copy + rename: 2–3 days instead of 1.5 weeks
- Eligibility query: adapt, not design from scratch
- Core allocation: same formula, change constants
- Freee/CSV: copy pattern, change filenames and table references
- Scenarios still need full testing (can't shortcut this): 1.5 weeks
- Buffer: 0.5 weeks

### Soli-san's Proposal: Lead + 2 devs + QA 2–3

**This is viable** if:
- CAP built first (6 weeks)
- CIP follows immediately (3–4 weeks)
- Total calendar time: ~10 weeks
- QA can run in parallel with CIP development (testing CAP while CIP is built)

**Timeline check against deadlines:**
- If start August 11: CAP done by Sept 19, CIP done by Oct 17 → both ready well before Dec 17 deadline ✅
- If start September 1: CAP done by Oct 10, CIP done by Nov 7 → still comfortable ✅
- If start October 1: CAP done by Nov 11, CIP done by Dec 5 → tight but feasible ⚠️

---

## Key Clarification for Kuroda-san

> "This seems to conflict with what I confirmed above, that CAP and CIP are independent implementations."

**No conflict.** Both of these are true simultaneously:

1. CAP and CIP ARE independent implementations (separate tables, separate commands, separate acceptance scenarios, separate namespaces — as you confirmed with RA-09)

2. CAP and CIP CAN be built by the same team sequentially, where CIP benefits enormously from CAP being built first (3–4 weeks instead of 6–7 weeks)

"Independent implementation" ≠ "requires independent team." It means the code and data don't share runtime dependencies. The same developers can build both projects in sequence, applying lessons from the first to accelerate the second.

---

## Answers to Kuroda-san's Three Questions

### Q1: Is assumption 1 accurate — is CIP's distribution logic covered by CAP's?

**The accounting formula is identical. The implementation details differ (eligibility query, prices, audience, tables).** CIP doesn't literally "run CAP's code" — it follows the same pattern with different inputs. This means the same team can build both efficiently, but CIP still needs its own implementation artifacts.

### Q2: Is assumption 2 accurate — does CIP use product_type = 9?

**Yes, confirmed.** CIP is a Coaching 30-min plan. The existing ASC daily rate calculation pipeline handles it without code changes. This was already our assumption in the estimate.

### Q3: Does this change the ASC-CIP scope estimate?

**It changes the team structure, not the work volume.**

| Before (separate teams) | After (absorbed) |
|---|---|
| CAP: Lead + 2 devs, 6 weeks | CAP: Lead + 2 devs, 6 weeks |
| CIP: Lead + 2 devs, 6–7 weeks | CIP: Same team, 3–4 weeks after CAP |
| Total engineers: Lead + 4 devs | Total engineers: Lead + 2 devs |
| Calendar time: 6–7 weeks (parallel) | Calendar time: 9–10 weeks (sequential) |
| Total person-weeks: ~24 | Total person-weeks: ~18 |

The trade-off: **smaller team = longer calendar time, but less total effort** (because CIP benefits from CAP's proven patterns). Both approaches deliver before the December 17 deadline if started by October.

---

## Recommendation

**Support the reduced team approach (Lead + 2 devs) with these conditions:**

1. Start CAP by mid-September at latest (after ASCH stabilizes)
2. Build CIP immediately after CAP (same team, sequential)
3. Keep `cip_*` tables separate (RA-09 stands — this is an audit requirement, not overridable by team-size optimization)
4. QA starts testing CAP while devs build CIP (parallel QA)
5. Total delivery: both CAP and CIP ready by late November / early December

This gives a **comfortable 3-week buffer** before the December 17 deadline.

---

## Cross-References

| Document | Relevance |
|---|---|
| `REPORT-00-asc-pipeline-sufficiency-analysis.md` | Proves standard ASC handles product_type=9 without changes |
| `research/CAP/cap-asc-development-timeline-estimate.md` | CAP estimate (6–7 weeks) |
| `research/CIP/cip-asc-development-timeline-estimate.md` | CIP estimate (6–7 weeks standalone) |
| `research/CAP/REF-CAP-02-Open-Items-Update-20260728.md` | CAP eligibility = new product_id (not plan_id) |
| `research/CIP/REF-CIP-00-ASC-Scope-20260727.md` | CIP scope (RA-09: separate `cip_*` namespace) |
