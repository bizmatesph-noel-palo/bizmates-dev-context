# Engineering Knowledge Base — The ASC Project Journey

This knowledge base documents real engineering problems encountered during the Bizmates ASC (Accounting System Changes) project. It's structured as a story: what we walked into, what broke while building, and what systemic issues remain.

---

## Start Here

| Document | What It Covers |
|----------|---------------|
| [Design Context](00_Design_Context.md) | How the legacy architecture created the conditions for these problems. Read first for the "why." |

---

## Act 1 — What We Walked Into

The ASC project's goal was to add a monthly rate report (revenue by lesson consumption). This topic covers the upstream design constraint that made everything harder.

| # | Topic | JIRA | TL;DR |
|---|-------|------|-------|
| 01 | [Uniform ticket validity window](01_Uniform_Ticket_Validity_Window.md) | ASC-254, 258, 264, 266, 267 | Tickets carry a generic 60-day expiry instead of business-rule expiry. The CTE must recompute what upstream should have stored. |

---

## Act 2 — What We Built and What Broke

Bugs discovered while building the monthly commands — ordered roughly by when the team encountered them during development.

| # | Topic | JIRA | TL;DR |
|---|-------|------|-------|
| 02 | [Fan-out join doubling values](02_Fan_Out_Join_Doubling.md) | ASC-236 | 1:N join inflated SUM(paid_price) by ticket count. ¥12,980 became ¥389,400. |
| 03 | [Wrong identity on derived rows](03_Wrong_Identity_On_Derived_Rows.md) | ASC-244 | Refund rows carried the original charge's ID instead of their own. |
| 04 | [DateTime range boundary](04_DateTime_Range_Boundary.md) | ASC-277 | BETWEEN with DATE excludes records after midnight on the last day. |
| 05 | [Invisible records — no log entry](05_Invisible_Records_No_Log_Entry.md) | ASC-269 | Charges with deleted tickets never enter the pipeline. |
| 06 | [Complex CTE boundary logic](06_Complex_CTE_Boundary_Logic.md) | ASC-211, 254, 258, 260, 261, 205, 234, 232 | Recursive CTE fails at edges: first/last charge, period transitions, lookahead, regressions. |
| 07 | [Data leaking across periods](07_Data_Leaking_Across_Periods.md) | ASC-267 | Expired charges produce ghost rows in next month's output. |
| 08 | [Computation at report time vs storage time](08_Refund_Logic_Placement.md) | ASC-269, 276 | Late refunds invisible because computed at CSV time, not stored in log. |
| 09 | [Orphaned records — missing dependencies](09_Orphaned_Records.md) | ASC-280 | Hard-deleted tickets orphan their parent charges from reports. |
| 10 | [Source table mismatch (Pre/Final)](10_Pre_Final_Table_Mismatch.md) | ASC-274 | Pre command read from Final table — empty reports looked like "no data." |
| 11 | [Rounding loss accumulation](11_Rounding_Loss_Accumulation.md) | ASC-239 | floor(14107/15) × 15 = ¥14,100. Missing ¥7 on full refunds. |
| 12 | [Stale aggregation data](12_Stale_Aggregation_Data.md) | ASC-203 | Re-runs doubled summaries because old rows weren't cleaned up. |
| 19 | [INTERVAL offset vs DATETIME boundary](19_Interval_Offset_Datetime_Boundary.md) | ASC-296 | `INTERVAL 1 DAY` resolves to midnight — excludes DATETIME records with time past 00:00:00. Need INTERVAL 2 DAY. |
| 20 | [Lookahead premature expiry](20_Lookahead_Premature_Expiry.md) | ASC-301 | 2-day lookahead fires one month too early for charges with next-month rows in the CTE. Gate on `rn = total_rows`. |

---

## Act 3 — Systemic Issues We Identified

Design debt documented during the project. These are structural problems that require larger refactoring and remain as known risks.

| # | Topic | Status | TL;DR |
|---|-------|--------|-------|
| 13 | [Tenant code duplication](13_Tenant_Code_Duplication.md) | Mitigated (review process) | Every fix applied to Bizmates must be manually repeated for Zipan. |
| 14 | [Pre/Final logic duplication](14_Pre_Final_Logic_Duplication.md) | Mitigated (review checklist) | 2,500 lines duplicated between Pre and Final — every fix applied twice. |
| 15 | [Unsafe delete scope for re-runs](15_Unsafe_Delete_Scope.md) | Mitigated (process discipline) | Re-running March's batch can wipe April's data. |
| 16 | [Global mutable state](16_Global_Mutable_State.md) | Low risk (single-month ops) | Dates leak between processing iterations via mutable class properties. |
| 17 | [No concurrency protection](17_No_Concurrency_Protection.md) | Low risk (cron spacing) | Concurrent batch runs corrupt shared log tables. |
| 18 | [Batch sequencing dependency](18_Batch_Sequencing_Dependency.md) | Mitigated (scheduling discipline) | Skipping a month permanently loses those charges from reports. |

---

## How to Use This Knowledge Base

- **Reading as a story:** Start with the Design Context, then Topic 01. Follow the numbering — it mirrors the team's discovery journey.
- **For a new project:** Browse Act 3 first. If your system has batch processing, multi-tenant, or financial data, these are the traps to avoid upfront.
- **For code review:** Use the Prevention Checklist at the bottom of each page.
- **For incident investigation:** Match symptoms to a topic's TL;DR to find root cause quickly.
