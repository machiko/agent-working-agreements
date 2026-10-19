---
name: setup
description: 用一次問答挑選要安裝的 agent 工作守則（規則檔），可重跑調整或移除。
argument-hint: "[移除]"
disable-model-invocation: true
---

# 安裝或調整 agent 工作守則

安裝器：`bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"`（以下簡稱 `install.sh`）。所有寫入都由它完成，不要自己複製或刪除規則檔。

兩個安裝位置：

| 範圍 | 目標目錄 |
|------|---------|
| 全域 | `~/.claude/rules/agent-agreements` |
| 本專案 | `<git 根目錄或目前目錄>/.claude/rules/agent-agreements` |

## 1. 讀取現況

1. 執行 `install.sh --list`。輸出以 tab 分隔：id、tier、stack、always 或 on-demand、本文行數、選項名稱、說明。
2. 讀取兩個目標目錄下的 `.agreements-profile`（如果存在），從 `file=` 行得知目前已安裝哪些 id。

如果使用者的參數是「移除」，跳到第 5 步。

## 2. 一次問完（AskUserQuestion，只呼叫一次，4 題）

提問前先用一兩句話告訴使用者：core 規則（`--list` 中 tier 為 core 的項目，例如誠實回報、驗證證據、Git 安全、危險操作）一律安裝，下面只挑選額外的規則；全部不勾也可以。

1. **安裝範圍**（單選，header「範圍」）：全域（推薦，所有專案適用）／本專案（只在這個 repo 生效）
2. **寫作規範**（複選，header「寫作」）：`writing/commit-messages`、`writing/changelog`、`writing/docs-and-cards`、`writing/taiwan-terminology`
3. **安全**（複選，header「安全」）：`security/sast-safe-patterns`、`security/data-scope`
4. **技術棧地雷**（複選，header「技術棧」）：`laravel/pitfalls`、`docker/pitfalls`

每個選項的文字**原樣使用** `--list` 的欄位，不要自行改寫或縮寫：

- label：「選項名稱」欄。
- description：「說明」欄，後面接「（N 行，常駐）」或「（N 行，按需載入）」。已安裝的項目在 description 最前面加上「已安裝｜」。
- 重跑時預設沿用上次的選擇。

## 3. 預覽

把勾選的 id 用逗號串起來，執行：

```bash
install.sh --target <目標目錄> --select <id1,id2,...> --dry-run
```

把輸出原樣給使用者看（＋ 新增、－ 移除、↻ 更新、！ 保留，以及常駐與按需載入的行數），再問一次是否套用。

## 4. 套用

使用者確認後，用同樣的參數去掉 `--dry-run` 執行。

- 輸出裡有「！ 保留」，代表那個檔案被手動改過。問使用者是否要覆蓋；要覆蓋才加 `--force` 重跑。
- 完成後提醒：規則會在**下一個 session** 開始生效；之後想調整，再執行一次 `/agreements:setup` 即可。

## 5. 移除

1. 有兩個安裝位置時，先問要移除哪一個。
2. 執行 `install.sh --target <目標目錄> --uninstall --dry-run`，給使用者看會刪哪些檔案。
3. 確認後去掉 `--dry-run` 執行。只會刪除 profile 記錄的檔案，使用者自己放在同一個目錄的檔案不受影響。
