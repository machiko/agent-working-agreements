---
category: security
tier: optional
label: "多租戶與匯出資料隔離"
summary: "防範 BOLA / IDOR 授權漏洞：列表、統計報表與非同步匯出必須強制過濾租戶/用戶範圍，背景任務必須顯式傳遞授權上下文"
incidents:
  - "報表與匯出功能漏套租戶範圍，可讀到其他租戶資料（BOLA／IDOR）"
  - "背景 Worker 沒有請求上下文，以為能取得目前登入者而越權"
last_reviewed: 2026-11-10
---

# 多租戶與匯出資料權限隔離 (Tenant Isolation & Data Scope)

## 1. 列表、統計報表與資料匯出強制綁定租戶範圍（Enforce Tenant Scope Across All Exits）

任何具備多租戶（Multi-tenant）、組織隔離或權限角色的系統，**所有列表查詢、統計報表與批次資料匯出（CSV/Excel/JSON），都必須強制套用租戶或用戶範圍過濾**。

**為什麼：**
這是 OWASP API Security Top 10 首要問題（BOLA / IDOR）。開發者或 AI 在開發前端清單時通常記得套用目前租戶 Scope，但當需求涉及「資料匯出」或「複雜圖表統計」時，常為了效能或圖方便使用 Raw SQL、獨立的匯出服務或第三方報表工具，從而繞過了框架的 Model Scope，導致低權限用戶甚至外部競爭對手能直接匯出全系統其他租戶的機敏資料。

**怎麼做：**
- **匯出服務只接收已過濾之資料**：匯出類別只負責將已完成權限過濾的資料集轉為檔案，嚴禁匯出類別自行查全表或繞過授權層。
- **Raw SQL 必須強制包含隔離條件**：涉及原生 SQL 時，強制檢查 WHERE 條件必須包含租戶或用戶外鍵（如 `tenant_id`、`org_id` 或 `user_id`），不可因優化查詢而省略。
- **列表授權與明細授權分離**：能在清單看見摘要，不等於具備編輯或查看完整 PII 明細的權限，兩者需獨立驗證。

---

## 2. 非同步背景任務必須顯式傳遞授權上下文（Explicit Tenant Context in Async Jobs）

涉及產生報表、發送批次通知或匯出檔案的非同步佇列任務（Workers / Jobs），必須在派發當下將授權與租戶過濾條件顯式序列化存入任務參數中。

**為什麼：**
背景 Worker 執行於獨立的 CLI 行程，**沒有 HTTP Request 上下文，也沒有目前登入者的 Session / Token**。AI Agent 常誤以為 Worker 能自動解析「當前使用者」，或在 Worker 內部退回以全系統最高權限（System Scope）重新查詢，引發嚴重跨租戶資料串線與外洩。

**怎麼做：**
- 在控制器（Controller / Handler）派發 Job 之前，明確取出當前使用者的 `tenant_id`、權限範圍與過濾條件，打包為可序列化的參數傳給 Job。
- Worker 收到參數後，強制將所有查詢限制在該 `tenant_id` 內執行，禁止以空條件全表掃描。
- Worker 程式碼更新後，必須透過容器或行程重啟（如 `systemctl restart` 或容器重建）確保完全載入最新程式碼。

---

## 3. 跨環境權限使用穩定字串代碼，禁止硬編碼數字 ID（Use Stable Slugs Over Auto-increment IDs）

在業務邏輯或 SQL 中判斷角色、權限或系統常數時，一律使用穩定的英文識別字串（Slug / Code），禁止寫死資料庫自動遞增的數字主鍵。

**為什麼：**
開發、測試、預發與生產環境中，自動遞增的 Primary Key（如 `role_id = 3`）在不同資料庫實例中的順序與 ID 通常不一致。AI Agent 習慣在程式碼中寫死數字 ID，導致本地測試通過，推至生產環境卻將管理員權限誤判給一般用戶。

**怎麼做：**
- 角色與權限使用字串識別碼（如 `role: 'finance_manager'`、`permission: 'export_invoices'`）。
- 嚴禁在業務邏輯中出現 `if (user.role_id === 2)` 等魔法數字。
