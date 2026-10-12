# REF-CIP-07 — CIP Refund-Type Identification (Kuroda-san, 2026-10-05)

## Document Info

| | |
|---|---|
| **Document type** | Research Summary (source document — verbatim) |
| **Date** | 2026-10-05 (Received — Slack thread) |
| **Author (source)** | Hayato Kuroda (PM) |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — normative. **Closes the CIP refund-type open item** left in REF-CIP-06 §2.6 and REF-CAP-12 §3 (Kuroda-san's reply to Patrick-san's Q1). |
| **Audience** | Dev team (ASCA/ASCI), Accounting |
| **Answers** | REF-CAP-12 §2 (Patrick-san's Q1: "how should the allocation engine identify CIP Shareholder refunds vs. Cooling-off/Tax Exemption?") and REF-CAP-12 §3 (Kuroda-san: "I'm checking this on our side and will get back to you. Please hold the CIP refund-split part until then.") |
| **Refines** | REF-CIP-06 §2.6, §3.4, §3.5 |

> ⚠️ **Verbatim source document.** Kuroda-san's answer to Patrick-san's Q1, preserved in full. Do not alter this content; our interpretation/impact analysis lives in `projects/asca/`. Cross-reference notes (mine, not part of the source) are at the very bottom, clearly marked.

---

## Kuroda-san — answer to Patrick's Q1 (2026-10-05)

> Hi @Roi Patrick Florentino san cc: @Noel
> Here's my answer to your Q1: how do we tell what kind of refund a negative CIP charge is?

**Short answer:** We only need to know whether a refund is a shareholder refund or not. We can tell that from data that already exists, so nothing outside ASC needs to change (no Admin changes).

**Why two cases are enough**
- Cooling-off and consumption-tax exemption are split the same way, so we don't need to tell them apart.
- Only the shareholder refund is handled differently (it goes to Coaching only).

**How ASC detects it**
1. For each refund charge on a CIP Coaching charge, find the original charge through `log_refund_history` (as decided for #1).
2. If `refund_charge_id` is in `trn_receipt_locked_charge`, it is a **shareholder refund**. Book the full amount to Coaching only and do not split it to App.
   - Only the shareholder CSV import (`addbycsv.php`) writes to this table. Normal Admin refunds (`student.php` `post_chargerefund`) and prorated refunds (`prorated.php`) do not write to it.
3. Otherwise (cooling-off, consumption-tax exemption, or any other Admin refund), split the amount by the fixed ratio:
   - App = `FLOOR(refund × 3,980 / 75,900)` (rounding toward negative infinity, same as PHP floor)
   - Coaching = refund − App
4. Book it in the `paid_at` month, as with any other negative charge.

**Acceptance examples**
- Cooling-off (90%): −68,310 → App −3,582 / Coaching −64,728
- Consumption-tax exemption: −6,900 → App −362 / Coaching −6,538
- Shareholder: −19,800 → App 0 / Coaching −19,800

**Why not the other keys**
- The `ADMIN_REFUND_` prefix on `transaction_id`: both the normal Admin refund and the shareholder CSV add it.
- `paid_at` set to 10:00:00: the CSV sets this time, but a normal refund can also land on 10:00, so we can't rely on it.

**Please note in the spec**
- `trn_receipt_locked_charge` was built to hide charges from receipts. It was not meant to mark refund types. If we ever start adding other refunds to this table, the detection will break. Please write this down as a known dependency.
- For CIP, this rule applies to 1028–1032. For 1029–1032, the lesson charge is separate and is not part of this split.

> Thank you.

---

## Cross-Reference (added by Noel — NOT part of the verbatim source)

### What this resolves

| Open item | Where it was raised | Now |
|---|---|---|
| CIP refund-type identification (shareholder vs cooling-off/tax-exemption) | REF-CIP-06 §2.6; REF-CAP-12 §2 (Patrick Q1) + §3 (Kuroda "please hold") | ✅ **Resolved** — detect shareholder via membership in `trn_receipt_locked_charge`; everything else is split by the fixed ratio. |

### Verification (checked against the referenced docs + arithmetic)

- **Detection source consistency:** REF-CIP-06 §2.5 confirms the shareholder CSV import (`addbycsv.php`) writes the receipt-lock row, and that normal Admin refunds (`student.php`) and prorated refunds (`prorated.php`) do **not**. So "in `trn_receipt_locked_charge` ⇒ shareholder" is a sound discriminator against the two other refund paths. ✅
- **Linkage consistency:** uses `log_refund_history` (`refunded_charge_id` → `refund_charge_id`), the same linkage decided for the CAP refund-pairing item (REF-CAP-13 #1). ✅
- **Numbers (fixed ratio App = FLOOR(refund × 3,980 / 75,900), Coaching = refund − App):**
  - Cooling-off −68,310 → App = FLOOR(−68,310 × 3,980 / 75,900) = FLOOR(−3,582.0…) = **−3,582**; Coaching = **−64,728**. ✅ (matches REF-CIP-06 §3.4 note)
  - Tax exemption −6,900 → App = FLOOR(−6,900 × 3,980 / 75,900) = FLOOR(−361.8…) = **−362**; Coaching = **−6,538**. ✅ (matches REF-CIP-06 per-product derivation 3,980−3,618 = 362 / 71,920−65,382 = 6,538)
  - Shareholder −19,800 → App **0** / Coaching **−19,800** (Coaching-only, not split). ✅
- **Divisor note:** the CIP fixed ratio uses **75,900** (CIP Solo plan total), distinct from the CAP ratio divisor **21,618** (18,000 + 3,618). The CIP App weight numerator is **3,980** (tax-incl. App), not the CAP 3,618 (tax-excl.). This is intentional — CIP uses tax-inclusive unit prices per REF-CIP-06 §2.3.

### Known dependency to record in the spec (Kuroda-san's explicit ask)

> `trn_receipt_locked_charge` was built to **hide charges from receipts**, not to mark refund types. The shareholder-refund detection relies on the fact that today only `addbycsv.php` writes to it. **If any other refund flow ever starts writing to `trn_receipt_locked_charge`, this detection silently breaks** (a non-shareholder refund would be mis-detected as shareholder and booked 100% to Coaching). This must be captured as a known dependency / risk in the CIP-refund spec, with a note to re-verify if the table's writers change.

### Scope reminders

- Applies to CIP plans **1028–1032**. For **1029–1032** the lesson charge is a separate charge and is **not** part of this split (consistent with REF-CIP-06 §3.10 — three independent charges, lesson stays on the existing ASC path).
- This is the **CIP** refund split. CAP refunds use the CAP formula (REF-CAP-13 #1 / 02b Req 9); the shareholder-only-to-Coaching rule and the `trn_receipt_locked_charge` discriminator are the CIP-specific pieces.

### Where this lands (NOT yet applied — pending Lead/PM scope decision)

| Target | Change needed | Status |
|---|---|---|
| CIP-refund **home** (extend 02b beyond CAP-only / new sub-spec / ASCI) | Decide where CIP-refund handling is specified | **Open — Lead/PM decision.** Identification is now unblocked, but the home was never decided. Noel to settle with Kuroda-san. |
| The chosen CIP-refund spec | Detection rule (receipt-lock discriminator), fixed-ratio split, Coaching-only shareholder, the `trn_receipt_locked_charge` known-dependency note, 3 acceptance examples | Not written yet |
| `asc-allocation-framework-technical-design.md` §1c | CIP refunds are the exception to "CIP uses no engine" — needs the detection + split note | Not yet edited |

> **No spec files were edited when creating this record.** The CIP-refund split remains out of the current CAP-only 02b until the home is decided.
