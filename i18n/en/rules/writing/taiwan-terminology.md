---
source_sha256: 50d1dd1ec942bf42a3813103131c977831a49b59c28dd41203b74b189acfac95
category: writing
tier: optional
label: "Taiwan terminology"
summary: "When writing Chinese UI text and docs, avoid Mainland China terms (用戶→使用者, 默認→預設). Pick this only if the product's users are in Taiwan"
stack: zh-tw
incidents:
  - "Convention: the product's users are in Taiwan, and Mainland China terms make the product feel non-local (no single incident)"
last_reviewed: 2026-11-10
---

# Taiwan terminology (zh-TW): word choice when writing Traditional Chinese text

> Applies when you write Chinese for UI text, permission names, docs, and commit messages. When the product's users are in Taiwan, Mainland China terms make the product feel non-local.

## Common replacements <!-- 參考 -->

| Avoid | Use instead |
|------|------|
| 群發 | 大量寄送, or a context-specific name (e.g. "通知信") |
| 信息 | 訊息, 資訊 |
| 用戶 | 使用者 |
| 默認 | 預設 |
| 視頻 | 影片 |
| 數據 | 資料 ("數據" is fine in statistics contexts) |
| 優化 (UI copy) | 改善, 調整 (commit verbs may keep "優化") |
| 質量 | 品質 |
| 項目 (meaning "project") | 專案 |
| 文檔 | 文件 |
| 運行 | 執行 |
| 支持 (a feature) | 支援 |
| 程序 (meaning "program") | 程式 |
| 登錄 (meaning "log in") | 登入 |
| 批次 (meaning a one-off scheduled job) | 任務 |

## How <!-- 慣例 -->

- Check screen text, permission names, and role descriptions for new features against Taiwanese usage first.
- Code identifiers (classes, routes, tables) can deliberately stay unchanged; change only user-visible text, to avoid a large-scale refactor.
