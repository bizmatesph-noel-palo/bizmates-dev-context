---
inclusion: manual
---

# Bug Fix Workflow

## Before Writing Code

1. **Read the investigation report** (if one exists)
2. **Identify all affected locations** — check the 4-location rule (Logic + PreLogic × Bizmates + Zipan)
3. **Verify table names from models** — never assume from pattern-matching
4. **Check which command exercises this code path** — Monthly? Send? Pre?

## The Fix

### Step 1: Understand
- What is the expected behavior?
- What is the actual behavior?
- Which CTE stage or function is involved?

### Step 2: Identify Scope
- [ ] How many locations need the same change? (typically 4)
- [ ] Does it affect daily, monthly, or both?
- [ ] Does it affect CSV generation?
- [ ] Is there a test case for this scenario?

### Step 3: Implement
- Fix the root cause, not the symptom
- Keep the fix minimal — don't refactor adjacent code
- Add SQL comments documenting the fix: `-- FIX ASC-XXX: description`
- Apply to ALL affected locations

### Step 4: Verify
- [ ] Run test case simulation (Unit level) for the specific TC
- [ ] Run functional simulation (related TCs)
- [ ] Smoke test: run the command locally, check logs for errors
- [ ] Show changes for code review — do NOT commit

## 4-Location Checklist

If the fix touches the monthly CTE:

- [ ] `MonthlyRateCalculationLogic.php` — Bizmates Grouped/FinalResult/MonthlyUsage
- [ ] `MonthlyRateCalculationLogic.php` — Zipan (same section, different connection block)
- [ ] `MonthlyRateCalculationPreLogic.php` — Bizmates
- [ ] `MonthlyRateCalculationPreLogic.php` — Zipan

If the fix touches CSV generation:

- [ ] `CommonUtil.php` — Bizmates function
- [ ] `ZipanUtil.php` — Zipan equivalent function

## After Fix

- Stop and present changes for review
- Describe what was changed and why
- Reference the test case that validates it
- Wait for approval before commit
