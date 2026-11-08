# agent-working-agreements

[![check](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml/badge.svg)](https://github.com/machiko/agent-working-agreements/actions/workflows/check.yml)
[![release](https://img.shields.io/github/v/release/machiko/agent-working-agreements)](https://github.com/machiko/agent-working-agreements/releases)
[![license](https://img.shields.io/github/license/machiko/agent-working-agreements)](LICENSE)

跨 AI Coding Agent（Claude Code、Cursor、GitHub Copilot、Windsurf、Codex 等）的工作協約與防禦守則。

源自長期在生產環境與 AI Agent 協作踩坑的真實事故（Production Incidents），不堆砌通用的最佳實踐廢話，專注於**防禦高危操作、攔截工程地雷、保護程式碼與測試完整性**。

> 本專案規則本文以**繁體中文**撰寫。每條規則皆遵循固定架構：**規則（Rule）→ 為什麼（Why：觸發的真實事故）→ 怎麼做（How：具體落實指引）**。只有理解「為什麼」，Agent 才能在邊界情境下做出正確判斷。

---

## ⚡ 核心設計原則

1. **真實事故驅動（Incident-Driven）**：只收錄實際在生產環境被 AI 搞砸過的問題（如靜默吞噬 Exception、動態 Tailwind 類別遭 Purge、外鍵死鎖、過寬 IAM 授權）。
2. **嚴格 Context 預算控制**：常駐核心守則（Core）在 CI 嚴格限制 **400 行以內**；技術棧與領域守則（Optional）採**按需載入（On-Demand）**，只在 Agent 接觸相關檔案時才載入，不浪費 Context Window。
3. **無損無痛相容（Zero-Friction Ingestion）**：支援獨立檔案複製、Cursor `.mdc` 格式轉譯，以及單檔標記區塊安全注入（保留檔案原有內容，不覆蓋既有設定）。
4. **主動工程防線（Active Guardrails）**：除了被動 Prompt 指示，提供 Git Hook、CLI 稽核與 CI 守門，在 Commit 與 PR 階段直接攔截地雷。

---

## 🚀 跨 Agent 快速安裝

先複製本專案（或直接使用安裝腳本）：

```bash
git clone https://github.com/machiko/agent-working-agreements.git
cd agent-working-agreements
```

### 1. 自動偵測專案技術棧（推薦先執行）
執行自動偵測，分析目前專案特徵並取得建議的規則清單：

```bash
scripts/install.sh --detect
```

---

### 2. 選擇你的 AI Agent 進行安裝

#### 🔹 Claude Code
支援以官方 Plugin 或 CLI 腳本安裝：
```bash
# 方式 A：透過 Plugin Marketplace（推薦）
/plugin marketplace add machiko/agent-working-agreements
/plugin install agreements@agent-working-agreements
/agreements:setup

# 方式 B：透過 CLI 腳本直接安裝至全域或專案規則目錄
scripts/install.sh --target ~/.claude/rules/agent-agreements --select frontend/pitfalls,database/pitfalls
```

#### 🔹 Cursor IDE (`.cursor/rules/*.mdc`)
自動轉譯為 Cursor 原生 `.mdc` 規格，Core 守則標註 `alwaysApply: true`，特定技術棧守則自動轉換為 `globs` 條件：
```bash
# 預覽安裝
scripts/install.sh --cursor .cursor/rules --select frontend/pitfalls,database/pitfalls --dry-run

# 正式套用
scripts/install.sh --cursor .cursor/rules --select frontend/pitfalls,database/pitfalls
```

#### 🔹 GitHub Copilot (`.github/copilot-instructions.md`)
透過 HTML 標記區塊安全注入，**完全保留檔案中原有的其他指令**：
```bash
# 注入至專案的 .github/copilot-instructions.md
scripts/install.sh --copilot --select frontend/pitfalls,backend/pitfalls
```

#### 🔹 Windsurf IDE (`.windsurfrules`)
透過安全標記區塊注入專案根目錄的 `.windsurfrules`：
```bash
# 注入至專案的 .windsurfrules
scripts/install.sh --windsurf --select frontend/pitfalls,security/supply-chain
```

#### 🔹 OpenAI Codex / Aider / 支援 `AGENTS.md` 的 Agent
注入至專案根目錄的 `AGENTS.md`，自動移除 Frontmatter 並保留前後原有文字，內建 Codex 32 KiB 讀取上限警示：
```bash
# 注入至 AGENTS.md
scripts/install.sh --agents-md AGENTS.md --select database/pitfalls,api/pitfalls
```

#### 🔹 通用 CLI Agent 或自訂目錄（Antigravity、Aider 等）
若使用的工具支援自訂規則目錄或 Prompt 載入：
```bash
scripts/install.sh --target ./my-rules-dir --select frontend/pitfalls
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

---

## 🛡️ 主動防護與體檢診斷工具

本專案不僅包含靜態 Prompt 守則，還附帶全套主動稽核與體檢工具：

### 🩺 守則健康度體檢與自動修復 (`scripts/doctor.sh`)
一鍵診斷專案的守則設定、版本新鮮度、Git 守門機制與 CI 工作流就緒度，產出 0–100 分綜合評分，支援 `--fix` 自動補齊修復：

```bash
# 體檢目前專案
scripts/doctor.sh

# 一鍵自動修復缺失之 Git hook、CI 檔案與過期守則
scripts/doctor.sh --fix

# Claude Code 專屬指令
/agreements:doctor
/agreements:doctor fix
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

### 🛡️ 執行期主動防護 (Runtime Hooks)
透過 Claude Code 的 Plugin Hook 機制，在 Agent 執行高危破壞性指令的當下直接阻擋：
- 🛑 **禁止 Force Push**：即時攔截 `git push --force` 或 `-f`
- 🛑 **防範無預警清空代碼**：阻擋未指定目錄之 `git reset --hard` 與 `git clean -f`
- 🛑 **禁止根目錄毀滅性指令**：阻擋 `rm -rf /` 與 `chmod -R 777`
- 🛑 **防範憑證外洩**：即時攔截包含 `.env` 之網路傳輸指令
- 💡 可透過環境變數 `AGREEMENTS_HOOKS_DISABLE=1` 暫時跳過攔截

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
具備 `paths` 條件，僅在碰觸相關檔案時才載入 Context：

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
| **風格慣例** | [`writing/taiwan-terminology.md`](rules/writing/taiwan-terminology.md) | 台灣繁體資訊專業術語標準轉換對照表 |

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

歡迎提交 Issue 與 PR 分享您踩過的新地雷！提交守則時請務必維持 **規則 → 為什麼（事故）→ 怎麼做** 的完整結構，並去除任何真實個資、主機或企業標識。

本專案在 CI 中執行嚴格的自動化驗證：
```bash
scripts/check-budget.sh      # 嚴格驗證 Core 守則行數小於 400 行
scripts/sanitize-check.sh    # 機敏字串、私有 IP、金鑰與去識別化掃描
scripts/check-version.sh     # 跨檔案版號一致性檢查
bash tests/install.test.sh   # 多 Agent 安裝與還原完整測試
bash tests/audit.test.sh     # 主動防線攔截行為測試
bash tests/doctor.test.sh    # 守則體檢與自動修復測試
bash tests/review.test.sh    # Agent 自省審核測試
```

---

## 📄 License

本專案依據 [MIT 授權條款](LICENSE) 開源發布。
