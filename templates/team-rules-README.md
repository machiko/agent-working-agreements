# 團隊守則

這個目錄放團隊自己的守則。每個 `<name>.md` 都會以 `custom/<name>` 安裝到 `.agreements.json` 的每個 `targets`（Claude Code、Cursor、AGENTS.md…），本檔（README.md）不會被安裝。

## 新增或修改

1. 新增 `<name>.md`，檔名只用小寫英數與連字號，格式見下方範例。也可以在 Claude Code 執行 `/agreements:record`。
2. 執行 `scripts/install.sh --sync`，把守則同步到各個 Agent 的規則檔。
3. 守則與同步產生的變更一起 commit，開 PR。CI 的防漂移檢查會擋下沒同步的 PR。

要讓某條守則不能被拿掉，把 `custom/<name>` 加進 `.agreements.json` 的 `enforce_rules`。

## 範例

```markdown
---
category: custom
tier: custom
label: "禁止連正式資料庫"
paths:              # 選填：只在碰到這些檔案時載入
  - "**/migrations/**"
incidents:
  - "測試設定指向正式資料庫，跑 migration 清掉了正式資料"
last_reviewed: 2026-11-11
---

# 禁止連正式資料庫

## 測試時連到正式資料庫

- **症狀：** 看得到的壞結果。
- **根因：** 為什麼會發生。
- **怎麼做：** 可以驗證的具體動作：指令、設定值、檢查方式。
```

沒有事故依據的團隊慣例，標題後面加 `<!-- 慣例 -->`，本文寫「規則 → **為什麼：** → **怎麼做：**」。
