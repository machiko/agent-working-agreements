---
name: audit
description: 執行 agent 工作守則合規稽核，掃描 Git staged、diff 或特定 commit 是否違反核心守則。
argument-hint: "[--staged | --diff | --commit <hash> | --install-hook]"
disable-model-invocation: true
---

# 執行 Agent 守則合規稽核 (Audit)

執行主動合規稽核，檢查當前工作區或提交內容是否踩中靜默吞錯誤、弱化測試、提交機敏檔、破壞 Tailwind 或直接在主分支修改等違規。

稽核腳本優先使用工作區或 Plugin 內的腳本：
```bash
if [ -f "./scripts/audit.sh" ]; then
  AUDIT_BIN="./scripts/audit.sh"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh" ]; then
  AUDIT_BIN="${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh"
else
  AUDIT_BIN="scripts/audit.sh"
fi
```

## 1. 執行檢查

依據使用者的參數呼叫 `$AUDIT_BIN`：
- 無參數或傳入 `--staged`：`bash "$AUDIT_BIN" --staged`（檢查 Git 暫存區）
- 傳入 `--diff`：`bash "$AUDIT_BIN" --diff`（檢查尚未暫存的修改）
- 傳入 `--commit <hash>`：`bash "$AUDIT_BIN" --commit <hash>`（檢查特定提交，如 HEAD）
- 傳入 `--install-hook`：`bash "$AUDIT_BIN" --install-hook`（安裝 Git pre-commit hook）

## 2. 判讀稽核結果

- **若稽核失敗 (FAIL > 0)：**
  1. 列出違規檔案與違規項目。
  2. 標註違反的具體守則與危害（例如：`api/pitfalls.md` 靜默吞噬例外、`security/sast-safe-patterns.md` 洩漏機敏資訊、`core/test-invariants.md` 弱化測試）。
  3. 提供具體的修復方針，提醒不要使用空 catch 或刪除斷言。

- **若稽核通過 (PASS)：**
  簡短回報所有檢查通過，變更符合 Agent 工作守則，可以安心建立 commit 或發起 Pull Request。
