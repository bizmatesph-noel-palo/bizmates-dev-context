# DataCorrectionCommand Usage — Confirmation (Wu-san + Harvey-san)

## Document Info

| | |
|---|---|
| **Document type** | Evidence Note (source confirmation — verbatim where quoted) |
| **Date** | 2026-10-05 (Harvey-san thread); references Wu-san 2026-08-28 |
| **Saved by** | Noel Palo (Kiro-assisted) |
| **Status** | Active — operational evidence for the 02d decommission decision |
| **Supports** | `ASCA-ADR-20261005-datacorrection-decommission.md` |
| **Audience** | Dev team (ASCA), DevOps, Kuroda-san, Patrick-san |

> ⚠️ **Source confirmation.** Harvey-san's reply is preserved verbatim below. This note exists so the 02d decommission decision does not rest only on a Slack thread. Cross-reference notes (mine) are clearly marked at the bottom.

---

## Why this note exists

ASCA Spec 02d's scope was reversed from "inject allocation into `DataCorrectionLogic`" to "decommission `DataCorrectionCommand`" on the basis that the command is no longer used. That claim is operational, not something visible in the ASCA code, so it must be recorded from the people who own the correction process (DevOps) rather than inferred.

---

## Wu-san (2026-08-28) — as relayed by Kuroda-san

Per Kuroda-san (REF-CAP-13 §4): Wu-san confirmed on 2026-08-28 that `DataCorrectionCommand` is **already unused** in operation. Accounting correction requests (via Redmine) are handled by DevOps running SQL directly on the DB, about once a month (e.g. RM#12098).

---

## Kuroda-san's question to Harvey-san (2026-10-05, verbatim)

> @Harvey san
> I have a quick question about the accounting system's data correction batch (DataCorrectionCommand).
> Back in August, Wu-san told us this command was no longer used. Accounting correction requests (via Redmine) are handled by DevOps running SQL directly on the DB, about once a month (e.g. RM#12098).
>
> @Noel san mentioned you might have handled a recent correction request from Accounting, so I'd like to confirm the current situation:
>
> - Have you run DataCorrectionCommand (importing a correction_{YYYYMM}.csv) recently? If so, when, and for which month's data?
> - For Accounting's correction requests, do you currently use direct SQL, the command, or both?
> - Do you see any case where the command would be needed in the future?
>
> We're deciding whether to update this command for the upcoming CAP allocation work (ASCA), or disable it if it's no longer used.

---

## Harvey-san's reply (2026-10-05, verbatim)

> Hello @Hayato Kuroda san, @Noel san
>
> **Have you run DataCorrectionCommand (importing a correction_{YYYYMM}.csv) recently? If so, when, and for which month's data?**
> No, this command hasn't been used for months. Instead we are now using this approach:
> https://bizmates.atlassian.net/wiki/x/DYDk_g
> Accounting Team send us a CSV file. Use a specific CSV file to generate an SQL Command based on what data is needed to be processed (INSERT, UPDATE, DELETE)
>
> **2. For Accounting's correction requests, do you currently use direct SQL, the command, or both?**
> We only use direct SQL Execution
> This is the sample Ticket for data correction:
> https://bizmates.atlassian.net/browse/DEVOPS-6706
>
> **3. Do you see any case where the command would be needed in the future?**
> I don't think the command for data correction is needed in the future since this is outdated and needs a constant update every time there's a structure changes in table.
>
> The accounting team is used to follow the approach on the Confluence Page I sent for the couple months.
> You can check on the DEVOPS ticket I shared.

---

## What this establishes (added by Noel — NOT part of the verbatim source)

| Point | Confirmed |
|---|---|
| The command has not run for months | ✅ Harvey-san |
| Corrections use **direct SQL only** (not the command) | ✅ Harvey-san ("We only use direct SQL Execution") |
| A documented replacement process exists (Confluence runbook: Accounting CSV → generated INSERT/UPDATE/DELETE SQL) | ✅ Harvey-san (wiki link + DEVOPS-6706) |
| No foreseen future need | ✅ Harvey-san ("outdated and needs a constant update every time there's a structure change in a table") |
| DevOps corrections use **post-allocation amounts** (so no un-allocated-N hook is needed there) | Per Kuroda-san REF-CAP-13 §4 |

**Implication for 02d:** injecting allocation would maintain dead code; leaving the command runnable keeps the drift risk; **decommissioning** closes the risk at near-zero cost. See `ASCA-ADR-20261005-datacorrection-decommission.md`.

**Known dependency to re-check if this changes:** if DevOps ever reverts to using `DataCorrectionCommand`, the CAP-allocation injection (original 02d scope) must be reconsidered before use (02d Req 4).

> Links are recorded as given by Harvey-san; they point to internal Confluence/Jira and are not fetched here.
