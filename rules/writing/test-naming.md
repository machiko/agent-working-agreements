---
category: writing
tier: core
---

# 測試命名

## 方法名一律用英文，母語寫在 docblock

```php
/** 服務類型不支援批次 API 時，回 422 並提示改用單筆操作 */
public function test_batch_fetch_returns_422_when_type_does_not_support_batch(): void
```

- 方法名要描述行為：`test_<動作>_<結果>_when_<條件>`。
- 中文（或其他母語）只寫在 docblock 或註解裡，交代情境與預期。
- 既有的非英文方法名是歷史遺留，改既有測試時不要順手改名（那超出範圍）。但自己新增的測試一定要用英文。

**為什麼：** 同一天被糾正兩次。非英文方法名在部分工具、CI 報表、終端機的顯示會出問題，也會讓新的測試延續舊的寫法。

## 測試結構

照 Arrange、Act、Assert 三段寫，每段之間空一行。一個測試只驗證一件行為。
