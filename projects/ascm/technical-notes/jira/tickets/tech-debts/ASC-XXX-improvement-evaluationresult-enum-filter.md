# Evaluation Counting — Clarification & Possible Improvement

## Summary

The `EvaluationFilter` CTE currently counts evaluations using:
```sql
AND e.status IN (0, 1)
AND e.result IN (0, 1, 2, 3, 4)
```

This counts ALL evaluation records regardless of `result` value or `status`. Two cases were reported where this counting produces `lessons_taken` exceeding the charge's `total` (lesson_volume).

## Current Behavior (Baseline)

The system counts every evaluation record that matches:
- `ticket_type = 3`
- `status IN (0, 1)` — both active and inactive records
- `result IN (0, 1, 2, 3, 4)` — all result types

Each matching evaluation row = 1 lesson taken. No deduplication per ticket.

## Reported Cases

### Zipan charge 12997 (student 4282, product_id 16 — 月5回プラン)

- **total (lesson_volume):** 5
- **lessons_taken in log:** 1 (April) + 6 (May) = 7. **Exceeds total by 2.**
- **Root cause:** Ticket 111395 has 3 evaluation records — 1 with `result = 1` and 2 with `result = 0` (pending/draft). All have `status = 1` (active).
- **Observation:** If `result = 0` were excluded, count would be 5 (matches total).

### Bizmates charge 3033180 (student 210462, product_id 29 — 月15回プラン)

- **total (lesson_volume):** 15
- **lessons_taken in log:** 14 (April) + 2 (May) = 16. **Exceeds total by 1.**
- **Root cause:** 4 tickets have multiple evaluation records, all with `result = 1`. All have `status = 1` (active).
- **Observation:** Filtering by `result = 1` alone would NOT fix this. Multiple "taught" evaluations exist per ticket.

## Reference: Evaluation Values

From `MBTI_backend/src/app/Models/TrnEvaluation.php`:

**Result values:**

| result | Constant | Meaning |
|--------|----------|---------|
| 0 | RESULT_LESSON_PENDING | Draft/pending (trainer pressed draft, not submitted) |
| 1 | RESULT_LESSON_TAUGHT | Lesson taught (evaluation saved) |
| 2 | RESULT_NO_SHOW | Student no-show |
| 3 | RESULT_ABSENT | Absent — trainer pay still applies |
| 4 | RESULT_ABSENT_SUB | Absent sub — another student took the slot |

**Status values:**

| status | Constant | Meaning |
|--------|----------|---------|
| 0 | EVALUATION_STATUS_INACTIVE | Inactive (deleted/reverted?) |
| 1 | EVALUATION_STATUS_ACTIVE | Active |

## Status × Result Matrix

| | status = 1 (Active) | status = 0 (Inactive) |
|---|---|---|
| **result = 1 (Taught)** | ✅ Lesson completed, active | ❓ Taught but record inactive |
| **result = 0 (Pending)** | ❓ Draft, not confirmed | ❌ Draft AND inactive |
| **result = 2 (No-Show)** | ✅ No-show, ticket consumed | ❓ No-show but record inactive |
| **result = 3 (Absent)** | ✅ Absent, ticket consumed | ❓ Absent but record inactive |
| **result = 4 (Absent Sub)** | ✅ Absent sub, ticket consumed | ❓ Absent sub but record inactive |

## Possible Directions (Pending Accounting Team Decision)

### For the Zipan case (result = 0 records):

Removing `result = 0` from the filter could resolve this — the 2 extra records are drafts/pending. However, this is only a theory until the Accounting team confirms how pending evaluations should be handled.

### For the Bizmates case (multiple result = 1 per ticket):

This is harder. Even filtering by result doesn't help since all records are `result = 1`. Possible approaches (pending decision):
- Cap counting at 1 per ticket (`COUNT(DISTINCT ticket_id)`)
- Cap at `lesson_volume` (never exceed total)
- Accept as-is if the platform allows multiple lessons per ticket by design

### For status = 0 (raised by Wu-san):

Neither reported case involves `status = 0` records. But the question is valid — should inactive records be counted? This should be part of the same clarification.

## Proposed Enum (Implementation Ready When Decision Is Made)

Once the counting rules are confirmed, we can implement using an int-backed enum:

```php
enum EvaluationResultEnum: int
{
    use HasEnumHelperTrait;

    case PENDING    = 0;
    case TAUGHT     = 1;
    case NO_SHOW    = 2;
    case ABSENT     = 3;
    case ABSENT_SUB = 4;

    public static function countableResults(): array
    {
        // Adjust based on Accounting team decision
        return [
            self::TAUGHT->value,
            self::NO_SHOW->value,
            self::ABSENT->value,
            self::ABSENT_SUB->value,
        ];
    }
}
```

Scope: 4 locations (Logic + PreLogic × Bizmates + Zipan)

## Status

Pending Accounting team clarification via Redmine ticket (created by Miyachi-san). No implementation until decision is confirmed.

## Notes

- Raised by Wu-san (2026-06-19, 2026-06-23)
- Investigated as part of the 20260618 data adjustments investigation (Category B)
- The Accounting team's response will determine:
  1. Which `result` values should count
  2. Whether `status = 0` should be excluded
  3. Whether multiple evaluations per ticket should be capped
