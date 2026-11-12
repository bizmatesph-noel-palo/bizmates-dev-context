# ASCI-23 — DEV04 - 20261111 command execution

> **Created in JIRA 2026-11-11 as [ASCI-23](https://bizmates.atlassian.net/browse/ASCI-23)** — Task under ASCI-15, Priority Medium, assigned to Throy-san, status To Do. This file is the source of record; the JIRA ticket carries the same content. Same pattern as ASCI-16 / ASCI-18 / ASCI-22.
> **Assumptions made at creation (confirm):** no new code is deployed today; the run is for 2026-10 and 2026-11.

**Type:** Task
**Parent / Epic:** ASCI-15 ([Ops] — DEV04, Investigations, Debugging & Deployment)
**Priority:** Medium
**Assignee:** Throy-san
**Related:** ASCI-22 (previous run, 2026-11-10), ASCI-14 (QA Testing)

---

## Goal

Run the batch commands on DEV04 on the current code so Glenn-san can use fresh reports for his regression and similar-record checks.

## Steps

### Step 1 - Confirm what code is on DEV04

On the DEV04 server, confirm the deployed branch and latest commit. It should include ASCI-19 commit `4b4e667a` and the ASCA-90 / ASCA-91 merges from 2026-11-10. Record the commit hash in a comment.

### Step 2 - Clear the previous data

Run `php artisan logs:clear-calculations {date}` for each target month before re-processing (see `batch-execution-flow.md`, "Re-Running a Month"). Do not skip this step, or the rerun may leave old rows behind.

### Step 3 - Run the batch commands

Run the same batch commands as for ASCI-22 for **both** target months, in order:

- 2026-10 (report dated 20261101)
- 2026-11 (report dated 20261201)

Commands use `exeDate` = the first day of the month after the target month (the system always processes the previous month).

### Step 4 - Check the logs

```bash
tail -50 storage/logs/laravel.log | grep -E "REVENUE_ALLOCATION|CIP_CONVERSION|CIP_REFUND|ERROR|FAILED|COMPLETED"
```

- Pass: `[REVENUE_ALLOCATION] - END` and no `EXECUTION FAILED!` lines.
- Report any `[CIP_CONVERSION]` or `[CIP_REFUND]` skip lines, with the student and charge IDs.

### Step 5 - Spot-check the CSV

In the generated `DailyRateCalculation` CSVs, check the five CIP students from ASCI-22 (1332, 1341, 2883, 303197, 1824) and the two CAP refund students (471, 7185) still show the same values as the 11-10 QA pass.

### Step 6 - Hand over to QA

Post the commit hash, the log check and the CSV spot-check as a comment on this ticket, and tell Glenn-san the new reports are ready.

## How to know it's done

- The commit on DEV04 is recorded.
- The batch ran for 2026-10 and 2026-11 with no errors.
- The spot-check matches the 11-10 results, or any difference is reported.
- Glenn-san is informed.

## Do NOT

- Do not change any code in this ticket. Report problems on the related fix ticket.
- Do not run commands against any environment other than DEV04.
