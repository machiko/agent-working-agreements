# agent-working-agreements

[![check](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml/badge.svg)](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml)
[![release](https://img.shields.io/github/v/release/machiko/agent-working-agreements)](https://github.com/machiko/agent-working-agreements/releases)
[![license](https://img.shields.io/github/license/machiko/agent-working-agreements)](LICENSE)

**繁體中文** | [English](README.en.md)

跨 AI Coding Agent（Claude Code、Cursor、GitHub Copilot、Windsurf、Codex 等）的工作協約與防禦守則。

源自長期在生產環境與 AI Agent 協作踩坑的真實事故（Production Incidents），不堆砌通用的最佳實踐廢話，專注於**防禦高危操作、攔截工程地雷、保護程式碼與測試完整性**。

> 本專案規則本文以**繁體中文**撰寫，另有逐行對照的英文版（[`i18n/en/rules/`](i18n/en/rules/)），安裝時加 `--lang en` 即可。每條規則皆遵循固定架構：**規則（Rule）→ 為什麼（Why：觸發的真實事故）→ 怎麼做（How：具體落實指引）**。只有理解「為什麼」，Agent 才能在邊界情境下做出正確判斷。

---

## ⚡ 核心設計原則

1. **真實事故驅動（Incident-Driven）**：只收錄實際在生產環境被 AI 搞砸過的問題（如靜默吞噬 Exception、動態 Tailwind 類別遭 Purge、外鍵死鎖、過寬 IAM 授權）。
2. **嚴格 Context 預算控制**：常駐核心守則（Core）在 CI 嚴格限制 **400 行以內**；技術棧與領域守則（Optional）採**按需載入（On-Demand）**，只在 Agent 接觸相關檔案時才載入，不浪費 Context Window。
3. **無損無痛相容（Zero-Friction Ingestion）**：支援獨立檔案複製、Cursor `.mdc` 格式轉譯，以及單檔標記區塊安全注入（保留檔案原有內容，不覆蓋既有設定）。
4. **主動工程防線（Active Guardrails）**：除了被動 Prompt 指示，提供 Git Hook、CLI 稽核與 CI 守門，在 Commit 與 PR 階段直接攔截地雷。

---

## 💡 為什麼需要本專案？（核心差異化）

傳統社群的 Prompt / Rules 庫多為「靜態建議」，Agent 在面對長上下文或複雜情境時容易遺忘或繞過；而一般的執行期工具往往僅針對單一環境或僅能攔截少數終端指令，無法防禦架構與代碼地雷。

本專案將「真實事故驅動的工程守則」與「多層主動防禦機制（Hooks + Policy + Schema + CI）」結合，建立完整的 Agent 協作治理防線：

| 比較維度 | 市面一般 Rules / Prompt 收集庫 | 單點執行期 Hook 工具 | 本專案 (`agent-working-agreements`) |
| :--- | :--- | :--- | :--- |
| **防護縱深** | 僅提示詞層（被動建議） | 僅終端 Hook（單點阻擋） | **三層立體防線**：提示詞守則 ＋ 執行期 Hook ＋ CI 閘門 |
| **跨 Agent 支援** | 需手動各自維護與複製 | 通常綁定單一工具環境 | **單一源頭編譯**：Claude Code、Cursor、Copilot、Windsurf、AGENTS.md 一鍵同步 |
| **工程防禦深度** | 通用最佳實踐，缺乏事故針對性 | 僅過濾少數終端指令（如 rm、push） | **事故驅動守則庫**（針對死鎖、例外吞噬、Mock 污染、租戶隔離等具體事故） |
| **Context 預算控制** | 缺乏限制，動輒膨脹耗盡 Window | 不涉及 Context | **嚴格預算控制**：Core 守則 < 400 行，其餘依 glob/路徑按需載入 |
| **團隊治理機制** | 無規範，容易各自為政 | 通常僅為本機或個人設定 | **Policy as Code**：支援 `.agreements.json`、JSON Schema v1 與不可繞過防線 |
| **體檢與防漂移** | 無檢驗機制，守則被改被刪無人知曉 | 僅單次狀態回報 | **自動化體檢修復**：`doctor.sh` 評分修復，CI `--check-drift` 阻擋 PR 漂移 |

---

## 🚀 跨 Agent 支援矩陣與安裝指南

| 支援等級 | 工具環境 | 防護層級 | 支援特性 | 推薦安裝方式（免手動 Clone） |
|---|---|---|---|---|
| **Tier 1 (原生全功能)** | **Claude Code** | 終端即時攔截 ＋ Git 守門 | 完整 Skills、PreToolUse 即時指令阻擋 Hooks、單層問答配置、體檢與自省 | `/plugin marketplace add machiko/agent-working-agreements`<br>`/plugin install agreements@agent-working-agreements` |
| **Tier 2 (深度適配)** | **Cursor IDE** | Git 守門（Commit/Push） | 原生 `.cursor/rules/*.mdc`，精準支援 `globs` 按需載入與 `alwaysApply` | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --cursor .cursor/rules` |
| **Tier 2 (指令檔案適配)** | **GitHub Copilot** | Git 守門（Commit/Push） | 原生 `.github/copilot-instructions.md` 區塊插入與乾淨更新 | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --copilot` |
| **Tier 2 (規則適配)** | **Windsurf** | Git 守門（Commit/Push） | 原生 `.windsurfrules` 區塊管理 | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --windsurf` |
| **Tier 3 (通用規範輸出)** | **AGENTS.md / Codex / Aider** | Git 守門（Commit/Push） | 符合通用規範之標記區塊，全語言與各 Agent 皆可載入 | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --agents-md AGENTS.md` |
| **通用防護網** | **任何終端與 IDE** | Git 守門（Commit/Push） | Git `pre-push` 防 Force Push、Git `pre-commit` 敏感憑證外洩攔截 | `curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh \| bash -s -- --git-hooks` |

> [!NOTE]
> **防護層次邊界說明**：
> - **終端即時攔截（Terminal-Level Interception）**：僅在支援 `PreToolUse` 事件的環境（如 Claude Code）生效，可在 Agent 敲下 `rm -rf /` 或外傳 `.env` 當下立即阻斷指令執行。
> - **Git 階段守門（Git-Level Gatekeeper）**：在 Cursor、Copilot、Windsurf 與一般終端機中，防線以 Universal Git Hook（`pre-commit` 與 `pre-push`）為核心，確保在提交代碼與推送到遠端時攔截高危破壞與敏感資料外洩。

---

## 🚀 選擇你的 AI Agent 進行安裝

### 1. Claude Code（Tier 1 原生全功能，最推薦）

**無需手動 clone 本專案，亦無需手動執行偵測腳本**。在你的專案目錄直接透過 Claude Code 終端執行：

```bash
# 1. 加入 Marketplace 並安裝 Plugin
/plugin marketplace add machiko/agent-working-agreements
/plugin install agreements@agent-working-agreements

# 2. 啟動互動式設定（自動偵測當前專案技術棧並推薦最佳守則組合）
/agreements:setup
```

> [!TIP]
> 執行 `/agreements:setup` 時，Claude Code 會自動在目前專案背景執行技術棧特徵掃描，並在交談中呈現「⚡ 智慧專案推薦」方案，一鍵即完成安裝！

---

### 2. Cursor、Copilot、Windsurf、AGENTS.md 或 CLI 腳本安裝

#### ⚡ 方式一：遠端一鍵安裝（免 clone，最推薦）

在目標專案根目錄下，依據你的編輯器直接執行一行指令：

```bash
# 🔹 Cursor IDE (.cursor/rules/*.mdc)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --cursor .cursor/rules

# 🔹 GitHub Copilot (.github/copilot-instructions.md)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --copilot

# 🔹 Windsurf IDE (.windsurfrules)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --windsurf

# 🔹 AGENTS.md / Codex / Aider
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --agents-md AGENTS.md

# 🔹 安裝通用 Git Hooks 防護網 (pre-push / pre-commit)
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --git-hooks
```
*(亦可隨時在尾端加上 `--select frontend/pitfalls,database/pitfalls` 指定特定守則；加上 `--lang en` 改裝英文版守則，之後 `--update` 會沿用同一個語言)*

#### 📦 方式二：本機複製（離線開發或進階自訂）

若想在本機保存腳本庫進行自訂或審閱，可先複製本專案：

```bash
git clone https://github.com/machiko/agent-working-agreements.git
cd agent-working-agreements
```

#### 步驟 A：自動偵測目標專案技術棧（取得推薦守則清單）
傳入**目標專案之路徑**（例如 `../my-project`），分析該專案特徵：
```bash
scripts/install.sh --detect /path/to/your-project
```
*(若直接在目標專案目錄執行，亦可傳入 `.` 或省略路徑)*

#### 步驟 B：依目標編輯器套用至目標專案

##### 🔹 Cursor IDE (`.cursor/rules/*.mdc`)
自動轉譯為 Cursor 原生 `.mdc` 規格，Core 守則標註 `alwaysApply: true`，特定技術棧守則自動轉換為 `globs` 條件：
```bash
# 預覽安裝
scripts/install.sh --cursor /path/to/your-project/.cursor/rules --select frontend/pitfalls,database/pitfalls --dry-run

# 正式套用至目標專案
scripts/install.sh --cursor /path/to/your-project/.cursor/rules --select frontend/pitfalls,database/pitfalls
```

##### 🔹 GitHub Copilot (`.github/copilot-instructions.md`)
透過 HTML 標記區塊安全注入，**完全保留檔案中原有的其他指令**：
```bash
scripts/install.sh --copilot /path/to/your-project/.github/copilot-instructions.md --select frontend/pitfalls,backend/pitfalls
```

##### 🔹 Windsurf IDE (`.windsurfrules`)
透過安全標記區塊注入目標專案根目錄的 `.windsurfrules`：
```bash
scripts/install.sh --windsurf /path/to/your-project/.windsurfrules --select frontend/pitfalls,security/supply-chain
```

##### 🔹 OpenAI Codex / Aider / 支援 `AGENTS.md` 的 Agent
注入至專案根目錄的 `AGENTS.md`，自動移除 Frontmatter 並保留前後原有文字，內建 Codex 32 KiB 讀取上限警示：
```bash
scripts/install.sh --agents-md /path/to/your-project/AGENTS.md --select database/pitfalls,api/pitfalls
```

##### 🔹 通用 CLI Agent 或自訂目錄（Antigravity、Aider 等）
若使用的工具支援自訂規則目錄或 Prompt 載入：
```bash
scripts/install.sh --target /path/to/your-project/my-rules-dir --select frontend/pitfalls
```

---

### 3. 主動守門防線配置（全平台 CI 自動化 / 本機 Git Hook）

主動稽核與守門的核心邏輯由獨立腳本 [`scripts/audit.sh`](scripts/audit.sh) 執行（純 Bash，無第三方依賴）。請依據專案環境選擇：

#### 🟢 雲端 CI/CD 自動化工作流（全平台支援）
支援主流平台與工具鏈，自動生成對應守門腳本：
```bash
scripts/install.sh --ci                 # 智慧自動偵測專案環境（GitHub / GitLab / Bitbucket / pre-commit）
scripts/install.sh --ci github          # 安裝 GitHub Actions 工作流 (.github/workflows/agent-audit.yml)
scripts/install.sh --ci gitlab          # 安裝 GitLab CI 工作流 (.gitlab-ci.yml)
scripts/install.sh --ci bitbucket       # 安裝 Bitbucket Pipelines 工作流 (bitbucket-pipelines.yml)
scripts/install.sh --ci pre-commit      # 安裝 Python pre-commit 框架配置 (.pre-commit-config.yaml)
```

#### 🟡 本機開發或私有伺服器（零平台門檻）
**完全不需要特定雲端平台！** 可直接安裝為本機 Git Pre-commit Hook：
```bash
scripts/audit.sh --install-hook
```
任何在本地電腦執行的 Git 專案皆可使用，在 `git commit` 當下立即由本機攔截，避免錯誤代碼進入版本歷史。
* hook 寫入 `git rev-parse --git-path hooks` 指向的目錄，git worktree 與設定 `core.hooksPath`（例如 husky）的專案都適用。
* 已有的 pre-commit／pre-push（非本工具安裝）會備份成 `<名稱>.agreements-bak`，守門檢查通過後接著執行，原本的 hook 不會消失。
* 專案內沒有 `scripts/audit.sh` 時改用安裝當下的稽核腳本；兩者都找不到只印警告，不會擋住 commit。

### 4. 團隊導入：負責人一條指令、成員一條指令

整個團隊共用同一套守則（含團隊自己寫的規範），跨 Claude Code、Cursor、AGENTS.md 等 Agent 都一致：

```bash
# 負責人：產生 .agreements.json 與 .agreements/rules/，安裝每個 Agent、Git hooks 與 CI 防漂移檢查
scripts/install.sh --team-init --targets claude,cursor,agents-md     # Claude Code：/agreements:setup team

# 成員：pull 之後同步（依策略檔鎖定的版本下載）
curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --sync
```

團隊規範寫在 `.agreements/rules/<name>.md`，`--sync` 會以 `custom/<name>` 裝到每個 Agent；沒同步的 PR 會被 CI 擋下。完整流程見 [團隊導入指南](docs/team.md)。

---

## 🛡️ 主動防護與體檢診斷工具

本專案不僅包含靜態 Prompt 守則，還附帶全套主動稽核與體檢工具：

### 🩺 守則健康度體檢、自動修復與 CI 防漂移 (`scripts/doctor.sh`)
一鍵診斷專案的守則設定、版本新鮮度、Git 守門機制與 CI 工作流就緒度，產出 0–100 分綜合評分，支援 `--fix` 自動補齊修復，並支援 CI 防漂移檢驗：

```bash
# 體檢目前專案
scripts/doctor.sh

# 一鍵自動修復缺失之 Git hook、CI 檔案與過期守則
scripts/doctor.sh --fix

# 固化目前已安裝之守則為專案 .agreements.json 策略檔
scripts/doctor.sh --init-policy

# CI 專用：檢驗守則無篡改、核心規則完整且符合團隊策略（若漂移 exit 1 阻擋 PR）
scripts/doctor.sh --check-drift

# Claude Code 專屬指令
/agreements:doctor
/agreements:doctor fix
/agreements:doctor drift
/agreements:doctor init-policy
```

### 📋 Agent 變更自省審查 (`scripts/review.sh`)
在提交 Commit 或宣告任務完成前，自動對照全套守則清查程式碼變更，輸出標準 Markdown 自省報告：
```bash
scripts/review.sh              # 審查目前未提交變更（或 HEAD）
scripts/review.sh --base main  # 審查與 main 分支之間的差距
scripts/review.sh --staged     # 審查暫存區變更

# Claude Code 專屬指令
/agreements:review
```

### 🏢 團隊策略設定檔與強制治理 (`.agreements.json`)
支援在專案根目錄放置 `.agreements.json` 或 `.agreementsrc` 鎖定團隊規範，在開發者或 Agent 執行安裝時自動強制套用：
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
  "targets": ["claude", "cursor", "agents-md"],
  "agreements_version": "1.6.0",
  "git_hooks": true,
  "prohibit_disable_hooks": false,
  "lang": "zh-TW"
}
```
* `targets`、`agreements_version`、`git_hooks` 給 `install.sh --sync` 使用：裝好每個目標、鎖定版本（版本不同時停下）、安裝 Git hooks。`enforce_rules` 可以寫 `custom/<name>` 強制團隊守則（`.agreements/rules/<name>.md`）。用法見 [團隊導入指南](docs/team.md)。
* 執行 `install.sh` 或 `/agreements:setup` 時，會自動向上尋找專案或 Monorepo 根目錄策略檔並鎖定強制守則，避免個人環境設置歧異。搜尋到 git root 為止；不在 git repo 內時不讀家目錄的策略檔。
* `preset` 支援指定團隊預設安裝方案（`"smart"` 智慧推薦、`"full"` 全套防禦、`"core"` 極簡核心）。當專案安裝且未明確指定 `--select` 時以此方案為基準展開，並自動疊加 `enforce_rules` 強制守則。
* `lang` 指定團隊的守則語言（`"zh-TW"` 或 `"en"`）。沒有帶 `--lang` 時依此安裝；優先順序是 `--lang` → 策略檔 `lang` → 既有安裝記錄的語言 → `zh-TW`；`doctor.sh --check-drift` 會把安裝語言與策略檔不符視為漂移。
* 若設定 `"prohibit_disable_hooks": true`，將鎖死防護網，強制忽略 `AGREEMENTS_HOOKS_DISABLE=1`，防止 Agent 或腳本繞過安全攔截。
* 具備完整 JSON Schema（[`schema/v1.json`](schema/v1.json)），在 VS Code 與 Cursor 等現代編輯器中支援全 28 條守則 ID 自動補齊與結構驗證。
* 可透過 `scripts/doctor.sh --init-policy` 或 `/agreements:doctor init-policy` 一鍵從現有安裝生成標準策略檔。
* CI 執行 `scripts/doctor.sh --check-drift` 時，會檢查 `targets` 的每個目標：策略檔指定之全部守則都已安裝、團隊守則與 `.agreements/rules/` 一致、安裝版本等於 `agreements_version`。

### 🛡️ 執行期主動防護 (Runtime Hooks & Universal Git Hooks)
透過 Claude Code 的 Plugin Hook 機制，在 Agent 執行高危破壞性指令的當下直接阻擋：
- 🛑 **禁止 Force Push**：即時攔截 `git push --force`、`-f`（含 `-uf` 等合併寫法）與 `+refspec`；`--force-with-lease` 放行
- 🛑 **防範無預警清空代碼**：阻擋所有 `git reset --hard` 與 `git clean -f`（`git clean -n` 預覽不受影響）
- 🛑 **防範丟失未提交或未合併的工作**：阻擋對整個目錄的 `git checkout .`／`git restore .`（`git restore --staged .` 放行）、強制刪除分支（`git branch -D`）與 `git stash clear`
- 🛑 **防範刪除整個環境**：阻擋 `terraform destroy`（含 `apply -destroy`、OpenTofu）、`kubectl delete namespace` 與 `kubectl delete --all`
- 🛑 **禁止根目錄毀滅性指令**：阻擋對 `/`、`~`、`$HOME` 遞迴刪除，以及遞迴 `chmod 777`
- 🛑 **防範憑證外洩**：即時攔截以 `curl`、`wget`、`nc`、`scp` 等傳送 `.env` 的指令
- 💡 被擋時 Agent 會收到攔截原因；可透過環境變數 `AGREEMENTS_HOOKS_DISABLE=1` 暫時跳過攔截（團隊策略設 `prohibit_disable_hooks` 時無效）
- ⚙️ 攔截規則集中在 [`scripts/lib/guard-rules.tsv`](scripts/lib/guard-rules.tsv)。有 `python3` 時以 Python 解析指令；沒有時改用 Bash 比對同一份規則，行為一致
- 👥 團隊可以在策略檔旁的 `.agreements/guard-rules.tsv` 加自己的攔截規則，只能多擋、不能放寬內建規則（見 [團隊導入指南](docs/team.md#團隊攔截規則)）
- 💬 只是「提到」不會被擋：`echo`、`printf`、`git commit -m`、`gh pr create --body` 這類指令引號裡的文字，以及交給 `cat`、`tee` 寫檔的 heredoc 內文，只當資料、不拿去比對；接到 `| sh`、`bash -c`、`$(…)` 這類會執行的內容照樣攔截。同一條指令裡有 `bash`、`source`、`./x.sh` 這類可能執行剛寫入內容的指令，或出現沒把握的語法時，整條照原文比對
- ⚠️ 已知限制：其他指令引號裡提到（例如 `grep "git push --force"`）仍會被擋；先寫進檔案、下一步再執行的指令攔不到，hook 擋的是「不小心」，不是安全邊界

**為 Cursor、Windsurf 或一般終端機安裝跨工具通用防線：**
```bash
scripts/hook-guard.sh --install-git-hooks
```
自動配置 Git `pre-push`（攔截非快進 Force Push）與 `pre-commit`（主動變更稽核），讓所有編輯器享有相同安全防線。`pre-push` 看不到 `--force-with-lease` 等旗標，任何覆寫遠端都會擋；確實需要時，請在團隊同意後以 `AGREEMENTS_HOOKS_DISABLE=1 git push …` 執行。

### 🔍 主動變更稽核 (`scripts/audit.sh`)
主動掃描 Git Staged、Diff 或指定 Commit，攔截常見高危變更：
- 🚫 **靜默吞噬錯誤**：攔截程式碼中空的 `catch (e) {}` 或 `except: pass`
- 🚫 **測試完整性破壞**：攔截被偷偷刪除的測試斷言（Assertions）
- 🚫 **機敏資料外洩**：攔截誤加入暫存的 `.env*`、`.sql`、憑證與資料庫 Dump
- 🚫 **高危全開權限**：攔截 `chmod 777` 與 Wildcard IAM（`Action: "*"` / `Resource: "*"`）
- ⚠️ **動態樣式清除**：警告前端動態字串拼接的 Tailwind class（避免遭 Purge）
- ⚠️ **直接變更主分支**：警告未開分支直接在 `main` / `master` 上修改

**安裝為本機 Git Pre-commit Hook：**
```bash
scripts/audit.sh --install-hook
```

### 🧪 規則命中測試台（[Playground](https://machiko.github.io/agent-working-agreements/)）
在瀏覽器裡改規則、輸入樣本，馬上看到哪一條規則命中：
- **指令攔截**：輸入指令，看切出哪幾段子指令、哪一條攔截規則命中、哪一段被放行例外放過，可以直接修改或新增規則再測一次
- **守則載入**：輸入檔案路徑，看會載入哪些守則；每份守則會顯示命中幾筆路徑，命中超過一半時會提示 glob 範圍可能太寬
- 比對邏輯跟 `hook-guard` 用同一份案例檔 [`tests/fixtures/guard-cases.tsv`](tests/fixtures/guard-cases.tsv) 驗證；新增攔截規則時，請在這份檔案補上應擋與應放行的案例
- 本機預覽：`node playground/build-data.mjs > playground/data.json && python3 -m http.server -d playground`

### 📝 踩坑事故即時採集 (`/agreements:record`)
當 Agent 又犯了新的低級錯誤時，執行此技能可透過引導式問答（*現象 → 根本原因 → 預防做法*），去識別化後自動儲存為自訂守則：
```bash
/agreements:record
```

---

## 📚 守則目錄清單

### 1. 核心守則（Core，一律安裝）
預算控制在 **400 行以內**，跨所有語言與框架皆適用的底線共識：

| 領域 | 守則名稱 | 重點規範 |
|------|---------|---------|
| **協作** | [`collaboration/honesty`](rules/collaboration/honesty.md) | 不得偽造工具執行結果、無證據不得聲稱「測試通過」（跳過不算通過） |
| **協作** | [`collaboration/test-integrity`](rules/collaboration/test-integrity.md) | 禁止刪除或放寬既有測試斷言來換取綠燈 |
| **協作** | [`collaboration/git-safety`](rules/collaboration/git-safety.md) | Commit 前必須重新確認目前分支，禁止直接在他人分支或主分支亂提交 |
| **協作** | [`collaboration/verification`](rules/collaboration/verification.md) | 以執行證據說話，報告完整重現步驟與驗證日誌 |
| **協作** | [`collaboration/communication`](rules/collaboration/communication.md) | 決策放在使用者看的見之處、重大變更先確認、命中守則時於結尾顯式標註 |
| **協作** | [`collaboration/design-judgment`](rules/collaboration/design-judgment.md) | 顯式程式碼優於隱含黑魔法；以 Guard Test 保障核心邏輯 |
| **協作** | [`collaboration/memory-hygiene`](rules/collaboration/memory-hygiene.md) | 記憶庫衛生管理，不將暫時性錯誤推論沉澱為全域記憶 |
| **安全** | [`security/dangerous-operations`](rules/security/dangerous-operations.md) | 禁止在 Agent 環境放置生產環境金鑰；危險破壞性指令必須二次確認 |
| **安全** | [`security/data-files`](rules/security/data-files.md) | 個資、客戶資料、資料庫 Dump 嚴禁提交進 Git |
| **撰寫** | [`writing/lean-instructions`](rules/writing/lean-instructions.md) | 保持指示文件精簡聚焦，不無限制膨脹全域 Prompt |
| **撰寫** | [`writing/test-naming`](rules/writing/test-naming.md) | 測試函式名稱維持標準英文命名規範 |

---

### 2. 領域與架構地雷守則（Optional，按需選擇安裝）
多數具備 `paths` 條件，僅在碰觸相關檔案時才載入 Context；`collaboration/sdlc-lifecycle`、`security/tenant-isolation` 與「風格慣例」類沒有 `paths`，安裝後常駐載入：

| 類別 | 守則名稱 | 防範之真實地雷事故 |
|------|---------|-------------------|
| **AI 與 LLM 應用** | [`ai/pitfalls`](rules/ai/pitfalls.md) | 外部 LLM SDK 未設超時造成連線池雪崩、未切分角色導致 Prompt 注入越獄、向量資料庫檢索未脫敏 PII、串流未監聽 Client Abort 導致記憶體與 Token 洩漏、歷史對話未設滑動視窗預算擊穿 |
| **自動化測試** | [`testing/pitfalls`](rules/testing/pitfalls.md) | Mock 全域外洩未重置導致跨測試污染、測試中使用靜態 sleep 導致 CI Flaky、整合測試未包覆 Transaction Rollback 造成資料庫髒污、過度 Mock 私有內部實作、非決定性時間與亂數斷言 |
| **前端架構** | [`frontend/pitfalls`](rules/frontend/pitfalls.md) | Tailwind 動態字串拼接遭 Purge、組件 Unmount 監聽與定時器殘留外洩、SSR 預渲染階段存取 Window/Document 崩潰、直接修改 Props 破壞單向數據流、解構遺失響應性（Vue/Svelte） |
| **後端服務** | [`backend/pitfalls`](rules/backend/pitfalls.md) | 空環境變數覆蓋安全預設值、Dev/Mock 依賴混入生產部署、建構階段密鑰殘留、資料大量匯出未分批造成記憶體 OOM、非標準 Primary Key ORM 存取錯誤 |
| **資料庫** | [`database/pitfalls`](rules/database/pitfalls.md) | 非冪等 Migration、大型資料表 `ALTER TABLE` 獲取排他鎖導致連線池打滿、ORM N+1 查詢引發記憶體暴增、軟刪除關聯外洩、浮點數儲存金額精度遺失 |
| **API 整合** | [`api/pitfalls`](rules/api/pitfalls.md) | HTTP/RPC 未設 Timeout 造成執行緒飢餓死鎖、以空 catch 靜默吞噬錯誤、重大變更未維持向下相容、缺乏 Idempotency Key 造成重複扣款/下單 |
| **非同步** | [`async/pitfalls`](rules/async/pitfalls.md) | 快取擊穿與雪崩（Stampede）、佇列毒藥訊息（Poison Pill）死循環、分散式鎖未設釋放防線導致死鎖、無上限並發請求衝垮下游、協程中共享可變狀態競爭 |
| **容器環境** | [`container/pitfalls`](rules/container/pitfalls.md) | 單檔 Bind Mount 在 `git switch` 後 Inode 失效斷鏈、Client 終止後容器遺留孤兒殭屍行程、macOS 檔案監聽事件遺失、反向代理缺少 Host 白名單、禁止將憑證與私鑰烤入映像檔 |
| **雲原生** | [`cloud/pitfalls`](rules/cloud/pitfalls.md) | 高基數（High-Cardinality）Metric 標籤耗盡記憶體、結構化 Log 洩漏 PII 與 Token、連線池與 TIME_WAIT 短暫埠耗盡、Presigned URL 權限與效期過長、循環 Healthcheck 假死 |
| **供應鏈安全** | [`security/supply-chain`](rules/security/supply-chain.md) | 套件名稱幻覺（Hallucination）與搶註投毒、Lockfile 與依賴失步、過度寬鬆 Wildcard IAM / RBAC 授權、多階段容器建構暫存密鑰殘留、測試環境混入未受控偽造憑證 |
| **協作流程** | [`collaboration/sdlc-lifecycle`](rules/collaboration/sdlc-lifecycle.md) | 規範中大型功能開發的 6 階段（規格、實作、測試、驗收、合併、上線）交付標準與品質閘門 |
| **安全合規** | [`security/sast-safe-patterns`](rules/security/sast-safe-patterns.md) | 常見靜態代碼分析（SAST）誤報與正確安全修正模式 |
| **安全合規** | [`security/tenant-isolation`](rules/security/tenant-isolation.md) | 防範 BOLA/IDOR：報表與匯出功能嚴格限制租戶資料範圍，背景任務顯式傳遞授權 |
| **風格慣例** | [`writing/commit-messages`](rules/writing/commit-messages.md) | 規範化 Conventional Commits 格式（搭配繁體中文動詞） |
| **風格慣例** | [`writing/changelog`](rules/writing/changelog.md) | 保持 CHANGELOG 維護粒度與語義清晰 |
| **風格慣例** | [`writing/docs-and-cards`](rules/writing/docs-and-cards.md) | 撰寫卡片與文檔時以 TL;DR 為先之專業表達結構 |
| **風格慣例** | [`writing/taiwan-terminology`](rules/writing/taiwan-terminology.md) | 台灣繁體資訊專業術語標準轉換對照表 |

---

## 🛠️ 管理、更新與移除

### 檢查更新與自動更新
當透過 Claude Code 使用時，執行 `/agreements:setup` 會**自動檢查更新**：
- 若發現已安裝守則有新版本，會主動提示並提供 **「(推薦) 一鍵自動更新至最新版」**，無須重新填寫問答。
- 您也可以隨時輸入 `/agreements:setup 更新` 進行差異預覽與一鍵套用。

若使用命令列腳本（CLI），可直接加上 `--update` 參數，自動沿用既有的勾選設定升級至最新版：
```bash
# Claude Code 規則目錄更新
scripts/install.sh --target ~/.claude/rules/agent-agreements --update

# Cursor 規則目錄更新
scripts/install.sh --cursor .cursor/rules --update

# 單一檔案注入更新（AGENTS.md / Copilot / Windsurf）
scripts/install.sh --agents-md AGENTS.md --update
scripts/install.sh --copilot --update
scripts/install.sh --windsurf --update
```

### 規格化安裝紀錄 (Profile Schema v1)
安裝目錄下的 `.agreements-profile` 採用嚴格的 **Schema v1** 規格維護，包含安裝版本、各規則安裝時之 SHA256 雜湊與團隊策略設定。
* 若從 0.x 升級，系統在執行 `--update` 或 `/agreements:setup` 時會自動進行**無痛向下相容平滑遷移**，使用者無須任何手動操作。

### 檢視安裝狀態
隨時檢查已安裝守則的標題、載入條件與最新版本狀態：
```bash
scripts/install.sh --target ~/.claude/rules/agent-agreements --status
scripts/install.sh --cursor .cursor/rules --status
scripts/install.sh --agents-md AGENTS.md --status
```

### 乾淨移除
只會移除由本工具建立的守則檔案或標記區塊，**絕不觸碰任何自訂檔案或原有設定**：
```bash
scripts/install.sh --target ~/.claude/rules/agent-agreements --uninstall
scripts/install.sh --cursor .cursor/rules --uninstall
scripts/install.sh --copilot --uninstall
scripts/install.sh --windsurf --uninstall
scripts/install.sh --agents-md AGENTS.md --uninstall
```

---

## 🤝 參與貢獻與品質驗證

歡迎提交 Issue 與 PR 分享您踩過的新地雷！從事故回報到守則 PR 的完整流程見 [CONTRIBUTING.md](CONTRIBUTING.md)；用 Claude Code 的話，`/agreements:record` 記錄事故後可以直接整理成事故回報草稿，確認後才送出。提交守則前請先讀 [守則品質標準](docs/rule-quality.md)：每個條目要有事故依據（**為什麼**，或地雷類的**症狀 → 根因 → 怎麼做**），frontmatter 要列 `incidents`（事故來源）與 `last_reviewed`（審查日期），並去除任何真實個資、主機或企業標識。沒有事故依據的條目要在標題標 `<!-- 慣例 -->` 或 `<!-- 參考 -->`。新增或修改守則時，`i18n/en/rules/` 的英文版要一起逐行更新，再執行 `scripts/check-i18n.sh --stamp en <id>`；不熟英文的話，PR 說明裡註明，維護者會協助翻譯。

新守則也要附上效果評測情境，證明「裝了守則，Agent 比較不會犯錯」，格式與執行方式見 [`evals/README.md`](evals/README.md)。

本專案在 CI 中執行嚴格的自動化驗證：
```bash
scripts/check-budget.sh      # frontmatter（含 incidents、last_reviewed、deprecated）與 Core 守則行數小於 400 行
scripts/lint-rules.sh        # 守則內容：條目結構、空泛用語、標題重複、條目長度
scripts/sanitize-check.sh    # 機敏字串、私有 IP、金鑰與去識別化掃描
scripts/check-version.sh     # 跨檔案版號一致性檢查
scripts/check-schema.sh      # schema/v1.json 與規則庫、策略檔範本一致；守則 enforced_by 與 audit／guard 檢查對得上
scripts/check-i18n.sh        # 英文守則與中文來源同步（雜湊、結構欄位、逐行對照）
bash tests/install.test.sh   # 多 Agent 安裝與還原完整測試
bash tests/audit.test.sh     # 主動防線攔截行為測試
bash tests/hook-guard.test.sh  # 執行期攔截（python3 與 bash 兩種模式）與 Git hook 安裝測試
bash tests/policy.test.sh    # 團隊策略檔搜尋與解析測試
bash tests/team.test.sh      # 團隊導入、同步、團隊守則與防漂移測試
bash tests/doctor.test.sh    # 守則體檢與自動修復測試
bash tests/review.test.sh    # Agent 自省審核測試
bash tests/check-version.test.sh  # 版號檢查腳本測試
bash tests/check-budget.test.sh   # frontmatter 預算檢查測試
bash tests/lint-rules.test.sh     # 守則內容檢查測試
bash tests/eval.test.sh           # 守則評測框架離線測試（情境判定、執行器、報表）
bash tests/deprecation.test.sh    # 守則淘汰與審查期限提示測試
bash tests/check-schema.test.sh   # 守則與機器檢查連動測試
bash tests/i18n.test.sh           # 翻譯同步檢查與 install.sh --lang 測試
bash tests/incident-draft.test.sh # 事故回報草稿與去識別化掃描測試
```

---

## 📄 License

本專案依據 [MIT 授權條款](LICENSE) 開源發布。
