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

> **Priority (as of 2026-10-29, Lead on leave Nov 11–23 ≈ 2 weeks out):** (1) **G2 sign-off on ASCI-9 / ASCI-10** — the single blocker on the whole ASCI build chain; do first. (2) **Start ASCI-11 Coding (Cristoff)** right after sign-off — ASCI is the critical path (ASCA is done); aim to finish Coding + G3 **before Nov 11** (Lead owns G3). (3) **Confirm Throy-san's ASCI leave coverage this week.** (4) Assign ASCA-82/83 (parallel, pre-leave). (5) NEW ASCH (2027) — defer past the leave unless a quick first pass fits before Nov 11.

### ASCA (ASC for CAP) — essentially complete
- [ ] Assign **ASCA-82** (accounting DB-safety guard, High) + **ASCA-83** (ls-db, Medium) to a dev → implement → PR → Lead review (G3) → merge.
  - Both created 2026-10-27, unassigned; follow-on from ASCA-70. Handover prompts ready.

### ASCI (ASC for CIP) — G2 artifacts in review (PRs raised)
- [x] **Promote** `requirements.md` → `accounting_related_system_for_freee/.kiro/specs/asci-spec-01-cip-integration/` (+ valid `.config.kiro`), reformatted to the Kiro spec-format validator. **PR raised for ASCI-9** (Requirements). *(done 2026-10-28)*
- [x] **G2 — Architecture** (ASCI-10): `design.md` + `tasks.md` generated (grounded in live code; both validate clean). **PR raised for ASCI-10** (Design + Tasks). *(done 2026-10-28)*
- [ ] **G2 review + sign-off** (Lead + Dev Cristoff): approve ASCI-9 + ASCI-10 PRs → unblocks Coding. *(awaiting review)*
- [ ] **Coding** (ASCI-11) — Dev (Cristoff), branch `feature/ASCI/ASCI-11-...` → PR to `feature/ASCA/ASCA-master`. *(blocked on G2 sign-off)* Day-to-day tasks (from `.kiro/specs/asci-spec-01-cip-integration/tasks.md`; all under `App\Libs\RevenueAllocation\Cip`):
  - [ ] **T1** — value objects (`CipChargePair`, `CipOriginalBundleData`). *(root — unblocks the rest)*
  - [ ] **T2** — `CipBundlePairing` (reuse CAP pairing rule) + **T2.1** unit tests.
  - [ ] **T3** — `CipSkipLog` (structured batch log line; no run table — design-phase note 4).
  - [ ] **T4** — `CipChargeConverter` (site→booking conversion, Req 2) + **T4.1** unit/property tests. *(needs T2+T3)*
  - [ ] **T5** — `CipRefundClassifier` (shareholder via `trn_receipt_locked_charge` / contract-overlap / non-shareholder) + **T5.1** tests. *(pre-grounded)*
  - [ ] **T6** — `CipRefundLinkageResolver` (basis via `log_refund_history`, recomputed not hard-coded) + **T6.1** tests. *(pre-grounded)*
  - [ ] **T7** — `CipRefundAppRowWriter` (insert execution-month negative App row; idempotent).
  - [ ] **T8** — `CipRefundAllocator` (refund split, cumulative cap, missing-link handling, Req 4) + **T8.1** property/example tests incl. non-divisible ¥50,000. *(needs T3,T5,T6,T7)*
  - [ ] **T9** — wire both transforms into `CommonUtil::createDailyRateCalculation()` (conversion before write-N loop; refund allocator after the ASCA injector; try/catch guards) + **T9.1** integration tests. *(needs T4+T8)*
  - [ ] **T10** — DEV04 verification (standard + first/6th-month conversion; refund standard + half-price; no-regression). *(= feeds ASCI-13 Dev Testing)*
- [ ] **Code Review / G3** (ASCI-12).
- [ ] **Dev/Manual Testing** (ASCI-13) on DEV04: standard + first/6th-month conversion; refund worked examples (standard + half-price).
- [ ] **QA Testing** (ASCI-14).
- [ ] Human check: confirm **CIP-179** released to the target env (DB query).
- [ ] Human check: Accounting (**Wada-san**) blesses the −181 half-price tax-exemption figure.
- [x] Design-phase notes (REF-CIP-09 Comment 4 + 5) **resolved in `design.md`**: missing-`log_refund_history`-link handling (→ CipRefundAllocator: no split, record + warn); cumulative App-refund cap ≤ original App booking (→ clamp, remainder to Coaching); non-divisible ¥50,000 test (→ Task 8.1); where CIP records conversion skip reasons (→ `CipSkipLog` batch log line, no run table — keeps the no-engine invariant).
### Cross-cutting
- [ ] **NEW ASCH (2027)** — Lead to review the new requirements vs. the cancelled 2026 ASCH, then give feedback. *(not started)* ⚠️ a **NEW** project, not the 2026 cancelled predecessor — name reused only. **Depends on CDB** (see below). Scope unfolds once the new requirements are ingested.
  - [x] **Ingest the new ASCH (2027) requirements** — ✅ captured 2026-10-29 as `projects/asch/technical-notes/research/ASCH-2027/REF-ASCH2027-01-Requirements-20261023.md` (Kuroda-san Confluence [DRAFT], last updated 2026-10-23), with overlap analysis vs the cancelled 2026 ASCH.
  - **CDB dependency reframed by the 2027 requirements:** the 2027 ASCH confirms **ASC does NOT read CDB** (REF-ASCH2027-01 §2/§3) — the discount arrives already baked into `paid_price`. So the "ASCH reads `trn_campaign_discount_eligibility`" contract (inherited from the *cancelled* ASCH, REF-CDB-02 Gap #5) is **superseded**; the ASC-side honki-identification burden is gone. The real 2027 CDB risk is **charge-correctness**:
    - [ ] **CDB catalog for 2027 (upstream, Soli-san — the real recheck):** CDB currently expects App **10021**; it must issue against **10022** (CAP/CIP actual), add CIP Coaching Intensive **10025**, and read the half-price `price_flag = 4` tier for CAP/CIP (REF-ASCH2027-01 Open Item 3). If CDB issues charges on the wrong App product, ASC books wrong numbers at the source. Confirm with Soli-san **before the 2027-01-04 application window.**
    - _Superseded (informational):_ the cancelled ASCH's `trn_campaign_discount_eligibility` schema-read contract (6 columns, `discount_flag` 1/2, per-product eligibility date — REF-CDB-02 Gap #5/#6) no longer applies to the 2027 ASC side, since 2027 ASC doesn't read CDB. Note the 2027 doc names the column `discount_grant_status` (-1/0/1/2) vs the old `discount_flag` (1/2) — informational only, not blocking.
  - [x] **Overlap analysis done** (REF-ASCH2027-01 Cross-Reference): the 2027 ASCH is a **near-no-op, architecturally unrelated to the cancelled 2026 ASCH** — no `asch_*` tables, no pooled proration, no adjustment-journal engine, no ASC-side Honki identification. It rides CAP (ASCA, done) + CIP (ASCI, in build) on the discounted paid amount.
  - [x] **Key finding:** the 2027 ASCH's only CIP asks (Open Items 1+2: the B-1 conversion for discounted months + the booked-amount refund basis) are **already in ASCI Spec 01** (Req 2 + Req 4, G1-approved 2026-10-28, design + tasks done). Not new ASCH work.
  - [ ] **Genuinely-new 2027 ASCH work (small, test-and-verify — NOT a build):** (a) CAP half-price-month verification (ASCA formula on discounted N; 57,200→28,600); (b) the 8 §7 test patterns, esp. the campaign-transition ones ASCI doesn't cover (pattern 5 Lesson plan change, pattern 6 CIP⇔CAP move, pattern 7 joins-coaching-later); (c) reconcile the §4.1 "Lesson booked alone" rule.
  - [ ] **Feedback to Kuroda-san** (the deliverable): agree with the framing; close Open Items 1+2 as already-done in ASCI; propose scoping 2027 ASCH as test-and-verify (no new build — likely no spec or a thin one; confirm whether it needs its own JIRA project or folds into ASCI QA); flag CDB Open Item 3 (App 10021→10022) as the real upstream risk; reconcile the shareholder-App-share open item (Open Item 4) between this doc and ASCI Req 4.4.
  - _Source:_ `projects/asch/technical-notes/research/ASCH-2027/REF-ASCH2027-01-Requirements-20261023.md`. _Placement open item:_ consider a fresh `projects/asch-2027/` if this becomes a tracked project.
- [ ] **(DEFERRED — decide later) Fix the ASCH doc location + structure.** `REF-ASCH2027-01` currently sits under `projects/asch/technical-notes/research/ASCH-2027/` — i.e. inside the **cancelled 2026** ASCH project tree, which is misleading. **Not** simply a new `projects/asch-2027/` (that would wrongly imply the 2026 ASCH shipped). Preferred approach (Lead, 2026-10-29): **archive the obsolete 2026 ASCH docs** (the pooled-proration engine design, 9-table schema, adjustment-journal/CSV material — all superseded) and **retain only what the 2027 ASCH still needs**, then settle the 2027 project's home/structure. Until then the current path stands. When moved, update references in: this tracker (`_Source:_` line), the REF doc's placement note, and any master-timeline mention.
- [ ] **Leave coverage (Nov 11–23):** formally confirm Throy-san oversees ASCI before the Lead's leave.
- [~] Commit the dev-context edits — **important docs committed** (2026-10-29). **Still pending/local-only:** `.ai/mcp/mcp.json` (local MCP config — Lead to handle later; ⚠️ note it is NOT covered by the `.gitignore` rule `.kiro/settings/*.json`, so it's a different path and will keep surfacing unless unstaged or ignored). Today's session also adds: `docs/asc-projects-task-tracker.md`, the ASCH-2027 REF doc, and the toolkit/accounting-repo spec changes (separate repos — commit per repo).

---

## Daily log (append-only)

### 2026-10-29
- **Status review (Lead).** Yesterday's G2 artifacts (ASCI-9 Requirements PR + ASCI-10 Design/Tasks PR) stand; **ASCI is now blocked on G2 review + sign-off** (Lead + Cristoff) — the one gate holding the entire ASCI build chain. No new code written today.
- **Expanded the ASCI-11 Coding item into its 10 day-to-day tasks (T1–T10)** in the Remaining checklist, mirroring `tasks.md`, so daily status is trackable here without opening the spec. Tasks stay unchecked — Coding is gated on G2 sign-off.
- **Docs sync check:** `asc-projects-task-tracker.md` + `asc-projects-master-timeline.md` + `projects/asca/documentation/asca-development-workflow.md` all confirmed aligned on the ASCI G2-in-review state. Added the priority banner above (leave-window-driven).
- **Leave-window flag:** Lead on leave **Nov 11–23** (~2 weeks out). Priority is to clear ASCI G2 sign-off today and get Coding (ASCI-11) + G3 substantially done before Nov 11, since the Lead owns G3 review. Throy-san's ASCI coverage still needs formal confirmation this week.
- **ASCH doc location flagged for restructure (deferred).** Noted that `REF-ASCH2027-01` is parked in the *cancelled* 2026 ASCH tree; a plain `projects/asch-2027/` is rejected (implies the old ASCH was done). Agreed approach: archive obsolete 2026 ASCH docs, retain only what 2027 needs, then settle structure — **decided later.** Recorded as a deferred cross-cutting to-do.
- **NEW ASCH (2027) requirements INGESTED + overlap analysis done.** Captured Kuroda-san's Confluence [DRAFT] (updated 2026-10-23) verbatim as `REF-ASCH2027-01`. **Headline: the 2027 ASCH is a near-no-op, architecturally unrelated to the cancelled 2026 ASCH** — no `asch_*` tables, no pooled proration, no adjustment engine, no ASC-side Honki lookup. It rides CAP (ASCA, done) + CIP (ASCI, in build) on the discounted paid amount. **Its only CIP asks (Open Items 1+2) are ALREADY in ASCI Spec 01 (Req 2 conversion + Req 4 refund basis, G1-approved).** Genuinely-new work is small test-and-verify (CAP half-month test + the 8 §7 patterns). **CDB reframed:** 2027 ASC does NOT read CDB; the real CDB risk is charge-correctness (CDB catalog still expects App 10021, must be 10022 — Soli-san, before 2027-01-04). Next: feedback to Kuroda-san.
- **NEW ASCH (2027) ↔ CDB dependency captured.** Expanded the cross-cutting item: the new ASCH identifies honki-set students by reading CDB's (Campaign Discount Batch, Paolo's team) `trn_campaign_discount_eligibility` (`discount_flag=2` = Honki 50% granted), per the cancelled ASCH's own CDB cross-check (REF-CDB-02 Gap #5/#6/#7). Added a **CDB-drift recheck** checklist (6 columns, flag semantics, per-product eligibility date, no table/flag moved) + an HCR honki-set cross-check, to run **before/as input to** the NEW ASCH requirements review. Detail is provisional until the new requirements are ingested.

### 2026-10-28 (later — G2 artifacts)
- **ASCI-01 promoted to the code repo.** `requirements.md` copied into `accounting_related_system_for_freee/.kiro/specs/asci-spec-01-cip-integration/` with a valid `.config.kiro` (fresh `specId`, `requirements-first` / `feature`). Reformatted to the Kiro spec-format validator (H1 `# Requirements Document`, top-level `## Requirements` + `## Glossary`) — the dev-context/PM draft format was rejected by the spec UI linter; captured as a reusable fix (toolkit `templates/spec/requirements.md` + a workflow-doc promotion checklist + KB lesson `projects/asci/knowledge-base/01-...`).
- **G2 generated (ASCI-10).** `design.md` + `tasks.md` authored, grounded against live code (`CommonUtil::createDailyRateCalculation`, the negative-charge recognition branch, ASCA 02b's `RefundLinkageResolver`/`RefundAppRowWriter`, `CoachingIntensivePlanEnum`). Both pass `validate_spec_format`. Design keeps the **no-engine invariant** (CIP writes no `log_alloc_*`, reads no `mst_alloc_*`); two CIP-specific arithmetic transforms (site→booking conversion + refund split) wired into `CommonUtil` at two points; all 4 design-phase notes resolved. 10-task plan with 10 correctness properties.
- **PRs raised:** **ASCI-9** (Requirements — the G1-approved `requirements.md` committed **verbatim** under its own story for time-logging/traceability; promotion, not regeneration — same discipline as ASCA 02a) and **ASCI-10** (Design + Tasks). Branch `feature/ASCI/ASCI-master` base. **Awaiting G2 review** (Lead + Cristoff) before Coding (ASCI-11).
- **Grounded Tasks 5–6:** confirmed `trn_receipt_locked_charge` = single `charge_id` col (only writer = bizmates.jp shareholder-refund CSV import — validates the REF-CIP-07 dependency risk); `log_refund_history` = `id, refunded_charge_id, refund_charge_id, created_at`, direction `refund_charge_id → refunded_charge_id` (matches ASCA 02b). No task-description changes needed.
- **Workflow doc aligned:** corrected the stale ASCI entry in `projects/asca/documentation/asca-development-workflow.md` (repo `accounting_related_system_for_freee` not "ls-db seeder"; scope = conversion + refund split; epic ASCI-8 CREATED).

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
