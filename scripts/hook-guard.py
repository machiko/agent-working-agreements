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
    name, pattern, message = fields[:3]
    allow_src = fields[3] if len(fields) == 4 else ""
    if not name.strip() or not pattern.strip() or not message.strip():
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


# ── 只是「提到」的文字不比對 ────────────────────────────────
# 指令先依 shell 詞法掃一遍，把確定只當資料用的引號內容與 heredoc 內文清空，再切子指令比對。
# 只在這些情況清空，其他一律照原文比對（寧可誤擋，不可漏擋）：
#   引號內容：管線開頭是 echo、printf（不含 -v）、git commit／tag、gh pr／issue／release／api，且管線沒有 | 或 >( <(
#   heredoc 內文：上面那些，或 cat、tee；分隔字加引號，或內文沒有 $( 與反引號；找不到結束字時不清空
#   $( ) 與反引號：裡面照樣遞迴處理；只有外層管線符合上面條件時，才採用清空後的版本
# 遇到沒模擬的語法，或可能把資料當指令執行的寫法，整條指令都不清空（_Bail）：
#   任何管線的指令是 bash、sh、source、eval、xargs、env、sudo、python 這類執行器，或是路徑、變數、動態組出的名稱；
#   出現 case／esac、alias、function、name() 函式定義；heredoc 結束字後面還黏著其他字。
# 這段邏輯在 lib/guard-command.awk（bash fallback）與 playground/guard-lex.js 各有一份，要一起改。
QUOTE_INERT = re.compile(r"^[ \t\n]*((echo|printf)([ \t\n]|$)|git[ \t]+(commit|tag)([ \t\n]|$)|gh[ \t]+(pr|issue|release|api)([ \t\n]|$))")
PRINTF_V = re.compile(r"^[ \t\n]*printf[ \t]+-v")
HEREDOC_SINK = re.compile(r"^[ \t\n]*(cat|tee)([ \t\n]|$)")
HEREDOC_OP = re.compile(r"<<(-?)[ \t]*(?:'([^']*)'|\"([^\"]*)\"|\\?([^ \t\n;&|<>()'\"`]+))")
BAIL_WORDS = re.compile(r"(^|[^A-Za-z0-9_-])(esac|alias|function)([^A-Za-z0-9_-]|$)|[A-Za-z0-9_-][ \t]*\(\)")
EXEC_WORDS = frozenset("bash sh zsh dash ksh fish source . exec eval xargs env sudo nohup nice timeout watch ssh "
                       "command builtin python python3 node perl ruby".split())
SKIP_WORDS = frozenset("if then do else elif while until time ! { (".split())
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
WORD_END = " \t\n;&|<>()"
COMMENT_AFTER = " \t\n;&|()<>"


class _Bail(Exception):
    """遇到沒模擬的語法或可能執行資料的寫法：整條指令照原文比對。"""


def _command_word(prefix: str) -> Tuple[str, bool]:
    """回傳 (指令名稱, 名稱是否為 prefix 的最後一個字且沒有以空白結尾)。"""
    words = [w for w in re.split(r"[ \t\n]+", prefix) if w]
    for k, w in enumerate(words):
        w = w.lstrip("({!")
        if not w or w in SKIP_WORDS or ASSIGNMENT.match(w):
            continue
        return w, k == len(words) - 1 and prefix[-1:] not in (" ", "\t", "\n")
    return "", False


class _Pipeline:
    def __init__(self) -> None:
        self.pieces: List[Tuple[str, str, str]] = []  # (種類, 原文, 清空後)
        self.piped = False

    def add(self, kind: str, text: str, masked: str = "") -> None:
        self.pieces.append((kind, text, masked))

    def flags(self) -> Tuple[bool, bool]:
        """回傳 (引號內容可清空, heredoc 內文可清空)；可能執行資料時丟 _Bail。"""
        prefix = ""
        for kind, text, _ in self.pieces:
            if kind != "plain":
                break
            prefix += text
        dynamic = any(kind != "plain" for kind, _, _ in self.pieces)
        word, touches = _command_word(prefix)
        if (not word and dynamic) or (touches and dynamic) or word in EXEC_WORDS or "/" in word or word[:1] == "$":
            raise _Bail()
        quote_ok = not self.piped and bool(QUOTE_INERT.match(prefix)) and not PRINTF_V.match(prefix)
        return quote_ok, quote_ok or (not self.piped and bool(HEREDOC_SINK.match(prefix)))

    def render(self) -> str:
        quote_ok, heredoc_ok = self.flags()
        out = []
        for kind, text, masked in self.pieces:
            if kind == "quote" and quote_ok:
                out.append("")
            elif kind == "subst" and heredoc_ok:
                out.append(masked)
            else:
                out.append(text)
        return "".join(out)


class _Body:
    """heredoc 內文：位置在換行之後，清不清空看開啟它的那條管線。"""

    def __init__(self, owner: _Pipeline, text: str, inert: bool) -> None:
        self.owner, self.text, self.inert = owner, text, inert

    def render(self) -> str:
        heredoc_ok = self.owner.flags()[1]
        return "" if self.inert and heredoc_ok else self.text


def _backtick_end(s: str, i: int) -> int:
    while i < len(s):
        if s[i] == "\\":
            i += 2
        elif s[i] == "`":
            return i + 1
        else:
            i += 1
    return len(s)


def _arith_end(s: str, i: int) -> int:
    """i 在 $(( 之後；回傳對應的 )) 之後的位置（只數括號）。"""
    depth = 2
    while i < len(s) and depth > 0:
        if s[i] == "(":
            depth += 1
        elif s[i] == ")":
            depth -= 1
        i += 1
    return i


def _ansi_quote_end(s: str, i: int) -> int:
    """i 在 $' 之後；回傳結尾單引號的位置，沒有結尾回傳 -1。"""
    while i < len(s):
        if s[i] == "\\":
            i += 2
        elif s[i] == "'":
            return i
        else:
            i += 1
    return -1


def _subst(s: str, i: int, pipe: _Pipeline) -> int:
    """s[i] 是 $( 的 $；回傳 ) 之後的位置。"""
    inner, end, closed = _scan(s, i + 2, True)
    pipe.add("subst", s[i:end], "$(" + inner + (")" if closed else ""))
    return end


def _double_quote(s: str, i: int, pipe: _Pipeline) -> int:
    """s[i] 是開頭的雙引號；回傳結尾引號之後的位置。"""
    pipe.add("plain", '"')
    i += 1
    lit = ""
    while i < len(s):
        c = s[i]
        if c == "\\":
            lit += s[i:i + 2]
            i += 2
        elif c == '"':
            pipe.add("quote", lit)
            pipe.add("plain", '"')
            return i + 1
        elif s.startswith("$((", i):
            pipe.add("quote", lit)
            lit = ""
            end = _arith_end(s, i + 3)
            pipe.add("code", s[i:end])
            i = end
        elif s.startswith("$(", i):
            pipe.add("quote", lit)
            lit = ""
            i = _subst(s, i, pipe)
        elif c == "`":
            pipe.add("quote", lit)
            lit = ""
            end = _backtick_end(s, i + 1)
            pipe.add("code", s[i:end])
            i = end
        else:
            lit += c
            i += 1
    pipe.add("plain", lit)  # 沒有結尾引號：shell 會語法錯誤，照原文比對
    return i


def _heredoc_bodies(s: str, i: int, pending: List[Tuple[str, bool, bool, _Pipeline]], out: list) -> int:
    """i 在 heredoc 開始的那一行換行之後；依序讀完每個 heredoc 內文，回傳之後的位置。"""
    for delim, strip_tabs, quoted, owner in pending:
        start = i
        while i < len(s):
            nl = s.find("\n", i)
            line_end = len(s) if nl < 0 else nl
            line = s[i:line_end]
            if (line.lstrip("\t") if strip_tabs else line) == delim:
                body = s[start:i]
                inert = quoted or ("$(" not in body and "`" not in body)
                out.append(_Body(owner, body, inert))
                out.append(s[i:line_end + 1])
                i = line_end + 1
                break
            i = line_end + 1
        else:
            out.append(_Body(owner, s[start:], False))  # 找不到結束字：照原文比對
            i = len(s)
    return min(i, len(s))


def _render(out: list) -> str:
    return "".join(x if isinstance(x, str) else x.render() for x in out)


def _scan(s: str, i: int, in_subst: bool) -> Tuple[str, int, bool]:
    """回傳 (處理後的文字, 結束位置, 是否遇到對應的右括號)。"""
    out: list = []  # 管線、heredoc 內文與原樣文字，依原本順序
    pipe = _Pipeline()
    pending: List[Tuple[str, bool, bool, _Pipeline]] = []
    depth = 0
    n = len(s)
    while i < n:
        c = s[i]
        two = s[i:i + 2]
        if c == "\\":
            pipe.add("plain", s[i:i + 2])
            i += 2
        elif c == "#" and (i == 0 or s[i - 1] in COMMENT_AFTER):
            nl = s.find("\n", i)
            end = n if nl < 0 else nl
            pipe.add("plain", s[i:end])
            i = end
        elif c == "'":
            end = s.find("'", i + 1)
            if end < 0:
                pipe.add("plain", s[i:])
                i = n
            else:
                pipe.add("plain", "'")
                pipe.add("quote", s[i + 1:end])
                pipe.add("plain", "'")
                i = end + 1
        elif two == "$'":
            end = _ansi_quote_end(s, i + 2)
            if end < 0:
                pipe.add("plain", s[i:])
                i = n
            else:
                pipe.add("plain", "$'")
                pipe.add("quote", s[i + 2:end])
                pipe.add("plain", "'")
                i = end + 1
        elif c == '"':
            i = _double_quote(s, i, pipe)
        elif c == "`":
            end = _backtick_end(s, i + 1)
            pipe.add("code", s[i:end])
            i = end
        elif s.startswith("$((", i):
            end = _arith_end(s, i + 3)
            pipe.add("code", s[i:end])
            i = end
        elif two == "$(":
            i = _subst(s, i, pipe)
        elif two in (">(", "<("):
            pipe.piped = True
            depth += 1
            pipe.add("plain", two)
            i += 2
        elif c == "(":
            depth += 1
            pipe.add("plain", c)
            i += 1
        elif c == ")":
            if in_subst and depth == 0:
                out.append(pipe)
                return _render(out), i + 1, True
            depth = max(0, depth - 1)
            pipe.add("plain", c)
            i += 1
        elif s.startswith("<<<", i):
            pipe.add("plain", "<<<")
            i += 3
        elif two == "<<":
            m = HEREDOC_OP.match(s, i)
            delim = next((g for g in m.groups()[1:] if g is not None), "") if m else ""
            if m and delim:
                if m.end() < n and s[m.end()] not in WORD_END:
                    raise _Bail()  # 'EOF'x 這類相連的結束字
                pending.append((delim, m.group(1) == "-", m.group(4) is None, pipe))
                pipe.add("plain", m.group(0))
                i = m.end()
            else:
                pipe.add("plain", two)
                i += 2
        elif c == "\n":
            pipe.add("plain", c)
            out.append(pipe)
            pipe = _Pipeline()
            i = _heredoc_bodies(s, i + 1, pending, out)
            pending = []
        elif two in ("&&", "||", ";;"):
            out += [pipe, two]
            pipe = _Pipeline()
            i += 2
        elif c == ";" or (c == "&" and s[i + 1:i + 2] != ">" and s[i - 1:i] not in (">", "<")):
            out += [pipe, c]
            pipe = _Pipeline()
            i += 1
        elif c == "|":
            pipe.piped = True
            pipe.add("plain", c)
            i += 1
        else:
            pipe.add("plain", c)
            i += 1
    out.append(pipe)
    return _render(out), n, False


def mask_inert(command: str) -> str:
    """把只當資料用的引號內容與 heredoc 內文清空；沒把握時整條原樣回傳。"""
    if BAIL_WORDS.search(command):
        return command
    try:
        return _scan(command, 0, False)[0]
    except _Bail:
        return command


def find_violation(command: str, rules: List[Rule], team: Optional[List[Rule]] = None) -> Optional[Tuple[str, str, bool]]:
    """回傳 (守則, 訊息, 是否為團隊規則)；同一段子指令先比內建規則，再比團隊規則。"""
    for segment in SEPARATORS.split(mask_inert(command)):
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
