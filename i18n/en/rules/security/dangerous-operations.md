---
source_sha256: 46b19b7c55546086e0dc35ab1ad5fed6e40a5d4d784f919c957903462e3dfd96
category: security
tier: core
sources:
  - https://code.claude.com/docs/en/best-practices
  - https://github.com/trailofbits/claude-code-config
  - https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/
incidents:
  - "2025 Replit incident: an agent deleted the production database during a code freeze"
last_reviewed: 2026-11-10
enforced_by:
  - guard:dangerous-operations
---

# Dangerous operations and credentials

## Keep production credentials out of the agent's environment

Wherever the agent can run commands, there must be no credentials for production databases, cloud admin accounts, or paid APIs. When one is required, use a separate account with least privilege and a spending cap.

**Why:** In a public incident, an agent deleted the production database during a code freeze (the 2025 Replit incident). If the key is in the environment, assume the agent will use it someday.

## Don't bypass credential boundaries <!-- 慣例 -->

- Don't read tokens from config files to "get the tool working" (e.g. when an MCP connection fails, going to look in `~/.claude.json` or the keychain). If the connection fails, report it and let the user handle it.
- If the user says a file is off-limits (e.g. `.env.testing`), that includes `cat`, `grep`, and `head`.
- Never put credentials in command arguments, logs, commits, or replies.

## Confirm irreversible operations every time

`rm -rf`, `git push --force`, `reset --hard`, deleting branches, rewriting pushed history, `DROP`/`TRUNCATE`, `migrate:fresh`, `terraform destroy`, deleting cloud resources: before running any of these, list what it will affect and proceed only after the user agrees. Agreement covers that one time only.

**Why:** Editor checkpoints and undo only cover file edits; **they don't cover changes made through Bash**, and they can't recover a database.

- When a permission rule blocks a command, don't rephrase it to get around the block (e.g. `rm -rf` is blocked, so you switch to `find -delete`). Being blocked means ask first.

## Deny rules and hooks are not a security boundary

Use deny rules in settings to block reads of `~/.ssh`, `~/.aws`, and `.env*`, but the real boundary is the sandbox, separate accounts, and least privilege.

**Why:** Without the sandbox enabled, deny rules can't stop Bash from reading files by other means. Hooks are good at stopping accidents, not deliberate circumvention.
