#!/usr/bin/env bash
# install.sh — 依選擇把規則檔安裝到目標目錄，並以 profile 記錄，可重跑調整或移除。
#
# 用法：
#   install.sh --list
#   install.sh --target <dir> [--select id1,id2] [--dry-run] [--force]
#   install.sh --target <dir> --uninstall [--dry-run] [--force]
#
#   --target    安裝目錄，例如 ~/.claude/rules/agent-agreements 或 <專案>/.claude/rules/agent-agreements
#   --select    要加裝的 optional 規則 id（逗號分隔，例如 writing/changelog,laravel/pitfalls）；core 一律安裝
#   --dry-run   只列出會做的變更，不寫入
#   --force     覆蓋或移除已被手動修改的檔案
#   --uninstall 只移除 profile 記錄的檔案，不碰目錄內其他檔案
#   --list      列出所有規則：id、tier、stack、是否按需載入、本文行數、選項名稱、說明（以 tab 分隔）
#
# 結束碼：0 成功；2 參數錯誤。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES="$ROOT/rules"
PROFILE_NAME=".agreements-profile"

target=""
select_ids=""
dry_run=0
force=0
mode="install"

die() { echo "✗ $1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || die "--target 需要目錄"; target="$2"; shift 2 ;;
    --select) [ $# -ge 2 ] || die "--select 需要規則 id"; select_ids="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --uninstall) mode="uninstall"; shift ;;
    --list) mode="list"; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "未知參數：$1" ;;
  esac
done

# ── 共用函式 ────────────────────────────────────────────

sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

# frontmatter 單行欄位值（與 check-budget.sh 相同的解析方式）
field() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, key ":") == 1 { sub("^" key ":[ ]*", ""); print; exit }' "$1"
}

has_paths() {
  awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } /^paths:/ { found = 1 } END { exit !found }' "$1"
}

body_lines() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { n++ } END { print n + 0 }' "$1"
}

# 去掉 YAML 字串外層的雙引號
unquote() { sed -e 's/^"//' -e 's/"$//'; }

title() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm && /^# / { sub(/^# /, ""); print; exit }' "$1"
}

all_ids() {
  find "$RULES" -type f -name '*.md' | sed -e "s#^$RULES/##" -e 's#\.md$##' | sort
}

version() {
  sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1
}

contains() { printf '%s\n' "$1" | grep -Fxq -- "$2"; }

# ── --list ─────────────────────────────────────────────

if [ "$mode" = "list" ]; then
  for id in $(all_ids); do
    f="$RULES/$id.md"
    stack="$(field "$f" stack)"
    scoped="always"; has_paths "$f" && scoped="on-demand"
    label="$(field "$f" label | unquote)"
    summary="$(field "$f" summary | unquote)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$(field "$f" tier)" "${stack:--}" "$scoped" "$(body_lines "$f")" "${label:-$(title "$f")}" "${summary:--}"
  done
  exit 0
fi

# ── 安裝／移除 ─────────────────────────────────────────

[ -n "$target" ] || die "需要 --target"
case "$target" in "~"/*) target="$HOME/${target#\~/}" ;; esac
profile="$target/$PROFILE_NAME"

# 期望安裝的規則：core 全部 ＋ 選擇的 optional
desired=""
if [ "$mode" = "install" ]; then
  for id in $(all_ids); do
    [ "$(field "$RULES/$id.md" tier)" = "core" ] && desired="$desired$id"$'\n'
  done
  if [ -n "$select_ids" ]; then
    for id in $(printf '%s' "$select_ids" | tr ',' ' '); do
      [ -f "$RULES/$id.md" ] || die "找不到規則：${id}（用 --list 查看可用 id）"
      contains "$desired" "$id" || desired="$desired$id"$'\n'
    done
  fi
  desired="$(printf '%s' "$desired" | sed '/^$/d' | sort)"
fi

# 已安裝的規則與記錄的雜湊（profile 每行：file=<id> sha256=<hash>）
installed=""
[ -f "$profile" ] && installed="$(sed -n 's/^file=\([^ ]*\) sha256=.*/\1/p' "$profile" | sort)"

recorded_sha() { sed -n "s#^file=$1 sha256=\\(.*\\)#\\1#p" "$profile" 2>/dev/null; }

is_modified() {
  local dest="$target/$1.md" rec
  [ -f "$dest" ] || return 1
  rec="$(recorded_sha "$1")"
  [ -n "$rec" ] && [ "$(sha "$dest")" != "$rec" ]
}

new_profile=""
changes=0

record() { new_profile="${new_profile}file=$1 sha256=$2"$'\n'; }

act() {  # act <符號> <動作> <id>
  printf '%s %s %s.md\n' "$1" "$2" "$3"
  changes=$((changes + 1))
}

# 移除不再需要的（uninstall 時全部移除）
for id in $installed; do
  if [ "$mode" = "install" ] && contains "$desired" "$id"; then continue; fi
  if is_modified "$id" && [ "$force" -eq 0 ]; then
    echo "！ 保留（已被手動修改，加 --force 才移除）$id.md"
    record "$id" "$(recorded_sha "$id")"
    continue
  fi
  act "－" "移除" "$id"
  if [ "$dry_run" -eq 0 ]; then
    rm -f "$target/$id.md"
    rmdir "$(dirname "$target/$id.md")" 2>/dev/null || true
  fi
done

# 新增或更新
unchanged=0
for id in $desired; do
  src="$RULES/$id.md"
  dest="$target/$id.md"
  src_sha="$(sha "$src")"

  if contains "$installed" "$id"; then
    if is_modified "$id" && [ "$force" -eq 0 ]; then
      echo "！ 保留（已被手動修改，加 --force 才覆蓋）$id.md"
      record "$id" "$(recorded_sha "$id")"
      continue
    fi
    if [ -f "$dest" ] && [ "$(sha "$dest")" = "$src_sha" ]; then
      unchanged=$((unchanged + 1))
      record "$id" "$src_sha"
      continue
    fi
    act "↻" "更新" "$id"
  else
    if [ -f "$dest" ] && [ "$force" -eq 0 ] && [ "$(sha "$dest")" != "$src_sha" ]; then
      echo "！ 略過（目標已有同名檔案且非本工具安裝，加 --force 才覆蓋）$id.md"
      continue
    fi
    act "＋" "新增" "$id"
  fi

  if [ "$dry_run" -eq 0 ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
  fi
  record "$id" "$src_sha"
done

# 摘要：常駐（沒有 paths）與按需載入的本文行數
always=0; ondemand=0
for id in $desired; do
  n="$(body_lines "$RULES/$id.md")"
  if has_paths "$RULES/$id.md"; then ondemand=$((ondemand + n)); else always=$((always + n)); fi
done

echo "──"
[ "$unchanged" -gt 0 ] && echo "＝ 不變 $unchanged 個"
[ "$changes" -eq 0 ] && echo "（沒有需要變更的檔案）"
if [ "$mode" = "install" ]; then
  echo "常駐：${always} 行｜按需載入：${ondemand} 行｜共 $(printf '%s\n' "$desired" | grep -c .) 個規則"
fi

if [ "$dry_run" -eq 1 ]; then
  echo "（dry-run：未寫入任何檔案）"
  exit 0
fi

# 寫入或移除 profile
if [ -z "$new_profile" ]; then
  rm -f "$profile"
  rmdir "$target" 2>/dev/null || true
  echo "✓ 已移除"
else
  mkdir -p "$target"
  {
    echo "# agent-working-agreements 安裝紀錄（由 install.sh 維護，請勿手動編輯）"
    echo "version=$(version)"
    echo "selected=$(printf '%s' "$select_ids" | tr -d ' ')"
    printf '%s' "$new_profile"
  } > "$profile"
  echo "✓ 完成：$target"
fi
