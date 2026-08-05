# Decision Needed: Freee Sending Approach for Per-Project Allocation Summaries

**Source:** Kuroda-san (Confluence: "Decision Needed: Freee Sending Approach for Per-Project Allocation Summaries")  
**Status:** OPEN DECISION — engineering input requested  
**Date received:** 2026-08-05  
**Scope:** Architecture decision for how ASCH/CAP/CIP send adjustment journals to Freee

---

## 1. Situation

The existing Freee integration (`SendJournalsDataLogic::sendFreeeJournals2()`) generates T1/T2/T3 journals from `log_sum_calculation`. ASCH, CAP, and CIP each write their allocation results to their own summary table (`asch_sum_calculation`, `cap_*`, `cip_*`), so none of them can feed the existing sender as-is.

ASCH leaned toward putting a summary layer in front of the existing sender. The CIP estimate recommends a dedicated command per project. The two directions have not been reconciled.

---

## 2. Options

### (a) Generalize the existing sender

Make the input source pluggable so it can accept any project's summary table at the same aggregation grain.

### (b) Dedicated thin sender per project

Each project sends its own journals, reusing only the `MstRuleForJournals` / `MstCodeChange` mapping lookup logic.

---

## 3. Questions (from Kuroda-san)

1. Which option do you recommend, and why?

2. If (a): what is the impact on the existing ASC pipeline? Our standing principle is that the existing recognition pipeline is not modified — does generalizing the sender stay within that principle, or does it break it?

3. If (b): how much duplication does this actually create across ASCH / CAP / CIP, and is the duplicated part limited to orchestration rather than the mapping/journal-construction logic?

4. Either way, does the choice affect failure isolation? We need a failure in one project's sending not to block another project's sending or CSV delivery.

5. Does the choice need to be the same for all three projects, or can ASCH keep its approach while CAP and CIP adopt a different one?

6. Is there an effort difference between the two options large enough to matter against the 2026-12-17 deadline?

---

## 4. Constraint

Whichever option is chosen, **journal sending must remain independent per project** — a failure or a revision run in one project must not block or alter another project's journal delivery. This is the same constraint as the unified CSV delivery requirement (REF-ASCH-07).

---

## 5. Context: Existing Implementation

### Current `SendJournalsDataLogic::sendFreeeJournals2()`

- Reads from `log_sum_calculation` (existing ASC summary table)
- Generates T1/T2/T3 journal entries
- Sends via Freee API
- Uses `MstRuleForJournals` for account/department mapping
- Uses `MstCodeChange` for product→Freee code translation

### ASCH Summary Table (`asch_sum_calculation`)

- Same aggregation granularity as `log_sum_calculation` (by design)
- Columns: `partner_id`, `order_no`, `department_id`, `product_type`, `contract_type`, `summary_kind`, `adjustment_amount`, `send_date`, `status`
- **T1 only** — no T2/T3 logic needed for ASCH
- `adjustment_amount` = floor(ΣP - ΣN) in integer yen

### Key Differences from Existing Sender

| Aspect | Existing ASC | ASCH |
|--------|-------------|------|
| Journal types | T1 + T2 + T3 | T1 only |
| Source table | `log_sum_calculation` | `asch_sum_calculation` |
| Amount column | Multiple (varies by T type) | `adjustment_amount` (single) |
| Product types | 1 (Lesson), 9 (Coaching) | 1, 9, 100 (App) |
| App mapping | Not needed | freee_code=236270504 via mst_code_change (confirmed REF-06 §5) |

---

## 6. Preliminary Analysis (Dev Team Input — To Be Filled)

### Option (a) — Generalize

**Pros:**
- Single code path for all projects
- Shared improvements benefit everyone
- Less total code surface

**Cons:**
- Touches existing ASC pipeline (violates standing principle?)
- Increases blast radius of bugs
- T1-only projects carry T2/T3 dead code

**Principle check:** If "generalize" means refactoring `SendJournalsDataLogic` to accept an interface/strategy, it modifies the existing sender class. If it means creating a new abstract sender that the existing one could optionally adopt later, the existing pipeline stays untouched.

### Option (b) — Dedicated Thin Sender

**Pros:**
- Perfect failure isolation (separate classes, separate commands)
- Existing ASC pipeline completely untouched
- Each project owns its sender end-to-end
- Simpler per-project: ASCH only implements T1, no T2/T3 dead paths

**Cons:**
- Mapping lookup logic (`MstRuleForJournals`, `MstCodeChange`) duplicated across projects
- Orchestration code (API call, error handling, `send_date` update) repeated

**Duplication assessment:** The mapping/lookup logic can be extracted into a shared trait or service class. The duplication would be limited to the orchestration shell (~50-100 lines per project), not the journal construction logic.

---

## 7. Recommendation (TBD)

*To be filled after dev team discussion.*

---

## 8. Related Documents

| Document | Relationship |
|----------|-------------|
| REF-ASCH-07 (Unified CSV Delivery) | Same failure-isolation constraint applies |
| REF-ASCH-05 §11.2 (Freee App Mapping) | Confirms App uses freee_code=236270504 |
| RESEARCH-04 (CSV-Zip-Email Integration) | Earlier research on delivery pipeline (partially superseded by REF-07) |
| RESEARCH-03 (Integration Points) | Existing `SendJournalsDataLogic` analysis |

---

*Received: 2026-08-05*  
*Filed by: Noel Palo*  
*Status: Awaiting dev team recommendation*
