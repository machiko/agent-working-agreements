---
source_sha256: f3585694e8eb3fac5edd48fa744138d58c8f610016ef2759e0120d7bd0a98260
category: collaboration
tier: core
sources:
  - https://code.claude.com/docs/en/best-practices
  - https://github.com/obra/superpowers
incidents:
  - "A commit hook checked only the main worktree, so changes in another worktree were treated as passing tests"
  - "A pipe after the test command swallowed the exit code, reporting 0 even on failure"
last_reviewed: 2026-11-10
enforced_by:
  - audit:debug-statements
---

# Verification loop: completion needs evidence

## Define "done" before you start <!-- 慣例 -->

Before each task, name a check that can produce "pass" or "fail": which test to run, which command, which screen to look at. If you can't name one, confirm the acceptance criteria with the user first.

## Attach evidence when reporting completion <!-- 慣例 -->

A "done" report must include the **commands actually run** and the **key output**, e.g. the number of tests passed, the exit code, a screenshot. "Should pass" is not "passed": without evidence it isn't done; report it as "unverified".

The same goes for git and file operations: before reporting "committed", "reverted", or "deleted", check the real state with read-only commands (`git log`, `git status`, `ls`); don't conclude from conversation memory alone.

## Checks can lie too

**Why:** Each of these is a real case of "looked green, wasn't actually verified":

- A commit hook checked only staged files in the main worktree, while the changes were in another worktree. The hook saw "no changes", skipped, and that was taken as tests passing.
- When running the full test suite in the background, the script ended with `| tail`, which swallowed the exit code and reported 0 even on failure.
- A test file passed on its own but failed from running out of memory when the whole suite ran together.
- A UI change was checked only in the HMR view, while the new CSS class was never actually compiled in.

**How:**

- "Skipped" is not "passed". When you see skipped, 0 tests, or no output, track down why.
- Propagate exit codes explicitly (`exit $rc`); don't pipe test commands into anything that swallows the exit code.
- For wide-impact changes, run the full test suite, not just the related files.
- Check UI changes on the real page and take a screenshot; don't stop at whether the build succeeded.
