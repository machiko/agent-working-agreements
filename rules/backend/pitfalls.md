---
category: backend
tier: optional
label: "Web 後端與應用服務地雷"
summary: "跨語言通用後端事故：環境變數空值覆蓋預設值、dev 測試依賴洩漏至正式環境、建構階段觸發密鑰注入失敗、匯出與大型運算記憶體 OOM、非標準主鍵存取。只在碰到後端檔時載入"
stack: backend
paths:
  - "**/*.php"
  - "**/*.py"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.java"
  - "**/*.rb"
  - "**/*.rs"
  - "composer.json"
  - "package.json"
  - "pyproject.toml"
  - "requirements.txt"
  - "go.mod"
  - "Cargo.toml"
  - "pom.xml"
incidents:
  - "環境變數設成空字串，預設值沒有生效，功能在特定環境悄悄停擺"
  - "開發依賴洩漏到正式環境的程式路徑，上線後找不到模組"
  - "大量匯出一次載入全部資料，程序被 OOM Killer 終止"
last_reviewed: 2026-11-10
---

# Web 後端與應用服務地雷

> 適用於 Node.js、Python、Go、PHP、Java 等現代 Web 後端與微服務架構。格式：症狀 → 根因 → 怎麼做。

## 環境變數留空覆蓋預設值 (Empty String Overrides Default)

- **症狀：** 服務限額歸零、外部連線端點變成空字串、或是某個關鍵功能在特定環境悄悄停擺，且未拋出缺少設定的錯誤。
- **根因：** 設定檔使用 `env('KEY', 'default_val')`、Node `process.env.KEY || 'default_val'` 或 Python `os.getenv('KEY', 'default_val')` 時，若 `.env` 或環境變數中定義了 `KEY=`（值為空字串 `""`），系統會認定「該變數存在」並返回空字串，而不是退回預設值。自動化腳本如果以空值填補缺少的 key，會全面覆蓋掉安全預設值。
- **怎麼做：**
  - 在配置載入層對空字串與未定義做嚴格防護（例如 `process.env.KEY?.trim() || 'default'`，或設定 schema 驗證工具如 Zod / Pydantic）。
  - `.env.example` 的每個 key 都填可以直接啟動的有效範例值，不留空；維護環境變數的腳本預設帶入範例值。

## 本機/開發依賴洩漏至正式環境 (Dev-dependencies Leakage)

- **症狀：** 生產環境在某個未涵蓋的異常分支突然噴出 `ClassNotFoundException`、`Cannot find module 'faker'` 或函式未定義錯誤；或在特定情況下使用者看見了 Mock 假資料。
- **根因：** 開發者使用了測試或本地假資料工具（如 Faker、Mock 庫、除錯 Toolbar），並在業務代碼的 `default` 分支退回產生假資料。CI 或本地測試環境通常安裝了全套依賴，但在生產環境以 `--production` 或 `--no-dev` 安裝時，這些模組並不存在。
- **怎麼做：**
  - 生產環境業務路徑嚴禁引用 dev-dependencies。
  - 任何產生 mock 或假資料的邏輯，一律以嚴格的環境檢查（如 `process.env.NODE_ENV !== 'production'`）包覆；業務常規分支遇到未匹配狀況必須拋出明確錯誤，絕不可靜默退回假資料。

## 建構或預編譯階段觸發未守護的外部密鑰注入

- **症狀：** 在 Dockerfile 執行 `npm run build`、`composer dump-autoload` 或靜態依賴掃描時，建構突然中斷，報錯缺少資料庫連線字串或第三方 API Key。
- **根因：** 框架在建構、指令註冊或依賴注入（DI Container）掃描時，會實例化相關模組或類別。若在模組頂層（Top-level）或建構子中直接要求必須讀取生產密鑰或嘗試建立遠端連線，建構環境（通常沒有掛載生產密鑰）便會直接崩潰。
- **怎麼做：** 需要遠端連線或敏感密鑰的 Service，一律使用延遲初始化（Lazy Resolution）或在實際業務呼叫（如 `handle()`、`execute()`）時才取得連線，不可在模組載入或建構子階段直接阻斷。

## 大型運算或匯出未做串流導致記憶體暴衝 (OOM)

- **症狀：** 單筆測試與小資料測試皆正常，整套測試跑至一半或生產環境有大量報表匯出時，程序無預警被作業系統 OOM Killer 強制終止。
- **根因：** 處理報表匯出（Excel / CSV / PDF）或批次資料時，一次性將所有資料全數載入記憶體陣列，導致 Heap 記憶體瞬間被吃滿。
- **怎麼做：**
  - 批量資料一律採用分塊處理（Chunking / Paging）或串流（Streaming / Generator / Cursor）逐筆輸出。
  - 測試大型匯出時，測試重點應放在邏輯轉換與 Header 契約，避免在 Feature 測試中無限制生成巨大實體陣列。

## ORM 存取不存在屬性或非標準主鍵造成資料覆蓋

- **症狀：** 多位使用者的資料快取或記錄互相覆蓋，但單人測試無法重現。
- **根因：** 資料庫歷史表格主鍵非標準（如 `user_pk` 而非 `id`），ORM 存取不存在的屬性（如 `model.id`）不報錯而靜默回傳 `undefined` / `null`。結果在組裝快取 key（如 `user:${model.id}`）時，所有人共用同一組 key。
- **怎麼做：** 組裝關鍵標識（Cache key、Log context、審計記錄）時，一律使用 ORM 內建主鍵方法（如 `getKey()`）或顯式具名欄位，嚴格防範對不存在屬性的靜默存取。
