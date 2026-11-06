# agent-working-agreements

[![check](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml/badge.svg)](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml)

Working agreements for AI coding agents (Claude Code, Cursor, Codex, and friends), distilled from real incidents across database, API, Docker, and fullstack architectures.

> 本 repo 的規則本文以**繁體中文**撰寫，內容是一年多來和 AI coding agent 協作時實際踩過的坑與定案的做法。涵蓋跨語言通用工程地雷（資料庫/ORM、API/契約、Docker）與前端/特定框架守則。安裝時支援自動特徵偵測與問答挑選，之後隨時可以重跑調整。

Every rule follows the same shape: **the rule → why (the incident that caused it) → how to apply**. The "why" matters: without it, an agent can't judge edge cases.

## Quick start

In Claude Code:

```
/plugin marketplace add machiko/agent-working-agreements
/plugin install agreements@agent-working-agreements
/agreements:setup
```

Claude Code 2.1.275 or later can install in one step: `/plugin install agreements --marketplace machiko/agent-working-agreements`.

`/agreements:setup` asks up to four questions (scope, writing conventions, security, tech stack), previews what will change, and installs only after you confirm. Run it again at any time to add or remove rules; run `/agreements:setup 狀態` to only show what is installed, or `/agreements:setup 移除` to uninstall. Rules take effect from the next session.

## Updating

Third-party marketplaces don't auto-update by default. To pull a new release:

```
/plugin marketplace update agent-working-agreements
/plugin update agreements@agent-working-agreements    # or: /plugin → Installed → agreements → Update now
/reload-plugins
/agreements:setup 狀態
```

Updating the plugin does **not** touch the rules already copied into `~/.claude/rules/agent-agreements` (or your project). `/agreements:setup 狀態` shows which installed rules have a newer version; run `/agreements:setup` to apply them. Rules you edited by hand are kept unless you choose to overwrite them. See [CHANGELOG.md](CHANGELOG.md) for what changed.

To update automatically: `/plugin` → Marketplaces → agent-working-agreements → Enable auto-update.

## Start here

| If you… | Read or install |
|---------|-----------------|
| had an agent report "tests pass" when they didn't | [`collaboration/honesty`](rules/collaboration/honesty.md), [`collaboration/verification`](rules/collaboration/verification.md) |
| had a commit land on the wrong branch | [`collaboration/git-safety`](rules/collaboration/git-safety.md) |
| saw an agent delete or loosen tests to go green | [`collaboration/test-integrity`](rules/collaboration/test-integrity.md) |
| worry about `rm -rf`, force pushes, or production credentials | [`security/dangerous-operations`](rules/security/dangerous-operations.md) |
| have a CLAUDE.md / AGENTS.md that keeps growing | [`writing/lean-instructions`](rules/writing/lean-instructions.md) |
| write database migrations, queries, or ORMs | [`database/pitfalls`](rules/database/pitfalls.md) (exclusive locks, non-idempotent migrations, N+1, money precision) |
| build or consume backend APIs and integrations | [`api/pitfalls`](rules/api/pitfalls.md) (unbounded timeouts, swallowed exceptions, breaking changes, idempotency) |
| manage queues, background jobs, or Redis cache | [`async/pitfalls`](rules/async/pitfalls.md) (cache stampede, poison pills, distributed lock deadlocks, fan-out) |
| build modern Web frontends (React / Vue / Svelte / Next.js) | [`frontend/pitfalls`](rules/frontend/pitfalls.md) (Tailwind purge, component unmount leaks, SSR window access, prop mutation) |
| build modern Web backends (Node / Python / Go / PHP / Java) | [`backend/pitfalls`](rules/backend/pitfalls.md) (empty env defaults, dev-dependencies leakage, build-time secrets injection, export OOM) |
| run containers & local environments (Docker / Podman / Compose) | [`container/pitfalls`](rules/container/pitfalls.md) (single-file bind mounts inode drop, container orphan processes, inotify drop) |
| manage cloud, k8s, or observability logs/metrics | [`cloud/pitfalls`](rules/cloud/pitfalls.md) (high cardinality metrics, structured log PII leaks, port exhaustion, circular healthchecks) |

## What's inside

**Core** rules are always installed. **Optional** rules are picked during setup.

| Directory | Highlights |
|-----------|-----------|
| [`rules/collaboration/`](rules/collaboration/) | Never fabricate tool results · completion needs evidence ("skipped" is not "passed") · never weaken tests to go green · re-check the branch before every commit · one worktree per parallel session · surface decisions where the user actually looks · explicit code + guard tests over hidden mechanisms · memory hygiene |
| [`rules/security/`](rules/security/) | No production credentials where agents run · confirm every irreversible operation · deny rules and hooks are not a security boundary · keep PII files out of git · *optional:* SAST-safe patterns, data scope on every report and export, verifying TLS certificate chains (browsers forgive what mobile clients don't) |
| [`rules/writing/`](rules/writing/) | Keep instruction files lean · English test method names · *optional:* commit format with fixed verbs, CHANGELOG granularity, TL;DR-first cards, Taiwan vs. China terminology |
| [`rules/database/`](rules/database/) | *optional:* non-idempotent migrations · exclusive lock on `ALTER TABLE` · ORM N+1 query memory blowup · soft delete relation leaks · money precision with floats |
| [`rules/api/`](rules/api/) | *optional:* missing HTTP/RPC timeout leading to thread starvation · swallowing exceptions with empty catch blocks · breaking API contracts · missing idempotency keys |
| [`rules/async/`](rules/async/) | *optional:* cache stampede & dogpiling · poison pills in job queues · distributed lock deadlocks · unbounded concurrency fan-out · shared mutable state in coroutines/threads |
| [`rules/frontend/`](rules/frontend/) | *optional:* Tailwind dynamic class purge · uncleaned event listeners / timers in unmount · SSR window / document prerender crashes · mutating props breaking one-way data flow · reactivity loss on destructuring |
| [`rules/backend/`](rules/backend/) | *optional:* empty env strings overriding safe defaults · dev / mock dependencies leaking to production · build-time secrets injection failures · unchunked export memory OOM · non-standard primary key ORM access |
| [`rules/container/`](rules/container/) | *optional:* single-file bind mounts breaking after `git switch` · container orphan processes after killing client · macOS inotify event drop · test profiler overhead · reverse proxy whitelist omission |
| [`rules/cloud/`](rules/cloud/) | *optional:* high-cardinality metric label memory blowup · structured log PII / secret leaks · outbound connection pool & TIME_WAIT exhaustion · presigned URL expiry & scope · circular healthcheck deadlocks |
| [`templates/CLAUDE.md`](templates/CLAUDE.md) | A short global instruction file to start from |

Always-loaded core rules are capped at 400 lines in total (`scripts/check-budget.sh`, enforced in CI). Stack-specific rules use `paths` frontmatter, so they only load when the agent touches matching files.

### What a rule looks like

Generic rule sets say *"verify the branch before committing."* Here is the same idea as it ships in [`collaboration/git-safety`](rules/collaboration/git-safety.md), with the incident that produced it:

> **commit 前重新確認目前分支**
>
> 每次 `git commit` 前都先跑 `git branch --show-current`（或 `git status -sb`），不要沿用 session 開頭或上一次 commit 時看到的分支。
>
> **為什麼：** 使用者常在另一個終端切分支並 commit。agent 沿用舊資訊，就把 `feat:` commit 落在別人的 `fix/` 分支上了。
>
> **怎麼做：** 分支名稱要和 commit 類型相符……落錯分支時，用 cherry-pick 搬到正確的分支，原分支用 `branch -f` 退回。不要 rebase 已經 push 的分支。

The "why" tells the agent *when* the rule matters (another terminal, a stale session snapshot), so it can apply the rule to cases the text doesn't list.

## Other ways to install

### Without the plugin

```bash
git clone https://github.com/machiko/agent-working-agreements.git
cd agent-working-agreements

scripts/install.sh --detect                                 # auto-detect project markers & recommendations
scripts/install.sh --list                                   # see every rule id
scripts/install.sh --target ~/.claude/rules/agent-agreements \
  --select database/pitfalls,api/pitfalls --dry-run         # preview
# drop --dry-run to apply; core rules are always included
scripts/install.sh --target ~/.claude/rules/agent-agreements --status   # what's installed (read-only)
```

`--status` lists each installed rule with its title, whether it is always loaded or on-demand (with its `paths`), and whether it is up to date, has a newer version, was edited by hand, or is missing. Re-running only applies the difference. Files you edited by hand are kept unless you pass `--force`. `--uninstall` removes only the files the installer put there.

### Codex / other agents that read `AGENTS.md`

```bash
scripts/install.sh --agents-md AGENTS.md --select writing/commit-messages --dry-run   # preview
scripts/install.sh --agents-md AGENTS.md --select writing/commit-messages             # apply
scripts/install.sh --agents-md AGENTS.md --uninstall                                  # remove
scripts/install.sh --agents-md AGENTS.md --status                                     # what's installed (read-only)
```

The rules (core + your selection, frontmatter stripped) go between `<!-- agent-agreements:start -->` and `<!-- agent-agreements:end -->`. Anything you wrote outside that block is left byte-for-byte untouched; re-running replaces only the block and prints what changed. Codex reads at most 32 KiB of `AGENTS.md` by default (`project_doc_max_bytes`), so the installer warns when the file grows past that.

### Cursor IDE (`.cursor/rules/*.mdc`)

```bash
scripts/install.sh --cursor .cursor/rules --select vue/pitfalls,writing/commit-messages --dry-run   # preview
scripts/install.sh --cursor .cursor/rules --select vue/pitfalls,writing/commit-messages             # apply
scripts/install.sh --cursor .cursor/rules --uninstall                                              # remove
scripts/install.sh --cursor .cursor/rules --status                                                 # what's installed (read-only)
```

`--cursor` installs rules as Cursor `.mdc` files, automatically converting `paths` into Cursor's `globs` frontmatter and marking core rules with `alwaysApply: true`.

### GitHub Copilot Workspace (`.github/copilot-instructions.md`)

```bash
scripts/install.sh --copilot                                                     # injects into .github/copilot-instructions.md
scripts/install.sh --copilot custom-path.md --select frontend/pitfalls           # custom path with specific rules
scripts/install.sh --copilot --uninstall                                         # removes only injected agreements block
```

### Windsurf IDE (`.windsurfrules`)

```bash
scripts/install.sh --windsurf                                                    # injects into .windsurfrules
scripts/install.sh --windsurf --select frontend/pitfalls,backend/pitfalls        # specify rules
scripts/install.sh --windsurf --uninstall                                        # removes only injected agreements block
```

### GitHub Actions CI Automated Guardrail

```bash
scripts/install.sh --ci                                                          # installs .github/workflows/agent-audit.yml & scripts/audit.sh
```

Automatically audits every Pull Request and main push in GitHub Actions CI to catch swallowed exceptions, sensitive files, or deleted test assertions before merging.

## Active Guardrails & Incident Recording

In addition to passive prompt rules, active verification and incident recording skills are included:

### `/agreements:audit` (or `scripts/audit.sh`)

Scans git staged changes, diffs, or specific commits against critical agreements:
- **Swallowed Exceptions**: blocks empty `catch (e) {}` / `except: pass` in code diffs.
- **Test Integrity**: detects deleted test assertions.
- **Sensitive Files**: intercepts staged `.env`, `.csv`, `.sql`, or `storage/` data files.
- **Tailwind Purge**: warns against dynamic class string concatenation.
- **Branch Isolation**: warns when modifying directly on `main` / `master`.

Install as a Git pre-commit hook with one command:
```bash
scripts/audit.sh --install-hook
```

### `/agreements:record`

Whenever an agent makes an unexpected mistake, run `/agreements:record`. It guides you through a 3-step structured interview (*Symptom → Root Cause → How to Prevent*), strips sensitive info, and saves it into `.claude/rules/agent-agreements/custom/<name>.md`.

## Make it yours

These are *my* agreements. Fork and edit. In particular:

- [`rules/writing/commit-messages.md`](rules/writing/commit-messages.md) encodes one team's format. Replace it with yours.
- [`rules/writing/taiwan-terminology.md`](rules/writing/taiwan-terminology.md) only makes sense for zh-TW products.
- Laravel / Docker pitfalls are version-sensitive (written against Laravel 11, PHP 8.3, Docker Desktop on macOS).

## Works well with

[ECC](https://github.com/affaan-m/ECC) (formerly everything-claude-code) ships broad, language-specific rule sets (coding style, testing, security checklists). This repo is intentionally narrower: it only contains lessons that came from real incidents, and doesn't duplicate generic best practices.

## Contributing

Issues and PRs welcome, especially new pitfalls. Please keep the **rule → why → how** shape, and strip anything that identifies a real person, host, or organization. Material adapted from other projects must be under a compatible license (MIT, Apache-2.0, CC0, CC BY) and listed in `sources`; anything else may only be paraphrased with a link.

### Rule file format

Every file under `rules/` starts with frontmatter:

```yaml
---
category: collaboration     # must match the parent directory
tier: core                  # core = always installed; optional = picked during setup
label: "Laravel 地雷"        # optional rules only; option name shown in /agreements:setup
summary: "…"                # optional rules only; what it does and when to pick it
stack: laravel              # optional; tech stack or locale this rule targets
paths:                      # optional; Claude Code loads the rule only when matching files are touched
  - "**/*.php"
sources:                    # optional; external material the rule paraphrases or adapts
  - https://example.com/post
---
```

Claude Code strips frontmatter before loading a rule and ignores every key except `paths`, so these fields cost no context.

Before opening a PR, run (CI runs the same checks on ubuntu and macOS):

```bash
scripts/check-budget.sh      # validates frontmatter; fails if core rules exceed 400 lines
scripts/sanitize-check.sh    # scans publishable files for paths, private IPs, emails, keys
scripts/check-version.sh     # plugin.json, marketplace.json and CHANGELOG agree on the version
bash tests/install.test.sh   # installer tests (writes only to /tmp)
bash tests/audit.test.sh     # active guardrail audit tests (writes only to /tmp)
```

Releasing: Claude Code only offers an update when the `version` string changes, so every release bumps `version` in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` and adds a `CHANGELOG.md` section, all in the last PR before tagging.

`sanitize-check.sh` also reads a private denylist (default `~/.claude/agreements-harvest/denylist.txt`, one case-insensitive regex per line) with your own project names, colleagues, hosts and product terms. Keep that file out of the repo.

### Harvesting lessons from your own memory

Run `/agreements:harvest` from a clone of this repo (or your fork). It lists the feedback and project memories added since the last harvest (`scripts/harvest-scan.sh`), sorts them into *new rule / strengthen an existing rule / skip*, drafts de-identified rules for the ones you pick, runs the three checks above, and writes nothing until you confirm. The skill ships with the plugin but refuses to run anywhere except a git clone, so it never writes into the installed plugin. Fork the repo and you can use it on your own memory.

## License

[MIT](LICENSE)
