# CAP positive-side gap (found in the ASCA-81 QA pass) — evidence, cause, and Kuroda-san's decision

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report (stakeholder thread capture + evidence) |
| **Status** | Decision made (2026-11-09); cause confirmed by Kuroda-san at 14:47; upstream CAP fix requested; DEV04 retest pending |
| **Date** | 2026-11-09 |
| **Author** | Noel Palo, Lead |
| **Assisted by** | Kiro |
| **Mode** | READ-ONLY (Slack threads pasted by the Lead, DEV04 CSVs in `projects/asca/generated-files/`, Glenn-san's SQL screenshots). No code changed. |
| **Related** | ASCA-81 (investigation), ASCA-86 (refund-path fix), Spec 01 Req 6.4 / 10.6, `../20261030-asca81-cap-refund-no-app-row/` (REPORT-00, REPORT-01) |

---

## 1. Summary (verdict first)

QA (Glenn-san, 2026-11-06) passed ASCA-81 and also found a related gap: for students 471 and 7185 the **original (positive) charges are still not split** between Coaching and App, while the **refund is now split** (ASCA-86). The totals net to 0 but the amounts shift between products.

**Decision (Kuroda-san, 2026-11-09): accept it as a known limitation. No Spec 01 change. Nothing to start before the Lead's leave (2026-11-11 to 2026-11-23). Keep the V-3 skip and its outcome logging as they are.** At 11:42 he withdrew his request to the CAP team for a code fix. **At 14:47 he reversed that part:** the business team confirmed the App should end on the same day as the Coaching, so he asked the CAP team (Soli-san) to update immediate REST so that it also ends the App on the same day. After that fix is deployed, QA retests on DEV04 with a new CAP student (immediate REST + refund) and checks that the original charge is split. The ASC side still has no change.

**Cause (confirmed by Kuroda-san at 14:47 after Glenn-san's video and DB check):** the "即時休会" (immediate rest) action in the admin portal sets the Coaching end date to the execution date and leaves the App charge unchanged. The Coaching and App end dates then differ, so the original charges are not paired and are skipped (V-3).

## 2. What QA found (Glenn-san, 2026-11-06 17:41)

| Student | Positive Coaching (raw price, unsplit) | Positive App | Refund Coaching | Refund App (new, ASCA-86) | Net Coaching | Net App |
|---|---|---|---|---|---|---|
| 471 | +21,175 | 0 | −19,241 | −1,934 | +1,934 | −1,934 |
| 7185 | +42,350 | 0 | −38,482 | −3,868 | +3,868 | −3,868 |

Only these two bundles on DEV04 have mismatched end dates (2 of the 12 CAP refunds). Before ASCA-86 both sides were unsplit, so each product netted 0.

## 3. Evidence (checked by the Lead)

**DEV04 CSV `202610_03_DailyRateCalculation(20261101).csv` (the date column is the charge end clipped to the target month end):**
- 471: Lesson original 3224203 and Coaching original 3224205 both run **2026-10-12 to 2026-10-15** (4 days); App 3224206 runs 2026-10-12 to 10-31 (clipped). The refund rows for Lesson and Coaching are dated 2026-10-15.
- 7185: Lesson original 3224137 and Coaching original 3224139 both run **2026-10-09 to 2026-10-15** (7 days); App 3224140 runs 2026-10-09 to 10-31 (clipped).
- So for both students the Lesson and Coaching charges end on **10-15, the refund date**, while the App does not. Glenn-san's db_logs give the App end dates as 11-11 (471) and 11-08 (7185); I did not verify those two dates myself.
- Observation not explained yet: the refund (negative) rows for 7185 carry the original full dates (2026-10-09 to 2026-11-08), while 471's refund rows end 2026-10-15.

**Code:** `BundleDetectionService` groups bundles on `student_id | order_no | plan_id | start_date | end_date`, so a Coaching and an App charge with different end dates never form a bundle. The injector skips such an unpaired bundle (V-3) and records it in `log_alloc_bundle_outcomes` (outcome = skipped).

**Glenn-san's SQL (screenshots, 2026-11-09):**
- Query on `trn_prorated_refund` / `trn_prorated_refund_charge` for students 471 and 7185: **empty set**. So these refunds did not go through the prorated refund registration.
- Query on `trn_charge` with `log_refund_history`: the four original charges (Lesson 3224203 and 3224137; Coaching 3224205 and 3224139; plan 1023) each have a negative charge linked in `log_refund_history` (3224286, 3224285, 3224287, 3224288), all paid 2026-10-15. The prorated-refund columns are NULL for all four rows.
- Glenn-san did the refund in the admin portal, Search Student screen (`/MyBizmates/student/searchstudent`), with the "rest" action (automatic refund), and **changed no dates by hand**. He mentioned a video; I have not seen it.

## 4. How the thread developed (2026-11-09)

| Time | Who | What |
|---|---|---|
| 10:00 | Kuroda-san | Thanked QA. First view: a refund means no more Coaching, so the App end date should be shortened too; thought the bizmates.jp prorated refund registration only handles the main and video charges, so the App is never shortened. Said he would confirm with the business and CAP teams and decide by end of day. |
| 11:42 | Kuroda-san | **Corrected himself.** The prorated refund screen does not offer Coaching at all, and the business team says Coaching is not refunded on a prorated basis. When a B2B contract overlaps a Coaching contract, operations set the Coaching and App end dates by hand to the same date. Until the B2B plan revision (April 2027) a switch from the new Honki plan to the old 30-minute plan can leave different end dates; overlaps are very rare and handled case by case (for example a Redmine request). **Decision: (a) accept as a known limitation.** Asked Glenn-san how the test data was made. |
| 11:46 | Glenn-san | The refund was done through the UI; no dates were changed. |
| 12:10 | Kuroda-san | Asked for the screen/URL and whether the Coaching charge IDs appear in `trn_prorated_refund_charge.refund_charge_id`. The ASCA decision stays the same either way. |
| 12:21 | Glenn-san | Screen: admin portal Search Student, "rest" (automatic refund). SQL result: empty set. |
| 12:35 | Kuroda-san | The query is correct. With the video this confirms the cause: the 即時休会 action set the Coaching end date to the execution date; the App was not changed. Will confirm expected behavior with the business and CAP teams. |
| 14:47 | Kuroda-san | **Conclusion.** Cause: the Coaching end date was changed by 即時休会 (Search Student > REST); no prorated refund registration exists for 471 and 7185; immediate REST sets the Coaching end date to the execution date but does not update the App (product 10022), which kept its original end date (he says 10/31), so the allocation could not pair them as a CAP bundle. The business team confirmed the App should end on the same day as the Coaching, and he asked the CAP team (Soli-san) to update immediate REST accordingly. No Spec 01 change planned; keep the V-3 skip and its outcome logging. Asked the Lead and Glenn-san to retest on DEV04 with a new CAP student (immediate REST + refund) once the fix is deployed and check that the original charge is split. |

## 5. Verified vs not verified

- **Verified by the Lead:** the amounts and charge IDs in section 3; Lesson and Coaching ending on the refund date in the CSV; the bundle key including `end_date` (code); the SQL result as shown in the screenshots.
- **Kuroda-san's conclusion, confirmed by him but not independently verified:** that the immediate rest action is the logic that shortens the Coaching end date and leaves the App unchanged. The data fits it, but I have not read that code, and I have not seen the video.
- **A discrepancy to check:** Kuroda-san says the App kept its original end date **10/31**. Glenn-san's db_logs give the App end dates as **11-11 (471) and 11-08 (7185)**, and the CSV only shows the end clipped to the target month (10-31), so 10/31 may come from the CSV. It does not change the conclusion (the dates differ either way), but the real App end dates should be confirmed when Glenn-san shares the DB logs.
- **Not checked:** how often an immediate rest on a CAP plan happens in production; the video; the difference between the refund rows of 471 and 7185.

## 6. What it means

1. **No Spec 01 change and no code change before the leave.** Spec 01 Req 6.4 (Coaching and App share identical dates) still holds for normal bundles.
2. **ASCA-86 is still needed.** An immediate rest creates exactly the shape that fix handles: the original charges are skipped, and the refund must still be split by pairing the App on the start date.
3. **Keep the V-3 skip and the `log_alloc_bundle_outcomes` logging.** Kuroda-san wants them as the safety net to find these cases, and any case where only one date is changed by hand.
4. **Expected effect in production:** a bundle whose Coaching and App end on different dates stays unsplit, and its refund is split, so Coaching and App shift by the App share of the refund (1,934 and 3,868 here); the total is unchanged. It is rare per the business team.
5. **ASCH estimate:** this is no longer a Scenario B trigger. Other triggers (a gap found in a test run) remain.
6. **ASCI-19** is a different defect (CIP pairing counts the refund charge) and is not affected by this decision.
7. **The root cause is fixed upstream, not in ASC.** Once the CAP team changes immediate REST so the App ends with the Coaching, new bundles have matching dates and pair normally. The retest should show, for a new CAP student, an original charge split by the floor formula and a split refund. Example with the 471 amounts: original 21,175 gives Coaching 19,242 / App 1,933; refund gives −19,241 / −1,934; each product nets ±1 yen, which is the accepted floor rule (ASCA 02b R-01), not the ±1,934 shift seen today.
8. **Not addressed by Kuroda-san:** cases created by immediate REST before the CAP fix stay mismatched. The V-3 skip and its logging are how to find them.

## 7. Open items

| Item | Owner |
|---|---|
| Update immediate REST so it also ends the App on the same day as the Coaching, and tell the team when it is deployed | Soli-san (CAP team), requested by Kuroda-san |
| Retest on DEV04 with a new CAP student (immediate REST + refund) and check that the original charge is split. The Lead is on leave 11-11 to 11-23, so Glenn-san checks with Throy-san rerunning the batch | Glenn-san, Throy-san (Lead if back) |
| Share the DB logs for 471 and 7185 | Glenn-san |
| Optional: a note in Spec 01 / 02b that a V-3 skip is expected for immediate-rest bundles. Kuroda-san said no Spec 01 change for now | Lead, after the leave |
| Optional: understand why 7185's refund rows keep the original end date and 471's do not | Lead, after the leave |
