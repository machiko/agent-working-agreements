// guard-lex.js — scripts/hook-guard.py 的 mask_inert 移植：把只當資料用的引號內容與 heredoc 內文清空。
// 規則說明在 hook-guard.py；bash fallback 在 scripts/lib/guard-command.awk。三份要一起改，
// tests/playground.test.sh 會用共用案例與隨機指令確認三邊輸出一致。

const QUOTE_INERT = /^[ \t\n]*((echo|printf)([ \t\n]|$)|git[ \t]+(commit|tag)([ \t\n]|$)|gh[ \t]+(pr|issue|release|api)([ \t\n]|$))/;
const PRINTF_V = /^[ \t\n]*printf[ \t]+-v/;
const HEREDOC_SINK = /^[ \t\n]*(cat|tee)([ \t\n]|$)/;
const HEREDOC_OP = /<<(-?)[ \t]*(?:'([^']*)'|"([^"]*)"|\\?([^ \t\n;&|<>()'"`]+))/y;
const BAIL_WORDS = /(^|[^A-Za-z0-9_-])(esac|alias|function)([^A-Za-z0-9_-]|$)|[A-Za-z0-9_-][ \t]*\(\)/;
const EXEC_WORDS = new Set(("bash sh zsh dash ksh fish source . exec eval xargs env sudo nohup nice timeout watch ssh " +
  "command builtin python python3 node perl ruby").split(" "));
const SKIP_WORDS = new Set("if then do else elif while until time ! { (".split(" "));
const ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=/;
const WORD_END = " \t\n;&|<>()";
const COMMENT_AFTER = " \t\n;&|()<>";

class Bail extends Error {}

// 回傳 [指令名稱, 名稱是否為 prefix 的最後一個字且沒有以空白結尾]
function commandWord(prefix) {
  const words = prefix.split(/[ \t\n]+/).filter(Boolean);
  for (const [k, raw] of words.entries()) {
    const w = raw.replace(/^[({!]+/, "");
    if (!w || SKIP_WORDS.has(w) || ASSIGNMENT.test(w)) continue;
    return [w, k === words.length - 1 && !" \t\n".includes(prefix.slice(-1) || "x")];
  }
  return ["", false];
}

function newPipeline() {
  return { pieces: [], piped: false };
}

function add(pipe, kind, text, masked = "") {
  pipe.pieces.push({ kind, text, masked });
}

// 回傳 [引號內容可清空, heredoc 內文可清空]；可能執行資料時丟 Bail
function flags(pipe) {
  let prefix = "";
  for (const p of pipe.pieces) {
    if (p.kind !== "plain") break;
    prefix += p.text;
  }
  const dynamic = pipe.pieces.some((p) => p.kind !== "plain");
  const [word, touches] = commandWord(prefix);
  if ((!word && dynamic) || (touches && dynamic) || EXEC_WORDS.has(word) || word.includes("/") || word.startsWith("$")) {
    throw new Bail();
  }
  const quoteOk = !pipe.piped && QUOTE_INERT.test(prefix) && !PRINTF_V.test(prefix);
  return [quoteOk, quoteOk || (!pipe.piped && HEREDOC_SINK.test(prefix))];
}

function render(pipe) {
  const [quoteOk, heredocOk] = flags(pipe);
  return pipe.pieces
    .map((p) => {
      if (p.kind === "quote" && quoteOk) return "";
      if (p.kind === "subst" && heredocOk) return p.masked;
      return p.text;
    })
    .join("");
}

// out 裡的項目：字串原樣輸出；管線依 flags 處理；heredoc 內文（{ owner, text, inert }）看開啟它的管線
function renderAll(out) {
  return out
    .map((x) => {
      if (typeof x === "string") return x;
      if (x.pieces) return render(x);
      const heredocOk = flags(x.owner)[1];
      return x.inert && heredocOk ? "" : x.text;
    })
    .join("");
}

function backtickEnd(s, i) {
  while (i < s.length) {
    if (s[i] === "\\") i += 2;
    else if (s[i] === "`") return i + 1;
    else i += 1;
  }
  return s.length;
}

// i 在 $(( 之後；回傳對應的 )) 之後的位置（只數括號）
function arithEnd(s, i) {
  let depth = 2;
  while (i < s.length && depth > 0) {
    if (s[i] === "(") depth += 1;
    else if (s[i] === ")") depth -= 1;
    i += 1;
  }
  return i;
}

// i 在 $' 之後；回傳結尾單引號的位置，沒有結尾回傳 -1
function ansiQuoteEnd(s, i) {
  while (i < s.length) {
    if (s[i] === "\\") i += 2;
    else if (s[i] === "'") return i;
    else i += 1;
  }
  return -1;
}

function subst(s, i, pipe) {
  const [inner, end, closed] = scan(s, i + 2, true);
  add(pipe, "subst", s.slice(i, end), "$(" + inner + (closed ? ")" : ""));
  return end;
}

function doubleQuote(s, i, pipe) {
  add(pipe, "plain", '"');
  i += 1;
  let lit = "";
  while (i < s.length) {
    const c = s[i];
    if (c === "\\") {
      lit += s.slice(i, i + 2);
      i += 2;
    } else if (c === '"') {
      add(pipe, "quote", lit);
      add(pipe, "plain", '"');
      return i + 1;
    } else if (s.startsWith("$((", i)) {
      add(pipe, "quote", lit);
      lit = "";
      const end = arithEnd(s, i + 3);
      add(pipe, "code", s.slice(i, end));
      i = end;
    } else if (s.startsWith("$(", i)) {
      add(pipe, "quote", lit);
      lit = "";
      i = subst(s, i, pipe);
    } else if (c === "`") {
      add(pipe, "quote", lit);
      lit = "";
      const end = backtickEnd(s, i + 1);
      add(pipe, "code", s.slice(i, end));
      i = end;
    } else {
      lit += c;
      i += 1;
    }
  }
  add(pipe, "plain", lit);
  return i;
}

function heredocBodies(s, i, pending, out) {
  for (const { delim, stripTabs, quoted, owner } of pending) {
    const start = i;
    let found = false;
    while (i < s.length) {
      const nl = s.indexOf("\n", i);
      const lineEnd = nl < 0 ? s.length : nl;
      const line = s.slice(i, lineEnd);
      if ((stripTabs ? line.replace(/^\t+/, "") : line) === delim) {
        const body = s.slice(start, i);
        out.push({ owner, text: body, inert: quoted || (!body.includes("$(") && !body.includes("`")) });
        out.push(s.slice(i, lineEnd + 1));
        i = lineEnd + 1;
        found = true;
        break;
      }
      i = lineEnd + 1;
    }
    if (!found) {
      out.push({ owner, text: s.slice(start), inert: false });
      i = s.length;
    }
  }
  return Math.min(i, s.length);
}

// 回傳 [處理後的文字, 結束位置, 是否遇到對應的右括號]
function scan(s, i, inSubst) {
  const out = [];
  let pipe = newPipeline();
  let pending = [];
  let depth = 0;
  const n = s.length;
  const flush = (sep) => {
    out.push(pipe, sep);
    pipe = newPipeline();
  };
  while (i < n) {
    const c = s[i];
    const two = s.slice(i, i + 2);
    if (c === "\\") {
      add(pipe, "plain", two);
      i += 2;
    } else if (c === "#" && (i === 0 || COMMENT_AFTER.includes(s[i - 1]))) {
      const nl = s.indexOf("\n", i);
      const end = nl < 0 ? n : nl;
      add(pipe, "plain", s.slice(i, end));
      i = end;
    } else if (c === "'") {
      const end = s.indexOf("'", i + 1);
      if (end < 0) {
        add(pipe, "plain", s.slice(i));
        i = n;
      } else {
        add(pipe, "plain", "'");
        add(pipe, "quote", s.slice(i + 1, end));
        add(pipe, "plain", "'");
        i = end + 1;
      }
    } else if (two === "$'") {
      const end = ansiQuoteEnd(s, i + 2);
      if (end < 0) {
        add(pipe, "plain", s.slice(i));
        i = n;
      } else {
        add(pipe, "plain", "$'");
        add(pipe, "quote", s.slice(i + 2, end));
        add(pipe, "plain", "'");
        i = end + 1;
      }
    } else if (c === '"') {
      i = doubleQuote(s, i, pipe);
    } else if (c === "`") {
      const end = backtickEnd(s, i + 1);
      add(pipe, "code", s.slice(i, end));
      i = end;
    } else if (s.startsWith("$((", i)) {
      const end = arithEnd(s, i + 3);
      add(pipe, "code", s.slice(i, end));
      i = end;
    } else if (two === "$(") {
      i = subst(s, i, pipe);
    } else if (two === ">(" || two === "<(") {
      pipe.piped = true;
      depth += 1;
      add(pipe, "plain", two);
      i += 2;
    } else if (c === "(") {
      depth += 1;
      add(pipe, "plain", c);
      i += 1;
    } else if (c === ")") {
      if (inSubst && depth === 0) {
        out.push(pipe);
        return [renderAll(out), i + 1, true];
      }
      depth = Math.max(0, depth - 1);
      add(pipe, "plain", c);
      i += 1;
    } else if (s.startsWith("<<<", i)) {
      add(pipe, "plain", "<<<");
      i += 3;
    } else if (two === "<<") {
      HEREDOC_OP.lastIndex = i;
      const m = HEREDOC_OP.exec(s);
      const delim = m ? (m[2] ?? m[3] ?? m[4] ?? "") : "";
      if (m && delim) {
        const after = i + m[0].length;
        if (after < n && !WORD_END.includes(s[after])) throw new Bail();
        pending.push({ delim, stripTabs: m[1] === "-", quoted: m[4] === undefined, owner: pipe });
        add(pipe, "plain", m[0]);
        i = after;
      } else {
        add(pipe, "plain", two);
        i += 2;
      }
    } else if (c === "\n") {
      add(pipe, "plain", c);
      flush("");
      i = heredocBodies(s, i + 1, pending, out);
      pending = [];
    } else if (two === "&&" || two === "||" || two === ";;") {
      flush(two);
      i += 2;
    } else if (c === ";" || (c === "&" && s[i + 1] !== ">" && s[i - 1] !== ">" && s[i - 1] !== "<")) {
      flush(c);
      i += 1;
    } else if (c === "|") {
      pipe.piped = true;
      add(pipe, "plain", c);
      i += 1;
    } else {
      add(pipe, "plain", c);
      i += 1;
    }
  }
  out.push(pipe);
  return [renderAll(out), n, false];
}

export function maskInert(command) {
  if (BAIL_WORDS.test(command)) return command;
  try {
    return scan(command, 0, false)[0];
  } catch (err) {
    if (err instanceof Bail) return command;
    throw err;
  }
}
