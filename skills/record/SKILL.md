---
name: record
description: 當 agent 踩雷或出錯時，即時進行簡短訪談並將教訓採集為專案自訂守則。
argument-hint: "[自訂規則名稱]"
---

# 採集 Agent 現場事故教訓 (Record Incident)

當 Agent 在開發過程中犯錯、改壞功能或踩中專案地雷時，透過此 Skill 將教訓直接固化成工作守則，避免未來重複踩雷。

## 1. 採集問答（3 個問題）

以簡短、結構化的提問引導開發者釐清事故：

1. **事故症狀 (Symptom)：**
   Agent 剛才做了什麼危險或錯誤的改動？引發了什麼具體壞事？（例如：清空了資料庫 migration、在迴圈裡發出數百個 SQL 查詢、直接修改了既有 API 欄位型別）
2. **根本原因 (Root Cause)：**
   為什麼 Agent 會做出這個錯誤判斷？（例如：誤以為只在 local 測試、未檢查全域常數、沒注意多租戶隔離）
3. **怎麼做 (Agreement)：**
   未來 Agent 遇到類似情境時，必須強制遵守的具體防線是什麼？（精簡明確、具備可操作性，避免抽象道德勸說）

## 2. 決定規則儲存位置與檔名

- **自訂名稱**：若使用者執行時有附帶參數，或自訂一個英數小寫連字號的名稱（例如 `prevent-schema-wipe`、`tenant-isolation`）。
- **目標範圍**：
  - 本專案（預設）：`<git-root>/.claude/rules/agent-agreements/custom/<name>.md`
  - 全域：`~/.claude/rules/agent-agreements/custom/<name>.md`
- **去識別化安全檢查**：檢查內容是否包含真實密碼、金鑰、內部 IP 或專有個人資訊。

## 3. 寫入規則檔案

格式遵循標準守則結構：

```markdown
---
category: custom
tier: custom
label: "<規則名稱>"
summary: "<一兩句話描述守則要點>"
---

# <規則名稱>

> 本規則由 /agreements:record 採集建立。格式：症狀 → 根因 → 怎麼做。

## <事故主題>

- **症狀：** <症狀描述>
- **根因：** <根本原因>
- **怎麼做：** <明確禁止或要求執行的規範>
```

確認目錄存在並寫入檔案後，向開發者確認建立成功，並提醒：「該規則已存入，後續 Agent 啟動或對話時將自動遵循此守則防線。」
