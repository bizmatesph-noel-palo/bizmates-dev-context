# REF-CAP-13 — ASCA Spec 02 Review Feedback, Round 2 (Kuroda-san, 2026-10-05)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-05 (Received — Slack thread) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative Round-2 review feedback for ASCA Spec 02 (sub-specs 02a–02d) |
| **Audience** | Dev team (ASCA), Accounting |
| **Reviewed** | Spec 02 requirements after the Round-1 (REF-CAP-12) feedback was folded in (dev-context edits 2026-10-05): `asca-spec-02a`, `asca-spec-02b`, `asca-spec-02c`, `asca-spec-02d` |
| **Supersedes/decides** | Finalizes the four G1 open items left as TBD after REF-CAP-12; adds a second round of refinements and a 02d scope position |
| **Companion** | `research/CAP/REF-CAP-12-ASCA-Spec02-Review-G1-20260928.md` (Round-1), `research/CIP/REF-CIP-06-CAP-CIP-Refund-Patterns-Overview-20260928.md` (refund patterns) |

> ⚠️ **Verbatim source document.** Kuroda-san's Round-2 Spec 02 review, preserved in full. Do not alter this content; our resolution/impact tracking lives in `projects/asca/`. Cross-reference notes (mine, not part of the source) are at the very bottom, clearly marked.

---

## Kuroda-san — Round-2 feedback (2026-10-05, 10:35 AM)

> @Noel san, cc: @Roi Patrick Florentino @Glenn
> thanks for the update.
> I checked them and the 02c linking columns look good.
> For the other G1 items, here are my decisions so the requirement text itself can be updated (right now they are only recorded as open items / TBD).

### 1. G1 decisions

**#2 [02a] Mid-run failure: option (b)**
Write each pair atomically. A failed pair keeps N, and the run is recorded as completed-with-errors with a list of failed pairs. This matches 02b Req 6 ("SHALL NOT block unrelated CAP records"). Please also update:
- 02a Req 4.3: N is kept for the failed pairs (not the whole log).
- 02c Req 3.2: the CSV guard must treat completed-with-errors as completed, and the failed pairs should appear in the CSV.

**#3 [02a] Re-run vs V-7: restore N from the snapshot**
On re-run, restore N from `log_alloc_prorations.original_paid_price` before recomputing, and apply V-7 to that restored (pre-allocation) value only. Please add a "re-run an already-allocated month" acceptance test to Req 3.

**#1 [02b] Refund pairing: direction for Req 9**
- ① Linkage: use `log_refund_history` (`refunded_charge_id` → `refund_charge_id`). Every refund path writes it: `libs/prorated.php:243`, `shareholderrefund/addbycsv.php:294`, `controller/api/student.php`.
- ② 1+1 check: refund charges are excluded from normal bundle grouping and allocated on their own via the linkage, so the normal allocation for that month is never skipped (case i).
- ③ P_app: insert a new App log row in the execution month for the negative P_app (case ii, and case i as well). Please assess the impact on the existing CSVs / Freee sender / PayPal sums / 02c and note it in the spec.
- ④ R-12: never net +/−. Acceptance tests for both (i) and (ii).

The CIP refund split (REF-CIP-06) also needs an App-side row in the execution month, so please design this so CIP refunds can reuse it later.

### 2. 02b is out of sync with REF-CIP-06 (09-28)

- Contract overlap produces no refund (§2.4/§3.8, corrected 09-28). Please remove Req 4, R-05/R-11 in Confirmed Decisions, and the "Overlap refund" glossary entry.
- "Cooling-off 10%" was removed (§3.3). Cooling-off is a 90% refund (10% fee). Please fix Req 3.1/3.3 and the glossary.
- Shareholder cashback: CAP is split Coaching/App by the formula; CIP is Coaching-only (§3.5). Fine as CAP-only for now, but please keep this distinction in mind when CIP refunds are added.
- CIP refund scope stays on hold until I answer Patrick's Q1 (refund-type identification).

### 3. Smaller items (as promised on 09-28)

**02a**
- V-3 skips are invisible to Accounting: please record the skipped-bundle count and reason on the run, so it can be checked without reading the logs.
- Add "App (10022) paid_price = 0 confirmed on real data" (the V-7 premise) to Dependencies.
- One sentence on the source of truth: the active Final run is authoritative; Pre is preliminary.
- Reference-price start date: CAP beta release is planned for 2026-12-01 (general release 12/8–10), but the initial `effective_from` is 2027-01-01 and the price is resolved on the last day of `target_ym`. As it stands, the first close after release (target_ym 2026-12, run in early January) finds no price row, so December CAP revenue would stay 100% on Coaching.
  Beta purchases are booked as normal revenue. Please set the initial `effective_from` to 2026-12-01 instead of 2027-01-01, and update the seeder and Spec 01 references accordingly. (CAP charges can't exist before the beta, so an earlier date is harmless if the schedule slips.)
- Also state the behaviour for any month with no reference-price row: every bundle is skipped with a reason, as a no-op (not a failure). Seed prices on DEV04 for the test month so the Req 6.4 smoke run actually allocates.
- Add a test that a standalone App charge (10012) is excluded.

**02b**
- Req 5.3: the ¥19,800 cap is applied upstream. Accounting sets `refund_price` in the CSV under the benefit rule; the upload itself only blocks totals above the original paid amount (`addbycsv.php` L245–258). The allocation layer uses the delivered negative as-is and does not re-cap (warning log at most).
- Add CAP numeric acceptance cases (15min, L = 18,000 : 3,618):
  - cooling-off 90% of 22,550: N = −20,295 → App −3,397 / Coaching −16,898
  - tax exemption 22,550 × 10/110: N = −2,050 → App −344 / Coaching −1,706
  - shareholder: N = −19,800 → App −3,314 / Coaching −16,486
- O-R3 can be closed: Req 3.4 already says the Admin Refund negative is used as delivered.
- Req 6.3: if `record_kind` is used to mark refunds, please use a value that doesn't collide with 2 (reserved for reversal).

**02c**
- The CSV guard must be per run type (Pre/Final). Otherwise the Final email could pick up a CSV from a completed Pre run when the Final run failed.
- ステータス(status) is always "Completed" (the file is only emitted for completed runs). Please make it per-row (allocated / skipped + reason / failed) and include skipped bundles.
- Show the tax basis in the headers, e.g. 参照価格(税抜), 元金額(税込), 配分後金額(税込).
- 契約種類 (contract type): please define the value → label mapping (0 = B2C, 1 = B2B, 2 = B2B2C/B2E). "Partner" can't be derived from `contract_type`, so either drop it or specify the source column.
- O-G1-4: the Japanese labels for the three new columns (チャージID / バンドルID / 行種別 (通常 / 返金)) are fine as drafted. No separate check with Accounting needed.
- O-C3: agreed. The Pre file should reflect the Pre run, consistent with the other 速報版 CSVs.

### 4. 02d

Thanks for the reasoning on drift. One correction: `DataCorrectionCommand` isn't "to be retired soon". Wu-san confirmed on 08-28 that it's already unused in operation. Accounting corrections now go through Redmine → DevOps manual SQL (about once a month), and those corrections are made with the post-allocation amounts, so no allocation hook is needed there either.

02d would only protect a path nobody runs, so I'd like to keep it out of scope. If the concern is someone running the command by accident, disabling it or marking it deprecated in code would be enough.

> Thanks you.

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

| Item | Decision | Where it lands |
|---|---|---|
| **#2 Mid-run failure (02a)** | **Option (b)** — per-pair atomic, failed pairs keep N, run = completed-with-errors + failed-pair list | 02a Req 4.3 (rewrite O-G1-2 → settled); 02c Req 3.2 (completed-with-errors = completed, failed pairs in CSV) |
| **#3 Re-run vs V-7 (02a)** | Restore N from `log_alloc_prorations.original_paid_price`; V-7 on restored value only; + re-run acceptance test | 02a Req 3 (rewrite O-G1-3 → settled) |
| **#1 Refund pairing (02b)** | ① link via `log_refund_history`; ② refunds excluded from normal grouping, allocated via linkage; ③ insert new App log row in execution month for negative P_app (assess CSV/Freee/PayPal/02c impact); ④ R-12 no-netting, tests (i)+(ii); design for CIP reuse | 02b Req 9 (fill in TBD → settled) + impact note |
| **02b REF-CIP-06 sync** | Remove Req 4 + R-05/R-11 + "Overlap refund" glossary (overlap produces no refund); fix cooling-off = 90% refund (Req 3.1/3.3 + glossary); keep CAP/CIP shareholder distinction noted | 02b Req 3/4, Confirmed Decisions, Glossary |
| **02a smaller items** | V-3 skip count+reason on run; App=0 dependency; source-of-truth sentence; **`effective_from` → 2026-12-01** (seeder + Spec 01 refs); no-price-row = skip-not-fail; standalone App (10012) exclusion test | 02a Reqs + Dependencies; **Spec 01 seeder/refs** |
| **02b smaller items** | Cap applied upstream (Req 5.3 reword — no re-cap); 3 numeric acceptance cases; close O-R3; `record_kind` ≠ 2 | 02b Req 5.3, Req 6.3, acceptance tests, O-R3 |
| **02c smaller items** | Per-run-type guard; per-row status (allocated/skipped+reason/failed, incl. skipped); tax-basis headers (税抜/税込); contract-type label map (0=B2C/1=B2B/2=B2B2C/B2E), drop or source "Partner"; O-G1-4 resolved; O-C3 agreed | 02c Reqs 1/2/3/4 |
| **02d scope** | Kuroda-san: **drop** (Wu-san 08-28 — `DataCorrectionCommand` already unused; corrections via Redmine→DevOps manual SQL with post-allocation amounts). **Lead position (Noel, 2026-10-07): HOLD the retain for now — Noel to clarify with Kuroda-san before any 02d requirement update.** 02d requirements left as-is pending that clarification. | 02d — no change yet; Lead to confirm with Kuroda-san |

> **Status:** Round-2 decisions are confirmed by Kuroda-san. Groups 1–3 (02a/02b/02c + Spec 01 seeder date) are cleared to fold into the requirement text. **02d is NOT dropped yet** — Noel is holding the retain and will clarify the accidental-execution concern with Kuroda-san directly before touching 02d. No spec files were edited when creating this record.
