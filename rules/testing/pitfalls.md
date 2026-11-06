---
category: testing
tier: optional
label: "測試與 Mock 地雷"
summary: "防範 Mock 全域外洩未重置、靜態 sleep 延遲導致 Flaky 測試、整合測試未回滾資料庫髒污、過度 Mock 私有實作細節與非決定性斷言。"
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/test/**"
---

# 測試與 Mock 地雷

> 跨語言通用的測試事故：Mock 外洩、靜態延遲、資料庫髒污、過度 Mock 與非決定性斷言。

### 1. Mock 狀態跨測試外洩污染（Mock State Leakage & Missing Reset）

在測試中使用 `jest.spyOn()`、`vi.mock()` 或 `unittest.mock.patch` 時，必須在每個 test case 結束後確實清理還原，嚴禁殘留自訂實作或計數。

**為什麼：**
AI Agent 常為了解決當前測試而臨時 mock 全域物件（如 `fetch`、`axios` 或系統服務），卻未在 `afterEach` 或框架設定中清理。單獨跑該測試時顯示綠燈，但在 CI 平行執行整個測試套件時，污染殘留導致其他測試隨機崩潰（Flaky Tests），排查極其困難。

**怎麼做：**
- 在測試框架配置中啟用自動還原（如 Vitest `restoreMocks: true`、Jest `restoreMocks: true`）。
- 使用 `spyOn` 必須在 `afterEach` 中調用 `mockRestore()` 或 `vi.restoreAllMocks()`。
- 區分 `mockClear()`（僅清空呼叫次數）、`mockReset()`（清空次數與實作）與 `mockRestore()`（還原至原始實作）。

```typescript
// ❌ 錯誤：mock 了全域物件，但測試結束後未還原，污染其他測試
it('fetches user data', async () => {
  vi.spyOn(global, 'fetch').mockResolvedValue(new Response('{"id": 1}'));
  const res = await getUser(1);
  expect(res.id).toBe(1);
});

// ✅ 正確：測試結束後確實還原原始方法
afterEach(() => {
  vi.restoreAllMocks();
});
```

---

### 2. 禁止在測試中使用靜態硬編碼延遲（Static `sleep` / `setTimeout`）

測試非同步流程、佇列處理或事件回呼時，嚴禁使用 `sleep(1000)`、`time.sleep()` 等靜態等待。

**為什麼：**
靜態 sleep 延遲在開發者本機上通常夠快能過，但在 CI 伺服器高負載或 CPU 降頻時，背景任務尚未完成測試就已逾時斷言；同時，累積多個 sleep 會讓原本幾秒鐘的測試套件膨脹至數十分鐘。

**怎麼做：**
- 使用測試框架提供的條件輪詢等待（如 Vitest/Testing Library 的 `waitFor(() => expect(...))`、Playwright 的 `waitForResponse()` / `waitForSelector()`）。
- 需測試時間推移的邏輯時，使用虛擬時鐘（Fake Timers: `vi.useFakeTimers()` / `jest.useFakeTimers()` / `freeze_gun`）快進時間，而非真實等待。

```typescript
// ❌ 錯誤：硬睡 1 秒等待非同步回呼
await new Promise(r => setTimeout(r, 1000));
expect(status.value).toBe('ready');

// ✅ 正確：使用條件輪詢等待，條件滿足立即通過，超時才報錯
await waitFor(() => {
  expect(status.value).toBe('ready');
}, { timeout: 2000 });
```

---

### 3. 整合測試必須隔離資料庫狀態（DB Transaction Rollback）

任何會向測試資料庫寫入資料（INSERT/UPDATE/DELETE）的整合測試，必須在測試結尾自動回滾交易或使用隨機隔離環境，禁止留下幽靈資料。

**為什麼：**
AI Agent 產生的測試腳本常直接將測試用戶或訂單寫進實體資料庫，未包覆交易回滾。當多個測試循序或並行執行時，後面的測試查詢到前面的髒資料，造成測試偶發性失控。

**怎麼做：**
- 一律啟用測試框架的交易回滾機制（如 Laravel `use RefreshDatabase;`、Django `TestCase`、Spring `@Transactional`）。
- 若為不支援交易的資料庫或多連線情境，在 `beforeEach` 或 `afterEach` 明確截斷（Truncate）相關表格，或透過隨機 UUID 租戶 ID 進行邏輯隔離。

---

### 4. 禁止過度 Mock 待測物件的私有實作細節（Over-mocking Implementation Details）

測試應聚焦於待測單元（System Under Test）的公共 API 契約與邊界副作用，不得為了通過測試而 Mock 待測類別自身的內部私有方法。

**為什麼：**
AI Agent 為了讓測試變綠，經常把被測物件內部的 3 個私有函式全部替換成假資料。這導致測試測的完全是 Mock 本身，一旦未來內部重構，測試依舊全綠，但生產環境直接故障崩潰。

**怎麼做：**
- **只 Mock 外部世界**：只 Mock 第三方 HTTP API、外部資料庫連線、雲端儲存 SDK 等邊界依賴。
- 待測單元內部應當作黑盒子，透過輸入驗證輸出狀態。若內部邏輯複雜到需要分開測試，應重構抽出獨立的新服務，而非 Mock 私有方法。

---

### 5. 消除時間與隨機性的非決定性斷言（Non-Deterministic Tests）

涉及時間、日期或隨機亂數的測試，必須固定基準時間與亂數種子，嚴禁直接斷言動態的 `new Date()` 或 `Math.random()`。

**為什麼：**
使用真實系統時間的測試常在「跨月最後一天」、「跨年瞬間」或「閏年 2 月 29 日」突然爆開；未固定種子的隨機演算法在特定邊界亂數下拋出異常，難以在本機重現。

**怎麼做：**
- 測試前固定系統基準時間（如 `vi.setSystemTime(new Date('2026-01-01 12:00:00'))`）。
- 隨機亂數使用確定性擬隨機產生器並傳入固定 Seed。
