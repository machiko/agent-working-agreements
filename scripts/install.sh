#!/usr/bin/env bash
# install.sh — 依選擇把規則檔安裝到目標目錄，並以 profile 記錄，可重跑調整或移除。
#
# 用法：
#   install.sh --list
#   install.sh --detect [dir]
#   install.sh --target <dir> [--select id1,id2] [--dry-run] [--force]
#   install.sh --target <dir> --uninstall [--dry-run] [--force]
#   install.sh --cursor <dir> [--select id1,id2] [--dry-run] [--force]
#   install.sh --cursor <dir> --uninstall [--dry-run] [--force]
#   install.sh --agents-md <file> [--select id1,id2] [--dry-run]
#   install.sh --agents-md <file> --uninstall [--dry-run]
#   install.sh --copilot [file] [--select id1,id2] [--dry-run]
#   install.sh --windsurf [file] [--select id1,id2] [--dry-run]
#   install.sh --ci [platform] [dir] [--dry-run]
#   install.sh --target <dir> --status
#   install.sh --cursor <dir> --status
#   install.sh --agents-md <file> --status
#
#   --target    安裝目錄，例如 ~/.claude/rules/agent-agreements 或 <專案>/.claude/rules/agent-agreements
#   --cursor    Cursor 規則目錄（產出 .mdc 檔），例如 .cursor/rules
#   --agents-md 寫入 AGENTS.md（Codex 等）：只改 agent-agreements 標記區塊，區塊外內容不動
#   --copilot   寫入 GitHub Copilot 指示（預設 .github/copilot-instructions.md），以標記區塊注入
#   --windsurf  寫入 Windsurf 規則（預設 .windsurfrules），以標記區塊注入
#   --ci        安裝 CI/CD 守門工作流（支援 github、gitlab、bitbucket、pre-commit，預設智慧自動偵測）
#   --select    要加裝的 optional 規則 id（逗號分隔，例如 writing/changelog,frontend/pitfalls）；core 一律安裝
#   --dry-run   只列出會做的變更，不寫入
#   --force     覆蓋或移除已被手動修改的檔案
#   --uninstall 只移除 profile 記錄的檔案，不碰目錄內其他檔案
#   --status    唯讀：依 core／選擇的規則分組列出已安裝規則的標題、載入方式與狀態
#               （最新、有新版、已手動修改、檔案遺失、來源已移除）；不能搭配其他選項
#   --list      列出所有規則：id、tier、stack、是否按需載入、本文行數、選項名稱、說明（以 tab 分隔）
#   --detect    自動掃描專案特徵並列出推薦的 optional 規則（以 tab 分隔 id 與推薦原因）
#
#   環境變數 AGENTS_MD_MAX_BYTES：AGENTS.md 大小警告門檻（預設 32768，Codex project_doc_max_bytes 預設值）
#
# 結束碼：0 成功；2 參數錯誤。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES="$ROOT/rules"
PROFILE_NAME=".agreements-profile"

target=""
cursor_dir=""
agents_md=""
copilot_file=""
windsurf_file=""
ci_dir=""
ci_platform=""
detect_dir=""
select_ids=""
dry_run=0
force=0
status=0
mode="install"

die() { echo "✗ $1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target) [ $# -ge 2 ] || die "--target 需要目錄"; target="$2"; shift 2 ;;
    --cursor) [ $# -ge 2 ] || die "--cursor 需要目錄"; cursor_dir="$2"; shift 2 ;;
    --agents-md) [ $# -ge 2 ] || die "--agents-md 需要檔案路徑"; agents_md="$2"; shift 2 ;;
    --copilot)
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        copilot_file="$2"; shift 2
      else
        copilot_file=".github/copilot-instructions.md"; shift
      fi
      ;;
    --windsurf)
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        windsurf_file="$2"; shift 2
      else
        windsurf_file=".windsurfrules"; shift
      fi
      ;;
    --ci)
      ci_dir="."
      shift
      while [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; do
        case "$1" in
          github|gitlab|bitbucket|pre-commit)
            ci_platform="$1"; shift ;;
          *)
            ci_dir="$1"; shift ;;
        esac
      done
      ;;
    --select) [ $# -ge 2 ] || die "--select 需要規則 id"; select_ids="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --uninstall) mode="uninstall"; shift ;;
    --list) mode="list"; shift ;;
    --detect)
      mode="detect"
      shift
      if [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; then
        detect_dir="$1"
        shift
      fi
      ;;
    --status) status=1; shift ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) die "未知參數：$1" ;;
  esac
done

if [ "$status" -eq 1 ]; then
  [ "$mode" = "install" ] && [ -z "$select_ids" ] && [ "$dry_run" -eq 0 ] && [ "$force" -eq 0 ] \
    || die "--status 不能搭配 --select、--uninstall、--list、--detect、--dry-run 或 --force"
  mode="status"
fi

# ── 共用函式 ────────────────────────────────────────────

sha() {
  if [ $# -ge 1 ]; then
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
    else sha256sum "$1" | cut -d' ' -f1; fi
  else
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d' ' -f1
    else sha256sum | cut -d' ' -f1; fi
  fi
}

# frontmatter 單行欄位值（與 check-budget.sh 相同的解析方式）
field() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, key ":") == 1 { sub("^" key ":[ ]*", ""); print; exit }' "$1"
}

has_paths() {
  awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } /^(paths|globs):/ { found = 1 } END { exit !found }' "$1"
}

body_lines() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { n++ } END { print n + 0 }' "$1"
}

# 去掉 YAML 字串外層的雙引號
unquote() { sed -e 's/^"//' -e 's/"$//'; }

title() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm && /^# / { sub(/^# /, ""); print; exit }' "$1"
}

all_ids() {
  find "$RULES" -type f -name '*.md' | sed -e "s#^$RULES/##" -e 's#\.md$##' | sort
}

version() {
  sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1
}

contains() { printf '%s\n' "$1" | grep -Fxq -- "$2"; }

# frontmatter 的 paths 清單，以「, 」串起來
paths_of() {
  awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
       /^(paths|globs):/ { on = 1; next } on && /^[ ]+- / { sub(/^[ ]+- [ ]*/, ""); gsub(/^"|"$/, ""); out = out (out == "" ? "" : ", ") $0; next }
       on { on = 0 } END { print out }' "$1"
}

# 產出 Cursor IDE 規範的 .mdc 規則內容
cursor_content() {
  local src="$1" desc
  desc="$(field "$src" label | unquote)"
  [ -z "$desc" ] && desc="$(title "$src")"
  echo "---"
  echo "description: \"$desc\""
  if has_paths "$src"; then
    echo "globs:"
    awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
         /^(paths|globs):/ { on = 1; next } on && /^[ ]+- / { print; next }
         on { on = 0 }' "$src"
    echo "alwaysApply: false"
  else
    echo "alwaysApply: true"
  fi
  echo "---"
  echo
  strip_body "$src"
}

# with_title <id> <顯示名稱>：來源規則有標題就印「<顯示名稱> — <標題>」，否則只印顯示名稱
with_title() {
  local t=""
  [ -f "$RULES/$1.md" ] && t="$(title "$RULES/$1.md")"
  if [ -n "$t" ]; then printf '%s — %s' "$2" "$t"; else printf '%s' "$2"; fi
}

START_RE='^<!-- agent-agreements:start'
END_LINE='<!-- agent-agreements:end -->'

# 去掉 frontmatter 與本文開頭的空行
strip_body() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } fm { next }
       !started && $0 == "" { next } { started = 1; print }' "$1"
}

# 區塊內某條規則的段落（到下一條規則或結束標記為止）
section() {
  awk -v id="$1" -v end="$END_LINE" '
    $0 == "<!-- rule: " id " -->" { on = 1; next }
    on && (index($0, "<!-- rule: ") == 1 || $0 == end) { exit }
    on { print }' "$2"
}

# ── --status 共用 ──────────────────────────────────────

# rule_record <id> <標題> <讀 paths 的檔案，空字串代表一律常駐> <狀態> <載入行數>
# 輸出一筆以 US（\037）分隔的紀錄：id、tier、標題、載入方式、狀態、行數、是否按需載入。
# 不用 tab：tab 屬於 IFS 空白字元，read 會把連續的 tab 合併，空欄位（例如沒有標題）後面就整列錯位。
US=$'\037'
rule_record() {
  local tier="optional" load="常駐" od=0
  [ -f "$RULES/$1.md" ] && tier="$(field "$RULES/$1.md" tier)"
  if [ -n "$3" ] && [ -f "$3" ] && has_paths "$3"; then
    load="按需載入（$(paths_of "$3")）"; od=1
  fi
  printf "%s${US}%s${US}%s${US}%s${US}%s${US}%s${US}%s\n" "$1" "$tier" "$2" "$load" "$4" "$5" "$od"
}

print_rule() {  # print_rule <id> <標題> <載入方式> <狀態>
  local name="$1"
  [ -n "$2" ] && name="$1 — $2"
  printf '  %s｜%s｜%s\n' "$name" "$3" "$4"
}

# 讀 rule_record 的紀錄，分 core／選擇的規則兩組印出，最後一行是行數與規則總數
report_status() {
  local records rows group label n always=0 ondemand=0 total=0
  records="$(cat)"
  for group in core selected; do
    if [ "$group" = "core" ]; then
      label="core"; rows="$(printf '%s\n' "$records" | awk -F"$US" '$2 == "core"')"
    else
      label="選擇的規則"; rows="$(printf '%s\n' "$records" | awk -F"$US" 'NF && $2 != "core"')"
    fi
    n="$(printf '%s\n' "$rows" | grep -c . || true)"
    echo "${label}（${n} 個）"
    [ "$n" -eq 0 ] && echo "  （無）"
    while IFS="$US" read -r id _tier t load st lines od; do
      [ -n "$id" ] || continue
      print_rule "$id" "$t" "$load" "$st"
      if [ "$od" -eq 1 ]; then ondemand=$((ondemand + lines)); else always=$((always + lines)); fi
      total=$((total + 1))
    done <<< "$rows"
  done
  echo "常駐：${always} 行｜按需載入：${ondemand} 行｜共 ${total} 個規則"
}

# ── --list ─────────────────────────────────────────────

if [ "$mode" = "list" ]; then
  for id in $(all_ids); do
    f="$RULES/$id.md"
    stack="$(field "$f" stack)"
    scoped="always"; has_paths "$f" && scoped="on-demand"
    label="$(field "$f" label | unquote)"
    summary="$(field "$f" summary | unquote)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$(field "$f" tier)" "${stack:--}" "$scoped" "$(body_lines "$f")" "${label:-$(title "$f")}" "${summary:--}"
  done
  exit 0
fi

# ── 別名相容對應 ───────────────────────────────────────
alias_id() {
  case "$1" in
    vue/pitfalls) echo "frontend/pitfalls" ;;
    laravel/pitfalls) echo "backend/pitfalls" ;;
    docker/pitfalls) echo "container/pitfalls" ;;
    *) echo "$1" ;;
  esac
}

# ── --detect ───────────────────────────────────────────

if [ "$mode" = "detect" ]; then
  dir="${detect_dir:-.}"
  case "$dir" in "~"/*) dir="$HOME/${dir#\~/}" ;; esac
  [ -d "$dir" ] || die "目錄不存在：$dir"

  # 1. 資料庫特徵
  if [ -d "$dir/migrations" ] || [ -d "$dir/migration" ] || [ -d "$dir/prisma" ] || [ -d "$dir/alembic" ] || [ -d "$dir/db/migrate" ] || [ -d "$dir/schema" ] || [ -f "$dir/schema.prisma" ] || [ -f "$dir/alembic.ini" ] || find "$dir" -maxdepth 2 -type f -name '*.sql' 2>/dev/null | grep -q .; then
    printf 'database/pitfalls\t偵測到資料庫遷移、schema 或 SQL 檔案\n'
  fi

  # 2. API 特徵
  if [ -d "$dir/controllers" ] || [ -d "$dir/controller" ] || [ -d "$dir/handlers" ] || [ -d "$dir/handler" ] || [ -d "$dir/routes" ] || [ -d "$dir/route" ] || [ -d "$dir/api" ] || [ -d "$dir/src/routes" ] || [ -d "$dir/src/controllers" ] || [ -d "$dir/src/handlers" ]; then
    printf 'api/pitfalls\t偵測到 API 路由或控制器目錄\n'
  fi

  # 3. 現代前端與組件化特徵
  if [ -f "$dir/vite.config.js" ] || [ -f "$dir/vite.config.ts" ] || [ -f "$dir/next.config.js" ] || [ -f "$dir/next.config.mjs" ] || [ -f "$dir/next.config.ts" ] || [ -f "$dir/nuxt.config.ts" ] || [ -f "$dir/nuxt.config.js" ] || [ -f "$dir/svelte.config.js" ] || find "$dir" -maxdepth 3 -type f \( -name '*.vue' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.svelte' \) 2>/dev/null | grep -q . || { [ -f "$dir/package.json" ] && grep -qiE '"(react|vue|svelte|next|nuxt|vite|tailwindcss)"' "$dir/package.json" 2>/dev/null; }; then
    printf 'frontend/pitfalls\t偵測到現代前端組件 (React/Vue/Svelte) 或建構工具\n'
  fi

  # 4. Web 後端與應用服務特徵
  if [ -f "$dir/artisan" ] || [ -f "$dir/composer.json" ] || [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/Pipfile" ] || [ -f "$dir/go.mod" ] || [ -f "$dir/Cargo.toml" ] || [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ] || { [ -f "$dir/package.json" ] && grep -qiE '"(express|nestjs|fastify|koa|hono|hapi)"' "$dir/package.json" 2>/dev/null; }; then
    printf 'backend/pitfalls\t偵測到 Web 後端應用架構或依賴\n'
  fi

  # 5. 容器與本機虛擬化特徵
  if [ -f "$dir/Dockerfile" ] || [ -f "$dir/Containerfile" ] || [ -f "$dir/docker-compose.yml" ] || [ -f "$dir/docker-compose.yaml" ] || [ -f "$dir/compose.yml" ] || [ -f "$dir/compose.yaml" ] || [ -f "$dir/.dockerignore" ] || [ -d "$dir/nginx" ]; then
    printf 'container/pitfalls\t偵測到容器設定檔 (Dockerfile/Compose/Containerfile)\n'
  fi

  # 6. 異步/佇列/快取特徵
  if [ -d "$dir/jobs" ] || [ -d "$dir/job" ] || [ -d "$dir/queues" ] || [ -d "$dir/queue" ] || [ -d "$dir/workers" ] || [ -d "$dir/worker" ] || [ -d "$dir/tasks" ] || [ -d "$dir/src/jobs" ] || [ -d "$dir/src/queues" ] || [ -d "$dir/src/workers" ] || [ -d "$dir/src/tasks" ] || { [ -f "$dir/package.json" ] && grep -qiE '"(bull|bullmq|redis|ioredis|celery|sidekiq)"' "$dir/package.json" 2>/dev/null; } || { [ -f "$dir/composer.json" ] && grep -qiE '"(predis/predis|redis)"' "$dir/composer.json" 2>/dev/null; }; then
    printf 'async/pitfalls\t偵測到佇列、Worker 或快取相關目錄或依賴\n'
  fi

  # 7. 雲原生、日誌與可觀測性特徵
  if [ -d "$dir/k8s" ] || [ -d "$dir/helm" ] || [ -d "$dir/terraform" ] || [ -d "$dir/.k8s" ] || find "$dir" -maxdepth 3 -type f \( -name '*telemetry*' -o -name '*otel*' -o -name '*logger*' \) 2>/dev/null | grep -q . || { [ -f "$dir/package.json" ] && grep -qiE '"(@opentelemetry|winston|pino|prom-client|datadog)"' "$dir/package.json" 2>/dev/null; } || { [ -f "$dir/go.mod" ] && grep -qiE '(prometheus|opentelemetry|zap|zerolog)' "$dir/go.mod" 2>/dev/null; } || { [ -f "$dir/requirements.txt" ] && grep -qiE '(prometheus|opentelemetry|structlog)' "$dir/requirements.txt" 2>/dev/null; }; then
    printf 'cloud/pitfalls\t偵測到雲端部署 (K8s/Terraform) 或日誌可觀測性依賴\n'
  fi

  # 8. 自動化測試特徵
  if [ -d "$dir/tests" ] || [ -d "$dir/test" ] || [ -d "$dir/__tests__" ] || [ -f "$dir/jest.config.js" ] || [ -f "$dir/jest.config.ts" ] || [ -f "$dir/vitest.config.ts" ] || [ -f "$dir/vitest.config.js" ] || [ -f "$dir/phpunit.xml" ] || [ -f "$dir/pytest.ini" ] || find "$dir" -maxdepth 3 -type f \( -name '*.test.*' -o -name '*.spec.*' \) 2>/dev/null | grep -q .; then
    printf 'testing/pitfalls\t偵測到自動化測試目錄 (tests/test) 或測試設定檔\n'
  fi

  exit 0
fi

# ── --ci：安裝全平台 CI/CD 守門工作流 ────────────────────

if [ -n "$ci_dir" ]; then
  case "$ci_dir" in "~"/*) ci_dir="$HOME/${ci_dir#\~/}" ;; esac
  [ -d "$ci_dir" ] || die "目錄不存在：$ci_dir"
  SCRIPTS_DIR="$ci_dir/scripts"

  # 智慧偵測平台
  if [ -z "$ci_platform" ]; then
    if [ -f "$ci_dir/.gitlab-ci.yml" ]; then
      ci_platform="gitlab"
    elif [ -f "$ci_dir/bitbucket-pipelines.yml" ]; then
      ci_platform="bitbucket"
    elif [ -f "$ci_dir/.pre-commit-config.yaml" ]; then
      ci_platform="pre-commit"
    else
      ci_platform="github"
    fi
  fi

  case "$ci_platform" in
    github)
      WF_DIR="$ci_dir/.github/workflows"
      WF_FILE="$WF_DIR/agent-audit.yml"
      if [ "$dry_run" -eq 1 ]; then
        echo "＋ 新增 $WF_FILE"
        [ ! -f "$SCRIPTS_DIR/audit.sh" ] && echo "＋ 新增 $SCRIPTS_DIR/audit.sh"
        exit 0
      fi
      mkdir -p "$WF_DIR" "$SCRIPTS_DIR"
      cat <<'EOF' > "$WF_FILE"
name: Agent Agreements Audit

on:
  pull_request:
    types: [opened, synchronize, reopened]
  push:
    branches: [main, master]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Agent Guardrail Audit
        run: |
          if [ -f "scripts/audit.sh" ]; then
            bash scripts/audit.sh --commit HEAD
          else
            echo "Notice: scripts/audit.sh not found."
          fi
EOF
      if [ ! -f "$SCRIPTS_DIR/audit.sh" ] && [ -f "$ROOT/scripts/audit.sh" ]; then
        cp "$ROOT/scripts/audit.sh" "$SCRIPTS_DIR/audit.sh"
        chmod +x "$SCRIPTS_DIR/audit.sh"
      fi
      echo "✓ 已成功安裝 GitHub Actions CI 守門工作流：$WF_FILE"
      echo "  提示：若專案託管於 GitHub，發 PR 與 Push 將自動觸發；若為 GitLab/Bitbucket 或本地開發，可改用 scripts/audit.sh --install-hook"
      exit 0
      ;;

    gitlab)
      WF_FILE="$ci_dir/.gitlab-ci.yml"
      if [ "$dry_run" -eq 1 ]; then
        echo "＋ 新增/配置 $WF_FILE"
        [ ! -f "$SCRIPTS_DIR/audit.sh" ] && echo "＋ 新增 $SCRIPTS_DIR/audit.sh"
        exit 0
      fi
      mkdir -p "$SCRIPTS_DIR"
      if [ -f "$WF_FILE" ] && ! grep -q "agent-audit" "$WF_FILE"; then
        printf '\n' >> "$WF_FILE"
        cat "$ROOT/templates/ci/gitlab-ci.yml" >> "$WF_FILE"
      elif [ ! -f "$WF_FILE" ]; then
        cp "$ROOT/templates/ci/gitlab-ci.yml" "$WF_FILE"
      fi
      if [ ! -f "$SCRIPTS_DIR/audit.sh" ] && [ -f "$ROOT/scripts/audit.sh" ]; then
        cp "$ROOT/scripts/audit.sh" "$SCRIPTS_DIR/audit.sh"
        chmod +x "$SCRIPTS_DIR/audit.sh"
      fi
      echo "✓ 已成功安裝 GitLab CI 守門工作流：$WF_FILE"
      exit 0
      ;;

    bitbucket)
      WF_FILE="$ci_dir/bitbucket-pipelines.yml"
      if [ "$dry_run" -eq 1 ]; then
        echo "＋ 新增/配置 $WF_FILE"
        [ ! -f "$SCRIPTS_DIR/audit.sh" ] && echo "＋ 新增 $SCRIPTS_DIR/audit.sh"
        exit 0
      fi
      mkdir -p "$SCRIPTS_DIR"
      if [ -f "$WF_FILE" ] && ! grep -q "Agent Agreements Guardrail Audit" "$WF_FILE"; then
        printf '\n' >> "$WF_FILE"
        cat "$ROOT/templates/ci/bitbucket-pipelines.yml" >> "$WF_FILE"
      elif [ ! -f "$WF_FILE" ]; then
        cp "$ROOT/templates/ci/bitbucket-pipelines.yml" "$WF_FILE"
      fi
      if [ ! -f "$SCRIPTS_DIR/audit.sh" ] && [ -f "$ROOT/scripts/audit.sh" ]; then
        cp "$ROOT/scripts/audit.sh" "$SCRIPTS_DIR/audit.sh"
        chmod +x "$SCRIPTS_DIR/audit.sh"
      fi
      echo "✓ 已成功安裝 Bitbucket Pipelines 守門工作流：$WF_FILE"
      exit 0
      ;;

    pre-commit)
      WF_FILE="$ci_dir/.pre-commit-config.yaml"
      if [ "$dry_run" -eq 1 ]; then
        echo "＋ 新增/配置 $WF_FILE"
        [ ! -f "$SCRIPTS_DIR/audit.sh" ] && echo "＋ 新增 $SCRIPTS_DIR/audit.sh"
        exit 0
      fi
      mkdir -p "$SCRIPTS_DIR"
      if [ -f "$WF_FILE" ] && ! grep -q "agent-agreements-audit" "$WF_FILE"; then
        printf '\n' >> "$WF_FILE"
        cat "$ROOT/templates/ci/pre-commit-config.yaml" >> "$WF_FILE"
      elif [ ! -f "$WF_FILE" ]; then
        cp "$ROOT/templates/ci/pre-commit-config.yaml" "$WF_FILE"
      fi
      if [ ! -f "$SCRIPTS_DIR/audit.sh" ] && [ -f "$ROOT/scripts/audit.sh" ]; then
        cp "$ROOT/scripts/audit.sh" "$SCRIPTS_DIR/audit.sh"
        chmod +x "$SCRIPTS_DIR/audit.sh"
      fi
      echo "✓ 已成功安裝 pre-commit 守門配置：$WF_FILE"
      exit 0
      ;;

    *)
      die "不支援的 CI 平台：$ci_platform（支援 github、gitlab、bitbucket、pre-commit）"
      ;;
  esac
fi

# ── 安裝／移除 ─────────────────────────────────────────

targets_set=0
[ -n "$target" ] && targets_set=$((targets_set + 1))
[ -n "$cursor_dir" ] && targets_set=$((targets_set + 1))
[ -n "$agents_md" ] && targets_set=$((targets_set + 1))
[ -n "$copilot_file" ] && targets_set=$((targets_set + 1))
[ -n "$windsurf_file" ] && targets_set=$((targets_set + 1))

[ "$targets_set" -gt 1 ] && die "--target、--cursor、--agents-md、--copilot 與 --windsurf 只能擇一"
[ "$targets_set" -eq 0 ] && die "需要指定目標（--target、--cursor、--agents-md、--copilot、--windsurf 或 --ci）"

[ -n "$copilot_file" ] && agents_md="$copilot_file"
[ -n "$windsurf_file" ] && agents_md="$windsurf_file"

# 期望安裝的規則：core 全部 ＋ 選擇的 optional
desired=""
if [ "$mode" = "install" ]; then
  for id in $(all_ids); do
    [ "$(field "$RULES/$id.md" tier)" = "core" ] && desired="$desired$id"$'\n'
  done
  if [ -n "$select_ids" ]; then
    for raw_id in $(printf '%s' "$select_ids" | tr ',' ' '); do
      id="$(alias_id "$raw_id")"
      [ -f "$RULES/$id.md" ] || die "找不到規則：${raw_id}（用 --list 查看可用 id）"
      contains "$desired" "$id" || desired="$desired$id"$'\n'
    done
  fi
  desired="$(printf '%s' "$desired" | sed '/^$/d' | sort)"
fi

# ── --agents-md：只改寫標記區塊 ────────────────────────

if [ -n "$agents_md" ]; then
  case "$agents_md" in "~"/*) agents_md="$HOME/${agents_md#\~/}" ;; esac
  MAX_BYTES="${AGENTS_MD_MAX_BYTES:-32768}"

  start_ln=""; end_ln=""
  if [ -f "$agents_md" ]; then
    start_ln="$(grep -n "$START_RE" "$agents_md" | head -n 1 | cut -d: -f1 || true)"
    end_ln="$(grep -n -x -F -- "$END_LINE" "$agents_md" | head -n 1 | cut -d: -f1 || true)"
    if [ -n "$start_ln" ] && { [ -z "$end_ln" ] || [ "$end_ln" -lt "$start_ln" ]; }; then
      die "${agents_md} 的 agent-agreements 區塊不完整（找不到結束標記），請手動修正後再執行"
    fi
  fi

  # --status：唯讀，比對區塊內每條規則與目前來源
  if [ "$mode" = "status" ]; then
    if [ -z "$start_ln" ]; then
      echo "尚未安裝：${agents_md} 沒有 agent-agreements 區塊"
      exit 0
    fi
    # 區塊只讀一次存進變數：用管線餵 section 時，awk 提早 exit 會讓上游收到 SIGPIPE，大區塊下整個 --status 失敗
    blk="$(sed -n "${start_ln},${end_ln}p" "$agents_md")"
    installed_v="$(sed -n "${start_ln}s/^<!-- agent-agreements:start v\([^ ]*\) -->.*/\1/p" "$agents_md")"
    echo "安裝位置：${agents_md}"
    echo "安裝版本：${installed_v:-未記錄}｜目前版本：$(version)"
    for id in $(printf '%s\n' "$blk" | sed -n 's/^<!-- rule: \([^ ]*\) -->$/\1/p' | sort); do
      sec="$(section "$id" - <<< "$blk")"
      lines=0; [ -n "$sec" ] && lines="$(printf '%s\n' "$sec" | grep -c '')"
      src="$RULES/$id.md"
      if [ -f "$src" ]; then
        t="$(title "$src")"
        if [ "$sec" = "$(strip_body "$src")" ]; then st="最新"; else st="有新版"; fi
      else
        t="$(printf '%s\n' "$sec" | sed -n 's/^# //p' | head -n 1)"; st="來源已移除"
      fi
      # AGENTS.md 沒有 paths 機制，整個檔案都會載入，一律算常駐
      rule_record "$id" "$t" "" "$st" "$lines"
    done | report_status
    exit 0
  fi

  work="$(mktemp -d "${TMPDIR:-/tmp}/aw-agents.XXXXXX")"

  old_block="$work/old"; : > "$old_block"
  [ -n "$start_ln" ] && sed -n "${start_ln},${end_ln}p" "$agents_md" > "$old_block"
  old_ids="$(sed -n 's/^<!-- rule: \([^ ]*\) -->$/\1/p' "$old_block" | sort)"

  new_block="$work/new"; : > "$new_block"
  if [ "$mode" = "install" ]; then
    {
      echo "<!-- agent-agreements:start v$(version) -->"
      echo "<!-- agent-agreements:selected=$(printf '%s' "$select_ids" | tr -d ' ') -->"
      echo "<!-- 由 agent-working-agreements 的 install.sh 產生，請勿手動編輯；重跑 install.sh --agents-md 即可更新 -->"
      for id in $desired; do
        echo
        echo "<!-- rule: $id -->"
        strip_body "$RULES/$id.md"
      done
      echo
      echo "$END_LINE"
    } > "$new_block"
  fi

  # 差異
  changes=0; unchanged=0
  for id in $old_ids; do
    if [ "$mode" = "install" ] && contains "$desired" "$id"; then continue; fi
    printf '－ 移除 %s\n' "$(with_title "$id" "$id")"; changes=$((changes + 1))
  done
  for id in $desired; do
    if contains "$old_ids" "$id"; then
      if [ "$(section "$id" "$old_block")" = "$(section "$id" "$new_block")" ]; then
        unchanged=$((unchanged + 1))
      else
        printf '↻ 更新 %s\n' "$(with_title "$id" "$id")"; changes=$((changes + 1))
      fi
    else
      printf '＋ 新增 %s\n' "$(with_title "$id" "$id")"; changes=$((changes + 1))
    fi
  done

  # 組出新檔案：區塊外的內容逐位元組保留
  result="$work/result"; : > "$result"
  if [ -n "$start_ln" ]; then
    keep_before=$((start_ln - 1))
    # 移除時，順便拿掉當初附加區塊時加的空白分隔行
    if [ "$mode" = "uninstall" ] && [ "$keep_before" -gt 0 ] && [ -z "$(sed -n "${keep_before}p" "$agents_md")" ]; then
      keep_before=$((keep_before - 1))
    fi
    [ "$keep_before" -gt 0 ] && head -n "$keep_before" "$agents_md" >> "$result"
    cat "$new_block" >> "$result"
    tail -n "+$((end_ln + 1))" "$agents_md" >> "$result"
  elif [ "$mode" = "install" ]; then
    if [ -s "$agents_md" ]; then
      cat "$agents_md" >> "$result"
      [ "$(tail -c 1 "$agents_md" | od -An -c | tr -d ' ')" = '\n' ] || echo >> "$result"
      echo >> "$result"
    fi
    cat "$new_block" >> "$result"
  else
    echo "（${agents_md} 沒有 agent-agreements 區塊，不需移除）"
    exit 0
  fi

  bytes="$(wc -c < "$result" | tr -d ' ')"
  echo "──"
  [ "$unchanged" -gt 0 ] && echo "＝ 不變 ${unchanged} 個"
  [ "$changes" -eq 0 ] && [ -f "$agents_md" ] && cmp -s "$result" "$agents_md" && echo "（區塊內容沒有變更）"
  if [ "$mode" = "install" ]; then
    echo "規則：$(printf '%s\n' "$desired" | grep -c .) 個｜${agents_md}：${bytes} bytes"
  else
    echo "${agents_md}：${bytes} bytes"
  fi
  if [ "$bytes" -gt "$MAX_BYTES" ]; then
    echo "⚠ 超過 ${MAX_BYTES} bytes（Codex project_doc_max_bytes 預設值），超出部分可能被截斷；可減少選擇的規則" >&2
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "（dry-run：未寫入任何檔案）"
    exit 0
  fi

  mkdir -p "$(dirname "$agents_md")"
  cat "$result" > "$agents_md"
  if [ "$mode" = "uninstall" ]; then
    if [ "$bytes" -eq 0 ]; then
      echo "✓ 已移除區塊；${agents_md} 現在是空檔案（未刪除檔案）"
    else
      echo "✓ 已移除區塊：${agents_md}"
    fi
  else
    echo "✓ 完成：${agents_md}"
  fi
  exit 0
fi

is_cursor=0
ext="md"
if [ -n "$cursor_dir" ]; then
  target="$cursor_dir"
  is_cursor=1
  ext="mdc"
fi

case "$target" in "~"/*) target="$HOME/${target#\~/}" ;; esac
profile="$target/$PROFILE_NAME"

if [ -f "$profile" ] && grep -q '^format=cursor$' "$profile"; then
  is_cursor=1
  ext="mdc"
fi

# 已安裝的規則與記錄的雜湊（profile 每行：file=<id> sha256=<hash>）
installed=""
[ -f "$profile" ] && installed="$(sed -n 's/^file=\([^ ]*\) sha256=.*/\1/p' "$profile" | sort)"

recorded_sha() { sed -n "s#^file=$1 sha256=\\(.*\\)#\\1#p" "$profile" 2>/dev/null; }

is_modified() {
  local dest="$target/$1.$ext" rec
  [ -f "$dest" ] || return 1
  rec="$(recorded_sha "$1")"
  [ -n "$rec" ] && [ "$(sha "$dest")" != "$rec" ]
}

# --status：唯讀，比對 profile 記錄、目標檔案與目前來源
if [ "$mode" = "status" ]; then
  if [ ! -f "$profile" ]; then
    echo "尚未安裝：${target} 沒有 ${PROFILE_NAME}"
    exit 0
  fi
  installed_v="$(sed -n 's/^version=//p' "$profile" | head -n 1)"
  echo "安裝位置：${target}"
  echo "安裝版本：${installed_v:-未記錄}｜目前版本：$(version)"
  for id in $installed; do
    src="$RULES/$id.md"; dest="$target/$id.$ext"; rec="$(recorded_sha "$id")"
    if [ ! -f "$dest" ]; then st="檔案遺失"
    elif [ "$(sha "$dest")" != "$rec" ]; then st="已手動修改"
    elif [ ! -f "$src" ]; then st="來源已移除"
    else
      if [ "$is_cursor" -eq 1 ]; then
        expected_sha="$(cursor_content "$src" | sha)"
      else
        expected_sha="$(sha "$src")"
      fi
      if [ "$rec" != "$expected_sha" ]; then st="有新版"
      else st="最新"; fi
    fi
    # 標題與 paths 以實際載入的檔案為準；檔案遺失時退回來源，且不計入行數
    info="$dest"; lines=0
    if [ -f "$dest" ]; then lines="$(body_lines "$dest")"; else info="$src"; fi
    t=""; [ -f "$info" ] && t="$(title "$info")"
    rule_record "$id" "$t" "$info" "$st" "$lines"
  done | report_status
  exit 0
fi

new_profile=""
changes=0

record() { new_profile="${new_profile}file=$1 sha256=$2"$'\n'; }

act() {  # act <符號> <動作> <id>
  printf '%s %s %s\n' "$1" "$2" "$(with_title "$3" "$3.$ext")"
  changes=$((changes + 1))
}

# 移除不再需要的（uninstall 時全部移除）
for id in $installed; do
  if [ "$mode" = "install" ] && contains "$desired" "$id"; then continue; fi
  if is_modified "$id" && [ "$force" -eq 0 ]; then
    echo "！ 保留（已被手動修改，加 --force 才移除）$(with_title "$id" "$id.$ext")"
    record "$id" "$(recorded_sha "$id")"
    continue
  fi
  act "－" "移除" "$id"
  if [ "$dry_run" -eq 0 ]; then
    rm -f "$target/$id.$ext"
    rmdir "$(dirname "$target/$id.$ext")" 2>/dev/null || true
  fi
done

# 新增或更新
unchanged=0
for id in $desired; do
  src="$RULES/$id.md"
  dest="$target/$id.$ext"
  if [ "$is_cursor" -eq 1 ]; then
    src_sha="$(cursor_content "$src" | sha)"
  else
    src_sha="$(sha "$src")"
  fi

  if contains "$installed" "$id"; then
    if is_modified "$id" && [ "$force" -eq 0 ]; then
      echo "！ 保留（已被手動修改，加 --force 才覆蓋）$(with_title "$id" "$id.$ext")"
      record "$id" "$(recorded_sha "$id")"
      continue
    fi
    if [ -f "$dest" ] && [ "$(sha "$dest")" = "$src_sha" ]; then
      unchanged=$((unchanged + 1))
      record "$id" "$src_sha"
      continue
    fi
    act "↻" "更新" "$id"
  else
    if [ -f "$dest" ] && [ "$force" -eq 0 ] && [ "$(sha "$dest")" != "$src_sha" ]; then
      echo "！ 略過（目標已有同名檔案且非本工具安裝，加 --force 才覆蓋）$(with_title "$id" "$id.$ext")"
      continue
    fi
    act "＋" "新增" "$id"
  fi

  if [ "$dry_run" -eq 0 ]; then
    mkdir -p "$(dirname "$dest")"
    if [ "$is_cursor" -eq 1 ]; then
      cursor_content "$src" > "$dest"
    else
      cp "$src" "$dest"
    fi
  fi
  record "$id" "$src_sha"
done

# 摘要：常駐（沒有 paths）與按需載入的本文行數
always=0; ondemand=0
for id in $desired; do
  n="$(body_lines "$RULES/$id.md")"
  if has_paths "$RULES/$id.md"; then ondemand=$((ondemand + n)); else always=$((always + n)); fi
done

echo "──"
[ "$unchanged" -gt 0 ] && echo "＝ 不變 $unchanged 個"
[ "$changes" -eq 0 ] && echo "（沒有需要變更的檔案）"
if [ "$mode" = "install" ]; then
  echo "常駐：${always} 行｜按需載入：${ondemand} 行｜共 $(printf '%s\n' "$desired" | grep -c .) 個規則"
fi

if [ "$dry_run" -eq 1 ]; then
  echo "（dry-run：未寫入任何檔案）"
  exit 0
fi

# 寫入或移除 profile
if [ -z "$new_profile" ]; then
  rm -f "$profile"
  rmdir "$target" 2>/dev/null || true
  echo "✓ 已移除"
else
  mkdir -p "$target"
  {
    echo "# agent-working-agreements 安裝紀錄（由 install.sh 維護，請勿手動編輯）"
    echo "version=$(version)"
    [ "$is_cursor" -eq 1 ] && echo "format=cursor"
    echo "selected=$(printf '%s' "$select_ids" | tr -d ' ')"
    printf '%s' "$new_profile"
  } > "$profile"
  echo "✓ 完成：$target"
fi
