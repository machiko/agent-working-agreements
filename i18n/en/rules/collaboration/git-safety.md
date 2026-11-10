---
source_sha256: f2bea6394d414551c9df41dfe1f3d474602f22dfd6d0e1b9ad7950457a871b62
category: collaboration
tier: core
incidents:
  - "Reused stale branch info and landed a feat commit on someone else's fix branch"
  - "Cut a fix branch from the wrong base, and an old release picked up features from another line"
  - "Parallel sessions shared a worktree, and a commit landed on someone else's branch"
last_reviewed: 2026-11-10
enforced_by:
  - audit:main-branch
  - guard:git-safety
---

# Git safety: branches, the staging area, parallel sessions

> Irreversible git operations (force push, `reset --hard`, deleting branches, rewriting pushed history) need confirmation every time; see [`../security/dangerous-operations.md`](../security/dangerous-operations.md).

## Recheck the current branch before committing

Before every `git commit`, run `git branch --show-current` (or `git status -sb`). Don't reuse the branch you saw at the start of the session or at the last commit.

**Why:** Users often switch branches and commit in another terminal. An agent relying on stale info landed a `feat:` commit on someone else's `fix/` branch.

**How:**

- The branch name must match the commit type (`feat` → `feature/`, `fix` → `fix/`, `chore` → `chore/`). If it doesn't, open a new branch with `git switch -c` first.
- Don't land feature or refactor commits directly on release/main; open a branch with the matching name and go through a PR. Only work belonging to that release itself (e.g. updating the CHANGELOG) may be committed directly.
- If reflog or status shows the branch was switched mid-work, stop and realign first.
- If a commit lands on the wrong branch, move it to the right one with cherry-pick and reset the original branch with `branch -f`. Don't rebase a branch that has already been pushed.

## Name the base explicitly when creating a branch

Before opening a fix/feature branch, ask "which release does this fix go into", then state the base explicitly with `git switch -c fix/x <target-branch>` instead of branching from the current HEAD.

**Why:** Once, a fix branch was cut from the development line in use at the time and then fast-forwarded into an old release. That release ended up carrying features unique to another line, touching dozens of files, and the only way out was to reset, cherry-pick, and push back with force-with-lease.

**How:** When release lines have features that "exist on only one line", run `git diff --stat A B` to confirm the differences before choosing a base. A new branch cut from `origin/<release>` automatically tracks that release; run `git branch --unset-upstream` first, or `git push`/`pull` will hit the release.

## Only add explicit paths

Don't use `git add -A` or `git add .`. Before committing, review the staged list file by file: `git status --short | grep -E '^[MDA] '`.

**Why:** After a squash (`reset --soft` then recommit) or an amend, the whole working tree sits in the staging area, which is exactly when untracked data files are most likely to get swept in. This actually happened: a CSV containing personal data was swept into a commit.

**How:** For `.csv`, `.xlsx`, `.sql`, `.json`, `.env*`, or paths under `storage/` or `data/`, always stop and ask the user. For personal-data rules, see [`../security/data-files.md`](../security/data-files.md).

## Give each parallel agent session its own worktree

Don't let multiple autonomous sessions (scheduled jobs, loops, background agents) share the same git worktree.

**Why:** HEAD is a single per-worktree state, not one copy per process. This actually happened: after session A created a docs branch and committed, parallel session B committed its lint fixes too, and they landed on A's branch. B then checked out main, restoring the working tree to old files, and A believed its edits had been reverted.

**How:**

- For parallel work, use `git worktree add` or the agent's worktree isolation, one branch per worktree.
- **Prevent parallel resource collisions**: when several sessions create database migrations at the same time, different worktrees can produce filenames with the same timestamp prefix down to the second; check for timestamp conflicts before merging. Give parallel local services (e.g. Docker containers, Vite dev servers) their own ports; don't share the same local state.
- Remove worktrees with `git worktree remove`, not `rm -rf`. For a worktree with initialized submodules, git always refuses without `--force`. Confirm `git status` is clean and the submodules have no uncommitted changes before adding `--force`.
- When isolation isn't possible, run `git status` and `git branch --show-current` before starting; right after committing, run `git log --oneline <branch>` to confirm the commit landed on your own branch.
