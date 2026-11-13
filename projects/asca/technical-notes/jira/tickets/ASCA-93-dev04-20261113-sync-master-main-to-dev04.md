# ASCA-93 — DEV04 - 20261113 sync master/main into deployment/dev04

> **Created in JIRA 2026-11-13 as [ASCA-93](https://bizmates.atlassian.net/browse/ASCA-93)** — Task under ASCA-9, Priority Medium, assigned to Throy-san, status To Do. Same short format as ASCI-16 / ASCI-24. This file is the source of record.

**Type:** Task
**Parent / Epic:** ASCA-9 (ASCA — Project Scaffolding)
**Priority:** Medium
**Assignee:** Throy-san
**Related:** ASCI-24 (CAP-382 merge), CIP-218 merge (draft)

---

## Description

Bring `deployment/dev04` up to date with the production branch (`master` / `main`) in each repo, so DEV04 matches production before the CAP-382 / CIP-218 merges and the next ASCA / ASCI retests. Same approach as the earlier syncs (`sync/dev04/master-to-dev04-<date>` / `sync/dev04/main-to-dev04-<date>`, last done 2026-10-02).

| Repo | Source | Target | Commits in source not on dev04 (2026-11-13) |
|---|---|---|---|
| `bizmates.jp` | `master` | `deployment/dev04` | 146 |
| `MBTI_backend` | `main` | `deployment/dev04` | 163 |
| `ls-database-migrations` | `main` | `deployment/dev04` | 68 |
| `accounting_related_system_for_freee` | `main` | `deployment/dev04` | 1 |

Counts are from local clones; only `bizmates.jp` was fetched on 2026-11-13, so refetch before starting. `ls-database-migrations` changes may need the migrations run on DEV04.

Log DEV04 sync work here: one `sync/dev04/...-20261113` branch and PR per repo, any conflicts, migrations run, and confirming the DEV04 server pulled the code.
