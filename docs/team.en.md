# Team guide

[繁體中文](team.md) | **English**

Get every AI agent on your team following the same rules. One policy file, `.agreements.json`, decides which rules to install, which agents to install them into, and which version to use. Your team's own rules live in `.agreements/rules/`. Both go into the repo, every change goes through a PR, and CI blocks changes that were not synced.

## Three steps

| Who | What | Command |
|-----|------|---------|
| Lead | Set up once, open a PR | `install.sh --team-init` (Claude Code: `/agreements:setup team`) |
| Members | Sync after clone or pull | `install.sh --sync` (Claude Code: `/agreements:setup sync`) |
| Anyone | Change the rules | edit `.agreements/rules/` or `.agreements.json` → `--sync` → open a PR |

If you don't want to clone this project, replace `install.sh` with the remote command:

```bash
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --sync
```

A remote `--sync` reads `agreements_version` from the policy file and downloads the version the team pinned, so people who download on different days still get the same version.

## 1. Lead: set up

From the project root:

```bash
scripts/install.sh --team-init --targets claude,cursor,agents-md --lang en
```

- `--targets`: the agents your team uses: `claude`, `cursor`, `agents-md`, `copilot`, `windsurf`. Without it, targets are detected from the project (a `.cursor/` directory adds cursor, and so on); if nothing is found, `claude,agents-md` is used.
- `--preset`: `smart` (default, recommends by stack), `full`, `core`.
- `--lang en`: install the English rules.
- `--no-ci`: skip the CI workflows.
- `--dry-run`: only list what would happen.

It then:

1. Writes `.agreements.json`, pinning the current version and enforcing `security/dangerous-operations` and `collaboration/git-safety`
2. Creates `.agreements/rules/README.md` (the team rule format)
3. Runs `--sync`: installs every target plus the Git pre-commit and pre-push hooks
4. Installs the CI gate (`agent-audit.yml`) and the drift check (`agent-agreements-drift.yml`)
5. Lists the files to commit and the command to send to members

Review, commit, and open a PR.

### The generated policy

```json
{
  "preset": "smart",
  "enforce_rules": ["security/dangerous-operations", "collaboration/git-safety"],
  "targets": ["claude", "cursor", "agents-md"],
  "agreements_version": "1.6.0",
  "git_hooks": true,
  "lang": "en"
}
```

| Field | Effect |
|-------|--------|
| `targets` | `--sync` installs or updates each one; `--check-drift` checks each one |
| `agreements_version` | `--sync` stops when the tool is a different version instead of silently upgrading or downgrading |
| `git_hooks` | when `true`, `--sync` installs Git hooks (hooks are not versioned, so every member syncs once) |
| `enforce_rules` | rules that must be installed; team rules are written `custom/<name>` |

All fields are in [`schema/v1.json`](../schema/v1.json).

## 2. Members: sync

```bash
scripts/install.sh --sync
```

- The first run installs every target and the Git hooks.
- Run it again whenever you pull changes to the policy or team rules. With nothing to change it prints "已同步，沒有變更" (already in sync).
- Format problems in team rules are listed with ⚠. They are hints and do not block the sync.
- Every sync recomputes the rule set from the policy: changes to `preset` or `enforce_rules` take effect after syncing, and rules you added yourself with `--select` are removed.
- When `git_hooks` is `true` and the project has no `scripts/audit.sh`, a copy is added for the pre-commit audit; commit it too.

## 3. Adding a team rule

1. Add `<name>.md` to `.agreements/rules/` using lowercase letters, digits and hyphens; the format is in that directory's `README.md`. In Claude Code, `/agreements:record` interviews you and writes the file there.
2. Run `--sync`. The rule is installed as `custom/<name>` into every target.
3. Commit the rule with the synced changes and open a PR.

To make a rule impossible to drop, add `custom/<name>` to `enforce_rules`.

Rules that older versions of `/agreements:record` wrote to `.claude/rules/agent-agreements/custom/` are only read by your own Claude Code. Move them to `.agreements/rules/` and run `--sync` to share them with the team and apply them to other agents; `doctor.sh` tells you how many are left.

### Team guard rules

To stop Claude Code from running certain commands (for example `helm uninstall`, or connecting straight to the production database), write them in `.agreements/guard-rules.tsv`. `--team-init` creates a template that contains only comments.

1. One rule per line, tab-separated: rule, pattern, message, optional allow pattern. The format matches the built-in [`scripts/lib/guard-rules.tsv`](../scripts/lib/guard-rules.tsv). Try rules in the [Playground](https://machiko.github.io/agent-working-agreements/) first.
2. Add a command that should be blocked (`deny`) and one that should pass (`allow`) to `.agreements/guard-cases.tsv`.
3. Run `--sync`, check that it reports the team guard rules as passing (團隊攔截規則：通過), then commit and open a PR.

- The rules travel with the repo and need no reinstall: when Claude Code runs a command, it walks up from the working directory to the policy file and reads `.agreements/guard-rules.tsv` next to it.
- Built-in rules are checked first. Team rules can only block more, never relax a built-in rule.
- A broken line (missing columns, a regex that does not compile, or one that matches the empty string) is skipped with a warning at run time; `--sync` lists it and `--check-drift` fails.
- Only Claude Code, which supports PreToolUse hooks, enforces these rules; Cursor, Copilot and other tools do not run them.

## 4. Upgrading

1. With the new tool version, change `agreements_version` in `.agreements.json` to the new version.
2. Run `--sync`; the rules are upgraded.
3. Commit together and open a PR. Members run `--sync` after pulling.

## When CI blocks you

The drift check (`doctor.sh --check-drift`) fails when:

| Message | Cause | Fix |
|---------|-------|-----|
| 缺少團隊守則 (team rule missing) | a rule was added to `.agreements/rules/` without syncing | run `--sync` and commit |
| 團隊守則與 .agreements/rules 不一致 (team rule differs) | a rule changed without syncing, or an installed file was edited by hand | run `--sync`; hand-edited files need `--force` to be overwritten |
| 已從 .agreements/rules 移除但仍安裝著 (removed but still installed) | a rule was deleted without syncing | run `--sync` |
| 安裝版本應為 X (installed version should be X) | the policy version changed but the rules were not reinstalled | run `--sync` with that version |
| 強制守則尚未安裝／狀態異常 (enforced rule missing or modified) | an `enforce_rules` entry is missing or edited | run `--sync` |
| 尚未安裝守則 (no rules installed) | a target in `targets` is not installed | run `--sync` |
| 團隊攔截規則…或案例檔有問題 (team guard rules or cases have problems) | a rule is broken, or a case's verdict differs from what it expects | fix the listed lines and run `--sync` until it passes |

GitLab, Bitbucket and other platforms don't get the drift workflow automatically. Add this step to your CI:

```bash
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --check-drift .
```
