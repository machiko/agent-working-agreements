---
name: setup
description: 智慧配置與安裝 Agent 工作守則（規則檔），支援專案自動偵測、套裝方案一鍵安裝、更新與移除。
argument-hint: "[狀態｜更新｜移除｜團隊｜同步]"
disable-model-invocation: true
---

# 安裝或調整 Agent 工作守則

安裝器：`bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh"`（以下簡稱 `install.sh`）。所有寫入都由它完成，不要自己複製或刪除規則檔。

兩個安裝位置：

| 範圍 | 目標目錄 |
|------|---------|
| 全域 | `~/.claude/rules/agent-agreements` |
| 本專案 | `<git 根目錄或目前目錄>/.claude/rules/agent-agreements` |

> 預設安裝目標：當前目錄處於 Git 專案內時，預設優先安裝至「本專案」；若不在 Git 專案內則預設為「全域」。

## 0. 團隊模式（先判斷）

先執行 `git rev-parse --show-toplevel 2>/dev/null`，看專案根目錄（不在 git repo 內就用目前目錄）有沒有 `.agreements.json`。

- **參數是「同步」或 `sync`，或專案已有 `.agreements.json` 且沒有帶參數**：團隊已經導入，個人不用再選方案。執行 `install.sh --sync`，把輸出原樣整理給使用者看，就結束。
  - 結束碼 1 且訊息是「團隊鎖定 vX」：照輸出提示說明。要跟團隊對齊，執行輸出裡那行 `curl … | bash -s -- --sync`；要把全隊升級是改策略檔並開 PR，由使用者決定，不要自己改。
  - 結束碼 2 是找不到策略檔或沒有 targets：照輸出提示說明。
  - 輸出有「團隊守則品質」的 ⚠：列給使用者看，說明不影響同步。
- **參數是「團隊」或 `team`**：團隊負責人第一次導入。專案已有 `.agreements.json` 時說明已經導入過、改執行同步，然後結束。否則用一次 AskUserQuestion 問兩題：
  1. header「團隊 Agent」（複選）：「團隊成員用哪些 AI Agent？每個都會安裝同一套守則。」選項：`Claude Code`（claude）、`Cursor`（cursor）、`AGENTS.md（Codex 等）`（agents-md）、`GitHub Copilot`（copilot）。使用者在 Other 填 Windsurf 時對應 windsurf。
  2. header「配置方案」（單選）：`智慧推薦`（smart，推薦）、`完整防禦`（full）、`極簡核心`（core）。
  
  執行 `install.sh --team-init --targets <逗號分隔的 id> --preset <方案>`（語言要英文時加 `--lang en`），把輸出的「接下來」三步原樣交給使用者。不要替使用者 commit。
- 其他情況照下面第 1 步以後的個人安裝流程。

## 1. 讀取現況與背景分析

1. 執行 `install.sh --list`。輸出以 tab 分隔：id、tier、stack、always 或 on-demand、本文行數、選項名稱、說明、淘汰狀態（`deprecated` 或 `-`）、替代守則 id（沒有時為 `-`）。標 `deprecated` 的守則不要推薦，也不要列進方案；使用者已安裝的話，在摘要提示改用第 9 欄的替代守則。
2. 對兩個範圍各執行一次 `install.sh --status --target <目標目錄>`（唯讀，不會建立目錄）。輸出依 core／選擇的規則分組，每行是「id — 標題｜常駐或按需載入（paths）｜狀態」，最後一行是常駐與按需載入的行數和規則總數。從這裡得知目前已安裝哪些 id，不要自己讀 `.agreements-profile`。
3. 執行 `install.sh --detect` 掃描目前專案特徵，取得推薦的規則 id 清單。
4. **遠端版本檢查（非阻塞，超時 2 秒）**：執行 `curl -sSf --connect-timeout 2 https://api.github.com/repos/machiko/agent-working-agreements/releases/latest 2>/dev/null`，比對 GitHub Release tag 與本地版本（`plugin.json` 之 `version`）。若遠端有更新發布，在摘要中提示使用者：「💡 發現套件新版本 vX.Y.Z（本地目前為 vA.B.C），可透過套件管理器或 git pull 升級」。
5. 用幾行簡明摘要呈現目標環境的安裝現況與偵測到的技術特徵。
6. 兩個範圍都已安裝時提醒：全域與本專案會各載入一份，同一條規則會重複載入、多佔 context；建議只留一個範圍。

### 參數處理與直達指令

- **參數是「狀態」**：摘要完就結束，不進入問答、不執行任何安裝。
- **參數是「移除」**：跳到第 4 步（移除）。
- **參數是「更新」**：直接對已安裝範圍執行一鍵更新：
  1. 執行 `install.sh --target <目標目錄> --update`。
  2. 套用完再執行一次 `install.sh --status --target <目標目錄>` 收尾。
- **若未提供參數（一般互動模式）**：進入第 2 步（單一決策引導）。

---

## 2. 統一單一決策引導 (AskUserQuestion)

徹底捨棄舊有的「加裝/移除/重新自訂」多層分流選單。無論專案是否曾安裝過，統一提供「方案驅動（Preset-Driven）」的扁平決策，一鍵即可完成安裝或同步。

提問前先告訴使用者：下面這些 core 規則一律安裝，方案只決定搭配的 optional 守則組合。接著逐行列出 core 規則的標題（`--list` 中 tier 為 core 的項目，原樣使用第 6 欄「選項名稱」）。

### 單一決策題（單選，header「配置方案」）：

向使用者提問配置方案：
- 標題：「請選擇要為此專案套用的工作守則方案（目標：`<目標範圍>`）：」
- 選項依當前安裝現況提供：

#### 若目標尚未安裝：
1. `⚡ 智慧專案推薦`（推薦）：
   - 自動包含：**Core 守則 ＋ 本專案偵測到的技術棧守則（如 `frontend/pitfalls`、`testing/pitfalls` 等） ＋ 基礎資安防護（`security/tenant-isolation`）**。
   - description：「依當前專案特徵自適應配置（偵測到：<列出偵測特徵>），一鍵安裝」。
2. `🛡️ 完整防禦套裝`：
   - 包含：**Core 守則 ＋ 全套工程地雷（前後端/資料庫/容器/雲端/API/異步/測試） ＋ 完整資安與 SDLC 規範（`collaboration/sdlc-lifecycle` 等）**。
   - description：「防禦全領域潛在地雷，適合對穩定度與合規要求極高的生產環境」。
3. `🪶 極簡核心守則`：
   - 包含：**僅安裝常駐 Core 守則**（400 行以內，零 Context 負擔）。
   - description：「僅載入跨專案通用核心防禦，完全不增加額外規則」。
4. `🛠️ 進階自訂挑選`：
   - description：「手動逐一挑選個別領域規則」。

#### 若目標已經安裝過：
1. `⚡ 智慧專案同步推薦`（推薦）：
   - 自動將既有守則與最新專案偵測特徵進行同步，補齊新特徵守則並升級至最新版本。
   - description：「比對專案特徵自動補齊並升級，既有規則完整保留」。
2. `🔄 維持現有規則並一鍵更新`：
   - 沿用目前安裝的規則組合，升級至最新版本。
   - description：「沿用目前安裝之規則組合，升級至最新版本，不調整規則項目」。
3. `🛡️ 完整防禦套裝`：
   - 一鍵切換為全套工程防線（Core ＋ 全套工程地雷 ＋ 資安 ＋ SDLC 規範）。
   - description：「升級並切換為全套防禦守則」。
4. `🛠️ 進階自訂挑選`：
   - description：「手動增減個別領域規則」。

### 語言題（單選，header「守則語言」，與配置方案放在同一次 AskUserQuestion）：

只在目標尚未安裝時問；已安裝時沿用 `--status` 顯示的「守則語言」，不再詢問（使用者主動要求切換語言時才問）。團隊策略檔有 `lang` 時不問：沒帶 `--lang` 的安裝與更新一律依策略檔，優先於既有安裝的語言；`doctor.sh --check-drift` 也會把語言不符視為漂移。

- 標題：「守則要用哪個語言安裝？」
- 選項：`繁體中文`（推薦，預設）、`English`。
- 選 English 時，下方所有 `install.sh --target ...` 指令都加上 `--lang en`；選繁體中文時不用加。`--update` 會自動沿用安裝時的語言。

---

### 各方案套用邏輯（一問即成，不需重複確認）：

- **若選擇「⚡ 智慧專案推薦」或「⚡ 智慧專案同步推薦」**：
  組出 ID 清單：`install.sh --detect` 輸出的全部 ID ＋ `security/tenant-isolation`（若為同步且已有安裝則併入既有 ID）。
  直接執行 `install.sh --target <目標目錄> --select <id1,id2,...>` 套用，進入第 3 步收尾。
- **若選擇「🔄 維持現有規則並一鍵更新」**：
  直接執行 `install.sh --target <目標目錄> --update` 套用，進入第 3 步收尾。
- **若選擇「🛡️ 完整防禦套裝」**：
  組出全部 optional ID，直接執行 `install.sh --target <目標目錄> --select <全部optional_ids>` 套用，進入第 3 步收尾。
- **若選擇「🪶 極簡核心守則」**：
  直接執行 `install.sh --target <目標目錄>`（不帶 `--select`）套用，進入第 3 步收尾。
- **若選擇「🛠️ 進階自訂挑選」**：
  僅向使用者發出精簡自訂問答（複選）：列出所有 optional 規則供自由勾選，選取後串接為 ID 清單執行 `install.sh --target <目標目錄> --select <勾選的ids>` 套用。

---

## 3. 套用與成果收尾

套用完成後，執行：

```bash
install.sh --status --target <目標目錄>
```

將結果呈現給使用者作為收尾。

- 若輸出包含「！ 保留」，代表該檔案曾被手動修改過而予以保留；提示使用者若要強制還原可加 `--force` 重新執行。
- **主動工程防線診斷提示**：
  檢查本專案是否具備 Git pre-commit 守門機制（`git rev-parse --git-path hooks` 所指目錄下的 `pre-commit`）或 CI 工作流。若尚未配置，給予貼心提醒：
  「💡 **守則已成功就緒！** 建議執行 `/agreements:doctor fix` 可一鍵安裝 Git Commit 守門與 CI 檢查，建立主動防護。」
- 提醒使用者：規則會在**下一個 session** 開始生效；之後若專案技術棧擴充，隨時執行 `/agreements:setup` 即可一鍵同步。

---

## 4. 移除

當使用者指定「移除」參數或意圖清除守則時：
1. 有兩個安裝位置時，先問要移除哪一個。
2. 執行 `install.sh --target <目標目錄> --uninstall`。只會刪除 profile 記錄的守則檔案，使用者放在同目錄的自訂檔案不受任何影響。
3. 移除完成後回報成果。
