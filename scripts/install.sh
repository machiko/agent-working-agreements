#!/usr/bin/env bash
# install.sh — 依選擇把規則檔安裝到目標目錄，並以 profile 記錄，可重跑調整或移除。
#
# 用法：
#   install.sh --list
#   install.sh --target <dir> [--select id1,id2] [--dry-run] [--force]
#   install.sh --target <dir> --uninstall [--dry-run] [--force]
#   install.sh --agents-md <file> [--select id1,id2] [--dry-run]
#   install.sh --agents-md <file> --uninstall [--dry-run]
#
#   --target    安裝目錄，例如 ~/.claude/rules/agent-agreements 或 <專案>/.claude/rules/agent-agreements
#   --agents-md 寫入 AGENTS.md（Codex 等）：只改 agent-agreements 標記區塊，區塊外內容不動
#   --select    要加裝的 optional 規則 id（逗號分隔，例如 writing/changelog,laravel/pitfalls）；core 一律安裝
#   --dry-run   只列出會做的變更，不寫入
#   --force     覆蓋或移除已被手動修改的檔案
#   --uninstall 只移除 profile 記錄的檔案，不碰目錄內其他檔案
#   --list      列出所有規則：id、tier、stack、是否按需載入、本文行數、選項名稱、說明（以 tab 分隔）
#
#   環境變數 AGENTS_MD_MAX_BYTES：AGENTS.md 大小警告門檻（預設 32768，Codex project_doc_max_bytes 預設值）
#
# 結束碼：0 成功；2 參數錯誤。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES="$ROOT/rules"
PROFILE_NAME=".agreements-profile"

target=""
agents_md=""
select_ids=""
dry_run=0
force=0
mode="install"

die() { echo "✗ $1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || die "--target 需要目錄"; target="$2"; shift 2 ;;
    --agents-md) [ $# -ge 2 ] || die "--agents-md 需要檔案路徑"; agents_md="$2"; shift 2 ;;
    --select) [ $# -ge 2 ] || die "--select 需要規則 id"; select_ids="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --uninstall) mode="uninstall"; shift ;;
    --list) mode="list"; shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
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

[ -n "$target" ] && [ -n "$agents_md" ] && die "--target 與 --agents-md 只能擇一"
[ -n "$target" ] || [ -n "$agents_md" ] || die "需要 --target 或 --agents-md"

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

# ── --agents-md：只改寫標記區塊 ────────────────────────

if [ -n "$agents_md" ]; then
  case "$agents_md" in "~"/*) agents_md="$HOME/${agents_md#\~/}" ;; esac
  START_RE='^<!-- agent-agreements:start'
  END_LINE='<!-- agent-agreements:end -->'
  MAX_BYTES="${AGENTS_MD_MAX_BYTES:-32768}"
  work="$(mktemp -d "${TMPDIR:-/tmp}/aw-agents.XXXXXX")"

  # 去掉 frontmatter 與本文開頭的空行
  strip_body() {
    awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } fm { next }
         !started && $0 == "" { next } { started = 1; print }' "$1"
  }

  # 區塊內某條規則的段落（到下一條規則或結束標記為止）
  section() {
    awk -v id="$1" -v end="$END_LINE" '
      $0 == "<!-- rule: " id " -->" { on = 1; next }
      on && (index($0, "<!-- rule: ") == 1 || $0 == end) { exit }
      on { print }' "$2"
  }

  start_ln=""; end_ln=""
  if [ -f "$agents_md" ]; then
    start_ln="$(grep -n "$START_RE" "$agents_md" | head -n 1 | cut -d: -f1 || true)"
    end_ln="$(grep -n -x -F -- "$END_LINE" "$agents_md" | head -n 1 | cut -d: -f1 || true)"
    if [ -n "$start_ln" ] && { [ -z "$end_ln" ] || [ "$end_ln" -lt "$start_ln" ]; }; then
      die "${agents_md} 的 agent-agreements 區塊不完整（找不到結束標記），請手動修正後再執行"
    fi
  fi

  old_block="$work/old"; : > "$old_block"
  [ -n "$start_ln" ] && sed -n "${start_ln},${end_ln}p" "$agents_md" > "$old_block"
  old_ids="$(sed -n 's/^<!-- rule: \([^ ]*\) -->$/\1/p' "$old_block" | sort)"

  new_block="$work/new"; : > "$new_block"
  if [ "$mode" = "install" ]; then
    {
      echo "<!-- agent-agreements:start v$(version) -->"
      echo "<!-- agent-agreements:selected=$(printf '%s' "$select_ids" | tr -d ' ') -->"
      echo "<!-- 由 agent-working-agreements 的 install.sh 產生，請勿手動編輯；重跑 install.sh --agents-md 即可更新 -->"
      for id in $desired; do
        echo
        echo "<!-- rule: $id -->"
        strip_body "$RULES/$id.md"
      done
      echo
      echo "$END_LINE"
    } > "$new_block"
  fi

  # 差異
  changes=0; unchanged=0
  for id in $old_ids; do
    if [ "$mode" = "install" ] && contains "$desired" "$id"; then continue; fi
    printf '－ 移除 %s\n' "$id"; changes=$((changes + 1))
  done
  for id in $desired; do
    if contains "$old_ids" "$id"; then
      if [ "$(section "$id" "$old_block")" = "$(section "$id" "$new_block")" ]; then
        unchanged=$((unchanged + 1))
      else
        printf '↻ 更新 %s\n' "$id"; changes=$((changes + 1))
      fi
    else
      printf '＋ 新增 %s\n' "$id"; changes=$((changes + 1))
    fi
  done

  # 組出新檔案：區塊外的內容逐位元組保留
  result="$work/result"; : > "$result"
  if [ -n "$start_ln" ]; then
    keep_before=$((start_ln - 1))
    # 移除時，順便拿掉當初附加區塊時加的空白分隔行
    if [ "$mode" = "uninstall" ] && [ "$keep_before" -gt 0 ] && [ -z "$(sed -n "${keep_before}p" "$agents_md")" ]; then
      keep_before=$((keep_before - 1))
    fi
    [ "$keep_before" -gt 0 ] && head -n "$keep_before" "$agents_md" >> "$result"
    cat "$new_block" >> "$result"
    tail -n "+$((end_ln + 1))" "$agents_md" >> "$result"
  elif [ "$mode" = "install" ]; then
    if [ -s "$agents_md" ]; then
      cat "$agents_md" >> "$result"
      [ "$(tail -c 1 "$agents_md" | od -An -c | tr -d ' ')" = '\n' ] || echo >> "$result"
      echo >> "$result"
    fi
    cat "$new_block" >> "$result"
  else
    echo "（${agents_md} 沒有 agent-agreements 區塊，不需移除）"
    exit 0
  fi

  bytes="$(wc -c < "$result" | tr -d ' ')"
  echo "──"
  [ "$unchanged" -gt 0 ] && echo "＝ 不變 ${unchanged} 個"
  [ "$changes" -eq 0 ] && [ -f "$agents_md" ] && cmp -s "$result" "$agents_md" && echo "（區塊內容沒有變更）"
  if [ "$mode" = "install" ]; then
    echo "規則：$(printf '%s\n' "$desired" | grep -c .) 個｜${agents_md}：${bytes} bytes"
  else
    echo "${agents_md}：${bytes} bytes"
  fi
  if [ "$bytes" -gt "$MAX_BYTES" ]; then
    echo "⚠ 超過 ${MAX_BYTES} bytes（Codex project_doc_max_bytes 預設值），超出部分可能被截斷；可減少選擇的規則" >&2
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "（dry-run：未寫入任何檔案）"
    exit 0
  fi

  mkdir -p "$(dirname "$agents_md")"
  cat "$result" > "$agents_md"
  if [ "$mode" = "uninstall" ]; then
    if [ "$bytes" -eq 0 ]; then
      echo "✓ 已移除區塊；${agents_md} 現在是空檔案（未刪除檔案）"
    else
      echo "✓ 已移除區塊：${agents_md}"
    fi
  else
    echo "✓ 完成：${agents_md}"
  fi
  exit 0
fi

case "$target" in "~"/*) target="$HOME/${target#\~/}" ;; esac
profile="$target/$PROFILE_NAME"

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
