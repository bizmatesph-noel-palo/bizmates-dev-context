# Trial Lesson Algorithm POC — Feasibility Analysis (20261021)

**Reported by:** Nice Human Capital
**JIRA Ticket:** [DEVOPS-6824](https://bizmates.atlassian.net/browse/DEVOPS-6824) — POC for Trial Lesson Algorithm
**Investigated by:** Throy Embudo (assisted by Kiro)
**Date:** 2026-10-01 (ticket created)
**Environment:** Code trace across `MBTI_backend`, `bizmates.jp`, `ls-database-migrations` (no DB/runtime data pulled)
**Period analyzed:** Current `feature/ASCA/ASCA-master` checkouts in the workspace

> **Scope note:** This is a **feasibility analysis for a POC request**, not a bug root-cause
> report. It maps how trial-assessor assignment works **today** and assesses what the
> proposed student-type-aware algorithm would require. All claims are code-traced with file
> paths; items that could not be verified are marked **Inferred** or **Not found in workspace**.

---

## 1. Summary

**The ticket's premise is accurate (confirmed by code).** Today every trial ("assessment")
booking is assigned to the available assessor with the highest **KPI6 conversion ratio**,
regardless of student type — and KPI6 is computed from **B2C + B2E enrollments only, with
B2B deliberately excluded**. The proposal to branch by student type (B2C/B2E → conversion +
500–2,000-lesson gate; B2B → B2B-rebookability) is **feasible**, but most of it is **net-new
data work**, not a selection-logic tweak.

**Feasibility verdict:** achievable, **medium effort**, spanning **three in-workspace repos
plus (conditionally) one external NLP service not in this workspace**. The ranking change is
small; the **per-student-type KPI aggregation it depends on does not exist today** and is the
bulk of the work.

**What already exists:** KPI6 conversion ratio (B2C+B2E), a generic rebookability KPI, and
per-record `contract_type`.
**What is net-new:** per-contract-type breakdown of both metrics, a 500–2,000 completed-lessons
gate in the assessor query, and student-type branching in the selection builder.

Confidence: **High** on the current flow and the B2C/B2E-only KPI6 filter (direct code trace).
**Medium** on the exact "completed lessons" column semantics and on whether the external NLP
path must also change (service source not in workspace).

---

## 2. Evidence — how assignment works today

### 2.1 Selection / ranking (MBTI_backend)

- **Entry:** `app/GraphQL/Queries/Student/Assessment.php` → `app/Actions/RecommendedTrainers/GetRecommendedTrainers.php`, which picks the `RecommendedTrainersAssessors` service and toggles NLP-vs-fallback via `config('data_preference.assessment_trainer_assessor')` (`DATA_PREFERENCE_ASSESSMENT_TRAINER_ASSESSOR`).
- **Service:** `app/Services/NlpApi/RecommendedTrainer/RecommendedTrainersAssessors.php` — `fetchRecommendedTrainers()` chooses `getNLPRecommendedTrainers()` (external NLP call) or `getFallbackRecommendedTrainers()`. The readable local algorithm is `getTrainerAvailability()`: availability filter → `leftJoinSub(TrnTeacher::kpiDailySubquery())` → `assessmentAssessorKpiOrder()` → `limit(10)`.
- **The actual ranking:** `app/Builders/TeacherBuilder.php`
  - `kpiDailySubquery()` joins `trn_teacher_kpi_daily` for `kpi_date = today` and selects `MAX(kpi6_ratio) AS assessment_daily`, `MAX(kpi6_assessment) AS assessment_count`.
  - `assessmentAssessorKpiOrder()` (per inline `@jira ARI-156`) always orders `->assessor()->orderBy('kpi.assessment_daily','DESC')->orderBy('kpi.assessment_count','DESC')` — i.e. **rank available assessors by KPI6 ratio desc**, tie-broken by assessment count. **No student-type branching.**

### 2.2 KPI6 conversion ratio (bizmates.jp) — B2C/B2E only, confirmed

- **Computed in:** `fuel/app/classes/libs/TrainerKPIContext.php::trainerKPI6()`. Run by batch `fuel/app/tasks/trainer_kpi.php`; all reads on the `slaveForKPI` connection.
- **Assessment & enrollment counts** both filter `trn_evaluation e JOIN trn_student s` on:
  `e.result=1 (taught) AND e.status=1 (valid) AND e.program_id=0 (assessment) AND e.lesson_datetime < now AND e.contract_type IN (0,2) AND s.department_id NOT IN (<kpi6_except_department_id = 32,67,111,118>)`. Enrollment additionally joins `log_student_tracking` on `enrollment_charge_id IS NOT NULL`.
- **Ratio:** `enrollment_ratio = assessment >= 20 ? (enrollment/assessment)*100 : 0`; zeroed if the trainer no longer holds the `ASSESSOR` role.
- **The decisive filter is `e.contract_type IN (0,2)`.** Per `MBTI_frontend/src/const/plan.js` `StudentModel`: `0 = B2C (private)`, `1 = B2B`, `2 = B2B2C` (the ticket's "B2E"). So KPI6 = **B2C + B2E**, and **B2B (type 1) is excluded** — exactly as the ticket states.
- **Stored in:** `trn_teacher_kpi_daily` / `trn_teacher_kpi` → `kpi6_ratio`, `kpi6_assessment`, `kpi6_enrollments`, `kpi6_points`, `kpi6_stars`.

### 2.3 Rebookability (bizmates.jp) — exists, but not student-type split

- Computed as a KPI1 sub-metric (`vote_type_rebookability = 17`) in `TrainerKPIContext.php`, with `fuel/app/classes/libs/kpi/Rebookability.php` + `kpiModel::getRebookabilityAverage()`.
- Columns `kpi1_rebookability`, `kpi1_rebookability_votes`, `kpi1_rebookability_stars` added via `ls-database-migrations/.../2025_10_20_073200_add_rebookability_columns_to_teacher_kpi_tables.php`.
- **Gap:** it is an **all-student-type average** and is **not** selected by `kpiDailySubquery()` nor used in `assessmentAssessorKpiOrder()`. A **B2B-only** rebookability does not exist.

### 2.4 Completed-lessons count

- No general "total completed lessons" field is used in the assessor-selection path. `getStartingLevelLessonCount()` counts **assessment Level 0/1 lessons only** (used for the beginner branch `starter_level_assessment_count > 10`, `@ref DEVOPS-707`).
- `trn_teacher_kpi_daily` has lesson-tally columns (e.g. `lessons`, `lessons_taught_total`, seen in `fuel/app/tasks/hc_weekly_stats_combined.php`) — the closest existing tallies, but **not wired into** the trial-assignment query, and their exact "completed lessons" semantics are **unverified (Inferred)**.

### 2.5 Student-type representation

- `trn_student.contract_type`, `trn_student_book.contract_type`, `trn_evaluation.contract_type` (0=B2C, 1=B2B, 2=B2B2C/"B2E"). KPI6 already *filters* on type but does **not break results down** by type. No per-type KPI aggregates exist.

---

## 3. Analysis — what the POC requires

| Proposed behavior | Exists today? | Work required |
|---|---|---|
| B2C/B2E → rank by trial-to-paid conversion | **Yes** (KPI6 ratio, B2C+B2E) | Reuse `kpi6_ratio`; already the default ordering. |
| …prioritizing trainers with **500–2,000 completed lessons** | **No** gate in the path | Net-new: a completed-lessons column (confirm/define semantics) + a `WHERE`/ordering gate in `kpiDailySubquery()` / `assessmentAssessorKpiOrder()`. |
| B2B → rank by **B2B-only Rebookability** | **No** (generic rebookability only) | Net-new: per-contract-type rebookability aggregation (bizmates.jp) + new column (ls-db) + select/order (MBTI_backend). |
| Break evaluations down by **student type** | **No** per-type aggregates | Net-new per-`contract_type` aggregation in `trainerKPI6()` (+ a B2B rebookability pass) + new KPI columns. |
| **Student-type branching** at assignment | **No** | Net-new branch in `TeacherBuilder` / `RecommendedTrainersAssessors` keyed on the booking's `contract_type`. |

### Cross-repo shape of the change
1. **ls-database-migrations** — new per-type KPI columns (e.g. B2B rebookability; optionally per-type conversion). Schema-first, since both other repos read these.
2. **bizmates.jp** — extend `trainerKPI6()` / add a B2B-rebookability aggregation to populate the new columns (batch, `slaveForKPI`).
3. **MBTI_backend** — select the new columns in `kpiDailySubquery()` and add student-type branching in `assessmentAssessorKpiOrder()` / `RecommendedTrainersAssessors`.
4. **External NLP service (conditional)** — if `DATA_PREFERENCE_ASSESSMENT_TRAINER_ASSESSOR=true` in the target env, the **preferred** ranking path is the NLP service, whose source is **not in this workspace**. A parallel change there may be required; otherwise the POC only affects the local fallback. **Needs confirmation.**

---

## 4. Scope assessment

- **Severity/urgency:** POC, BACKLOG, Medium — no production incident.
- **Blast radius:** touches trainer KPI batch + assessor assignment (student-facing trial booking). Behind the NLP-vs-fallback config flag.
- **Data dependency:** per-student-type KPI aggregation is the critical path — it gates both branches.
- **External dependency risk:** the NLP service being out-of-workspace is the biggest unknown for sizing.
- **Reversibility:** additive (new columns + branched ordering); low risk to existing flows if gated.

---

## 5. Open questions (for the POC / estimation)

1. **"Completed lessons" definition** for the 500–2,000 gate — which column/metric is authoritative (`lessons_taught_total`? a new count?). Confirm semantics before relying on it.
2. **NLP path in scope?** Is the target env on the NLP service or the fallback for assessor recommendation? If NLP, is that repo available and in scope?
3. **"B2E" = B2B2C (contract_type 2)?** Confirm the ticket's "B2E" maps to type 2 (the code strongly implies it).
4. **B2B-rebookability definition** — same vote metric filtered to `contract_type = 1`, or a different measure?
5. **500–2,000 as a hard filter or a soft boost?** (Exclude out-of-range trainers, or just rank them lower?)
6. **Tie-breakers / fallback** when no in-range assessor is available (mirror the existing beginner-fallback pattern?).

---

## 6. Cross-reference

- `MBTI_backend/src/app/Builders/TeacherBuilder.php` — `kpiDailySubquery()`, `assessmentAssessorKpiOrder()` (the ranking to change)
- `MBTI_backend/src/app/Services/NlpApi/RecommendedTrainer/RecommendedTrainersAssessors.php` — NLP-vs-fallback entry
- `MBTI_backend/src/app/Actions/RecommendedTrainers/GetRecommendedTrainers.php` — service selection + config flag
- `bizmates.jp/fuel/app/classes/libs/TrainerKPIContext.php` — `trainerKPI6()` (B2C/B2E filter), rebookability fields
- `bizmates.jp/fuel/app/tasks/trainer_kpi.php` — KPI batch runner
- `MBTI_frontend/src/const/plan.js` — `StudentModel` contract-type mapping (0/1/2)
- `ls-database-migrations/.../2025_10_20_073200_add_rebookability_columns_to_teacher_kpi_tables.php` — rebookability columns (no type split)
- `ls-database-migrations/.../2025_07_03_055626_create_trn_teacher_kpi_table.php` — KPI6 columns

---

## 7. Next steps

1. Answer the §5 open questions with HC/PM (especially completed-lessons definition and NLP scope).
2. Confirm whether the external NLP recommendation service is in scope and available.
3. If proceeding to estimation: size the three in-workspace layers (ls-db columns → bizmates.jp aggregation → MBTI_backend branching) separately, flag the NLP service as a conditional external line item.
