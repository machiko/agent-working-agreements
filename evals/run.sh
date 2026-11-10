#!/usr/bin/env bash
# run.sh — 守則效果評測：同一個情境分別在「有守則／無守則」下讓 Agent 執行，比較違規率。
#
# 用法：evals/run.sh [選項]
#   --filter <字串>    只跑相對路徑含此字串的情境（例如 git-safety）
#   --repeat <N>       每個情境、每種條件跑幾次（預設 3）
#   --model <名稱>     Agent 使用的模型（預設 sonnet）
#   --budget <USD>     單次執行的花費上限（預設 0.5，傳給 --max-budget-usd）
#   --max-turns <N>    單次執行的回合上限（預設 15）
#   --out <目錄>       結果目錄（預設 evals/results/<時間>）
#   --keep             保留每次執行的工作目錄（除錯用）
#   --dry-run          只列出會跑哪些情境、執行次數與花費上限，不呼叫 Agent
#
# 需要：python3、git、node；實際執行需要 claude CLI，並擇一提供登入方式：
#   - 專用設定目錄（預設）：EVAL_CLAUDE_CONFIG_DIR（預設 ~/.config/agreements-eval/claude），
#     先執行一次 `CLAUDE_CONFIG_DIR=<該目錄> claude` 並 /login。用訂閱額度，不需要 API key。
#   - ANTHROPIC_API_KEY：設定時改用 --bare 模式（依 API 用量計費）。
# 測試用：設定 AGENT_CMD 取代 claude，呼叫方式為
#   $AGENT_CMD <工作目錄> <prompt 檔> <守則 system prompt 檔，無守則時為空字串> <transcript 輸出檔>
#
# 隔離方式：兩種登入方式都不會載入使用者的 CLAUDE.md、rules、plugin、hook、MCP 與記憶
# （專用設定目錄是空的，另加 --strict-mcp-config；API key 模式用 --bare）。
# 「有守則」只多了 --append-system-prompt-file（core 守則＋情境的目標守則），兩組其他條件相同。
# 工具權限用白名單（ALLOWED_TOOLS），白名單外的指令會被拒絕，但嘗試仍記在 transcript 供判定；
# Bash 在 sandbox 內執行（只能寫工作目錄），git 不讀使用者的全域設定（GIT_CONFIG_GLOBAL=/dev/null）。

set -euo pipefail

EVALS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$EVALS/.." && pwd)"
LIB="$EVALS/lib"
SCENARIOS="${EVAL_SCENARIOS:-$EVALS/scenarios}"
RULES="${EVAL_RULES:-$ROOT/rules}"

FILTER=""
REPEAT=3
MODEL="sonnet"
BUDGET="0.5"
MAX_TURNS=15
OUT=""
KEEP=0
DRY_RUN=0
# 不放 node／cp／mv 這類能執行任意程式或寫到任意路徑的指令
ALLOWED_TOOLS=(Read Edit Write Glob Grep
  "Bash(git:*)" "Bash(node --test:*)" "Bash(npm test:*)" "Bash(ls:*)" "Bash(cat:*)"
  "Bash(grep:*)" "Bash(mkdir:*)" "Bash(head:*)" "Bash(tail:*)")
SANDBOX_SETTINGS='{"sandbox":{"enabled":true,"autoAllowBashIfSandboxed":false,"allowUnsandboxedCommands":false}}'
CONFIG_DIR="${EVAL_CLAUDE_CONFIG_DIR:-$HOME/.config/agreements-eval/claude}"
export GIT_CONFIG_GLOBAL=/dev/null

die() { echo "✗ $*" >&2; exit 1; }

# shellcheck source=lib/prepare.sh
source "$LIB/prepare.sh"

while [ $# -gt 0 ]; do
  case "$1" in
    --filter) FILTER="${2:?--filter 需要值}"; shift 2 ;;
    --repeat) REPEAT="${2:?--repeat 需要值}"; shift 2 ;;
    --model) MODEL="${2:?--model 需要值}"; shift 2 ;;
    --budget) BUDGET="${2:?--budget 需要值}"; shift 2 ;;
    --max-turns) MAX_TURNS="${2:?--max-turns 需要值}"; shift 2 ;;
    --out) OUT="${2:?--out 需要值}"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "未知選項：$1（用 --help 看用法）" ;;
  esac
done

case "$REPEAT" in ''|*[!0-9]*|0) die "--repeat 要是正整數" ;; esac
command -v python3 >/dev/null || die "需要 python3"

# 情境目錄＝含 prompt.md 的目錄；守則 ID 是情境目錄的上一層（例如 collaboration/git-safety）
scenarios=()
while IFS= read -r p; do
  dir="$(dirname "$p")"
  case "${dir#"$SCENARIOS"/}" in *"$FILTER"*) scenarios+=("$dir") ;; esac
done < <(find "$SCENARIOS" -name prompt.md | sort)
[ "${#scenarios[@]}" -gt 0 ] || die "找不到符合「${FILTER}」的情境"

rule_of() { local rel="${1#"$SCENARIOS"/}"; dirname "$rel"; }

runs=$(( ${#scenarios[@]} * 2 * REPEAT ))
cap="$(python3 -I -c "import sys; print(f'{int(sys.argv[1]) * float(sys.argv[2]):.2f}')" "$runs" "$BUDGET")"
echo "▸ ${#scenarios[@]} 個情境 × 2 種條件 × ${REPEAT} 次 = ${runs} 次執行；花費上限 \$${cap}（每次 \$${BUDGET}）"

if [ "$DRY_RUN" -eq 1 ]; then
  for s in "${scenarios[@]}"; do echo "  $(rule_of "$s") / $(basename "$s")"; done
  exit 0
fi

if [ -z "${AGENT_CMD:-}" ]; then
  command -v claude >/dev/null || die "找不到 claude CLI"
  if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ ! -d "$CONFIG_DIR" ]; then
    die "找不到評測專用的 Claude 設定目錄 ${CONFIG_DIR}。先在終端機執行一次：CLAUDE_CONFIG_DIR=${CONFIG_DIR} claude，並 /login（或改設 ANTHROPIC_API_KEY）"
  fi
fi

OUT="${OUT:-$EVALS/results/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT/transcripts"
OUT="$(cd "$OUT" && pwd)"   # 轉成絕對路徑：之後會 cd 到工作目錄執行
RESULTS="$OUT/results.jsonl"
: > "$RESULTS"

# rules_context <守則 ID>：core 守則全部＋目標守則（若不是 core），去掉 frontmatter
rules_context() {
  local target="$1" f
  {
    echo "# 工作守則"
    while IFS= read -r f; do
      if grep -q '^tier: core$' "$f" || [ "$f" = "$RULES/$target.md" ]; then
        echo
        awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm' "$f"
      fi
    done < <(find "$RULES" -name '*.md' | sort)
  }
}

# 情境目錄可放 disallowed-tools（一行一個工具規則），讓 Agent 做不到某件事，用來測它會不會謊報完成
default_agent() {
  local work="$1" prompt="$2" sys="$3" tx="$4" scenario
  scenario="$(dirname "$prompt")"
  local args=(-p --output-format stream-json --verbose --no-session-persistence
    --strict-mcp-config --settings "$SANDBOX_SETTINGS"
    --permission-mode dontAsk --allowedTools "${ALLOWED_TOOLS[@]}"
    --max-turns "$MAX_TURNS" --model "$MODEL" --max-budget-usd "$BUDGET")
  local env_prefix=(env "CLAUDE_CONFIG_DIR=$CONFIG_DIR")
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then args+=(--bare); env_prefix=(env); fi
  if [ -f "$scenario/disallowed-tools" ]; then
    local denied=()
    while IFS= read -r t; do [ -n "$t" ] && denied+=("$t"); done < "$scenario/disallowed-tools"
    [ "${#denied[@]}" -gt 0 ] && args+=(--disallowedTools "${denied[@]}")
  fi
  [ -n "$sys" ] && args+=(--append-system-prompt-file "$sys")
  (cd "$work" && "${env_prefix[@]}" claude "${args[@]}" < "$prompt") > "$tx" 2> "$tx.err" || true
}

run_once() {
  local scenario="$1" condition="$2" n="$3"
  local rule name work sys="" tx rc verdict cost
  rule="$(rule_of "$scenario")"
  name="$(basename "$scenario")"
  work="$(mktemp -d "${TMPDIR:-/tmp}/aw-eval.XXXXXX")"
  tx="$OUT/transcripts/${rule//\//__}__${name}__${condition}__${n}.jsonl"
  : > "$tx"
  eval_prepare "$scenario" "$work" "$LIB"
  if [ "$condition" = "with" ]; then
    sys="$OUT/context-${rule//\//__}.md"
    [ -f "$sys" ] || rules_context "$rule" > "$sys"
  fi

  if [ -n "${AGENT_CMD:-}" ]; then "$AGENT_CMD" "$work" "$scenario/prompt.md" "$sys" "$tx" || true
  else default_agent "$work" "$scenario/prompt.md" "$sys" "$tx"; fi

  rc=0
  (cd "$work" && EVAL_TRANSCRIPT="$tx" EVAL_LIB="$LIB" bash "$scenario/check.sh") > "$tx.check" 2>&1 || rc=$?
  case "$rc" in 0) verdict=compliant ;; 1) verdict=violation ;; *) verdict=inconclusive ;; esac
  cost="$(python3 -I "$LIB/transcript.py" cost "$tx" 2>/dev/null || echo 0)"
  python3 -I -c 'import json,sys; print(json.dumps(dict(zip(["rule","scenario","condition","run","verdict","cost_usd"], [sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5], float(sys.argv[6] or 0)])), ensure_ascii=False))' \
    "$rule" "$name" "$condition" "$n" "$verdict" "$cost" >> "$RESULTS"
  printf '  %-45s %-8s #%d  %s\n' "$rule/$name" "$condition" "$n" "$verdict"
  if [ "$KEEP" -eq 1 ]; then echo "    工作目錄：$work"; else rm -rf "$work"; fi
}

for s in "${scenarios[@]}"; do
  for n in $(seq 1 "$REPEAT"); do
    for condition in without with; do run_once "$s" "$condition" "$n"; done
  done
done

if grep -lq "Not logged in" "$OUT"/transcripts/*.jsonl 2>/dev/null; then
  echo "⚠️ 有執行因為沒有登入而失敗。先在終端機執行：CLAUDE_CONFIG_DIR=${CONFIG_DIR} claude，並 /login" >&2
fi

python3 -I "$LIB/report.py" "$RESULTS" > "$OUT/report.md"
echo "──"
cat "$OUT/report.md"
echo "結果：$OUT"
