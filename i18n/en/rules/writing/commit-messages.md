---
source_sha256: f0706d858a92730164680850e8473962bdcb43a2372eb956d2555c367317ef79
category: writing
tier: optional
label: "Commit format"
summary: "Commit messages use the \"type: verb description\" format with a fixed set of Traditional Chinese verbs. If your team already has its own format, don't select this, or edit it after installing"
incidents:
  - "Commit and merge messages go to PMs, clients, and auditors, and heavy-handed wording was read as an incident report"
last_reviewed: 2026-11-10
---

# Commit messages

> Below is a format that has been used in practice (Traditional Chinese verb version). If your team has its own convention, edit this file directly. The agent only follows what is written here.

## Format

```
<type>: <動詞> <敘述>

- details (optional; the second line must be blank)
```

| type | Purpose |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation |
| `style` | Formatting, no behavior change |
| `refactor` | Refactor, same functionality |
| `perf` | Performance |
| `test` | Tests |
| `chore` | Dependencies, config, misc |
| `ui` | UI and UX |

Use only these six verbs, followed by a space: **新增 (add), 更新 (update), 修復 (fix), 刪除 (remove), 重構 (refactor), 優化 (optimize)**.

```
✅ fix: 修復 快取 key 在主鍵非 id 時無法區分使用者
✅ feat: 新增 匯出檔 AES-256 加密
❌ fix: 驗證碼快取 key 問題          ← missing verb
❌ feat: 改進                         ← no description
❌ chore: update packages             ← wrong language
```

**Why "never omit the verb" is spelled out:** The convention itself is clear; the mistakes happen when it isn't checked word for word at write time. The verb is what the agent omits most often.

## Use neutral wording for security fixes

For security fixes, keep words like "data leak", "leak", or "vulnerability" out of branch names, commit messages, changelog entries, and task card names. Rewrite them as neutral descriptions, e.g. "narrow the data fields output by the page" or "encrypt plaintext fields".

**Why:** This text persists and is shown to PMs, clients, or auditors. Merge commits also keep the branch name. Heavy-handed wording gets read as an incident report.

**How:** Describing the problem plainly while analyzing it in conversation is fine. Switch to neutral wording only when writing text that will persist or be delivered.

## Checklist <!-- 參考 -->

- [ ] The first line matches `<type>: <動詞> <敘述>`
- [ ] The current branch matches the type (see [`../collaboration/git-safety.md`](../collaboration/git-safety.md))
- [ ] Whether to append an AI attribution trailer (`Co-Authored-By`, etc.) follows team policy. If it's forbidden, say so explicitly in your CLAUDE.md; otherwise the agent appends one by its own default
- [ ] No force push to main/develop
