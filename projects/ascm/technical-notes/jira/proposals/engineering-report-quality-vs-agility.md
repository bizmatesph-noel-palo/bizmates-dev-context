# Engineering Report: Balancing Quality and Agility

> ### 💡 The Core Pillars of Software Engineering
> * **On Execution:** **"Fast is the enemy of accuracy and precision."** — *Project Core Value*
> * **On Velocity:** **"The only way to go fast, is to go well."** — *Robert C. Martin (Uncle Bob)*
> * **On Planning:** **"Without requirements and design, programming is the art of adding bugs to an empty text file."** — *Louis Srygley*

## 1. Executive Summary

The **ASC (Accounting System Changes)** project — `accounting_related_system_for_freee` — is a Laravel 8 batch system that computes monthly revenue recognition for the Bizmates and Zipan online English lesson services. It processes student charges, calculates lesson consumption (taken/expired/remaining), generates CSV accounting reports, and submits journal entries to the Freee accounting API.

Over the past development cycle (ASC-149 through ASC-297), the project has delivered 40+ bug fixes and feature additions under production deadlines. This velocity came at a measurable cost: **19 documented engineering issues** in our Knowledge Base, a **4x fix multiplication factor** (Pre × Final × Bizmates × Zipan), and a pattern where single-character boundary errors (e.g., `<` vs `<=`, `INTERVAL 1 DAY` vs `INTERVAL 2 DAY`) required multi-week investigation and re-testing cycles.

The tension is real: the accounting team needs accurate monthly reports on a fixed calendar, yet the system's structural debt means every fix risks introducing new regressions. This report examines how we arrived here and proposes concrete guardrails to stabilize delivery without sacrificing agility.

## 2. Terminology Matrix

| Pillar | Focus | Software Context | Agile Objective |
| :--- | :--- | :--- | :--- |
| **Requirements & Design** | Pre-computation | Turning an empty text file into an architectural roadmap. | **Validation:** Testing market assumptions via MVPs. |
| **Accuracy & Precision** | Defect Prevention | Building clean, bug-free, and maintainable logic. | **Verification:** Automated tests, CI/CD, and code reviews. |
| **Sustainable Velocity** | Long-Term Output | Prioritizing craftsmanship over short-term hacks. | **Craftsmanship:** Moving fast by building well. |

## 3. The Core Paradox: The Illusion of Speed in Our Codebase

### Case 1: The `MonthlyRateCalculationLogic.php` Bug Parade

**File:** `app/Libs/MonthlyRateCalculationLogic.php` (1,427 lines)
**Duplicate:** `app/Libs/MonthlyRateCalculationPreLogic.php` (1,433 lines)

The function-level docblock in these files tells the story — it lists **20 separate fix entries** (ASC-149 through ASC-297), each representing a boundary bug discovered in production or QA. The root cause was not developer negligence but **incomplete requirements**:

- The original spec said "add a monthly rate report." It did not specify how tickets with 60-day validity windows should be expired, how orphaned charges (deleted tickets) should be handled, or how FLP plans with `order_no = NULL` should interact with the B2B expiry path.
- Each missing requirement surfaced as a bug weeks after implementation, requiring investigation, DB queries against DEV04, test case creation, and a fix applied in **4 locations** (both files × both tenants).

The cumulative cost: ASC-296 alone required two investigation rounds (Part 1: `<` → `<=` on `charge_in_past`; Part 2: `INTERVAL 1 DAY` → `INTERVAL 2 DAY` on the expiry boundary). Part 2 was invisible until Part 1 was fixed — a cascading dependency that a single integration test with FLP data would have caught on day one.

### Case 2: The Fan-Out Join (ASC-236) — ¥12,980 Became ¥389,400

A 1:N join between charges and tickets inflated `SUM(paid_price)` by the ticket count. A ¥12,980 charge appeared as ¥389,400 in reports. The numbers were large enough to look plausible as monthly totals, which **delayed detection by days**.

Root cause: no data assertions or sanity-bound checks in the pipeline. The code trusted its own output because there was no automated verification layer.

### The Pattern

Both cases share the same dynamic:
1. Unclear/missing requirements → developer fills gaps with assumptions
2. No automated tests to catch boundary errors → bugs reach QA or production
3. Fix applied under pressure → incomplete understanding → regression in adjacent logic
4. Investigation cycle repeats

**Total documented bugs from this pattern: 19 (Knowledge Base) + 40+ JIRA tickets.**

## 4. Reconciling Speed, Design, and Quality in Our Process

* **Incorrect Approach:** Skip design → Rush coding → Drop Quality (Causes systemic bugs)
* **Correct Agile Approach:** Minimal design → Maintain precision → Shrink Scope (Stable MVP)

### Proposed Quality Guardrails for Our Project

#### 1. Definition of Ready (User Stories → Implementation)

Before a ticket moves to "In Progress," it must have:

- **Explicit boundary conditions.** For any date/datetime comparison: what happens at midnight? On the last day of the month? With `NULL` values? (Would have prevented ASC-277, ASC-285, ASC-296.)
- **Affected plan types enumerated.** Which product_ids are in scope? Does the fix apply to FLP (product_id 29), standard 8-lesson B2B, and Zipan plans equally? (Would have caught ASC-296's FLP gap during design.)
- **Expected output for at least one edge case.** A concrete charge_id with `start_date`, `end_date`, and expected `expired/remaining/paid_price` values. This becomes the test case.
- **Duplication checklist.** Explicitly lists: "Apply to: MonthlyRateCalculationLogic.php (Bizmates section, Zipan section), MonthlyRateCalculationPreLogic.php (Bizmates section, Zipan section)."

#### 2. Definition of Done (PR → Merge)

A PR is not merge-ready until:

- **All 4 locations updated.** If the fix touches the monthly CTE, reviewer verifies Pre + Final × Bizmates + Zipan.
- **PHPUnit test added.** At minimum, a data-provider-based test that asserts the fixed boundary condition (e.g., "charge with `end_date = last day of month` must have `charge_in_past = 1`").
- **No new god-class growth.** If `MonthlyRateCalculationLogic.php` or `CommonUtil.php` grows by more than 20 lines, the PR must justify why extraction wasn't possible.
- **SQL comments document INTERVAL choices.** Every `DATE_ADD(..., INTERVAL N DAY)` must have an inline comment explaining what time-of-day range N covers and why.

#### 3. Urgent Refactoring Target

**File:** `app/Libs/CommonUtil.php` (2,225 lines)

This file is the project's primary risk vector:
- Holds global mutable state (target month, service ID) that leaks between iterations (Knowledge Base Topic 16)
- Contains shared utilities, date helpers, CSV generation, and Freee API orchestration in one class
- Changes here can break daily calculations, monthly calculations, journal submission, and balance transition — all at once

**Proposed split:**
- `DateRangeHelper.php` — immutable date computation
- `CsvGenerator.php` — file output formatting
- `FreeeApiClient.php` — journal submission
- `BatchContext.php` — immutable value object replacing mutable properties

## 5. Implementation Roadmap

### Recommendation 1: Add PHPStan (Level 5) with CI Enforcement

**Why:** The project has **zero static analysis**. No `phpstan.neon`, no `rector.php`. Type errors, null-safety violations, and dead code are caught only by manual review or production failure.

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

**Why:** The project has ~16 test files for 8,300+ lines of core logic. The monthly CTE — the most complex and bug-prone code — has **zero automated test coverage**. Every regression is caught by manual CSV comparison against test case .md files.

**Action:** Create `tests/Unit/Libs/MonthlyRateCalculationLogicTest.php` with data providers covering:

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

**Why:** The Pre/Final duplication (Topic 14) is the single largest source of regressions — fixes applied to Final missed on Pre. A review checklist mitigates but doesn't prevent.

**Action:** Create a parity test that compares the two files structurally:

```php
public function testPreFinalCteParityBizmates(): void
{
    $final = $this->extractCteBlock('MonthlyRateCalculationLogic', 'bizmates');
    $pre   = $this->extractCteBlock('MonthlyRateCalculationPreLogic', 'bizmates');

    // Normalize whitespace and table name differences
    $finalNormalized = str_replace('log_monthly_rate_calculation', '', $final);
    $preNormalized   = str_replace('log_monthly_rate_calculation_pre', '', $pre);

    $this->assertEquals($finalNormalized, $preNormalized,
        'Pre and Final CTE logic have diverged. Apply the same fix to both files.'
    );
}
```

This test fails the moment someone updates one file but not the other. It replaces human memory with automation.

## 6. Conclusion

Programming without design is an exercise in futility, and fast remains the enemy of accuracy and precision. Agile accelerates delivery by breaking work down into manageable pieces, not by skipping quality. As Uncle Bob noted, the only way to go fast is to go well.

The ASC project's 19 documented issues are not failures of developer skill — they are the predictable outcome of **incomplete requirements meeting structural debt under deadline pressure**. A single missing boundary condition (`<` vs `<=`) cascaded into a multi-week investigation involving DB queries, CSV comparisons, and 12-location code changes. That's not a bug — that's a process gap.

The path forward is not a rewrite. It is:
1. **Better requirements** (Definition of Ready with explicit boundary conditions)
2. **Automated verification** (PHPStan + boundary tests + parity assertions)
3. **Incremental extraction** (CommonUtil decomposition, eventual Pre/Final unification)

Each step reduces the cost of the next fix. Each skipped step compounds into the next regression.
