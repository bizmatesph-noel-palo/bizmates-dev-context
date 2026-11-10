# ASCI-22 — DEV04 - 20261110 ASCI-19 deployment and command execution

> **Created in JIRA 2026-11-10 as [ASCI-22](https://bizmates.atlassian.net/browse/ASCI-22)** — Task under ASCI-15, Priority Medium, assigned to Throy-san, status To Do. This file is the source of record; the JIRA ticket carries the same content. Same pattern as ASCI-16 / ASCI-18.

**Type:** Task
**Parent / Epic:** ASCI-15 ([Ops] — DEV04, Investigations, Debugging & Deployment)
**Priority:** Medium
**Assignee:** Throy-san
**Related:** ASCI-19 (the fix), ASCI-17 / ASCI-20 / ASCI-21 (close after this run is verified)

---

## Goal

Deploy the ASCI-19 fix to DEV04, rerun the batch, and confirm the CIP refunds and conversions are correct, so ASCI-17, ASCI-20 and ASCI-21 can be closed.

## Steps

### Step 1 - Merge ASCI-19

After the Lead approves the ASCI-19 PR, merge `feature/ASCI/ASCI-19-cip-pairing-ignore-refund` into `feature/ASCI/ASCI-master`.

### Step 2 - Deploy to DEV04

Deploy the same way as on 2026-11-04: create a new branch from `deployment/dev04`, merge `feature/ASCI/ASCI-master` into it, then merge it into `deployment/dev04`.

### Step 3 - Check DEV04 pulled the code

On the DEV04 server, confirm the deployed code contains the ASCI-19 commit `4b4e667a` before running anything. On 2026-11-04 a fix was deployed but not pulled, and the first rerun showed the old result.

### Step 4 - Run the batch

Run the same batch commands as for ASCI-18, for the 2026-11 target month (the report dated 20261201).

### Step 5 - Check the result

In `202611_03_DailyRateCalculation(20261201).csv`:

| Student | Expected Coaching refund | Expected App refund (new row) |
|---|---|---|
| 1332, 1341, 2883 | −71,920 | −3,980 |
| 303197, 1824 | −35,960 | −1,990 |

- The original charges of these five students are converted (a Coaching and App split, not 75,900 and 0).
- Searching the DEV04 log for `[CIP_CONVERSION]` and `[CIP_REFUND]` shows no skip lines for these five students.

### Step 6 - Hand over to QA

Post the CSV and the log check as a comment on this ticket, and tell Glenn-san so he can retest QA-T9346 and QA-T9350 to QA-T9352 for ASCI-20 / ASCI-21.

## How to know it's done

- ASCI-19 is in `feature/ASCI/ASCI-master` and on DEV04 (commit `4b4e667a` confirmed on the server).
- The batch ran for 2026-11 and the five students match the table in Step 5.
- The results are posted here and Glenn-san is informed.

## Do NOT

- Do not run the batch before Step 3 is confirmed.
- Do not change any code in this ticket. If the result is wrong, report it on ASCI-19.
