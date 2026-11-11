#!/usr/bin/env node
// build-data.mjs — 產生 Playground 的 data.json（印到 stdout）。
// 來源：scripts/lib/guard-rules.tsv 與 rules/**/*.md 的 frontmatter。
// data.json 只在部署（.github/workflows/pages.yml）與測試時產生，不 commit，避免跟原始檔不一致。
//
// 用法：node playground/build-data.mjs > playground/data.json

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { parseRulesTsv } from "./guard-match.js";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const GUARD_RULES = join(ROOT, "scripts", "lib", "guard-rules.tsv");
const RULES_DIR = join(ROOT, "rules");

function listMarkdown(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) return listMarkdown(full);
    return entry.name.endsWith(".md") ? [full] : [];
  });
}

function unquote(value) {
  return value.trim().replace(/^"(.*)"$/, "$1");
}

// 只解析需要的欄位：label、tier 與 paths／globs 清單
function parseFrontmatter(text) {
  const lines = text.split("\n");
  if (lines[0] !== "---") return { label: "", tier: "", paths: [] };
  const end = lines.indexOf("---", 1);
  const body = lines.slice(1, end === -1 ? lines.length : end);
  const field = (name) => {
    const line = body.find((l) => l.startsWith(`${name}:`));
    return line ? unquote(line.slice(name.length + 1)) : "";
  };
  const start = body.findIndex((l) => /^(paths|globs):/.test(l));
  const paths = [];
  if (start !== -1) {
    for (const line of body.slice(start + 1)) {
      const m = /^\s+-\s*(.*)$/.exec(line);
      if (!m) break;
      paths.push(unquote(m[1]));
    }
  }
  return { label: field("label"), tier: field("tier"), paths };
}

function heading(text) {
  const line = text.split("\n").find((l) => l.startsWith("# "));
  return line ? line.slice(2).trim() : "";
}

export function buildData() {
  const guardRules = parseRulesTsv(readFileSync(GUARD_RULES, "utf8"));
  const rules = listMarkdown(RULES_DIR)
    .map((file) => {
      const text = readFileSync(file, "utf8");
      const id = relative(RULES_DIR, file).split(sep).join("/").replace(/\.md$/, "");
      const fm = parseFrontmatter(text);
      return { id, label: fm.label || heading(text), tier: fm.tier, paths: fm.paths };
    })
    .sort((a, b) => a.id.localeCompare(b.id));
  return { guardRules, rules };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.stdout.write(`${JSON.stringify(buildData(), null, 2)}\n`);
}
