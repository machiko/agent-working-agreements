// glob-match.js — 守則 frontmatter paths 的 glob 比對，給 Playground 使用。
// 採常見 glob 語意：** 跨目錄（含零層）、* 與 ? 不跨 /、{a,b} 多選一。
// 實際載入由各 Agent 自行比對（Claude Code、Cursor 各有實作），這裡只是近似，頁面上有註明。

const REGEX_SPECIAL = /[.+^$()|[\]\\]/;

// 把 {a,b} 內容轉成 (?:a|b)；巢狀大括號不支援，遇到就當一般字元
function braceToRegex(body) {
  return `(?:${body.split(",").map(globToRegexSource).join("|")})`;
}

/**
 * @param {string} glob
 * @returns {string} RegExp 原始碼（不含 ^ $）
 */
export function globToRegexSource(glob) {
  let out = "";
  let i = 0;
  while (i < glob.length) {
    const ch = glob[i];
    if (glob.startsWith("**/", i)) {
      out += "(?:.*/)?";
      i += 3;
    } else if (glob.startsWith("**", i)) {
      out += ".*";
      i += 2;
    } else if (ch === "*") {
      out += "[^/]*";
      i += 1;
    } else if (ch === "?") {
      out += "[^/]";
      i += 1;
    } else if (ch === "{" && glob.indexOf("}", i) > i) {
      const close = glob.indexOf("}", i);
      out += braceToRegex(glob.slice(i + 1, close));
      i = close + 1;
    } else {
      out += REGEX_SPECIAL.test(ch) ? `\\${ch}` : ch;
      i += 1;
    }
  }
  return out;
}

/**
 * @param {string} glob
 * @returns {RegExp}
 */
export function compileGlob(glob) {
  return new RegExp(`^${globToRegexSource(glob)}$`);
}

// 路徑正規化：反斜線轉 /、去掉開頭的 ./ 與 /
export function normalizePath(path) {
  return path.trim().replace(/\\/g, "/").replace(/^(\.\/)+/, "").replace(/^\/+/, "");
}

/**
 * 回傳路徑命中的第一個 glob；沒命中回傳 null
 * @param {string} path
 * @param {string[]} globs
 * @returns {string | null}
 */
export function firstMatchingGlob(path, globs) {
  const target = normalizePath(path);
  return globs.find((glob) => compileGlob(glob).test(target)) ?? null;
}
