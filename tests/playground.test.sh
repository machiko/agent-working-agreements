#!/usr/bin/env bash
# playground.test.sh — 規則命中測試台（playground/）的比對邏輯測試。
# 重點是 JS 移植版跟 hook-guard.py 判定一致：兩邊跑同一份 tests/fixtures/guard-cases.tsv，
# 而且拒絕時命中的守則也要相同。另測 glob 比對與 data.json 產生器。
set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/tests/fixtures/guard-cases.tsv"

if ! command -v node >/dev/null 2>&1; then
  echo "▸ 略過 playground 測試（環境沒有 node）"
  exit 0
fi

# Python 的判定：每筆案例輸出「deny<TAB>守則」或「allow」，一行一筆，順序同案例檔
PY_VERDICTS=""
if command -v python3 >/dev/null 2>&1; then
  PY_VERDICTS="$(python3 - "$ROOT/scripts/hook-guard.py" "$CASES" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("hook_guard", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
rules = mod.load_rules()
with open(sys.argv[2], encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        _, cmd = line.split("\t", 1)
        hit = mod.find_violation(cmd, rules)
        print(f"deny\t{hit[0]}" if hit else "allow")
PY
)"
fi

PY_VERDICTS="$PY_VERDICTS" node --input-type=module - "$ROOT" <<'JS'
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = process.argv[2];
const load = (rel) => import(pathToFileURL(join(root, rel)).href);
const { compileRule, evaluate, parseRulesTsv, expand } = await load("playground/guard-match.js");
const { compileGlob, normalizePath, firstMatchingGlob } = await load("playground/glob-match.js");
const { buildData } = await load("playground/build-data.mjs");

let pass = 0;
let fail = 0;
const check = (name, ok) => {
  if (ok) { pass += 1; console.log(`  ✓ ${name}`); }
  else { fail += 1; console.error(`  ✗ ${name}`); }
};

const rules = parseRulesTsv(readFileSync(join(root, "scripts/lib/guard-rules.tsv"), "utf8")).map(compileRule);
check("內建攔截規則全部能編譯成 JS RegExp", rules.length > 0 && rules.every((r) => !r.error));

const cases = readFileSync(join(root, "tests/fixtures/guard-cases.tsv"), "utf8")
  .split("\n")
  .filter((l) => l && !l.startsWith("#"))
  .map((l) => { const i = l.indexOf("\t"); return { kind: l.slice(0, i), cmd: l.slice(i + 1) }; });
const py = (process.env.PY_VERDICTS || "").split("\n").filter(Boolean);

console.log("▸ JS 比對器 × 共用案例檔");
for (const [i, c] of cases.entries()) {
  const result = evaluate(c.cmd, rules);
  check(`[js] ${c.kind === "deny" ? "攔截" : "放行"}：${c.cmd}`, result.decision === c.kind);
  if (py.length) {
    const js = result.violation ? `deny\t${result.violation.rule.rule}` : "allow";
    check(`[js = python] 命中守則一致：${c.cmd}`, js === py[i]);
  }
}
if (!py.length) console.log("▸ 略過 python 對照（環境沒有 python3）");

console.log("▸ 比對明細");
const clean = evaluate("git clean -nfd", rules);
check("git clean -nfd 標示為「被例外放行」", clean.segments[0].results.some((r) => r.status === "allowed"));
const chained = evaluate("echo ok && rm -rf /", rules);
check("串接指令切成兩段，第二段被攔", chained.segments.length === 2 && chained.violation.segment === 1);
const hit = chained.segments[1].results.find((r) => r.status === "hit");
check("命中範圍落在子指令內", hit && hit.range[0] >= 0 && hit.range[1] <= chained.segments[1].text.length);
const broken = [compileRule({ rule: "bad", pattern: "git (push", message: "", allow: "" }), ...rules];
check("錯誤的正規表示式只標記該條規則，不丟例外", broken[0].error && !broken.slice(1).some((r) => r.error));
check("錯誤規則不影響其他規則判定", evaluate("git reset --hard", broken).decision === "deny");
check("佔位符展開", expand("a{S}b{E}") === "a[ \\t]b([^A-Za-z0-9_=./-]|$)");

console.log("▸ glob 比對");
const globCases = [
  ["**/*.tsx", "app/components/Button.tsx", true],
  ["**/*.tsx", "Button.tsx", true],
  ["**/*.tsx", "Button.ts", false],
  ["**/api/**", "api/users.ts", true],
  ["**/api/**", "src/api/v1/users.ts", true],
  ["**/api/**", "src/apis/users.ts", false],
  ["**/*.{php,js,ts}", "app/Http/UserController.php", true],
  ["**/*.{php,js,ts}", "app/main.py", false],
  ["**/Dockerfile*", "deploy/Dockerfile.dev", true],
  ["**/*.test.*", "src/a.test.ts", true],
  ["**/*.test.*", "src/atest.ts", false],
  ["src/?.go", "src/a.go", true],
  ["src/?.go", "src/ab.go", false],
  ["*.md", "docs/a.md", false],
];
for (const [glob, path, expected] of globCases) {
  check(`${glob} ${expected ? "命中" : "不命中"} ${path}`, compileGlob(glob).test(path) === expected);
}
check("路徑正規化：去掉開頭的 ./", normalizePath("./src/main.go") === "src/main.go");
check("路徑正規化：反斜線轉 /", normalizePath(".\\src\\main.go") === "src/main.go");
check("firstMatchingGlob 回傳第一個命中的 glob", firstMatchingGlob("./a/b.vue", ["**/*.ts", "**/*.vue"]) === "**/*.vue");

console.log("▸ data.json 產生器");
const data = buildData();
const schema = JSON.parse(readFileSync(join(root, "schema/v1.json"), "utf8"));
const ids = schema.properties.enforce_rules.items.anyOf.find((x) => x.enum).enum;
const built = data.rules.map((r) => r.id);
check(`涵蓋 schema 列出的 ${ids.length} 份守則`, ids.every((id) => built.includes(id)) && built.length === ids.length);
check("攔截規則數量與 guard-rules.tsv 相同", data.guardRules.length === rules.length);
check("每份守則都有標題", data.rules.every((r) => r.label));
check("內建守則的 paths 都能編譯成 glob", data.rules.every((r) => r.paths.every((g) => compileGlob(g) instanceof RegExp)));
check("有 paths 的守則數量大於零", data.rules.some((r) => r.paths.length > 0));

// ai/pitfalls 曾用 **/*ai*、**/*rag*，main.go、storage.ts 這類一般檔案都會載入；放在 ai/ 目錄下的檔案反而沒命中
console.log("▸ ai/pitfalls 載入範圍");
const aiPaths = data.rules.find((r) => r.id === "ai/pitfalls")?.paths ?? [];
const aiHits = ["src/ai/client.py", "src/rag/retriever.py", "src/prompts/system.md", "src/chat/ai_service.ts",
  "app/Services/AiService.php", "src/Services/OpenAIClient.php", "src/LLMClient.ts", "src/rag_pipeline.py",
  "services/vector_store.py", "src/anthropic_client.ts"];
const aiMisses = ["src/main.go", "src/components/Detail.tsx", "app/Services/MailService.php", "docker/container.yml",
  "src/utils/storage.ts", "src/fragment.js", "src/drag-drop.ts", "src/train.py", "lib/chain.rb", "src/air/quality.py"];
for (const p of aiHits) check(`載入 ${p}`, firstMatchingGlob(p, aiPaths) !== null);
for (const p of aiMisses) check(`不載入 ${p}`, firstMatchingGlob(p, aiPaths) === null);

console.log("──");
console.log(`通過 ${pass}｜失敗 ${fail}`);
process.exit(fail ? 1 : 0);
JS
