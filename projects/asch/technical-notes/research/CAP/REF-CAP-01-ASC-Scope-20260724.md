# ASC for CAP — Development Scope (from Kuroda-san, 2026-07-24)

**Source:** Confluence — "ASC for CAP - Scope for Development (as of 260724)"  
**Status:** Draft for engineering estimation  
**Purpose:** Define accounting-system development scope for CAP (automatic App attachment to Coaching)

---

## Quick Summary for Estimation

CAP is structurally similar to ASCH but significantly simpler:

| Dimension | ASCH | CAP |
|---|---|---|
| Products in bundle | 3 (Lesson + Coaching + App) | 2 (Coaching + App) |
| Patterns/scenarios | 9 complex patterns | ~10 scenarios (simpler) |
| Formula | Complex (basis = L or M depending on discount type) | Simple ratio: App/(Coaching+App) × N |
| Discount complexity | Multiple discount types affect basis | No discount-type logic — always same ratio |
| Monthly-count plans | Monthly 15 (ticket consumption) | Option B only (if combined charge exists) |
| CDB dependency | Yes (eligibility from external batch) | No (plan_id is the discriminator) |
| Eligible population | Campaign-specific, quarterly | All CAP plan purchases (permanent) |
| Tables | 9 (run_id model) | ~5 (similar pattern, fewer layers) |
| Existing code modified | 0 lines | 0 lines |
| Freee integration | T1 only, same as ASCH | T1 only, same as ASCH |

---

## Key Design Decisions Already Made (from scope doc)

1. **Separate namespace:** `cap_*` tables — do NOT reuse ASCH tables
2. **plan_id is the discriminator** — no CDB needed, no campaign logic
3. **App reference price:** ¥3,980 tax-incl (constant, not from DB)
4. **Formula:** `App = N × 3,980 / (CoachingRef + 3,980)`, `Coaching = N - App`
5. **Same operational pattern as ASCH:** preview (1st), final (3rd), revision
6. **Separate command + separate email** (implied by ASCH precedent)
7. **Run_id model** (implied — same pattern as ASCH)
8. **Zero modification to existing ASC**

---

## Estimation Comparison to ASCH

Since we just estimated ASCH at 7–8 weeks (2 devs), CAP can be estimated by comparing scope:

| ASCH Phase | ASCH Effort | CAP Equivalent | CAP Effort (estimated) | Why |
|---|---|---|---|---|
| Foundation (schema + run lifecycle) | 2 wk | Same pattern, fewer tables (~5 vs 9) | 1–1.5 wk | Reuse architectural knowledge from ASCH |
| Eligibility | 1 wk | Simple plan_id lookup (no CDB) | 0.5 wk | Trivial compared to ASCH |
| Core calculation | 1.5 wk | Simpler formula (fixed ratio, no basis logic) | 1 wk | No 9 patterns, no discount-type branching |
| Pattern extensions | 1.5 wk | Refund, plan change, contract change, cooling-off | 1–1.5 wk | Fewer scenarios but still needs coverage |
| Freee submission | 1 wk | Same T1 pattern | 0.5–1 wk | Can reference ASCH implementation |
| CSV + email | 0.5 wk | Same pattern | 0.5 wk | Copy ASCH approach |
| Testing | 1 wk | ~10 scenarios | 1 wk | |
| Buffer | 1 wk | | 1 wk | |
| **Total** | **9.5 wk (1 dev)** | | **7–8 wk (1 dev)** | ~25% smaller scope |
| **With 2 devs** | **7–8 wk** | | **5–6 wk** | |

---

## Open Question: Option A vs Option B

**Option A (base):** CAP Coaching + App are separate charges. CAP only allocates the Coaching charge. Simple.

**Option B (combined):** 8L/10L monthly-count plans create a combined Lesson+Coaching+App charge. CAP must then also handle ticket-consumption allocation — approaching ASCH-level complexity for those plan types.

| | Option A | Option B (additional) |
|---|---|---|
| Scope | Coaching allocation only | + Monthly-count lesson allocation |
| Complexity | Simple ratio | + Ticket consumption (I/J), partial months |
| Effort | Base estimate | +2–3 weeks |
| Risk | Low | Medium (new territory for CAP) |
