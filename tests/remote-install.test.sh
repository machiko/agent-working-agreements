#!/usr/bin/env bash
# remote-install.test.sh — scripts/remote-install.sh 行為測試。只寫入 /tmp 底下的暫存目錄。
set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/remote-install.sh"
TMP="$(cd "$(mktemp -d /tmp/aw-remote-test.XXXXXX)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok()  { echo "  ✓ $1"; pass=$((pass + 1)); }
bad() { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

echo "▸ remote-install.sh 基本語法與幫助參數傳遞"
if bash -n "$SCRIPT"; then ok "腳本語法檢驗通過"; else bad "腳本語法錯誤"; fi

echo "▸ remote-install.sh 整合模擬測試 (AGREEMENTS_SOURCE_DIR)"
T_CURSOR="$TMP/cursor-out"
AGREEMENTS_SOURCE_DIR="$ROOT" bash "$SCRIPT" --cursor "$T_CURSOR" --dry-run > "$TMP/out" 2>&1
if grep -q "新增" "$TMP/out"; then
  ok "成功轉發參數給 install.sh (--cursor dry-run 正常)"
else
  bad "未正確轉發參數給 install.sh"
  cat "$TMP/out" >&2
fi

echo "▸ remote-install.sh --git-hooks 轉發測試"
T_REPO="$TMP/fake-repo"
mkdir -p "$T_REPO/.git/hooks"
(
  cd "$T_REPO"
  git init -q
  AGREEMENTS_SOURCE_DIR="$ROOT" bash "$SCRIPT" --git-hooks > "$TMP/hook-out" 2>&1
)
if [ -f "$T_REPO/.git/hooks/pre-push" ]; then
  ok "成功轉發 --git-hooks 給 hook-guard.sh"
else
  bad "未成功安裝 pre-push"
  cat "$TMP/hook-out" >&2
fi

echo "──"
echo "通過 ${pass}｜失敗 ${fail}"
[ "$fail" -eq 0 ]
