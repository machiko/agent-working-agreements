---
category: database
tier: optional
label: "資料庫與 ORM 地雷"
summary: "跨語言通用資料庫事故：線上鎖表、未做冪等的遷移、N+1 查詢暴衝、軟刪除髒讀、金額浮點數精度。只在碰到資料庫相關檔案時載入"
stack: database
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/migration/**"
  - "**/schema/**"
  - "**/entities/**"
  - "**/models/**"
  - "**/prisma/**"
  - "**/alembic/**"
incidents:
  - "migration 中途失敗後重跑報錯，部署流程卡死"
  - "大表直接加欄位觸發排他鎖，正式環境 API 全面逾時"
  - "金額用浮點數計算，對帳出現大量小額差異"
last_reviewed: 2026-11-10
---

# 資料庫與 ORM 地雷

> 跨語言與 ORM 的真實資料庫事故（適用 PostgreSQL, MySQL, SQLite, Prisma, SQLAlchemy, GORM 等）。格式：症狀 → 根因 → 怎麼做。

## 遷移腳本缺乏冪等性 (Non-Idempotent Migrations)

- **症狀：** 部署時 migration 跑到一半因網路中斷或語法錯誤中途失敗，修復後重跑噴出 `Table already exists` 或 `Duplicate column name`，自動部署流程全面鎖死，必須手動進正式環境清理結構。
- **根因：** DDL 腳本未做防禦性存在檢查（未加 `IF NOT EXISTS` / `IF EXISTS`），且部分資料庫引擎或語句不支援跨 DDL 的交易回滾。
- **怎麼做：** 遷移中的建立與修改欄位一律使用安全防禦語法（或 ORM 的 `hasTable` / `hasColumn` 守衛）；每個 migration 必須成對提供能乾淨還原的 rollback/down 邏輯；禁止在同一個 migration 內混入大量結構修改與長時間的資料回填。

## 生產環境大表加欄位造成排他鎖 (Exclusive Lock)

- **症狀：** 部署一執行 migration，正式環境請求大量堆積、連線池被打滿、資料庫 CPU 飆高，所有涉及該表的 API 陸續逾時崩潰。
- **根因：** 在百萬級以上大表直接執行 `ALTER TABLE ... ADD COLUMN ... DEFAULT 'foo'`，在未支援或未指定線上 DDL 機制時觸發全表複製重寫，咬住排他鎖阻止所有並行的讀寫。
- **怎麼做：** 大表加欄位優先允許 `NULL` 且不帶非 null 的固定預設值（或使用資料庫原生 Instant DDL 特性）；建立索引一律使用非阻塞語法（如 PostgreSQL 的 `CONCURRENTLY`，MySQL 的 `ONLINE DDL` 或 `gh-ost` / `pt-online-schema-change`）；百萬筆以上的資料更新收斂至排程分批（Chunking）執行。

## ORM 隱形 N+1 查詢與記憶體暴衝

- **症狀：** 本地開發與單元測試幾筆假資料跑得極快，但上線後一碰真實資料列表或匯出，SQL 查詢數萬次、資料庫瞬間被敲昏，後端 process 觸發 OOM 崩潰。
- **根因：** 在迴圈中直接存取關聯物件屬性（如 `order.customer.name`），觸發 ORM 的 Lazy Loading（延遲載入），導致每一筆主資料都額外送出一筆獨立查詢。
- **怎麼做：** 列表與批次查詢一律顯式預先載入（Eager Loading，如 `with()`、`select_related`、`include`）；code review 時在迴圈內存取關聯物件一律當作性能紅旗；可在測試環境開啟 ORM 嚴格模式（如禁止延遲載入）提早攔截。

## 軟刪除 (Soft Delete) 關聯髒讀洩漏

- **症狀：** 報表數字對不齊、統計頁面出現已被停權或刪除的使用者、原生 SQL 跨表計算時把已作廢的項目計入營收。
- **根因：** ORM 通常只會自動為主要查詢 Model 加上 `deleted_at IS NULL` 條件；一旦改寫原生 SQL、複雜 JOIN 或 Subquery，軟刪除過濾條件極易被漏掉。
- **怎麼做：** 撰寫原生 SQL 或多表 JOIN 報表時，逐表檢查是否包含 `deleted_at IS NULL`；統計金額與數量必須編寫包含「關聯項目已軟刪除」情境的邊界測試。

## 浮點數計算金額之精度災難

- **症狀：** 每筆訂單折算後差 0.01 元、退款總額與付款總額不符，系統運作數週後財務對帳發現大量無從查起的小額差額。
- **根因：** 使用 IEEE 754 浮點數（`float`, `double`）儲存或運算金額，二進位轉換的捨入誤差在乘除累加中被放大。
- **怎麼做：** 資料庫中金額一律儲存為定點數 `DECIMAL(16, 4)` 或以最小貨幣單位儲存為整數（如以「分」為單位用 `BIGINT`）；程式語言中計算金額一律使用高精度數值庫（如 `Decimal`、`BigNumber`），嚴禁直接以浮點數進行金錢計算。
