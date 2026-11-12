// guard-view.js — 「指令攔截」分頁：規則編輯區與比對結果。
import { compileRule, evaluate } from "./guard-match.js";
import { h, highlight, nonEmptyLines } from "./dom.js";

const STATUS_LABEL = Object.freeze({
  hit: "命中",
  allowed: "被例外放行",
  error: "規則錯誤",
});

function field(label, control) {
  return h("label", { class: "field" }, h("span", { class: "field-label" }, label), control);
}

function ruleRow(rule, index, handlers) {
  const change = (key) => (event) => handlers.onChange(index, key, event.target.value);
  return h(
    "li",
    { class: "rule-row", dataset: { index: String(index) } },
    h(
      "div",
      { class: "rule-row-head" },
      h("span", { class: "rule-index" }, `#${index + 1}`),
      h("span", { class: rule.team ? "tier tier-custom" : "tier" }, rule.team ? "團隊" : "內建"),
      field("守則", h("input", { class: "mono", value: rule.rule, spellcheck: "false", oninput: change("rule") })),
      h(
        "button",
        { type: "button", class: "icon-button", "aria-label": `刪除第 ${index + 1} 條規則`, onclick: () => handlers.onRemove(index) },
        "×",
      ),
    ),
    field(
      "攔截式",
      h("textarea", { class: "mono", rows: "2", spellcheck: "false", value: rule.pattern, oninput: change("pattern") }),
    ),
    field(
      "放行例外（可留空）",
      h("input", { class: "mono", value: rule.allow, spellcheck: "false", oninput: change("allow") }),
    ),
    field("攔截訊息", h("textarea", { rows: "2", value: rule.message, oninput: change("message") })),
    h("p", { class: "rule-error", role: "status", "aria-live": "polite", dataset: { role: "error" } }),
    h(
      "details",
      { class: "expanded" },
      h("summary", {}, "展開佔位符後的正規表示式"),
      h("code", { class: "mono", dataset: { role: "expanded" } }),
    ),
  );
}

export function renderGuardEditor(container, rules, handlers) {
  container.replaceChildren(...rules.map((rule, index) => ruleRow(rule, index, handlers)));
}

// 輸入時不重建編輯區（避免游標跳掉），只更新每列的錯誤與展開結果
export function refreshGuardMeta(container, compiledRules) {
  for (const row of container.querySelectorAll(".rule-row")) {
    const rule = compiledRules[Number(row.dataset.index)];
    if (!rule) continue;
    const error = row.querySelector('[data-role="error"]');
    error.textContent = rule.error ? `正規表示式錯誤：${rule.error}` : "";
    row.classList.toggle("has-error", Boolean(rule.error));
    const expanded = row.querySelector('[data-role="expanded"]');
    expanded.textContent = rule.expandedAllow
      ? `${rule.expandedPattern}\n放行例外：${rule.expandedAllow}`
      : rule.expandedPattern;
  }
}

function resultChip(result, rule) {
  return h(
    "li",
    { class: `chip chip-${result.status}` },
    h("span", { class: "chip-rule mono" }, `#${result.index + 1} ${rule.rule}`),
    h("span", { class: "chip-status" }, STATUS_LABEL[result.status]),
  );
}

function segmentItem(segment, compiledRules) {
  const notable = segment.results.filter((r) => r.status !== "miss");
  const marker = notable.find((r) => r.status === "hit") || notable.find((r) => r.status === "allowed");
  const text = segment.text.trim() === "" ? "（空的子指令）" : segment.text;
  return h(
    "li",
    { class: "segment" },
    h("code", { class: "mono segment-text" }, ...highlight(text, marker && marker.range, `mark-${marker && marker.status}`)),
    notable.length
      ? h("ul", { class: "chips" }, notable.map((r) => resultChip(r, compiledRules[r.index])))
      : h("p", { class: "segment-miss" }, "沒有規則命中"),
  );
}

function commandCard(command, compiledRules) {
  const result = evaluate(command, compiledRules);
  const isDeny = result.decision === "deny";
  return h(
    "article",
    { class: `verdict verdict-${result.decision}` },
    h(
      "header",
      { class: "verdict-head" },
      h("span", { class: "verdict-badge" }, isDeny ? "拒絕" : "放行"),
      h("code", { class: "mono verdict-command" }, command),
    ),
    result.segments.length > 1
      ? h("p", { class: "verdict-note" }, `切成 ${result.segments.length} 段子指令，逐段比對`)
      : null,
    result.masked !== command
      ? h("p", { class: "verdict-note" }, "echo、printf、git commit 這類指令引號裡的文字只是資料，清空後才比對")
      : null,
    h("ol", { class: "segments" }, result.segments.map((seg) => segmentItem(seg, compiledRules))),
    isDeny
      ? h(
          "p",
          { class: "verdict-reason" },
          `🛡️ 觸發 ${result.violation.rule.rule} ${result.violation.rule.team ? "團隊規則" : "守則"}攔截：${result.violation.rule.message}`,
        )
      : null,
  );
}

export function compileGuardRules(rules) {
  return rules.map(compileRule);
}

export function renderGuardResults(container, summary, compiledRules, commandsText) {
  const commands = nonEmptyLines(commandsText);
  const cards = commands.map((command) => commandCard(command, compiledRules));
  const denied = cards.filter((card) => card.classList.contains("verdict-deny")).length;
  summary.textContent = commands.length
    ? `${commands.length} 筆指令：拒絕 ${denied}｜放行 ${commands.length - denied}`
    : "輸入指令後，這裡會顯示比對結果";
  container.replaceChildren(...cards);
}
