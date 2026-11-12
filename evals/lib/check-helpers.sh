# check-helpers.sh — 情境 check.sh 與 simulate 腳本共用的函式。由 run.sh 與測試以 source 載入。
#
# 需要的環境變數：
#   EVAL_TRANSCRIPT  Agent 的 transcript（stream-json，每行一個事件）
#   EVAL_LIB         本目錄路徑
#
# check.sh 的結束碼：0 合規、1 違規、2 無法判定（例如 Agent 沒有正常結束）

COMPLIANT=0
VIOLATION=1
INCONCLUSIVE=2

_tx() { python3 -I "$EVAL_LIB/transcript.py" "$1" "$EVAL_TRANSCRIPT"; }

# Agent 嘗試執行過的 Bash 指令，一行一個
commands() { _tx commands; }
# Agent 用 Read 工具讀過的檔案
reads() { _tx reads; }
# Agent 最後的回覆
final_text() { _tx final; }
# 工具回傳給 Agent 的所有內容（Agent 實際看到的東西）
tool_output() { _tx results; }

# code_only：濾掉註解行，避免註解裡提到關鍵字造成誤判
code_only() { grep -Ev '^[[:space:]]*(//|/\*|\*|#|--)' || true; }

# ran <ERE>：有任何 Bash 指令符合就回傳 0
ran() { commands | grep -Eq -- "$1"; }

# said <ERE>：最後回覆符合就回傳 0（不分大小寫）
said() { final_text | grep -Eiq -- "$1"; }

# eval_node：印出第一個能正常執行的 node（PATH 前段可能有壞掉的安裝）；都不能用就回傳 1。
# 需要實際執行程式才能判定的 check.sh 用：NODE="$(eval_node)" || exit "$INCONCLUSIVE"
eval_node() {
  local n
  while IFS= read -r n; do
    "$n" -e 0 >/dev/null 2>&1 && { echo "$n"; return 0; }
  done < <(type -ap node)
  return 1
}

# require_finished：Agent 沒有正常結束就直接判定為無法判定
require_finished() { _tx ok || exit "$INCONCLUSIVE"; }

# changed_files：相對於初始 commit（tag eval-base）的所有變動檔案，含未追蹤檔
changed_files() {
  { git diff --name-only eval-base; git ls-files --others --exclude-standard; } | sort -u
}

# added_lines [pathspec…]：相對於 eval-base 新增的行（含已 commit、已暫存、未暫存），加上新的未追蹤檔全文
added_lines() {
  git diff eval-base -- "$@" | grep '^+' | grep -v '^+++' | cut -c2- || true
  git ls-files --others --exclude-standard -- "$@" | while IFS= read -r f; do cat "$f"; done
}

# ── simulate 腳本用：寫出假的 transcript 事件 ──

_fake_event() { python3 -I -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1]), ensure_ascii=False))' "$1" >> "$EVAL_TRANSCRIPT"; }
_json_str() { python3 -I -c 'import json,sys; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$1"; }

fake_bash() {
  _fake_event "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":$(_json_str "$1")}}]}}"
}
fake_read() {
  _fake_event "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{\"file_path\":$(_json_str "$1")}}]}}"
}
fake_result() {
  _fake_event "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"content\":$(_json_str "$1")}]}}"
}
fake_final() {
  _fake_event "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"total_cost_usd\":0,\"result\":$(_json_str "$1")}"
}
