#!/usr/bin/env bash
# harvest-scan.sh — 盤點 Claude Code 私人 memory 裡，上次 harvest 之後新增或修改的教訓。
#
# 用法：
#   scripts/harvest-scan.sh              列出上次 harvest 之後的候選（第一次執行列出全部）
#   scripts/harvest-scan.sh --all        列出全部候選
#   scripts/harvest-scan.sh --mark       把「上次 harvest」設為現在（整理完才執行）
#
# 只讀 memory，不寫任何 memory 檔。輸出以 tab 分隔：
#   修改日期、type、name、檔案路徑、description
#
# 環境變數：
#   CLAUDE_CONFIG_DIR       Claude 設定目錄（預設 ~/.claude）
#   AGREEMENTS_HARVEST_DIR  harvest 狀態目錄（預設 ~/.claude/agreements-harvest）

set -euo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STATE_DIR="${AGREEMENTS_HARVEST_DIR:-$HOME/.claude/agreements-harvest}"
STATE="$STATE_DIR/state"

mode="since"
case "${1:-}" in
  --all) mode="all" ;;
  --mark) mode="mark" ;;
  -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  '') ;;
  *) echo "未知參數：$1" >&2; exit 2 ;;
esac

if [ "$mode" = "mark" ]; then
  mkdir -p "$STATE_DIR"
  echo "last_harvest=$(date +%s)" > "$STATE"
  echo "✓ 已記錄 harvest 時間：$(date '+%Y-%m-%d %H:%M')"
  exit 0
fi

since=0
if [ "$mode" = "since" ] && [ -f "$STATE" ]; then
  since="$(sed -n 's/^last_harvest=//p' "$STATE")"
fi

mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
day() { date -r "$1" '+%Y-%m-%d' 2>/dev/null || date -d "@$1" '+%Y-%m-%d'; }

# frontmatter 欄位（支援頂層或 metadata 底下縮排的 type）
fm() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    { line = $0; sub(/^[ ]+/, "", line) }
    index(line, key ":") == 1 { sub("^" key ":[ ]*", "", line); gsub(/^"|"$/, "", line); print line; exit }' "$1"
}

count=0
for f in "$CONFIG_DIR"/projects/*/memory/*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "MEMORY.md" ] && continue
  t="$(mtime "$f")"
  [ "$t" -gt "$since" ] || continue
  type="$(fm "$f" type)"
  case "$type" in feedback|project) ;; *) continue ;; esac
  printf '%s\t%s\t%s\t%s\t%s\n' "$(day "$t")" "$type" "$(fm "$f" name)" "$f" "$(fm "$f" description)"
  count=$((count + 1))
done | sort -r

if [ "$since" -gt 0 ]; then
  echo "── 上次 harvest：$(day "$since")" >&2
else
  echo "── 第一次 harvest（或使用 --all），列出全部 feedback／project 記憶" >&2
fi
