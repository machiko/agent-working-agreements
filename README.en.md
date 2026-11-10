# agent-working-agreements

[![check](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml/badge.svg)](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml)
[![release](https://img.shields.io/github/v/release/machiko/agent-working-agreements)](https://github.com/machiko/agent-working-agreements/releases)
[![license](https://img.shields.io/github/license/machiko/agent-working-agreements)](LICENSE)

[繁體中文](README.md) | **English**

Working agreements and defensive rules for AI coding agents (Claude Code, Cursor, GitHub Copilot, Windsurf, Codex, and more).

Drawn from real production incidents in long-term work with AI agents. No generic best-practice filler: the focus is on **blocking high-risk operations, catching engineering pitfalls, and protecting code and test integrity**.

> The rule bodies are written in **Traditional Chinese**, with a line-by-line English translation under [`i18n/en/rules/`](i18n/en/rules/). Add `--lang en` when installing to get the English rules. Every rule follows the same structure: **Rule → Why (the real incident that triggered it) → How (concrete guidance)**. An agent can only make the right call in edge cases if it understands the "why".

---

## ⚡ Design Principles

1. **Incident-driven**: only problems that AI has actually broken in production are included (e.g. silently swallowed exceptions, dynamic Tailwind classes purged, foreign-key deadlocks, overly broad IAM grants).
2. **Strict context budget**: the always-loaded Core rules are capped at **400 lines** in CI; stack and domain rules (Optional) are **loaded on demand**, only when the agent touches related files, so they don't waste the context window.
3. **Zero-friction ingestion**: supports copying standalone files, translating to Cursor `.mdc` format, and safe injection into a single file via marker blocks (existing content is preserved, existing settings are not overwritten).
4. **Active guardrails**: beyond passive prompt instructions, Git hooks, a CLI audit, and CI gates catch pitfalls at commit and PR time.

---

## 💡 Why This Project? (What Makes It Different)

Most community prompt/rules collections are "static advice" that agents forget or work around in long contexts or complex situations. Typical runtime tools usually target a single environment or block only a few terminal commands, and cannot defend against architecture and code pitfalls.

This project combines "incident-driven engineering rules" with "multi-layer active defense (Hooks + Policy + Schema + CI)" to build a complete governance line for agent collaboration:

| Dimension | Typical rules / prompt collections | Single-point runtime hook tools | This project (`agent-working-agreements`) |
| :--- | :--- | :--- | :--- |
| **Defense depth** | Prompt layer only (passive advice) | Terminal hooks only (single-point blocking) | **Three layers**: prompt rules + runtime hooks + CI gates |
| **Cross-agent support** | Maintained and copied by hand per tool | Usually tied to one tool | **Single-source compile**: one-step sync to Claude Code, Cursor, Copilot, Windsurf, AGENTS.md |
| **Engineering depth** | Generic best practices, not incident-specific | Filters a few terminal commands (e.g. rm, push) | **Incident-driven rule library** (deadlocks, swallowed exceptions, mock pollution, tenant isolation, and other concrete incidents) |
| **Context budget** | No limits, easily bloats the window | Not applicable | **Strict budget**: Core rules < 400 lines, the rest loaded on demand by glob/path |
| **Team governance** | No standard, everyone does their own thing | Usually local or personal settings only | **Policy as Code**: `.agreements.json`, JSON Schema v1, and non-bypassable guardrails |
| **Health checks and drift** | No verification; edited or deleted rules go unnoticed | One-off status reports only | **Automated checkup and repair**: `doctor.sh` scores and fixes, CI `--check-drift` blocks drifting PRs |

---

## 🚀 Cross-Agent Support Matrix and Installation

| Support tier | Tool | Protection layer | Features | Recommended install (no manual clone) |
|---|---|---|---|---|
| **Tier 1 (native, full)** | **Claude Code** | Real-time terminal interception + Git gate | Full skills, PreToolUse hooks that block commands in real time, single-round Q&A setup, checkup and self-review | `/plugin marketplace add machiko/agent-working-agreements`<br>`/plugin install agreements@agent-working-agreements` |
| **Tier 2 (deep integration)** | **Cursor IDE** | Git gate (commit/push) | Native `.cursor/rules/*.mdc`, with precise `globs` on-demand loading and `alwaysApply` | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --cursor .cursor/rules --lang en` |
| **Tier 2 (instructions file)** | **GitHub Copilot** | Git gate (commit/push) | Block insertion into native `.github/copilot-instructions.md` with clean updates | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --copilot --lang en` |
| **Tier 2 (rules file)** | **Windsurf** | Git gate (commit/push) | Native `.windsurfrules` block management | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --windsurf --lang en` |
| **Tier 3 (generic output)** | **AGENTS.md / Codex / Aider** | Git gate (commit/push) | Marker block following the common convention, loadable by any language and agent | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --agents-md AGENTS.md --lang en` |
| **Universal safety net** | **Any terminal or IDE** | Git gate (commit/push) | Git `pre-push` blocks force pushes, Git `pre-commit` catches leaked credentials | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --git-hooks` |

> [!NOTE]
> **Protection layer boundaries**:
> - **Terminal-level interception**: only works in environments that support the `PreToolUse` event (such as Claude Code). It stops a command the moment the agent types `rm -rf /` or tries to send `.env` out.
> - **Git-level gatekeeper**: in Cursor, Copilot, Windsurf, and plain terminals, the defense centers on universal Git hooks (`pre-commit` and `pre-push`), catching destructive changes and sensitive data leaks at commit and push time.

---

## 🚀 Install for Your AI Agent

### 1. Claude Code (Tier 1, native full support, most recommended)

**No need to clone this project or run detection scripts by hand.** Run these directly in Claude Code from your project directory:

```bash
# 1. Add the marketplace and install the plugin
/plugin marketplace add machiko/agent-working-agreements
/plugin install agreements@agent-working-agreements

# 2. Start interactive setup (detects the current project's stack and recommends a rule set)
/agreements:setup
```

> [!TIP]
> When you run `/agreements:setup`, Claude Code scans the current project's stack in the background and presents a "⚡ Smart project recommendation" in the conversation; one step completes the install. On a first install it also asks which language to install (Traditional Chinese or English).

---

### 2. Cursor, Copilot, Windsurf, AGENTS.md, or CLI Script Install

#### ⚡ Option 1: Remote one-line install (no clone, most recommended)

From the target project's root, run the line for your editor:

```bash
# 🔹 Cursor IDE (.cursor/rules/*.mdc)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --cursor .cursor/rules --lang en

# 🔹 GitHub Copilot (.github/copilot-instructions.md)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --copilot --lang en

# 🔹 Windsurf IDE (.windsurfrules)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --windsurf --lang en

# 🔹 AGENTS.md / Codex / Aider
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --agents-md AGENTS.md --lang en

# 🔹 Install the universal Git hooks safety net (pre-push / pre-commit)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --git-hooks
```
*(You can append `--select frontend/pitfalls,database/pitfalls` at any time to choose specific rules. `--lang en` installs the English rules; without it you get the Traditional Chinese originals. Later `--update` runs keep the same language.)*

#### 📦 Option 2: Local clone (offline work or advanced customization)

To keep the scripts locally for customization or review, clone the project first:

```bash
git clone https://github.com/machiko/agent-working-agreements.git
cd agent-working-agreements
```

#### Step A: Detect the target project's stack (get a recommended rule list)
Pass the **target project's path** (e.g. `../my-project`) to analyze it:
```bash
scripts/install.sh --detect /path/to/your-project
```
*(If you run it from inside the target project, pass `.` or omit the path.)*

#### Step B: Apply to the target project for your editor

##### 🔹 Cursor IDE (`.cursor/rules/*.mdc`)
Translated into native Cursor `.mdc` files: Core rules are marked `alwaysApply: true`, and stack-specific rules are converted to `globs` conditions:
```bash
# Preview the install
scripts/install.sh --cursor /path/to/your-project/.cursor/rules --select frontend/pitfalls,database/pitfalls --lang en --dry-run

# Apply to the target project
scripts/install.sh --cursor /path/to/your-project/.cursor/rules --select frontend/pitfalls,database/pitfalls --lang en
```

##### 🔹 GitHub Copilot (`.github/copilot-instructions.md`)
Injected safely through an HTML marker block, **leaving all other existing instructions in the file untouched**:
```bash
scripts/install.sh --copilot /path/to/your-project/.github/copilot-instructions.md --select frontend/pitfalls,backend/pitfalls --lang en
```

##### 🔹 Windsurf IDE (`.windsurfrules`)
Injected into the target project's root `.windsurfrules` through a safe marker block:
```bash
scripts/install.sh --windsurf /path/to/your-project/.windsurfrules --select frontend/pitfalls,security/supply-chain --lang en
```

##### 🔹 OpenAI Codex / Aider / agents that support `AGENTS.md`
Injected into the project root's `AGENTS.md`. Frontmatter is stripped, surrounding text is preserved, and a warning is built in for Codex's 32 KiB read limit:
```bash
scripts/install.sh --agents-md /path/to/your-project/AGENTS.md --select database/pitfalls,api/pitfalls --lang en
```

##### 🔹 Generic CLI agents or custom directories (Antigravity, Aider, etc.)
If your tool supports a custom rules directory or prompt loading:
```bash
scripts/install.sh --target /path/to/your-project/my-rules-dir --select frontend/pitfalls --lang en
```

---

### 3. Active Gate Setup (CI on Any Platform / Local Git Hook)

The core audit and gate logic lives in the standalone script [`scripts/audit.sh`](scripts/audit.sh) (pure Bash, no third-party dependencies). Pick what fits your environment:

#### 🟢 Cloud CI/CD workflows (all platforms)
Supports mainstream platforms and toolchains, generating the matching gate script:
```bash
scripts/install.sh --ci                 # Auto-detect the project environment (GitHub / GitLab / Bitbucket / pre-commit)
scripts/install.sh --ci github          # Install a GitHub Actions workflow (.github/workflows/agent-audit.yml)
scripts/install.sh --ci gitlab          # Install a GitLab CI workflow (.gitlab-ci.yml)
scripts/install.sh --ci bitbucket       # Install a Bitbucket Pipelines workflow (bitbucket-pipelines.yml)
scripts/install.sh --ci pre-commit      # Install a Python pre-commit framework config (.pre-commit-config.yaml)
```

#### 🟡 Local development or private servers (no platform required)
**No specific cloud platform needed.** Install it directly as a local Git pre-commit hook:
```bash
scripts/audit.sh --install-hook
```
Works for any Git project on your machine and blocks at `git commit` time, keeping bad code out of history.
* The hook is written to the directory that `git rev-parse --git-path hooks` points to, so it works with git worktrees and projects that set `core.hooksPath` (e.g. husky).
* An existing pre-commit/pre-push not installed by this tool is backed up as `<name>.agreements-bak` and runs after the gate check passes, so your original hook is kept.
* If the project has no `scripts/audit.sh`, the audit script from install time is used instead; if neither is found, it only prints a warning and does not block the commit.

---

## 🛡️ Active Protection and Checkup Tools

Beyond static prompt rules, the project ships a full set of active audit and checkup tools:

### 🩺 Rule Health Checkup, Auto-Fix, and CI Drift Detection (`scripts/doctor.sh`)
Diagnoses the project's rule setup, version freshness, Git gates, and CI workflow readiness in one run, producing a 0–100 overall score. Supports `--fix` to fill in what's missing and a CI drift check:

```bash
# Check the current project
scripts/doctor.sh

# Auto-fix missing Git hooks, CI files, and outdated rules
scripts/doctor.sh --fix

# Pin the currently installed rules into a project .agreements.json policy file
scripts/doctor.sh --init-policy

# For CI: verify rules are untampered, core rules are complete, and the team policy is met (exits 1 on drift to block the PR)
scripts/doctor.sh --check-drift

# Claude Code commands
/agreements:doctor
/agreements:doctor fix
/agreements:doctor drift
/agreements:doctor init-policy
```

### 📋 Agent Self-Review of Changes (`scripts/review.sh`)
Before committing or declaring a task done, checks code changes against the full rule set and outputs a standard Markdown self-review report:
```bash
scripts/review.sh              # Review uncommitted changes (or HEAD)
scripts/review.sh --base main  # Review the diff against the main branch
scripts/review.sh --staged     # Review staged changes

# Claude Code command
/agreements:review
```

### 🏢 Team Policy File and Enforced Governance (`.agreements.json`)
Put `.agreements.json` or `.agreementsrc` in the project root to lock team standards; they are enforced automatically whenever a developer or agent runs the installer:
```json
{
  "$schema": "https://raw.githubusercontent.com/machiko/agent-working-agreements/main/schema/v1.json",
  "version": "1.0",
  "preset": "smart",
  "enforce_rules": [
    "security/dangerous-operations",
    "collaboration/git-safety",
    "security/tenant-isolation"
  ],
  "prohibit_disable_hooks": false,
  "lang": "zh-TW"
}
```
* When you run `install.sh` or `/agreements:setup`, it searches upward for a policy file in the project or monorepo root and locks in the enforced rules, avoiding differences between personal setups. The search stops at the git root; outside a git repo, policy files in the home directory are not read.
* `preset` sets the team's default install plan (`"smart"` smart recommendation, `"full"` full defense, `"core"` minimal core). When installing without an explicit `--select`, this plan is the baseline, and `enforce_rules` are added on top.
* `lang` sets the team's rule language (`"zh-TW"` or `"en"`). English-speaking teams should set `"lang": "en"`. It applies when `--lang` is not given; the precedence is `--lang` → policy file `lang` → language of the existing install record → `zh-TW`. `doctor.sh --check-drift` treats an installed language that differs from the policy as drift.
* With `"prohibit_disable_hooks": true`, the safety net is locked: `AGREEMENTS_HOOKS_DISABLE=1` is ignored, so agents or scripts cannot bypass interception.
* Comes with a full JSON Schema ([`schema/v1.json`](schema/v1.json)), giving autocompletion for all 28 rule IDs and structure validation in modern editors such as VS Code and Cursor.
* Generate a standard policy file from an existing install with `scripts/doctor.sh --init-policy` or `/agreements:doctor init-policy`.
* When CI runs `scripts/doctor.sh --check-drift`, it checks that the project has installed every rule the policy file requires.

### 🛡️ Runtime Protection (Runtime Hooks & Universal Git Hooks)
Through Claude Code's plugin hook mechanism, high-risk destructive commands are blocked the moment the agent runs them:
- 🛑 **No force push**: blocks `git push --force`, `-f` (including combined forms like `-uf`), and `+refspec` in real time; `--force-with-lease` is allowed
- 🛑 **No silent code wipes**: blocks every `git reset --hard` and `git clean -f` (`git clean -n` previews are not affected)
- 🛑 **No destructive root commands**: blocks recursive deletion of `/`, `~`, `$HOME`, and recursive `chmod 777`
- 🛑 **No credential leaks**: blocks commands that send `.env` via `curl`, `wget`, `nc`, `scp`, etc.
- 💡 When blocked, the agent receives the reason; set `AGREEMENTS_HOOKS_DISABLE=1` to temporarily skip interception (has no effect when the team policy sets `prohibit_disable_hooks`)
- ⚙️ Interception rules are kept in [`scripts/lib/guard-rules.tsv`](scripts/lib/guard-rules.tsv). With `python3` available, commands are parsed in Python; without it, Bash matches the same rules with the same behavior
- ⚠️ Known limitation: matching works on the command string, so merely "mentioning" these commands inside quotes (e.g. `echo "git push --force"`) is also blocked

**Install the cross-tool universal guardrails for Cursor, Windsurf, or plain terminals:**
```bash
scripts/hook-guard.sh --install-git-hooks
```
Sets up Git `pre-push` (blocks non-fast-forward force pushes) and `pre-commit` (active change audit), so every editor gets the same safety net. `pre-push` cannot see flags like `--force-with-lease`, so any overwrite of the remote is blocked; when you really need it, run `AGREEMENTS_HOOKS_DISABLE=1 git push …` with your team's agreement.

### 🔍 Active Change Audit (`scripts/audit.sh`)
Scans Git staged changes, diffs, or a given commit to catch common high-risk changes:
- 🚫 **Silently swallowed errors**: empty `catch (e) {}` or `except: pass` in code
- 🚫 **Broken test integrity**: test assertions quietly deleted
- 🚫 **Sensitive data leaks**: `.env*`, `.sql`, credentials, and database dumps accidentally staged
- 🚫 **Wide-open permissions**: `chmod 777` and wildcard IAM (`Action: "*"` / `Resource: "*"`)
- ⚠️ **Purged dynamic styles**: warns about Tailwind classes built by dynamic string concatenation in frontend code (to avoid purging)
- ⚠️ **Direct changes to the main branch**: warns about edits made directly on `main` / `master` without a branch

**Install as a local Git pre-commit hook:**
```bash
scripts/audit.sh --install-hook
```

### 📝 Capture Incidents on the Spot (`/agreements:record`)
When the agent makes a new basic mistake, run this skill. It walks you through a guided Q&A (*symptom → root cause → prevention*), anonymizes the result, and saves it as a custom rule:
```bash
/agreements:record
```

---

## 📚 Rule Catalog

Links below point to the English version of each rule; the Traditional Chinese source is at the same path under [`rules/`](rules/).

### 1. Core Rules (Core, always installed)
Kept under a **400-line** budget; baseline agreements that apply across all languages and frameworks:

| Area | Rule | Focus |
|------|---------|---------|
| **Collaboration** | [`collaboration/honesty`](i18n/en/rules/collaboration/honesty.md) | Honest reporting: only report what actually happened |
| **Collaboration** | [`collaboration/test-integrity`](i18n/en/rules/collaboration/test-integrity.md) | Test integrity: don't change tests just to go green |
| **Collaboration** | [`collaboration/git-safety`](i18n/en/rules/collaboration/git-safety.md) | Git safety: branches, the staging area, parallel sessions |
| **Collaboration** | [`collaboration/verification`](i18n/en/rules/collaboration/verification.md) | Verification loop: completion needs evidence |
| **Collaboration** | [`collaboration/communication`](i18n/en/rules/collaboration/communication.md) | Communication: let the user decide with the least effort |
| **Collaboration** | [`collaboration/design-judgment`](i18n/en/rules/collaboration/design-judgment.md) | Design judgment: one explicit pattern, plus a guard test |
| **Collaboration** | [`collaboration/memory-hygiene`](i18n/en/rules/collaboration/memory-hygiene.md) | Memory hygiene: store each piece of information in one place |
| **Security** | [`security/dangerous-operations`](i18n/en/rules/security/dangerous-operations.md) | Dangerous operations and credentials |
| **Security** | [`security/data-files`](i18n/en/rules/security/data-files.md) | Keep personal data and sensitive files out of version control |
| **Writing** | [`writing/lean-instructions`](i18n/en/rules/writing/lean-instructions.md) | Lean rule files: every line must earn its place |
| **Writing** | [`writing/test-naming`](i18n/en/rules/writing/test-naming.md) | Test naming |

---

### 2. Domain and Architecture Pitfall Rules (Optional, install as needed)
Most have a `paths` condition and are loaded into context only when related files are touched. `collaboration/sdlc-lifecycle`, `security/tenant-isolation`, and the "Style conventions" rules have no `paths` and are always loaded once installed:

| Category | Rule | Real incidents it guards against |
|------|---------|-------------------|
| **AI and LLM apps** | [`ai/pitfalls`](i18n/en/rules/ai/pitfalls.md) | **AI and LLM application pitfalls**: cascading failures from external LLM calls without timeouts, prompt-injection jailbreaks, streams that keep burning memory and tokens after disconnect, and unmasked PII in vector retrieval |
| **Automated testing** | [`testing/pitfalls`](i18n/en/rules/testing/pitfalls.md) | **Testing and mock pitfalls**: global mocks leaking without reset, static sleep delays causing flaky tests, integration tests leaving the database dirty without rollback, over-mocking private implementation details, and non-deterministic assertions |
| **Frontend architecture** | [`frontend/pitfalls`](i18n/en/rules/frontend/pitfalls.md) | **Modern frontend and component pitfalls**: memory leaks on React/Vue/Next.js/Svelte component unmount, dynamic Tailwind classes purged, window/document errors during SSR/prerendering, prop mutation breaking one-way data flow, and reactivity lost through destructuring |
| **Backend services** | [`backend/pitfalls`](i18n/en/rules/backend/pitfalls.md) | **Web backend and application service pitfalls**: empty env vars overriding defaults, dev/test dependencies leaking into production, build steps tripping secret injection, OOM on exports and large jobs, access to non-standard primary keys |
| **Database** | [`database/pitfalls`](i18n/en/rules/database/pitfalls.md) | **Database and ORM pitfalls**: locking tables in production, non-idempotent migrations, N+1 query explosions, soft-delete dirty reads, and floating-point precision on money |
| **API integration** | [`api/pitfalls`](i18n/en/rules/api/pitfalls.md) | **API and integration contract pitfalls**: cascading failures from external calls without timeouts, silently swallowed errors, breaking field changes, and duplicate charges from missing idempotency keys |
| **Async** | [`async/pitfalls`](i18n/en/rules/async/pitfalls.md) | **Async, queue and cache pitfalls**: cache avalanche and stampede, poison messages retried forever, distributed locks without leases deadlocking, unbounded concurrent fan-out overwhelming downstream services, shared state races across coroutines |
| **Containers** | [`container/pitfalls`](i18n/en/rules/container/pitfalls.md) | **Container and local virtualization pitfalls**: single-file bind mount inode breaks after switching branches, container processes surviving after the terminal kills the client, Xdebug/profilers slowing tests, lost file system events under macOS virtualization, reverse proxy route allowlists |
| **Cloud native** | [`cloud/pitfalls`](i18n/en/rules/cloud/pitfalls.md) | **Cloud-native, logging, and observability pitfalls**: high-cardinality metrics exploding memory, structured logs leaking unmasked PII and tokens, connection pools not reused exhausting ephemeral ports, presigned URL permissions out of control, circular health-check deadlocks |
| **Supply-chain security** | [`security/supply-chain`](i18n/en/rules/security/supply-chain.md) | **Supply-chain security and dependency pitfalls**: package hallucination and dependency poisoning, floating versions and lockfile drift, over-permissive wildcard grants, build-time secrets left in multi-stage image layers, leaked fake test credentials |
| **Collaboration process** | [`collaboration/sdlc-lifecycle`](i18n/en/rules/collaboration/sdlc-lifecycle.md) | **Software lifecycle standard**: defines the delivery standards and quality gates for the 6 stages (spec, implementation, testing, acceptance, merge, release) of medium-to-large feature work |
| **Security compliance** | [`security/sast-safe-patterns`](i18n/en/rules/security/sast-safe-patterns.md) | **SAST-safe coding patterns**: avoid, at write time, the 8 patterns that Checkmarx-style scanners commonly flag. Pick this only if the project runs SAST scans |
| **Security compliance** | [`security/tenant-isolation`](i18n/en/rules/security/tenant-isolation.md) | **Multi-tenant and export data isolation**: guards against BOLA / IDOR authorization flaws; lists, statistical reports, and async exports must enforce tenant/user scope filtering, and background jobs must pass authorization context explicitly |
| **Style conventions** | [`writing/commit-messages`](i18n/en/rules/writing/commit-messages.md) | **Commit format**: commit messages use the "type: verb description" format with a fixed set of Traditional Chinese verbs. If your team already has its own format, don't select this, or edit it after installing |
| **Style conventions** | [`writing/changelog`](i18n/en/rules/writing/changelog.md) | **How to write a CHANGELOG**: one entry per user-visible feature, 15-20 entries per release, deployment steps as a numbered list. Pick this only if you maintain a CHANGELOG |
| **Style conventions** | [`writing/docs-and-cards`](i18n/en/rules/writing/docs-and-cards.md) | **Writing task cards**: open Notion/Jira cards with a TL;DR, use tables heavily, and keep PM-facing sections in plain language. Pick this if you have the agent write cards or planning docs |
| **Style conventions** | [`writing/taiwan-terminology`](i18n/en/rules/writing/taiwan-terminology.md) | **Taiwan terminology**: when writing Chinese UI text and docs, avoid Mainland China terms (用戶→使用者, 默認→預設). Pick this only if the product's users are in Taiwan |

---

## 🛠️ Manage, Update, and Uninstall

### Checking for and applying updates
When used through Claude Code, `/agreements:setup` **checks for updates automatically**:
- If a newer version of the installed rules is available, it offers **"(Recommended) Update to the latest version in one step"** without asking the setup questions again.
- You can also run `/agreements:setup 更新` at any time to preview the diff and apply it in one step.

With the CLI script, add `--update` to upgrade to the latest version, reusing your existing selection (and language):
```bash
# Update a Claude Code rules directory
scripts/install.sh --target ~/.claude/rules/agent-agreements --update

# Update a Cursor rules directory
scripts/install.sh --cursor .cursor/rules --update

# Update single-file injections (AGENTS.md / Copilot / Windsurf)
scripts/install.sh --agents-md AGENTS.md --update
scripts/install.sh --copilot --update
scripts/install.sh --windsurf --update
```

### Install record (Profile Schema v1)
The `.agreements-profile` file in the install directory follows a strict **Schema v1** format, recording the installed version, the SHA256 hash of each rule at install time, and team policy settings.
* When upgrading from 0.x, `--update` or `/agreements:setup` **migrates the record automatically and backward-compatibly**; no manual steps are needed.

### Viewing install status
Check the title, load condition, and latest-version status of installed rules at any time:
```bash
scripts/install.sh --target ~/.claude/rules/agent-agreements --status
scripts/install.sh --cursor .cursor/rules --status
scripts/install.sh --agents-md AGENTS.md --status
```

### Clean uninstall
Removes only the rule files or marker blocks this tool created, **never touching any custom files or existing settings**:
```bash
scripts/install.sh --target ~/.claude/rules/agent-agreements --uninstall
scripts/install.sh --cursor .cursor/rules --uninstall
scripts/install.sh --copilot --uninstall
scripts/install.sh --windsurf --uninstall
scripts/install.sh --agents-md AGENTS.md --uninstall
```

---

## 🤝 Contributing and Quality Checks

Issues and PRs sharing new pitfalls you've hit are welcome! The full flow from incident report to rule PR is in [CONTRIBUTING.en.md](CONTRIBUTING.en.md). With Claude Code, `/agreements:record` can turn a captured incident into an incident report draft, which is only submitted after you confirm it. Before submitting a rule, read the [rule quality standard](docs/rule-quality.md): every entry needs an incident basis (**Why**, or for pitfall rules **Symptom → Root cause → How**), the frontmatter must list `incidents` (incident sources) and `last_reviewed` (review date), and any real personal data, hosts, or company identifiers must be removed. Entries without an incident basis must be marked `<!-- 慣例 -->` or `<!-- 參考 -->` in the heading.

The rule source is written in Traditional Chinese under `rules/`. When you add or change a rule, update the English translation in `i18n/en/rules/` line by line, then run `scripts/check-i18n.sh --stamp en <id>`. If you can't write Chinese, feel free to open an issue or PR in English; the maintainers will help with the Chinese source.

New rules should also come with evaluation scenarios showing that "with the rule installed, the agent makes fewer mistakes". See [`evals/README.md`](evals/README.md) for the format and how to run them.

CI runs strict automated checks:
```bash
scripts/check-budget.sh      # Frontmatter (incl. incidents, last_reviewed, deprecated) and Core rules under 400 lines
scripts/lint-rules.sh        # Rule content: entry structure, vague wording, duplicate headings, entry length
scripts/sanitize-check.sh    # Scan for sensitive strings, private IPs, keys, and anonymization
scripts/check-version.sh     # Version consistency across files
scripts/check-schema.sh      # schema/v1.json matches the rule library and policy template; rule enforced_by matches audit/guard checks
scripts/check-i18n.sh        # English rules in sync with the Chinese source (hashes, structural fields, line-by-line alignment)
bash tests/install.test.sh   # Full multi-agent install and restore tests
bash tests/audit.test.sh     # Active gate interception tests
bash tests/hook-guard.test.sh  # Runtime interception (python3 and bash modes) and Git hook install tests
bash tests/policy.test.sh    # Team policy file search and parsing tests
bash tests/doctor.test.sh    # Rule checkup and auto-fix tests
bash tests/review.test.sh    # Agent self-review tests
bash tests/check-version.test.sh  # Version check script tests
bash tests/check-budget.test.sh   # Frontmatter budget check tests
bash tests/lint-rules.test.sh     # Rule content check tests
bash tests/eval.test.sh           # Offline tests for the rule eval framework (scenario judging, runner, reports)
bash tests/deprecation.test.sh    # Rule deprecation and review-deadline warning tests
bash tests/check-schema.test.sh   # Rule-to-machine-check linkage tests
bash tests/i18n.test.sh           # Translation sync check and install.sh --lang tests
bash tests/incident-draft.test.sh # Incident report draft and sanitization tests
```

---

## 📄 License

This project is released under the [MIT License](LICENSE).
