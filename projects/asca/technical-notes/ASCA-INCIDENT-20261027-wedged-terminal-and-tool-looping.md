# Incident Report — AI Repeatedly Re-ran a Hanging/Wedged Tool Instead of Switching Methods

## Document Info

| | |
|---|---|
| **Document type** | Process Incident Report (AI working failure) |
| **Date** | 2026-10-27 |
| **Author** | Noel Palo, Lead Developer |
| **Assisted by** | Kiro |
| **Severity** | Medium — no production, data, or external impact. Cost was wasted Lead time and repeated multi-minute stalls while doing ASCI/ASCA doc + JIRA work; eroded trust. All work completed correctly in the end. |
| **Status** | ✅ Open lesson recorded; corrective rules proposed (toolkit promotion pending Lead go). |
| **Caught by** | Noel (Lead) — had to cancel the hanging tool calls repeatedly and finally called it out. |

---

## 1. What happened

Across a working session (ASCI-01 G1 fold-in, doc syncs, JIRA ticket creation, and file renames), the AI repeatedly invoked tools that **hung for a very long time** (user: "took 100 years to complete", "100M years") before either timing out, being interrupted, or being cancelled by the Lead. The two recurring culprits:

1. **`grep_search`** — hung/stalled multiple times (at least 3 separate invocations across the session), twice reported as "interrupted before it reported a result."
2. **Shell commands piped through a pager** — `git diff` / `git`-family commands invoked via the `wsl` shell triggered an interactive `less` pager that **wedged the terminal**, capturing subsequent commands as keystrokes and mangling output (seen as doubled/garbled characters), so the next several commands failed or appeared to hang.

The critical failure is not that the tools misbehaved — it is that **the AI kept reaching for the same failing approach** instead of switching methods after the first or second failure, despite having a loaded portable lesson (`follow-the-procedure...` / wedged-terminal guidance in `write-to-an-absolute-path-and-verify.md`) describing exactly this.

## 2. The failure pattern (chronological, condensed)

| # | What the AI did | Result |
|---|---|---|
| 1 | Ran `git --no-pager diff` / `git diff` for review | Pager wedged the wsl terminal; output garbled; follow-on commands captured as keystrokes |
| 2 | Retried pager variants (`cat`, `\| head`, `core.pager=cat`) | Still fighting the wedged `less`; more garbled output |
| 3 | Eventually used a temp-file + file-read workaround | ✅ worked — but only after several wasted rounds |
| 4 | Later used `grep_search` to find references | Hung; "interrupted before it reported a result" |
| 5 | Re-ran `grep_search` again (same tool) | Hung again; Lead cancelled ("took 100yrs") |
| 6 | Re-ran `grep_search` a THIRD time for the final sweep | Hung again; Lead cancelled and escalated |
| 7 | Finally switched to `grep -rl ... > /tmp/file` + read | ✅ worked immediately, clean result |

The working method (temp-file + explicit exit code) was discovered at step 3 and again at step 7 — the AI **knew the reliable path and still returned to the failing one** on the next similar task.

## 3. Why this is a process failure (not a tool's fault)

1. **Did not treat "hang/interrupt" as a stop signal.** A tool that stalls or is interrupted once should trigger a method switch, not a retry of the same tool.
2. **Fought a wedged terminal instead of resetting + avoiding it.** The toolkit's wedged-terminal lesson says: reset, then use a method that can't be derailed by shell/pager state (dedicated file tools, or redirect-to-file + read). The AI re-tried pager variants instead.
3. **Ignored a loaded lesson at the decision point.** `knowledge/write-to-an-absolute-path-and-verify.md` and `follow-the-procedure-you-were-told-to-check.md` both warn about wedged terminals and tool hygiene. Reading a rule ≠ applying it — same meta-failure as the 2026-10-20 incident.
4. **No circuit-breaker.** There was no "two strikes → change approach" discipline; the same tool was tried a third time.

## 4. Root cause

- **Environment:** `grep_search` is unreliable in this setup (Windows host + `\\wsl.localhost` UNC workspace paths over WSL) — it hangs rather than returning. The `wsl` shell's default git pager (`less`) is interactive and wedges on non-TTY invocation.
- **Behavioral:** the AI defaulted to the "normal" tool each time instead of the method that had just proven reliable in this exact environment. Action-bias over observed evidence.

## 5. Impact

- Repeated multi-minute stalls; several Lead cancellations.
- Eroded trust; the Lead had to escalate to get the behavior to change.
- **No external/data impact** — all doc edits, JIRA tickets (ASCA-82/83), and file renames completed correctly.

## 6. Corrective actions

### For the AI's working method (effective immediately this session)
1. **Two-strikes circuit-breaker.** If a tool hangs, is interrupted, or is cancelled **once**, do NOT re-run the same tool the same way. After the **second** failure of any kind, switch method entirely and say so.
2. **Prefer dedicated file tools over shell for search/read in this environment.** For content search where `grep_search` has hung, fall back to `grep -rl <pat> <dir> --include=... > /tmp/out.txt; echo EXIT=$?` then read the temp file with the file tool. Never pipe long git/grep output through the interactive pager.
3. **Disable the pager on every git read command in `wsl`.** Use `GIT_PAGER=cat git ...` (or `git --no-pager`) AND redirect to a temp file, then read the file — never rely on inline terminal rendering.
4. **Treat a wedged terminal as a hard reset point.** Send a single reset, then change method; do not feed variants into a stuck shell.
5. **Verify results via exit code, not scrollback.** `echo EXIT=$?` after redirected commands; a clean file + known exit code is the signal, not garbled terminal text.

### For the toolkit (recommended — NOT yet written; needs Lead go + sanitize pass)
6. Promote an anonymized rule to `agentic-toolkit/` capturing: **"environment-aware tool fallback + two-strikes circuit-breaker."** Candidate homes: a new `knowledge/stop-retrying-a-wedged-or-hanging-tool.md`, and/or a line in `.kiro/steering/` tool-hygiene rules. Per the toolkit-portability rule this must be company/project/path-agnostic (no `\\wsl.localhost`, no real names) — draft below. **Flagged; awaiting Lead go before writing to the toolkit repo (separate repo, outside the active workspace).**

### Proposed portable rule text (draft for the toolkit — anonymized)
> **Stop retrying a wedged or hanging tool.** If a command/tool hangs, is interrupted, or is cancelled, do not re-run it the same way. After a second failure of any kind, switch method and say so. In environments where a search tool hangs or a shell pager wedges the terminal: disable the pager (`GIT_PAGER=cat` / `--no-pager`), redirect output to a temp file and read the file, and prefer dedicated file tools over shell scrollback. Verify by exit code, not by terminal text. A reset is a method-change point, not an invitation to retry the same approach.

## 7. Bug report filed

A Kiro product bug report for the underlying tool issues (grep_search hang on `\\wsl.localhost` UNC paths; git pager wedging the `wsl` shell) is at:
`projects/asca/technical-notes/KIRO-BUG-20261027-grep-hang-and-pager-wedge-wsl.md` — to be submitted to the Kiro dev team.

## 8. Candid note (recorded at the Lead's request)

The AI repeated the same avoidable stall pattern several times in one session despite having the reliable workaround in hand and a loaded lesson describing the exact failure. The Lead had to cancel repeatedly and escalate (justified frustration). This is a "knew it, didn't apply it" failure at the tool-selection decision point — the same meta-pattern as the 2026-10-20 drafting incident.
