#!/usr/bin/env bash
# team.test.sh — 團隊同步（install.sh --team-init／--sync、團隊守則、--check-drift）行為測試。
# 只寫入 /tmp 底下的暫存目錄；HOME 也指到暫存目錄，避免讀寫真正的家目錄。
set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/scripts/install.sh"
DOCTOR="$ROOT/scripts/doctor.sh"
TMP="$(cd "$(mktemp -d /tmp/aw-team-test.XXXXXX)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
git config --global user.email t@example.com; git config --global user.name t
VERSION="$(sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" | head -n 1)"

pass=0
fail=0
ok()  { echo "  ✓ $1"; pass=$((pass + 1)); }
bad() { echo "  ✗ $1" >&2; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

new_repo() {  # new_repo <名稱>：建立空 git repo 並印出路徑
  local d="$TMP/$1"
  mkdir -p "$d" && git -C "$d" init -q && git -C "$d" commit -q --allow-empty -m init
  echo "$d"
}

write_rule() {  # write_rule <repo> <name> [怎麼做]
  mkdir -p "$1/.agreements/rules"
  cat > "$1/.agreements/rules/$2.md" <<EOF
---
category: custom
tier: custom
label: "團隊守則 $2"
incidents:
  - "測試用事故"
last_reviewed: 2026-11-11
---

# 團隊守則 $2

## 條目 $2

- **症狀：** 壞結果。
- **根因：** 原因。
- **怎麼做：** ${3:-執行指令前確認目標。}
EOF
}

snapshot() {  # snapshot <repo>：守則檔與策略檔的雜湊清單（不含 .git）
  (cd "$1" && find . -path ./.git -prune -o -type f -print | sort | xargs shasum -a 256 2>/dev/null || true)
}

body() {  # body <檔案>：去掉 frontmatter 與開頭空行
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } fm { next }
       !s && $0 == "" { next } { s = 1; print }' "$1"
}

echo "▸ --team-init --dry-run 不寫入"
R="$(new_repo dry)"
bash "$INSTALL" --team-init "$R" --targets claude --dry-run > "$TMP/out" 2>&1
check "dry-run 結束碼 0" '[ $? -eq 0 ]'
check "dry-run 沒有產生策略檔" '[ ! -f "$R/.agreements.json" ]'
check "dry-run 列出會安裝的目標" 'grep -q "＋ .claude/rules/agent-agreements" "$TMP/out"'

echo "▸ --team-init 一條指令導入"
R="$(new_repo init)"
bash "$INSTALL" --team-init "$R" --targets claude,cursor,agents-md > "$TMP/out" 2>&1
rc=$?
check "結束碼 0" '[ $rc -eq 0 ]'
check "產生策略檔" '[ -f "$R/.agreements.json" ]'
check "策略檔記錄 targets" 'grep -q "\"targets\": \[\"claude\", \"cursor\", \"agents-md\"\]" "$R/.agreements.json"'
check "策略檔鎖定目前版本" 'grep -q "\"agreements_version\": \"$VERSION\"" "$R/.agreements.json"'
check "策略檔符合 schema" '"$ROOT/scripts/check-schema.sh" "$R/.agreements.json" >/dev/null 2>&1'
check "產生團隊守則 README" '[ -f "$R/.agreements/rules/README.md" ]'
check "安裝 Claude Code 目標" '[ -f "$R/.claude/rules/agent-agreements/.agreements-profile" ]'
check "安裝 Cursor 目標" '[ -f "$R/.cursor/rules/.agreements-profile" ]'
check "安裝 AGENTS.md 目標" 'grep -q "^<!-- agent-agreements:start" "$R/AGENTS.md"'
check "安裝 pre-push hook" '[ -x "$R/.git/hooks/pre-push" ]'
check "安裝防漂移 CI 工作流" '[ -f "$R/.github/workflows/agent-agreements-drift.yml" ]'
check "列出成員要執行的同步指令" 'grep -q "bash -s -- --sync" "$TMP/out"'
check "README 不會被當成守則安裝" '[ ! -e "$R/.claude/rules/agent-agreements/custom/README.md" ]'
check "導入後 --check-drift 通過" 'bash "$DOCTOR" --check-drift "$R" >/dev/null 2>&1'

bash "$INSTALL" --team-init "$R" > "$TMP/out" 2>&1
check "已有策略檔時拒絕重複導入（結束碼 2）" '[ $? -eq 2 ] && grep -q "已有團隊策略檔" "$TMP/out"'

echo "▸ --sync 冪等"
before="$(snapshot "$R")"
bash "$INSTALL" --sync "$R" > "$TMP/out" 2>&1
check "第二次同步顯示沒有變更" 'grep -q "已同步，沒有變更" "$TMP/out"'
check "第二次同步沒有改任何檔案" '[ "$before" = "$(snapshot "$R")" ]'

echo "▸ 團隊守則跨 Agent 一致"
write_rule "$R" no-prod-db
bash "$DOCTOR" --check-drift "$R" > "$TMP/out" 2>&1
check "新增團隊守則但沒同步：--check-drift 失敗" '[ $? -eq 1 ] && grep -q "缺少團隊守則：custom/no-prod-db" "$TMP/out"'
bash "$INSTALL" --sync "$R" > "$TMP/out" 2>&1
check "同步後每個目標都新增團隊守則" '[ "$(grep -c "新增 custom/no-prod-db" "$TMP/out")" -eq 3 ]'
src_body="$(body "$R/.agreements/rules/no-prod-db.md")"
check "Claude Code 內容與來源一致" '[ "$(cat "$R/.claude/rules/agent-agreements/custom/no-prod-db.md")" = "$(cat "$R/.agreements/rules/no-prod-db.md")" ]'
check "Cursor 本文與來源一致" '[ "$(body "$R/.cursor/rules/custom/no-prod-db.mdc")" = "$src_body" ]'
check "AGENTS.md 區塊與來源一致" '[ "$(awk "/^<!-- rule: custom\/no-prod-db -->\$/{on=1;next} on&&/^<!-- (rule: |agent-agreements:end)/{exit} on" "$R/AGENTS.md" | sed -e :a -e "/^\n*\$/{\$d;N;ba" -e "}")" = "$src_body" ]'
bash "$INSTALL" --target "$R/.claude/rules/agent-agreements" --status > "$TMP/status" 2>&1
check "--status 另列團隊守則分組" 'grep -q "^團隊守則（1 個）" "$TMP/status"'
check "同步後 --check-drift 通過" 'bash "$DOCTOR" --check-drift "$R" >/dev/null 2>&1'

write_rule "$R" no-prod-db "改過的做法。"
bash "$DOCTOR" --check-drift "$R" > "$TMP/out" 2>&1
check "改了團隊守則沒同步：--check-drift 失敗" '[ $? -eq 1 ] && grep -q "團隊守則與 .agreements/rules 不一致" "$TMP/out"'
bash "$INSTALL" --sync "$R" >/dev/null 2>&1
check "同步更新後 --check-drift 通過" 'bash "$DOCTOR" --check-drift "$R" >/dev/null 2>&1'

echo "x" >> "$R/.cursor/rules/custom/no-prod-db.mdc"
bash "$DOCTOR" --check-drift "$R" > "$TMP/out" 2>&1
check "手動改掉已安裝的團隊守則：--check-drift 失敗" '[ $? -eq 1 ] && grep -q "cursor" "$TMP/out"'
bash "$INSTALL" --cursor "$R/.cursor/rules" --update --force >/dev/null 2>&1

rm "$R/.agreements/rules/no-prod-db.md"
bash "$DOCTOR" --check-drift "$R" > "$TMP/out" 2>&1
check "刪掉團隊守則沒同步：--check-drift 失敗" '[ $? -eq 1 ] && grep -q "已從 .agreements/rules 移除" "$TMP/out"'
bash "$INSTALL" --sync "$R" > "$TMP/out" 2>&1
check "同步會移除已刪掉的團隊守則" '[ "$(grep -c "移除 custom/no-prod-db" "$TMP/out")" -eq 3 ]'
check "移除後 --check-drift 通過" 'bash "$DOCTOR" --check-drift "$R" >/dev/null 2>&1'

echo "▸ 策略檔強制團隊守則"
R2="$(new_repo enforce)"
printf '{ "preset": "core", "enforce_rules": ["custom/must-have"], "targets": ["claude"] }\n' > "$R2/.agreements.json"
bash "$INSTALL" --target "$R2/.claude/rules/agent-agreements" > "$TMP/out" 2>&1
check "強制的團隊守則沒有來源檔：安裝失敗並說明" '[ $? -eq 2 ] && grep -q "找不到團隊守則 .agreements/rules/must-have.md" "$TMP/out"'
bash "$DOCTOR" --check-drift "$R2" > "$TMP/out" 2>&1
check "強制的團隊守則沒有來源檔：--check-drift 失敗" '[ $? -eq 1 ] && grep -q "custom/must-have" "$TMP/out"'
write_rule "$R2" must-have
bash "$INSTALL" --sync "$R2" >/dev/null 2>&1
check "補上來源檔後同步，--check-drift 通過" 'bash "$DOCTOR" --check-drift "$R2" >/dev/null 2>&1'

echo "▸ 團隊守則檔名與品質提示"
write_rule "$R2" Bad_Name
printf -- '---\ncategory: custom\ntier: custom\n---\n\n# 品質不足\n\n## 條目\n\n盡量小心。\n' > "$R2/.agreements/rules/weak.md"
bash "$INSTALL" --sync "$R2" > "$TMP/out" 2>&1
check "不合法檔名略過並警告" 'grep -q "略過團隊守則.*Bad_Name.md" "$TMP/out" && [ ! -e "$R2/.claude/rules/agent-agreements/custom/Bad_Name.md" ]'
check "品質問題只提示、不擋同步" 'grep -q "團隊守則品質（只提示" "$TMP/out" && grep -q "空泛用語「盡量」" "$TMP/out" && [ -f "$R2/.claude/rules/agent-agreements/custom/weak.md" ]'

echo "▸ 版本鎖定"
R3="$(new_repo pin)"
printf '{ "targets": ["claude"], "agreements_version": "0.0.1" }\n' > "$R3/.agreements.json"
bash "$INSTALL" --sync "$R3" > "$TMP/out" 2>&1
check "版本不符時 --sync 結束碼 1" '[ $? -eq 1 ]'
check "版本不符時說明對齊與升級方法" 'grep -q "團隊鎖定 v0.0.1" "$TMP/out" && grep -q "agreements_version 改成" "$TMP/out"'
check "版本不符時不寫入任何守則" '[ ! -e "$R3/.claude" ]'
printf '{ "targets": ["claude"], "agreements_version": "%s" }\n' "$VERSION" > "$R3/.agreements.json"
bash "$INSTALL" --sync "$R3" >/dev/null 2>&1
sed -i.bak 's/^version=.*/version=0.0.1/' "$R3/.claude/rules/agent-agreements/.agreements-profile"
bash "$DOCTOR" --check-drift "$R3" > "$TMP/out" 2>&1
check "安裝版本與鎖定版本不符：--check-drift 失敗" '[ $? -eq 1 ] && grep -q "安裝版本應為 $VERSION" "$TMP/out"'

echo "▸ 舊策略檔與錯誤情境"
R4="$(new_repo legacy)"
bash "$INSTALL" --sync "$R4" > "$TMP/out" 2>&1
check "沒有策略檔：結束碼 2 並指向 --team-init" '[ $? -eq 2 ] && grep -q "team-init" "$TMP/out"'
printf '{ "preset": "core" }\n' > "$R4/.agreements.json"
bash "$INSTALL" --sync "$R4" > "$TMP/out" 2>&1
check "沒有 targets 也沒安裝過：結束碼 2 並說明" '[ $? -eq 2 ] && grep -q "targets" "$TMP/out"'
bash "$INSTALL" --agents-md "$R4/AGENTS.md" >/dev/null 2>&1
bash "$INSTALL" --sync "$R4" > "$TMP/out" 2>&1
check "沒有 targets 時沿用已安裝的目標" '[ $? -eq 0 ] && grep -q "沿用已安裝的目標：agents-md" "$TMP/out"'

echo "▸ 唯讀來源也能更新"
R5="$(new_repo readonly)"
printf '{ "preset": "core", "targets": ["claude"] }\n' > "$R5/.agreements.json"
write_rule "$R5" ro
chmod 444 "$R5/.agreements/rules/ro.md"
bash "$INSTALL" --sync "$R5" >/dev/null 2>&1
chmod 644 "$R5/.agreements/rules/ro.md"; write_rule "$R5" ro "新的做法。"; chmod 444 "$R5/.agreements/rules/ro.md"
bash "$INSTALL" --sync "$R5" > "$TMP/out" 2>&1
check "來源唯讀時第二次同步仍成功更新" '[ $? -eq 0 ] && grep -q "新的做法" "$R5/.claude/rules/agent-agreements/custom/ro.md"'

echo "▸ 審查回饋的回歸測試"
R6="$(new_repo traversal)"
echo "secret" > "$R6/CLAUDE.md"
printf '{ "preset": "core", "enforce_rules": ["custom/../../CLAUDE"], "targets": ["claude"] }\n' > "$R6/.agreements.json"
bash "$INSTALL" --sync "$R6" > "$TMP/out" 2>&1
check "custom/../.. 路徑穿越：同步失敗並說明名稱不合法" '[ $? -eq 1 ] && grep -q "名稱不合法" "$TMP/out"'
check "custom/../.. 路徑穿越：沒有寫到安裝目錄外" '[ ! -e "$R6/.claude/rules/CLAUDE.md" ] && [ "$(cat "$R6/CLAUDE.md")" = "secret" ]'
bash "$INSTALL" --target "$R6/.claude/rules/agent-agreements" --select "custom/../../CLAUDE" --policy /dev/null > "$TMP/out" 2>&1
check "--select custom/../.. 也被擋下" '[ $? -ne 0 ] && [ ! -e "$R6/.claude/rules/CLAUDE.md" ]'

R7="$(new_repo smart)"
printf '{ "dependencies": { "openai": "4.0.0" } }\n' > "$R7/package.json"
bash "$INSTALL" --team-init "$R7" --targets "claude, agents-md" --no-ci > "$TMP/out" 2>&1
check "--targets 的空白會去掉" 'grep -q "\"targets\": \[\"claude\", \"agents-md\"\]" "$R7/.agreements.json"'
check "smart 方案在 sync 時偵測專案根目錄（claude）" '[ -f "$R7/.claude/rules/agent-agreements/ai/pitfalls.md" ]'
check "smart 方案在 sync 時偵測專案根目錄（AGENTS.md）" 'grep -q "^<!-- rule: ai/pitfalls -->" "$R7/AGENTS.md"'
check "沒有 scripts/audit.sh 時同步會複製一份給 pre-commit 用" '[ -x "$R7/scripts/audit.sh" ]'
sed -i.bak 's/"preset": "smart"/"preset": "full"/' "$R7/.agreements.json"
bash "$INSTALL" --sync "$R7" >/dev/null 2>&1
check "策略檔改 preset 後 --sync 會生效" '[ -f "$R7/.claude/rules/agent-agreements/database/pitfalls.md" ]'
sed -i.bak 's/"preset": "full"/"preset": "core"/' "$R7/.agreements.json"
bash "$INSTALL" --sync "$R7" >/dev/null 2>&1
check "改回 core 後 --sync 移除多出來的守則" '[ ! -e "$R7/.claude/rules/agent-agreements/database/pitfalls.md" ]'
mkdir -p "$R7/.agreements/rules"; echo "# 說明" > "$R7/.agreements/rules/readme.md"
bash "$INSTALL" --sync "$R7" >/dev/null 2>&1
check "小寫 readme.md 不算團隊守則（--check-drift 通過）" 'bash "$DOCTOR" --check-drift "$R7" >/dev/null 2>&1'

write_rule "$R7" leak-check
(cd "$R7" && bash "$INSTALL" --target "$HOME/.claude/rules/agent-agreements" > "$TMP/out" 2>&1)
check "在團隊 repo 內做全域安裝：不帶入團隊守則" '[ ! -e "$HOME/.claude/rules/agent-agreements/custom/leak-check.md" ]'
rm -rf "$HOME/.claude"

R8="$(new_repo pinned-url)"
bash "$INSTALL" --team-init "$R8" --targets claude > "$TMP/out" 2>&1
check "防漂移工作流的遠端腳本釘在目前版本的 tag" 'grep -q "agent-working-agreements/v$VERSION/scripts/remote-install.sh" "$R8/.github/workflows/agent-agreements-drift.yml"'
check "給成員的同步指令釘在目前版本的 tag" 'grep -q "agent-working-agreements/v$VERSION/scripts/remote-install.sh | bash -s -- --sync" "$TMP/out"'

echo "▸ remote-install.sh 轉發 --check-drift"
AGREEMENTS_SOURCE_DIR="$ROOT" bash "$ROOT/scripts/remote-install.sh" --check-drift "$R2" > "$TMP/out" 2>&1
check "--check-drift 轉給 doctor.sh" 'grep -q "CI 防漂移檢驗" "$TMP/out"'
AGREEMENTS_SOURCE_DIR="$ROOT" bash "$ROOT/scripts/remote-install.sh" --version 1.x --sync > "$TMP/out" 2>&1
check "--version 格式錯誤時結束碼 2" '[ $? -eq 2 ] && grep -q "版本號格式不對" "$TMP/out"'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
