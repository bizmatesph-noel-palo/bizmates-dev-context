# ASCI-25 — DEV04 - 20261113 merge feature/CIP/CIP-base (CIP-218) into bizmates.jp deployment/dev04

> **Created in JIRA 2026-11-13 20:12 as [ASCI-25](https://bizmates.atlassian.net/browse/ASCI-25)** — Task under ASCI-15, Priority Medium, assigned to Throy-san, status To Do. Same short format as ASCI-24 (the CAP-382 merge). This file is the source of record.
> **Branch (checked in git 2026-11-13 evening):** CIP-218 (`489f4b0`) is now in `feature/CIP/CIP-base`, the CIP equivalent of the `CAP-base` used for ASCI-24. It is **not** in `deployment/dev04` yet. Confirm with Jefferson-san that `CIP-base` is the branch to merge (the CAP side went through a `release/CAP/CAP-base` branch, PR #21244).

**Type:** Task
**Parent / Epic:** ASCI-15 ([Ops] — DEV04, Investigations, Debugging & Deployment)
**Priority:** Medium
**Assignee:** Throy-san (or as decided)
**Related:** CIP-218, ASCI-24 (CAP-382 merge)

---

## Description

Merge the CIP-218 changes (immediate REST of a CIP Coaching also ends the App companion 10022 on the same day) into DEV04, so Glenn-san can run the CIP side of the immediate-REST retest.

- **Repo:** `bizmatesinc/bizmates.jp`
- **Source branch:** `feature/CIP/CIP-base` (to confirm with Jefferson-san)
- **Target branch:** `deployment/dev04`
- **CIP-218:** PR #21218, merge commit `489f4b0` (2026-11-12). It changes only `fuel/app/classes/controller/api/students/rest.php`. Still QA (REVIEW) in JIRA on 2026-11-13.

Context: CAP-382 (ASCI-24) is already in `deployment/dev04` (PR #21244, Cristoff-san, 2026-11-13). CIP-218 changes the same file, `rest.php`, so check for a conflict there. `CIP-base` may also carry other commits that are not on DEV04; check with the CIP team that they are fine for DEV04 before merging.

Log DEV04 merge work here: the merge, confirming the DEV04 server pulled `489f4b0`, and the hand-over to Glenn-san for the CIP retest (new CIP student, immediate REST + refund; Throy-san reruns the batch).
