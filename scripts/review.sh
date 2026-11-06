#!/usr/bin/env bash
# review.sh — Agent 守則自省審查工具：比對當前變更並逐條對照守則產出審查報告。
#
# 用法：
#   scripts/review.sh [--base <branch>] [--commit <hash>] [--staged]
#
# 結束碼：0 審核合格；1 存在違規或高危風險。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

base_branch=""
commit_hash=""
staged_only=0

while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || { echo "✗ --base 需要分支名稱" >&2; exit 2; }; base_branch="$2"; shift 2 ;;
    --commit) [ $# -ge 2 ] || { echo "✗ --commit 需要 commit hash" >&2; exit 2; }; commit_hash="$2"; shift 2 ;;
    --staged) staged_only=1; shift ;;
    -h|--help)
      echo "用法：scripts/review.sh [--base <branch>] [--commit <hash>] [--staged]"
      echo "  --base    比對目前分支與目標分支差距（例如 --base main）"
      echo "  --commit  審查特定 commit（例如 --commit HEAD）"
      echo "  --staged  只審查 Git 暫存區變更 (git diff --cached)"
      exit 0
      ;;
    *) echo "✗ 未知選項：$1" >&2; exit 2 ;;
  esac
done

# 判斷 diff 命令與受檢目標描述
diff_cmd=""
name_cmd=""
target_desc=""

if [ -n "$commit_hash" ]; then
  diff_cmd="git show -m --format= $commit_hash"
  name_cmd="git diff-tree -m --no-commit-id --name-only -r $commit_hash"
  target_desc="Commit $commit_hash"
elif [ -n "$base_branch" ]; then
  diff_cmd="git diff $base_branch...HEAD"
  name_cmd="git diff --name-only $base_branch...HEAD"
  target_desc="分支差距 ($base_branch...HEAD)"
elif [ "$staged_only" -eq 1 ] || [ -n "$(git diff --cached --name-only 2>/dev/null)" ]; then
  diff_cmd="git diff --cached"
  name_cmd="git diff --cached --name-only"
  target_desc="Git 暫存區 (Staged)"
elif [ -n "$(git diff --name-only 2>/dev/null)" ]; then
  diff_cmd="git diff"
  name_cmd="git diff --name-only"
  target_desc="工作區變更 (Diff)"
else
  diff_cmd="git show -m --format= HEAD"
  name_cmd="git diff-tree -m --no-commit-id --name-only -r HEAD"
  target_desc="最近一次 Commit (HEAD)"
fi

# 取得受檢檔案列表
files="$($name_cmd 2>/dev/null || true)"
files_changed="$(printf '%s\n' "$files" | grep -c . || true)"

failures=0
warnings=0

echo "# 📋 Agent 工作守則自省審查報告 (Self-Review Report)"
echo ""
echo "- **審查對象**：\`${target_desc}\`"
echo "- **影響檔案數**：${files_changed} 個檔案"
echo ""
echo "| 檢驗項目 | 對應守則 | 狀態 | 判定說明 |"
echo "|---------|---------|:---:|---------|"

# 檢驗 1：靜默吞噬錯誤 (Empty Catch) — 排除 markdown 文件
code_files="$(printf '%s\n' "$files" | grep -v -E '\.md$' | grep -E '\.(php|py|js|ts|jsx|tsx|vue|go|java|rb|rs|c|cpp|cs)$' || true)"
c1_status="✅ 通過"
c1_desc="未發現空 catch 或 except: pass"
if [ -n "$code_files" ]; then
  code_diff="$($diff_cmd -- $code_files 2>/dev/null || true)"
  empty_catch="$(printf '%s\n' "$code_diff" | awk '
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
  if [ -n "$empty_catch" ]; then
    c1_status="❌ 攔截"
    c1_desc="發現靜默吞噬錯誤（空 catch / except: pass）"
    failures=$((failures + 1))
  fi
fi
echo "| 錯誤吞噬防禦 | \`api/pitfalls\` | $c1_status | $c1_desc |"

# 檢驗 2：測試斷言完整性 (Test Integrity)
test_files="$(printf '%s\n' "$files" | grep -E 'test|spec' || true)"
c2_status="✅ 通過"
c2_desc="未發現刪除既有測試斷言"
if [ -n "$test_files" ]; then
  test_diff="$($diff_cmd -- $test_files 2>/dev/null || true)"
  del_asserts="$(printf '%s\n' "$test_diff" | grep -E '^\-[^-]' | grep -c -E 'assert|expect\(|@test' || true)"
  add_asserts="$(printf '%s\n' "$test_diff" | grep -E '^\+[^+]' | grep -c -E 'assert|expect\(|@test' || true)"
  if [ "$del_asserts" -gt "$add_asserts" ]; then
    c2_status="❌ 攔截"
    c2_desc="檢測到測試斷言被刪除（減少 $((del_asserts - add_asserts)) 個斷言）"
    failures=$((failures + 1))
  fi
fi
echo "| 測試斷言完整性 | \`collaboration/test-integrity\` | $c2_status | $c2_desc |"

# 檢驗 3：機敏資料檔案防線 (Data Files)
c3_status="✅ 通過"
c3_desc="無誤存敏感環境變數或資料庫 Dump"
sens_files="$(printf '%s\n' "$files" | grep -v 'example' | grep -E '(^|/)(\.env|\.env\..*|\.sql|\.pem|\.key)$' || true)"
if [ -n "$sens_files" ]; then
  c3_status="❌ 攔截"
  c3_desc="發現誤加入之機敏或金鑰檔案 (.env / .sql / .pem)"
  failures=$((failures + 1))
fi
echo "| 機敏憑證防護 | \`security/data-files\` | $c3_status | $c3_desc |"

# 檢驗 4：高危權限與 IAM (Permissions & Supply Chain) — 排除腳本本身與文檔
non_audit_files="$(printf '%s\n' "$files" | grep -v -E '(audit\.sh|review\.sh|\.md)$' || true)"
c4_status="✅ 通過"
c4_desc="未包含 chmod 777 或過寬 Wildcard IAM"
if [ -n "$non_audit_files" ]; then
  sec_diff="$($diff_cmd -- $non_audit_files 2>/dev/null || true)"
  if printf '%s\n' "$sec_diff" | grep -E '^\+[^+]' | grep -E '\bchmod\s+777\b' >/dev/null 2>&1; then
    c4_status="❌ 攔截"
    c4_desc="檢測到高危險 chmod 777 全開權限指令"
    failures=$((failures + 1))
  elif printf '%s\n' "$sec_diff" | grep -E '^\+[^+]' | grep -E '"(Action|Resource)"\s*:\s*"\*"' >/dev/null 2>&1; then
    c4_status="⚠️ 警告"
    c4_desc="檢測到過度寬鬆之 Wildcard IAM 授權"
    warnings=$((warnings + 1))
  fi
fi
echo "| 高危權限與 IAM | \`security/supply-chain\` | $c4_status | $c4_desc |"

# 檢驗 5：測試硬編碼 Sleep 防線 (Testing Pitfalls)
c5_status="✅ 通過"
c5_desc="未在測試檔案中發現硬編碼 sleep 延遲"
if [ -n "$test_files" ]; then
  test_diff="$($diff_cmd -- $test_files 2>/dev/null || true)"
  if printf '%s\n' "$test_diff" | grep -v -E '(audit\.test\.sh|review\.test\.sh)' | grep -E '^\+[^+]' | grep -E '\b(time\.sleep\(|sleep\([0-9]+\)|setTimeout\(.*?,\s*[0-9]{3,}\))' >/dev/null 2>&1; then
    c5_status="⚠️ 警告"
    c5_desc="測試中包含靜態硬編碼延遲，易導致 Flaky CI"
    warnings=$((warnings + 1))
  fi
fi
echo "| 測試硬延遲防禦 | \`testing/pitfalls\` | $c5_status | $c5_desc |"

# 檢驗 6：動態 Tailwind 類別 (Frontend Pitfalls)
front_files="$(printf '%s\n' "$files" | grep -E '\.(vue|jsx|tsx|svelte|html)$' || true)"
c6_status="✅ 通過"
c6_desc="未發現動態字串拼接 class 名稱"
if [ -n "$front_files" ]; then
  front_diff="$($diff_cmd -- $front_files 2>/dev/null || true)"
  dyn_classes="$(printf '%s\n' "$front_diff" | grep -E '^\+[^+]' | grep -E '(:class|className)=["\x27{][^"}\x27]*(\x27|\x22|\`)[a-z]+-[a-z0-9]*-?(\x27|\x22|\`)\s*(\+|\$)' || true)"
  if [ -n "$dyn_classes" ]; then
    c6_status="⚠️ 警告"
    c6_desc="發現動態字串拼接 class，可能在生產建構遭 Purge"
    warnings=$((warnings + 1))
  fi
fi
echo "| 樣式 Purge 風險 | \`frontend/pitfalls\` | $c6_status | $c6_desc |"

echo ""
echo "## 📌 審核結論"
if [ "$failures" -gt 0 ]; then
  echo "❌ **未通過審核**：發現 ${failures} 項重大違規阻擋項目，請修復後再提交！"
  exit 1
elif [ "$warnings" -gt 0 ]; then
  echo "⚠️ **通過但有警告**：發現 ${warnings} 項可能風險，建議檢視上方說明評估是否優化。"
  exit 0
else
  echo "✅ **完美通過**：程式碼變更完全符合 Agent Working Agreements 守則，無安全與架構地雷！"
  exit 0
fi
