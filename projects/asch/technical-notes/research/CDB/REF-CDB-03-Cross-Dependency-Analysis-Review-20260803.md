# CDB ↔ ASCH Cross-Dependency Analysis — Review & Cross-Check

**Source:** Roi Patrick Florentino (ASCH CO-PO), via Confluence  
**Reviewed by:** Noel Palo (ASCH Lead Developer)  
**Date:** 2026-08-03  
**Purpose:** Cross-check Patrick-san's CDB↔ASCH dependency document against ASCH project research artifacts and authoritative requirements

---

## Review Summary

Patrick's document is **well-structured and largely accurate**. The major facts — schema, architecture, dependencies, timing, discount rules — all align with our research artifacts. Below is the detailed cross-check organized by verification status.

---

## ✅ Confirmed — Fully Aligned with Research Artifacts

| Section / Claim | Verification Source |
|-----------------|---------------------|
| CDB tracks eligibility, ASCH reads it for proration | `project-context.md`, RESEARCH-03-CDB-Shared-Table-Discussion |
| Table name: `trn_campaign_discount_eligibility` | REF-CDB-01 UPDATE section (2026-07-21 confirmation) |
| Column schema (student_id, discount_campaign_id, discount_campaign_type, product_id, plan_id, initial_charge_id, discount_flag, discount_eligibility_date) | REF-CDB-01 UPDATE — exact match |
| ASCH reads CDB via table join (Option a from Gap #5) | REF-CDB-02-ASCH-Alignment-Gaps §Gap #5 |
| History table: `log_campaign_discount_eligibility` | REF-CDB-01 UPDATE (3-table confirmation) |
| Month-6 trigger = calendar-month based (not sequence) | REF-ASCH-06 §1 — corrected 2026-07-31 |
| Discount basis rules: Honki Set discount → L (list price); First Month/B2E/Loyal → M (paid amount) | REF-CDB-02 Gap #5, project-context.md §Proration Formula |
| ASCH can derive discounted_charge_id without CDB providing it | REF-CDB-02 Gap #7 |
| Fallback self-detection if CDB not ready | project-context.md Open Item #7, REF-CDB-01 §Impact on ASCH Timeline |
| Separate ASCH command + separate email (decided 2026-07-22) | project-context.md §Outputs |
| Oct 1 deadline = hard (quarterly close) | project-context.md §Schedule |
| Eligibility-loss = future-only reversion, no retroactive recalculation | REF-ASCH-06 §3 |
| Plan-change discount applies to new plan's price | REF-ASCH-06 §2 |
| Lesson target_month anchored to Coaching's timeline | REF-ASCH-06 §4 |
| ASCH snapshots CDB data into `asch_source_documents` (payload_json, deduped by hash) | REF-ASCH-05 §5.1, project-context.md §New Database Tables |
| ASCH is Bizmates-only (mysql connection) | project-context.md §Architecture |
| T1 journals only | project-context.md §Outputs |
| Tax-inclusive amounts throughout | project-context.md §Key Open Items #5 (resolved) |

---

## ⚠️ Minor Discrepancies — Correct but Needs Clarification

### 1. `log_first_month_enrollment_discount_apply` is NOT a CDB table

**Patrick's document (§4):** Describes this as "From CDB (via log_first_month_enrollment_discount_apply)"

**Actual:** This is a pre-existing Bizmates table that ASCH reads **independently** of CDB. CDB does not own, write to, or manage this table. It's part of the existing First Month campaign system (see `domain-knowledge/campaigns.md` → First Month Campaign).

**Recommendation:** Reword §4 to distinguish:
- CDB provides: `trn_campaign_discount_eligibility` (Honki Set membership + month-6 date)
- Existing tables ASCH reads directly: `log_first_month_enrollment_discount_apply` (First Month campaign), `log_loyal_benefits_charge` (Loyal discount)

### 2. `discount_campaign_type` mapping (1=Jul, 2=Oct, 3=Jan) — unverified

**Patrick's document:** States `discount_campaign_type: 1=Jul Honki, 2=Oct Honki, 3=Jan Honki`

**Our context:** REF-CDB-01 defines this column as "Campaign group" but does not specify these exact numeric mappings. The per-round identifier appears to be `discount_campaign_id` (which maps to `mst_first_month_enrollment_discount_schedule` IDs: 324=April, 334=July). The `discount_campaign_type` may be a broader category.

**Recommendation:** Verify exact `discount_campaign_type` values with CDB team (Wu-san). Consider whether it's a round identifier or a campaign-family identifier.

### 3. Third CDB table omitted

**Patrick's document:** Only discusses 2 tables in detail (trn + log)

**Actual:** CDB confirmed 3 tables: `trn_campaign_discount_eligibility`, `mst_campaign_discount_eligibility` (master/config), and `log_campaign_discount_eligibility` (history).

**Impact:** Low — ASCH doesn't read from the master table directly. But for completeness as a dependency document, mention all 3.

### 4. `discount_flag` value range

**Patrick's document:** Shows values -1/0/1/2

**Actual:** REF-CDB-01 lists -1/0/1/2/3/4 where 3=Granted as tickets, 4=Granted as gift certificate.

**Impact:** None for ASCH (only reads flag IN (1, 2)). Patrick's simplification is appropriate for the audience, but a footnote acknowledging other values exist would prevent confusion if CDB team reads this.

### 5. CDB Open Item #7 (table name) status

**Patrick's document:** Marks CDB schema as "✅ Designed"

**project-context.md Open Item #7:** Still flags table name as "⚠️ pending final confirmation" between `trn_campaign_price_eligibility` (Kuroda spec) and `trn_campaign_discount_eligibility` (CDB session)

**Resolution:** REF-CDB-01 UPDATE (2026-07-21) confirms the final name IS `trn_campaign_discount_eligibility`. Patrick is correct; our project-context.md Open Item #7 is stale and should be updated. **Action: Update project-context.md to close this item.**

---

## 🟡 Items to Verify — Not From Our Research Artifacts

These items in Patrick's document are plausible but not sourced from the ASCH Kiro context. They likely come from sync meetings or CDB-internal planning:

| Item | Notes |
|------|-------|
| CDB internal timeline (Aug 16–31 backfill, Sep 1–15 testing, Sep 15 production) | No CDB schedule exists in our artifacts. Treat as proposed until confirmed by CDB PM. |
| Wu-san as "CDB PM" | Our earlier docs (Jul 9) reference Soli-san/Ankit-san/Nasu-san. Wu-san appears later in Open Item #7 context. Role may have shifted — verify. |
| "Fallback self-detection: ~3 days dev time" | No dev estimate for fallback exists in our artifacts. REF-CDB-01 says "Timeline impact: None" because fallback was always planned. The 3-day estimate needs validation. |
| "Batch runtime < 5 minutes" performance target | No performance requirement exists in REF-ASCH-05, REF-ASCH-06, or project-context.md. This is Patrick's proposed SLA — reasonable but unconfirmed by PM. |
| "Revenue proration accuracy: ± ¥1,000 vs Excel" | The proration formula is deterministic with floor rounding and remainder-absorption. Results should match Excel exactly (to the yen), not within a tolerance. If ± ¥1,000 is meant to account for rounding strategy differences, this should be stated explicitly. |
| Tuesday/Friday sync cadence | Operational info — not in our research artifacts. Presumably from team communication. |
| "Gate dates: Aug 15, Aug 31, Sep 15, Sep 30" | These are Patrick's proposed milestone dates. Reasonable scaffolding, but not from PM-approved timeline. |

---

## 🔴 Recommended Corrections

### 1. Revenue accuracy metric

**Current:** "± ¥1,000 vs Excel"

**Should be:** "Exact match vs Excel simulation (within floor-rounding rules)" or document what the tolerance covers. ASCH's invariant is ΣO = ΣM (exact), and P values follow deterministic floor rounding. A tolerance implies acceptable error — which contradicts the validation invariants.

### 2. Section 4 framing of discount data sources

**Current:** Frames First Month and Loyal discount detection as "CDB feeds discount information → ASCH uses"

**Should be:** Separate into:
- **CDB provides:** Honki Set membership, month-6 eligibility date, active/forfeited status
- **Existing tables (not CDB):** `log_first_month_enrollment_discount_apply` (First Month campaign), `log_loyal_benefits_charge` (Loyal benefits)

This distinction matters because if CDB is delayed, ASCH's ability to detect First Month/Loyal discounts is unaffected — only Honki Set membership detection requires the fallback.

---

## Overall Assessment

| Aspect | Rating |
|--------|--------|
| Factual accuracy (schema, rules, architecture) | 9/10 — minor framing issue on data source ownership |
| Completeness of dependency mapping | 8/10 — missing mst table, unclear on existing vs CDB-owned tables |
| Timeline realism | 7/10 — dates are reasonable but largely unconfirmed proposals |
| Risk analysis quality | 9/10 — fallback strategy accurately represents our planned approach |
| Actionability for stakeholders | 9/10 — clear handoff checklist and escalation path |

**Verdict:** Suitable for publication after the corrections above. The document adds significant value as an operational coordination tool that complements our research artifacts.

---

## Actions After This Review

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | Fix §4: separate CDB-owned vs existing table attribution | Patrick | Before publish |
| 2 | Verify `discount_campaign_type` exact values with CDB team | Patrick / Wu-san | Next sync |
| 3 | Clarify revenue accuracy metric (exact vs tolerance) | Patrick / Kuroda-san | Before sign-off |
| 4 | Confirm CDB internal timeline dates with CDB PM | Patrick | Next Tuesday sync |
| 5 | Update project-context.md Open Item #7 (close as resolved) | Noel | This session |
| 6 | Add mst_campaign_discount_eligibility to table list (optional) | Patrick | Low priority |

---

## Cross-References

| Document | Location |
|----------|----------|
| Patrick's original document | Confluence (to be published) |
| CDB initial design + UPDATE | `research/CDB/REF-CDB-01-Initial-Design-Proposal.md` |
| CDB↔ASCH alignment gaps | `research/CDB/REF-CDB-02-ASCH-Alignment-Gaps-20260727.md` |
| CDB shared table discussion | `research/CDB/RESEARCH-03-CDB-Shared-Table-Discussion.md` |
| ASCH authoritative requirements | `research/ASCH/REF-ASCH-05-Requirements-Update-20260724.md` |
| ASCH latest corrections (month-6, plan-change) | `research/ASCH/REF-ASCH-06-Requirements-Update-20260731.md` |
| ASCH project context | `projects/asch/project-context.md` |
| Campaign domain knowledge | `domain-knowledge/campaigns.md` §Honki Set |
