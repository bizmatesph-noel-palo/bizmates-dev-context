# ZPR Data Clean-up Runbook — for DevOps (@yijun.he san)

## Document Info

| | |
|---|---|
| **Document type** | Production Runbook |
| **Date** | 2026-09-28 (Authored) · 2026-09-30 (Executed) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | ✅ Cleanup executed 2026-09-30 by Yijun-san (DevOps) — 8 rows deleted. ✅ 10/01 PRE verified (Noel, 2026-10-01) — `product_id=38` now in the monthly-rate table, not daily. ⏳ September FINAL scheduled 10/02 18:00 JST. |
| **Audience** | DevOps (executor), Kuroda-san (PM), Patrick-san (SDM) |
| **Related** | `docs/asc-projects-master-timeline.md`; `projects/ascm/documentation/02-asc-project-changelog.md` §8 |

---

## Summary

Remove **8 incorrect rows** from the **Zipan production** database. These rows belong to a monthly plan (`product_id = 38`, the new Zipan 20-lesson plan) but were mistakenly written into the **daily** rate tables by the 09/01 and 09/03 batch runs.

- **When:** Must be completed **before the 10/01 PRE batch runs** — please finish during **09/30**.
- **Database:** Zipan **production** DB (the `zipan` connection). Run everything below on the Zipan DB.
- **Tool:**
  - Steps 1–4 (checks) — can run in Metabase or a MySQL client (read-only, safe).
  - Steps 5–8 (transaction with DELETE) — **must run in a MySQL client with write access.** Metabase is read-only and cannot run `DELETE` / `COMMIT`.
- **How to run:** one query at a time, in order. Compare each result to the **Expected** line. 🛑 **If any result does not match Expected, STOP and message Noel before continuing.**

---

## ✅ Execution record (2026-09-30)

Executed by **Yijun-san (DevOps)** on **2026-09-30**, within the "finish during 09/30, before the 10/01 PRE" window.

- **Part A (safety checks, Steps 1–4):** all matched Expected — Step 1 = 4 rows, Step 2 = 4 rows, Step 3 = 0 rows, Step 4 = 0 rows. Checkpoint cleared.
- **Part B/C (transaction):** `DELETE` affected **4 + 4 = 8 rows** (4 from `log_daily_rate_calculation_zipan`, 4 from `log_daily_rate_calculation_pre_zipan`). Step 7 pre-commit verification showed `remaining_final = 0` and `remaining_pre = 0`; transaction **committed**. Part C final confirmation: both counts = 0.
- **Result:** the 8 stale `product_id = 38` daily rows (charges 14265–14268) are removed. Delete-only — no re-run.

**Post-cleanup checkpoints:**

- ✅ **10/01 PRE verification — DONE (Noel, 2026-10-01).** The 10/01 PRE batch ran; Metabase confirms **`product_id = 38` now lands in the monthly-rate table (`log_monthly_rate_calculation_pre`), not the daily table** — i.e. the new 20-lesson plan is routed through the monthly pipeline as intended, and no `product_id = 38` rows remain in the daily table. Expected reference figures that were checked against: 202609 rows for 14265/14266 (total = 20, paid_price = ¥41,580 each); 202609 PRE sum for order 10030672 = ¥112,860.
- ⏳ **September FINAL run — scheduled 10/02 (Fri) 18:00 JST** (MonthlyRateCalculationCommand + SendJournalsDataCommand; moved by Kuroda-san for quarterly closing). Not yet run as of this update.

---

## PART A — Verification (safe, read-only. Nothing is changed.)

### STEP 1 — FINAL table: what will be deleted?

```sql
SELECT id, target_ym, charge_id, product_id, paid_price, created_at
FROM log_daily_rate_calculation_zipan
WHERE product_id = 38
  AND charge_id IN (14265, 14266, 14267, 14268);
```

**Expected: exactly 4 rows.**
🛑 If not exactly 4 rows → STOP, share the result with Noel.

### STEP 2 — PRE table: what will be deleted?

```sql
SELECT id, target_ym, charge_id, product_id, paid_price, created_at
FROM log_daily_rate_calculation_pre_zipan
WHERE product_id = 38
  AND charge_id IN (14265, 14266, 14267, 14268);
```

**Expected: exactly 4 rows.**
🛑 If not exactly 4 rows → STOP, share the result with Noel.

👉 **Please save/screenshot the Step 1 and Step 2 results — this is our backup of the rows before deletion.**

### STEP 3 — Safety check (FINAL): does anything depend on these rows?

```sql
SELECT h.id, h.log_sum_calculation_id, h.log_daily_rate_calculation_id, h.created_at
FROM log_sum_calculation_history_zipan h
JOIN log_daily_rate_calculation_zipan d
  ON d.id = h.log_daily_rate_calculation_id
WHERE d.product_id = 38
  AND d.charge_id IN (14265, 14266, 14267, 14268)
  AND h.created_at >= '2026-09-01';
```

**Expected: 0 rows (empty).**
🛑 If ANY rows are returned → STOP, share with Noel. Do NOT delete.

### STEP 4 — Safety check (PRE): same check for the PRE table

```sql
SELECT h.id, h.log_sum_calculation_id, h.log_daily_rate_calculation_id, h.created_at
FROM log_sum_calculation_history_zipan h
JOIN log_daily_rate_calculation_pre_zipan d
  ON d.id = h.log_daily_rate_calculation_id
WHERE d.product_id = 38
  AND d.charge_id IN (14265, 14266, 14267, 14268)
  AND h.created_at >= '2026-09-01';
```

**Expected: 0 rows (empty).**
🛑 If ANY rows are returned → STOP, share with Noel. Do NOT delete.

---

## ✅ CHECKPOINT — only proceed to PART B if ALL of these are true:

- Step 1 = 4 rows
- Step 2 = 4 rows
- Step 3 = 0 rows
- Step 4 = 0 rows

If any differ, do not run Part B. Message Noel.

---

## PART B — Deletion inside a transaction (MySQL client, write access)

> The deletes run inside a transaction. **Nothing becomes permanent until you run `COMMIT`.** If anything looks wrong at any point, run `ROLLBACK` and nothing will have changed.

### STEP 5 — Start the transaction

```sql
SET autocommit = 0;
START TRANSACTION;
```

### STEP 6 — Delete from both tables

```sql
DELETE FROM log_daily_rate_calculation_zipan
WHERE product_id = 38
  AND charge_id IN (14265, 14266, 14267, 14268);
```

**Expected: 4 rows affected.**

```sql
DELETE FROM log_daily_rate_calculation_pre_zipan
WHERE product_id = 38
  AND charge_id IN (14265, 14266, 14267, 14268);
```

**Expected: 4 rows affected.**

### STEP 7 — Verify BEFORE committing (still inside the transaction)

```sql
SELECT
  (SELECT COUNT(*) FROM log_daily_rate_calculation_zipan
     WHERE product_id = 38 AND charge_id IN (14265,14266,14267,14268)) AS remaining_final,
  (SELECT COUNT(*) FROM log_daily_rate_calculation_pre_zipan
     WHERE product_id = 38 AND charge_id IN (14265,14266,14267,14268)) AS remaining_pre;
```

**Expected: `remaining_final = 0` AND `remaining_pre = 0`.**

- ✅ **If both are 0** (and Step 6 affected 4 + 4 rows) → go to STEP 8 (COMMIT).
- 🛑 **If either is NOT 0, or Step 6 did not affect exactly 4 + 4 rows** → run the following to undo everything, then message Noel:

```sql
ROLLBACK;
```

### STEP 8 — Commit (make it permanent)

```sql
COMMIT;
```

---

## PART C — Final confirmation (after COMMIT)

```sql
SELECT
  (SELECT COUNT(*) FROM log_daily_rate_calculation_zipan
     WHERE product_id = 38 AND charge_id IN (14265,14266,14267,14268)) AS remaining_final,
  (SELECT COUNT(*) FROM log_daily_rate_calculation_pre_zipan
     WHERE product_id = 38 AND charge_id IN (14265,14266,14267,14268)) AS remaining_pre;
```

**Expected: both = 0.**

---

## After the clean-up

- Please share the **Part A results (Steps 1–4)** and the **Part C result** so we have a record.
- The **10/01 PRE** batch will then recognize these charges correctly through the monthly pipeline. After it runs, Noel will review the verification figures:
  - `log_monthly_rate_calculation_pre` has 202609 rows for 14265/14266: total = 20, paid_price = ¥41,580 each
  - 202609 PRE sum for order 10030672 = ¥112,860
  - No `product_id = 38` rows in the daily table

### ⏰ Schedule (updated 2026-09-28 by Kuroda-san — quarterly closing)

The September **FINAL** run (MonthlyRateCalculationCommand + SendJournalsDataCommand, normally on the 3rd business day) is moved to **10/02 (Fri) 18:00 JST**.

| Task | Deadline |
|---|---|
| 8-row deletion (Parts A–C above) | **within 09/30** (before the 10/01 PRE) — no change |
| 10/01 PRE verification (the figures above) | **complete by 10/02 15:00 JST** (buffer before the 18:00 FINAL) |
| September FINAL run | **10/02 (Fri) 18:00 JST** |

> Note: any earlier reference to "10/03 FINAL" now means **10/02 18:00 JST**.

---

## ⚠️ Golden rules

1. Run one query at a time, in order.
2. Compare every result to its **Expected** line.
3. If anything does not match — **STOP.** If you are inside the transaction (after STEP 5), run `ROLLBACK`. Then message Noel.
4. Never run `COMMIT` unless STEP 7 shows both counts = 0 and STEP 6 affected exactly 4 + 4 rows.
