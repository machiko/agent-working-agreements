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
DRIFT_BAD='(已手動修改|檔案遺失|來源已移除)'
drift=0
drift_err() { echo "  ✗ [DRIFT] $1" >&2; drift=1; }

# rule_line <status 輸出> <id>：取出該守則在 --status 的那一行
rule_line() { printf '%s\n' "$1" | grep -E "^[[:space:]]*$2[[:space:]—]" || true; }

# drift_check_target <目標> <路徑>：檢查一個安裝目標的 core、強制守則、團隊守則、語言與版本
drift_check_target() {
  local kind="$1" path="$2" out line id label
  label="${kind}（${path#"$proj_root"/}）"
  out="$(bash "$ROOT/scripts/install.sh" "$(aw_target_flag "$kind")" "$path" --status 2>/dev/null || true)"
  if [ -z "$out" ] || printf '%s\n' "$out" | grep -q '^尚未安裝'; then
    drift_err "${label} 尚未安裝守則"
    return 0
  fi
  for id in $core_ids; do
    line="$(rule_line "$out" "$id")"
    if [ -z "$line" ]; then drift_err "${label} 缺少核心守則：${id}"
    elif printf '%s\n' "$line" | grep -qE "$DRIFT_BAD"; then
      drift_err "${label} 核心守則狀態異常 (${id})：$(printf '%s\n' "$line" | awk -F'｜' '{print $NF}')"
    fi
  done
  [ -n "$policy_file" ] || return 0
  for id in $enforced; do
    line="$(rule_line "$out" "$id")"
    if [ -z "$line" ]; then drift_err "${label} 違反團隊策略：強制守則 ${id} 尚未安裝"
    elif printf '%s\n' "$line" | grep -qE "$DRIFT_BAD"; then
      drift_err "${label} 違反團隊策略：強制守則狀態異常 (${id})：$(printf '%s\n' "$line" | awk -F'｜' '{print $NF}')"
    fi
  done
  # 團隊守則：repo 裡改了卻沒同步（有新版）也算漂移
  for id in $team; do
    line="$(rule_line "$out" "$id")"
    if [ -z "$line" ]; then drift_err "${label} 缺少團隊守則：${id}（執行 install.sh --sync）"
    elif printf '%s\n' "$line" | grep -qE "(已手動修改|檔案遺失|有新版)"; then
      drift_err "${label} 團隊守則與 .agreements/rules 不一致 (${id})：$(printf '%s\n' "$line" | awk -F'｜' '{print $NF}')（執行 install.sh --sync）"
    fi
  done
  for id in $(printf '%s\n' "$out" | sed -n 's/^[[:space:]]*\(custom\/[a-z0-9-]*\)[[:space:]—].*/\1/p'); do
    contains_word "$team" "$id" || drift_err "${label} 團隊守則 ${id} 已從 .agreements/rules 移除但仍安裝著（執行 install.sh --sync）"
  done
  local inst_lang inst_ver
  inst_lang="$(printf '%s\n' "$out" | sed -n 's/^守則語言：//p' | head -n 1)"
  if [ -n "$policy_lang" ] && [ "${inst_lang:-zh-TW}" != "$policy_lang" ]; then
    drift_err "${label} 違反團隊策略：守則語言應為 ${policy_lang}，目前安裝的是 ${inst_lang:-zh-TW}"
  fi
  inst_ver="$(printf '%s\n' "$out" | sed -n 's/^安裝版本：\([^｜]*\)｜.*/\1/p' | head -n 1)"
  if [ -n "$pinned" ] && [ "$inst_ver" != "$pinned" ]; then
    drift_err "${label} 違反團隊策略：安裝版本應為 ${pinned}，目前是 ${inst_ver:-未記錄}（執行 install.sh --sync）"
  fi
}

contains_word() { printf '%s\n' "$1" | grep -Fxq -- "$2"; }

if [ "$check_drift" -eq 1 ]; then
  echo "▸ 執行 Agent 工作守則 CI 防漂移檢驗 (--check-drift)"
  echo "──"

  core_ids="$(find "$ROOT/rules" -type f -name '*.md' -exec grep -l "^tier: core" {} + | sed -e "s#^$ROOT/rules/##" -e 's#\.md$##' | sort)"
  policy_file="$(aw_find_policy "$target_dir" || true)"
  enforced=""; team=""; policy_lang=""; pinned=""; targets=""; proj_root="$target_dir"
  if [ -n "$policy_file" ]; then
    proj_root="$(dirname "$policy_file")"
    enforced="$(aw_policy_enforce_rules "$policy_file")"
    policy_lang="$(aw_policy_lang "$policy_file")"
    pinned="$(aw_policy_get "$policy_file" agreements_version)"
    targets="$(aw_policy_targets "$policy_file")"
    tdir="$(aw_team_rules_dir "$policy_file")"
    team="$(aw_team_rule_ids "$tdir" 2>/dev/null)"
    for id in $enforced; do
      case "$id" in custom/*) contains_word "$team" "$id" || drift_err "違反團隊策略（$(basename "$policy_file")）：強制守則 ${id} 在 .agreements/rules 找不到來源檔" ;; esac
    done
    if ! guard_check="$(aw_check_team_guard "$policy_file")"; then
      printf '%s\n' "$guard_check" | sed 's/^/    /' >&2
      drift_err "團隊攔截規則（.agreements/guard-rules.tsv）或案例檔有問題，修正後再提交"
    elif [ -n "$(aw_team_guard_file "$policy_file")" ]; then
      echo "  ✓ 團隊攔截規則格式正確$([ -n "$(aw_team_guard_cases "$policy_file")" ] && echo "，案例檔判定一致")"
    fi
  fi

  if [ -n "$targets" ]; then
    # 策略檔有宣告 targets：每個目標都要檢查
    for t in $targets; do
      drift_check_target "$t" "$proj_root/$(aw_target_path "$t")"
    done
  else
    # 沒宣告 targets：沿用舊行為，挑第一個偵測到的安裝位置
    if [ -d "$target_dir/.claude/rules/agent-agreements" ]; then
      drift_check_target claude "$target_dir/.claude/rules/agent-agreements"
    elif [ -d "$target_dir/.cursor/rules" ]; then
      drift_check_target cursor "$target_dir/.cursor/rules"
    elif [ -f "$target_dir/AGENTS.md" ]; then
      drift_check_target agents-md "$target_dir/AGENTS.md"
    elif [ -d "$HOME/.claude/rules/agent-agreements" ]; then
      drift_check_target claude "$HOME/.claude/rules/agent-agreements"
    else
      echo "✗ [DRIFT] 未偵測到已安裝之 Agent 工作守則，無法通過 CI 漂移檢驗。" >&2
      exit 1
    fi
  fi

  if [ "$drift" -eq 1 ]; then
    echo "✗ [DRIFT] 守則與團隊策略不一致：執行 scripts/install.sh --sync（或 /agreements:setup sync）同步後再提交。" >&2
    exit 1
  fi
  [ -n "$policy_file" ] && echo "  ✓ 符合團隊策略檔（$(basename "$policy_file")）之全部要求"
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

# 2b. 已安裝守則的生命週期：已淘汰（扣分）、超過審查期限（只提示）
REVIEW_MAX_YEARS="${AGREEMENTS_REVIEW_MAX_YEARS:-1}"
if [ -n "$installed_profile" ]; then
  cutoff=$(( $(date +%Y%m%d) - REVIEW_MAX_YEARS * 10000 ))
  for rid in $(sed -n 's/^file=\([^ ]*\) .*/\1/p' "$installed_profile"); do
    src="$ROOT/rules/$rid.md"
    [ -f "$src" ] || continue
    fm="$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$src")"
    if printf '%s\n' "$fm" | grep -q '^deprecated:'; then
      reason="$(printf '%s\n' "$fm" | sed -n 's/^deprecated:[ ]*//p' | sed -e 's/^"//' -e 's/"$//')"
      replaced="$(printf '%s\n' "$fm" | sed -n 's/^replaced_by:[ ]*//p' | sed -e 's/^"//' -e 's/"$//')"
      warn_item "守則 ${rid} 已淘汰：${reason}${replaced:+；改用 ${replaced}}（重新執行 setup 調整選擇）" 5
    fi
    reviewed="$(printf '%s\n' "$fm" | sed -n 's/^last_reviewed:[ ]*//p')"
    if printf '%s' "$reviewed" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' && [ "$(printf '%s' "$reviewed" | tr -d '-')" -lt "$cutoff" ]; then
      info_item "守則 ${rid} 上次審查是 ${reviewed}，超過 ${REVIEW_MAX_YEARS} 年未審查，內容可能過時"
    fi
  done
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

# 6. 團隊守則與舊版自訂守則
team_policy="$(aw_find_policy "$target_dir" || true)"
team_dir="$(aw_team_rules_dir "$team_policy")"
if [ -n "$team_dir" ]; then
  team_count="$(aw_team_rule_ids "$team_dir" 2>/dev/null | grep -c . || true)"
  pass_item "團隊守則 ${team_count} 條 (.agreements/rules/)"
fi
team_guard="$(aw_team_guard_file "$team_policy")"
if [ -n "$team_guard" ]; then
  guard_count="$(grep -cvE '^(#|[[:space:]]*$)' "$team_guard" || true)"
  if aw_check_team_guard "$team_policy" >/dev/null; then
    pass_item "團隊攔截規則 ${guard_count} 條 (.agreements/guard-rules.tsv)"
  else
    warn_item "團隊攔截規則或案例檔有問題（寫錯的規則在 Claude Code 執行時會被跳過）：執行 install.sh --sync 看細節" 5
  fi
fi
if [ -n "$team_policy" ] && [ -z "$(aw_policy_targets "$team_policy")" ]; then
  info_item "策略檔沒有 targets：加上團隊用的 Agent 後，成員只要執行 install.sh --sync"
fi
# 舊版 /agreements:record 寫在安裝目錄的 custom/，install.sh 沒有記錄這些檔案（只有團隊守則會記錄）
custom_dir="$local_rules/custom"
[ ! -d "$custom_dir" ] && custom_dir="$global_rules/custom"
if [ -d "$custom_dir" ]; then
  legacy=0
  for f in "$custom_dir"/*.md; do
    [ -f "$f" ] || continue
    id="custom/$(basename "$f" .md)"
    grep -q "^file=$id " "$(dirname "$custom_dir")/.agreements-profile" 2>/dev/null || legacy=$((legacy + 1))
  done
  if [ "$legacy" -gt 0 ]; then
    info_item "偵測到 ${legacy} 條只存在本機的自訂守則 (${custom_dir})：搬到專案的 .agreements/rules/ 後執行 install.sh --sync，就能跟團隊共用並套用到其他 Agent"
  fi
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
