#!/usr/bin/env python3
"""hook-guard.py — Claude Code PreToolUse 執行期防線的比對器。

由 hook-guard.sh 呼叫（停用開關與團隊策略檔的判斷都在 hook-guard.sh）。
從 stdin 讀 PreToolUse JSON，指令命中 lib/guard-rules.tsv 的規則就輸出 deny；
規則檔與 bash fallback 共用，兩邊行為一致。

用法：
  hook-guard.py [--team <團隊規則檔>]           stdin 為 PreToolUse JSON
  hook-guard.py --check <團隊規則檔> [案例檔]   檢查團隊規則格式，並跑案例檔；有問題 exit 1

團隊規則（.agreements/guard-rules.tsv）格式跟內建規則相同，只能多擋、不能放寬：
內建規則先比對，團隊規則的放行例外只作用在它自己那一行。
團隊規則有一行寫錯時只跳過那一行並警告，其他規則照常攔截。
"""

import json
import os
import re
import sys
from typing import List, Optional, Pattern, Tuple

Rule = Tuple[str, Pattern[str], str, Optional[Pattern[str]]]
Problem = Tuple[int, str]

RULES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib", "guard-rules.tsv")
PLACEHOLDERS = {"{S}": r"[ \t]", "{NS}": r"[^ \t\"']", "{E}": r"([^A-Za-z0-9_=./-]|$)"}
SEPARATORS = re.compile(r"&&|\|\||;|\n")
# bash fallback 用 grep -E（POSIX ERE），這些寫法在兩邊意思不同或不支援
NON_PORTABLE = re.compile(r"\\[bBsSdDwW]|\(\?")


def load_rules() -> List[Rule]:
    rules, _ = parse_rules(RULES_FILE)
    return rules


def parse_rules(path: str) -> Tuple[List[Rule], List[Problem]]:
    """讀規則檔；寫錯的行跳過並記在 problems，不丟例外。"""
    rules: List[Rule] = []
    problems: List[Problem] = []
    with open(path, "r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.rstrip("\r\n")
            if not line.strip() or line.startswith("#"):
                continue
            rule, problem = parse_rule_line(line)
            if problem:
                problems.append((lineno, problem))
            else:
                rules.append(rule)
    return rules, problems


def parse_rule_line(line: str) -> Tuple[Optional[Rule], str]:
    fields = line.split("\t")
    if len(fields) < 3 or len(fields) > 4:
        return None, f"欄位數是 {len(fields)}，要用 Tab 分成 3 或 4 欄：守則、攔截式、訊息、放行例外（選填）"
    name, pattern, message = (x.strip() for x in fields[:3])
    allow_src = fields[3].strip() if len(fields) == 4 else ""
    if not name or not pattern or not message:
        return None, "守則、攔截式、訊息都不能是空的"
    try:
        compiled = re.compile(expand(pattern))
    except re.error as e:
        return None, f"攔截式無法編譯：{e}"
    if compiled.search(""):
        return None, "攔截式連空字串都會命中，會擋掉所有指令"
    allow = None
    if allow_src:
        try:
            allow = re.compile(expand(allow_src))
        except re.error as e:
            return None, f"放行例外無法編譯：{e}"
    return (name, compiled, message, allow), ""


def expand(pattern: str) -> str:
    for token, cls in PLACEHOLDERS.items():
        pattern = pattern.replace(token, cls)
    return pattern


def find_violation(command: str, rules: List[Rule], team: Optional[List[Rule]] = None) -> Optional[Tuple[str, str, bool]]:
    """回傳 (守則, 訊息, 是否為團隊規則)；同一段子指令先比內建規則，再比團隊規則。"""
    for segment in SEPARATORS.split(command):
        for group, is_team in ((rules, False), (team or [], True)):
            for rule, pattern, message, allow in group:
                if pattern.search(segment) and not (allow and allow.search(segment)):
                    return rule, message, is_team
    return None


def load_team_rules(path: str) -> List[Rule]:
    try:
        rules, problems = parse_rules(path)
    except (OSError, UnicodeDecodeError) as e:
        print(f"⚠ [agent-agreements] 讀不到團隊攔截規則 {path}：{e}", file=sys.stderr)
        return []
    for lineno, problem in problems:
        print(f"⚠ [agent-agreements] 略過團隊攔截規則 {path}:{lineno}：{problem}", file=sys.stderr)
    return rules


def check(team_path: str, cases_path: Optional[str]) -> int:
    """檢查團隊規則與案例檔，印出問題；有問題回傳 1。"""
    errors: List[str] = []
    team_name = os.path.basename(team_path)
    try:
        team, problems = parse_rules(team_path)
    except (OSError, UnicodeDecodeError) as e:
        print(f"✗ 讀不到 {team_path}：{e}")
        return 1
    errors += [f"{team_name}:{n}：{p}" for n, p in problems]
    with open(team_path, "r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            if line.startswith("#") or not line.strip():
                continue
            fields = line.rstrip("\r\n").split("\t")
            if any(NON_PORTABLE.search(x) for x in fields[1:2] + fields[3:4]):
                errors.append(f"{team_name}:{lineno}：用了 \\b \\s \\d \\w 或 (?…)，沒有 python3 時的 bash 比對不支援；改用 {{S}}、{{E}}、[0-9] 這類寫法")

    if cases_path:
        builtin = load_rules()
        cases_name = os.path.basename(cases_path)
        with open(cases_path, "r", encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                line = line.rstrip("\r\n")
                if not line.strip() or line.startswith("#"):
                    continue
                kind, _, command = line.partition("\t")
                if kind not in ("deny", "allow") or not command:
                    errors.append(f"{cases_name}:{lineno}：格式是 deny 或 allow，加一個 Tab，再接指令")
                    continue
                hit = find_violation(command, builtin, team)
                got = "deny" if hit else "allow"
                if got != kind:
                    by = f"（{hit[0]}）" if hit else ""
                    errors.append(f"{cases_name}:{lineno}：預期 {kind}，實際 {got}{by}：{command}")

    for e in errors:
        print(f"✗ {e}")
    return 1 if errors else 0


def main(argv: List[str]) -> int:
    if argv[:1] == ["--check"]:
        if len(argv) not in (2, 3):
            print("用法：hook-guard.py --check <團隊規則檔> [案例檔]", file=sys.stderr)
            return 2
        return check(argv[1], argv[2] if len(argv) == 3 else None)

    team_path = argv[1] if argv[:1] == ["--team"] and len(argv) > 1 else ""
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return 0  # 輸入不是 JSON 時放行（fail-open），不擋住 Agent 的正常操作
    if not isinstance(data, dict) or data.get("tool_name") != "Bash":
        return 0
    tool_input = data.get("tool_input") or {}
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not command:
        return 0

    team = load_team_rules(team_path) if team_path else []
    hit = find_violation(command, load_rules(), team)
    if hit is None:
        return 0
    rule, message, is_team = hit
    reason = f"🛡️ 觸發 {rule} {'團隊規則' if is_team else '守則'}攔截：{message}"
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": data.get("hook_event_name", "PreToolUse"),
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        },
        "systemMessage": reason,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
