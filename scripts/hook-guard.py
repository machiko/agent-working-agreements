#!/usr/bin/env python3
"""hook-guard.py — Claude Code PreToolUse runtime guardrail hook.

Intercepts high-risk destructive operations before execution.
"""

import os
import re
import sys
import json


def is_destructive_git(cmd: str) -> tuple[bool, str]:
    # Check force push: --force or -f or +refs/
    if re.search(r'\bgit\s+push\b.*(^|\s)(--force|-f\b|\+refs/)', cmd):
        return True, "🛡️ 觸發 git-safety 守則攔截：嚴禁使用 force push（--force 或 -f）。所有變更應透過 feature 分支開立 PR 合併。"

    # Check git clean -f
    if re.search(r'\bgit\s+clean\b.*(^|\s)-[a-zA-Z]*f', cmd):
        return True, "🛡️ 觸發 git-safety 守則攔截：git clean -f 會永久刪除未追蹤的檔案。不可未經使用者明確指示逕行刪除。"

    # Check git reset --hard
    if re.search(r'\bgit\s+reset\s+--hard\b', cmd):
        return True, "🛡️ 觸發 git-safety 守則攔截：git reset --hard 會無預警抹除工作區所有修改。若需暫存改動請改用 git stash。"

    return False, ""


def is_destructive_system(cmd: str) -> tuple[bool, str]:
    # Check rm -rf / or rm -rf ~ or rm -rf $HOME
    if re.search(r'\brm\b.*(^|\s)-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\s+([/~]|\$HOME|/\*)(\s|$)', cmd):
        return True, "🛡️ 觸發 dangerous-operations 守則攔截：嚴禁對根目錄或家目錄執行 rm -rf 刪除操作。"

    # Check chmod -R 777
    if re.search(r'\bchmod\b.*(^|\s)-[a-zA-Z]*R[a-zA-Z]*\s+777(\s|$)', cmd) or re.search(r'\bchmod\b.*\b777\s+-[a-zA-Z]*R\b', cmd):
        return True, "🛡️ 觸發 dangerous-operations 守則攔截：嚴禁對目錄設定 777 全開放權限。"

    # Check leaking .env file via curl/wget/nc
    if re.search(r'\b(curl|wget|nc|ncat)\b.*\.env(\.[a-zA-Z0-9_-]+)?(\s|$)', cmd) or re.search(r'\bcat\s+.*\.env.*\|\s*(curl|wget|nc)', cmd):
        return True, "🛡️ 觸發 data-files 守則攔截：嚴禁將 .env 機敏設定檔透過網路傳輸或洩漏至外部。"

    return False, ""


def check_prohibit_disable() -> bool:
    for candidate in [".agreements.json", ".agreementsrc"]:
        if os.path.isfile(candidate):
            try:
                with open(candidate, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return bool(data.get("prohibit_disable_hooks", False))
            except (json.JSONDecodeError, OSError):
                continue
    return False


def main():
    prohibit_disable = check_prohibit_disable()
    if not prohibit_disable and os.environ.get("AGREEMENTS_HOOKS_DISABLE") not in (None, "", "0"):
        sys.exit(0)

    try:
        raw_input = sys.stdin.read()
        if not raw_input.strip():
            sys.exit(0)
        data = json.loads(raw_input)
    except Exception:
        # Fail-open if json parsing fails
        sys.exit(0)

    hook_event = data.get("hook_event_name", "PreToolUse")
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    if tool_name == "Bash":
        cmd = tool_input.get("command", "")
        if cmd:
            blocked, reason = is_destructive_git(cmd)
            if not blocked:
                blocked, reason = is_destructive_system(cmd)

            if blocked:
                output = {
                    "hookSpecificOutput": {
                        "hookEventName": hook_event,
                        "permissionDecision": "deny"
                    },
                    "systemMessage": reason
                }
                print(json.dumps(output, ensure_ascii=False))
                sys.exit(0)

    # Allow operation by default
    sys.exit(0)


if __name__ == "__main__":
    main()
