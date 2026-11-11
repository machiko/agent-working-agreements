# Team rules

This directory holds your team's own rules. Each `<name>.md` is installed as `custom/<name>` into every entry of `targets` in `.agreements.json` (Claude Code, Cursor, AGENTS.md…). This file (README.md) is not installed.

## Adding or changing a rule

1. Add `<name>.md` using lowercase letters, digits and hyphens only; see the example below. In Claude Code you can also run `/agreements:record`.
2. Run `scripts/install.sh --sync` to sync the rules into each agent's rule files.
3. Commit the rule together with the synced changes and open a PR. The CI drift check fails PRs that were not synced.

To make a rule impossible to drop, add `custom/<name>` to `enforce_rules` in `.agreements.json`.

## Example

```markdown
---
category: custom
tier: custom
label: "Never touch the production database"
paths:              # optional: load only when these files are touched
  - "**/migrations/**"
incidents:
  - "Test config pointed at production; a migration wiped production data"
last_reviewed: 2026-11-11
---

# Never touch the production database

## Tests connected to the production database

- **Symptom:** the visible bad outcome.
- **Root cause:** why it happened.
- **How:** a concrete, verifiable action: command, setting, or check.
```

For team conventions without an incident behind them, append `<!-- 慣例 -->` to the heading (the marker stays in Chinese) and write "rule → **Why:** → **How:**".
