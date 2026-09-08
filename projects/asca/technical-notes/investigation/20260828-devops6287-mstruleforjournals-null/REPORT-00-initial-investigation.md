# SendJournalsData crash — mst_rule_for_journals null for B2B_App (20260828)

## Document Info

| | |
|---|---|
| **Document type** | Investigation Report |
| **Date** | 2026-08-28 (Reported) · 2026-08-28 (Investigated + Resolved) |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Status** | Resolved — data fix applied by Wu-san on DEV04 |
| **Audience** | Patrick-san (SDM), Kuroda-san (PM), Dev team |
| **JIRA** | [DEVOPS-6287](https://bizmates.atlassian.net/browse/DEVOPS-6287) (root cause), [DEVOPS-6415](https://bizmates.atlassian.net/browse/DEVOPS-6415) (blocked by this) |

**Reported by:** Noel Palo (during DEVOPS-6415 smoke test on DEV04)  
**Investigated by:** Noel Palo  
**Resolved by:** Wu-san (data fix SQL)  
**Environment:** DEV04 (`deployment/dev04` branch)  
**Period analyzed:** target_ym `202601`

---

## Summary

`SendJournalsDataCommand` crashed with "Attempt to read property `product_type` on null" at line 275. Root cause: DEVOPS-6287 deployed code that routes B2B + BizmatesApp to a new segment2 tag (B2B_App = 1622735), but the `mst_rule_for_journals` row on DEV04 still had the old segment2_id (261928). Query returned null → crash.

**Confidence:** Confirmed via code trace + Wu-san's fix query.

---

## Evidence

### Error log

```
[2026-08-28 15:44:43] local.INFO: SumList：ID9678, PT:100, did:10090, price:198
[2026-08-28 15:44:43] local.ERROR: ErrorException: Attempt to read property "product_type" on null
    in /var/www/bizmates.jp/laravel/app/Libs/SendJournalsDataLogic.php:275
```

### Code path (traced)

1. `log_sum_calculation` row: `product_type=100` (App), `department_id=10090`, `paid_price=198`
2. `MstCodeChange::getChangeCodeToFreeeCode(1, 100)` → returns `236270504` (BizmatesApp)
3. `CommonUtil::getContractTypeInfo(236270504, 10090, $contractType)`:
   - Not Zipan, not Coaching → falls to Bizmates path (`masterDataType = 2`)
   - `getSegment2Id(10090, $contractType)` → `10090` not in Partner list → returns `$contractType` (likely `1` = B2B)
   - **DEVOPS-6287 branch hit:** `$contractType == B2B (1)` AND `$freeeProductType == BizmatesApp (236270504)` → TRUE
   - Queries: `MstCodeChange::getChangeCodeToFreeeCode(2, 4)` → returns `1622735` (B2B_App segment2_id)
4. `MstRuleForJournals::getMstRuleForJournals(1622735, 236270504)` → **null** (no row with this segment2_id exists yet)
5. Line 275: `$mstRuleForJournals->product_type` → crash

### Config values (from `config/code.php`)

| Key | Value |
|---|---|
| `freeeProductType.BizmatesApp` | `236270504` |
| `segment2Id.B_B2B` | `261928` |
| B2B_App (new, DEVOPS-6287) | `1622735` |
| `contractType.B2B` | `1` (array index) |
| `contractType.B2B_App` | `4` (array index, from `config/const.php`) |

### Root cause

DEVOPS-6287 introduced two changes:
1. **Code:** Added a branch in `getContractTypeInfo()` that routes `B2B + BizmatesApp` to query `mst_code_change` with `code=4` (B2B_App), returning segment2_id `1622735`
2. **Data:** Requires `mst_rule_for_journals` row `id=102` to have `segment2_id = 1622735` instead of `261928`

The **code** was deployed to DEV04 (in the `deployment/dev04` branch). The **data migration** (UPDATE of row 102) had not been run on DEV04's database yet.

---

## Analysis

This is a **code-data deployment mismatch** — the code expects data that doesn't exist yet. The pattern is:

```
Code deployed (routes to new segment2_id) → Data not updated (still has old segment2_id) → Query returns null → crash
```

This only surfaces when a non-zero App charge exists for a B2B department. Before ASCA/CAP, App charges always had `paid_price=0` and were skipped by the `if ($sumList->paid_price != 0)` check. The DEV04 test data has a ¥198 App charge that exposed the gap.

### Why it wasn't caught earlier

- Production hasn't run DEVOPS-6287 with non-zero App charges yet
- DEV04 test data included App charges with non-zero prices (likely from CAP test seeding or manual testing)
- The previous batch run may have been on a branch without DEVOPS-6287's code

---

## Resolution

### Data fix (Wu-san, 2026-08-28)

```sql
USE bizmates_new;

-- Add B2B_App mapping to mst_code_change
INSERT INTO mst_code_change (master_data_type, product_id, code, freee_code, item_name, description, created_at, updated_at)
VALUES (2, NULL, 4, 1622735, 'B2B_App', 'Segment 2 Tag for Bizmates B2B App', NOW(), NOW());

-- Update existing rule row to use new B2B_App segment2_id
UPDATE mst_rule_for_journals SET segment2_id = 1622735 WHERE id = 102;
```

**What this does:**
- INSERT: Creates the `mst_code_change` row so `getChangeCodeToFreeeCode(2, 4)` returns `1622735`
- UPDATE: Changes rule row 102's `segment2_id` from `261928` (B_B2B) to `1622735` (B2B_App) so `getMstRuleForJournals(1622735, 236270504)` finds the row

### Defensive code fix (not yet applied — separate ticket)

`getMstRuleForJournals()` can return null for any unmapped combination. The code at line 275 doesn't null-check. A 5-line guard would prevent this class of crash:

```php
$mstRuleForJournals = MstRuleForJournals::getMstRuleForJournals($freeeContractType, $freeeProductType);
if ($mstRuleForJournals === null) {
    Log::error("No mst_rule_for_journals for segment2_id={$freeeContractType}, product_type={$freeeProductType}. Skipping ID: {$sumList->id}");
    continue;
}
```

---

## Scope Assessment

| Dimension | Assessment |
|---|---|
| Severity | Low on DEV04 (test env). Would be High if hit in production. |
| Caused by | DEVOPS-6287 code-data mismatch (not DEVOPS-6415) |
| DEVOPS-6415 impact | Blocked smoke test — resolved once data fix applied |
| Production risk | Low — non-zero App charges don't exist in prod yet (CAP not live) |

---

## Next Steps

- [x] Root cause identified (code-data mismatch from DEVOPS-6287)
- [x] Data fix provided by Wu-san
- [ ] Apply fix on DEV04 and re-run smoke test
- [ ] Consider defensive null-check as separate ticket (prevents future crashes for ANY missing mapping)

---

## Cross-Reference

| Document | Relevance |
|---|---|
| `app/Libs/SendJournalsDataLogic.php:275` | Crash location |
| `app/Libs/CommonUtil.php:727-731` | DEVOPS-6287 B2B_App routing code |
| `app/Models/MstRuleForJournals.php` | Query that returns null |
| `config/code.php` | freeeProductType.BizmatesApp = 236270504 |
| `config/const.php` | contractType B2B_App = 4 |

---

## Key Insight: Freee Journal Mapping Chain

For future reference, the full chain that must be consistent when adding new product/segment combinations:

```
product_type (log_sum_calculation)
  → mst_code_change (master_data_type=1, code=product_type) → freee_code (freeeProductType)
    → getContractTypeInfo() resolves segment2_id routing
      → mst_code_change (master_data_type=2, code=segment2_id) → freee_code (freeeContractType)
        → mst_rule_for_journals (segment2_id=freeeContractType, product_type=freeeProductType) → journal rules
```

ALL FOUR must exist and be consistent. If any link is missing, `getMstRuleForJournals()` returns null and the batch crashes.
