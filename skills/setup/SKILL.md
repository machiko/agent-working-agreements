---
name: setup
description: 用一次問答挑選要安裝的 agent 工作守則（規則檔），可重跑調整或移除。
argument-hint: "[狀態｜更新｜移除]"
disable-model-invocation: true
---

# 安裝或調整 agent 工作守則

安裝器：`bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"`（以下簡稱 `install.sh`）。所有寫入都由它完成，不要自己複製或刪除規則檔。

兩個安裝位置：

| 範圍 | 目標目錄 |
|------|---------|
| 全域 | `~/.claude/rules/agent-agreements` |
| 本專案 | `<git 根目錄或目前目錄>/.claude/rules/agent-agreements` |

## 1. 讀取現況與檢查更新

1. 執行 `install.sh --list`。輸出以 tab 分隔：id、tier、stack、always 或 on-demand、本文行數、選項名稱、說明。
2. 對兩個範圍各執行一次 `install.sh --status --target <目標目錄>`（唯讀，不會建立目錄）。輸出依 core／選擇的規則分組，每行是「id — 標題｜常駐或按需載入（paths）｜狀態」，最後一行是常駐與按需載入的行數和規則總數。從這裡得知目前已安裝哪些 id，不要自己讀 `.agreements-profile`。
3. 用幾行摘要給使用者看：每個範圍「尚未安裝」或裝了幾條（core 幾條、選擇的規則有哪些），以及有沒有標成「已手動修改」「有新版」「檔案遺失」「來源已移除」的規則（列出 id）。
4. **遠端版本檢查（非阻塞，超時 2 秒）**：執行 `curl -sSf --connect-timeout 2 https://api.github.com/repos/machiko/agent-working-agreements/releases/latest 2>/dev/null`，比對 GitHub Release tag 與本地版本（`plugin.json` 之 `version`）。若遠端有更新發布，在摘要中提示使用者：「💡 發現套件新版本 vX.Y.Z（本地目前為 vA.B.C），可透過套件管理器或 git pull 升級」。
5. 兩個範圍都已安裝時提醒：全域與本專案會各載入一份，同一條規則會重複載入、多佔 context；建議只留一個範圍。
6. 執行 `install.sh --detect` 掃描目前專案特徵，記下推薦的規則 id 清單。

### 參數處理與一鍵更新

- **參數是「狀態」**：摘要完就結束，不進入問答、不執行任何安裝。
- **參數是「移除」**：跳到第 5 步（移除）。
- **參數是「更新」**：直接對已安裝範圍執行一鍵更新：
  1. 執行 `install.sh --target <目標目錄> --update --dry-run` 產生預覽。
  2. 將差異（＋新增、↻ 更新、－移除、！保留）呈報給使用者確認。
  3. 使用者確認後去掉 `--dry-run` 執行更新，並以 `install.sh --status` 收尾。
- **若未提供參數（一般互動模式）**：
  - 進入第 2 步（意圖確認與問答引導）。

## 2. 意圖確認與問答引導 (AskUserQuestion)

依目標範圍的安裝現況進行分流引導：

### 情境 A：目標範圍已安裝（調整、加裝或更新模式）

向使用者提問操作意圖（單選，header「操作」）：
- 標題：「您想如何調整目前已安裝的工作守則？」
- 選項（2～4 項）：
  1. `維持現有規則並一鍵更新`（推薦）：沿用目前安裝的規則設定，升級至最新版，無須填寫後續問答。
  2. `加裝其他規則`：從尚未安裝的規則中挑選要追加的項目，現有規則 100% 完整保留，絕不誤刪。
  3. `移除部分規則`：只列出目前已安裝的 optional 規則，勾選要卸載的項目進行精準移除。
  4. `重新自訂挑選`：完整重新進行各領域挑選（若想大幅度重新規劃規則組合）。

各選項後續流程：
- **若選擇「維持現有規則並一鍵更新」**：
  直接跳到第 3 步執行 `install.sh --target <目標目錄> --update --dry-run` 預覽並套用。
- **若選擇「加裝其他規則」**：
  向使用者發出問答（複選，每題 2～4 個選項）：只列出目前**尚未安裝**的 optional 規則（若符合專案偵測特徵則冠上「推薦｜」）。使用者勾選要追加的 id 後，將「既有已安裝 id ＋ 新勾選 id」以逗號串接傳入第 3 步的 `--select` 執行預覽與套用。
- **若選擇「移除部分規則」**：
  向使用者發出問答（複選）：只列出目前**已安裝**的 optional 規則。使用者勾選「確定要移除的規則」後，將「既有已安裝 id 排除勾選要移除的 id」傳入第 3 步的 `--select` 執行預覽（會顯示 `－ 移除 ...`）並套用。
- **若選擇「重新自訂挑選」**：
  進入下方「情境 B」的完整問答流程。

---

### 情境 B：首次安裝或重新自訂挑選

提問前先告訴使用者：下面這些 core 規則一律安裝，問答只挑選額外的 optional 規則；全部不勾也可以。接著逐行列出 core 規則的標題（`--list` 中 tier 為 core 的項目，原樣使用第 6 欄「選項名稱」）。

發出問答（注意：Claude Code 之 AskUserQuestion 每題選項為 2～4 項）：
1. **安裝範圍**（單選，header「範圍」）：全域（推薦，所有專案適用）／本專案（只在這個 repo 生效）。若目前已有安裝範圍，預設選擇該範圍。
2. **協作與交付規範**（複選，header「協作」）：例如 `collaboration/sdlc-lifecycle`、`writing/commit-messages`、`writing/changelog`、`writing/taiwan-terminology`（若已安裝，在 label 最前面加上「【已安裝】」）。
3. **安全防護**（複選，header「安全」）：`security/sast-safe-patterns`、`security/tenant-isolation`、`security/supply-chain`（若已安裝，在 label 最前面加上「【已安裝】」）。
4. **工程地雷**（複選，header「工程地雷」）：例如架構層（`database/pitfalls`、`api/pitfalls`、`testing/pitfalls` 等）與應用層（`frontend/pitfalls`、`backend/pitfalls`、`container/pitfalls` 等；可依 `--detect` 推薦優先放入推薦選項，每題 2～4 項；已安裝項目 label 加上「【已安裝】」）。

每個選項的文字：
- label：已安裝的項目加上「【已安裝】」，被 `--detect` 推薦的項目加上「(推薦)」。
- description：「說明」欄，後面接「（N 行，常駐）」或「（N 行，按需載入）」。

使用者完成選取後，只將最終選取的規則 id 以逗號串接傳入第 3 步的 `--select`。

## 3. 預覽

把勾選的 id 用逗號串起來，執行：

```bash
install.sh --target <目標目錄> --select <id1,id2,...> --dry-run
```

把輸出原樣給使用者看（＋ 新增、－ 移除、↻ 更新、！ 保留，以及常駐與按需載入的行數），再問一次是否套用。

## 4. 套用

使用者確認後，用同樣的參數去掉 `--dry-run` 執行。套用完再執行一次 `install.sh --status --target <目標目錄>`，把結果給使用者看作為收尾。

- 輸出裡有「！ 保留」，代表那個檔案被手動改過。問使用者是否要覆蓋；要覆蓋才加 `--force` 重跑。
- 完成後提醒：規則會在**下一個 session** 開始生效；之後想調整，再執行一次 `/agreements:setup` 即可。

## 5. 移除

1. 有兩個安裝位置時，先問要移除哪一個。
2. 執行 `install.sh --target <目標目錄> --uninstall --dry-run`，給使用者看會刪哪些檔案。
3. 確認後去掉 `--dry-run` 執行。只會刪除 profile 記錄的檔案，使用者自己放在同一個目錄的檔案不受影響。
