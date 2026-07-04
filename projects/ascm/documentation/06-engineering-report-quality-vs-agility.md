# Engineering Report: Balancing Quality and Agility

## Summary

This report examines the quality-versus-speed tension in the ASC project — how incomplete requirements and structural debt produced 19 documented engineering issues and 40+ JIRA tickets — and proposes concrete guardrails to stabilize delivery without sacrificing agility.

---

## The Problem

### What We Observed

The **ASC (Accounting System Changes)** project — `accounting_related_system_for_freee` — is a Laravel 8 batch system that computes monthly revenue recognition for Bizmates and Zipan. Over the development cycle (ASC-149 through ASC-297), the project delivered 40+ bug fixes under production deadlines at a measurable cost:

- **19 documented engineering issues** in the Knowledge Base
- **4x fix multiplication factor** (Pre × Final × Bizmates × Zipan) — every fix must be applied in 4 locations
- Single-character boundary errors (e.g., `<` vs `<=`, `INTERVAL 1 DAY` vs `INTERVAL 2 DAY`) requiring multi-week investigation cycles

The accounting team needs accurate monthly reports on a fixed calendar. The system's structural debt means every fix risks introducing new regressions.

### Case 1: The Bug Parade (`MonthlyRateCalculationLogic.php`)

**File:** `app/Libs/MonthlyRateCalculationLogic.php` (1,427 lines)
**Duplicate:** `app/Libs/MonthlyRateCalculationPreLogic.php` (1,433 lines)

The function-level docblock lists **20 separate fix entries** (ASC-149 through ASC-297). The root cause was not developer negligence but **incomplete requirements**:

- The original spec said "add a monthly rate report." It did not specify how tickets with 60-day validity should be expired, how orphaned charges should be handled, or how FLP plans with `order_no = NULL` interact with the B2B expiry path.
- Each missing requirement surfaced as a bug weeks after implementation — requiring investigation, DB queries, test case creation, and a fix applied in 4 locations.

ASC-296 alone required two investigation rounds (Part 1: `<` → `<=`; Part 2: `INTERVAL 1 DAY` → `INTERVAL 2 DAY`). Part 2 was invisible until Part 1 was fixed — a cascading dependency that a single integration test with FLP data would have caught on day one.

### Case 2: The Fan-Out Join (ASC-236) — ¥12,980 Became ¥389,400

A 1:N join between charges and tickets inflated `SUM(paid_price)` by the ticket count. The numbers were large enough to look plausible, delaying detection by days.

Root cause: no data assertions or sanity-bound checks in the pipeline. The code trusted its own output because there was no automated verification layer.

### The Pattern

Both cases share the same dynamic:

1. Unclear/missing requirements → developer fills gaps with assumptions
2. No automated tests to catch boundary errors → bugs reach QA or production
3. Fix applied under pressure → incomplete understanding → regression in adjacent logic
4. Investigation cycle repeats

**Total documented bugs from this pattern: 19 (Knowledge Base) + 40+ JIRA tickets.**

---

## What We Propose

### Quality Guardrails

* **Incorrect Approach:** Skip design → Rush coding → Drop Quality (causes systemic bugs)
* **Correct Agile Approach:** Minimal design → Maintain precision → Shrink Scope (stable MVP)

### 1. Definition of Ready (User Stories → Implementation)

Before a ticket moves to "In Progress," it must have:

- **Explicit boundary conditions.** For any date/datetime comparison: what happens at midnight? On the last day of the month? With `NULL` values? (Would have prevented ASC-277, ASC-285, ASC-296.)
- **Affected plan types enumerated.** Which product_ids are in scope? Does the fix apply to FLP (product_id 29), standard 8-lesson B2B, and Zipan plans equally? (Would have caught ASC-296's FLP gap during design.)
- **Expected output for at least one edge case.** A concrete charge_id with `start_date`, `end_date`, and expected `expired/remaining/paid_price` values. This becomes the test case.
- **Duplication checklist.** Explicitly lists: "Apply to: MonthlyRateCalculationLogic.php (Bizmates section, Zipan section), MonthlyRateCalculationPreLogic.php (Bizmates section, Zipan section)."

### 2. Definition of Done (PR → Merge)

A PR is not merge-ready until:

- **All 4 locations updated.** If the fix touches the monthly CTE, reviewer verifies Pre + Final × Bizmates + Zipan.
- **PHPUnit test added.** At minimum, a data-provider-based test that asserts the fixed boundary condition.
- **No new god-class growth.** If `MonthlyRateCalculationLogic.php` or `CommonUtil.php` grows by more than 20 lines, the PR must justify why extraction wasn't possible.
- **SQL comments document INTERVAL choices.** Every `DATE_ADD(..., INTERVAL N DAY)` must have an inline comment explaining what time-of-day range N covers and why.

### 3. Urgent Refactoring Target: `CommonUtil.php`

**File:** `app/Libs/CommonUtil.php` (2,225 lines)

This file is the project's primary risk vector:
- Holds global mutable state (target month, service ID) that leaks between iterations
- Contains shared utilities, date helpers, CSV generation, and Freee API orchestration in one class
- Changes here can break daily calculations, monthly calculations, journal submission, and balance transition — all at once

**Proposed split:**
- `DateRangeHelper.php` — immutable date computation
- `CsvGenerator.php` — file output formatting
- `FreeeApiClient.php` — journal submission
- `BatchContext.php` — immutable value object replacing mutable properties

---

## Implementation Roadmap

### Recommendation 1: Add PHPStan (Level 5) with CI Enforcement

The project has **zero static analysis**. Type errors, null-safety violations, and dead code are caught only by manual review or production failure.

**Action:**
```bash
composer require --dev phpstan/phpstan phpstan/phpstan-deprecation-rules larastan/larastan
```

Start at Level 5 (catches type errors, undefined variables, return type mismatches). Add a `Makefile` target:
```makefile
lint:
	vendor/bin/phpstan analyse app/ --level=5 --memory-limit=512M
```

Gate PRs on `make lint` passing. Escalate to Level 6+ quarterly.

### Recommendation 2: Boundary-Condition Test Suite (PHPUnit + Data Providers)

The monthly CTE — the most complex and bug-prone code — has **zero automated test coverage**. Every regression is caught by manual CSV comparison against test case `.md` files.

**Action:** Create `tests/Unit/Libs/MonthlyRateCalculationLogicTest.php` with data providers:

```php
/**
 * @dataProvider expiryBoundaryProvider
 */
public function testExpiryBoundaryConditions(
    string $endDate,
    string $maxTicketEnd,
    string $monthStart,
    bool $expectedExpiry
): void {
    // Assert the SQL condition evaluates correctly for each edge case
}

public static function expiryBoundaryProvider(): array
{
    return [
        'FLP ticket 00:59:59 on 1st of next month' => ['2026-04-30', '2026-05-01 00:59:59', '2026-04-01', true],
        'Standard ticket midnight boundary'        => ['2026-04-30', '2026-05-01 00:00:00', '2026-04-01', true],
        'Ticket still valid mid-month'             => ['2026-05-15', '2026-06-15 00:00:00', '2026-04-01', false],
    ];
}
```

Minimum: 1 test per KB topic (19 tests). Target: 100+ boundary assertions.

### Recommendation 3: Pre/Final Parity Assertion (Automated Drift Detection)

The Pre/Final duplication is the single largest source of regressions — fixes applied to Final missed on Pre.

**Action:** Create a parity test that compares the two files structurally:

```php
public function testPreFinalCteParityBizmates(): void
{
    $final = $this->extractCteBlock('MonthlyRateCalculationLogic', 'bizmates');
    $pre   = $this->extractCteBlock('MonthlyRateCalculationPreLogic', 'bizmates');

    $finalNormalized = str_replace('log_monthly_rate_calculation', '', $final);
    $preNormalized   = str_replace('log_monthly_rate_calculation_pre', '', $pre);

    $this->assertEquals($finalNormalized, $preNormalized,
        'Pre and Final CTE logic have diverged. Apply the same fix to both files.'
    );
}
```

This test fails the moment someone updates one file but not the other. Replaces human memory with automation.

---

## Why This Works

### The Core Principles

| Pillar | Focus | Software Context | Agile Objective |
| :--- | :--- | :--- | :--- |
| **Requirements & Design** | Pre-computation | Turning an empty text file into an architectural roadmap | **Validation:** Testing assumptions via edge cases |
| **Accuracy & Precision** | Defect Prevention | Building clean, bug-free, and maintainable logic | **Verification:** Automated tests and code reviews |
| **Sustainable Velocity** | Long-Term Output | Prioritizing craftsmanship over short-term hacks | **Craftsmanship:** Moving fast by building well |

Programming without design is futility. Fast is the enemy of accuracy and precision. But Agile doesn't mean skipping quality — it means breaking work into manageable pieces while maintaining precision.

The project's 19 documented issues are the predictable outcome of **incomplete requirements meeting structural debt under deadline pressure**. A single missing boundary condition (`<` vs `<=`) cascaded into multi-week investigations involving DB queries, CSV comparisons, and 12-location code changes. That's not a bug — that's a process gap.

---

## Strengths of This Approach

| Strength | Impact |
|---|---|
| Definition of Ready catches boundary gaps before coding starts | Prevents the most expensive class of bugs (investigation + 4-location fix) |
| PHPUnit data providers scale to 100+ assertions | Each new bug becomes a permanent regression guard |
| Parity assertion automates Pre/Final synchronization | Eliminates the #1 human-error source |
| PHPStan catches type errors at commit time | No more NULL-safety bugs reaching production |
| Incremental — no rewrite required | Each step reduces cost of the next fix independently |

---

## Limitations

| Limitation | Mitigation |
|---|---|
| PHPUnit tests can't execute raw SQL CTEs | Test boundary conditions in isolation (PHP logic), not end-to-end SQL |
| Definition of Ready requires upfront time | Offset by reduced investigation time downstream |
| CommonUtil split is high-risk refactoring | Do in small PRs with parity tests as safety net |
| Static analysis (Level 5) may produce false positives initially | Baseline and suppress legacy issues, fix incrementally |

---

## Conclusion

The path forward is not a rewrite. It is:

1. **Better requirements** (Definition of Ready with explicit boundary conditions)
2. **Automated verification** (PHPStan + boundary tests + parity assertions)
3. **Incremental extraction** (CommonUtil decomposition, eventual Pre/Final unification)

Each step reduces the cost of the next fix. Each skipped step compounds into the next regression.

---

## Appendix: Guiding Quotes

> **"Fast is the enemy of accuracy and precision."** — *ASC Project Core Value*

> **"The only way to go fast, is to go well."** — *Robert C. Martin (Uncle Bob)*

> **"Without requirements and design, programming is the art of adding bugs to an empty text file."** — *Louis Srygley*
