# ASCI-24 — DEV04 - 20261113 merge feature/CAP/CAP-base (CAP-382) into bizmates.jp deployment/dev04

> **Created in JIRA 2026-11-13 as [ASCI-24](https://bizmates.atlassian.net/browse/ASCI-24); shortened and changed to `feature/CAP/CAP-base` the same day (per Keith-san).** Task under ASCI-15, Priority Medium. Assignee changed to Cristoff-san on 2026-11-13 (11:43). This file is the source of record; the JIRA ticket carries the same content.

**Type:** Task
**Parent / Epic:** ASCI-15 ([Ops] — DEV04, Investigations, Debugging & Deployment)
**Related:** CAP-382, ASCA retest (CAP-382 AC6)

---

## Description

Merge the CAP-382 changes (immediate REST also ends the App companion 10022) into DEV04, so Glenn-san can run the ASCA retest (CAP-382 AC6).

- **Repo:** `bizmatesinc/bizmates.jp`
- **Source branch:** `feature/CAP/CAP-base` (per Keith-san)
- **Target branch:** `deployment/dev04`
- **CAP-382:** PR #21205, merge commit `24fbe75`, already in `CAP-base`. It passed CAP QA on DEV02 and STG (AC1 to AC3).

Context: `CAP-base` also carries about 70 other commits that are not on DEV04 (CAP-358, CAP-324, CAP-331, CAP-305, CDB and DEVOPS items), and it does not include CAP-392. Check with the CAP team that these are fine for DEV04 before merging. CIP-218 is a separate merge (see the CIP ticket).

Log DEV04 merge work here: the merge, confirming the DEV04 server pulled `24fbe75`, the batch run if needed, and the hand-over to Glenn-san.
