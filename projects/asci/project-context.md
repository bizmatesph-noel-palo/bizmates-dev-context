# ASCI — Project Context

> Load this at the start of each ASCI session.
> Also load `projects/asca/project-context.md` for the shared framework context.
> If context gets compacted, re-read both files before continuing.

---

## What ASCI Is

**ASCI (ASC for CIP)** adds Coaching Intensive Plan allocation to the shared framework built by ASCA. It's a configuration exercise — same formula, same injection point, different plan_ids and reference prices.

**JIRA:** [ASCI Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/summary) · [Backlog](https://bizmates.atlassian.net/jira/software/c/projects/ASCI/boards/2793/backlog)

**Scope:** Bizmates-only. Reuses everything ASCA built.

---

## Key Info

| Item | Value |
|---|---|
| Project code | ASCI |
| Full name | ASC for CIP (Coaching Intensive Plan) |
| Upstream project | CIP (Jefferson's team) |
| Code repo | `accounting_related_system_for_freee`, `ls-database-migrations` |
| Lead | Noel Palo (overall) |
| Sub-Lead | Orlino Monares |
| Developer | Cristoff Danganan |
| SDM | Patrick-san |
| PM | Kuroda-san |
| Deadline | 2026/12/17 |
| First batch run | 2027/01/01 |
| Depends on | ASCA (shared foundation must be complete first) |

---

## What ASCI Adds (on top of ASCA)

1. **CIP Detection:** `CoachingIntensivePlanEnum` (plans 1028–1032, product 10022)
2. **CIP Reference Price:** L_coaching = ¥84,020 (= plan ¥88,000 − L_app ¥3,980)
3. **Config:** Add CIP rows to `mst_alloc_reference_prices` seeder
4. **Testing:** DEV04 validation for CIP plans

**Estimated effort:** 1–1.5 weeks (after ASCA foundation is complete)

---

## CIP-Specific Data

| Item | Value |
|---|---|
| Plan IDs | 1028–1032 (5 plans, all new — no historical data) |
| Coaching product_id | 10022 (Coaching Intensive — new product) |
| App product_id | 10021 (same as CAP) |
| L_coaching | ¥84,020 (plan price minus L_app) |
| L_app | ¥3,980 |
| Date filter needed? | No (new plan_ids, no history) |

---

## Related Projects

| Code | JIRA | Relationship |
|---|---|---|
| ASCA | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASCA/boards/2792/backlog) | Sister project — builds the foundation ASCI depends on |
| ASC (ASCM) | [Board](https://bizmates.atlassian.net/jira/software/c/projects/ASC/boards/1186/backlog) | Base system |
| CIP (upstream) | — | Creates the charges ASCI allocates |

---

## Key Documents

| Document | Location |
|---|---|
| Technical design (authoritative) | `docs/asc-allocation-framework-technical-design.md` |
| Master timeline | `docs/asc-projects-master-timeline.md` |
| Upstream CIP research | `research/CIP/` |
| ASCA project context | `projects/asca/project-context.md` |
| Plans & products reference | `domain-knowledge/plans-and-products.md` |
