# Changelog

格式依 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，條目寫法依本 repo 的 [`rules/writing/changelog.md`](rules/writing/changelog.md)。版號依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

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
