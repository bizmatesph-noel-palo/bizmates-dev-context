# Freee Journal Mapping Chain

## What This Is

The Freee journal pipeline resolves 4 linked tables to determine how a revenue row becomes a Freee journal entry. All 4 links must exist and be consistent. If any link is missing, `getMstRuleForJournals()` returns null and the batch crashes.

## The Chain

```
log_sum_calculation.product_type (e.g., 100 = App)
│
▼ Step 1: product_type → freeeProductType
mst_code_change WHERE master_data_type=1, code={product_type}
  → returns freee_code (e.g., 236270504 for BizmatesApp)
│
▼ Step 2: resolve segment2 routing
CommonUtil::getContractTypeInfo($freeeProductType, $departmentId, $contractType)
  → determines masterDataType (2=Bizmates, 3=Zipan, 4=Coaching)
  → resolves segment2_id via getSegment2Id() (B2C=0, B2B=1, B2B2C=2, Partner=3)
  → special cases: DEVOPS-6287 routes B2B+BizmatesApp to code=4 (B2B_App)
│
▼ Step 3: segment2_id → freeeContractType
mst_code_change WHERE master_data_type={masterDataType}, code={segment2_id or special code}
  → returns freee_code (e.g., 1622735 for B2B_App, or 261928 for B_B2B)
│
▼ Step 4: look up journal rules
mst_rule_for_journals WHERE segment2_id={freeeContractType} AND product_type={freeeProductType} AND status=1
  → returns: department_id, segment1_id, segment2_id (the actual Freee dimensions for the journal entry)
```

## When This Matters

You need to verify this chain when:
- Adding a new product_type to the system
- Adding a new segment2 tag (like B2B_App)
- ASCA allocation changes `paid_price` from 0 to non-zero for App (makes previously-skipped rows hit the pipeline)
- Any upstream project introduces new plans/products that flow through the accounting batch

## Known Configurations

### Product Type Mappings (mst_code_change, master_data_type=1)

| product_type code | freee_code | Name | Notes |
|---|---|---|---|
| 100 | 236270504 | BizmatesApp | App product |
| 9 | 191155067 | BizmatesCoaching | Coaching 15/30min |
| (various) | 191155084 | Zipan | Zipan products |
| (tickets) | 191155070 | Tickets | Lesson tickets |

### Segment2 Routing (mst_code_change, master_data_type=2)

| code | freee_code | Name | Notes |
|---|---|---|---|
| 0 | 261926 | B_B2C | Bizmates B2C |
| 1 | 261928 | B_B2B | Bizmates B2B |
| 2 | 261927 | B_B2B2C | Bizmates B2B2C |
| 3 | 261929 | B_Partner | Bizmates Partner |
| 4 | 1622735 | B2B_App | Bizmates B2B App (DEVOPS-6287) |

### Special Routing Rules

| Condition | What happens | Added by |
|---|---|---|
| `freeeProductType` in `freeeZipanCodes` | Routes to `masterDataType=3` (Zipan) | Original |
| `freeeProductType == bizmatesCoaching` or `bizmatesVersant` | Routes to `masterDataType=4` (Coaching) | Original |
| `contractType == B2B` AND `freeeProductType == BizmatesApp` | Uses `code=4` (B2B_App) instead of `code=1` (B2B) | DEVOPS-6287 |
| Everything else | Routes to `masterDataType=2` (Bizmates) with standard segment2_id | Original |

## Failure Mode

If any step returns null:
- Step 1 null → `$freeeProductType = null` → downstream queries fail
- Step 3 null → `$freeeContractType = null` → `getMstRuleForJournals(null, ...)` returns null
- Step 4 null → **crash** at `$mstRuleForJournals->product_type` (no null check in existing code)

The batch `catch` block handles the crash gracefully (logs error, continues to END), but the journal for that sum row is lost.

## Code Locations

| Component | File | Method/Line |
|---|---|---|
| Step 1 | `app/Models/MstCodeChange.php` | `getChangeCodeToFreeeCode()` |
| Step 2 | `app/Libs/CommonUtil.php` | `getContractTypeInfo()` (~line 705) |
| Step 2 (segment2) | `app/Libs/CommonUtil.php` | `getSegment2Id()` (~line 668) |
| Step 4 | `app/Models/MstRuleForJournals.php` | `getMstRuleForJournals()` |
| Caller | `app/Libs/SendJournalsDataLogic.php` | `sendFreeeJournals2()` (~line 232-238) |

## Repo

`accounting_related_system_for_freee` (batch accounting system)

## History

- **2026-08-28:** DEVOPS-6287 added B2B_App routing. Code-data mismatch on DEV04 caused crash (missing UPDATE on `mst_rule_for_journals` row 102). Fixed by Wu-san.
- **ASCA (future):** When allocation makes App `paid_price > 0`, these rows will hit the pipeline for the first time. Must verify all 4 chain links exist for App before go-live.
