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

> **Priority (as of 2026-11-04 — Lead leave Nov 11–23, ~5 working days left incl. today):** (1) **ASCI-11 G3 review** — Throy reports Coding done; merge → ASCI-master → DEV04 directed, but G3 (Lead) is still owed and must land before 11-11. (2) **Assign ASCA-86 + ASCI-17** (unassigned code fixes for the ASCA-81 defect) — each also needs Lead G3 before 11-11, so pick owners today. Cristoff is still stuck on ASCA-82, so weigh load. (3) **Close ASCA-82 / ASCA-83** — unit tests + `drop table` finding still open. (4) **ASCH 2027** — reply + docs sent; awaiting Kuroda-san. (5) **Confirm Throy-san's ASCI leave coverage** (also carrying ASCI-11).

### ASCA (ASC for CAP) — essentially complete
- [ ] **ASCA-82** (accounting DB-safety guard, High) — **PR OPEN, Cristoff-san; still open with issues to fix** (unit-test work). ⚠️ Earlier finding: Kiro-generated code contained a `drop table` — the exact hazard this guard exists to prevent; must be removed/guarded before merge → Lead G3. Follow-on from ASCA-70.
- [ ] **ASCA-83** (ls-db DB-safety guard, Medium) — **PR OPEN, Throy-san; still open**, held pending ASCA-82 (same pattern, 82 lands first). Follow-on from ASCA-70.
- [ ] **ASCA-86** (fix — ASCA-81 defect) — created, **UNASSIGNED** (not pre-assigned). Drop `end_date` match in `RefundLinkageResolver::fetchAppCompanion()` + warning log + real regression test (471 shape). Sub-task under ASCA-47. Full handover in the ticket.
- [x] **LEAD spec-doc fix (ASCA)** — ✅ DONE + committed (2026-11-03/04, Lead). Option A (refund-path carve-out only): new 02b Req 9.7 + 02b design (RefundLinkageResolver bullet + component row) + 02b tasks, plus a refund-exception note on Spec 01 Req 6.5. Positive-path Req 6.4 / Property 3 / Req 10.6 deliberately unchanged. ls-db: no change needed.
- [x] **ASCA-81 (investigation task) — DONE.** Confirmed a real Spec 02b defect: CAP refunds drop the negative App row because `RefundLinkageResolver` pairs the App companion on `end_date` (which differs for refunds); CIP repeats it in `CipBundlePairing`. **Fix tickets created:** **ASCA-86** (CAP, under ASCA-47) + **ASCI-17** (CIP, under ASCI-11), both code + tests, unassigned. **Spec docs updated to align with the change (committed):** ASCA Spec 01 (Req 6.5 refund-path exception note), ASCA Spec 02b (new Req 9.7 + design + tasks), ASCI Spec 01 (Req 2.7 + design + T2) — all pair the App companion on `start_date` only, not `end_date`. ls-db: no change. Close ASCA-81 once ASCA-86 + ASCI-17 are merged and the negative App row is verified on DEV04 (students 471, 7185).

### ASCI (ASC for CIP) — G2 CLEARED; Coding (ASCI-11) in progress (Throy-san)
- [x] **Promote** `requirements.md` → `accounting_related_system_for_freee/.kiro/specs/asci-spec-01-cip-integration/` (+ valid `.config.kiro`), reformatted to the Kiro spec-format validator. **PR raised for ASCI-9** (Requirements). *(done 2026-10-28)*
- [x] **G2 — Architecture** (ASCI-10): `design.md` + `tasks.md` generated (grounded in live code; both validate clean). **PR raised for ASCI-10** (Design + Tasks). *(done 2026-10-28)*
- [x] **G2 review + sign-off** — ✅ **ASCI-9 + ASCI-10 merged to `feature/ASCI/ASCI-master`** (per Lead, 2026-10-29/30); Throy-san picked up Coding. *(local checkout not yet fetched the merge — verify on next pull; recorded per Lead.)*
- [~] **Coding** (ASCI-11) — **Throy-san reports Coding DONE (2026-11-03 DSM).** **Lead direction: merge to `feature/ASCI/ASCI-master` → deploy DEV04** (for testing ahead of the leave). ⚠️ This precedes a formal **G3** (ASCI-12, Lead) — G3 still owed; confirm parallel/post-merge vs waived. Day-to-day tasks below reflect the plan; mark each as the PR/review confirms them (not yet individually verified). From `.kiro/specs/asci-spec-01-cip-integration/tasks.md`, all under `App\Libs\RevenueAllocation\Cip`:
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
- [~] **ASCI-15** (epic, non-spec Ops: DEV04, investigations, debugging, deployment) — created 2026-11-03. **ASCI-16** "DEV04 - 20261103 deployment" — task under ASCI-15, assigned to Throy-san, To Do.
- [ ] **ASCI-17** (fix — same defect as ASCA-81) — created, **UNASSIGNED** (not pre-assigned). Drop `end_date` match in `CipBundlePairing::findPair()`, flip the test that asserts the bug, add a half-price refund test. Sub-task under ASCI-11. Full handover in the ticket.
- [x] **LEAD spec-doc fix (ASCI)** — ✅ DONE + committed (2026-11-03/04, Lead). ASCI Req 2.7 + design Component 2 + tasks T2 now pair on `start_date` only (no `end_date`), with ASCA-81 rationale (shared `CipBundlePairing` serves both conversion and refund).
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
  - [x] **Reply to Kuroda-san's Slack (3 questions + estimate-timing)** — ✅ SENT 2026-11-03 (with the 2 Confluence docs: estimate + code-check). Awaiting his feedback (he was on JP holiday 11-03). Draft/analysis in REF-ASCH2027-01.
    - **Q1 (ASCI §4.3/§4.4 OK to include?):** ✅ Yes — already in ASCI-01, G1-approved 2026-10-28 (REF-CIP-09 Comment 4). Close-the-loop; point at `asci-spec-01-cip-integration`.
    - **Q2 (anything else in ASC beyond §6?):** No new code. 3 QA/reconcile items: CAP half-price-month test (57,200→28,600), verify §4.1 Lesson-booked-alone, no proration change. Real risk is upstream: CDB catalog App 10021→10022 (Soli-san).
    - **Q3 (rough estimate):** ~3–5 dev-days, almost all testing (CIP = 0 incremental, in ASCI; CAP test-only; the net-new is §7 patterns 5/6/7). No new build.
    - **Estimate timing (2026-10-28 follow-up):** send the rough number **now**; firm it up once ASCI-11 Coding is underway, **before the Nov 11 leave** — and only after the prioritized ASCA/I tasks, per his instruction.
    - **Board (10:53):** he used the old ASCH board, invited change → decide with the deferred `projects/` restructure. Low priority.
  - _Source:_ `projects/asch/technical-notes/research/ASCH-2027/REF-ASCH2027-01-Requirements-20261023.md`. _Placement open item:_ consider a fresh `projects/asch-2027/` if this becomes a tracked project.
- [ ] **(DEFERRED — decide later) Fix the ASCH doc location + structure.** `REF-ASCH2027-01` currently sits under `projects/asch/technical-notes/research/ASCH-2027/` — i.e. inside the **cancelled 2026** ASCH project tree, which is misleading. **Not** simply a new `projects/asch-2027/` (that would wrongly imply the 2026 ASCH shipped). Preferred approach (Lead, 2026-10-29): **archive the obsolete 2026 ASCH docs** (the pooled-proration engine design, 9-table schema, adjustment-journal/CSV material — all superseded) and **retain only what the 2027 ASCH still needs**, then settle the 2027 project's home/structure. Until then the current path stands. When moved, update references in: this tracker (`_Source:_` line), the REF doc's placement note, and any master-timeline mention.
- [ ] **Leave coverage (Nov 11–23):** formally confirm Throy-san oversees ASCI before the Lead's leave.
- [~] Commit the dev-context edits — **most staged changes committed** (Lead, 2026-10-29). **Still uncommitted (intentional, Lead to handle):** `.ai/mcp/mcp.json` (local MCP config; ⚠️ NOT matched by the `.gitignore` rule `.kiro/settings/*.json` — different path, will keep surfacing) + **3 files** + the **new ASCH-2027 timeline/estimate files**. New since: today's tracker + master-timeline edits, the ASCH-2027 estimate (grounded) + investigation report, and the toolkit/accounting-repo spec changes (separate repos — commit per repo).

---

## Daily log (append-only)

### 2026-11-04
- **Recap of 11-03:** ASCA-81 investigation closed (diagnosis valid; fix not in any branch; CIP repeats the bug). Fix tickets **ASCA-86** (under ASCA-47) + **ASCI-17** (under ASCI-11) created, unassigned, rewritten junior-friendly. Ops epic **ASCI-15** + **ASCI-16** (DEV04 deploy, Throy) created. Spec-doc corrections done + committed on both sides (ASCA: 02b Req 9.7/design/tasks + Spec 01 Req 6.5 note; ASCI: Req 2.7/design/T2). ls-db: no change. ASCH 2027 reply + docs sent to Kuroda-san.
- **Open today:** ASCI-11 G3 (Lead); assign ASCA-86 + ASCI-17; ASCA-82 (Cristoff, unit tests + `drop table`) then ASCA-83; Throy leave coverage; ASCH awaiting Kuroda-san. Leave starts 11-11 (~5 working days incl. today).
- Docs synced: tracker + master timeline to 2026-11-04 (stale items fixed: Lead spec tasks done, ASCH reply sent, ASCI-15/16 added).

### 2026-11-03
- **JP holiday (Culture Day)** — Kuroda-san/PM off; PH dev team worked. Lead leave now ~6 working days out (starts Wed 11-11).
- **ASCI-11 Coding — Throy-san reports DONE at DSM, but NO PR yet.** Next action is raising the PR → then G3 (Lead owns it, must land before the leave). Not git-verified (local checkout still on the ASCI-10 branch).
- **ASCI-11 → DEV04 (Lead direction, 2026-11-03):** Lead instructed Throy-san to **merge the ASCI-11 changes to `feature/ASCI/ASCI-master` and deploy to DEV04.** ⚠️ Note this puts ASCI-11 on DEV04 **ahead of a formal G3 code review** (Lead owns G3) — intent is to get it on DEV04 for testing before the leave; **G3 still to be done** (confirm whether in-parallel/post-merge or waived). Flagging so the gate isn't silently dropped.
- **ASCA-82 / ASCA-83 (DB-safety unit tests)** — both PRs still open, issues to fix. ASCA-82's earlier `drop table` finding still the thing to clear before merge; 83 waits on 82.
- **ASCA-81 — NEW:** reported over the weekend, investigated by Cristoff-san, who left a Jira comment (per today's DSM). What it is isn't captured here yet — Lead to read the comment and record scope/next step.
- **ASCH 2027 — Slack reply + Confluence docs SENT to Kuroda-san.** No feedback yet (he's on JP holiday). Estimate stands at ~2–2.5 wk rough, pending CDB confirmations.

### 2026-10-30
- **ASCI G2 CLEARED → Coding started.** ASCI-9 (Requirements) + ASCI-10 (Design + Tasks) **merged to `feature/ASCI/ASCI-master`** (Lead); **Throy-san picked up ASCI-11 Coding.** ASCI moves from "G2 in review" to "Coding in progress" — the critical path is now live. (Note: Coding owner is Throy-san, not Cristoff as earlier planned.) *Local checkout had not fetched the merge at time of writing — verify on next pull.*
- **ASCA-82 (DB-safety, accounting) in progress — Cristoff-san, PR OPEN.** ⚠️ **Test issues found + Kiro-generated code still contains a `drop table`** — precisely the hazard ASCA-82 was created to guard against (follow-on from ASCA-70). Must be removed/guarded before merge.
- **ASCA-83 (DB-safety, ls-db) in progress — Throy-san, PR OPEN**, held pending ASCA-82 (82 lands first, same pattern).
- **DEV04 QA report rerun (Throy-san):** regenerated reports for the batch window **2026/02/01 (January data) → 2026/12/01 (November data)** for QA testing. (Batch processes the previous month, so the data-month vs report-month wording differs as usual.)
- **ASCH 2027 estimate finalized + grounded.** Light estimate created (`asch-2027-development-estimate-20261029.md`), then a read-only investigation (REPORT-00) **verified in code** that ASCH needs **no new ASC logic** (all §7 transitions + §4.4/§4.5 resolve to "billing issues the charges, ASC books them"). Estimate updated to **Scenario A ~2–2.5 weeks** (3–5 testing-days + 1–2wk buffer) / **Scenario B ~4–5wk contingency**, with a grounding section citing the code evidence. ASCH 2027 Slack reply to Kuroda-san **drafted, under Lead review (not yet sent).**
- **Docs aligned:** tracker advanced to 2026-10-30; master timeline given a 2026-10-30 snapshot + its first ASCH-2027 entry (was absent). Priority banner refreshed.
- **Calendar flag (PH and JP holidays are independent — each team works through the other's):** **Mon 2026-11-02 = PH holiday** — PH dev team off, Kuroda-san/JP works normally. **Tue 2026-11-03 = JP holiday** (per Kuroda-san) — Kuroda-san/PM off, PH dev team works normally. They do NOT stack: the dev team loses only Mon 11-02; PM turnaround is unavailable only Tue 11-03. Both fall in the pre-leave crunch (Lead leave from Wed 11-11).

### 2026-10-29
- **Status review (Lead).** Yesterday's G2 artifacts (ASCI-9 Requirements PR + ASCI-10 Design/Tasks PR) stand; **ASCI is now blocked on G2 review + sign-off** (Lead + Cristoff) — the one gate holding the entire ASCI build chain. No new code written today.
- **Expanded the ASCI-11 Coding item into its 10 day-to-day tasks (T1–T10)** in the Remaining checklist, mirroring `tasks.md`, so daily status is trackable here without opening the spec. Tasks stay unchecked — Coding is gated on G2 sign-off.
- **Docs sync check:** `asc-projects-task-tracker.md` + `asc-projects-master-timeline.md` + `projects/asca/documentation/asca-development-workflow.md` all confirmed aligned on the ASCI G2-in-review state. Added the priority banner above (leave-window-driven).
- **Leave-window flag:** Lead on leave **Nov 11–23** (~2 weeks out). Priority is to clear ASCI G2 sign-off today and get Coding (ASCI-11) + G3 substantially done before Nov 11, since the Lead owns G3 review. Throy-san's ASCI coverage still needs formal confirmation this week.
- **ASCH 2027 "testing-only" claim VERIFIED by investigation** (read-only; `projects/asch/technical-notes/investigation/20261029-asch2027-logic-vs-testonly/REPORT-00-...md`). Grounded in code (`CommonUtil`, `BundleDetectionService` plan+date-keyed grouping cleanly separates CIP↔CAP transition months, `TwoWayAllocationFormula` input-agnostic to half-price N, `getContractDateInfoList` refund-lump branch, ASCI campaign-agnostic conversion/booked-amount refund): **NO new ASC logic** for any §7 transition / §4.5 / §4.4. Estimate revised → **Scenario A ~2–2.5 weeks** (3–5 testing-days + 1–2wk buffer); **Scenario B ~4–5wk contingency** only if a §7 run finds a gap. Residual risk entirely upstream (CDB clean charges + App 10021→10022). Estimate doc updated.
- **ASCH 2027 light estimate + timeline created** → `projects/asch/technical-notes/research/ASCH-2027/asch-2027-development-estimate-20261029.md`. Bottom line: **~3–5 dev-days, almost all testing**; no build (rides ASCA/ASCI); CIP = 0 incremental (in ASCI-01); net-new = §7 patterns 5/6/7. Fits before 2027-01-01 **provided ASCI-01 ships** (ASCH is downstream of ASCI; schedule risk lives in ASCI, not here). **Slack reply drafted** (Q1–3 + estimate-timing + board) — Lead to send.
- **Kuroda-san's ASCH 2027 Slack thread captured + response drafted.** Three messages (2026-10-23 ×2, 2026-10-28 follow-up) appended verbatim to REF-ASCH2027-01. Draft answers: Q1 ✅ already in ASCI-01 (G1-approved); Q2 no new code (3 QA/reconcile items + the upstream CDB App-id risk); Q3 ~3–5 dev-days mostly testing (§7 patterns 5/6/7 the net-new). Rough estimate can go now; firm estimate after ASCA/I priorities, before Nov 11. Lead to review + reply on Slack.
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
