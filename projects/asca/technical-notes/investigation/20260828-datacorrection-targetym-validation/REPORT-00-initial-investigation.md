# DataCorrectionLogic target_ym Validation Gap (20260828)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report |
| **Date** | 2026-08-28 (Reported) · 2026-08-28 (Investigated) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Closed — no action required for DEVOPS-6415 |
| **Audience** | Patrick-san (SDM), Kuroda-san (PM), Dev team |
| **JIRA** | [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) (parent context) |

**Reported by:** Patrick-san (Slack, 2026-08-28)  
**Investigated by:** Noel Palo  
**Environment:** Code analysis (`accounting_related_system_for_freee`, branch `feature/DEVOPS/DEVOPS-6415-ASCM-fix-data-correction-logic`)  
**Period analyzed:** N/A (code-level investigation, no data query)

---

## Summary

DataCorrectionLogic does **not validate** that rows in `correction_{YYYYMM}.csv` have a `target_ym` matching the file's month or the system's processing month. Out-of-month rows would be processed silently. This is not an active bug — Accounting's operational process prevents it — but it is an unguarded edge case.

**Confidence:** Confirmed via code trace. Operational safety confirmed by Kuroda-san (Slack).

---

## Evidence

### Code trace: how dates are derived

**File:** `app/Libs/DataCorrectionLogic.php`, `execute()` method

```php
$targetYm = \App\Libs\CommonUtil::getTargetYm();   // → last month
$now = (new Carbon())->format('Ym');                 // → current month
$filePath = storage_path('app/csv/correction_' . $now . '.csv');  // filename = current month
```

**File:** `app/Libs/CommonUtil.php`, `getTargetFromTo()` method

```php
$targetYear = Carbon::now()->firstOfMonth()->subMonth(1)->year;
$targetMonth = Carbon::now()->firstOfMonth()->subMonth(1)->month;
```

### Derived values (if run in August 2026)

| Variable | Value | Source |
|---|---|---|
| `$now` | `202608` | `Carbon::now()->format('Ym')` — current month |
| `$targetYm` | `202607` | `CommonUtil::getTargetYm()` — previous month |
| Filename loaded | `correction_202608.csv` | Concatenates `$now` |
| Row `target_ym` | User-provided | `$correctionData->target_ym = (int)$data[1]` — column 2 of CSV |

### What's NOT validated

The row's `target_ym` (from CSV column 2) is never compared against:
- `$now` (filename month)
- `$targetYm` (system's processing month = last month)
- Any range limit

The row's `target_ym` is passed directly to operation handlers (`correctDailyRateCalculation`, `createBalanceTransitionWithOrderNumber`, etc.) which use it to locate and modify records in log tables.

### Kuroda-san confirmation (Slack, 2026-08-28 12:11 PM)

> "I think they don't fix the data more than 2 month ago. Every month they need to finalize correct sales data within the month, it should include only the last month data."

---

## Analysis

### Why filename month ≠ system targetYm (by design)

The system is designed so that the batch processes **last month's** data during the **current month**:

1. Monthly batch runs early in the month (e.g., Aug 1) — processes July
2. Errors found → Accounting fills `correction_202608.csv` (named for current month)
3. Rows inside target July data (`target_ym = 202607`)
4. DataCorrectionCommand runs — corrects July's log tables

The 1-month offset between filename and row `target_ym` is intentional. A naive "filename must match row" check would break the valid workflow.

### Why no validation exists

The correction command was built as a manual tool for the Accounting team. The implicit assumption is that Accounting provides correct data — the system trusts the CSV content. This is consistent with the design philosophy of the batch system (no input validation on the CSV beyond the `containts` field check).

### Risk assessment

| Factor | Assessment |
|---|---|
| Has this ever caused a production issue? | No (per Kuroda-san) |
| Could it cause one? | Yes — if Accounting accidentally includes wrong-month rows |
| Likelihood | Very low — manual process with experienced operators |
| Impact if triggered | Wrong month's log data modified silently |
| Detection | Would only surface during monthly reconciliation |

---

## Expected Fix

If desired as a future safety net (not in DEVOPS-6415 scope):

```php
// After parsing $correctionData, before dispatching to handlers:
$twoMonthsAgo = (int) Carbon::now()->subMonths(2)->format('Ym');
if ($correctionData->target_ym < $twoMonthsAgo) {
    Log::warning("Row target_ym ({$correctionData->target_ym}) is older than 2 months. Skipping.");
    $this->errorList[] = $this->createErrorData(
        "対象年月が2ヶ月以上前のデータです。(row: {$correctionData->target_ym})",
        $correctionData
    );
    continue;
}
```

**Why not a strict same-month check:** Row `target_ym` is legitimately 1 month behind `$now` (corrections for July in an August-named file). A strict `target_ym == $now` check would reject all valid rows.

**Effort:** ~30 minutes, standalone ticket.

---

## Scope Assessment

| Dimension | Assessment |
|---|---|
| Severity | Low — operational process prevents the scenario |
| Data loss risk | None currently |
| Tenants affected | Both (Bizmates + Zipan) — same code path |
| Requires immediate action? | No |

---

## Next Steps

- [x] Code trace complete
- [x] Confirmed with Kuroda-san (operational convention)
- [x] Communicated to Patrick-san (Slack reply)
- [ ] Optional: Create standalone ticket for "2-month safety check" if Patrick-san/Kuroda-san want it

**Decision:** No action for DEVOPS-6415. Close investigation.

---

## Cross-Reference

| Document | Relevance |
|---|---|
| `app/Libs/DataCorrectionLogic.php` | The file containing the gap |
| `app/Libs/CommonUtil.php` (`getTargetYm`, `getTargetFromTo`) | Derives the system's target month |
| `app/Libs/CorrectionDataObject.php` | DTO documenting the CSV column structure |
| `projects/asca/technical-notes/jira/epics/DEVOPS-6415/DEVOPS-6415-verification-guide.md` | Explains how DataCorrectionCommand works operationally |
| Slack thread (2026-08-28, Patrick-san → Kuroda-san → Noel) | Source of the question and confirmation |
