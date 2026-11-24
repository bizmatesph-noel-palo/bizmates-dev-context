# ASCI JIRA Layout — Spec 01 (CIP Integration) — DRAFT

> Draft only. Mirrors the ASCA epic + 6-story structure. Create in JIRA on the Lead's go, AFTER final ASCI-01 G1 sign-off (Kuroda-san). Project key: **ASCI**.
>
> **Status (2026-10-27):** CIP-refund-home decision ✅ **resolved — inside ASCI-01** (Kuroda-san G1 feedback, REF-CIP-09). G1 is **approved-with-changes**; the revised `requirements.md` (B-1 + W-1..W-5 folded in) has NOT yet gone back to Kuroda-san for the final tick. **So gate (1) below is not yet cleared — keep as draft.** The per-ticket content below is fleshed out and ready to paste on the Lead's go.

## Structure (same pattern as ASCA Spec 01 / 02)

One epic + the standard 6-story set. Spec stories prefixed `[Spec 01] —` so the spec is identifiable from the title (ASCA convention).

| Key | Type | Parent | Summary | Owner | Gate |
|---|---|---|---|---|---|
| [ASCI-8](https://bizmates.atlassian.net/browse/ASCI-8) | Epic | — | [Spec 01] — CIP Integration | — | — |
| [ASCI-9](https://bizmates.atlassian.net/browse/ASCI-9) | Story | ASCI-8 | [Spec 01] — Requirements + Sign-off | PM (Kuroda-san) | G1 ✅ approved |
| [ASCI-10](https://bizmates.atlassian.net/browse/ASCI-10) | Story | ASCI-8 | [Spec 01] — Architecture (Design + Tasks) | Lead / Sub-Lead (Orlino) | G2 |
| [ASCI-11](https://bizmates.atlassian.net/browse/ASCI-11) | Story | ASCI-8 | [Spec 01] — Coding | Dev (Cristoff) | — |
| [ASCI-12](https://bizmates.atlassian.net/browse/ASCI-12) | Story | ASCI-8 | [Spec 01] — Code Review | Lead | G3 |
| [ASCI-13](https://bizmates.atlassian.net/browse/ASCI-13) | Story | ASCI-8 | [Spec 01] — Dev/Manual Testing | Lead / Sub-Lead | — |
| [ASCI-14](https://bizmates.atlassian.net/browse/ASCI-14) | Story | ASCI-8 | [Spec 01] — QA Testing | QA | — |

> **Created in JIRA 2026-10-27** (all unassigned). Epic ASCI-8 + 6 stories ASCI-9..14.

## Scaffolding (non-spec, optional — mirror ASCA-9)

If ASCI needs its own scaffolding epic (steering alignment, DEV04 CIP data prep), add:

| Proposed key | Type | Summary | Notes |
|---|---|---|---|
| ASCI-E0 | Epic | ASCI — Project Scaffolding | Holds steering/context alignment + DEV04 CIP test-data prep. May be unnecessary if ASCA-9's DEV04 env is reused directly. |

Decide at creation whether ASCI reuses ASCA-9's scaffolding or gets its own.

## Likely implementation sub-tasks (under Coding, ASCI-S3) — for reference

From the ASCI-01 requirements (not JIRA tickets yet; the Coding story breaks down at task-execution time):
- ls-db: new `mst_new_price_listing` `price_flag = 3` record for Coaching Intensive 10025 (seeder, `database/seeders/Bizmates/`). → accounting-vs-ls-db placement to confirm (ReferencePriceSeeder precedent is accounting repo).
- accounting: CIP refund split (Coaching Intensive negative → App fixed ratio; shareholder Coaching-only; lesson untouched) — placement depends on the CIP-refund-home decision.
- Verification harness for normal CIP pro-ration on DEV04.

## Dependencies / sequencing

- Create epic + stories only AFTER G1 sign-off (same discipline as ASCA sub-specs).
- The CIP-refund-home decision (extend 02b / new sub-spec / inside ASCI-01) must be settled at G1 — it determines whether S3 Coding touches ASCA 02b or stays ASCI-only.
- ASCA foundation + DEV04 env is a prerequisite.

## Notes

- Do NOT create these in JIRA until: (1) ASCI-01 requirements signed off by Kuroda-san [**pending final tick — see Status**], and (2) the CIP-refund-home decision is made [**✅ done — inside ASCI-01**].
- Keep the `[Spec 01] —` title prefix so the spec is identifiable (ASCA precedent).

---

## Fleshed-out ticket content (paste-ready — create on the Lead's go)

> Keys below use the `ASCI-XX#` placeholders from the table above. On creation, JIRA assigns real keys; then replace the placeholders here with the real ones and set each story's `Parent` to the real epic key.

### ASCI-XX0 — Epic — [Spec 01] — CIP Integration

**Summary:** CIP (Coaching Intensive Plan, plan_id 1028–1032) revenue recognition. CIP uses **no allocation engine** (REF-CIP-05): the batch applies a CIP-specific site→booking conversion, then the existing daily pro-ration; refunds are split Coaching/App by the month's booked-amount ratio. Bizmates-only. Depends on the ASCA foundation + DEV04 env.
**Spec of record:** `projects/asci/specs/asci-spec-01-cip-integration/requirements.md` (5 requirements).
**Sources:** REF-CIP-04/05/06/07/08/09.

### ASCI-XX1 — Story — [Spec 01] — Requirements + Sign-off (G1)

**Owner:** PM (Kuroda-san). **Gate:** G1.
**Done:** `requirements.md` approved by Kuroda-san. Covers Req 1 (CIP-179 price record), Req 2 (site→booking conversion, B-1), Req 3 (normal pro-ration, no engine), Req 4 (refund split), Req 5 (DEV04 verification).
**Status:** approved-with-changes; final tick pending (revised draft to be sent back to Kuroda-san). Refund-home confirmed inside ASCI-01.

### ASCI-XX2 — Story — [Spec 01] — Architecture (Design + Tasks) (G2)

**Owner:** Lead / Sub-Lead (Orlino). **Gate:** G2.
**Done:** `design.md` + `tasks.md` generated via the spec UI from the signed-off requirements, reviewed.
**Design decisions to resolve here (flagged in requirements):**
- price_flag=3 seeder **placement** is moot for creation (CIP-179 already made it) — but confirm the verification approach (how ASCI asserts the record is present on the target env).
- CIP-refund resolver: net-new CIP-scoped code reusing 02b's `log_refund_history` linkage pattern (the ASCA `RefundLinkageResolver` excludes CIP by design — verified in code).
- Reuse the existing `CoachingIntensivePlanEnum` (1028–1032) — already in the accounting repo; do not duplicate.

### ASCI-XX3 — Story — [Spec 01] — Coding

**Owner:** Dev (Cristoff). **Likely sub-tasks (break down at task time):**
- Verify/confirm the CIP-179 `mst_new_price_listing` `price_flag=3` (10025) record on the target env (no ASCI seeder — CIP-179 owns it).
- **Site→booking conversion** (Req 2): Coaching = site − App, App = `FLOOR(site × 3,980 / 75,900)`, before day-proration; campaign-agnostic.
- **CIP refund split** (Req 4): Coaching Intensive negative → App by the month's booked-amount ratio (via `log_refund_history`); shareholder = Coaching-only, CSV amount as-is (no in-batch cap); lesson untouched; explicit type list incl. full refund.

### ASCI-XX4 — Story — [Spec 01] — Code Review (G3)

**Owner:** Lead. **Gate:** G3. PR review against requirements + correctness properties (conversion balance, campaign-agnostic, refund split balance, booked-amount basis, no-engine invariant, lesson isolation).

### ASCI-XX5 — Story — [Spec 01] — Dev/Manual Testing

**Owner:** Lead / Sub-Lead. DEV04 verification per Req 5: standard + first-month + 6th-month (Honki) conversion cases; refund worked examples (standard + half-price); follows the ASCA DB-safety rule (ASCA-70 follow-on).

### ASCI-XX6 — Story — [Spec 01] — QA Testing

**Owner:** QA (Glenn). Manual verification against the Req 4/5 worked examples; CIP amounts in the existing DailyRateCalculation CSV (no AllocationDetail CSV).
