# ASC Projects — Task Tracker (ASCA + ASCI)

## Document Info

| | |
|---|---|
| **Document type** | Project Timeline (task tracker — day-to-day actuals) |
| **Date** | 2026-10-28 (Created) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Active |
| **Audience** | Dev team (Noel, Throy, Cristoff), Glenn (QA), Patrick-san (SDM), Kuroda-san (PM) |
| **Scope** | ASCA (ASC for CAP) + ASCI (ASC for CIP) |
| **Companion** | `docs/asc-projects-master-timeline.md` (the authoritative timeline + planned baseline; this file is the running task/day-to-day view) |

> **How to use this file:** the **Remaining** checklist below is the live to-do; the **Daily log** is append-only history. When something is done, tick it in Remaining and add a dated line to the Daily log. Keep the authoritative schedule/baseline in the master timeline; keep granular day-to-day task status here.

---

## Remaining — live checklist

### ASCA (ASC for CAP) — essentially complete
- [ ] Assign **ASCA-82** (accounting DB-safety guard, High) + **ASCA-83** (ls-db, Medium) to a dev → implement → PR → Lead review (G3) → merge.
  - Both created 2026-10-27, unassigned; follow-on from ASCA-70. Handover prompts ready.

### ASCI (ASC for CIP) — G1 cleared, build ahead
- [ ] **Promote** `requirements.md` → code repos' `.kiro/specs/` (+ valid `.config.kiro`) to unlock the spec UI "Continue to Design". *(immediate next step)*
- [ ] **G2 — Architecture** (ASCI-10): generate + review `design.md` + `tasks.md`.
- [ ] **Coding** (ASCI-11): price-record verification, site→booking conversion (Req 2), CIP refund split (Req 4).
- [ ] **Code Review / G3** (ASCI-12).
- [ ] **Dev/Manual Testing** (ASCI-13) on DEV04: standard + first/6th-month conversion; refund worked examples (standard + half-price).
- [ ] **QA Testing** (ASCI-14).
- [ ] Human check: confirm **CIP-179** released to the target env (DB query).
- [ ] Human check: Accounting (**Wada-san**) blesses the −181 half-price tax-exemption figure.
- [ ] Design-phase notes to carry into G2 (REF-CIP-09 Comment 4): missing-`log_refund_history`-link handling; cumulative App-refund cap (≤ original App booking); non-divisible ¥50,000 test.

### Cross-cutting
- [ ] **NEW ASCH (2027)** requirements — Lead to review overlap vs. the cancelled 2026 ASCH, then give feedback. *(not started)*
- [ ] **Leave coverage (Nov 11–23):** formally confirm Throy-san oversees ASCI before the Lead's leave.
- [ ] Commit the uncommitted dev-context edits from the 2026-10-27/28 session.

---

## Daily log (append-only)

### 2026-10-28
- **ASCI-01 G1 APPROVED** (Kuroda-san). Round-2 reply captured (REF-CIP-09 Comment 4); additions A (Req 2 App-charge pairing, CAP G1 1-5 + skip/V-3) and B (Req 4 App-refund row via ASCA 02b Req 9) folded into `requirements.md`; wording fix (refund basis = original charge's booking amount before day-proration); flag-2 open item closed (CIP-179 removes it). 3 items deferred to design.
- **ASCI JIRA created:** Epic **ASCI-8** + stories **ASCI-9..14** (all unassigned). Layout file backfilled with real keys.
- Master timeline + ASCI project-context updated to G1-approved; this task tracker created.
- **ASCI work branch created:** `feature/ASCI/ASCI-master` in both repos (accounting + ls-db), branched from `feature/ASCA/ASCA-master`. Branch recorded across ASCI project-context (Key Info), requirements.md (Dependencies §1), and the master timeline (JIRA Projects note + snapshot). ASCA branch unchanged = `feature/ASCA/ASCA-master`.

### 2026-10-27
- **ASCI-01 round-1 G1 feedback** ingested + folded in (REF-CIP-09): new Req 2 (site→booking conversion), W-1..W-5, two 10-23 add-ons. Sent back to Kuroda-san + announced on Slack.
- **CIP-179 verified in Jira** (QA Passed 2026-10-12; tier1 65,382 / tier2 32,691; removes the 10025 flag-2 rows); flag-2 fact synced across master-timeline, plans-and-products, ASCA technical-design.
- **ASCA-70 DB-safety fix tickets created:** **ASCA-82** (accounting, High, under ASCA-17) + **ASCA-83** (ls-db, Medium, under ASCA-16), unassigned, each "relates to" ASCA-70; handover files prepared + renamed to real keys.
- Logged a process incident (wedged-terminal / tool-looping) + a Kiro bug report draft.

### Earlier (see master timeline for full history)
- 02c AllocationDetail CSV removal (ASCA-78) ✅; CEIL steering note (ASCA-79) ✅; DEV04 re-run (ASCA-80) ✅; ASCA-70 investigation + verification ✅; Spec 01 + Spec 02 (02a–02d) all merged + DEV04-verified ✅.
