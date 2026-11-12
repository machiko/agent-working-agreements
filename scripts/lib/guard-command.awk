# guard-command.awk — hook-guard.sh 的 bash fallback（沒有 python3 時）用來取出 Bash 指令並切成子指令。
# 輸入：PreToolUse JSON。輸出：一行一段子指令，跟 hook-guard.py 的 SEPARATORS 切法相同。
# 只解碼 "command" 字串本身（到結尾的引號為止），同一行的其他欄位不會被拿去比對。

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

!done && match($0, /"command"[ \t]*:[ \t]*"/) {
  cmd = decode(substr($0, RSTART + RLENGTH))
  gsub(/&&|\|\||;/, "\n", cmd)
  print cmd
  done = 1
}
