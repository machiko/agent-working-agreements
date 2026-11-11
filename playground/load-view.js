// load-view.js — 「守則載入」分頁：守則 paths 編輯區與檔案路徑比對結果。
import { compileGlob, normalizePath } from "./glob-match.js";
import { h, nonEmptyLines } from "./dom.js";

// 樣本數至少這麼多、且命中比例超過這個值時，提示 glob 範圍可能太寬
const BROAD_MIN_SAMPLES = 3;
const BROAD_RATIO = 0.5;

const TIER_LABEL = Object.freeze({ core: "核心", optional: "選用", custom: "團隊" });

function ruleRow(rule, index, handlers) {
  const idControl = rule.builtin
    ? h("span", { class: "mono load-id" }, rule.id)
    : h("input", {
        class: "mono load-id",
        value: rule.id,
        spellcheck: "false",
        "aria-label": "團隊守則 id",
        oninput: (event) => handlers.onChange(index, "id", event.target.value),
      });
  return h(
    "li",
    { class: "load-row", dataset: { index: String(index) } },
    h(
      "div",
      { class: "load-row-head" },
      h("span", { class: `tier tier-${rule.tier || "optional"}` }, TIER_LABEL[rule.tier] || rule.tier || "選用"),
      idControl,
      h("span", { class: "load-count", dataset: { role: "count" } }),
      rule.builtin
        ? null
        : h(
            "button",
            { type: "button", class: "icon-button", "aria-label": `刪除 ${rule.id}`, onclick: () => handlers.onRemove(index) },
            "×",
          ),
    ),
    h("p", { class: "load-label" }, rule.label),
    h(
      "label",
      { class: "field" },
      h("span", { class: "field-label" }, "paths（一行一個 glob；留空代表裝了就常駐）"),
      h("textarea", {
        class: "mono",
        rows: String(Math.min(Math.max(rule.paths.length, 1), 6)),
        spellcheck: "false",
        value: rule.paths.join("\n"),
        placeholder: "（常駐）",
        oninput: (event) => handlers.onChange(index, "paths", nonEmptyLines(event.target.value)),
      }),
    ),
    h("p", { class: "load-broad", role: "status", dataset: { role: "broad" } }),
  );
}

export function renderLoadEditor(container, rules, handlers) {
  container.replaceChildren(...rules.map((rule, index) => ruleRow(rule, index, handlers)));
}

// glob 語法不會丟例外（未閉合的 { 當一般字元），所以這裡不需要錯誤處理
function matchRule(rule, path) {
  return rule.paths.find((glob) => compileGlob(glob).test(path)) ?? null;
}

export function computeLoad(rules, filesText) {
  const files = nonEmptyLines(filesText).map(normalizePath);
  // 以索引當 key：團隊守則的 id 可能跟內建守則重複，不能用 id 區分
  const scoped = rules.flatMap((rule, index) => (rule.paths.length > 0 ? [{ rule, index }] : []));
  const perFile = files.map((path) => ({
    path,
    matches: scoped.flatMap(({ rule, index }) => {
      const glob = matchRule(rule, path);
      return glob ? [{ id: rule.id, index, glob }] : [];
    }),
  }));
  const counts = new Map(scoped.map(({ index }) => [index, 0]));
  for (const file of perFile) {
    for (const m of file.matches) counts.set(m.index, counts.get(m.index) + 1);
  }
  return { files, perFile, counts, alwaysOn: rules.length - scoped.length };
}

export function refreshLoadCounts(container, rules, load) {
  const total = load.files.length;
  for (const row of container.querySelectorAll(".load-row")) {
    const index = Number(row.dataset.index);
    if (!rules[index]) continue;
    const count = load.counts.get(index);
    const isScoped = count !== undefined;
    const isBroad = isScoped && total >= BROAD_MIN_SAMPLES && count / total > BROAD_RATIO;
    row.querySelector('[data-role="count"]').textContent = isScoped ? `命中 ${count}／${total}` : "常駐";
    row.querySelector('[data-role="broad"]').textContent = isBroad ? "命中超過一半的樣本，載入範圍可能太寬" : "";
    row.classList.toggle("is-hit", isScoped && count > 0);
    row.classList.toggle("is-broad", isBroad);
  }
}

function fileCard(file) {
  return h(
    "article",
    { class: `file-card ${file.matches.length ? "file-hit" : "file-miss"}` },
    h("code", { class: "mono file-path" }, file.path),
    file.matches.length
      ? h(
          "ul",
          { class: "chips" },
          file.matches.map((m) =>
            h(
              "li",
              { class: "chip chip-load" },
              h("span", { class: "chip-rule mono" }, m.id),
              h("span", { class: "chip-status mono" }, m.glob),
            ),
          ),
        )
      : h("p", { class: "segment-miss" }, "不會載入任何按需守則"),
  );
}

export function renderLoadResults(container, summary, load) {
  const loaded = load.perFile.filter((f) => f.matches.length).length;
  summary.textContent = load.files.length
    ? `${load.files.length} 個路徑：${loaded} 個會載入按需守則｜另有 ${load.alwaysOn} 份常駐守則一律載入`
    : "輸入檔案路徑後，這裡會顯示會載入哪些守則";
  container.replaceChildren(...load.perFile.map(fileCard));
}
