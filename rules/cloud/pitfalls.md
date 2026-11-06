---
category: cloud
tier: optional
label: "雲原生、日誌與可觀測性地雷"
summary: "跨語言通用雲端與監控事故：高基數指標記憶體爆炸、結構化日誌洩漏未遮罩個資與Token、連線池未複用致Ephemeral Port耗盡、Presigned URL權限失控、循環健康檢查死鎖。只在碰觸雲端、日誌與監控檔案時載入"
stack: cloud
paths:
  - "**/k8s/**"
  - "**/helm/**"
  - "**/terraform/**"
  - "**/*logger*.*"
  - "**/*metric*.*"
  - "**/*telemetry*.*"
  - "**/*s3*.*"
  - "**/*storage*.*"
  - "**/*cloud*.*"
  - "**/*otel*.*"
---

# 雲原生、日誌與可觀測性地雷

> 跨語言通用的雲端服務、日誌、監控指標與微服務通訊事故。格式：症狀 → 根因 → 怎麼做。

## 高基數 (High Cardinality) 指標標籤拖垮監控系統

- **症狀：** 服務上線新版本後，Prometheus、Datadog 或 OpenTelemetry Collector 記憶體飆破數十 GB 甚至頻繁 OOM 重啟，Grafana 儀表板查詢超時，監控帳單暴增數倍。
- **根因：** 開發者在 Metric Label / Tag 中放入了高基數（動態且無限成長）的維度，例如 `user_id`、`order_id`、完整 URL 路徑（含 ID 查詢參數）或隨機 UUID。每個唯一組合都會在記憶體中建立獨立的時間序列（Time Series）。
- **怎麼做：**
  - Metric Tag / Label 嚴格限制在**有限的枚舉值**（如 HTTP Method、Status Code 區間 `2xx` / `4xx`、處理器名稱或 Service Name）。
  - 個別請求的詳細識別標籤（如 `user_id`、`trace_id`、`request_id`）一律放入 Trace Span Attribute 或結構化日誌，絕不可作為 Metric Tag。

## 結構化日誌洩漏未遮罩的 PII、Token 與請求 Header

- **症狀：** 安全審計或合規掃描發現 Kibana / Loki / CloudWatch 中充斥著使用者的明文信用卡號、密碼、Bearer Token、手機號碼或身分證字號，面臨嚴厲法規罰款與資安通報。
- **根因：** 為了除錯方便，Agent 在 Controller / Middleware 中加上了整包請求 Payload 或 Header 的日誌記錄（例如 `logger.info("Request received", { body: req.body, headers: req.headers })`），未預先過濾敏感鍵值。
- **怎麼做：**
  - 在日誌框架頂層全域配置遮罩器（Masker / Redactor），對 `password`, `token`, `authorization`, `credit_card`, `secret` 等敏感欄位強制以 `***` 遮蔽。
  - 記錄請求 Body 前顯式使用白名單過濾領域屬性，或使用專用的 DTO / Summary 物件，嚴禁在生產環境直接印出原始 Request Payload。

## 連線池未複用致暫時連接埠 (Ephemeral Port) 與 TIME_WAIT 耗盡

- **症狀：** 服務在高流量或定時排程跑數千次外部 HTTP / 微服務呼叫時，突然大量噴出 `connect: cannot assign requested address` 或連線超時，伺服器明明負載不高卻無法對外發出任何網路請求。
- **根因：** 每次呼叫外部 API 時都 `new HttpClient()`、`http.Client{}` 或建立新的資料庫連線，請求結束後連線進入 `TIME_WAIT` 狀態（通常需停留 60 秒至 2 分鐘）。高並發下作業系統分配給出站連線的本地連接埠（Ephemeral Ports，通常 3 萬至 6 萬個）迅速被耗盡。
- **怎麼做：**
  - HTTP Client、RPC Client 與 Redis/DB 連線物件一律作為單例（Singleton）或連線池管理，跨請求重複複用底層 TCP 連線（Keep-Alive）。
  - 合理配置連線池最大連線數（MaxIdleConns / MaxConnsPerHost）與連線存活時間，避免頻繁建立新連線。

## 雲端物件儲存 Presigned URL 未限縮權限與逾期時間

- **症狀：** 前端使用者取得上傳或下載連結後，連結被未經授權的第三方長期存取；或惡意使用者利用簽名 URL 上傳覆蓋了別人的核心資料檔案或巨大未知檔案塞爆儲存空間。
- **根因：** 後端產生 S3 / GCS Presigned URL 時，給予過長的有期時間（如 24 小時至數天），且在產生 PutObject 簽名時未限制 `Content-Length-Range`（檔案大小上限）與 `Content-Type`，亦未限制特定的路徑前綴。
- **怎麼做：**
  - Presigned URL 的有效期限建議設為最小合理時間（如上傳 5–15 分鐘、臨時檢視 5 分鐘）。
  - 產生上傳簽名時強制綁定檔案大小限制（Content-Length Policy）與 MIME Type 白名單，路徑必須包含隨機 UUID 或限定在專屬租戶目錄下。

## 分散式服務健康檢查循環相依造成死鎖 (Circular Healthcheck)

- **症狀：** Kubernetes 或叢集重啟期間，Service A 與 Service B 同時處於 CrashLoopBackOff 或 NotReady 狀態，兩個服務各自等待對方的健康端點變成 200 OK，形成死鎖無法復原。
- **根因：** 在深層健康檢查（Deep Readiness / Liveness Probe）中，將非必要的外部服務健康狀態作為本機就緒的先決條件。當整個叢集冷啟動時，彼此互相等待下游回應。
- **怎麼做：**
  - **Liveness Probe（存活檢查）：** 只檢查本機內部程序是否還活著（未 deadlock、記憶體正常），絕不可呼叫任何外部相依（資料庫、快取或其他微服務）。
  - **Readiness Probe（就緒檢查）：** 只檢查本機核心資源與必備的直接資料庫連線，對外部非核心第三方一律走軟性降級或異步重試，不可因外部未就緒而癱瘓本機啟動。
