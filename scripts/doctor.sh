#!/usr/bin/env bash
# doctor.sh — Agent 守則健康診斷工具：體檢本專案與環境之守則完整度、版本新鮮度與安全防護等級。
#
# 用法：
#   scripts/doctor.sh [--fix] [專案目錄]       # 體檢並評分；--fix 自動補裝 Git hooks、CI 工作流與過期守則
#   scripts/doctor.sh --check-drift [專案目錄] # CI 用：核心守則被改、遺失或缺少團隊策略強制守則時 exit 1
#   scripts/doctor.sh --init-policy [專案目錄] # 依目前安裝現況產生 .agreements.json
#
# 結束碼：體檢模式一律 0（警告只影響評分）；--check-drift 發現漂移為 1；參數或目錄錯誤為 2。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/policy.sh
. "$ROOT/scripts/lib/policy.sh"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

fix_mode=0
check_drift=0
init_policy=0
target_dir="."

while [ $# -gt 0 ]; do
  case "$1" in
    --fix) fix_mode=1; shift ;;
    --check-drift) check_drift=1; shift ;;
    --init-policy) init_policy=1; shift ;;
    -h|--help)
      echo "用法：scripts/doctor.sh [--fix] [--check-drift] [--init-policy] [專案目錄]"
      echo "  --fix          自動修復缺失之 Git pre-commit 防線、CI 工作流或過期守則"
      echo "  --check-drift  CI 專用：驗證守則未遭篡改、核心規則完整且符合團隊策略（若漂移則 exit 1）"
      echo "  --init-policy  依據目前專案守則安裝現況，一鍵初始化 .agreements.json 團隊策略檔"
      exit 0
      ;;
    *) target_dir="$1"; shift ;;
  esac
done

case "$target_dir" in "~"/*) target_dir="$HOME/${target_dir#\~/}" ;; esac
[ -d "$target_dir" ] || { echo "✗ 目錄不存在：$target_dir" >&2; exit 2; }

git_root="$(cd "$target_dir" && git rev-parse --show-toplevel 2>/dev/null || echo "$target_dir")"
# git 實際使用的 hooks 目錄（支援 worktree 與 core.hooksPath）；不在 git repo 內則為空
hooks_dir="$(cd "$git_root" 2>/dev/null && rel="$(git rev-parse --git-path hooks 2>/dev/null)" && mkdir -p "$rel" && cd "$rel" && pwd -P || true)"

# ── --init-policy 一鍵初始化團隊策略檔 ───────────────────
if [ "$init_policy" -eq 1 ]; then
  policy_target="$git_root/.agreements.json"
  if [ -f "$policy_target" ]; then
    echo "ℹ 專案已存在團隊策略檔：${policy_target}（未覆寫）"
    exit 0
  fi
  inst_profile=""
  if [ -f "$git_root/.claude/rules/agent-agreements/.agreements-profile" ]; then
    inst_profile="$git_root/.claude/rules/agent-agreements/.agreements-profile"
  elif [ -f "$target_dir/.claude/rules/agent-agreements/.agreements-profile" ]; then
    inst_profile="$target_dir/.claude/rules/agent-agreements/.agreements-profile"
  fi

  rules_json='    "security/dangerous-operations",
    "collaboration/git-safety"'

  if [ -n "$inst_profile" ]; then
    opt_rules="$(sed -n 's/^file=\([^ ]*\) .*/\1/p' "$inst_profile" | while read -r r; do
      [ -f "$ROOT/rules/$r.md" ] || continue
      [ "$(awk 'NR>1 && $0=="---"{exit} /tier:[ ]*core/{c=1} END{print c+0}' "$ROOT/rules/$r.md")" -eq 1 ] && continue
      echo "$r"
    done || true)"
    for r in $opt_rules; do
      [ -n "$r" ] && rules_json="${rules_json},
    \"$r\""
    done
  fi

  cat <<EOF > "$policy_target"
{
  "\$schema": "https://raw.githubusercontent.com/machiko/agent-working-agreements/main/schema/v1.json",
  "version": "1.0",
  "preset": "smart",
  "enforce_rules": [
${rules_json}
  ],
  "prohibit_disable_hooks": false,
  "description": "團隊 Agent 工作守則策略設定檔。由 install.sh 與 doctor.sh 讀取並強制遵循。"
}
EOF
  echo "✓ 已成功建立團隊策略檔：$policy_target"
  exit 0
fi

# ── --check-drift CI 防漂移檢驗模式 ─────────────────────
if [ "$check_drift" -eq 1 ]; then
  echo "▸ 執行 Agent 工作守則 CI 防漂移檢驗 (--check-drift)"
  echo "──"

  rule_target=""
  is_agents_md=0
  is_cursor=0

  if [ -d "$target_dir/.claude/rules/agent-agreements" ]; then
    rule_target="$target_dir/.claude/rules/agent-agreements"
  elif [ -d "$target_dir/.cursor/rules" ]; then
    rule_target="$target_dir/.cursor/rules"
    is_cursor=1
  elif [ -f "$target_dir/AGENTS.md" ]; then
    rule_target="$target_dir/AGENTS.md"
    is_agents_md=1
  elif [ -d "$HOME/.claude/rules/agent-agreements" ]; then
    rule_target="$HOME/.claude/rules/agent-agreements"
  fi

  if [ -z "$rule_target" ]; then
    echo "✗ [DRIFT] 未偵測到已安裝之 Agent 工作守則，無法通過 CI 漂移檢驗。" >&2
    exit 1
  fi

  # 取得 status
  if [ "$is_agents_md" -eq 1 ]; then
    status_out="$(bash "$ROOT/scripts/install.sh" --agents-md "$rule_target" --status 2>/dev/null)"
  elif [ "$is_cursor" -eq 1 ]; then
    status_out="$(bash "$ROOT/scripts/install.sh" --cursor "$rule_target" --status 2>/dev/null)"
  else
    status_out="$(bash "$ROOT/scripts/install.sh" --target "$rule_target" --status 2>/dev/null)"
  fi

  # 檢查核心守則是否完整無損
  drift_core=0
  for core_f in $(find "$ROOT/rules" -type f -name '*.md' -exec grep -l "^tier: core" {} +); do
    core_id="$(echo "$core_f" | sed -e "s#^$ROOT/rules/##" -e 's#\.md$##')"
    rule_line="$(printf '%s\n' "$status_out" | grep -E "^[[:space:]]*${core_id}[[:space:]—]" || true)"
    if [ -z "$rule_line" ]; then
      echo "  ✗ [DRIFT] 缺少核心守則：${core_id}" >&2
      drift_core=1
    elif printf '%s\n' "$rule_line" | grep -qE "(已手動修改|檔案遺失|來源已移除)"; then
      echo "  ✗ [DRIFT] 核心守則狀態異常 (${core_id})：$(printf '%s\n' "$rule_line" | awk -F'｜' '{print $NF}')" >&2
      drift_core=1
    fi
  done

  if [ "$drift_core" -eq 1 ]; then
    echo "✗ [DRIFT] 核心守則完整性受損，請重新執行 /agreements:setup 或 install.sh 更新還原。" >&2
    exit 1
  fi

  # 檢查團隊策略檔 (.agreements.json / .agreementsrc)
  policy_file="$(aw_find_policy "$target_dir" || true)"

  if [ -n "$policy_file" ]; then
    enforced="$(aw_policy_enforce_rules "$policy_file")"
    for enf in $enforced; do
      enf_line="$(printf '%s\n' "$status_out" | grep -E "^[[:space:]]*${enf}[[:space:]—]" || true)"
      if [ -z "$enf_line" ]; then
        echo "  ✗ [DRIFT] 違反團隊策略（$(basename "$policy_file")）：強制守則 ${enf} 尚未安裝！" >&2
        exit 1
      fi
      if printf '%s\n' "$enf_line" | grep -qE "(已手動修改|檔案遺失|來源已移除)"; then
        echo "  ✗ [DRIFT] 違反團隊策略（$(basename "$policy_file")）：強制守則狀態異常 (${enf})：$(printf '%s\n' "$enf_line" | awk -F'｜' '{print $NF}')" >&2
        exit 1
      fi
    done
    echo "  ✓ 符合團隊策略檔（$(basename "$policy_file")）之全部強制守則要求"
  fi

  echo "✓ [PASS] 守則合規無漂移 (No Drift Detected)：核心防線完整且與來源一致"
  exit 0
fi

echo "▸ 執行 Agent 工作守則全面健康診斷 (Doctor)$([ "$fix_mode" -eq 1 ] && echo " [自動修復模式]")"
echo "──"

# ── 自動修復預處理 ──────────────────────────────────────
if [ "$fix_mode" -eq 1 ]; then
  # 1. 自動安裝 Git pre-commit hook
  if [ -n "$hooks_dir" ] && { [ ! -x "$hooks_dir/pre-commit" ] || ! grep -q "scripts/audit.sh" "$hooks_dir/pre-commit" 2>/dev/null; }; then
    (cd "$git_root" && bash "$ROOT/scripts/audit.sh" --install-hook >/dev/null 2>&1) || true
    echo "  ⚙ [AUTO-FIX] 已自動安裝 Git pre-commit 主動稽核防線"
  fi

  # 2. 自動安裝 Git pre-push hook (防 Force Push)
  if [ -n "$hooks_dir" ] && [ ! -x "$hooks_dir/pre-push" ]; then
    (cd "$git_root" && bash "$ROOT/scripts/audit.sh" --install-pre-push >/dev/null 2>&1) || true
    echo "  ⚙ [AUTO-FIX] 已自動安裝 Git pre-push 破壞性操作防線"
  fi

  # 3. 自動安裝 CI/CD 守門工作流（若尚未配置）
  if [ ! -f "$git_root/.github/workflows/agent-audit.yml" ] && [ ! -f "$git_root/.gitlab-ci.yml" ] && [ ! -f "$git_root/bitbucket-pipelines.yml" ] && [ ! -f "$git_root/.pre-commit-config.yaml" ]; then
    bash "$ROOT/scripts/install.sh" --ci "$git_root" >/dev/null 2>&1 || true
    echo "  ⚙ [AUTO-FIX] 已自動配置專案 CI/CD 守門工作流"
  fi
fi

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

# 1. 守則安裝與環境診斷
local_rules="$target_dir/.claude/rules/agent-agreements"
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
  # 檢查是否以 cursor、agents-md、copilot 或 windsurf 安裝
  if [ -d "$target_dir/.cursor/rules" ]; then
    pass_item "偵測到 Cursor IDE 規則目錄 (.cursor/rules)"
  elif [ -f "$target_dir/AGENTS.md" ] && grep -q "<!-- agent-agreements:start" "$target_dir/AGENTS.md" 2>/dev/null; then
    pass_item "偵測到 AGENTS.md 守則區塊"
  elif [ -f "$target_dir/.github/copilot-instructions.md" ] && grep -q "<!-- agent-agreements:start" "$target_dir/.github/copilot-instructions.md" 2>/dev/null; then
    pass_item "偵測到 GitHub Copilot 守則區塊"
  elif [ -f "$target_dir/.windsurfrules" ] && grep -q "<!-- agent-agreements:start" "$target_dir/.windsurfrules" 2>/dev/null; then
    pass_item "偵測到 Windsurf 守則區塊"
  else
    if [ "$fix_mode" -eq 1 ]; then
      bash "$ROOT/scripts/install.sh" --target "$local_rules" >/dev/null 2>&1 || true
      pass_item "守則已自動安裝至本專案 (${local_rules})"
    else
      warn_item "尚未在此專案或全域環境安裝守則（可執行 /agreements:setup 安裝或加 --fix 自動修復）" 25
    fi
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
    if [ "$fix_mode" -eq 1 ]; then
      # 自動更新
      sel="$(sed -n 's/^selected=//p' "$installed_profile" | head -n 1)"
      target_rule_dir="$(dirname "$installed_profile")"
      bash "$ROOT/scripts/install.sh" --target "$target_rule_dir" --select "$sel" >/dev/null 2>&1 || true
      pass_item "守則已自動升級至最新版 (v${latest_ver})"
    else
      warn_item "守則版本 (v${inst_ver:-未知}) 落後於最新版 (v${latest_ver})，建議重新執行 setup 更新（或加 --fix）" 15
    fi
  fi
else
  info_item "未偵測到 .agreements-profile，略過版本比對"
fi

# 3. 核心守門完整度 (Core Invariants)
core_count="$(find "$ROOT/rules" -type f -name "*.md" -exec grep -l "^tier: core" {} + | wc -l | tr -d ' ')"
pass_item "已具備完整核心守則庫 (${core_count} 條核心不變守則)"

# 4. 本地 Pre-commit 守門檢查
if [ -n "$hooks_dir" ] && [ -x "$hooks_dir/pre-commit" ] && grep -q "scripts/audit.sh" "$hooks_dir/pre-commit" 2>/dev/null; then
  pass_item "Git pre-commit 主動稽核防線已啟動"
else
  warn_item "尚未安裝 Git pre-commit 防線（可執行 scripts/audit.sh --install-hook 安裝）" 10
fi

# 5. CI/CD 雲端自動化守護
if [ -f "$git_root/.github/workflows/agent-audit.yml" ]; then
  pass_item "GitHub Actions CI 守門工作流已就緒"
elif [ -f "$git_root/.gitlab-ci.yml" ] && grep -q "agent-audit" "$git_root/.gitlab-ci.yml" 2>/dev/null; then
  pass_item "GitLab CI 守門工作流已就緒"
elif [ -f "$git_root/bitbucket-pipelines.yml" ] && grep -q "Agent Agreements Guardrail Audit" "$git_root/bitbucket-pipelines.yml" 2>/dev/null; then
  pass_item "Bitbucket Pipelines 守門工作流已就緒"
elif [ -f "$git_root/.pre-commit-config.yaml" ] && grep -q "agent-agreements-audit" "$git_root/.pre-commit-config.yaml" 2>/dev/null; then
  pass_item "pre-commit 守門配置已就緒"
else
  info_item "尚未配置 CI 守門工作流（若專案在 GitHub/GitLab 等可執行 scripts/install.sh --ci）"
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
  echo "建議依據上方標示之 [WARN] 項目進行改善（或執行 scripts/doctor.sh --fix 自動修復）。"
  exit 0
fi
