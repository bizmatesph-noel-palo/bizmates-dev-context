# ADR-001: ASCH CSV Delivery Method

**Status:** Accepted  
**Date:** 2026-07-22  
**Deciders:** Hayato Kuroda (PM), Noel Palo (Lead Dev)

---

## Context

ASCH produces two CSV reports (`AschComponentDetail`, `AschCalculationSummary`) that must be delivered to the accounting team each month. The existing ASC batch already produces ~15 CSV files, zips them, and sends emails:

**Current email schedule (before ASCH):**

| Run | Command | When | Email |
|---|---|---|---|
| Preview (速報) | `DailyRateCalculationPreCommand` | 1st of month | Email 1: Pre zip (preview CSVs) |
| Final (確定) | `SendJournalsDataCommand` | 3rd business day | Email 2: Final zip (final CSVs + Freee journals sent) |

**With ASCH added (4 emails total):**

| Run | Command | When | Email |
|---|---|---|---|
| Preview | `DailyRateCalculationPreCommand` | 1st of month | Email 1: ASC Pre zip |
| Preview | `AschProrationCommand --run-type=preview` | 1st of month (after Email 1) | Email 2: ASCH Pre zip |
| Final | `SendJournalsDataCommand` | 3rd business day | Email 3: ASC Final zip |
| Final | `AschProrationCommand --run-type=final` | 3rd business day (after Email 3) | Email 4: ASCH Final zip |

The question: should ASCH CSVs be merged into the existing zips (2 emails, same as before) or sent separately (4 emails total)?

### The Execution Order Constraint

ASCH must run AFTER the existing command because it reads N values that the existing command creates:

```
SendJournalsDataCommand:
  Step 1: createDailyRateCalculation()  → writes N to log tables
  Step 2: sendFreeeJournals2()          → sends T1/T2/T3 to Freee
  Step 3: createBalanceTransition()
  Step 4: createSendMailAttacheFile()   → zips all CSVs, sends email
                                           ↑ zip happens HERE, ASCH CSVs don't exist yet

AschProrationCommand (runs AFTER):
  Step A: Read N from log tables (written by Step 1)
  Step B: Calculate P
  Step C: Send P−N to Freee (adjustment to what Step 2 sent)
  Step D: Generate CSVs, zip, email
```

Because the zip (Step 4) is created before ASCH runs, ASCH CSVs cannot be in that zip without restructuring the existing command.

---

## Decision

**Option A: Separate ASCH commands with separate emails (4 emails total).**

ASCH runs as independent commands after the existing batch. Own zip, own email for each run (preview and final).

---

## Consequences

### Positive

- Zero regression risk — existing batch completely untouched
- Independent testability — ASCH tested and debugged without touching ASC
- Error isolation — if ASCH fails, accounting still gets existing reports on time
- Fastest to implement — no integration code, fits within 9.5-week timeline
- Follows Strangler Fig pattern — new system alongside old, not inside it
- Easy to revert — disable ASCH command without affecting anything else
- ASCH can be rerun independently if issues found (no need to rerun entire ASC pipeline)

### Negative

- Accounting receives 4 emails instead of 2 (confirmed acceptable by PM)
- Two zip files per run to download instead of one
- Cannot view ASCH + ASC data side-by-side in same zip (but ASCH CSVs include N column for comparison)

### Neutral

- If accounting later requests combined delivery, Option C (orchestrator) can be built as a separate initiative after ASCH is stable in production
- The 4-email model may actually be preferred operationally — accounting can process ASC and ASCH independently, and ASCH email arriving slightly later is a natural "ready to review" signal

---

## Alternatives Considered

### Option B: Inject ASCH into Existing Commands (2 emails, merged zip)

Inject ASCH calculation logic inside `SendJournalsDataLogic` (between balance transition and zip creation) so ASCH CSVs are included in the same zip.

```php
// Inside SendJournalsDataLogic::execute() — modified
// After Step 3 (balance transition), before Step 4 (zip/email):
$aschService = app()->make(AschProrationService::class);
$aschService->calculateAndSendToFreee($targetYm);
// Then Step 4 includes ASCH CSVs in $fileNameList
```

- **Pros:**
  - Accounting receives 2 emails (familiar, no operational change)
  - All data in one zip per run
  - ASCH + ASC data together in one delivery

- **Cons:**
  - Modifies `SendJournalsDataLogic` — a 1100-line monolith with 5 transaction blocks
  - Introduces `app()->make()` into a class with no dependency injection pattern
  - ASCH failure could prevent the entire email from sending (ASC reports delayed)
  - Must modify BOTH `SendJournalsDataLogic` AND `DailyRateCalculationPreLogic` (2 monoliths)
  - Transaction boundary ambiguity — ASCH runs between commit blocks
  - Testing requires running the full pipeline (cannot test ASCH independently)
  - Violates project principle: "existing ASC batch is not modified"
  - Timeline: +1 week (10.5 weeks total, tight for 10/1 deadline)

- **Why rejected:** Regression risk to an accounting system that processes real money. Error coupling means ASCH bugs could delay ASC reports. The integration effort adds 1 week with no technical benefit — only cosmetic (fewer emails).

### Option C: Split SendJournals + Orchestrator (2 emails, clean architecture)

Refactor the existing command to separate "processing" from "reporting," add an orchestrator that runs both ASC and ASCH processing, then combines all CSVs into one zip.

```
Step 1: AscProcessingCommand    → daily calc + Freee T1/T2/T3 + balance (NO zip/email)
Step 2: AschProrationCommand    → ASCH calc + Freee T1 adjustment (NO zip/email)
Step 3: AccountingReportCommand → collects all CSVs from steps 1+2, zips, emails
```

- **Pros:**
  - Best long-term architecture (clean separation of concerns)
  - Single delivery per run for accounting (2 emails total)
  - Foundation for future subsystems to plug in
  - Each component independently testable after refactor

- **Cons:**
  - Requires splitting a 1100-line monolith that processes real money
  - Every existing report must be verified byte-for-byte unchanged after split
  - Timeline: +2–3 weeks (12+ weeks total, exceeds 10/1 deadline)
  - Highest regression risk during the refactor period
  - Extensive QA required for the split itself (not just ASCH)
  - Overkill for immediate need (one additional subsystem)

- **Why rejected:** Exceeds the 10/1 deadline by 2–3 weeks. The refactor risk is disproportionate to the benefit (fewer emails). Can be done later as a separate initiative once ASCH is stable.

---

## Comparison Summary

| Dimension | Option A (Separate) | Option B (Inject) | Option C (Orchestrate) |
|---|---|---|---|
| Existing code modified | 0 lines | ~30 lines in 2 files | ~500+ lines refactor |
| Regression risk | Zero | Medium | High |
| Timeline impact | None (9.5 wk) | +1 week (10.5 wk) | +2–3 weeks (12 wk) |
| Fits 10/1 deadline? | ✅ Yes | ⚠️ Tight | ❌ No |
| Emails per month | 4 (2 per run) | 2 (1 per run) | 2 (1 per run) |
| Testability | High (independent) | Low (coupled) | High (after refactor) |
| Error isolation | Full | None (ASCH blocks ASC) | Full (after refactor) |
| ASCH rerun-ability | Independent | Must rerun full pipeline | Independent |
| Future extensibility | New commands add easily | Each new system modifies monolith | Plug into orchestrator |

---

## Industry Alignment

### Strangler Fig Pattern (Microsoft, AWS, Martin Fowler)

The industry-standard approach for adding functionality to legacy systems: build new alongside the old, don't modify the old system's internals. Option A follows this pattern exactly — ASCH is independent, communicates through the database (N values as the interface), and can eventually replace or outlive the legacy system.

### Amazon's Service Independence Principle

Each capability should be independently deployable, testable, and recoverable. Option A gives ASCH its own lifecycle — it can fail, be fixed, and rerun without impacting the existing accounting pipeline.

### Google's "Don't Break the Build"

Modifying shared infrastructure requires owning the risk for all downstream consumers. `SendJournalsDataLogic` is shared infrastructure producing 15+ reports. Option A avoids owning that risk entirely.

### The Pragmatic Guidance (Industry Consensus)

Move to a combined architecture (Option C) only when:
- The operational overhead of separation (4 emails) becomes genuinely painful
- The system is stable enough that refactoring carries low risk
- There's dedicated time allocated for the refactor (not under deadline pressure)

None of these conditions hold today. They may hold in Q1 2027 after ASCH is proven.

---

## References

- [Strangler Fig Pattern — Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig)
- [Strangler Fig Pattern — AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/strangler-fig.html)
- `RESEARCH-03-Integration-Points-Analysis.md` — code-level analysis of existing pipeline
- `RESEARCH-04-CSV-Zip-Email-Integration.md` — detailed investigation of zip/email mechanism
- `REF-ASCH-04-Requirements-Update-20260722.md` — decision record from Kuroda-san
