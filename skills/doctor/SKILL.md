---
name: doctor
description: 診斷目前專案與環境之 Agent 守則健康度、安裝完整度、版本新鮮度與安全防線配置，支援自動修復。
argument-hint: "[fix]"
disable-model-invocation: true
---

# Agent 守則健康體檢診斷 (Doctor)

檢查本機與專案之守則安裝配置、版本新鮮度、Git pre-commit 守門機制與 CI 工作流就緒度，產出健康評分與修復指引，可一鍵自動修復。

## 1. 執行體檢腳本

```bash
if [ -f "./scripts/doctor.sh" ]; then
  DOCTOR_BIN="./scripts/doctor.sh"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh" ]; then
  DOCTOR_BIN="${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
else
  DOCTOR_BIN="scripts/doctor.sh"
fi

if [ "$1" = "fix" ] || [ "$1" = "--fix" ]; then
  bash "$DOCTOR_BIN" --fix
else
  bash "$DOCTOR_BIN"
fi
```

## 2. 判讀結果與建議

- **若得分為 100 分**：向開發者回報專案守則配置健全，防線完備。
- **若有 [WARN] 項目**：
  - 提示可直接執行 `/agreements:doctor fix` 自動修復所有缺失。
  - 若提示未安裝守則：引導執行 `/agreements:setup` 或 `/agreements:doctor fix`。
  - 若提示未安裝 Git hook：引導執行 `scripts/audit.sh --install-hook` 或 `/agreements:doctor fix`。
  - 若提示未配置 CI：若專案託管在 GitHub，可引導執行 `scripts/install.sh --ci`；若專案不在 GitHub 或為本機開發，引導使用 `scripts/audit.sh --install-hook`。
  - 若提示版本過舊：引導執行 `/agreements:setup` 重新同步。
