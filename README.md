# agent-working-agreements

Working agreements for AI coding agents (Claude Code, Codex, and friends), distilled from a year of real incidents on a production Laravel + Vue codebase.

> 本 repo 的規則本文以**繁體中文**撰寫，內容是一年多來和 AI coding agent 協作時實際踩過的坑與定案的做法。安裝時用問答挑選需要的規則，之後隨時可以重跑調整。

Every rule follows the same shape: **the rule → why (the incident that caused it) → how to apply**. The "why" matters: without it, an agent can't judge edge cases.

## Quick start

In Claude Code:

```
/plugin marketplace add machiko/agent-working-agreements
/plugin install agreements@agent-working-agreements
/agreements:setup
```

Claude Code 2.1.275 or later can install in one step: `/plugin install agreements --marketplace machiko/agent-working-agreements`.

`/agreements:setup` asks up to four questions (scope, writing conventions, security, tech stack), previews what will change, and installs only after you confirm. Run it again at any time to add or remove rules; run `/agreements:setup 移除` to uninstall. Rules take effect from the next session.

## Start here

| If you… | Read or install |
|---------|-----------------|
| had an agent report "tests pass" when they didn't | [`collaboration/honesty`](rules/collaboration/honesty.md), [`collaboration/verification`](rules/collaboration/verification.md) |
| had a commit land on the wrong branch | [`collaboration/git-safety`](rules/collaboration/git-safety.md) |
| saw an agent delete or loosen tests to go green | [`collaboration/test-integrity`](rules/collaboration/test-integrity.md) |
| worry about `rm -rf`, force pushes, or production credentials | [`security/dangerous-operations`](rules/security/dangerous-operations.md) |
| have a CLAUDE.md / AGENTS.md that keeps growing | [`writing/lean-instructions`](rules/writing/lean-instructions.md) |
| run a Laravel or Docker-compose stack | [`laravel/pitfalls`](rules/laravel/pitfalls.md), [`docker/pitfalls`](rules/docker/pitfalls.md) (load only when matching files are touched) |

## What's inside

**Core** rules are always installed. **Optional** rules are picked during setup.

| Directory | Highlights |
|-----------|-----------|
| [`rules/collaboration/`](rules/collaboration/) | Never fabricate tool results · completion needs evidence ("skipped" is not "passed") · never weaken tests to go green · re-check the branch before every commit · one worktree per parallel session · surface decisions where the user actually looks · explicit code + guard tests over hidden mechanisms · memory hygiene |
| [`rules/security/`](rules/security/) | No production credentials where agents run · confirm every irreversible operation · deny rules and hooks are not a security boundary · keep PII files out of git · *optional:* SAST-safe patterns, data scope on every report and export |
| [`rules/writing/`](rules/writing/) | Keep instruction files lean · English test method names · *optional:* commit format with fixed verbs, CHANGELOG granularity, TL;DR-first cards, Taiwan vs. China terminology |
| [`rules/laravel/`](rules/laravel/) | *optional:* `fake()` in production · `$model->id` silently null · empty `env()` values beating defaults · `package:discover` breaking Docker builds · … |
| [`rules/docker/`](rules/docker/) | *optional:* single-file bind mounts breaking after `git switch` · `restart` vs `--force-recreate` · Xdebug trigger mode · CI cache pitfalls |
| [`templates/CLAUDE.md`](templates/CLAUDE.md) | A short global instruction file to start from |

Always-loaded core rules are capped at 400 lines in total (`scripts/check-budget.sh`). Stack-specific rules use `paths` frontmatter, so they only load when the agent touches matching files.

## Other ways to install

### Without the plugin

```bash
git clone https://github.com/machiko/agent-working-agreements.git
cd agent-working-agreements

scripts/install.sh --list                                   # see every rule id
scripts/install.sh --target ~/.claude/rules/agent-agreements \
  --select writing/commit-messages,laravel/pitfalls --dry-run   # preview
# drop --dry-run to apply; core rules are always included
```

Re-running only applies the difference. Files you edited by hand are kept unless you pass `--force`. `--uninstall` removes only the files the installer put there.

### Codex / other agents that read `AGENTS.md`

```bash
scripts/install.sh --agents-md AGENTS.md --select writing/commit-messages --dry-run   # preview
scripts/install.sh --agents-md AGENTS.md --select writing/commit-messages             # apply
scripts/install.sh --agents-md AGENTS.md --uninstall                                  # remove
```

The rules (core + your selection, frontmatter stripped) go between `<!-- agent-agreements:start -->` and `<!-- agent-agreements:end -->`. Anything you wrote outside that block is left byte-for-byte untouched; re-running replaces only the block and prints what changed. Codex reads at most 32 KiB of `AGENTS.md` by default (`project_doc_max_bytes`), so the installer warns when the file grows past that.

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

Before opening a PR, run:

```bash
scripts/check-budget.sh      # validates frontmatter; fails if core rules exceed 400 lines
scripts/sanitize-check.sh    # scans publishable files for paths, private IPs, emails, keys
bash tests/install.test.sh   # installer tests (writes only to /tmp)
```

`sanitize-check.sh` also reads a private denylist (default `~/.claude/agreements-harvest/denylist.txt`, one case-insensitive regex per line) with your own project names, colleagues, hosts and product terms. Keep that file out of the repo.

### Harvesting lessons from your own memory

Run `/agreements:harvest` from a clone of this repo (or your fork). It lists the feedback and project memories added since the last harvest (`scripts/harvest-scan.sh`), sorts them into *new rule / strengthen an existing rule / skip*, drafts de-identified rules for the ones you pick, runs the three checks above, and writes nothing until you confirm. The skill ships with the plugin but refuses to run anywhere except a git clone, so it never writes into the installed plugin. Fork the repo and you can use it on your own memory.

## License

[MIT](LICENSE)
