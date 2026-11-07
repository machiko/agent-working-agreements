---
name: review
description: Agent 守則自省審查技能：在提交變更或宣告任務完成前，對照守則逐條清查 Diff 並輸出 Markdown 審查報告。
argument-hint: "[--base 分支 | --commit hash | --staged]"
disable-model-invocation: true
---

# Agent 守則自省審查 (Self-Review)

比對當前程式碼變更與工作守則，主動攔截空 catch、機敏金鑰洩漏、過寬權限、被刪除的測試斷言與樣式 Purge 風險。

## 1. 執行審查腳本

```bash
if [ -f "./scripts/review.sh" ]; then
  REVIEW_BIN="./scripts/review.sh"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/review.sh" ]; then
  REVIEW_BIN="${CLAUDE_PLUGIN_ROOT}/scripts/review.sh"
else
  REVIEW_BIN="scripts/review.sh"
fi

bash "$REVIEW_BIN" "$@"
```

## 2. 判讀與處理結果

- **若輸出「✅ 完美通過」**：變更符合所有防禦守則，可安全向使用者回報並執行 commit / PR。
- **若輸出「⚠️ 通過但有警告」**：檢視警告原因（例如動態 Tailwind class 或測試 sleep），確認是否有不可避免之業務需求。
- **若輸出「❌ 未通過審核」**：必須修復標記為攔截之項目（如補齊 catch 內錯誤處理、移除敏感檔案等）方可交付。
- **回報時顯式標註**：依據 `collaboration/communication` 守則，在向使用者回報的結尾列出本次變更所命中的守則（格式：`🛡️ 命中守則：[類別/名稱] 具體採取的防禦或規範動作`）。
