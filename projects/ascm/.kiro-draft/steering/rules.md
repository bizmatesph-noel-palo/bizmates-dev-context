---
inclusion: auto
---

# Rules & Behavioral Standards

## Git Operations

**CRITICAL — no exceptions.**

**Allowed without asking:** `git status`, `git log`, `git diff`, `git branch -a`, `git stash`

**Ask first:** `git checkout -b` (creating branches), `git checkout` (switching with uncommitted changes)

**NEVER without explicit permission after code review:** `git commit`, `git push`, `git merge`, `git rebase`

**Development flow:**
1. Ticket has a JIRA ID → starting investigation and code changes is OK
2. Code changes done → STOP. Show the diff or describe changes. Wait for review.
3. User approves → ask: "Ready to commit?"
4. User says yes → only then commit

**The code changes are my job. Git is the user's domain.**

## General Development Rules

1. **Read before writing** — always read relevant existing code before proposing changes. Never assume structure.
2. **Minimal changes only** — fix the specific issue. Don't refactor adjacent code in the same change.
3. **Explain reasoning** — when proposing a solution, explain why this approach over alternatives.
4. **Flag risks explicitly** — multi-tenant impact, deployment dependencies, cross-service effects.
5. **Ask when uncertain** — if unsure about a table name, pattern, or convention, ask. Don't assume.
6. **Never combine unrelated actions** — each action requiring approval must be asked separately.

## Investigation & Analysis Rules

1. **Never assume data is correct** without verifying against business rules.
2. **Never propose a fix until root cause is verified and certain.**
3. **Always check `end_date` against target month** before concluding expiry is correct.
4. **Do not frame observations as root causes** — use "observed behavior" until verified.
5. **State what is known vs not verified** — mark unverified claims explicitly.
6. **Never report half-baked truth** — every claim must be backed by data or marked as inferred.
7. **When referencing a test case**, include JIRA ticket and description: `TC035 (ASC-301) — FLP premature expiry`.

## Multi-Tenant Safety

- Every fix must be checked against BOTH tenants (Bizmates + Zipan)
- Verify table names from model `$table` property — never pattern-match
- Test with both connection contexts if the code touches DB directly
