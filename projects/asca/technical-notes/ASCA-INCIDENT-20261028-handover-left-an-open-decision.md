# Incident Report — Handover Left an Open Decision, Forcing the Dev to Ask for Confirmation

## Document Info

| | |
|---|---|
| **Document type** | Process Incident Report (handover-quality failure) |
| **Date** | 2026-10-28 |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Severity** | Low–Medium — no code/data impact. The dev (Throy-san) was correctly blocked and asked rather than guessing (good), but the handover should not have required the question at all. Cost: a round-trip to the Lead that a complete handover would have avoided. |
| **Status** | ✅ Resolved — decision made (tripwire (a)), recorded on ASCA-83 + its source file + handover. |
| **Caught by** | Throy-san's Kiro (surfaced the open choice) → relayed to Noel (Lead). |
| **Related ticket** | [ASCA-83](https://bizmates.atlassian.net/browse/ASCA-83) (ls-db DB-safety guard) |

---

## 1. What happened

ASCA-83 (ls-db test-DDL guard, created 2026-10-27) was handed off to Throy-san with a paste-ready dev-Kiro prompt and a source-of-record ticket. During execution, Throy-san's Kiro **stopped and asked the Lead to choose** between two guardrail approaches:

> (a) CI/grep check — scans `tests/` for new unguarded DDL. (b) Base-class assertion — fail-closed check.
> "The ticket accepts either; the handover says it's Noel's call."

That is: the handover **explicitly deferred a design decision to the dev's execution time**, so the dev could not proceed without a Lead confirmation.

## 2. Why this violates the stated handover rule

The Lead's standing instruction for handovers (given earlier this project): **once a handover is produced, the design is decided FOR the dev. The dev implements the decided approach and does NOT ask for confirmation again — unless something genuinely new surfaces that needs a new decision.** A good handover is a checklist a junior could execute without re-deciding architecture.

ASCA-83's ticket broke this: both the scope list and the handover prompt said *"either a CI/grep check OR a base-class assertion"* and *"decide which guardrail you prefer … so Cristoff doesn't deliberate — the prompt tells him to ask."* That is an **open architectural choice shipped inside a 'ready' handover** — the exact thing the rule forbids. The dev correctly refused to guess (that part is right), but the question should never have been necessary.

Contrast ASCA-82 (accounting), which was done correctly: the approach was fully decided ("THE APPROACH IS DECIDED — do not design your own; implement exactly this"), with the one trap called out. The dev there had nothing to decide.

## 3. Root cause

- **Left an either/or in the spec instead of resolving it before handover.** The ticket author (Kiro, drafting for the Lead) knew both options existed and knew the technical reason (a) was correct — ls-db's one DDL test legitimately uses a real `bizmates_mysql` scratch DB, so a sqlite-disposable base-class assertion (b) would fight it — but shipped the choice to the dev rather than making it.
- **Confused "the ticket accepts either" (a spec-flexibility note) with "the dev should pick" (a decision hand-off).** Flexibility in what's acceptable is not license to defer the decision to execution time.
- A handover that says "ask the Lead to choose X vs Y" is a **design gap wearing a handover costume**, not a complete handover.

## 4. The deeper rule (what "handover is done" must mean)

A handover is complete only when **every decision the implementer would otherwise have to make is already made** in the ticket/prompt, with the rationale, so the implementer:
1. Implements the single decided approach.
2. Does **not** ask for confirmation of anything already decided.
3. Asks **only** when they hit something genuinely new — i.e. the live code contradicts the handover, or a requirement/assumption turns out false — i.e. a **new** decision, not a pre-existing open one the author failed to close.

"Ask the Lead which of A or B" is category (a pre-existing open decision), and it must be closed **before** the handover ships.

## 5. Impact

- One avoidable Lead round-trip on ASCA-83.
- Mild erosion of the "a handover means go, not deliberate" guarantee.
- **No code/data impact**; the dev did the right thing by asking rather than guessing on an ambiguous spec.

## 6. Corrective actions

### For the AI when producing handovers
1. **Resolve every either/or BEFORE shipping the handover.** If the author knows (or can determine) the right option — as here, where the code made (a) clearly correct — decide it, state it, and give the one-line rationale. Never ship "choose A or B" to the implementer.
2. **A handover may state what is *acceptable* (spec flexibility) but must still name the *chosen* path.** "Either is valid; we are doing (a) because X" is correct. "Either is valid; you decide / ask the Lead" is not.
3. **If a decision genuinely cannot be made pre-handover** (missing input only the Lead/PM has), that is a **blocker to raise with the Lead BEFORE handover**, not a question to embed in the dev prompt.
4. **Verify the handover against the rule before marking it ready:** scan for any "ask", "decide which", "your call", "A or B" aimed at the implementer; if present, the handover is not done.
5. **Preserve the legitimate ask.** The dev SHOULD still stop and ask when the live code contradicts the handover or a new decision surfaces — that is correct behavior (ASCA-82's prompt models it). The fix is to eliminate *pre-existing* open decisions, not to discourage asking about genuinely new ones.

### Applied to this incident
- Decision made: **tripwire (a), the CI/grep check** (rationale in §2 / ASCA-83). Recorded on ASCA-83 (comment + description source file + handover). Throy-san unblocked.

### For the toolkit (recommended — NOT yet written; needs Lead go + sanitize pass)
6. Promote an anonymized rule: **"A handover ships with every decision closed; never defer an either/or to the implementer."** Candidate home: `agentic-toolkit/knowledge/` (sibling to the no-unauthorized-changes / load-the-standard lessons) + a line in the handover/spec-driven workflow. Flagged; awaiting Lead go (separate repo, outside the active workspace).

## 7. Candid note (recorded at the Lead's request)

The handover was otherwise strong (grounded, trap called out, paste-ready) but shipped with an unresolved architectural choice it had the information to close. "The ticket accepts either, so ask the Lead" is precisely the deferral the handover rule exists to prevent. The author (AI) should have made the call — the code made it obvious — and stated it, so the dev never had to ask.
