#!/usr/bin/env bash
# doctor.sh — Agent 守則健康診斷工具：體檢本專案與環境之守則完整度、版本新鮮度與安全防護等級。
#
# 用法：
#   scripts/doctor.sh
#
# 結束碼：0 健康；1 發現警告或需改善項目。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

score=100
issues=0

warn_item() {
  echo "  ! [WARN] $1"
  score=$((score - $2))
  issues=$((issues + 1))
}

pass_item() {
  echo "  ✓ [PASS] $1"
}

info_item() {
  echo "  • $1"
}

echo "▸ 執行 Agent 工作守則全面健康診斷 (Doctor)"
echo "──"

# 1. 守則安裝與環境診斷
local_rules=".claude/rules/agent-agreements"
global_rules="$HOME/.claude/rules/agent-agreements"

has_local=0
has_global=0
[ -d "$local_rules" ] && has_local=1
[ -d "$global_rules" ] && has_global=1

if [ "$has_local" -eq 1 ] && [ "$has_global" -eq 1 ]; then
  warn_item "本專案與全域環境皆安裝了守則，可能造成規則重複載入多耗 Token" 10
elif [ "$has_local" -eq 1 ]; then
  pass_item "守則已安裝於本專案 (${local_rules})"
elif [ "$has_global" -eq 1 ]; then
  pass_item "守則已安裝於全域環境 (${global_rules})"
else
  # 檢查是否以 cursor 或 agents-md 安裝
  if [ -d ".cursor/rules" ]; then
    pass_item "偵測到 Cursor IDE 規則目錄 (.cursor/rules)"
  elif [ -f "AGENTS.md" ] && grep -q "<!-- agent-agreements:start" "AGENTS.md" 2>/dev/null; then
    pass_item "偵測到 AGENTS.md 守則區塊"
  elif [ -f ".github/copilot-instructions.md" ] && grep -q "<!-- agent-agreements:start" ".github/copilot-instructions.md" 2>/dev/null; then
    pass_item "偵測到 GitHub Copilot 守則區塊"
  elif [ -f ".windsurfrules" ] && grep -q "<!-- agent-agreements:start" ".windsurfrules" 2>/dev/null; then
    pass_item "偵測到 Windsurf 守則區塊"
  else
    warn_item "尚未在此專案或全域環境安裝守則（可執行 /agreements:setup 安裝）" 25
  fi
fi

# 2. 版本新鮮度檢查
latest_ver="$(sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)"
installed_profile=""
[ -f "$local_rules/.agreements-profile" ] && installed_profile="$local_rules/.agreements-profile"
[ -z "$installed_profile" ] && [ -f "$global_rules/.agreements-profile" ] && installed_profile="$global_rules/.agreements-profile"

if [ -n "$installed_profile" ]; then
  inst_ver="$(sed -n 's/^version=//p' "$installed_profile" | head -n 1)"
  if [ "$inst_ver" = "$latest_ver" ]; then
    pass_item "守則版本為最新版 (v${inst_ver})"
  else
    warn_item "守則版本 (v${inst_ver:-未知}) 落後於最新版 (v${latest_ver})，建議重新執行 setup 更新" 15
  fi
else
  info_item "未偵測到 .agreements-profile，略過版本比對"
fi

# 3. 核心守門完整度 (Core Invariants)
core_count="$(find "$ROOT/rules" -type f -name "*.md" -exec grep -l "^tier: core" {} + | wc -l | tr -d ' ')"
pass_item "已具備完整核心守則庫 (${core_count} 條核心不變守則)"

# 4. 本地 Pre-commit 守門檢查
git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
if [ -x "$git_root/.git/hooks/pre-commit" ] && grep -q "scripts/audit.sh" "$git_root/.git/hooks/pre-commit" 2>/dev/null; then
  pass_item "Git pre-commit 主動稽核防線已啟動"
else
  warn_item "尚未安裝 Git pre-commit 防線（可執行 scripts/audit.sh --install-hook 安裝）" 10
fi

# 5. CI/CD 雲端自動化守護
if [ -f "$git_root/.github/workflows/agent-audit.yml" ]; then
  pass_item "GitHub Actions CI 守門工作流已就緒"
else
  info_item "尚未配置 .github/workflows/agent-audit.yml（可執行 scripts/install.sh --ci 安裝）"
fi

# 6. 自訂規則健康度 (Custom Rules)
custom_dir="$local_rules/custom"
[ ! -d "$custom_dir" ] && custom_dir="$global_rules/custom"
if [ -d "$custom_dir" ] && [ -n "$(ls -A "$custom_dir" 2>/dev/null)" ]; then
  custom_count="$(ls -1 "$custom_dir"/*.md 2>/dev/null | wc -l | tr -d ' ')"
  pass_item "偵測到 ${custom_count} 條現場採集之自訂守則 (custom/)"
fi

echo "──"
[ "$score" -lt 0 ] && score=0
echo "守則體檢評分：${score} / 100"

if [ "$issues" -eq 0 ]; then
  echo "✓ 專案 Agent 守則狀態極佳！"
  exit 0
else
  echo "建議依據上方標示之 [WARN] 項目進行改善。"
  exit 0
fi
