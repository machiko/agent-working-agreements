#!/usr/bin/env bash
# hook-guard.test.sh — tests for scripts/hook-guard.sh, hook-guard.py 與 Git hook 安裝。
# python3 與純 bash fallback 兩種模式跑同一組案例，確保兩套防線行為一致。
set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$ROOT/scripts/hook-guard.sh"
TMP="$(mktemp -d /tmp/aw-hook-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1" >&2; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# json_input <command> [cwd]：組出 PreToolUse 的 stdin（指令裡的 \ 與 " 會跳脫）
json_input() {
  local esc cwd_field=""
  # 反斜線、引號、Tab、換行都要跳脫，才是合法的 JSON 字串
  esc="$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{ gsub(/\t/, "\\t"); printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }')"
  [ -n "${2:-}" ] && cwd_field=",\"cwd\":\"$2\""
  printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}%s}' "$esc" "$cwd_field"
}

# guard_out <command> [cwd]：依目前 GUARD_MODE 執行 guard 並印出輸出
guard_out() {
  if [ "$GUARD_MODE" = "bash" ]; then
    json_input "$@" | AGREEMENTS_HOOK_FORCE_BASH=1 bash "$GUARD" 2>/dev/null
  else
    json_input "$@" | bash "$GUARD" 2>/dev/null
  fi
}

is_deny() { printf '%s' "$1" | grep -Eq '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; }

denies()  { local o; o="$(guard_out "$@")"; is_deny "$o"; }
allows()  { local o; o="$(guard_out "$@")"; ! is_deny "$o"; }

# 攔截與放行案例放在共用案例檔，Playground 的 JS 比對器也跑同一份（tests/playground.test.sh）
CASES="$ROOT/tests/fixtures/guard-cases.tsv"
DENY_CASES=()
ALLOW_CASES=()
while IFS=$'\t' read -r kind cmd; do
  case "$kind" in
    deny)  DENY_CASES+=("$cmd") ;;
    allow) ALLOW_CASES+=("$cmd") ;;
  esac
done < "$CASES"
# 多行案例（heredoc）：\n 代表換行、\t 代表 Tab
while IFS=$'\t' read -r kind cmd; do
  cmd="${cmd//\\n/$'\n'}"; cmd="${cmd//\\t/$'\t'}"
  case "$kind" in
    deny)  DENY_CASES+=("$cmd") ;;
    allow) ALLOW_CASES+=("$cmd") ;;
  esac
done < "$ROOT/tests/fixtures/guard-multiline-cases.tsv"
check "共用案例檔讀到攔截與放行案例" '[ "${#DENY_CASES[@]}" -gt 0 ] && [ "${#ALLOW_CASES[@]}" -gt 0 ]'

run_cases() {
  local c
  for c in "${DENY_CASES[@]}"; do
    check "[$GUARD_MODE] 攔截：$c" 'denies "$c"'
  done
  for c in "${ALLOW_CASES[@]}"; do
    check "[$GUARD_MODE] 放行：$c" 'allows "$c"'
  done
}

# 團隊攔截規則樣本：好的規則、寫錯的規則（欄位不足、無法編譯、連空字串都命中）、想放寬內建規則的規則
{
  printf '# 團隊攔截規則\n'
  printf 'custom/infra\t(^|[^A-Za-z0-9_-])helm{S}(.*{S})?uninstall{E}\t禁止 helm uninstall，請走變更流程。\n'
  printf 'custom/db\t(^|[^A-Za-z0-9_-])psql{S}.*prod\t不要直接連正式機資料庫。\t--read-only\n'
  printf 'custom/loose\tgit{S}push\t推送前先開 PR。\t--force\n'
  printf 'custom/short\tonly-two-fields\n'
  printf 'custom/bad\tfoo([\t無法編譯\n'
  printf 'custom/empty\tx*\t連空字串都命中\n'
  printf 'custom/k8s\t(^|[^A-Za-z0-9_-])kubectl{S}drain{E}\t不要 drain 節點。\n'
} > "$TMP/team-rules.tsv"

for GUARD_MODE in python bash; do
  if [ "$GUARD_MODE" = "python" ] && ! command -v python3 >/dev/null 2>&1; then
    echo "▸ 略過 python 模式（環境沒有 python3）"
    continue
  fi
  echo "▸ hook-guard（$GUARD_MODE 模式）：攔截與放行"
  run_cases

  out_force="$(guard_out "git push origin main --force")"
  check "[$GUARD_MODE] 拒絕時附 permissionDecisionReason" 'printf "%s" "$out_force" | grep -q "permissionDecisionReason"'
  check "[$GUARD_MODE] 拒絕原因標示 git-safety 守則" 'printf "%s" "$out_force" | grep -q "git-safety"'

  non_bash='{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"x","content":"git push --force"}}'
  if [ "$GUARD_MODE" = "bash" ]; then
    out_nb="$(printf '%s' "$non_bash" | AGREEMENTS_HOOK_FORCE_BASH=1 bash "$GUARD")"
  else
    out_nb="$(printf '%s' "$non_bash" | bash "$GUARD")"
  fi
  check "[$GUARD_MODE] 非 Bash 工具不攔截" '! is_deny "$out_nb"'

  with_desc='{"tool_name":"Bash","tool_input":{"command":"ls -la","description":"git reset --hard 之前先看一下"}}'
  esc_cmd='{"tool_name":"Bash","tool_input":{"command":"echo \"a\\\\b\" \u0026\u0026 git reset --hard","description":"x"}}'
  if [ "$GUARD_MODE" = "bash" ]; then
    out_desc="$(printf '%s' "$with_desc" | AGREEMENTS_HOOK_FORCE_BASH=1 bash "$GUARD")"
    out_esc="$(printf '%s' "$esc_cmd" | AGREEMENTS_HOOK_FORCE_BASH=1 bash "$GUARD")"
  else
    out_desc="$(printf '%s' "$with_desc" | bash "$GUARD")"
    out_esc="$(printf '%s' "$esc_cmd" | bash "$GUARD")"
  fi
  check "[$GUARD_MODE] 只比對 command 欄位，description 提到高危指令不攔截" '! is_deny "$out_desc"'
  check "[$GUARD_MODE] command 裡的跳脫字元與 \\u0026 解碼後照常攔截" 'is_deny "$out_esc"'

  echo "▸ hook-guard（$GUARD_MODE 模式）：停用開關與 prohibit_disable_hooks"
  out_dis="$(AGREEMENTS_HOOKS_DISABLE=1 guard_out "git push --force" "$TMP")"
  check "[$GUARD_MODE] AGREEMENTS_HOOKS_DISABLE=1 時不攔截" '! is_deny "$out_dis"'

  LOCK="$TMP/lock-$GUARD_MODE"
  mkdir -p "$LOCK/packages/api"
  (cd "$LOCK" && git init -q)
  printf '{\n  "prohibit_disable_hooks": true\n}\n' > "$LOCK/.agreements.json"
  out_lock="$(cd "$LOCK" && AGREEMENTS_HOOKS_DISABLE=1 guard_out "git push --force")"
  check "[$GUARD_MODE] prohibit_disable_hooks 時忽略停用開關" 'is_deny "$out_lock"'

  out_sub="$(cd "$TMP" && AGREEMENTS_HOOKS_DISABLE=1 guard_out "git push --force" "$LOCK/packages/api")"
  check "[$GUARD_MODE] Monorepo 子目錄 cwd 向上找到 prohibit_disable_hooks" 'is_deny "$out_sub"'

  rm -f "$LOCK/.agreements.json"
  printf '{ "prohibit_disable_hooks": true }' > "$LOCK/.agreementsrc"
  out_rc="$(cd "$LOCK" && AGREEMENTS_HOOKS_DISABLE=1 guard_out "git push --force")"
  check "[$GUARD_MODE] .agreementsrc 的 prohibit_disable_hooks 生效" 'is_deny "$out_rc"'
  rm -f "$LOCK/.agreementsrc"

  printf '{ "prohibit_disable_hooks": "false" }' > "$LOCK/.agreements.json"
  out_str="$(cd "$LOCK" && AGREEMENTS_HOOKS_DISABLE=1 guard_out "git push --force")"
  check "[$GUARD_MODE] 字串 \"false\" 不視為鎖定（停用開關仍有效）" '! is_deny "$out_str"'

  printf '[1, 2]' > "$LOCK/.agreements.json"
  out_arr="$(cd "$LOCK" && AGREEMENTS_HOOKS_DISABLE=1 guard_out "git push --force")"
  if [ "$GUARD_MODE" = "python" ]; then
    check "[$GUARD_MODE] 策略檔不是 JSON 物件時採安全預設（仍攔截）" 'is_deny "$out_arr"'
  fi
  rm -f "$LOCK/.agreements.json"

  echo "▸ hook-guard（$GUARD_MODE 模式）：團隊攔截規則"
  TEAM="$TMP/team-$GUARD_MODE"
  mkdir -p "$TEAM/.agreements" "$TEAM/sub"
  (cd "$TEAM" && git init -q)
  printf '{}\n' > "$TEAM/.agreements.json"
  cp "$TMP/team-rules.tsv" "$TEAM/.agreements/guard-rules.tsv"
  out_tf="$(guard_out "helm uninstall web --namespace prod" "$TEAM/sub")"
  check "[$GUARD_MODE] 團隊規則攔截 helm uninstall" 'is_deny "$out_tf"'
  check "[$GUARD_MODE] 拒絕原因標出團隊規則與守則名稱" 'printf "%s" "$out_tf" | grep -q "custom/infra 團隊規則攔截"'
  check "[$GUARD_MODE] 團隊規則沒命中的指令放行" 'allows "helm list" "$TEAM"'
  check "[$GUARD_MODE] 團隊規則的放行例外生效" 'allows "psql -h prod-db --read-only" "$TEAM"'
  check "[$GUARD_MODE] 團隊規則無法放行內建規則攔截的指令" 'denies "git push --force" "$TEAM"'
  check "[$GUARD_MODE] 寫錯的團隊規則被跳過，不會擋掉所有指令" 'allows "ls -la" "$TEAM"'
  check "[$GUARD_MODE] 寫錯的團隊規則之後的規則照常攔截" 'denies "kubectl drain node-1" "$TEAM"'
  if [ "$GUARD_MODE" = "bash" ]; then
    err_team="$(json_input "ls" "$TEAM" | AGREEMENTS_HOOK_FORCE_BASH=1 bash "$GUARD" 2>&1 >/dev/null)"
  else
    err_team="$(json_input "ls" "$TEAM" | bash "$GUARD" 2>&1 >/dev/null)"
  fi
  check "[$GUARD_MODE] 跳過寫錯的團隊規則時警告" '[ "$(printf "%s\n" "$err_team" | grep -c "略過團隊")" -ge 3 ]'
  rm -f "$TEAM/.agreements.json"
  check "[$GUARD_MODE] 沒有策略檔時不讀團隊規則" 'allows "helm uninstall web" "$TEAM"'
done

if command -v python3 >/dev/null 2>&1; then
  echo "▸ hook-guard.py --check：團隊規則與案例檔"
  PYG="$ROOT/scripts/hook-guard.py"
  grep -v -e '^custom/short' -e '^custom/bad' -e '^custom/empty' "$TMP/team-rules.tsv" > "$TMP/good.tsv"
  check "格式正確的團隊規則通過" 'python3 "$PYG" --check "$TMP/good.tsv" >/dev/null'
  out_chk="$(python3 "$PYG" --check "$TMP/team-rules.tsv" 2>&1)"; rc_chk=$?
  check "寫錯的團隊規則 exit 1" '[ "$rc_chk" -eq 1 ]'
  check "列出每一行寫錯的位置" '[ "$(printf "%s\n" "$out_chk" | grep -c "^✗ team-rules.tsv:")" -eq 3 ]'
  printf 'custom/x\tfoo\\sbar\t不可攜\n' > "$TMP/nonportable.tsv"
  out_np="$(python3 "$PYG" --check "$TMP/nonportable.tsv" 2>&1)"; rc_np=$?
  check "\\s 這類 bash 不支援的寫法被指出" '[ "$rc_np" -eq 1 ] && printf "%s" "$out_np" | grep -q "bash"'
  printf 'deny\thelm uninstall web\nallow\thelm list\ndeny\tgit push -f\nallow\tpsql -h prod-db --read-only\n' > "$TMP/cases.tsv"
  check "案例檔跟判定一致時通過" 'python3 "$PYG" --check "$TMP/good.tsv" "$TMP/cases.tsv" >/dev/null'
  printf 'allow\thelm uninstall web\nmaybe\tls\n' > "$TMP/bad-cases.tsv"
  out_cases="$(python3 "$PYG" --check "$TMP/good.tsv" "$TMP/bad-cases.tsv" 2>&1)"; rc_cases=$?
  check "案例不符時 exit 1" '[ "$rc_cases" -eq 1 ]'
  check "列出預期與實際判定" 'printf "%s" "$out_cases" | grep -q "預期 allow，實際 deny（custom/infra）"'
  check "案例格式錯誤被指出" 'printf "%s" "$out_cases" | grep -q "bad-cases.tsv:2"'
fi

echo "▸ hook-guard：策略檔搜尋停在 git root，不讀上層目錄"
OUTER="$TMP/outer"
mkdir -p "$OUTER/repo"
(cd "$OUTER/repo" && git init -q)
printf '{ "prohibit_disable_hooks": true }' > "$OUTER/.agreements.json"
GUARD_MODE=python
command -v python3 >/dev/null 2>&1 || GUARD_MODE=bash
out_outer="$(cd "$OUTER/repo" && AGREEMENTS_HOOKS_DISABLE=1 guard_out "git push --force")"
check "git repo 外層的策略檔不影響 repo 內" '! is_deny "$out_outer"'

echo "▸ --install-git-hooks：安裝與 pre-push 攔截"
REPO="$TMP/repo"
mkdir -p "$REPO"
(cd "$REPO" && git init -q && git config user.email "test@example.com" && git config user.name "Test")
HOOKS="$REPO/.git/hooks"

bash "$GUARD" --install-git-hooks "$REPO" > /dev/null
check "建立 pre-push hook" '[ -x "$HOOKS/pre-push" ]'
check "建立 pre-commit hook" '[ -x "$HOOKS/pre-commit" ]'

(cd "$REPO" && echo "1" > a && git add a && git commit -n -m "init" -q)
c1="$(cd "$REPO" && git rev-parse HEAD)"
(cd "$REPO" && echo "2" > a && git commit -n -am "second" -q)
c2="$(cd "$REPO" && git rev-parse HEAD)"
(cd "$REPO" && git checkout -q -b branch2 "$c1" && echo "3" > b && git add b && git commit -n -m "branch2" -q)
c3="$(cd "$REPO" && git rev-parse HEAD)"

push_input="refs/heads/branch2 $c3 refs/heads/main $c2"
out_pp="$(printf '%s\n' "$push_input" | (cd "$REPO" && bash .git/hooks/pre-push origin https://example.com) 2>&1 || true)"
check "pre-push 攔截 force push 覆蓋" 'printf "%s" "$out_pp" | grep -q "git-safety"'

ff_input="refs/heads/main $c2 refs/heads/main $c1"
check "pre-push 放行快進推送" 'printf "%s\n" "$ff_input" | (cd "$REPO" && bash .git/hooks/pre-push origin https://example.com) >/dev/null 2>&1'

missing_input="refs/heads/main $c2 refs/heads/main 1234567890123456789012345678901234567890"
out_pp_missing="$(printf '%s\n' "$missing_input" | (cd "$REPO" && bash .git/hooks/pre-push origin https://example.com) 2>&1 || true)"
check "pre-push 遇到本機沒有的遠端 commit 時要求先 fetch" 'printf "%s" "$out_pp_missing" | grep -q "git fetch"'

printf '{\n  "prohibit_disable_hooks": true\n}\n' > "$REPO/.agreements.json"
out_pp_lock="$(printf '%s\n' "$push_input" | (cd "$REPO" && AGREEMENTS_HOOKS_DISABLE=1 bash .git/hooks/pre-push origin https://example.com) 2>&1 || true)"
check "pre-push 遇 prohibit_disable_hooks 仍攔截 force push" 'printf "%s" "$out_pp_lock" | grep -q "git-safety"'
rm -f "$REPO/.agreements.json"

echo "▸ --install-git-hooks：pre-commit 不依賴專案內的 scripts/audit.sh"
(cd "$REPO" && git checkout -q main 2>/dev/null || git checkout -q master)
[ ! -e "$REPO/scripts/audit.sh" ] || rm -f "$REPO/scripts/audit.sh"
(cd "$REPO" && echo "4" > c && git add c)
check "專案沒有 scripts/audit.sh 時 commit 仍成功" '(cd "$REPO" && git commit -q -m "no audit copy" >/dev/null 2>&1)'

echo "▸ --install-git-hooks：既有 hook 備份並串接執行"
REPO2="$TMP/repo2"
mkdir -p "$REPO2"
(cd "$REPO2" && git init -q && git config user.email "test@example.com" && git config user.name "Test")
cat > "$REPO2/.git/hooks/pre-commit" <<EOF
#!/usr/bin/env bash
echo ran > "$TMP/user-pre-commit-ran"
EOF
cat > "$REPO2/.git/hooks/pre-push" <<EOF
#!/usr/bin/env bash
cat > "$TMP/user-pre-push-stdin"
EOF
chmod +x "$REPO2/.git/hooks/pre-commit" "$REPO2/.git/hooks/pre-push"

bash "$GUARD" --install-git-hooks "$REPO2" > "$TMP/install2.out"
check "既有 pre-commit 備份為 .agreements-bak" '[ -x "$REPO2/.git/hooks/pre-commit.agreements-bak" ]'
check "既有 pre-push 備份為 .agreements-bak" '[ -x "$REPO2/.git/hooks/pre-push.agreements-bak" ]'
check "安裝輸出提示已備份" 'grep -q "agreements-bak" "$TMP/install2.out"'

(cd "$REPO2" && echo "1" > a && git add a && git commit -q -m "init" >/dev/null 2>&1)
check "commit 時串接執行原本的 pre-commit" '[ -f "$TMP/user-pre-commit-ran" ]'

r2="$(cd "$REPO2" && git rev-parse HEAD)"
printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$r2" \
  | (cd "$REPO2" && bash .git/hooks/pre-push origin https://example.com) >/dev/null 2>&1
check "pre-push 串接執行原本的 hook 並轉交 stdin" 'grep -q "$r2" "$TMP/user-pre-push-stdin" 2>/dev/null'

printf '#!/usr/bin/env bash\nexit 0\n' > "$REPO2/.git/hooks/pre-push.agreements-bak"
big_input="$(for i in $(seq 1 2000); do printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$r2"; done)"
check "串接的 hook 不讀 stdin 時 pre-push 仍成功（無 SIGPIPE）" 'printf "%s\n" "$big_input" | (cd "$REPO2" && bash .git/hooks/pre-push origin https://example.com) >/dev/null 2>&1'
cat > "$REPO2/.git/hooks/pre-push.agreements-bak" <<EOF
#!/usr/bin/env bash
cat > "$TMP/user-pre-push-stdin"
EOF

bash "$GUARD" --install-git-hooks "$REPO2" > /dev/null
check "重複安裝不覆寫備份（備份仍是使用者原本的 hook）" 'grep -q "user-pre-commit-ran" "$REPO2/.git/hooks/pre-commit.agreements-bak"'

echo "▸ --install-git-hooks：git worktree 與 core.hooksPath"
WT="$TMP/wt"
(cd "$REPO" && git worktree add -q "$WT" -b wt-branch >/dev/null 2>&1)
rm -f "$HOOKS/pre-push" "$HOOKS/pre-commit"
check "在 worktree 裡安裝成功結束" 'bash "$GUARD" --install-git-hooks "$WT" > /dev/null 2>&1'
wt_hooks="$(cd "$WT" && cd "$(git rev-parse --git-path hooks)" && pwd)"
check "worktree 安裝寫入 git 實際使用的 hooks 目錄" '[ -x "$wt_hooks/pre-push" ] && [ -x "$wt_hooks/pre-commit" ]'

REPO3="$TMP/repo3"
mkdir -p "$REPO3"
(cd "$REPO3" && git init -q && git config core.hooksPath .githooks)
bash "$GUARD" --install-git-hooks "$REPO3" > /dev/null 2>&1
check "core.hooksPath 設定時寫入該目錄" '[ -x "$REPO3/.githooks/pre-push" ] && [ -x "$REPO3/.githooks/pre-commit" ]'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}"
[ "$fail" -eq 0 ]
