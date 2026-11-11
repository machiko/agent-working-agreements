#!/usr/bin/env bash
# team.sh — 團隊同步：負責人一條指令導入，成員一條指令同步。通常經由 install.sh --sync／--team-init 呼叫。
#
# 用法：
#   team.sh --sync [專案目錄] [--dry-run]
#       讀團隊策略檔（.agreements.json），把 targets 列的每個安裝目標裝好或更新，
#       帶入 enforce_rules 與 .agreements/rules/ 的團隊守則；git_hooks 為 true 時安裝 Git hooks。
#       策略檔的 agreements_version 跟這份工具版本不同時停下來，不悄悄升級或降級。
#   team.sh --team-init [專案目錄] [--targets claude,cursor,...] [--preset smart|full|core]
#                       [--lang zh-TW|en] [--no-ci] [--dry-run]
#       產生策略檔與 .agreements/rules/，執行 --sync，安裝 CI 工作流，最後列出要 commit 的檔案。
#
#   targets 可用：claude（.claude/rules/agent-agreements）、cursor（.cursor/rules）、agents-md（AGENTS.md）、
#                 copilot（.github/copilot-instructions.md）、windsurf（.windsurfrules）
#
# 結束碼：0 成功；1 同步失敗或版本不符；2 參數錯誤或找不到策略檔。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/policy.sh
. "$ROOT/scripts/lib/policy.sh"

ALL_TARGETS="claude cursor agents-md copilot windsurf"
REMOTE_BASE="https://raw.githubusercontent.com/machiko/agent-working-agreements"

die() { echo "✗ $1" >&2; exit 2; }

mode=""; dir="."; dry_run=0; targets_arg=""; preset="smart"; lang="zh-TW"; with_ci=1
while [ $# -gt 0 ]; do
  case "$1" in
    --sync) mode="sync"; shift ;;
    --team-init) mode="init"; shift ;;
    --dry-run) dry_run=1; shift ;;
    --targets) [ $# -ge 2 ] || die "--targets 需要目標清單"; targets_arg="$2"; shift 2 ;;
    --preset)
      [ $# -ge 2 ] || die "--preset 需要 smart、full 或 core"
      case "$2" in smart|full|core) preset="$2" ;; *) die "不支援的方案：$2（可用：smart、full、core）" ;; esac
      shift 2 ;;
    --lang)
      [ $# -ge 2 ] || die "--lang 需要 zh-TW 或 en"
      case "$2" in zh-TW|en) lang="$2" ;; *) die "不支援的語言：$2（可用：zh-TW、en）" ;; esac
      shift 2 ;;
    --no-ci) with_ci=0; shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    -*) die "未知參數：$1" ;;
    *) dir="$1"; shift ;;
  esac
done
[ -n "$mode" ] || die "需要 --sync 或 --team-init"
case "$dir" in "~"/*) dir="$HOME/${dir#\~/}" ;; esac
[ -d "$dir" ] || die "目錄不存在：$dir"
dir="$(cd "$dir" && pwd -P)"

tool_version() {
  sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1
}

# remote_url [版本]：遠端安裝腳本網址；有版本就釘在該 tag，不跟著 main 變動
remote_url() {
  if [ -n "${1:-}" ]; then echo "$REMOTE_BASE/v$1/scripts/remote-install.sh"
  else echo "$REMOTE_BASE/main/scripts/remote-install.sh"; fi
}

# is_installed <目標> <路徑>：該目標已經由本工具安裝過
is_installed() {
  case "$1" in
    claude|cursor) [ -f "$2/.agreements-profile" ] ;;
    *) [ -f "$2" ] && grep -q '^<!-- agent-agreements:start' "$2" ;;
  esac
}

hooks_ready() {  # hooks_ready <根目錄>：pre-commit（稽核）與 pre-push 都已安裝
  local hd
  hd="$(cd "$1" && rel="$(git rev-parse --git-path hooks 2>/dev/null)" && cd "$rel" 2>/dev/null && pwd -P || true)"
  [ -n "$hd" ] && [ -x "$hd/pre-push" ] && grep -q "audit.sh" "$hd/pre-commit" 2>/dev/null
}

# ── --sync ───────────────────────────────────────────────

# lint_team_rules <策略檔>：團隊守則的格式與用語檢查，只提示、不擋同步
lint_team_rules() {
  local tdir out
  tdir="$(aw_team_rules_dir "$1")"
  [ -n "$tdir" ] || return 0
  [ -n "$(aw_team_rule_ids "$tdir" 2>/dev/null)" ] || return 0
  out="$( { RULES_DIR="$tdir" bash "$ROOT/scripts/check-budget.sh" --quiet; RULES_DIR="$tdir" bash "$ROOT/scripts/lint-rules.sh"; } 2>&1 >/dev/null || true)"
  out="$(printf '%s\n' "$out" | grep '^✗ rules/' || true)"
  if [ -n "$out" ]; then
    echo "▸ 團隊守則品質（只提示，不影響同步；標準見 .agreements/rules/README.md）"
    printf '%s\n' "$out" | grep '^✗ rules/' | sed 's#^✗ rules/#  ⚠ .agreements/rules/#'
  else
    echo "▸ 團隊守則品質：通過"
  fi
}

do_sync() {
  local policy root pinned local_v targets t path rel flag out rc changes=0 failed=0 lines
  policy="$(aw_find_policy "$dir" || true)"
  if [ -z "$policy" ]; then
    echo "✗ 找不到團隊策略檔（.agreements.json）" >&2
    echo "  團隊負責人先在專案根目錄執行：scripts/install.sh --team-init（或 /agreements:setup team）" >&2
    exit 2
  fi
  root="$(dirname "$policy")"
  echo "▸ 依團隊策略檔同步：${policy}"

  pinned="$(aw_policy_get "$policy" agreements_version)"
  local_v="$(tool_version)"
  if [ -n "$pinned" ] && [ "$pinned" != "$local_v" ]; then
    echo "✗ 團隊鎖定 v${pinned}，這份工具是 v${local_v}，沒有同步任何檔案" >&2
    echo "  跟團隊對齊：curl -fsSL $(remote_url "$pinned") | bash -s -- --sync" >&2
    echo "  （遠端安裝會依 agreements_version 自動下載 v${pinned}）" >&2
    echo "  要把全隊升到 v${local_v}：把 .agreements.json 的 agreements_version 改成 \"${local_v}\"，再執行 --sync 並開 PR" >&2
    exit 1
  fi

  targets="$(aw_policy_targets "$policy")"
  if [ -z "$targets" ]; then
    for t in $ALL_TARGETS; do
      is_installed "$t" "$root/$(aw_target_path "$t")" && targets="$targets $t"
    done
    if [ -z "$targets" ]; then
      echo "✗ 策略檔沒有 targets，專案裡也沒有已安裝的目標" >&2
      echo "  在 .agreements.json 加上例如 \"targets\": [\"claude\", \"agents-md\"]（可用：${ALL_TARGETS}）" >&2
      exit 2
    fi
    echo "  策略檔沒有 targets，沿用已安裝的目標：$(echo $targets)"
  fi

  for t in $targets; do
    rel="$(aw_target_path "$t")"; path="$root/$rel"; flag="$(aw_target_flag "$t")"
    # 不用 --update：它會沿用安裝記錄的 selected，策略檔改了 preset 或 enforce_rules 就不會生效。
    # 每次都依策略檔重新展開，新成員與舊成員才會裝到同一套守則。
    set -- "$flag" "$path" --policy "$policy"
    [ "$dry_run" -eq 1 ] && set -- "$@" --dry-run
    rc=0; out="$(bash "$ROOT/scripts/install.sh" "$@" 2>&1)" || rc=$?
    echo "▸ ${t}（${rel}）"
    if [ "$rc" -ne 0 ]; then
      printf '%s\n' "$out" | sed 's/^/  /' >&2
      failed=$((failed + 1)); continue
    fi
    lines="$(printf '%s\n' "$out" | grep -E '^(＋|↻|－|！|⚠)' || true)"
    if [ -n "$lines" ]; then
      printf '%s\n' "$lines" | sed 's/^/  /'
      changes=$((changes + $(printf '%s\n' "$lines" | grep -cE '^(＋|↻|－)' || true)))
    else
      echo "  ＝ 已是最新"
    fi
  done

  lint_team_rules "$policy"

  if [ "$(aw_policy_get "$policy" git_hooks)" = "true" ]; then
    if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
      echo "▸ Git hooks：${root} 不是 git repo，略過"
    elif hooks_ready "$root" && [ -f "$root/scripts/audit.sh" ]; then
      echo "▸ Git hooks：已安裝"
    elif [ "$dry_run" -eq 1 ]; then
      echo "▸ Git hooks：＋ 會安裝 pre-commit 與 pre-push（專案沒有 scripts/audit.sh 時一併複製）"; changes=$((changes + 1))
    else
      # 遠端安裝時本工具在暫存目錄、結束就刪除；pre-commit 要靠專案內的 scripts/audit.sh 才能稽核
      if [ ! -f "$root/scripts/audit.sh" ]; then
        mkdir -p "$root/scripts"
        cp "$ROOT/scripts/audit.sh" "$root/scripts/audit.sh"
        chmod +x "$root/scripts/audit.sh"
        echo "▸ ＋ scripts/audit.sh（pre-commit 稽核用，請 commit 進 repo）"; changes=$((changes + 1))
      fi
      if ! hooks_ready "$root"; then
        bash "$ROOT/scripts/hook-guard.sh" --install-git-hooks "$root" >/dev/null
        echo "▸ Git hooks：＋ 已安裝 pre-commit 與 pre-push"; changes=$((changes + 1))
      fi
    fi
  fi

  echo "──"
  if [ "$failed" -gt 0 ]; then
    echo "✗ ${failed} 個目標同步失敗（訊息見上方）" >&2
    exit 1
  fi
  if [ "$dry_run" -eq 1 ]; then
    echo "（dry-run：未寫入任何檔案；${changes} 項變更）"
  elif [ "$changes" -eq 0 ]; then
    echo "✓ 已同步，沒有變更"
  else
    echo "✓ 已同步：${changes} 項變更"
  fi
}

# ── --team-init ──────────────────────────────────────────

detect_targets() {  # 依專案裡已有的設定猜團隊用的 Agent；都沒有就用 claude 與 agents-md
  local found=""
  { [ -d "$1/.claude" ] || [ -f "$1/CLAUDE.md" ]; } && found="$found,claude"
  [ -d "$1/.cursor" ] && found="$found,cursor"
  [ -f "$1/AGENTS.md" ] && found="$found,agents-md"
  [ -f "$1/.github/copilot-instructions.md" ] && found="$found,copilot"
  [ -f "$1/.windsurfrules" ] && found="$found,windsurf"
  found="${found#,}"
  echo "${found:-claude,agents-md}"
}

json_list() {  # json_list a,b → "a", "b"
  printf '%s' "$1" | tr ',' '\n' | sed '/^$/d' | sed 's/.*/"&"/' | paste -sd, - | sed 's/,/, /g'
}

write_policy() {  # write_policy <檔案> <targets 逗號清單>
  cat > "$1" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/machiko/agent-working-agreements/main/schema/v1.json",
  "version": "1.0",
  "preset": "${preset}",
  "enforce_rules": [
    "security/dangerous-operations",
    "collaboration/git-safety"
  ],
  "targets": [$(json_list "$2")],
  "agreements_version": "$(tool_version)",
  "git_hooks": true,
  "lang": "${lang}",
  "prohibit_disable_hooks": false,
  "description": "團隊 Agent 工作守則策略檔。改這個檔案或 .agreements/rules/ 都要開 PR；成員 pull 後執行 install.sh --sync。"
}
EOF
}

write_team_readme() {
  mkdir -p "$(dirname "$1")"
  if [ "$lang" = "en" ]; then cp "$ROOT/templates/team-rules-README.en.md" "$1"
  else cp "$ROOT/templates/team-rules-README.md" "$1"; fi
}

install_drift_ci() {  # 只有 GitHub Actions 自動加防漂移工作流；其他平台印出要加的指令
  local root="$1" wf="$1/.github/workflows/agent-agreements-drift.yml"
  if [ -d "$root/.github/workflows" ] || { [ ! -f "$root/.gitlab-ci.yml" ] && [ ! -f "$root/bitbucket-pipelines.yml" ]; }; then
    mkdir -p "$(dirname "$wf")"
    sed "s#$REMOTE_BASE/main/#$REMOTE_BASE/v$(tool_version)/#" "$ROOT/templates/workflows/agent-agreements-drift.yml" > "$wf"
    echo "  ＋ ${wf#"$root"/}"
  else
    echo "  ！ 請在 CI 加一個步驟：curl -fsSL $(remote_url "$(tool_version)") | bash -s -- --check-drift ."
  fi
}

do_init() {
  local root policy targets t
  root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")"
  root="$(cd "$root" && pwd -P)"
  policy="$(aw_find_policy "$root" || true)"
  if [ -n "$policy" ]; then
    echo "✗ 已有團隊策略檔：${policy}" >&2
    echo "  成員同步請用：scripts/install.sh --sync" >&2
    exit 2
  fi
  targets="$(printf '%s' "${targets_arg:-$(detect_targets "$root")}" | tr -d ' \t')"
  for t in $(printf '%s' "$targets" | tr ',' ' '); do
    case " $ALL_TARGETS " in *" $t "*) ;; *) die "不支援的目標：$t（可用：${ALL_TARGETS}）" ;; esac
  done
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || echo "⚠️ ${root} 不是 git repo：策略檔與守則要放進版本控制才能跟團隊共用" >&2

  echo "▸ 團隊導入：${root}"
  if [ -n "$targets_arg" ]; then echo "  目標：${targets}（--targets 指定）"
  else echo "  目標：${targets}（依專案現有設定偵測；用 --targets 改）"; fi
  echo "  方案：${preset}｜語言：${lang}｜版本：v$(tool_version)"
  if [ "$dry_run" -eq 1 ]; then
    echo "  ＋ .agreements.json"
    echo "  ＋ .agreements/rules/README.md"
    for t in $(printf '%s' "$targets" | tr ',' ' '); do echo "  ＋ $(aw_target_path "$t")"; done
    echo "  ＋ Git hooks（pre-commit、pre-push）"
    [ "$with_ci" -eq 1 ] && echo "  ＋ CI 守門與防漂移工作流"
    echo "（dry-run：未寫入任何檔案）"
    return 0
  fi

  write_policy "$root/.agreements.json" "$targets"
  write_team_readme "$root/.agreements/rules/README.md"
  echo "  ＋ .agreements.json"
  echo "  ＋ .agreements/rules/README.md"
  echo
  dir="$root"
  if ! ( do_sync ); then
    echo >&2
    echo "✗ 已建立 .agreements.json，但同步失敗（訊息見上方）。修正後執行：scripts/install.sh --sync" >&2
    [ "$with_ci" -eq 1 ] && echo "  CI 工作流還沒安裝，同步成功後執行：scripts/install.sh --ci" >&2
    exit 1
  fi
  echo
  if [ "$with_ci" -eq 1 ]; then
    echo "▸ CI"
    bash "$ROOT/scripts/install.sh" --ci "$root" | sed 's/^/  /'
    install_drift_ci "$root"
  fi

  echo
  echo "── 接下來"
  echo "1. 檢查並 commit 這些檔案，開 PR："
  echo "   .agreements.json .agreements/"
  for t in $(printf '%s' "$targets" | tr ',' ' '); do echo "   $(aw_target_path "$t")"; done
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "   （git status 目前的變更：）"
    git -C "$root" status --short | sed 's/^/     /'
  fi
  echo "2. 轉告成員：pull 之後執行一次"
  echo "   curl -fsSL $(remote_url "$(tool_version)") | bash -s -- --sync"
  echo "3. 團隊規範寫在 .agreements/rules/（格式見裡面的 README.md），改完執行 --sync 再開 PR"
}

case "$mode" in
  sync) do_sync ;;
  init) do_init ;;
esac
