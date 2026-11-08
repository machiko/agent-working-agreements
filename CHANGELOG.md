# Changelog

格式依 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，條目寫法依本 repo 的 [`rules/writing/changelog.md`](rules/writing/changelog.md)。版號依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

## [0.10.0] - 2026-11-08

### Added

- 新增 執行期主動防線（Runtime Hooks）：新增 `hooks/hooks.json`、`scripts/hook-guard.sh` 與 `scripts/hook-guard.py`，透過 Claude Code `PreToolUse` 機制，在 Agent 敲下 `git push --force`、未授權 `git reset --hard`、`git clean -f`、`rm -rf /` 或洩漏 `.env` 傳輸時即時攔截，支援 `AGREEMENTS_HOOKS_DISABLE=1` 停用開關
- 新增 AI 與 LLM 應用地雷守則：`rules/ai/pitfalls.md`（Optional），防範外部 SDK 呼叫未設超時造成連線池雪崩、未切分角色導致 Prompt 注入與系統提示外洩、向量化與 RAG 檢索未脫敏 PII、串流未監聽 Client Abort 導致記憶體與 Token 洩漏、歷史對話未設滑動視窗預算擊穿
- 擴充 智慧專案特徵偵測：`scripts/install.sh --detect` 支援辨識 OpenAI、Anthropic、LangChain、LlamaIndex 與向量資料庫（Pinecone/Chroma/Qdrant/Weaviate）依賴，自動推薦安裝 `ai/pitfalls`
- 新增 Hook 主動防線單元測試：`tests/hook-guard.test.sh` 涵蓋各類破壞性 Git 指令、系統高危操作攔截與停用開關驗證

## [0.9.6] - 2026-11-08

### Changed

- 重構 `/agreements:setup` 引導流程：徹底廢除舊版多層「加裝/移除/重新自訂」意圖分流選單，重構為「統一單一入口、方案驅動（Preset-Driven）」體驗。首次安裝與後續重跑皆由第 1 題直達核心方案（⚡ 智慧專案推薦、🔄 維持現狀更新、🛡️ 完整防禦套裝、🪶 極簡核心守則），一鍵自動完成安裝或同步。

## [0.9.5] - 2026-11-07

### Added

- 新增 命中守則顯式提示機制：`rules/collaboration/communication.md` 與 `templates/CLAUDE.md` 規範 Agent 於觸發具體工程防禦與協作動作時，在回應結尾以 `🛡️ 命中守則：[類別/名稱] 具體動作` 單行徽章標註，讓守則防護透明可見

## [0.9.4] - 2026-11-06

### Fixed

- 修復 `/agreements:setup` 重跑流程：重構為「意圖分流機制（加裝、移除、一鍵更新、重新挑選）」，解決 Claude Code 終端問答介面無法預選勾選框導致既有守則遭誤刪的問題

## [0.9.3] - 2026-11-06

### Added

- 新增 軟體開發生命週期守則：`rules/collaboration/sdlc-lifecycle.md`（Optional），定義中大型功能在規格 (Spec)、實作 (Code)、測試 (Test)、驗收 (Review)、合併 (Merge)、上線 (Release) 之 6 階段交付標準與品質閘門

### Changed

- 更新 `/agreements:setup`：問答第 2 題擴充為「協作與寫作規範」，納入 `collaboration/sdlc-lifecycle` 供專案自由勾選安裝
- 更新 守則目錄文件：`README.md` 新增「協作流程」分類登記

## [0.9.2] - 2026-11-06

### Added

- 新增 一鍵更新機制：`scripts/install.sh --update`，自動沿用既有安裝之 profile 記錄或標記區塊之規則選項，無須重新指定 `--select` 即可將已安裝守則升級至最新版本
- 新增 自動檢查更新引導：`/agreements:setup` 與 `/agreements:setup 更新`，啟動時自動檢查遠端最新版本與已安裝守則新鮮度，若偵測到新版主動提供「(推薦) 一鍵自動更新至最新版」，無須重填問答流程

### Changed

- 更新 守則管理指南：`README.md` 新增檢查更新與自動更新章節，涵蓋 Claude Code、Cursor、AGENTS.md、Copilot 與 Windsurf 之 `--update` 操作指引

## [0.9.1] - 2026-11-06

### Added

- 新增 多租戶與匯出資料隔離守則：`rules/security/tenant-isolation.md`，防範 OWASP BOLA / IDOR 授權漏洞，規範列表/報表/匯出強制套用租戶範圍，背景 Worker 顯式傳遞授權上下文，跨環境權限使用固定代碼
- 新增 向下相容別名：`scripts/install.sh` 支援 `security/data-scope -> security/tenant-isolation` 與 `security/tls-certificates -> container/pitfalls` 無痛升級

### Changed

- 更新 `/agreements:setup`：已安裝守則在問答中一律預設為勾選狀態（Checked）；若使用者取消勾選（Uncheck）則代表自目標環境移除該規則
- 更新 容器環境地雷：`rules/container/pitfalls.md` 增補「憑證與私鑰禁止打包進容器映像」條款，防止私鑰殘留映像歷史 Layer

### Removed

- 刪除 專案特化規則：移除帶有特定地端換證事故痕跡的 `rules/security/tls-certificates.md`，將核心原則收斂至容器守則

## [0.9.0] - 2026-11-06

### Added

- 新增 全平台 CI/CD 守門生成矩陣：`scripts/install.sh --ci` 擴充支援 `github`、`gitlab`、`bitbucket` 與 Python `pre-commit` 框架，內建專案環境智慧自動偵測
- 新增 CI 平台標準設定範本：`templates/ci/gitlab-ci.yml`、`templates/ci/bitbucket-pipelines.yml`、`templates/ci/pre-commit-config.yaml`
- 新增 測試與 Mock 地雷守則：`rules/testing/pitfalls.md`，防範 Mock 全域外洩未重置、靜態 sleep 延遲導致 Flaky 測試、整合測試未回滾資料庫髒污、過度 Mock 私有內部實作細節與非決定性斷言
- 新增 Agent 自省審查工具與技能：`scripts/review.sh` 與 `/agreements:review`，在提交前對照守則逐條清查 Diff 並輸出 Markdown 審查報告表格
- 新增 守則健康診斷自動修復：`scripts/doctor.sh --fix` 與 `/agreements:doctor fix`，一鍵自動安裝 Git pre-commit 防線、配置 CI 守門工作流並補齊核心守則
- 新增 自動化測試：新增 `tests/doctor.test.sh` 與 `tests/review.test.sh` 完整驗證體檢修復與自省審查功能

### Changed

- 更新 專案特徵偵測：`scripts/install.sh --detect` 支援辨識 Jest、Vitest、PHPUnit、Pytest 與測試目錄，自動推薦 `testing/pitfalls`
- 更新 `/agreements:setup`：問答擴充納入「測試與 Mock 地雷 (`testing/pitfalls`)」
- 更新 發版自動化腳本：`scripts/release.sh` 發版驗證納入 `doctor.test.sh` 與 `review.test.sh`
- 更新 文件指南：`README.md` 全面擴充多平台 CI/CD、Doctor 自動修復與自省審查說明

## [0.8.0] - 2026-11-06

### Added

- 新增 供應鏈安全與依賴地雷：`rules/security/supply-chain.md`，防範套件名稱幻覺與搶註投毒、依賴版本浮動與 Lockfile 失步、過度寬鬆 Wildcard IAM 授權、多階段容器建構暫存密鑰殘留、測試環境混入未受控偽造憑證
- 新增 Agent 守則健康體檢診斷工具：`scripts/doctor.sh` 與 `/agreements:doctor` 技能，評估守則安裝配置、版本新鮮度、Git pre-commit 守門機制與 CI 工作流就緒度，產出 0–100 健康評分與修復指引
- 新增 高危全開放權限主動稽核：`scripts/audit.sh` 新增第 6 項安全防線，自動攔截 `chmod 777` 與 Wildcard IAM (`Action: "*"`, `Resource: "*"`) 變更

### Changed

- 更新 `/agreements:setup`：安全類別問答擴充納入「供應鏈安全與依賴地雷 (`security/supply-chain`)」
- 更新 發版自動化腳本：`scripts/release.sh` 發版檢查加入 `doctor.sh` 守則健康度自動驗證

## [0.7.0] - 2026-11-06

### Added

- 新增 雲原生、日誌與可觀測性通用規則：`rules/cloud/pitfalls.md`，涵蓋高基數指標標籤拖垮監控、結構化日誌洩漏 PII/Token、連線池未複用致 Ephemeral Port 耗盡、Presigned URL 權限與有效期限失控、循環健康檢查重啟死鎖
- 新增 GitHub Copilot 支援：`scripts/install.sh --copilot` 一鍵將守則注入 `.github/copilot-instructions.md` 標記區塊，支援預覽、狀態查詢與獨立卸載
- 新增 Windsurf 規則支援：`scripts/install.sh --windsurf` 一鍵將守則注入 `.windsurfrules`，達成主流 Agent 工具鏈全覆蓋
- 新增 CI 自動化守護工作流安裝器：`scripts/install.sh --ci` 一鍵配置 `.github/workflows/agent-audit.yml` 與審查腳本，在 PR 階段阻擋合規違規
- 新增 雲原生與監控特徵偵測：`install.sh --detect` 支援辨識 K8s、Helm、Terraform、Prometheus、OpenTelemetry、Datadog 依賴並自動推薦 `cloud/pitfalls`
- 新增 測試套件：新增 Copilot、Windsurf、CI 工作流安裝與雲原生偵測自動化測試案例

### Changed

- 更新 `/agreements:setup`：工程地雷問答擴充納入架構層「雲原生、日誌與可觀測性地雷 (`cloud/pitfalls`)」
- 更新 說明文件：新增 GitHub Copilot、Windsurf 與 GitHub Actions CI 自動化守門章節

## [0.6.0] - 2026-11-06

### Added

- 新增 現代前端與組件化通用規則：`rules/frontend/pitfalls.md`，涵蓋 React、Vue、Next.js、Svelte 跨框架通用事故（Tailwind dynamic purge、組件卸載記憶體洩漏、SSR window/document 預渲染報錯、Prop 屬性突變、響應性解構追蹤）
- 新增 Web 後端與應用服務通用規則：`rules/backend/pitfalls.md`，涵蓋 Node.js、Python、Go、PHP、Java 跨語言通用事故（環境變數留空覆蓋預設值、dev 依賴洩漏、建構階段密鑰注入失敗、匯出與大運算 OOM、ORM 非標準主鍵資料覆蓋）
- 新增 容器與本機虛擬化環境通用規則：`rules/container/pitfalls.md`，涵蓋 Docker、Podman、Compose 通用事故（切分支單檔 bind mount inode 斷線、終端殺 client 程序殘留、macOS inotify 檔案事件丟失、測試 profiler 常駐拖慢、反向代理路由白名單）
- 新增 向後相容別名映射：`scripts/install.sh` 自動將舊技術棧 id (`vue/pitfalls`, `laravel/pitfalls`, `docker/pitfalls`) 平滑映射至全新通用應用層規則
- 新增 多技術棧智慧特徵偵測：擴大支援 React、Next.js、Nuxt、Svelte、Python、Go、Node.js、Containerfile 等特徵識別

### Changed

- 重構 守則架構昇華為純通用分層：移除特定技術棧目錄（`rules/vue/`, `rules/laravel/`, `rules/docker/`），工程地雷全面劃分為「架構層（API、Database、Async）」與「應用層（Frontend、Backend、Container）」
- 更新 主動稽核工具：`scripts/audit.sh` 前端樣式稽核全面支援 `.vue`, `.jsx`, `.tsx`, `.svelte`, `.html`，並增補除錯語法殘留檢查
- 更新 `/agreements:setup`：問答工程地雷選項全面升級為通用架構層與通用應用層

## [0.5.1] - 2026-11-06

### Changed

- 優化 自動發版流程：`scripts/release.sh` 發版時自動依 CHANGELOG 內容建立 GitHub Release 頁面並標記最新版本

## [0.5.0] - 2026-11-06

### Added

- 新增 主動守護稽核工具：`scripts/audit.sh` 與 `/agreements:audit` 技能，可掃描 staged 暫存區、diff 或 commit 是否違反空 catch、弱化測試斷言、機敏檔案與分支隔離守則，並支援 `--install-hook` 安裝 Git pre-commit 守門機制
- 新增 optional 規則「異步、佇列與快取地雷」：快取雪崩與熱點擊穿、佇列毒藥訊息無窮重試、分佈式鎖未設租約死鎖、未受控併發扇出打爆下游、跨協程/執行緒共用可變狀態競爭
- 新增 現場事故採集技能：`/agreements:record` 引導開發者以 3 題問答快速將踩雷教訓固化為專案自訂守則
- 新增 異步架構智慧偵測：`install.sh --detect` 支援識別 jobs、queues、workers、tasks 及 Redis、BullMQ、Celery、Sidekiq 依賴並自動推薦 `async/pitfalls`
- 新增 稽核工具測試套件：`tests/audit.test.sh` 覆蓋暫存區攔截、空 catch 識別、文件反例忽略與 pre-commit hook 安裝驗證

### Changed

- 更新 `/agreements:setup`：工程地雷問答納入通用架構「異步、佇列與快取地雷 (`async/pitfalls`)」
- 更新 說明文件：新增主動稽核與事故採集技能說明，強化分散式架構與通用防線定位

## [0.4.0] - 2026-11-06

### Added

- 新增 optional 規則「資料庫與 ORM 地雷」：遷移腳本缺乏冪等性、大表加欄位排他鎖、ORM 隱形 N+1 查詢暴衝、軟刪除關聯洩漏、浮點數金額精度災難
- 新增 optional 規則「API 與整合契約地雷」：外部呼叫未設超時造成雪崩、靜默吞噬錯誤、破壞性欄位變更、缺乏冪等鍵造成重複扣款
- 新增 專案智慧偵測：`install.sh --detect` 自動掃描專案檔案與結構，回傳推薦的 optional 規則清單
- 新增 `/agreements:setup` 自動推薦：以 `--detect` 掃描專案特徵，並在「工程地雷」問答中為匹配項目標註「推薦｜」

### Changed

- 更新 品牌定位與文件：由特定框架轉型為涵蓋跨語言通用工程地雷（資料庫/ORM、API/契約、Docker）與前端/特定框架守則
- 更新 測試套件：新增 `--detect` 專案特徵偵測與參數校驗測試

## [0.3.0] - 2026-11-06

### Added

- 新增 optional 規則「Vue 與前端地雷」：Vue 3 響應性解構丟失、直接修改 Prop 屬性、Pinia store 在 action 外賦值、Tailwind 動態 class 被 purge、未清理的監聽器造成內存洩漏、Vite SSR window 存取、第三方庫 shallowRef
- 新增 Cursor IDE 規則格式支援：`install.sh --cursor` 自動將規則轉換為 Cursor `.mdc` 檔案，自動將 paths 轉譯為 globs frontmatter 並標記 core 規則為 `alwaysApply: true`
- 新增 GitHub Issue 事故回報模板：以結構化表單徵集真實「症狀 → 根因 → 怎麼做」與去識別化自檢清單
- 新增 並行 session 守則強化：在 Git 安全守則增補多 session / worktree 並行時的 DB migration 與本機 port 碰撞防護

### Changed

- 更新 `/agreements:setup`：技術棧地雷選項納入「Vue 與前端地雷」
- 更新 測試套件：新增 Cursor `.mdc` 轉換與安裝解除安裝的自動化測試

## [0.2.0] - 2026-11-05

### Added

- 新增 安裝現況查詢：`install.sh --status` 與 `/agreements:setup 狀態` 列出已安裝的規則、載入方式，以及最新／有新版／已手動修改／檔案遺失
- 新增 安裝、預覽、移除的每一行都附上規則標題；`/agreements:setup` 開頭先摘要兩個範圍的現況，兩邊都裝時提醒會重複載入
- 新增 optional 規則「TLS 憑證更換」：逐張核對憑證鏈並用實機驗收、WAF／LB 終止 TLS 時換對地方、憑證不烤進映像
- 新增 Docker 地雷「部署管線」：部署不依賴外部 registry、runner 顯示線上不代表在跑、自動回滾的前提
- 新增 GitHub Actions 檢查：安裝器測試、core 行數預算、識別資訊掃描、版號一致，ubuntu 與 macOS 都跑
- 新增 本 CHANGELOG 與 README 的更新步驟

### Changed

- 更新 CHANGELOG 規則：動詞改用跟 commit 同一組；版本日期在發版前最後一個 PR 填好，補日期的 commit 不加 `[skip ci]`
- 更新 Commit 格式規則：資安修補的分支、commit、changelog 改用中性措辭
- 更新 Git 安全規則：從遠端 release 切出的分支要取消追蹤；含 submodule 的 worktree 正確移除方式

## [0.1.0] - 2026-10-19

### Added

- 新增 19 條有事故佐證的規則，分 core（一律安裝、常駐上限 400 行）與 optional（問答挑選，技術棧規則按需載入）
- 新增 `/agreements:setup` 問答安裝：一次 4 題、預覽後才寫入、可重跑調整或移除，手動改過的檔案預設保留
- 新增 Codex 等讀 `AGENTS.md` 的 agent 安裝方式：只改寫標記區塊，區塊外內容不動
- 新增 `/agreements:harvest` 維護流程：從私人 memory 盤點新教訓、去識別化後整理成規則
