#!/usr/bin/env bash
# audit.sh — 主動守護稽核工具：檢查 staged 或近期改動是否違反 agent-working-agreements 守則。
#
# 用法：
#   scripts/audit.sh                # 優先檢查 staged 暫存區，若無暫存則檢查最近一次 commit
#   scripts/audit.sh --staged       # 明確只檢查 staged 暫存區（或 --cached）
#   scripts/audit.sh --diff         # 檢查工作區尚未暫存的修改 (Unstaged diff)
#   scripts/audit.sh --commit HEAD  # 檢查指定 commit
#   scripts/audit.sh --install-hook # 安裝為 .git/hooks/pre-commit
#
# 結束碼：0 合規；1 發現嚴重違規 (FAIL)；2 參數錯誤。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

mode="auto"
target_ref=""

while [ $# -gt 0 ]; do
  case "$1" in
    --cached|--staged) mode="cached"; shift ;;
    --diff) mode="diff"; shift ;;
    --commit) [ $# -ge 2 ] || { echo "✗ --commit 需要指定 ref" >&2; exit 2; }; target_ref="$2"; mode="commit"; shift 2 ;;
    --install-hook) mode="install-hook"; shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "✗ 未知參數：$1" >&2; exit 2 ;;
  esac
done

# ── 安裝 Git Hook ─────────────────────────────────────

if [ "$mode" = "install-hook" ]; then
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")"
  HOOK_DIR="$git_root/.git/hooks"
  [ -d "$HOOK_DIR" ] || { echo "✗ 找不到 .git/hooks 目錄" >&2; exit 1; }
  HOOK_FILE="$HOOK_DIR/pre-commit"
  cat <<'EOF' > "$HOOK_FILE"
#!/usr/bin/env bash
# 由 agent-working-agreements 安裝的 pre-commit 守門檢查
exec bash scripts/audit.sh --staged
EOF
  chmod +x "$HOOK_FILE"
  echo "✓ 已成功安裝 pre-commit hook：$HOOK_FILE"
  exit 0
fi

# ── 決定比對範圍 ─────────────────────────────────────

diff_cmd=""
name_cmd=""
scope_desc=""

if [ "$mode" = "cached" ] || { [ "$mode" = "auto" ] && [ -n "$(git diff --cached --name-only 2>/dev/null)" ]; }; then
  diff_cmd="git diff --cached"
  name_cmd="git diff --cached --name-only"
  scope_desc="Git 暫存區 (Staged)"
elif [ "$mode" = "diff" ]; then
  diff_cmd="git diff"
  name_cmd="git diff --name-only"
  scope_desc="工作區修改 (Diff)"
elif [ "$mode" = "commit" ]; then
  diff_cmd="git show -m --format= $target_ref"
  name_cmd="git diff-tree -m --no-commit-id --name-only -r $target_ref"
  scope_desc="Commit $target_ref"
else
  diff_cmd="git show -m --format= HEAD"
  name_cmd="git diff-tree -m --no-commit-id --name-only -r HEAD"
  scope_desc="最近一次 Commit (HEAD)"
fi

files="$($name_cmd 2>/dev/null || true)"
if [ -z "$files" ]; then
  echo "（${scope_desc} 沒有變更檔案，略過稽核）"
  exit 0
fi

echo "▸ 執行 agent 守則合規稽核 [範圍：${scope_desc}]"

fails=0
warns=0

fail() { echo "  ✗ [FAIL] $1" >&2; fails=$((fails + 1)); }
warn() { echo "  ! [WARN] $1"; warns=$((warns + 1)); }
pass() { echo "  ✓ [PASS] $1"; }

# 1. 個資與資料檔案檢查 (rules/security/data-files.md)
sensitive_files="$(printf '%s\n' "$files" | grep -E '\.(csv|xlsx|sql|env(\..+)?)$|^storage/|^data/' || true)"
if [ -n "$sensitive_files" ]; then
  fail "發現敏感或資料檔案被暫存（請確認是否符合 data-files 守則）："
  printf '%s\n' "$sensitive_files" | sed 's/^/      - /' >&2
else
  pass "無敏感或未審查的資料檔案暫存"
fi

# 2. 靜默吞噬例外檢查 (rules/api/pitfalls.md) — 排除 markdown 文件
code_files="$(printf '%s\n' "$files" | grep -v -E '\.md$' | grep -E '\.(php|py|js|ts|jsx|tsx|vue|go|java|rb|rs|c|cpp|cs)$' || true)"
if [ -n "$code_files" ]; then
  code_diff="$($diff_cmd -- $code_files 2>/dev/null || true)"
  swallowed="$(printf '%s\n' "$code_diff" | awk '
    /^\+[^+]/ {
      line = $0
      sub(/^\+/, "", line)
      buf = buf "\n" line
      next
    }
    {
      if (buf ~ /catch[^{]*\{[[:space:]]*(\/\*.*\*\/|\/\/[^\n]*)?[[:space:]]*\}|except[^:]*:[[:space:]]*(pass|\.\.\.)/) { found = 1 }
      buf = ""
    }
    END {
      if (buf ~ /catch[^{]*\{[[:space:]]*(\/\*.*\*\/|\/\/[^\n]*)?[[:space:]]*\}|except[^:]*:[[:space:]]*(pass|\.\.\.)/) { found = 1 }
      if (found) print "swallowed"
    }')"
  if [ -n "$swallowed" ]; then
    fail "檢測到靜默吞噬例外的空 catch/except 區塊（違反 api/pitfalls 守則）"
  else
    pass "無靜默吞噬例外的空 catch 區塊"
  fi
else
  pass "未觸及程式碼檔案或無程式碼異動"
fi

# 3. 測試完整性檢查 (rules/collaboration/test-integrity.md)
test_files="$(printf '%s\n' "$files" | grep -E 'test|spec' || true)"
if [ -n "$test_files" ]; then
  test_diff="$($diff_cmd -- $test_files 2>/dev/null || true)"
  del_asserts="$(printf '%s\n' "$test_diff" | grep -E '^\-[^-]' | grep -c -E 'assert|expect\(|@test' || true)"
  add_asserts="$(printf '%s\n' "$test_diff" | grep -E '^\+[^+]' | grep -c -E 'assert|expect\(|@test' || true)"
  if [ "$del_asserts" -gt "$add_asserts" ]; then
    warn "檢測到測試斷言被刪除（減少 $((del_asserts - add_asserts)) 個斷言），請確認是否為了變綠而改測試"
  else
    pass "測試完整性正常（未發現斷言異常減少）"
  fi
else
  pass "未觸及測試檔案或無測試異動"
fi

# 4. 動態 Tailwind Class Purge 檢查 (rules/vue/pitfalls.md)
front_files="$(printf '%s\n' "$files" | grep -E '\.(vue|jsx|tsx|html)$' || true)"
if [ -n "$front_files" ]; then
  front_diff="$($diff_cmd -- $front_files 2>/dev/null || true)"
  dyn_classes="$(printf '%s\n' "$front_diff" | grep -E '^\+[^+]' | grep -E ':class="[^"]*(\x27|\x22)[a-z]+-[a-z0-9]*-?(\x27|\x22)\s*\+' || true)"
  if [ -n "$dyn_classes" ]; then
    warn "檢測到動態字串拼接 class（可能在生產 build 時被 Tailwind purge 移除）"
  else
    pass "前端 class 完整性正常"
  fi
else
  pass "無前端 template/樣式變更"
fi

# 5. Git 分支安全檢查 (rules/collaboration/git-safety.md)
branch="$(git branch --show-current 2>/dev/null || true)"
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  warn "目前位於主分支「${branch}」，功能與重大重構請開分支走 PR"
else
  pass "當前工作分支符合隔離規範 (${branch})"
fi

echo "──"
echo "稽核結果：FAIL ${fails}｜WARN ${warns}"

if [ "$fails" -gt 0 ]; then
  echo "✗ 稽核未通過，請修正上述 FAIL 項目後再繼續。" >&2
  exit 1
fi

echo "✓ 稽核通過"
exit 0
