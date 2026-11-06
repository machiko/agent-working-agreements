# Changelog

格式依 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，條目寫法依本 repo 的 [`rules/writing/changelog.md`](rules/writing/changelog.md)。版號依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

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
