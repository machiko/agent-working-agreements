#!/usr/bin/env python3
"""transcript.py — 從 `claude -p --output-format stream-json` 的 transcript 取出判定需要的資訊。

用法：transcript.py <子指令> <transcript.jsonl>
  commands  每行一個 Agent 嘗試執行的 Bash 指令（含被權限拒絕的嘗試）
  reads     每行一個 Agent 嘗試讀取的檔案路徑（Read 工具，與 Bash 指令中提到的路徑分開）
  results   所有工具回傳給 Agent 的內容（判斷 Agent 實際看到了什麼）
  final     Agent 最後的回覆文字
  cost      本次花費（USD），沒有就印 0
  ok        Agent 正常結束就 exit 0，否則 exit 1（逾時、錯誤、預算用完）
"""

import json
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
            body = block.get("content")
            if isinstance(body, list):
                body = "\n".join(str(b.get("text", "")) for b in body if isinstance(b, dict))
            texts.append(str(body or ""))
    return texts


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
