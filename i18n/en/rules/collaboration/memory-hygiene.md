---
source_sha256: 6e4d506a2ded981f0bb1e73c442bed21005d0da5fd2b27e0c2907f644b739dff
category: collaboration
tier: core
incidents:
  - "In-progress work in memory contradicted the board card; memory said the worktree was cleaned up but it still existed"
last_reviewed: 2026-11-10
---

# Memory hygiene: store each piece of information in one place

## In-progress state lives in exactly one place

Branch progress, commits, and next steps go in a single "live" place only (board card, issue, PR description). The agent's long-term memory holds only three kinds of things: cross-project lessons, reasons behind decisions, and pitfalls.

**Why:** An inventory found that "in-progress work" in the memory file duplicated the board card and contradicted it. For example, memory said the worktree had been cleaned up when it actually still existed. Anything maintained in two places will drift out of sync.

**How:**

- Only when the work is finished and the card archived, write the lessons worth keeping as a memory entry.
- When memory contradicts a live source, the live source (card, `git`, file system) wins; fix or delete the stale memory.
- Before relying on a file, function, or flag mentioned in memory, confirm it still exists.

## Memories must say "why"

Every feedback-type memory needs three parts: the rule itself, **why** (the triggering incident or the user's own words), and **how** (in which situations to apply it next time). A rule without its reason leaves you unable to decide whether it applies in edge cases.

## Don't store what the repo already tells you <!-- 慣例 -->

Code structure, git history, and anything already in the README or CLAUDE.md don't need to be remembered. If the user asks you to remember something like that, first ask which part is non-obvious, and remember only that part.

## Use absolute dates <!-- 慣例 -->

"Yesterday" and "next week" lose their meaning once written into memory; always convert them to `YYYY-MM-DD`.
