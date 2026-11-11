// guard-match.js — scripts/hook-guard.py 比對邏輯的 JS 移植，給 Playground 使用。
// 判定結果必須跟 Python／bash 一致：tests/playground.test.sh 用 tests/fixtures/guard-cases.tsv 驗證。
// 跟 hook-guard.py 的差別只有一個：這裡回傳每段子指令 × 每條規則的比對明細，不是只回傳第一條命中。

export const PLACEHOLDERS = Object.freeze({
  "{S}": "[ \\t]",
  "{NS}": "[^ \\t\"']",
  "{E}": "([^A-Za-z0-9_=./-]|$)",
});

const SEPARATORS = /&&|\|\||;|\n/;

export function expand(pattern) {
  return Object.entries(PLACEHOLDERS).reduce(
    (acc, [token, cls]) => acc.split(token).join(cls),
    pattern,
  );
}

// 編譯失敗時回傳 { error }，讓 UI 只在該列提示，不影響其他規則
function compile(source) {
  if (!source) return { regex: null, error: null };
  try {
    return { regex: new RegExp(expand(source)), error: null };
  } catch (err) {
    return { regex: null, error: err.message };
  }
}

// rule: { rule, pattern, message, allow }
export function compileRule(rule) {
  const block = compile(rule.pattern);
  const allow = compile(rule.allow || "");
  return Object.freeze({
    ...rule,
    expandedPattern: expand(rule.pattern),
    expandedAllow: rule.allow ? expand(rule.allow) : "",
    blockRegex: block.regex,
    allowRegex: allow.regex,
    error: block.error || allow.error,
  });
}

export function parseRulesTsv(text) {
  return text
    .split("\n")
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => {
      const [rule, pattern, message, allow = ""] = line.split("\t");
      return { rule, pattern, message, allow };
    });
}

// status：hit（命中且未被放行）、allowed（命中但被例外放行）、miss、error
function matchSegment(segment, compiled) {
  if (compiled.error || !compiled.blockRegex) {
    return { status: "error", range: null };
  }
  const m = compiled.blockRegex.exec(segment);
  if (!m) return { status: "miss", range: null };
  const range = [m.index, m.index + m[0].length];
  if (compiled.allowRegex && compiled.allowRegex.test(segment)) {
    return { status: "allowed", range };
  }
  return { status: "hit", range };
}

// 回傳 { decision: "deny" | "allow", violation, segments: [{ text, results: [...] }] }
// violation 與 hook-guard.py 的 find_violation 相同：依子指令順序、再依規則順序的第一個 hit
export function evaluate(command, compiledRules) {
  const segments = command.split(SEPARATORS).map((text) => ({
    text,
    results: compiledRules.map((rule, index) => ({ index, ...matchSegment(text, rule) })),
  }));
  let violation = null;
  for (const [segIndex, seg] of segments.entries()) {
    const hit = seg.results.find((r) => r.status === "hit");
    if (hit) {
      violation = { segment: segIndex, rule: compiledRules[hit.index] };
      break;
    }
  }
  return { decision: violation ? "deny" : "allow", violation, segments };
}
