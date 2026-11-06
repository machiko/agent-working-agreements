---
category: async
tier: optional
label: "異步、佇列與快取地雷"
summary: "跨語言通用異步事故：快取雪崩與擊穿、佇列毒藥訊息無窮重試、分佈式鎖未設租約死鎖、未受控併發扇出打爆下游、跨協程共享狀態競爭。只在碰到佇列、Worker、快取相關檔案時載入"
stack: async
paths:
  - "**/jobs/**"
  - "**/job/**"
  - "**/queues/**"
  - "**/queue/**"
  - "**/workers/**"
  - "**/worker/**"
  - "**/tasks/**"
  - "**/task/**"
  - "**/*redis*.*"
  - "**/*cache*.*"
---

# 異步、佇列與快取地雷

> 跨語言通用的背景工作、非同步任務、分散式鎖與快取事故。格式：症狀 → 根因 → 怎麼做。

## 快取雪崩與熱點擊穿 (Cache Stampede & Dogpiling)

- **症狀：** 高流量首頁或促銷活動期間，快取到期或重啟瞬間，後端資料庫 CPU 瞬間飆到 100%，連線池耗盡，整個服務全面掛掉。
- **根因：** 批量寫入的快取鍵使用了完全相同的過期時間（TTL），導致同一秒內全部失效；或是單一超熱門資料過期瞬間，數千個並行請求同時穿透快取打進資料庫重新計算。
- **怎麼做：**
  - 快取 TTL 必須加入隨機抖動（Jitter，例如 `base_ttl + rand(1, 300)` 秒），避免集體同時到期。
  - 熱點資料計算應採用互斥鎖防護（Mutex / SingleFlight 機制）或背景預先更新，保證同一時間只有一個 Worker 在重新載入資料庫，其他請求等候或降級返回舊快取（Stale-while-revalidate）。

## 佇列毒藥訊息無窮重試 (Poison Pill in Job Queue)

- **症狀：** 背景 Worker 數量全部佔滿且 CPU 狂飆，正常佇列累積數萬筆訊息無法消化，檢查日誌發現只有特定一兩筆資料引發例外且反覆重跑。
- **根因：** 任務失敗未設定重試上限（Max Tries）或退避策略（Backoff），遇到格式錯誤、遺失外鍵或無法復原的業務邏輯壞資料（毒藥訊息）時，Worker 不斷重新放回佇列（Re-queue）並秒級重跑。
- **怎麼做：**
  - 任何非同步任務一律明確配置最大重試次數（如 3 次）與指數退避時間（Exponential Backoff + Jitter）。
  - 超過重試上限時，強制移入死信佇列（Dead Letter Queue, DLQ），並記錄警報與原始 Payload，絕不可無窮重試阻塞主佇列。

## 分佈式鎖未設租約死鎖 (Distributed Lock Deadlocks)

- **症狀：** 某批定時排程或資源搶佔工作突然永久停止運作，重啟單一實體無效，必須手動進 Redis 清除特定 key 才能恢復。
- **根因：** 搶鎖時未設定過期時間（Lease / TTL），或是獲取鎖的程序在釋放前崩潰（OOM / 節點重啟 / 網路中斷）；另外釋放鎖時未核對鎖持有者 Token，誤刪了其他程序延長或重新取得的鎖。
- **怎麼做：**
  - 分布式鎖取得時必須原子性賦予過期租約（如 Redis `SET key value NX PX 30000`），絕不能使用無過期時間的鎖。
  - 釋放鎖必須比對 Unique Token（通常用 Lua 腳本確保只有持有者能釋放）。
  - 耗時較長之任務應使用鎖續約（Watchdog / Heartbeat）機制。

## 未受控併發扇出打爆下游 (Unbounded Concurrency Fan-out)

- **症狀：** 一個批次事件觸發後，程式使用 `Promise.all`、`go func()` 或非同步 Worker 瞬間並行發出數萬個 HTTP 請求或 DB 查詢，導致第三方 API 觸發 Rate Limit（429）封鎖，或自家資料庫連線池直接崩潰。
- **根因：** 對集合資料（陣列、列表）進行扇出並行處理時，未加上並發池（Concurrency Pool / Semaphore / Rate Limiter）限制。
- **怎麼做：**
  - 扇出並行操作必須顯式限制最大並行度（Concurrency Limit，例如 `p-limit`、固定 Worker Pool、Go Channel Semaphore 等，建議預設 5–10）。
  - 對外部 API 應配置配合服務商配額的限速器（Rate Limiter）或令牌桶（Token Bucket）。

## 跨協程/執行緒共用可變狀態競爭 (Shared Mutable State Race Conditions)

- **症狀：** 高並發下訂單計算金額偶發錯亂、計數器數字短少、多租戶請求出現別的用戶的 Session 或資料。
- **根因：** 在多執行緒或異步協程環境（如 Node.js 全域物件、Go 全域變數、Python 類別靜態變數、PHP 常駐 Worker 如 Octane/Swoole）中，共享了未加鎖的記憶體變數，或將單一請求上下文（Request Context）存放在跨請求共享的單例（Singleton）中。
- **怎麼做：**
  - 請求生命週期的狀態（User ID、DB Transaction、Tenant）一律透過參數或執行緒/協程隔離的 Context（如 Go `context.Context`、Node.js `AsyncLocalStorage`）傳遞。
  - 若必須共享可變狀態，必須透過不可變資料結構、原子操作（Atomic）、互斥鎖（Mutex）或專責的狀態管理 Actor 來存取。
