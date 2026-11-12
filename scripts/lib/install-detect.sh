#!/usr/bin/env bash
# install-detect.sh — install.sh --detect：掃描專案特徵，列出推薦的 optional 守則（tab 分隔 id 與推薦原因）。
#
# 依賴 rules.sh 的 is_deprecated（已淘汰的守則不推薦）與呼叫端的 die。
# 這支只定義函式，用 source 載入。

# detect_rules <目錄>：目錄不存在時 die；已淘汰的守則不列出
detect_rules() {
  local dir="$1"
  case "$dir" in "~"/*) dir="$HOME/${dir#\~/}" ;; esac
  [ -d "$dir" ] || die "目錄不存在：$dir"
  {

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

  # 9. AI 與 LLM 應用特徵
  # 排除 Agent 設定目錄與本工具產生的檔案（例如 .github/workflows/agent-audit.yml），否則安裝後再偵測會誤判
  if find "$dir" -maxdepth 3 \( -path '*/.git' -o -path '*/.github' -o -path '*/.claude' -o -path '*/.cursor' -o -path '*/.agreements' -o -path '*/node_modules' \) -prune \
       -o -type f \( -name '*prompt*' -o -name '*agent*' -o -name '*rag*' \) ! -name 'AGENTS.md' -print 2>/dev/null | grep -q . \
    || { [ -f "$dir/package.json" ] && grep -qiE '"(openai|@anthropic-ai|anthropic|@google/genai|langchain|@langchain|llamaindex|chromadb|pinecone|@pinecone-database|weaviate-client|qdrant|tiktoken)"' "$dir/package.json" 2>/dev/null; } \
    || { [ -f "$dir/requirements.txt" ] && grep -qiE '(openai|anthropic|google-generativeai|langchain|llama-index|chromadb|pinecone-client|qdrant-client|weaviate-client|tiktoken|litellm)' "$dir/requirements.txt" 2>/dev/null; } \
    || { [ -f "$dir/pyproject.toml" ] && grep -qiE '(openai|anthropic|google-generativeai|langchain|llama-index|chromadb|pinecone|qdrant|weaviate|litellm)' "$dir/pyproject.toml" 2>/dev/null; } \
    || { [ -f "$dir/go.mod" ] && grep -qiE '(sashabaranov/go-openai|tmc/langchaingo)' "$dir/go.mod" 2>/dev/null; }; then
    printf 'ai/pitfalls\t偵測到 AI / LLM 或向量資料庫依賴與模組\n'
  fi
  } | while IFS=$'\t' read -r did dreason; do
    # 已淘汰的守則不推薦
    is_deprecated "$did" || printf '%s\t%s\n' "$did" "$dreason"
  done
}
