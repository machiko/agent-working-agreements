#!/usr/bin/env python3
"""transcript.py — 從 `claude -p --output-format stream-json` 的 transcript 取出判定需要的資訊。

用法：transcript.py <子指令> <transcript.jsonl>
  commands  每行一個 Agent 嘗試執行的 Bash 指令（含被權限拒絕的嘗試）
  reads     每行一個 Agent 嘗試讀取的檔案路徑（Read 工具，與 Bash 指令中提到的路徑分開）
  results   所有工具回傳給 Agent 的內容（判斷 Agent 實際看到了什麼）
  executed  每行一個實際執行的 Bash 指令（排除被權限拒絕的嘗試；沒有對應結果的視為已執行）
  denied    每行一個被權限拒絕的工具呼叫：「工具名<TAB>指令或輸入」
  final     Agent 最後的回覆文字
  cost      本次花費（USD），沒有就印 0
  ok        Agent 正常結束就 exit 0，否則 exit 1（逾時、錯誤、預算用完）
"""

import json
import re
import sys
from typing import Iterator, List


def events(path: str) -> Iterator[dict]:
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            if isinstance(ev, dict):
                yield ev


def tool_uses(path: str, name: str) -> List[dict]:
    found = []
    for ev in events(path):
        if ev.get("type") != "assistant":
            continue
        content = (ev.get("message") or {}).get("content") or []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("name") == name:
                found.append(block.get("input") or {})
    return found


def tool_results(path: str) -> List[str]:
    texts = []
    for ev in events(path):
        if ev.get("type") != "user":
            continue
        content = (ev.get("message") or {}).get("content") or []
        for block in content if isinstance(content, list) else []:
            if not isinstance(block, dict) or block.get("type") != "tool_result":
                continue
            texts.append(_result_text(block))
    return texts


# Claude Code 拒絕工具時回傳的訊息，例如「Permission to use Bash has been denied because …」
# 沒有結構化欄位（例如 simulate 的假事件）時的備援；--disallowedTools 的格式是「Permission to use Bash with command … has been denied.」
DENIAL = re.compile(
    r"Permission to use \S+ (with command .+? )?(has been |was )?denied|denied because Claude Code",
    re.IGNORECASE | re.DOTALL,
)


def denied_ids(path: str) -> set:
    """result 事件的 permission_denials 列出被拒絕的 tool_use_id，真實 transcript 以此為準。"""
    ids = set()
    for ev in events(path):
        if ev.get("type") != "result":
            continue
        for d in ev.get("permission_denials") or []:
            if isinstance(d, dict) and d.get("tool_use_id"):
                ids.add(d["tool_use_id"])
    return ids


def _result_text(block: dict) -> str:
    body = block.get("content")
    if isinstance(body, list):
        body = "\n".join(str(b.get("text", "")) for b in body if isinstance(b, dict))
    return str(body or "")


def paired_uses(path: str) -> List[dict]:
    """依序配對每個工具呼叫與它的結果：有 tool_use_id 就照 id，沒有就配給最早還沒有結果的呼叫。"""
    uses: List[dict] = []
    pending: List[dict] = []
    known_denied = denied_ids(path)
    for ev in events(path):
        if ev.get("type") not in ("assistant", "user") or not isinstance(ev.get("message"), dict):
            continue
        content = ev["message"].get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if ev.get("type") == "assistant" and block.get("type") == "tool_use":
                use = {"id": block.get("id"), "name": block.get("name"), "input": block.get("input") or {}, "denied": False}
                uses.append(use)
                pending.append(use)
            elif ev.get("type") == "user" and block.get("type") == "tool_result" and pending:
                tid = block.get("tool_use_id")
                use = next((u for u in pending if tid and u["id"] == tid), pending[0])
                pending.remove(use)
                use["denied"] = bool(block.get("is_error")) and bool(DENIAL.search(_result_text(block)))
    for use in uses:
        if use["id"] and use["id"] in known_denied:
            use["denied"] = True
    return uses


def _summary(use: dict) -> str:
    inp = use["input"]
    text = inp.get("command") or inp.get("file_path") or inp.get("skill") or json.dumps(inp, ensure_ascii=False)
    return str(text).replace("\n", " ")


def result(path: str) -> dict:
    last = {}
    for ev in events(path):
        if ev.get("type") == "result":
            last = ev
    return last


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, path = sys.argv[1], sys.argv[2]
    if cmd == "commands":
        for inp in tool_uses(path, "Bash"):
            print(str(inp.get("command", "")).replace("\n", " "))
    elif cmd == "reads":
        for inp in tool_uses(path, "Read"):
            print(inp.get("file_path", ""))
    elif cmd == "results":
        for text in tool_results(path):
            print(text)
    elif cmd == "executed":
        for use in paired_uses(path):
            if use["name"] == "Bash" and not use["denied"]:
                print(_summary(use))
    elif cmd == "denied":
        for use in paired_uses(path):
            if use["denied"]:
                print(f"{use['name']}\t{_summary(use)}")
    elif cmd == "final":
        print(result(path).get("result") or "")
    elif cmd == "cost":
        print(result(path).get("total_cost_usd", 0))
    elif cmd == "ok":
        r = result(path)
        return 0 if r and r.get("subtype") == "success" and not r.get("is_error") else 1
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
