#!/usr/bin/env bash
# audit.test.sh — scripts/audit.sh 的行為測試。只寫入 /tmp 底下的暫存目錄。
#
# 用法：tests/audit.test.sh

set -uo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/scripts/audit.sh"
TMP="$(mktemp -d /tmp/aw-audit-test.XXXXXX)"

trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  cd "$dir"
  git init -q
  git config user.name "Tester"
  git config user.email "tester@example.com"
  git branch -M main
  echo "# Test Repo" > README.md
  git add README.md
  git commit -q -m "Initial commit"
  git checkout -q -b feat/audit-test
}

echo "▸ 說明選單 (--help)"
"$AUDIT" --help > "$TMP/out" 2>&1
if [ $? -eq 0 ] && grep -q "主動守護稽核工具" "$TMP/out"; then
  ok "--help 正常印出用法"
else
  bad "--help 輸出非預期"
fi

echo "▸ 乾淨工作區稽核 (PASS)"
REPO_CLEAN="$TMP/repo_clean"
init_repo "$REPO_CLEAN"
mkdir -p "$REPO_CLEAN/src"
cat << 'EOF' > "$REPO_CLEAN/src/math.js"
export function add(a, b) {
  try {
    return a + b;
  } catch (err) {
    console.error("Math error:", err);
    throw err;
  }
}
EOF
git add "$REPO_CLEAN/src/math.js"
"$AUDIT" --staged > "$TMP/out" 2>&1
rc=$?
if [ $rc -eq 0 ] && grep -q "稽核通過" "$TMP/out"; then
  ok "正確程式碼通過稽核"
else
  bad "乾淨工作區未通過稽核 (exit $rc)"
fi

echo "▸ 捕捉機敏與未審查資料暫存 (FAIL)"
REPO_SENSITIVE="$TMP/repo_sensitive"
init_repo "$REPO_SENSITIVE"
echo "SECRET_KEY=12345" > "$REPO_SENSITIVE/.env.local"
git add "$REPO_SENSITIVE/.env.local"
"$AUDIT" --staged > "$TMP/out" 2>&1
rc=$?
if [ $rc -eq 1 ] && grep -q "發現敏感或資料檔案被暫存" "$TMP/out"; then
  ok "成功攔截 .env.local 暫存"
else
  bad "未攔截敏感暫存檔 (exit $rc)"
fi

echo "▸ 捕捉靜默吞噬錯誤 (Swallowed Exception) (FAIL)"
REPO_CATCH="$TMP/repo_catch"
init_repo "$REPO_CATCH"
mkdir -p "$REPO_CATCH/src"
cat << 'EOF' > "$REPO_CATCH/src/bad.ts"
function bad() {
  try {
    doSomething();
  } catch (e) {
  }
}
EOF
git add "$REPO_CATCH/src/bad.ts"
"$AUDIT" --staged > "$TMP/out" 2>&1
rc=$?
if [ $rc -eq 1 ] && grep -q "靜默吞噬例外" "$TMP/out"; then
  ok "成功攔截空 catch 區塊"
else
  bad "未攔截空 catch (exit $rc)"
fi

echo "▸ 文件 (.md) 內的程式碼片段不應造成誤判"
REPO_DOC="$TMP/repo_doc"
init_repo "$REPO_DOC"
cat << 'EOF' > "$REPO_DOC/guide.md"
# Guide
Avoid doing this:
```js
try {
  run();
} catch (e) {}
```
EOF
git add "$REPO_DOC/guide.md"
"$AUDIT" --staged > "$TMP/out" 2>&1
rc=$?
if [ $rc -eq 0 ]; then
  ok "文件中的反例代碼未誤判"
else
  bad "文件中的反例代碼觸發了誤判 (exit $rc)"
fi

echo "▸ 前端 React JSX/TSX 動態 Tailwind 拼接警告"
REPO_FRONT="$TMP/repo_front"
init_repo "$REPO_FRONT"
mkdir -p "$REPO_FRONT/src"
cat << 'EOF' > "$REPO_FRONT/src/Button.tsx"
export const Button = ({ color }) => {
  return <button className={'bg-' + color + '-500'}>Click</button>;
};
EOF
git add "$REPO_FRONT/src/Button.tsx"
"$AUDIT" --staged > "$TMP/out" 2>&1
rc=$?
if [ $rc -eq 0 ] && grep -q "檢測到動態字串拼接 class" "$TMP/out"; then
  ok "成功警告 React TSX 動態 Tailwind class 拼接"
else
  bad "未發出動態 class 拼接警告 (exit $rc)"
fi

echo "▸ 高危全開放權限警告 (chmod 777)"
REPO_PERM="$TMP/repo_perm"
init_repo "$REPO_PERM"
echo "chmod 777 /var/run/docker.sock" > "$REPO_PERM/setup.sh"
git add "$REPO_PERM/setup.sh"
"$AUDIT" --staged > "$TMP/out" 2>&1
rc=$?
if [ $rc -eq 0 ] && grep -q "檢測到高危全開放權限" "$TMP/out"; then
  ok "成功發出 chmod 777 高危權限警告"
else
  bad "未發出高危權限警告 (exit $rc)"
fi

echo "▸ 安裝 Git pre-commit hook (--install-hook)"
REPO_HOOK="$TMP/repo_hook"
init_repo "$REPO_HOOK"
"$AUDIT" --install-hook > "$TMP/out" 2>&1
rc=$?
if [ $rc -eq 0 ] && [ -x "$REPO_HOOK/.git/hooks/pre-commit" ] && grep -q "scripts/audit.sh --staged" "$REPO_HOOK/.git/hooks/pre-commit"; then
  ok "成功安裝且 pre-commit hook 具備執行權限"
else
  bad "pre-commit hook 安裝失敗 (exit $rc)"
fi

echo "──"
echo "通過 ${pass}｜失敗 ${fail}"
[ "$fail" -eq 0 ]
