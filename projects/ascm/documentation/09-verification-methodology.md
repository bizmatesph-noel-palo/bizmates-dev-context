# ASC Project — Verification & Testing Methodology

## Summary

This document explains the three-point verification method used by the ASC project to validate that the monthly rate calculation produces correct results. The method is grounded in established software engineering and data validation practices used by organizations including Google, MathWorks, Netflix, and the financial services industry.

---

## The Three-Point Verification Model

We validate correctness by checking agreement across three independent representations of the same truth:

```
             Code Logic
            (business rules
             implemented in SQL)
               /        \
              /          \
      review /            \ produces
            /              \
           v                v
     Test Cases ←────────→ CSV Output
    (expected values       (actual system
     from real data)        output from DEV04)
                  matches?
```

| Verification Point | What It Is | Where It Lives |
|-------------------|------------|----------------|
| **Code Logic** | The CTE pipeline, refund query, orphaned charge query | `MonthlyRateCalculationLogic.php` |
| **Test Cases** | Expected output values for specific charge_ids based on business rules | `Testcases/ASC-XXX_TestCase001–035.md` |
| **CSV Output** | Actual system output from running the batch against DEV04 data | `DEV04_Generated_Files/*.csv` |

### How It Works

1. **Code Logic → Test Cases:** We review the SQL logic and determine what the output SHOULD be for a given charge with known data. This produces the expected values in the test case.

2. **Code Logic → CSV Output:** The batch command executes the logic against real data in DEV04, producing actual CSV files.

3. **Test Cases → CSV Output:** We compare the expected values from the test case against the actual CSV row for that charge_id. Match = PASS, mismatch = FAIL.

**When all three agree**, we have high confidence that the system is correct. **When any point disagrees**, we know exactly where to investigate:

| Symptom | Root Cause |
|---------|-----------|
| Test case PASS but CSV values look wrong to stakeholder | Test case has wrong expected values (business rule misunderstanding) |
| CSV matches test case but code review finds a flaw | Misread the logic — or the flaw doesn't affect this specific case |
| Logic looks correct but CSV doesn't match test case | Bug in execution (data issue, environment, timing, unprocessed dependencies) |

---

## How the Test Cases Were Built

### The Problem

The team had JIRA tickets with defined ACs and sample CSV output — but no fast way to use those as automated regression checks against code changes. Traditional PHPUnit testing was not feasible:

- The CTE queries are multi-level recursive SQL (700+ lines) embedded in PHP strings — mocking them is extremely complex
- Translating SQL boundary behavior into PHP assertions requires deep understanding of every edge case
- The tight deadline (8 working days from Kiro adoption to production deployment) didn't allow time to build a traditional test suite

### What Drove the Approach

After ASC-246, when the fix-and-bug cycle continued despite manual efforts, the team decided that AI-assisted checking was necessary. The team needed:

1. A way to **define expected output** for known charge scenarios
2. A way to **automatically compare** those expectations against actual system output
3. A way to **detect regressions** fast enough to validate every code change before deployment

Unit tests would have been ideal but required too much time to build. The team needed something that could work immediately with existing data.

### The Process: JIRA → Structured `.md` → AI Simulation

The process had two phases: **format design** (one-time setup) and **test case creation** (repeatable workflow).

#### Phase 1: Designing the Test Case Format (One-Time)

```
Noel asks Kiro: "What input format do you need to simulate code correctness?"
        │
        ▼
Kiro defines required sections: [Precondition], [Steps], [Expected], charge data
        │
        ▼
Noel takes Kiro's format spec → feeds it to Gemini with sample JIRA data
        │
        ▼
Gemini produces draft .md files → Noel feeds them back to Kiro for validation
        │
        ▼
Kiro identifies gaps: "I need explicit end_date, ticket_expiry, order_no..."
        │
        ▼
Back-and-forth between Gemini (generation) and Kiro (validation)
until both agree on a format that produces reliable simulation results
        │
        ▼
Final format established — becomes the template for all future test cases
```

This back-and-forth between Gemini and Kiro was essential. Gemini alone couldn't know what Kiro needs for code simulation. Kiro alone couldn't efficiently batch-process raw JIRA data into structured files. The two tools complemented each other: Kiro defined what it needs, Gemini mass-produced it.

#### Phase 2: Creating Test Cases (Repeatable Workflow)

```
JIRA Tickets (ACs + sample CSV output)
        │
        ▼
Noel extracts test data from tickets (e.g., ASC-247 compilation, ASC-301)
        │
        ▼
Feed ticket data + established format template to Google Gemini
        │
        ▼
Gemini produces structured .md test case files
        │
        ▼
Kiro uses .md files to simulate code, compare against DEV04 CSV output
        │
        ▼
PASS/FAIL scorecard per test case
```

This is the current process for creating new test cases. When a new bug is reported (e.g., ASC-301), the investigation produces charge data and expected values. These are formatted into a new `.md` file following the established template, and Kiro can immediately simulate against it.

### Why `.md` Test Cases Instead of PHPUnit

| Aspect | PHPUnit Tests | `.md` Test Cases + AI Simulation |
|---|---|---|
| Time to create | Weeks (complex SQL mocking) | Days (structured text from existing ACs) |
| Execution | Automated CI/CD | AI-assisted comparison (Kiro) |
| Readability | Code (developers only) | Plain language (anyone can verify expected values) |
| Maintenance | Requires code changes | Edit a text file |
| SQL coverage | Must mock CTE behavior in PHP | Tests actual SQL output via CSV |
| Database dependency | Needs test fixtures or mocks | Uses real DEV04 data |
| Regression detection | Fails at test runtime | Fails at simulation (same effect, different mechanism) |

The key advantage: `.md` test cases validate the **actual system output** (CSV from real SQL execution on DEV04) rather than testing a PHP abstraction of the SQL. This catches bugs that unit tests with mocked queries would miss — such as MySQL-specific date boundary behavior.

### Industry Backing

This approach aligns with several established patterns:

**Golden File / Snapshot Testing** — Records expected output in a separate human-readable file, then compares current output against it. Used by testthat (R), Jest (JavaScript), and Go's testdata pattern. Our `.md` files serve the same role as golden files — they define "known-good" output for comparison.

*(Source: [testthat — Snapshot Tests](https://testthat.r-lib.org/articles/snapshotting.html), [MIT CRAN — Golden Tests](https://cran.csail.mit.edu/web/packages/testthat/vignettes/snapshotting.html))*

**Spec-Driven Development** — Uses Markdown specifications as a single source of truth for AI-assisted code generation and validation. The specification defines intent; the AI validates implementation against it.

*(Source: [Syncfusion — Spec-Driven Development with Markdown](https://www.syncfusion.com/blogs/post/spec-driven-ai-development-with-markdown-prompts), [Augment Code — Spec-Driven Development](https://www.augmentcode.com/guides/what-is-spec-driven-development))*

**AI-Driven Test Case Generation from Natural Language** — Research demonstrates that LLMs can generate test cases from natural language requirements, with oracles correct in 88% of cases. Our approach inverts this: we use natural language test cases as the oracle that an AI checks against system output.

*(Source: [arXiv — AI-Driven Test Case Generation from Natural Language Requirements](https://arxiv.org/abs/2606.06563), [arXiv — LLM-Generated Oracle Verifiers](https://ar5iv.labs.arxiv.org/html/2305.14591))*

**LLMs as Verification Tools** — A dual-perspective review confirms that LLMs are increasingly used not just for code generation but for code verification — checking whether implementations meet specifications.

*(Source: [Frontiers in Computing — LLMs and Code Verification](https://www.frontiersin.org/articles/10.3389/fcomp.2025.1655469))*

Content rephrased for compliance with licensing restrictions.

---

## Our Process in Detail

### Verification Model vs Workflow

The three-point verification describes the **shape of the comparison** — three independent representations checked against each other at the moment of validation. The actual **workflow** that produces those three points is sequential:

**Actual Workflow (how it happens):**

```
Bug Report / New Requirement
        │
        ▼
Investigation (review code + query DEV04 data)
        │
        ├──→ Code Fix (implement change in SQL/PHP)
        │
        └──→ Test Case (derive expected values from business rules + real data)
                        │
                        ▼
              Batch runs on DEV04 → CSV Output
                        │
                        ▼
              Simulation (Kiro compares Test Case vs CSV)
                        │
                ┌───────┴───────┐
              PASS            FAIL
           (validated)     (investigate)
```

The three points are created sequentially, but they remain **independent at the moment of comparison**:
- The test case doesn't influence what the CSV produces
- The CSV doesn't know what the test case expects
- Agreement between them validates both the code logic and the expected values simultaneously

This is the same independence principle behind double-entry bookkeeping — debits and credits are written by the same person at the same time, but they must balance independently.

### Step 1: Investigation

A bug is reported (by QA, stakeholders, or found during development). The developer:
1. Queries DEV04 for the affected student's charge data
2. Reviews the code logic to understand the root cause
3. Identifies what the correct behavior should be based on business rules

### Step 2: Fix + Test Case Creation

From the investigation:
- **Code fix** is implemented (change to the CTE, additional query, boundary correction)
- **Test case** is written with expected values derived from business rules applied to the real data found in Step 1

These are derived from the same investigation but serve different purposes: the fix changes behavior, the test case defines what correct behavior looks like.

### Step 3: Batch Execution

The batch command runs against DEV04 with the fix applied, producing new CSV files. This step is fully automated — no human judgment affects what values appear in the CSV.

### Step 4: AI-Assisted Test Case Simulation

The comparison step is performed by **Kiro (AI development assistant)**. Given the test case files and the CSV output files, Kiro:

1. Reads each test case's [Expected] section to extract charge_ids and expected values
2. Searches the corresponding CSV file for the matching charge_id row
3. Compares actual CSV values against expected values column by column
4. Reports results as a PASS/FAIL scorecard with specific mismatches highlighted

This AI-assisted simulation provides:
- **Speed:** All 35 test cases validated in seconds rather than manual line-by-line comparison
- **Consistency:** No human error in reading CSV columns or transposing numbers
- **Reproducibility:** The same simulation can be re-run after any code change with identical methodology
- **No database access required:** Kiro works entirely from local files (test case .md + CSV), making it safe to run without production connectivity

The developer reviews Kiro's scorecard, investigates any FAILs, and makes the fix/re-run decision.

### Step 5: Investigate Failures

When a test case fails:
1. Check if the test case expectations are correct (re-verify business rules)
2. Check if the data in DEV04 matches what the test case assumes
3. Review the code logic for the specific condition that's failing
4. Fix the code, re-run, re-compare

---

## Why This Works: The Consistency Principle

The mathematical foundation is simple:

> If three independent representations of the same truth all produce the same answer, the probability that all three are wrong in the same way is near zero.

Each point is derived independently:
- **Test cases** are written from business rules and real DB data (queried separately)
- **Code logic** is implemented in SQL based on specifications
- **CSV output** is produced by the system running against production-like data

They share no common computation path. A coincidental match across all three — where all three are independently wrong but produce the same incorrect result — is statistically negligible.

This is the same reasoning behind:
- **Double-entry bookkeeping** in accounting (two independent records must balance)
- **Checksum verification** in data transfer (independent hash must match content)
- **Consensus algorithms** in distributed systems (multiple nodes must agree)

---

## Strengths

| Strength | How It Applies |
|----------|---------------|
| **No false confidence** | A passing test means logic AND data AND output agree — not just "code compiles" |
| **Precise failure location** | Mismatches tell you exactly which leg of the triangle broke |
| **Real data, not mocks** | Test cases are grounded in actual production-like data from DEV04 |
| **Business-readable** | Test cases are written in plain language — anyone can verify the expected values |
| **Incremental** | Each new bug becomes a new test case, permanently preventing regression |
| **No infrastructure dependency** | Simulation can run offline (CSV comparison) without database access |

---

## Limitations

| Limitation | Mitigation |
|-----------|-----------|
| Only validates known scenarios | Continuously add test cases for newly discovered edge cases |
| Relies on DEV04 data accuracy | Cross-check with stakeholder expectations when discrepancies arise |
| Manual process (not CI/CD) | Acceptable for monthly batch with low change frequency |
| Cannot catch issues in untested charge types | Expand test matrix over time (currently 35 cases, growing) |

---

## Conclusion

The three-point verification method provides confidence in correctness through independent cross-validation. When code logic, test case expectations, and actual system output all agree, the result is trustworthy. When they disagree, the specific point of failure is identifiable. This makes the method both reliable for proving correctness and efficient for diagnosing problems.

---

## Appendix: Industry Precedent

The three-point verification method is not a novel invention — it applies established principles used across the software and financial industries.

### 1. Google — Data Validation Tool (DVT)

Google's open-source [Data Validation Tool](https://github.com/GoogleCloudPlatform/professional-services-data-validator) compares source and target tables to verify they match after migration. The principle is identical to ours: compare expected data (source) against actual output (target), flag discrepancies for investigation.

Google Cloud's documentation states: "Data validation involves comparing structured data from the source and target tables and verifying that they match after each migration step." Our process does the same — but instead of source/target tables, we compare expected test case values against actual CSV output.

*(Source: [Google Cloud Blog — Automate data validation with DVT](https://cloud.google.com/blog/products/databases/automate-data-validation-with-dvt))*

### 2. MathWorks — Back-to-Back Testing (ISO 26262)

MathWorks Simulink uses [back-to-back equivalence testing](https://in.mathworks.com/help/sltest/ug/back-to-back-equivalence-testing.html) for safety-critical automotive software. The method compares model simulation output against generated code output — two independent implementations of the same specification must produce identical results.

This is formally recognized in ISO 26262 (functional safety standard for automotive) as a valid verification technique. Our approach applies the same principle: the test case (specification) and the CSV output (execution) are compared for equivalence.

*(Source: [MathWorks — Back-to-Back Equivalence Testing](https://in.mathworks.com/help/sltest/ug/back-to-back-equivalence-testing.html))*

### 3. N-Version Programming (Fault Tolerance)

N-version programming is a technique where multiple functionally equivalent programs are independently developed from the same specifications, then run in parallel. A decision mechanism compares outputs to detect faults. If all versions agree, the output is accepted as correct.

Our three-point model is a lightweight variant: instead of N independent implementations, we have N independent representations (logic, expected values, actual output). Agreement across all three provides the same confidence guarantee.

*(Source: [ResearchGate — N-Version Programming](https://www.researchgate.net/publication/229654022_N-Version_Programming))*

### 4. Netflix — Write-Audit-Publish (WAP) Pattern

Netflix's data engineering team uses a three-step [Write-Audit-Publish](https://thedatasitter.substack.com/p/netflixs-wap-guarantee-data-quality) process before releasing data to downstream consumers. The "Audit" step validates that written data meets expectations before it's published for consumption. This mirrors our process: the batch writes to log tables, we audit (compare against test cases), and only then is the data considered verified.

*(Source: [Netflix WAP — The Data Sitter](https://thedatasitter.substack.com/p/netflixs-wap-guarantee-data-quality))*

### 5. Oracle Financial Services — Balance Reconciliation

Oracle's Accounting Foundation product uses [balance reconciliation workflows](https://docs.oracle.com/en/industries/financial-services/ofs-analytical-applications/accounting-foundation/23a/user/workflow-balance-reconciliation.html) that compare GL source systems against operational systems. Discrepancies are flagged for investigation. The pattern is: two independent data sources representing the same financial truth must agree — if they don't, something is wrong.

Our test case vs CSV comparison is the same pattern applied to batch accounting output.

*(Source: [Oracle — Workflow of Balance Reconciliation](https://docs.oracle.com/en/industries/financial-services/ofs-analytical-applications/accounting-foundation/23a/user/workflow-balance-reconciliation.html))*

### 6. Research — Triangulation for Validity

In research methodology, triangulation is a well-established technique for increasing validity. It uses multiple independent data sources or methods to cross-verify findings, reducing bias from any single source. When independent approaches converge on the same conclusion, confidence in correctness increases significantly.

*(Source: [BMJ — Triangulation in research, with examples](https://ebn.bmj.com/content/22/3/67))*
