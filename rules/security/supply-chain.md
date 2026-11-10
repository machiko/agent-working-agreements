---
category: security
tier: optional
label: "供應鏈安全與依賴地雷"
summary: "AI 協作高危資安事故：套件幻覺與依賴投毒、浮動版本與Lockfile失步、過度寬鬆Wildcard授權、多階段映像建構暫存密鑰殘留、偽造測試憑證洩漏。只在碰觸套件設定與安全權限時載入"
stack: security
paths:
  - "package.json"
  - "package-lock.json"
  - "yarn.lock"
  - "pnpm-lock.yaml"
  - "composer.json"
  - "composer.lock"
  - "requirements.txt"
  - "pyproject.toml"
  - "poetry.lock"
  - "go.mod"
  - "go.sum"
  - "Cargo.toml"
  - "Cargo.lock"
  - "**/Dockerfile*"
  - "**/*.tf"
  - "**/*policy*.json"
  - "**/*rbac*.yaml"
incidents:
  - "Agent 安裝 LLM 幻覺出的套件名稱，裝到被搶註投毒的惡意套件"
  - "改了依賴卻沒同步 lock 檔，部署時拉到破壞性更新"
  - "私有 Token 殘留在映像歷史層，推送後被掃出"
last_reviewed: 2026-11-10
enforced_by:
  - audit:wildcard-permissions
---

# 供應鏈安全與依賴地雷

> AI Agent 協作開發時易引發的軟體供應鏈、依賴套件與權限外洩事故。格式：症狀 → 根因 → 怎麼做。

## 套件名稱幻覺與搶註投毒 (Package Hallucination & Typosquatting)

- **症狀：** Agent 為了實作某個功能，自動執行指令安裝了某個看起來很直觀的第三方開源庫（如 `npm i date-fns-utils`），CI 或正式環境執行時伺服器突然向未知外部 IP 建立反向 Shell，或竊取環境變數密鑰。
- **根因：** LLM 在給出解決方案時經常幻覺出「語意上看似存在但官方從未發布過」的套件名稱。惡意攻擊者長期在 NPM、PyPI、Packagist 監控此類常見幻覺名稱並進行搶先註冊（Typosquatting），植入木馬代碼。
- **怎麼做：**
  - 嚴禁 Agent 未經人類審查直接執行安裝全新未知的第三方依賴。
  - 引入任何新套件前，必須人工核對官方首頁、GitHub Star 數、近期發布頻率與安全通報（如 Snyk、Socket.dev）。

## 浮動版本與 Lockfile 失步 (Lockfile Drift)

- **症狀：** 開發者本地執行測試綠燈，隔天生產環境部署時突然全線崩潰；或同一份代碼在不同機器上安裝時拉取到了破壞性更新的次要版本。
- **根因：** Agent 在新增或更新套件時，直接編輯了 `package.json`（使用了 `^` 或 `~` 萬用字元）卻未同步產生或更新 lock 檔（`package-lock.json`、`pnpm-lock.yaml`、`composer.lock`），或使用 `--no-lock` 忽略了依賴鎖定。
- **怎麼做：**
  - 生產環境部署與 CI 管線強制使用嚴格鎖定安裝模式（如 `npm ci`、`pnpm install --frozen-lockfile`、`composer install --locked`）。
  - 所有依賴變更 PR 必須同時提交對應的 lockfile 更新，不得留空。

## 過度寬鬆授權 (Over-privileged Wildcard IAM & RBAC)

- **症狀：** 某個僅需讀取公開資料的微服務遭 SSRF 滲透後，攻擊者輕易獲取了刪除全庫資料表、變更安全組規則或讀取生產機敏密鑰的頂級權限。
- **根因：** Agent 在撰寫 AWS IAM Policy、GCP Role、Kubernetes ClusterRole 時，為了「確保程式一定能跑過且不報 403」，使用了萬用字元萬靈丹（如 `Action: "*"`、`Resource: "*"`、`rules: [{ verbs: ["*"], resources: ["*"] }]`）。
- **怎麼做：**
  - 嚴格遵守最小權限原則（Least Privilege），每個應用或 ServiceAccount 僅授權其業務所需的最小動作集合（如 `s3:GetObject` 限定特定 Bucket ARN）。
  - 嚴禁在生產環境與 CI Runner 配置全域 `*` 萬用授權。

## 多階段容器建構暫存密鑰殘留 (Build-time Secrets Leaking into Image)

- **症狀：** 專案映像推送到 Docker Hub 或外部 Container Registry 後，資安掃描在映像歷史層（Image History Layer）中挖出了公司的私有 GitHub Token、NPM 憑證或內部 SSH 私鑰。
- **根因：** 在 Dockerfile 內部使用 `ARG GITHUB_TOKEN` 或 `ENV TOKEN` 下載私有依賴，雖然在後續步驟 `rm` 刪除，但 Docker 的分層儲存機制依然將密鑰完整固化在先前的唯讀層中。
- **怎麼做：**
  - 建構需私有認證之映像時，一律使用 Docker BuildKit 的安全掛載機制（如 `RUN --mount=type=secret,id=token ...`），密鑰不會寫入映像層。
  - 或在獨立的 Builder 階段完成依賴編譯，最終階段（Production Runner）僅複製編譯後之純產物，絕不引入建構期憑證。

## 測試環境混入未受控的偽造憑證或明文端點

- **症狀：** 在測試程式碼或 Mock 檔案中寫入了「看似測試用但其實曾於內部環境有效」的連線字串、預設帳號密碼或自簽憑證，隨開源或協作外洩造成內部網路曝險。
- **根因：** Agent 在編寫測試時，將真實本地環境的連線資訊隨手複製貼進測試資料庫或種子資料（Seeders）中。
- **怎麼做：**
  - 測試設定檔中的密鑰一律使用顯而易見的虛擬佔位符（如 `secret_mock_for_test_only`）。
  - 透過主動守護腳本定期掃描測試目錄，攔截真實格式的金鑰與內部專用主機名。
