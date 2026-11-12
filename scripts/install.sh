#!/usr/bin/env bash
# install.sh — 依選擇把規則檔安裝到目標目錄，並以 profile 記錄，可重跑調整或移除。
#
# 用法：
#   install.sh --list [--lang en]
#   install.sh --detect [dir]
#   install.sh --target <dir> [--select id1,id2] [--lang en|zh-TW] [--dry-run] [--force]
#   install.sh --target <dir> --update [--dry-run] [--force]
#   install.sh --target <dir> --uninstall [--dry-run] [--force]
#   install.sh --cursor <dir> [--select id1,id2] [--dry-run] [--force]
#   install.sh --cursor <dir> --update [--dry-run] [--force]
#   install.sh --cursor <dir> --uninstall [--dry-run] [--force]
#   install.sh --agents-md <file> [--select id1,id2] [--dry-run]
#   install.sh --agents-md <file> --update [--dry-run]
#   install.sh --agents-md <file> --uninstall [--dry-run]
#   install.sh --copilot [file] [--select id1,id2] [--dry-run]
#   install.sh --copilot [file] --update [--dry-run]
#   install.sh --windsurf [file] [--select id1,id2] [--dry-run]
#   install.sh --windsurf [file] --update [--dry-run]
#   install.sh --ci [platform] [dir] [--dry-run]
#   install.sh --target <dir> --status
#   install.sh --cursor <dir> --status
#   install.sh --agents-md <file> --status
#   install.sh --sync [dir] [--dry-run]                       # 依團隊策略檔同步所有安裝目標（見 team.sh）
#   install.sh --team-init [dir] [--targets a,b] [--dry-run]  # 團隊一條指令導入（見 team.sh）
#
#   --target    安裝目錄，例如 ~/.claude/rules/agent-agreements 或 <專案>/.claude/rules/agent-agreements
#   --cursor    Cursor 規則目錄（產出 .mdc 檔），例如 .cursor/rules
#   --agents-md 寫入 AGENTS.md（Codex 等）：只改 agent-agreements 標記區塊，區塊外內容不動
#   --copilot   寫入 GitHub Copilot 指示（預設 .github/copilot-instructions.md），以標記區塊注入
#   --windsurf  寫入 Windsurf 規則（預設 .windsurfrules），以標記區塊注入
#   --ci        安裝 CI/CD 守門工作流（支援 github、gitlab、bitbucket、pre-commit，預設智慧自動偵測）
#   --select    要加裝的 optional 規則 id（逗號分隔，例如 writing/changelog,frontend/pitfalls）；core 一律安裝
#   --update    一鍵更新：沿用既有安裝記錄（profile / 標記區塊）之規則選項，升級至最新版本
#   --dry-run   只列出會做的變更，不寫入
#   --force     覆蓋或移除已被手動修改的檔案
#   --uninstall 只移除 profile 記錄的檔案，不碰目錄內其他檔案
#   --status    唯讀：依 core／選擇的規則分組列出已安裝規則的標題、載入方式與狀態
#               （最新、有新版、已手動修改、檔案遺失、來源已移除）；不能搭配其他選項
#   --lang      守則語言：zh-TW（預設，rules/）或 en（i18n/en/rules/）。沒指定時依序沿用團隊策略檔的 lang、
#               既有安裝記錄的語言，最後才用 zh-TW；--list 也會顯示該語言的選項名稱與說明
#   --list      列出所有規則：id、tier、stack、是否按需載入、本文行數、選項名稱、說明、是否淘汰（以 tab 分隔）
#   --detect    自動掃描專案特徵並列出推薦的 optional 規則（以 tab 分隔 id 與推薦原因）
#
#   團隊守則：策略檔旁的 .agreements/rules/<name>.md 以 id「custom/<name>」一律安裝到每個目標，
#   可以列進策略檔的 enforce_rules；沒有策略檔時不讀團隊守則。
#
#   環境變數 AGENTS_MD_MAX_BYTES：AGENTS.md 大小警告門檻（預設 32768，Codex project_doc_max_bytes 預設值）
#
# 結束碼：0 成功；2 參數錯誤。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES="$ROOT/rules"
LANGS="zh-TW en"
lang=""       # 實際使用的語言；--lang 有指定就固定，否則依策略檔、既有安裝記錄決定
lang_arg=""
PROFILE_NAME=".agreements-profile"
TEAM_RULES=""  # 團隊守則目錄（策略檔旁的 .agreements/rules），找到策略檔才有

case "${1:-}" in
  --sync|--team-init) exec bash "$ROOT/scripts/team.sh" "$@" ;;
esac
# shellcheck source=lib/policy.sh
. "$ROOT/scripts/lib/policy.sh"
# shellcheck source=lib/rules.sh
. "$ROOT/scripts/lib/rules.sh"
# shellcheck source=lib/install-report.sh
. "$ROOT/scripts/lib/install-report.sh"
# shellcheck source=lib/install-detect.sh
. "$ROOT/scripts/lib/install-detect.sh"
# shellcheck source=lib/install-ci.sh
. "$ROOT/scripts/lib/install-ci.sh"
# shellcheck source=lib/install-select.sh
. "$ROOT/scripts/lib/install-select.sh"
# shellcheck source=lib/install-agents-md.sh
. "$ROOT/scripts/lib/install-agents-md.sh"
# shellcheck source=lib/install-target.sh
. "$ROOT/scripts/lib/install-target.sh"

target=""
cursor_dir=""
agents_md=""
copilot_file=""
windsurf_file=""
ci_dir=""
ci_platform=""
detect_dir=""
select_ids=""
policy_file=""
active_policy=""
dry_run=0
force=0
status=0
mode="install"

die() { echo "✗ $1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || die "--target 需要目錄"; target="$2"; shift 2 ;;
    --cursor) [ $# -ge 2 ] || die "--cursor 需要目錄"; cursor_dir="$2"; shift 2 ;;
    --agents-md) [ $# -ge 2 ] || die "--agents-md 需要檔案路徑"; agents_md="$2"; shift 2 ;;
    --copilot)
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        copilot_file="$2"; shift 2
      else
        copilot_file=".github/copilot-instructions.md"; shift
      fi
      ;;
    --windsurf)
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        windsurf_file="$2"; shift 2
      else
        windsurf_file=".windsurfrules"; shift
      fi
      ;;
    --ci)
      ci_dir="."
      shift
      while [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; do
        case "$1" in
          github|gitlab|bitbucket|pre-commit)
            ci_platform="$1"; shift ;;
          *)
            ci_dir="$1"; shift ;;
        esac
      done
      ;;
    --select) [ $# -ge 2 ] || die "--select 需要規則 id"; select_ids="$2"; shift 2 ;;
    --policy) [ $# -ge 2 ] || die "--policy 需要檔案路徑"; policy_file="$2"; shift 2 ;;
    --lang)
      [ $# -ge 2 ] || die "--lang 需要語言代碼（zh-TW 或 en）"
      case "$2" in zh-TW|en) lang_arg="$2" ;; *) die "不支援的語言：$2（可用：${LANGS}）" ;; esac
      shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --uninstall) mode="uninstall"; shift ;;
    --update) mode="update"; shift ;;
    --list) mode="list"; shift ;;
    --detect)
      mode="detect"
      shift
      if [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; then
        detect_dir="$1"
        shift
      fi
      ;;
    --status) status=1; shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) die "未知參數：$1" ;;
  esac
done

# use_lang <語言>：切換守則來源目錄（zh-TW 用 rules/，其他語言用 i18n/<語言>/rules/）
use_lang() {
  lang="$1"
  if [ "$lang" = "zh-TW" ]; then RULES="$ROOT/rules"; else RULES="$ROOT/i18n/$lang/rules"; fi
  [ -d "$RULES" ] || die "找不到 ${lang} 守則目錄：$RULES"
}
use_lang "${lang_arg:-zh-TW}"

if [ "$status" -eq 1 ]; then
  [ "$mode" = "install" ] && [ -z "$select_ids" ] && [ "$dry_run" -eq 0 ] && [ "$force" -eq 0 ] && [ -z "$lang_arg" ] \
    || die "--status 不能搭配 --select、--uninstall、--list、--detect、--dry-run、--force 或 --lang（會用安裝時的語言比對）"
  mode="status"
fi

# ── 主流程 ─────────────────────────────────────────────
# 以下各步驟的函式都定義在 scripts/lib/install-*.sh；安裝、狀態查詢完成後由函式以 exit 結束。
# 用 if 呼叫而不是 &&：&& 左側條件會讓函式內的 set -e 失效。

if [ "$mode" = "list" ]; then
  list_rules
  exit 0
fi

if [ "$mode" = "detect" ]; then
  detect_rules "${detect_dir:-.}"
  exit 0
fi

if [ -n "$ci_dir" ]; then
  install_ci "$ci_dir" "$ci_platform"
fi

targets_set=0
[ -n "$target" ] && targets_set=$((targets_set + 1))
[ -n "$cursor_dir" ] && targets_set=$((targets_set + 1))
[ -n "$agents_md" ] && targets_set=$((targets_set + 1))
[ -n "$copilot_file" ] && targets_set=$((targets_set + 1))
[ -n "$windsurf_file" ] && targets_set=$((targets_set + 1))

[ "$targets_set" -gt 1 ] && die "--target、--cursor、--agents-md、--copilot 與 --windsurf 只能擇一"
[ "$targets_set" -eq 0 ] && die "需要指定目標（--target、--cursor、--agents-md、--copilot、--windsurf 或 --ci）"

[ -n "$copilot_file" ] && agents_md="$copilot_file"
[ -n "$windsurf_file" ] && agents_md="$windsurf_file"

resolve_installed_lang
if [ "$mode" = "update" ]; then
  resolve_update_selection
fi
resolve_policy

desired=""
if [ "$mode" = "install" ]; then
  resolve_desired
fi

if [ -n "$agents_md" ]; then
  install_agents_md
fi
install_target
