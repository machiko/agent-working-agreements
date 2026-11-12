# guard-command.awk — hook-guard.sh 的 bash fallback（沒有 python3 時）用來取出 Bash 指令並切成子指令。
# 輸入：PreToolUse JSON。輸出：一行一段子指令，跟 hook-guard.py 的 SEPARATORS 切法相同。
# 只解碼 "command" 字串本身（到結尾的引號為止），同一行的其他欄位不會被拿去比對。
# 切之前先跑 scan()：只當資料用的引號內容與 heredoc 內文清空，規則與 hook-guard.py 的 mask_inert 相同，
# Playground 的 playground/guard-lex.js 也有一份，三份要一起改。

function hexval(h,    i, v, c) {
  v = 0
  for (i = 1; i <= length(h); i++) {
    c = index("0123456789abcdef", tolower(substr(h, i, 1)))
    if (c == 0) return -1
    v = v * 16 + c - 1
  }
  return v
}

# 從 JSON 字串開頭（引號之後）解碼到結尾引號；\uXXXX 只還原 ASCII，其餘保留原樣
function decode(s,    out, i, c, n, v) {
  out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "\"") return out
    if (c != "\\") { out = out c; continue }
    n = substr(s, ++i, 1)
    if (n == "n") out = out "\n"
    else if (n == "t") out = out "\t"
    else if (n == "r") out = out "\r"
    else if (n == "u") {
      v = hexval(substr(s, i + 1, 4))
      if (v > 0 && v < 128) { out = out sprintf("%c", v); i += 4 }
      else out = out "\\u"
    }
    else out = out n
  }
  return out
}

# ── 管線：一段段文字（plain、quote、subst、code），整段掃完才決定哪些要清空 ──
# 管線存在全域 PL[編號, …]，遞迴掃 $( ) 時編號不會重複；O[…] 是每層 scan 的輸出順序。
function pnew(    id) { id = ++PID; PL[id, "n"] = 0; PL[id, "piped"] = 0; return id }

function padd(id, kind, text, masked,    k) {
  k = ++PL[id, "n"]; PL[id, "k", k] = kind; PL[id, "t", k] = text; PL[id, "m", k] = masked
}

# 設定 QOK（引號內容可清空）與 HOK（heredoc 內文可清空）
function pflags(id,    k, prefix) {
  prefix = ""
  for (k = 1; k <= PL[id, "n"]; k++) {
    if (PL[id, "k", k] != "plain") break
    prefix = prefix PL[id, "t", k]
  }
  prefix = prefix " "
  QOK = !PL[id, "piped"] && match(prefix, /^[ \t\n]*((echo|printf)[ \t\n]|git[ \t]+(commit|tag)[ \t\n]|gh[ \t]+(pr|issue|release|api)[ \t\n])/)
  HOK = QOK || (!PL[id, "piped"] && match(prefix, /^[ \t\n]*(cat|tee)[ \t\n]/))
}

function prender(id,    k, out, kind) {
  pflags(id)
  out = ""
  for (k = 1; k <= PL[id, "n"]; k++) {
    kind = PL[id, "k", k]
    if (kind == "quote" && QOK) continue
    if (kind == "subst" && HOK) { out = out PL[id, "m", k]; continue }
    out = out PL[id, "t", k]
  }
  return out
}

# O[k, "type"]：text（原樣）、pipe（管線編號）、body（heredoc 內文，看 owner 管線決定）
function oadd(O, type, a, b, c,    k) {
  k = ++O["n"]; O[k, "type"] = type; O[k, "a"] = a; O[k, "b"] = b; O[k, "c"] = c
}

function orender(O,    k, out) {
  out = ""
  for (k = 1; k <= O["n"]; k++) {
    if (O[k, "type"] == "text") out = out O[k, "a"]
    else if (O[k, "type"] == "pipe") out = out prender(O[k, "a"])
    else { pflags(O[k, "b"]); out = out ((O[k, "c"] && HOK) ? "" : O[k, "a"]) }
  }
  return out
}

function btend(s, i,    n, c) {
  n = length(s)
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") i += 2
    else if (c == "`") return i + 1
    else i++
  }
  return n + 1
}

function subst(s, i, id,    inner) {
  inner = scan(s, i + 2, 1)
  padd(id, "subst", substr(s, i, SCAN_END - i), "$(" inner (SCAN_CLOSED ? ")" : ""))
  return SCAN_END
}

function dq(s, i, id,    n, lit, c, e) {
  padd(id, "plain", "\"")
  i++; lit = ""; n = length(s)
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { lit = lit substr(s, i, 2); i += 2 }
    else if (c == "\"") { padd(id, "quote", lit); padd(id, "plain", "\""); return i + 1 }
    else if (substr(s, i, 2) == "$(" && substr(s, i, 3) != "$((") { padd(id, "quote", lit); lit = ""; i = subst(s, i, id) }
    else if (c == "`") { padd(id, "quote", lit); lit = ""; e = btend(s, i + 1); padd(id, "code", substr(s, i, e - i)); i = e }
    else { lit = lit c; i++ }
  }
  padd(id, "plain", lit)
  return i
}

# i 指向 << 的第一個 <；是 heredoc 就設定 HD_DELIM、HD_STRIP、HD_QUOTED 並回傳之後的位置，否則回傳 0
function heredoc_op(s, i,    j, c, e, w, n) {
  HD_DELIM = ""; HD_STRIP = 0; HD_QUOTED = 0
  n = length(s); j = i + 2
  if (substr(s, j, 1) == "-") { HD_STRIP = 1; j++ }
  while (substr(s, j, 1) == " " || substr(s, j, 1) == "\t") j++
  c = substr(s, j, 1)
  if (c == "'" || c == "\"") {
    e = index(substr(s, j + 1), c)
    if (!e) return 0
    HD_DELIM = substr(s, j + 1, e - 1); HD_QUOTED = 1
    return j + e + 1
  }
  w = ""
  if (c == "\\") {
    j++
    while (j <= n && !index(" \t\n;&|<>()'\"`", substr(s, j, 1))) { w = w substr(s, j, 1); j++ }
    HD_DELIM = (w == "") ? "\\" : w
    return j
  }
  while (j <= n && !index(" \t\n;&|<>()'\"`", substr(s, j, 1))) { w = w substr(s, j, 1); j++ }
  if (w == "") return 0
  HD_DELIM = w
  return j
}

function inert(body, quoted) {
  return (quoted || (!index(body, "$(") && !index(body, "`"))) ? 1 : 0
}

# i 在 heredoc 那一行的換行之後；依序讀完每個 heredoc 內文，回傳之後的位置
function bodies(s, i, H, O,    k, n, start, found, nl, le, line, cmp, body) {
  n = length(s)
  for (k = 1; k <= H["n"]; k++) {
    start = i; found = 0
    while (i <= n) {
      nl = index(substr(s, i), "\n")
      le = nl ? i + nl - 1 : n + 1
      line = substr(s, i, le - i)
      cmp = line
      if (H["s", k]) sub(/^\t+/, "", cmp)
      if (cmp == H["d", k]) {
        body = substr(s, start, i - start)
        oadd(O, "body", body, H["o", k], inert(body, H["q", k]))
        oadd(O, "text", substr(s, i, le - i + 1))
        i = le + 1; found = 1
        break
      }
      i = le + 1
    }
    if (!found) {
      body = substr(s, start)
      oadd(O, "body", body, H["o", k], inert(body, H["q", k]))
      i = n + 1
    }
  }
  return (i > n + 1) ? n + 1 : i
}

# 回傳處理後的文字；SCAN_END 為結束位置，SCAN_CLOSED 表示遇到對應的右括號
function scan(s, i, insub,    O, H, id, depth, n, c, two, e, j, k, prev) {
  O["n"] = 0; H["n"] = 0; id = pnew(); depth = 0; n = length(s)
  while (i <= n) {
    c = substr(s, i, 1); two = substr(s, i, 2)
    prev = (i > 1) ? substr(s, i - 1, 1) : ""
    if (c == "\\") { padd(id, "plain", two); i += 2 }
    else if (c == "'") {
      e = index(substr(s, i + 1), "'")
      if (!e) { padd(id, "plain", substr(s, i)); i = n + 1 }
      else { padd(id, "plain", "'"); padd(id, "quote", substr(s, i + 1, e - 1)); padd(id, "plain", "'"); i = i + e + 1 }
    }
    else if (c == "\"") i = dq(s, i, id)
    else if (c == "`") { e = btend(s, i + 1); padd(id, "code", substr(s, i, e - i)); i = e }
    else if (two == "$(" && substr(s, i, 3) != "$((") i = subst(s, i, id)
    else if (two == ">(" || two == "<(") { PL[id, "piped"] = 1; depth++; padd(id, "plain", two); i += 2 }
    else if (c == "(") { depth++; padd(id, "plain", c); i++ }
    else if (c == ")") {
      if (insub && depth == 0) { oadd(O, "pipe", id); e = orender(O); SCAN_END = i + 1; SCAN_CLOSED = 1; return e }
      if (depth > 0) depth--
      padd(id, "plain", c); i++
    }
    else if (substr(s, i, 3) == "<<<") { padd(id, "plain", "<<<"); i += 3 }
    else if (two == "<<") {
      j = heredoc_op(s, i)
      if (j && HD_DELIM != "") {
        k = ++H["n"]; H["d", k] = HD_DELIM; H["s", k] = HD_STRIP; H["q", k] = HD_QUOTED; H["o", k] = id
        padd(id, "plain", substr(s, i, j - i)); i = j
      } else { padd(id, "plain", two); i += 2 }
    }
    else if (c == "\n") {
      padd(id, "plain", c); oadd(O, "pipe", id); id = pnew()
      i = bodies(s, i + 1, H, O); H["n"] = 0
    }
    else if (two == "&&" || two == "||" || two == ";;") { oadd(O, "pipe", id); oadd(O, "text", two); id = pnew(); i += 2 }
    else if (c == ";" || (c == "&" && substr(s, i + 1, 1) != ">" && prev != ">" && prev != "<")) { oadd(O, "pipe", id); oadd(O, "text", c); id = pnew(); i++ }
    else if (c == "|") { PL[id, "piped"] = 1; padd(id, "plain", c); i++ }
    else { padd(id, "plain", c); i++ }
  }
  oadd(O, "pipe", id); e = orender(O); SCAN_END = n + 1; SCAN_CLOSED = 0
  return e
}

!done && match($0, /"command"[ \t]*:[ \t]*"/) {
  cmd = scan(decode(substr($0, RSTART + RLENGTH)), 1, 0)
  if (MASK_ONLY) { printf "%s", cmd; done = 1; next }
  gsub(/&&|\|\||;/, "\n", cmd)
  print cmd
  done = 1
}
