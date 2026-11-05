#!/usr/bin/env bash
# check-version.sh — 檢查版號一致：plugin.json、marketplace.json、CHANGELOG 最新版本段。
#
# 用法：scripts/check-version.sh
#   ROOT=<目錄>  要檢查的 repo 根目錄（預設本腳本的上一層，測試用）
#
# CHANGELOG 的版本段格式：`## [0.2.0] - 2026-11-05`；`## [Unreleased]` 不算版本段。
#
# 結束碼：0 一致；1 不一致或缺檔。

set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PLUGIN="$ROOT/.claude-plugin/plugin.json"
MARKET="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/CHANGELOG.md"

errors=0
fail() { echo "✗ $1" >&2; errors=$((errors + 1)); }

# 第一個 "version": "x" 的值（與 install.sh 的 version() 相同解析方式）
json_version() {
  sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1
}

for f in "$PLUGIN" "$MARKET" "$CHANGELOG"; do
  [ -f "$f" ] || fail "找不到 ${f#"$ROOT"/}"
done
[ "$errors" -eq 0 ] || exit 1

plugin_v="$(json_version "$PLUGIN")"
market_v="$(json_version "$MARKET")"
changelog_v="$(sed -n 's/^## \[\([0-9][^]]*\)\].*/\1/p' "$CHANGELOG" | head -n 1)"

[ -n "$plugin_v" ] || fail "plugin.json 沒有 version"
[ -n "$market_v" ] || fail "marketplace.json 沒有 version"
[ -n "$changelog_v" ] || fail "CHANGELOG.md 沒有版本段（## [x.y.z] - 日期）"

if [ "$errors" -eq 0 ]; then
  [ "$market_v" = "$plugin_v" ] || fail "marketplace.json 版號 ${market_v} ≠ plugin.json ${plugin_v}"
  [ "$changelog_v" = "$plugin_v" ] || fail "CHANGELOG.md 最新版本段 ${changelog_v} ≠ plugin.json ${plugin_v}"
fi

if [ "$errors" -gt 0 ]; then
  exit 1
fi
echo "✓ 版號一致：${plugin_v}"
