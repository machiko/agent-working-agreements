#!/usr/bin/env bash
# remote-install.sh — 免 clone 遠端一鍵安裝與部署 Agent Working Agreements。
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- <參數>
#
# 範例：
#   # Cursor 規則部署
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --cursor .cursor/rules
#
#   # Copilot 指示注入
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --copilot
#
#   # Windsurf 規則注入
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --windsurf
#
#   # 通用 Git Hooks 防護網安裝
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --git-hooks
#
#   # 技術棧智慧偵測
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --detect .

set -euo pipefail

REPO_TARBALL="https://github.com/machiko/agent-working-agreements/archive/refs/heads/main.tar.gz"
GIT_REPO="https://github.com/machiko/agent-working-agreements.git"

TMP_DIR="$(mktemp -d /tmp/agreements-remote.XXXXXX)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

# 取得最新規則與腳本
fetch_repo() {
  if [ -n "${AGREEMENTS_SOURCE_DIR:-}" ] && [ -d "$AGREEMENTS_SOURCE_DIR" ]; then
    cp -R "$AGREEMENTS_SOURCE_DIR"/* "$TMP_DIR/" 2>/dev/null && return 0
  fi
  if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    curl -fsSL "$REPO_TARBALL" | tar -xz -C "$TMP_DIR" --strip-components=1 2>/dev/null && return 0
  fi
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 -q "$GIT_REPO" "$TMP_DIR" 2>/dev/null && return 0
  fi
  echo "✗ 遠端安裝需要 curl 與 tar，或 git" >&2
  return 1
}

fetch_repo || exit 1

# 若使用者指定安裝 Git hooks
if [ "${1:-}" = "--git-hooks" ]; then
  shift
  bash "$TMP_DIR/scripts/hook-guard.sh" --install-git-hooks "$@"
  exit $?
fi

# 預設執行 install.sh
bash "$TMP_DIR/scripts/install.sh" "$@"
