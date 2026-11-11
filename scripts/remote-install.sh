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
#
#   # 團隊成員同步（依 .agreements.json 的 agreements_version 下載對應版本）
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --sync
#
#   # CI 防漂移檢查（同樣依 agreements_version 下載對應版本）
#   curl -fsSL https://raw.githubusercontent.com/machiko/agent-working-agreements/main/scripts/remote-install.sh | bash -s -- --check-drift .
#
#   --version <X.Y.Z>  下載指定版本（tag vX.Y.Z）；沒指定時，--sync 與 --check-drift 依策略檔的 agreements_version，
#                      其他指令用 main。設定 AGREEMENTS_SOURCE_DIR 時改用該目錄（測試用），不下載。

set -euo pipefail

REPO_TARBALL="https://github.com/machiko/agent-working-agreements/archive/refs/heads/main.tar.gz"
REPO_TAG_TARBALL="https://github.com/machiko/agent-working-agreements/archive/refs/tags"
GIT_REPO="https://github.com/machiko/agent-working-agreements.git"

TMP_DIR="$(mktemp -d /tmp/agreements-remote.XXXXXX)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

# 解析 --version；--sync／--check-drift 沒指定版本時讀策略檔的 agreements_version
want_version=""
args=()
mode_arg=""
while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      [ $# -ge 2 ] || { echo "✗ --version 需要版本號，例如 1.6.0" >&2; exit 2; }
      want_version="${2#v}"; shift 2 ;;
    *)
      case "$1" in --sync|--check-drift) [ -z "$mode_arg" ] && mode_arg="$1" ;; esac
      args+=("$1"); shift ;;
  esac
done
set -- ${args[@]+"${args[@]}"}

# pinned_version <起點>：往上找到 git root 為止的 .agreements.json，印出 agreements_version
pinned_version() {
  local d top
  d="$(cd "${1:-.}" 2>/dev/null && pwd -P)" || return 0
  top="$(cd "$d" && git rev-parse --show-toplevel 2>/dev/null || echo "$d")"
  while :; do
    if [ -f "$d/.agreements.json" ]; then
      tr '\n' ' ' < "$d/.agreements.json" | sed -n 's/.*"agreements_version"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p'
      return 0
    fi
    [ "$d" = "$top" ] || [ "$d" = "/" ] && return 0
    d="$(dirname "$d")"
  done
}

if [ -z "$want_version" ] && [ -n "$mode_arg" ]; then
  start="."
  # --sync <dir> 或 --check-drift <dir>：從指定目錄開始找策略檔
  for a in "$@"; do case "$a" in -*) ;; *) start="$a"; break ;; esac; done
  want_version="$(pinned_version "$start")"
fi
if [ -n "$want_version" ] && ! printf '%s' "$want_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'; then
  echo "✗ 版本號格式不對：${want_version}（例如 1.6.0）" >&2
  exit 2
fi

# 取得規則與腳本（有指定版本就抓該 tag，否則抓 main）
fetch_repo() {
  if [ -n "${AGREEMENTS_SOURCE_DIR:-}" ] && [ -d "$AGREEMENTS_SOURCE_DIR" ]; then
    cp -R "$AGREEMENTS_SOURCE_DIR"/* "$TMP_DIR/" 2>/dev/null && return 0
  fi
  local url="$REPO_TARBALL" ref=()
  if [ -n "$want_version" ]; then
    url="$REPO_TAG_TARBALL/v${want_version}.tar.gz"; ref=(--branch "v${want_version}")
    echo "▸ 下載 agent-working-agreements v${want_version}" >&2
  fi
  if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    curl -fsSL "$url" | tar -xz -C "$TMP_DIR" --strip-components=1 2>/dev/null && return 0
  fi
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 -q ${ref[@]+"${ref[@]}"} "$GIT_REPO" "$TMP_DIR" 2>/dev/null && return 0
  fi
  [ -n "$want_version" ] && echo "✗ 下載 v${want_version} 失敗：確認版本號存在（https://github.com/machiko/agent-working-agreements/releases）" >&2 && return 1
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

if [ "${1:-}" = "--check-drift" ]; then
  shift
  bash "$TMP_DIR/scripts/doctor.sh" --check-drift "$@"
  exit $?
fi

# 預設執行 install.sh
bash "$TMP_DIR/scripts/install.sh" "$@"
