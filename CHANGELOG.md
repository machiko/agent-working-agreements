# Changelog

格式依 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，條目寫法依本 repo 的 [`rules/writing/changelog.md`](rules/writing/changelog.md)。版號依 [Semantic Versioning](https://semver.org/lang/zh-TW/)。

## [Unreleased]

### Fixed

- 修復 搜尋團隊策略檔時，找到策略檔後往上列目錄的程序仍繼續寫入已關閉的管線；在忽略 SIGPIPE 的環境（例如 GitHub macOS runner）會停不下來，讓安裝、hook 與 CI 卡住

## [1.7.0] - 2026-11-11

### Added

- 新增 規則命中測試台（[Playground](https://machiko.github.io/agent-working-agreements/)）：「指令攔截」輸入指令，看切出哪幾段子指令、哪一條攔截規則命中、哪一段被放行例外放過，可以直接修改或新增規則再測；「守則載入」輸入檔案路徑，看會載入哪些守則，命中超過一半樣本的 glob 會提示範圍可能太寬；網址會記住改過的內容，可以分享
- 新增 攔截規則的共用案例檔 `tests/fixtures/guard-cases.tsv`：hook-guard（python、bash）與 Playground 跑同一份案例，CI 確認三邊判定與命中的守則一致；新增攔截規則時在這裡補上應擋與應放行的案例

## [1.6.0] - 2026-11-11

### Added

- 新增 團隊守則：放在策略檔旁的 `.agreements/rules/<name>.md`，以 `custom/<name>` 安裝到每個目標（Claude Code、Cursor、AGENTS.md、Copilot、Windsurf），`enforce_rules` 可以強制；`--status` 另列「團隊守則」分組
- 新增 `install.sh --sync`（`/agreements:setup sync`）：依策略檔把每個目標裝好或更新、帶入團隊守則、安裝 Git hooks，每次依策略檔重新展開 `preset` 與 `enforce_rules`，連跑兩次第二次不會有變更；團隊守則有格式問題時列出提示，不擋同步；專案沒有 `scripts/audit.sh` 時複製一份給 pre-commit 稽核
- 新增 `install.sh --team-init`（`/agreements:setup team`）：一條指令產生策略檔與 `.agreements/rules/`、安裝每個目標、Git hooks、CI 守門與防漂移工作流，最後列出要 commit 的檔案與給成員的同步指令
- 新增 策略檔欄位 `targets`、`agreements_version`、`git_hooks`；`agreements_version` 跟工具版本不同時 `--sync` 停下並說明怎麼對齊或升級
- 新增 `remote-install.sh --version`；遠端執行 `--sync`、`--check-drift` 時依策略檔的 `agreements_version` 下載對應版本；`--team-init` 產生的防漂移工作流與成員同步指令釘在當下版本的 tag
- 新增 團隊導入指南（`docs/team.md`、`docs/team.en.md`）

### Changed

- `doctor.sh --check-drift` 檢查策略檔 `targets` 的每個目標，團隊守則改了沒同步、刪了沒同步、安裝版本與 `agreements_version` 不符都算漂移
- `/agreements:record` 在有 `.agreements.json` 的專案預設寫到 `.agreements/rules/` 並同步；`doctor.sh` 提示還留在本機 `custom/` 的自訂守則可以搬過去
- `scripts/lint-rules.sh`、`scripts/check-budget.sh` 可用 `RULES_DIR` 檢查團隊守則

### Fixed

- 來源守則檔唯讀時（例如唯讀的 plugin 快取），安裝出來的檔案也變成唯讀，之後無法更新
- 策略檔 `preset: smart` 在專案安裝時偵測的是安裝目錄（例如 `.claude/rules/agent-agreements`）而不是專案根目錄，等於沒有偵測
- `--detect` 把 `.github/workflows/agent-audit.yml` 等本工具產生的檔案當成 AI 專案特徵，安裝後再偵測會多推薦 `ai/pitfalls`

## [1.5.0] - 2026-11-10

### Added

- 新增 貢獻指南（`CONTRIBUTING.md`、`CONTRIBUTING.en.md`）：從事故回報、分類判斷、寫守則、英文版、評測情境到開 PR 的完整流程
- 新增 PR 範本：新守則要勾選事故來源、英文版、評測情境、去識別化與各項檢查
- 新增 `/agreements:record` 回報上游：記錄事故後可整理成事故回報 issue 草稿，標題與草稿都做去識別化掃描，使用者看過並明確確認後才送出
- 新增 `scripts/incident-draft.sh`：把自訂守則轉成事故回報草稿，只產生本機檔案、不會送出；`scripts/sanitize-check.sh` 可掃描指定檔案

### Changed

- 事故回報 issue 範本的分類選單更新為目前的 12 個分類

## [1.4.0] - 2026-11-10

### Added

- 新增 英文版守則：28 條守則都有逐行對照的英文版（`i18n/en/rules/`），安裝時加 `--lang en` 即可；團隊可在 `.agreements.json` 設 `"lang": "en"` 統一語言
- 新增 安裝語言記錄：`--update`、`--status` 沿用安裝時的語言，`/agreements:setup` 首次安裝時詢問語言，`doctor.sh --check-drift` 把安裝語言與策略檔不符視為漂移
- 新增 翻譯同步檢查：`scripts/check-i18n.sh` 擋下中文改了但英文沒跟上、結構不一致或沒有逐行對齊的翻譯，納入 CI
- 新增 英文版 README（`README.en.md`），與中文 README 互相連結

### Changed

- 守則品質標準新增第 9 節「翻譯」：逐行對照、哪些欄位原樣複製、哪些範例保留中文，以及改完中文後用 `--stamp` 更新雜湊

## [1.3.0] - 2026-11-10

### Added

- 新增 守則淘汰機制：frontmatter 可標 `deprecated`（原因）與 `replaced_by`（替代守則）；淘汰守則不再被 `--detect` 推薦，`preset: full` 也不安裝，明確 `--select` 時照裝並提示替代守則，`install.sh --list` 第 8、9 欄標示淘汰狀態與替代守則
- 新增 `doctor.sh` 守則生命週期檢查：已安裝的淘汰守則扣分並提示替代守則；`last_reviewed` 超過 1 年時提示重新審查，年數可用 `AGREEMENTS_REVIEW_MAX_YEARS` 調整
- 新增 守則與機器檢查連動：`audit.sh` 每項檢查有穩定 ID，守則以 `enforced_by` 列出對應的 audit 檢查與執行期攔截規則，`scripts/check-schema.sh` 雙向驗證，避免改了檢查卻忘了守則

### Changed

- `scripts/check-budget.sh` 檢查淘汰欄位：原因不可空白、core 守則不可直接淘汰（先改成 optional），`replaced_by` 必須是另一條存在且未淘汰的守則
- 守則品質標準新增第 7 節「淘汰守則」（含 CHANGELOG Deprecated／Removed 慣例）與第 8 節「守則與機器檢查連動」

## [1.2.0] - 2026-11-10

### Added

- 新增 守則效果評測：`evals/run.sh` 讓 Agent 在有守則、無守則下各跑同一個任務，自動判定違規並輸出違規率對照表，標出無效守則；以評測專用設定目錄或 `--bare` 隔離個人設定，Agent 在 sandbox 內執行
- 新增 27 個評測情境：core 守則各 2 個，testing、database、supply-chain、tenant-isolation、sast 各 1 個；情境格式與撰寫方式見 `evals/README.md`

## [1.1.0] - 2026-11-10

### Added

- 新增 守則品質標準：`docs/rule-quality.md` 定義地雷、協作守則、慣例、參考四種條目，以及依據、可驗證動作、不重複、長度與常駐預算的要求
- 新增 守則內容檢查：`scripts/lint-rules.sh` 檢查條目結構、空泛用語、跨檔標題重複與條目長度，納入 CI
- 新增 守則事故來源與審查日期：frontmatter 新增 `incidents`、`last_reviewed`，由 `scripts/check-budget.sh` 檢查；`/agreements:record` 產出的守則一併帶上

### Changed

- 更新 28 條守則：依品質標準盤點，補上事故來源與審查日期；沒有事故依據的條目標為慣例或參考；「盡量」等空泛用語改寫成具體動作
- 更新 常駐守則去重：`git-safety` 的不可逆操作確認併入 `dangerous-operations`，`verification` 的「交給 hook」準則併入 `lean-instructions`，`taiwan-terminology` 刪除與 `communication` 重複的命名條目

## [1.0.1] - 2026-11-09

### Added

- 新增 團隊策略預設方案：`.agreements.json` 的 `preset`（`smart`、`full`、`core`）正式生效，專案安裝且未自訂 `--select` 時自動依方案展開預設守則，並更新 `schema/v1.json`
- 新增 遠端免 Clone 一鍵安裝腳本：`scripts/remote-install.sh`，非 Claude Code 編輯器（Cursor、Copilot、Windsurf、AGENTS.md）可直接透過 `curl | bash` 一行完成部署與 Git hooks 安裝

### Changed

- 更新 README 支援矩陣與安裝指南：新增各 Agent 遠端一鍵安裝指引，並標明 Claude Code（終端即時攔截）與其他編輯器（Git 守門攔截）之防護層次邊界
- 更新 README 核心差異化分析：新增客觀生態對比表格，釐清本專案三層立體防線與一般 Rules 庫、單點 Hook 工具之定位區隔

## [1.0.0] - 2026-11-09

### Added

- 新增 團隊策略檔規範（Team Policy as Code）：支援專案根目錄 `.agreements.json` / `.agreementsrc` 與 `schema/v1.json`，鎖定團隊必備守則（`enforce_rules`），支援 Monorepo 階層向上繼承與一鍵導出（`doctor.sh --init-policy`）
- 新增 執行期主動防護網（Active Runtime Hooks）：透過 Claude Code `PreToolUse` 與 Git `pre-push`/`pre-commit` 通用 Hook，在 Agent 執行 `push --force`、未授權 `reset --hard`、`git clean -f`、`rm -rf /` 或外傳 `.env` 時即時攔截，集中管理於 `scripts/lib/guard-rules.tsv`
- 新增 守則安全防篡改機制：團隊策略支援 `prohibit_disable_hooks: true`，強制忽略環境變數繞過開關（`AGREEMENTS_HOOKS_DISABLE`），確保 CI 與本地安全防線不可被 Agent 自行解除
- 新增 Profile Schema v1 與規格化遷移：`.agreements-profile` 升級為 Schema v1，記錄安裝版本、規則 SHA256 雜湊與策略來源，支援舊版平滑升級
- 新增 CI 守則防漂移檢驗（Anti-Drift）：`scripts/doctor.sh --check-drift` 於 CI 流程嚴格檢驗守查完整性與團隊強制守則安裝狀態，遭竄改或遺失直接阻擋 PR
- 新增 Schema 一致性自動化 CI 檢查：`scripts/check-schema.sh` 比對 `schema/v1.json` 的守則清單與規則庫，並驗證策略檔範本與 `--init-policy` 產出，納入 CI
- 新增 AI 與 LLM 應用地雷守則：`rules/ai/pitfalls.md`，防範 SDK 呼叫未設逾時、Prompt 注入、PII 洩漏、串流未監聽 Client Abort 與 Token 預算擊穿
- 新增 一鍵更新機制：`scripts/install.sh --update` 與 `/agreements:setup`，自動沿用既有 profile 無須重新問答

### Changed

- 更新 `/agreements:setup` 引導流程：重構為方案驅動（Preset-Driven）體驗，支援智慧專案推薦、維持現狀更新、完整防禦套裝與極簡核心守則一鍵安裝
- 更新 命中守則顯式提示機制：規範 Agent 於觸發防禦或協作動作時，以 `🛡️ 命中守則：[類別/名稱]` 單行徽章標註，提升防護透明度
- 更新 跨編輯器與通用 Git Hook 相容性：相容 husky、worktree 與 `core.hooksPath`，已存在 hook 自動備份並串接執行

### Fixed

- 修復 執行期攔截規則漏洞與誤判：補齊 `rm -fr /`、`git push -uf`、`bash -c`、子 shell 包裝攔截，並修正 `--force-with-lease` 與 `git clean -n` 誤擋
- 修復 跨平台相容性：支援 macOS（BSD）與 Linux（GNU）雙平台 `stat`、`date`、`shasum`/`sha256sum` 與無 `python3` 環境之 bash fallback

## [1.0.0-rc.3] - 2026-11-08

### Added

- 新增 schema 一致性檢查：`scripts/check-schema.sh` 比對 `schema/v1.json` 的守則清單與規則庫，並驗證策略檔範本與 `--init-policy` 產出，納入 CI

### Changed

- 更新 執行期攔截規則：攔截規則集中到 `scripts/lib/guard-rules.tsv`，有無 `python3` 行為一致；被擋時 Agent 會收到攔截原因；python 比對失敗時改走 bash 比對
- 更新 `/agreements:doctor` 與 `/agreements:audit`：優先執行 Plugin 內的腳本，不再誤跑專案內同名的其他腳本
- 更新 `schema/v1.json`：`preset` 標明為保留欄位，目前不生效
- 更新 README：修正攔截範圍、按需載入與測試清單的錯誤描述

### Fixed

- 修復 Git pre-commit hook 在專案沒有 `scripts/audit.sh` 時擋下所有 commit；找不到稽核腳本時改用 Plugin 內版本，都沒有只警告
- 修復 安裝 Git hook 覆寫既有 hook（例如 husky）；改為備份成 `.agreements-bak` 並在守門檢查通過後串接執行
- 修復 Git worktree 與設定 `core.hooksPath` 的專案無法安裝或偵測 hook
- 修復 執行期攔截漏擋 `rm -fr /`、`git push -uf`、`+refspec`、`bash -c` 與 `$(…)` 包裝、`${HOME}`，以及誤擋 `--force-with-lease`、`git clean` 預覽與用 `&&` 串接的正常指令
- 修復 沒有 `python3` 時的 bash 攔截漏擋 `git clean`、`chmod 777` 與 `.env` 外傳，並誤擋 `rm -rf /tmp/…`
- 修復 團隊策略檔：首次安裝到新目錄時被略過、搜尋越過 git root 讀到家目錄、Monorepo 子目錄的 `prohibit_disable_hooks` 不生效、字串 `"false"` 被當成鎖定、沒有 `python3` 時單行 `enforce_rules` 只讀到最後一項
- 修復 `--check-drift` 對策略強制守則只檢查有無安裝，檔案遺失或被修改仍判定通過
- 修復 `/agreements:doctor fix`、`drift`、`init-policy` 參數沒有傳進腳本
- 修復 pre-push 遇到本機沒有的遠端 commit 時誤判為 force push；改為提示先 `git fetch`

## [1.0.0-rc.2] - 2026-11-08

### Added

- 新增 JSON Schema 定義檔：`schema/v1.json`，提供完整的團隊策略檔（`.agreements.json` / `.agreementsrc`）結構約束與 28 條守則 ID 列舉，在 VS Code、Cursor 等現代 IDE 中提供原生自動補全與即時型別提示
- 新增 守則安全防篡改機制：團隊策略檔支援 `prohibit_disable_hooks: true`，在 `scripts/hook-guard.sh`、`scripts/hook-guard.py` 及 Git `pre-push` Universal Hook 中強制忽略 `AGREEMENTS_HOOKS_DISABLE=1`，確保核心安全防線不可被 Agent 或外部環境變數繞過
- 新增 一鍵策略檔生成功能：`scripts/doctor.sh --init-policy` 與 Claude Code 技能 `/agreements:doctor init-policy`，可將目前專案已安裝之守則自動固化導出為標準 `.agreements.json` 策略檔
- 擴充 Monorepo 多套件支援：`scripts/install.sh` 與 `scripts/doctor.sh` 支援向上層層尋找根目錄 `.agreements.json` 策略檔，讓 Monorepo 子目錄安裝時能自動繼承團隊全域策略
- 擴充 `/agreements:doctor` 技能指令：支援 `/agreements:doctor drift`（防漂移檢驗）與 `/agreements:doctor init-policy`（一鍵初始化策略檔）

### Fixed

- 修復 `skills/audit/SKILL.md` 過期守則引用：修正第 35 行 `core/test-invariants.md` 歷史路徑至現行標準路徑 `collaboration/test-integrity.md`

## [1.0.0-rc.1] - 2026-11-08

### Added

- 新增 規格化 Profile Schema v1：`.agreements-profile` 升級為 Schema v1，記錄 `schema_version`、安裝版本、安裝時各規則 SHA256 雜湊與團隊策略來源，實作舊版 v0 profile 自動平滑遷移機制
- 新增 團隊策略檔支援（Team Policy）：新增 `templates/agreements.json`，支援於專案根目錄配置 `.agreements.json` 或 `.agreementsrc` 強制鎖定團隊必備守則（`enforce_rules`），`install.sh` 與 setup 自動強制套用
- 新增 CI 守則防漂移檢驗（Anti-Drift）：`scripts/doctor.sh` 新增 `--check-drift` 模式，在 CI 流程中嚴格檢驗核心守則完整性與團隊強制守則安裝狀態，若遭手動篡改或缺失直接非零退出阻擋 PR 合併
- 新增 跨工具通用 Git Hook 防護網：`scripts/hook-guard.sh --install-git-hooks` 支援為專案安裝 Git `pre-push`（精準攔截非快進 force push）與 `pre-commit` 稽核防線，讓 Cursor、Windsurf、Copilot 與終端開發者同享防護
- 擴充 CI 測試矩陣：在 GitHub Actions 雙平台（Ubuntu 與 macOS）矩陣補齊 `tests/hook-guard.test.sh` 與防漂移、團隊策略單元測試

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
