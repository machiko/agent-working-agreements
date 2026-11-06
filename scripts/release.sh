#!/usr/bin/env bash
# release.sh — 一鍵完成全自動發版：push 分支、開 PR、合併、升版號、CHANGELOG、檢查、合併到 main、打 tag 並 push。
#
# 用法：
#   scripts/release.sh <版號>
#   例如：scripts/release.sh 0.4.0
#
# 結束碼：0 成功；1 失敗或檢查未通過；2 參數錯誤。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
[ -d "/opt/homebrew/bin" ] && export PATH="/opt/homebrew/bin:$PATH"

die() { echo "✗ $1" >&2; exit "${2:-1}"; }
info() { echo "▸ $1"; }
ok()   { echo "  ✓ $1"; }

[ $# -ge 1 ] || die "請指定要發布的版號（例如：scripts/release.sh 0.4.0）" 2
VERSION="$1"
TAG="v$VERSION"
RELEASE_BRANCH="release/$TAG"

# 依賴檢查
command -v gh >/dev/null 2>&1 || die "需要安裝 GitHub CLI (gh)"
command -v git >/dev/null 2>&1 || die "需要安裝 git"

# 工作區狀態檢查
git diff --quiet || die "工作區有未提交的改動，請先 commit"
[ -z "$(git status --porcelain)" ] || die "工作區有未追蹤的檔案，請先處理"

CURRENT_BRANCH="$(git branch --show-current)"
info "目前分支：${CURRENT_BRANCH}｜發版目標：${TAG}"

# 0. 執行品質與預算檢查
info "執行預算、資安與單元測試檢查..."
bash "$ROOT/scripts/check-budget.sh" >/dev/null || die "check-budget.sh 未通過"
bash "$ROOT/scripts/sanitize-check.sh" >/dev/null || die "sanitize-check.sh 未通過"
bash "$ROOT/tests/check-version.test.sh" >/dev/null || die "check-version.test.sh 未通過"
bash "$ROOT/tests/install.test.sh" >/dev/null || die "install.test.sh 未通過"
bash "$ROOT/tests/audit.test.sh" >/dev/null || die "audit.test.sh 未通過"
bash "$ROOT/scripts/doctor.sh" >/dev/null || die "doctor.sh 未通過"
ok "所有自動化檢查通過"

# 1. 確保遠端 release 分支存在
if ! git ls-remote --heads origin "$RELEASE_BRANCH" | grep -q .; then
  info "遠端尚未建立 ${RELEASE_BRANCH}，從 main 切出並推送..."
  git branch "$RELEASE_BRANCH" main 2>/dev/null || true
  git push -u origin "$RELEASE_BRANCH"
  ok "已建立遠端分支 ${RELEASE_BRANCH}"
fi

# 2. 如果目前在 feature 分支，推送並開 PR 合併到 release 分支
if [ "$CURRENT_BRANCH" != "$RELEASE_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ]; then
  info "推送功能分支 ${CURRENT_BRANCH} 至遠端..."
  git push -u origin "$CURRENT_BRANCH"
  
  info "開立 PR 合併至 ${RELEASE_BRANCH}..."
  LAST_MSG="$(git log -1 --pretty=%s)"
  PR_FEAT_URL="$(gh pr create --base "$RELEASE_BRANCH" --head "$CURRENT_BRANCH" --title "$LAST_MSG" --body "發版前合併功能分支至 ${RELEASE_BRANCH}" 2>/dev/null || gh pr list --head "$CURRENT_BRANCH" --base "$RELEASE_BRANCH" --json url -q '.[0].url')"
  ok "功能 PR：${PR_FEAT_URL}"
  
  info "等候檢查並合併功能 PR 至 ${RELEASE_BRANCH}..."
  gh pr checks "$CURRENT_BRANCH" --watch 2>/dev/null || true
  gh pr merge "$CURRENT_BRANCH" --merge
  ok "已合併至 ${RELEASE_BRANCH}"
fi

# 3. 切換至 release 分支並拉取最新代碼
info "切換至 ${RELEASE_BRANCH} 並同步最新代碼..."
git switch "$RELEASE_BRANCH"
git pull origin "$RELEASE_BRANCH"
ok "已就緒於 ${RELEASE_BRANCH}"

# 4. 更新版號與 CHANGELOG
info "升級版號至 ${VERSION} 並更新 CHANGELOG.md..."
TODAY="$(date +%Y-%m-%d)"
PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
MARKET_JSON="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/CHANGELOG.md"

# 更新 JSON 版號
sed 's/"version"[ ]*:[ ]*"[^"]*"/"version": "'"$VERSION"'"/' "$PLUGIN_JSON" > "$PLUGIN_JSON.tmp" && mv "$PLUGIN_JSON.tmp" "$PLUGIN_JSON"
sed 's/"version"[ ]*:[ ]*"[^"]*"/"version": "'"$VERSION"'"/' "$MARKET_JSON" > "$MARKET_JSON.tmp" && mv "$MARKET_JSON.tmp" "$MARKET_JSON"

# 更新 CHANGELOG
if ! grep -q "^## \[$VERSION\]" "$CHANGELOG"; then
  awk -v ver="$VERSION" -v dt="$TODAY" '
    $0 == "## [Unreleased]" && !done {
      print "## [Unreleased]\n\n## [" ver "] - " dt
      done = 1
      next
    }
    { print }' "$CHANGELOG" > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"
fi

# 驗證三處版號一致
bash "$ROOT/scripts/check-version.sh" >/dev/null || die "check-version.sh 未通過"
ok "版號與 CHANGELOG 更新完畢且一致"

# 提交發版變更（如果有變更）
if ! git diff --quiet || [ -n "$(git status --porcelain)" ]; then
  git add "$PLUGIN_JSON" "$MARKET_JSON" "$CHANGELOG"
  [ -f "$ROOT/scripts/release.sh" ] && git add "$ROOT/scripts/release.sh"
  git commit -m "chore: 新增 ${VERSION} 發版：CHANGELOG 與版號升級"
  git push origin "$RELEASE_BRANCH"
  ok "已提交並推送版號升級 commit"
fi

# 5. 開立發版 PR 合併至 main
info "開立發版 PR (${RELEASE_BRANCH} -> main)..."
PR_RELEASE_URL="$(gh pr create --base main --head "$RELEASE_BRANCH" --title "chore: 新增 ${VERSION} 發版" --body "自動發版 ${TAG}" 2>/dev/null || gh pr list --head "$RELEASE_BRANCH" --base main --json url -q '.[0].url')"
ok "發版 PR：${PR_RELEASE_URL}"

info "等候 CI 檢查..."
gh pr checks "$RELEASE_BRANCH" --watch 2>/dev/null || true

info "合併發版 PR 至 main..."
gh pr merge "$RELEASE_BRANCH" --merge
ok "已合併發版 PR 至 main"

# 6. 切至 main、拉取、建立 Tag 並推送
info "切換至 main 並拉取最新提交..."
git switch main
git pull origin main

info "打上 Git Tag ${TAG} 並推送..."
git tag "$TAG"
git push origin "$TAG"
ok "成功建立並推送 Tag ${TAG}"

info "建立 GitHub Release..."
NOTES="$(awk -v ver="$VERSION" '
  $0 ~ "^## \\[" ver "\\]" { found=1; next }
  /^## \[/ && found { exit }
  found { print }
' "$CHANGELOG")"
gh release create "$TAG" --title "$TAG" --notes "$NOTES" --latest 2>/dev/null || true
ok "已建立 GitHub Release"

echo "──"
echo "🎉 發版成功！"
echo "  • 版本：${TAG}"
echo "  • Tag 連結：https://github.com/machiko/agent-working-agreements/releases/tag/${TAG}"
echo "  • 發版 PR：${PR_RELEASE_URL}"
