#!/usr/bin/env python3
"""hook-guard.py — Claude Code PreToolUse 執行期防線的比對器。

由 hook-guard.sh 呼叫（停用開關與團隊策略檔的判斷都在 hook-guard.sh）。
從 stdin 讀 PreToolUse JSON，指令命中 lib/guard-rules.tsv 的規則就輸出 deny；
規則檔與 bash fallback 共用，兩邊行為一致。
"""

import json
import os
import re
import sys
from typing import List, Optional, Pattern, Tuple

Rule = Tuple[str, Pattern[str], str, Optional[Pattern[str]]]

RULES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib", "guard-rules.tsv")
PLACEHOLDERS = {"{S}": r"[ \t]", "{NS}": r"[^ \t\"']", "{E}": r"([^A-Za-z0-9_=./-]|$)"}
SEPARATORS = re.compile(r"&&|\|\||;|\n")


def load_rules() -> List[Rule]:
    rules: List[Rule] = []
    with open(RULES_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            rule, pattern, message, *rest = line.split("\t")
            allow = re.compile(expand(rest[0])) if rest and rest[0] else None
            rules.append((rule, re.compile(expand(pattern)), message, allow))
    return rules


def expand(pattern: str) -> str:
    for token, cls in PLACEHOLDERS.items():
        pattern = pattern.replace(token, cls)
    return pattern


def find_violation(command: str, rules: List[Rule]) -> Optional[Tuple[str, str]]:
    for segment in SEPARATORS.split(command):
        for rule, pattern, message, allow in rules:
            if pattern.search(segment) and not (allow and allow.search(segment)):
                return rule, message
    return None


def main() -> None:
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return  # 輸入不是 JSON 時放行（fail-open），不擋住 Agent 的正常操作
    if not isinstance(data, dict) or data.get("tool_name") != "Bash":
        return
    tool_input = data.get("tool_input") or {}
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not command:
        return

    hit = find_violation(command, load_rules())
    if hit is None:
        return
    rule, message = hit
    reason = f"🛡️ 觸發 {rule} 守則攔截：{message}"
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": data.get("hook_event_name", "PreToolUse"),
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        },
        "systemMessage": reason,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
