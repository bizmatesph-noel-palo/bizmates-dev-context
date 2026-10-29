# DEVOPS-6824 — Project Context

> Standalone investigation context. This is NOT an ASC/accounting project — it concerns
> the Trial Lesson assessor-assignment algorithm (trainer KPI / conversion domain).

---

## What this is

**DEVOPS-6824 — "POC for Trial Lesson Algorithm"** — a feasibility/POC request to make
trial-lesson **assessor assignment** student-type aware.

- **Type:** Task (POC) · **Status:** BACKLOG · **Priority:** Medium
- **Reporter:** Nice Human Capital · **Assignee:** Churchil Siao
- **Created:** 2026-10-01 · **Approved:** Marlee Cuenco, 2026-10-01
- **JIRA:** [DEVOPS-6824](https://bizmates.atlassian.net/browse/DEVOPS-6824)

### The ask
Today, trial bookings are assigned to the available Assessor with the highest conversion
ratio (KPI6) — regardless of student type. KPI6 only accounts for B2C + B2E. The proposal:

- **B2C / B2E students** → assign the available Assessor with the highest trial-to-paid
  conversion rate, **prioritizing trainers with 500–2,000 completed lessons**.
- **B2B students** → assign the available Assessor with the highest **Rebookability score
  from B2B students**.

This requires breaking down evaluations by student type (B2C / B2E / B2B).

### Recommended algorithm (Rachel Ann Benzon, 2026-10-07)
Prioritize trainers with 500–2,000 completed lessons, ranked by trial-to-paid conversion
rate, so trial students match experienced trainers with strong conversion performance.

---

## Repos involved (reference-only for this POC)

| Repo | Role |
|---|---|
| `MBTI_backend` | Runtime assessor **selection/ranking** (GraphQL). Where student-type branching must go. |
| `bizmates.jp` | **KPI6 conversion** + rebookability computation (FuelPHP batch, `slaveForKPI`). |
| `ls-database-migrations` | Schema for the KPI tables + `trn_student.contract_type`. |
| External **NLP service** | Preferred ranking path (`fetchNlpApi`). **Not in this workspace.** |

---

## Key artifacts

| Document | Location |
|---|---|
| Feasibility investigation (REPORT-00) | `technical-notes/investigation/20261021-trial-lesson-algorithm/REPORT-00-feasibility.md` |
