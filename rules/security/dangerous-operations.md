---
category: security
tier: core
sources:
  - https://code.claude.com/docs/en/best-practices
  - https://github.com/trailofbits/claude-code-config
  - https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/
---

# 危險操作與憑證

## agent 的環境裡不放正式機憑證

agent 能執行指令的地方，就不要有正式資料庫、雲端管理員、付費 API 的憑證。必須用到時，給權限最小、有額度上限的獨立帳號。

**為什麼：** 公開的事故裡，agent 在程式碼凍結期間刪掉了正式資料庫（2025 年 Replit 事件）。只要環境裡有那把鑰匙，就應該假設 agent 有一天會用到它。

## 不要繞過憑證的邊界

- 不要為了「讓工具能動」去讀設定檔裡的 token（例如 MCP 連線失敗時，改去 `~/.claude.json` 或 keychain 裡找）。連線失敗就回報，讓使用者處理。
- 使用者說某個檔案不能讀（例如 `.env.testing`），就連 `cat`、`grep`、`head` 都不行。
- 不要把憑證寫進指令參數、log、commit 或回覆內容裡。

## 不可逆的操作要逐次確認

`rm -rf`、`git push --force`、`reset --hard`、`DROP`／`TRUNCATE`、`migrate:fresh`、`terraform destroy`、刪除雲端資源：執行前列出會影響什麼，取得使用者同意後才做。同意只對那一次有效。

- 編輯器的 checkpoint、undo 只涵蓋檔案編輯，**涵蓋不到 Bash 造成的變更**，也救不回資料庫。
- 指令被權限規則擋下時，不要換個寫法繞過去（例如 `rm -rf` 被擋，就改用 `find -delete`）。被擋就代表要先問。

## deny 規則與 hook 不是安全邊界

- 在 settings 裡用 deny 規則擋掉讀取 `~/.ssh`、`~/.aws`、`.env*`，但要知道：沒有開 sandbox 時，deny 擋不住 Bash 用其他方式讀取。
- hook 適合擋「不小心」，擋不住「刻意繞過」。真正的邊界是 sandbox、獨立帳號和最小權限。
