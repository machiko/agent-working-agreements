// team-tsv.js — 團隊攔截規則檔（.agreements/guard-rules.tsv）的匯入與匯出。
// 匯出的內容要能直接被 hook-guard 讀取：tests/playground.test.sh 會用 hook-guard.py --check 驗證。
import { parseRulesTsv } from "./guard-match.js";

export const TEAM_FILE = ".agreements/guard-rules.tsv";

const HEADER = [
  "# 團隊攔截規則：Claude Code 執行 Bash 指令前比對，命中就拒絕執行。",
  "# 內建規則先比對；這裡只能多擋，不能放寬內建規則。",
  "# 格式：守則<TAB>攔截式<TAB>訊息[<TAB>放行例外]；佔位符 {S} 空白、{NS} 非空白非引號、{E} 字詞結尾",
  "# 由 Playground 匯出：https://machiko.github.io/agent-working-agreements/",
];

// Tab 與換行是欄位與行的分隔符號，出現在欄位裡會讓檔案錯位，一律換成空白
const clean = (value) => String(value ?? "").replace(/[\t\r\n]+/g, " ");

/**
 * @param {{rule: string, pattern: string, message: string, allow: string}[]} rules
 * @returns {string}
 */
export function toTeamTsv(rules) {
  const lines = rules.map((r) => {
    const fields = [r.rule, r.pattern, r.message].map(clean);
    const allow = clean(r.allow);
    return (allow ? [...fields, allow] : fields).join("\t");
  });
  return `${[...HEADER, ...lines].join("\n")}\n`;
}

/**
 * @param {string} text
 * @returns {{rule: string, pattern: string, message: string, allow: string, team: true}[]}
 */
export function fromTeamTsv(text) {
  return parseRulesTsv(text).map((rule) => ({ ...rule, team: true }));
}
