# ASC Allocation Framework — Proposed DB Design (CAP / CIP)

**Source:** Kuroda-san (Confluence)  
**Status:** DB Design proposal — review requested  
**Date received:** 2026-08-10  
**Scope:** Database design only. Effort re-estimation is requested but not included here.  
**Responds to:** ASC for CAP & CIP — Revised Estimation (Post-ASCH Cancellation), Noel Palo, 2026-08-08

---

## Key Decisions & Differences from Estimate

| # | Topic | Our estimate (2026-08-08) | This design | Effort impact |
|---|---|---|---|---|
| D-1 | Number of tables | ~6 generic `asc_alloc_*` | 10 tables + 1 view | Increase |
| D-2 | Reference prices | Application config | DB master with effective dating (`asc_alloc_reference_prices`) | Small increase Phase 1, large decrease in risk |
| D-3 | Bundle layer | Not specified | Normalized: `asc_alloc_bundles` + `asc_alloc_bundle_charges` | +1 migration, +1 join |
| D-4 | Contract-period table | Not specified | Dropped (not needed — read from charge directly) | Decrease |
| D-5 | Detection logic | Not specified | Per-project Strategy in code (not config table) | Same |
| D-6 | Failure isolation | Listed but mechanism not specified | Structural: `asc_alloc_deliveries` table | Small increase Phase 6 |
| D-7 | proration_basis | Not mentioned | Dropped (not needed for CAP/CIP) | Decrease |
| D-8 | Rounding | floor() | Same — floor adopted | Same |
| D-9 | Dependencies D-1 to D-4 | New open items | Re-mapped to existing tracked items | Same |
| D-10 | Start date | "TBD pending requirements" | Steps 1–5 unblocked — work can start now | Same |

## Tables (10 + 1 view)

1. `asc_alloc_calculation_runs` — run management (+ `project_code`)
2. `asc_alloc_source_documents` — immutable snapshots
3. `asc_alloc_bundles` — bundle header (primary_charge_id, contract attrs, match_rule)
4. `asc_alloc_bundle_charges` — one row per product in bundle (always 2 today)
5. `asc_alloc_groups` — one bundle × one month (ΣN, ΣP, is_balanced)
6. `asc_alloc_prorations` — core: one row per product per group (L, ratio, N, P, adjustment)
7. `asc_alloc_reference_prices` — allocation weights (effective-dated master)
8. `asc_alloc_sum_calculation` — Freee aggregation (no send_date — see deliveries)
9. `asc_alloc_sum_calculation_history` — trace: summary → allocation rows
10. `asc_alloc_deliveries` — Freee/CSV/email attempt tracking
11. `v_asc_alloc_prorations_active` — view for active-run queries

## Formula

```
P_app      = floor( N × L_app / (L_coaching + L_app) )
P_coaching = N − P_app  (absorbs remainder)

Freee adjustment:
  Coaching: P_coaching − N = −P_app  (decrease)
  App:      P_app − 0 = +P_app       (increase)
  Net: zero
```

## Validation Invariants

| # | Condition | Level | If it fails |
|---|---|---|---|
| V-1 | ΣP = ΣN | Group | Cannot finalize |
| V-2 | Σ adjustment_amount = 0 | Run | Cannot finalize |
| V-3 | No row has bundle_status ≠ 0 | Run | Warning only |
| V-4 | All applied reference-price rows are effective | Run | Cannot finalize |
| V-5 | Only one active final run per (project_code, target_ym) | Global | Guaranteed by transaction |

## Implementation Order (from Kuroda-san)

| # | Step | Blocked by |
|---|---|---|
| 1 | Naming agreement, then 10 migrations + structure tests | O-3 only |
| 2 | Models, resources, enums, run lifecycle service | None |
| 3 | Reference-price master and price resolution service | None |
| 4 | Detection Strategy and bundle generation | O-1 (CAP only) |
| 5 | Allocation engine and validations V-1 to V-5 | None |
| 6 | Refund allocation (record_kind = 1) | None |
| 7 | Summary aggregation, Freee thin sender, deliveries | CIP RA-05 |
| 8 | CSV generation and unified email orchestrator | CIP RA-13 |
| 9 | Reversal (record_kind = 2) | O-4 |

**Steps 1–5 are unblocked.** Work can start now.

## Open Items

| ID | Item | Owner | Blocks |
|---|---|---|---|
| O-1 | CAP dedicated App product_id | CAP app team | CAP detection only |
| O-2 | Asymmetric discount assumption (CIP RA-04) | Accounting | If rejected, proration_basis comes back |
| O-3 | `asc_alloc_` prefix naming convention | Engineering team | Step 1 (migrations) |
| O-4 | B2B App start → bundled App reversal logic | Accounting + CAP app | Step 9 |
| O-5 | CIP reference prices | Business + Accounting | CIP finalize + QA only |

## Reviewer Questions (for us)

1. Is the table structure implementable as described? (Section 8)
2. Are the 10 differences acceptable, and how do they change the effort? (Section 3)
3. Is the implementation order realistic? (Section 11)
4. O-3: decide the table prefix (`asc_alloc_*` vs `trn_asc_alloc_*` / `log_asc_alloc_*`)

---

*Filed by: Noel Palo, 2026-08-10*
