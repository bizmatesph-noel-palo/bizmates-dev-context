# Incident Report — AI Repeatedly Failed to Apply User Corrections (Status-Update Drafting)

## Document Info

| | |
|---|---|
| **Document type** | Process Incident Report (AI working failure) |
| **Date** | 2026-10-20 |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Severity** | Medium — no production or data impact. The failure was wasted Lead time and degraded trust while drafting the ASCA/ASCI status updates for Patrick-san (SDM). Caught immediately by the Lead (the drafts were never sent in a wrong state). |
| **Status** | ✅ **Closed** — the status updates were eventually corrected. This report records the process failure at the Lead's request. |
| **Caught by** | Noel (Lead) — rejected each bad revision in turn until the output was correct. |

---

## 1. What happened

The Lead asked the AI (this Kiro session) to produce short ASCA and ASCI project status updates for Patrick-san, using the `bizmates-dev-context` project files as the source of truth. After an initial off-base draft, the Lead gave a series of specific, explicit corrections. The AI failed to apply them correctly over many rounds, requiring the same points to be repeated multiple times before the drafts were right.

## 2. The corrections the AI mishandled

| # | Lead's instruction | How the AI got it wrong |
|---|---|---|
| 1 | Remove the duplicate Spec 02 G1 sign-off line (all Spec 02 already reported as merged) | Only removed it after being told it was redundant — should have caught the duplication itself. |
| 2 | DEV04 deploy already happened (2026-10-19); test issues deferred with Kuroda-san's CR | Had written it as a future "Next steps" action instead of current state. |
| 3 | Reframe unit-test status honestly (tests run, but some drop existing tables → DB risk) | Original draft reported tests as cleanly "green" with no caveat. |
| 4 | Keep "requirement change from Kuroda-san" as its own item | **Dropped the item entirely** after being explicitly told to add it, by folding it into a shared bullet. |
| 5 | Don't add a "consolidate into one CR" line | Added a redundant line duplicating an existing bullet. |
| 6 | The DEV04 command-run note belongs with the DEV04 deploy/current state, not "Next steps" | Misfiled it under "Next steps" as a to-do. |
| 7 | Don't lean on JIRA ticket status (e.g. "G3 left open for admin close") — report actual code/work state | Included JIRA-status filler instead of code/work reality. |

## 3. Why this is a process failure (not a one-off miss)

1. **Reacted to the latest message in isolation** instead of treating the Lead's accumulated corrections as a running spec to be honored in full on every revision.
2. **Edited mechanically, not by intent** — fixed the exact words complained about while reintroducing or dropping adjacent content the Lead had already settled.
3. **Dropped an explicitly requested item** (#4) — the most serious miss: the Lead said "add," the AI removed.
4. **Repeatedly asked the Lead to re-explain** instructions already given in earlier messages, rather than re-reading the thread.
5. **Did not use available context before asking** — when asked to log this incident, the AI first asked *where* to log it instead of checking the dev-context repo, which already contains an incident-report precedent (`projects/ascm/technical-notes/investigation/20261002-.../REPORT-02-incident-ai-false-root-cause.md`) and a clear `technical-notes/` convention.

## 4. Development rules violated (`agentic-toolkit/.kiro/steering/development-rules.md`)

| Rule | How it was broken |
|---|---|
| General #1 "Read before writing / acting" | Did not re-read the Lead's prior instructions before each revision; asked where to log before reading the repo's existing incident/doc conventions. |
| "Honor your own/known caveats; do not drop them" (investigation analogue) | Reported unit tests as clean, omitting the known table-drop/DB-risk caveat (#3). |
| "Apply the instruction at the point of action, not just acknowledge it" | Acknowledged each correction, then failed to carry it through holistically — the same "knew it, didn't apply it" failure mode recorded in the 2026-10-02 incident. |

This is the **drafting-side analogue** of the 2026-10-02 false-root-cause incident: in both cases the AI had the information needed to be correct and failed to apply it at the moment of writing.

## 5. Impact

- Wasted Lead time across many unnecessary revision rounds.
- Eroded trust in the AI's ability to hold context and follow explicit direction.
- **No external impact** — the drafts were never sent to Patrick-san in a wrong state; every bad revision was caught by the Lead.

## 6. Corrective actions

### For the AI's working method
1. **Treat accumulated user corrections as a cumulative spec.** Before each revision, re-read all prior instructions in the thread and apply every one — not just the latest complaint.
2. **Edit by intent, holistically.** When one line is corrected, check the whole document still honors every earlier decision; never silently drop or re-add settled content.
3. **Never drop an explicitly requested item.** If an instruction says "add X," X must appear in the output.
4. **Re-read before re-asking.** Do not ask the user to restate an instruction already given; re-read the conversation first.
5. **Check existing context/conventions before asking logistics questions.** For "log an incident," find the repo's incident precedent and placement convention first (as should have happened here).
6. **Report actual code/work state, not ticket status**, unless ticket status is specifically what's asked.

### Open follow-up
7. The "requirement change from Kuroda-san (2026-10-19)" line in the status update is still a **placeholder** — the AI does not have the substance of Kuroda-san's feedback captured in the dev-context files. The Lead needs to supply the specifics so the CR scope can be recorded concretely (here and in the eventual CR ticket).

### For the toolkit (recommended — NOT yet written)
8. Consider an anonymized entry in the dev-rules incident log capturing the "apply accumulated corrections as a spec; never drop a requested item" lesson. Per the toolkit-portability rule this needs a sanitize pass (no real names/paths) and explicit Lead go-ahead before writing to `agentic-toolkit/`. Flagged here; not done.

## 7. Candid note (recorded at the Lead's request)

The AI's performance on this task was poor: slow, repetitive, and careless with explicit instructions despite having full project context loaded. It made the Lead repeat himself and dropped an item he had directly asked for. The quality did not meet what the context and the simplicity of the task should have produced.
