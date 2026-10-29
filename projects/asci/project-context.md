# ASCI — Project Context

> Load this at the start of each ASCI session.
> Also load `projects/asca/project-context.md` for the shared framework context, and `domain-knowledge/plans-and-products.md`.
> If context gets compacted, re-read these before continuing.

---

## ⚠️ Important: ASCI is NOT an allocation-engine config exercise

An earlier version of this file described ASCI as "a configuration exercise — same formula, same injection point, add CIP plan_ids + reference prices." **That is superseded and wrong.** Per **REF-CIP-05 (2026-09-17)**, CIP does **NOT** use the ASCA allocation engine for normal charges. Do not build ASCI on the old "add CIP to the engine" assumption.

---

## What ASCI Is (grounded in REF-CIP-04/05/06/07/08)

**ASCI (ASC for CIP)** makes the accounting system correctly recognize revenue for the Coaching Intensive Plan (CIP, plan_id 1028–1032). Unlike ASCA/CAP, CIP revenue is split by **issuing separate, already-priced charges** that flow through the **existing daily pro-ration** — there is **no allocation engine, no formula, no reference-price weight, no run/anchor tracking** for CIP normal charges.

**The only place CIP needs a split is REFUNDS** — a CIP refund is booked as one negative on the Coaching Intensive charge and then distributed to App by a fixed per-type rule (the exception to "no engine" — REF-CIP-06/07/08).

**Scope:** Bizmates-only. Depends on the ASCA foundation being complete (shared framework + the DEV04 environment), but reuses little of the engine — mostly the project scaffolding, the DEV04 setup, and the refund-handling patterns.

**JIRA:** [ASCI Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) · [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog)

---

## Key Info

| Item | Value |
|---|---|
| Project code | ASCI |
| Full name | ASC for CIP (Coaching Intensive Plan) |
| Upstream project | CIP (Jefferson's team) |
| Code repo | `accounting_related_system_for_freee`, `ls-database-migrations` |
| Project branch | **`feature/ASCI/ASCI-master`** (both repos) — branched from `feature/ASCA/ASCA-master` (the ASCA foundation base), created 2026-10-28 |
| Lead | Noel Palo |
| Developer | Throy Embudo, Cristoff Danganan |
| QA | Glenn Flamiano |
| SDM | Patrick-san |
| PM | Kuroda-san |
| Deadline | 2026/12/17 |
| First batch run | 2027/01/01 |
| Depends on | ASCA foundation (shared) — and the ASCA CAP-refund design (02b), which the CIP refund rule parallels |

---

## Corrected CIP master data (vs the old stale values)

| Item | CORRECT value (REF-CIP-04/05/06) | Old stale value (do NOT use) |
|---|---|---|
| Coaching Intensive product_id | **10025** | ~~10022~~ |
| Auto-bundled App product_id | **10022** (same product as CAP) | ~~10021~~ |
| CIP plan_ids | **1028–1032** (5 plans, all new, no history) | (unchanged) |
| CIP Solo (1028) plan price | **¥75,900 tax-incl** (¥69,000 pre-tax = Coaching+App) | ~~¥88,000~~ |
| Coaching Intensive booking price | **¥71,920 tax-incl** (¥65,382 tax-excl) — new `mst_new_price_listing` `price_flag = 3` record (= 75,900 − 3,980) | ~~L_coaching ¥84,020 weight~~ (no weight exists — no engine) |
| App price | **¥3,980 tax-incl** (existing `price_flag = 2`, reused directly) | (unchanged) |
| Lesson (1029–1032) | its own existing standalone lesson price, separate charge | — |
| Allocation weight / L_coaching | **N/A — CIP is not engine-allocated** | ~~¥84,020~~ |

---

## What ASCI actually builds

1. **Verify the Coaching Intensive price record (NOT built by ASCI):** the `price_flag = 3` row (10025, ¥65,382 tax-excl / ¥71,920 tax-incl / tier2 ¥32,691) is **created by CIP-179** (Jefferson; QA Passed 2026-10-12 — verified in Jira), not by an ASCI seeder. ASCI verifies it shipped to the target env. ⚠️ CIP-179 **also removes** the 10025 `price_flag = 2` rows (66,500/33,250) — REF-CIP-09 W-2 said that row "stays"; open item with Kuroda-san. (The App `price_flag = 2` on 10022 ≈ ¥3,980 tax-incl already exists; no new App record. Plans/products/banners already seeded.)
2. **Site→booking conversion (B-1 — the new requirement from G1):** on the site the Coaching Intensive charge carries the whole Coaching+App amount (¥75,900) and the App charge is ¥0. The batch converts to Coaching ¥71,920 / App ¥3,980 (App = `FLOOR(site × 3,980 / 75,900)`) **before** day-proration. Campaign-agnostic (no Honki/month detection); a half-price month → 35,960 / 1,990. Not the allocation engine.
3. **Verify existing pro-ration + discounts** produce the expected per-charge amounts for CIP Solo (1028) and lesson-bundled (1029–1032): Lesson, Coaching Intensive (71,920), App (3,980) each day-prorated independently after the conversion; first-month AND 6th-month 50% discounts (2027 Honki) apply via the conversion, no special-casing.
4. **CIP refund split (the real logic):** a negative on the Coaching Intensive charge is distributed to App by the month's booked-amount ratio. Lesson refunds always land on the Lesson charge (existing ASC, untouched). See the refund table below.
5. **DEV04 validation** for CIP plans.

**Estimated effort:** small for normal flow (price-record verification + the B-1 conversion step); the refund split is the substantive piece. (The old "1–1.5 weeks, config-only" estimate predates the refund scope.)

---

## CIP refund rules (fully specified — REF-CIP-06 §3, REF-CIP-07, REF-CIP-08)

CIP refunds are booked as one negative on the **Coaching Intensive charge** (Admin cannot refund a ¥0 App), then distributed to App by a fixed rule. The **divisor is the Coaching+App portion (75,900)** — NOT the full bundled plan total. Lesson is always a separate negative on the Lesson charge (existing ASC; the CIP split never touches it).

| Refund type | Lesson charge | Coaching Intensive charge | App split | Detection |
|---|---|---|---|---|
| Cooling-off (90%) | negative, existing ASC (e.g. 1029: −13,365) | −68,310 (= 75,900 × 90%) | Coaching −64,728 / App −3,582 | — |
| Consumption-tax exemption | negative, existing ASC (e.g. −1,350) | −6,900 | Coaching −6,538 / App −362 | — |
| Full refund | — / Lesson separate | −75,900 | Coaching −71,920 / App −3,980 | — |
| Shareholder benefit | Lesson row → Lesson charge (existing ASC) | Coaching only, −19,800 (CSV amount; cap applied upstream, NOT in batch) | **no App split** (confirmed, REF-CIP-09 W-3) | refund_charge_id in `trn_receipt_locked_charge` ⇒ shareholder |
| Contract overlap (B2C/B2E → B2B) | Lesson refunded only | **no negative on CI charge** | no refund | — |

- Non-shareholder split (updated REF-CIP-09 Comment 2): App = `FLOOR(refund × App_booked / original_site_amount)`, Coaching = refund − App — basis is the **month's booked App amount** (3,980/75,900 standard; 1,990/37,950 half-price), found via `log_refund_history`, **not** a hard-coded 3,980. Explicit type list: cooling-off / tax-exemption / **full refund**.
- Half-price month (2027 Honki): cooling-off CI −34,155 → −32,364/−1,791; tax-exemption −3,450 → −3,269/−181; full −37,950 → −35,960/−1,990.
- Shareholder: batch books the CSV amount **as-is**; it does NOT apply or truncate the ¥19,800 (interim) cap — that is upstream (REF-CIP-09 W-3).
- Negative recognized as a lump in the `paid_at` (execution) month; not day-prorated, not spread back.

---

## Decisions & open items

**CIP-refund home — ✅ CONFIRMED inside ASCI-01** (Kuroda-san G1 feedback, REF-CIP-09, 2026-10-22): "specify and implement the CIP refund split inside ASCI-01." ASCI stays one spec. (Was the explicit G1 question.)

**Open item — flag-2 "stays vs removed":** REF-CIP-09 W-2 says the 10025 `price_flag = 2` (¥66,500) row stays (unused by CIP); CIP-179's acceptance criteria **remove** it (verified in Jira). Does not affect CIP (uses flag-3), but confirm with Kuroda-san. Also pending human checks: CIP-179 released to the target env (DB), and the half-price tax-exemption −181 figure blessed by Accounting (Wada-san).

---

## Spec shape (proposed — for G1)

ASCI is **one spec, ASCI-01** (refund home confirmed inside it — REF-CIP-09), with five requirements: (1) verify the CIP-179 booking price record, (2) the B-1 site→booking conversion, (3) existing-proration/discount verification, (4) the CIP refund split, (5) DEV04 verification/tests.

---

## Related Projects

| Code | JIRA | Relationship |
|---|---|---|
| ASCA | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog) | Sister project — built the foundation + the CAP refund design (02b) the CIP refund parallels |
| ASC (ASCM) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/boards/1186/backlog) | Base system — CIP charges ride its existing daily pro-ration |
| CIP (upstream) | — | Jefferson's team — creates the CIP charges ASCI recognizes |

---

## Key Documents

| Document | Location |
|---|---|
| CIP no-engine decision (normative) | `research/CIP/REF-CIP-05-Residual-Value-Pricing-Replaces-Allocation-20260917.md` |
| CIP refund patterns (normative) | `research/CIP/REF-CIP-06-CAP-CIP-Refund-Patterns-Overview-20260928.md` |
| CIP refund-type identification | `research/CIP/REF-CIP-07-CIP-Refund-Type-Identification-20261005.md` |
| Lesson-bundled CIP refund clarification | `research/CIP/REF-CIP-08-Lesson-Bundled-CIP-Refund-Clarification-20261020.md` |
| **Kuroda-san G1 feedback (B-1, W-1..W-5, add-ons)** | `research/CIP/REF-CIP-09-ASCI-Spec01-G1-Feedback-20261026.md` |
| CIP product/plan IDs + price matrix | `research/CIP/REF-CIP-04-Product-Plan-IDs-And-Price-Matrix-20260824.md` |
| Technical design (shared framework) | `projects/asca/documentation/asc-allocation-framework-technical-design.md` |
| Master timeline (all ASC projects) | `docs/asc-projects-master-timeline.md` |
| Task tracker (day-to-day actuals) | `docs/asc-projects-task-tracker.md` |
| ASCA project context (shared) | `projects/asca/project-context.md` |
| Plans & products reference | `domain-knowledge/plans-and-products.md` |

---

> **Status note (2026-10-20):** this file was rewritten to the REF-CIP-05/06/07/08 reality (no engine, product_id 10025/10022, residual ¥71,920, refund split). The prior version (engine-based, 10022/10021, ¥84,020) was fully superseded.
>
> **Status note (2026-10-22):** **ASCI-01 requirements polished, cross-checked, and committed — G1-ready, submitted to Kuroda-san for review.** Cross-check (read-only investigation, `projects/asci/technical-notes/investigation/20261022-asci-req-vs-asca-impl-crosscheck/`) verdict: no blockers; refund logic verified against REF-CIP-07/08 + REF-CAP-17 and against live ASCA code (CIP cannot enter the allocation engine — `BundleDetectionService` filters plan_id 1016–1027, `RefundLinkageResolver` excludes 1028–1032). Two price-label fixes applied (SF-1/SF-2) plus contract-type/campaign clarifications. **Awaiting Kuroda-san G1 sign-off** — on approval, promote `requirements.md` to the code repos' `.kiro/specs/` and create the ASCI JIRA epic + stories (layout draft in `technical-notes/jira/asci-spec-01-jira-layout.md`). CIP-refund-home (inside ASCI-01) is the explicit G1 decision requested.
>
> **Status note (2026-10-23):** ASCI-01 requirements **committed and submitted to Kuroda-san for G1**. **No feedback yet** — Lead to **follow up Monday (2026-10-27)**. On sign-off: promote to the code repo `.kiro/specs/`, create the ASCI epic + stories, then design/tasks/implement. **Leave coverage (Lead on leave 2026-11-11 → 11-23): Throy-san oversees ASCI** during the absence (to be confirmed formally as the last pre-leave item). ASCI is the critical-path watch item, since it is blocked on an external G1 and its downstream work may run during the leave.
>
> **Status note (2026-10-26):** **Kuroda-san has PROVIDED his G1 feedback** on ASCI-01 (shared at DSM) — this supersedes the 2026-10-23 "awaiting feedback" note. The ball is now on our side: **ingest + process the feedback**, capture it as a verbatim REF (same approach as the other Kuroda-san inputs), fold it into `requirements.md`, then promote to the code repo `.kiro/specs/` and create the ASCI epic + stories → design/build. **Action: capture the feedback (where it came through) and process it.** Leave coverage unchanged (Throy-san oversees ASCI during 2026-11-11 → 11-23).
>
> **Status note (2026-10-26, later):** **G1 feedback ingested, processed, and folded in.** Kuroda-san's three Confluence comments captured verbatim as **REF-CIP-09**; verdict = **approved-with-changes** ("once B-1 is reflected, I'm happy to sign off"); **refund home CONFIRMED inside ASCI-01**. `requirements.md` revised (now 5 requirements): added Req 2 (B-1 site→booking conversion, campaign-agnostic), reworded Req 1 (record exists via CIP-179, flag-2 legacy), Req 4 (explicit refund types incl. full refund; basis = month's booked App amount via `log_refund_history`; shareholder no-cap/Coaching-only confirmed), Req 5 (first + 6th-month discount tests). **Jira-verified:** CIP-179 (Add price_flag for 10025) = QA Passed 2026-10-12, Jefferson, tier1 65,382/tier2 32,691 — and its ACs **remove** the 10025 flag-2 rows (→ W-2 "stays vs removed" open item with Kuroda-san). No ASCI seeder creates the record (confirmed via grep; `ReferencePriceSeeder` disclaims it). Synced the flag-2/CIP-179 facts across master-timeline, plans-and-products, and the ASCA technical-design doc. **Still GATED (not done):** sending the revised draft back to Kuroda-san (Confluence — human action), promoting `requirements.md` to the code repos' `.kiro/specs/`, and creating the ASCI epic + stories. **Pending human checks:** CIP-179 released to target env (DB query); −181 half-price tax-exemption figure blessed by Accounting (Wada-san). Leave coverage unchanged (Throy-san, 2026-11-11 → 11-23).
>
> **Status note (2026-10-27):** **Revised ASCI-01 requirements SENT BACK to Kuroda-san for final G1 confirmation + announced on the team Slack channel.** The send-back note flagged the two items that grew past wording (new Req 2 conversion step; refund basis now the month's booked App amount) and the flag-2 "stays vs removed" reconciliation (W-2 vs CIP-179). **Awaiting Kuroda-san's final tick.** On confirmation: promote `requirements.md` to the code repos' `.kiro/specs/` + create the ASCI epic/6 stories (drafts fleshed out with `ASCI-XX#` placeholders in `technical-notes/jira/asci-spec-01-jira-layout.md`). **Do NOT promote or create tickets until the tick lands.** Separately, the ASCA-70 DB-safety fix is ready to delegate (two guard tickets grounded on live HEAD) — pending Lead go to create the JIRA sub-tasks (accounting/ASCA-17 High, ls-db/ASCA-16 Medium).
>
> **Status note (2026-10-28):** **ASCI-01 G1 APPROVED by Kuroda-san.** Round-2 reply captured (REF-CIP-09 Comment 4); additions A (Req 2 App-charge pairing — CAP G1 1-5, skip/V-3) and B (Req 4 App-refund row via ASCA 02b Req 9) folded in, plus the "booked amount before day-proration" wording fix; flag-2 open item closed (CIP-179 removes it). `requirements.md` status = **G1 APPROVED**. **ASCI JIRA created:** Epic **ASCI-8** + stories **ASCI-9..14** (all unassigned). **Next: promote `requirements.md` → code repos' `.kiro/specs/` (+ valid `.config.kiro`) → G2 design/tasks.** Deferred to design (REF-CIP-09 Comment 4): missing-`log_refund_history`-link handling; cumulative App-refund cap (≤ original App booking); non-divisible ¥50,000 test. Pending human checks: CIP-179 released to target env (DB); Wada-san blesses the −181 figure.
